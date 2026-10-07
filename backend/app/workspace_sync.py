"""Sincronización periódica de workspace: snapshots, deltas y sugerencias."""

from __future__ import annotations

import asyncio
import json
import logging
import re
from typing import Any

import httpx

from .config import settings
from .cursor_agent import parse_llm_json, run_cursor_agent
from .workspace import build_workspace_snapshot

logger = logging.getLogger(__name__)

SYNC_SYSTEM_PROMPT = """Eres un asistente de gestión ágil. Analizas cambios en el repositorio git de un proyecto
y propones acciones concretas en el tablero TaskBoard.

Responde SOLO con JSON válido (sin markdown):
{"suggestions":[{"type":"info|project_status|task","title":"...","body":"...","payload":{}}]}

Reglas:
- Máximo 2 sugerencias.
- type=project_status → payload {"status":"planning|development|completed|archived"} solo si tiene sentido.
- type=task → payload {"title":"...","description":"...","complexity":"simple|medium|complex","tags":[],"subtasks":[]}.
- type=info → payload vacío {}.
- Español, títulos accionables."""


def _git_fingerprint(snap: dict[str, Any]) -> tuple[str | None, str | None, int]:
    git = snap.get("git") or {}
    commit = git.get("commit_full") or git.get("commit")
    branch = git.get("branch")
    dirty = int(git.get("dirty_count") or 0)
    return (str(commit) if commit else None, str(branch) if branch else None, dirty)


def _docker_service_states(snap: dict[str, Any]) -> dict[str, str]:
    docker = snap.get("docker") or {}
    services = docker.get("services") or []
    out: dict[str, str] = {}
    if isinstance(services, list):
        for svc in services:
            if isinstance(svc, dict):
                name = str(svc.get("name") or "?")
                state = str(svc.get("state") or "?")
                out[name] = state
    return out


def _heuristic_suggestions(
    *,
    project_id: int,
    project_title: str,
    project_status: str,
    prev_snap: dict[str, Any] | None,
    new_snap: dict[str, Any],
    snapshot_id: int,
) -> list[dict[str, Any]]:
    suggestions: list[dict[str, Any]] = []
    git = new_snap.get("git") or {}
    prev_git = (prev_snap or {}).get("git") or {}
    prev_commit = prev_git.get("commit_full") or prev_git.get("commit")
    new_commit = git.get("commit_full") or git.get("commit")
    prev_dirty = int(prev_git.get("dirty_count") or 0)
    new_dirty = int(git.get("dirty_count") or 0)
    commit_msg = (git.get("commit_message") or "").strip()

    if prev_snap is None:
        suggestions.append(
            {
                "project_id": project_id,
                "snapshot_id": snapshot_id,
                "suggestion_type": "info",
                "title": "Workspace monitorizado",
                "body": f"Se ha registrado el estado inicial del workspace para «{project_title}».",
                "payload": {},
            }
        )
        return suggestions

    if new_commit and prev_commit and str(new_commit) != str(prev_commit):
        body = commit_msg or "Nuevo commit detectado en el repositorio."
        suggestions.append(
            {
                "project_id": project_id,
                "snapshot_id": snapshot_id,
                "suggestion_type": "task",
                "title": "Revisar último commit del repo",
                "body": body,
                "payload": {
                    "title": "Revisar cambios del último commit",
                    "description": (
                        f"Commit {str(new_commit)[:12]}: {body}\n\n"
                        "Comprobar coherencia con el backlog y actualizar tareas si aplica."
                    ),
                    "complexity": "medium",
                    "tags": ["workspace", "git"],
                    "subtasks": [
                        "Revisar diff del commit",
                        "Actualizar estado de tareas relacionadas",
                        "Anotar follow-ups en el tablero",
                    ],
                },
            }
        )
        if project_status == "planning":
            suggestions.append(
                {
                    "project_id": project_id,
                    "snapshot_id": snapshot_id,
                    "suggestion_type": "project_status",
                    "title": "Hay actividad en el repo",
                    "body": "Se detectó un commit nuevo; conviene marcar el proyecto como «En desarrollo».",
                    "payload": {"status": "development"},
                }
            )

    if new_dirty - prev_dirty >= 5:
        suggestions.append(
            {
                "project_id": project_id,
                "snapshot_id": snapshot_id,
                "suggestion_type": "task",
                "title": "Muchos cambios sin commitear",
                "body": f"El working tree pasó de {prev_dirty} a {new_dirty} cambios sin commitear.",
                "payload": {
                    "title": "Organizar y commitear cambios pendientes",
                    "description": (
                        f"Hay {new_dirty} archivo(s) con cambios sin commitear en el workspace. "
                        "Agrupa el trabajo en commits coherentes con el backlog."
                    ),
                    "complexity": "simple",
                    "tags": ["workspace", "git"],
                    "subtasks": [
                        "Revisar git status",
                        "Commitear cambios listos",
                        "Actualizar tareas del tablero",
                    ],
                },
            }
        )

    prev_docker = _docker_service_states(prev_snap or {})
    new_docker = _docker_service_states(new_snap)
    stopped: list[str] = []
    for name, state in prev_docker.items():
        prev_running = "run" in state.lower()
        new_state = new_docker.get(name, "")
        new_running = "run" in new_state.lower()
        if prev_running and not new_running:
            stopped.append(name)
    if stopped:
        suggestions.append(
            {
                "project_id": project_id,
                "snapshot_id": snapshot_id,
                "suggestion_type": "info",
                "title": "Servicios Docker detenidos",
                "body": f"Servicios que ya no están en ejecución: {', '.join(stopped[:8])}.",
                "payload": {},
            }
        )

    return suggestions


