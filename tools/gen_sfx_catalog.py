#!/usr/bin/env python3
"""Regenerate godot/game/scripts/sfx_catalog.gd from soundeffects.md.

Adds `trigger` (mapped gameplay action / effect) for the SFX test page.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "systemdesign" / "soundeffects.md"
OUT = ROOT / "godot" / "game" / "scripts" / "sfx_catalog.gd"
TXT = ROOT / "godot" / "game" / "audio" / "sfx_catalog.txt"

ROW_RE = re.compile(
    r"\|\s*`?(sfx_[a-z0-9_]+)`?\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*(P[012])\s*\|"
)


def group_of(sid: str) -> str:
    rest = sid[4:]
    for g in (
        "move", "box", "shelf", "checkout", "clean", "fight", "ko", "thief",
        "loot", "guest", "skill", "ult", "clerk", "phase", "early", "dirt", "ui",
    ):
        if rest.startswith(g + "_") or rest == g:
            return g
    return "ui"


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main() -> int:
    text = DOC.read_text(encoding="utf-8")
    rows = ROW_RE.findall(text)
    if not rows:
        print("FAIL: no rows in", DOC, file=sys.stderr)
        return 1
    order = {"P0": 0, "P1": 1, "P2": 2}
    entries = []
    for sid, trigger, _timbre, pri in rows:
        entries.append(
            (sid, pri, f"res://audio/sfx/{sid}.wav", group_of(sid), trigger.strip())
        )
    entries.sort(key=lambda e: (order[e[1]], e[0]))

    lines = [
        "extends RefCounted",
        "## Alpha SFX catalog — IDs match docs/systemdesign/soundeffects.md.",
        "## Assets: res://audio/sfx/<id>.wav (procedural placeholders; replace later).",
        "## `trigger` = mapped gameplay action / effect (from soundeffects.md).",
        "",
        '## Each entry: { "id", "priority", "path", "group", "trigger" }',
        "const ENTRIES: Array[Dictionary] = [",
    ]
    for sid, pri, path, group, trigger in entries:
        lines.append(
            '\t{"id": "%s", "priority": "%s", "path": "%s", "group": "%s", "trigger": "%s"},'
            % (sid, pri, path, group, esc(trigger))
        )
    lines += [
        "]",
        "",
        "",
        "static func all_ids() -> PackedStringArray:",
        "\tvar ids := PackedStringArray()",
        "\tfor e in ENTRIES:",
        '\t\tids.append(String(e["id"]))',
        "\treturn ids",
        "",
        "",
        "static func entry(id: String) -> Dictionary:",
        "\tfor e in ENTRIES:",
        '\t\tif String(e["id"]) == id:',
        "\t\t\treturn e",
        "\treturn {}",
        "",
        "",
        "static func path_for(id: String) -> String:",
        "\tvar e := entry(id)",
        "\tif e.is_empty():",
        '\t\treturn ""',
        '\treturn String(e["path"])',
        "",
        "",
        "static func trigger_for(id: String) -> String:",
        "\tvar e := entry(id)",
        "\tif e.is_empty():",
        '\t\treturn ""',
        '\treturn String(e.get("trigger", ""))',
        "",
        "",
        "static func by_priority(pri: String) -> Array[Dictionary]:",
        "\tvar out: Array[Dictionary] = []",
        "\tfor e in ENTRIES:",
        '\t\tif String(e["priority"]) == pri:',
        "\t\t\tout.append(e)",
        "\treturn out",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")

    tlines = ["# id\tpriority\tpath\ttrigger"]
    for sid, pri, path, _group, trigger in entries:
        tlines.append(f"{sid}\t{pri}\t{path}\t{trigger}")
    TXT.write_text("\n".join(tlines) + "\n", encoding="utf-8")
    print(f"Wrote {len(entries)} catalog entries → {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
