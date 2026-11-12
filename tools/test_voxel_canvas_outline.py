#!/usr/bin/env python3
"""Run the headless voxel canvas-outline check inside the Godot project."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "godot" / "game"
SRC = Path(__file__).resolve().parent / "voxel_canvas_outline_check.gd"
DEST = GAME / "scripts" / "_tmp_voxel_canvas_outline.gd"
SCENE = GAME / "scenes" / "_tmp_voxel_canvas_outline.tscn"
SCENE_TEXT = """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/_tmp_voxel_canvas_outline.gd" id="1"]

[node name="Check" type="Node"]
script = ExtResource("1")
"""
CANDIDATES = [
    Path("/Applications/Godot.app/Contents/MacOS/Godot"),
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
    binary = godot_bin()
    if binary is None:
        print("FAIL voxel canvas outline: godot binary not found")
        return 1
    DEST.write_text(SRC.read_text(encoding="utf-8"), encoding="utf-8")
    SCENE.write_text(SCENE_TEXT, encoding="utf-8")
    env = os.environ.copy()
    ## Ensure env override does not force outline ON for the default-OFF assertion.
    env.pop("VOXEL_CANVAS_OUTLINE", None)
    try:
        proc = subprocess.run(
            [
                str(binary),
                "--path",
                str(GAME),
                "--headless",
                str(SCENE),
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
            timeout=40,
            env=env,
        )
    finally:
        DEST.unlink(missing_ok=True)
        SCENE.unlink(missing_ok=True)
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)
    combined = proc.stdout + proc.stderr
    if "SHADER ERROR" in combined or "Shader compilation failed" in combined:
        print("FAIL voxel canvas outline: shader compile")
        return 1
    if proc.returncode != 0 or "OK voxel canvas outline" not in proc.stdout:
        print("FAIL voxel canvas outline runner", proc.returncode)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
