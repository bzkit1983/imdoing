extends Node
## Autoload InteractLock — §11.6 L-class target locks by seat.
## First seat to acquire a target blocks other seats until release.
## Online: Host owns the table; keys prefer stable net ids (not instance_id).

## lock_key -> seat_id
var _held: Dictionary = {}


func clear() -> void:
	_held.clear()


## Stable key for networked L-locks. Empty → cannot lock online; local falls back to instance_id.
func lock_key_of(target: Object) -> String:
	if target == null or not is_instance_valid(target):
		return ""
	if target.get("net_shelf_id") != null:
		var sid := int(target.get("net_shelf_id"))
		if sid >= 0:
			return "shelf:%d" % sid
	if target.get("net_agent_id") != null:
		var aid := int(target.get("net_agent_id"))
		if aid >= 0:
			return "agent:%d" % aid
	if target.get("net_restock_id") != null:
		var rid := int(target.get("net_restock_id"))
		if rid >= 0:
			return "restock:%d" % rid
	if target.get("register_index") != null:
		var reg := int(target.get("register_index"))
		if reg >= 0:
			return "register:%d" % reg
	if target.get("net_portal_id") != null:
		var pid := int(target.get("net_portal_id"))
		if pid >= 0:
			return "portal:%d" % pid
	## Dirt / ops pickups often only have instance identity locally.
	var kind := str(target.get("kind")) if target.get("kind") != null else ""
	if kind != "":
		return "inst:%d" % target.get_instance_id()
	return "inst:%d" % target.get_instance_id()


func try_acquire_key(key: String, seat: int) -> bool:
	if key == "":
		return false
	## Online clients never own the lock table — Host enforces L (§11.6).
	if SessionService.is_networked() and SessionService.is_client():
		return true
	if _held.has(key):
		return int(_held[key]) == seat
	_held[key] = seat
	return true


func release_key(key: String, seat: int) -> void:
	if key == "":
		return
	if SessionService.is_networked() and SessionService.is_client():
		return
	if not _held.has(key):
		return
	if int(_held[key]) == seat:
		_held.erase(key)


func try_acquire(target: Object, seat: int) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var key := lock_key_of(target)
	if key == "":
		return false
	return try_acquire_key(key, seat)


func release(target: Object, seat: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	release_key(lock_key_of(target), seat)


func release_all_for_seat(seat: int) -> void:
	if SessionService.is_networked() and SessionService.is_client():
		return
	var gone: Array = []
	for id in _held.keys():
		if int(_held[id]) == seat:
			gone.append(id)
	for id in gone:
		_held.erase(id)


func is_held_by_other(target: Object, seat: int) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	## Client has no authoritative lock table; Host will reject via sim.
	if SessionService.is_networked() and SessionService.is_client():
		return false
	var key := lock_key_of(target)
	if key == "" or not _held.has(key):
		return false
	return int(_held[key]) != seat


func holder_of(target: Object) -> int:
	if target == null or not is_instance_valid(target):
		return -1
	if SessionService.is_networked() and SessionService.is_client():
		return -1
	var key := lock_key_of(target)
	if key == "" or not _held.has(key):
		return -1
	return int(_held[key])
