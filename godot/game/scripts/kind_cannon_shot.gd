extends "res://scripts/drop_flight.gd"
## If the locked thief is no longer convertible at impact, drop the round in place.
var host: Node
var target: Node2D
var owner_seat: int = 0


func _ready() -> void:
	finished.connect(_resolve)


func _process(delta: float) -> void:
	if not is_instance_valid(host) or str(host.get("phase")) not in ["open", "restock"]:
		return
	if host.has_method("asking_early_close") and host.asking_early_close():
		return
	super._process(delta)


func _resolve() -> void:
	if count <= 0:
		return
	count = 0
	var converted := false
	if is_instance_valid(target) and target.has_method("is_active_thief") and target.is_active_thief():
		converted = bool(host.convert_thief_to_guest(target, owner_seat))
	if not converted:
		host.spawn_dropped_box(_to, sku, 1)
