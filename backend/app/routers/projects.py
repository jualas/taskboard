from uuid import UUID

import asyncio
import json

from fastapi import APIRouter, HTTPException, status

from ..agent_sessions import (
    clear_project_agent_session,
    get_project_agent_session,
    list_agent_runs,
)
from ..deps import CurrentUser, DbConn
from ..permissions import is_project_owner, require_edit, require_owner, require_view
from ..schemas import (
    AgentRunOut,
    AgentSessionOut,
    MemberCreate,
    MemberPatch,
    ProjectCreate,
    ProjectMemberOut,
    ProjectOut,
    ProjectPatch,
    WorkspacePathBody,
    WorkspaceSnapshotOut,
    WorkspaceSuggestionOut,
    WorkspaceInventoryOut,
    WorkspaceInventoryEntry,
    WorkspaceOrphanProject,
    TaskboardMdOut,
    TaskboardMdExportBody,
    IdePromptOut,
    IdeSessionOut,
)
from ..ide_prompt import build_ide_prompt_for_project
from ..taskboard_md import (
    build_taskboard_md_for_project,
    write_taskboard_md_file,
)
from ..workspace import build_workspace_snapshot, normalize_workspace_path
from ..workspace_inventory import scan_workspace_inventory
from ..workspace_sync import count_pending_suggestions, sync_project_workspace

router = APIRouter(prefix="/api/projects", tags=["projects"])

_PROJECT_SELECT = """
        select p.id, p.title, p.description, p.status, p.workspace_path,
          p.owner_id, p.created_at, p.updated_at,
"""

_PENDING_SUGGESTIONS_SQL = """
          coalesce((
            select count(*)::int from workspace_suggestions ws
            where ws.project_id = p.id and ws.state = 'pending'
          ), 0) as pending_workspace_suggestions
"""


def _project_out(row) -> ProjectOut:
    d = dict(row)
    d.setdefault("pending_workspace_suggestions", 0)
    return ProjectOut(**d)


async def _next_project_id(conn) -> int:
    return await conn.fetchval("select coalesce(max(id), 0) + 1 from projects")


