extends RefCounted
## Ops / event / story task packs as serializable Dictionaries (tasksystem.md).
## Temporary GDScript source; same shape as future res://data/tasks/*.json.

## Metrics wired in this MVP (generator prefers these).
const WIRED_METRICS: Array[String] = [
	"shelve_count",
	"shelve_count_sku",
	"clean_count",
	"deliver_count",
	"hand_deliver_count",
	"toss_deliver_count",
	"perfect_deliver_count",
	"wrong_deliver",
	"deliver_combo",
	"checkout_count",
	"checkout_perfect",
	"angry_leave",
	"dash_knock_guest",
	"thief_caught",
	"thief_caught_melee",
	"thief_caught_dash",
	"skill_cast",
	"ult_cast",
	"sales_revenue",
	"shop_money",
	"ops_rating",
	"day_grade",
	"shop_rating",
]

const UNWIRED_METRICS: Array[String] = [
	"sales_revenue_category",
	"sales_revenue_sku",
	"sold_count",
	"sold_count_category",
	"sold_count_sku",
	"dirt_affect_count",
	"deliver_sku",
	"shelf_setup",
	"grade_streak",
]


static func is_wired(metric: String) -> bool:
	return metric in WIRED_METRICS


static func task(
	id: String,
	metric: String,
	op: String,
	target: Variant,
	scope: Dictionary,
	filters: Dictionary = {},
	loc_key: String = "",
	rewards: Array = [],
) -> Dictionary:
	return {
		"id": id,
		"metric": metric,
		"op": op,
		"target": target,
		"scope": scope.duplicate(true),
		"filters": filters.duplicate(true),
		"loc_key": loc_key if loc_key != "" else ("quest.%s" % id.to_lower().replace("-", "_")),
		"rewards": rewards.duplicate(true),
	}


static func pack(pack_id: String, kind: String, tasks: Array) -> Dictionary:
	var out_tasks: Array = []
	for t in tasks:
		if t is Dictionary:
			out_tasks.append((t as Dictionary).duplicate(true))
	return {"pack_id": pack_id, "kind": kind, "tasks": out_tasks}


static func pack_op_tut_001() -> Dictionary:
	## sku id is Tuning "can" (design alias canned).
	return pack("OP-TUT-001", "ops", [
		task("OP-TUT-001-A", "shelve_count_sku", ">=", 12, {"type": "day"}, {"sku": "can"}, "quest.op_tut_001_a"),
		task("OP-TUT-001-B", "clean_count", ">=", 6, {"type": "day"}, {}, "quest.op_tut_001_b"),
		task("OP-TUT-001-C", "deliver_count", ">=", 10, {"type": "day"}, {}, "quest.op_tut_001_c"),
		task("OP-TUT-001-D", "perfect_deliver_count", ">=", 3, {"type": "day"}, {}, "quest.op_tut_001_d"),
		task("OP-TUT-001-E", "checkout_count", ">=", 3, {"type": "day"}, {}, "quest.op_tut_001_e"),
		task("OP-TUT-001-F", "angry_leave", "<", 5, {"type": "day"}, {}, "quest.op_tut_001_f"),
	])


static func pack_op_man_001() -> Dictionary:
	return pack("OP-MAN-001", "ops", [
		task("OP-MAN-001-A", "sales_revenue", ">=", 500, {"type": "day"}, {}, "quest.op_man_001_a"),
		task("OP-MAN-001-B", "day_grade", ">=", 1, {"type": "day"}, {}, "quest.op_man_001_b"),
	])


static func pack_op_man_002() -> Dictionary:
	return pack("OP-MAN-002", "ops", [
		task("OP-MAN-002-A", "clean_count", ">=", 20, {"type": "accumulate", "max_days": 3}, {}, "quest.op_man_002_a"),
		task("OP-MAN-002-B", "shop_rating", ">=", 5, {"type": "accumulate"}, {}, "quest.op_man_002_b"),
	])


static func pack_by_id(pack_id: String) -> Dictionary:
	match String(pack_id):
		"OP-TUT-001", "pack_tutorial_prologue":
			return pack_op_tut_001()
		"OP-MAN-001", "pack_manual_OP-MAN-001":
			return pack_op_man_001()
		"OP-MAN-002", "pack_manual_OP-MAN-002":
			return pack_op_man_002()
		_:
			return {}


static func list_test_pack_ids() -> Array[String]:
	return ["OP-TUT-001", "OP-MAN-001", "OP-MAN-002"]


