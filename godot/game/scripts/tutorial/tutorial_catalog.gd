extends RefCounted
## Tutorial lesson definitions (docs/systemdesign/tutorial.md).


static func all_lessons() -> Array[Dictionary]:
	return [
		_prep_open_shop(),
		_prep_buy_stock(),
		_prep_shop_layout(),
		_ops_shelve(),
		_ops_clean(),
		_ops_checkout(),
		_ops_thief(),
		_ops_empty_shelf(),
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
		## 購入階段：先開放購入；採購／店鋪設計等買齊後再進下一課。
		"prep_restrict": {
			"home_hub_allow": ["hub_shop"],
			"shop_hub_allow": ["furn"],
			"pages_allow": ["home", "hub_shop", "furn"],
			"shop_hint_key": "tut.prep.restrict.shop_hint_furn",
			"furniture_owned_cap": {
				"cashier": 1,
				"restock_dry": 1,
				"shelf_dry_4": 1,
			},
		},
	}


## Scenario 5：購入家具後 → 採購罐頭 99 件進倉庫。
static func _prep_buy_stock() -> Dictionary:
	return {
		"id": "tut.prep.buy_stock",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": ["tut.prep.open_shop"],
		},
		"pages": [
			_page("tut.prep.buy_stock.p1.title", "tut.prep.buy_stock.p1.body"),
			_page("tut.prep.buy_stock.p2.title", "tut.prep.buy_stock.p2.body"),
			_page("tut.prep.buy_stock.p3.title", "tut.prep.buy_stock.p3.body"),
		],
		"steps": [
			_step("tut.prep.buy_stock.s1", 1, "stock_pieces", ">=", 99, "", {"sku": "can"}),
		],
		"ops_task": {
			"name_key": "tut.prep.buy_stock.task.name",
			"desc_key": "tut.prep.buy_stock.task.desc",
		},
		"complete_pages": [
			_page("tut.prep.buy_stock.done.title", "tut.prep.buy_stock.done.body"),
		],
		"prep_restrict": {
			"home_hub_allow": ["hub_goods"],
			"goods_hub_allow": ["buy"],
			"pages_allow": ["home", "hub_goods", "buy"],
			"home_hint_key": "tut.prep.restrict.home_hint_buy",
		},
	}


## Scenario 5：採購完成後鏈式觸發 → 只准店鋪設計，把三件擺進店。
static func _prep_shop_layout() -> Dictionary:
	return {
		"id": "tut.prep.shop_layout",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": ["tut.prep.buy_stock"],
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
			"shop_hub_allow": ["layout"],
			"pages_allow": ["home", "hub_shop", "layout"],
			"home_hint_key": "tut.prep.restrict.home_hint_layout",
			"shop_hint_key": "tut.prep.restrict.shop_hint",
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


## Scenario 5：清潔完成後 → 收銀台收錢兩次。
static func _ops_checkout() -> Dictionary:
	return {
		"id": "tut.ops.checkout",
		"phase": "ops",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"day_index": 0,
			"requires_done": ["tut.ops.clean"],
		},
		"pages": [
			_page("tut.ops.checkout.p1.title", "tut.ops.checkout.p1.body"),
			_page("tut.ops.checkout.p2.title", "tut.ops.checkout.p2.body"),
			_page("tut.ops.checkout.p3.title", "tut.ops.checkout.p3.body"),
		],
		"steps": [
			_step("tut.ops.checkout.s1", 1, "checkout_count", ">=", 2, ""),
		],
		"ops_task": {
			"name_key": "tut.ops.checkout.task.name",
			"desc_key": "tut.ops.checkout.task.desc",
		},
		"complete_pages": [
			_page("tut.ops.checkout.done.title", "tut.ops.checkout.done.body"),
		],
	}


## Scenario 5：收銀完成後小偷進場 → 捉住一次。
static func _ops_thief() -> Dictionary:
	return {
		"id": "tut.ops.thief",
		"phase": "ops",
		"trigger": {
			"when": "flag",
			"flag": "thief_present",
			"scenario": 5,
			"day_index": 0,
			"requires_done": ["tut.ops.checkout"],
		},
		"pages": [
			_page("tut.ops.thief.p1.title", "tut.ops.thief.p1.body"),
			_page("tut.ops.thief.p2.title", "tut.ops.thief.p2.body"),
			_page("tut.ops.thief.p3.title", "tut.ops.thief.p3.body"),
		],
		"steps": [
			_step("tut.ops.thief.s1", 1, "thief_caught", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.ops.thief.task.name",
			"desc_key": "tut.ops.thief.task.desc",
		},
		"complete_pages": [
			_page("tut.ops.thief.done.title", "tut.ops.thief.done.body"),
		],
	}


## Scenario 5：收銀後首次貨架被清空 → 純提示（無強制練習）。
static func _ops_empty_shelf() -> Dictionary:
	return {
		"id": "tut.ops.empty_shelf",
		"phase": "ops",
		"trigger": {
			"when": "flag",
			"flag": "shelf_empty",
			"scenario": 5,
			"day_index": 0,
			"requires_done": ["tut.ops.checkout"],
		},
		"pages": [
			_page("tut.ops.empty_shelf.p1.title", "tut.ops.empty_shelf.p1.body"),
			_page("tut.ops.empty_shelf.p2.title", "tut.ops.empty_shelf.p2.body"),
		],
		## Tip: empty steps → pages ack completes the lesson (no settle hard-gate).
		"steps": [],
		"ops_task": {
			"name_key": "tut.ops.empty_shelf.task.name",
			"desc_key": "tut.ops.empty_shelf.task.desc",
		},
		"complete_pages": [
			_page("tut.ops.empty_shelf.done.title", "tut.ops.empty_shelf.done.body"),
		],
	}
