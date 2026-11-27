#!/usr/bin/env python3
"""Cursor hooks: remind agents to run tools/run_ci_static.py after CI-relevant edits.

Events (via .cursor/hooks.json):
  afterFileEdit       — mark session as needing CI if path is gate-relevant
  afterShellExecution — clear need when output shows OK ci static
  stop                — one follow-up remind if still needed (fail-open)

State lives under $TMPDIR/imdoing-ci-gate/<conversation_id>/ (not in the repo).
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

OK_MARK = "OK ci static"


def _state_dir(conversation_id: str) -> Path:
    safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in (conversation_id or "unknown"))
    d = Path(tempfile.gettempdir()) / "imdoing-ci-gate" / safe
    d.mkdir(parents=True, exist_ok=True)
    return d


def _is_ci_relevant(file_path: str) -> bool:
    p = file_path.replace("\\", "/")
    lower = p.lower()
    if "/godot/game/" in p or p.startswith("godot/game/") or lower.endswith("/godot/game"):
        return True
    base = Path(p).name
    if base.startswith("test_") and base.endswith(".py") and "/tools/" in p:
        return True
    if base in ("project.godot", "anim_manifest.json", "props_manifest.json"):
        return True
    if base in ("strings.csv", "data.csv") and "/locale/" in p:
        return True
    if base in ("controls.gd",) and "/godot/game/" in p:
        return True
    return False


def _emit(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj))
    sys.stdout.flush()


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        _emit({})
        return 0

    event = str(payload.get("hook_event_name") or payload.get("event") or "")
    conversation_id = str(
        payload.get("conversation_id")
        or payload.get("session_id")
        or "unknown"
    )
    state = _state_dir(conversation_id)
    touched = state / "touched"
    ci_ok = state / "ci_ok"

    if event == "afterFileEdit":
        path = str(payload.get("file_path") or "")
        if path and _is_ci_relevant(path):
            touched.write_text("1", encoding="utf-8")
            if ci_ok.exists():
                ci_ok.unlink()
        _emit({})
        return 0

    if event == "afterShellExecution":
        command = str(payload.get("command") or "")
        output = str(payload.get("output") or "")
        if "run_ci_static" in command and OK_MARK in output:
            ci_ok.write_text("1", encoding="utf-8")
            if touched.exists():
                touched.unlink()
        _emit({})
        return 0

    if event == "stop":
        status = str(payload.get("status") or "completed")
        loop_count = int(payload.get("loop_count") or 0)
        if (
            status == "completed"
            and loop_count == 0
            and touched.exists()
            and not ci_ok.exists()
        ):
            _emit(
                {
                    "followup_message": (
                        "CI-relevant files were edited this session but "
                        "`python3 tools/run_ci_static.py` did not report OK. "
                        "Run it now, fix any FAIL, then finish. "
                        "Do not suggest push until it passes."
                    )
                }
            )
            return 0
        _emit({})
        return 0

    _emit({})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
