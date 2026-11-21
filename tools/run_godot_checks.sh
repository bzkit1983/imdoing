#!/usr/bin/env bash
# Optional Godot headless checks (tech-review Q1).
# Usage (repo root): GODOT=/path/to/Godot ./tools/run_godot_checks.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT" ]]; then
  echo "FAIL: Godot not found at $GODOT (set GODOT=...)" >&2
  exit 1
fi
export GODOT
exec python3 "$ROOT/tools/run_godot_checks.py"
