"""Claude Code: comando con permisos cerrados, entorno sin secretos y lectura del stream."""

import asyncio
import json
import os
import stat
import sys
from pathlib import Path

import pytest

from app import claude_code
from app.config import settings

# Líneas reales de `claude -p --output-format stream-json --verbose` (2.1.x), recortadas.
INIT = {"type": "system", "subtype": "init", "cwd": "/ws", "session_id": "s-1", "model": "claude-sonnet-5-5"}
TEXT = {"type": "assistant", "message": {"content": [{"type": "text", "text": "Leo el README."}]}}
TOOL = {
    "type": "assistant",
    "message": {"content": [{"type": "tool_use", "name": "Read", "input": {"file_path": "/ws/README.md"}}]},
}
TOOL_RESULT = {"type": "user", "message": {"content": [{"type": "tool_result", "content": "secreto"}]}}
RESULT = {"type": "result", "subtype": "success", "is_error": False, "result": "Hecho", "session_id": "s-1"}


def _line(obj):
    return json.dumps(obj)


def test_stream_events():
    assert claude_code.parse_claude_stream_line(_line(INIT)) == [
        {"kind": "init", "text": "Claude Code · claude-sonnet-5-5 · /ws", "session_id": "s-1"}
    ]
    assert claude_code.parse_claude_stream_line(_line(TEXT)) == [{"kind": "text", "text": "Leo el README."}]
    assert claude_code.parse_claude_stream_line(_line(TOOL)) == [
        {"kind": "tool", "text": "▸ Read: /ws/README.md", "tool": "Read"}
    ]
    # El resultado de las herramientas (contenido del repo) no se reenvía a la UI.
    assert claude_code.parse_claude_stream_line(_line(TOOL_RESULT)) == []
    (done,) = claude_code.parse_claude_stream_line(_line(RESULT))
    assert (done["kind"], done["text"], done["is_error"], done["session_id"]) == ("done", "Hecho", False, "s-1")
    assert claude_code.parse_claude_stream_line("no es json") == [{"kind": "log", "text": "no es json"}]


def test_result_errors_are_explained():
    (done,) = claude_code.parse_claude_stream_line(_line({"type": "result", "subtype": "error_max_turns"}))
    assert done["is_error"] is True
    assert "máximo de pasos" in done["text"]


def _option(cmd, name):
    """Valores de una opción variádica hasta la siguiente opción."""
    i = cmd.index(name) + 1
    out = []
    while i < len(cmd) and not cmd[i].startswith("--"):
        out.append(cmd[i])
        i += 1
    return out


def test_follow_up_mode_is_read_only_with_board_tools():
    cmd = claude_code.build_claude_cmd("hola", execute=False, system_prompt="s", mcp_config="/tmp/m.json")
    assert cmd[_option_index(cmd, "--permission-mode")] == "dontAsk"
    assert _option(cmd, "--tools") == ["Read,Grep,Glob,Bash"]
    allowed = _option(cmd, "--allowedTools")
    assert not any(a.startswith(("Edit", "Write")) for a in allowed)
    assert "Read(./**)" in allowed and "Read" not in allowed
    assert "Bash(git commit:*)" not in allowed
    assert "Bash(git log:*)" in allowed and "mcp__taskboard" in allowed
    assert "Bash(git push:*)" in _option(cmd, "--disallowedTools")
    assert cmd[-2:] == ["--", "hola"]
    assert "--strict-mcp-config" in cmd


def test_develop_mode_edits_and_commits_but_never_pushes():
    cmd = claude_code.build_claude_cmd("x", execute=True, system_prompt="s", resume_session_id="s-1")
    allowed = _option(cmd, "--allowedTools")
    assert {"Edit(./**)", "Write(./**)", "Bash(git commit:*)", "Bash(pytest:*)"} <= set(allowed)
    assert not any("push" in a for a in allowed)
    assert {"Bash(git push:*)", "WebFetch", "mcp__taskboard__delete_task"} <= set(_option(cmd, "--disallowedTools"))
    assert _option(cmd, "--resume") == ["s-1"]
    assert "--mcp-config" not in cmd


