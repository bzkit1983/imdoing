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
const FxBurst = preload("res://scripts/fx_burst.gd")
const GlowScript = preload("res://scripts/interact_glow.gd")

signal stats_changed

## Last HUD right-panel fingerprint; emit stats_changed only when it changes.
var _hud_fp: String = ""
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
## Seconds the interact button has been held this press. Short vs long splits at SKU_PICK_HOLD.
var _j_time: float = 0.0
## Long action already started (clean / stock / cashier / hand delivery) — release must not also take.
var _long_committed: bool = false
var _deliver_done: bool = false
## This dash already resolved a guest (deliver or KO).
var _dash_guest_done: bool = false
## Short cancel closed a menu or an in-progress action, so it must not toss a piece.
var _cancel_swallowed: bool = false
var _pickup_used: bool = false
var _circle: Node2D
var _prompt: Node2D
var _menu: Node2D
var _body: CanvasItem
var _arrow: Polygon2D
var _no_queue_logged: bool = false
var _l_held: bool = false
var _l_time: float = 0.0
## Short tap left the menu up. Direction fires now; skill key again fires the center.
var _skill_latch: bool = false
## Slot that a held menu will cast on release. 0 is the center skill.
var _skill_aim: int = 0
## Second skill press already confirmed the center; ignore that press's release.
var _skill_release_ignore: bool = false
var _u_held: bool = false
var _ult_index: int = 0
var _cd: Dictionary = {}
var _buffs: Dictionary = {}
var _cust_speed_q: Array[String] = []
var _cardinal_armed: bool = true
## After skill/ult/restock/checkout dir mode, ignore move until stick/keys go neutral
## so releasing the menu on a held WASD key does not start walking.
var _move_locked_until_neutral: bool = false
var _passive_checkout_pct: float = 0.0
var _restock_picking: bool = false
var _restock_hold: float = 0.0
var _restock_aborted: bool = false
var _fighting: bool = false
var _fight_release: bool = false
## True while KO banner / knockaway plays after a fight mash win.
var _fight_ko: bool = false
## EliteCustomer intro ZOOM — locks player actions (~1s).
var _elite_focus_left: float = 0.0
var _shake_left: float = 0.0
var _shake_mag: float = 0.0
var _stun_pending: float = Tuning.STUN_SEC
var _cancel_held: bool = false
var _cancel_time: float = 0.0
## True once hold exceeds DROP_HOLD_SEC — release then drops (not auto).
var _cancel_drop_ready: bool = false
## True after this press has already tossed (prevents double drop).
var _cancel_dropped: bool = false
## Aim direction while holding cancel. Zero = drop at feet.
var _cancel_drop_dir: Vector2 = Vector2.ZERO
## True from toss start until the flying box lands — movement stays locked.
var _drop_flight_lock: bool = false
## Piece tosses in the air. Movement stays stopped until the latest one lands
## and the player is not already holding another short drop.
var _piece_flights: int = 0
var _piece_drop_lock: bool = false
var _drop_aim_line: Line2D
var _drop_aim_mark: Polygon2D
## Reused halo. Parented onto the current interact target, or parked off-tree.
var _interact_glow: Node2D
var _glow_host: Node2D
## Cached game host (avoids get_first_node_in_group every physics frame).
var game: Node = null
## Dirty HUD: skip inventory.grouped() fingerprint until something relevant changes.
var _hud_dirty: bool = true
var _hud_inv_rev: int = -1
var _hud_move: String = ""
var _hud_stam: float = -999.0
var _hud_stam_max: float = -999.0
var _hud_carry: int = -1
var _hud_hold: float = -999.0
var _hud_blocked: bool = false
var _hud_target_id: int = 0
var _hud_target_detail: String = ""
var _shown_anim: String = ""
var _cast_pose_left: float = 0.0
var _deliver_pose_left: float = 0.0
var _shown_tint: Color = Color(0, 0, 0, 0)
var _menu_fp: String = ""
var _cached_clock: float = 1.0
var _cached_cust_mult: float = 1.0
var _buff_cache_valid: bool = false
var _crowd_active: bool = false
var _crowd_say: Label
var _wave_vfx_cd: float = 0.0


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
	if inventory.has_signal("changed"):
		inventory.changed.connect(_mark_hud_dirty)
	_setup_drop_aim()
	_setup_crowd_say()
	_refresh_passive_checkout()


func _setup_crowd_say() -> void:
	_crowd_say = Label.new()
	_crowd_say.name = "CrowdSay"
	_crowd_say.visible = false
	_crowd_say.text = "唔該借借⋯"
	_crowd_say.position = Vector2(-70, -92)
	_crowd_say.z_index = 10
	UiFont.apply_label(_crowd_say, UiFont.WORLD)
	_crowd_say.add_theme_color_override("font_color", Color("fff4c2"))
	_crowd_say.add_theme_color_override("font_outline_color", Color("121212"))
	_crowd_say.add_theme_constant_override("outline_size", 6)
	add_child(_crowd_say)


func _setup_drop_aim() -> void:
	_drop_aim_line = Line2D.new()
	_drop_aim_line.name = "DropAimLine"
	_drop_aim_line.width = 3.0
	_drop_aim_line.default_color = Tuning.DROP_AIM_LINE_COLOR
	_drop_aim_line.visible = false
	_drop_aim_line.z_index = 6
	add_child(_drop_aim_line)
	_drop_aim_mark = Polygon2D.new()
	_drop_aim_mark.name = "DropAimMark"
	_drop_aim_mark.color = Tuning.DROP_AIM_MARK_COLOR
	_drop_aim_mark.polygon = PackedVector2Array([
		Vector2(-10, 0), Vector2(0, -10), Vector2(10, 0), Vector2(0, 10),
	])
	_drop_aim_mark.visible = false
	_drop_aim_mark.z_index = 6
	add_child(_drop_aim_mark)


## Base 5 身位; later drop-range skills can multiply this.
func drop_toss_dist() -> float:
	return Tuning.DROP_TOSS_DIST


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
	var was := dirt_contacts
	if area != null and not _dirt_areas.has(area):
		_dirt_areas.append(area)
	dirt_contacts = _dirt_areas.size()
	if was <= 0 and dirt_contacts > 0:
		SfxBus.play("sfx_move_dirt_step")


func exit_dirt(area: Node) -> void:
	_dirt_areas.erase(area)
	_prune_dirt_inplace()


func on_dirt() -> bool:
	## Trust enter/exit; prune only when an area exits the tree.
	return dirt_contacts > 0


func _prune_dirt_inplace() -> void:
	var i := 0
	while i < _dirt_areas.size():
		if _dirt_areas[i] == null or not is_instance_valid(_dirt_areas[i]):
			_dirt_areas.remove_at(i)
			continue
		i += 1
	dirt_contacts = _dirt_areas.size()


func _has_dirt_type(dtype: String) -> bool:
	if dirt_contacts <= 0:
		return false
	for a in _dirt_areas:
		if a != null and is_instance_valid(a) and String(a.get("dirt_type")) == dtype:
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


## Thrown boxes / pieces home to the nearest same-SKU shelf.
func sniper_shelf_active() -> bool:
	return buff_left("shelf_sniper") > 0.0


## Thrown boxes / pieces home to the nearest guest who still wants that SKU.
func sniper_guest_active() -> bool:
	return buff_left("guest_sniper") > 0.0


## Thrown boxes / pieces home to the nearest active thief and KO them.
func sniper_thief_active() -> bool:
	return buff_left("thief_sniper") > 0.0


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
	if _buffs.has("shelf_sniper"):
		bits.append("狙擊手（貨架） %.0fs" % _buffs["shelf_sniper"])
	if _buffs.has("guest_sniper"):
		bits.append("狙擊手（客人） %.0fs" % _buffs["guest_sniper"])
	if _buffs.has("thief_sniper"):
		bits.append("狙擊手（小偷） %.0fs" % _buffs["thief_sniper"])
	if _buffs.has("dash_deliver"):
		bits.append("衝刺交付 %.0fs" % _buffs["dash_deliver"])
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
				_j_time = 0.0
				_long_committed = false
				_deliver_done = false
				_restock_hold = 0.0
				_restock_aborted = false
				_pickup_used = false
				_no_queue_logged = false
			else:
				_release_interact()
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
				_cancel_drop_ready = false
				_cancel_dropped = false
				_cancel_drop_dir = Vector2.ZERO
				_cancel_swallowed = false
				_sample_cancel_drop_dir()
				_cancel_input()
			else:
				_on_cancel_release()


func move_state() -> String:
	if _stun_left > 0.0:
		return "暈眩"
	if _slip_left > 0.0:
		return "滑倒"
	if _drop_flight_lock or _piece_drop_lock:
		return "丟貨"
	if _cancel_held and not _cancel_dropped:
		return "掉貨瞄準"
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
	if _crowd_near():
		m *= Tuning.CROWD_SPEED_MULT
	return clampf(m, 0.0, Tuning.SPEED_MAX_MULT)


