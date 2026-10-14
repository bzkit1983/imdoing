extends CharacterBody2D

const Tuning = preload("res://scripts/tuning.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const CircleScript = preload("res://scripts/loading_circle.gd")
const BoxStackScript = preload("res://scripts/box_stack.gd")
const PromptScript = preload("res://scripts/command_prompt.gd")

signal stats_changed
signal log_line(text: String)
signal paid(amount: int)

var inventory = InventoryScript.new()
var stamina: float = Tuning.stamina_max()
var facing: Vector2 = Vector2.RIGHT
var hold_progress: float = 0.0
var blocked_mismatch: bool = false
var target: Node2D = null
var interactables: Array[Node2D] = []
var dirt_contacts: int = 0
var command_lock: bool = false
var seq_index: int = 0
var seq_done: bool = false

var _k_held: bool = false
var _k_time: float = 0.0
var _running: bool = false
var _dashing: bool = false
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_left: float = 0.0
var _regen_delay: float = 0.0
var _j_held: bool = false
var _pickup_used: bool = false
var _circle: Node2D
var _prompt: Node2D
var _body: Polygon2D
var _arrow: Polygon2D
var _no_queue_logged: bool = false


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	stamina = Tuning.stamina_max()
	_circle = CircleScript.new()
	add_child(_circle)
	_prompt = PromptScript.new()
	add_child(_prompt)
	var stack := BoxStackScript.new()
	stack.position = Vector2(0, -6)
	stack.setup(inventory)
	add_child(stack)


func bind_visuals(body: Polygon2D, arrow: Polygon2D) -> void:
	_body = body
	_arrow = arrow


func add_dirt(delta_count: int) -> void:
	dirt_contacts = maxi(0, dirt_contacts + delta_count)


func on_dirt() -> bool:
	return dirt_contacts > 0


func move_state() -> String:
	if command_lock:
		return "收銀指令"
	if _dashing:
		return "DASH"
	if _running and velocity.length() > 8.0:
		return "RUN"
	if velocity.length() > 8.0:
		return "WALK"
	return "IDLE"


func speed_mult() -> float:
	var m := Tuning.agi_mult()
	var n := inventory.count()
	if n > Tuning.CARRY_CAP:
		m *= Tuning.OVERWEIGHT_OVER_CAP_MULT
	elif n >= Tuning.CARRY_CAP:
		m *= Tuning.OVERWEIGHT_AT_CAP_MULT
	if on_dirt():
		m *= Tuning.DIRT_MULT
	return clampf(m, 0.0, Tuning.SPEED_MAX_MULT)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or key_event.echo:
		return
	var key: int = key_event.physical_keycode
	if command_lock and key_event.pressed and not seq_done:
		var dir := _dir_from_key(key)
		if dir >= 0:
			_try_command(dir)
			return
	if key == KEY_K:
		if command_lock:
			return
		if key_event.pressed:
			_k_held = true
			_k_time = 0.0
		else:
			if _k_held and not _running and _k_time < Tuning.RUN_HOLD_THRESHOLD:
				_try_dash()
			_k_held = false
			_running = false
	elif key == KEY_J or key == KEY_ENTER:
		_j_held = key_event.pressed
		if not key_event.pressed:
			_reset_hold()
			_pickup_used = false
			_no_queue_logged = false
	elif key_event.pressed:
		_handle_hotkeys(key)


func _physics_process(delta: float) -> void:
	command_lock = _j_held and target != null and String(target.get("kind")) == "cashier"
	if not command_lock:
		_prompt.active = false
	if _k_held and not command_lock:
		_k_time += delta
		if _k_time >= Tuning.RUN_HOLD_THRESHOLD:
			_running = stamina > 1.0
	if _dashing:
		_tick_dash(delta)
	else:
		_tick_move(delta)
	_regen(delta)
	_update_target()
	_tick_action(delta)
	if _circle:
		_circle.progress = hold_progress
		_circle.blocked = blocked_mismatch
	_update_visuals()
	stats_changed.emit()


func _move_axis() -> Vector2:
	if command_lock:
		return Vector2.ZERO
	var v := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _tick_move(delta: float) -> void:
	var axis := _move_axis()
	if axis != Vector2.ZERO:
		facing = axis
		if _j_held and not command_lock:
			_reset_hold()
	var want_run := _running and axis != Vector2.ZERO
	if want_run:
		if stamina <= 0.0:
			want_run = false
			_running = false
		else:
			stamina = maxf(0.0, stamina - Tuning.RUN_STAMINA_PER_SEC * delta)
			_regen_delay = Tuning.STAMINA_REGEN_DELAY
	var walk := Tuning.WALK_SPEED * speed_mult()
	var target_speed := walk * (Tuning.RUN_SPEED_MULT if want_run else 1.0)
	target_speed = clampf(target_speed, Tuning.SPEED_FLOOR, Tuning.WALK_SPEED * Tuning.SPEED_MAX_MULT)
	if axis == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, walk * 8.0 * delta)
	else:
		velocity = axis * target_speed
	move_and_slide()


