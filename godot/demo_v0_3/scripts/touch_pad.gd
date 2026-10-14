extends CanvasLayer
## Circular virtual stick (left) + Xbox-style ABXY diamond (right).
## Game-pixel size tracks the canvas scale so thumbs stay large on iPhone.

signal stick_changed(axis: Vector2)
signal hold_changed(action: String, pressed: bool)

const UiFont = preload("res://scripts/ui_font.gd")

var _stick_touch := -1
var _knob: Panel
var _base: Control
var _stick: float = 500.0
var _face: float = 210.0
var _gap: float = 240.0
var _knob_s: float = 210.0
var _ult: float = 160.0
var _edge_x: float = 28.0
var _edge_y: float = 48.0
var _last_fit: float = -1.0


func _ready() -> void:
	layer = 20
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	var f := UiFont.fit()
	if get_child_count() > 0 and absf(f - _last_fit) < 0.03:
		return
	_last_fit = f
	for c in get_children():
		c.queue_free()
	_stick_touch = -1
	_knob = null
	_base = null
	_build()


func _metrics() -> void:
	var fit := maxf(UiFont.fit(), 0.25)
	# ~250 CSS px stick, ~110 CSS px face buttons.
	_stick = clampf(250.0 / fit, 480.0, 760.0)
	_face = clampf(110.0 / fit, 200.0, 320.0)
	_gap = _face * 0.70
	_knob_s = _stick * 0.44
	_ult = _face * 0.62
	_edge_x = 24.0
	_edge_y = 40.0


func _build() -> void:
	_metrics()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_base = Control.new()
	_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_base.offset_left = _edge_x
	_base.offset_top = -_edge_y - _stick
	_base.offset_right = _edge_x + _stick
	_base.offset_bottom = -_edge_y
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_base)
	_base.add_child(_circle_panel(Vector2.ZERO, Vector2(_stick, _stick), Color(0.12, 0.16, 0.14, 0.5), Color(0.96, 0.95, 0.92, 0.28)))
	_knob = _circle_panel(
		Vector2((_stick - _knob_s) * 0.5, (_stick - _knob_s) * 0.5),
		Vector2(_knob_s, _knob_s),
		Color(0.96, 0.95, 0.92, 0.88),
		Color(1, 1, 1, 0.4)
	)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.add_child(_knob)

	var diamond := Control.new()
	diamond.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var dsize := _face + _gap * 2.0
	diamond.offset_left = -_edge_x - dsize
	diamond.offset_top = -_edge_y - dsize
	diamond.offset_right = -_edge_x
	diamond.offset_bottom = -_edge_y
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(diamond)

	var mid := (dsize - _face) * 0.5
	_face_btn(diamond, Vector2(mid, mid + _gap), "interact", "A\n行動", Color("2a9d8f"))
	_face_btn(diamond, Vector2(mid + _gap, mid), "cancel", "B\n取消", Color("c45c26"))
	_face_btn(diamond, Vector2(mid - _gap, mid), "dash", "X\n衝刺", Color("3d7ea6"))
	_face_btn(diamond, Vector2(mid, mid - _gap), "skill", "Y\n技能", Color("e8c36a"))
	var rb := Control.new()
	rb.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	rb.offset_right = -8.0
	rb.offset_bottom = -_edge_y - dsize + _face * 0.15
	rb.offset_left = rb.offset_right - _ult
	rb.offset_top = rb.offset_bottom - _ult
	rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rb)
	_face_btn(rb, Vector2.ZERO, "ult", "RB\n奧義", Color("c0392b"), Vector2(_ult, _ult))


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
	style.set_border_width_all(3)
	style.border_color = border
	p.add_theme_stylebox_override("panel", style)
	return p


func _face_btn(parent: Control, pos: Vector2, action: String, caption: String, tint: Color, size := Vector2.ZERO) -> void:
	if size == Vector2.ZERO:
		size = Vector2(_face, _face)
	var b := Button.new()
	b.position = pos
	b.size = size
	b.text = caption
	b.focus_mode = Control.FOCUS_NONE
	UiFont.apply_button(b, UiFont.BUTTON)
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
	s.set_border_width_all(3)
	s.border_color = Color(1, 1, 1, 0.35)
	s.set_content_margin_all(8)
	return s


func _emit_hold(action: String, pressed: bool) -> void:
	hold_changed.emit(action, pressed)


func _to_stick_local(vp: Vector2) -> Vector2:
	return _base.get_global_transform_with_canvas().affine_inverse() * vp


func _input(event: InputEvent) -> void:
	if _base == null:
		return
	var idx := -2
	var pos := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := false
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		idx = t.index
		pos = t.position
		pressed = t.pressed
		released = not t.pressed
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		idx = d.index
		pos = d.position
		moved = true
		pressed = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		idx = 0
		pos = mb.position
		pressed = mb.pressed
		released = not mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			return
		idx = 0
		pos = mm.position
		moved = true
		pressed = true
	else:
		return
	var local := _to_stick_local(pos)
	var pad := Rect2(Vector2(-36, -36), _base.size + Vector2(72, 72))
	var on_left := pos.x < get_viewport().get_visible_rect().size.x * 0.48
	if released and idx == _stick_touch:
		_stick_touch = -1
		_reset_stick()
		return
	if idx == _stick_touch and (moved or pressed):
		_apply_stick(local)
		return
	if pressed and not moved and on_left and pad.has_point(local):
		_stick_touch = idx
		_apply_stick(local)


func _apply_stick(local: Vector2) -> void:
	if _base == null or _knob == null:
		return
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
	if _base == null or _knob == null:
		return
	_knob.position = _base.size * 0.5 - _knob.size * 0.5
	stick_changed.emit(Vector2.ZERO)