func _crowd_near() -> bool:
	var g := _game()
	if g == null or not g.has_method("customers_near"):
		## Fallback: scan game customers group / thieves list.
		return _crowd_near_fallback()
	return bool(g.call("customers_near", global_position, Tuning.CROWD_RADIUS_SQ))


func _crowd_near_fallback() -> bool:
	var g := _game()
	if g == null:
		return false
	var rsq := Tuning.CROWD_RADIUS_SQ
	if g.get("_customers") != null:
		for c in g._customers.get_children():
			if c == null or not is_instance_valid(c):
				continue
			if global_position.distance_squared_to(c.global_position) <= rsq:
				return true
	return false


func _sync_crowd_say() -> void:
	var on := _crowd_near()
	if on and not _crowd_active:
		SfxBus.play("sfx_move_crowd")
	_crowd_active = on
	if _crowd_say:
		_crowd_say.visible = on


func _shelving() -> bool:
	return _long_committed and _j_held and is_instance_valid(target) and String(target.get("kind")) == "shelf"


func _cleaning() -> bool:
	return _long_committed and _j_held and is_instance_valid(target) and String(target.get("kind")) == "dirt"


func _in_dir_mode() -> bool:
	if ult_prep or skill_menu_open or _restock_picking or _l_held or _u_held:
		return true
	if _j_held and target != null:
		var kind := String(target.get("kind"))
		if kind == "cashier" or kind == "restock":
			return true
	return command_lock


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	# Early-close dialog and closeout own confirm / cancel.
	if _asking_early():
		return
	if not _round_active() and (event.is_action(Controls.INTERACT) or event.is_action(Controls.CANCEL)):
		return
	# Discrete directions only here; analog stick uses _poll_stick_cardinal.
	if _in_dir_mode() and event.is_pressed() and (
		event is InputEventKey or event is InputEventJoypadButton
	):
		var dir := Controls.dir_from_event(event)
		if dir >= 0:
			_try_dir(dir)
			get_viewport().set_input_as_handled()
			return
	for action in Controls.HOLD_ACTIONS:
		if event.is_action(action) and (event is InputEventKey or event is InputEventJoypadButton):
			set_hold(action, event.is_pressed())
			get_viewport().set_input_as_handled()
			return
	if event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton):
		_handle_hotkey_actions(event)


func _begin_drop_aim() -> void:
	## Entering drop prep pauses walk/run/dash until the box lands.
	_running = false
	_dashing = false
	velocity = Vector2.ZERO


func _tick_cancel_hold(delta: float) -> void:
	if _cancel_dropped:
		return
	## Direction is sampled the whole time. Aim circle and move-lock start only after the long press.
	_sample_cancel_drop_dir()
	_cancel_time += delta
	if _cancel_time >= Tuning.DROP_HOLD_SEC:
		if not _cancel_drop_ready:
			_cancel_drop_ready = true
			_begin_drop_aim()
			SfxBus.play("sfx_box_drop_aim")
		_update_drop_aim()


func _on_cancel_release() -> void:
	## Armed by long-press → toss the top segment on release.
	## Short press with a direction tosses one piece, unless this press cancelled a menu or action.
	if _cancel_drop_ready and not _cancel_dropped and not _drop_flight_lock:
		_cancel_dropped = true
		_hide_drop_aim()
		_discard_top_box()
	elif not _drop_flight_lock:
		if not _cancel_swallowed:
			_toss_top_piece()
		_cancel_drop_dir = Vector2.ZERO
		_hide_drop_aim()
	## Previous piece already landed and this press did not throw another: walk again.
	## A whole-box flight keeps its own lock, so clear the piece lock here too.
	if _piece_flights <= 0:
		_piece_drop_lock = false
	_cancel_time = 0.0
	_cancel_drop_ready = false


func _sample_cancel_drop_dir() -> void:
	## Direction keys retarget aim; no input keeps last aim or feet (zero).
	var v := Controls.move_vector() + stick_axis
	if v.length() >= Tuning.DROP_DIR_DEADZONE:
		_cancel_drop_dir = v.normalized()
		facing = _cancel_drop_dir


func _drop_aim_dest() -> Vector2:
	return global_position + Tuning.drop_offset(_cancel_drop_dir, drop_toss_dist())


func _update_drop_aim() -> void:
	if _drop_aim_line == null or inventory.is_empty():
		_hide_drop_aim()
		return
	var dest := _drop_aim_dest()
	_drop_aim_line.visible = true
	_drop_aim_mark.visible = true
	_drop_aim_line.points = PackedVector2Array([Vector2.ZERO, dest - global_position])
	_drop_aim_mark.position = dest - global_position


func _hide_drop_aim() -> void:
	if _drop_aim_line:
		_drop_aim_line.visible = false
	if _drop_aim_mark:
		_drop_aim_mark.visible = false


func _game() -> Node:
	if game != null and is_instance_valid(game):
		return game
	game = get_tree().get_first_node_in_group("game")
	return game


func _round_active() -> bool:
	var g := _game()
	if g == null:
		return true
	var phase := String(g.get("phase"))
	return phase == "restock" or phase == "open"


func _asking_early() -> bool:
	var g := _game()
	return g != null and g.has_method("asking_early_close") and bool(g.asking_early_close())


func _mark_hud_dirty() -> void:
	_hud_dirty = true


func _discard_top_box() -> void:
	if not _round_active():
		return
	if _stun_left > 0.0 or _slip_left > 0.0 or _fighting:
		return
	if inventory.is_empty():
		log_line.emit("手上沒有貨箱")
		_hide_drop_aim()
		return
	var run: Dictionary = inventory.trailing_run()
	var name := Tuning.sku_name(String(run["id"]))
	var toss := _cancel_drop_dir
	_drop_top_box(toss)
	if toss.length_squared() > 0.01:
		SfxBus.play("sfx_box_toss")
		var hint := _sniper_toss_log(name, true)
		if hint != "":
			log_line.emit(hint)
		else:
			log_line.emit(
				"丟掉 %s 1箱 — 往%s飛出（可砸小偷／同款貨架上架）" % [name, _drop_dir_label(toss)]
			)
	else:
		SfxBus.play("sfx_box_drop_feet")
		log_line.emit("丟掉 %s 1箱 — 掉在腳邊，可以再撿" % name)


## Direction + short cancel: throw the top piece. No aim circle.
## Stop while it flies. Another toss before it lands keeps the stop.
## When the last piece lands and cancel is up, a held direction walks again.
func _toss_top_piece() -> bool:
	if not _round_active():
		return false
	if _stun_left > 0.0 or _slip_left > 0.0 or _fighting or _drop_flight_lock:
		return false
	if _cancel_drop_dir.length_squared() < 0.01:
		return false
	if inventory.is_empty():
		log_line.emit("手上沒有貨箱")
		return false
	var run: Dictionary = inventory.trailing_run()
	var sku := String(run["id"])
	inventory.remove_trailing(1)
	var host := _game()
	if host and host.has_method("spawn_dropped_box"):
		_piece_flights += 1
		_piece_drop_lock = true
		_running = false
		_dashing = false
		velocity = Vector2.ZERO
		host.call(
			"spawn_dropped_box",
			global_position,
			sku,
			1,
			_cancel_drop_dir,
			drop_toss_dist(),
			Callable(self, "_on_piece_drop_landed"),
		)
	SfxBus.play("sfx_box_toss")
	var hint := _sniper_toss_log(Tuning.sku_name(sku), false)
	if hint != "":
		log_line.emit(hint)
	else:
		log_line.emit("丟掉 %s 1件 — 往%s飛出" % [Tuning.sku_name(sku), _drop_dir_label(_cancel_drop_dir)])
	return true


func _sniper_toss_log(sku_name: String, whole_box: bool) -> String:
	var unit := "1箱" if whole_box else "1件"
	if sniper_thief_active():
		return "丟掉 %s %s — 狙擊手飛向小偷" % [sku_name, unit]
	if sniper_guest_active():
		return "丟掉 %s %s — 狙擊手飛向清單客人" % [sku_name, unit]
	if sniper_shelf_active():
		return "丟掉 %s %s — 狙擊手飛向同款貨架" % [sku_name, unit]
	return ""


func _on_piece_drop_landed() -> void:
	_piece_flights = maxi(0, _piece_flights - 1)
	if _piece_flights > 0:
		return
	## Still holding cancel for another short drop: stay stopped until that press ends.
	if _cancel_held and not _cancel_swallowed and not _cancel_drop_ready:
		return
	_piece_drop_lock = false


