import json
import re
from typing import Any

import httpx
from fastapi import APIRouter, Header, HTTPException, status

from ..config import settings
from ..deps import CurrentUser
from ..schemas import AiSuggestBody

router = APIRouter(prefix="/api/ai", tags=["ai"])

SYSTEM_PROMPT = """Eres un asistente para equipos que trabajan con metodologías ágiles (Scrum/Kanban): desglosas peticiones en UNA tarea principal bien definida para el tablero.

Responde SOLO con un JSON válido (sin markdown, sin bloques ```) con esta forma exacta:
{"tasks":[{"title":"...","description":"...","complexity":"simple|medium|complex","estimatedHours":null o entero,"tags":[],"subtasks":[]}]}

Reglas:
- complexity: solo simple, medium o complex (en inglés).
- title: nombre corto y accionable del entregable (no genérico).
- description: texto en español, enriquecido según el contexto. Incluye cuando aplique:
  • Línea tipo historia de usuario: "Como <rol>, quiero <necesidad> para <beneficio>" si el contexto lo permite.
  • Sección "Objetivo:" con 1-3 frases.
  • Sección "Criterios de aceptación:" con viñetas "-" (una por línea) con condiciones verificables.
  • Si encaja: "Notas / riesgos:" breve.
  Usa saltos de línea reales dentro del string JSON (válido en JSON con \\n).
- tags: 3 a 8 etiquetas en español o técnico (ej. frontend, api, testing, documentación, spike, deuda-técnica) alineadas al contexto; no repitas el título.
- subtasks: OBLIGATORIO un checklist accionable de 5 a 12 strings. Cada string es un ítem del tablero tipo DoD incremental: pasos concretos (diseño, implementación, pruebas, revisión, despliegue, documentación) según encaje con la petición. Redacción breve, verificable, orden lógico (primero lo bloqueante). No dejes subtasks vacío salvo que la petición sea trivial de una sola acción; en ese caso usa al menos 3 ítems.

La primera entrada de "tasks" es la única que se usará; debe ser coherente con el proyecto y la petición del usuario."""


@router.post("/suggest")
async def suggest_tasks(
    body: AiSuggestBody,
    user: CurrentUser,
    x_operation_id: str | None = Header(None, alias="x-operation-id"),
) -> dict[str, Any]:
    _ = user
    _ = x_operation_id
    ctx = body.projectContext or {}
    title = (ctx.get("title") or "").strip()
    desc = (ctx.get("description") or "").strip()
    user_msg = (body.userMessage or "").strip()
    user_content = (
        f"Proyecto: {title}\n"
        f"Descripción del proyecto: {desc}\n\n"
        "Contexto de trabajo: metodologías ágiles (historias de usuario, criterios de aceptación, "
        "checklist incremental y definición de hecho).\n\n"
        f"Petición del usuario (brief para esta tarea):\n{user_msg}"
    )

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_content},
    ]

    if settings.deepseek_api_key.strip():
        return await _call_deepseek(messages)
    return await _call_ollama(messages)


async def _call_deepseek(messages: list[dict[str, str]]) -> dict[str, Any]:
    url = f"{settings.deepseek_base_url.rstrip('/')}/v1/chat/completions"
    payload = {
        "model": settings.deepseek_model,
        "messages": messages,
        "response_format": {"type": "json_object"},
    }
    headers = {"Authorization": f"Bearer {settings.deepseek_api_key}"}
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            r = await client.post(url, json=payload, headers=headers)
    except httpx.RequestError as e:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            f"No se pudo conectar con DeepSeek: {e!s}",
        ) from e
    if r.status_code >= 400:
        detail_text = r.text[:500]
        try:
            err = r.json().get("error")
            if isinstance(err, dict) and err.get("message"):
                detail_text = str(err["message"])
        except (ValueError, TypeError, KeyError):
            pass
        if r.status_code == 402:
            raise HTTPException(
                status.HTTP_402_PAYMENT_REQUIRED,
                "DeepSeek: saldo insuficiente. Recarga créditos en https://platform.deepseek.com/",
            )
        if r.status_code == 401:
            raise HTTPException(
                status.HTTP_401_UNAUTHORIZED,
                "DeepSeek: API key no válida o revocada.",
            )
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            f"DeepSeek ({r.status_code}): {detail_text}",
        )
    data = r.json()
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError) as e:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Respuesta DeepSeek inesperada: {e}") from e
    parsed = _parse_tasks_json(content)
    parsed["provider"] = "deepseek"
    return parsed


async def _call_ollama(messages: list[dict[str, str]]) -> dict[str, Any]:
    url = f"{settings.ollama_base_url.rstrip('/')}/v1/chat/completions"
    payload = {
        "model": settings.local_llm_model,
        "messages": messages,
        "stream": False,
    }
    try:
        async with httpx.AsyncClient(timeout=180.0) as client:
            r = await client.post(url, json=payload)
    except httpx.RequestError as e:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            "No se pudo conectar con Ollama. En Docker usa OLLAMA_BASE_URL=http://host.docker.internal:11434 "
            f"y extra_hosts host-gateway, o define DEEPSEEK_API_KEY. Detalle: {e!s}",
        ) from e
    if r.status_code >= 400:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Ollama: {r.status_code} {r.text[:500]}")
    data = r.json()
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError) as e:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"Respuesta Ollama inesperada: {e}") from e
    parsed = _parse_tasks_json(content)
    parsed["provider"] = "local"
    return parsed


def _parse_tasks_json(content: str) -> dict[str, Any]:
    text = content.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        obj = json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{[\s\S]*\}", text)
        if not m:
            raise HTTPException(status.HTTP_502_BAD_GATEWAY, "La IA no devolvió JSON parseable")
        obj = json.loads(m.group(0))
    if not isinstance(obj, dict):
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "JSON raíz debe ser objeto")
    tasks = obj.get("tasks")
    if not isinstance(tasks, list):
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "Falta lista tasks en JSON")
    return {"tasks": tasks}
