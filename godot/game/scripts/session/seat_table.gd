extends Node
## SeatTable for M1 coop + M2 LAN seats (multiplayer.md §3.4 / §12).
## Autoload `SeatTable`. Seat ≠ Peer: owner_peer_id / local_index / ready / role_flags.
## Joy devices 0/1; keyboard fills unbound *local* seats.

const CharacterSheet = preload("res://scripts/session/character_sheet.gd")

const LOCAL_PEER := 1
const MAX_LOCAL_SEATS := 2
const ROOM_MAX_SEATS := 4

signal seat_count_changed(count: int)

## 1 = solo (default), 2 = local coop (M1). LAN may rise toward ROOM_MAX_SEATS.
var seat_count: int = 1
## Optional in-memory character sheet for seat 1 (M1 local P2).
var guest_stats = null
## Index into GuestSlots (0..2), or -1 if ephemeral clone.
var guest_slot_index: int = -1

## Per-seat rows keyed by seat_id → Dictionary fields below.
var _seats: Dictionary = {}
## seat_id → CharacterSheet (remote + optional local guest).
var _sheets: Dictionary = {}
## seat_id → true when frozen mid-day after disconnect.
var _frozen: Dictionary = {}


func _ready() -> void:
	_ensure_seat(0)


func _ensure_seat(seat_id: int) -> Dictionary:
	if not _seats.has(seat_id):
		_seats[seat_id] = {
			"seat_id": seat_id,
			"owner_peer_id": LOCAL_PEER,
			"local_index": seat_id,
			"ready": true,
			"role_flags": 0,
		}
	return _seats[seat_id]


func reset_solo() -> void:
	seat_count = 1
	guest_stats = null
	guest_slot_index = -1
	_seats.clear()
	_sheets.clear()
	_frozen.clear()
	_ensure_seat(0)
	seat_count_changed.emit(seat_count)


func configure_local(count: int, guest = null, slot_index: int = -1) -> void:
	seat_count = clampi(count, 1, MAX_LOCAL_SEATS)
	guest_stats = guest if seat_count >= 2 else null
	guest_slot_index = slot_index if seat_count >= 2 else -1
	_seats.clear()
	_sheets.clear()
	_frozen.clear()
	for s in seat_count:
		var row := _ensure_seat(s)
		row["owner_peer_id"] = LOCAL_PEER
		row["local_index"] = s
		row["ready"] = true
		row["role_flags"] = 0
	if guest_stats != null:
		_sheets[1] = guest_stats
	seat_count_changed.emit(seat_count)


## LAN host: local seats 0..count-1 owned by host peer; remotes claim later.
func configure_lan_host(count: int, guest = null, slot_index: int = -1) -> void:
	configure_local(count, guest, slot_index)


## Allocate next free seat for remote peer (claim 1). Returns seat_id or -1.
func add_remote_seat(peer_id: int, sheet) -> int:
	var ids := add_remote_seats(peer_id, [sheet])
	return ids[0] if not ids.is_empty() else -1


## Allocate 1–2 seats for a remote peer. `sheets[i]` → local_index i. Returns new seat ids or [].
func add_remote_seats(peer_id: int, sheets: Array) -> Array[int]:
	var out: Array[int] = []
	if sheets.is_empty() or sheets.size() > MAX_LOCAL_SEATS:
		return out
	if seat_count + sheets.size() > ROOM_MAX_SEATS:
		return out
	for i in sheets.size():
		var seat_id := seat_count
		seat_count += 1
		var row := _ensure_seat(seat_id)
		row["owner_peer_id"] = peer_id
		row["local_index"] = i
		row["ready"] = false
		row["role_flags"] = 0
		var sheet = sheets[i]
		if sheet != null:
			_sheets[seat_id] = sheet
		out.append(seat_id)
	seat_count_changed.emit(seat_count)
	return out


func remove_seat(seat_id: int) -> void:
	if seat_id <= 0:
		return
	_seats.erase(seat_id)
	_sheets.erase(seat_id)
	_frozen.erase(seat_id)
	## Compact: rebuild contiguous 0..n-1 from remaining sorted ids.
	var ids: Array[int] = []
	for k in _seats.keys():
		ids.append(int(k))
	ids.sort()
	var new_seats: Dictionary = {}
	var new_sheets: Dictionary = {}
	var new_frozen: Dictionary = {}
	var ni := 0
	for old_id in ids:
		new_seats[ni] = _seats[old_id]
		new_seats[ni]["seat_id"] = ni
		if _sheets.has(old_id):
			new_sheets[ni] = _sheets[old_id]
		if _frozen.has(old_id):
			new_frozen[ni] = true
		ni += 1
	_seats = new_seats
	_sheets = new_sheets
	_frozen = new_frozen
	seat_count = maxi(1, ni)
	if not _seats.has(0):
		_ensure_seat(0)
		seat_count = 1
	## Keep guest_stats pointer if seat 1 still local guest.
	if seat_count < 2:
		guest_stats = null
		guest_slot_index = -1
	elif _sheets.has(1):
		guest_stats = _sheets[1]
	seat_count_changed.emit(seat_count)


func sheet_of(seat_id: int):
	if _sheets.has(seat_id):
		return _sheets[seat_id]
	if seat_id == 1 and guest_stats != null:
		return guest_stats
	return null