func _drop_dir_label(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "右" if dir.x > 0.0 else "左"
	return "下" if dir.y > 0.0 else "上"


func _cancel_input() -> void:
	var used := _fighting or _stun_left > 0.0 or _slip_left > 0.0 or _long_committed or command_lock
	if _restock_picking:
		_abort_restock_pick()
		_restock_aborted = true
		_j_held = false
		log_line.emit("取消選貨")
		used = true
	if skill_menu_open or _l_held or _skill_latch:
		_close_skill_menu()
		SfxBus.play("sfx_skill_menu_cancel")
		log_line.emit("取消技能選單")
		used = true
	if ult_prep:
		_on_ult_hold(false)
		used = true
	if _j_held:
		set_hold("interact", false)
		used = true
	if used:
		_cancel_swallowed = true


func _physics_process(delta: float) -> void:
	if _asking_early():
		velocity = Vector2.ZERO
		_sync_interact_glow()
		return
	if _elite_focus_left > 0.0:
		_elite_focus_left = maxf(0.0, _elite_focus_left - delta)
		velocity = Vector2.ZERO
		_tick_buffs(delta)
		_tick_status(delta)
		_tick_camera_shake(delta)
		_sync_interact_glow()
		return
	_tick_buffs(delta)
	_tick_status(delta)
	if _cast_pose_left > 0.0:
		_cast_pose_left = maxf(0.0, _cast_pose_left - delta)
	if _deliver_pose_left > 0.0:
		_deliver_pose_left = maxf(0.0, _deliver_pose_left - delta)
	command_lock = _long_committed and _j_held and is_instance_valid(target) and String(target.get("kind")) == "cashier" and not skill_menu_open and not ult_prep
	if not command_lock and not ult_prep:
		_prompt.active = false
	if _k_held and not _cancel_held and not _drop_flight_lock and not _piece_drop_lock and not command_lock and not skill_menu_open and not ult_prep and not _fighting and _stun_left <= 0.0 and _slip_left <= 0.0:
		_k_time += delta
		if _k_time >= Tuning.RUN_HOLD_THRESHOLD:
			_running = stamina > 1.0
	if _cancel_held:
		_tick_cancel_hold(delta)
	## Long-press aim, a flying box, or a piece still in the air: freeze locomotion.
	if (_cancel_drop_ready or _drop_flight_lock or _piece_drop_lock) and _slip_left <= 0.0:
		_running = false
		_dashing = false
		velocity = Vector2.ZERO
	if _l_held and _sick_left <= 0.0 and _stun_left <= 0.0:
		_l_time += delta
		if not skill_menu_open and _l_time >= Skills.HOLD_MENU_SEC:
			_open_skill_menu(false)
		if skill_menu_open and not _skill_latch:
			_sync_hold_aim()
	## Skill / ult / checkout dir modes: hard-stop so held WASD cannot coast.
	if _in_dir_mode() or _move_locked_until_neutral:
		_running = false
		if not _dashing and _slip_left <= 0.0:
			velocity = Vector2.ZERO
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
	_sync_interact_glow()
	if _circle:
		## Clean uses dirt StickHint (blue meter + stick), not the yellow hold Circle.
		if _cleaning():
			_circle.progress = 0.0
			_circle.blocked = false
		else:
			_circle.progress = hold_progress
			_circle.blocked = blocked_mismatch
	if _menu:
		_menu.open = skill_menu_open
		if skill_menu_open:
			var mfp := "%s|%s" % [str(_cd), str(_loadout())]
			if mfp != _menu_fp:
				_menu_fp = mfp
				_menu.set_slots(_loadout(), _cd)
	_sync_crowd_say()
	_update_visuals()
	_emit_stats_if_changed()


func _target_detail_fp(node: Node2D) -> String:
	if node == null or not is_instance_valid(node):
		return "-"
	var k := String(node.get("kind"))
	var tinfo := "%s:%d" % [k, node.get_instance_id()]
	match k:
		"restock":
			tinfo += ":%s" % String(node.call("selected_sku"))
		"dirt":
			tinfo += ":%s" % String(node.call("type_name"))
		"drop":
			tinfo += ":%s:%d" % [String(node.get("sku")), int(node.get("count"))]
		"shelf":
			var cap := int(node.get("capacity"))
			if cap <= 0:
				cap = Tuning.SHELF_CAP
			tinfo += ":%s:%d:%d" % [String(node.get("sku")), int(node.get("count")), cap]
		"thief":
			tinfo += ":%.0f:%.1f" % [float(node.get("fight_hp")), float(node.get("fight_left"))]
	return tinfo


func _hud_fingerprint() -> String:
	## Assumes cheap HUD caches were refreshed by _emit_stats_if_changed.
	var inv_bits: PackedStringArray = []
	for g in inventory.grouped():
		inv_bits.append("%s:%d" % [String(g["id"]), int(g["count"])])
	return "%s|%.2f|%.2f|%d|%s|%.2f|%s|%s" % [
		_hud_move,
		_hud_stam,
		_hud_stam_max,
		_hud_carry,
		",".join(inv_bits),
		_hud_hold,
		str(_hud_blocked),
		_hud_target_detail,
	]


func _emit_stats_if_changed() -> void:
	## Cheap dirty gate — avoid inventory.grouped() / string join when nothing changed.
	var inv_rev: int = int(inventory.revision) if inventory != null else 0
	var move := move_state()
	var stam := snappedf(stamina, 0.25)
	var stam_max := snappedf(stamina_max_now(), 0.25)
	var carry := int(carry_boxes())
	var hold := snappedf(hold_progress, 0.01)
	var tid: int = target.get_instance_id() if is_instance_valid(target) else 0
	var need := _hud_dirty
	if inv_rev != _hud_inv_rev:
		need = true
	elif move != _hud_move:
		need = true
	elif not is_equal_approx(stam, _hud_stam):
		need = true
	elif not is_equal_approx(stam_max, _hud_stam_max):
		need = true
	elif carry != _hud_carry:
		need = true
	elif not is_equal_approx(hold, _hud_hold):
		need = true
	elif blocked_mismatch != _hud_blocked:
		need = true
	elif tid != _hud_target_id:
		need = true
	elif tid != 0:
		var detail := _target_detail_fp(target)
		if detail != _hud_target_detail:
			need = true
			_hud_target_detail = detail
	if not need:
		return
	_hud_inv_rev = inv_rev
	_hud_move = move
	_hud_stam = stam
	_hud_stam_max = stam_max
	_hud_carry = carry
	_hud_hold = hold
	_hud_blocked = blocked_mismatch
	_hud_target_id = tid
	_hud_target_detail = _target_detail_fp(target) if tid != 0 else "-"
	_hud_dirty = false
	var fp := _hud_fingerprint()
	if fp == _hud_fp:
		return
	_hud_fp = fp
	stats_changed.emit()


func _enqueue_cust_speed(skill_id: String) -> void:
	if not _cust_speed_q.has(skill_id):
		_cust_speed_q.append(skill_id)
		_buff_cache_valid = false


func _customer_move_kind(skill_id: String) -> String:
	var ult_id := String(_ult_sk().get("id", ""))
	if ult_id != "" and skill_id == ult_id:
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
	var changed := not gone.is_empty()
	for id in gone:
		if id == "the_world":
			SfxBus.play("sfx_ult_the_world_end")
		_buffs.erase(id)
	for id in _cd.keys():
		_cd[id] = maxf(0.0, float(_cd[id]) - delta)
	var keep_q: Array[String] = []
	for id in _cust_speed_q:
		if _buffs.has(id):
			keep_q.append(id)
	if keep_q.size() != _cust_speed_q.size():
		changed = true
	_cust_speed_q = keep_q
	if changed or not _buff_cache_valid:
		_cached_clock = _world_clock_now()
		_cached_cust_mult = _customer_move_mult_now()
		_buff_cache_valid = true
	clock_scale = _cached_clock
	customer_move_mult = _cached_cust_mult


func _wiggle_axis() -> Vector2:
	var v := Controls.move_vector() + stick_axis
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _move_axis() -> Vector2:
	## Long-press aim, box flight, or a piece still in the air: no locomotion.
	## After the last piece lands, a direction that is still held walks again.
	if _cancel_drop_ready or _drop_flight_lock or _piece_drop_lock:
		return Vector2.ZERO
	if _elite_focus_left > 0.0:
		return Vector2.ZERO
	if _stun_left > 0.0 or _slip_left > 0.0 or _fighting or _shelving() or _cleaning():
		return Vector2.ZERO
	if _in_dir_mode():
		## Arm latch: skill menu / ult / checkout / restock pick consume move_* .
		_move_locked_until_neutral = true
		return Vector2.ZERO
	var v := Controls.move_vector() + stick_axis
	if _move_locked_until_neutral:
		if v.length() < Controls.MOVE_DEADZONE:
			_move_locked_until_neutral = false
		else:
			return Vector2.ZERO
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _poll_stick_cardinal() -> void:
	# Analog only (touch stick / left stick). Discrete move_* taps are handled in _input.
	if not _in_dir_mode():
		_cardinal_armed = true
		return
	var v := stick_axis + _joy_stick_vector()
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


func _joy_stick_vector() -> Vector2:
	var v := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	if v.length() < Controls.MOVE_DEADZONE:
		return Vector2.ZERO
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


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
	var walk := Tuning.WALK_SPEED * Tuning.PLAYER_MOVE_MULT * speed_mult()
	var target_speed := walk * (Tuning.RUN_SPEED_MULT if want_run else 1.0)
	var speed_cap := Tuning.WALK_SPEED * Tuning.PLAYER_MOVE_MULT * Tuning.SPEED_MAX_MULT
	target_speed = clampf(target_speed, Tuning.SPEED_FLOOR, speed_cap)
	if axis == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, walk * 8.0 * delta)
	else:
		velocity = axis * target_speed
		if velocity.length() > 8.0:
			SfxBus.play_foot(want_run)
			if inventory.count() > carry_cap():
				SfxBus.play_overcarry()
	move_and_slide()


