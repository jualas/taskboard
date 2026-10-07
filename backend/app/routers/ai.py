import json
import logging
import re
from typing import Any

import httpx
from fastapi import APIRouter, Header, HTTPException, status
from fastapi.responses import StreamingResponse

from ..agent_sessions import (
    clear_project_agent_session,
    get_project_agent_session,
    insert_agent_run,
    list_agent_runs,
    upsert_project_agent_session,
)
from ..config import settings
from ..cursor_agent import (
    parse_llm_json,
    resolve_workspace_path,
    run_cursor_agent_messages,
    stream_cursor_agent,
)
from ..deps import CurrentUser, DbConn
from ..permissions import require_view
from ..schemas import AiAgentStreamBody, AiChatBody, AiSuggestBody, AgentRunOut, AgentSessionOut
from ..repo_context import read_workspace_docs_for_ai
from ..workspace import build_workspace_snapshot, format_snapshot_for_ai

router = APIRouter(prefix="/api/ai", tags=["ai"])
logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """Eres un asistente para equipos que trabajan con metodologías ágiles (Scrum/Kanban): desglosas peticiones en UNA tarea principal bien definida para el tablero.

Responde SOLO con un JSON válido (sin markdown, sin bloques ```) con esta forma exacta:
{"tasks":[{"title":"...","description":"...","complexity":"simple|medium|complex","estimatedHours":null o entero,"tags":[],"subtasks":[]}]}

Reglas:
- complexity: solo simple, medium o complex (en inglés).
- title: nombre corto y accionable del entregable (no genérico).
- description: texto en español, enriquecido según el contexto.
- tags: 3 a 8 etiquetas.
- subtasks: checklist de 5 a 12 strings accionables.

La primera entrada de "tasks" es la única que se usará."""

SYSTEM_PROMPT_PROJECT_PLAN = """Eres un arquitecto de backlog ágil. Descomponer el proyecto en MUCHAS tareas de tablero (10-14, mínimo 8).

Responde SOLO con JSON válido:
{"tasks":[{"title":"...","description":"...","complexity":"simple|medium|complex","estimatedHours":null o entero,"tags":[],"subtasks":[]}, ...]}

Cubrir fases: descubrimiento, diseño, desarrollo, calidad/CI, despliegue, retrospectiva. JSON completo y válido."""

SYSTEM_PROMPT_PROJECT_CHAT = """Eres un arquitecto de backlog ágil en conversación sobre un PROYECTO DE SOFTWARE.
Ayudas a definir, revisar y refinar el backlog; también respondes preguntas sobre el estado del repo si se proporciona.

Responde SOLO con JSON válido:
{"message":"texto en español","tasks":null o [{"title":"...","description":"...","complexity":"simple|medium|complex","estimatedHours":null o entero,"tags":[],"subtasks":[]}, ...]}

- "message": respuesta clara en español.
- "tasks": null si solo preguntan; lista COMPLETA actualizada si piden cambios al backlog o alinear kanban con el repo.
- Si piden implementar o alinear: actualiza "tasks" con el borrador corregido (estados, títulos, nuevas tareas, archivar obsoletas).
  En "message" resume cambios en tablero y, si aplica, pasos concretos en el repo (commits, docs); el tablero se aplica con el botón de la UI.
- Si hay contexto de workspace (git/docker), úsalo para comentar coherencia entre código y tareas.
- Si se incluyen secciones «Documentos del repositorio» (STATUS.md, TASKBOARD.md), úsalas como fuente principal para alinear; NO explores el filesystem salvo que falte información crítica.
- NO cortes el JSON."""

_ALIGNMENT_KEYWORDS = (
    "alinear",
    "alineación",
    "alineacion",
    "sincroniz",
    "actualizar el estado",
    "estado actual del proyecto",
    "estado del repositorio",
    "repo",
    "repositorio",
    "taskboard",
    "kanban",
    "status.md",
)


def _user_wants_alignment(messages: list) -> bool:
    for msg in messages or []:
        if (getattr(msg, "role", "") or "").strip().lower() != "user":
            continue
        text = (getattr(msg, "content", "") or "").strip().lower()
        if any(k in text for k in _ALIGNMENT_KEYWORDS):
            return True
    return False


async def _export_taskboard_before_chat(conn, project_id: int) -> None:
    try:
        from ..taskboard_md import build_taskboard_md_for_project, write_taskboard_md_file

        data = await build_taskboard_md_for_project(conn, project_id=project_id)
        write_taskboard_md_file(file_path=data["file_path"], content=data["content"])
    except Exception as e:
        logger.warning("Pre-export TASKBOARD.md falló (project %s): %s", project_id, e)


