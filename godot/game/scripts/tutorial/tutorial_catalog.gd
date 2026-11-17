extends RefCounted
## Tutorial lesson definitions (docs/systemdesign/tutorial.md).


static func all_lessons() -> Array[Dictionary]:
	return [
		_prep_open_shop(),
		_prep_buy_stock(),
		_prep_shop_layout(),
		_prep_allocate_stats(),
		_prep_equip_skills(),
		_prep_develop_goods(),
		_prep_buy_new_goods(),
		_prep_buy_new_furn(),
		_prep_layout_expand(),
		_prep_buy_cashier(),
		_prep_hire_clerk(),
		_ops_shelve(),
		_ops_clean(),
		_ops_checkout(),
		_ops_thief(),
		_ops_deliver(),
		_ops_finish_day(),
		_ops_use_skills(),
		_ops_rating(),
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


## Scenario 5：第一日結算回 prep → 配點（保證 LV2；花完 unspent）。
static func _prep_allocate_stats() -> Dictionary:
	return {
		"id": "tut.prep.allocate_stats",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": ["tut.ops.finish_day"],
		},
		"pages": [
			_page("tut.prep.allocate_stats.p1.title", "tut.prep.allocate_stats.p1.body"),
			_page("tut.prep.allocate_stats.p2.title", "tut.prep.allocate_stats.p2.body"),
			_page("tut.prep.allocate_stats.p3.title", "tut.prep.allocate_stats.p3.body"),
			_page("tut.prep.allocate_stats.p4.title", "tut.prep.allocate_stats.p4.body"),
			_page("tut.prep.allocate_stats.p5.title", "tut.prep.allocate_stats.p5.body"),
		],
		"steps": [
			_step("tut.prep.allocate_stats.s1", 1, "unspent", "==", 0, ""),
		],
		"ops_task": {
			"name_key": "tut.prep.allocate_stats.task.name",
			"desc_key": "tut.prep.allocate_stats.task.desc",
		},
		"complete_pages": [
			_page("tut.prep.allocate_stats.done.title", "tut.prep.allocate_stats.done.body"),
		],
		"prep_restrict": {
			"home_hub_allow": ["hub_char"],
			"char_hub_allow": ["stats"],
			"pages_allow": ["home", "hub_char", "stats"],
			"home_hint_key": "tut.prep.restrict.home_hint_stats",
		},
	}


## Scenario 5：配點完成後 → 裝備技能（任意改一次組合）。
static func _prep_equip_skills() -> Dictionary:
	return {
		"id": "tut.prep.equip_skills",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": ["tut.prep.allocate_stats"],
		},
		"pages": [
			_page("tut.prep.equip_skills.p1.title", "tut.prep.equip_skills.p1.body"),
			_page("tut.prep.equip_skills.p2.title", "tut.prep.equip_skills.p2.body"),
			_page("tut.prep.equip_skills.p3.title", "tut.prep.equip_skills.p3.body"),
			_page("tut.prep.equip_skills.p4.title", "tut.prep.equip_skills.p4.body"),
		],
		"steps": [
			_step("tut.prep.equip_skills.s1", 1, "loadout_changed", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.prep.equip_skills.task.name",
			"desc_key": "tut.prep.equip_skills.task.desc",
		},
		"complete_pages": [
			_page("tut.prep.equip_skills.done.title", "tut.prep.equip_skills.done.body"),
		],
		"prep_restrict": {
			"home_hub_allow": ["hub_char"],
			"char_hub_allow": ["skills"],
			"pages_allow": ["home", "hub_char", "skills", "skill_set", "skill_pick"],
			"home_hint_key": "tut.prep.restrict.home_hint_skills",
		},
	}


## Scenario 5：use_skills 結算回 prep → 開發零食＋支裝凍飲（LV4）。
static func _prep_develop_goods() -> Dictionary:
	return {
		"id": "tut.prep.develop_goods",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": ["tut.ops.use_skills"],
		},
		"pages": [
			_page("tut.prep.develop_goods.p1.title", "tut.prep.develop_goods.p1.body"),
			_page("tut.prep.develop_goods.p2.title", "tut.prep.develop_goods.p2.body"),
			_page("tut.prep.develop_goods.p3.title", "tut.prep.develop_goods.p3.body"),
		],
		"steps": [
			_step("tut.prep.develop_goods.s1", 1, "developed_has", ">=", 1, "tut.prep.develop_goods.s2", {"sku": "snack"}),
			_step("tut.prep.develop_goods.s2", 2, "developed_has", ">=", 1, "", {"sku": "drink"}),
		],
		"ops_task": {
			"name_key": "tut.prep.develop_goods.task.name",
			"desc_key": "tut.prep.develop_goods.task.desc",
		},
		"complete_pages": [
			_page("tut.prep.develop_goods.done.title", "tut.prep.develop_goods.done.body"),
		],
		"prep_restrict": {
			"home_hub_allow": ["hub_goods"],
			"goods_hub_allow": ["develop"],
			"pages_allow": ["home", "hub_goods", "develop"],
			"home_hint_key": "tut.prep.restrict.home_hint_develop",
			"goods_hint_key": "tut.prep.restrict.goods_hint_develop",
			"goods_sku_allow": ["snack", "drink"],
		},
	}