func set_sheet(seat_id: int, sheet) -> void:
	if sheet == null:
		_sheets.erase(seat_id)
	else:
		_sheets[seat_id] = sheet
	if seat_id == 1:
		guest_stats = sheet


func freeze_seat(seat_id: int) -> void:
	_frozen[seat_id] = true


func is_frozen(seat_id: int) -> bool:
	return bool(_frozen.get(seat_id, false))


func frozen_snapshot() -> Dictionary:
	return _frozen.duplicate()


func sheets_snapshot() -> Dictionary:
	var out := {}
	for k in _sheets.keys():
		var sh = _sheets[k]
		if sh != null and sh.has_method("to_dict"):
			out[int(k)] = sh.to_dict()
		elif sh is Dictionary:
			out[int(k)] = sh
	return out


func apply_lobby_payload(payload: Dictionary) -> void:
	seat_count = clampi(int(payload.get("seat_count", 1)), 1, ROOM_MAX_SEATS)
	_seats.clear()
	_sheets.clear()
	_frozen.clear()
	var seats_arr = payload.get("seats", [])
	if seats_arr is Array:
		for row in seats_arr:
			if row is Dictionary:
				var sid := int(row.get("seat_id", 0))
				_seats[sid] = {
					"seat_id": sid,
					"owner_peer_id": int(row.get("owner_peer_id", LOCAL_PEER)),
					"local_index": int(row.get("local_index", 0)),
					"ready": bool(row.get("ready", false)),
					"role_flags": int(row.get("role_flags", 0)),
				}
	var sheets = payload.get("sheets", {})
	if sheets is Dictionary:
		for k in sheets.keys():
			var sid := int(k)
			var data = sheets[k]
			if data is Dictionary:
				_sheets[sid] = CharacterSheet.from_dict(data)
	var froz = payload.get("frozen", {})
	if froz is Dictionary:
		for k in froz.keys():
			if bool(froz[k]):
				_frozen[int(k)] = true
	if not _seats.has(0):
		_ensure_seat(0)
	guest_stats = _sheets.get(1, guest_stats)
	seat_count_changed.emit(seat_count)


func seats_owned_by(peer_id: int) -> Array[int]:
	var out: Array[int] = []
	for s in seat_count:
		if owner_peer_of(s) == peer_id:
			out.append(s)
	return out


func seat_owned_locally(seat_id: int) -> bool:
	if is_frozen(seat_id):
		return false
	## Local transport: all seats local.
	if SessionService.is_local_transport():
		return seat_id >= 0 and seat_id < seat_count
	return owner_peer_of(seat_id) == SessionService.local_peer_id


func is_coop() -> bool:
	return seat_count >= 2


func set_owner_peer(seat_id: int, peer_id: int) -> void:
	_ensure_seat(seat_id)["owner_peer_id"] = peer_id


func owner_peer_of(seat_id: int) -> int:
	return int(_ensure_seat(seat_id).get("owner_peer_id", LOCAL_PEER))


func set_local_index(seat_id: int, local_index: int) -> void:
	_ensure_seat(seat_id)["local_index"] = local_index


func local_index_of(seat_id: int) -> int:
	return int(_ensure_seat(seat_id).get("local_index", seat_id))


func set_seat_ready(seat_id: int, ready: bool) -> void:
	_ensure_seat(seat_id)["ready"] = ready


func is_seat_ready(seat_id: int) -> bool:
	return bool(_ensure_seat(seat_id).get("ready", false))


func all_ready() -> bool:
	for s in seat_count:
		if is_frozen(s):
			continue
		if not is_seat_ready(s):
			return false
	return true


func set_role_flags(seat_id: int, flags: int) -> void:
	_ensure_seat(seat_id)["role_flags"] = flags


func role_flags_of(seat_id: int) -> int:
	return int(_ensure_seat(seat_id).get("role_flags", 0))


func snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in seat_count:
		out.append(_ensure_seat(s).duplicate())
	return out


## Joypad device index for this seat, or -1 if none assigned.
func joy_device_for_seat(seat: int) -> int:
	if not seat_owned_locally(seat):
		return -1
	var local_i := local_index_of(seat)
	var pads: Array = Input.get_connected_joypads()
	if pads.has(local_i):
		return local_i
	if local_i < pads.size():
		return int(pads[local_i])
	return -1


## True when this seat should accept keyboard (WASD / JKL…).
func keyboard_owns_seat(seat: int) -> bool:
	if not seat_owned_locally(seat):
		return false
	## Count local seats on this machine.
	var local_seats: Array[int] = []
	for s in seat_count:
		if seat_owned_locally(s):
			local_seats.append(s)
	if local_seats.is_empty():
		return false
	if local_seats.size() == 1:
		return local_seats[0] == seat
	## Keyboard fills unbound local seats among this machine's seats.
	var unbound: Array[int] = []
	for s in local_seats:
		if joy_device_for_seat(s) < 0:
			unbound.append(s)
	if unbound.is_empty():
		return false
	return unbound[0] == seat


func seat_ids() -> Array[int]:
	var out: Array[int] = []
	for s in seat_count:
		out.append(s)
	return out