@router.get("", response_model=list[ProjectOut])
async def list_projects(conn: DbConn, user: CurrentUser) -> list[ProjectOut]:
    rows = await conn.fetch(
        f"""
        {_PROJECT_SELECT}
          case
            when p.owner_id = $1 then 'owner'
            else coalesce(
              (select pm.role from project_members pm
               where pm.project_id = p.id and pm.user_id = $1 limit 1),
              'viewer'
            )
          end as current_user_role,
        {_PENDING_SUGGESTIONS_SQL}
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
    return [_project_out(r) for r in rows]


@router.post("", response_model=ProjectOut, status_code=status.HTTP_201_CREATED)
async def create_project(body: ProjectCreate, conn: DbConn, user: CurrentUser) -> ProjectOut:
    nid = await _next_project_id(conn)
    title = (body.title or "").strip() or "Sin título"
    st = body.status if body.status in ("planning", "development", "completed", "archived") else "planning"
    ws = normalize_workspace_path(body.workspace_path) if (body.workspace_path or "").strip() else ""
    row = await conn.fetchrow(
        """
        insert into projects (id, title, description, status, workspace_path, owner_id, created_at, updated_at)
        values ($1, $2, $3, $4, $5, $6, timezone('utc', now()), timezone('utc', now()))
        returning id, title, description, status, workspace_path, owner_id, created_at, updated_at,
          'owner'::text as current_user_role,
          0::int as pending_workspace_suggestions
        """,
        nid,
        title,
        body.description or "",
        st,
        ws,
        user,
    )
    return _project_out(row)


@router.post("/workspace-snapshot-preview")
async def preview_workspace_snapshot(
    body: WorkspacePathBody, user: CurrentUser
) -> dict:
    _ = user
    path = normalize_workspace_path(body.path)
    return await build_workspace_snapshot(path)


@router.get("/workspace-inventory", response_model=WorkspaceInventoryOut)
async def workspace_inventory(conn: DbConn, user: CurrentUser) -> WorkspaceInventoryOut:
    """Inventario de carpetas en WORKSPACE_ROOTS y su vínculo con proyectos."""
    scanned = await asyncio.to_thread(scan_workspace_inventory)
    scanned_paths = {e["path"] for e in scanned}

    rows = await conn.fetch(
        """
        select p.id, p.title, trim(coalesce(p.workspace_path, '')) as workspace_path
        from projects p
        where trim(coalesce(p.workspace_path, '')) != ''
          and (
            p.owner_id = $1
            or exists (
              select 1 from project_members pm
              where pm.project_id = p.id and pm.user_id = $1
            )
          )
        """,
        user,
    )
    link_map: dict[str, dict[str, object]] = {}
    for row in rows:
        path = row["workspace_path"]
        if path:
            link_map[path] = {"id": row["id"], "title": row["title"]}

    entries: list[WorkspaceInventoryEntry] = []
    linked = 0
    for raw in scanned:
        link = link_map.get(raw["path"])
        if link:
            linked += 1
        entries.append(
            WorkspaceInventoryEntry(
                path=raw["path"],
                name=raw["name"],
                root=raw["root"],
                root_path=raw.get("root_path", ""),
                has_git=bool(raw.get("has_git")),
                has_docker_compose=bool(raw.get("has_docker_compose")),
                linked_project_id=int(link["id"]) if link else None,
                linked_project_title=str(link["title"]) if link else None,
            )
        )

    orphans: list[WorkspaceOrphanProject] = []
    for path, info in link_map.items():
        if path not in scanned_paths:
            orphans.append(
                WorkspaceOrphanProject(
                    project_id=int(info["id"]),
                    project_title=str(info["title"]),
                    workspace_path=path,
                )
            )

    total = len(entries)
    return WorkspaceInventoryOut(
        entries=entries,
        orphan_projects=orphans,
        total=total,
        linked=linked,
        unlinked=total - linked,
    )


@router.get("/{project_id}/agent-session", response_model=AgentSessionOut | None)
async def read_agent_session(
    project_id: int, conn: DbConn, user: CurrentUser
) -> AgentSessionOut | None:
    await require_view(conn, project_id, user)
    row = await get_project_agent_session(conn, project_id)
    if row is None:
        return None
    return AgentSessionOut(
        project_id=int(row["project_id"]),
        session_id=str(row["session_id"]),
        workspace_path=str(row.get("workspace_path") or ""),
        updated_at=row["updated_at"],
    )


@router.delete("/{project_id}/agent-session", status_code=status.HTTP_204_NO_CONTENT)
async def reset_agent_session(project_id: int, conn: DbConn, user: CurrentUser) -> None:
    await require_edit(conn, project_id, user)
    await clear_project_agent_session(conn, project_id)


@router.get("/{project_id}/agent-runs", response_model=list[AgentRunOut])
async def read_agent_runs(
    project_id: int,
    conn: DbConn,
    user: CurrentUser,
    limit: int = 40,
) -> list[AgentRunOut]:
    await require_view(conn, project_id, user)
    rows = await list_agent_runs(conn, project_id, limit=limit)
    return [
        AgentRunOut(
            id=int(r["id"]),
            project_id=int(r["project_id"]),
            session_id=r.get("session_id"),
            prompt=str(r.get("prompt") or ""),
            execute_mode=bool(r.get("execute_mode")),
            result_preview=str(r.get("result_preview") or ""),
            is_error=bool(r.get("is_error")),
            created_at=r["created_at"],
        )
        for r in rows
    ]


@router.get("/{project_id}/taskboard-md", response_model=TaskboardMdOut)
async def preview_taskboard_md(
    project_id: int,
    conn: DbConn,
    user: CurrentUser,
    filename: str = "",
) -> TaskboardMdOut:
    """Vista previa del Markdown de tareas (sin escribir en disco)."""
    await require_view(conn, project_id, user)
    data = await build_taskboard_md_for_project(
        conn, project_id=project_id, filename=filename or None
    )
    return TaskboardMdOut(**data, written=False)


@router.post("/{project_id}/taskboard-md", response_model=TaskboardMdOut)
async def export_taskboard_md(
    project_id: int,
    conn: DbConn,
    user: CurrentUser,
    body: TaskboardMdExportBody | None = None,
) -> TaskboardMdOut:
    """Escribe TASKBOARD.md (u otro nombre) en la carpeta workspace del proyecto."""
    await require_edit(conn, project_id, user)
    opts = body or TaskboardMdExportBody()
    data = await build_taskboard_md_for_project(
        conn,
        project_id=project_id,
        filename=(opts.filename or "").strip() or None,
    )
    written = False
    if not opts.dry_run:
        write_taskboard_md_file(file_path=data["file_path"], content=data["content"])
        written = True
    return TaskboardMdOut(**data, written=written)


@router.get("/{project_id}/ide-prompt", response_model=IdePromptOut)
async def read_ide_prompt(
    project_id: int,
    conn: DbConn,
    user: CurrentUser,
    focus_task_id: int | None = None,
) -> IdePromptOut:
    """Plantilla de prompt para Cursor IDE rellenada con datos del proyecto."""
    await require_view(conn, project_id, user)
    data = await build_ide_prompt_for_project(
        conn, project_id=project_id, focus_task_id=focus_task_id
    )
    return IdePromptOut(**data)


@router.post("/{project_id}/ide-session", response_model=IdeSessionOut)
async def prepare_ide_session(
    project_id: int,
    conn: DbConn,
    user: CurrentUser,
    focus_task_id: int | None = None,
) -> IdeSessionOut:
    """Exporta TASKBOARD.md y devuelve el prompt listo para pegar en Cursor."""
    await require_edit(conn, project_id, user)
    md_data = await build_taskboard_md_for_project(conn, project_id=project_id)
    write_taskboard_md_file(file_path=md_data["file_path"], content=md_data["content"])
    export_out = TaskboardMdOut(**md_data, written=True)
    prompt_data = await build_ide_prompt_for_project(
        conn, project_id=project_id, focus_task_id=focus_task_id, export_first=False
    )
    return IdeSessionOut(export=export_out, ide_prompt=IdePromptOut(**prompt_data))


@router.get("/by-workspace-path", response_model=ProjectOut)
async def project_by_workspace_path(
    path: str, conn: DbConn, user: CurrentUser
) -> ProjectOut:
    """Resuelve el proyecto vinculado a una carpeta workspace (p. ej. cwd de Cursor)."""
    resolved = normalize_workspace_path(path)
    row = await conn.fetchrow(
        f"""
        {_PROJECT_SELECT}
          case
            when p.owner_id = $2 then 'owner'
            else coalesce(
              (select pm.role from project_members pm
               where pm.project_id = p.id and pm.user_id = $2 limit 1),
              'viewer'
            )
          end as current_user_role,
        {_PENDING_SUGGESTIONS_SQL}
        from projects p
        where trim(coalesce(p.workspace_path, '')) = $1
          and (
            p.owner_id = $2
            or exists (
              select 1 from project_members pm
              where pm.project_id = p.id and pm.user_id = $2
            )
          )
        limit 1
        """,
        resolved,
        user,
    )
    if row is None:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND,
            f"Ningún proyecto vinculado a {resolved}",
        )
    return _project_out(row)


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
        f"""
        {_PROJECT_SELECT}
          case
            when p.owner_id = $2 then 'owner'
            else coalesce(
              (select pm.role from project_members pm
               where pm.project_id = p.id and pm.user_id = $2 limit 1),
              'viewer'
            )
          end as current_user_role,
        {_PENDING_SUGGESTIONS_SQL}
        from projects p where p.id = $1
        """,
        project_id,
        user,
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Proyecto no encontrado")
    return _project_out(row)


@router.patch("/{project_id}", response_model=ProjectOut)
async def patch_project(
    project_id: int, body: ProjectPatch, conn: DbConn, user: CurrentUser
) -> ProjectOut:
    await require_edit(conn, project_id, user)
    row = await conn.fetchrow(
        "select id, title, description, status, workspace_path, owner_id, created_at, updated_at from projects where id = $1",
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
    ws = row["workspace_path"] or ""
    if body.workspace_path is not None:
        ws = normalize_workspace_path(body.workspace_path)
    updated = await conn.fetchrow(
        """
        update projects
        set title = $2, description = $3, status = $4, workspace_path = $5,
            updated_at = timezone('utc', now())
        where id = $1
        returning id, title, description, status, workspace_path, owner_id, created_at, updated_at
        """,
        project_id,
        title,
        desc,
        st,
        ws,
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
    d["pending_workspace_suggestions"] = await count_pending_suggestions(conn, project_id)
    if body.workspace_path is not None and ws.strip():
        try:
            await sync_project_workspace(conn, project_id)
            d["pending_workspace_suggestions"] = await count_pending_suggestions(conn, project_id)
        except Exception:
            pass
    return _project_out(d)


def _payload_dict(raw) -> dict:
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str):
        try:
            val = json.loads(raw)
            return val if isinstance(val, dict) else {}
        except json.JSONDecodeError:
            return {}
    return {}


def _suggestion_out(row) -> WorkspaceSuggestionOut:
    d = dict(row)
    d["payload"] = _payload_dict(d.get("payload"))
    return WorkspaceSuggestionOut(**d)


@router.post("/{project_id}/workspace-sync")
async def trigger_workspace_sync(
    project_id: int, conn: DbConn, user: CurrentUser
) -> dict:
    await require_edit(conn, project_id, user)
    return await sync_project_workspace(conn, project_id)


@router.get("/{project_id}/workspace-snapshots", response_model=list[WorkspaceSnapshotOut])
async def list_workspace_snapshots(
    project_id: int,
    conn: DbConn,
    user: CurrentUser,
    limit: int = 20,
) -> list[WorkspaceSnapshotOut]:
    await require_view(conn, project_id, user)
    lim = max(1, min(limit, 50))
    rows = await conn.fetch(
        """
        select id, project_id, git_commit, git_branch, dirty_count, summary, created_at
        from workspace_snapshots
        where project_id = $1
        order by created_at desc
        limit $2
        """,
        project_id,
        lim,
    )
    return [WorkspaceSnapshotOut(**dict(r)) for r in rows]


@router.get("/{project_id}/workspace-suggestions", response_model=list[WorkspaceSuggestionOut])
async def list_workspace_suggestions(
    project_id: int,
    conn: DbConn,
    user: CurrentUser,
    state: str = "pending",
) -> list[WorkspaceSuggestionOut]:
    await require_view(conn, project_id, user)
    st = state if state in ("pending", "dismissed", "applied") else "pending"
    rows = await conn.fetch(
        """
        select id, project_id, snapshot_id, suggestion_type, title, body, payload, state, created_at
        from workspace_suggestions
        where project_id = $1 and state = $2
        order by created_at desc
        limit 50
        """,
        project_id,
        st,
    )
    return [_suggestion_out(r) for r in rows]


@router.post("/{project_id}/workspace-suggestions/{suggestion_id}/dismiss")
async def dismiss_workspace_suggestion(
    project_id: int,
    suggestion_id: int,
    conn: DbConn,
    user: CurrentUser,
) -> WorkspaceSuggestionOut:
    await require_edit(conn, project_id, user)
    row = await conn.fetchrow(
        """
        update workspace_suggestions
        set state = 'dismissed'
        where id = $1 and project_id = $2 and state = 'pending'
        returning id, project_id, snapshot_id, suggestion_type, title, body, payload, state, created_at
        """,
        suggestion_id,
        project_id,
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sugerencia no encontrada o ya gestionada")
    return _suggestion_out(row)


@router.post("/{project_id}/workspace-suggestions/{suggestion_id}/apply")
async def apply_workspace_suggestion(
    project_id: int,
    suggestion_id: int,
    conn: DbConn,
    user: CurrentUser,
) -> dict:
    await require_edit(conn, project_id, user)
    row = await conn.fetchrow(
        """
        select id, project_id, suggestion_type, title, body, payload, state
        from workspace_suggestions
        where id = $1 and project_id = $2
        """,
        suggestion_id,
        project_id,
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sugerencia no encontrada")
    if row["state"] != "pending":
        raise HTTPException(status.HTTP_409_CONFLICT, "La sugerencia ya fue gestionada")

    payload = _payload_dict(row["payload"])
    applied: dict = {"suggestion_id": suggestion_id, "type": row["suggestion_type"]}

    if row["suggestion_type"] == "project_status":
        new_status = str(payload.get("status") or "").strip()
        if new_status not in ("planning", "development", "completed", "archived"):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Estado sugerido inválido")
        await conn.execute(
            """
            update projects set status = $2, updated_at = timezone('utc', now())
            where id = $1
            """,
            project_id,
            new_status,
        )
        applied["project_status"] = new_status

    elif row["suggestion_type"] == "task":
        title = str(payload.get("title") or row["title"] or "Tarea sugerida").strip()
        description = str(payload.get("description") or row["body"] or "").strip()
        complexity = str(payload.get("complexity") or "medium").strip()
        if complexity not in ("simple", "medium", "complex"):
            complexity = "medium"
        tags_raw = payload.get("tags")
        tags = [str(t) for t in tags_raw] if isinstance(tags_raw, list) else ["workspace"]
        subtasks_raw = payload.get("subtasks")
        subtasks_db: list[dict] = []
        if isinstance(subtasks_raw, list):
            for i, item in enumerate(subtasks_raw, start=1):
                if isinstance(item, str) and item.strip():
                    subtasks_db.append({"id": i, "title": item.strip(), "isDone": False, "is_done": False})
        next_id = await conn.fetchval("select coalesce(max(id), 0) + 1 from tasks")
        max_pos = await conn.fetchval(
            "select coalesce(max(kanban_position), 0) from tasks where project_id = $1",
            project_id,
        )
        task_row = await conn.fetchrow(
            """
            insert into tasks (
              id, project_id, title, description, status, kanban_position,
              estimated_hours, complexity, tags, subtasks, created_at, updated_at
            )
            values (
              $1, $2, $3, $4, 'pending', $5, null, $6, $7::jsonb, $8::jsonb,
              timezone('utc', now()), timezone('utc', now())
            )
            returning id, title
            """,
            next_id,
            project_id,
            title,
            description,
            float(max_pos or 0) + 1.0,
            complexity,
            json.dumps(tags),
            json.dumps(subtasks_db),
        )
        applied["task_id"] = task_row["id"]
        applied["task_title"] = task_row["title"]

    await conn.execute(
        """
        update workspace_suggestions set state = 'applied'
        where id = $1 and project_id = $2
        """,
        suggestion_id,
        project_id,
    )
    applied["pending_suggestions"] = await count_pending_suggestions(conn, project_id)
    return applied


@router.get("/{project_id}/workspace-snapshot")
async def project_workspace_snapshot(
    project_id: int, conn: DbConn, user: CurrentUser
) -> dict:
    await require_view(conn, project_id, user)
    ws = await conn.fetchval(
        "select workspace_path from projects where id = $1",
        project_id,
    )
    path = (ws or "").strip()
    return await build_workspace_snapshot(path)


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_project(project_id: int, conn: DbConn, user: CurrentUser) -> None:
    await require_owner(conn, project_id, user)
    await conn.execute("delete from projects where id = $1", project_id)
