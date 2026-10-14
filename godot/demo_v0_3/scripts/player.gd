extends CharacterBody2D

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const CircleScript = preload("res://scripts/loading_circle.gd")
const BoxStackScript = preload("res://scripts/box_stack.gd")
const PromptScript = preload("res://scripts/command_prompt.gd")
const MenuScript = preload("res://scripts/skill_menu.gd")

signal stats_changed
signal log_line(text: String)
signal paid(amount: int)
signal skill_cast(skill_name: String, is_ult: bool)

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
var skill_menu_open: bool = false
var ult_prep: bool = false
var stick_axis: Vector2 = Vector2.ZERO
var clock_scale: float = 1.0
var customer_move_mult: float = 1.0
var camera: Camera2D

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
var _menu: Node2D
var _body: Polygon2D
var _arrow: Polygon2D
var _no_queue_logged: bool = false
var _l_held: bool = false
var _l_time: float = 0.0
var _u_held: bool = false
var _ult_index: int = 0
var _cd: Dictionary = {}
var _buffs: Dictionary = {}
var _cardinal_armed: bool = true
var _passive_checkout_pct: float = 0.0
var _restock_picking: bool = false
var _restock_hold: float = 0.0
var _restock_aborted: bool = false


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	stamina = Tuning.stamina_max()
	_circle = CircleScript.new()
	add_child(_circle)
	_prompt = PromptScript.new()
	add_child(_prompt)
	_menu = MenuScript.new()
	add_child(_menu)
	var stack := BoxStackScript.new()
	stack.position = Vector2(0, -6)
	stack.setup(inventory)
	add_child(stack)
	for sk in Skills.EQUIPPED:
		if String(sk.get("kind")) == "passive":
			_passive_checkout_pct += float(sk.get("checkout_pct", 0.0))


func bind_visuals(body: Polygon2D, arrow: Polygon2D) -> void:
	_body = body
	_arrow = arrow


func add_dirt(delta_count: int) -> void:
	dirt_contacts = maxi(0, dirt_contacts + delta_count)


func on_dirt() -> bool:
	return dirt_contacts > 0


func carry_cap() -> int:
	var n := Tuning.CARRY_CAP
	if _buffs.has("carry_boost"):
		n += int(Skills.slot(0).get("carry_add", 0))
	return n


func move_pct_bonus() -> float:
	if _buffs.has("move_boost"):
		return float(Skills.slot(1).get("move_pct", 0.0))
	return 0.0


func restock_seconds_now() -> float:
	var base := Tuning.restock_seconds()
	if _buffs.has("instant_restock"):
		var sk := Skills.slot(4)
		if bool(sk.get("restock_instant", false)):
			return 0.0
		return base * float(sk.get("restock_circle_mult", 1.0))
	return base


func checkout_seconds_now() -> float:
	var sec := Tuning.checkout_seconds()
	var pct := _passive_checkout_pct
	return sec / (1.0 + pct)


func cd_left(skill_id: String) -> float:
	return float(_cd.get(skill_id, 0.0))


func buff_left(skill_id: String) -> float:
	return float(_buffs.get(skill_id, 0.0))


func store_status_text() -> String:
	var bits: PackedStringArray = []
	if _buffs.has("the_world"):
		bits.append("The World! 時停 %.0fs" % _buffs["the_world"])
	if _buffs.has("metal_rush"):
		bits.append("金屬狂潮 +150%% %.0fs" % _buffs["metal_rush"])
	if bits.is_empty():
		return "商店狀態  無技能效果"
	return "商店狀態  " + " · ".join(bits)


func role_status_text() -> String:
	var bits: PackedStringArray = []
	bits.append("STR%d AGI%d INT%d" % [Tuning.STR, Tuning.AGI, Tuning.INT])
	if _buffs.has("carry_boost"):
		bits.append("負重+60 %.0fs" % _buffs["carry_boost"])
	if _buffs.has("move_boost"):
		bits.append("移速+60%% %.0fs" % _buffs["move_boost"])
	if _buffs.has("instant_restock"):
		bits.append("瞬間上架 %.0fs" % _buffs["instant_restock"])
	if _passive_checkout_pct > 0.0:
		bits.append("收銀+%.0f%%" % (_passive_checkout_pct * 100.0))
	return "角色狀態  " + " ".join(bits)


func set_hold(action: String, pressed: bool) -> void:
	match action:
		"interact":
			if pressed:
				_j_held = true
				_restock_hold = 0.0
				_restock_aborted = false
				_pickup_used = false
				_no_queue_logged = false
			else:
				_release_restock_interact()
				_j_held = false
				_reset_hold()
				_pickup_used = false
				_no_queue_logged = false
		"dash":
			if command_lock or skill_menu_open or ult_prep:
				return
			if pressed:
				_k_held = true
				_k_time = 0.0
			else:
				if _k_held and not _running and _k_time < Tuning.RUN_HOLD_THRESHOLD:
					_try_dash()
				_k_held = false
				_running = false
		"skill":
			_on_skill_hold(pressed)
		"ult":
			_on_ult_hold(pressed)
		"cancel":
			if pressed:
				_cancel_input()


