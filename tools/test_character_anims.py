#!/usr/bin/env python3
"""Sanity-check Alpha character anim sprites + manifest + props."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "godot" / "game" / "art" / "sprites"
MANIFEST = SPRITES / "anim_manifest.json"
PROPS = SPRITES / "props_manifest.json"

REQUIRED = {
    "player": [
        "idle", "walk", "walk_carry", "run", "dash", "clean", "fight",
        "checkout", "slip", "down", "restock", "cast", "deliver",
    ],
    "customer": ["idle", "walk", "angry", "leave"],
    "customer_hurry": ["idle", "walk", "angry", "leave"],
    "customer_slow": ["idle", "walk", "angry", "leave"],
    "thief": ["idle", "walk", "fight", "leave", "fly"],
    "clerk_cashier": ["idle", "walk", "walk_carry", "checkout"],
    "clerk_restock": ["idle", "walk", "walk_carry", "restock"],
}

FX_REQUIRED = ["suck", "spray", "coin", "combo", "timestop", "clean_spark", "skid"]
SHELF_CATS = ["dry", "frozen", "ice"]


def main() -> int:
    if not MANIFEST.exists():
        print("missing", MANIFEST)
        return 1
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    chars = data.get("characters", {})
    errors: list[str] = []
    for cid, anims in REQUIRED.items():
        if cid not in chars:
            errors.append(f"manifest missing character {cid}")
            continue
        for anim in anims:
            if anim not in chars[cid]:
                errors.append(f"{cid} missing anim {anim}")
                continue
            n = int(chars[cid][anim]["frames"])
            for facing in range(4):
                for fi in range(n):
                    path = SPRITES / f"{cid}_{anim}_{facing}_{fi}.png"
                    if not path.exists():
                        errors.append(f"missing {path.name}")
    if not PROPS.exists():
        errors.append(f"missing {PROPS.name}")
    else:
        props = json.loads(PROPS.read_text(encoding="utf-8"))
        for cat in SHELF_CATS:
            for fill in range(4):
                for facing in range(4):
                    path = SPRITES / f"shelf_{cat}_fill_{fill}_{facing}.png"
                    if not path.exists():
                        errors.append(f"missing {path.name}")
        for dirt in ("trash", "puddle", "vomit"):
            for stage in range(3):
                path = SPRITES / f"{dirt}_clean_{stage}_0.png"
                if not path.exists():
                    errors.append(f"missing {path.name}")
        fx_meta = props.get("fx", {})
        for fx in FX_REQUIRED:
            if fx not in fx_meta:
                errors.append(f"props missing fx {fx}")
                continue
            n = int(fx_meta[fx]["frames"])
            for fi in range(n):
                path = SPRITES / f"fx_{fx}_{fi}.png"
                if not path.exists():
                    errors.append(f"missing {path.name}")
    if errors:
        print("FAIL")
        for e in errors[:40]:
            print(" ", e)
        if len(errors) > 40:
            print(f"  … +{len(errors) - 40} more")
        return 1
    print(
        "OK character anims",
        sum(len(v) for v in REQUIRED.values()),
        "anim slots + shelf fill + dirt clean + fx",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
