#!/usr/bin/env python3
"""Run the headless self_service_operation check (was tools/test_self_service_operation.cjs)."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _godot_headless import run_check

if __name__ == "__main__":
	sys.exit(run_check("self_service_operation", "OK self service operation", timeout=90))
