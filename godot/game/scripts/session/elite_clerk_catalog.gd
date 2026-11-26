extends RefCounted
## Static elite-clerk definitions. Runtime progress lives on GameState.elite_clerks.
## Design: docs/systemdesign/eliteclerk.md

const LEVEL_MAX_DEFAULT := 10

## Theme-lead placeholders (brainstorm names) + one event / minigame sample.
const ENTRIES: Array[Dictionary] = [
	{
		"id": "alan",
		"theme_id": "theme_break",
		"source_hint": "theme_clear",
		"name_key": "elite_clerk.alan.name",
		"bio_key": "elite_clerk.alan.bio",
		"model_id": "clerk_cashier",
		"allowed_roles": ["cashier", "security", "cleaner"],
		"max_posts": 2,
		"default_roles": ["cashier", "cleaner"],
		"skill_id": "soothe",
		"level_max": 10,
		"growth": _growth_agi_lean(),
		"upgrade_costs": _costs_standard(),
	},
	{
		"id": "yayoi",
		"theme_id": "theme_historic",
		"source_hint": "theme_clear",
		"name_key": "elite_clerk.yayoi.name",
		"bio_key": "elite_clerk.yayoi.bio",
		"model_id": "clerk_cashier",
		"allowed_roles": ["cashier", "security"],
		"max_posts": 2,
		"default_roles": ["cashier", "security"],
		"skill_id": "checkout_speed",
		"level_max": 10,
		"growth": _growth_int_lean(),
		"upgrade_costs": _costs_standard(),
	},
	{
		"id": "sumi",
		"theme_id": "theme_ritual",
		"source_hint": "theme_clear",
		"name_key": "elite_clerk.sumi.name",
		"bio_key": "elite_clerk.sumi.bio",
		"model_id": "clerk_cleaner",
		"allowed_roles": ["cleaner", "cashier"],
		"max_posts": 2,
		"default_roles": ["cleaner"],
		"skill_id": "sweeping_monk",
		"level_max": 10,
		"growth": _growth_agi_lean(),
		"upgrade_costs": _costs_standard(),
	},
	{
		"id": "griffin",
		"theme_id": "theme_fantasy",
		"source_hint": "theme_clear",
		"name_key": "elite_clerk.griffin.name",
		"bio_key": "elite_clerk.griffin.bio",
		"model_id": "clerk_security",
		"allowed_roles": ["security", "restock"],
		"max_posts": 2,
		"default_roles": ["security", "restock"],
		"skill_id": "carry_passive",
		"level_max": 10,
		"growth": _growth_str_lean(),
		"upgrade_costs": _costs_standard(),
	},
	{
		"id": "nul",
		"theme_id": "theme_tech",
		"source_hint": "theme_clear",
		"name_key": "elite_clerk.nul.name",
		"bio_key": "elite_clerk.nul.bio",
		"model_id": "clerk_restock",
		"allowed_roles": ["restock", "cashier", "security", "cleaner"],
		"max_posts": 3,
		"default_roles": ["restock", "cashier", "cleaner"],
		"skill_id": "npc_multi_micro",
		"level_max": 10,
		"growth": _growth_balanced(),
		"upgrade_costs": _costs_standard(),
	},
	{
		"id": "ran",
		"theme_id": "theme_climate",
		"source_hint": "theme_clear",
		"name_key": "elite_clerk.ran.name",
		"bio_key": "elite_clerk.ran.bio",
		"model_id": "clerk_cleaner",
		"allowed_roles": ["cleaner", "security"],
		"max_posts": 2,
		"default_roles": ["cleaner", "security"],
		"skill_id": "calm_zone",
		"level_max": 10,
		"growth": _growth_agi_lean(),
		"upgrade_costs": _costs_standard(),
	},
	{
		"id": "mirror_you",
		"theme_id": "theme_mirror",
		"source_hint": "theme_clear",
		"name_key": "elite_clerk.mirror_you.name",
		"bio_key": "elite_clerk.mirror_you.bio",
		"model_id": "clerk_cashier",
		"allowed_roles": ["cashier", "security", "cleaner"],
		"max_posts": 2,
		"default_roles": ["cashier", "security"],
		"skill_id": "elite_guest_specialist",
		"level_max": 10,
		"growth": _growth_int_lean(),
		"upgrade_costs": _costs_premium(),
	},
	{
		"id": "kiko",
		"theme_id": "",
		"source_hint": "minigame",
		"name_key": "elite_clerk.kiko.name",
		"bio_key": "elite_clerk.kiko.bio",
		"model_id": "clerk_restock",
		"allowed_roles": ["restock", "cleaner"],
		"max_posts": 2,
		"default_roles": ["restock", "cleaner"],
		"skill_id": "restock_speed",
		"level_max": 8,
		"growth": _growth_balanced_short(),
		"upgrade_costs": _costs_light(),
	},
]

