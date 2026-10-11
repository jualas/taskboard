"""Eventos tool_call reales del CLI Cursor Agent (stream-json, versión 2026.10)."""

import json

from app.cursor_agent import parse_agent_stream_line

READ_STARTED = {
    "type": "tool_call",
    "subtype": "started",
    "call_id": "tool_1",
    "tool_call": {
        "readToolCall": {"args": {"path": "/s/ws/a.txt"}},
        "hookAdditionalContexts": [],
        "toolCallId": "tool_1",
    },
    "session_id": "s1",
}
SHELL_STARTED = {
    "type": "tool_call",
    "subtype": "started",
    "call_id": "tool_2",
    "tool_call": {
        "shellToolCall": {
            "args": {"command": "ls -la /s/ws", "workingDirectory": "", "timeout": 30000, "simpleCommands": ["ls"]}
        },
        "toolCallId": "tool_2",
    },
    "session_id": "s1",
}


def _parse(obj):
    return parse_agent_stream_line(json.dumps(obj))


def test_read_tool_shows_path():
    assert _parse(READ_STARTED) == {"kind": "tool", "text": "▸ read: /s/ws/a.txt", "tool": "read"}


def test_shell_tool_shows_command():
    assert _parse(SHELL_STARTED) == {"kind": "tool", "text": "▸ shell: ls -la /s/ws", "tool": "shell"}


def test_completed_event_is_not_repeated():
    completed = dict(READ_STARTED, subtype="completed")
    completed["tool_call"] = {"readToolCall": {"args": {"path": "/s/ws/a.txt"}, "result": {"success": {"content": "hola"}}}}
    assert _parse(completed) is None


def test_long_command_is_truncated_on_one_line():
    obj = json.loads(json.dumps(SHELL_STARTED))
    obj["tool_call"]["shellToolCall"]["args"]["command"] = "echo " + "x" * 500 + "\n&& rm -rf /tmp/y"
    text = _parse(obj)["text"]
    assert "\n" not in text
    assert text.endswith("…")
    assert len(text) < 260


def test_unknown_and_legacy_formats():
    assert _parse({"type": "tool_call", "tool_call": {"fooToolCall": {}}})["text"] == "▸ foo"
    assert _parse({"type": "tool", "tool_name": "grep"})["text"] == "▸ grep"
