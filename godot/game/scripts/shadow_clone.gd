extends CharacterBody2D
## Multiple Shadow Clone: player look, snapshot stats, cashier or restock for 30s.

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const ShadowCloneCast = preload("res://scripts/shadow_clone_cast.gd")
const FxBurst = preload("res://scripts/fx_burst.gd")

var is_shadow_clone: bool = true
var role: String = ""
var register: Node2D
var snap_str: int = 10
var snap_agi: int = 10
var snap_int: int = 10
var move_pct: float = 0.0
var restock_pct: float = 0.0
var checkout_pct: float = 0.0
var wave_step: bool = false
var temp_left: float = ShadowCloneCast.DURATION
var dirt_contacts: int = 0
var _dirt_areas: Array[Node] = []

var _game: Node
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0
var _goal: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _shelf: Node2D
var _plan_sku: String = ""
var _box_sku: String = ""
var _box_n: int = 0
var _sprite: CanvasItem
var _label: Label
var _job_search_cd: float = 0.0
var _shown_anim: String = ""
var _dash_stun_left: float = 0.0
var _dash_ko_tween: Tween
var _vanishing: bool = false
var _facing: Vector2 = Vector2.DOWN
var _model_id: String = "player"


func setup(game: Node, at: Vector2, snap: Dictionary) -> void:
	_game = game
	global_position = at
	snap_str = int(snap.get("str", 10))
	snap_agi = int(snap.get("agi", 10))
	snap_int = int(snap.get("int", 10))
	move_pct = float(snap.get("move_pct", 0.0))
	restock_pct = float(snap.get("restock_pct", 0.0))
	checkout_pct = float(snap.get("checkout_pct", 0.0))
	wave_step = bool(snap.get("wave_step", false))
	temp_left = ShadowCloneCast.DURATION
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = Tuning.LAYER_CUSTOMERS
	collision_mask = Tuning.LAYER_WALLS
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 22)
	shape.shape = rect
	add_child(shape)
	const SkinCatalog = preload("res://scripts/session/skin_catalog.gd")
	_model_id = SkinCatalog.normalize(String(snap.get("skin_id", "player")))
	_sprite = Vox.animated(_model_id)
	_sprite.name = "Body"
	_sprite.modulate = Color(1, 1, 1, ShadowCloneCast.ALPHA)
	add_child(_sprite)
	_label = Label.new()
	_label.position = Vector2(-40, -36)
	UiFont.apply_label(_label, UiFont.WORLD)
	_label.add_theme_color_override("font_color", Color("d6ecff"))
	_label.add_theme_color_override("font_outline_color", Color("121212"))
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)
	_sync_label()


func is_shadow_clone_unit() -> bool:
	return true


func begin_job(job: String, reg: Node2D = null) -> void:
	role = "cashier" if job == "cashier" and reg != null else "restock"
	register = reg if role == "cashier" else null
	_sync_label()


func _sync_label() -> void:
	if _label == null:
		return
	if role == "cashier":
		_label.text = "分身收銀"
	elif role == "restock":
		_label.text = "分身補貨"
	else:
		_label.text = "分身"


func enter_dirt(area: Node) -> void:
	if area != null and not _dirt_areas.has(area):
		_dirt_areas.append(area)
	dirt_contacts = _dirt_areas.size()


func exit_dirt(area: Node) -> void:
	_dirt_areas.erase(area)
	var i := 0
	while i < _dirt_areas.size():
		if _dirt_areas[i] == null or not is_instance_valid(_dirt_areas[i]):
			_dirt_areas.remove_at(i)
			continue
		i += 1
	dirt_contacts = _dirt_areas.size()


func on_dirt() -> bool:
	return dirt_contacts > 0


func _physics_process(delta: float) -> void:
	if _vanishing:
		return
	if _game == null:
		return
	var phase := String(_game.get("phase"))
	if phase == "closed" or phase == "prep":
		vanish()
		return
	temp_left -= delta
	if temp_left <= 0.0:
		vanish()
		return
	if _game.has_method("asking_early_close") and bool(_game.call("asking_early_close")):
		velocity = Vector2.ZERO
		_sync_visual("idle", _facing)
		return
	if _dash_stun_left > 0.0:
		_dash_stun_left = maxf(0.0, _dash_stun_left - delta)
		velocity = Vector2.ZERO
		_sync_visual("down", _facing)
		return
	if role == "cashier":
		_tick_cashier(delta)
	elif role == "restock":
		_tick_restock(delta)
	if velocity.length() <= 8.0:
		var face := Vector2.UP if role == "cashier" else _facing
		if role == "cashier" and _timer > 0.0:
			_sync_visual("checkout", face)
		elif role == "restock" and _box_n > 0:
			_sync_visual("restock", face)
		else:
			_sync_visual("idle", face)


