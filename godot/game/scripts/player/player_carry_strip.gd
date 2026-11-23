extends Node2D
## Under-foot carry preview (below stamina).
## Idle: focus well only. Expand (LB select / Y·I pulse): five wells, middle = focus.

const SkuIcons = preload("res://scripts/sku_icons.gd")
const UiFont = preload("res://scripts/ui_font.gd")

var host: CharacterBody2D
var _expand: bool = false
var _expand_until: float = 0.0
var _focus_boost: bool = false

const ICON := 26.0
## Below floor stamina bar (Y0=28, BAR_H=6 → strip under ~40).
const Y := 46.0
const GAP := 30.0


func setup(p_host: CharacterBody2D) -> void:
	host = p_host
	z_index = 26


func pulse() -> void:
	## Keyboard Y/I: briefly show five-slot strip.
	_expand = true
	_expand_until = Time.get_ticks_msec() / 1000.0 + 1.25
	_focus_boost = false


func set_select_expand(on: bool, boost_focus: bool = false) -> void:
	## Pad: hold LB select mode.
	_expand = on
	_focus_boost = on and boost_focus
	if on:
		_expand_until = Time.get_ticks_msec() / 1000.0 + 99999.0
	else:
		_expand_until = 0.0
		_focus_boost = false


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	## Timed pulse (keyboard Y/I); pad LB select clears via set_select_expand(false).
	if _expand and not _focus_boost and _expand_until < 90000.0 and now > _expand_until:
		_expand = false
	queue_redraw()


func _draw() -> void:
	if host == null or not is_instance_valid(host):
		return
	var inv = host.get("inventory")
	if inv == null or not inv.has_method("count") or int(inv.count()) <= 0:
		return
	var focus_i := int(inv.focus_index)
	var n: int = inv.slots.size() if inv.get("slots") != null else 0
	if n <= 0 or focus_i < 0:
		return
	var show_five := _expand
	if not show_five:
		_draw_well(0.0, focus_i, true, 1.0)
		return
	## Five wells: [−2][−1][FOCUS][+1][+2]; wrap when kind count > 5 (or always via mod).
	for k in range(-2, 3):
		var idx: int
		if n > 5:
			idx = posmod(focus_i + k, n)
		else:
			idx = focus_i + k
			if idx < 0 or idx >= n:
				## Ghost empty well outside range (≤5 kinds).
				_draw_ghost(float(k) * GAP)
				continue
		var x := float(k) * GAP
		var dist := abs(k)
		var sc := 1.0
		if dist == 0:
			sc = 1.08 if _focus_boost else 1.0
		elif dist == 1:
			sc = 0.82
		else:
			sc = 0.68
		_draw_well(x, idx, dist == 0, sc)


func _draw_ghost(x: float) -> void:
	var p := Vector2(x, Y)
	var sz := ICON * 0.68
	draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(0.07, 0.09, 0.1, 0.35))
	draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(0.42, 0.78, 0.68, 0.35), false, 1.25)


func _draw_well(x: float, slot_i: int, focus: bool, sc: float) -> void:
	var inv = host.get("inventory")
	var slot: Dictionary = inv.slots[slot_i]
	var sid := String(slot.get("id", ""))
	var cnt := int(slot.get("count", 0))
	var p := Vector2(x, Y)
	var sz := ICON * sc
	var bg := Color(0.07, 0.09, 0.1, 0.94) if focus else Color(0.07, 0.09, 0.1, 0.75)
	var ring := Color(0.95, 0.83, 0.37, 1.0) if focus else Color(0.42, 0.78, 0.68, 0.7)
	draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), bg)
	draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), ring, false, 2.0 if focus else 1.5)
	if sid != "":
		var tex := SkuIcons.texture(sid)
		if tex != null:
			draw_texture_rect(tex, Rect2(p - Vector2(sz, sz) * 0.4, Vector2(sz, sz) * 0.8), false)
	if cnt > 0:
		var font := UiFont.font()
		draw_string(
			font,
			p + Vector2(2, sz * 0.38),
			"×%d" % cnt,
			HORIZONTAL_ALIGNMENT_LEFT,
			40,
			UiFont.px(12),
			Color.WHITE,
		)
