#!/usr/bin/env bash
# J1 headless Performance sample (demo scene settle — not full dual-player load).
# Usage (repo root): ./tools/j1_perf_probe.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT" ]]; then
  echo "FAIL: Godot not found at $GODOT (set GODOT=...)" >&2
  exit 1
fi
exec "$GODOT" --headless --path "$ROOT/godot/game" --script "$ROOT/tools/j1_perf_probe.gd"