func _try_dash() -> void:
	if _dashing or _fighting or _stun_left > 0.0 or _slip_left > 0.0:
		return
	_dash_guest_done = false
	if stamina < Tuning.DASH_STAMINA_COST:
		SfxBus.play("sfx_move_stamina_empty")
		return
	var dir := _move_axis()
	if dir == Vector2.ZERO:
		dir = facing
	_dashing = true
	_dash_dir = dir.normalized()
	_dash_left = Tuning.DASH_TIME
	stamina = maxf(0.0, stamina - Tuning.DASH_STAMINA_COST)
	_regen_delay = Tuning.STAMINA_REGEN_DELAY
	SfxBus.play("sfx_move_dash")
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
	if _has_flag("ignore_puddle_slip"):
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
	## Slip dump: no aim lock — player is already sliding.
	_drop_top_box(Vector2.ZERO, false)
	_spawn_fx("skid", global_position + Vector2(0, 8))
	SfxBus.play("sfx_move_slip")
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
		SfxBus.play("sfx_move_stun")


func _drop_top_box(toss_dir: Vector2 = Vector2.ZERO, lock_until_land: bool = true) -> void:
	if inventory.is_empty():
		return
	var run: Dictionary = inventory.trailing_run()
	var n := mini(Tuning.BOX_SIZE, int(run["count"]))
	inventory.remove_trailing(n)
	var game := _game()
	if game and game.has_method("spawn_dropped_box"):
		var landed := Callable()
		if lock_until_land:
			_drop_flight_lock = true
			_running = false
			_dashing = false
			velocity = Vector2.ZERO
			landed = Callable(self, "_on_drop_flight_done")
		game.call(
			"spawn_dropped_box",
			global_position,
			String(run["id"]),
			n,
			toss_dir,
			drop_toss_dist(),
			landed,
		)


func _on_drop_flight_done() -> void:
	_drop_flight_lock = false
	_cancel_drop_dir = Vector2.ZERO
	_hide_drop_aim()


func _tick_status(delta: float) -> void:
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		velocity = Vector2.ZERO
	if _sick_left > 0.0:
		_sick_left = maxf(0.0, _sick_left - delta)
	if _has_dirt_type(Tuning.DIRT_VOMIT) and not _has_flag("ignore_vomit_sick"):
		if _sick_left <= 0.0:
			log_line.emit("踩到嘔吐物 — 技能禁止、能力 −30% 10 秒")
		_sick_left = Tuning.SICK_SEC
	if _has_dirt_type(Tuning.DIRT_TRASH) and not _has_flag("ignore_trash_stamina"):
		stamina = maxf(0.0, stamina - Tuning.TRASH_STAMINA_PER_SEC * delta)
		_regen_delay = Tuning.STAMINA_REGEN_DELAY
	if _wave_vfx_cd > 0.0:
		_wave_vfx_cd = maxf(0.0, _wave_vfx_cd - delta)


func _regen(delta: float) -> void:
	if _dashing or _slip_left > 0.0 or (_running and _move_axis() != Vector2.ZERO) or (_has_dirt_type(Tuning.DIRT_TRASH) and not _has_flag("ignore_trash_stamina")):
		return
	if _regen_delay > 0.0:
		_regen_delay -= delta
		return
	stamina = minf(stamina_max_now(), stamina + Tuning.STAMINA_REGEN_PER_SEC * delta)


## Facing and range test. Returns distance, or -1 when this node is not a valid interact target.
func _interact_dist(node: Node2D) -> float:
	if node == null or not is_instance_valid(node):
		return -1.0
	var to_obj: Vector2 = node.global_position - global_position
	var dist_sq := to_obj.length_squared()
	if dist_sq > Tuning.INTERACT_RANGE_SQ or dist_sq < 0.000001:
		return -1.0
	var dist := sqrt(dist_sq)
	var kind := String(node.get("kind"))
	var dot := facing.dot(to_obj / dist)
	if kind == "dirt" and _dirt_areas.has(node):
		dot = 1.0
	elif kind == "thief":
		dot = maxf(dot, 0.85)
	if kind == "cashier":
		if global_position.y < node.global_position.y - 8.0:
			return -1.0
		dot = 1.0
	elif dot < Tuning.FACE_DOT:
		return -1.0
	return dist


func _nearest_kind(kind: String) -> Node2D:
	var best: Node2D = null
	var best_d := 1000000.0
	for node in interactables:
		if node == null or not is_instance_valid(node):
			continue
		if String(node.get("kind")) != kind:
			continue
		var d := _interact_dist(node)
		if d < 0.0 or d >= best_d:
			continue
		best_d = d
		best = node
	return best


func _nearest_active_thief() -> Node2D:
	var best: Node2D = null
	var best_d := 1000000.0
	for node in interactables:
		if node == null or not is_instance_valid(node):
			continue
		if String(node.get("kind")) != "thief":
			continue
		if not node.has_method("is_active_thief") or not bool(node.call("is_active_thief")):
			continue
		var d := _interact_dist(node)
		if d < 0.0 or d >= best_d:
			continue
		best_d = d
		best = node
	return best


func _nearest_stocked_shelf() -> Node2D:
	var best: Node2D = null
	var best_d := 1000000.0
	for node in interactables:
		if node == null or not is_instance_valid(node):
			continue
		if String(node.get("kind")) != "shelf":
			continue
		if int(node.get("count")) <= 0:
			continue
		var d := _interact_dist(node)
		if d < 0.0 or d >= best_d:
			continue
		best_d = d
		best = node
	return best


func _store_open() -> bool:
	var g := _game()
	return g != null and String(g.get("phase")) == "open"


