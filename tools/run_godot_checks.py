#!/usr/bin/env python3
"""Optional Godot headless checks (tech-review Q1).

Runs a short set of living-line wrappers that copy `*_check.gd` into
`godot/game` as temp scenes (same pattern as `test_skill_cast.py`).

Usage (repo root):
  GODOT=/path/to/Godot python3 tools/run_godot_checks.py
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"

## Keep this list short — CI optional job budget.
## Prefer wrappers that still pass after host／skill_caster extracts.
## (skill_cast／shadow_clone／dark_side harnesses need a separate bind fix.)
CHECKS = (
	"test_shelf_sniper.py",
	"test_interact_glow.py",
	"test_difficulty.py",
)


def godot_bin() -> str | None:
	env = os.environ.get("GODOT", "").strip()
	if env and Path(env).exists():
		return env
	mac = Path("/Applications/Godot.app/Contents/MacOS/Godot")
	if mac.exists():
		return str(mac)
	return None


def main() -> int:
	godot = godot_bin()
	if not godot:
		print("FAIL: Godot not found (set GODOT=…)", file=sys.stderr)
		return 1
	env = os.environ.copy()
	env["GODOT"] = godot
	## Wrappers look for `godot` on PATH / fixed Linux paths — expose a shim.
	shim_dir = ROOT / ".tools" / "godot-shim"
	shim_dir.mkdir(parents=True, exist_ok=True)
	shim = shim_dir / "godot"
	if shim.exists() or shim.is_symlink():
		shim.unlink()
	shim.symlink_to(godot)
	env["PATH"] = str(shim_dir) + os.pathsep + env.get("PATH", "")
	failed: list[str] = []
	for name in CHECKS:
		path = TOOLS / name
		print(f"==> {name}")
		proc = subprocess.run([sys.executable, str(path)], cwd=ROOT, env=env)
		if proc.returncode != 0:
			failed.append(name)
	if failed:
		print("FAIL godot checks")
		for f in failed:
			print(f"  - {f}")
		return 1
	print(f"OK godot checks ({len(CHECKS)} wrappers)")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
