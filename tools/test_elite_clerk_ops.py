#!/usr/bin/env python3
"""Run the headless elite-clerk ops check inside the Godot project."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _godot_headless import run_check

if __name__ == "__main__":
	sys.exit(run_check("elite_clerk_ops", "OK elite clerk ops", timeout=90))
