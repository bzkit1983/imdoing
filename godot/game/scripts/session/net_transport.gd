extends RefCounted
## Swappable MultiplayerPeer factory (multiplayer.md §6.1 / §12.1 / §13).
## Only SessionService constructs peers — gameplay never calls this directly.

const DEFAULT_PORT := 7777
## Peer cap only (host + remotes). Seat cap is SessionService.ROOM_MAX_SEATS —
## claim2 can fill 4 seats with fewer peers, so host must refuse extra peers.
const MAX_CLIENTS := 3
## Valve Spacewar — free Steamworks test App ID (multiplayer.md §13).
const STEAM_TEST_APP_ID := 480
## Steam.LOBBY_TYPE_FRIENDS_ONLY — invite／好友可見，非公開瀏覽。
const STEAM_LOBBY_FRIENDS_ONLY := 2
## Steam.RESULT_OK
const STEAM_RESULT_OK := 1
const STEAM_LOBBY_TIMEOUT_SEC := 12.0

static var _steam_inited: bool = false
## Invite／Join Game hooks bound once after Steam init (§13.6).
static var _invite_hooks_bound: bool = false
## Callable(lobby_id: int) — SessionService queues pending join.
static var _on_invite_lobby: Callable = Callable()


static func lan_available() -> bool:
	## Web has no bare ENet UDP.
	return not OS.has_feature("web")


static func steam_available() -> bool:
	## Requires GodotSteam (or equiv.) providing SteamMultiplayerPeer. Web never.
	if OS.has_feature("web"):
		return false
	return ClassDB.class_exists("SteamMultiplayerPeer")


static func steam_running() -> bool:
	if not steam_available():
		return false
	var steam := _steam_singleton()
	if steam == null:
		return false
	if steam.has_method("isSteamRunning"):
		return bool(steam.call("isSteamRunning"))
	return false


static func _steam_singleton() -> Object:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var n = (tree as SceneTree).root.get_node_or_null("/root/Steam")
		if n != null:
			return n
	if Engine.has_singleton("Steam"):
		return Engine.get_singleton("Steam")
	return null


static func _scene_tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	return loop as SceneTree


static func _apply_steam_app_id(app_id: int) -> void:
	## Editor／非 Steam 啟動時必須帶 App ID（§13 開發用 480）。
	OS.set_environment("SteamAppId", str(app_id))
	OS.set_environment("SteamGameId", str(app_id))
	if ProjectSettings.has_setting("steam/initialization/app_data/app_id"):
		ProjectSettings.set_setting("steam/initialization/app_data/app_id", app_id)
	if ProjectSettings.has_setting("steam/initialization/processes/embed_callbacks"):
		ProjectSettings.set_setting("steam/initialization/processes/embed_callbacks", true)


static func ensure_steam_init(app_id: int = STEAM_TEST_APP_ID) -> String:
	## Returns "" on ok, else error code. Safe to call repeatedly.
	## Do not hard-fail on isSteamRunning alone — try steamInitEx for a real status.
	if not steam_available():
		return "steam_unavailable"
	if _steam_inited:
		return ""
	var steam := _steam_singleton()
	if steam == null:
		return "steam_unavailable"
	_apply_steam_app_id(app_id)
	## GodotSteam 4.24: steamInitEx(app_id, embed_callbacks).
	## status: 0 OK, 1 other failure, 2 cannot connect (client not running), 3 client outdated.
	if steam.has_method("steamInitEx"):
		var result: Variant = steam.call("steamInitEx", app_id, true)
		if typeof(result) == TYPE_DICTIONARY:
			var status := int(result.get("status", -1))
			var verbal := String(result.get("verbal", "")).to_lower()
			if status == 0:
				_steam_inited = true
				return ""
			if status == 2:
				return "steam_not_running"
			if status == 3:
				return "steam_outdated"
			if "install directory" in verbal or "steam client" in verbal:
				return "steam_not_installed"
			if not steam_running():
				return "steam_not_running"
			return "steam_init_%d" % status
		_steam_inited = true
		return ""
	if steam.has_method("steamInit"):
		var ok: Variant = steam.call("steamInit", app_id, true)
		if typeof(ok) == TYPE_BOOL and not bool(ok):
			if not steam_running():
				return "steam_not_running"
			return "steam_init_failed"
		_steam_inited = true
		return ""
	return "steam_peer_api"


static func create_host(port: int = DEFAULT_PORT) -> Dictionary:
	## Returns {ok: bool, peer: MultiplayerPeer|null, error: String, port: int}.
	if not lan_available():
		return {"ok": false, "peer": null, "error": "web_no_enet", "port": port}
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return {"ok": false, "peer": null, "error": "create_server_%d" % err, "port": port}
	return {"ok": true, "peer": peer, "error": "", "port": port}


