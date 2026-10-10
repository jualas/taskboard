from uuid import UUID

import asyncpg

from .config import workspace_admin_emails


async def is_project_owner(conn: asyncpg.Connection, project_id: int, user_id: UUID) -> bool:
    row = await conn.fetchrow(
        "select 1 from projects where id = $1 and owner_id = $2",
        project_id,
        user_id,
    )
    return row is not None


async def get_member_role(
    conn: asyncpg.Connection, project_id: int, user_id: UUID
) -> str | None:
    row = await conn.fetchrow(
        "select role from project_members where project_id = $1 and user_id = $2",
        project_id,
        user_id,
    )
    return row["role"] if row else None


async def can_view_project(conn: asyncpg.Connection, project_id: int, user_id: UUID) -> bool:
    if await is_project_owner(conn, project_id, user_id):
        return True
    role = await get_member_role(conn, project_id, user_id)
    return role is not None


async def can_edit_project(conn: asyncpg.Connection, project_id: int, user_id: UUID) -> bool:
    if await is_project_owner(conn, project_id, user_id):
        return True
    role = await get_member_role(conn, project_id, user_id)
    return role in ("owner", "editor")


async def require_view(conn: asyncpg.Connection, project_id: int, user_id: UUID) -> None:
    if not await can_view_project(conn, project_id, user_id):
        from fastapi import HTTPException, status

        raise HTTPException(status.HTTP_403_FORBIDDEN, "Sin acceso al proyecto")


async def require_edit(conn: asyncpg.Connection, project_id: int, user_id: UUID) -> None:
    if not await can_edit_project(conn, project_id, user_id):
        from fastapi import HTTPException, status

        raise HTTPException(status.HTTP_403_FORBIDDEN, "Sin permiso de edición")


async def require_owner(conn: asyncpg.Connection, project_id: int, user_id: UUID) -> None:
    if not await is_project_owner(conn, project_id, user_id):
        from fastapi import HTTPException, status

        raise HTTPException(status.HTTP_403_FORBIDDEN, "Solo el propietario puede hacer esto")


async def is_workspace_admin(conn: asyncpg.Connection, user_id: UUID) -> bool:
    """Acceso a carpetas del servidor y a Cursor Agent (WORKSPACE_ADMIN_EMAILS)."""
    admins = workspace_admin_emails()
    if not admins:
        return False
    email = await conn.fetchval("select lower(email) from app_users where id = $1", user_id)
    return email in admins


async def require_workspace_admin(conn: asyncpg.Connection, user_id: UUID) -> None:
    if not await is_workspace_admin(conn, user_id):
        from fastapi import HTTPException, status

        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "Solo los administradores del servidor pueden usar carpetas workspace y Cursor Agent",
        )
