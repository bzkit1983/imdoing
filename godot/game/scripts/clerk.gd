extends CharacterBody2D
## Hired NPC. Restock fills shelves that already have a SKU. Cashier skips direction commands.

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

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
var _model_id: String = "clerk_restock"
var _job_search_cd: float = 0.0
var _shown_anim: String = ""


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
	_model_id = "clerk_cashier" if role == "cashier" else "clerk_restock"
	_sprite = Vox.animated(_model_id)
	_sprite.name = "Body"
	add_child(_sprite)
	var lab := Label.new()
	lab.text = "店員收銀" if role == "cashier" else "店員補貨"
	lab.position = Vector2(-40, -36)
	UiFont.apply_label(lab, UiFont.WORLD)
	lab.add_theme_color_override("font_color", Color("d6ecff"))
	lab.add_theme_color_override("font_outline_color", Color("121212"))
	lab.add_theme_constant_override("outline_size", 5)
	add_child(lab)


func _physics_process(delta: float) -> void:
	if _game == null or String(_game.get("phase")) == "closed" or String(_game.get("phase")) == "prep":
		_sync_visual("idle", Vector2.DOWN)
		return
	if _game.has_method("asking_early_close") and bool(_game.asking_early_close()):
		velocity = Vector2.ZERO
		_sync_visual("idle", Vector2.DOWN)
		return
	if role == "cashier":
		_tick_cashier(delta)
	else:
		_tick_restock(delta)
	if velocity.length() <= 8.0:
		var face := Vector2.UP if role == "cashier" else Vector2.DOWN
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
	var player = _game.get("_player")
	if player and bool(player.get("command_lock")) and player.get("target") == register:
		return
	var cust = register.call("ready_customer")
	if cust == null:
		_timer = 0.0
		return
	_timer += delta
	if _timer < Tuning.checkout_seconds(10):
		return
	_timer = 0.0
	var amount: int = int(cust.call("cart_total"))
	SfxBus.play("sfx_checkout_clerk")
	_game.call("_on_paid", amount)
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
		elif placed == 0:
			_drop_box()
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
	var point: Node2D = _game.call("restock_for", cat)
	if point == null:
		_clear_plan()
		return
	if not _follow(point.global_position + Vector2(70, 0), delta):
		return
	if not bool(_game.state.consume_box(_plan_sku)):
		_clear_plan()
		return
	_game.call("sync_stock")
	_box_sku = _plan_sku
	_box_n = Tuning.BOX_SIZE
	_timer = 0.0
	SfxBus.play("sfx_clerk_pull")
	_clear_path()


func _find_job() -> Dictionary:
	var present := _skus_on_shelves()
	var held := _reserved_by_others()
	var reserved_sku: Dictionary = held["sku"]
	var reserved_shelf: Dictionary = held["shelf"]
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
		if int(s.get("count")) + Tuning.BOX_SIZE > cap:
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
	if _box_n > 0 and _box_sku != "":
		_game.state.stock[_box_sku] = int(_game.state.stock.get(_box_sku, 0))
		# Partial items are not a full box; leave them out of stock rather than invent a box.
	_box_n = 0
	_box_sku = ""
	_plan_sku = ""
	_shelf = null
	_timer = 0.0


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
	var spd := Tuning.WALK_SPEED * Tuning.agi_mult(10)
	spd *= float(_game.customer_move_mult()) if _game.has_method("customer_move_mult") else float(_game.call("customer_move_mult"))
	velocity = to.normalized() * maxf(spd, 1.0)
	var walk_anim := "walk_carry" if _box_n > 0 and Vox.has_anim(_model_id, "walk_carry") else "walk"
	_sync_visual(walk_anim, velocity)
	move_and_slide()
	return false


func _sync_visual(anim: String, face: Vector2) -> void:
	var key := "%s_%d" % [anim, Vox.k_from_facing(face)]
	if key == _shown_anim:
		return
	_shown_anim = key
	if _sprite is AnimatedSprite2D:
		Vox.play_anim(_sprite as AnimatedSprite2D, _model_id, anim, face)
	elif _sprite is Sprite2D:
		Vox.apply(_sprite as Sprite2D, _model_id, Vox.k_from_facing(face))


func _clear_path() -> void:
	_path = PackedVector2Array()
	_path_i = 0
