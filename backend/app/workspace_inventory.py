"""Inventario de carpetas bajo WORKSPACE_ROOTS (Fase 4)."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .workspace import _find_compose_file, workspace_roots

_SKIP_DIR_NAMES = frozenset(
    {
        ".git",
        "node_modules",
        "__pycache__",
        ".venv",
        "venv",
        "volumes",
        "lost+found",
        ".next",
        "dist",
        "build",
    }
)


def _root_label(root: Path) -> str:
    name = root.name.lower()
    if "docker" in name:
        return "docker"
    if "proyecto" in name:
        return "Proyectos"
    return root.name


def scan_workspace_inventory() -> list[dict[str, Any]]:
    """Lista subcarpetas inmediatas de cada raíz configurada."""
    entries: list[dict[str, Any]] = []
    seen_paths: set[str] = set()

    for root in workspace_roots():
        if not root.is_dir():
            continue
        label = _root_label(root)
        try:
            children = sorted(root.iterdir(), key=lambda p: p.name.lower())
        except OSError:
            continue
        for child in children:
            if not child.is_dir():
                continue
            name = child.name
            if name.startswith(".") or name in _SKIP_DIR_NAMES:
                continue
            try:
                resolved = str(child.resolve())
            except OSError:
                continue
            if resolved in seen_paths:
                continue
            seen_paths.add(resolved)
            entries.append(
                {
                    "path": resolved,
                    "name": name,
                    "root": label,
                    "root_path": str(root),
                    "has_git": (child / ".git").exists(),
                    "has_docker_compose": _find_compose_file(child) is not None,
                }
            )

    entries.sort(key=lambda e: (e["root"], e["name"].lower()))
    return _dedupe_equivalent_roots(entries)


def _dedupe_equivalent_roots(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Evita duplicados cuando WORKSPACE_ROOTS monta la misma árbol con otra ruta."""
    best: dict[tuple[str, str], dict[str, Any]] = {}
    for entry in entries:
        key = (entry["root"], entry["name"].lower())
        current = best.get(key)
        if current is None:
            best[key] = entry
            continue
        if _prefer_inventory_path(entry["path"], current["path"]):
            best[key] = entry
    out = list(best.values())
    out.sort(key=lambda e: (e["root"], e["name"].lower()))
    return out


def _prefer_inventory_path(a: str, b: str) -> bool:
    """Prefiere /mnt/datos/ frente a rutas home equivalentes."""
    a_mnt = a.startswith("/mnt/datos/")
    b_mnt = b.startswith("/mnt/datos/")
    if a_mnt != b_mnt:
        return a_mnt
    return len(a) < len(b)
