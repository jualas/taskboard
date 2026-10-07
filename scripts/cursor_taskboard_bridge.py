#!/usr/bin/env python3
"""
Puente local TaskBoard ↔ Cursor Agent CLI (`agent`).

Carga contexto del proyecto vía API y opcionalmente ejecuta el agente Cursor
en la carpeta workspace con `agent --print --trust`.

Uso:
  python scripts/cursor_taskboard_bridge.py --path /mnt/datos/docker/oposiciones
  python scripts/cursor_taskboard_bridge.py --project-id 1
  python scripts/cursor_taskboard_bridge.py --path ... --agent "Resume el backlog pendiente"
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "mcp-taskboard"))

from app.cursor_agent import run_cursor_agent  # noqa: E402
from taskboard_client import TaskboardApiError, TaskboardClient  # noqa: E402


def _load_context(client: TaskboardClient, project_id: int) -> dict:
    project = client.request_json("GET", f"/api/projects/{project_id}")
    tasks = client.request_json("GET", f"/api/tasks/by-project/{project_id}")
    snapshot = None
    suggestions = []
    if (project.get("workspace_path") or "").strip():
        try:
            snapshot = client.request_json("GET", f"/api/projects/{project_id}/workspace-snapshot")
        except TaskboardApiError:
            pass
        try:
            suggestions = client.request_json(
                "GET",
                f"/api/projects/{project_id}/workspace-suggestions",
                query={"state": "pending"},
            )
        except TaskboardApiError:
            pass
    return {
        "project": project,
        "tasks": tasks,
        "workspace_snapshot": snapshot,
        "pending_suggestions": suggestions,
    }


def _format_context(ctx: dict) -> str:
    p = ctx["project"]
    lines = [
        f"# Proyecto TaskBoard: {p.get('title')} (id={p.get('id')})",
        f"Estado: {p.get('status')}",
        f"Workspace: {p.get('workspace_path') or '(sin vincular)'}",
        "",
        "## Tareas",
    ]
    for t in ctx.get("tasks") or []:
        lines.append(f"- [{t.get('status')}] #{t.get('id')} {t.get('title')}")
    snap = ctx.get("workspace_snapshot") or {}
    summary = snap.get("summary")
    if summary:
        lines.extend(["", "## Workspace (git/docker)", summary])
    sugs = ctx.get("pending_suggestions") or []
    if sugs:
        lines.extend(["", "## Sugerencias pendientes"])
        for s in sugs:
            lines.append(f"- [{s.get('suggestion_type')}] {s.get('title')}: {s.get('body')}")
    return "\n".join(lines)


def _run_agent_cli(cwd: Path, prompt: str) -> int:
    """Ejecuta el CLI `agent` (Cursor Agent) en el workspace."""
    mode = os.environ.get("CURSOR_AGENT_MODE", "ask").strip() or "ask"
    try:
        result = asyncio.run(
            run_cursor_agent(
                prompt,
                workspace=cwd,
                mode=mode,
            )
        )
    except FileNotFoundError:
        bin_path = os.environ.get("CURSOR_AGENT_BIN", "agent")
        print(
            f"No se encontró «{bin_path}». Instala Cursor Agent CLI o define CURSOR_AGENT_BIN.",
            file=sys.stderr,
        )
        return 127
    except Exception as e:
        print(f"Cursor agent falló: {e}", file=sys.stderr)
        return 1

    print(result)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Puente TaskBoard ↔ Cursor Agent CLI")
    parser.add_argument("--path", help="Carpeta workspace local")
    parser.add_argument("--project-id", type=int, help="ID de proyecto TaskBoard")
    parser.add_argument("--env-file", help="Ruta .env con API_BASE_URL y credenciales")
    parser.add_argument("--json", action="store_true", help="Salida JSON en lugar de texto")
    parser.add_argument(
        "--agent",
        metavar="PROMPT",
        help="Ejecutar Cursor Agent CLI (`agent --print`) en el workspace",
    )
    args = parser.parse_args()

    client = TaskboardClient.from_env(args.env_file)
    project_id = args.project_id
    workspace = (args.path or "").strip()

    if project_id is None:
        if not workspace:
            print("Indica --project-id o --path", file=sys.stderr)
            return 1
        project = client.request_json(
            "GET",
            "/api/projects/by-workspace-path",
            query={"path": workspace},
        )
        project_id = int(project["id"])
    else:
        project = client.request_json("GET", f"/api/projects/{project_id}")
        if not workspace:
            workspace = (project.get("workspace_path") or "").strip()

    ctx = _load_context(client, project_id)
    if args.json:
        print(json.dumps(ctx, ensure_ascii=False, indent=2))
    else:
        print(_format_context(ctx))

    if args.agent:
        if not workspace:
            print("No hay workspace_path para ejecutar el agente local", file=sys.stderr)
            return 1
        cwd = Path(workspace)
        if not cwd.is_dir():
            print(f"Carpeta workspace no accesible: {workspace}", file=sys.stderr)
            return 1
        full_prompt = (
            f"{args.agent}\n\n--- Contexto TaskBoard ---\n{_format_context(ctx)}"
        )
        return _run_agent_cli(cwd, full_prompt)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