## NPC-only skill tags (not in player Skills pool).
const NPC_SKILLS: Dictionary = {
	"npc_multi_micro": {
		"id": "npc_multi_micro",
		"kind": "passive",
		"restock_pct": 0.15,
		"move_pct": 0.10,
		"name_key": "skill.npc_multi_micro.name",
		"blurb_key": "skill.npc_multi_micro.blurb",
	},
}


static func _growth_balanced() -> Array:
	return [
		{"str": 8, "agi": 8, "int": 8},
		{"str": 9, "agi": 9, "int": 9},
		{"str": 10, "agi": 10, "int": 10},
		{"str": 11, "agi": 11, "int": 11},
		{"str": 12, "agi": 12, "int": 12},
		{"str": 13, "agi": 13, "int": 13},
		{"str": 14, "agi": 14, "int": 14},
		{"str": 15, "agi": 15, "int": 15},
		{"str": 16, "agi": 16, "int": 16},
		{"str": 18, "agi": 18, "int": 18},
	]


static func _growth_balanced_short() -> Array:
	return [
		{"str": 7, "agi": 9, "int": 7},
		{"str": 8, "agi": 10, "int": 8},
		{"str": 9, "agi": 11, "int": 9},
		{"str": 10, "agi": 12, "int": 10},
		{"str": 11, "agi": 13, "int": 11},
		{"str": 12, "agi": 14, "int": 12},
		{"str": 13, "agi": 15, "int": 13},
		{"str": 14, "agi": 16, "int": 14},
	]


static func _growth_str_lean() -> Array:
	return [
		{"str": 12, "agi": 7, "int": 6},
		{"str": 14, "agi": 8, "int": 7},
		{"str": 16, "agi": 8, "int": 7},
		{"str": 18, "agi": 9, "int": 8},
		{"str": 20, "agi": 10, "int": 8},
		{"str": 22, "agi": 10, "int": 9},
		{"str": 24, "agi": 11, "int": 9},
		{"str": 26, "agi": 12, "int": 10},
		{"str": 28, "agi": 12, "int": 10},
		{"str": 30, "agi": 13, "int": 11},
	]


static func _growth_agi_lean() -> Array:
	return [
		{"str": 7, "agi": 12, "int": 7},
		{"str": 8, "agi": 14, "int": 8},
		{"str": 8, "agi": 16, "int": 8},
		{"str": 9, "agi": 18, "int": 9},
		{"str": 10, "agi": 20, "int": 9},
		{"str": 10, "agi": 22, "int": 10},
		{"str": 11, "agi": 24, "int": 10},
		{"str": 12, "agi": 26, "int": 11},
		{"str": 12, "agi": 28, "int": 12},
		{"str": 13, "agi": 30, "int": 12},
	]


static func _growth_int_lean() -> Array:
	return [
		{"str": 6, "agi": 8, "int": 12},
		{"str": 7, "agi": 9, "int": 14},
		{"str": 7, "agi": 9, "int": 16},
		{"str": 8, "agi": 10, "int": 18},
		{"str": 8, "agi": 10, "int": 20},
		{"str": 9, "agi": 11, "int": 22},
		{"str": 9, "agi": 12, "int": 24},
		{"str": 10, "agi": 12, "int": 26},
		{"str": 10, "agi": 13, "int": 28},
		{"str": 11, "agi": 14, "int": 30},
	]


static func _costs_standard() -> Array:
	return [500, 800, 1200, 1800, 2500, 3500, 4800, 6500, 8500]


static func _costs_premium() -> Array:
	return [800, 1200, 1800, 2600, 3600, 5000, 6800, 9000, 12000]


static func _costs_light() -> Array:
	return [300, 500, 800, 1200, 1700, 2300, 3000]


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for e in ENTRIES:
		out.append(String(e.get("id", "")))
	return out


static func entry(elite_id: String) -> Dictionary:
	var id := String(elite_id)
	for e in ENTRIES:
		if String(e.get("id", "")) == id:
			return e
	return {}


static func exists(elite_id: String) -> bool:
	return not entry(elite_id).is_empty()


static func display_name(elite_id: String) -> String:
	var e := entry(elite_id)
	if e.is_empty():
		return elite_id
	var key := String(e.get("name_key", ""))
	if key != "" and Loc != null and Loc.has_method("t"):
		return Loc.t(key)
	return elite_id