func move_state() -> String:
	if ult_prep:
		return "奧義指令"
	if skill_menu_open:
		return "技能選單"
	if _restock_picking:
		return "選貨"
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
	m *= 1.0 + move_pct_bonus()
	var n := inventory.count()
	var cap := carry_cap()
	if n > cap:
		m *= Tuning.OVERWEIGHT_OVER_CAP_MULT
	elif n >= cap:
		m *= Tuning.OVERWEIGHT_AT_CAP_MULT
	if on_dirt():
		m *= Tuning.DIRT_MULT
	return clampf(m, 0.0, Tuning.SPEED_MAX_MULT)


func _in_dir_mode() -> bool:
	if ult_prep or skill_menu_open or _restock_picking:
		return true
	if _j_held and target != null and String(target.get("kind")) == "cashier":
		return true
	return command_lock


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_on_key_event(event as InputEventKey)
	elif event is InputEventJoypadButton:
		_on_pad_button(event as InputEventJoypadButton)


func _on_key_event(key_event: InputEventKey) -> void:
	if key_event.echo:
		return
	var key: int = key_event.physical_keycode
	# Keyboard directions are WASD only — never Xbox A/B/X/Y.
	if key_event.pressed:
		var dir := _dir_from_key(key)
		if dir >= 0 and _in_dir_mode():
			_try_dir(dir)
			get_viewport().set_input_as_handled()
			return
	if key == KEY_K:
		set_hold("dash", key_event.pressed)
		get_viewport().set_input_as_handled()
	elif key == KEY_J or key == KEY_ENTER:
		set_hold("interact", key_event.pressed)
		get_viewport().set_input_as_handled()
	elif key == KEY_L:
		set_hold("skill", key_event.pressed)
		get_viewport().set_input_as_handled()
	elif key == KEY_U:
		set_hold("ult", key_event.pressed)
		get_viewport().set_input_as_handled()
	elif key == KEY_SEMICOLON or key == KEY_BACKSPACE:
		if key_event.pressed:
			_cancel_input()
			get_viewport().set_input_as_handled()
	elif key_event.pressed:
		_handle_hotkeys(key)


func _on_pad_button(pad: InputEventJoypadButton) -> void:
	# Xbox layout: A/B/X/Y are actions. D-pad is directions.
	match pad.button_index:
		JOY_BUTTON_A:
			set_hold("interact", pad.pressed)
		JOY_BUTTON_B:
			if pad.pressed:
				_cancel_input()
		JOY_BUTTON_X:
			set_hold("dash", pad.pressed)
		JOY_BUTTON_Y:
			set_hold("skill", pad.pressed)
		JOY_BUTTON_RIGHT_SHOULDER:
			set_hold("ult", pad.pressed)
		JOY_BUTTON_DPAD_UP:
			if pad.pressed and _in_dir_mode():
				_try_dir(0)
		JOY_BUTTON_DPAD_DOWN:
			if pad.pressed and _in_dir_mode():
				_try_dir(1)
		JOY_BUTTON_DPAD_LEFT:
			if pad.pressed and _in_dir_mode():
				_try_dir(2)
		JOY_BUTTON_DPAD_RIGHT:
			if pad.pressed and _in_dir_mode():
				_try_dir(3)
		_:
			return
	get_viewport().set_input_as_handled()


func _cancel_input() -> void:
	if _restock_picking:
		_abort_restock_pick()
		_restock_aborted = true
		_j_held = false
		log_line.emit("取消選貨")
		return
	if skill_menu_open or _l_held:
		_close_skill_hold()
		log_line.emit("取消技能選單")
	if ult_prep:
		_on_ult_hold(false)
	if _j_held:
		set_hold("interact", false)


func _physics_process(delta: float) -> void:
	_tick_buffs(delta)
	command_lock = _j_held and target != null and String(target.get("kind")) == "cashier" and not skill_menu_open and not ult_prep
	if not command_lock and not ult_prep:
		_prompt.active = false
	if _k_held and not command_lock and not skill_menu_open and not ult_prep:
		_k_time += delta
		if _k_time >= Tuning.RUN_HOLD_THRESHOLD:
			_running = stamina > 1.0
	if _l_held:
		_l_time += delta
		if not skill_menu_open and _l_time >= Skills.HOLD_MENU_SEC:
			skill_menu_open = true
			_menu.open = true
			_menu.set_slots(Skills.EQUIPPED, _cd)
			log_line.emit("技能選單 — WASD／搖桿選技能2–5，放手取消")
	if _dashing:
		_tick_dash(delta)
	else:
		_tick_move(delta)
	_poll_stick_cardinal()
	_regen(delta)
	_update_target()
	_tick_action(delta)
	if _circle:
		_circle.progress = hold_progress
		_circle.blocked = blocked_mismatch
	if _menu:
		_menu.open = skill_menu_open
		if skill_menu_open:
			_menu.set_slots(Skills.EQUIPPED, _cd)
	_update_visuals()
	stats_changed.emit()


