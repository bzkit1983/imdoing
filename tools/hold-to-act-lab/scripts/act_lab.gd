extends Node2D
## Hold-to-Act Lab — Demo v0.1 執貨 is instant; 上架 uses a hold-J loading circle.

const Tuning = preload("res://scripts/act_tuning.gd")
const PlayerScript = preload("res://scripts/player.gd")
const StationScript = preload("res://scripts/station.gd")
const ShelfScript = preload("res://scripts/shelf.gd")

const FLOOR_SIZE := Vector2(920, 620)
const FLOOR_ORIGIN := Vector2(40, 50)

var _player: CharacterBody2D


func _ready() -> void:
	_paint_bg()
	_build_floor()
	_build_walls()
	var stations: Array[Node2D] = []
	stations.append(_build_restock())
	stations.append_array(_build_shelves())
	_player = _make_player()
	add_child(_player)
	_player.global_position = FLOOR_ORIGIN + Vector2(160, 310)
	_player.set("interactables", stations)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	_player.add_child(cam)
	cam.make_current()
	var hud := preload("res://scenes/hud.tscn").instantiate()
	add_child(hud)
	hud.setup(_player)


func _paint_bg() -> void:
	var bg := Polygon2D.new()
	bg.color = Color("1b2420")
	bg.polygon = PackedVector2Array([
		Vector2(-200, -200), Vector2(1600, -200), Vector2(1600, 1000), Vector2(-200, 1000)
	])
	bg.z_index = -8
	add_child(bg)


func _build_floor() -> void:
	var floor_poly := Polygon2D.new()
	floor_poly.color = Color("dcc9a3")
	floor_poly.z_index = -4
	floor_poly.polygon = PackedVector2Array([
		FLOOR_ORIGIN,
		FLOOR_ORIGIN + Vector2(FLOOR_SIZE.x, 0),
		FLOOR_ORIGIN + FLOOR_SIZE,
		FLOOR_ORIGIN + Vector2(0, FLOOR_SIZE.y),
	])
	add_child(floor_poly)
	var title := Label.new()
	title.text = "Demo v0.1  ·  Hold-to-Act Lab  ·  執貨即時 / 上架長按"
	title.position = Vector2(48, 12)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f4f1ea"))
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(title)


func _build_walls() -> void:
	var t := 18.0
	var o := FLOOR_ORIGIN
	var s := FLOOR_SIZE
	_obstacle(Rect2(o.x - t, o.y - t, s.x + t * 2, t), Color("3d2b1f"))
	_obstacle(Rect2(o.x - t, o.y + s.y, s.x + t * 2, t), Color("3d2b1f"))
	_obstacle(Rect2(o.x - t, o.y, t, s.y), Color("3d2b1f"))
	_obstacle(Rect2(o.x + s.x, o.y, t, s.y), Color("3d2b1f"))


func _build_restock() -> Node2D:
	var r := Rect2(FLOOR_ORIGIN + Vector2(28, 210), Vector2(88, 200))
	var node: StaticBody2D = StationScript.new()
	_setup_box(node, r, Color("c45c26"))
	var lab := _caption(r.position + Vector2(4, 70), "")
	node.set("label", lab)
	add_child(node)
	return node


func _build_shelves() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var start := FLOOR_ORIGIN + Vector2(280, 120)
	for i in 6:
		var col := i % 3
		var row := int(i / 3)
		var r := Rect2(start + Vector2(col * 180.0, row * 220.0), Vector2(120, 72))
		var node: StaticBody2D = ShelfScript.new()
		node.set("shelf_index", i + 1)
		_setup_box(node, r, Color("2f5d50"))
		var lab := _caption(r.position + Vector2(10, 16), "")
		node.set("label", lab)
		node.call("_refresh")
		add_child(node)
		out.append(node)
	return out


func _make_player() -> CharacterBody2D:
	var p: CharacterBody2D = PlayerScript.new()
	p.name = "Clerk"
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
	arrow.polygon = PackedVector2Array([
		Vector2(-6, 4), Vector2(6, 4), Vector2(0, 14)
	])
	p.add_child(arrow)
	return p


func _setup_box(body: StaticBody2D, r: Rect2, color: Color) -> void:
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


func _obstacle(r: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	_setup_box(body, r, color)
	add_child(body)


func _caption(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.z_index = 2
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("f4f1ea"))
	add_child(l)
	return l
