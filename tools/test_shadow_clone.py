#!/usr/bin/env python3
"""Run the headless Multiple Shadow Clone check inside the Godot project."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "godot" / "game"
SRC = Path(__file__).resolve().parent / "shadow_clone_check.gd"
DEST = GAME / "scripts" / "_tmp_shadow_clone.gd"
SCENE = GAME / "scenes" / "_tmp_shadow_clone.tscn"
SCENE_TEXT = """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/_tmp_shadow_clone.gd" id="1"]

[node name="Check" type="Node"]
script = ExtResource("1")
"""
CANDIDATES = [
    Path("/tmp/godot-setup/Godot_v4.7.2-stable_linux.x86_64"),
    Path("/usr/local/bin/godot"),
    Path("/usr/bin/godot"),
]


def godot_bin() -> Path | None:
    for path in CANDIDATES:
        if path.is_file():
            return path
    found = shutil.which("godot")
    return Path(found) if found else None


def main() -> int:
    demo = (GAME / "scripts" / "demo.gd").read_text(encoding="utf-8")
    finish = demo.split("func _finish_day()", 1)[-1].split("func ", 1)[0]
    if "dismiss_shadow_clones" not in finish:
        print("FAIL closeout does not dismiss clones")
        return 1
    if finish.find("dismiss_shadow_clones") > finish.find("_return_unsold_to_warehouse"):
        print("FAIL clones must drop before unsold collect")
        return 1
    toss = demo.split("func _resolve_toss_landing", 1)[-1].split("func ", 1)[0]
    for name in ("_thief_for_toss", "_guest_for_toss", "_shelf_for_toss", "_clone_for_toss"):
        if name not in toss:
            print("FAIL toss missing", name)
            return 1
    if toss.find("_thief_for_toss") > toss.find("_guest_for_toss"):
        print("FAIL toss order thief must precede guest")
        return 1
    if toss.find("_guest_for_toss") > toss.find("_shelf_for_toss"):
        print("FAIL toss order guest must precede shelf")
        return 1
    if toss.find("_shelf_for_toss") > toss.find("_clone_for_toss"):
        print("FAIL toss order shelf must precede clone")
        return 1
    binary = godot_bin()
    if binary is None:
        print("FAIL shadow clone: godot binary not found")
        return 1
    DEST.write_text(SRC.read_text(encoding="utf-8"), encoding="utf-8")
    SCENE.write_text(SCENE_TEXT, encoding="utf-8")
    try:
        proc = subprocess.run(
            [str(binary), "--path", str(GAME), "--headless", str(SCENE)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
            timeout=60,
        )
    finally:
        DEST.unlink(missing_ok=True)
        SCENE.unlink(missing_ok=True)
        Path(str(DEST) + ".uid").unlink(missing_ok=True)
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)
    if proc.returncode != 0 or "OK shadow clone" not in proc.stdout:
        print("FAIL shadow clone runner", proc.returncode)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
