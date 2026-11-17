extends CharacterBody2D

var _checkout_customer: Node
## Hired NPC. Restock fills shelves that already have a SKU. Cashier skips direction commands.

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const BoxFaceplate = preload("res://scripts/box_faceplate.gd")

var role: String = "restock"
var register: Node2D
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
var _name_lab: Label
var _model_id: String = "clerk_restock"
var _job_search_cd: float = 0.0
var _shown_anim: String = ""
## Security patrol / chase.
var _patrol_i: int = 0
var _patrol_pts: PackedVector2Array = PackedVector2Array()
var _chase_target: Node2D = null
var _catch_cd: float = 0.0
var _fight_flash: float = 0.0
## M2.2 LAN presentation puppet.
var net_agent_id: int = -1
var net_puppet: bool = false
var _puppet_facing: Vector2 = Vector2.DOWN


func is_net_puppet() -> bool:
	return net_puppet


func apply_net_pose(pos: Vector2, facing: Vector2) -> void:
	var moved := global_position.distance_squared_to(pos) > 2.25
	global_position = pos
	if facing.length_squared() > 0.01:
		_puppet_facing = facing.normalized()
	velocity = Vector2.ZERO
	var anim := "walk" if moved else "idle"
	_sync_visual(anim, _puppet_facing)


func setup(game: Node, at: Vector2, job: String, reg: Node2D) -> void:
	_game = game
	role = job
	register = reg
	global_position = at
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = Tuning.LAYER_WALLS
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 22)
	shape.shape = rect
	add_child(shape)
	match role:
		"cashier":
			_model_id = "clerk_cashier"
		"security":
			_model_id = "clerk_security"
		_:
			_model_id = "clerk_restock"
	_sprite = Vox.animated(_model_id)
	_sprite.name = "Body"
	add_child(_sprite)
	_name_lab = Label.new()
	_name_lab.text = _role_label()
	_name_lab.position = Vector2(-40, -36)
	UiFont.apply_label(_name_lab, UiFont.WORLD)
	_name_lab.add_theme_color_override("font_color", Color("d6ecff"))
	_name_lab.add_theme_color_override("font_outline_color", Color("121212"))
	_name_lab.add_theme_constant_override("outline_size", 5)
	_name_lab.visible = PlatformServices.is_show_dev_hud()
	add_child(_name_lab)


func _role_label() -> String:
	match role:
		"cashier":
			return Loc.t("world.clerk.cashier")
		"security":
			return Loc.t("world.clerk.security")
		_:
			return Loc.t("world.clerk.restock")


func refresh_dev_labels() -> void:
	if _name_lab == null:
		return
	_name_lab.visible = PlatformServices.is_show_dev_hud()
	if _name_lab.visible:
		_name_lab.text = _role_label()


func _physics_process(delta: float) -> void:
	if net_puppet:
		## Presentation only — Host owns clerk AI (§8 / M2.2).
		return
	if _game == null or String(_game.get("phase")) == "closed" or String(_game.get("phase")) == "prep":
		_sync_visual("idle", Vector2.DOWN)
		return
	if bool(_game.asking_early_close()):
		velocity = Vector2.ZERO
		_sync_visual("idle", Vector2.DOWN)
		return
	match role:
		"cashier":
			_tick_cashier(delta)
		"security":
			_tick_security(delta)
		_:
			_tick_restock(delta)
	if velocity.length() <= 8.0:
		var face := Vector2.UP if role == "cashier" else Vector2.DOWN
		if role == "cashier" and _timer > 0.0:
			_sync_visual("checkout", face)
		elif role == "restock" and _box_n > 0:
			_sync_visual("restock", face)
		elif role == "security" and _fight_flash > 0.0:
			_sync_visual("fight", face)
		else:
			_sync_visual("idle", face)


func _tick_security(delta: float) -> void:
	_catch_cd = maxf(0.0, _catch_cd - delta)
	_fight_flash = maxf(0.0, _fight_flash - delta)
	if not _chase_target_valid(_chase_target):
		_chase_target = _nearest_catchable_thief()
	if _chase_target != null:
		_tick_security_chase(delta)
		return
	_tick_security_patrol(delta)


