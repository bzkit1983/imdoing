extends Node
## Session layer for Seat ≠ Peer (multiplayer.md §3 / §6.5 / §12).
## Autoload `SessionService`. Gameplay must not construct MultiplayerPeer — only here.

const NetTransport = preload("res://scripts/session/net_transport.gd")
const CharacterSheet = preload("res://scripts/session/character_sheet.gd")

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal seats_changed()
signal start_day()
## `during_day` true when Host left mid-run (client must dissolve, not keep playing).
signal disconnect_session(during_day: bool)
signal lobby_changed()
signal room_paused_changed(paused: bool)
signal settle_payload_received(payload: Dictionary)
signal net_error(message: String)
## M2.2／M2.3: Host → client world-agent presentation (§8).
signal agent_spawn_received(payload: Dictionary)
signal agent_despawn_received(agent_id: int, reason: String)
signal agent_state_received(payload: Dictionary)
signal flight_received(payload: Dictionary)
## M2.4: Host → client shelf / warehouse absolute stock presentation.
signal stock_state_received(payload: Dictionary)
## M2.6: Host → client seat carry stack absolute presentation.
signal carry_state_received(payload: Dictionary)
## M2.9: Host → client seat checkout prompt chrome (arrows／hold).
signal prompt_state_received(payload: Dictionary)

const ROOM_MAX_SEATS := 4
const LOCAL_PEER_ID := 1

## local | lan_enet | steam | web_ws
var transport_id: String = "local"
var active: bool = false
var host_peer_id: int = LOCAL_PEER_ID
## True after start_run until close / return to prep.
var day_started: bool = false
## Client: true after Host settle RPC was applied to local save (§12.8).
## Prevents Host returning to prep (room teardown) from looking like "day not settled".
var settlement_applied: bool = false
## LAN listen port (host).
var lan_port: int = NetTransport.DEFAULT_PORT
## Address used by join (for UI).
var join_address: String = ""
## Client join claim 1｜2 (M2 second slice).
var join_claim_seats: int = 1
## GuestSlots index for claim-2 second seat (−1 = none / ephemeral clone).
var join_guest_slot_index: int = -1
## Open-day seat count frozen for XP denominator (§12.8).
var open_day_seat_n: int = 1
## Local peer id once connected (1 on host).
var local_peer_id: int = LOCAL_PEER_ID

var _peer: MultiplayerPeer = null
## peer_id → pending sheet dict before seat assigned (client→host).
var _pending_sheets: Dictionary = {}
## Client: second-seat sheet dict staged for claim-2 upload.
var _join_guest_sheet_dict: Dictionary = {}