func _faced_guests() -> Array:
	var found: Array = []
	var g := _game()
	if g == null:
		return found
	var custs = g.get("_customers")
	if custs == null:
		return found
	for c in custs.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.has_method("can_receive_delivery") or not bool(c.call("can_receive_delivery")):
			continue
		if _interact_dist(c) < 0.0:
			continue
		found.append(c)
	found.sort_custom(func(a, b) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return found


## Long-press target when no thief is in range. Restock ticks from the first frame; the others wait out the tap.
func _long_kind() -> String:
	if _nearest_kind("dirt") != null:
		return "dirt"
	if _store_open() and not inventory.is_empty() and not _faced_guests().is_empty():
		return "guest"
	if _nearest_kind("shelf") != null:
		return "shelf"
	if _nearest_kind("cashier") != null:
		return "cashier"
	if _nearest_kind("restock") != null:
		return "restock"
	if _nearest_kind("drop") != null:
		return "drop"
	return ""


func _preview_target() -> Node2D:
	var thief := _nearest_active_thief()
	if thief != null:
		return thief
	var stocked := _nearest_stocked_shelf()
	if stocked != null:
		return stocked
	var restock := _nearest_kind("restock")
	if restock != null:
		return restock
	var drop := _nearest_kind("drop")
	if drop != null:
		return drop
	match _long_kind():
		"dirt":
			return _nearest_kind("dirt")
		"guest":
			var guests := _faced_guests()
			return guests[0] if not guests.is_empty() else null
		"shelf":
			return _nearest_kind("shelf")
		"cashier":
			return _nearest_kind("cashier")
	return null


func _release_interact() -> void:
	if _restock_aborted:
		_restock_aborted = false
		_restock_picking = false
		_restock_hold = 0.0
		return
	if _fighting or _long_committed or _deliver_done or _restock_picking:
		if _restock_picking and target != null and String(target.get("kind")) == "restock":
			var sku := String(target.call("commit_pick"))
			SfxBus.play("sfx_box_sku_confirm")
			log_line.emit("補貨點改為 %s" % Tuning.sku_name(sku))
		_restock_picking = false
		_restock_hold = 0.0
		return
	_do_short_interact()
	_restock_picking = false
	_restock_hold = 0.0


## Tap: thief (already grabbed), else one piece off a stocked shelf, else a restock box, else a floor box.
func _do_short_interact() -> void:
	if _nearest_active_thief() != null:
		return
	var shelf := _nearest_stocked_shelf()
	if shelf != null:
		_take_shelf_piece(shelf)
		return
	var restock := _nearest_kind("restock")
	if restock != null:
		target = restock
		_pickup_used = false
		_try_pickup()
		return
	var drop := _nearest_kind("drop")
	if drop != null:
		target = drop
		_pickup_used = false
		_tick_drop()
		return
	if _store_open() and not inventory.is_empty() and not _faced_guests().is_empty():
		log_line.emit("長按行動鍵把貨交給客人")


func _take_shelf_piece(shelf: Node2D) -> void:
	if inventory.count() >= carry_cap():
		SfxBus.play("sfx_box_pull_fail")
		log_line.emit("負重不足：%d/%d 件" % [inventory.count(), carry_cap()])
		return
	var sku := String(shelf.get("sku"))
	if sku == "" or not shelf.has_method("take_n"):
		return
	var taken := int(shelf.call("take_n", 1))
	if taken <= 0:
		return
	inventory.add_one(sku)
	_spawn_fx("suck", shelf.global_position)
	SfxBus.play("sfx_box_pull")
	log_line.emit("從貨架取 %s 1件" % Tuning.sku_name(sku))


func _guest_wants_carried(guest: Node) -> bool:
	if guest == null or not is_instance_valid(guest):
		return false
	for s in guest.shopping:
		if inventory.count_of(String(s)) > 0:
			return true
	return false


func _give_guest(guest: Node) -> int:
	if guest == null or not guest.has_method("accept_toss_box"):
		return 0
	var given := 0
	var seen := {}
	var wants: Array[String] = []
	for s in guest.shopping:
		var sku := String(s)
		if seen.has(sku):
			continue
		seen[sku] = true
		wants.append(sku)
	for sku in wants:
		if guest.has_method("can_receive_delivery") and not bool(guest.call("can_receive_delivery")):
			break
		var need := 0
		for s in guest.shopping:
			if String(s) == sku:
				need += 1
		var n := mini(need, inventory.count_of(sku))
		if n <= 0:
			continue
		var taken := int(guest.call("accept_toss_box", sku, n))
		if taken > 0:
			inventory.remove_sku(sku, taken)
			given += taken
	return given


## Nearest guest first. `penalize_miss` adds +15 on the nearest guest when nothing matched.
func _hand_deliver(guests: Array, penalize_miss: bool) -> int:
	var total := 0
	var nearest: Node = null
	for guest in guests:
		if guest == null or not is_instance_valid(guest):
			continue
		if not guest.has_method("can_receive_delivery") or not bool(guest.call("can_receive_delivery")):
			continue
		if nearest == null:
			nearest = guest
		total += _give_guest(guest)
	if total > 0:
		SfxBus.play("sfx_box_hit_guest_ok")
		log_line.emit("交給客人 ×%d" % total)
		_deliver_pose_left = 0.4
		return total
	if penalize_miss and nearest != null and nearest.has_method("apply_toss_reject"):
		nearest.call("apply_toss_reject", "")
		SfxBus.play("sfx_box_hit_guest_reject")
		log_line.emit("沒有對的貨 — 不滿 +15")
	return 0


func _dash_guests() -> Array:
	var found: Array = []
	var g := _game()
	if g == null:
		return found
	var custs = g.get("_customers")
	if custs == null:
		return found
	for c in custs.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if bool(c.get("is_thief")):
			continue
		var st := int(c.get("state"))
		if st == 7 or st == 9:
			continue
		if float(c.get("_dash_stun_left")) > 0.0:
			continue
		if global_position.distance_to(c.global_position) > Tuning.DASH_HIT_RANGE:
			continue
		found.append(c)
	found.sort_custom(func(a, b) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return found


## Warm halo on the one object the interact button would actually use.
func _sync_interact_glow() -> void:
	var host := _glow_host_now()
	if host != null and host == _glow_host and is_instance_valid(_interact_glow) and _interact_glow.get_parent() == host:
		return
	_detach_interact_glow()
	if host == null:
		return
	if _interact_glow == null or not is_instance_valid(_interact_glow):
		_interact_glow = GlowScript.new()
		_interact_glow.name = "InteractGlow"
	_interact_glow.call("set_span", _glow_span(host))
	host.add_child(_interact_glow)
	_glow_host = host


func _detach_interact_glow() -> void:
	_glow_host = null
	if _interact_glow == null or not is_instance_valid(_interact_glow):
		_interact_glow = null
		return
	var parent := _interact_glow.get_parent()
	if parent != null:
		parent.remove_child(_interact_glow)


func _glow_host_now() -> Node2D:
	if not _round_active() or _asking_early():
		return null
	if skill_menu_open or ult_prep or _stun_left > 0.0 or _slip_left > 0.0 or _elite_focus_left > 0.0:
		return null
	if _cancel_drop_ready:
		return null
	if not is_instance_valid(target):
		return null
	if not _interact_available(target):
		return null
	return target


## True when pressing interact would start a real action on this node.
func _interact_available(node: Node2D) -> bool:
	var kind := String(node.get("kind"))
	if kind == "thief":
		return inventory.is_empty() and node.has_method("is_active_thief") and bool(node.call("is_active_thief"))
	if kind == "shelf":
		return _shelf_interactable(node)
	if kind == "restock":
		return _restock_interactable(node)
	if kind == "drop":
		var n := int(node.get("count"))
		return n > 0 and inventory.count() + n <= carry_cap()
	if kind == "dirt":
		return inventory.is_empty()
	if kind == "cashier":
		return node.has_method("ready_customer") and node.call("ready_customer") != null
	if kind == "elite" or kind == "":
		if not _store_open() or inventory.is_empty():
			return false
		if not node.has_method("can_receive_delivery"):
			return false
		return bool(node.call("can_receive_delivery"))
	return false


func _shelf_interactable(node: Node2D) -> bool:
	if int(node.get("count")) > 0 and inventory.count() < carry_cap():
		return true
	if inventory.is_empty() or not node.has_method("can_accept"):
		return false
	var run: Dictionary = inventory.trailing_run()
	return bool(node.call("can_accept", String(run["id"])))


func _restock_interactable(node: Node2D) -> bool:
	if not node.has_method("skus"):
		return false
	var raw = node.call("skus")
	if not (raw is Array):
		return false
	return not (raw as Array).is_empty()


## Same halo shape as the first fit, pulled in a little so it sits closer to the body.
const GLOW_SPAN_SCALE := 0.85


func _glow_span(node: Node2D) -> Vector2:
	var kind := String(node.get("kind"))
	var span := Vector2(150.0, 150.0)
	if kind == "shelf" or kind == "cashier" or kind == "restock":
		span = Vector2(240.0, 150.0)
		for child in node.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var sz: Vector2 = (child.shape as RectangleShape2D).size
				span = Vector2(maxf(sz.x, 64.0) * 1.85, maxf(sz.y, 48.0) * 2.15)
				break
	elif kind == "dirt":
		span = Vector2(168.0, 140.0)
	elif kind == "drop":
		span = Vector2(120.0, 120.0)
	return span * GLOW_SPAN_SCALE


func _update_target() -> void:
	if _fighting:
		return
	## Aim / flight / slip / held interact: keep the action target (no full rescan).
	if _j_held or _cancel_drop_ready or _drop_flight_lock or _slip_left > 0.0:
		return
	var best := _preview_target()
	if target != best:
		if _restock_picking and target != null and String(target.get("kind")) == "restock":
			target.call("abort_pick")
		_restock_picking = false
		_restock_hold = 0.0
		_reset_hold()
		_pickup_used = false
		_hud_dirty = true
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
	if not _j_held:
		hold_progress = 0.0
		_clear_clean_hint()
		return
	_j_time += delta
	var thief := _nearest_active_thief()
	if thief != null:
		target = thief
		_begin_fight()
		return
	var long_kind := _long_kind()
	if long_kind == "restock":
		target = _nearest_kind("restock")
		_tick_sku_pick(delta)
		return
	if _j_time < Tuning.SKU_PICK_HOLD:
		return
	match long_kind:
		"dirt":
			_long_committed = true
			target = _nearest_kind("dirt")
			_tick_clean(delta)
		"guest":
			_long_committed = true
			var guests := _faced_guests()
			if not guests.is_empty():
				target = guests[0]
			if not _deliver_done:
				_deliver_done = true
				_hand_deliver(guests, true)
		"shelf":
			_long_committed = true
			target = _nearest_kind("shelf")
			_tick_restock(delta)
		"cashier":
			_long_committed = true
			target = _nearest_kind("cashier")
			_tick_cashier(delta)


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
	_fight_ko = false
	_fight_release = true
	target.call("begin_fight")
	SfxBus.play("sfx_fight_grab")
	log_line.emit("抓住小偷 — 連按行動鍵扣血，剩 5 秒")
	if camera:
		camera.position = (target.global_position - global_position) * 0.35
		var tw := create_tween()
		tw.tween_property(
			camera, "zoom",
			Vector2(Tuning.FIGHT_ZOOM, Tuning.FIGHT_ZOOM),
			0.16,
		)


func _tick_fight(delta: float) -> void:
	if _fight_ko:
		_tick_camera_shake(delta)
		return
	if not is_instance_valid(target) or not bool(target.call("in_fight")):
		_end_fight(false)
		return
	target.fight_left = maxf(0.0, float(target.fight_left) - delta)
	hold_progress = clampf(float(target.fight_hp) / 100.0, 0.0, 1.0)
	target.call("_refresh_labels")
	_tick_camera_shake(delta)
	if float(target.fight_left) <= 0.0:
		_fight_fail()


func _fight_tap() -> void:
	if not is_instance_valid(target) or _fight_ko:
		return
	var dmg := Tuning.hit_damage(_str_now())
	_shake_camera(Tuning.FIGHT_HIT_SHAKE, Tuning.FIGHT_HIT_SHAKE_SEC)
	SfxBus.play("sfx_fight_hit")
	if bool(target.call("take_hit", dmg)):
		_fight_win()


func _fight_win() -> void:
	if _fight_ko:
		return
	_fight_ko = true
	var game := _game()
	if game and game.has_method("record_caught"):
		game.call("record_caught")
	log_line.emit("打倒小偷 — KO！贓物散落地上")
	_play_ko_sequence(target, "ko_scatter_and_flee")


## Directional tossed box hit an active thief → Screen KO (counts as catch).
func apply_toss_ko(thief: Node, knock_dir: Vector2) -> void:
	if thief == null or not is_instance_valid(thief):
		return
	if not thief.has_method("is_active_thief") or not bool(thief.call("is_active_thief")):
		return
	if not thief.has_method("ko_box_hit_and_flee"):
		return
	var game := _game()
	if game and game.has_method("record_caught"):
		game.call("record_caught")
	log_line.emit("貨箱砸中小偷 — KO！贓物原地掉落")
	SfxBus.play("sfx_box_hit_thief")
	## If this toss finishes an ongoing grab fight, clear fight state after the KO.
	var end_fight := _fighting and target == thief
	if end_fight:
		_fight_ko = true
	var dir := knock_dir
	if dir.length_squared() < 0.01:
		dir = (thief as Node2D).global_position - global_position
	if dir.length_squared() < 0.01:
		dir = facing
	_play_ko_sequence(thief, "ko_box_hit_and_flee", dir.normalized(), end_fight)


func _play_ko_sequence(
	thief: Node,
	flee_method: String = "ko_scatter_and_flee",
	knock_override: Vector2 = Vector2.ZERO,
	end_fight: bool = true,
) -> void:
	_shake_camera(Tuning.FIGHT_KO_SHAKE, 0.22)
	SfxBus.play("sfx_ko_screen")
	if camera:
		var punch := create_tween()
		punch.tween_property(
			camera, "zoom",
			Vector2(Tuning.FIGHT_KO_ZOOM, Tuning.FIGHT_KO_ZOOM),
			0.07,
		)
	var game := _game()
	if game and game.has_method("play_ko_banner"):
		game.call("play_ko_banner")
	await get_tree().create_timer(0.18).timeout
	if is_instance_valid(thief) and thief.has_method(flee_method):
		var knock: Vector2 = knock_override
		if knock.length_squared() < 0.01:
			knock = (thief as Node2D).global_position - global_position
		if knock.length_squared() < 0.01:
			knock = facing
		thief.call(flee_method, knock.normalized())
	await get_tree().create_timer(Tuning.FIGHT_KO_FLASH_SEC * 0.55).timeout
	if end_fight:
		_end_fight(true)
	elif camera:
		## Toss KO outside a fight: restore shop framing after the punch-in.
		camera.zoom = Vector2(Tuning.CAMERA_ZOOM, Tuning.CAMERA_ZOOM)
		camera.offset = Vector2.ZERO


func _fight_fail() -> void:
	if _fight_ko:
		return
	if is_instance_valid(target):
		var away := global_position - target.global_position
		if away.length_squared() < 0.01:
			away = -facing
		facing = away.normalized()
		target.call("escape_with_loot")
	log_line.emit("打擊失敗 — 被撞開，倒地 5 秒")
	SfxBus.play("sfx_fight_fail")
	SfxBus.play("sfx_move_stun")
	_end_fight(false)
	_dashing = false
	_running = false
	_slip_left = Tuning.SLIP_TIME
	_stun_pending = Tuning.FIGHT_DOWN_SEC


func _end_fight(_won: bool) -> void:
	_fighting = false
	_fight_release = false
	_fight_ko = false
	_shake_left = 0.0
	hold_progress = 0.0
	if camera:
		camera.zoom = Vector2(Tuning.CAMERA_ZOOM, Tuning.CAMERA_ZOOM)
		camera.position = Vector2.ZERO
		camera.offset = Vector2.ZERO
	var game := _game()
	if game != null and game.has_method("notify_camera_priority_idle"):
		game.call("notify_camera_priority_idle")


func camera_priority_busy() -> bool:
	## Fight / KO framing beats EliteCustomer intro zoom.
	return _fighting or _fight_ko


func play_elite_focus(target_node: Node, sec: float = Tuning.ELITE_ZOOM_SEC) -> void:
	if target_node == null or not is_instance_valid(target_node) or camera == null:
		await get_tree().create_timer(sec).timeout
		return
	_elite_focus_left = maxf(_elite_focus_left, sec)
	var base_z := Tuning.CAMERA_ZOOM
	var punch_z := base_z * 1.35
	camera.position = ((target_node as Node2D).global_position - global_position) * 0.55
	var tw := create_tween()
	tw.tween_property(camera, "zoom", Vector2(punch_z, punch_z), 0.18)
	await get_tree().create_timer(sec).timeout
	if camera:
		var back := create_tween()
		back.tween_property(camera, "zoom", Vector2(base_z, base_z), 0.22)
		back.parallel().tween_property(camera, "position", Vector2.ZERO, 0.22)
	_elite_focus_left = 0.0


func _shake_camera(mag: float, dur: float) -> void:
	_shake_mag = mag
	_shake_left = maxf(_shake_left, dur)


func _tick_camera_shake(delta: float) -> void:
	if camera == null:
		return
	if _shake_left <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_shake_left = maxf(0.0, _shake_left - delta)
	var falloff := clampf(_shake_left / maxf(Tuning.FIGHT_HIT_SHAKE_SEC, 0.01), 0.0, 1.0)
	var m := _shake_mag * (0.35 + 0.65 * falloff)
	camera.offset = Vector2(randf_range(-m, m), randf_range(-m, m))


func _try_dash_thief() -> void:
	_try_dash_hits()


func _try_dash_hits() -> void:
	var g := _game()
	if g == null:
		return
	_try_wave_dirt_vfx()
	## Thieves first (caught).
	if g.has_method("thieves"):
		for t in g.call("thieves"):
			if t == null or not is_instance_valid(t):
				continue
			if not bool(t.call("is_active_thief")):
				continue
			if global_position.distance_to(t.global_position) > Tuning.DASH_HIT_RANGE:
				continue
			t.call("dash_knock_away", _dash_dir)
			if g.has_method("record_caught"):
				g.call("record_caught")
			SfxBus.play("sfx_thief_dash_out")
			log_line.emit("衝刺撞飛小偷 — 算抓住，贓物散落")
			if _fighting:
				_end_fight(false)
			return
	## One guest resolution per dash: deliver if 衝刺交付 is up and the nearest wants a carried piece, else KO.
	if _dash_guest_done:
		return
	var guests := _dash_guests()
	if guests.is_empty():
		return
	var nearest: Node = guests[0]
	if buff_left("dash_deliver") > 0.0 and nearest.has_method("can_receive_delivery") and bool(nearest.call("can_receive_delivery")) and _guest_wants_carried(nearest):
		var gave := _hand_deliver(guests, false)
		if gave > 0:
			_dash_guest_done = true
			log_line.emit("衝刺交付 ×%d — 不撞飛" % gave)
			return
	_dash_guest_done = true
	var add := 0.0 if _has_flag("polite_dash") else Tuning.DASH_GUEST_DISSAT
	if g.has_method("play_ko_banner"):
		g.call("play_ko_banner")
	if nearest.has_method("dash_knock_guest"):
		nearest.call("dash_knock_guest", add)
	SfxBus.play("sfx_ko_guest_dash")
	log_line.emit("衝刺撞到客人 — 暈眩 2 秒，貨品掉落" if add > 0.0 else "衝刺撞到客人 — 禮貌衝撞，不滿不增加")


func _try_wave_dirt_vfx() -> void:
	if not _has_flag("ignore_dirt_slow") or _wave_vfx_cd > 0.0:
		return
	if not on_dirt():
		return
	_wave_vfx_cd = 0.2
	var ring := Polygon2D.new()
	ring.color = Color(0.45, 0.95, 1.0, 0.55)
	ring.polygon = PackedVector2Array([
		Vector2(-18, 0), Vector2(0, -12), Vector2(18, 0), Vector2(0, 12),
	])
	ring.z_index = 9
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.22)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ring.queue_free)