async def _workspace_context_for_project(
    conn, project_id: int | None, user
) -> str:
    if project_id is None:
        return ""
    try:
        await require_view(conn, project_id, user)
    except HTTPException:
        return ""
    ws = await conn.fetchval(
        "select workspace_path from projects where id = $1",
        project_id,
    )
    path = (ws or "").strip()
    if not path:
        return ""
    cached = await conn.fetchrow(
        """
        select summary, created_at from workspace_snapshots
        where project_id = $1
        order by created_at desc
        limit 1
        """,
        project_id,
    )
    if cached and (cached["summary"] or "").strip():
        ts = cached["created_at"]
        stamp = ts.isoformat() if hasattr(ts, "isoformat") else str(ts)
        base = f"(Snapshot automático {stamp})\n{cached['summary']}"
        docs = read_workspace_docs_for_ai(path)
        if docs:
            return f"{base}\n\n{docs}"
        return base
    try:
        snap = await build_workspace_snapshot(path)
        base = format_snapshot_for_ai(snap)
    except Exception as e:
        logger.warning("workspace snapshot falló para proyecto %s: %s", project_id, e)
        base = f"No se pudo leer el workspace en {path}."

    docs = read_workspace_docs_for_ai(path)
    if docs:
        return f"{base}\n\n{docs}"
    return base


@router.post("/suggest")
async def suggest_tasks(
    body: AiSuggestBody,
    user: CurrentUser,
    x_operation_id: str | None = Header(None, alias="x-operation-id"),
) -> dict[str, Any]:
    _ = x_operation_id
    ctx = body.projectContext or {}
    title = (ctx.get("title") or "").strip()
    desc = (ctx.get("description") or "").strip()
    user_msg = (body.userMessage or "").strip()
    plan = body.project_plan

    if plan:
        user_content = (
            f"Nombre del proyecto: {title or '(sin título)'}\n"
            f"Descripción:\n{desc or '(sin descripción)'}\n\n"
            f"Detalles extra:\n{user_msg or '(inferir según el dominio)'}\n\n"
            "Genera backlog 10-14 tareas cubriendo fases ágiles."
        )
        system = SYSTEM_PROMPT_PROJECT_PLAN
        long_output = True
    else:
        user_content = (
            f"Proyecto: {title}\nDescripción: {desc}\n\n"
            f"Petición del usuario:\n{user_msg}"
        )
        system = SYSTEM_PROMPT
        long_output = False

    if settings.cursor_agent_enabled:
        long_output = True

    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user_content},
    ]

    try:
        result = await _invoke_llm(
            messages,
            long_output=long_output,
            chat=False,
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("ai.suggest falló")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Error IA: {e!s}") from e

    if plan and isinstance(result.get("tasks"), list):
        result["tasks"] = result["tasks"][:16]
    return result


@router.post("/chat")
async def chat_project_plan(
    body: AiChatBody,
    conn: DbConn,
    user: CurrentUser,
    x_operation_id: str | None = Header(None, alias="x-operation-id"),
) -> dict[str, Any]:
    _ = x_operation_id
    ctx = body.projectContext or {}
    title = (ctx.get("title") or "").strip()
    desc = (ctx.get("description") or "").strip()
    history = body.messages or []
    if not history:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Se requiere al menos un mensaje.")
    if history[-1].role.strip().lower() != "user":
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "El último mensaje debe ser del usuario.")

    align_request = _user_wants_alignment(history)
    if body.project_id is not None and align_request:
        await _export_taskboard_before_chat(conn, body.project_id)

    ws_text = await _workspace_context_for_project(conn, body.project_id, user)
    draft_json = json.dumps(body.draftTasks or [], ensure_ascii=False)
    if len(draft_json) > 12000:
        draft_json = draft_json[:12000] + "…"

    system = (
        f"{SYSTEM_PROMPT_PROJECT_CHAT}\n\n"
        f"Proyecto: {title or '(sin título)'}\n"
        f"Descripción:\n{desc or '(sin descripción)'}\n\n"
    )
    if ws_text:
        system += f"Estado del workspace en disco:\n{ws_text}\n\n"
    system += f"Borrador actual de tareas (JSON):\n{draft_json}"

    llm_messages: list[dict[str, str]] = [{"role": "system", "content": system}]
    for msg in history:
        role = msg.role.strip().lower()
        if role not in ("user", "assistant"):
            continue
        content = (msg.content or "").strip()
        if content:
            llm_messages.append({"role": role, "content": content})

    ws_path = ""
    if body.project_id is not None:
        ws_val = await conn.fetchval(
            "select workspace_path from projects where id = $1",
            body.project_id,
        )
        ws_path = (ws_val or "").strip()

    long_output = (
        settings.cursor_agent_enabled
        or not body.draftTasks
        or len(body.draftTasks) >= 6
        or align_request
    )
    try:
        result = await _invoke_llm(
            llm_messages,
            long_output=long_output,
            chat=True,
            workspace_path=ws_path,
        )
    except HTTPException:
        raise
    except TimeoutError as e:
        raise HTTPException(
            status.HTTP_504_GATEWAY_TIMEOUT,
            f"Cursor Agent: {e!s}",
        ) from e
    except Exception as e:
        logger.exception("ai.chat falló")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Error IA: {e!s}") from e

    tasks = result.get("tasks")
    if isinstance(tasks, list):
        result["tasks"] = tasks[:16]
    return result


