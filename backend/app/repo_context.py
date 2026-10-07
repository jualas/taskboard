"""Lectura de documentos del repo (STATUS, TASKBOARD) para contexto IA."""

from __future__ import annotations

from pathlib import Path

from .config import settings
from .taskboard_md import taskboard_md_filename

_DEFAULT_STATUS = ("docs/STATUS.md", "STATUS.md", "docs/status.md")
_MAX_STATUS_CHARS = 10_000
_MAX_TASKBOARD_CHARS = 8_000


def _status_candidates() -> list[str]:
    raw = (settings.taskboard_status_md_paths or "").strip()
    if raw:
        return [p.strip() for p in raw.split(",") if p.strip()]
    return list(_DEFAULT_STATUS)


def _read_capped(path: Path, *, max_chars: int) -> str | None:
    if not path.is_file():
        return None
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    text = text.strip()
    if not text:
        return None
    if len(text) > max_chars:
        return text[:max_chars] + "\n\n…(truncado)"
    return text


def read_workspace_docs_for_ai(workspace_path: str) -> str:
    """Devuelve bloque de texto con STATUS.md y TASKBOARD.md si existen."""
    ws = Path(workspace_path)
    if not ws.is_dir():
        return ""

    parts: list[str] = []
    for rel in _status_candidates():
        content = _read_capped(ws / rel, max_chars=_MAX_STATUS_CHARS)
        if content:
            parts.append(f"### {rel}\n{content}")
            break

    md_name = taskboard_md_filename(None)
    tb = _read_capped(ws / md_name, max_chars=_MAX_TASKBOARD_CHARS)
    if tb:
        parts.append(f"### {md_name}\n{tb}")

    if not parts:
        return ""
    return "## Documentos del repositorio (fuente para alinear tablero)\n\n" + "\n\n".join(parts)