def _option_index(cmd, name):
    return cmd.index(name) + 1


def test_env_has_no_api_secrets(monkeypatch):
    monkeypatch.setenv("JWT_SECRET", "jwt")
    monkeypatch.setenv("DEEPSEEK_API_KEY", "sk-x")
    monkeypatch.setenv("DATABASE_URL", "postgresql://u:p@db/x")
    monkeypatch.setattr(settings, "claude_code_oauth_token", "oat")
    monkeypatch.setattr(settings, "claude_code_home", "/home/agente")
    env = claude_code.agent_env()
    assert env["CLAUDE_CODE_OAUTH_TOKEN"] == "oat" and env["HOME"] == "/home/agente"
    assert not {"JWT_SECRET", "DEEPSEEK_API_KEY", "DATABASE_URL"} & set(env)


def test_mcp_config_is_private_and_removed(monkeypatch, tmp_path):
    server = tmp_path / "server.py"
    server.write_text("")
    monkeypatch.setattr(settings, "claude_code_mcp_server", str(server))
    with claude_code.taskboard_mcp_config("jwt-corto") as path:
        assert stat.S_IMODE(os.stat(path).st_mode) == 0o600
        cfg = json.loads(Path(path).read_text())["mcpServers"]["taskboard"]
        assert cfg["env"]["TASKBOARD_API_TOKEN"] == "jwt-corto"
        assert cfg["args"] == [str(server)]
    assert not Path(path).exists()


def test_mcp_config_missing_server(monkeypatch):
    monkeypatch.setattr(settings, "claude_code_mcp_server", "/no/existe.py")
    with claude_code.taskboard_mcp_config("t") as path:
        assert path is None


def _fake_cli(tmp_path, lines, *, exit_code=0, sleep=0):
    script = tmp_path / "claude"
    payload = "\n".join(json.dumps(x) for x in lines)
    script.write_text(
        f"#!{sys.executable}\nimport sys, time\n"
        f"print({payload!r}, flush=True)\ntime.sleep({sleep})\n"
        f"sys.stderr.write('detalle interno')\nsys.exit({exit_code})\n"
    )
    script.chmod(0o755)
    return str(script)


async def _collect(**kwargs):
    return [e async for e in claude_code.stream_claude_code("hola", **kwargs)]


def test_stream_runs_cli_in_workspace(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "claude_code_bin", _fake_cli(tmp_path, [INIT, TEXT, RESULT]))
    events = asyncio.run(_collect(workspace=tmp_path, execute=False, project_id=1, api_token=None))
    assert [e["kind"] for e in events] == ["init", "text", "done"]


def test_stream_hides_cli_errors(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "claude_code_bin", _fake_cli(tmp_path, [INIT], exit_code=1))
    events = asyncio.run(_collect(workspace=tmp_path, execute=False, project_id=1, api_token=None))
    assert events[-1] == {"kind": "error", "text": "Claude Code falló (detalle en los logs del API)."}


def test_stream_timeout_kills_process(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "claude_code_bin", _fake_cli(tmp_path, [INIT], sleep=5))
    monkeypatch.setattr(settings, "claude_code_timeout_sec", 0.5)
    with pytest.raises(TimeoutError):
        asyncio.run(_collect(workspace=tmp_path, execute=False, project_id=1, api_token=None))


def test_missing_workspace(tmp_path):
    with pytest.raises(FileNotFoundError):
        asyncio.run(_collect(workspace=tmp_path / "no", execute=False, project_id=1, api_token=None))


def test_run_claude_code_returns_result_or_raises(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "claude_code_bin", _fake_cli(tmp_path, [INIT, RESULT]))
    assert asyncio.run(claude_code.run_claude_code("p", workspace=tmp_path)) == "Hecho"
    failed = {**RESULT, "is_error": True, "result": "sin saldo"}
    monkeypatch.setattr(settings, "claude_code_bin", _fake_cli(tmp_path, [INIT, failed]))
    with pytest.raises(RuntimeError):
        asyncio.run(claude_code.run_claude_code("p", workspace=tmp_path))
