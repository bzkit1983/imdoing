extends CharacterBody2D

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const CircleScript = preload("res://scripts/loading_circle.gd")
const BoxStackScript = preload("res://scripts/box_stack.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const PromptScript = preload("res://scripts/command_prompt.gd")
const MenuScript = preload("res://scripts/skill_menu.gd")
const UiFont = preload("res://scripts/ui_font.gd")

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
var _dirt_areas: Array[Node] = []
var _slip_left: float = 0.0
var _stun_left: float = 0.0
var _sick_left: float = 0.0
var _last_wiggle: Vector2 = Vector2.ZERO
var _clean_hint: bool = false
var command_lock: bool = false
var seq_index: int = 0
var seq_done: bool = false
var skill_menu_open: bool = false
var ult_prep: bool = false
var stick_axis: Vector2 = Vector2.ZERO
var clock_scale: float = 1.0
var customer_move_mult: float = 1.0
var camera: Camera2D
var stats = null

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
var _body: CanvasItem
var _arrow: Polygon2D
var _no_queue_logged: bool = false
var _l_held: bool = false
var _l_time: float = 0.0
var _u_held: bool = false
var _ult_index: int = 0
var _cd: Dictionary = {}
var _buffs: Dictionary = {}
var _cust_speed_q: Array[String] = []
var _cardinal_armed: bool = true
var _passive_checkout_pct: float = 0.0
var _restock_picking: bool = false
var _restock_hold: float = 0.0
var _restock_aborted: bool = false
var _fighting: bool = false
var _fight_release: bool = false
var _stun_pending: float = Tuning.STUN_SEC
var _cancel_held: bool = false
var _cancel_time: float = 0.0
var _cancel_dropped: bool = false


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	stamina = stamina_max_now()
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
	_refresh_passive_checkout()


func _loadout() -> Array[Dictionary]:
	if stats != null and stats.has_method("loadout"):
		return stats.loadout()
	return Skills.EQUIPPED


func _skill_at(i: int) -> Dictionary:
	var slots := _loadout()
	if i < 0 or i >= slots.size():
		return {}
	return slots[i]


func _ult_sk() -> Dictionary:
	if stats != null and stats.has_method("ult_skill"):
		return stats.ult_skill()
	return Skills.ULTIMATE


func _stat_base(which: String) -> int:
	if stats == null:
		match which:
			"agi":
				return Tuning.AGI
			"int":
				return Tuning.INT
			_:
				return Tuning.STR
	match which:
		"agi":
			return int(stats.agi_stat)
		"int":
			return int(stats.int_stat)
		_:
			return int(stats.str_stat)


func _has_flag(flag: String) -> bool:
	return stats != null and stats.has_method("has_flag") and bool(stats.has_flag(flag))


func _refresh_passive_checkout() -> void:
	_passive_checkout_pct = 0.0
	for sk in _loadout():
		if String(sk.get("kind")) == "passive":
			_passive_checkout_pct += float(sk.get("checkout_pct", 0.0))


func bind_visuals(body: CanvasItem, arrow: Polygon2D) -> void:
	_body = body
	_arrow = arrow


func add_dirt(delta_count: int) -> void:
	dirt_contacts = maxi(0, dirt_contacts + delta_count)


func enter_dirt(area: Node) -> void:
	if area != null and not _dirt_areas.has(area):
		_dirt_areas.append(area)
	dirt_contacts = _dirt_areas.size()


func exit_dirt(area: Node) -> void:
	_dirt_areas.erase(area)
	dirt_contacts = _dirt_areas.size()


func on_dirt() -> bool:
	_prune_dirt()
	return not _dirt_areas.is_empty()


func _prune_dirt() -> void:
	var keep: Array[Node] = []
	for a in _dirt_areas:
		if is_instance_valid(a):
			keep.append(a)
	_dirt_areas = keep
	dirt_contacts = _dirt_areas.size()


func _has_dirt_type(dtype: String) -> bool:
	_prune_dirt()
	for a in _dirt_areas:
		if String(a.get("dirt_type")) == dtype:
			return true
	return false


func _ability_mult() -> float:
	return Tuning.SICK_ABILITY_MULT if _sick_left > 0.0 else 1.0


func _agi_now() -> int:
	return clampi(int(round(float(_stat_base("agi")) * _ability_mult())), 1, Tuning.AGI_EFFECT_CAP)


func _str_now() -> int:
	return clampi(int(round(float(_stat_base("str")) * _ability_mult())), 1, Tuning.STR_EFFECT_CAP)


func _int_now() -> int:
	return clampi(int(round(float(_stat_base("int")) * _ability_mult())), 1, Tuning.INT_EFFECT_CAP)


func stamina_max_now() -> float:
	return Tuning.stamina_max(_str_now())


func carry_boxes() -> int:
	var n := Tuning.carry_boxes_from_str(_str_now())
	for sk in _loadout():
		var add := int(sk.get("carry_add", 0))
		if add == 0:
			continue
		if String(sk.get("kind")) == "passive" or _buffs.has(String(sk.get("id"))):
			n += add
	return n


func carry_cap() -> int:
	return carry_boxes() * Tuning.BOX_SIZE


func move_speed_rate() -> float:
	var rate := 1.0
	for sk in _loadout():
		var pct := float(sk.get("move_pct", 0.0))
		if pct == 0.0:
			continue
		if String(sk.get("kind")) == "passive" or _buffs.has(String(sk.get("id"))):
			rate *= 1.0 + pct
	return rate


func restock_seconds_now() -> float:
	var base := Tuning.restock_seconds(_agi_now())
	var restock_pct := 0.0
	for sk in _loadout():
		var sid := String(sk.get("id"))
		if String(sk.get("kind")) == "passive":
			restock_pct += float(sk.get("restock_pct", 0.0))
			continue
		if not _buffs.has(sid):
			continue
		if bool(sk.get("restock_instant", false)):
			return 0.0
		base *= float(sk.get("restock_circle_mult", 1.0))
	if restock_pct > 0.0:
		base /= 1.0 + restock_pct
	return base


func checkout_seconds_now() -> float:
	_refresh_passive_checkout()
	var sec := Tuning.checkout_seconds(_int_now())
	var rate := 1.0
	if _passive_checkout_pct > 0.0:
		rate *= 1.0 + _passive_checkout_pct
	for sk in _loadout():
		var sid := String(sk.get("id"))
		if String(sk.get("kind")) != "active" or not _buffs.has(sid):
			continue
		if sk.has("checkout_pct"):
			rate *= 1.0 + float(sk.get("checkout_pct"))
	return sec / rate


func cd_left(skill_id: String) -> float:
	return float(_cd.get(skill_id, 0.0))


func buff_left(skill_id: String) -> float:
	return float(_buffs.get(skill_id, 0.0))


func store_status_text() -> String:
	var bits: PackedStringArray = []
	if _buffs.has("the_world"):
		bits.append("The World! 時停 %.0fs" % _buffs["the_world"])
	if _buffs.has("yes_my_lord"):
		bits.append("Yes! My Lord! %.0fs" % _buffs["yes_my_lord"])
	if _buffs.has("metal_rush"):
		bits.append("金屬狂潮 +150%% %.0fs" % _buffs["metal_rush"])
	if bits.is_empty():
		return "商店狀態  無技能效果"
	return "商店狀態  " + " · ".join(bits)


func role_status_text() -> String:
	var bits: PackedStringArray = []
	bits.append("STR%d AGI%d INT%d" % [_stat_base("str"), _stat_base("agi"), _stat_base("int")])
	if _buffs.has("carry_boost"):
		bits.append("負重+60箱 %.0fs" % _buffs["carry_boost"])
	if _buffs.has("move_boost"):
		bits.append("移速+60%% %.0fs" % _buffs["move_boost"])
	if _buffs.has("instant_restock"):
		bits.append("瞬間上架 %.0fs" % _buffs["instant_restock"])
	if _sick_left > 0.0:
		bits.append("嘔吐物 −30%% %.0fs" % _sick_left)
	if _fighting:
		bits.append("打擊中")
	if _stun_left > 0.0:
		bits.append("倒地 %.0fs" % _stun_left)
	if _passive_checkout_pct > 0.0:
		bits.append("收銀+%.0f%%" % (_passive_checkout_pct * 100.0))
	return "角色狀態  " + " ".join(bits)


func set_hold(action: String, pressed: bool) -> void:
	match action:
		"interact":
			if _fighting:
				if pressed:
					if not _fight_release:
						_fight_tap()
					_fight_release = true
				else:
					_fight_release = false
				return
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
			if command_lock or skill_menu_open or ult_prep or _fighting:
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
			_cancel_held = pressed
			if pressed:
				_cancel_time = 0.0
				_cancel_dropped = false
				_cancel_input()
			else:
				_cancel_time = 0.0


func move_state() -> String:
	if _stun_left > 0.0:
		return "暈眩"
	if _slip_left > 0.0:
		return "滑倒"
	if ult_prep:
		return "奧義指令"
	if skill_menu_open:
		return "技能選單"
	if _restock_picking:
		return "選貨"
	if _cleaning():
		return "清潔"
	if _fighting:
		return "打擊"
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
	var m := Tuning.agi_mult(_agi_now())
	m *= move_speed_rate()
	var n := inventory.count()
	var cap := carry_cap()
	if n > cap:
		m *= Tuning.OVERWEIGHT_OVER_CAP_MULT
	if on_dirt() and not _has_flag("ignore_dirt_slow"):
		m *= Tuning.DIRT_MULT
	return clampf(m, 0.0, Tuning.SPEED_MAX_MULT)


func _shelving() -> bool:
	return _j_held and is_instance_valid(target) and String(target.get("kind")) == "shelf"


func _cleaning() -> bool:
	return _j_held and is_instance_valid(target) and String(target.get("kind")) == "dirt"


func _in_dir_mode() -> bool:
	if ult_prep or skill_menu_open or _restock_picking or _l_held or _u_held:
		return true
	if _j_held and target != null:
		var kind := String(target.get("kind"))
		if kind == "cashier" or kind == "restock":
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
	# Early-close dialog and closeout own confirm and cancel.
	if _asking_early():
		return
	if not _round_active() and (key == KEY_J or key == KEY_ENTER or key == KEY_SEMICOLON or key == KEY_BACKSPACE):
		return
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
		set_hold("cancel", key_event.pressed)
		get_viewport().set_input_as_handled()
	elif key_event.pressed:
		_handle_hotkeys(key)


func _on_pad_button(pad: InputEventJoypadButton) -> void:
	# Early-close dialog and closeout own A and B.
	if _asking_early():
		return
	if not _round_active() and (pad.button_index == JOY_BUTTON_A or pad.button_index == JOY_BUTTON_B):
		return
	# Xbox layout: A/B/X/Y are actions. D-pad is directions.
	match pad.button_index:
		JOY_BUTTON_A:
			set_hold("interact", pad.pressed)
		JOY_BUTTON_B:
			set_hold("cancel", pad.pressed)
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


func _tick_cancel_hold(delta: float) -> void:
	if _cancel_dropped:
		return
	_cancel_time += delta
	if _cancel_time < Tuning.DROP_HOLD_SEC:
		return
	_cancel_dropped = true
	_discard_top_box()


func _round_active() -> bool:
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return true
	var phase := String(game.get("phase"))
	return phase == "restock" or phase == "open"


func _asking_early() -> bool:
	var game := get_tree().get_first_node_in_group("game")
	return game != null and game.has_method("asking_early_close") and bool(game.asking_early_close())


func _discard_top_box() -> void:
	if not _round_active():
		return
	if _stun_left > 0.0 or _slip_left > 0.0 or _fighting:
		return
	if inventory.is_empty():
		log_line.emit("手上沒有貨箱")
		return
	var run: Dictionary = inventory.trailing_run()
	var name := Tuning.sku_name(String(run["id"]))
	_drop_top_box()
	log_line.emit("丟掉 %s 1箱 — 掉在腳邊，可以再撿" % name)


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
	if _asking_early():
		velocity = Vector2.ZERO
		return
	_tick_buffs(delta)
	_tick_status(delta)
	command_lock = _j_held and is_instance_valid(target) and String(target.get("kind")) == "cashier" and not skill_menu_open and not ult_prep
	if not command_lock and not ult_prep:
		_prompt.active = false
	if _k_held and not command_lock and not skill_menu_open and not ult_prep and not _fighting and _stun_left <= 0.0 and _slip_left <= 0.0:
		_k_time += delta
		if _k_time >= Tuning.RUN_HOLD_THRESHOLD:
			_running = stamina > 1.0
	if _cancel_held:
		_tick_cancel_hold(delta)
	if _l_held and _sick_left <= 0.0 and _stun_left <= 0.0:
		_l_time += delta
		if not skill_menu_open and _l_time >= Skills.HOLD_MENU_SEC:
			skill_menu_open = true
			_menu.open = true
			_menu.set_slots(_loadout(), _cd)
			log_line.emit("技能選單 — WASD／搖桿選技能2–5，放手取消")
	if _fighting:
		velocity = Vector2.ZERO
	elif _slip_left > 0.0:
		_tick_slip(delta)
	elif _dashing:
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
			_menu.set_slots(_loadout(), _cd)
	_update_visuals()
	stats_changed.emit()


func _enqueue_cust_speed(skill_id: String) -> void:
	if not _cust_speed_q.has(skill_id):
		_cust_speed_q.append(skill_id)


func _customer_move_kind(skill_id: String) -> String:
	if skill_id == String(_ult_sk().get("id")):
		var scale := float(_ult_sk().get("clock_scale", 0.0))
		if scale <= 0.001:
			return "stop"
		if scale < 1.0:
			return "slow"
		return ""
	for sk in _loadout():
		if String(sk.get("id")) != skill_id:
			continue
		var pct := float(sk.get("customer_move_pct", 0.0))
		if pct > 0.0:
			return "fast"
		if pct < 0.0:
			return "slow"
	return ""


func _customer_move_mult_now() -> float:
	var kinds: PackedStringArray = []
	for id in _cust_speed_q:
		if not _buffs.has(id):
			continue
		var k := _customer_move_kind(id)
		if k != "" and not kinds.has(k):
			kinds.append(k)
	if kinds.has("stop"):
		return 1.0
	var mixed := kinds.has("fast") and kinds.has("slow")
	if mixed:
		for id in _cust_speed_q:
			if not _buffs.has(id):
				continue
			var k := _customer_move_kind(id)
			if k == "fast":
				return 1.0 + _cust_move_pct(id)
			if k == "slow":
				return 1.0
		return 1.0
	var m := 1.0
	for id in _cust_speed_q:
		if not _buffs.has(id):
			continue
		if _customer_move_kind(id) != "fast":
			continue
		m *= 1.0 + _cust_move_pct(id)
	return m


func _world_clock_now() -> float:
	if not _buffs.has("the_world"):
		return 1.0
	var scale := float(_ult_sk().get("clock_scale", 0.0))
	if scale <= 0.001:
		return 0.0
	var has_fast := false
	var has_slow := false
	for id in _cust_speed_q:
		if not _buffs.has(id):
			continue
		var k := _customer_move_kind(id)
		if k == "fast":
			has_fast = true
		elif k == "slow":
			has_slow = true
	if has_fast and has_slow:
		for id in _cust_speed_q:
			if not _buffs.has(id):
				continue
			var k := _customer_move_kind(id)
			if k == "fast":
				return 1.0
			if k == "slow":
				return scale
	return scale


func _cust_move_pct(skill_id: String) -> float:
	if skill_id == "the_world":
		return 0.0
	for sk in _loadout():
		if String(sk.get("id")) == skill_id:
			return float(sk.get("customer_move_pct", 0.0))
	return 0.0


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
	clock_scale = _world_clock_now()
	customer_move_mult = _customer_move_mult_now()
	var keep_q: Array[String] = []
	for id in _cust_speed_q:
		if _buffs.has(id):
			keep_q.append(id)
	_cust_speed_q = keep_q


func _wiggle_axis() -> Vector2:
	var v := _key_move_axis() + _pad_move_axis() + stick_axis
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _move_axis() -> Vector2:
	if _stun_left > 0.0 or _slip_left > 0.0 or _fighting or _in_dir_mode() or _shelving() or _cleaning():
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
	if v.length() < 0.42:
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
		if _j_held and not command_lock and not _shelving() and not _cleaning():
			_reset_hold()
	if _can_slip():
		_begin_slip()
		return
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
	if _dashing or _fighting or _stun_left > 0.0 or _slip_left > 0.0 or stamina < Tuning.DASH_STAMINA_COST:
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
	velocity = _dash_dir * speed
	move_and_slide()
	_try_dash_thief()
	if _can_slip():
		_dashing = false
		_begin_slip()
		return
	if _dash_left <= 0.0:
		_dashing = false
		velocity *= 0.35


func _can_slip() -> bool:
	if _slip_left > 0.0 or _stun_left > 0.0:
		return false
	if not _has_dirt_type(Tuning.DIRT_PUDDLE):
		return false
	return _dashing or _running


func _begin_slip() -> void:
	_dashing = false
	_running = false
	_slip_left = Tuning.SLIP_TIME
	_stun_pending = Tuning.STUN_SEC
	_reset_hold()
	_drop_top_box()
	log_line.emit("水漬滑倒 — 滑出 3 身位，暈眩 3 秒")


func _tick_slip(delta: float) -> void:
	_slip_left -= delta
	var dist := Tuning.SLIP_BODY_LENGTHS * Tuning.BODY_LENGTH
	var dir := facing
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	velocity = dir.normalized() * (dist / Tuning.SLIP_TIME)
	move_and_slide()
	if _slip_left <= 0.0:
		velocity = Vector2.ZERO
		_stun_left = _stun_pending


func _drop_top_box() -> void:
	if inventory.is_empty():
		return
	var run: Dictionary = inventory.trailing_run()
	var n := mini(Tuning.BOX_SIZE, int(run["count"]))
	inventory.remove_trailing(n)
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("spawn_dropped_box"):
		game.call("spawn_dropped_box", global_position, String(run["id"]), n)


func _tick_status(delta: float) -> void:
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		velocity = Vector2.ZERO
	if _sick_left > 0.0:
		_sick_left = maxf(0.0, _sick_left - delta)
	if _has_dirt_type(Tuning.DIRT_VOMIT):
		if _sick_left <= 0.0:
			log_line.emit("踩到嘔吐物 — 技能禁止、能力 −30% 10 秒")
		_sick_left = Tuning.SICK_SEC
	if _has_dirt_type(Tuning.DIRT_TRASH):
		stamina = maxf(0.0, stamina - Tuning.TRASH_STAMINA_PER_SEC * delta)
		_regen_delay = Tuning.STAMINA_REGEN_DELAY


func _regen(delta: float) -> void:
	if _dashing or _slip_left > 0.0 or (_running and _move_axis() != Vector2.ZERO) or _has_dirt_type(Tuning.DIRT_TRASH):
		return
	if _regen_delay > 0.0:
		_regen_delay -= delta
		return
	stamina = minf(stamina_max_now(), stamina + Tuning.STAMINA_REGEN_PER_SEC * delta)


func _update_target() -> void:
	if _fighting:
		return
	var best: Node2D = null
	var best_score := -1.0
	for node in interactables:
		if node == null or not is_instance_valid(node):
			continue
		var to_obj: Vector2 = node.global_position - global_position
		var dist := to_obj.length()
		if dist > Tuning.INTERACT_RANGE or dist < 0.001:
			continue
		var dot := facing.dot(to_obj.normalized())
		if String(node.get("kind")) == "dirt" and _dirt_areas.has(node):
			dot = 1.0
		if String(node.get("kind")) == "thief":
			dot = maxf(dot, 0.85)
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
	if _fighting:
		_tick_fight(delta)
		return
	if _stun_left > 0.0 or _slip_left > 0.0:
		if is_instance_valid(target) and String(target.get("kind")) == "dirt":
			target.call("set_cleaning", false, Vector2.ZERO, 0.0)
		return
	if not is_instance_valid(target) or not _j_held:
		if not _j_held:
			hold_progress = 0.0
			_clear_clean_hint()
		return
	var kind := String(target.get("kind"))
	if kind == "restock":
		_tick_sku_pick(delta)
	elif kind == "shelf":
		_tick_restock(delta)
	elif kind == "cashier":
		_tick_cashier(delta)
	elif kind == "dirt":
		_tick_clean(delta)
	elif kind == "drop":
		_tick_drop()
	elif kind == "thief":
		_begin_fight()


func _begin_fight() -> void:
	if not inventory.is_empty():
		if not _pickup_used:
			log_line.emit("打擊要空手 — 先把貨上架")
			_pickup_used = true
		return
	if not is_instance_valid(target) or not bool(target.get("is_thief")):
		return
	if not bool(target.call("is_active_thief")):
		return
	_fighting = true
	_fight_release = true
	target.call("begin_fight")
	log_line.emit("抓住小偷 — 連按行動鍵扣血，剩 5 秒")
	if camera:
		camera.zoom = Vector2(Tuning.FIGHT_ZOOM, Tuning.FIGHT_ZOOM)
		camera.position = (target.global_position - global_position) * 0.4


func _tick_fight(delta: float) -> void:
	if not is_instance_valid(target) or not bool(target.call("in_fight")):
		_end_fight(false)
		return
	target.fight_left = maxf(0.0, float(target.fight_left) - delta)
	hold_progress = clampf(float(target.fight_hp) / 100.0, 0.0, 1.0)
	target.call("_refresh_labels")
	if float(target.fight_left) <= 0.0:
		_fight_fail()


func _fight_tap() -> void:
	if not is_instance_valid(target):
		return
	var dmg := Tuning.hit_damage(_str_now())
	if bool(target.call("take_hit", dmg)):
		_fight_win()


func _fight_win() -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("record_caught"):
		game.call("record_caught")
	if is_instance_valid(target):
		target.call("drop_loot_and_leave")
	log_line.emit("打倒小偷 — 贓物掉在地上")
	_end_fight(true)


func _fight_fail() -> void:
	if is_instance_valid(target):
		var away := global_position - target.global_position
		if away.length_squared() < 0.01:
			away = -facing
		facing = away.normalized()
		target.call("escape_with_loot")
	log_line.emit("打擊失敗 — 被撞開，倒地 5 秒")
	_end_fight(false)
	_dashing = false
	_running = false
	_slip_left = Tuning.SLIP_TIME
	_stun_pending = Tuning.FIGHT_DOWN_SEC


func _end_fight(_won: bool) -> void:
	_fighting = false
	_fight_release = false
	hold_progress = 0.0
	if camera:
		camera.zoom = Vector2(Tuning.CAMERA_ZOOM, Tuning.CAMERA_ZOOM)
		camera.position = Vector2.ZERO


func _try_dash_thief() -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null or not game.has_method("thieves"):
		return
	for t in game.call("thieves"):
		if t == null or not is_instance_valid(t):
			continue
		if not bool(t.call("is_active_thief")):
			continue
		if global_position.distance_to(t.global_position) > Tuning.DASH_HIT_RANGE:
			continue
		t.call("dash_knock_away", _dash_dir)
		log_line.emit("衝刺撞飛小偷")
		if _fighting:
			_end_fight(false)
		return


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
		log_line.emit("負重不足：%d/%d 箱" % [inventory.count() / Tuning.BOX_SIZE, carry_boxes()])
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
		if int(target.get("count")) >= int(target.get("capacity")):
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


func _tick_clean(_delta: float) -> void:
	if not inventory.is_empty():
		log_line.emit("清潔要空手 — 先把貨上架")
		_j_held = false
		_clear_clean_hint()
		return
	var axis := _wiggle_axis()
	if not _clean_hint:
		_last_wiggle = axis
	var travel := (axis - _last_wiggle).length()
	_last_wiggle = axis
	var needed := Tuning.CLEAN_WIGGLE_PER_SEC * Tuning.clean_seconds(_agi_now())
	if needed <= 0.001:
		hold_progress = 1.0
	else:
		hold_progress = minf(1.0, hold_progress + travel / needed)
	if not _clean_hint:
		_clean_hint = true
		log_line.emit("清潔 %s — 按住行動並持續轉搖桿／WASD" % String(target.call("type_name")))
	target.call("set_cleaning", true, axis, hold_progress * 100.0)
	if hold_progress >= 1.0:
		var name := String(target.call("type_name"))
		target.queue_free()
		target = null
		hold_progress = 0.0
		_clean_hint = false
		_last_wiggle = Vector2.ZERO
		var game := get_tree().get_first_node_in_group("game")
		if game and game.has_method("note_clean"):
			game.note_clean()
		log_line.emit("清潔完成 — %s 已清除" % name)


func _tick_drop() -> void:
	if _pickup_used:
		return
	_pickup_used = true
	var n := int(target.get("count"))
	var sku := String(target.get("sku"))
	if n <= 0:
		return
	if inventory.count() + n > carry_cap():
		log_line.emit("負重不足，撿不回掉落箱")
		return
	var taken := int(target.call("take_all"))
	for i in taken:
		inventory.items.append(sku)
	log_line.emit("撿起 %s ×%d" % [Tuning.sku_name(sku), taken])


func _clear_clean_hint() -> void:
	_clean_hint = false
	_last_wiggle = Vector2.ZERO
	if is_instance_valid(target) and String(target.get("kind")) == "dirt":
		target.call("set_cleaning", false, Vector2.ZERO, hold_progress * 100.0)
	for a in _dirt_areas:
		if is_instance_valid(a) and a.has_method("set_cleaning"):
			a.call("set_cleaning", false, Vector2.ZERO, 0.0)


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
	UiFont.apply_label(lab, UiFont.TITLE)
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
		if _sick_left > 0.0 or _stun_left > 0.0 or _fighting:
			log_line.emit("現在不能發動技能")
			return
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
		if _sick_left > 0.0 or _stun_left > 0.0 or _fighting:
			log_line.emit("現在不能發動奧義")
			return
		var ult := _ult_sk()
		if bool(ult.get("unimplemented", false)):
			log_line.emit("%s 本 Demo 未實作，不會進入冷卻" % String(ult.get("name")))
			return
		var ult_id := String(ult.get("id"))
		if cd_left(ult_id) > 0.05:
			log_line.emit("奧義冷卻中 %.0fs" % cd_left(ult_id))
			return
		_u_held = true
		ult_prep = true
		_ult_index = 0
		_prompt.active = true
		var seq: Array[int] = []
		for d in ult.get("seq", []):
			seq.append(int(d))
		_prompt.sequence = seq
		_prompt.index = 0
		_prompt.fail_at = -1
		log_line.emit("奧義準備 — %s" % String(_ult_sk().get("name")))
		return
	if ult_prep:
		log_line.emit("放手 — 奧義取消")
	_u_held = false
	ult_prep = false
	if not command_lock:
		_prompt.active = false
		_prompt.fail_at = -1


func _try_ult_dir(dir: int) -> void:
	var seq: Array = _ult_sk().get("seq", [])
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
	if _sick_left > 0.0 or _stun_left > 0.0 or _fighting:
		log_line.emit("現在不能發動技能")
		return
	var sk: Dictionary = _skill_at(i)
	if sk.is_empty():
		return
	if bool(sk.get("unimplemented", false)):
		log_line.emit("%s 本 Demo 未實作，不會進入冷卻" % String(sk.get("name")))
		return
	if String(sk.get("kind")) != "active":
		log_line.emit("%s 是被動技能，無法主動施放" % String(sk.get("name")))
		return
	var sid := String(sk.get("id"))
	if cd_left(sid) > 0.05:
		log_line.emit("%s 冷卻中 %.0fs" % [String(sk.get("name")), cd_left(sid)])
		return
	_cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), _int_now())
	_buffs[sid] = float(sk.get("duration", Skills.ACTIVE_DURATION))
	if sk.has("customer_move_pct"):
		_enqueue_cust_speed(sid)
	if sk.has("soothe_keep"):
		var game := get_tree().get_first_node_in_group("game")
		if game and game.has_method("soothe_all"):
			game.soothe_all(float(sk.get("soothe_keep")))
	log_line.emit("施放 %s LV%d" % [String(sk.get("name")), int(sk.get("lv", 3))])
	skill_cast.emit(String(sk.get("name")), false)
	_play_zoom(false)


