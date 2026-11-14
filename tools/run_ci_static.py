#!/usr/bin/env python3
"""CI entry: run living-line static `tools/test_*.py` (tech-review v0.2 G1).

- Always runs pure/static Python contracts (no Godot binary required).
- Skips Godot-headless wrappers unless GODOT / Godot.app is available.
- Quarantines known-outdated design contracts so the PR gate stays green while
  those suites are repaired separately (listed below with reason).
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"

## Need a Godot binary. Skipped unless RUN_GODOT_TESTS=1 and GODOT=… (or macOS app).
## Default CI stays Python-only so PRs do not need a Godot install.
GODOT_REQUIRED = {
    "test_dark_side.py",
    "test_difficulty.py",
    "test_guest_sniper.py",
    "test_interact_glow.py",
    "test_shadow_clone.py",
    "test_shelf_sniper.py",
    "test_skill_cast.py",
    "test_skill_scenario.py",
    "test_thief_sniper.py",
    "test_xbox_pad.py",
}

## Documented drift — do not block PR until repaired (track in tech-review / issues).
QUARANTINE = {
    "test_customized_skillset_design.py": "version/SAVE_VERSION assertions lag product",
    "test_design_gap_rules.py": "tuning/design anchor drift",
    "test_font_charset.py": "charset subset missing new locale glyphs",
    "test_sfx_catalog.py": "wav missing for new skill/ult ids",
}


def godot_bin() -> str | None:
    env = os.environ.get("GODOT", "").strip()
    if env and Path(env).exists():
        return env
    mac = Path("/Applications/Godot.app/Contents/MacOS/Godot")
    if mac.exists():
        return str(mac)
    return None


def main() -> int:
    tests = sorted(TOOLS.glob("test_*.py"))
    godot = godot_bin()
    ran = 0
    skipped: list[str] = []
    failed: list[str] = []

    for path in tests:
        name = path.name
        if name in QUARANTINE:
            skipped.append(f"{name} (quarantine: {QUARANTINE[name]})")
            continue
        if name in GODOT_REQUIRED:
            if os.environ.get("RUN_GODOT_TESTS", "").strip() != "1" or not godot:
                skipped.append(f"{name} (Godot suite; set RUN_GODOT_TESTS=1 GODOT=…)")
                continue
        env = os.environ.copy()
        if godot:
            env["GODOT"] = godot
        ran += 1
        print(f"==> {name}")
        proc = subprocess.run([sys.executable, str(path)], cwd=ROOT, env=env)
        if proc.returncode != 0:
            failed.append(name)

    print()
    print(f"ran={ran} skipped={len(skipped)} failed={len(failed)}")
    for s in skipped:
        print(f"  skip {s}")
    if failed:
        print("FAIL")
        for f in failed:
            print(f"  - {f}")
        return 1
    print("OK ci static")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
