extends ColorRect

signal dialogue_ready

const UiFont = preload("res://scripts/ui_font.gd")
const SPEAKERS := ["god", "player", "god", "god"]

var ready_for_dialogue := false
var _glow: TextureRect
var _copy: Label
var _fade: Tween


func _ready() -> void:
	z_index = 7
	color = Color.BLACK
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.05, 0.2, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 0.95, 1.0), Color(1.0, 0.87, 0.58, 0.85),
		Color(1.0, 0.74, 0.38, 0.22), Color.TRANSPARENT,
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_glow = TextureRect.new()
	_glow.texture = texture
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)
	_glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_glow.offset_left = -48
	_glow.offset_right = 48
	_glow.offset_top = -112
	_glow.offset_bottom = -16
	_copy = Label.new()
	_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFont.apply_label(_copy, UiFont.SIZE_HEADING_SM)
	add_child(_copy)
	_copy.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_copy.offset_left = 32
	_copy.offset_right = -32
	_copy.offset_top = -245
	_copy.offset_bottom = -40
	hide()


func start() -> void:
	show()
	ready_for_dialogue = false
	_glow.modulate.a = 0.0
	_copy.hide()
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_interval(0.25)
	_fade.tween_property(_glow, "modulate:a", 1.0, 1.1)
	_fade.tween_callback(_reveal_dialogue)


func stop() -> void:
	if _fade != null:
		_fade.kill()
	hide()


func set_line(index: int) -> void:
	_copy.text = "%s\n%s\n\n%s" % [
		Loc.t("prep.light_quiz." + SPEAKERS[index]),
		Loc.t("prep.light_quiz.line%d" % (index + 1)),
		Loc.t("prep.light_quiz.continue"),
	]


func _reveal_dialogue() -> void:
	ready_for_dialogue = true
	_copy.show()
	dialogue_ready.emit()
