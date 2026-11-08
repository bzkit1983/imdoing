extends CanvasLayer
## Left virtual stick + LoL-mobile-style right cluster (large interact + satellites).
## Sized from viewport so left/right chrome stay ≤ ~28% width and leave center clear.
##
## Layout tweak (no drag editor yet): edit the LAYOUT_* constants below.
## Offsets are in units of `_core` (行動 diameter). Angle uses Godot Y-down
## (0 = right, -PI/2 = up, PI = left). Match: docs wireframe / PM sketch.

signal stick_changed(axis: Vector2)
signal hold_changed(action: String, pressed: bool)
## Instant cast skill slots 0–4 (= skills 1–5).
signal skill_hotkey(slot: int)

const UiFont = preload("res://scripts/ui_font.gd")

## --- Right-cluster layout (multiples of `_core`) ---
## 行動位置有兩層：
## 1) LAYOUT_INTERACT — 相對簇內其他掣（通常留 Vector2.ZERO；其他掣跟呢個中心）
## 2) LAYOUT_CLUSTER_PAD — 成簇離螢幕右下角再縮入（像素）；郁呢個＝成組含行動一齊移
const LAYOUT_INTERACT := Vector2.ZERO
const LAYOUT_CLUSTER_PAD := Vector2(20.0, 20.0) ## +x = 再入左；+y = 再上移
const LAYOUT_DASH := Vector2(-1.1, 0.0) ## 相對行動
const LAYOUT_CANCEL := Vector2(0.0, -0.88)
## Fan radius / angles for 技1→技5 (left → up → upper-right).
## Y-down: −PI ≈ left, −PI/2 = up, 0 = right.
const LAYOUT_FAN_R := 1.9
const LAYOUT_FAN_ANG: Array[float] = [
	-3.00, ## 技1 — left of 衝刺
	-2.60, ## 技2
	-2.20, ## 技3
	-1.80, ## 技4
	-1.40, ## 技5 — above／slightly right of 取消
]
## 奧義 above the 技4／技5 gap.
const LAYOUT_ULT_R := 2.5
const LAYOUT_ULT_ANG := -1.6

var _stick_touch := -1
var _knob: Panel
var _base: Control
var _stick: float = 500.0
var _core: float = 210.0
var _sat: float = 150.0
var _skill: float = 120.0
var _ult: float = 130.0
var _edge_x: float = 28.0
var _edge_y: float = 48.0
var _last_fit: float = -1.0
var _last_vp: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 20
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	var vp := get_viewport().get_visible_rect().size
	var f := UiFont.fit()
	if get_child_count() > 0 and absf(f - _last_fit) < 0.03 and vp.distance_to(_last_vp) < 2.0:
		return
	_last_fit = f
	_last_vp = vp
	## Drop stale stick so demo does not keep coasting after rotate/resize rebuild.
	stick_changed.emit(Vector2.ZERO)
	for c in get_children():
		c.queue_free()
	_stick_touch = -1
	_knob = null
	_base = null
	_build()


func _metrics() -> void:
	var vp := get_viewport().get_visible_rect().size
	var fit := maxf(UiFont.fit(), 0.25)
	## Right cluster is wider (skill fan); keep ≤ ~32% width.
	var max_side := vp.x * 0.32
	_stick = clampf(200.0 / fit, 320.0, mini(520.0, max_side))
	_core = clampf(88.0 / fit, 132.0, mini(200.0, max_side * 0.34))
	_sat = _core * 0.66
	_skill = _core * 0.50
	_ult = _core * 0.56
	_edge_x = clampf(20.0 / fit, 18.0, 40.0)
	_edge_y = clampf(28.0 / fit, 24.0, 48.0)


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
	var knob_s := _stick * 0.44
	_knob = _circle_panel(
		Vector2((_stick - knob_s) * 0.5, (_stick - knob_s) * 0.5),
		Vector2(knob_s, knob_s),
		Color(0.96, 0.95, 0.92, 0.88),
		Color(1, 1, 1, 0.4)
	)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.add_child(_knob)

	_build_right_cluster(root)


