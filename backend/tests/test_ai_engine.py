"""Disponibilidad del asistente y errores sin detalles internos."""

import asyncio
import json

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
    monkeypatch.setattr(settings, "ai_engine", "auto")


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


def test_ai_engine_explicit_choice(no_engines, monkeypatch):
    monkeypatch.setattr(settings, "deepseek_api_key", "test-key")
    monkeypatch.setattr(settings, "ollama_base_url", "http://ollama:11434")
    monkeypatch.setattr(settings, "cursor_agent_enabled", True)
    monkeypatch.setattr(settings, "cursor_agent_default_workspace", "/tmp/ws")
    monkeypatch.setattr(settings, "ai_engine", "deepseek")
    assert ai.available_engine(allow_agent=True) == "deepseek"
    monkeypatch.setattr(settings, "ai_engine", "ollama")
    assert ai.available_engine(allow_agent=True) == "local"
    monkeypatch.setattr(settings, "ai_engine", "agent")
    assert ai.available_engine(allow_agent=True) == "cursor_agent"
    assert ai.available_engine(allow_agent=False) is None
    monkeypatch.setattr(settings, "ai_engine", "otro")
    assert ai.available_engine(allow_agent=True) == "cursor_agent"


def test_explicit_engine_without_key_is_unavailable(no_engines, monkeypatch):
    monkeypatch.setattr(settings, "ollama_base_url", "http://ollama:11434")
    monkeypatch.setattr(settings, "ai_engine", "deepseek")
    assert ai.available_engine(allow_agent=False) is None
    with pytest.raises(HTTPException) as exc:
        asyncio.run(ai._invoke_llm(MESSAGES, chat=True))
    assert exc.value.status_code == 503


def _deepseek_ok(content, finish="stop"):
    return {
        "model": "deepseek-chat",
        "choices": [{"message": {"content": content}, "finish_reason": finish}],
        "usage": {"prompt_tokens": 120, "completion_tokens": 40},
    }


def test_deepseek_sends_token_limit_and_logs_only_usage(no_engines, monkeypatch, caplog):
    monkeypatch.setattr(settings, "deepseek_api_key", "test-key")
    monkeypatch.setattr(settings, "ai_engine", "deepseek")
    sent = []

    def handler(req):
        sent.append(json.loads(req.content))
        return httpx.Response(200, json=_deepseek_ok('{"message": "secreto del usuario", "tasks": null}'))

    _mock_transport(monkeypatch, handler)
    caplog.set_level("INFO", logger=ai.logger.name)
    out = asyncio.run(ai._invoke_llm(MESSAGES, chat=True))
    asyncio.run(ai._invoke_llm(MESSAGES, chat=True, long_output=True))
    assert out == {"message": "secreto del usuario", "tasks": None, "provider": "deepseek"}
    assert [p["max_tokens"] for p in sent] == [settings.deepseek_max_tokens, settings.deepseek_max_tokens_plan]
    assert sent[0]["response_format"] == {"type": "json_object"}
    assert "tokens_entrada=120 tokens_salida=40" in caplog.text
    assert "secreto" not in caplog.text and "test-key" not in caplog.text


def test_deepseek_insufficient_balance_keeps_402_for_the_ui(no_engines, monkeypatch):
    monkeypatch.setattr(settings, "deepseek_api_key", "test-key")
    _mock_transport(monkeypatch, lambda req: httpx.Response(402, json={"error": {"message": "Insufficient Balance"}}))
    with pytest.raises(HTTPException) as exc:
        asyncio.run(ai._invoke_llm(MESSAGES, chat=True))
    assert exc.value.status_code == 502
    assert "402" in exc.value.detail


def test_deepseek_timeout_is_504(no_engines, monkeypatch):
    monkeypatch.setattr(settings, "deepseek_api_key", "test-key")

    def slow(req):
        raise httpx.ReadTimeout("timed out", request=req)

    _mock_transport(monkeypatch, slow)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(ai._invoke_llm(MESSAGES, chat=True))
    assert exc.value.status_code == 504


def test_deepseek_truncated_json_explains_token_limit(no_engines, monkeypatch):
    monkeypatch.setattr(settings, "deepseek_api_key", "test-key")
    _mock_transport(monkeypatch, lambda req: httpx.Response(200, json=_deepseek_ok('{"tasks": [{"title": "A', "length")))
    with pytest.raises(HTTPException) as exc:
        asyncio.run(ai._invoke_llm(MESSAGES, chat=False))
    assert exc.value.status_code == 502
    assert "límite de tokens" in exc.value.detail