func _tick_security_patrol(delta: float) -> void:
	_ensure_patrol_pts()
	if _patrol_pts.is_empty():
		velocity = Vector2.ZERO
		return
	_patrol_i = posmod(_patrol_i, _patrol_pts.size())
	var goal: Vector2 = _patrol_pts[_patrol_i]
	if _follow(goal, delta):
		_patrol_i = posmod(_patrol_i + 1, _patrol_pts.size())
		_clear_path()


func _tick_security_chase(delta: float) -> void:
	var target: Node2D = _chase_target
	if not _chase_target_valid(target):
		_chase_target = null
		_clear_path()
		return
	var catch_sq := Tuning.SECURITY_CATCH_PX * Tuning.SECURITY_CATCH_PX
	if global_position.distance_squared_to(target.global_position) <= catch_sq:
		_try_catch_thief(target)
		return
	_follow(target.global_position, delta, Tuning.SECURITY_CHASE_SPEED_MULT)


func _ensure_patrol_pts() -> void:
	if not _patrol_pts.is_empty():
		return
	if _game == null:
		return
	var origin: Vector2 = _game.FLOOR_ORIGIN
	var size: Vector2 = _game.FLOOR_SIZE
	var inset := 72.0
	_patrol_pts = PackedVector2Array([
		origin + Vector2(inset, inset),
		origin + Vector2(size.x - inset, inset),
		origin + Vector2(size.x - inset, size.y - inset),
		origin + Vector2(inset, size.y - inset),
	])


func _nearest_catchable_thief() -> Node2D:
	if _game == null or not _game.has_method("thieves"):
		return null
	var detect_sq := Tuning.SECURITY_DETECT_PX * Tuning.SECURITY_DETECT_PX
	var best: Node2D = null
	var best_d := detect_sq
	for t in _game.thieves():
		if not _chase_target_valid(t):
			continue
		var d := global_position.distance_squared_to(t.global_position)
		if d <= best_d:
			best = t
			best_d = d
	return best


func _chase_target_valid(t: Node2D) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if not t.has_method("is_active_thief") or not bool(t.call("is_active_thief")):
		return false
	## Skip thieves already in a player fight / locked by a seat.
	if t.has_method("in_fight") and bool(t.call("in_fight")):
		return false
	var lock = get_node_or_null("/root/InteractLock")
	if lock != null and int(lock.call("holder_of", t)) >= 0:
		return false
	return true


func _try_catch_thief(t: Node2D) -> void:
	if _catch_cd > 0.0 or not _chase_target_valid(t):
		_chase_target = null
		return
	var dir := t.global_position - global_position
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	t.call("dash_knock_away", dir)
	_game.record_caught(-1, "guard", self)
	SfxBus.play("sfx_thief_dash_out")
	_catch_cd = Tuning.SECURITY_CATCH_COOLDOWN_SEC
	_fight_flash = 0.35
	_chase_target = null
	_clear_path()
	_sync_visual("fight", dir)


func _tick_cashier(delta: float) -> void:
	if register == null or not is_instance_valid(register):
		return
	if not _follow(register.call("back_position"), delta):
		return
	if _game != null and bool(_game.seat_locks_register(register)):
		return
	var cust = register.call("ready_customer")
	if cust == null:
		_timer = 0.0
		return
	if _checkout_customer != cust:
		_timer = 0.0
		_checkout_customer = cust
	register.operator_checkout()
	_timer += delta
	if _timer < Tuning.checkout_seconds(10):
		return
	_timer = 0.0
	var amount: int = int(cust.call("payout_total")) if cust.has_method("payout_total") else int(cust.call("cart_total"))
	var from_elite: bool = cust.get("is_elite") == true
	SfxBus.play("sfx_checkout_cash_pop2")
	_game._on_paid(amount, from_elite, 0, self)
	cust.finish_paid()
	register.dequeue(cust)


