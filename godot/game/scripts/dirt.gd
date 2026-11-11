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
## Seat currently driving the clean UI (-1 = free). Blocks other seats from wiping it.
var clean_seat: int = -1
## M2.2 LAN presentation puppet (Host owns clean authority).
var net_agent_id: int = -1
var net_puppet: bool = false


func is_net_puppet() -> bool:
	return net_puppet


func apply_net_pose(pos: Vector2, _facing: Vector2 = Vector2.ZERO) -> void:
	global_position = pos

var _label: Label
var _stick_draw: Node2D
var _spr: Sprite2D
var _clean_stage: int = -1
## Last Host clean snapshot fingerprint (M2.8 throttle).
var _net_clean_fp: String = ""


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


## `seat` owns the clean session. Other seats cannot start/clear while locked.
func set_cleaning(active: bool, axis: Vector2, meter: float, seat: int = -1) -> bool:
	if active:
		if clean_seat >= 0 and seat >= 0 and clean_seat != seat:
			return false
		if seat >= 0:
			clean_seat = seat
		cleaning = true
		stick = axis
		clean_meter = clampf(meter, 0.0, 100.0)
	else:
		if clean_seat >= 0 and seat >= 0 and clean_seat != seat:
			return false
		cleaning = false
		stick = Vector2.ZERO
		clean_meter = clampf(meter, 0.0, 100.0)
		clean_seat = -1
	_sync_clean_visual()
	if _stick_draw:
		_stick_draw.set_process(cleaning)
		_stick_draw.queue_redraw()
	_broadcast_clean_state()
	return true


## Client presentation: Host clean chrome snapshot (M2.8).
func apply_net_clean(active: bool, meter: float, axis: Vector2, seat: int = -1) -> void:
	## Absolute Host chrome — drop local lock so set_cleaning cannot reject.
	clean_seat = -1
	set_cleaning(active, axis, meter, seat)


func is_clean_locked_by_other(seat: int) -> bool:
	return cleaning and clean_seat >= 0 and clean_seat != seat


func _clean_state_fp() -> String:
	## Quantize stick／meter so tiny wiggles do not flood the wire.
	var sx := int(round(stick.x * 10.0))
	var sy := int(round(stick.y * 10.0))
	return "%d|%d|%d|%d|%d" % [
		1 if cleaning else 0,
		int(round(clean_meter)),
		sx,
		sy,
		clean_seat,
	]


func _broadcast_clean_state() -> void:
	## Host absolute clean chrome for client StickHint／fade (M2.8).
	if net_puppet or net_agent_id < 0:
		return
	if not SessionService.is_networked() or not SessionService.is_server():
		return
	var fp := _clean_state_fp()
	if fp == _net_clean_fp:
		return
	_net_clean_fp = fp
	SessionService.broadcast_agent_state({
		"id": net_agent_id,
		"cleaning": cleaning,
		"meter": clean_meter,
		"sx": stick.x,
		"sy": stick.y,
		"seat": clean_seat,
	})


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
	_stick_draw.set_process(false)
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
		## Only enabled while cleaning (see set_cleaning).
		queue_redraw()

	func _draw() -> void:
		if host == null or host.get("cleaning") != true:
			return
		## Ring + stick only (no solid disc) so the player sprite stays visible underneath.
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 36, Color("f4f1ea", 0.75), 2.2)
		var knob: Vector2 = Vector2(host.get("stick")).limit_length(1.0) * 12.0
		draw_circle(knob, 6.0, Color("f4d35e"))
		var p: float = float(host.get("clean_meter")) / 100.0
		draw_arc(Vector2.ZERO, 26.0, -PI / 2.0, -PI / 2.0 + p * TAU, 40, Color("7ec8e3"), 3.6)
