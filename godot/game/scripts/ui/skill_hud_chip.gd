extends HBoxContainer
## One ops-HUD skill row: [Cozy skill slot] name — imdoing-pause-ui-chrome.
## Slot: parchment plate + sand edge; gold rim; CD veil over art.

const SkillIcons = preload("res://scripts/skill_icons.gd")
const UiFont = preload("res://scripts/ui_font.gd")

const ICON := 32.0
const PAD := 5.0
const RING_W := 2.75
const RING_INK_W := 4.25
const PLATE := Color(0.969, 0.933, 0.839, 0.96) ## Warm Parchment
const PLATE_EDGE := Color(0.875, 0.827, 0.722, 1.0) ## Soft Sand
const GOLD := Color(1.0, 0.831, 0.231, 1.0) ## Sunlit Gold
const GOLD_DIM := Color(0.878, 0.675, 0.086, 0.85) ## E0AC16-ish
const RING_INK := Color(0.361, 0.286, 0.220, 0.92) ## Cocoa

var skill_id: String = ""
var kind: String = "active"
var cd_left: float = 0.0
var cd_max: float = 0.0
var buff_left: float = 0.0
var buff_max: float = 0.0

var _icon_pad: Control
var _plate: Panel
var _icon: TextureRect
var _ring: Control
var _name: Label
var _mat: ShaderMaterial
var _flash_t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	_build()


func _build() -> void:
	if _icon_pad != null:
		return
	_icon_pad = Control.new()
	_icon_pad.custom_minimum_size = Vector2(ICON + PAD * 2.0, ICON + PAD * 2.0)
	_icon_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_pad)

	_plate = Panel.new()
	_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PLATE
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(1)
	sb.border_color = PLATE_EDGE
	_plate.add_theme_stylebox_override("panel", sb)
	_icon_pad.add_child(_plate)

	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = PAD
	_icon.offset_top = PAD
	_icon.offset_right = -PAD
	_icon.offset_bottom = -PAD
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = load("res://shaders/skill_hud_icon.gdshader") as Shader
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_icon.material = _mat
	_icon_pad.add_child(_icon)

	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_icon_pad.add_child(_ring)

	_name = Label.new()
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFont.apply_label(_name, UiFont.WORLD)
	_name.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93, 1.0))
	_name.add_theme_color_override("font_outline_color", Color(0.045, 0.055, 0.06, 1.0))
	_name.add_theme_constant_override("outline_size", 4)
	add_child(_name)


func setup(sid: String, display_name: String, skill_kind: String) -> void:
	_build()
	skill_id = sid
	kind = skill_kind
	_name.text = display_name
	_icon.texture = SkillIcons.texture(sid)
	_apply_visuals()


func set_timers(p_cd_left: float, p_cd_max: float, p_buff_left: float, p_buff_max: float) -> void:
	cd_left = maxf(0.0, p_cd_left)
	cd_max = maxf(0.0, p_cd_max)
	buff_left = maxf(0.0, p_buff_left)
	buff_max = maxf(0.0, p_buff_max)
	_apply_visuals()


func _process(delta: float) -> void:
	_flash_t += delta
	if _wants_gold_ring():
		_ring.queue_redraw()


func _wants_gold_ring() -> bool:
	if kind == "passive":
		return true
	return buff_left > 0.05


func _cd_progress() -> float:
	if kind == "passive":
		return 1.0
	if cd_left <= 0.05:
		return 1.0
	var cap := maxf(maxf(cd_max, cd_left), 0.01)
	return clampf(1.0 - cd_left / cap, 0.0, 1.0)


func _buff_frac() -> float:
	if kind == "passive":
		return 1.0
	if buff_left <= 0.05:
		return 0.0
	var cap := maxf(maxf(buff_max, buff_left), 0.01)
	return clampf(buff_left / cap, 0.0, 1.0)


func _apply_visuals() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("progress", _cd_progress())
	_mat.set_shader_parameter("veil_alpha", 0.72)
	_mat.set_shader_parameter("veil_color", Color(0.04, 0.05, 0.07))
	_ring.queue_redraw()


func _draw_ring() -> void:
	if _ring == null or not _wants_gold_ring():
		return
	var frac := _buff_frac()
	if frac <= 0.001:
		return
	var pulse := 0.5 + 0.5 * sin(_flash_t * 6.5)
	var col := GOLD.lerp(GOLD_DIM, 1.0 - pulse)
	var center := _ring.size * 0.5
	## Sit on the plate rim so gold reads against charcoal, not icon fill.
	var radius := minf(center.x, center.y) - 1.25
	if radius <= 1.0:
		return
	var start := deg_to_rad(-90.0)
	var sweep := -TAU * frac
	## Ink understroke first, then gold — keeps the arc readable on any art color.
	_ring.draw_arc(center, radius, start, start + sweep, 52, RING_INK, RING_INK_W, true)
	_ring.draw_arc(center, radius, start, start + sweep, 52, col, RING_W, true)
