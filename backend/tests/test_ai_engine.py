"""Disponibilidad del asistente y errores sin detalles internos."""

import asyncio

import httpx
import pytest
from fastapi import HTTPException

from app.config import settings
from app.routers import ai

MESSAGES = [{"role": "user", "content": "hola"}]


@pytest.fixture
def no_engines(monkeypatch):
    monkeypatch.setattr(settings, "cursor_agent_enabled", False)
    monkeypatch.setattr(settings, "deepseek_api_key", "")
    monkeypatch.setattr(settings, "ollama_base_url", "")


def test_no_engine_returns_503_with_clear_message(no_engines):
    assert ai.available_engine(allow_agent=False) is None
    with pytest.raises(HTTPException) as exc:
        asyncio.run(ai._invoke_llm(MESSAGES, chat=True))
    assert exc.value.status_code == 503
    assert "no está disponible" in exc.value.detail


def test_engine_order(no_engines, monkeypatch):
    monkeypatch.setattr(settings, "ollama_base_url", "http://ollama:11434")
    assert ai.available_engine(allow_agent=False) == "local"
    monkeypatch.setattr(settings, "deepseek_api_key", "test-key")
    assert ai.available_engine(allow_agent=False) == "deepseek"
    monkeypatch.setattr(settings, "cursor_agent_enabled", True)
    monkeypatch.setattr(settings, "cursor_agent_default_workspace", "/tmp/ws")
    assert ai.available_engine(allow_agent=False) == "deepseek"
    assert ai.available_engine(allow_agent=True) == "cursor_agent"


def _mock_transport(monkeypatch, handler):
    real = httpx.AsyncClient

    def factory(*args, **kwargs):
        kwargs["transport"] = httpx.MockTransport(handler)
        return real(*args, **kwargs)

    monkeypatch.setattr(ai.httpx, "AsyncClient", factory)


def test_provider_error_body_is_not_returned(no_engines, monkeypatch):
    monkeypatch.setattr(settings, "deepseek_api_key", "test-key")
    _mock_transport(monkeypatch, lambda req: httpx.Response(401, text="invalid key sk-XXXX for account 42"))
    with pytest.raises(HTTPException) as exc:
        asyncio.run(ai._invoke_llm(MESSAGES, chat=True))
    assert exc.value.status_code == 502
    assert "401" in exc.value.detail
    assert "sk-XXXX" not in exc.value.detail and "account" not in exc.value.detail


def test_connection_error_does_not_leak_address(no_engines, monkeypatch):
    monkeypatch.setattr(settings, "ollama_base_url", "http://203.0.113.7:11434")

    def refuse(req):
        raise httpx.ConnectError("All connection attempts failed to 203.0.113.7", request=req)

    _mock_transport(monkeypatch, refuse)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(ai._invoke_llm(MESSAGES, chat=True))
    assert exc.value.status_code == 502
    assert "203.0.113" not in exc.value.detail
