#!/usr/bin/env python3
"""Servidor MCP TaskBoard — CRUD y workspace vía API REST (Cursor / agentes)."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import Any

from mcp.server.fastmcp import FastMCP

from taskboard_client import TaskboardApiError, TaskboardClient

mcp = FastMCP(
    "taskboard",
    instructions=(
        "Herramientas para leer y escribir proyectos/tareas en TaskBoard (kanban.jualas.es). "
        "Usa resolve_project_by_path cuando trabajes en una carpeta local vinculada. "
        "Estados de tarea válidos: pending, in_progress, completed. "
        "Estados de proyecto: planning, development, completed, archived. "
        "Complejidad: simple, medium, complex."
    ),
)

TASK_STATUSES = ("pending", "in_progress", "completed")
PROJECT_STATUSES = ("planning", "development", "completed", "archived")

_client: TaskboardClient | None = None


def _client_instance() -> TaskboardClient:
    global _client
    if _client is None:
        env_file = os.environ.get("TASKBOARD_ENV_FILE")
        _client = TaskboardClient.from_env(env_file)
    return _client


def _json(data: Any) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2)


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _api(method: str, path: str, **kwargs: Any) -> str:
    try:
        return _json(_client_instance().request_json(method, path, **kwargs))
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


def _due_date_value(due_date: str) -> str | None:
    """'' → sin fecha; 'YYYY-MM-DD' → medianoche UTC; ISO completo se pasa tal cual."""
    value = due_date.strip()
    if not value:
        return None
    if len(value) == 10:
        return f"{value}T00:00:00Z"
    return value


def _subtasks_from_titles(titles: list[str]) -> list[dict[str, Any]]:
    return [{"id": 0, "title": t.strip(), "isDone": False} for t in titles if t.strip()]


def _put_task(client: TaskboardClient, current: dict[str, Any], changes: dict[str, Any]) -> str:
    body = {**current, **changes, "updated_at": _utc_now_iso()}
    return _json(client.request_json("PUT", "/api/tasks", body=body))


@mcp.tool()
def list_projects() -> str:
    """Lista proyectos visibles para el usuario autenticado."""
    try:
        data = _client_instance().request_json("GET", "/api/projects")
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def get_project(project_id: int) -> str:
    """Detalle de un proyecto por id."""
    try:
        data = _client_instance().request_json("GET", f"/api/projects/{project_id}")
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def resolve_project_by_path(workspace_path: str) -> str:
    """Encuentra el proyecto TaskBoard vinculado a una carpeta local (workspace_path)."""
    try:
        data = _client_instance().request_json(
            "GET",
            "/api/projects/by-workspace-path",
            query={"path": workspace_path},
        )
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def list_tasks(project_id: int) -> str:
    """Lista tareas de un proyecto."""
    try:
        data = _client_instance().request_json("GET", f"/api/tasks/by-project/{project_id}")
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def create_task(
    project_id: int,
    title: str,
    description: str = "",
    status: str = "pending",
    complexity: str = "medium",
    tags: list[str] | None = None,
    due_date: str = "",
    estimated_hours: int | None = None,
    subtasks: list[str] | None = None,
) -> str:
    """Crea una tarea nueva en el proyecto (obtiene id automáticamente).

    due_date: 'YYYY-MM-DD' o ISO 8601 ('' = sin fecha). subtasks: lista de títulos del checklist.
    """
    if status not in TASK_STATUSES:
        return _json({"error": f"status inválido: {status}"})
    client = _client_instance()
    try:
        next_id = client.request_json("GET", "/api/meta/next-task-id")
        now = _utc_now_iso()
        body = {
            "id": int(next_id),
            "project_id": project_id,
            "title": title.strip(),
            "description": description,
            "status": status,
            "due_date": _due_date_value(due_date),
            "kanban_position": 999.0,
            "estimated_hours": estimated_hours,
            "complexity": complexity,
            "tags": tags or [],
            "subtasks": _subtasks_from_titles(subtasks or []),
            "created_at": now,
            "updated_at": now,
        }
        created = client.request_json("PUT", "/api/tasks", body=body)
        return _json(created)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def update_task_status(task_id: int, project_id: int, status: str) -> str:
    """Actualiza el estado kanban de una tarea existente."""
    if status not in TASK_STATUSES:
        return _json({"error": f"status inválido: {status}"})
    client = _client_instance()
    try:
        current = client.request_json("GET", f"/api/tasks/{task_id}")
        if int(current["project_id"]) != project_id:
            return _json({"error": "La tarea no pertenece al project_id indicado"})
        return _put_task(client, current, {"status": status})
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def get_task(task_id: int) -> str:
    """Detalle de una tarea (incluye checklist de subtareas)."""
    return _api("GET", f"/api/tasks/{task_id}")


@mcp.tool()
def update_task(
    task_id: int,
    project_id: int,
    title: str | None = None,
    description: str | None = None,
    status: str | None = None,
    complexity: str | None = None,
    tags: list[str] | None = None,
    due_date: str | None = None,
    estimated_hours: int | None = None,
    kanban_position: float | None = None,
) -> str:
    """Modifica campos de una tarea; solo cambia los parámetros indicados.

    due_date: 'YYYY-MM-DD', ISO 8601 o '' para quitar la fecha. tags reemplaza la lista completa.
    """
    if status is not None and status not in TASK_STATUSES:
        return _json({"error": f"status inválido: {status}"})
    candidates = {
        "title": title.strip() if title is not None else None,
        "description": description,
        "status": status,
        "complexity": complexity,
        "tags": tags,
        "estimated_hours": estimated_hours,
        "kanban_position": kanban_position,
    }
    changes: dict[str, Any] = {k: v for k, v in candidates.items() if v is not None}
    if due_date is not None:
        changes["due_date"] = _due_date_value(due_date)
    if not changes:
        return _json({"error": "No se indicó ningún campo a cambiar"})
    client = _client_instance()
    try:
        current = client.request_json("GET", f"/api/tasks/{task_id}")
        if int(current["project_id"]) != project_id:
            return _json({"error": "La tarea no pertenece al project_id indicado"})
        return _put_task(client, current, changes)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def add_subtasks(task_id: int, project_id: int, titles: list[str]) -> str:
    """Añade elementos al checklist de una tarea (al final, sin marcar)."""
    new_items = _subtasks_from_titles(titles)
    if not new_items:
        return _json({"error": "Lista de subtareas vacía"})
    client = _client_instance()
    try:
        current = client.request_json("GET", f"/api/tasks/{task_id}")
        if int(current["project_id"]) != project_id:
            return _json({"error": "La tarea no pertenece al project_id indicado"})
        return _put_task(client, current, {"subtasks": [*current.get("subtasks", []), *new_items]})
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def set_subtask_done(task_id: int, project_id: int, index: int, done: bool = True) -> str:
    """Marca o desmarca una subtarea por su posición (0-based) en el checklist."""
    client = _client_instance()
    try:
        current = client.request_json("GET", f"/api/tasks/{task_id}")
        if int(current["project_id"]) != project_id:
            return _json({"error": "La tarea no pertenece al project_id indicado"})
        subtasks = [dict(s) for s in current.get("subtasks", [])]
        if not 0 <= index < len(subtasks):
            return _json({"error": f"index fuera de rango (hay {len(subtasks)} subtareas)"})
        subtasks[index].update({"isDone": done, "is_done": done})
        return _put_task(client, current, {"subtasks": subtasks})
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def delete_task(task_id: int, project_id: int, confirm: bool = False) -> str:
    """Borra una tarea de forma irreversible. Requiere confirm=true tras confirmarlo con el usuario."""
    client = _client_instance()
    try:
        current = client.request_json("GET", f"/api/tasks/{task_id}")
        if int(current["project_id"]) != project_id:
            return _json({"error": "La tarea no pertenece al project_id indicado"})
        if not confirm:
            return _json({
                "error": "Borrado no confirmado: repite con confirm=true tras confirmarlo con el usuario",
                "task": {"id": current["id"], "title": current["title"], "status": current["status"]},
            })
        client.request_json("DELETE", f"/api/tasks/{task_id}")
        return _json({"deleted": task_id, "title": current["title"]})
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def create_project(title: str, description: str = "", status: str = "planning") -> str:
    """Crea un proyecto nuevo (el usuario autenticado queda como owner)."""
    if status not in PROJECT_STATUSES:
        return _json({"error": f"status de proyecto inválido: {status}"})
    if not title.strip():
        return _json({"error": "El título es obligatorio"})
    return _api(
        "POST",
        "/api/projects",
        body={"title": title.strip(), "description": description, "status": status},
    )


@mcp.tool()
def update_project(
    project_id: int,
    title: str | None = None,
    description: str | None = None,
    status: str | None = None,
) -> str:
    """Modifica título, descripción o estado de un proyecto (solo los parámetros indicados)."""
    if status is not None and status not in PROJECT_STATUSES:
        return _json({"error": f"status de proyecto inválido: {status}"})
    body = {
        k: v
        for k, v in {"title": title, "description": description, "status": status}.items()
        if v is not None
    }
    if not body:
        return _json({"error": "No se indicó ningún campo a cambiar"})
    return _api("PATCH", f"/api/projects/{project_id}", body=body)


@mcp.tool()
def board_summary(project_id: int | None = None) -> str:
    """Resumen del tablero: tareas por estado, vencidas y en curso, de un proyecto o de todos."""
    client = _client_instance()
    try:
        projects = client.request_json("GET", "/api/projects")
        if project_id is not None:
            projects = [p for p in projects if int(p["id"]) == project_id]
            if not projects:
                return _json({"error": f"Proyecto {project_id} no encontrado o sin acceso"})
        now = datetime.now(timezone.utc)
        summary = []
        for p in projects:
            tasks = client.request_json("GET", f"/api/tasks/by-project/{p['id']}")
            counts = {s: 0 for s in TASK_STATUSES}
            overdue, in_progress = [], []
            for t in tasks:
                counts[t["status"]] = counts.get(t["status"], 0) + 1
                if t["status"] == "in_progress":
                    in_progress.append({"id": t["id"], "title": t["title"]})
                due = t.get("due_date")
                if due and t["status"] != "completed":
                    due_dt = datetime.fromisoformat(due.replace("Z", "+00:00"))
                    if due_dt.tzinfo is None:
                        due_dt = due_dt.replace(tzinfo=timezone.utc)
                    if due_dt < now:
                        overdue.append({"id": t["id"], "title": t["title"], "due_date": due})
            summary.append({
                "project_id": p["id"],
                "title": p["title"],
                "status": p["status"],
                "task_counts": counts,
                "total": len(tasks),
                "in_progress": in_progress,
                "overdue": overdue,
                "pending_workspace_suggestions": p.get("pending_workspace_suggestions", 0),
            })
        return _json(summary)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def get_ide_development_prompt(project_id: int, focus_task_id: int | None = None) -> str:
    """Plantilla de prompt para Cursor IDE (backlog + instrucciones). Exporta TASKBOARD.md con prepare_ide_session."""
    query: dict[str, str] = {}
    if focus_task_id is not None:
        query["focus_task_id"] = str(focus_task_id)
    try:
        data = _client_instance().request_json(
            "GET",
            f"/api/projects/{project_id}/ide-prompt",
            query=query or None,
        )
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def prepare_ide_session(project_id: int, focus_task_id: int | None = None) -> str:
    """Exporta TASKBOARD.md al workspace y devuelve prompt listo para pegar en Cursor."""
    query: dict[str, str] = {}
    if focus_task_id is not None:
        query["focus_task_id"] = str(focus_task_id)
    try:
        data = _client_instance().request_json(
            "POST",
            f"/api/projects/{project_id}/ide-session",
            body={},
            query=query or None,
        )
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def export_taskboard_md(project_id: int, filename: str = "", dry_run: bool = False) -> str:
    """Escribe TASKBOARD.md (tareas + estados) en la carpeta workspace del proyecto."""
    body: dict[str, Any] = {"dryRun": dry_run}
    if filename.strip():
        body["filename"] = filename.strip()
    try:
        data = _client_instance().request_json(
            "POST",
            f"/api/projects/{project_id}/taskboard-md",
            body=body,
        )
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def get_workspace_snapshot(project_id: int) -> str:
    """Snapshot git/docker del workspace vinculado al proyecto."""
    try:
        data = _client_instance().request_json("GET", f"/api/projects/{project_id}/workspace-snapshot")
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def list_workspace_suggestions(project_id: int, state: str = "pending") -> str:
    """Sugerencias automáticas del workspace (Fase 2)."""
    try:
        data = _client_instance().request_json(
            "GET",
            f"/api/projects/{project_id}/workspace-suggestions",
            query={"state": state},
        )
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def list_workspace_inventory() -> str:
    """Inventario de carpetas en WORKSPACE_ROOTS y su vínculo con proyectos (Fase 4)."""
    try:
        data = _client_instance().request_json("GET", "/api/projects/workspace-inventory")
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def sync_workspace(project_id: int) -> str:
    """Fuerza sincronización workspace → snapshots/sugerencias."""
    try:
        data = _client_instance().request_json("POST", f"/api/projects/{project_id}/workspace-sync")
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def apply_workspace_suggestion(project_id: int, suggestion_id: int) -> str:
    """Aplica una sugerencia (crear tarea o cambiar estado del proyecto)."""
    try:
        data = _client_instance().request_json(
            "POST",
            f"/api/projects/{project_id}/workspace-suggestions/{suggestion_id}/apply",
        )
        return _json(data)
    except TaskboardApiError as e:
        return _json({"error": e.detail, "status": e.status})


@mcp.tool()
def dismiss_workspace_suggestion(project_id: int, suggestion_id: int) -> str:
    """Descarta una sugerencia automática del workspace."""
    return _api("POST", f"/api/projects/{project_id}/workspace-suggestions/{suggestion_id}/dismiss")


if __name__ == "__main__":
    mcp.run()
