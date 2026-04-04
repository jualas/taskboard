from fastapi import APIRouter

from ..deps import CurrentUser, DbConn
from ..schemas import AppUserOut

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("", response_model=list[AppUserOut])
async def list_users(conn: DbConn, user: CurrentUser) -> list[AppUserOut]:
    _ = user
    rows = await conn.fetch(
        "select id as user_id, email from app_users where email is not null order by lower(email)"
    )
    return [AppUserOut(user_id=str(r["user_id"]), email=r["email"]) for r in rows]
