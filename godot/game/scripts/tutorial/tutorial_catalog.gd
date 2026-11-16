extends RefCounted
## Tutorial lesson definitions (docs/systemdesign/tutorial.md).


static func all_lessons() -> Array[Dictionary]:
	return [
		_prep_open_shop(),
		_prep_shop_layout(),
		_ops_shelve(),
		_ops_clean(),
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


## Scenario 5：重選劇本／進準備 → 先購入三件基本商店物品。
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
			## Soft-lock 只准買這三類；買齊後 owned.size()==3。
			_step("tut.prep.open_shop.s1", 1, "owned_furniture_kinds", ">=", 3, ""),
		],
		"ops_task": {
			"name_key": "tut.prep.open_shop.task.name",
			"desc_key": "tut.prep.open_shop.task.desc",
		},
		## 購入階段：先開放購入；店鋪設計等買齊後再進下一課。
		"prep_restrict": {
			"home_hub_allow": ["hub_shop"],
			"shop_hub_allow": ["furn"],
			"pages_allow": ["home", "hub_shop", "furn"],
			"furniture_owned_cap": {
				"cashier": 1,
				"restock_dry": 1,
				"shelf_dry_4": 1,
			},
		},
	}


## Scenario 5：買齊後首次進店鋪設計 → 把三件擺進店（位置不限）。
static func _prep_shop_layout() -> Dictionary:
	return {
		"id": "tut.prep.shop_layout",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"prep_page": "layout",
			"requires_done": ["tut.prep.open_shop"],
		},
		"pages": [
			_page("tut.prep.shop_layout.p1.title", "tut.prep.shop_layout.p1.body"),
			_page("tut.prep.shop_layout.p2.title", "tut.prep.shop_layout.p2.body"),
			_page("tut.prep.shop_layout.p3.title", "tut.prep.shop_layout.p3.body"),
			_page("tut.prep.shop_layout.p4.title", "tut.prep.shop_layout.p4.body"),
		],
		"steps": [
			_step("tut.prep.shop_layout.s1", 1, "open_ready", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.prep.shop_layout.task.name",
			"desc_key": "tut.prep.shop_layout.task.desc",
		},
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


## Scenario 5：首次營運 → 補貨架執貨再貨架上架（營運第一課）。
static func _ops_shelve() -> Dictionary:
	return {
		"id": "tut.ops.shelve",
		"phase": "ops",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"day_index": 0,
			"requires_done": ["tut.prep.shop_layout"],
		},
		"pages": [
			_page("tut.ops.shelve.p1.title", "tut.ops.shelve.p1.body"),
			_page("tut.ops.shelve.p2.title", "tut.ops.shelve.p2.body"),
			_page("tut.ops.shelve.p3.title", "tut.ops.shelve.p3.body"),
			_page("tut.ops.shelve.p4.title", "tut.ops.shelve.p4.body"),
		],
		"steps": [
			_step("tut.ops.shelve.s1", 1, "shelve_count", ">=", 4, ""),
		],
		"ops_task": {
			"name_key": "tut.ops.shelve.task.name",
			"desc_key": "tut.ops.shelve.task.desc",
		},
		"complete_pages": [
			_page("tut.ops.shelve.done.title", "tut.ops.shelve.done.body"),
		],
	}


## Scenario 5：上架完成後、污物首次出現 → 清潔入門。
static func _ops_clean() -> Dictionary:
	return {
		"id": "tut.ops.clean",
		"phase": "ops",
		"trigger": {
			"when": "flag",
			"flag": "dirt_present",
			"scenario": 5,
			"day_index": 0,
			"requires_done": ["tut.ops.shelve"],
		},
		"pages": [
			_page("tut.ops.clean.p1.title", "tut.ops.clean.p1.body"),
			_page("tut.ops.clean.p2.title", "tut.ops.clean.p2.body"),
			_page("tut.ops.clean.p3.title", "tut.ops.clean.p3.body"),
		],
		"steps": [
			_step("tut.ops.clean.s1", 1, "clean_count", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.ops.clean.task.name",
			"desc_key": "tut.ops.clean.task.desc",
		},
	}
