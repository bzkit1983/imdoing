extends StaticBody2D
## Permanent self-checkout furniture (`self_cashier`). Queue API mirrors cashier.gd
## for guest pick_register; always-on ~10s auto-pay with durability + repair BAR.

const Tuning = preload("res://scripts/tuning.gd")

var kind: String = "self_cashier"
var queue: Array = []
var label: Label
var front_offset := Vector2(0, -78)
var slot_gap := 48.0
var facing := Vector2.UP
var register_index: int = 0
var _label_n: int = -1

var durability: float = 100.0
var _host: Node
var _pay_customer: Node
var _pay_progress: float = 0.0
var _broken_sfx_armed: bool = true

var _repairing: bool = false
var _repair_seat: int = -1
var _repair_t: float = 0.0
var _repair_draw: Node2D


func bind_host(host: Node) -> void:
	_host = host


func set_facing(dir: Vector2) -> void:
	facing = dir.normalized() if dir.length_squared() > 0.01 else Vector2.UP
	front_offset = facing * 78.0


func is_broken() -> bool:
	return durability <= 0.0


func queue_dissat_mult() -> float:
	return 2.0 if is_broken() else 1.0


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
	if customer == _pay_customer:
		_clear_pay_customer()
	queue.erase(customer)
	_compact_queue_stands()
	_refresh_label()


func queue_index_of(customer) -> int:
	return int(queue.find(customer))


func slot_position(index: int) -> Vector2:
	return global_position + front_offset + facing * slot_gap * float(index)


func _compact_queue_stands() -> void:
	const CustomerScript = preload("res://scripts/customer.gd")
	for i in queue.size():
		var c = queue[i]
		if c == null or not is_instance_valid(c):
			continue
		if c.get("_queue_idx") != null:
			c.set("_queue_idx", i)
		var st := int(c.get("state")) if c.get("state") != null else -1
		if st != CustomerScript.State.QUEUE and st != CustomerScript.State.PAYING:
			continue
		c.global_position = slot_position(i)
		if c.get("velocity") != null:
			c.set("velocity", Vector2.ZERO)
		if c.has_method("_clear_route"):
			c.call("_clear_route")


func back_position() -> Vector2:
	return global_position - facing * 52.0


func can_repair() -> bool:
	return is_broken() and not _repairing


func begin_repair(seat: int) -> bool:
	if not can_repair():
		return false
	_repairing = true
	_repair_seat = seat
	_repair_t = 0.0
	_ensure_repair_draw()
	_refresh_label()
	return true


func cancel_repair(seat: int = -1) -> void:
	if not _repairing:
		return
	if seat >= 0 and _repair_seat >= 0 and seat != _repair_seat:
		return
	_repairing = false
	_repair_seat = -1
	_hide_repair_draw()
	_refresh_label()


func try_repair_hit(seat: int) -> bool:
	if not _repairing:
		return false
	if _repair_seat >= 0 and seat != _repair_seat:
		return false
	var zone := _cursor_zone()
	var heal := Tuning.self_cashier_repair_heal(zone)
	durability = minf(Tuning.SELF_CASHIER_DURABILITY_MAX, durability + float(heal))
	_repairing = false
	_repair_seat = -1
	_hide_repair_draw()
	_broken_sfx_armed = durability <= 0.0
	_refresh_label()
	return true


func _cursor_zone() -> String:
	## Ping-pong 0..1 across seven equal zones L→R: blank red yellow green yellow red white.
	var trip := absf(fposmod(_repair_t * Tuning.SELF_CASHIER_REPAIR_HZ * 2.0, 2.0) - 1.0)
	var idx := clampi(int(floor(trip * 7.0)), 0, 6)
	match idx:
		0:
			return "blank"
		1, 5:
			return "red"
		2, 4:
			return "yellow"
		3:
			return "green"
		_:
			return "white"


func _ready() -> void:
	process_physics_priority = 100
	durability = Tuning.SELF_CASHIER_DURABILITY_MAX


