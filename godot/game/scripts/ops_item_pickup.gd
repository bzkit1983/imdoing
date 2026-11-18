extends Area2D
## Floor ops-item pickup with sparkle prompt. kind = ops_item.

const Tuning = preload("res://scripts/tuning.gd")
const OpsItems = preload("res://scripts/ops_items.gd")
const OpsItemIcons = preload("res://scripts/ops_item_icons.gd")
const UiFont = preload("res://scripts/ui_font.gd")

## Show name a bit before interact range so players can identify while walking up.
const NAME_REVEAL_RANGE := Tuning.INTERACT_RANGE * 1.35

var kind: String = "ops_item"
var item_id: String = ""
var net_agent_id: int = -1
var net_puppet: bool = false

var _spr: Sprite2D
var _glow: Sprite2D
var _name: Label
var _spark_t: float = 0.0
var _name_alpha: float = 0.0
var _game: Node = null


func is_net_puppet() -> bool:
	return net_puppet


func apply_net_pose(pos: Vector2, _facing: Vector2 = Vector2.ZERO) -> void:
	global_position = pos


func setup(id: String) -> void:
	item_id = id
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	z_index = 1
	_build()


func _build() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = OpsItems.PICKUP_SIZE
	shape.shape = rect
	add_child(shape)

	_glow = Sprite2D.new()
	_glow.texture = OpsItemIcons.glow_texture()
	_glow.z_index = -1
	_glow.modulate = Color(1.0, 0.95, 0.55, 0.55)
	add_child(_glow)

	_spr = Sprite2D.new()
	_spr.texture = OpsItemIcons.texture(item_id)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)

	_name = Label.new()
	_name.text = OpsItems.display_name(item_id)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.z_index = 4
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.apply_label(_name, UiFont.WORLD)
	_name.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
	_name.add_theme_color_override("font_outline_color", Color(0.07, 0.08, 0.09, 1.0))
	_name.add_theme_constant_override("outline_size", 5)
	_name.modulate.a = 0.0
	add_child(_name)
	_center_name_label()

	set_process(true)


func _center_name_label() -> void:
	if _name == null:
		return
	## Prefer measured size; fall back until first layout.
	var w := maxf(_name.size.x, _name.get_minimum_size().x)
	if w <= 1.0:
		w = float(_name.text.length()) * 10.0
	_name.position = Vector2(-w * 0.5, -42.0)


func _process(delta: float) -> void:
	_spark_t += delta
	var pulse := 0.55 + 0.45 * sin(_spark_t * 6.0)
	if _glow != null:
		_glow.modulate.a = 0.35 + 0.4 * pulse
		_glow.scale = Vector2.ONE * (1.15 + 0.2 * pulse)
	if _spr != null:
		_spr.position.y = -2.0 + sin(_spark_t * 3.2) * 3.0
	_tick_name_reveal(delta)


func _tick_name_reveal(delta: float) -> void:
	if _name == null:
		return
	var want := 1.0 if _player_in_reveal_range() else 0.0
	_name_alpha = move_toward(_name_alpha, want, delta * 6.0)
	_name.modulate.a = _name_alpha
	_name.visible = _name_alpha > 0.02
	if _name.visible:
		_center_name_label()


func _player_in_reveal_range() -> bool:
	var host := _game_host()
	if host == null:
		return false
	var players = host.get("_players")
	if not (players is Array):
		return false
	var lim_sq := NAME_REVEAL_RANGE * NAME_REVEAL_RANGE
	for p in players:
		if p == null or not is_instance_valid(p) or not (p is Node2D):
			continue
		if global_position.distance_squared_to((p as Node2D).global_position) <= lim_sq:
			return true
	return false


func _game_host() -> Node:
	if _game != null and is_instance_valid(_game):
		return _game
	var n: Node = get_parent()
	while n != null:
		if n.get("_players") != null:
			_game = n
			return _game
		n = n.get_parent()
	return null


func take() -> String:
	var id := item_id
	item_id = ""
	queue_free()
	return id
