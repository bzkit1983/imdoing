extends Node
## Local SeatTable for M1 coop (transport=local). Autoload `SeatTable`.
## seat 0 = host/P1, seat 1 = P2. Joy devices 0/1; keyboard fills unbound seats.

const LOCAL_PEER := 1
const MAX_LOCAL_SEATS := 2

signal seat_count_changed(count: int)

## 1 = solo (default), 2 = local coop.
var seat_count: int = 1
## Optional in-memory character sheet for seat 1 (RefCounted / GameState-like).
var guest_stats = null
## Index into GuestSlots (0..2), or -1 if ephemeral clone.
var guest_slot_index: int = -1


func reset_solo() -> void:
	seat_count = 1
	guest_stats = null
	guest_slot_index = -1
	seat_count_changed.emit(seat_count)


func configure_local(count: int, guest = null, slot_index: int = -1) -> void:
	seat_count = clampi(count, 1, MAX_LOCAL_SEATS)
	guest_stats = guest if seat_count >= 2 else null
	guest_slot_index = slot_index if seat_count >= 2 else -1
	seat_count_changed.emit(seat_count)


func is_coop() -> bool:
	return seat_count >= 2


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
