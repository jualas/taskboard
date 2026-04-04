import json
from typing import Any

from fastapi import APIRouter, HTTPException, status

from ..deps import CurrentUser, DbConn
from ..permissions import require_edit, require_view
from ..schemas import TaskIn

router = APIRouter(prefix="/api/tasks", tags=["tasks"])


def _as_bool(v: Any) -> bool:
    if isinstance(v, bool):
        return v
    if isinstance(v, (int, float)):
        return bool(v)
    if isinstance(v, str):
        return v.strip().lower() in ("true", "1", "yes", "sí", "si")
    return False


def _jsonb_py(raw: Any) -> Any:
    """asyncpg puede devolver jsonb como str JSON; normaliza a list/dict nativos."""
    if isinstance(raw, str):
        try:
            return json.loads(raw)
        except (json.JSONDecodeError, TypeError):
            return None
    return raw


def _normalize_tags(raw: Any) -> list[str]:
    data = _jsonb_py(raw)
    if isinstance(data, list):
        return [str(x) for x in data]
    return []


def _normalize_subtasks(raw: Any) -> list[dict[str, Any]]:
    """Unifica checklist: siempre id, title, isDone (y is_done espejo) para JSON estable."""
    data = _jsonb_py(raw)
    if not isinstance(data, list):
        return []
    raw = data
    out: list[dict[str, Any]] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        sid = item.get("id", 0)
        try:
            sid = int(sid)
        except (TypeError, ValueError):
            sid = 0
        title = str(item.get("title", "") or "")
        done = _as_bool(
            item.get("isDone", item.get("is_done", item.get("done", False))),
        )
        out.append({"id": sid, "title": title, "isDone": done, "is_done": done})
    return out


def _subtasks_json_for_db(subtasks: list[Any]) -> str:
    return json.dumps(_normalize_subtasks(subtasks))


def _row_to_task_dict(row) -> dict:
    return {
        "id": row["id"],
        "project_id": row["project_id"],
        "title": row["title"],
        "description": row["description"],
        "status": row["status"],
        "due_date": row["due_date"],
        "kanban_position": float(row["kanban_position"]),
        "estimated_hours": row["estimated_hours"],
        "complexity": row["complexity"],
        "tags": _normalize_tags(row["tags"]),
        "subtasks": _normalize_subtasks(row["subtasks"]),
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


@router.get("", response_model=list[TaskIn])
async def list_all_tasks(conn: DbConn, user: CurrentUser) -> list[TaskIn]:
    rows = await conn.fetch(
        """
        select t.id, t.project_id, t.title, t.description, t.status, t.due_date,
               t.kanban_position, t.estimated_hours, t.complexity, t.tags, t.subtasks,
               t.created_at, t.updated_at
        from tasks t
        join projects p on p.id = t.project_id
        where p.owner_id = $1
           or exists (
             select 1 from project_members pm
             where pm.project_id = p.id and pm.user_id = $1
           )
        order by t.id
        """,
        user,
    )
    return [TaskIn(**_row_to_task_dict(r)) for r in rows]


@router.get("/by-project/{project_id}", response_model=list[TaskIn])
async def list_by_project(project_id: int, conn: DbConn, user: CurrentUser) -> list[TaskIn]:
    await require_view(conn, project_id, user)
    rows = await conn.fetch(
        """
        select id, project_id, title, description, status, due_date, kanban_position,
               estimated_hours, complexity, tags, subtasks, created_at, updated_at
        from tasks where project_id = $1
        order by kanban_position
        """,
        project_id,
    )
    return [TaskIn(**_row_to_task_dict(r)) for r in rows]


@router.get("/{task_id}", response_model=TaskIn)
async def get_task(task_id: int, conn: DbConn, user: CurrentUser) -> TaskIn:
    row = await conn.fetchrow(
        """
        select t.id, t.project_id, t.title, t.description, t.status, t.due_date,
               t.kanban_position, t.estimated_hours, t.complexity, t.tags, t.subtasks,
               t.created_at, t.updated_at
        from tasks t
        where t.id = $1
        """,
        task_id,
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tarea no encontrada")
    await require_view(conn, row["project_id"], user)
    return TaskIn(**_row_to_task_dict(row))


@router.put("", response_model=TaskIn)
async def upsert_task(body: TaskIn, conn: DbConn, user: CurrentUser) -> TaskIn:
    await require_edit(conn, body.project_id, user)
    row = await conn.fetchrow(
        """
        insert into tasks (
            id, project_id, title, description, status, due_date, kanban_position,
            estimated_hours, complexity, tags, subtasks, created_at, updated_at
        )
        values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11::jsonb,$12,$13)
        on conflict (id) do update set
            project_id = excluded.project_id,
            title = excluded.title,
            description = excluded.description,
            status = excluded.status,
            due_date = excluded.due_date,
            kanban_position = excluded.kanban_position,
            estimated_hours = excluded.estimated_hours,
            complexity = excluded.complexity,
            tags = excluded.tags,
            subtasks = excluded.subtasks,
            updated_at = excluded.updated_at
        returning id, project_id, title, description, status, due_date, kanban_position,
                  estimated_hours, complexity, tags, subtasks, created_at, updated_at
        """,
        body.id,
        body.project_id,
        body.title,
        body.description,
        body.status,
        body.due_date,
        body.kanban_position,
        body.estimated_hours,
        body.complexity,
        json.dumps(body.tags),
        _subtasks_json_for_db(body.subtasks),
        body.created_at,
        body.updated_at,
    )
    return TaskIn(**_row_to_task_dict(row))


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(task_id: int, conn: DbConn, user: CurrentUser) -> None:
    row = await conn.fetchrow("select project_id from tasks where id = $1", task_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tarea no encontrada")
    await require_edit(conn, row["project_id"], user)
    await conn.execute("delete from tasks where id = $1", task_id)
