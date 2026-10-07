"""Plantilla de prompt para sesiones de desarrollo en Cursor IDE / CLI."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from fastapi import HTTPException, status

from .config import settings
from .taskboard_md import taskboard_md_filename
from .workspace import normalize_workspace_path

_DEFAULT_STATUS_CANDIDATES = ("docs/STATUS.md", "STATUS.md", "docs/status.md")


def _status_md_candidates() -> list[str]:
    raw = (getattr(settings, "taskboard_status_md_paths", None) or "").strip()
    if raw:
        return [p.strip() for p in raw.split(",") if p.strip()]
    return list(_DEFAULT_STATUS_CANDIDATES)


def _resolve_status_refs(workspace: Path) -> list[str]:
    found: list[str] = []
    for rel in _status_md_candidates():
        if (workspace / rel).is_file():
            found.append(rel.replace("\\", "/"))
    return found


def _task_line(task: dict[str, Any]) -> str:
    tid = int(task.get("id") or 0)
    title = str(task.get("title") or "(sin título)").strip()
    return f"- **[#{tid}]** {title}"


def _pick_focus_task(
    tasks: list[dict[str, Any]],
    focus_task_id: int | None,
) -> dict[str, Any] | None:
    if focus_task_id is not None:
        for t in tasks:
            if int(t.get("id") or 0) == focus_task_id:
                return t
        return None
    for st in ("in_progress", "pending"):
        group = [t for t in tasks if str(t.get("status") or "") == st]
        if group:
            group.sort(key=lambda x: float(x.get("kanban_position") or 0))
            return group[0]
    return None


def build_ide_development_prompt(
    *,
    project: dict[str, Any],
    tasks: list[dict[str, Any]],
    workspace_path: str,
    focus_task_id: int | None = None,
    export_first: bool = True,
) -> dict[str, Any]:
    """Genera prompt genérico rellenado con datos del proyecto."""
    ws = Path(workspace_path)
    md_name = taskboard_md_filename(None)
    status_refs = _resolve_status_refs(ws)

    by_status: dict[str, list[dict[str, Any]]] = {
        "in_progress": [],
        "pending": [],
        "completed": [],
    }
    for t in tasks:
        st = str(t.get("status") or "pending")
        by_status.setdefault(st, []).append(t)
    for st in by_status:
        by_status[st].sort(key=lambda x: float(x.get("kanban_position") or 0))

    focus = _pick_focus_task(tasks, focus_task_id)
    pid = int(project.get("id") or 0)
    title = str(project.get("title") or "(sin título)").strip()
    pstatus = str(project.get("status") or "planning")

    file_refs = [f"@{md_name}"]
    file_refs.extend(f"@{ref}" for ref in status_refs)
    if not status_refs:
        file_refs.append("@docs/STATUS.md _(crear o indicar ruta si no existe)_")

    in_prog = by_status.get("in_progress") or []
    pending = by_status.get("pending") or []
    completed = by_status.get("completed") or []

    focus_block = ""
    if focus:
        fid = int(focus.get("id") or 0)
        ft = str(focus.get("title") or "").strip()
        fst = str(focus.get("status") or "pending")
        focus_block = (
            f"\n## Tarea foco\n\n"
            f"Trabaja primero en **[#{fid}]** {ft} (`{fst}`).\n"
        )

    in_prog_block = "\n".join(_task_line(t) for t in in_prog[:8]) or "- _(ninguna)_"
    pending_block = "\n".join(_task_line(t) for t in pending[:6]) or "- _(ninguna)_"

    export_note = ""
    if export_first:
        export_note = (
            f"\n> **Antes de pegar este prompt:** exporta `{md_name}` desde TaskBoard "
            f"(botón *Exportar TASKBOARD.md* o `POST /api/projects/{pid}/taskboard-md`) "
            f"para que el archivo refleje el tablero actual.\n"
        )

    prompt = f"""# Sesión de desarrollo — {title}

{export_note}
## Archivos de contexto (léelos primero)

{chr(10).join(f"- {ref}" for ref in file_refs)}

## Proyecto

- **Nombre:** {title}
- **ID TaskBoard:** `{pid}`
- **Estado del proyecto:** `{pstatus}`
- **Workspace:** `{workspace_path}`

## Backlog resumido

### En progreso ({len(in_prog)})
{in_prog_block}

### Pendientes destacadas ({len(pending)} total)
{pending_block}

### Completadas ({len(completed)} total)
_(ver `{md_name}` para detalle)_
{focus_block}
## Objetivo

Continuar el desarrollo alineando **código**, **`{md_name}`** y **estado real del repo** ({", ".join(status_refs) if status_refs else "docs/STATUS.md"}).

## Instrucciones para el agente

1. Lee los archivos de contexto y detecta divergencias repo ↔ tablero.
2. Prioriza tareas `in_progress`; si no hay, elige la pendiente más crítica según STATUS y dependencias técnicas.
3. Implementa cambios en el repo (código, tests, docs). Puedes editar archivos.
4. Actualiza `{status_refs[0] if status_refs else "docs/STATUS.md"}` si cambia el estado real del proyecto.
5. Si dispones de MCP **taskboard**: sincroniza estados (`update_task_status`) al cerrar ítems.
6. Al terminar, resume: **hecho**, **pendiente**, **bloqueos** y tareas TaskBoard a actualizar.

## Criterios de éxito

- Código coherente con la arquitectura descrita en STATUS.
- Tarea foco avanzada con entregable verificable (test, endpoint, UI, doc).
- Sin dejar el repo en estado inconsistente (migraciones, env, build).
"""

    return {
        "project_id": pid,
        "project_title": title,
        "workspace_path": workspace_path,
        "taskboard_md": md_name,
        "status_md_paths": status_refs,
        "file_references": file_refs,
        "focus_task_id": int(focus["id"]) if focus else None,
        "focus_task_title": str(focus.get("title") or "") if focus else None,
        "prompt": prompt.strip() + "\n",
        "task_counts": {
            "in_progress": len(in_prog),
            "pending": len(pending),
            "completed": len(completed),
            "total": len(tasks),
        },
    }


async def build_ide_prompt_for_project(
    conn,
    *,
    project_id: int,
    focus_task_id: int | None = None,
    export_first: bool = True,
) -> dict[str, Any]:
    project_row = await conn.fetchrow(
        "select id, title, description, status, workspace_path from projects where id = $1",
        project_id,
    )
    if project_row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Proyecto no encontrado")

    project = dict(project_row)
    ws_raw = (project.get("workspace_path") or "").strip()
    if not ws_raw:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "El proyecto no tiene carpeta workspace vinculada.",
        )
    workspace_path = normalize_workspace_path(ws_raw)

    task_rows = await conn.fetch(
        """
        select id, project_id, title, description, status, kanban_position,
               complexity, tags, subtasks, updated_at
        from tasks where project_id = $1
        order by kanban_position, id
        """,
        project_id,
    )
    tasks = [dict(r) for r in task_rows]

    return build_ide_development_prompt(
        project={**project, "workspace_path": workspace_path},
        tasks=tasks,
        workspace_path=workspace_path,
        focus_task_id=focus_task_id,
        export_first=export_first,
    )