## Scenario 5：開發完成後 → 採購零食＋支裝凍飲（罐頭可選）。
static func _prep_buy_new_goods() -> Dictionary:
	return {
		"id": "tut.prep.buy_new_goods",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": ["tut.prep.develop_goods"],
		},
		"pages": [
			_page("tut.prep.buy_new_goods.p1.title", "tut.prep.buy_new_goods.p1.body"),
			_page("tut.prep.buy_new_goods.p2.title", "tut.prep.buy_new_goods.p2.body"),
			_page("tut.prep.buy_new_goods.p3.title", "tut.prep.buy_new_goods.p3.body"),
		],
		"steps": [
			_step("tut.prep.buy_new_goods.s1", 1, "stock_pieces", ">=", 4, "tut.prep.buy_new_goods.s2", {"sku": "snack"}),
			_step("tut.prep.buy_new_goods.s2", 2, "stock_pieces", ">=", 4, "", {"sku": "drink"}),
		],
		"ops_task": {
			"name_key": "tut.prep.buy_new_goods.task.name",
			"desc_key": "tut.prep.buy_new_goods.task.desc",
		},
		"complete_pages": [
			_page("tut.prep.buy_new_goods.done.title", "tut.prep.buy_new_goods.done.body"),
		],
		"prep_restrict": {
			"home_hub_allow": ["hub_goods"],
			"goods_hub_allow": ["buy"],
			"pages_allow": ["home", "hub_goods", "buy"],
			"home_hint_key": "tut.prep.restrict.home_hint_buy_new",
			"goods_hint_key": "tut.prep.restrict.goods_hint_buy_new",
			"goods_sku_allow": ["can", "snack", "drink"],
		},
	}


## Scenario 5：採購後 → 再買乾／凍櫃貨架與補貨架。
static func _prep_buy_new_furn() -> Dictionary:
	return {
		"id": "tut.prep.buy_new_furn",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": ["tut.prep.buy_new_goods"],
		},
		"pages": [
			_page("tut.prep.buy_new_furn.p1.title", "tut.prep.buy_new_furn.p1.body"),
			_page("tut.prep.buy_new_furn.p2.title", "tut.prep.buy_new_furn.p2.body"),
			_page("tut.prep.buy_new_furn.p3.title", "tut.prep.buy_new_furn.p3.body"),
		],
		"steps": [
			_step("tut.prep.buy_new_furn.s1", 1, "owned_qty", ">=", 1, "tut.prep.buy_new_furn.s2", {"type": "restock_frozen"}),
			_step("tut.prep.buy_new_furn.s2", 2, "owned_qty", ">=", 1, "tut.prep.buy_new_furn.s3", {"type": "shelf_frozen_4"}),
			_step("tut.prep.buy_new_furn.s3", 3, "owned_qty", ">=", 2, "tut.prep.buy_new_furn.s4", {"type": "restock_dry"}),
			_step("tut.prep.buy_new_furn.s4", 4, "owned_qty", ">=", 2, "", {"type": "shelf_dry_4"}),
		],
		"ops_task": {
			"name_key": "tut.prep.buy_new_furn.task.name",
			"desc_key": "tut.prep.buy_new_furn.task.desc",
		},
		"complete_pages": [
			_page("tut.prep.buy_new_furn.done.title", "tut.prep.buy_new_furn.done.body"),
		],
		"prep_restrict": {
			"home_hub_allow": ["hub_shop"],
			"shop_hub_allow": ["furn"],
			"pages_allow": ["home", "hub_shop", "furn"],
			"home_hint_key": "tut.prep.restrict.home_hint_furn_expand",
			"shop_hint_key": "tut.prep.restrict.shop_hint_furn_expand",
			"furn_hint_key": "tut.prep.restrict.furn_hint_expand",
			"furniture_owned_cap": {
				"cashier": 1,
				"restock_dry": 2,
				"restock_frozen": 1,
				"shelf_dry_4": 2,
				"shelf_frozen_4": 1,
			},
		},
	}


