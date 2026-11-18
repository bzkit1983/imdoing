extends "res://scripts/drop_flight.gd"
## Warehouse-paid delivery projectile; invalid demand becomes an ordinary floor drop.

var host: Node
var target: Node2D
var owner_seat: int = 0
var reservation_target_id: int = 0


func _ready() -> void:
	finished.connect(_resolve)


func _process(delta: float) -> void:
	if not is_instance_valid(host) or str(host.get("phase")) not in ["open", "restock"]:
		return
	if host.has_method("asking_early_close") and host.call("asking_early_close"):
		return
	super._process(delta)


func _resolve() -> void:
	if count <= 0:
		return
	count = 0
	var delivered := false
	if is_instance_valid(host):
		delivered = bool(
			host.call(
				"resolve_elite_guest_cannon_delivery",
				target,
				sku,
				owner_seat,
				reservation_target_id,
			)
		)
	if not delivered and is_instance_valid(host):
		host.call("spawn_dropped_box", _to, sku, 1)


func _recycle() -> void:
	## Subclass projectiles must not enter DropFlight's shared generic pool.
	visible = false
	set_process(false)
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