async def _call_llm_for_suggestions(
    user_content: str,
    *,
    workspace_path: str = "",
) -> list[dict[str, Any]]:
    prompt = f"{SYNC_SYSTEM_PROMPT}\n\n{user_content}"
    path = (workspace_path or "").strip()

    if settings.cursor_agent_enabled and path:
        try:
            raw = await run_cursor_agent(prompt, workspace=path, mode=settings.cursor_agent_mode)
            parsed = parse_llm_json(raw)
            return _normalize_suggestion_rows(parsed)
        except Exception as e:
            logger.warning("Cursor agent workspace suggestions falló: %s", e)

    messages = [
        {"role": "system", "content": SYNC_SYSTEM_PROMPT},
        {"role": "user", "content": user_content},
    ]
    try:
        if settings.deepseek_api_key.strip():
            parsed = await _call_deepseek_json(messages)
        else:
            parsed = await _call_ollama_json(messages)
    except Exception as e:
        logger.warning("IA workspace suggestions falló: %s", e)
        return []

    return _normalize_suggestion_rows(parsed)


def _normalize_suggestion_rows(parsed: dict[str, Any]) -> list[dict[str, Any]]:
    raw = parsed.get("suggestions")
    if not isinstance(raw, list):
        return []
    out: list[dict[str, Any]] = []
    for item in raw[:2]:
        if not isinstance(item, dict):
            continue
        stype = str(item.get("type") or "info").strip().lower()
        if stype not in ("info", "project_status", "task"):
            stype = "info"
        title = str(item.get("title") or "").strip()
        if not title:
            continue
        body = str(item.get("body") or "").strip()
        payload = item.get("payload")
        if not isinstance(payload, dict):
            payload = {}
        out.append(
            {
                "suggestion_type": stype,
                "title": title,
                "body": body,
                "payload": payload,
            }
        )
    return out


