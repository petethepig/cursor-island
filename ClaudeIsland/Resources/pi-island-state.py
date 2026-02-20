#!/usr/bin/env python3
"""
Claude Island Hook — Pi Coding Agent
- Reads Pi hook format (camelCase events, same as Cursor)
- Sends normalized session state to ClaudeIsland.app via Unix socket
- Fire-and-forget only
- MUST be fully resilient: never write to stderr, always exit 0
"""
import json
import os
import socket
import sys

# Suppress ALL stderr output
sys.stderr = open(os.devnull, "w")

SOCKET_PATH = "/tmp/claude-island.sock"
TIMEOUT_SECONDS = 5


def send_event(state):
    """Send event to app (fire-and-forget)."""
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(TIMEOUT_SECONDS)
        sock.connect(SOCKET_PATH)
        sock.sendall(json.dumps(state).encode())
        sock.close()
    except Exception:
        pass


def parse_input(raw):
    """Best-effort JSON extraction from potentially malformed stdin."""
    # 1. Try direct parse
    try:
        return json.loads(raw)
    except Exception:
        pass

    # 2. Extract the outermost { ... } and try parsing that
    start = raw.find("{")
    end = raw.rfind("}")
    if start >= 0 and end > start:
        try:
            return json.loads(raw[start : end + 1])
        except Exception:
            pass

    # 3. Try stripping common trailing garbage by finding balanced braces
    if start >= 0:
        depth = 0
        in_string = False
        escape = False
        for i in range(start, len(raw)):
            c = raw[i]
            if escape:
                escape = False
                continue
            if c == "\\":
                escape = True
                continue
            if c == '"' and not escape:
                in_string = not in_string
                continue
            if in_string:
                continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    try:
                        return json.loads(raw[start : i + 1])
                    except Exception:
                        pass
                    break

    return None


def main():
    try:
        raw = sys.stdin.read()
    except Exception:
        return

    data = parse_input(raw)
    if data is None:
        return

    # Pi format: session_id is the full JSONL file path, workspace_roots has cwd
    raw_session_id = data.get("session_id") or ""
    event = data.get("hook_event_name", "")
    workspace_roots = data.get("workspace_roots") or []
    cwd = data.get("cwd") or (workspace_roots[0] if workspace_roots else "")
    tool_input = data.get("tool_input", {})
    if isinstance(tool_input, str):
        try:
            tool_input = json.loads(tool_input) if tool_input else {}
        except Exception:
            tool_input = {}

    # Pi sends session_id as the full file path to the JSONL session file.
    # Extract the UUID from the filename (format: <timestamp>_<uuid>.jsonl)
    # and pass the full path as transcript_path.
    transcript_path = ""
    session_id = raw_session_id
    if raw_session_id and "/" in raw_session_id:
        transcript_path = raw_session_id
        basename = os.path.basename(raw_session_id)
        # Strip .jsonl extension
        if basename.endswith(".jsonl"):
            basename = basename[:-6]
        # Extract UUID after the timestamp prefix (timestamp_uuid)
        parts = basename.split("_", 1)
        if len(parts) == 2:
            session_id = parts[1]
        else:
            session_id = basename

    if not session_id or session_id == "ephemeral":
        session_id = "unknown"

    # Build state object
    state = {
        "session_id": session_id,
        "cwd": cwd,
        "event": event,
        "agent_type": "pi",
        "status": "unknown",
    }

    if transcript_path:
        state["transcript_path"] = transcript_path

    # Extract tool_use_id for tool tracking
    tool_use_id = data.get("tool_use_id", "")

    # Map hook event names to status
    if event == "beforeSubmitPrompt":
        state["status"] = "processing"

    elif event == "preToolUse":
        state["status"] = "running_tool"
        state["tool"] = data.get("tool_name")
        state["tool_input"] = tool_input
        if tool_use_id:
            state["tool_use_id"] = tool_use_id
        if state.get("tool") == "Shell":
            state["tool_display"] = "Bash"

    elif event == "postToolUse":
        state["status"] = "processing"
        state["tool"] = data.get("tool_name")
        state["tool_input"] = tool_input
        if tool_use_id:
            state["tool_use_id"] = tool_use_id
        if state.get("tool") == "Shell":
            state["tool_display"] = "Bash"

    elif event == "stop":
        state["status"] = "waiting_for_input"

    elif event == "subagentStop":
        state["status"] = "waiting_for_input"

    elif event == "sessionStart":
        state["status"] = "waiting_for_input"

    elif event == "sessionEnd":
        state["status"] = "ended"

    elif event == "preCompact":
        state["status"] = "compacting"

    else:
        state["status"] = "unknown"

    send_event(state)


if __name__ == "__main__":
    try:
        main()
        print("{}")
    except Exception:
        pass