func release_checkout() -> void:
	seq_index = 0
	seq_done = false
	hold_progress = 0.0
	_j_held = false
	if _prompt and not ult_prep:
		_prompt.active = false
		_prompt.fail_at = -1


func _lord_seconds(lv: int) -> float:
	match lv:
		1:
			return 3.0
		2:
			return 5.0
		_:
			return 10.0


func _cast_ultimate() -> void:
	var sk: Dictionary = _ult_sk()
	if bool(sk.get("unimplemented", false)):
		log_line.emit("%s 本 Demo 未實作" % String(sk.get("name")))
		_prompt.active = false
		return
	var sid := String(sk.get("id"))
	var lv := int(sk.get("lv", 3))
	_cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ULT_CD)), _int_now())
	var game := get_tree().get_first_node_in_group("game")
	if sid == "fundraise":
		if game and game.has_method("cast_fundraise"):
			game.call("cast_fundraise", lv)
		log_line.emit("奧義 全體集資 LV%d" % lv)
		skill_cast.emit(String(sk.get("name")), true)
		_play_zoom(true)
		_prompt.active = false
		return
	if sid == "yes_my_lord":
		_buffs[sid] = _lord_seconds(lv)
		log_line.emit("奧義 Yes! My Lord! LV%d — 客人搶購 %.0f 秒" % [lv, _lord_seconds(lv)])
		skill_cast.emit(String(sk.get("name")), true)
		_play_zoom(true)
		_prompt.active = false
		return
	_buffs[sid] = float(sk.get("duration", Skills.ULT_DURATION))
	_enqueue_cust_speed(sid)
	log_line.emit("奧義 %s LV%d — 時停" % [String(sk.get("name")), lv])
	skill_cast.emit(String(sk.get("name")), true)
	_play_zoom(true)
	_prompt.active = false


