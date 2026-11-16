extends Node2D
## Five slots around the clerk. Center is skill 1; up/right/down/left are 2–5.
## `aim` is the slot that will fire (0 = center).

const UiFont = preload("res://scripts/ui_font.gd")
const SkillIcons = preload("res://scripts/skill_icons.gd")

var open: bool = false
var aim: int = 0
var dim: Array[bool] = [false, false, false, false, false]
var names: Array[String] = ["", "", "", "", ""]
var ids: Array[String] = ["", "", "", "", ""]
var cds: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]

const _POS := [
	Vector2(0, 8),
	Vector2(0, -164),
	Vector2(280, 8),
	Vector2(0, 164),
	Vector2(-280, 8),
]
const _BOX := Vector2(260, 80)


func set_slots(equipped: Array[Dictionary], cd_map: Dictionary) -> void:
	for i in 5:
		var sk: Dictionary = equipped[i] if i < equipped.size() else {}
		names[i] = String(sk.get("name", ""))
		ids[i] = String(sk.get("id", ""))
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


func _dir_label(slot: int) -> String:
	match slot:
		0:
			return Loc.t("touch.center")
		1:
			return Loc.t("dir.up")
		2:
			return Loc.t("dir.right")
		3:
			return Loc.t("dir.down")
		4:
			return Loc.t("dir.left")
	return ""


func _draw_slot(p: Vector2, slot: int) -> void:
	var passive := dim[slot]
	var cd := cds[slot]
	var title := names[slot] if names[slot] != "" else Loc.t("world.guest_slot.empty")
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
	var text_x := 10.0
	if ids[slot] != "":
		var icon := SkillIcons.texture(ids[slot])
		if icon != null:
			draw_texture_rect(icon, Rect2(r.position + Vector2(8, 22), Vector2(40, 40)), false)
			text_x = 54.0
	var font := UiFont.font()
	var name := title
	if cd > 0.05 and not passive and names[slot] != "":
		name = "%s  %.0f" % [title, cd]
	draw_string(font, r.position + Vector2(text_x, 28), _dir_label(slot), HORIZONTAL_ALIGNMENT_LEFT, 70, UiFont.px(20), col)
	draw_string(font, r.position + Vector2(text_x, 56), name, HORIZONTAL_ALIGNMENT_LEFT, _BOX.x - text_x - 10, UiFont.px(22), col)
	if passive:
		draw_string(font, r.position + Vector2(text_x + 72, 28), Loc.t("prep.kind.passive"), HORIZONTAL_ALIGNMENT_LEFT, 90, UiFont.px(20), Color("8a8a8a"))
