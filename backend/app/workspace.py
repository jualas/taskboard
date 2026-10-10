"""Inspección de carpetas de proyecto (git, docker compose) bajo WORKSPACE_ROOTS."""

from __future__ import annotations

import asyncio
import json
import os
import difflib
from pathlib import Path
from typing import Any

from fastapi import HTTPException, status

from .config import settings

_COMPOSE_NAMES = ("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")


def workspace_roots() -> list[Path]:
    raw = (settings.workspace_roots or "").strip()
    if not raw:
        return []
    out: list[Path] = []
    for part in raw.split(","):
        p = part.strip()
        if not p:
            continue
        try:
            out.append(Path(p).expanduser().resolve())
        except OSError:
            continue
    return out


def _within_roots(path: Path, roots: list[Path]) -> bool:
    for root in roots:
        try:
            path.relative_to(root)
            return True
        except ValueError:
            continue
    return False


def _similar_path_hint(resolved: Path, roots: list[Path]) -> str | None:
    """Si el último segmento parece un typo, sugiere carpeta hermana bajo el mismo padre."""
    parent = resolved.parent
    name = resolved.name
    if not name or not _within_roots(parent, roots) or not parent.is_dir():
        return None
    try:
        siblings = [entry.name for entry in parent.iterdir() if entry.is_dir()]
    except OSError:
        return None
    matches = difflib.get_close_matches(name, siblings, n=1, cutoff=0.72)
    if not matches:
        return None
    return str(parent / matches[0])


def normalize_workspace_path(path_str: str | None) -> str:
    """Valida y devuelve ruta absoluta, o cadena vacía si se borra.

    Comprueba WORKSPACE_ROOTS antes de tocar el disco: una ruta fuera de las raíces
    no revela si existe ni qué carpetas hay a su lado.
    """
    if path_str is None:
        return ""
    cleaned = path_str.strip()
    if not cleaned:
        return ""
    roots = workspace_roots()
    if not roots:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "WORKSPACE_ROOTS no está configurado en el API",
        )
    # Normalización de texto (sin tocar el disco) y comprobación de raíces; después resolve()
    # sigue enlaces simbólicos y se vuelve a comprobar que el destino real sigue dentro.
    candidate = os.path.normpath(os.path.abspath(os.path.expanduser(cleaned)))
    for root in roots:
        prefix = str(root)
        if not candidate.startswith(prefix):
            continue
        if candidate != prefix and not candidate.startswith(prefix + os.sep):
            continue
        return _existing_dir_within_roots(candidate, roots)
    allowed = ", ".join(str(r) for r in roots)
    raise HTTPException(
        status.HTTP_400_BAD_REQUEST,
        f"Ruta fuera de WORKSPACE_ROOTS permitidas ({allowed})",
    )


def _existing_dir_within_roots(candidate: str, roots: list[Path]) -> str:
    """candidate ya está normalizada y dentro de una raíz; resolve() sigue enlaces simbólicos."""
    try:
        resolved = Path(candidate).resolve()
    except (OSError, RuntimeError) as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Ruta inválida") from e
    if not _within_roots(resolved, roots):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "La ruta apunta (enlace simbólico) fuera de WORKSPACE_ROOTS",
        )
    if not resolved.exists():
        hint = _similar_path_hint(resolved, roots)
        detail = "La ruta no existe en el servidor"
        if hint:
            detail += f". ¿Quisiste decir «{hint}»?"
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail)
    if not resolved.is_dir():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "La ruta debe ser un directorio")
    return str(resolved)


async def _run(cmd: list[str], *, cwd: Path, timeout: float = 20.0) -> tuple[int, str, str]:
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        cwd=str(cwd),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout_b, stderr_b = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        return -1, "", "timeout"
    return (
        proc.returncode or 0,
        (stdout_b or b"").decode(errors="replace").strip(),
        (stderr_b or b"").decode(errors="replace").strip(),
    )


def _find_compose_file(path: Path) -> Path | None:
    for name in _COMPOSE_NAMES:
        candidate = path / name
        if candidate.is_file():
            return candidate
    return None


def _git_cmd(*args: str) -> list[str]:
    """Git en repos montados (Samba/Docker) suele requerir safe.directory."""
    return ["git", "-c", "safe.directory=*", *args]


