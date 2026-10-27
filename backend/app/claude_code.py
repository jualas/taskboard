"""Invocación headless de Claude Code (`claude -p`) sobre el repo vinculado a un proyecto.

Dos modos:
- seguimiento (execute=False): lee el repo y git, y alinea el tablero con el MCP de TaskBoard.
- desarrollo (execute=True): además edita ficheros y hace commits locales; nunca push.

Los permisos se fijan con una lista cerrada (`--permission-mode dontAsk`): lo que no está
en la lista se deniega sin preguntar. El proceso recibe un entorno mínimo, sin los secretos
del API (JWT_SECRET, DATABASE_URL, DEEPSEEK_API_KEY…).
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import sys
import tempfile
from collections.abc import AsyncIterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

from .config import settings

logger = logging.getLogger(__name__)

# Comandos de solo lectura que el agente puede lanzar en ambos modos.
_READ_ONLY_BASH = (
    "git status",
    "git log",
    "git diff",
    "git show",
    "git branch",
    "git rev-parse",
    "git ls-files",
    "git remote -v",
    "ls",
    "wc",
)
# Además, en modo desarrollo: commits locales, tests y linters.
_DEVELOP_BASH = (
    "git add",
    "git commit",
    "git switch",
    "git checkout -b",
    "git restore",
    "git stash",
    "pytest",
    "python -m pytest",
    "ruff",
    "npm test",
    "npm run lint",
    "npm run test",
    "pnpm test",
    "pnpm lint",
    "flutter test",
    "flutter analyze",
    "dart format",
)
# Nada que publique, borre historia o salga de la máquina, aunque una regla de arriba lo cubra.
_DENIED = (
    "Bash(git push:*)",
    "Bash(git reset --hard:*)",
    "Bash(git clean:*)",
    "Bash(git config:*)",
    "Bash(curl:*)",
    "Bash(wget:*)",
    "WebFetch",
    "WebSearch",
    "mcp__taskboard__delete_task",
    "mcp__taskboard__create_project",
    "mcp__taskboard__update_project",
)

FOLLOW_UP_PROMPT = """Trabajas desde TaskBoard sobre el repositorio de un proyecto (directorio actual).
Proyecto TaskBoard id={project_id}. Usa solo ese proyecto en las herramientas mcp__taskboard__*.
Modo SEGUIMIENTO: no edites ficheros. Ejecuta un comando por llamada a Bash (solo git de lectura). Revisa git (log, ramas, diff) y el código para responder,
y si te piden alinear el tablero, crea o actualiza tareas y subtareas con mcp__taskboard__*.
Una tarea pasa a completed solo si su trabajo está fusionado en la rama principal.
Termina con un resumen breve de lo que has visto y de los cambios hechos en el tablero."""

DEVELOP_PROMPT = """Trabajas desde TaskBoard sobre el repositorio de un proyecto (directorio actual).
Proyecto TaskBoard id={project_id}. Usa solo ese proyecto en las herramientas mcp__taskboard__*.
Modo DESARROLLO: puedes editar ficheros, ejecutar tests y linters y hacer commits locales.
Trabaja en una rama nueva si estás en la principal. Nunca hagas push: lo revisa una persona.
Crea y edita ficheros con Edit y Write, no con la shell. Ejecuta un comando por llamada a Bash,
sin encadenar con && o ; y sin redirecciones: solo están permitidos git, tests y linters.
Sigue las instrucciones del repo (AGENTS.md, CLAUDE.md) y deja el tablero al día con mcp__taskboard__*.
Termina con un resumen: rama, commits, tests ejecutados y tareas actualizadas."""


def build_allowed_tools(*, execute: bool, with_mcp: bool) -> list[str]:
    commands = _READ_ONLY_BASH + (_DEVELOP_BASH if execute else ())
    # Rutas relativas al directorio actual (el workspace): nada de leer o escribir fuera del repo.
    tools = ["Read(./**)", "Grep(./**)", "Glob(./**)"] + [f"Bash({c}:*)" for c in commands]
    if execute:
        tools += ["Edit(./**)", "Write(./**)"]
    if with_mcp:
        tools.append("mcp__taskboard")
    return tools


def build_claude_cmd(
    prompt: str,
    *,
    execute: bool,
    system_prompt: str,
    mcp_config: str | None = None,
    resume_session_id: str | None = None,
) -> list[str]:
    builtin = "Read,Grep,Glob,Bash,Edit,Write" if execute else "Read,Grep,Glob,Bash"
    cmd = [
        (settings.claude_code_bin or "claude").strip() or "claude",
        "-p",
        "--output-format",
        "stream-json",
        "--verbose",
        "--permission-mode",
        "dontAsk",
        "--tools",
        builtin,
        "--allowedTools",
        *build_allowed_tools(execute=execute, with_mcp=mcp_config is not None),
        "--disallowedTools",
        *_DENIED,
        "--append-system-prompt",
        system_prompt,
        "--max-turns",
        str(settings.claude_code_max_turns),
    ]
    if settings.claude_code_max_budget_usd > 0:
        cmd += ["--max-budget-usd", f"{settings.claude_code_max_budget_usd:g}"]
    model = (settings.claude_code_model or "").strip()
    if model:
        cmd += ["--model", model]
    if mcp_config:
        cmd += ["--mcp-config", mcp_config, "--strict-mcp-config"]
    resume = (resume_session_id or "").strip()
    if resume:
        cmd += ["--resume", resume]
    # `--` separa el prompt de las listas de herramientas (opciones variádicas).
    cmd += ["--", prompt]
    return cmd


def agent_env() -> dict[str, str]:
    """Entorno mínimo: sin heredar los secretos del contenedor del API."""
    env = {
        "PATH": os.environ.get("PATH", "/usr/local/bin:/usr/bin:/bin"),
        "HOME": (settings.claude_code_home or "").strip() or os.environ.get("HOME", "/tmp"),
        "LANG": "C.UTF-8",
        "CLAUDE_CODE_OAUTH_TOKEN": settings.claude_code_oauth_token,
        "DISABLE_AUTOUPDATER": "1",
        "DISABLE_TELEMETRY": "1",
        "GIT_AUTHOR_NAME": settings.claude_code_git_name,
        "GIT_AUTHOR_EMAIL": settings.claude_code_git_email,
        "GIT_COMMITTER_NAME": settings.claude_code_git_name,
        "GIT_COMMITTER_EMAIL": settings.claude_code_git_email,
    }
    return env


@contextmanager
def taskboard_mcp_config(api_token: str):
    """Fichero temporal (0600) con el MCP de TaskBoard; se borra al terminar la ejecución."""
    server = Path((settings.claude_code_mcp_server or "").strip())
    if not server.is_file():
        logger.warning("Claude Code: MCP de TaskBoard no encontrado en %s; sin herramientas de tablero", server)
        yield None
        return
    config = {
        "mcpServers": {
            "taskboard": {
                "command": sys.executable,
                "args": [str(server)],
                "env": {
                    "TASKBOARD_API_URL": settings.claude_code_mcp_api_url,
                    "TASKBOARD_API_TOKEN": api_token,
                },
            }
        }
    }
    fd, path = tempfile.mkstemp(prefix="tb-mcp-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(config, f)
        yield path
    finally:
        Path(path).unlink(missing_ok=True)


_TOOL_DETAIL_KEYS = ("command", "file_path", "path", "pattern", "query", "url", "title", "task_id")
_MAX_TOOL_DETAIL = 200


def describe_tool_use(block: dict[str, Any]) -> tuple[str, str]:
    name = str(block.get("name") or "tool")
    args = block.get("input") if isinstance(block.get("input"), dict) else {}
    for key in _TOOL_DETAIL_KEYS:
        detail = " ".join(str(args.get(key) or "").split())
        if detail:
            if len(detail) > _MAX_TOOL_DETAIL:
                detail = detail[:_MAX_TOOL_DETAIL] + "…"
            return name, detail
    return name, ""


def parse_claude_stream_line(line: str) -> list[dict[str, Any]]:
    """Convierte una línea NDJSON de `claude -p --output-format stream-json` en eventos de la UI."""
    line = line.strip()
    if not line:
        return []
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        return [{"kind": "log", "text": line}]
    if not isinstance(obj, dict):
        return []

    kind = obj.get("type")
    if kind == "system" and obj.get("subtype") == "init":
        return [
            {
                "kind": "init",
                "text": f"Claude Code · {obj.get('model') or ''} · {obj.get('cwd') or ''}",
                "session_id": str(obj.get("session_id") or ""),
            }
        ]
    if kind == "assistant":
        msg = obj.get("message") if isinstance(obj.get("message"), dict) else {}
        events: list[dict[str, Any]] = []
        for block in msg.get("content") or []:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "text" and str(block.get("text") or "").strip():
                events.append({"kind": "text", "text": str(block["text"])})
            elif block.get("type") == "tool_use":
                name, detail = describe_tool_use(block)
                text = f"▸ {name}: {detail}" if detail else f"▸ {name}"
                events.append({"kind": "tool", "text": text, "tool": name})
        return events
    if kind == "result":
        is_error = bool(obj.get("is_error")) or obj.get("subtype") not in (None, "success")
        text = str(obj.get("result") or "")
        if not text and is_error:
            text = _result_error_text(obj)
        return [
            {
                "kind": "done",
                "text": text,
                "is_error": is_error,
                "session_id": str(obj.get("session_id") or ""),
                "cost_usd": obj.get("total_cost_usd"),
            }
        ]
    # tool_result (type user), rate_limit_event, system/hooks…: no se muestran.
    return []


def _result_error_text(obj: dict[str, Any]) -> str:
    subtype = str(obj.get("subtype") or "")
    if subtype == "error_max_turns":
        return "Claude Code alcanzó el máximo de pasos. Divide la petición o continúa la sesión."
    if subtype == "error_max_budget_usd":
        return "Claude Code alcanzó el gasto máximo por ejecución."
    return "Claude Code terminó con error (detalle en los logs del API)."


async def stream_claude_code(
    prompt: str,
    *,
    workspace: str | Path,
    execute: bool,
    project_id: int | None,
    api_token: str | None,
    resume_session_id: str | None = None,
    system_prompt: str | None = None,
) -> AsyncIterator[dict[str, Any]]:
    """Ejecuta Claude Code en el workspace y emite eventos simplificados para la UI."""
    ws = Path(workspace)
    if not ws.is_dir():
        raise FileNotFoundError(f"Workspace no accesible: {workspace}")
    if system_prompt is None:
        template = DEVELOP_PROMPT if execute else FOLLOW_UP_PROMPT
        system_prompt = template.format(project_id=project_id if project_id is not None else "(ninguno)")
    timeout = float(settings.claude_code_timeout_sec)

    with taskboard_mcp_config(api_token) if api_token else _no_mcp() as mcp_config:
        cmd = build_claude_cmd(
            prompt,
            execute=execute,
            system_prompt=system_prompt,
            mcp_config=mcp_config,
            resume_session_id=resume_session_id,
        )
        logger.info(
            "Claude Code stream: workspace=%s execute=%s resume=%s mcp=%s",
            ws,
            execute,
            (resume_session_id or "")[:8] or "-",
            bool(mcp_config),
        )
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            cwd=str(ws),
            stdin=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=agent_env(),
            limit=4 * 1024 * 1024,
        )
        assert proc.stdout is not None
        loop = asyncio.get_running_loop()
        deadline = loop.time() + timeout
        try:
            while True:
                remaining = deadline - loop.time()
                if remaining <= 0:
                    raise TimeoutError(f"Claude Code excedió {timeout:.0f}s")
                try:
                    line_b = await asyncio.wait_for(proc.stdout.readline(), timeout=remaining)
                except asyncio.TimeoutError as e:
                    raise TimeoutError(f"Claude Code excedió {timeout:.0f}s") from e
                if not line_b:
                    break
                for event in parse_claude_stream_line(line_b.decode(errors="replace")):
                    yield event
            try:
                await asyncio.wait_for(proc.wait(), timeout=30.0)
            except asyncio.TimeoutError:
                yield {"kind": "error", "text": "Claude Code no terminó a tiempo tras el stream."}
                return
            if proc.returncode != 0:
                err_b = await proc.stderr.read() if proc.stderr is not None else b""
                logger.warning(
                    "Claude Code salió con %s: %s",
                    proc.returncode,
                    (err_b or b"").decode(errors="replace").strip()[:800],
                )
                yield {"kind": "error", "text": "Claude Code falló (detalle en los logs del API)."}
        finally:
            # Cliente desconectado, timeout o error: no dejar el proceso vivo.
            if proc.returncode is None:
                try:
                    proc.kill()
                except ProcessLookupError:
                    pass
                await proc.wait()


@contextmanager
def _no_mcp():
    yield None


def claude_code_ready() -> bool:
    return settings.claude_code_enabled and bool(settings.claude_code_oauth_token.strip())


def resolve_workspace_path(explicit: str | None = None) -> str:
    """Ruta workspace para el agente: explícita → default configurada."""
    path = (explicit or "").strip()
    if path:
        return path
    return (settings.claude_code_default_workspace or "").strip()


ANSWER_ONLY_PROMPT = """Respondes a una petición del asistente de TaskBoard sobre el repositorio del directorio actual.
No edites nada. Puedes leer el repo y git para dar contexto. Sigue el formato de respuesta que pide el mensaje."""


async def run_claude_code(prompt: str, *, workspace: str | Path) -> str:
    """Ejecución de solo lectura y sin MCP; devuelve el texto final (motor «agent» de suggest/chat)."""
    result = ""
    async for event in stream_claude_code(
        prompt,
        workspace=workspace,
        execute=False,
        project_id=None,
        api_token=None,
        system_prompt=ANSWER_ONLY_PROMPT,
    ):
        if event["kind"] == "error":
            raise RuntimeError(event["text"])
        if event["kind"] == "done":
            if event.get("is_error"):
                raise RuntimeError(event["text"])
            result = event["text"]
    return result
