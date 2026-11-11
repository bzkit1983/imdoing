#!/usr/bin/env bash
# M3 smoke: GodotSteam class load + SessionService steam/LAN gates.
# Usage (repo root): ./tools/m3_steam_smoke.sh
# Dual-account invite is NOT covered — needs Steam client + second account (see docs/alpha/godotsteam-setup.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT" ]]; then
  echo "FAIL: Godot not found at $GODOT (set GODOT=...)" >&2
  exit 1
fi
PROBE="$(mktemp /tmp/m3_smoke.XXXXXX.gd)"
trap 'rm -f "$PROBE"' EXIT
cat >"$PROBE" <<'EOF'
extends SceneTree
func _initialize() -> void:
	await process_frame
	await process_frame
	var fail := 0
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		print("FAIL SteamMultiplayerPeer missing")
		fail += 1
	else:
		print("OK SteamMultiplayerPeer")
	if not Engine.has_singleton("Steam"):
		print("FAIL Steam singleton missing")
		fail += 1
	else:
		print("OK Steam singleton")
	var ss = root.get_node_or_null("/root/SessionService")
	if ss == null:
		print("FAIL SessionService missing")
		quit(2)
		return
	if not ss.steam_available():
		print("FAIL steam_available=false")
		fail += 1
	else:
		print("OK steam_available")
	ss.create_room(1)
	if ss.is_networked() or ss.is_lan():
		print("FAIL local room should not be networked/lan")
		fail += 1
	else:
		print("OK local transport gate")
	ss.close()
	var lan_err: String = ss.host_lan(1)
	if lan_err != "":
		print("FAIL host_lan=", lan_err)
		fail += 1
	elif not ss.is_networked() or not ss.is_lan():
		print("FAIL lan gates after host_lan")
		fail += 1
	else:
		print("OK host_lan networked+lan")
	ss.close()
	var steam_err: String = await ss.host_steam(1)
	if steam_err in ["steam_not_running", "steam_not_installed", "steam_outdated"] or steam_err.begins_with("steam_init_"):
		print("SKIP host_steam (Steam client / install): ", steam_err)
	elif steam_err != "":
		print("FAIL host_steam=", steam_err)
		fail += 1
	else:
		print("OK host_steam lobby=", ss.steam_lobby_id, " networked=", ss.is_networked())
		ss.close()
	if fail > 0:
		print("M3_SMOKE FAIL count=", fail)
		quit(1)
	print("M3_SMOKE PASS (invite dual-account still manual)")
	quit(0)
EOF
cd "$ROOT/godot/game"
"$GODOT" --headless --path . -s "$PROBE"