func _tick_sku_pick(delta: float) -> void:
	_restock_hold += delta
	if _restock_picking or _restock_hold < Tuning.SKU_PICK_HOLD:
		return
	_restock_picking = true
	target.call("begin_pick")
	SfxBus.play("sfx_box_sku_open")
	log_line.emit("貨品清單 — 上下選擇，放手確定，B／; 取消")


func _abort_restock_pick() -> void:
	if target != null and String(target.get("kind")) == "restock":
		target.call("abort_pick")
		SfxBus.play("sfx_box_sku_cancel")
	_restock_picking = false
	_restock_hold = 0.0


func _try_pickup() -> void:
	if _pickup_used:
		return
	_pickup_used = true
	if not inventory.can_take_box(carry_cap()):
		SfxBus.play("sfx_box_pull_fail")
		log_line.emit("負重不足：%d/%d 箱" % [inventory.count() / Tuning.BOX_SIZE, carry_boxes()])
		return
	if not bool(target.call("take_box")):
		SfxBus.play("sfx_box_pull_fail")
		log_line.emit("%s 補貨點已空" % Tuning.sku_name(String(target.call("selected_sku"))))
		return
	var sku := String(target.call("selected_sku"))
	inventory.take_box(sku)
	_spawn_fx("suck", target.global_position)
	SfxBus.play("sfx_box_pull")
	log_line.emit("執貨（即時）%s 1箱 +%d" % [Tuning.sku_name(sku), Tuning.BOX_SIZE])


