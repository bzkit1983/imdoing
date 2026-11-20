extends Node2D
## Ops bag radial: center ❌ cancel; up/left/right/down = bag slots 0/3/1/2
## (ops bag order: up, right, down, left → indices 0,1,2,3).
## Sketch: 1 up, 2 left, 3 right, 4 down.

const OpsItemIcons = preload("res://scripts/ops_item_icons.gd")
const OpsItems = preload("res://scripts/ops_items.gd")
const UiFont = preload("res://scripts/ui_font.gd")

const AIM_CANCEL := -1
const OUTER_R := 110.0
const SLOT_R := 32.0
const CANCEL_R := 26.0
const DEADZONE := 0.42

var open: bool = false
## -1 cancel; 0–3 = bag slot index (up, right, down, left).
var aim: int = AIM_CANCEL
var ids: Array[String] = ["", "", "", ""]
var unlocked: int = 4

## Visual positions: up, left, right, down — map to bag indices.
const _VIS := [
	{"pos": Vector2(0, -OUTER_R), "slot": 0}, ## up
	{"pos": Vector2(-OUTER_R, 0), "slot": 3}, ## left
	{"pos": Vector2(OUTER_R, 0), "slot": 1}, ## right
	{"pos": Vector2(0, OUTER_R), "slot": 2}, ## down
]


func set_bag(bag: Array, unlocked_count: int) -> void:
	unlocked = unlocked_count
	ids = ["", "", "", ""]
	for i in 4:
		ids[i] = String(bag[i]) if i < bag.size() else ""
	queue_redraw()


func set_aim(slot: int) -> void:
	if slot < AIM_CANCEL:
		slot = AIM_CANCEL
	elif slot > 3:
		slot = 3
	aim = slot
	queue_redraw()


static func aim_from_stick(v: Vector2) -> int:
	if v.length() < DEADZONE:
		return AIM_CANCEL
	## Cardinal: up=0, right=1, down=2, left=3.
	if absf(v.x) > absf(v.y):
		return 1 if v.x > 0.0 else 3
	return 2 if v.y > 0.0 else 0


func _process(_delta: float) -> void:
	visible = open
	if open:
		queue_redraw()


func _draw() -> void:
	if not open:
		return
	_draw_cancel()
	for entry in _VIS:
		_draw_slot(entry["pos"] as Vector2, int(entry["slot"]))


func _draw_cancel() -> void:
	var chosen := aim == AIM_CANCEL
	var bg := Color(0.35, 0.12, 0.12, 0.94) if chosen else Color(0.12, 0.08, 0.08, 0.88)
	var ring := Color("ff6b6b") if chosen else Color("a05050")
	draw_circle(Vector2.ZERO, CANCEL_R, bg)
	draw_arc(Vector2.ZERO, CANCEL_R, 0.0, TAU, 32, ring, 3.0 if chosen else 2.0, true)
	var font := UiFont.font()
	draw_string(font, Vector2(-10, 6), "✕", HORIZONTAL_ALIGNMENT_LEFT, 24, UiFont.px(22), ring)


func _draw_slot(p: Vector2, slot: int) -> void:
	var locked := slot >= unlocked
	var id := ids[slot] if slot < ids.size() else ""
	var chosen := slot == aim
	var col := Color("8a8a8a") if locked or id == "" else Color("7ec8e3")
	if chosen and id != "" and not locked:
		col = Color("fff4c2")
	var bg := Color(0.14, 0.18, 0.22, 0.94) if chosen else Color(0.05, 0.07, 0.08, 0.88)
	draw_circle(p, SLOT_R, bg)
	draw_arc(p, SLOT_R, 0.0, TAU, 28, col, 3.5 if chosen else 2.0, true)
	if id != "" and not locked:
		var icon := OpsItemIcons.texture(id)
		if icon != null:
			draw_texture_rect(icon, Rect2(p - Vector2(16, 16), Vector2(32, 32)), false)
	var font := UiFont.font()
	draw_string(
		font,
		p + Vector2(-6, SLOT_R + 14),
		"%d" % (slot + 1),
		HORIZONTAL_ALIGNMENT_LEFT,
		20,
		UiFont.px(14),
		col,
	)
