"""Invocación headless del CLI Cursor Agent (`agent --print`)."""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
from collections.abc import AsyncIterator
from pathlib import Path
from typing import Any

from .config import settings

logger = logging.getLogger(__name__)


def messages_to_prompt(messages: list[dict[str, str]]) -> str:
    """Convierte mensajes chat-style en un único prompt para el CLI."""
    parts: list[str] = []
    for msg in messages:
        role = (msg.get("role") or "user").strip().lower()
        content = (msg.get("content") or "").strip()
        if not content:
            continue
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


def _parse_agent_envelope(raw: str) -> str:
    """Extrae el campo result del JSON envelope de `agent --output-format json`."""
    text = raw.strip()
    if not text:
        raise RuntimeError("Cursor agent devolvió salida vacía")
    try:
        envelope = json.loads(text)
        if isinstance(envelope, dict):
            if envelope.get("is_error"):
                raise RuntimeError(str(envelope.get("result") or "Cursor agent error"))
            if "result" in envelope and envelope["result"] is not None:
                return str(envelope["result"])
    except json.JSONDecodeError:
        pass
    return text


def _agent_env() -> dict[str, str]:
    env = os.environ.copy()
    home = (settings.cursor_agent_home or "").strip()
    if home:
        env["HOME"] = home
        env["XDG_CONFIG_HOME"] = f"{home}/.config"
        env.setdefault("XDG_CACHE_HOME", "/tmp/cursor-agent-cache")
        env.setdefault("NODE_COMPILE_CACHE", "/tmp/cursor-compile-cache")
    api_key = (settings.cursor_api_key or "").strip()
    if api_key:
        env["CURSOR_API_KEY"] = api_key
    return env


def _resolve_agent_bin() -> str:
    """Ruta ejecutable del CLI; resuelve symlink roto en Docker."""
    configured = (settings.cursor_agent_bin or "agent").strip() or "agent"
    candidate = Path(configured)
    if candidate.is_file() and candidate.name == "cursor-agent":
        return str(candidate)

    home = (settings.cursor_agent_home or os.environ.get("HOME") or "").strip()
    share = Path(home) / ".local/share/cursor-agent/versions" if home else None
    if share and share.is_dir():
        for version_dir in sorted(share.iterdir(), reverse=True):
            script = version_dir / "cursor-agent"
            if script.is_file():
                return str(script)

    if candidate.is_file():
        return str(candidate)
    return configured


def _build_agent_cmd(
    prompt: str,
    *,
    workspace: Path,
    mode: str,
    timeout_sec: float,
    long_output: bool,
    stream: bool = False,
    execute: bool = False,
    resume_session_id: str | None = None,
) -> list[str]:
    bin_path = _resolve_agent_bin()
    cmd = [
        bin_path,
        "--print",
        "--trust",
    ]
    resume = (resume_session_id or "").strip()
    if resume:
        cmd.extend(["--resume", resume])
    cmd.extend(["--workspace", str(workspace)])
    if execute:
        cmd.append("--force")
    else:
        cmd.extend(["--mode", mode or "ask"])
    if stream:
        cmd.extend(["--output-format", "stream-json", "--stream-partial-output"])
    else:
        cmd.extend(["--output-format", "json"])
    model = (settings.cursor_agent_model or "").strip()
    if model:
        cmd.extend(["--model", model])
    if settings.cursor_agent_approve_mcps:
        cmd.append("--approve-mcps")
    cmd.append(prompt)
    _ = timeout_sec, long_output
    return cmd


def parse_agent_stream_line(line: str) -> dict[str, Any] | None:
    """Convierte una línea NDJSON del CLI en evento simplificado para la UI."""
    line = line.strip()
    if not line:
        return None
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        return {"kind": "log", "text": line}

    if not isinstance(obj, dict):
        return None

    kind = obj.get("type")
    if kind == "assistant":
        msg = obj.get("message") if isinstance(obj.get("message"), dict) else {}
        parts: list[str] = []
        for block in msg.get("content") or []:
            if isinstance(block, dict) and block.get("type") == "text":
                text = str(block.get("text") or "")
                if text:
                    parts.append(text)
        if parts:
            return {"kind": "text", "text": "".join(parts)}
        return None
    if kind == "tool_call" or kind == "tool":
        name = obj.get("tool_name") or obj.get("name") or "tool"
        return {"kind": "tool", "text": f"▸ {name}"}
    if kind == "result":
        return {
            "kind": "done",
            "text": str(obj.get("result") or ""),
            "is_error": bool(obj.get("is_error")),
            "session_id": str(obj.get("session_id") or ""),
        }
    if kind == "system":
        model = obj.get("model") or ""
        cwd = obj.get("cwd") or ""
        return {
            "kind": "init",
            "text": f"Cursor Agent · {model} · {cwd}",
            "session_id": str(obj.get("session_id") or ""),
        }
    return {"kind": "meta", "text": kind or "event"}


