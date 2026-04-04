from typing import Annotated
from uuid import UUID

import asyncpg
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .db import get_pool
from .security import decode_token, parse_uuid

security = HTTPBearer(auto_error=False)


async def db_conn() -> asyncpg.Connection:
    pool = await get_pool()
    async with pool.acquire() as conn:
        yield conn


async def current_user_id(
    cred: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
) -> UUID:
    if cred is None or cred.scheme.lower() != "bearer":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Falta token Bearer")
    uid = decode_token(cred.credentials)
    parsed = parse_uuid(uid) if uid else None
    if parsed is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token inválido o caducado")
    return parsed


DbConn = Annotated[asyncpg.Connection, Depends(db_conn)]
CurrentUser = Annotated[UUID, Depends(current_user_id)]