static func join_host(address: String, port: int = DEFAULT_PORT) -> Dictionary:
	## Returns {ok: bool, peer: MultiplayerPeer|null, error: String}.
	if not lan_available():
		return {"ok": false, "peer": null, "error": "web_no_enet"}
	var host := address.strip_edges()
	if host.is_empty():
		return {"ok": false, "peer": null, "error": "empty_address"}
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		return {"ok": false, "peer": null, "error": "create_client_%d" % err}
	return {"ok": true, "peer": peer, "error": ""}


static func create_steam_host() -> Dictionary:
	## Async. Returns {ok, peer, error, lobby_id}. Awaits lobby_created then host_with_lobby.
	var init_err := ensure_steam_init()
	if init_err != "":
		return {"ok": false, "peer": null, "error": init_err, "lobby_id": 0}
	var steam := _steam_singleton()
	var tree := _scene_tree()
	if steam == null or tree == null:
		return {"ok": false, "peer": null, "error": "steam_unavailable", "lobby_id": 0}
	var state := {"done": false, "result": 0, "lobby_id": 0}
	var on_created := func(connect_result: int, lobby_id: int) -> void:
		state["result"] = connect_result
		state["lobby_id"] = lobby_id
		state["done"] = true
	steam.connect("lobby_created", on_created)
	steam.call("createLobby", STEAM_LOBBY_FRIENDS_ONLY, 4)
	var deadline := Time.get_ticks_msec() + int(STEAM_LOBBY_TIMEOUT_SEC * 1000.0)
	while not bool(state["done"]) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if steam.is_connected("lobby_created", on_created):
		steam.disconnect("lobby_created", on_created)
	if not bool(state["done"]):
		return {"ok": false, "peer": null, "error": "lobby_timeout", "lobby_id": 0}
	if int(state["result"]) != STEAM_RESULT_OK:
		return {"ok": false, "peer": null, "error": "lobby_failed", "lobby_id": 0}
	var lobby_id := int(state["lobby_id"])
	if lobby_id <= 0:
		return {"ok": false, "peer": null, "error": "lobby_failed", "lobby_id": 0}
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	if peer == null:
		leave_steam_lobby(lobby_id)
		return {"ok": false, "peer": null, "error": "steam_peer_missing", "lobby_id": lobby_id}
	var err: int = peer.call("host_with_lobby", lobby_id)
	if err != OK:
		leave_steam_lobby(lobby_id)
		return {"ok": false, "peer": null, "error": "steam_host_%d" % err, "lobby_id": lobby_id}
	return {"ok": true, "peer": peer, "error": "", "lobby_id": lobby_id}


static func join_steam_lobby(lobby_id: int) -> Dictionary:
	## Async. Returns {ok, peer, error, lobby_id}. Awaits lobby_joined then connect_to_lobby.
	var init_err := ensure_steam_init()
	if init_err != "":
		return {"ok": false, "peer": null, "error": init_err, "lobby_id": lobby_id}
	if lobby_id <= 0:
		return {"ok": false, "peer": null, "error": "lobby_invalid", "lobby_id": lobby_id}
	var steam := _steam_singleton()
	var tree := _scene_tree()
	if steam == null or tree == null:
		return {"ok": false, "peer": null, "error": "steam_unavailable", "lobby_id": lobby_id}
	var state := {"done": false, "lobby": 0, "response": -1}
	var on_joined := func(lobby: int, _permissions: int, _locked: bool, response: int) -> void:
		state["lobby"] = lobby
		state["response"] = response
		state["done"] = true
	steam.connect("lobby_joined", on_joined)
	steam.call("joinLobby", lobby_id)
	var deadline := Time.get_ticks_msec() + int(STEAM_LOBBY_TIMEOUT_SEC * 1000.0)
	while not bool(state["done"]) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if steam.is_connected("lobby_joined", on_joined):
		steam.disconnect("lobby_joined", on_joined)
	if not bool(state["done"]):
		return {"ok": false, "peer": null, "error": "lobby_timeout", "lobby_id": lobby_id}
	## ChatRoomEnterResponse OK = 1.
	if int(state["response"]) != 1:
		return {"ok": false, "peer": null, "error": "join_failed", "lobby_id": lobby_id}
	var joined_id := int(state["lobby"])
	if joined_id <= 0:
		joined_id = lobby_id
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	if peer == null:
		leave_steam_lobby(joined_id)
		return {"ok": false, "peer": null, "error": "steam_peer_missing", "lobby_id": joined_id}
	var err: int = peer.call("connect_to_lobby", joined_id)
	if err != OK:
		leave_steam_lobby(joined_id)
		return {"ok": false, "peer": null, "error": "steam_join_%d" % err, "lobby_id": joined_id}
	return {"ok": true, "peer": peer, "error": "", "lobby_id": joined_id}


static func leave_steam_lobby(lobby_id: int) -> void:
	if lobby_id <= 0:
		return
	var steam := _steam_singleton()
	if steam != null and steam.has_method("leaveLobby"):
		steam.call("leaveLobby", lobby_id)


## Bind Overlay／Friends invite callbacks. `on_lobby(lobby_id: int)` receives pending joins.
static func bind_invite_hooks(on_lobby: Callable) -> void:
	_on_invite_lobby = on_lobby
	var init_err := ensure_steam_init()
	if init_err != "":
		return
	_connect_invite_signals()