## Random ops templates: metric, op, base, min, max, default filters, wired flag.
static func _templates() -> Array[Dictionary]:
	return [
		{"metric": "clean_count", "op": ">=", "base": 6, "min": 3, "max": 20, "filters": {}, "wired": true},
		{"metric": "deliver_count", "op": ">=", "base": 8, "min": 4, "max": 25, "filters": {}, "wired": true},
		{"metric": "perfect_deliver_count", "op": ">=", "base": 3, "min": 1, "max": 10, "filters": {}, "wired": true},
		{"metric": "hand_deliver_count", "op": ">=", "base": 5, "min": 2, "max": 15, "filters": {}, "wired": true},
		{"metric": "checkout_count", "op": ">=", "base": 5, "min": 2, "max": 15, "filters": {}, "wired": true},
		{"metric": "checkout_perfect", "op": ">=", "base": 2, "min": 1, "max": 8, "filters": {}, "wired": true},
		{"metric": "shelve_count", "op": ">=", "base": 12, "min": 6, "max": 40, "filters": {}, "wired": true},
		{"metric": "shelve_count_sku", "op": ">=", "base": 12, "min": 6, "max": 30, "filters": {"sku": "can"}, "wired": true},
		{"metric": "sales_revenue", "op": ">=", "base": 400, "min": 200, "max": 2000, "filters": {}, "wired": true},
		{"metric": "thief_caught", "op": ">=", "base": 1, "min": 1, "max": 5, "filters": {}, "wired": true},
		{"metric": "angry_leave", "op": "<", "base": 5, "min": 2, "max": 10, "filters": {}, "wired": true},
		{"metric": "wrong_deliver", "op": "<", "base": 4, "min": 2, "max": 8, "filters": {}, "wired": true},
		{"metric": "ops_rating", "op": ">=", "base": 55, "min": 45, "max": 70, "filters": {}, "wired": true},
		{"metric": "day_grade", "op": ">=", "base": 1, "min": 0, "max": 2, "filters": {}, "wired": true},
		{"metric": "shop_rating", "op": ">=", "base": 3, "min": 1, "max": 15, "filters": {}, "wired": true},
		{"metric": "dash_knock_guest", "op": "<", "base": 3, "min": 1, "max": 6, "filters": {}, "wired": true},
		{"metric": "dirt_affect_count", "op": "<", "base": 5, "min": 2, "max": 10, "filters": {}, "wired": false},
		{"metric": "sold_count", "op": ">=", "base": 20, "min": 10, "max": 60, "filters": {}, "wired": false},
	]


static func generate_ops(
	rng_seed: int,
	slot_count: int = 3,
	_day_index: int = 0,
	_player_level: int = 1,
	difficulty_mult: float = 1.0,
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var use_seed := rng_seed if rng_seed != 0 else int(hash(Time.get_ticks_msec()))
	rng.seed = use_seed
	var n := clampi(slot_count, 2, 4)
	var pool: Array[Dictionary] = []
	for t in _templates():
		## Prefer wired; still allow unwired only if pool would be empty (should not happen).
		if bool(t.get("wired", false)):
			pool.append(t)
	if pool.is_empty():
		pool = _templates().duplicate()
	var used_keys: Dictionary = {}
	var tasks: Array = []
	var cap_used := false
	var guard := 0
	while tasks.size() < n and guard < 64:
		guard += 1
		var idx := rng.randi_range(0, pool.size() - 1)
		var tmpl: Dictionary = pool[idx]
		var metric := String(tmpl.get("metric", ""))
		var filters: Dictionary = (tmpl.get("filters", {}) as Dictionary).duplicate(true)
		var key := metric + "|" + str(filters.get("sku", ""))
		if used_keys.has(key):
			continue
		var op := String(tmpl.get("op", ">="))
		var is_cap := op == "<" or op == "<="
		if is_cap and cap_used:
			continue
		var base := float(tmpl.get("base", 5))
		var lo := int(tmpl.get("min", 1))
		var hi := int(tmpl.get("max", 20))
		var jitter := rng.randf_range(0.85, 1.15)
		var target := int(round(base * difficulty_mult * jitter))
		target = clampi(target, lo, hi)
		## Scope weights: 70% day, 20% 3-day, 10% infinite.
		var roll := rng.randf()
		var scope: Dictionary
		if roll < 0.70:
			scope = {"type": "day"}
		elif roll < 0.90:
			scope = {"type": "accumulate", "max_days": 3}
		else:
			scope = {"type": "accumulate"}
		## Cap tasks stay day-scoped for clearer fail-X.
		if is_cap:
			scope = {"type": "day"}
			cap_used = true
		var tid := "OP-RAND-%d-%d" % [use_seed, tasks.size()]
		tasks.append(task(tid, metric, op, target, scope, filters, "quest.op_rand_generic"))
		used_keys[key] = true
	var out := pack("OP-RAND", "ops", tasks)
	out["seed"] = use_seed
	return out
