"""Persistencia de sesión Cursor Agent e historial por proyecto."""

from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID


async def get_project_agent_session(conn, project_id: int) -> dict[str, Any] | None:
    row = await conn.fetchrow(
        """
        select project_id, session_id, workspace_path, updated_at
        from project_agent_sessions
        where project_id = $1
        """,
        project_id,
    )
    return dict(row) if row else None


async def upsert_project_agent_session(
    conn,
    *,
    project_id: int,
    session_id: str,
    workspace_path: str,
) -> None:
    sid = (session_id or "").strip()
    if not sid:
        return
    await conn.execute(
        """
        insert into project_agent_sessions (project_id, session_id, workspace_path, updated_at)
        values ($1, $2, $3, timezone('utc', now()))
        on conflict (project_id) do update set
          session_id = excluded.session_id,
          workspace_path = excluded.workspace_path,
          updated_at = timezone('utc', now())
        """,
        project_id,
        sid,
        workspace_path,
    )


async def clear_project_agent_session(conn, project_id: int) -> None:
    await conn.execute(
        "delete from project_agent_sessions where project_id = $1",
        project_id,
    )


async def insert_agent_run(
    conn,
    *,
    project_id: int,
    session_id: str | None,
    prompt: str,
    execute_mode: bool,
    result_preview: str,
    is_error: bool,
    created_by: UUID | None,
) -> int:
    run_id = await conn.fetchval(
        """
        insert into project_agent_runs (
          project_id, session_id, prompt, execute_mode,
          result_preview, is_error, created_by, created_at
        )
        values ($1, $2, $3, $4, $5, $6, $7, timezone('utc', now()))
        returning id
        """,
        project_id,
        (session_id or "").strip() or None,
        prompt,
        execute_mode,
        (result_preview or "")[:4000],
        is_error,
        created_by,
    )
    return int(run_id)


async def list_agent_runs(conn, project_id: int, *, limit: int = 40) -> list[dict[str, Any]]:
    lim = max(1, min(int(limit), 100))
    rows = await conn.fetch(
        """
        select id, project_id, session_id, prompt, execute_mode,
               result_preview, is_error, created_at
        from project_agent_runs
        where project_id = $1
        order by created_at desc
        limit $2
        """,
        project_id,
        lim,
    )
    return [dict(r) for r in rows]
