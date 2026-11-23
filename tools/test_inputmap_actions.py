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
    "bag_menu",
    "carry_menu",
    "ult",
    "rotate",
    "bag_slot_up",
    "bag_slot_right",
    "bag_slot_down",
    "bag_slot_left",
    "carry_prev",
    "carry_next",
    "skill_hot_1",
    "skill_hot_5",
]


def main() -> int:
    controls = (GAME / "scripts" / "controls.gd").read_text(encoding="utf-8")
    project = (GAME / "project.godot").read_text(encoding="utf-8")
    assert 'Controls="*res://scripts/controls.gd"' in project, "Controls autoload missing"
    for action in REQUIRED_ACTIONS:
        assert f'"{action}"' in controls or f':= "{action}"' in controls, action
        # constants use ACTION := "name"
        assert re.search(rf':= "{action}"', controls), f"const for {action}"
    player = (GAME / "scripts" / "player.gd").read_text(encoding="utf-8")
    assert "Controls.INTERACT" in player
    ## Seat-aware helpers (local coop / net); bare move_vector() is not used on player.
    assert "Controls.move_vector_for(seat_id)" in player
    assert "Controls.stick_vector_for(seat_id)" in player
    assert "KEY_J" not in player
    assert "JOY_BUTTON_A" not in player
    assert "get_joy_axis(0" not in controls
    assert "get_joy_axis(0" not in player
    assert "JOY_ALL_DEVICES" in controls
    assert "ev.device = JOY_ALL_DEVICES" in controls
    assert "get_connected_joypads" in controls
    assert "KEY_H" in controls and "KEY_SPACE" in controls and "KEY_K" in controls
    assert "CARRY_MENU" in controls
    ## Ambient Peek: D-Pad + arrows → bag_slot_*; not on move_*.
    assert "BAG_SLOT_UP" in controls
    assert "_ensure_joy_btn(BAG_SLOT_UP, JOY_BUTTON_DPAD_UP)" in controls
    assert "HOLD_OPEN_SEC" in controls
    assert "_migrate_ambient_peek_v1" in controls
    ## Move must not bind D-Pad (bag owns it).
    assert re.search(
        r'_ensure_action\(MOVE_UP[\s\S]*?\]\)',
        controls,
    )
    move_up_block = re.search(
        r'_ensure_action\(MOVE_UP, MOVE_DEADZONE, \[(.*?)\]\)',
        controls,
        re.S,
    )
    assert move_up_block is not None
    assert "JOY_BUTTON_DPAD" not in move_up_block.group(1)
    assert "KEY_UP" not in move_up_block.group(1)
    assert "JOY_BUTTON_LEFT_SHOULDER" in controls and "JOY_BUTTON_RIGHT_SHOULDER" in controls
    assert "player_bag_diamond.gd" in player
    assert "player_skill_pips.gd" in player
    assert "_on_carry_select_hold" in player
    assert "_tick_skill_right_stick" in player
    prep = (GAME / "scripts" / "prep_menu.gd").read_text(encoding="utf-8")
    assert "Controls.ROTATE" in prep
    assert "KEY_J" not in prep
    demo = (GAME / "scripts" / "demo.gd").read_text(encoding="utf-8")
    assert "Controls.CANCEL" in demo
    assert "KEY_J" not in demo
    control_doc = (ROOT / "docs" / "systemdesign" / "control.md").read_text(encoding="utf-8")
    assert "device = -1" in control_doc or "device` 為 **-1" in control_doc
    assert "長按" in control_doc and "D-Pad" in control_doc
    print("ok: InputMap actions wired (Controls autoload)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
