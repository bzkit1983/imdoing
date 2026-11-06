extends RefCounted
## Character-only progress for M1 P2 guest slots (and in-session seat1 stats).
## No shop / money / warehouse. Duck-types with GameState for player.stats.

const Skills = preload("res://scripts/skills.gd")

const TINT_COUNT := 4
const TINT_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.82, 0.90, 1.0),
	Color(1.0, 0.90, 0.82),
	Color(0.88, 1.0, 0.86),
]

var xp: int = 0
var level: int = 1
var unspent: int = 0
var base_str: int = 10
var base_agi: int = 10
var base_int: int = 10
var str_stat: int = 10
var agi_stat: int = 10
var int_stat: int = 10
var slots: Array = ["", "", "", "", ""]
var ult_id: String = "the_world"
var skill_sets: Array = []
var skill_set_index: int = 0
var flags: Dictionary = {}
## Appearance palette index 0..TINT_COUNT-1.
var tint: int = 0
var display_name: String = ""


static func tint_color(index: int) -> Color:
	var i := clampi(index, 0, TINT_COUNT - 1)
	return TINT_COLORS[i]


static func blank() -> RefCounted:
	var sheet = load("res://scripts/session/character_sheet.gd").new()
	sheet.xp = 0
	sheet.level = 1
	sheet.unspent = 0
	sheet.base_str = 10
	sheet.base_agi = 10
	sheet.base_int = 10
	sheet.str_stat = 10
	sheet.agi_stat = 10
	sheet.int_stat = 10
	sheet.slots = ["carry_boost", "move_boost", "metal_rush", "checkout_speed", "instant_restock"]
	sheet.ult_id = "the_world"
	sheet.skill_sets = [{
		"name": "預設",
		"slots": sheet.slots.duplicate(),
		"ult_id": "the_world",
		"levels": {},
	}]
	sheet.skill_set_index = 0
	sheet.flags = {}
	sheet.tint = 0
	sheet.display_name = ""
	return sheet


static func from_game_state(src) -> RefCounted:
	var sheet = load("res://scripts/session/character_sheet.gd").new()
	if src == null:
		return sheet
	sheet.xp = int(src.xp)
	sheet.level = int(src.level)
	sheet.unspent = int(src.unspent)
	sheet.base_str = int(src.base_str)
	sheet.base_agi = int(src.base_agi)
	sheet.base_int = int(src.base_int)
	sheet.str_stat = int(src.str_stat)
	sheet.agi_stat = int(src.agi_stat)
	sheet.int_stat = int(src.int_stat)
	sheet.ult_id = String(src.ult_id)
	sheet.skill_set_index = int(src.skill_set_index)
	sheet.slots = src.slots.duplicate()
	sheet.skill_sets = src.skill_sets.duplicate(true)
	if src.get("flags") is Dictionary:
		sheet.flags = (src.flags as Dictionary).duplicate()
	var t := 0
	if "tint" in src:
		t = int(src.tint)
	sheet.tint = clampi(t, 0, TINT_COUNT - 1)
	return sheet


static func from_dict(data: Dictionary) -> RefCounted:
	var sheet = load("res://scripts/session/character_sheet.gd").new()
	if data.is_empty():
		return blank()
	sheet.xp = maxi(0, int(data.get("xp", 0)))
	sheet.level = clampi(int(data.get("level", 1)), 1, 99)
	sheet.unspent = maxi(0, int(data.get("unspent", 0)))
	sheet.base_str = int(data.get("base_str", 10))
	sheet.base_agi = int(data.get("base_agi", 10))
	sheet.base_int = int(data.get("base_int", 10))
	sheet.str_stat = int(data.get("str_stat", sheet.base_str))
	sheet.agi_stat = int(data.get("agi_stat", sheet.base_agi))
	sheet.int_stat = int(data.get("int_stat", sheet.base_int))
	sheet.ult_id = String(data.get("ult_id", "the_world"))
	sheet.skill_set_index = int(data.get("skill_set_index", 0))
	var raw_slots = data.get("slots", [])
	if raw_slots is Array and raw_slots.size() >= 5:
		sheet.slots = []
		for i in 5:
			sheet.slots.append(String(raw_slots[i]))
	var raw_sets = data.get("skill_sets", [])
	if raw_sets is Array and not raw_sets.is_empty():
		sheet.skill_sets = raw_sets.duplicate(true)
	else:
		sheet.skill_sets = [{
			"name": "預設",
			"slots": sheet.slots.duplicate(),
			"ult_id": sheet.ult_id,
			"levels": {},
		}]
	if data.get("flags") is Dictionary:
		sheet.flags = (data["flags"] as Dictionary).duplicate()
	sheet.tint = clampi(int(data.get("tint", 0)), 0, TINT_COUNT - 1)
	sheet.display_name = String(data.get("display_name", ""))
	return sheet


func to_dict() -> Dictionary:
	var slot_list: Array = []
	for s in slots:
		slot_list.append(String(s))
	return {
		"xp": xp,
		"level": level,
		"unspent": unspent,
		"base_str": base_str,
		"base_agi": base_agi,
		"base_int": base_int,
		"str_stat": str_stat,
		"agi_stat": agi_stat,
		"int_stat": int_stat,
		"slots": slot_list,
		"ult_id": ult_id,
		"skill_sets": skill_sets.duplicate(true),
		"skill_set_index": skill_set_index,
		"flags": flags.duplicate(),
		"tint": clampi(tint, 0, TINT_COUNT - 1),
		"display_name": display_name,
	}


func loadout() -> Array[Dictionary]:
	var levels := _levels_of(skill_set_index)
	var out: Array[Dictionary] = []
	for id in slots:
		if id == "":
			out.append({})
		else:
			var sk: Dictionary = Skills.by_id(String(id))
			if levels.has(id):
				sk = sk.duplicate()
				sk["lv"] = int(levels[id])
			out.append(sk)
	return out


func ult_skill() -> Dictionary:
	if ult_id == "":
		return {}
	return Skills.by_id(ult_id)


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func appearance_tint() -> Color:
	return tint_color(tint)


## Same level curve as GameState.settle. Returns {xp, ups, note}.
func apply_xp_gain(gain: int) -> Dictionary:
	var g := maxi(0, gain)
	xp += g
	var ups := 0
	while level < 10:
		var need := _xp_need(level + 1)
		if need <= 0 or xp < need:
			break
		xp -= need
		level += 1
		unspent += 5
		ups += 1
	var note := ""
	if ups > 0:
		note = "升級 %d 級，未分配點數 +%d" % [ups, ups * 5]
	if level >= 10:
		note += "  LV10 之後經驗表未定，不再升級"
	return {"xp": g, "ups": ups, "note": note}


func summary_line() -> String:
	var name := display_name if display_name.strip_edges() != "" else "訪客"
	return "%s  LV%d  XP%d  色%d" % [name, level, xp, tint]


func _xp_need(target_lv: int) -> int:
	match target_lv:
		2: return 200
		3: return 400
		4: return 800
		5: return 1200
		6: return 1500
		7: return 2000
		8: return 3000
		9: return 5000
		10: return 6000
		_: return 0


func _levels_of(set_i: int) -> Dictionary:
	if set_i < 0 or set_i >= skill_sets.size():
		return {}
	var pack: Dictionary = skill_sets[set_i]
	var levels = pack.get("levels", {})
	return levels if levels is Dictionary else {}