func _play_zoom(ult: bool) -> void:
	if camera == null:
		return
	var base := Tuning.CAMERA_ZOOM
	var z := base * (1.28 if ult else 1.12)
	var tw := create_tween()
	tw.tween_property(camera, "zoom", Vector2(z, z), 0.18)
	tw.tween_interval(0.22 if ult else 0.12)
	tw.tween_property(camera, "zoom", Vector2(base, base), 0.28)


func _reset_hold() -> void:
	if hold_progress > 0.0 or seq_index > 0:
		log_line.emit("放手 — 指令與 Circle 重置")
	_clear_clean_hint()
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
	if _body is Sprite2D:
		Vox.apply(_body as Sprite2D, "player", Vox.k_from_facing(facing))
	var tint := Color.WHITE
	if ult_prep:
		tint = Color(1.0, 0.45, 0.4)
	elif skill_menu_open:
		tint = Color(0.65, 0.9, 1.0)
	elif command_lock:
		tint = Color(1.0, 0.9, 0.55)
	elif _dashing:
		tint = Color(1.0, 0.92, 0.45)
	elif _running:
		tint = Color(0.7, 1.0, 0.85)
	elif _fighting:
		tint = Color(1.0, 0.45, 0.4)
	elif _stun_left > 0.0:
		tint = Color(0.85, 0.7, 1.0)
	elif on_dirt():
		tint = Color(0.75, 0.62, 0.45)
	_body.modulate = tint