static func _connect_invite_signals() -> void:
	if _invite_hooks_bound:
		return
	var steam := _steam_singleton()
	if steam == null:
		return
	## GameLobbyJoinRequested — Overlay invite / Join Lobby while game running.
	if steam.has_signal("join_requested") and not steam.is_connected("join_requested", _on_join_requested):
		steam.connect("join_requested", _on_join_requested)
	## GameRichPresenceJoinRequested — Friends "Join Game" via connect string.
	if steam.has_signal("join_game_requested") and not steam.is_connected("join_game_requested", _on_join_game_requested):
		steam.connect("join_game_requested", _on_join_game_requested)
	_invite_hooks_bound = true


static func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	_emit_invite_lobby(int(lobby_id))


static func _on_join_game_requested(_friend_id: int, connect_string: String) -> void:
	var lobby_id := parse_lobby_id_from_connect(String(connect_string))
	if lobby_id > 0:
		_emit_invite_lobby(lobby_id)


static func _emit_invite_lobby(lobby_id: int) -> void:
	if lobby_id <= 0:
		return
	if _on_invite_lobby.is_valid():
		_on_invite_lobby.call(lobby_id)


## After host lobby create: lobby data + Rich Presence so Friends can Join Game.
static func publish_lobby(lobby_id: int) -> void:
	if lobby_id <= 0:
		return
	var steam := _steam_singleton()
	if steam == null:
		return
	if steam.has_method("setLobbyData"):
		steam.call("setLobbyData", lobby_id, "game", "imdoing")
	if steam.has_method("setRichPresence"):
		steam.call("setRichPresence", "status", "In lobby")
		steam.call("setRichPresence", "connect", str(lobby_id))


static func clear_lobby_presence() -> void:
	var steam := _steam_singleton()
	if steam == null:
		return
	if steam.has_method("clearRichPresence"):
		steam.call("clearRichPresence")


## Opens Steam Overlay invite dialog for the current lobby. Returns "" or error code.
static func invite_overlay(lobby_id: int) -> String:
	if lobby_id <= 0:
		return "lobby_invalid"
	var init_err := ensure_steam_init()
	if init_err != "":
		return init_err
	var steam := _steam_singleton()
	if steam == null:
		return "steam_unavailable"
	if not steam.has_method("activateGameOverlayInviteDialog"):
		return "steam_peer_api"
	steam.call("activateGameOverlayInviteDialog", lobby_id)
	return ""


## Parse lobby id from Rich Presence / invite connect string.
static func parse_lobby_id_from_connect(connect_string: String) -> int:
	var s := connect_string.strip_edges()
	if s.is_empty():
		return 0
	if s.is_valid_int():
		return int(s)
	## Tolerate "+connect_lobby 123" or "connect_lobby=123" embedded in one token.
	var args := s.split(" ", false)
	var parsed := parse_connect_lobby_args(args)
	if parsed > 0:
		return parsed
	if "=" in s:
		var parts := s.split("=", false, 1)
		if parts.size() == 2 and String(parts[1]).strip_edges().is_valid_int():
			return int(String(parts[1]).strip_edges())
	return 0


## Parse `+connect_lobby <id>` from a string arg list (testable; used by cmdline consume).
static func parse_connect_lobby_args(args: PackedStringArray) -> int:
	for i in args.size():
		var a := String(args[i]).strip_edges()
		if a == "+connect_lobby" or a == "connect_lobby":
			if i + 1 < args.size():
				var id_s := String(args[i + 1]).strip_edges()
				if id_s.is_valid_int():
					return int(id_s)
		elif a.begins_with("+connect_lobby="):
			var id_s := a.substr(String("+connect_lobby=").length()).strip_edges()
			if id_s.is_valid_int():
				return int(id_s)
		elif a.begins_with("connect_lobby="):
			var id_s2 := a.substr(String("connect_lobby=").length()).strip_edges()
			if id_s2.is_valid_int():
				return int(id_s2)
	return 0


## Cold-start: Steam launches with +connect_lobby when invite accepted while game closed.
static func consume_cmdline_connect_lobby() -> int:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	var from_os := parse_connect_lobby_args(args)
	if from_os > 0:
		return from_os
	## Steam API only after successful init (avoids Apps-class errors when client missing).
	if not _steam_inited:
		return 0
	var steam := _steam_singleton()
	if steam != null and steam.has_method("getLaunchCommandLine"):
		var launch: Variant = steam.call("getLaunchCommandLine")
		if typeof(launch) == TYPE_STRING:
			return parse_lobby_id_from_connect(String(launch))
		if typeof(launch) == TYPE_DICTIONARY:
			var cmd := String(launch.get("command_line", launch.get("cmd", "")))
			if not cmd.is_empty():
				return parse_lobby_id_from_connect(cmd)
	return 0


static func close_peer(peer: MultiplayerPeer) -> void:
	if peer == null:
		return
	peer.close()
