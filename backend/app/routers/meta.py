from fastapi import APIRouter

from ..deps import CurrentUser, DbConn

router = APIRouter(prefix="/api/meta", tags=["meta"])


@router.get("/next-project-id", response_model=int)
async def next_project_id(conn: DbConn, user: CurrentUser) -> int:
    _ = user
    return await conn.fetchval("select coalesce(max(id), 0) + 1 from projects")


@router.get("/next-task-id", response_model=int)
async def next_task_id(conn: DbConn, user: CurrentUser) -> int:
    _ = user
    return await conn.fetchval("select coalesce(max(id), 0) + 1 from tasks")