func reset_for_open() -> void:
	durability = Tuning.SELF_CASHIER_DURABILITY_MAX
	_clear_pay_customer()
	cancel_repair()
	_broken_sfx_armed = true
	_refresh_label()


func _physics_process(delta: float) -> void:
	if _repairing:
		_repair_t += delta
		if is_instance_valid(_repair_draw) and _repair_draw.has_method("queue_redraw"):
			_repair_draw.queue_redraw()
	if not is_instance_valid(_host):
		return
	var phase := str(_host.get("phase"))
	if phase == "closed" or phase == "prep":
		_clear_pay_customer()
		return
	if _host.has_method("asking_early_close") and _host.asking_early_close():
		return
	_tick_auto_pay(delta)
	_refresh_label()


func _tick_auto_pay(delta: float) -> void:
	if is_broken():
		if _pay_customer != null:
			_fail_pay_break()
		return
	var cust = ready_customer()
	if _pay_customer != null and (not is_instance_valid(_pay_customer) or _pay_customer != cust):
		_clear_pay_customer()
	if not is_instance_valid(_pay_customer):
		if cust == null:
			return
		if cust.get("is_boss") == true or (cust.has_method("blocks_auto_checkout") and bool(cust.call("blocks_auto_checkout"))):
			return
		_pay_customer = cust
		_pay_progress = 0.0
	_pay_progress += delta
	## Continuous durability drain while paying (~10 over full pay window).
	var drain := Tuning.SELF_CASHIER_DRAIN_PER_SEC * delta
	durability = maxf(0.0, durability - drain)
	if _pay_progress + 0.00001 >= Tuning.SELF_CASHIER_PAY_SEC:
		var paying := _pay_customer
		_clear_pay_customer()
		var amount: int = int(paying.payout_total())
		_host._on_paid(amount, paying.get("is_elite") == true, 0, self, false, paying, false)
		SfxBus.play("sfx_checkout_cash_pop2")
		paying.finish_paid()
		dequeue(paying)
		if durability <= 0.0:
			_mark_broken()
		return
	if durability <= 0.0:
		_fail_pay_break()


func _fail_pay_break() -> void:
	var paying = _pay_customer
	_clear_pay_customer()
	if paying != null and is_instance_valid(paying):
		if paying.has_method("cancel_pay"):
			paying.cancel_pay()
		if paying.has_method("gain_dissat"):
			paying.gain_dissat(Tuning.SELF_CASHIER_BREAK_DISSAT)
	_mark_broken()


func _mark_broken() -> void:
	durability = 0.0
	if _broken_sfx_armed:
		_broken_sfx_armed = false
		## Optional id — silent if missing.
		if Engine.get_main_loop() != null:
			SfxBus.play("sfx_self_cashier_break")


func _clear_pay_customer() -> void:
	_pay_customer = null
	_pay_progress = 0.0


func _refresh_label() -> void:
	if label == null:
		return
	var n: int = queue.size()
	var hp := int(ceil(durability))
	var text := Loc.t("world.self_cashier.status", [register_index + 1, n, hp])
	if is_broken():
		text += "\n" + Loc.t("world.self_cashier.broken")
	elif is_instance_valid(_pay_customer):
		var pct := 100.0 * _pay_progress / Tuning.SELF_CASHIER_PAY_SEC
		text += "\n" + Loc.t("world.self_cashier.loading", [pct])
	if _repairing:
		text += "\n" + Loc.t("world.self_cashier.repairing")
	label.text = text
	_label_n = n


func _ensure_repair_draw() -> void:
	if _repair_draw != null and is_instance_valid(_repair_draw):
		_repair_draw.visible = true
		_repair_draw.queue_redraw()
		return
	var drawer := Node2D.new()
	drawer.z_index = 20
	drawer.position = Vector2(0, -110)
	drawer.set_script(load("res://scripts/self_cashier_repair_bar.gd"))
	drawer.set("machine", self)
	add_child(drawer)
	_repair_draw = drawer


func _hide_repair_draw() -> void:
	if _repair_draw != null and is_instance_valid(_repair_draw):
		_repair_draw.visible = false
