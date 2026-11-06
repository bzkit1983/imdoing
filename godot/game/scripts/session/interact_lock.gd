extends Node
## Autoload InteractLock — §11.6 L-class target locks by seat.
## First seat to acquire a target blocks other seats until release.

## instance_id -> seat_id
var _held: Dictionary = {}


func clear() -> void:
	_held.clear()


func try_acquire(target: Object, seat: int) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var id := target.get_instance_id()
	if _held.has(id):
		return int(_held[id]) == seat
	_held[id] = seat
	return true


func release(target: Object, seat: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	var id := target.get_instance_id()
	if not _held.has(id):
		return
	if int(_held[id]) == seat:
		_held.erase(id)


func release_all_for_seat(seat: int) -> void:
	var gone: Array = []
	for id in _held.keys():
		if int(_held[id]) == seat:
			gone.append(id)
	for id in gone:
		_held.erase(id)


func is_held_by_other(target: Object, seat: int) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var id := target.get_instance_id()
	if not _held.has(id):
		return false
	return int(_held[id]) != seat


func holder_of(target: Object) -> int:
	if target == null or not is_instance_valid(target):
		return -1
	var id := target.get_instance_id()
	if not _held.has(id):
		return -1
	return int(_held[id])
