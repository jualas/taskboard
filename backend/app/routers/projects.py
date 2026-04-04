from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from ..deps import CurrentUser, DbConn
from ..permissions import is_project_owner, require_edit, require_owner, require_view
from ..schemas import ProjectCreate, ProjectMemberOut, MemberCreate, MemberPatch, ProjectOut, ProjectPatch

router = APIRouter(prefix="/api/projects", tags=["projects"])


async def _next_project_id(conn) -> int:
    return await conn.fetchval("select coalesce(max(id), 0) + 1 from projects")


@router.get("", response_model=list[ProjectOut])
async def list_projects(conn: DbConn, user: CurrentUser) -> list[ProjectOut]:
    rows = await conn.fetch(
        """
        select p.id, p.title, p.description, p.status, p.owner_id, p.created_at, p.updated_at,
          case
            when p.owner_id = $1 then 'owner'
            else coalesce(
              (select pm.role from project_members pm
               where pm.project_id = p.id and pm.user_id = $1 limit 1),
              'viewer'
            )
          end as current_user_role
        from projects p
        where p.owner_id = $1
           or exists (
             select 1 from project_members pm
             where pm.project_id = p.id and pm.user_id = $1
           )
        order by p.id
        """,
        user,
    )
    return [ProjectOut(**dict(r)) for r in rows]


@router.post("", response_model=ProjectOut, status_code=status.HTTP_201_CREATED)
async def create_project(body: ProjectCreate, conn: DbConn, user: CurrentUser) -> ProjectOut:
    nid = await _next_project_id(conn)
    title = (body.title or "").strip() or "Sin título"
    st = body.status if body.status in ("planning", "development", "completed", "archived") else "planning"
    row = await conn.fetchrow(
        """
        insert into projects (id, title, description, status, owner_id, created_at, updated_at)
        values ($1, $2, $3, $4, $5, timezone('utc', now()), timezone('utc', now()))
        returning id, title, description, status, owner_id, created_at, updated_at,
          'owner'::text as current_user_role
        """,
        nid,
        title,
        body.description or "",
        st,
        user,
    )
    return ProjectOut(**dict(row))


@router.get("/{project_id}/members", response_model=list[ProjectMemberOut])
async def list_members(project_id: int, conn: DbConn, user: CurrentUser) -> list[ProjectMemberOut]:
    await require_view(conn, project_id, user)
    rows = await conn.fetch(
        "select project_id, user_id, role, created_at from project_members where project_id = $1 order by created_at",
        project_id,
    )
    return [
        ProjectMemberOut(
            project_id=r["project_id"],
            user_id=str(r["user_id"]),
            role=r["role"],
            created_at=r["created_at"],
        )
        for r in rows
    ]


@router.post("/{project_id}/members", response_model=ProjectMemberOut, status_code=status.HTTP_201_CREATED)
async def add_member(
    project_id: int, body: MemberCreate, conn: DbConn, user: CurrentUser
) -> ProjectMemberOut:
    await require_edit(conn, project_id, user)
    if body.role not in ("owner", "editor", "viewer"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Rol inválido")
    exists = await conn.fetchval("select 1 from app_users where id = $1", body.user_id)
    if not exists:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Usuario no existe")
    row = await conn.fetchrow(
        """
        insert into project_members (project_id, user_id, role, invited_by)
        values ($1, $2, $3, $4)
        on conflict (project_id, user_id) do update set role = excluded.role
        returning project_id, user_id, role, created_at
        """,
        project_id,
        body.user_id,
        body.role,
        user,
    )
    return ProjectMemberOut(
        project_id=row["project_id"],
        user_id=str(row["user_id"]),
        role=row["role"],
        created_at=row["created_at"],
    )


@router.patch("/{project_id}/members/{member_user_id}", response_model=ProjectMemberOut)
async def patch_member(
    project_id: int, member_user_id: UUID, body: MemberPatch, conn: DbConn, user: CurrentUser
) -> ProjectMemberOut:
    await require_edit(conn, project_id, user)
    if body.role not in ("owner", "editor", "viewer"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Rol inválido")
    if await is_project_owner(conn, project_id, member_user_id) and body.role != "owner":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No se puede degradar al propietario del proyecto")
    row = await conn.fetchrow(
        """
        update project_members set role = $3
        where project_id = $1 and user_id = $2
        returning project_id, user_id, role, created_at
        """,
        project_id,
        member_user_id,
        body.role,
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Miembro no encontrado")
    return ProjectMemberOut(
        project_id=row["project_id"],
        user_id=str(row["user_id"]),
        role=row["role"],
        created_at=row["created_at"],
    )


@router.delete("/{project_id}/members/{member_user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_member(
    project_id: int, member_user_id: UUID, conn: DbConn, user: CurrentUser
) -> None:
    await require_edit(conn, project_id, user)
    if await is_project_owner(conn, project_id, member_user_id):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No se puede eliminar al propietario")
    await conn.execute(
        "delete from project_members where project_id = $1 and user_id = $2",
        project_id,
        member_user_id,
    )


@router.get("/{project_id}", response_model=ProjectOut)
async def get_project(project_id: int, conn: DbConn, user: CurrentUser) -> ProjectOut:
    await require_view(conn, project_id, user)
    row = await conn.fetchrow(
        """
        select p.id, p.title, p.description, p.status, p.owner_id, p.created_at, p.updated_at,
          case
            when p.owner_id = $2 then 'owner'
            else coalesce(
              (select pm.role from project_members pm
               where pm.project_id = p.id and pm.user_id = $2 limit 1),
              'viewer'
            )
          end as current_user_role
        from projects p where p.id = $1
        """,
        project_id,
        user,
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Proyecto no encontrado")
    return ProjectOut(**dict(row))


@router.patch("/{project_id}", response_model=ProjectOut)
async def patch_project(
    project_id: int, body: ProjectPatch, conn: DbConn, user: CurrentUser
) -> ProjectOut:
    await require_edit(conn, project_id, user)
    row = await conn.fetchrow(
        "select id, title, description, status, owner_id, created_at, updated_at from projects where id = $1",
        project_id,
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Proyecto no encontrado")
    title = body.title if body.title is not None else row["title"]
    desc = body.description if body.description is not None else row["description"]
    st = row["status"]
    if body.status is not None:
        if body.status in ("planning", "development", "completed", "archived"):
            st = body.status
    updated = await conn.fetchrow(
        """
        update projects
        set title = $2, description = $3, status = $4, updated_at = timezone('utc', now())
        where id = $1
        returning id, title, description, status, owner_id, created_at, updated_at
        """,
        project_id,
        title,
        desc,
        st,
    )
    role_row = await conn.fetchrow(
        """
        select case
          when owner_id = $2 then 'owner'
          else coalesce(
            (select pm.role from project_members pm
             where pm.project_id = projects.id and pm.user_id = $2 limit 1),
            'viewer'
          )
        end as current_user_role
        from projects where id = $1
        """,
        project_id,
        user,
    )
    d = dict(updated)
    d["current_user_role"] = role_row["current_user_role"] if role_row else None
    return ProjectOut(**d)


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_project(project_id: int, conn: DbConn, user: CurrentUser) -> None:
    await require_owner(conn, project_id, user)
    await conn.execute("delete from projects where id = $1", project_id)
