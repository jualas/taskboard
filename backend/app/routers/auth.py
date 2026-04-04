from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from ..config import settings
from ..deps import CurrentUser, DbConn
from ..schemas import ChangePasswordRequest, LoginRequest, RegisterRequest, TokenResponse, UserPublic
from ..security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, conn: DbConn) -> TokenResponse:
    row = await conn.fetchrow(
        "select id, email, password_hash from app_users where lower(email) = lower($1)",
        body.email.strip(),
    )
    if row is None or not verify_password(body.password, row["password_hash"]):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Credenciales incorrectas")
    uid: UUID = row["id"]
    token = create_access_token(str(uid), {"email": row["email"]})
    return TokenResponse(
        access_token=token,
        user=UserPublic(id=uid, email=row["email"]),
    )


@router.post("/register", response_model=TokenResponse)
async def register(body: RegisterRequest, conn: DbConn) -> TokenResponse:
    if not settings.allow_registration:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Registro deshabilitado")
    email = body.email.strip()
    if not email or not body.password:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Email y contraseña requeridos")
    exists = await conn.fetchval("select 1 from app_users where lower(email) = lower($1)", email)
    if exists:
        raise HTTPException(status.HTTP_409_CONFLICT, "Ya existe un usuario con ese email")
    uid = await conn.fetchval(
        """
        insert into app_users (email, password_hash, display_name)
        values ($1, $2, $3)
        returning id
        """,
        email,
        hash_password(body.password),
        body.display_name,
    )
    token = create_access_token(str(uid), {"email": email})
    return TokenResponse(
        access_token=token,
        user=UserPublic(id=uid, email=email),
    )


@router.post("/change-password")
async def change_password(
    body: ChangePasswordRequest,
    conn: DbConn,
    user_id: CurrentUser,
) -> dict[str, bool]:
    if not body.new_password.strip():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "La nueva contraseña no puede estar vacía")
    row = await conn.fetchrow(
        "select password_hash from app_users where id = $1",
        user_id,
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado")
    if not verify_password(body.current_password, row["password_hash"]):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Contraseña actual incorrecta")
    await conn.execute(
        "update app_users set password_hash = $2 where id = $1",
        user_id,
        hash_password(body.new_password),
    )
    return {"ok": True}