func _tick_buffs(delta: float) -> void:
	var gone: Array[String] = []
	for id in _buffs.keys():
		_buffs[id] = float(_buffs[id]) - delta
		if float(_buffs[id]) <= 0.0:
			gone.append(String(id))
	for id in gone:
		_buffs.erase(id)
	for id in _cd.keys():
		_cd[id] = maxf(0.0, float(_cd[id]) - delta)
	clock_scale = 0.0 if _buffs.has("the_world") else 1.0
	customer_move_mult = 1.0
	if _buffs.has("metal_rush"):
		customer_move_mult += float(Skills.slot(2).get("customer_move_pct", 0.0))
	if _buffs.has("the_world"):
		customer_move_mult = 0.0


func _move_axis() -> Vector2:
	if _in_dir_mode():
		return Vector2.ZERO
	var v := _key_move_axis() + _pad_move_axis() + stick_axis
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _key_move_axis() -> Vector2:
	return Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)


func _pad_analog_axis() -> Vector2:
	var v := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	if v.length() < 0.25:
		return Vector2.ZERO
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _pad_move_axis() -> Vector2:
	var v := _pad_analog_axis()
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		v.x += 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		v.x -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		v.y += 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		v.y -= 1.0
	if v.length() < 0.25:
		return Vector2.ZERO
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _poll_stick_cardinal() -> void:
	# Touch stick / left analog only. WASD and D-pad are discrete press events.
	if not _in_dir_mode():
		_cardinal_armed = true
		return
	var v := stick_axis + _pad_analog_axis()
	if v.length() < 0.55:
		_cardinal_armed = true
		return
	if not _cardinal_armed:
		return
	_cardinal_armed = false
	var dir := 0
	if absf(v.x) > absf(v.y):
		dir = 3 if v.x > 0.0 else 2
	else:
		dir = 1 if v.y > 0.0 else 0
	_try_dir(dir)


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
		if _restock_picking and target != null and String(target.get("kind")) == "restock":
			target.call("abort_pick")
		_restock_picking = false
		_restock_hold = 0.0
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
		_tick_sku_pick(delta)
	elif kind == "shelf":
		_tick_restock(delta)
	elif kind == "cashier":
		_tick_cashier(delta)


func _tick_sku_pick(delta: float) -> void:
	_restock_hold += delta
	if _restock_picking or _restock_hold < Tuning.SKU_PICK_HOLD:
		return
	_restock_picking = true
	target.call("begin_pick")
	log_line.emit("貨品清單 — 上下選擇，放手確定，B／; 取消")


func _release_restock_interact() -> void:
	if _restock_aborted:
		_restock_aborted = false
		_restock_picking = false
		_restock_hold = 0.0
		return
	if target != null and String(target.get("kind")) == "restock":
		if _restock_picking:
			var sku := String(target.call("commit_pick"))
			log_line.emit("補貨點改為 %s" % Tuning.sku_name(sku))
		elif _restock_hold < Tuning.SKU_PICK_HOLD:
			_try_pickup()
	elif _restock_picking:
		_abort_restock_pick()
	_restock_picking = false
	_restock_hold = 0.0


func _abort_restock_pick() -> void:
	if target != null and String(target.get("kind")) == "restock":
		target.call("abort_pick")
	_restock_picking = false
	_restock_hold = 0.0


func _try_pickup() -> void:
	if _pickup_used:
		return
	_pickup_used = true
	if not inventory.can_take_box(carry_cap()):
		log_line.emit("負重不足：一箱需要 %d 件空位（%d/%d）" % [Tuning.BOX_SIZE, inventory.count(), carry_cap()])
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
	var dur := restock_seconds_now()
	if dur <= 0.001:
		hold_progress = 1.0
	else:
		hold_progress = minf(1.0, hold_progress + delta / dur)
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
	hold_progress = minf(1.0, hold_progress + delta / checkout_seconds_now())
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


func _try_dir(dir: int) -> void:
	if _restock_picking:
		if target != null and String(target.get("kind")) == "restock":
			if dir == 0:
				target.call("move_pick", -1)
			elif dir == 1:
				target.call("move_pick", 1)
		return
	if ult_prep:
		_try_ult_dir(dir)
		return
	if skill_menu_open:
		var slot_i: int = int(Skills.DIR_TO_SLOT.get(dir, -1))
		if slot_i >= 0:
			_cast_slot(slot_i)
			_close_skill_hold()
		return
	if command_lock:
		_try_command(dir)


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


