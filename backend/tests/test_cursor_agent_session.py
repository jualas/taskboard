"""Renovación de la sesión de Cursor antes de invocar el agente en modo --print."""

import asyncio
import base64
import json
import time

import pytest

from app import cursor_agent
from app.config import settings


def _token(exp: float) -> str:
    payload = base64.urlsafe_b64encode(json.dumps({"exp": int(exp)}).encode()).decode().rstrip("=")
    return f"cabecera.{payload}.firma"


@pytest.fixture
def agent_home(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "cursor_agent_home", str(tmp_path))
    monkeypatch.setattr(settings, "cursor_api_key", "")
    (tmp_path / ".config" / "cursor").mkdir(parents=True)
    return tmp_path


def _write_auth(home, content: str) -> None:
    (home / ".config" / "cursor" / "auth.json").write_text(content, encoding="utf-8")


def test_vigente_no_renueva(agent_home):
    _write_auth(agent_home, json.dumps({"accessToken": _token(time.time() + 3600)}))
    assert cursor_agent._session_expired() is False


def test_caducada_renueva(agent_home):
    _write_auth(agent_home, json.dumps({"accessToken": _token(time.time() - 10)}))
    assert cursor_agent._session_expired() is True


def test_auth_ilegible_renueva(agent_home):
    _write_auth(agent_home, "no es json")
    assert cursor_agent._session_expired() is True


def test_sin_auth_no_renueva(agent_home):
    assert cursor_agent._session_expired() is False


def test_con_api_key_no_renueva(agent_home, monkeypatch):
    monkeypatch.setattr(settings, "cursor_api_key", "clave")
    _write_auth(agent_home, json.dumps({"accessToken": _token(time.time() - 10)}))
    assert cursor_agent._session_expired() is False


def test_ensure_session_lanza_status_solo_si_caducada(agent_home, monkeypatch):
    calls: list[tuple] = []

    class FakeProc:
        async def wait(self):
            return 0

    async def fake_exec(*args, **kwargs):
        calls.append(args)
        return FakeProc()

    monkeypatch.setattr(cursor_agent, "_resolve_agent_bin", lambda: "/bin/cursor-agent")
    monkeypatch.setattr(cursor_agent.asyncio, "create_subprocess_exec", fake_exec)

    _write_auth(agent_home, json.dumps({"accessToken": _token(time.time() + 3600)}))
    asyncio.run(cursor_agent._ensure_session())
    assert calls == []

    _write_auth(agent_home, json.dumps({"accessToken": _token(time.time() - 10)}))
    asyncio.run(cursor_agent._ensure_session())
    assert calls == [("/bin/cursor-agent", "status")]