func _tick_cashier(delta: float) -> void:
	if register == null or not is_instance_valid(register):
		return
	if not _follow(register.call("back_position"), delta):
		return
	if _game != null and _game.has_method("seat_locks_register") and bool(_game.call("seat_locks_register", register)):
		return
	var cust = register.call("ready_customer")
	if cust == null:
		_timer = 0.0
		return
	_timer += delta
	if _timer < _checkout_need():
		return
	_timer = 0.0
	var amount: int = int(cust.call("payout_total")) if cust.has_method("payout_total") else int(cust.call("cart_total"))
	var from_elite := bool(cust.get("is_elite"))
	SfxBus.play("sfx_checkout_clerk")
	_game.call("_on_paid", amount, from_elite, 0, self)
	cust.finish_paid()
	register.dequeue(cust)


func _tick_restock(delta: float) -> void:
	if _box_n > 0:
		if _shelf == null or not is_instance_valid(_shelf):
			_drop_box()
			return
		var stand: Vector2 = _game.call("shelf_stand", _shelf)
		if not _follow(stand, delta):
			return
		_timer += delta
		if _timer < _restock_need():
			return
		var placed := int(_shelf.call("add_items", _box_sku, _box_n))
		if placed > 0:
			SfxBus.play("sfx_clerk_stock")
		_box_n -= placed
		_timer = 0.0
		if _box_n <= 0:
			_box_sku = ""
			_plan_sku = ""
			_shelf = null
		elif placed == 0:
			_drop_box()
		return
	if _plan_sku == "" or _shelf == null or not is_instance_valid(_shelf):
		_job_search_cd -= delta
		if _job_search_cd > 0.0:
			return
		_job_search_cd = Tuning.CLERK_JOB_SEARCH_SEC
		var job := _find_job()
		if job.is_empty():
			return
		_shelf = job["shelf"]
		_plan_sku = String(job["sku"])
	var cat := String(_shelf.get("category"))
	var point: Node2D = _game.call("restock_for", cat)
	if point == null:
		_clear_plan()
		return
	if not _follow(point.global_position + Vector2(70, 0), delta):
		return
	var cap := int(_shelf.get("capacity"))
	if cap <= 0:
		cap = Tuning.SHELF_CAP
	var free := maxi(0, cap - int(_shelf.get("count")))
	var avail := int(_game.state.stock.get(_plan_sku, 0))
	var n := mini(free, avail)
	if n <= 0 or not bool(_game.state.consume_stock(_plan_sku, n)):
		_clear_plan()
		return
	_game.call("sync_stock")
	_box_sku = _plan_sku
	_box_n = n
	_timer = 0.0
	SfxBus.play("sfx_clerk_pull")
	_clear_path()


func _find_job() -> Dictionary:
	var present := _skus_on_shelves()
	var held := _reserved_by_others()
	var reserved_sku: Dictionary = held.get("sku", {})
	var reserved_shelf: Dictionary = held.get("shelf", {})
	var best_shelf: Node2D = null
	var best_sku := ""
	var best_d := 99999.0
	var best_empty := false
	for s in _game.shelves:
		if s == null or reserved_shelf.has(s):
			continue
		var cap := int(s.get("capacity"))
		if cap <= 0:
			cap = Tuning.SHELF_CAP
		if int(s.get("count")) >= cap:
			continue
		var sku := String(s.get("sku"))
		var pick := ""
		var is_empty := sku == ""
		if is_empty:
			pick = _missing_sku(String(s.get("category")), present, reserved_sku)
		elif int(_game.state.stock.get(sku, 0)) > 0 and not reserved_sku.has(sku):
			pick = sku
		if pick == "":
			continue
		var d := global_position.distance_squared_to(s.global_position)
		var better := best_shelf == null
		if not better and is_empty != best_empty:
			better = is_empty
		elif not better and d < best_d:
			better = true
		if better:
			best_shelf = s
			best_sku = pick
			best_d = d
			best_empty = is_empty
	if best_shelf == null:
		return {}
	return {"shelf": best_shelf, "sku": best_sku}


func _missing_sku(category: String, present: Dictionary, reserved: Dictionary) -> String:
	for sku in Tuning.skus_for(category):
		if not _game.state.developed.has(sku):
			continue
		if present.has(sku) or reserved.has(sku):
			continue
		if int(_game.state.stock.get(sku, 0)) <= 0:
			continue
		return sku
	return ""


func _skus_on_shelves() -> Dictionary:
	var on := {}
	for s in _game.shelves:
		if s == null:
			continue
		var sku := String(s.get("sku"))
		if sku != "":
			on[sku] = true
	return on


func _reserved_by_others() -> Dictionary:
	if _game != null and _game.has_method("restock_holds"):
		return _game.call("restock_holds", self)
	return {"sku": {}, "shelf": {}}


