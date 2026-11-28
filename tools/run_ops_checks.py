#!/usr/bin/env python3
"""Ops-day headless checks (tech-review R1 / #149).

Covers elite clerks, cooked stall, fishing／fish tank, portals, and
self_cashier furniture. Also re-runs the existing self_checkout skill
wrappers named in the issue acceptance criteria.

Usage (repo root):
  GODOT=/path/to/Godot python3 tools/run_ops_checks.py
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))
from _godot_headless import ensure_project_imported  # noqa: E402


## #149 harnesses + issue-cited skill wrappers (all Python／Godot headless).
PY_CHECKS = (
	"test_portal_pair.py",
	"test_cooked_stall.py",
	"test_ops_fishing.py",
	"test_self_cashier_furniture.py",
	"test_elite_clerk_ops.py",
	"test_self_checkout.py",
	"test_self_service_operation.py",
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
	env["GODOT_BIN"] = godot
	shim_dir = ROOT / ".tools" / "godot-shim"
	shim_dir.mkdir(parents=True, exist_ok=True)
	shim = shim_dir / "godot"
	if shim.exists() or shim.is_symlink():
		shim.unlink()
	shim.symlink_to(godot)
	env["PATH"] = str(shim_dir) + os.pathsep + env.get("PATH", "")
	steam_linux = ROOT / "godot" / "game" / "addons" / "godotsteam" / "linux64"
	if steam_linux.is_dir():
		prev = env.get("LD_LIBRARY_PATH", "")
		env["LD_LIBRARY_PATH"] = str(steam_linux) + (os.pathsep + prev if prev else "")
	if ensure_project_imported(godot) != 0:
		return 1

	failed: list[str] = []
	for name in PY_CHECKS:
		path = TOOLS / name
		print(f"==> {name}")
		proc = subprocess.run([sys.executable, str(path)], cwd=ROOT, env=env)
		if proc.returncode != 0:
			failed.append(name)

	if failed:
		print("FAIL ops checks")
		for f in failed:
			print(f"  - {f}")
		return 1
	print(f"OK ops checks ({len(PY_CHECKS)} wrappers)")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
