#!/usr/bin/env python3
"""Round-trip check for the save.json shape used by game_state.gd (SAVE_VERSION 1).

Does not run Godot; validates that a fixture matching to_dict() survives
JSON encode/decode with required keys and types.
"""

from __future__ import annotations

import json
import sys
from copy import deepcopy

SAVE_VERSION = 1
REQUIRED = {
    "version",
    "scenario",
    "money",
    "xp",
    "level",
    "unspent",
    "base_str",
    "base_agi",
    "base_int",
    "str_stat",
    "agi_stat",
    "int_stat",
    "developed",
    "stock",
    "owned",
    "placed",
    "shop_scale",
    "grid_w",
    "grid_h",
    "clerks",
    "slots",
    "ult_id",
    "day_procurement",
    "last_loss",
    "level_note",
}


def sample() -> dict:
    return {
        "version": SAVE_VERSION,
        "scenario": 2,
        "money": 9000,
        "xp": 50,
        "level": 5,
        "unspent": 2,
        "base_str": 10,
        "base_agi": 10,
        "base_int": 10,
        "str_stat": 12,
        "agi_stat": 14,
        "int_stat": 11,
        "developed": {"can": True, "snack": True},
        "stock": {"can": 3, "snack": 1},
        "owned": {"cashier": 1, "shelf_dry_12": 2},
        "placed": [
            {"type": "cashier", "x": 4, "y": 8, "rot": 0, "w": 2, "h": 1},
            {"type": "shelf_dry_12", "x": 1, "y": 2, "rot": 0, "w": 2, "h": 1},
        ],
        "shop_scale": 2,
        "grid_w": 15,
        "grid_h": 15,
        "clerks": [{"role": "restock", "register": 0}],
        "slots": ["carry_boost", "move_boost", "", "", ""],
        "ult_id": "the_world",
        "day_procurement": 120,
        "last_loss": False,
        "level_note": "",
    }


def validate(data: dict) -> None:
    missing = REQUIRED - set(data)
    assert not missing, f"missing keys: {missing}"
    assert int(data["version"]) == SAVE_VERSION
    assert isinstance(data["developed"], dict)
    assert isinstance(data["stock"], dict)
    assert isinstance(data["owned"], dict)
    assert isinstance(data["placed"], list)
    assert len(data["slots"]) == 5
    assert isinstance(data["clerks"], list)
    for it in data["placed"]:
        for k in ("type", "x", "y", "rot", "w", "h"):
            assert k in it


def main() -> int:
    original = sample()
    text = json.dumps(original, ensure_ascii=False, indent="\t")
    loaded = json.loads(text)
    validate(loaded)
    assert loaded == original
    # Simulate a too-new version rejection rule used in from_dict.
    newer = deepcopy(loaded)
    newer["version"] = SAVE_VERSION + 1
    assert int(newer["version"]) > SAVE_VERSION
    print("ok: save.json schema round-trip (version %d)" % SAVE_VERSION)
    return 0


if __name__ == "__main__":
    sys.exit(main())
