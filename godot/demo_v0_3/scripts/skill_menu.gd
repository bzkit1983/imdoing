extends Node2D
## Radial labels while holding the skill key (up/right/down/left = slots 2–5).

const Skills = preload("res://scripts/skills.gd")

var open: bool = false
var dim: Array[bool] = [false, false, false, false]
var names: Array[String] = ["", "", "", ""]
var cds: Array[float] = [0.0, 0.0, 0.0, 0.0]


func set_slots(equipped: Array[Dictionary], cd_map: Dictionary) -> void:
	# Menu order: up, right, down, left = slots 2,3,4,5
	var order := [1, 2, 3, 4]
	for i in 4:
		var sk: Dictionary = equipped[order[i]]
		names[i] = String(sk.get("name", ""))
		dim[i] = String(sk.get("kind", "")) != "active"
		cds[i] = float(cd_map.get(String(sk.get("id", "")), 0.0))
	queue_redraw()


func _process(_delta: float) -> void:
	visible = open
	if open:
		queue_redraw()


func _draw() -> void:
	if not open:
		return
	_draw_slot(Vector2(0, -92), names[0], dim[0], cds[0], "上")
	_draw_slot(Vector2(88, 0), names[1], dim[1], cds[1], "右")
	_draw_slot(Vector2(0, 70), names[2], dim[2], cds[2], "下")
	_draw_slot(Vector2(-88, 0), names[3], dim[3], cds[3], "左")
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-36, -8), "技能1 輕放", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f4f1ea"))


func _draw_slot(p: Vector2, title: String, passive: bool, cd: float, dir: String) -> void:
	var col := Color("8a8a8a") if passive else Color("f4d35e")
	if cd > 0.05 and not passive:
		col = Color("c45c26")
	var bg := Color(0.05, 0.07, 0.06, 0.82)
	var r := Rect2(p + Vector2(-54, -22), Vector2(108, 40))
	draw_rect(r, bg)
	draw_rect(r, col, false, 1.6)
	var font := ThemeDB.fallback_font
	var line := "%s %s" % [dir, title]
	if cd > 0.05 and not passive:
		line = "%s %.0f" % [title, cd]
	draw_string(font, p + Vector2(-50, -4), line, HORIZONTAL_ALIGNMENT_LEFT, 100, 12, col)
	if passive:
		draw_string(font, p + Vector2(-50, 12), "被動", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color("8a8a8a"))
