extends Node
## Session layer for Seat ≠ Peer (multiplayer.md §3 / §6.5).
## Autoload `SessionService`. M1 uses transport=local; M2 plugs NetTransport later.
## Gameplay must not construct MultiplayerPeer here — only Session does.

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal seats_changed()
signal start_day()
signal disconnect_session()

const ROOM_MAX_SEATS := 4
const LOCAL_PEER_ID := 1

## local | lan_enet | steam | web_ws (transport not opened until M2).
var transport_id: String = "local"
## True after create_room / join_room until close.
var active: bool = false
## Peer that owns the listen-server sim (always LOCAL_PEER_ID for local).
var host_peer_id: int = LOCAL_PEER_ID


func _ready() -> void:
	## Keep SeatTable as the live seat source; mirror M1 configure into seat rows.
	if not SeatTable.seat_count_changed.is_connected(_on_seat_count_changed):
		SeatTable.seat_count_changed.connect(_on_seat_count_changed)


func _on_seat_count_changed(_count: int) -> void:
	seats_changed.emit()


## Open a local room (M1). `local_seat_count` 1–2; guest sheet optional.
func create_room(local_seat_count: int = 1, guest = null, slot_index: int = -1) -> void:
	transport_id = "local"
	active = true
	host_peer_id = LOCAL_PEER_ID
	SeatTable.configure_local(local_seat_count, guest, slot_index)
	_sync_local_peers()
	seats_changed.emit()


func join_room(_claim_seats: int = 1) -> String:
	## M2: claim remote seats. Local-only for now.
	return "local_transport_only"


func close() -> void:
	active = false
	transport_id = "local"
	SeatTable.reset_solo()
	disconnect_session.emit()
	seats_changed.emit()


func set_ready(seat_id: int, ready: bool = true) -> void:
	SeatTable.set_seat_ready(seat_id, ready)
	seats_changed.emit()


func all_ready() -> bool:
	return SeatTable.all_ready()


func start_run() -> void:
	## Lobby → day. Host only; clients wait for RPC in M2.
	if not active:
		create_room(SeatTable.seat_count, SeatTable.guest_stats, SeatTable.guest_slot_index)
	start_day.emit()


func seat_table_snapshot() -> Array[Dictionary]:
	return SeatTable.snapshot()


func is_local_transport() -> bool:
	return transport_id == "local"


func _sync_local_peers() -> void:
	## Each local seat is owned by the local peer.
	for seat_id in SeatTable.seat_ids():
		SeatTable.set_owner_peer(seat_id, LOCAL_PEER_ID)
		SeatTable.set_local_index(seat_id, seat_id)
		SeatTable.set_seat_ready(seat_id, true)
