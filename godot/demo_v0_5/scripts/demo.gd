extends Node2D
## Demo v0.5: v0.4 plus thieves and mash combat.

const Tuning = preload("res://scripts/tuning.gd")
const PlayerScript = preload("res://scripts/player.gd")
const RestockScript = preload("res://scripts/restock_point.gd")
const ShelfScript = preload("res://scripts/shelf.gd")
const DirtScript = preload("res://scripts/dirt.gd")
const DroppedBoxScript = preload("res://scripts/dropped_box.gd")
const CashierScript = preload("res://scripts/cashier.gd")
const CustomerScript = preload("res://scripts/customer.gd")
const PathfinderScript = preload("res://scripts/pathfinder.gd")
const UiFont = preload("res://scripts/ui_font.gd")

const FLOOR_SIZE := Vector2(1000, 680)
const FLOOR_ORIGIN := Vector2(16, 48)

var phase: String = "restock"
var real_time: float = 0.0
var game_hours: float = Tuning.GAME_START_HOUR
var revenue: int = 0
var served: int = 0
var angry_left: int = 0
var stolen_count: int = 0
var stolen_value: int = 0
var thieves_caught: int = 0
var thieves_escaped: int = 0
var cashier: Node2D
var shelves: Array[Node2D] = []
var pathfinder
var _obstacles: Array[Rect2] = []
var _spawn_in: float = 2.0
var _player: CharacterBody2D
var _customers: Node2D
var _hud: CanvasLayer
var _dirts: Array[Node2D] = []
var _dirt_spawn_in: float = Tuning.DIRT_SPAWN_SEC
var _thief_spawn_in: float = Tuning.THIEF_SPAWN_FIRST


