"""Generación y escritura de TASKBOARD.md en el workspace del proyecto."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import HTTPException, status

from .config import settings
from .workspace import build_workspace_snapshot, normalize_workspace_path

logger = logging.getLogger(__name__)

_STATUS_ORDER = ("in_progress", "pending", "completed")
_STATUS_HEADINGS = {
    "in_progress": "En progreso",
    "pending": "Pendiente",
    "completed": "Completada",
}
_COMPLEXITY_LABELS = {
    "simple": "simple",
    "medium": "media",
    "complex": "compleja",
    "sencilla": "simple",
    "media": "media",
    "compleja": "compleja",
}


def taskboard_md_filename(custom: str | None = None) -> str:
    name = (custom or settings.taskboard_md_filename or "TASKBOARD.md").strip()
    if not name:
        name = "TASKBOARD.md"
    if "/" in name or "\\" in name or name.startswith("."):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Nombre de archivo inválido")
    if not name.lower().endswith(".md"):
        name += ".md"
    return name


def _fmt_dt(value: Any) -> str:
    if value is None:
        return "—"
    if isinstance(value, datetime):
        dt = value
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    return str(value)


def _status_counts(tasks: list[dict[str, Any]]) -> dict[str, int]:
    counts = {s: 0 for s in _STATUS_ORDER}
    for t in tasks:
        st = str(t.get("status") or "pending")
        counts[st] = counts.get(st, 0) + 1
    return counts


def _render_task(task: dict[str, Any]) -> list[str]:
    tid = int(task.get("id") or 0)
    title = str(task.get("title") or "(sin título)").strip()
    status = str(task.get("status") or "pending")
    complexity = _COMPLEXITY_LABELS.get(
        str(task.get("complexity") or "simple").lower(),
        str(task.get("complexity") or "simple"),
    )
    lines = [
        f'<a id="task-{tid}"></a>',
        f"### [#{tid}] {title}",
        "",
        "| Campo | Valor |",
        "|-------|-------|",
        f"| ID | `{tid}` |",
        f"| Estado | `{status}` |",
        f"| Complejidad | {complexity} |",
    ]
    hours = task.get("estimated_hours")
    if hours is not None:
        lines.append(f"| Horas estimadas | {hours} |")
    pos = task.get("kanban_position")
    if pos is not None:
        lines.append(f"| Posición Kanban | {pos} |")
    lines.append(f"| Actualizado | {_fmt_dt(task.get('updated_at'))} |")
    lines.append("")

    desc = str(task.get("description") or "").strip()
    if desc:
        lines.extend([desc, ""])

    tags = task.get("tags") or []
    if isinstance(tags, list) and tags:
        tag_str = ", ".join(f"`{t}`" for t in tags if str(t).strip())
        if tag_str:
            lines.extend([f"**Etiquetas:** {tag_str}", ""])

    subtasks = task.get("subtasks") or []
    if isinstance(subtasks, list) and subtasks:
        lines.append("**Checklist:**")
        for item in subtasks:
            if not isinstance(item, dict):
                continue
            done = bool(item.get("isDone") or item.get("is_done") or item.get("done"))
            stitle = str(item.get("title") or "").strip()
            if not stitle:
                continue
            mark = "x" if done else " "
            lines.append(f"- [{mark}] {stitle}")
        lines.append("")

    lines.append("---")
    lines.append("")
    return lines


def render_taskboard_md(
    *,
    project: dict[str, Any],
    tasks: list[dict[str, Any]],
    exported_at: datetime | None = None,
    git_commit: str | None = None,
    git_branch: str | None = None,
) -> str:
    """Genera Markdown legible para IDE/CLI con metadatos embebidos."""
    when = exported_at or datetime.now(timezone.utc)
    if when.tzinfo is None:
        when = when.replace(tzinfo=timezone.utc)
    iso = when.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    pid = int(project.get("id") or 0)
    title = str(project.get("title") or "(sin título)").strip()
    desc = str(project.get("description") or "").strip()
    pstatus = str(project.get("status") or "planning")
    workspace = str(project.get("workspace_path") or "").strip()

    counts = _status_counts(tasks)
    by_status: dict[str, list[dict[str, Any]]] = {s: [] for s in _STATUS_ORDER}
    for t in tasks:
        st = str(t.get("status") or "pending")
        by_status.setdefault(st, []).append(t)
    for st in by_status:
        by_status[st].sort(key=lambda x: float(x.get("kanban_position") or 0))

    lines: list[str] = [
        "<!-- taskboard-export: generated file; safe to edit for notes -->",
        f"<!-- taskboard-project-id: {pid} -->",
        f"<!-- taskboard-exported-at: {iso} -->",
        "",
        f"# TaskBoard — {title}",
        "",
        f"**Proyecto:** {title} (`id={pid}`)  ",
        f"**Estado del proyecto:** `{pstatus}`  ",
    ]
    if workspace:
        lines.append(f"**Workspace:** `{workspace}`  ")
    lines.append(f"**Exportado:** {_fmt_dt(when)}  ")
    if git_branch or git_commit:
        short = (git_commit or "")[:8]
        lines.append(f"**Git:** `{git_branch or '?'}` @ `{short or '?'}`  ")
    lines.extend(["", "> Fuente de verdad operativa: TaskBoard. Este archivo es espejo para IDE/CLI.", ""])

    if desc:
        lines.extend(["## Descripción del proyecto", "", desc, ""])

    lines.extend(
        [
            "## Resumen por estado",
            "",
            "| Estado | Tareas |",
            "|--------|--------|",
        ]
    )
    for st in _STATUS_ORDER:
        label = _STATUS_HEADINGS.get(st, st)
        lines.append(f"| {label} (`{st}`) | {counts.get(st, 0)} |")
    other = sum(counts.get(k, 0) for k in counts if k not in _STATUS_ORDER)
    if other:
        lines.append(f"| Otros | {other} |")
    lines.extend(["", "---", ""])

    for st in _STATUS_ORDER:
        group = by_status.get(st) or []
        if not group:
            continue
        heading = _STATUS_HEADINGS.get(st, st)
        lines.extend([f"## {heading} (`{st}`)", ""])
        for task in group:
            lines.extend(_render_task(task))

    lines.extend(
        [
            "## Referencia rápida (agentes / CLI)",
            "",
            "- Estados válidos: `pending`, `in_progress`, `completed`",
            "- Para sincronizar cambios al tablero: MCP `taskboard`, API TaskBoard o modo **Planificar** en la web.",
            f"- Regenerar este archivo: `POST /api/projects/{pid}/taskboard-md` o botón **Exportar TASKBOARD.md**.",
            "",
        ]
    )
    return "\n".join(lines).rstrip() + "\n"


async def build_taskboard_md_for_project(
    conn,
    *,
    project_id: int,
    filename: str | None = None,
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
        select id, project_id, title, description, status, due_date, kanban_position,
               estimated_hours, complexity, tags, subtasks, created_at, updated_at
        from tasks where project_id = $1
        order by kanban_position, id
        """,
        project_id,
    )
    tasks = [dict(r) for r in task_rows]

    git_commit = None
    git_branch = None
    try:
        snap = await build_workspace_snapshot(workspace_path)
        git = snap.get("git") or {}
        git_commit = git.get("commit_full") or git.get("commit")
        git_branch = git.get("branch")
    except Exception:
        pass

    fname = taskboard_md_filename(filename)
    content = render_taskboard_md(
        project={**project, "workspace_path": workspace_path},
        tasks=tasks,
        git_commit=str(git_commit) if git_commit else None,
        git_branch=str(git_branch) if git_branch else None,
    )
    file_path = str(Path(workspace_path) / fname)

    return {
        "project_id": project_id,
        "workspace_path": workspace_path,
        "file_path": file_path,
        "filename": fname,
        "content": content,
        "task_count": len(tasks),
        "git_commit": git_commit,
        "git_branch": git_branch,
    }


def write_taskboard_md_file(*, file_path: str, content: str) -> None:
    path = Path(file_path)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    except OSError as e:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            f"No se pudo escribir {file_path}: {e!s}. "
            "Comprueba que el workspace esté montado con permiso de escritura en taskboard-api.",
        ) from e


async def auto_export_if_enabled(conn, project_id: int) -> None:
    """Regenera TASKBOARD.md tras cambios de tareas si TASKBOARD_MD_AUTO_EXPORT=true."""
    if not settings.taskboard_md_auto_export:
        return
    try:
        data = await build_taskboard_md_for_project(conn, project_id=project_id)
        write_taskboard_md_file(file_path=data["file_path"], content=data["content"])
        logger.info("TASKBOARD.md auto-export project=%s path=%s", project_id, data["file_path"])
    except Exception as e:
        logger.warning("Auto-export TASKBOARD.md falló (project %s): %s", project_id, e)