## Scenario 5：評價日後 → 買並擺第二台收銀機（開課升規模 2）。
static func _prep_buy_cashier() -> Dictionary:
	return {
		"id": "tut.prep.buy_cashier",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": ["tut.ops.rating"],
		},
		"pages": [
			_page("tut.prep.buy_cashier.p1.title", "tut.prep.buy_cashier.p1.body"),
			_page("tut.prep.buy_cashier.p2.title", "tut.prep.buy_cashier.p2.body"),
			_page("tut.prep.buy_cashier.p3.title", "tut.prep.buy_cashier.p3.body"),
		],
		"steps": [
			_step("tut.prep.buy_cashier.s1", 1, "owned_qty", ">=", 2, "tut.prep.buy_cashier.s2", {"type": "cashier"}),
			_step("tut.prep.buy_cashier.s2", 2, "cashier_count", ">=", 2, ""),
		],
		"ops_task": {
			"name_key": "tut.prep.buy_cashier.task.name",
			"desc_key": "tut.prep.buy_cashier.task.desc",
		},
		"complete_pages": [
			_page("tut.prep.buy_cashier.done.title", "tut.prep.buy_cashier.done.body"),
		],
		"prep_restrict": {
			"home_hub_allow": ["hub_shop"],
			"shop_hub_allow": ["furn", "layout"],
			"pages_allow": ["home", "hub_shop", "furn", "layout"],
			"home_hint_key": "tut.prep.restrict.home_hint_buy_cashier",
			"shop_hint_key": "tut.prep.restrict.shop_hint_buy_cashier",
			"furn_hint_key": "tut.prep.restrict.furn_hint_buy_cashier",
			"furniture_owned_cap": {
				"cashier": 2,
				"restock_dry": 2,
				"restock_frozen": 1,
				"shelf_dry_4": 2,
				"shelf_frozen_4": 1,
			},
		},
	}


## Scenario 5：第二台收銀機後 → 招募一名店員；教學鏈結束。
static func _prep_hire_clerk() -> Dictionary:
	return {
		"id": "tut.prep.hire_clerk",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": ["tut.prep.buy_cashier"],
		},
		"pages": [
			_page("tut.prep.hire_clerk.p1.title", "tut.prep.hire_clerk.p1.body"),
			_page("tut.prep.hire_clerk.p2.title", "tut.prep.hire_clerk.p2.body"),
			_page("tut.prep.hire_clerk.p3.title", "tut.prep.hire_clerk.p3.body"),
			_page("tut.prep.hire_clerk.p4.title", "tut.prep.hire_clerk.p4.body"),
		],
		"steps": [
			_step("tut.prep.hire_clerk.s1", 1, "clerk_count", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.prep.hire_clerk.task.name",
			"desc_key": "tut.prep.hire_clerk.task.desc",
		},
		"complete_pages": [
			_page("tut.prep.hire_clerk.done.title", "tut.prep.hire_clerk.done.body"),
		],
		"prep_restrict": {
			"home_hub_allow": ["clerks"],
			"pages_allow": ["home", "clerks"],
			"home_hint_key": "tut.prep.restrict.home_hint_clerks",
		},
	}