func _tick_restock(delta: float) -> void:
	if inventory.is_empty():
		log_line.emit("空手 — 不能上架")
		_j_held = false
		return
	var run: Dictionary = inventory.trailing_run()
	var sku := String(run["id"])
	if not bool(target.call("can_accept", sku)):
		if int(target.get("count")) >= int(target.get("capacity")):
			SfxBus.play("sfx_shelf_stock_blocked")
			log_line.emit("貨架已滿")
			_j_held = false
			_reset_hold()
			return
		if not blocked_mismatch:
			SfxBus.play("sfx_shelf_stock_blocked")
		blocked_mismatch = true
		hold_progress = 0.0
		return
	var dur := restock_seconds_now()
	if dur <= 0.001:
		hold_progress = 1.0
	else:
		hold_progress = minf(1.0, hold_progress + delta / dur)
		if hold_progress < 1.0:
			SfxBus.play_stock_loop()
	if hold_progress >= 1.0:
		var placed := int(target.call("add_items", sku, int(run["count"])))
		inventory.remove_trailing(placed)
		_spawn_fx("spray", target.global_position + Vector2(0, -20))
		if dur <= 0.001:
			SfxBus.play("sfx_shelf_stock_instant")
		else:
			SfxBus.play("sfx_shelf_stock_done")
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
		var before := hold_progress
		hold_progress = minf(1.0, hold_progress + travel / needed)
		if hold_progress > before:
			SfxBus.play_scrub()
	if not _clean_hint:
		_clean_hint = true
		SfxBus.play("sfx_clean_start")
		log_line.emit("清潔 %s — 按住行動並持續轉搖桿／方向" % String(target.call("type_name")))
	target.call("set_cleaning", true, axis, hold_progress * 100.0)
	if hold_progress >= 1.0:
		var name := String(target.call("type_name"))
		var spark_at := target.global_position
		target.queue_free()
		target = null
		hold_progress = 0.0
		_clean_hint = false
		_last_wiggle = Vector2.ZERO
		_spawn_fx("clean_spark", spark_at)
		SfxBus.play("sfx_clean_done")
		var game := _game()
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
		inventory.add_one(sku)
	SfxBus.play("sfx_box_pickup_floor")
	log_line.emit("撿起 %s ×%d" % [Tuning.sku_name(sku), taken])


func _clear_clean_hint() -> void:
	if _clean_hint:
		SfxBus.play("sfx_clean_cancel")
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
		SfxBus.play("sfx_checkout_enter")
		log_line.emit("收銀指令 %d 次（購物 %d 件）" % [n, cust.cart.size()])
	cust.begin_paying()


func _try_dir(dir: int) -> void:
	if _restock_picking:
		if target != null and String(target.get("kind")) == "restock":
			if dir == 0:
				target.call("move_pick", -1)
				SfxBus.play("sfx_box_sku_move")
			elif dir == 1:
				target.call("move_pick", 1)
				SfxBus.play("sfx_box_sku_move")
		return
	if ult_prep:
		_try_ult_dir(dir)
		return
	if skill_menu_open:
		var slot_i: int = int(Skills.DIR_TO_SLOT.get(dir, -1))
		if slot_i < 0:
			return
		if _skill_latch:
			SfxBus.play("sfx_skill_menu_move")
			_confirm_skill(slot_i)
			return
		## Hold: the direction only previews. Release of the skill key confirms.
		_set_skill_aim(slot_i)
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
		SfxBus.play("sfx_checkout_dir_ok")
		if seq_index >= seq.size():
			seq_done = true
			SfxBus.play("sfx_checkout_seq_done")
			log_line.emit("指令完成 — 維持長按出現 Loading Circle")
	else:
		_prompt.fail_at = seq_index
		seq_index = 0
		SfxBus.play("sfx_checkout_dir_fail")
		log_line.emit("指令錯誤 × 同一串重來")


func _finish_checkout(cust) -> void:
	var amount: int = int(cust.call("payout_total")) if cust.has_method("payout_total") else int(cust.call("cart_total"))
	var from_elite := bool(cust.get("is_elite"))
	## paid signal → demo._on_paid; pass elite via game helper when connected.
	var game := _game()
	if game != null and game.has_method("_on_paid"):
		game.call("_on_paid", amount, from_elite)
	else:
		paid.emit(amount)
	SfxBus.play("sfx_checkout_circle_done")
	if from_elite:
		log_line.emit("麻煩客人收銀  +$%d（雙倍）" % amount)
	else:
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
	SfxBus.play("sfx_checkout_cash_pop")
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


func _on_skill_hold(pressed: bool) -> void:
	if pressed:
		if _sick_left > 0.0 or _stun_left > 0.0 or _fighting:
			log_line.emit("現在不能發動技能")
			return
		if _skill_latch:
			_confirm_skill(0)
			_skill_release_ignore = true
			return
		_l_held = true
		_l_time = 0.0
		_skill_aim = 0
		return
	if _skill_release_ignore:
		_skill_release_ignore = false
		_l_held = false
		return
	## Cancel already dropped the hold, or this release is not ours.
	if not _l_held:
		return
	if skill_menu_open:
		if not _skill_latch:
			_sync_hold_aim()
		_confirm_skill(_skill_aim)
		return
	var short := _l_time < Skills.HOLD_MENU_SEC
	_l_held = false
	if short:
		_open_skill_menu(true)


func _open_skill_menu(latch: bool) -> void:
	skill_menu_open = true
	_skill_latch = latch
	_skill_aim = 0
	_move_locked_until_neutral = true
	_running = false
	velocity = Vector2.ZERO
	if _menu:
		_menu.open = true
		_menu.call("set_slots", _loadout(), _cd)
		if _menu.has_method("set_aim"):
			_menu.call("set_aim", 0)
	_menu_fp = "%s|%s" % [str(_cd), str(_loadout())]
	## A stick already pushed for walking must not count as the tap-menu choice.
	if latch and (stick_axis.length() >= 0.42 or _joy_stick_vector().length() >= 0.42):
		_cardinal_armed = false
	SfxBus.play("sfx_skill_menu_open")
	if latch:
		log_line.emit("技能選單 — 按方向即發動，再按技能鍵發動中間")
	else:
		log_line.emit("技能選單 — 拉方向預覽，放開發動；回中則中間")