func _try_dash() -> void:
	if _dashing or stamina < Tuning.DASH_STAMINA_COST:
		return
	var dir := _move_axis()
	if dir == Vector2.ZERO:
		dir = facing
	_dashing = true
	_dash_dir = dir.normalized()
	_dash_left = Tuning.DASH_TIME
	stamina = maxf(0.0, stamina - Tuning.DASH_STAMINA_COST)
	_regen_delay = Tuning.STAMINA_REGEN_DELAY
	_reset_hold()


func _tick_dash(delta: float) -> void:
	_dash_left -= delta
	var speed := Tuning.DASH_DISTANCE / Tuning.DASH_TIME
	speed = minf(speed, Tuning.WALK_SPEED * Tuning.SPEED_MAX_MULT)
	velocity = _dash_dir * speed
	move_and_slide()
	if _dash_left <= 0.0:
		_dashing = false
		velocity *= 0.35


func _regen(delta: float) -> void:
	if _dashing or (_running and _move_axis() != Vector2.ZERO):
		return
	if _regen_delay > 0.0:
		_regen_delay -= delta
		return
	stamina = minf(Tuning.stamina_max(), stamina + Tuning.STAMINA_REGEN_PER_SEC * delta)


func _update_target() -> void:
	var best: Node2D = null
	var best_score := -1.0
	for node in interactables:
		if node == null:
			continue
		var to_obj: Vector2 = node.global_position - global_position
		var dist := to_obj.length()
		if dist > Tuning.INTERACT_RANGE or dist < 0.001:
			continue
		var dot := facing.dot(to_obj.normalized())
		if String(node.get("kind")) == "cashier":
			# Prefer standing behind the register (south of it).
			if global_position.y < node.global_position.y - 8.0:
				continue
			dot = 1.0
		elif dot < Tuning.FACE_DOT:
			continue
		var score := dot * 2.0 - dist / Tuning.INTERACT_RANGE
		if score > best_score:
			best_score = score
			best = node
	if target != best:
		_reset_hold()
		_pickup_used = false
	target = best


func _tick_action(delta: float) -> void:
	blocked_mismatch = false
	if target == null or not _j_held:
		if not _j_held:
			hold_progress = 0.0
		return
	var kind := String(target.get("kind"))
	if kind == "restock":
		_try_pickup()
	elif kind == "shelf":
		_tick_restock(delta)
	elif kind == "cashier":
		_tick_cashier(delta)


func _try_pickup() -> void:
	if _pickup_used:
		return
	_pickup_used = true
	if not inventory.can_take_box():
		log_line.emit("負重不足：一箱需要 %d 件空位（%d/%d）" % [Tuning.BOX_SIZE, inventory.count(), Tuning.CARRY_CAP])
		return
	if not bool(target.call("take_box")):
		log_line.emit("%s 補貨點已空" % Tuning.sku_name(String(target.call("selected_sku"))))
		return
	var sku := String(target.call("selected_sku"))
	inventory.take_box(sku)
	log_line.emit("執貨（即時）%s 1箱 +%d" % [Tuning.sku_name(sku), Tuning.BOX_SIZE])


func _tick_restock(delta: float) -> void:
	if inventory.is_empty():
		log_line.emit("空手 — 不能對貨架互動")
		_j_held = false
		return
	var run: Dictionary = inventory.trailing_run()
	var sku := String(run["id"])
	if not bool(target.call("can_accept", sku)):
		if int(target.get("count")) >= Tuning.SHELF_CAP:
			log_line.emit("貨架已滿")
			_j_held = false
			_reset_hold()
			return
		blocked_mismatch = true
		hold_progress = 0.0
		return
	hold_progress = minf(1.0, hold_progress + delta / Tuning.restock_seconds())
	if hold_progress >= 1.0:
		var placed := int(target.call("add_items", sku, int(run["count"])))
		inventory.remove_trailing(placed)
		log_line.emit("上架 %s ×%d" % [Tuning.sku_name(sku), placed])
		hold_progress = 0.0