async def _git_snapshot(path: Path) -> dict[str, Any] | None:
    code, out, _ = await _run(_git_cmd("rev-parse", "--is-inside-work-tree"), cwd=path)
    if code != 0 or out.lower() != "true":
        return None

    git: dict[str, Any] = {"available": True}
    _, branch, _ = await _run(_git_cmd("branch", "--show-current"), cwd=path)
    git["branch"] = branch or "(detached)"

    code, log_line, _ = await _run(
        _git_cmd("log", "-1", "--format=%H|%s|%ci"),
        cwd=path,
    )
    if code == 0 and log_line and "|" in log_line:
        sha, msg, dt = log_line.split("|", 2)
        git["commit"] = sha[:12]
        git["commit_full"] = sha
        git["commit_message"] = msg.strip()
        git["commit_date"] = dt.strip()

    code, status_out, _ = await _run(_git_cmd("status", "--porcelain"), cwd=path)
    dirty: list[str] = []
    if code == 0 and status_out:
        for line in status_out.splitlines():
            if len(line) > 3:
                dirty.append(line[3:].strip())
    git["dirty_count"] = len(dirty)
    git["dirty_sample"] = dirty[:8]
    return git


async def _docker_snapshot(path: Path) -> dict[str, Any] | None:
    compose = _find_compose_file(path)
    if compose is None:
        return None

    docker: dict[str, Any] = {"compose_file": compose.name, "services": []}
    compose_args = ["-f", compose.name, "ps", "--format", "json"]
    for cmd in (
        ["docker", "compose", *compose_args],
        ["docker-compose", *compose_args],
    ):
        code, out, err = await _run(cmd, cwd=path, timeout=25.0)
        if code == 0:
            break
    else:
        docker["error"] = err or "Estado de Docker no disponible desde el API (sin acceso al socket por seguridad)"
        return docker

    services: list[dict[str, str]] = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        name = row.get("Name") or row.get("Service") or "?"
        state = row.get("State") or row.get("Status") or "?"
        services.append({"name": str(name), "state": str(state)})
    docker["services"] = services
    return docker


async def build_workspace_snapshot(path_str: str) -> dict[str, Any]:
    """Genera snapshot JSON; path_str debe estar ya normalizado o vacío."""
    if not path_str:
        return {
            "path": "",
            "configured": False,
            "summary": "Sin carpeta de workspace vinculada al proyecto.",
            "errors": [],
        }

    path = Path(path_str)
    result: dict[str, Any] = {
        "path": path_str,
        "configured": True,
        "exists": path.is_dir(),
        "git": None,
        "docker": None,
        "errors": [],
    }

    if not path.is_dir():
        result["summary"] = f"La ruta {path_str} no es accesible desde el API."
        return result

    try:
        result["git"] = await _git_snapshot(path)
    except Exception as e:  # noqa: BLE001
        result["errors"].append(f"git: {e!s}")

    try:
        result["docker"] = await _docker_snapshot(path)
    except Exception as e:  # noqa: BLE001
        result["errors"].append(f"docker: {e!s}")

    result["summary"] = format_snapshot_for_ai(result)
    return result


def format_snapshot_for_ai(snapshot: dict[str, Any]) -> str:
    if not snapshot.get("configured"):
        return "Sin carpeta de workspace vinculada."
    if not snapshot.get("exists"):
        return f"Carpeta configurada pero no accesible: {snapshot.get('path', '')}"

    lines = [f"Carpeta workspace: {snapshot.get('path')}"]
    git = snapshot.get("git")
    if git:
        lines.append(
            f"Git: rama «{git.get('branch')}», último commit {git.get('commit')} "
            f"({git.get('commit_date', '?')}): {git.get('commit_message', '')}"
        )
        dirty = git.get("dirty_count", 0)
        if dirty:
            sample = ", ".join(git.get("dirty_sample") or [])
            lines.append(f"Working tree con {dirty} cambio(s) sin commitear. Ej.: {sample}")
        else:
            lines.append("Working tree limpio (sin cambios pendientes de commit).")
    else:
        lines.append("No es un repositorio git (o git no disponible).")

    docker = snapshot.get("docker")
    if docker:
        if docker.get("error"):
            lines.append(f"Docker Compose ({docker.get('compose_file')}): {docker['error']}")
        elif docker.get("services"):
            svc = ", ".join(
                f"{s['name']}={s['state']}" for s in docker["services"][:12]
            )
            lines.append(f"Docker Compose ({docker.get('compose_file')}): {svc}")
        else:
            lines.append(f"Docker Compose presente ({docker.get('compose_file')}) sin servicios en ejecución.")

    for err in snapshot.get("errors") or []:
        lines.append(f"Aviso: {err}")
    return "\n".join(lines)
