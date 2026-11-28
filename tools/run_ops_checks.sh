#!/usr/bin/env bash
# Ops-day Godot headless suite (R1 / #149).
# Usage (repo root): GODOT=/path/to/Godot ./tools/run_ops_checks.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/tools/run_ops_checks.py"
