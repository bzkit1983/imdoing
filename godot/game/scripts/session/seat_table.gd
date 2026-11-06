extends Node
## SeatTable for M1 coop + M2-ready fields (multiplayer.md §3.4).
## Autoload `SeatTable`. seat 0 = host/P1, seat 1 = P2 (local).
## Joy devices 0/1; keyboard fills unbound seats.
## Seat ≠ Peer: owner_peer_id / local_index / ready / role_flags per seat.

const LOCAL_PEER := 1
const MAX_LOCAL_SEATS := 2
const ROOM_MAX_SEATS := 4

signal seat_count_changed(count: int)

## 1 = solo (default), 2 = local coop (M1). M2 may rise toward ROOM_MAX_SEATS.
var seat_count: int = 1
## Optional in-memory character sheet for seat 1 (RefCounted / GameState-like).
var guest_stats = null
## Index into GuestSlots (0..2), or -1 if ephemeral clone.
var guest_slot_index: int = -1

## Per-seat rows keyed by seat_id → Dictionary fields below.
## owner_peer_id, local_index, ready, role_flags
var _seats: Dictionary = {}


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
	_ensure_seat(0)
	seat_count_changed.emit(seat_count)


func configure_local(count: int, guest = null, slot_index: int = -1) -> void:
	seat_count = clampi(count, 1, MAX_LOCAL_SEATS)
	guest_stats = guest if seat_count >= 2 else null
	guest_slot_index = slot_index if seat_count >= 2 else -1
	_seats.clear()
	for s in seat_count:
		var row := _ensure_seat(s)
		row["owner_peer_id"] = LOCAL_PEER
		row["local_index"] = s
		row["ready"] = true
		row["role_flags"] = 0
	seat_count_changed.emit(seat_count)


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
	if seat < 0 or seat >= seat_count:
		return -1
	var pads: Array = Input.get_connected_joypads()
	## Prefer stable index matching seat id when present.
	if pads.has(seat):
		return seat
	## Fallback: nth connected pad.
	if seat < pads.size():
		return int(pads[seat])
	return -1


## True when this seat should accept keyboard (WASD / JKL…).
func keyboard_owns_seat(seat: int) -> bool:
	if seat < 0 or seat >= seat_count:
		return false
	if not is_coop():
		return true
	## Keyboard fills seats that have no joypad. If every seat has a pad, keyboard is dead.
	var unbound: Array[int] = []
	for s in seat_count:
		if joy_device_for_seat(s) < 0:
			unbound.append(s)
	if unbound.is_empty():
		return false
	## Lowest unbound seat gets the keyboard.
	return unbound[0] == seat


func seat_ids() -> Array[int]:
	var out: Array[int] = []
	for s in seat_count:
		out.append(s)
	return out