func _clear_plan() -> void:
	_plan_sku = ""
	_shelf = null


func _drop_box() -> void:
	var n := _box_n
	var sku := _box_sku
	_box_n = 0
	_box_sku = ""
	_plan_sku = ""
	_shelf = null
	_timer = 0.0
	if n <= 0 or sku == "" or _game == null:
		return
	var piles: Array = [{"sku": sku, "n": n}]
	if _game.has_method("spawn_loot_inplace"):
		_game.call("spawn_loot_inplace", global_position, piles)
	elif _game.has_method("spawn_dropped_box"):
		_game.call("spawn_dropped_box", global_position, sku, n)


func dash_knock() -> void:
	_drop_box()
	_clear_path()
	_play_dash_ko_hop()
	_dash_stun_left = Tuning.DASH_GUEST_STUN_SEC


func apply_toss_hit() -> void:
	_drop_box()
	_clear_path()


func vanish() -> void:
	if _vanishing:
		return
	_vanishing = true
	_drop_box()
	var host: Node = _game
	if host == null:
		host = get_parent()
	if host != null:
		FxBurst.spawn(host, "spray", global_position)
	SfxBus.play("sfx_skill_clone_vanish")
	var p := get_parent()
	if p != null:
		p.remove_child(self)
	queue_free()


func _play_dash_ko_hop() -> void:
	var base := global_position
	if _dash_ko_tween != null:
		_dash_ko_tween.kill()
	_dash_ko_tween = create_tween()
	_dash_ko_tween.tween_property(self, "global_position", base + Vector2(0, -56), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_ko_tween.tween_property(self, "global_position", base, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_dash_ko_tween.tween_callback(func() -> void: SfxBus.play("sfx_guest_dash_land"))


func _checkout_need() -> float:
	var sec := Tuning.checkout_seconds(snap_int)
	var rate := 1.0 + checkout_pct
	return sec / maxf(rate, 0.01)


func _restock_need() -> float:
	var sec := Tuning.restock_seconds(snap_agi)
	var rate := 1.0 + restock_pct
	return sec / maxf(rate, 0.01)


func walk_speed() -> float:
	var m := Tuning.agi_mult(snap_agi) * (1.0 + move_pct)
	if on_dirt() and not wave_step:
		m *= Tuning.DIRT_MULT
	m = clampf(m, 0.0, Tuning.SPEED_MAX_MULT)
	var spd := Tuning.WALK_SPEED * Tuning.PLAYER_MOVE_MULT * m
	var cap := Tuning.WALK_SPEED * Tuning.PLAYER_MOVE_MULT * Tuning.SPEED_MAX_MULT
	return clampf(spd, Tuning.SPEED_FLOOR, cap)


func _follow(pos: Vector2, delta: float) -> bool:
	var arrive_sq := 36.0 * 36.0
	if global_position.distance_squared_to(pos) <= arrive_sq:
		velocity = Vector2.ZERO
		return true
	if _path.is_empty() or pos.distance_squared_to(_goal) > 324.0:
		var pts: PackedVector2Array = _game.call("find_path", global_position, pos)
		if pts.is_empty() and not _path.is_empty():
			pass
		else:
			_goal = pos
			_path = pts if not pts.is_empty() else PackedVector2Array([pos])
			_path_i = 0
	while _path_i < _path.size() and global_position.distance_squared_to(_path[_path_i]) <= 256.0:
		_path_i += 1
	var next := pos
	if _path_i < _path.size():
		next = _path[_path_i]
	var to := next - global_position
	if to.length_squared() < 1.0:
		return global_position.distance_squared_to(pos) <= arrive_sq
	var spd := walk_speed()
	velocity = to.normalized() * maxf(spd, 1.0)
	_facing = velocity
	var walk_anim := "walk_carry" if _box_n > 0 and Vox.has_anim("player", "walk_carry") else "walk"
	_sync_visual(walk_anim, velocity)
	move_and_slide()
	return false


func _sync_visual(anim: String, face: Vector2) -> void:
	if face.length_squared() > 0.01:
		_facing = face
	var prev_k := -1
	if _sprite is AnimatedSprite2D:
		prev_k = int((_sprite as AnimatedSprite2D).get_meta("vox_anim_facing", -1))
	var k := Vox.k_from_facing_stable(_facing, prev_k)
	var key := "%s_%d" % [anim, k]
	if key == _shown_anim:
		return
	_shown_anim = key
	if _sprite is AnimatedSprite2D:
		Vox.play_anim(_sprite as AnimatedSprite2D, _model_id, anim, _facing)
	elif _sprite is Sprite2D:
		Vox.apply(_sprite as Sprite2D, _model_id, k)


func _clear_path() -> void:
	_path = PackedVector2Array()
	_path_i = 0
