extends Node2D
## Five slots around the clerk. Center is skill 1; up/right/down/left are 2–5.
## `aim` is the slot that will fire (0 = center).

const UiFont = preload("res://scripts/ui_font.gd")

var open: bool = false
var aim: int = 0
var dim: Array[bool] = [false, false, false, false, false]
var names: Array[String] = ["", "", "", "", ""]
var cds: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]

const _DIRS := ["中", "上", "右", "下", "左"]
const _POS := [
	Vector2(0, 8),
	Vector2(0, -156),
	Vector2(250, 8),
	Vector2(0, 156),
	Vector2(-250, 8),
]
const _BOX := Vector2(220, 76)


func set_slots(equipped: Array[Dictionary], cd_map: Dictionary) -> void:
	for i in 5:
		var sk: Dictionary = equipped[i] if i < equipped.size() else {}
		names[i] = String(sk.get("name", ""))
		dim[i] = names[i] != "" and String(sk.get("kind", "")) != "active"
		cds[i] = float(cd_map.get(String(sk.get("id", "")), 0.0))
	queue_redraw()


func set_aim(slot: int) -> void:
	aim = clampi(slot, 0, 4)
	queue_redraw()


func _process(_delta: float) -> void:
	visible = open
	if open:
		queue_redraw()


func _draw() -> void:
	if not open:
		return
	for i in 5:
		_draw_slot(_POS[i], i)


func _draw_slot(p: Vector2, slot: int) -> void:
	var passive := dim[slot]
	var cd := cds[slot]
	var title := names[slot] if names[slot] != "" else "（空）"
	var col := Color("8a8a8a") if passive or names[slot] == "" else Color("f4d35e")
	if cd > 0.05 and not passive and names[slot] != "":
		col = Color("c45c26")
	var chosen := slot == aim
	if chosen and not passive and names[slot] != "":
		col = Color("fff4c2")
	var bg := Color(0.16, 0.2, 0.14, 0.94) if chosen else Color(0.05, 0.07, 0.06, 0.88)
	var r := Rect2(p - _BOX * 0.5, _BOX)
	draw_rect(r, bg)
	draw_rect(r, col, false, 4.0 if chosen else 2.0)
	var font := UiFont.font()
	var name := title
	if cd > 0.05 and not passive and names[slot] != "":
		name = "%s  %.0f" % [title, cd]
	draw_string(font, r.position + Vector2(10, 26), _DIRS[slot], HORIZONTAL_ALIGNMENT_LEFT, 40, UiFont.px(22), col)
	draw_string(font, r.position + Vector2(10, 52), name, HORIZONTAL_ALIGNMENT_LEFT, _BOX.x - 20, UiFont.px(22), col)
	if passive:
		draw_string(font, r.position + Vector2(48, 26), "被動", HORIZONTAL_ALIGNMENT_LEFT, 80, UiFont.px(22), Color("8a8a8a"))