static func bio(elite_id: String) -> String:
	var e := entry(elite_id)
	if e.is_empty():
		return ""
	var key := String(e.get("bio_key", ""))
	if key != "" and Loc != null and Loc.has_method("t"):
		return Loc.t(key)
	return ""


static func level_max(elite_id: String) -> int:
	var e := entry(elite_id)
	if e.is_empty():
		return LEVEL_MAX_DEFAULT
	return maxi(1, int(e.get("level_max", LEVEL_MAX_DEFAULT)))


static func max_posts(elite_id: String) -> int:
	var e := entry(elite_id)
	if e.is_empty():
		return 1
	return maxi(1, int(e.get("max_posts", 1)))


static func allowed_roles(elite_id: String) -> Array[String]:
	var out: Array[String] = []
	var e := entry(elite_id)
	if e.is_empty():
		return out
	var raw = e.get("allowed_roles", [])
	if raw is Array:
		for r in raw:
			var s := String(r)
			if s != "" and not out.has(s):
				out.append(s)
	return out


static func default_roles(elite_id: String) -> Array[String]:
	var out: Array[String] = []
	var e := entry(elite_id)
	if e.is_empty():
		return out
	var raw = e.get("default_roles", [])
	if raw is Array:
		for r in raw:
			var s := String(r)
			if s != "" and not out.has(s):
				out.append(s)
	var allowed := allowed_roles(elite_id)
	var filtered: Array[String] = []
	for r in out:
		if allowed.has(r):
			filtered.append(r)
	var cap := max_posts(elite_id)
	while filtered.size() > cap:
		filtered.pop_back()
	if filtered.is_empty() and not allowed.is_empty():
		filtered.append(allowed[0])
	return filtered


static func skill_id(elite_id: String) -> String:
	var e := entry(elite_id)
	if e.is_empty():
		return ""
	return String(e.get("skill_id", ""))


static func model_id(elite_id: String) -> String:
	var e := entry(elite_id)
	if e.is_empty():
		return "clerk_restock"
	var mid := String(e.get("model_id", "clerk_restock"))
	return mid if mid != "" else "clerk_restock"


static func stats_at(elite_id: String, level: int) -> Dictionary:
	var e := entry(elite_id)
	var lv := clampi(level, 1, level_max(elite_id))
	if e.is_empty():
		return {"str": 8, "agi": 8, "int": 8}
	var growth = e.get("growth", [])
	if growth is Array and growth.size() > 0:
		var idx := clampi(lv - 1, 0, growth.size() - 1)
		var row = growth[idx]
		if row is Dictionary:
			return {
				"str": int(row.get("str", 8)),
				"agi": int(row.get("agi", 8)),
				"int": int(row.get("int", 8)),
			}
	return {"str": 8, "agi": 8, "int": 8}


static func upgrade_cost(elite_id: String, from_level: int) -> int:
	## Cost to go from_level → from_level+1. 0 if maxed / unknown.
	var e := entry(elite_id)
	if e.is_empty():
		return 0
	var lv_max := level_max(elite_id)
	if from_level < 1 or from_level >= lv_max:
		return 0
	var costs = e.get("upgrade_costs", [])
	if costs is Array and costs.size() > 0:
		var idx := from_level - 1
		if idx >= 0 and idx < costs.size():
			return maxi(0, int(costs[idx]))
	return 500 * from_level


static func skill_def(skill: String) -> Dictionary:
	var sid := String(skill)
	if sid == "":
		return {}
	if NPC_SKILLS.has(sid):
		return NPC_SKILLS[sid]
	var Skills = load("res://scripts/skills.gd")
	if Skills != null and Skills.has_method("by_id"):
		var sk = Skills.by_id(sid)
		if sk is Dictionary:
			return sk
	## Fall back to scanning Skills.ALL if present.
	if Skills != null:
		for pool_name in ["ACTIVES", "PASSIVES", "ALL"]:
			if pool_name in Skills:
				var pool = Skills.get(pool_name)
				if pool is Array:
					for row in pool:
						if row is Dictionary and String(row.get("id", "")) == sid:
							return row
	return {}


static func skill_name(skill: String) -> String:
	var def := skill_def(skill)
	if def.is_empty():
		return skill
	var key := String(def.get("name_key", ""))
	if key == "":
		key = "skill.%s.name" % String(def.get("id", skill))
	if Loc != null and Loc.has_method("t"):
		return Loc.t(key)
	return skill


static func skill_blurb(skill: String) -> String:
	var def := skill_def(skill)
	if def.is_empty():
		return ""
	var key := String(def.get("blurb_key", ""))
	if key == "":
		key = "skill.%s.blurb" % String(def.get("id", skill))
	if Loc != null and Loc.has_method("t"):
		return Loc.t(key)
	return ""
