#!/usr/bin/env python3
"""Assert game font charset covers Loc zh_TW and SFX catalog triggers."""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARSET = ROOT / "godot" / "game" / "fonts" / "charset_game.txt"
LOCALE = ROOT / "godot" / "game" / "locale" / "strings.csv"
CATALOG = ROOT / "godot" / "game" / "scripts" / "sfx_catalog.gd"
FONT = ROOT / "godot" / "game" / "fonts" / "NotoSansTC-Game.otf"


def main() -> int:
    if not CHARSET.is_file():
        print("FAIL missing charset_game.txt")
        return 1
    cs = set(CHARSET.read_text(encoding="utf-8"))
    missing: list[str] = []
    with LOCALE.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            for c in row.get("zh_TW", ""):
                if ord(c) > 127 and c not in cs:
                    missing.append(f"locale:{row['key']}:{c}")
    for m in re.finditer(r'"trigger": "([^"]*)"', CATALOG.read_text(encoding="utf-8")):
        for c in m.group(1):
            if ord(c) > 127 and c not in cs:
                missing.append(f"trigger:{m.group(1)[:24]}:{c}")
    if missing:
        print("FAIL charset missing chars (rebuild: python3 tools/fonts/subset_notosans_tc.py)")
        for e in missing[:40]:
            print(" ", e)
        if len(missing) > 40:
            print(f"  … +{len(missing) - 40} more")
        return 1
    if not FONT.is_file() or FONT.stat().st_size < 50_000:
        print("FAIL missing or tiny NotoSansTC-Game.otf")
        return 1
    print(f"OK charset covers locale + SFX triggers ({len(cs)} chars, font {FONT.stat().st_size // 1024} KiB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
