extends StaticBody2D

const Tuning = preload("res://scripts/tuning.gd")

var kind: String = "cashier"
var queue: Array = []
var label: Label
var front_offset := Vector2(0, -78)
var slot_gap := 34.0
var facing := Vector2.UP
var register_index: int = 0
var _label_n: int = -1

# Operators claim first each physics frame; automation runs last.
var _self_host: Node
var _self_left: float = 0.0
var _self_seconds: float = 3.0
var _self_seat: int = 0
var _self_customer: Node
var _self_progress: float = 0.0
var _operator_frame: int = -1
var _self_visible: bool = false



func set_facing(dir: Vector2) -> void:
	facing = dir.normalized() if dir.length_squared() > 0.01 else Vector2.UP
	front_offset = facing * 78.0


func front_customer():
	if queue.is_empty():
		return null
	return queue[0]


func ready_customer():
	var cust = front_customer()
	if cust == null:
		return null
	if cust.has_method("is_at_register") and bool(cust.call("is_at_register")):
		return cust
	return null


func enqueue(customer) -> void:
	if customer in queue:
		return
	queue.append(customer)
	_refresh_label()


func dequeue(customer) -> void:
	if customer == _self_customer:
		_clear_self_customer()
	queue.erase(customer)
	_refresh_label()


func queue_index_of(customer) -> int:
	return int(queue.find(customer))


func slot_position(index: int) -> Vector2:
	return global_position + front_offset + facing * slot_gap * float(index)


func back_position() -> Vector2:
	return global_position - facing * 52.0


func _refresh_label() -> void:
	if label == null:
		return
	var n: int = queue.size()
	if n == _label_n and _self_left <= 0.0 and _self_customer == null and not _self_visible:
		return
	_label_n = n
	label.text = Loc.t("world.cashier.status", [register_index + 1, n])
	_self_visible = _self_left > 0.0 or is_instance_valid(_self_customer)
	if _self_visible:
		var status := Loc.t("self_checkout.active")
		if _self_left <= 0.0:
			status = Loc.t("self_checkout.tail")
		elif _operator_frame == Engine.get_physics_frames():
			status = Loc.t("self_checkout.standby")
		if is_instance_valid(_self_customer):
			status += "\n" + Loc.t("self_checkout.loading", [100.0 * _self_progress / _self_seconds])
		label.text += "\n" + status




func _ready() -> void:
	process_physics_priority = 100


func activate_self_checkout(host: Node, level: int, seat: int) -> void:
	_clear_self_customer()
	_self_host = host
	_self_left = 15.0
	_self_seconds = float(6 - clampi(level, 1, 3))
	_self_seat = seat
	_refresh_label()


func operator_checkout() -> void:
	_operator_frame = Engine.get_physics_frames()
	_clear_self_customer()


func _clear_self_customer() -> void:
	_self_customer = null
	_self_progress = 0.0


func clear_self_checkout() -> void:
	_self_left = 0.0
	_clear_self_customer()
	_refresh_label()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_self_host):
		return
	var phase := str(_self_host.get("phase"))
	if phase == "closed" or phase == "prep":
		clear_self_checkout()
		_self_host = null
		return
	if _self_host.has_method("asking_early_close") and _self_host.asking_early_close():
		return
	_tick_self_checkout(delta)


func _tick_self_checkout(delta: float) -> void:
	var available := minf(delta, maxf(0.0, _self_left))
	_self_left = maxf(0.0, _self_left - delta)
	var cust = ready_customer()
	if _self_customer != null and (not is_instance_valid(_self_customer) or _self_customer != cust):
		_clear_self_customer()
	var occupied := _operator_frame == Engine.get_physics_frames()
	if _self_host.has_method("seat_locks_register"):
		occupied = occupied or bool(_self_host.seat_locks_register(self))
	if occupied:
		_clear_self_customer()
		_refresh_label()
		return
	if not is_instance_valid(_self_customer):
		if _self_left <= 0.0 or cust == null:
			_refresh_label()
			return
		_self_customer = cust
		_self_progress = available
	else:
		_self_progress += delta
	if _self_progress + 0.00001 >= _self_seconds:
		var paying := _self_customer
		_clear_self_customer()
		var amount: int = int(paying.payout_total())
		_self_host._on_paid(amount, paying.get("is_elite") == true, _self_seat, self, false)
		SfxBus.play("sfx_checkout_circle_done")
		paying.finish_paid()
		dequeue(paying)
	_refresh_label()
