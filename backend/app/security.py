from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID

import bcrypt
import jwt

from .config import settings


def _pw_bytes(password: str) -> bytes:
    # bcrypt solo usa 72 bytes; passlib truncaba igual, así los hashes existentes siguen valiendo.
    return password.encode("utf-8")[:72]


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(_pw_bytes(plain), hashed.encode("utf-8"))
    except ValueError:
        return False


def hash_password(password: str) -> str:
    return bcrypt.hashpw(_pw_bytes(password), bcrypt.gensalt()).decode("utf-8")


def create_access_token(sub: str, extra: dict[str, Any] | None = None) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.jwt_expire_days)
    payload: dict[str, Any] = {"sub": sub, "exp": expire}
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> str | None:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
            options={"require": ["exp", "sub"]},
        )
        sub = payload.get("sub")
        if sub is None:
            return None
        return str(sub)
    except jwt.PyJWTError:
        return None


def parse_uuid(value: str) -> UUID | None:
    try:
        return UUID(value)
    except ValueError:
        return None
