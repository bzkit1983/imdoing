extends Area2D

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

var kind: String = "dirt"
var dirt_type: String = Tuning.DIRT_TRASH
var patch_size: Vector2 = Tuning.DIRT_SIZE
var clean_meter: float = 0.0
var cleaning: bool = false
var stick: Vector2 = Vector2.ZERO

var _label: Label
var _stick_draw: Node2D
var _spr: Sprite2D
var _clean_stage: int = -1


func setup(dtype: String, size: Vector2) -> void:
	dirt_type = dtype
	patch_size = size
	collision_layer = 0
	collision_mask = Tuning.LAYER_WALLS | Tuning.LAYER_CUSTOMERS
	monitoring = true
	monitorable = false
	z_index = -2
	_build()
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func type_name() -> String:
	return Tuning.dirt_type_name(dirt_type)


func diss_per_sec() -> float:
	return Tuning.dirt_dissat(dirt_type)


func set_cleaning(active: bool, axis: Vector2, meter: float) -> void:
	cleaning = active
	stick = axis
	clean_meter = clampf(meter, 0.0, 100.0)
	_sync_clean_visual()
	if _stick_draw:
		_stick_draw.queue_redraw()


func _dirt_model() -> String:
	if dirt_type == Tuning.DIRT_PUDDLE:
		return "puddle"
	if dirt_type == Tuning.DIRT_VOMIT:
		return "vomit"
	return "trash"


func _sync_clean_visual() -> void:
	if _spr == null:
		return
	var stage := 0
	if clean_meter >= 66.0:
		stage = 2
	elif clean_meter >= 33.0:
		stage = 1
	if cleaning and stage != _clean_stage:
		_clean_stage = stage
		var clean_id := "%s_clean_%d" % [_dirt_model(), stage]
		var path := "res://art/sprites/%s_0.png" % clean_id
		if ResourceLoader.exists(path):
			Vox.apply(_spr, clean_id, 0)
			Vox.fit(_spr, patch_size)
	# Fade as meter fills (Alpha stand-in for dissolving dirt).
	_spr.modulate.a = clampf(1.0 - clean_meter / 120.0, 0.35, 1.0)


func _build() -> void:
	var model := _dirt_model()
	_spr = Vox.sprite(model, 0)
	Vox.fit(_spr, patch_size)
	_spr.z_index = -2
	add_child(_spr)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = patch_size
	col.shape = shape
	add_child(col)
	_label = Label.new()
	_label.text = type_name()
	_label.position = Vector2(-32, -patch_size.y * 0.5 - 18)
	_label.z_index = 4
	UiFont.apply_label(_label, UiFont.WORLD)
	_label.add_theme_color_override("font_color", Color("fff4c2"))
	_label.add_theme_color_override("font_outline_color", Color("121212"))
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)
	_stick_draw = StickHint.new()
	## Above the dirt / character head so clean anims stay readable.
	_stick_draw.position = Vector2(0, -patch_size.y * 0.5 - 88)
	_stick_draw.z_index = 8
	add_child(_stick_draw)
	_stick_draw.host = self


func _on_enter(body: Node2D) -> void:
	if body.has_method("enter_dirt"):
		body.enter_dirt(self)


func _on_exit(body: Node2D) -> void:
	if body.has_method("exit_dirt"):
		body.exit_dirt(self)


class StickHint extends Node2D:
	var host: Area2D

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if host == null or not bool(host.get("cleaning")):
			return
		## Ring + stick only (no solid disc) so the player sprite stays visible underneath.
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 36, Color("f4f1ea", 0.75), 2.2)
		var knob: Vector2 = Vector2(host.get("stick")).limit_length(1.0) * 12.0
		draw_circle(knob, 6.0, Color("f4d35e"))
		var p: float = float(host.get("clean_meter")) / 100.0
		draw_arc(Vector2.ZERO, 26.0, -PI / 2.0, -PI / 2.0 + p * TAU, 40, Color("7ec8e3"), 3.6)