## Matches the PM wireframe: 行動 bottom-right, 衝刺 left, 取消 above,
## 技1–5 polar fan, 奧義 on top. Tweak LAYOUT_* constants to nudge.
func _build_right_cluster(root: Control) -> void:
	var core_c := LAYOUT_INTERACT * _core
	var items: Array = [
		{"c": core_c, "s": Vector2(_core, _core), "kind": "face", "action": "interact", "cap": "行動", "tint": Color("2a9d8f")},
		{"c": core_c + LAYOUT_DASH * _core, "s": Vector2(_sat, _sat), "kind": "face", "action": "dash", "cap": "衝刺", "tint": Color("3d7ea6")},
		{"c": core_c + LAYOUT_CANCEL * _core, "s": Vector2(_sat, _sat), "kind": "face", "action": "cancel", "cap": "取消", "tint": Color("c45c26")},
		{
			"c": core_c + Vector2(cos(LAYOUT_ULT_ANG), sin(LAYOUT_ULT_ANG)) * (LAYOUT_ULT_R * _core),
			"s": Vector2(_ult, _ult),
			"kind": "face",
			"action": "ult",
			"cap": "奧義",
			"tint": Color("c0392b"),
		},
	]
	var caps: Array[String] = ["技1", "技2", "技3", "技4", "技5"]
	for i in LAYOUT_FAN_ANG.size():
		var ang: float = LAYOUT_FAN_ANG[i]
		items.append({
			"c": core_c + Vector2(cos(ang), sin(ang)) * (LAYOUT_FAN_R * _core),
			"s": Vector2(_skill, _skill),
			"kind": "skill",
			"slot": i,
			"cap": caps[i],
			"tint": Color("6b5b95"),
		})

	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for it in items:
		var c: Vector2 = it["c"]
		var s: Vector2 = it["s"]
		var tl := c - s * 0.5
		var br := c + s * 0.5
		min_x = mini(min_x, tl.x)
		min_y = mini(min_y, tl.y)
		max_x = maxf(max_x, br.x)
		max_y = maxf(max_y, br.y)

	var pad := 6.0
	var span_w := (max_x - min_x) + pad * 2.0
	var span_h := (max_y - min_y) + pad * 2.0
	## Core center inside the cluster local rect.
	var origin := Vector2(-min_x + pad, -min_y + pad)

	var inset := Vector2(_edge_x, _edge_y) + LAYOUT_CLUSTER_PAD
	var cluster := Control.new()
	cluster.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cluster.offset_left = -inset.x - span_w
	cluster.offset_top = -inset.y - span_h
	cluster.offset_right = -inset.x
	cluster.offset_bottom = -inset.y
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cluster)

	for it in items:
		var c: Vector2 = it["c"]
		var s: Vector2 = it["s"]
		var tl := origin + c - s * 0.5
		if it["kind"] == "face":
			_face_btn(cluster, tl, String(it["action"]), String(it["cap"]), it["tint"], s)
		else:
			_skill_btn(cluster, tl, int(it["slot"]), String(it["cap"]), it["tint"])


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


func _face_btn(parent: Control, pos: Vector2, action: String, caption: String, tint: Color, size: Vector2) -> void:
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


func _skill_btn(parent: Control, pos: Vector2, slot: int, caption: String, tint: Color) -> void:
	var size := Vector2(_skill, _skill)
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
	b.add_theme_stylebox_override("normal", idle)
	b.add_theme_stylebox_override("hover", _btn_style(tint.lightened(0.12), 0.92, size))
	b.add_theme_stylebox_override("pressed", _btn_style(tint.lightened(0.2), 1.0, size))
	b.add_theme_stylebox_override("focus", idle)
	b.pressed.connect(func() -> void: skill_hotkey.emit(slot))
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
	s.set_content_margin_all(6)
	return s


func _emit_hold(action: String, pressed: bool) -> void:
	hold_changed.emit(action, pressed)


func _to_stick_local(vp: Vector2) -> Vector2:
	return _base.get_global_transform_with_canvas().affine_inverse() * vp


func _input(event: InputEvent) -> void:
	if not visible or _base == null:
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
