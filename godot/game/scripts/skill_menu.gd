extends Node2D
## Skill radial around the clerk.
## aim -1 = center cancel (❌); 0–4 = loadout slots at sketch positions
## 1 up, 2 UL, 3 UR, 4 LL, 5 LR.

const UiFont = preload("res://scripts/ui_font.gd")
const SkillIcons = preload("res://scripts/skill_icons.gd")

const AIM_CANCEL := -1
const OUTER_R := 150.0
const SLOT_R := 36.0
const CANCEL_R := 28.0
## Stick length below this → cancel aim.
const DEADZONE := 0.42

var open: bool = false
## -1 cancel; 0–4 loadout index.
var aim: int = AIM_CANCEL
var dim: Array[bool] = [false, false, false, false, false]
var names: Array[String] = ["", "", "", "", ""]
var ids: Array[String] = ["", "", "", "", ""]
var cds: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]

## Screen offsets for loadout 0–4 (up, UL, UR, LL, LR).
const _POS := [
	Vector2(0, -OUTER_R),
	Vector2(-OUTER_R * 0.85, -OUTER_R * 0.55),
	Vector2(OUTER_R * 0.85, -OUTER_R * 0.55),
	Vector2(-OUTER_R * 0.85, OUTER_R * 0.55),
	Vector2(OUTER_R * 0.85, OUTER_R * 0.55),
]


func set_slots(equipped: Array, cd_map: Dictionary) -> void:
	for i in 5:
		var sk: Dictionary = equipped[i] if i < equipped.size() and equipped[i] is Dictionary else {}
		names[i] = String(sk.get("name", ""))
		ids[i] = String(sk.get("id", ""))
		dim[i] = names[i] != "" and String(sk.get("kind", "")) != "active"
		cds[i] = float(cd_map.get(String(sk.get("id", "")), 0.0))
	queue_redraw()


func set_aim(slot: int) -> void:
	if slot < AIM_CANCEL:
		slot = AIM_CANCEL
	elif slot > 4:
		slot = 4
	aim = slot
	queue_redraw()


## Map stick vector → aim (-1 cancel, 0–4 slot).
static func aim_from_stick(v: Vector2) -> int:
	if v.length() < DEADZONE:
		return AIM_CANCEL
	## atan2(-y, x): 0=right, +pi/2=up, ±pi=left, -pi/2=down.
	var ang := atan2(-v.y, v.x)
	## Sector centers (radians): up, UL, UR, LL, LR.
	var centers := [
		PI * 0.5,
		PI * 0.5 + PI * 0.4,
		PI * 0.5 - PI * 0.4,
		PI * 0.5 + PI * 0.8,
		PI * 0.5 - PI * 0.8,
	]
	var best := 0
	var best_d := 99.0
	for i in 5:
		var d := _angle_dist(ang, centers[i])
		if d < best_d:
			best_d = d
			best = i
	return best


static func _angle_dist(a: float, b: float) -> float:
	var d := absf(a - b)
	while d > PI:
		d = absf(d - TAU)
	return d


func _process(_delta: float) -> void:
	visible = open
	if open:
		queue_redraw()


func _draw() -> void:
	if not open:
		return
	_draw_cancel()
	for i in 5:
		_draw_skill_slot(_POS[i], i)


func _draw_cancel() -> void:
	var chosen := aim == AIM_CANCEL
	var bg := Color(0.35, 0.12, 0.12, 0.94) if chosen else Color(0.12, 0.08, 0.08, 0.88)
	var ring := Color("ff6b6b") if chosen else Color("a05050")
	draw_circle(Vector2.ZERO, CANCEL_R, bg)
	draw_arc(Vector2.ZERO, CANCEL_R, 0.0, TAU, 32, ring, 3.0 if chosen else 2.0, true)
	var font := UiFont.font()
	draw_string(
		font,
		Vector2(-10, 6),
		"✕",
		HORIZONTAL_ALIGNMENT_LEFT,
		24,
		UiFont.px(22),
		ring,
	)


func _draw_skill_slot(p: Vector2, slot: int) -> void:
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
	draw_circle(p, SLOT_R, bg)
	draw_arc(p, SLOT_R, 0.0, TAU, 28, col, 3.5 if chosen else 2.0, true)
	if ids[slot] != "":
		var icon := SkillIcons.texture(ids[slot])
		if icon != null:
			draw_texture_rect(icon, Rect2(p - Vector2(18, 18), Vector2(36, 36)), false)
	var font := UiFont.font()
	var label := "%d" % (slot + 1)
	draw_string(font, p + Vector2(-6, SLOT_R + 16), label, HORIZONTAL_ALIGNMENT_LEFT, 20, UiFont.px(16), col)
	if chosen and title != "":
		var shown := title
		if cd > 0.05 and not passive:
			shown = "%s  %.0f" % [title, cd]
		draw_string(
			font,
			p + Vector2(-60, -SLOT_R - 8),
			shown,
			HORIZONTAL_ALIGNMENT_LEFT,
			120,
			UiFont.px(16),
			col,
		)