func _tick_restock(delta: float) -> void:
	if _box_n > 0:
		if _shelf == null or not is_instance_valid(_shelf):
			_drop_box()
			return
		var stand: Vector2 = _game.shelf_stand(_shelf)
		if not _follow(stand, delta):
			return
		_timer += delta
		if _timer < Tuning.restock_seconds(10):
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
			_refresh_held_carton()
		elif placed == 0:
			_drop_box()
		else:
			_refresh_held_carton()
		return
	## Idle: throttle job search. Active plan: keep walking every frame (do not
	## sit on _job_search_cd or the clerk freezes between search ticks).
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
	var point: Node2D = _game.restock_for(cat)
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
	_game.sync_stock()
	_box_sku = _plan_sku
	_box_n = n
	_timer = 0.0
	_refresh_held_carton()
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
		if _game.state.has_method("is_for_sale") and not _game.state.is_for_sale(sku):
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
	if _game != null:
		return _game.restock_holds(self)
	var sku := {}
	var shelf := {}
	var parent := get_parent()
	if parent == null:
		return {"sku": sku, "shelf": shelf}
	for c in parent.get_children():
		if c == self:
			continue
		var role = c.get("role")
		if typeof(role) != TYPE_STRING or role != "restock":
			continue
		var planned := str(c.get("_plan_sku"))
		if planned != "":
			sku[planned] = true
		var carried := str(c.get("_box_sku"))
		if carried != "":
			sku[carried] = true
		var target = c.get("_shelf")
		if target != null:
			shelf[target] = true
	return {"sku": sku, "shelf": shelf}


func _clear_plan() -> void:
	_plan_sku = ""
	_shelf = null


func _drop_box() -> void:
	## Failed restock: return held pieces to warehouse (piece-native; no ceil).
	if _box_n > 0 and _box_sku != "":
		_game.state.stock[_box_sku] = int(_game.state.stock.get(_box_sku, 0)) + _box_n
	_box_n = 0
	_box_sku = ""
	_plan_sku = ""
	_shelf = null
	_timer = 0.0
	_refresh_held_carton()


func _refresh_held_carton() -> void:
	BoxFaceplate.sync_held_carton(self, _box_sku, _box_n)


func _follow(pos: Vector2, delta: float, speed_mult: float = 1.0) -> bool:
	var arrive_sq := 36.0 * 36.0
	if global_position.distance_squared_to(pos) <= arrive_sq:
		velocity = Vector2.ZERO
		return true
	if _path.is_empty() or pos.distance_squared_to(_goal) > 324.0:
		var pts: PackedVector2Array = _game.find_path(global_position, pos)
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
	var spd := Tuning.WALK_SPEED * Tuning.agi_mult(10) * maxf(speed_mult, 0.01)
	spd *= float(_game.customer_move_mult())
	velocity = to.normalized() * maxf(spd, 1.0)
	var walk_anim := "walk"
	if _fight_flash > 0.0 and Vox.has_anim(_model_id, "fight"):
		walk_anim = "fight"
	elif _box_n > 0 and Vox.has_anim(_model_id, "walk_carry"):
		walk_anim = "walk_carry"
	_sync_visual(walk_anim, velocity)
	move_and_slide()
	return false


func _sync_visual(anim: String, face: Vector2) -> void:
	## Gate with the same stable k play_anim uses so hysteresis cannot skip updates.
	var prev_k := -1
	if _sprite is AnimatedSprite2D:
		prev_k = int((_sprite as AnimatedSprite2D).get_meta("vox_anim_facing", -1))
	var k := Vox.k_from_facing_stable(face, prev_k)
	var key := "%s_%d" % [anim, k]
	if key == _shown_anim:
		return
	_shown_anim = key
	if _sprite is AnimatedSprite2D:
		Vox.play_anim(_sprite as AnimatedSprite2D, _model_id, anim, face)
	elif _sprite is Sprite2D:
		Vox.apply(_sprite as Sprite2D, _model_id, k)


func _clear_path() -> void:
	_path = PackedVector2Array()
	_path_i = 0