func _ready() -> void:
	## Keep polling peers while the tree is paused (room pause).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not SeatTable.seat_count_changed.is_connected(_on_seat_count_changed):
		SeatTable.seat_count_changed.connect(_on_seat_count_changed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_seat_count_changed(_count: int) -> void:
	seats_changed.emit()
	lobby_changed.emit()


func lan_available() -> bool:
	return NetTransport.lan_available()


func is_local_transport() -> bool:
	return transport_id == "local"


func is_lan() -> bool:
	return transport_id == "lan_enet" and active


func is_server() -> bool:
	if not is_lan():
		return true
	return multiplayer.is_server()


func is_client() -> bool:
	return is_lan() and not multiplayer.is_server()


## Open a local room (M1). `local_seat_count` 1–2; guest sheet optional.
func create_room(local_seat_count: int = 1, guest = null, slot_index: int = -1) -> void:
	_teardown_peer()
	transport_id = "local"
	active = true
	day_started = false
	settlement_applied = false
	host_peer_id = LOCAL_PEER_ID
	local_peer_id = LOCAL_PEER_ID
	SeatTable.configure_local(local_seat_count, guest, slot_index)
	_sync_local_peers()
	seats_changed.emit()
	lobby_changed.emit()


## Host opens LAN room with local 1｜2 seats already configured like M1.
func host_lan(local_seat_count: int = 1, guest = null, slot_index: int = -1, port: int = NetTransport.DEFAULT_PORT) -> String:
	if not lan_available():
		return "web_no_enet"
	_teardown_peer()
	var result: Dictionary = NetTransport.create_host(port)
	if not bool(result.get("ok", false)):
		return String(result.get("error", "host_failed"))
	_peer = result["peer"]
	lan_port = int(result.get("port", port))
	multiplayer.multiplayer_peer = _peer
	transport_id = "lan_enet"
	active = true
	day_started = false
	settlement_applied = false
	host_peer_id = LOCAL_PEER_ID
	local_peer_id = LOCAL_PEER_ID
	SeatTable.configure_lan_host(local_seat_count, guest, slot_index)
	_sync_local_peers()
	## Host seats start ready; remotes must ready up.
	for s in SeatTable.seat_ids():
		if SeatTable.owner_peer_of(s) == local_peer_id:
			SeatTable.set_seat_ready(s, true)
	seats_changed.emit()
	lobby_changed.emit()
	return ""


## Client joins LAN. claim_seats 1｜2 (M2 second slice). Optional guest sheet for claim 2.
func join_room(
	claim_seats: int = 1,
	address: String = "127.0.0.1",
	port: int = NetTransport.DEFAULT_PORT,
	guest_sheet = null,
	guest_slot_index: int = -1
) -> String:
	if not lan_available():
		return "web_no_enet"
	var claim := clampi(claim_seats, 1, SeatTable.MAX_LOCAL_SEATS)
	if claim_seats != claim:
		return "claim_invalid"
	if not PlatformServices.has_save():
		return "no_save"
	if claim >= 2 and guest_sheet == null:
		return "guest_sheet_required"
	_teardown_peer()
	join_address = address.strip_edges()
	lan_port = port
	join_claim_seats = claim
	join_guest_slot_index = guest_slot_index if claim >= 2 else -1
	_join_guest_sheet_dict = {}
	if claim >= 2 and guest_sheet != null and guest_sheet.has_method("to_dict"):
		_join_guest_sheet_dict = guest_sheet.to_dict()
	var result: Dictionary = NetTransport.join_host(join_address, port)
	if not bool(result.get("ok", false)):
		return String(result.get("error", "join_failed"))
	_peer = result["peer"]
	multiplayer.multiplayer_peer = _peer
	transport_id = "lan_enet"
	active = true
	day_started = false
	settlement_applied = false
	host_peer_id = LOCAL_PEER_ID
	## local_peer_id set on connected_to_server
	SeatTable.reset_solo()
	lobby_changed.emit()
	return ""


func close() -> void:
	_teardown_peer()
	active = false
	day_started = false
	settlement_applied = false
	transport_id = "local"
	host_peer_id = LOCAL_PEER_ID
	local_peer_id = LOCAL_PEER_ID
	open_day_seat_n = 1
	join_claim_seats = 1
	join_guest_slot_index = -1
	_join_guest_sheet_dict = {}
	_pending_sheets.clear()
	SeatTable.reset_solo()
	disconnect_session.emit(false)
	seats_changed.emit()
	lobby_changed.emit()


func set_ready(seat_id: int, ready: bool = true) -> void:
	if is_lan() and not is_server():
		_rpc_set_ready.rpc_id(1, seat_id, ready)
		return
	SeatTable.set_seat_ready(seat_id, ready)
	seats_changed.emit()
	lobby_changed.emit()
	if is_lan() and is_server():
		_broadcast_lobby()


func all_ready() -> bool:
	return SeatTable.all_ready()


func seats_remaining() -> int:
	return maxi(0, ROOM_MAX_SEATS - SeatTable.seat_count)


func start_run(world_snapshot: Dictionary = {}) -> void:
	## Lobby → day. Host only on LAN.
	if is_lan() and not is_server():
		return
	if not active:
		create_room(SeatTable.seat_count, SeatTable.guest_stats, SeatTable.guest_slot_index)
	if is_lan() and is_server():
		if not all_ready():
			net_error.emit("not_all_ready")
			return
		open_day_seat_n = SeatTable.seat_count
		day_started = true
		var snap := world_snapshot.duplicate(true)
		snap["seat_table"] = _lobby_payload()
		snap["open_day_seat_n"] = open_day_seat_n
		## Clients get start via RPC; host prep emits its own start_day.
		_rpc_start_day.rpc(snap)
		return
	open_day_seat_n = SeatTable.seat_count
	day_started = true
	start_day.emit()


func seat_table_snapshot() -> Array[Dictionary]:
	return SeatTable.snapshot()


func request_pause(wanted_paused: bool) -> void:
	if not is_lan():
		room_paused_changed.emit(wanted_paused)
		return
	if is_server():
		_apply_pause(wanted_paused)
	else:
		_rpc_request_pause.rpc_id(1, wanted_paused)


func request_end_day() -> bool:
	## Only host may end day on LAN.
	if is_lan() and not is_server():
		return false
	return true


func send_intent(seat_id: int, payload: Dictionary) -> void:
	if not is_lan() or is_server():
		return
	if SeatTable.owner_peer_of(seat_id) != local_peer_id:
		return
	_rpc_intent.rpc_id(1, seat_id, payload)


func broadcast_player_transforms(transforms: Array) -> void:
	if not is_lan() or not is_server() or not day_started:
		return
	_rpc_player_transforms.rpc(transforms)


func broadcast_agent_spawn(payload: Dictionary) -> void:
	if not is_lan() or not is_server() or not day_started:
		return
	_rpc_agent_spawn.rpc(payload)


func broadcast_agent_despawn(agent_id: int, reason: String = "") -> void:
	if not is_lan() or not is_server() or not day_started:
		return
	_rpc_agent_despawn.rpc(agent_id, reason)


func broadcast_agent_transforms(transforms: Array) -> void:
	if not is_lan() or not is_server() or not day_started:
		return
	if transforms.is_empty():
		return
	_rpc_agent_transforms.rpc(transforms)


func broadcast_agent_state(payload: Dictionary) -> void:
	## Dark Side temp／炮台 ammo／drop 件數等低頻狀態（M2.3）.
	if not is_lan() or not is_server() or not day_started:
		return
	_rpc_agent_state.rpc(payload)


func broadcast_flight(payload: Dictionary) -> void:
	## 短命飛行箱／炮彈：client 本地 lerp，落地箱另由 spawn（M2.3）.
	if not is_lan() or not is_server() or not day_started:
		return
	_rpc_flight.rpc(payload)


func broadcast_stock_state(payload: Dictionary) -> void:
	## 貨架 sku/count 與倉庫件數絕對快照（M2.4）；Client 只套用。
	if not is_lan() or not is_server() or not day_started:
		return
	if payload.is_empty():
		return
	_rpc_stock_state.rpc(payload)


func broadcast_carry_state(payload: Dictionary) -> void:
	## 手持件序絕對快照（M2.6）；Client 只套用。
	if not is_lan() or not is_server() or not day_started:
		return
	if payload.is_empty():
		return
	_rpc_carry_state.rpc(payload)


func broadcast_prompt_state(payload: Dictionary) -> void:
	## 收銀指令箭頭／Circle hold 絕對快照（M2.9）；Client 只套用。
	if not is_lan() or not is_server() or not day_started:
		return
	if payload.is_empty():
		return
	_rpc_prompt_state.rpc(payload)


func send_settle_to_clients(payload: Dictionary) -> void:
	if not is_lan() or not is_server():
		return
	_rpc_settle.rpc(payload)


func apply_client_settle_to_save(payload: Dictionary) -> Dictionary:
	## Client writes XP / support_rating (§12.8) + 同等營業額到主存檔資金（M2.1）.
	## local_index 0 → main save (XP + support + revenue)；local_index 1 → guest_slots only.
	var fail := {
		"ok": false,
		"shared_xp": 0,
		"support_rating": 0,
		"grade": 0,
		"seat": -1,
		"revenue": 0,
		"money": 0,
	}
	if payload.is_empty():
		return fail
	var owned: Array[int] = []
	for s in SeatTable.seat_ids():
		if SeatTable.owner_peer_of(s) == local_peer_id:
			owned.append(s)
	if owned.is_empty():
		return fail
	var per: Dictionary = payload.get("per_seat", {})
	var grade := int(payload.get("host_grade", 0))
	var shared_xp := int(payload.get("shared_xp", 0))
	var revenue := maxi(0, int(payload.get("revenue", 0)))
	var main_support := 0
	var main_money := 0
	var main_seat := -1
	var wrote_any := false
	for s in owned:
		var entry: Dictionary = {}
		if per.has(s):
			entry = per[s]
		elif per.has(str(s)):
			entry = per[str(s)]
		else:
			continue
		var xp := int(entry.get("shared_xp", shared_xp))
		shared_xp = xp
		var li := SeatTable.local_index_of(s)
		if li == 0:
			var StateScript = load("res://scripts/game_state.gd")
			var state = StateScript.new()
			if String(state.load_from_disk()) != "":
				continue
			var sheet = CharacterSheet.from_game_state(state)
			sheet.support_rating = int(state.support_rating)
			sheet.apply_xp_gain(xp)
			sheet.support_rating = int(sheet.support_rating) + grade
			state.xp = sheet.xp
			state.level = sheet.level
			state.unspent = sheet.unspent
			state.support_rating = sheet.support_rating
			## M2.1：訪客本店資金 += Host 當日營業額（商店評價／進貨支出不動）。
			state.money += revenue
			if String(state.save_to_disk()) != "":
				continue
			main_support = int(state.support_rating)
			main_money = int(state.money)
			main_seat = s
			wrote_any = true
		elif li == 1 and join_guest_slot_index >= 0:
			var GuestSlots = load("res://scripts/session/guest_slots.gd")
			var store = GuestSlots.create()
			var gsheet = store.get_sheet(join_guest_slot_index)
			if gsheet == null:
				continue
			gsheet.apply_xp_gain(xp)
			gsheet.support_rating = int(gsheet.support_rating) + grade
			store.set_sheet(join_guest_slot_index, gsheet)
			store.save_to_disk()
			wrote_any = true
	if not wrote_any:
		return fail
	return {
		"ok": true,
		"shared_xp": shared_xp,
		"support_rating": main_support,
		"grade": grade,
		"seat": main_seat,
		"revenue": revenue,
		"money": main_money,
	}


# --- Multiplayer callbacks ---------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not is_lan() or not is_server():
		return
	## ENet MAX_CLIENTS is peer-based, not seat-based — refuse when no seat left
	## (e.g. host2 + remote claim2 = 4 seats, but a 3rd client can still TCP/UDP in).
	if day_started:
		_refuse_peer(peer_id, "day_started")
		return
	if seats_remaining() <= 0:
		_refuse_peer(peer_id, "room_full")
		return
	peer_joined.emit(peer_id)
	## Do not lobby-sync yet — wait until claim assigns seats (avoids "ghost" lobby).


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_lan() or not is_server():
		return
	_handle_peer_left(peer_id)
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	## Upload main-save sheet (+ guest sheet when claim 2).
	var StateScript = load("res://scripts/game_state.gd")
	var state = StateScript.new()
	var err: String = String(state.load_from_disk())
	if err != "":
		net_error.emit("no_save")
		close()
		return
	var sheet = CharacterSheet.from_game_state(state)
	sheet.support_rating = int(state.support_rating)
	var sheets: Array = [sheet.to_dict()]
	if join_claim_seats >= 2:
		if _join_guest_sheet_dict.is_empty():
			net_error.emit("guest_sheet_required")
			close()
			return
		sheets.append(_join_guest_sheet_dict.duplicate(true))
	_rpc_claim_seats.rpc_id(1, sheets)
	## Lobby UI waits for claim accept (_rpc_lobby_sync) or _rpc_claim_rejected.


func _on_connection_failed() -> void:
	net_error.emit("connection_failed")
	close()


func _on_server_disconnected() -> void:
	## Host left → dissolve room (§12.7).
	## Notify gameplay BEFORE flipping to transport=local / reset_solo — otherwise
	## seat_owned_locally() treats every seat as local and the client pilots P1.
	## If settle RPC already applied, Host closing the room is normal — not an abort.
	var during_day := day_started and not settlement_applied
	net_error.emit("server_disconnected")
	disconnect_session.emit(during_day)
	day_started = false
	_teardown_peer()
	active = false
	transport_id = "local"
	host_peer_id = LOCAL_PEER_ID
	local_peer_id = LOCAL_PEER_ID
	open_day_seat_n = 1
	join_claim_seats = 1
	join_guest_slot_index = -1
	_join_guest_sheet_dict = {}
	_pending_sheets.clear()
	SeatTable.reset_solo()
	seats_changed.emit()
	lobby_changed.emit()


# --- RPCs --------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _rpc_claim_seats(sheet_dicts: Array) -> void:
	if not is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if day_started:
		_refuse_peer(peer_id, "day_started")
		return
	## Peer already owns seats → ignore duplicate claim.
	if not SeatTable.seats_owned_by(peer_id).is_empty():
		return
	var n := sheet_dicts.size()
	if n < 1 or n > SeatTable.MAX_LOCAL_SEATS:
		_refuse_peer(peer_id, "claim_invalid")
		return
	if SeatTable.seat_count + n > ROOM_MAX_SEATS:
		_refuse_peer(peer_id, "room_full")
		return
	var sheets: Array = []
	for d in sheet_dicts:
		if d is Dictionary:
			sheets.append(CharacterSheet.from_dict(d))
		else:
			_refuse_peer(peer_id, "claim_failed")
			return
	var ids: Array[int] = SeatTable.add_remote_seats(peer_id, sheets)
	if ids.size() != n:
		_refuse_peer(peer_id, "claim_failed")
		return
	for sid in ids:
		SeatTable.set_seat_ready(sid, false)
	_broadcast_lobby()
	seats_changed.emit()
	lobby_changed.emit()


@rpc("authority", "reliable")
func _rpc_claim_rejected(reason: String) -> void:
	net_error.emit(reason)
	close()


## Host: tell client why, then drop the peer (seat gate ≠ ENet peer gate).
func _refuse_peer(peer_id: int, reason: String) -> void:
	if not is_server() or peer_id <= LOCAL_PEER_ID:
		return
	_rpc_claim_rejected.rpc_id(peer_id, reason)
	## Defer so the reliable reject RPC can flush before the socket dies.
	call_deferred("_disconnect_peer_now", peer_id)


func _disconnect_peer_now(peer_id: int) -> void:
	if not is_lan() or not is_server():
		return
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return
	## Already gone (client closed on reject) — disconnect_peer is safe no-op-ish.
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	peer.disconnect_peer(peer_id)


@rpc("any_peer", "reliable")
func _rpc_set_ready(seat_id: int, ready: bool) -> void:
	if not is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if SeatTable.owner_peer_of(seat_id) != peer_id:
		return
	SeatTable.set_seat_ready(seat_id, ready)
	_broadcast_lobby()
	seats_changed.emit()
	lobby_changed.emit()


@rpc("authority", "reliable")
func _rpc_lobby_sync(payload: Dictionary) -> void:
	SeatTable.apply_lobby_payload(payload)
	seats_changed.emit()
	lobby_changed.emit()


@rpc("authority", "reliable")
func _rpc_start_day(snap: Dictionary) -> void:
	## Clients only (host already emitted locally in start_run).
	if is_server():
		return
	open_day_seat_n = int(snap.get("open_day_seat_n", SeatTable.seat_count))
	day_started = true
	var seats_payload: Dictionary = snap.get("seat_table", {})
	if not seats_payload.is_empty():
		SeatTable.apply_lobby_payload(seats_payload)
	## Stash snapshot for demo to consume.
	set_meta("pending_day_snapshot", snap)
	start_day.emit()


@rpc("any_peer", "reliable")
func _rpc_request_pause(wanted_paused: bool) -> void:
	if not is_server():
		return
	_apply_pause(wanted_paused)


@rpc("authority", "reliable")
func _rpc_room_paused(paused: bool) -> void:
	room_paused_changed.emit(paused)


@rpc("any_peer", "unreliable")
func _rpc_intent(seat_id: int, payload: Dictionary) -> void:
	if not is_server() or not day_started:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if SeatTable.owner_peer_of(seat_id) != peer_id:
		return
	if SeatTable.is_frozen(seat_id):
		return
	## demo polls via take_remote_intent
	if not has_meta("remote_intents"):
		set_meta("remote_intents", {})
	var bag: Dictionary = get_meta("remote_intents")
	bag[seat_id] = payload


@rpc("authority", "unreliable")
func _rpc_player_transforms(transforms: Array) -> void:
	if is_server():
		return
	set_meta("player_transforms", transforms)


@rpc("authority", "reliable")
func _rpc_agent_spawn(payload: Dictionary) -> void:
	if is_server():
		return
	agent_spawn_received.emit(payload)


@rpc("authority", "reliable")
func _rpc_agent_despawn(agent_id: int, reason: String) -> void:
	if is_server():
		return
	agent_despawn_received.emit(agent_id, reason)


@rpc("authority", "unreliable")
func _rpc_agent_transforms(transforms: Array) -> void:
	if is_server():
		return
	set_meta("agent_transforms", transforms)


@rpc("authority", "reliable")
func _rpc_agent_state(payload: Dictionary) -> void:
	if is_server():
		return
	agent_state_received.emit(payload)


@rpc("authority", "reliable")
func _rpc_flight(payload: Dictionary) -> void:
	if is_server():
		return
	flight_received.emit(payload)


@rpc("authority", "reliable")
func _rpc_stock_state(payload: Dictionary) -> void:
	if is_server():
		return
	stock_state_received.emit(payload)


@rpc("authority", "reliable")
func _rpc_carry_state(payload: Dictionary) -> void:
	if is_server():
		return
	carry_state_received.emit(payload)


@rpc("authority", "reliable")
func _rpc_prompt_state(payload: Dictionary) -> void:
	if is_server():
		return
	prompt_state_received.emit(payload)


@rpc("authority", "reliable")
func _rpc_settle(payload: Dictionary) -> void:
	if is_server():
		return
	var result: Dictionary = apply_client_settle_to_save(payload)
	if bool(result.get("ok", false)):
		settlement_applied = true
		## Day is closed out; Host may tear down the room without it being an abort.
		day_started = false
	## Always notify demo (UI can show ok/fail from payload meta).
	var ui_payload := payload.duplicate(true)
	ui_payload["_apply"] = result
	settle_payload_received.emit(ui_payload)


@rpc("authority", "reliable")
func _rpc_freeze_seat(seat_id: int) -> void:
	SeatTable.freeze_seat(seat_id)
	seats_changed.emit()


# --- Internals ---------------------------------------------------------------

func take_remote_intent(seat_id: int) -> Dictionary:
	if not has_meta("remote_intents"):
		return {}
	var bag: Dictionary = get_meta("remote_intents")
	if not bag.has(seat_id):
		return {}
	var out: Dictionary = bag[seat_id]
	bag.erase(seat_id)
	return out


func peek_player_transforms() -> Array:
	if not has_meta("player_transforms"):
		return []
	return get_meta("player_transforms")


func peek_agent_transforms() -> Array:
	if not has_meta("agent_transforms"):
		return []
	return get_meta("agent_transforms")


func take_pending_day_snapshot() -> Dictionary:
	if not has_meta("pending_day_snapshot"):
		return {}
	var snap: Dictionary = get_meta("pending_day_snapshot")
	remove_meta("pending_day_snapshot")
	return snap


func _apply_pause(wanted_paused: bool) -> void:
	## Last Host-applied state wins (§12.6).
	if is_lan() and is_server():
		_rpc_room_paused.rpc(wanted_paused)
	room_paused_changed.emit(wanted_paused)


func _broadcast_lobby() -> void:
	if not is_server():
		return
	_rpc_lobby_sync.rpc(_lobby_payload())


func _lobby_payload() -> Dictionary:
	return {
		"seat_count": SeatTable.seat_count,
		"seats": SeatTable.snapshot(),
		"sheets": SeatTable.sheets_snapshot(),
		"frozen": SeatTable.frozen_snapshot(),
	}


func _handle_peer_left(peer_id: int) -> void:
	var seats := SeatTable.seats_owned_by(peer_id)
	## Highest id first — remove_seat compacts downward.
	seats.sort()
	seats.reverse()
	if not day_started:
		for s in seats:
			SeatTable.remove_seat(s)
		_broadcast_lobby()
		seats_changed.emit()
		lobby_changed.emit()
		return
	## Mid-day: freeze seats, remove avatars via signal consumers.
	for s in seats:
		SeatTable.freeze_seat(s)
		_rpc_freeze_seat.rpc(s)
	seats_changed.emit()
	lobby_changed.emit()


func _sync_local_peers() -> void:
	for seat_id in SeatTable.seat_ids():
		SeatTable.set_owner_peer(seat_id, local_peer_id)
		SeatTable.set_local_index(seat_id, seat_id)
		SeatTable.set_seat_ready(seat_id, true)


func _teardown_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	if _peer != null:
		NetTransport.close_peer(_peer)
		_peer = null
	if has_meta("remote_intents"):
		remove_meta("remote_intents")
	if has_meta("player_transforms"):
		remove_meta("player_transforms")
	if has_meta("agent_transforms"):
		remove_meta("agent_transforms")
	if has_meta("pending_day_snapshot"):
		remove_meta("pending_day_snapshot")