func _on_skill_hold(pressed: bool) -> void:
	if pressed:
		_l_held = true
		_l_time = 0.0
		skill_menu_open = false
		return
	var was_menu := skill_menu_open
	_close_skill_hold()
	if not was_menu and _l_time < Skills.HOLD_MENU_SEC:
		_cast_slot(0)


func _close_skill_hold() -> void:
	_l_held = false
	skill_menu_open = false
	if _menu:
		_menu.open = false


func _on_ult_hold(pressed: bool) -> void:
	if pressed:
		if cd_left("the_world") > 0.05:
			log_line.emit("奧義冷卻中 %.0fs" % cd_left("the_world"))
			return
		_u_held = true
		ult_prep = true
		_ult_index = 0
		_prompt.active = true
		var seq: Array[int] = []
		for d in Skills.ULTIMATE["seq"]:
			seq.append(int(d))
		_prompt.sequence = seq
		_prompt.index = 0
		_prompt.fail_at = -1
		log_line.emit("奧義準備 — 輸入 上上下下左右左右")
		return
	if ult_prep:
		log_line.emit("放手 — 奧義取消")
	_u_held = false
	ult_prep = false
	if not command_lock:
		_prompt.active = false
		_prompt.fail_at = -1


func _try_ult_dir(dir: int) -> void:
	var seq: Array = Skills.ULTIMATE["seq"]
	if dir == int(seq[_ult_index]):
		_prompt.fail_at = -1
		_ult_index += 1
		_prompt.index = _ult_index
		if _ult_index >= seq.size():
			_cast_ultimate()
			_u_held = false
			ult_prep = false
	else:
		_prompt.fail_at = _ult_index
		_ult_index = 0
		_prompt.index = 0
		log_line.emit("奧義指令錯誤 ✕ 同一串重來")


func _cast_slot(i: int) -> void:
	var sk: Dictionary = Skills.slot(i)
	if sk.is_empty():
		return
	if String(sk.get("kind")) != "active":
		log_line.emit("%s 是被動技能，無法主動施放" % String(sk.get("name")))
		return
	var sid := String(sk.get("id"))
	if cd_left(sid) > 0.05:
		log_line.emit("%s 冷卻中 %.0fs" % [String(sk.get("name")), cd_left(sid)])
		return
	_cd[sid] = float(sk.get("cd", Skills.ACTIVE_CD))
	_buffs[sid] = float(sk.get("duration", Skills.ACTIVE_DURATION))
	log_line.emit("施放 %s LV%d" % [String(sk.get("name")), int(sk.get("lv", 3))])
	skill_cast.emit(String(sk.get("name")), false)
	_play_zoom(false)


func _cast_ultimate() -> void:
	var sk: Dictionary = Skills.ULTIMATE
	var sid := String(sk.get("id"))
	_cd[sid] = float(sk.get("cd", Skills.ULT_CD))
	_buffs[sid] = float(sk.get("duration", Skills.ULT_DURATION))
	log_line.emit("奧義 %s LV%d — 時停" % [String(sk.get("name")), int(sk.get("lv", 3))])
	skill_cast.emit(String(sk.get("name")), true)
	_play_zoom(true)
	_prompt.active = false


func _play_zoom(ult: bool) -> void:
	if camera == null:
		return
	var z := 1.55 if ult else 1.32
	var tw := create_tween()
	tw.tween_property(camera, "zoom", Vector2(z, z), 0.18)
	tw.tween_interval(0.22 if ult else 0.12)
	tw.tween_property(camera, "zoom", Vector2.ONE, 0.28)


func _reset_hold() -> void:
	if hold_progress > 0.0 or seq_index > 0:
		log_line.emit("放手 — 指令與 Circle 重置")
	hold_progress = 0.0
	blocked_mismatch = false
	seq_index = 0
	seq_done = false
	if _prompt and not ult_prep:
		_prompt.active = false
		_prompt.fail_at = -1
	if target != null and String(target.get("kind")) == "cashier":
		var cust = target.call("front_customer")
		if cust:
			cust.cancel_pay()


func _handle_hotkeys(key: int) -> void:
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
	if ult_prep:
		_body.color = Color("c0392b")
	elif skill_menu_open:
		_body.color = Color("7ec8e3")
	elif command_lock:
		_body.color = Color("e8c36a")
	elif _dashing:
		_body.color = Color("f4d35e")
	elif _running:
		_body.color = Color("2a9d8f")
	elif on_dirt():
		_body.color = Color("6b4f3a")
	else:
		_body.color = Color("2a6b4a")