async def _workspace_path_for_project(conn, project_id: int | None, user) -> str:
    if project_id is None:
        return resolve_workspace_path("")
    try:
        await require_view(conn, project_id, user)
    except HTTPException:
        return resolve_workspace_path("")
    ws_val = await conn.fetchval(
        "select workspace_path from projects where id = $1",
        project_id,
    )
    return resolve_workspace_path((ws_val or "").strip())


@router.post("/agent-stream")
async def agent_stream(
    body: AiAgentStreamBody,
    conn: DbConn,
    user: CurrentUser,
) -> StreamingResponse:
    """Stream en vivo del CLI Cursor Agent (terminal integrado en el asistente)."""
    if not settings.cursor_agent_enabled:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Cursor Agent CLI no está habilitado en el API.",
        )

    prompt = (body.prompt or "").strip()
    if not prompt:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Se requiere prompt.")

    ws_path = await _workspace_path_for_project(conn, body.project_id, user)
    if not ws_path:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "No hay carpeta workspace vinculada al proyecto.",
        )

    resume_id: str | None = None
    pid = body.project_id
    if pid is not None:
        if body.new_session:
            await clear_project_agent_session(conn, pid)
        elif body.continue_session:
            stored = await get_project_agent_session(conn, pid)
            if stored and (stored.get("session_id") or "").strip():
                resume_id = str(stored["session_id"]).strip()

    ctx = body.project_context or {}
    title = (ctx.get("title") or "").strip()
    desc = (ctx.get("description") or "").strip()
    full_prompt = prompt
    if title or desc:
        full_prompt = (
            f"Proyecto TaskBoard: {title or '(sin título)'}\n"
            f"Descripción: {desc or '(sin descripción)'}\n\n"
            f"{prompt}"
        )

    async def event_generator():
        yield ": stream start\n\n"
        session_id: str | None = resume_id
        result_preview = ""
        had_error = False
        try:
            if resume_id:
                meta = json.dumps(
                    {"kind": "session", "text": f"Reanudando sesión {resume_id[:8]}…", "session_id": resume_id},
                    ensure_ascii=False,
                )
                yield f"data: {meta}\n\n"
            async for event in stream_cursor_agent(
                full_prompt,
                workspace=ws_path,
                execute=body.execute,
                resume_session_id=resume_id,
            ):
                sid = (event.get("session_id") or "").strip()
                if sid:
                    session_id = sid
                kind = event.get("kind")
                if kind == "done":
                    result_preview = str(event.get("text") or "")
                    had_error = bool(event.get("is_error"))
                elif kind == "error":
                    had_error = True
                    result_preview = str(event.get("text") or "")
                payload = json.dumps(event, ensure_ascii=False)
                yield f"data: {payload}\n\n"
        except FileNotFoundError as e:
            had_error = True
            result_preview = str(e)
            err = json.dumps({"kind": "error", "text": str(e)}, ensure_ascii=False)
            yield f"data: {err}\n\n"
        except TimeoutError as e:
            had_error = True
            result_preview = str(e)
            err = json.dumps({"kind": "error", "text": str(e)}, ensure_ascii=False)
            yield f"data: {err}\n\n"
        except Exception as e:
            had_error = True
            result_preview = str(e)
            logger.exception("agent-stream falló")
            err = json.dumps({"kind": "error", "text": str(e)}, ensure_ascii=False)
            yield f"data: {err}\n\n"
        finally:
            if pid is not None:
                try:
                    if session_id:
                        await upsert_project_agent_session(
                            conn,
                            project_id=pid,
                            session_id=session_id,
                            workspace_path=ws_path,
                        )
                    await insert_agent_run(
                        conn,
                        project_id=pid,
                        session_id=session_id,
                        prompt=prompt,
                        execute_mode=body.execute,
                        result_preview=result_preview,
                        is_error=had_error,
                        created_by=user,
                    )
                except Exception:
                    logger.exception("No se pudo guardar historial agent (project %s)", pid)
        yield 'data: {"kind":"end"}\n\n'

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


