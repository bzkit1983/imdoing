"""Shared helper: copy a tools/*_check.gd into godot/game and run headless."""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "godot" / "game"
TOOLS = Path(__file__).resolve().parent
STEAM_LINUX64 = GAME / "addons" / "godotsteam" / "linux64"
CANDIDATES = [
	Path("/tmp/godot-setup/Godot_v4.7.2-stable_linux.x86_64"),
	Path("/usr/local/bin/godot"),
	Path("/usr/bin/godot"),
]


def godot_bin() -> Path | None:
	env = os.environ.get("GODOT", "").strip()
	if env and Path(env).is_file():
		return Path(env)
	for path in CANDIDATES:
		if path.is_file():
			return path
	found = shutil.which("godot")
	return Path(found) if found else None


def _run_env() -> dict[str, str]:
	env = os.environ.copy()
	if STEAM_LINUX64.is_dir():
		prev = env.get("LD_LIBRARY_PATH", "")
		env["LD_LIBRARY_PATH"] = str(STEAM_LINUX64) + (os.pathsep + prev if prev else "")
	return env


def ensure_project_imported(binary: str | Path, timeout: int = 1200) -> int:
	"""Cold CI checkouts have no godot/game/.godot — import once before wrappers.

	Without this, the first headless scene run burns a short timeout on ~10k
	asset imports and fails spuriously on Actions.
	"""
	imported = GAME / ".godot" / "imported"
	if imported.is_dir() and any(imported.iterdir()):
		return 0
	print("==> godot --import (warm .godot)")
	try:
		proc = subprocess.run(
			[str(binary), "--headless", "--path", str(GAME), "--import"],
			cwd=ROOT,
			text=True,
			capture_output=True,
			check=False,
			timeout=timeout,
			env=_run_env(),
		)
	except subprocess.TimeoutExpired:
		print("FAIL godot import: timeout")
		return 1
	## Import logs are huge — keep a short tail for CI diagnosis.
	tail = (proc.stderr or "")[-4000:]
	if tail.strip():
		sys.stderr.write(tail)
		if not tail.endswith("\n"):
			sys.stderr.write("\n")
	if proc.returncode != 0:
		print(f"FAIL godot import: exit {proc.returncode}")
		return 1
	print("OK godot import")
	return 0


def run_check(stem: str, ok_token: str, timeout: int = 180) -> int:
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
			env=_run_env(),
		)
	finally:
		dest.unlink(missing_ok=True)
		scene.unlink(missing_ok=True)
		Path(str(dest) + ".uid").unlink(missing_ok=True)
	sys.stdout.write(proc.stdout or "")
	sys.stderr.write(proc.stderr or "")
	## Steam／RID noise can print SCRIPT ERROR on Linux CI even when the check OK'd.
	if ok_token not in (proc.stdout or ""):
		if "SCRIPT ERROR" in (proc.stderr or ""):
			print(f"FAIL {stem} runner: SCRIPT ERROR in stderr (no OK token)")
		else:
			print(f"FAIL {stem} runner", proc.returncode)
		return 1
	if proc.returncode != 0:
		print(f"FAIL {stem} runner", proc.returncode)
		return 1
	return 0