func _tick_cashier(delta: float) -> void:
	var cust = target.call("ready_customer")
	if cust == null:
		_prompt.active = false
		if not _no_queue_logged:
			if target.call("front_customer") != null:
				log_line.emit("客人還在前往收銀機，請等到隊伍前端")
			else:
				log_line.emit("收銀機前沒有客人")
			_no_queue_logged = true
		return
	_ensure_seq(cust)
	_prompt.active = true
	_prompt.sequence = cust.checkout_seq
	_prompt.index = seq_index
	if not seq_done:
		return
	hold_progress = minf(1.0, hold_progress + delta / Tuning.checkout_seconds())
	if hold_progress >= 1.0:
		_finish_checkout(cust)


func _ensure_seq(cust) -> void:
	if cust.checkout_seq.is_empty():
		var n := Tuning.command_count(cust.cart.size())
		var seq: Array[int] = []
		for i in n:
			seq.append(randi() % 4)
		cust.checkout_seq = seq
		seq_index = 0
		seq_done = false
		log_line.emit("收銀指令 %d 次（購物 %d 件）" % [n, cust.cart.size()])
	cust.begin_paying()


func _try_command(dir: int) -> void:
	var cust = target.call("ready_customer") if target else null
	if cust == null or seq_done:
		return
	var seq: Array = cust.checkout_seq
	if seq.is_empty() or seq_index >= seq.size():
		return
	if dir == int(seq[seq_index]):
		_prompt.fail_at = -1
		seq_index += 1
		if seq_index >= seq.size():
			seq_done = true
			log_line.emit("指令完成 — 維持長按出現 Loading Circle")
	else:
		_prompt.fail_at = seq_index
		seq_index = 0
		log_line.emit("指令錯誤 ✕ 同一串重來")


func _finish_checkout(cust) -> void:
	var amount: int = int(cust.call("cart_total"))
	paid.emit(amount)
	log_line.emit("收銀完成  +$%d" % amount)
	_spawn_dollar()
	cust.finish_paid()
	if target:
		target.dequeue(cust)
	seq_index = 0
	seq_done = false
	hold_progress = 0.0
	_prompt.active = false


func _spawn_dollar() -> void:
	var lab := Label.new()
	lab.text = "$"
	lab.position = Vector2(-6, -90)
	lab.add_theme_font_size_override("font_size", 28)
	lab.add_theme_color_override("font_color", Color("e8c36a"))
	add_child(lab)
	var tw := create_tween()
	tw.tween_property(lab, "position:y", -130.0, 0.55)
	tw.parallel().tween_property(lab, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lab.queue_free)


func _dir_from_key(key: int) -> int:
	match key:
		KEY_W:
			return 0
		KEY_S:
			return 1
		KEY_A:
			return 2
		KEY_D:
			return 3
	return -1


func _reset_hold() -> void:
	if hold_progress > 0.0 or seq_index > 0:
		log_line.emit("放手 — 指令與 Circle 重置")
	hold_progress = 0.0
	blocked_mismatch = false
	seq_index = 0
	seq_done = false
	if _prompt:
		_prompt.active = false
		_prompt.fail_at = -1
	if target != null and String(target.get("kind")) == "cashier":
		var cust = target.call("front_customer")
		if cust:
			cust.cancel_pay()


func _handle_hotkeys(key: int) -> void:
	if key == KEY_L or key == KEY_SEMICOLON or key == KEY_U:
		log_line.emit("v0.2 不實作技能")
		return
	if target == null or String(target.get("kind")) != "restock":
		return
	match key:
		KEY_Q:
			target.call("cycle", -1)
		KEY_E:
			target.call("cycle", 1)
		KEY_1:
			target.call("set_highlight", 0)
		KEY_2:
			target.call("set_highlight", 1)
		KEY_3:
			target.call("set_highlight", 2)


func _update_visuals() -> void:
	if _arrow:
		_arrow.rotation = facing.angle() + PI / 2.0
	if _body == null:
		return
	if command_lock:
		_body.color = Color("e8c36a")
	elif _dashing:
		_body.color = Color("f4d35e")
	elif _running:
		_body.color = Color("2a9d8f")
	elif on_dirt():
		_body.color = Color("6b4f3a")
	else:
		_body.color = Color("2a6b4a")