async def run_cursor_agent(
    prompt: str,
    *,
    workspace: str | Path,
    mode: str | None = None,
    timeout_sec: float | None = None,
    long_output: bool = False,
) -> str:
    """Ejecuta `agent --print` y devuelve el texto result (normalmente JSON)."""
    ws = Path(workspace)
    if not ws.is_dir():
        raise FileNotFoundError(f"Workspace no accesible: {workspace}")

    agent_mode = (mode or settings.cursor_agent_mode or "ask").strip() or "ask"
    timeout = timeout_sec
    if timeout is None:
        timeout = (
            float(settings.cursor_agent_timeout_plan_sec)
            if long_output
            else float(settings.cursor_agent_timeout_sec)
        )

    cmd = _build_agent_cmd(
        prompt,
        workspace=ws,
        mode=agent_mode,
        timeout_sec=timeout,
        long_output=long_output,
        stream=False,
        execute=False,
    )
    logger.info("Cursor agent: %s (workspace=%s)", cmd[0], ws)

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=_agent_env(),
    )
    try:
        stdout_b, stderr_b = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError as e:
        proc.kill()
        await proc.communicate()
        raise TimeoutError(f"Cursor agent excedió {timeout:.0f}s") from e

    stdout = (stdout_b or b"").decode(errors="replace")
    stderr = (stderr_b or b"").decode(errors="replace")
    if proc.returncode != 0:
        detail = stderr.strip() or stdout.strip() or f"exit {proc.returncode}"
        raise RuntimeError(f"Cursor agent falló: {detail[:800]}")

    return _parse_agent_envelope(stdout)


async def run_cursor_agent_messages(
    messages: list[dict[str, str]],
    *,
    workspace: str | Path,
    long_output: bool = False,
    mode: str | None = None,
) -> str:
    return await run_cursor_agent(
        messages_to_prompt(messages),
        workspace=workspace,
        mode=mode,
        long_output=long_output,
    )


def resolve_workspace_path(explicit: str | None = None) -> str:
    """Ruta workspace para el agente: explícita → default configurada."""
    path = (explicit or "").strip()
    if path:
        return path
    return (settings.cursor_agent_default_workspace or "").strip()


async def stream_cursor_agent(
    prompt: str,
    *,
    workspace: str | Path,
    execute: bool = False,
    timeout_sec: float | None = None,
    resume_session_id: str | None = None,
) -> AsyncIterator[dict[str, Any]]:
    """Stream NDJSON del CLI `agent --print --stream-partial-output`."""
    ws = Path(workspace)
    if not ws.is_dir():
        raise FileNotFoundError(f"Workspace no accesible: {workspace}")

    timeout = timeout_sec or float(settings.cursor_agent_timeout_plan_sec)
    agent_mode = (settings.cursor_agent_mode or "ask").strip() or "ask"
    cmd = _build_agent_cmd(
        prompt,
        workspace=ws,
        mode=agent_mode,
        timeout_sec=timeout,
        long_output=True,
        stream=True,
        execute=execute,
        resume_session_id=resume_session_id,
    )
    logger.info(
        "Cursor agent stream: %s (workspace=%s execute=%s resume=%s)",
        cmd[0],
        ws,
        execute,
        (resume_session_id or "")[:8] or "-",
    )

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=_agent_env(),
    )
    assert proc.stdout is not None

    async def _read_stdout():
        while True:
            line_b = await proc.stdout.readline()
            if not line_b:
                break
            line = line_b.decode(errors="replace").rstrip("\r\n")
            event = parse_agent_stream_line(line)
            if event:
                yield event

    try:
        async for event in _read_stdout():
            yield event
        try:
            await asyncio.wait_for(proc.wait(), timeout=30.0)
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()
            yield {"kind": "error", "text": "El agente no terminó a tiempo tras el stream."}
            return

        if proc.returncode != 0:
            err_b = b""
            if proc.stderr is not None:
                err_b = await proc.stderr.read()
            detail = (err_b or b"").decode(errors="replace").strip() or f"exit {proc.returncode}"
            yield {"kind": "error", "text": detail[:800]}
    except asyncio.CancelledError:
        proc.kill()
        await proc.wait()
        raise