async def _invoke_llm(
    messages: list[dict[str, str]],
    *,
    long_output: bool = False,
    chat: bool = False,
    workspace_path: str = "",
) -> dict[str, Any]:
    ws = resolve_workspace_path(workspace_path)
    if settings.cursor_agent_enabled and ws:
        try:
            raw = await run_cursor_agent_messages(
                messages,
                workspace=ws,
                long_output=long_output,
            )
            parsed = parse_llm_json(raw)
            if chat:
                out = _parse_chat_json_from_obj(parsed)
            else:
                out = _parse_tasks_json_from_obj(parsed)
            out["provider"] = "cursor_agent"
            return out
        except TimeoutError as e:
            raise HTTPException(
                status.HTTP_504_GATEWAY_TIMEOUT,
                f"Cursor Agent: {e!s}",
            ) from e
        except Exception as e:
            logger.warning("Cursor agent falló: %s", e)
            if not settings.cursor_agent_fallback_llm:
                raise HTTPException(
                    status.HTTP_502_BAD_GATEWAY,
                    f"Cursor Agent CLI: {e!s}",
                ) from e
            logger.info("Cursor agent: usando fallback DeepSeek/Ollama")

    if settings.deepseek_api_key.strip():
        return await _call_deepseek(messages, long_output=long_output, chat=chat)
    return await _call_ollama(messages, long_output=long_output, chat=chat)


async def _call_deepseek(
    messages: list[dict[str, str]], *, long_output: bool = False, chat: bool = False
) -> dict[str, Any]:
    url = f"{settings.deepseek_base_url.rstrip('/')}/v1/chat/completions"
    payload: dict[str, Any] = {
        "model": settings.deepseek_model,
        "messages": messages,
        "response_format": {"type": "json_object"},
    }
    if long_output:
        payload["max_tokens"] = 8192
    headers = {"Authorization": f"Bearer {settings.deepseek_api_key}"}
    read_sec = (
        float(settings.deepseek_timeout_plan_sec)
        if long_output
        else float(settings.deepseek_timeout_sec)
    )
    timeout = httpx.Timeout(connect=30.0, read=read_sec, write=60.0, pool=30.0)
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            r = await client.post(url, json=payload, headers=headers)
    except httpx.RequestError as e:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"No se pudo conectar con DeepSeek: {e!s}") from e
    if r.status_code >= 400:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"DeepSeek ({r.status_code}): {r.text[:500]}")
    data = r.json()
    content = data["choices"][0]["message"]["content"]
    parsed = _parse_chat_json(content) if chat else _parse_tasks_json(content)
    parsed["provider"] = "deepseek"
    return parsed


async def _call_ollama(
    messages: list[dict[str, str]], *, long_output: bool = False, chat: bool = False
) -> dict[str, Any]:
    url = f"{settings.ollama_base_url.rstrip('/')}/v1/chat/completions"
    payload: dict[str, Any] = {
        "model": settings.local_llm_model,
        "messages": messages,
        "stream": False,
    }
    if long_output:
        payload["max_tokens"] = 6144
    read_sec = (
        float(settings.ollama_timeout_plan_sec)
        if long_output
        else float(settings.ollama_timeout_sec)
    )
    timeout = httpx.Timeout(connect=30.0, read=read_sec, write=60.0, pool=30.0)
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            r = await client.post(url, json=payload)
    except httpx.RequestError as e:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            f"No se pudo conectar con Ollama: {e!s}",
        ) from e
    if r.status_code >= 400:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Ollama: {r.status_code} {r.text[:500]}")
    data = r.json()
    content = data["choices"][0]["message"]["content"]
    parsed = _parse_chat_json(content) if chat else _parse_tasks_json(content)
    parsed["provider"] = "local"
    return parsed


def _parse_chat_json_from_obj(obj: Any) -> dict[str, Any]:
    message = obj.get("message")
    if message is None or not str(message).strip():
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, 'Falta campo "message"')
    out: dict[str, Any] = {"message": str(message).strip()}
    tasks = obj.get("tasks")
    if tasks is None:
        out["tasks"] = None
    elif isinstance(tasks, list):
        out["tasks"] = tasks
    else:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, 'Campo "tasks" inválido')
    return out


def _parse_tasks_json_from_obj(obj: Any) -> dict[str, Any]:
    tasks = obj.get("tasks")
    if not isinstance(tasks, list):
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "Falta lista tasks")
    return {"tasks": tasks}


def _parse_chat_json(content: str | None) -> dict[str, Any]:
    return _parse_chat_json_from_obj(_load_json_object(content))


def _parse_tasks_json(content: str | None) -> dict[str, Any]:
    return _parse_tasks_json_from_obj(_load_json_object(content))


def _load_json_object(content: str | None) -> Any:
    if content is None or not str(content).strip():
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "La IA devolvió contenido vacío.")
    text = str(content).strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text).strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        if start < 0:
            raise HTTPException(status.HTTP_502_BAD_GATEWAY, "JSON no parseable")
        obj, _ = json.JSONDecoder().raw_decode(text, start)
        return obj
