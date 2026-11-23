extends Node2D
## Skill radial around the clerk.
## aim -1 = center cancel (❌); 0–4 = active-only holes:
## 1 up, 2 right, 3 down, 4 left, 5 upper-right. Passives omitted.

const UiFont = preload("res://scripts/ui_font.gd")
const SkillIcons = preload("res://scripts/skill_icons.gd")

const AIM_CANCEL := -1
## Ring diameter tightened for Ambient Peek (was 300px / OUTER_R 150).
const OUTER_R := 105.0
const SLOT_R := 30.0
const CANCEL_R := 22.0
const CD_RING_R := 34.0
## Stick length below this → cancel aim.
const DEADZONE := 0.42
const CD_COL := Color("c45c26")

var open: bool = false
## -1 cancel; 0–4 ring hole (not raw loadout index).
var aim: int = AIM_CANCEL
var dim: Array[bool] = [false, false, false, false, false]
var names: Array[String] = ["", "", "", "", ""]
var ids: Array[String] = ["", "", "", "", ""]
var cds: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var cd_maxs: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
## Ring hole → original loadout index (−1 empty).
var loadout_idx: Array[int] = [-1, -1, -1, -1, -1]
var _cd_peak: Dictionary = {} ## skill id → peak remaining this cool cycle

## Screen offsets: up, right, down, left, UR (5th hole).
const _POS := [
	Vector2(0, -OUTER_R),
	Vector2(OUTER_R, 0),
	Vector2(0, OUTER_R),
	Vector2(-OUTER_R, 0),
	Vector2(OUTER_R * 0.85, -OUTER_R * 0.55),
]


func set_slots(equipped: Array, cd_map: Dictionary) -> void:
	var live: Dictionary = {}
	var actives: Array = []
	for li in equipped.size():
		var sk0: Dictionary = equipped[li] if equipped[li] is Dictionary else {}
		if String(sk0.get("kind", "")) != "active":
			continue
		if String(sk0.get("id", "")) == "":
			continue
		actives.append({"sk": sk0, "li": li})
	for i in 5:
		names[i] = ""
		ids[i] = ""
		dim[i] = false
		cds[i] = 0.0
		cd_maxs[i] = 0.0
		loadout_idx[i] = -1
		if i >= actives.size():
			continue
		var sk: Dictionary = actives[i]["sk"]
		loadout_idx[i] = int(actives[i]["li"])
		names[i] = String(sk.get("name", ""))
		ids[i] = String(sk.get("id", ""))
		dim[i] = false
		var sid := ids[i]
		var left := float(cd_map.get(sid, 0.0)) if sid != "" else 0.0
		cds[i] = left
		if sid == "" or left <= 0.05:
			cd_maxs[i] = 0.0
			if sid != "":
				_cd_peak.erase(sid)
			continue
		live[sid] = true
		var peak := float(_cd_peak.get(sid, left))
		peak = maxf(peak, left)
		_cd_peak[sid] = peak
		cd_maxs[i] = peak
	for id in _cd_peak.keys():
		if not live.has(id):
			_cd_peak.erase(id)
	queue_redraw()


func loadout_index_for_aim(ring_aim: int) -> int:
	if ring_aim < 0 or ring_aim >= 5:
		return -1
	return int(loadout_idx[ring_aim])


func set_aim(slot: int) -> void:
	if slot < AIM_CANCEL:
		slot = AIM_CANCEL
	elif slot > 4:
		slot = 4
	aim = slot
	queue_redraw()


## Map stick vector → aim (-1 cancel, 0–4 hole: up/right/down/left/UR).
static func aim_from_stick(v: Vector2) -> int:
	if v.length() < DEADZONE:
		return AIM_CANCEL
	## atan2(-y, x): 0=right, +pi/2=up, ±pi=left, -pi/2=down.
	var ang := atan2(-v.y, v.x)
	## Sector centers: up, right, down, left, UR.
	var centers := [
		PI * 0.5,
		0.0,
		-PI * 0.5,
		PI,
		PI * 0.25,
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
	if names[slot] == "" or ids[slot] == "":
		return
	var cd := cds[slot]
	var title := names[slot]
	var col := Color("f4d35e")
	if cd > 0.05:
		col = Color("c45c26")
	var chosen := slot == aim
	if chosen and cd <= 0.05:
		col = Color("fff4c2")
	var bg := Color(0.16, 0.2, 0.14, 0.94) if chosen else Color(0.05, 0.07, 0.06, 0.88)
	draw_circle(p, SLOT_R, bg)
	draw_arc(p, SLOT_R, 0.0, TAU, 28, col, 3.5 if chosen else 2.0, true)
	if cd > 0.05:
		var frac := clampf(cd / maxf(cd_maxs[slot], 0.01), 0.0, 1.0)
		var start := deg_to_rad(-90.0)
		var sweep := -TAU * frac
		var w := 4.5 if chosen else 3.25
		draw_arc(p, CD_RING_R, start, start + sweep, 40, CD_COL, w, true)
	var icon := SkillIcons.texture(ids[slot])
	if icon != null:
		var isz := 28.0
		draw_texture_rect(icon, Rect2(p - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false)
	var font := UiFont.font()
	var label := "%d" % (slot + 1)
	draw_string(font, p + Vector2(-6, SLOT_R + 16), label, HORIZONTAL_ALIGNMENT_LEFT, 20, UiFont.px(16), col)
	if chosen and title != "":
		var shown := title
		if cd > 0.05:
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
