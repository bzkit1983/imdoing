#!/usr/bin/env python3
"""Sanity-check Alpha character anim sprites + manifest."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "godot" / "game" / "art" / "sprites"
MANIFEST = SPRITES / "anim_manifest.json"

REQUIRED = {
    "player": ["idle", "walk", "run", "dash", "clean", "fight", "checkout", "slip", "down", "restock"],
    "customer": ["idle", "walk", "angry", "leave"],
    "thief": ["idle", "walk", "fight", "leave", "fly"],
    "clerk_cashier": ["idle", "walk", "checkout"],
    "clerk_restock": ["idle", "walk", "restock"],
}


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
    if errors:
        print("FAIL")
        for e in errors[:40]:
            print(" ", e)
        if len(errors) > 40:
            print(f"  … +{len(errors) - 40} more")
        return 1
    print("OK character anims", sum(len(v) for v in REQUIRED.values()), "anim slots")
    return 0


if __name__ == "__main__":
    sys.exit(main())
