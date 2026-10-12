extends Node2D
## Demo v0.1 full shop-operation round: keyboard move, 執貨, 上架.
## Starts in the store. No skills, no levels, no timed prep, no guests.

const Tuning = preload("res://scripts/tuning.gd")
const PlayerScript = preload("res://scripts/player.gd")
const RestockScript = preload("res://scripts/restock_point.gd")
const ShelfScript = preload("res://scripts/shelf.gd")
const DirtScript = preload("res://scripts/dirt.gd")

const FLOOR_SIZE := Vector2(960, 640)
const FLOOR_ORIGIN := Vector2(24, 56)


func _ready() -> void:
	_floor()
	_walls()
	_checkout_prop()
	var nodes: Array[Node2D] = []
	nodes.append(_restock())
	nodes.append_array(_shelves())
	_dirt(Rect2(FLOOR_ORIGIN + Vector2(520, 338), Vector2(96, 72)))
	_dirt(Rect2(FLOOR_ORIGIN + Vector2(210, 490), Vector2(120, 60)))
	var player := _player()
	add_child(player)
	player.global_position = FLOOR_ORIGIN + Vector2(168, 318)
	player.interactables = nodes
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.5
	player.add_child(cam)
	cam.make_current()
	var hud := preload("res://scenes/hud.tscn").instantiate()
	add_child(hud)
	hud.setup(player)


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
	var stripe := Polygon2D.new()
	stripe.z_index = -5
	stripe.color = Color("c9b48d")
	stripe.polygon = PackedVector2Array([
		FLOOR_ORIGIN + Vector2(0, 300),
		FLOOR_ORIGIN + Vector2(FLOOR_SIZE.x, 300),
		FLOOR_ORIGIN + Vector2(FLOOR_SIZE.x, 316),
		FLOOR_ORIGIN + Vector2(0, 316),
	])
	add_child(stripe)


func _walls() -> void:
	var t := 20.0
	var o := FLOOR_ORIGIN
	var s := FLOOR_SIZE
	_solid(Rect2(o.x - t, o.y - t, s.x + t * 2.0, t), Color("3a2a1e"))
	_solid(Rect2(o.x - t, o.y + s.y, s.x + t * 2.0, t), Color("3a2a1e"))
	_solid(Rect2(o.x - t, o.y, t, s.y), Color("3a2a1e"))
	_solid(Rect2(o.x + s.x, o.y, t, s.y), Color("3a2a1e"))


func _checkout_prop() -> void:
	var r := Rect2(FLOOR_ORIGIN + Vector2(700, 28), Vector2(220, 64))
	_solid(r, Color("5c4033"))
	_caption(r.position + Vector2(18, 18), "收銀（v0.1 不實作）")


func _restock() -> Node2D:
	var r := Rect2(FLOOR_ORIGIN + Vector2(24, 200), Vector2(100, 220))
	var node: StaticBody2D = RestockScript.new()
	_fit_body(node, r, Color("c45c26"))
	node.body = node.get_node("Body")
	var lab := _caption(r.position + Vector2(6, 78), "")
	node.label = lab
	node._refresh()
	add_child(node)
	return node


func _shelves() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var start := FLOOR_ORIGIN + Vector2(280, 110)
	for i in Tuning.SHELF_COUNT:
		var col := i % 3
		var row := int(i / 3)
		var r := Rect2(start + Vector2(col * 190.0, row * 230.0), Vector2(128, 78))
		var node: StaticBody2D = ShelfScript.new()
		node.shelf_index = i + 1
		_fit_body(node, r, Color("2f5d50"))
		node.body = node.get_node("Body")
		node.label = _caption(r.position + Vector2(12, 18), "")
		node._refresh()
		add_child(node)
		out.append(node)
	return out


func _dirt(r: Rect2) -> void:
	var area: Area2D = DirtScript.new()
	area.position = r.position + r.size * 0.5
	var poly := Polygon2D.new()
	poly.color = Color(0.34, 0.27, 0.16, 0.8)
	var hx := r.size.x * 0.5
	var hy := r.size.y * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy + 6), Vector2(hx, -hy), Vector2(hx - 8, hy), Vector2(-hx + 10, hy)
	])
	area.add_child(poly)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	col.shape = shape
	area.add_child(col)
	add_child(area)
	_caption(r.position + Vector2(22, 20), "污物")


func _player() -> CharacterBody2D:
	var p: CharacterBody2D = PlayerScript.new()
	p.name = "Clerk"
	p.collision_layer = 1
	p.collision_mask = 1
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
	var body := StaticBody2D.new()
	_fit_body(body, r, color)
	add_child(body)


func _fit_body(body: StaticBody2D, r: Rect2, color: Color) -> void:
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
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("f4f1ea"))
	add_child(l)
	return l
