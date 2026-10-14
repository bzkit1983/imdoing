extends CanvasLayer
## Circular virtual stick (left) + Xbox-style ABXY diamond (right).

signal stick_changed(axis: Vector2)
signal hold_changed(action: String, pressed: bool)

const FACE := 64.0
const FACE_GAP := 74.0
const STICK := 148.0
const KNOB := 56.0

var _stick_touch := -1
var _knob: Panel
var _base: Control


func _ready() -> void:
	layer = 20
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_base = Control.new()
	_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_base.offset_left = 24
	_base.offset_top = -24 - STICK
	_base.offset_right = 24 + STICK
	_base.offset_bottom = -24
	_base.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_base)
	_base.add_child(_circle_panel(Vector2.ZERO, Vector2(STICK, STICK), Color(0.12, 0.16, 0.14, 0.5), Color(0.96, 0.95, 0.92, 0.28)))
	_knob = _circle_panel(
		Vector2((STICK - KNOB) * 0.5, (STICK - KNOB) * 0.5),
		Vector2(KNOB, KNOB),
		Color(0.96, 0.95, 0.92, 0.88),
		Color(1, 1, 1, 0.4)
	)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.add_child(_knob)
	_base.gui_input.connect(_on_stick_input)

	var diamond := Control.new()
	diamond.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var dsize := FACE + FACE_GAP * 2.0
	diamond.offset_left = -28 - dsize
	diamond.offset_top = -28 - dsize - 52
	diamond.offset_right = -28
	diamond.offset_bottom = -28
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(diamond)

	var mid := (dsize - FACE) * 0.5
	_face_btn(diamond, Vector2(mid, mid + FACE_GAP), "interact", "A\n行動", Color("2a9d8f"))
	_face_btn(diamond, Vector2(mid + FACE_GAP, mid), "cancel", "B\n取消", Color("c45c26"))
	_face_btn(diamond, Vector2(mid - FACE_GAP, mid), "dash", "X\n衝刺", Color("3d7ea6"))
	_face_btn(diamond, Vector2(mid, mid - FACE_GAP), "skill", "Y\n技能", Color("e8c36a"))

	var rb := Control.new()
	rb.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	rb.offset_left = -28 - 56
	rb.offset_top = -28 - dsize - 52 - 64
	rb.offset_right = -28
	rb.offset_bottom = -28 - dsize - 52 - 8
	rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rb)
	_face_btn(rb, Vector2.ZERO, "ult", "RB\n奧義", Color("c0392b"), Vector2(56, 56))


func _circle_panel(pos: Vector2, size: Vector2, fill: Color, border: Color) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	var r := int(mini(size.x, size.y) * 0.5)
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.corner_radius_bottom_left = r
	style.corner_radius_bottom_right = r
	style.set_border_width_all(2)
	style.border_color = border
	p.add_theme_stylebox_override("panel", style)
	return p


func _face_btn(parent: Control, pos: Vector2, action: String, caption: String, tint: Color, size := Vector2(FACE, FACE)) -> void:
	var b := Button.new()
	b.position = pos
	b.size = size
	b.text = caption
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color("f4f1ea"))
	b.add_theme_color_override("font_pressed_color", Color("121212"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	var idle := _btn_style(tint, 0.82, size)
	var down := _btn_style(tint.lightened(0.2), 1.0, size)
	b.add_theme_stylebox_override("normal", idle)
	b.add_theme_stylebox_override("hover", _btn_style(tint.lightened(0.12), 0.92, size))
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", idle)
	b.button_down.connect(_emit_hold.bind(action, true))
	b.button_up.connect(_emit_hold.bind(action, false))
	parent.add_child(b)


func _btn_style(fill: Color, alpha: float, size: Vector2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(fill.r, fill.g, fill.b, alpha)
	var r := int(mini(size.x, size.y) * 0.5)
	s.corner_radius_top_left = r
	s.corner_radius_top_right = r
	s.corner_radius_bottom_left = r
	s.corner_radius_bottom_right = r
	s.set_border_width_all(2)
	s.border_color = Color(1, 1, 1, 0.35)
	s.set_content_margin_all(4)
	return s


func _emit_hold(action: String, pressed: bool) -> void:
	hold_changed.emit(action, pressed)


func _on_stick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_stick_touch = t.index
			_apply_stick(_base.get_local_mouse_position())
		elif t.index == _stick_touch:
			_stick_touch = -1
			_reset_stick()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_touch:
			_apply_stick(_base.get_local_mouse_position())
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_stick_touch = 0
			_apply_stick(mb.position)
		else:
			_stick_touch = -1
			_reset_stick()
	elif event is InputEventMouseMotion and _stick_touch == 0:
		_apply_stick((event as InputEventMouseMotion).position)


func _apply_stick(local: Vector2) -> void:
	var center := _base.size * 0.5
	var v := local - center
	var max_r := mini(_base.size.x, _base.size.y) * 0.42
	if v.length() > max_r:
		v = v.normalized() * max_r
	_knob.position = center + v - _knob.size * 0.5
	var axis := v / max_r
	if axis.length() < 0.12:
		axis = Vector2.ZERO
	stick_changed.emit(axis)


func _reset_stick() -> void:
	_knob.position = _base.size * 0.5 - _knob.size * 0.5
	stick_changed.emit(Vector2.ZERO)