async def _call_deepseek_json(messages: list[dict[str, str]]) -> dict[str, Any]:
    url = f"{settings.deepseek_base_url.rstrip('/')}/v1/chat/completions"
    payload = {
        "model": settings.deepseek_model,
        "messages": messages,
        "response_format": {"type": "json_object"},
        "max_tokens": 1024,
    }
    headers = {"Authorization": f"Bearer {settings.deepseek_api_key}"}
    timeout = httpx.Timeout(connect=30.0, read=float(settings.deepseek_timeout_sec), write=60.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.post(url, json=payload, headers=headers)
    r.raise_for_status()
    content = r.json()["choices"][0]["message"]["content"]
    return _load_json_object(content)


async def _call_ollama_json(messages: list[dict[str, str]]) -> dict[str, Any]:
    url = f"{settings.ollama_base_url.rstrip('/')}/v1/chat/completions"
    payload = {
        "model": settings.local_llm_model,
        "messages": messages,
        "stream": False,
        "max_tokens": 1024,
    }
    timeout = httpx.Timeout(connect=30.0, read=float(settings.ollama_timeout_sec), write=60.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.post(url, json=payload)
    r.raise_for_status()
    content = r.json()["choices"][0]["message"]["content"]
    return _load_json_object(content)


def _load_json_object(content: str | None) -> dict[str, Any]:
    text = str(content or "").strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text).strip()
    obj = json.loads(text)
    if not isinstance(obj, dict):
        raise ValueError("JSON raíz debe ser objeto")
    return obj


async def _insert_snapshot(
    conn,
    *,
    project_id: int,
    snap: dict[str, Any],
) -> int:
    commit, branch, dirty = _git_fingerprint(snap)
    summary = str(snap.get("summary") or "")
    row = await conn.fetchrow(
        """
        insert into workspace_snapshots
          (project_id, snapshot, git_commit, git_branch, dirty_count, summary)
        values ($1, $2::jsonb, $3, $4, $5, $6)
        returning id
        """,
        project_id,
        json.dumps(snap, ensure_ascii=False),
        commit,
        branch,
        dirty,
        summary,
    )
    return int(row["id"])


async def _has_recent_duplicate(conn, project_id: int, title: str) -> bool:
    return bool(
        await conn.fetchval(
            """
            select exists(
              select 1 from workspace_suggestions
              where project_id = $1
                and title = $2
                and state = 'pending'
                and created_at > timezone('utc', now()) - interval '24 hours'
            )
            """,
            project_id,
            title,
        )
    )


async def _insert_suggestions(conn, rows: list[dict[str, Any]]) -> int:
    inserted = 0
    for row in rows:
        if await _has_recent_duplicate(conn, row["project_id"], row["title"]):
            continue
        await conn.execute(
            """
            insert into workspace_suggestions
              (project_id, snapshot_id, suggestion_type, title, body, payload)
            values ($1, $2, $3, $4, $5, $6::jsonb)
            """,
            row["project_id"],
            row.get("snapshot_id"),
            row["suggestion_type"],
            row["title"],
            row.get("body") or "",
            json.dumps(row.get("payload") or {}, ensure_ascii=False),
        )
        inserted += 1
    return inserted


async def sync_project_workspace(conn, project_id: int) -> dict[str, Any]:
    """Captura snapshot, detecta cambios y crea sugerencias."""
    row = await conn.fetchrow(
        "select id, title, status, workspace_path from projects where id = $1",
        project_id,
    )
    if row is None:
        return {"project_id": project_id, "skipped": True, "reason": "not_found"}

    path = (row["workspace_path"] or "").strip()
    if not path:
        return {"project_id": project_id, "skipped": True, "reason": "no_workspace"}

    snap = await build_workspace_snapshot(path)
    if not snap.get("configured") or not snap.get("exists"):
        return {"project_id": project_id, "skipped": True, "reason": "path_inaccessible"}

    commit, branch, dirty = _git_fingerprint(snap)

    last = await conn.fetchrow(
        """
        select id, git_commit, git_branch, dirty_count, snapshot, summary
        from workspace_snapshots
        where project_id = $1
        order by created_at desc
        limit 1
        """,
        project_id,
    )

    prev_snap: dict[str, Any] | None = None
    if last:
        raw = last["snapshot"]
        if isinstance(raw, str):
            prev_snap = json.loads(raw)
        elif isinstance(raw, dict):
            prev_snap = raw
        else:
            prev_snap = json.loads(str(raw))

    unchanged = (
        last is not None
        and last["git_commit"] == commit
        and int(last["dirty_count"] or 0) == dirty
        and _docker_service_states(prev_snap or {}) == _docker_service_states(snap)
    )
    if unchanged:
        return {
            "project_id": project_id,
            "skipped": True,
            "reason": "unchanged",
            "pending_suggestions": await count_pending_suggestions(conn, project_id),
        }

    snapshot_id = await _insert_snapshot(conn, project_id=project_id, snap=snap)

    suggestions = _heuristic_suggestions(
        project_id=project_id,
        project_title=row["title"] or "",
        project_status=row["status"] or "planning",
        prev_snap=prev_snap,
        new_snap=snap,
        snapshot_id=snapshot_id,
    )

    prev_commit = None
    if prev_snap and prev_snap.get("git"):
        prev_commit = prev_snap["git"].get("commit_full") or prev_snap["git"].get("commit")
    commit_changed = bool(commit and prev_commit and str(commit) != str(prev_commit))

    if settings.workspace_ai_suggestions and commit_changed:
        task_rows = await conn.fetch(
            "select title, status from tasks where project_id = $1 order by id limit 20",
            project_id,
        )
        task_lines = "\n".join(f"- [{t['status']}] {t['title']}" for t in task_rows) or "(sin tareas)"
        prev_summary = (last["summary"] if last else "") or "(sin snapshot previo)"
        user_content = (
            f"Proyecto: {row['title']}\nEstado actual: {row['status']}\n"
            f"Tareas en tablero:\n{task_lines}\n\n"
            f"Resumen workspace anterior:\n{prev_summary}\n\n"
            f"Resumen workspace nuevo:\n{snap.get('summary', '')}\n\n"
            "Sugiere acciones concretas (máx. 2)."
        )
        ai_rows = await _call_llm_for_suggestions(user_content, workspace_path=path)
        for ai in ai_rows:
            suggestions.append(
                {
                    "project_id": project_id,
                    "snapshot_id": snapshot_id,
                    "suggestion_type": ai["suggestion_type"],
                    "title": ai["title"],
                    "body": ai.get("body") or "",
                    "payload": ai.get("payload") or {},
                }
            )

    inserted = await _insert_suggestions(conn, suggestions)
    pending = await count_pending_suggestions(conn, project_id)
    return {
        "project_id": project_id,
        "skipped": False,
        "snapshot_id": snapshot_id,
        "git_commit": commit,
        "git_branch": branch,
        "dirty_count": dirty,
        "suggestions_created": inserted,
        "pending_suggestions": pending,
    }


async def sync_all_projects_with_workspace(conn) -> dict[str, Any]:
    rows = await conn.fetch(
        """
        select id from projects
        where coalesce(trim(workspace_path), '') <> ''
        order by id
        """
    )
    results: list[dict[str, Any]] = []
    for row in rows:
        try:
            results.append(await sync_project_workspace(conn, int(row["id"])))
        except Exception as e:
            logger.exception("workspace sync falló proyecto %s", row["id"])
            results.append({"project_id": int(row["id"]), "error": str(e)})
    synced = sum(1 for r in results if not r.get("skipped") and not r.get("error"))
    return {"projects_checked": len(rows), "snapshots_created": synced, "results": results}


async def count_pending_suggestions(conn, project_id: int) -> int:
    val = await conn.fetchval(
        """
        select count(*)::int from workspace_suggestions
        where project_id = $1 and state = 'pending'
        """,
        project_id,
    )
    return int(val or 0)


async def workspace_sync_loop(stop_event: asyncio.Event) -> None:
    """Bucle en background; se detiene cuando stop_event está activo."""
    from .db import get_pool

    interval = max(5, int(settings.workspace_snapshot_interval_min)) * 60
    logger.info(
        "Workspace sync loop iniciado (intervalo %s min, IA=%s)",
        settings.workspace_snapshot_interval_min,
        settings.workspace_ai_suggestions,
    )
    while not stop_event.is_set():
        if settings.workspace_snapshot_enabled:
            try:
                pool = await get_pool()
                async with pool.acquire() as conn:
                    summary = await sync_all_projects_with_workspace(conn)
                logger.info(
                    "Workspace sync ciclo: %s proyectos, %s snapshots nuevos",
                    summary["projects_checked"],
                    summary["snapshots_created"],
                )
            except Exception:
                logger.exception("Workspace sync ciclo falló")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=interval)
        except asyncio.TimeoutError:
            continue
    logger.info("Workspace sync loop detenido")
