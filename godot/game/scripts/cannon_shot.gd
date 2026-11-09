extends "res://scripts/drop_flight.gd"
## Independent from its turret: cancellation cannot destroy an airborne item.
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
	var accepted := false
	if is_instance_valid(target):
		if target.has_method("is_active_thief") and target.is_active_thief():
			host.cannon_hit_thief(target, owner_seat, (_to - _from).normalized())
		elif target.has_method("can_receive_delivery") and not target.get("is_thief") and not target.get("temp_clerk") and target.can_receive_delivery() and target.shopping.has(sku):
			accepted = target.accept_toss_box(sku, 1) == 1
		elif target.has_method("can_accept") and target.can_accept(sku):
			accepted = target.add_items(sku, 1) == 1
	if not accepted:
		host.spawn_dropped_box(_to, sku, 1)
