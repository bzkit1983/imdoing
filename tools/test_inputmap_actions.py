#!/usr/bin/env python3
"""Smoke-check that Controls action names stay wired in living-line scripts."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "godot" / "game"

REQUIRED_ACTIONS = [
    "move_up",
    "move_down",
    "move_left",
    "move_right",
    "interact",
    "cancel",
    "dash",
    "skill",
    "ult",
    "rotate",
]


def main() -> int:
    controls = (GAME / "scripts" / "controls.gd").read_text(encoding="utf-8")
    project = (GAME / "project.godot").read_text(encoding="utf-8")
    assert 'Controls="*res://scripts/controls.gd"' in project, "Controls autoload missing"
    for action in REQUIRED_ACTIONS:
        assert f'"{action}"' in controls or f":= \"{action}\"" in controls, action
        # constants use ACTION := "name"
        assert re.search(rf':= "{action}"', controls), f"const for {action}"
    player = (GAME / "scripts" / "player.gd").read_text(encoding="utf-8")
    assert "Controls.INTERACT" in player
    assert "Controls.move_vector()" in player
    assert "Controls.stick_vector()" in player
    assert "KEY_J" not in player
    assert "JOY_BUTTON_A" not in player
    assert "get_joy_axis(0" not in controls
    assert "get_joy_axis(0" not in player
    assert "JOY_ALL_DEVICES" in controls
    assert "ev.device = JOY_ALL_DEVICES" in controls
    assert "get_connected_joypads" in controls
    prep = (GAME / "scripts" / "prep_menu.gd").read_text(encoding="utf-8")
    assert "Controls.ROTATE" in prep
    assert "KEY_J" not in prep
    demo = (GAME / "scripts" / "demo.gd").read_text(encoding="utf-8")
    assert "Controls.CANCEL" in demo
    assert "KEY_J" not in demo
    control_doc = (ROOT / "docs" / "systemdesign" / "control.md").read_text(encoding="utf-8")
    assert "device = -1" in control_doc or "device` 為 **-1" in control_doc
    print("ok: InputMap actions wired (Controls autoload)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