func _sync_hold_aim() -> void:
	_set_skill_aim(_skill_aim_slot())


func _skill_aim_slot() -> int:
	var v := Controls.move_vector() + stick_axis
	if v.length() < 0.42:
		return 0
	var dir := Skills.DIR_DOWN if v.y > 0.0 else Skills.DIR_UP
	if absf(v.x) > absf(v.y):
		dir = Skills.DIR_RIGHT if v.x > 0.0 else Skills.DIR_LEFT
	return int(Skills.DIR_TO_SLOT.get(dir, 0))


func _set_skill_aim(slot: int) -> void:
	slot = clampi(slot, 0, 4)
	if slot == _skill_aim:
		if _menu and _menu.has_method("set_aim"):
			_menu.call("set_aim", slot)
		return
	_skill_aim = slot
	if _menu and _menu.has_method("set_aim"):
		_menu.call("set_aim", slot)
	SfxBus.play("sfx_skill_menu_move")


func _confirm_skill(slot: int) -> void:
	_close_skill_menu()
	_cast_slot(slot)
	_move_locked_until_neutral = true
	velocity = Vector2.ZERO


func _close_skill_menu() -> void:
	_l_held = false
	_l_time = 0.0
	_skill_latch = false
	_skill_aim = 0
	skill_menu_open = false
	if _menu:
		_menu.open = false
		if _menu.has_method("set_aim"):
			_menu.call("set_aim", 0)


func _on_ult_hold(pressed: bool) -> void:
	if pressed:
		if _sick_left > 0.0 or _stun_left > 0.0 or _fighting:
			log_line.emit("現在不能發動奧義")
			return
		var ult := _ult_sk()
		if ult.is_empty() or String(ult.get("id", "")) == "":
			log_line.emit("沒有裝備奧義")
			return
		if bool(ult.get("unimplemented", false)):
			log_line.emit("%s 本 Demo 未實作，不會進入冷卻" % String(ult.get("name")))
			return
		var ult_id := String(ult.get("id"))
		if cd_left(ult_id) > 0.05:
			SfxBus.play("sfx_skill_cd_deny")
			log_line.emit("奧義冷卻中 %.0fs" % cd_left(ult_id))
			return
		_u_held = true
		ult_prep = true
		_ult_index = 0
		SfxBus.play("sfx_ult_prep")
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
		SfxBus.play("sfx_ult_cancel")
		log_line.emit("放手 — 奧義取消")
	_u_held = false
	ult_prep = false
	if not command_lock:
		_prompt.active = false
		_prompt.fail_at = -1


func _try_ult_dir(dir: int) -> void:
	var seq: Array = _ult_sk().get("seq", [])
	if seq.is_empty() or _ult_index < 0 or _ult_index >= seq.size():
		return
	if dir == int(seq[_ult_index]):
		_prompt.fail_at = -1
		_ult_index += 1
		_prompt.index = _ult_index
		SfxBus.play("sfx_ult_dir_ok")
		if _ult_index >= seq.size():
			_cast_ultimate()
			_u_held = false
			ult_prep = false
	else:
		_prompt.fail_at = _ult_index
		_ult_index = 0
		_prompt.index = 0
		SfxBus.play("sfx_ult_dir_fail")
		log_line.emit("奧義指令錯誤 × 同一串重來")


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
		SfxBus.play("sfx_skill_cd_deny")
		log_line.emit("%s 冷卻中 %.0fs" % [String(sk.get("name")), cd_left(sid)])
		return
	_cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), _int_now())
	_buffs[sid] = float(sk.get("duration", Skills.ACTIVE_DURATION))
	## 衝刺交付: the armed window is the cooldown itself, and INT does not shorten this 5s.
	if bool(sk.get("dash_deliver", false)):
		var window := float(sk.get("cd", 5.0))
		_cd[sid] = window
		_buffs[sid] = window
	_buff_cache_valid = false
	if sk.has("customer_move_pct"):
		_enqueue_cust_speed(sid)
	if sk.has("soothe_keep"):
		var game := _game()
		if game and game.has_method("soothe_all"):
			game.soothe_all(float(sk.get("soothe_keep")))
		SfxBus.play("sfx_skill_soothe")
	else:
		SfxBus.play("sfx_skill_cast")
	log_line.emit("施放 %s LV%d" % [String(sk.get("name")), int(sk.get("lv", 3))])
	_begin_cast_pose(false)
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
	if sk.is_empty() or String(sk.get("id", "")) == "":
		log_line.emit("沒有裝備奧義")
		_prompt.active = false
		return
	if bool(sk.get("unimplemented", false)):
		log_line.emit("%s 本 Demo 未實作" % String(sk.get("name")))
		_prompt.active = false
		return
	var sid := String(sk.get("id"))
	var lv := int(sk.get("lv", 3))
	_cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ULT_CD)), _int_now())
	_buff_cache_valid = false
	var game := _game()
	if sid == "fundraise":
		if game and game.has_method("cast_fundraise"):
			game.call("cast_fundraise", lv)
		SfxBus.play("sfx_ult_fundraise")
		log_line.emit("奧義 全體集資 LV%d" % lv)
		_begin_cast_pose(true)
		skill_cast.emit(String(sk.get("name")), true)
		_play_zoom(true)
		_prompt.active = false
		return
	if sid == "yes_my_lord":
		_buffs[sid] = _lord_seconds(lv)
		_buff_cache_valid = false
		SfxBus.play("sfx_ult_yes_my_lord")
		log_line.emit("奧義 Yes! My Lord! LV%d — 客人搶購 %.0f 秒" % [lv, _lord_seconds(lv)])
		_begin_cast_pose(true)
		_spawn_fx("combo", global_position + Vector2(0, -36))
		skill_cast.emit(String(sk.get("name")), true)
		_play_zoom(true)
		_prompt.active = false
		return
	_buffs[sid] = float(sk.get("duration", Skills.ULT_DURATION))
	_buff_cache_valid = false
	_enqueue_cust_speed(sid)
	SfxBus.play("sfx_ult_the_world")
	log_line.emit("奧義 %s LV%d — 時停" % [String(sk.get("name")), lv])
	_begin_cast_pose(true)
	_spawn_fx("timestop", global_position + Vector2(0, -40))
	skill_cast.emit(String(sk.get("name")), true)
	_play_zoom(true)
	_prompt.active = false


func _begin_cast_pose(ult: bool) -> void:
	_cast_pose_left = 0.55 if ult else 0.35


func _spawn_fx(fx_id: String, at: Vector2) -> void:
	var host: Node = _game()
	if host == null:
		host = get_parent()
	FxBurst.spawn(host, fx_id, at)


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
		SfxBus.play("sfx_checkout_release_reset")
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


func _handle_hotkey_actions(event: InputEvent) -> void:
	if target == null or String(target.get("kind")) != "restock":
		return
	if event.is_action_pressed(Controls.RESTOCK_PREV):
		target.call("cycle", -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Controls.RESTOCK_NEXT):
		target.call("cycle", 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Controls.RESTOCK_SLOT_1):
		target.call("set_highlight", 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Controls.RESTOCK_SLOT_2):
		target.call("set_highlight", 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Controls.RESTOCK_SLOT_3):
		target.call("set_highlight", 2)
		get_viewport().set_input_as_handled()


func _visual_anim() -> String:
	if _stun_left > 0.0:
		return "down"
	if _slip_left > 0.0:
		return "slip"
	if _cast_pose_left > 0.0 and Vox.has_anim("player", "cast"):
		return "cast"
	if _deliver_pose_left > 0.0 and Vox.has_anim("player", "deliver"):
		return "deliver"
	if _fighting:
		return "fight"
	if _cleaning():
		return "clean"
	if command_lock:
		return "checkout"
	if _shelving():
		return "restock"
	if _dashing:
		return "dash"
	if _running and velocity.length() > 8.0:
		return "run"
	if velocity.length() > 8.0:
		if not inventory.is_empty() and Vox.has_anim("player", "walk_carry"):
			return "walk_carry"
		return "walk"
	return "idle"


func _update_visuals() -> void:
	if _arrow:
		_arrow.rotation = facing.angle() + PI / 2.0
	if _body == null:
		return
	var anim := _visual_anim()
	var anim_key := "%s_%d_%.2f" % [anim, Vox.k_from_facing(facing), 1.25 if _running else 1.0]
	if _body is AnimatedSprite2D:
		if anim_key != _shown_anim:
			_shown_anim = anim_key
			var spd := 1.25 if _running else 1.0
			Vox.play_anim(_body as AnimatedSprite2D, "player", anim, facing, spd)
	elif _body is Sprite2D:
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
	if tint != _shown_tint:
		_shown_tint = tint
		_body.modulate = tint
