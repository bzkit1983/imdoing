extends Node2D

const PlayerSceneScript = preload("res://scripts/player.gd")
## Clerk Move Lab — Demo v0.1 store footprint (1 dry restock + 6 shelves).
## Movement only: WASD, tap K dash, hold K run. No skills, no guests, stats = 10.

const FLOOR_SIZE := Vector2(920, 620)
const FLOOR_ORIGIN := Vector2(40, 50)

var _player: CharacterBody2D
var _dirt_areas: Array[Rect2] = []


func _ready() -> void:
	_build_floor()
	_build_walls()
	_build_restock()
	_build_shelves()
	_build_dirt()
	_player = _make_player()
	add_child(_player)
	_player.global_position = FLOOR_ORIGIN + Vector2(120, 310)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.ignore_rotation = true
	_player.add_child(cam)
	cam.make_current()
	var hud := preload("res://scenes/hud.tscn").instantiate()
	add_child(hud)
	hud.setup(_player)


func _process(_delta: float) -> void:
	if _player == null:
		return
	var local := _player.global_position
	var touching := false
	for r in _dirt_areas:
		if r.has_point(local):
			touching = true
			break
	_player.set("on_dirt", touching)


func _build_floor() -> void:
	var floor_poly := Polygon2D.new()
	floor_poly.color = Color("dcc9a3")
	floor_poly.polygon = PackedVector2Array([
		FLOOR_ORIGIN,
		FLOOR_ORIGIN + Vector2(FLOOR_SIZE.x, 0),
		FLOOR_ORIGIN + FLOOR_SIZE,
		FLOOR_ORIGIN + Vector2(0, FLOOR_SIZE.y),
	])
	add_child(floor_poly)
	var title := Label.new()
	title.text = "Demo v0.1  ·  店鋪經營回合移動實驗室"
	title.position = Vector2(48, 12)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f4f1ea"))
	var ui := CanvasLayer.new()
	ui.layer = 0
	add_child(ui)
	ui.add_child(title)


func _build_walls() -> void:
	var t := 18.0
	var o := FLOOR_ORIGIN
	var s := FLOOR_SIZE
	_box_body(Rect2(o.x - t, o.y - t, s.x + t * 2, t), Color("3d2b1f"))
	_box_body(Rect2(o.x - t, o.y + s.y, s.x + t * 2, t), Color("3d2b1f"))
	_box_body(Rect2(o.x - t, o.y, t, s.y), Color("3d2b1f"))
	_box_body(Rect2(o.x + s.x, o.y, t, s.y), Color("3d2b1f"))


func _build_restock() -> void:
	var r := Rect2(FLOOR_ORIGIN + Vector2(28, 210), Vector2(88, 200))
	_box_body(r, Color("c45c26"))
	_caption(r.position + Vector2(6, 84), "乾貨\n補貨點")


func _build_shelves() -> void:
	var start := FLOOR_ORIGIN + Vector2(280, 120)
	for i in 6:
		var col := i % 3
		var row := int(i / 3)
		var r := Rect2(start + Vector2(col * 180.0, row * 220.0), Vector2(120, 72))
		_box_body(r, Color("2f5d50"))
		_caption(r.position + Vector2(18, 24), "乾貨架 %d" % (i + 1))


func _build_dirt() -> void:
	var puddles := [
		Rect2(FLOOR_ORIGIN + Vector2(520, 330), Vector2(90, 70)),
		Rect2(FLOOR_ORIGIN + Vector2(200, 470), Vector2(110, 64)),
	]
	for r in puddles:
		var poly := Polygon2D.new()
		poly.color = Color(0.35, 0.28, 0.16, 0.75)
		poly.polygon = PackedVector2Array([
			r.position,
			r.position + Vector2(r.size.x, 8),
			r.position + r.size,
			r.position + Vector2(10, r.size.y),
		])
		add_child(poly)
		var label := _caption(r.position + Vector2(18, 22), "污物")
		label.add_theme_color_override("font_color", Color("ead7a5"))
		_dirt_areas.append(r.grow(-6))


func _make_player() -> CharacterBody2D:
	var p: CharacterBody2D = PlayerSceneScript.new()
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
	arrow.polygon = PackedVector2Array([
		Vector2(-6, 4), Vector2(6, 4), Vector2(0, 14)
	])
	p.add_child(arrow)
	return p


func _box_body(r: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = r.position + r.size * 0.5
	var poly := Polygon2D.new()
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
	add_child(body)


func _caption(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("f4f1ea"))
	add_child(l)
	return l
