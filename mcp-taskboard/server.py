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
        "Estados de tarea válidos: pending, in_progress, completed."
    ),
)

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
) -> str:
    """Crea una tarea nueva en el proyecto (obtiene id automáticamente)."""
    if status not in ("pending", "in_progress", "completed"):
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
            "due_date": None,
            "kanban_position": 999.0,
            "estimated_hours": None,
            "complexity": complexity,
            "tags": tags or [],
            "subtasks": [],
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
    if status not in ("pending", "in_progress", "completed"):
        return _json({"error": f"status inválido: {status}"})
    client = _client_instance()
    try:
        current = client.request_json("GET", f"/api/tasks/{task_id}")
        if int(current["project_id"]) != project_id:
            return _json({"error": "La tarea no pertenece al project_id indicado"})
        now = _utc_now_iso()
        body = {**current, "status": status, "updated_at": now}
        updated = client.request_json("PUT", "/api/tasks", body=body)
        return _json(updated)
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


if __name__ == "__main__":
    mcp.run()
