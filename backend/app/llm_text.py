"""Utilidades de texto para modelos: mensajes a un único prompt y JSON de la respuesta."""

from __future__ import annotations

import json
import re
from typing import Any

_ROLE_LABEL_RE = re.compile(r"^\[(Sistema|Asistente|Usuario)\]", re.MULTILINE)


def messages_to_prompt(messages: list[dict[str, str]]) -> str:
    """Convierte mensajes chat-style en un único prompt para el CLI."""
    parts: list[str] = []
    for msg in messages:
        role = (msg.get("role") or "user").strip().lower()
        content = (msg.get("content") or "").strip()
        if not content:
            continue
        if role != "system":
            # Un texto de usuario o del repo no puede abrir un bloque [Sistema] propio.
            content = _ROLE_LABEL_RE.sub(r"[\1 (citado)]", content)
        if role == "system":
            parts.append(f"[Sistema]\n{content}")
        elif role == "assistant":
            parts.append(f"[Asistente]\n{content}")
        else:
            parts.append(f"[Usuario]\n{content}")
    return "\n\n".join(parts)


def parse_llm_json(content: str | None) -> Any:
    if content is None or not str(content).strip():
        raise ValueError("La IA devolvió contenido vacío.")
    text = str(content).strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text).strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        if start < 0:
            raise ValueError("JSON no parseable") from None
        obj, _ = json.JSONDecoder().raw_decode(text, start)
        return obj
