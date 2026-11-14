#!/usr/bin/env bash
# M3 smoke: GodotSteam class load + SessionService steam/LAN gates + §13.6 invite parse.
# Usage (repo root): ./tools/m3_steam_smoke.sh
# Dual-account Overlay invite is NOT covered — needs Steam client + second account
# (see docs/alpha/godotsteam-setup.md §13.6).
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
const NetTransport = preload("res://scripts/session/net_transport.gd")
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
	## §13.6: cmdline／connect string parse (no Steam client required).
	var parsed := NetTransport.parse_connect_lobby_args(PackedStringArray(["+connect_lobby", "109775241012345678"]))
	if parsed != 109775241012345678:
		print("FAIL parse_connect_lobby_args got=", parsed)
		fail += 1
	else:
		print("OK parse_connect_lobby_args")
	var parsed2 := NetTransport.parse_lobby_id_from_connect("1097752410999")
	if parsed2 != 1097752410999:
		print("FAIL parse_lobby_id_from_connect got=", parsed2)
		fail += 1
	else:
		print("OK parse_lobby_id_from_connect")
	var inv_err: String = ss.invite_steam_friends()
	if inv_err != "lobby_invalid":
		print("FAIL invite_steam_friends before host expected lobby_invalid got=", inv_err)
		fail += 1
	else:
		print("OK invite_steam_friends gate")
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
		## Busy invite while hosted should not overwrite pending.
		ss.pending_steam_lobby_id = 0
		ss._on_steam_invite_lobby(42)
		if ss.pending_steam_lobby_id != 0:
			print("FAIL invite while networked should not set pending")
			fail += 1
		else:
			print("OK invite_busy while networked")
		var inv2: String = ss.invite_steam_friends()
		if inv2 != "":
			print("SKIP invite_overlay (may fail without Overlay): ", inv2)
		else:
			print("OK invite_steam_friends overlay call")
		ss.close()
	if fail > 0:
		print("M3_SMOKE FAIL count=", fail)
		quit(1)
	print("M3_SMOKE PASS (Overlay dual-account still manual — see godotsteam-setup.md)")
	quit(0)
EOF
cd "$ROOT/godot/game"
"$GODOT" --headless --path . -s "$PROBE"
