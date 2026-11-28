#!/usr/bin/env python3
"""Run the headless fish-tank + Fishing Taro check inside the Godot project."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _godot_headless import run_check

if __name__ == "__main__":
	sys.exit(run_check("ops_fishing", "OK ops fishing", timeout=90))
