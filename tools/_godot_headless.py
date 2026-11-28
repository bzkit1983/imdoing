"""Shared helper: copy a tools/*_check.gd into godot/game and run headless."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "godot" / "game"
TOOLS = Path(__file__).resolve().parent
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


def run_check(stem: str, ok_token: str, timeout: int = 60) -> int:
	"""stem e.g. `portal_pair` → tools/portal_pair_check.gd → OK portal pair."""
	binary = godot_bin()
	if binary is None:
		print(f"FAIL {stem}: godot binary not found")
		return 1
	src = TOOLS / f"{stem}_check.gd"
	dest = GAME / "scripts" / f"_tmp_{stem}.gd"
	scene = GAME / "scenes" / f"_tmp_{stem}.tscn"
	scene_text = (
		'[gd_scene load_steps=2 format=3]\n\n'
		f'[ext_resource type="Script" path="res://scripts/_tmp_{stem}.gd" id="1"]\n\n'
		'[node name="Check" type="Node"]\n'
		'script = ExtResource("1")\n'
	)
	dest.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
	scene.write_text(scene_text, encoding="utf-8")
	try:
		proc = subprocess.run(
			[str(binary), "--path", str(GAME), "--headless", str(scene)],
			cwd=ROOT,
			text=True,
			capture_output=True,
			check=False,
			timeout=timeout,
		)
	finally:
		dest.unlink(missing_ok=True)
		scene.unlink(missing_ok=True)
		Path(str(dest) + ".uid").unlink(missing_ok=True)
	sys.stdout.write(proc.stdout)
	sys.stderr.write(proc.stderr)
	if "SCRIPT ERROR" in (proc.stderr or ""):
		print(f"FAIL {stem} runner: SCRIPT ERROR in stderr")
		return 1
	if proc.returncode != 0 or ok_token not in proc.stdout:
		print(f"FAIL {stem} runner", proc.returncode)
		return 1
	return 0