## Scenario 5：購入後 → 擺齊新家具並設互異補貨預設。
static func _prep_layout_expand() -> Dictionary:
	return {
		"id": "tut.prep.layout_expand",
		"phase": "prep",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"requires_done": ["tut.prep.buy_new_furn"],
		},
		"pages": [
			_page("tut.prep.layout_expand.p1.title", "tut.prep.layout_expand.p1.body"),
			_page("tut.prep.layout_expand.p2.title", "tut.prep.layout_expand.p2.body"),
			_page("tut.prep.layout_expand.p3.title", "tut.prep.layout_expand.p3.body"),
		],
		"steps": [
			_step("tut.prep.layout_expand.s1", 1, "unplaced_qty", "==", 0, "tut.prep.layout_expand.s2"),
			_step("tut.prep.layout_expand.s2", 2, "restock_defaults_distinct", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.prep.layout_expand.task.name",
			"desc_key": "tut.prep.layout_expand.task.desc",
		},
		"complete_pages": [
			_page("tut.prep.layout_expand.done.title", "tut.prep.layout_expand.done.body"),
		],
		"prep_restrict": {
			"home_hub_allow": ["hub_shop"],
			"shop_hub_allow": ["layout"],
			"pages_allow": ["home", "hub_shop", "layout"],
			"home_hint_key": "tut.prep.restrict.home_hint_layout_expand",
			"shop_hint_key": "tut.prep.restrict.shop_hint",
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


## Scenario 5：捉賊完成後 → 交付客人三次。
static func _ops_deliver() -> Dictionary:
	return {
		"id": "tut.ops.deliver",
		"phase": "ops",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"day_index": 0,
			"requires_done": ["tut.ops.thief"],
		},
		"pages": [
			_page("tut.ops.deliver.p1.title", "tut.ops.deliver.p1.body"),
			_page("tut.ops.deliver.p2.title", "tut.ops.deliver.p2.body"),
			_page("tut.ops.deliver.p3.title", "tut.ops.deliver.p3.body"),
		],
		"steps": [
			_step("tut.ops.deliver.s1", 1, "deliver_count", ">=", 3, ""),
		],
		"ops_task": {
			"name_key": "tut.ops.deliver.task.name",
			"desc_key": "tut.ops.deliver.task.desc",
		},
		"complete_pages": [
			_page("tut.ops.deliver.done.title", "tut.ops.deliver.done.body"),
		],
	}


## Scenario 5：交付完成後 → 自由營業直到本日結算。
static func _ops_finish_day() -> Dictionary:
	return {
		"id": "tut.ops.finish_day",
		"phase": "ops",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"day_index": 0,
			"requires_done": ["tut.ops.deliver"],
		},
		"pages": [
			_page("tut.ops.finish_day.p1.title", "tut.ops.finish_day.p1.body"),
			_page("tut.ops.finish_day.p2.title", "tut.ops.finish_day.p2.body"),
			_page("tut.ops.finish_day.p3.title", "tut.ops.finish_day.p3.body"),
		],
		"steps": [
			_step("tut.ops.finish_day.s1", 1, "day_settled", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.ops.finish_day.task.name",
			"desc_key": "tut.ops.finish_day.task.desc",
		},
		"complete_pages": [
			_page("tut.ops.finish_day.done.title", "tut.ops.finish_day.done.body"),
		],
		## Must not hard-gate settle — completing the day is the step.
		"allow_settle": true,
	}


## Scenario 5：第二日營運 → 主動 5 次＋奧義 1 次後自由營業。
static func _ops_use_skills() -> Dictionary:
	return {
		"id": "tut.ops.use_skills",
		"phase": "ops",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"day_index": 1,
			"requires_done": ["tut.prep.equip_skills"],
		},
		"pages": [
			_page("tut.ops.use_skills.p1.title", "tut.ops.use_skills.p1.body"),
			_page("tut.ops.use_skills.p2.title", "tut.ops.use_skills.p2.body"),
			_page("tut.ops.use_skills.p3.title", "tut.ops.use_skills.p3.body"),
			_page("tut.ops.use_skills.p4.title", "tut.ops.use_skills.p4.body"),
		],
		"steps": [
			_step("tut.ops.use_skills.s1", 1, "skill_cast", ">=", 5, "tut.ops.use_skills.s2"),
			_step("tut.ops.use_skills.s2", 2, "ult_cast", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.ops.use_skills.task.name",
			"desc_key": "tut.ops.use_skills.task.desc",
		},
		"complete_pages": [
			_page("tut.ops.use_skills.done.title", "tut.ops.use_skills.done.body"),
		],
	}


## Scenario 5：開發商品鏈後第三日 → 評價點數＋OP-TUT-001 練習；結算即結課。
static func _ops_rating() -> Dictionary:
	return {
		"id": "tut.ops.rating",
		"phase": "ops",
		"trigger": {
			"when": "scenario",
			"scenario": 5,
			"day_index": 2,
			"requires_done": ["tut.prep.layout_expand"],
		},
		"pages": [
			_page("tut.ops.rating.p1.title", "tut.ops.rating.p1.body"),
			_page("tut.ops.rating.p2.title", "tut.ops.rating.p2.body"),
			_page("tut.ops.rating.p3.title", "tut.ops.rating.p3.body"),
			_page("tut.ops.rating.p4.title", "tut.ops.rating.p4.body"),
			_page("tut.ops.rating.p5.title", "tut.ops.rating.p5.body"),
			_page("tut.ops.rating.p6.title", "tut.ops.rating.p6.body"),
		],
		## First guest during this lesson → interrupt tip (not a separate Lesson).
		"perfect_deliver_pages": [
			_page("tut.ops.rating.perfect.p1.title", "tut.ops.rating.perfect.p1.body"),
			_page("tut.ops.rating.perfect.p2.title", "tut.ops.rating.perfect.p2.body"),
		],
		"steps": [
			_step("tut.ops.rating.s1", 1, "day_settled", ">=", 1, ""),
		],
		"ops_task": {
			"name_key": "tut.ops.rating.task.name",
			"desc_key": "tut.ops.rating.task.desc",
		},
		"complete_pages": [
			_page("tut.ops.rating.done.title", "tut.ops.rating.done.body"),
		],
		## Practice pack is soft; settle anytime completes the lesson.
		"allow_settle": true,
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