func _ready() -> void:
	add_to_group("game")
	_floor()
	_walls_and_door()
	var nodes: Array[Node2D] = []
	nodes.append(_restock(Rect2(FLOOR_ORIGIN + Vector2(20, 240), Vector2(92, 150)), Tuning.CAT_DRY))
	nodes.append(_restock(Rect2(FLOOR_ORIGIN + Vector2(20, 70), Vector2(92, 150)), Tuning.CAT_FROZEN))
	nodes.append_array(_make_shelves(Tuning.CAT_FROZEN, FLOOR_ORIGIN + Vector2(260, 80), 3, 1))
	nodes.append_array(_make_shelves(Tuning.CAT_DRY, FLOOR_ORIGIN + Vector2(260, 280), 3, 1))
	cashier = _make_cashier()
	nodes.append(cashier)
	pathfinder = PathfinderScript.new()
	pathfinder.setup(FLOOR_ORIGIN, FLOOR_SIZE, _obstacles)
	_customers = Node2D.new()
	_customers.name = "Customers"
	add_child(_customers)
	_player = _make_player()
	add_child(_player)
	_player.global_position = FLOOR_ORIGIN + Vector2(150, 430)
	_player.interactables = nodes
	_player.paid.connect(_on_paid)
	var cam := Camera2D.new()
	cam.zoom = Vector2(Tuning.CAMERA_ZOOM, Tuning.CAMERA_ZOOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.5
	_player.add_child(cam)
	cam.make_current()
	_player.camera = cam
	_hud = preload("res://scenes/hud.tscn").instantiate()
	add_child(_hud)
	_hud.setup(self, _player)
	var pad = preload("res://scripts/touch_pad.gd").new()
	add_child(pad)
	pad.stick_changed.connect(func(axis: Vector2) -> void: _player.stick_axis = axis)
	pad.hold_changed.connect(func(action: String, pressed: bool) -> void: _player.set_hold(action, pressed))
	for i in Tuning.DIRT_START_COUNT:
		_try_spawn_dirt()


func world_delta(delta: float) -> float:
	if _player == null:
		return delta
	return delta * float(_player.get("clock_scale"))


func customer_move_mult() -> float:
	if _player == null:
		return 1.0
	return float(_player.get("customer_move_mult"))


func _process(delta: float) -> void:
	if phase == "closed":
		return
	real_time += world_delta(delta)
	if real_time < Tuning.RESTOCK_REAL_SEC:
		phase = "restock"
		var t := real_time / Tuning.RESTOCK_REAL_SEC
		game_hours = lerpf(Tuning.GAME_START_HOUR, Tuning.OPEN_HOUR, t)
	elif real_time < Tuning.RESTOCK_REAL_SEC + Tuning.OPEN_REAL_SEC:
		phase = "open"
		var t := (real_time - Tuning.RESTOCK_REAL_SEC) / Tuning.OPEN_REAL_SEC
		game_hours = lerpf(Tuning.OPEN_HOUR, Tuning.CLOSE_HOUR, t)
		_spawn_in -= world_delta(delta)
		if _spawn_in <= 0.0:
			_spawn_customer()
			_spawn_in = randf_range(Tuning.CUSTOMER_SPAWN_MIN, Tuning.CUSTOMER_SPAWN_MAX)
		_thief_spawn_in -= world_delta(delta)
		if _thief_spawn_in <= 0.0:
			_spawn_thief()
			_thief_spawn_in = Tuning.THIEF_SPAWN_SEC
	else:
		phase = "closed"
		game_hours = Tuning.CLOSE_HOUR
		_hud.show_closeout()
		return
	_dirt_spawn_in -= world_delta(delta)
	if _dirt_spawn_in <= 0.0:
		_try_spawn_dirt()
		_dirt_spawn_in = Tuning.DIRT_SPAWN_SEC


func find_shelf(sku: String) -> Node2D:
	for s in shelves:
		if shelf_has(s, sku):
			return s
	return null


func shelf_has(shelf: Node2D, sku: String) -> bool:
	if shelf == null:
		return false
	return String(shelf.get("sku")) == sku and int(shelf.get("count")) > 0


func take_from_shelf(shelf: Node2D, sku: String) -> bool:
	if not shelf_has(shelf, sku):
		return false
	var n := int(shelf.get("count")) - 1
	shelf.set("count", n)
	if n <= 0:
		shelf.set("sku", "")
		shelf.set("count", 0)
	shelf.call("_refresh")
	return true


func shelf_stand(shelf: Node2D) -> Vector2:
	if shelf and shelf.has_method("stand_position"):
		return shelf.stand_position()
	return shelf.global_position + Vector2(0, -58)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if pathfinder == null:
		return PackedVector2Array([to])
	return pathfinder.find_path(from, to)


func exit_pos() -> Vector2:
	return door_pos() + Vector2(0, -90)


func door_pos() -> Vector2:
	return FLOOR_ORIGIN + Vector2(FLOOR_SIZE.x * 0.5, 8)


func inside_pos() -> Vector2:
	return door_pos() + Vector2(0, 70)


func guest_count() -> int:
	if _customers == null:
		return 0
	var n := 0
	for c in _customers.get_children():
		if c.has_method("occupies_store") and not bool(c.call("occupies_store")):
			continue
		n += 1
	return n


func thief_count() -> int:
	var n := 0
	for c in thieves():
		if c.has_method("is_active_thief") and bool(c.call("is_active_thief")):
			n += 1
	return n


func thieves() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if _customers == null:
		return out
	for c in _customers.get_children():
		if bool(c.get("is_thief")):
			out.append(c)
	return out


func record_stolen(items: Array) -> void:
	for sku in items:
		stolen_count += 1
		stolen_value += Tuning.sku_price(String(sku))
	thieves_escaped += 1


func record_caught() -> void:
	thieves_caught += 1


func clock_text() -> String:
	var h := int(floor(game_hours)) % 24
	var m := int(floor((game_hours - floorf(game_hours)) * 60.0))
	return "%02d:%02d" % [h, m]


func phase_text() -> String:
	match phase:
		"restock":
			return "補貨時段  06:00–08:00  無客人"
		"open":
			return "營運時段  08:00–22:00"
		_:
			return "關店結算"


func _on_paid(amount: int) -> void:
	revenue += amount
	served += 1


func _spawn_customer() -> void:
	if guest_count() >= Tuning.CUSTOMER_CAP:
		return
	var c: CharacterBody2D = CustomerScript.new()
	_customers.add_child(c)
	c.setup(self, door_pos())


func _spawn_thief() -> void:
	if thief_count() >= Tuning.THIEF_CAP:
		return
	var c: CharacterBody2D = CustomerScript.new()
	_customers.add_child(c)
	c.setup(self, door_pos(), true)
	_add_interactable(c)
	c.tree_exiting.connect(func() -> void: _remove_interactable(c))
	if _player:
		_player.log_line.emit("小偷進店！")


func _floor() -> void:
	var poly := Polygon2D.new()
	poly.z_index = -6
	poly.color = Color("d7c4a0")
	poly.polygon = PackedVector2Array([
		FLOOR_ORIGIN,
		FLOOR_ORIGIN + Vector2(FLOOR_SIZE.x, 0),
		FLOOR_ORIGIN + FLOOR_SIZE,
		FLOOR_ORIGIN + Vector2(0, FLOOR_SIZE.y),
	])
	add_child(poly)


func _walls_and_door() -> void:
	var t := 18.0
	var o := FLOOR_ORIGIN
	var s := FLOOR_SIZE
	var door_w := 90.0
	var mid := o.x + s.x * 0.5
	_solid(Rect2(o.x - t, o.y - t, mid - door_w * 0.5 - (o.x - t), t), Color("3a2a1e"))
	_solid(Rect2(mid + door_w * 0.5, o.y - t, (o.x + s.x + t) - (mid + door_w * 0.5), t), Color("3a2a1e"))
	_solid(Rect2(o.x - t, o.y + s.y, s.x + t * 2.0, t), Color("3a2a1e"))
	_solid(Rect2(o.x - t, o.y, t, s.y), Color("3a2a1e"))
	_solid(Rect2(o.x + s.x, o.y, t, s.y), Color("3a2a1e"))
	_caption(Vector2(mid - 28, o.y + 6), "大門")


func _restock(r: Rect2, cat: String) -> Node2D:
	_obstacles.append(r)
	var node: StaticBody2D = RestockScript.new()
	_fit_body(node, r, Color("c45c26") if cat == Tuning.CAT_DRY else Color("3d7ea6"), 2)
	node.body = node.get_node("Body")
	node.label = _caption(r.position + Vector2(4, 18), "")
	node.setup(cat)
	add_child(node)
	return node


func _make_shelves(cat: String, start: Vector2, count: int, start_index: int) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for i in count:
		var r := Rect2(start + Vector2(i * 168.0, 0), Vector2(140, 70))
		_obstacles.append(r)
		var node: StaticBody2D = ShelfScript.new()
		node.category = cat
		node.shelf_index = start_index + i
		_fit_body(node, r, Color("2f5d50"), 2)
		node.body = node.get_node("Body")
		var lab := Label.new()
		lab.position = Vector2(-58, -18)
		UiFont.apply_label(lab, UiFont.WORLD)
		lab.add_theme_color_override("font_color", Color("fff4c2"))
		lab.add_theme_color_override("font_outline_color", Color("121212"))
		lab.add_theme_constant_override("outline_size", 5)
		node.add_child(lab)
		node.label = lab
		add_child(node)
		node._refresh()
		shelves.append(node)
		out.append(node)
	return out


func _make_cashier() -> Node2D:
	var r := Rect2(FLOOR_ORIGIN + Vector2(760, 520), Vector2(150, 56))
	_obstacles.append(r)
	var node: StaticBody2D = CashierScript.new()
	_fit_body(node, r, Color("5c4033"), 2)
	node.label = _caption(r.position + Vector2(16, 8), "")
	add_child(node)
	_caption(r.position + Vector2(16, 62), "← 店員站後方")
	return node


func _try_spawn_dirt() -> void:
	if _dirts.size() >= Tuning.DIRT_CAP:
		return
	var size := Tuning.DIRT_SIZE
	for _i in 28:
		var origin := FLOOR_ORIGIN + Vector2(
			randf_range(36.0, FLOOR_SIZE.x - size.x - 36.0),
			randf_range(48.0, FLOOR_SIZE.y - size.y - 36.0)
		)
		var r := Rect2(origin, size)
		if _blocked_rect(r):
			continue
		_spawn_dirt(r, Tuning.random_dirt_type())
		return


func _blocked_rect(r: Rect2) -> bool:
	var grow := r.grow(18.0)
	for o in _obstacles:
		if grow.intersects(o):
			return true
	for d in _dirts:
		if not is_instance_valid(d):
			continue
		var other := Rect2(d.global_position - Tuning.DIRT_SIZE * 0.5, Tuning.DIRT_SIZE).grow(24.0)
		if grow.intersects(other):
			return true
	var door := Rect2(door_pos() + Vector2(-70, -20), Vector2(140, 110))
	return grow.intersects(door)


func _spawn_dirt(r: Rect2, dtype: String) -> void:
	var area: Area2D = DirtScript.new()
	area.setup(dtype, r.size)
	area.global_position = r.position + r.size * 0.5
	add_child(area)
	_dirts.append(area)
	_add_interactable(area)
	area.tree_exiting.connect(_on_dirt_gone.bind(area))


func _on_dirt_gone(area: Node2D) -> void:
	_dirts.erase(area)
	_remove_interactable(area)


func _add_interactable(node: Node2D) -> void:
	if _player == null:
		return
	if not _player.interactables.has(node):
		_player.interactables.append(node)


func _remove_interactable(node: Node2D) -> void:
	if _player == null:
		return
	_player.interactables.erase(node)


func spawn_dropped_box(pos: Vector2, sku: String, n: int) -> void:
	var drop: Area2D = DroppedBoxScript.new()
	drop.setup(sku, n)
	drop.global_position = pos + Vector2(randf_range(-18, 18), 22)
	add_child(drop)
	_add_interactable(drop)
	drop.tree_exiting.connect(func() -> void: _remove_interactable(drop))


func _make_player() -> CharacterBody2D:
	var p: CharacterBody2D = PlayerScript.new()
	p.name = "Clerk"
	p.collision_layer = 1
	p.collision_mask = 1 | 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 26)
	shape.shape = rect
	p.add_child(shape)
	var body := Polygon2D.new()
	body.name = "Body"
	body.color = Color("2a6b4a")
	body.polygon = PackedVector2Array([
		Vector2(-13, -13), Vector2(13, -13), Vector2(13, 13), Vector2(-13, 13)
	])
	p.add_child(body)
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.color = Color("f4f1ea")
	arrow.polygon = PackedVector2Array([Vector2(-6, 4), Vector2(6, 4), Vector2(0, 14)])
	p.add_child(arrow)
	p.bind_visuals(body, arrow)
	return p


func _solid(r: Rect2, color: Color) -> void:
	_obstacles.append(r)
	var body := StaticBody2D.new()
	_fit_body(body, r, color)
	add_child(body)


func _fit_body(body: StaticBody2D, r: Rect2, color: Color, layer: int = 1) -> void:
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var poly := Polygon2D.new()
	poly.name = "Body"
	poly.color = color
	var hx := r.size.x * 0.5
	var hy := r.size.y * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
	])
	body.add_child(poly)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	col.shape = shape
	body.add_child(col)


func _caption(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.z_index = 3
	UiFont.apply_label(l, UiFont.WORLD)
	l.add_theme_color_override("font_color", Color("fff4c2"))
	l.add_theme_color_override("font_outline_color", Color("121212"))
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	return l
