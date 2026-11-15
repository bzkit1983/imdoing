extends RefCounted
## Tutorial lesson definitions (docs/systemdesign/tutorial.md).


static func all_lessons() -> Array[Dictionary]:
	return [
		_prep_open_shop(),
		_stub_ops_clean(),
	]


static func lesson_by_id(id: String) -> Dictionary:
	for lesson in all_lessons():
		if String(lesson.get("id", "")) == id:
			return lesson.duplicate(true)
	return {}


static func lessons_for_phase(phase: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var want := String(phase)
	for lesson in all_lessons():
		var p := String(lesson.get("phase", "either"))
		if p == "either" or p == want:
			out.append(lesson.duplicate(true))
	return out


static func _page(title_key: String, body_key: String, image_path: String = "") -> Dictionary:
	return {
		"title_key": title_key,
		"body_key": body_key,
		"image_path": image_path,
	}


static func _step(
	id: String,
	order: int,
	metric: String,
	op: String,
	target: int,
	next_id: String = "",
	filters: Dictionary = {},
) -> Dictionary:
	return {
		"id": id,
		"order": order,
		"condition": {
			"metric": metric,
			"op": op,
			"target": target,
			"filters": filters.duplicate(true),
		},
		"next": next_id,
	}


## Scenario 5：開店第一步（空店→可開業；限店鋪管理＋指定三件家具）。
static func _prep_open_shop() -> Dictionary:
	return {
		"id": "tut.prep.open_shop",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": [],
		},
		"pages": [
			_page("tut.prep.open_shop.p1.title", "tut.prep.open_shop.p1.body"),
			_page("tut.prep.open_shop.p2.title", "tut.prep.open_shop.p2.body"),
			_page("tut.prep.open_shop.p3.title", "tut.prep.open_shop.p3.body"),
		],
		"steps": [
			_step("tut.prep.open_shop.s1", 1, "open_ready", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.prep.open_shop.task.name",
			"desc_key": "tut.prep.open_shop.task.desc",
		},
		## Prep soft-lock while forced: only shop hub／buy＋layout; furniture caps.
		"prep_restrict": {
			"home_hub_allow": ["hub_shop"],
			"shop_hub_allow": ["furn", "layout"],
			"pages_allow": ["home", "hub_shop", "furn", "layout"],
			"furniture_owned_cap": {
				"cashier": 1,
				"restock_dry": 1,
				"shelf_dry_4": 1,
			},
		},
	}


## Scenario 5 ops stub: clean once on first open day after prep lesson.
static func _stub_ops_clean() -> Dictionary:
	return {
		"id": "tut.stub.ops_clean",
		"phase": "ops",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"day_index": 0,
			"requires_done": ["tut.prep.open_shop"],
		},
		"pages": [
			_page("tut.stub.ops_clean.p1.title", "tut.stub.ops_clean.p1.body"),
		],
		"steps": [
			_step("tut.stub.ops_clean.s1", 1, "clean_count", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.stub.ops_clean.task.name",
			"desc_key": "tut.stub.ops_clean.task.desc",
		},
	}
