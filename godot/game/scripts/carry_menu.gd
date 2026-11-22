extends Node2D
## Carry radial: center ❌ cancel; outer slots = inventory.grouped() SKUs.
## Stick selects; latch confirm on outer aim (same pattern as skill latch).

const SkuIcons = preload("res://scripts/sku_icons.gd")
const UiFont = preload("res://scripts/ui_font.gd")

const AIM_CANCEL := -1
const OUTER_R := 130.0
const SLOT_R := 30.0
const CANCEL_R := 26.0
const DEADZONE := 0.42
const MAX_SLOTS := 8

var open: bool = false
## -1 cancel; 0..n-1 = grouped slot index.
var aim: int = AIM_CANCEL
var groups: Array = [] ## [{id, count}, ...]


func set_groups(g: Array) -> void:
	groups = []
	var n := mini(g.size(), MAX_SLOTS)
	for i in n:
		groups.append(g[i])
	if aim >= groups.size():
		aim = AIM_CANCEL
	queue_redraw()


func set_aim(slot: int) -> void:
	if slot < AIM_CANCEL:
		slot = AIM_CANCEL
	elif slot >= groups.size():
		slot = AIM_CANCEL
	aim = slot
	queue_redraw()


static func aim_from_stick(v: Vector2, count: int) -> int:
	if count <= 0 or v.length() < DEADZONE:
		return AIM_CANCEL
	## atan2(-y, x): 0=right, +pi/2=up.
	var ang := atan2(-v.y, v.x)
	var best := 0
	var best_d := 99.0
	for i in count:
		## Start at up, go clockwise.
		var center := PI * 0.5 - (TAU * float(i) / float(count))
		var d := _angle_dist(ang, center)
		if d < best_d:
			best_d = d
			best = i
	return best


static func _angle_dist(a: float, b: float) -> float:
	var d := absf(a - b)
	while d > PI:
		d = absf(d - TAU)
	return d


func _slot_pos(i: int, count: int) -> Vector2:
	if count <= 0:
		return Vector2.ZERO
	var ang := PI * 0.5 - (TAU * float(i) / float(count))
	return Vector2(cos(ang), -sin(ang)) * OUTER_R


func _process(_delta: float) -> void:
	visible = open
	if open:
		queue_redraw()


func _draw() -> void:
	if not open:
		return
	_draw_cancel()
	var n := groups.size()
	for i in n:
		_draw_slot(_slot_pos(i, n), i)


func _draw_cancel() -> void:
	var chosen := aim == AIM_CANCEL
	var bg := Color(0.35, 0.12, 0.12, 0.94) if chosen else Color(0.12, 0.08, 0.08, 0.88)
	var ring := Color("ff6b6b") if chosen else Color("a05050")
	draw_circle(Vector2.ZERO, CANCEL_R, bg)
	draw_arc(Vector2.ZERO, CANCEL_R, 0.0, TAU, 32, ring, 3.0 if chosen else 2.0, true)
	var font := UiFont.font()
	draw_string(font, Vector2(-10, 6), "✕", HORIZONTAL_ALIGNMENT_LEFT, 24, UiFont.px(22), ring)


func _draw_slot(p: Vector2, slot: int) -> void:
	var g: Dictionary = groups[slot] if slot < groups.size() else {}
	var sid := String(g.get("id", ""))
	var n := int(g.get("count", 0))
	var chosen := slot == aim
	var col := Color("8a8a8a") if sid == "" else Color("65d2b7")
	if chosen and sid != "":
		col = Color("fff4c2")
	var bg := Color(0.14, 0.18, 0.14, 0.94) if chosen else Color(0.05, 0.08, 0.06, 0.88)
	draw_circle(p, SLOT_R, bg)
	draw_arc(p, SLOT_R, 0.0, TAU, 28, col, 3.5 if chosen else 2.0, true)
	if sid != "":
		var icon := SkuIcons.texture(sid)
		if icon != null:
			draw_texture_rect(icon, Rect2(p - Vector2(14, 18), Vector2(28, 28)), false)
		var font := UiFont.font()
		draw_string(
			font,
			p + Vector2(-10, SLOT_R + 12),
			"×%d" % n,
			HORIZONTAL_ALIGNMENT_LEFT,
			40,
			UiFont.px(14),
			col
		)
