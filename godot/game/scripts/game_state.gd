extends RefCounted
## Prep-phase progress. Persist with to_dict / save_to_disk via PlatformServices.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")

## Bump when the save schema changes; from_dict must migrate or reject.
const SAVE_VERSION := 1

const CELL := 64.0
const WAGE := 100
const XP_CLOSE := 100
const XP_SERVE := 2
const XP_CATCH := 10
const XP_CLEAN := 5
## Extra XP when a 麻煩客人（EliteCustomer）is successfully checked out.
const XP_ELITE_SERVE := 10
const SCALE_MAX := {1: 10, 2: 15, 3: 20}
const SCALE_COST := {2: 3000, 3: 6000}
const SCALE_NEED_LV := {2: 4, 3: 7}
const HIRE_CAP := {1: 0, 2: 1, 3: 2}

const FURNITURE := {
	"cashier": {"name": "收銀機", "price": 1000, "w": 2, "h": 1, "unlock": 1},
	"restock_dry": {"name": "乾貨補貨架", "price": 500, "w": 2, "h": 2, "unlock": 1},
	"restock_frozen": {"name": "凍櫃補貨架", "price": 700, "w": 2, "h": 2, "unlock": 4},
	"restock_ice": {"name": "冰櫃補貨架", "price": 800, "w": 2, "h": 2, "unlock": 7},
	"shelf_dry_4": {"name": "乾貨類貨架（4件）", "price": 40, "w": 2, "h": 1, "unlock": 1, "cap": 4},
	"shelf_dry_8": {"name": "乾貨類貨架（8件）", "price": 70, "w": 2, "h": 1, "unlock": 1, "cap": 8},
	"shelf_dry_12": {"name": "乾貨類貨架（12件）", "price": 100, "w": 2, "h": 1, "unlock": 1, "cap": 12},
	"shelf_dry_24": {"name": "乾貨類貨架（24件）", "price": 200, "w": 2, "h": 1, "unlock": 1, "cap": 24},
	"shelf_frozen_4": {"name": "凍櫃類貨架（4件）", "price": 70, "w": 2, "h": 1, "unlock": 4, "cap": 4},
	"shelf_frozen_8": {"name": "凍櫃類貨架（8件）", "price": 130, "w": 2, "h": 1, "unlock": 4, "cap": 8},
	"shelf_frozen_12": {"name": "凍櫃類貨架（12件）", "price": 200, "w": 2, "h": 1, "unlock": 4, "cap": 12},
	"shelf_frozen_24": {"name": "凍櫃類貨架（24件）", "price": 400, "w": 2, "h": 1, "unlock": 4, "cap": 24},
	"shelf_ice_4": {"name": "冰櫃類貨架（4件）", "price": 100, "w": 2, "h": 1, "unlock": 7, "cap": 4},
	"shelf_ice_8": {"name": "冰櫃類貨架（8件）", "price": 200, "w": 2, "h": 1, "unlock": 7, "cap": 8},
	"shelf_ice_12": {"name": "冰櫃類貨架（12件）", "price": 300, "w": 2, "h": 1, "unlock": 7, "cap": 12},
	"shelf_ice_24": {"name": "冰櫃類貨架（24件）", "price": 600, "w": 2, "h": 1, "unlock": 7, "cap": 24},
}

var scenario: int = 1
var money: int = 10000
var xp: int = 0
var level: int = 1
var unspent: int = 0
var base_str: int = 10
var base_agi: int = 10
var base_int: int = 10
var str_stat: int = 10
var agi_stat: int = 10
var int_stat: int = 10
var developed: Dictionary = {}
var stock: Dictionary = {}
var owned: Dictionary = {}
var placed: Array[Dictionary] = []
var shop_scale: int = 1
var grid_w: int = 10
var grid_h: int = 10
var clerks: Array[Dictionary] = []
## Selected set, mirrored for older readers. Source of truth is skill_sets.
var slots: Array[String] = ["", "", "", "", ""]
var ult_id: String = "the_world"
## Five saved loadouts. Each is {name, slots, ult_id}. ult_id "" means no ultimate.
const SKILL_SET_COUNT := 5
const SKILL_NAME_MAX := 10
var skill_sets: Array[Dictionary] = []
var skill_set_index: int = 0
var day_procurement: int = 0
var last_loss: bool = false
var level_note: String = ""


func _init() -> void:
	_install_new_game_sets()


func apply_scenario(id: int) -> void:
	scenario = id
	developed.clear()
	stock.clear()
	owned.clear()
	placed.clear()
	clerks.clear()
	day_procurement = 0
	last_loss = false
	level_note = ""
	_install_new_game_sets()
	match id:
		2:
			_scenario_mid()
		3:
			_scenario_late()
		4:
			_scenario_skill()
		_:
			_scenario_new()
	_grant_initial_goods()


func _grant_initial_goods() -> void:
	developed["can"] = true
	if not stock.has("can"):
		stock["can"] = 0


func _scenario_new() -> void:
	money = 10000
	level = 1
	xp = 0
	unspent = 0
	base_str = 10
	base_agi = 10
	base_int = 10
	str_stat = 10
	agi_stat = 10
	int_stat = 10
	shop_scale = 1
	grid_w = 10
	grid_h = 10


func _scenario_mid() -> void:
	money = 10000
	level = 5
	xp = 0
	unspent = 20
	base_str = 10
	base_agi = 10
	base_int = 10
	str_stat = 10
	agi_stat = 10
	int_stat = 10
	shop_scale = 2
	grid_w = 15
	grid_h = 15
	for sku in ["can", "snack", "cup", "drink", "milk"]:
		developed[sku] = true
		stock[sku] = 50
	owned = {"cashier": 1, "restock_dry": 1, "restock_frozen": 1, "shelf_dry_12": 2, "shelf_frozen_12": 2}
	_place("restock_frozen", 1, 1, 0)
	_place("restock_dry", 1, 5, 0)
	_place("shelf_frozen_12", 5, 2, 0)
	_place("shelf_frozen_12", 8, 2, 0)
	_place("shelf_dry_12", 5, 6, 0)
	_place("shelf_dry_12", 8, 6, 0)
	_place("cashier", 10, 12, 0)
	clerks.append({"role": "restock", "register": 0})


func _scenario_late() -> void:
	money = 99999
	level = 10
	xp = 0
	unspent = 20
	base_str = 10
	base_agi = 10
	base_int = 10
	str_stat = 30
	agi_stat = 30
	int_stat = 30
	shop_scale = 3
	grid_w = 20
	grid_h = 20
	for sku in Tuning.SELLABLE_SKUS:
		developed[sku] = true
		stock[sku] = 99
	owned = {
		"cashier": 2,
		"restock_dry": 1, "restock_frozen": 1, "restock_ice": 1,
		"shelf_dry_12": 2, "shelf_frozen_12": 2, "shelf_ice_12": 2,
	}
	_place("restock_ice", 1, 1, 0)
	_place("restock_frozen", 1, 4, 0)
	_place("restock_dry", 1, 7, 0)
	_place("shelf_ice_12", 5, 1, 0)
	_place("shelf_ice_12", 8, 1, 0)
	_place("shelf_frozen_12", 5, 4, 0)
	_place("shelf_frozen_12", 8, 4, 0)
	_place("shelf_dry_12", 5, 8, 0)
	_place("shelf_dry_12", 8, 8, 0)
	_place("cashier", 14, 16, 0)
	_place("cashier", 14, 18, 0)
	clerks.append({"role": "cashier", "register": 0})
	clerks.append({"role": "restock", "register": 0})


## Skill sandbox. LV10 budget is 45 points (9 level-ups × 5).
## Stats sit at 20 (30 points spent from base 10); 15 stay unspent.
## Every shop item is owned twice. The floor is 18×10 so a round can start:
## two cashiers beside the door, two frozen restock racks on the left,
## two dry restock racks on the right, and a matching pair of 12-slot shelves
## for each of those categories (the open check needs a shelf with its restock).
func _scenario_skill() -> void:
	money = 99999
	level = 10
	xp = 0
	unspent = 15
	base_str = 10
	base_agi = 10
	base_int = 10
	str_stat = 20
	agi_stat = 20
	int_stat = 20
	shop_scale = 3
	grid_w = 18
	grid_h = 10
	for sku in ["can", "snack", "drink", "milk"]:
		developed[sku] = true
		stock[sku] = 50
	for type in FURNITURE.keys():
		owned[type] = 2
	# Door is cells (8,0) and (9,0). Cashiers sit on that row, one cell away.
	_place("cashier", 6, 0, 0)
	_place("cashier", 10, 0, 0)
	_place("restock_frozen", 0, 2, 0)
	_place("restock_frozen", 0, 5, 0)
	_place("restock_dry", 16, 2, 0)
	_place("restock_dry", 16, 5, 0)
	_place("shelf_frozen_12", 4, 3, 0)
	_place("shelf_frozen_12", 4, 6, 0)
	_place("shelf_dry_12", 12, 3, 0)
	_place("shelf_dry_12", 12, 6, 0)
	clerks.append({"role": "restock", "register": 0})
	clerks.append({"role": "cashier", "register": 0})


func _place(type: String, x: int, y: int, rot: int) -> void:
	var fp := footprint(type, rot)
	placed.append({"type": type, "x": x, "y": y, "rot": rot, "w": fp.x, "h": fp.y})


func xp_to_next() -> int:
	if level >= 10:
		return 0
	return _xp_need(level + 1)


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


func spend_point(stat: String, delta: int) -> String:
	if delta > 0:
		if unspent <= 0:
			return "沒有未分配點數"
		unspent -= 1
		_add_stat(stat, 1)
		return ""
	if _stat_value(stat) <= _base_value(stat):
		return "不能低於本劇本基底"
	unspent += 1
	_add_stat(stat, -1)
	return ""


func reset_stats_cost() -> int:
	return maxi(1, level) * Tuning.STAT_RESET_FEE_PER_LEVEL


## Returns "" on success, or an error message (e.g. not enough money).
func reset_stats() -> String:
	var fee := reset_stats_cost()
	if money < fee:
		return "重置能力值要 $%d，現有 $%d" % [fee, money]
	money -= fee
	var spent := (str_stat - base_str) + (agi_stat - base_agi) + (int_stat - base_int)
	unspent += spent
	str_stat = base_str
	agi_stat = base_agi
	int_stat = base_int
	return ""


func _add_stat(stat: String, n: int) -> void:
	match stat:
		"agi":
			agi_stat += n
		"int":
			int_stat += n
		_:
			str_stat += n


func _stat_value(stat: String) -> int:
	match stat:
		"agi": return agi_stat
		"int": return int_stat
		_: return str_stat


func _base_value(stat: String) -> int:
	match stat:
		"agi": return base_agi
		"int": return base_int
		_: return base_str


func sku_unlocked(sku: String) -> bool:
	return level >= int(Tuning.SKU_UNLOCK_LV.get(sku, 99))


func develop(sku: String) -> String:
	if sku == "can":
		developed["can"] = true
		if not stock.has("can"):
			stock["can"] = 0
		return "罐頭是初始貨物，不用開發"
	if developed.has(sku):
		return "已開發"
	if not sku_unlocked(sku):
		return "未到開放等級"
	var fee := int(Tuning.SKU_DEVELOP.get(sku, 0))
	if money < fee:
		return "資金不足"
	money -= fee
	developed[sku] = true
	if not stock.has(sku):
		stock[sku] = 0
	return ""


func buy_stock(sku: String, boxes: int) -> String:
	if not developed.has(sku):
		return "尚未開發"
	boxes = clampi(boxes, 1, 99)
	var cost := int(Tuning.SKU_COST.get(sku, 0)) * boxes
	if money < cost:
		return "資金不足"
	money -= cost
	stock[sku] = int(stock.get(sku, 0)) + boxes
	day_procurement += cost
	return ""


func consume_box(sku: String) -> bool:
	if int(stock.get(sku, 0)) <= 0:
		return false
	stock[sku] = int(stock[sku]) - 1
	return true


## Credit unsold shop pieces back to warehouse boxes at closeout.
## `pieces_by_sku` maps sku → piece count (shelf + floor aggregate).
## Remainders round up so leftover pieces are not discarded (`ceil(n / BOX_SIZE)`).
## Returns total boxes added.
func credit_unsold_pieces(pieces_by_sku: Dictionary) -> int:
	var total := 0
	for sku_v in pieces_by_sku.keys():
		var sku := String(sku_v)
		var pieces := int(pieces_by_sku[sku_v])
		if sku == "" or pieces <= 0:
			continue
		var boxes := (pieces + Tuning.BOX_SIZE - 1) / Tuning.BOX_SIZE
		stock[sku] = int(stock.get(sku, 0)) + boxes
		total += boxes
	return total


func furniture_unlocked(type: String) -> bool:
	return level >= int(FURNITURE[type]["unlock"])


func buy_furniture(type: String) -> String:
	if not FURNITURE.has(type):
		return "沒有這件"
	if not furniture_unlocked(type):
		return "未到開放等級"
	var price := int(FURNITURE[type]["price"])
	if money < price:
		return "資金不足"
	money -= price
	owned[type] = int(owned.get(type, 0)) + 1
	return ""


func unplaced(type: String) -> int:
	return int(owned.get(type, 0)) - placed_count(type)


func placed_count(type: String) -> int:
	var n := 0
	for it in placed:
		if String(it["type"]) == type:
			n += 1
	return n


func footprint(type: String, rot: int) -> Vector2i:
	var w := int(FURNITURE[type]["w"])
	var h := int(FURNITURE[type]["h"])
	if rot % 2 == 1:
		return Vector2i(h, w)
	return Vector2i(w, h)


func door_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x0 := maxi(0, grid_w / 2 - 1)
	out.append(Vector2i(x0, 0))
	if x0 + 1 < grid_w:
		out.append(Vector2i(x0 + 1, 0))
	return out


func can_place(type: String, x: int, y: int, rot: int, ignore: int = -1) -> bool:
	if unplaced(type) <= 0 and ignore < 0:
		return false
	var fp := footprint(type, rot)
	if x < 0 or y < 0 or x + fp.x > grid_w or y + fp.y > grid_h:
		return false
	var blocked := door_cells()
	for cy in fp.y:
		for cx in fp.x:
			if Vector2i(x + cx, y + cy) in blocked:
				return false
	var rect := Rect2i(x, y, fp.x, fp.y)
	for i in placed.size():
		if i == ignore:
			continue
		var it: Dictionary = placed[i]
		var other := Rect2i(int(it["x"]), int(it["y"]), int(it["w"]), int(it["h"]))
		if rect.intersects(other):
			return false
	return true


func place_item(type: String, x: int, y: int, rot: int) -> String:
	if not can_place(type, x, y, rot):
		return "放不下"
	var fp := footprint(type, rot)
	placed.append({"type": type, "x": x, "y": y, "rot": rot, "w": fp.x, "h": fp.y})
	return ""


func move_item(index: int, x: int, y: int, rot: int) -> String:
	if index < 0 or index >= placed.size():
		return "放不下"
	var type := String(placed[index]["type"])
	if not can_place(type, x, y, rot, index):
		return "放不下"
	var fp := footprint(type, rot)
	placed[index]["x"] = x
	placed[index]["y"] = y
	placed[index]["rot"] = rot
	placed[index]["w"] = fp.x
	placed[index]["h"] = fp.y
	return ""


func remove_at(index: int) -> void:
	if index >= 0 and index < placed.size():
		placed.remove_at(index)


func item_at(x: int, y: int) -> int:
	for i in placed.size():
		var it: Dictionary = placed[i]
		var r := Rect2i(int(it["x"]), int(it["y"]), int(it["w"]), int(it["h"]))
		if r.has_point(Vector2i(x, y)):
			return i
	return -1


func area_cap() -> int:
	var side := int(SCALE_MAX[shop_scale])
	return side * side


func set_grid(w: int, h: int) -> String:
	if w < 8 or h < 8:
		return "闊度和長度最少是 8。"
	if w * h > area_cap():
		return "總面積超過規模上限"
	for it in placed:
		if int(it["x"]) + int(it["w"]) > w or int(it["y"]) + int(it["h"]) > h:
			return "有傢俬在新邊界外，先收回"
	grid_w = w
	grid_h = h
	return ""


func expand() -> String:
	if shop_scale >= 3:
		return "已是最大規模"
	var nxt := shop_scale + 1
	if level < int(SCALE_NEED_LV[nxt]):
		return "角色要到 LV%d" % int(SCALE_NEED_LV[nxt])
	var price := int(SCALE_COST[nxt])
	if money < price:
		return "資金不足"
	money -= price
	shop_scale = nxt
	grid_w = int(SCALE_MAX[nxt])
	grid_h = int(SCALE_MAX[nxt])
	return ""


func cashier_count() -> int:
	return placed_count("cashier")


## Reasons the operate round cannot start. Empty means the layout is ready.
## A pair is one placed restock point plus one placed shelf of the same category.
func open_blockers() -> PackedStringArray:
	var out: PackedStringArray = []
	if cashier_count() < 1:
		out.append("店舖內要放置至少一台收銀機。")
	if not _has_matching_pair():
		out.append("店舖內要放置至少一組同類型的補貨架和貨架。乾貨、凍櫃、冰櫃都可以，但補貨架和貨架要同一類。")
	return out


func shelf_capacity(type: String) -> int:
	if FURNITURE.has(type) and FURNITURE[type].has("cap"):
		return int(FURNITURE[type]["cap"])
	return Tuning.SHELF_CAP


func _furn_category(type: String) -> String:
	if type.contains("frozen"):
		return Tuning.CAT_FROZEN
	if type.contains("ice"):
		return Tuning.CAT_ICE
	if type.contains("dry"):
		return Tuning.CAT_DRY
	return ""


func _has_matching_pair() -> bool:
	var restock := {}
	var shelf := {}
	for it in placed:
		var t := String(it["type"])
		var cat := _furn_category(t)
		if cat == "":
			continue
		if t.begins_with("restock"):
			restock[cat] = true
		elif t.begins_with("shelf"):
			shelf[cat] = true
	for cat in restock.keys():
		if shelf.has(cat):
			return true
	return false


func hire_limit() -> int:
	return mini(int(HIRE_CAP.get(shop_scale, 0)), cashier_count())


func hire() -> String:
	if clerks.size() >= int(HIRE_CAP.get(shop_scale, 0)):
		return "店舖規模雇員已滿"
	if clerks.size() >= cashier_count():
		return "店員不能多過收銀機"
	clerks.append({"role": "restock", "register": 0})
	return ""


func fire(index: int) -> void:
	if index >= 0 and index < clerks.size():
		clerks.remove_at(index)


func cycle_role(index: int) -> void:
	if index < 0 or index >= clerks.size():
		return
	clerks[index]["role"] = "cashier" if String(clerks[index]["role"]) == "restock" else "restock"


func cycle_register(index: int) -> void:
	if index < 0 or index >= clerks.size():
		return
	var n := maxi(1, cashier_count())
	clerks[index]["register"] = (int(clerks[index]["register"]) + 1) % n


func default_skill_set_name(i: int) -> String:
	return "自訂技能組合%d" % [i + 1]


func skill_set_name(i: int) -> String:
	if i < 0 or i >= skill_sets.size():
		return ""
	return String(skill_sets[i].get("name", ""))


func skill_set_name_is_custom(set_name: String) -> bool:
	return _is_english_letters(set_name) and set_name.length() <= SKILL_NAME_MAX and set_name.length() > 0


func equip(slot_i: int, skill_id: String) -> String:
	return equip_set(skill_set_index, slot_i, skill_id)


func equip_set(set_i: int, slot_i: int, skill_id: String) -> String:
	if set_i < 0 or set_i >= skill_sets.size():
		return ""
	var sk := Skills.by_id(skill_id)
	if sk.is_empty():
		return "沒有這招"
	var pack: Dictionary = skill_sets[set_i]
	if slot_i == 5:
		if String(sk.get("kind")) != "ultimate":
			return "奧義格只能放奧義"
		if String(pack.get("ult_id", "")) == skill_id:
			return ""
		pack["ult_id"] = skill_id
		_after_set_edit(set_i)
		return ""
	if String(sk.get("kind")) == "ultimate":
		return "奧義要放奧義格"
	if slot_i < 0 or slot_i > 4:
		return ""
	var set_slots: Array = pack["slots"]
	for i in set_slots.size():
		if i != slot_i and String(set_slots[i]) == skill_id:
			return "已經裝備在別格"
	if String(set_slots[slot_i]) == skill_id:
		return ""
	var prev := String(set_slots[slot_i])
	set_slots[slot_i] = skill_id
	if _cost_of_ids(set_slots) > 5:
		set_slots[slot_i] = prev
		return "COST 超過 5"
	_after_set_edit(set_i)
	return ""


func unequip(slot_i: int) -> void:
	unequip_set(skill_set_index, slot_i)


func unequip_set(set_i: int, slot_i: int) -> void:
	if set_i < 0 or set_i >= skill_sets.size():
		return
	var pack: Dictionary = skill_sets[set_i]
	if slot_i == 5:
		if String(pack.get("ult_id", "")) == "":
			return
		pack["ult_id"] = ""
		_after_set_edit(set_i)
		return
	if slot_i < 0 or slot_i > 4:
		return
	var set_slots: Array = pack["slots"]
	if String(set_slots[slot_i]) == "":
		return
	set_slots[slot_i] = ""
	_after_set_edit(set_i)


func select_skill_set(set_i: int) -> void:
	if set_i < 0 or set_i >= skill_sets.size():
		return
	if set_i == skill_set_index:
		return
	skill_set_index = set_i
	_mirror_selected()
	_persist_skill_edit()


func rename_skill_set(set_i: int, raw: String) -> String:
	if set_i < 0 or set_i >= skill_sets.size():
		return ""
	var trimmed := raw.strip_edges()
	var set_name := trimmed
	if set_name == "":
		set_name = default_skill_set_name(set_i)
	else:
		if not _is_english_letters(set_name) or set_name.length() > SKILL_NAME_MAX:
			return "名稱只用英文字母，最多 10 個"
		var folded := set_name.to_lower()
		for i in skill_sets.size():
			if i == set_i:
				continue
			if String(skill_sets[i].get("name", "")).to_lower() == folded:
				return "名稱已被使用"
	if String(skill_sets[set_i].get("name", "")) == set_name:
		return ""
	skill_sets[set_i]["name"] = set_name
	_persist_skill_edit()
	return ""


func cost_sum() -> int:
	return cost_sum_of(skill_set_index)


func cost_sum_of(set_i: int) -> int:
	if set_i < 0 or set_i >= skill_sets.size():
		return 0
	return _cost_of_ids(skill_sets[set_i].get("slots", []))


func loadout() -> Array[Dictionary]:
	var levels := _levels_of(skill_set_index)
	var out: Array[Dictionary] = []
	for id in slots:
		if id == "":
			out.append({})
		else:
			out.append(_with_chosen_level(Skills.by_id(id), levels))
	return out


## Dark Side is the only skill whose level is chosen on the prep page.
## Missing choice means LV3. Other skills keep the catalog level.
func skill_level_of(set_i: int, skill_id: String) -> int:
	var sk := Skills.by_id(skill_id)
	var fallback := 3 if bool(sk.get("dark_side", false)) else int(sk.get("lv", 1))
	var levels := _levels_of(set_i)
	if not levels.has(skill_id):
		return fallback
	return clampi(int(levels[skill_id]), 1, 3)


func set_skill_level(set_i: int, skill_id: String, lv: int) -> void:
	var sk := Skills.by_id(skill_id)
	if sk.is_empty() or not bool(sk.get("dark_side", false)):
		return
	if set_i < 0 or set_i >= skill_sets.size():
		return
	var pack: Dictionary = skill_sets[set_i]
	var levels: Dictionary = pack.get("levels", {})
	if not (levels is Dictionary):
		levels = {}
	levels[skill_id] = clampi(lv, 1, 3)
	pack["levels"] = levels
	_persist_skill_edit()


func _levels_of(set_i: int) -> Dictionary:
	if set_i < 0 or set_i >= skill_sets.size():
		return {}
	var raw = skill_sets[set_i].get("levels", {})
	if raw is Dictionary:
		return raw
	return {}


func _with_chosen_level(sk: Dictionary, levels: Dictionary) -> Dictionary:
	if sk.is_empty() or not bool(sk.get("dark_side", false)):
		return sk
	var id := String(sk.get("id"))
	var lv := 3
	if levels.has(id):
		lv = clampi(int(levels[id]), 1, 3)
	sk["lv"] = lv
	return sk


func ult_skill() -> Dictionary:
	return ult_of(skill_set_index)


## Empty dictionary means this set has no ultimate. Unknown ids still fall back to The World!.
func ult_of(set_i: int) -> Dictionary:
	if set_i < 0 or set_i >= skill_sets.size():
		return {}
	var id := String(skill_sets[set_i].get("ult_id", ""))
	if id == "":
		return {}
	var sk := Skills.by_id(id)
	if sk.is_empty() or String(sk.get("kind")) != "ultimate":
		return Skills.ULTIMATE
	return sk


func has_flag(flag: String) -> bool:
	for sk in loadout():
		if bool(sk.get(flag, false)):
			return true
	return false


func thief_spawn_rate() -> float:
	for sk in loadout():
		if sk.has("thief_rate"):
			return float(sk["thief_rate"])
	return 1.0


func begin_day() -> String:
	var blocks := open_blockers()
	if not blocks.is_empty():
		return "\n".join(blocks)
	var wage := WAGE * clerks.size()
	money -= wage
	return ""


func settle(
	revenue: int,
	served: int,
	caught: int,
	cleaned: int,
	bonus_xp: int = 0,
	elite_served: int = 0,
) -> Dictionary:
	var gain_xp := (
		XP_CLOSE
		+ served * XP_SERVE
		+ caught * XP_CATCH
		+ cleaned * XP_CLEAN
		+ elite_served * XP_ELITE_SERVE
		+ bonus_xp
	)
	xp += gain_xp
	var ups := 0
	while level < 10:
		var need := _xp_need(level + 1)
		if need <= 0 or xp < need:
			break
		xp -= need
		level += 1
		unspent += 5
		ups += 1
	money += revenue
	last_loss = revenue < day_procurement
	var note := ""
	if ups > 0:
		note = "升級 %d 級，未分配點數 +%d" % [ups, ups * 5]
	if level >= 10:
		note += "  LV10 之後經驗表未定，不再升級"
	level_note = note
	var loss := last_loss
	var spent := day_procurement
	day_procurement = 0
	return {"xp": gain_xp, "ups": ups, "loss": loss, "spent": spent, "wage_note": note}


func developed_of(category: String) -> Array[String]:
	var out: Array[String] = []
	for sku in Tuning.skus_for(category):
		if developed.has(sku):
			out.append(sku)
	return out


func guest_cap() -> int:
	return 15 if scenario == 3 else 10


func spawn_every() -> float:
	return 5.0 if scenario == 3 else 10.0


func customer_list_min() -> int:
	return 1 if scenario == 1 else Tuning.LIST_MIN


func customer_list_max() -> int:
	return 3 if scenario == 1 else Tuning.LIST_MAX


func dirt_spawn_sec() -> float:
	return Tuning.DIRT_SPAWN_SEC * 2.0 if scenario == 1 else Tuning.DIRT_SPAWN_SEC


func thief_spawn_first() -> float:
	return Tuning.THIEF_SPAWN_FIRST * 2.0 if scenario == 1 else Tuning.THIEF_SPAWN_FIRST


func thief_spawn_sec() -> float:
	return Tuning.THIEF_SPAWN_SEC * 2.0 if scenario == 1 else Tuning.THIEF_SPAWN_SEC


func sellable() -> Array[String]:
	var out: Array[String] = []
	for sku in Tuning.SELLABLE_SKUS:
		if developed.has(sku):
			out.append(sku)
	return out


func to_dict() -> Dictionary:
	if skill_sets.is_empty():
		_install_new_game_sets()
	_mirror_selected()
	var slot_list: Array = []
	for id in slots:
		slot_list.append(String(id))
	var placed_list: Array = []
	for it in placed:
		placed_list.append({
			"type": String(it.get("type", "")),
			"x": int(it.get("x", 0)),
			"y": int(it.get("y", 0)),
			"rot": int(it.get("rot", 0)),
			"w": int(it.get("w", 1)),
			"h": int(it.get("h", 1)),
		})
	var clerk_list: Array = []
	for c in clerks:
		clerk_list.append({
			"role": String(c.get("role", "restock")),
			"register": int(c.get("register", 0)),
		})
	return {
		"version": SAVE_VERSION,
		"scenario": scenario,
		"money": money,
		"xp": xp,
		"level": level,
		"unspent": unspent,
		"base_str": base_str,
		"base_agi": base_agi,
		"base_int": base_int,
		"str_stat": str_stat,
		"agi_stat": agi_stat,
		"int_stat": int_stat,
		"developed": developed.duplicate(true),
		"stock": stock.duplicate(true),
		"owned": owned.duplicate(true),
		"placed": placed_list,
		"shop_scale": shop_scale,
		"grid_w": grid_w,
		"grid_h": grid_h,
		"clerks": clerk_list,
		"slots": slot_list,
		"ult_id": ult_id,
		"skill_sets": _skill_sets_for_save(),
		"skill_set_index": skill_set_index,
		"day_procurement": day_procurement,
		"last_loss": last_loss,
		"level_note": level_note,
	}


## Empty string means ok; otherwise a human-readable error.
func from_dict(data: Dictionary) -> String:
	if data.is_empty():
		return "存檔是空的"
	if not data.has("version"):
		return "存檔缺少 version"
	var ver := int(data["version"])
	if ver < 1:
		return "存檔 version 無效"
	if ver > SAVE_VERSION:
		return "存檔版本過新（%d > %d），請更新遊戲" % [ver, SAVE_VERSION]
	scenario = int(data.get("scenario", 1))
	money = int(data.get("money", 0))
	xp = int(data.get("xp", 0))
	level = clampi(int(data.get("level", 1)), 1, 99)
	unspent = maxi(0, int(data.get("unspent", 0)))
	base_str = int(data.get("base_str", 10))
	base_agi = int(data.get("base_agi", 10))
	base_int = int(data.get("base_int", 10))
	str_stat = int(data.get("str_stat", base_str))
	agi_stat = int(data.get("agi_stat", base_agi))
	int_stat = int(data.get("int_stat", base_int))
	developed = _string_bool_dict(data.get("developed", {}))
	stock = _string_int_dict(data.get("stock", {}))
	owned = _string_int_dict(data.get("owned", {}))
	placed.clear()
	var raw_placed = data.get("placed", [])
	if raw_placed is Array:
		for it in raw_placed:
			if not (it is Dictionary):
				continue
			var d: Dictionary = it
			var t := String(d.get("type", ""))
			if t == "" or not FURNITURE.has(t):
				continue
			var rot := int(d.get("rot", 0))
			var fp := footprint(t, rot)
			placed.append({
				"type": t,
				"x": int(d.get("x", 0)),
				"y": int(d.get("y", 0)),
				"rot": rot,
				"w": int(d.get("w", fp.x)),
				"h": int(d.get("h", fp.y)),
			})
	shop_scale = clampi(int(data.get("shop_scale", 1)), 1, 3)
	grid_w = maxi(8, int(data.get("grid_w", 10)))
	grid_h = maxi(8, int(data.get("grid_h", 10)))
	clerks.clear()
	var raw_clerks = data.get("clerks", [])
	if raw_clerks is Array:
		for c in raw_clerks:
			if not (c is Dictionary):
				continue
			var role := String(c.get("role", "restock"))
			if role != "cashier" and role != "restock":
				role = "restock"
			clerks.append({"role": role, "register": maxi(0, int(c.get("register", 0)))})
	var loaded_slots: Array[String] = ["", "", "", "", ""]
	var raw_slots = data.get("slots", [])
	if raw_slots is Array:
		for i in mini(5, raw_slots.size()):
			loaded_slots[i] = String(raw_slots[i])
	var loaded_ult := _sanitize_ult_id(String(data.get("ult_id", "the_world")))
	if not _load_skill_sets(data.get("skill_sets", null)):
		_migrate_single_loadout(loaded_slots, loaded_ult)
		skill_set_index = 0
	else:
		skill_set_index = clampi(int(data.get("skill_set_index", 0)), 0, SKILL_SET_COUNT - 1)
	_repair_set_names()
	_mirror_selected()
	day_procurement = maxi(0, int(data.get("day_procurement", 0)))
	last_loss = bool(data.get("last_loss", false))
	level_note = String(data.get("level_note", ""))
	_grant_initial_goods()
	return ""


func _install_new_game_sets() -> void:
	skill_sets.clear()
	skill_sets.append(_make_set(default_skill_set_name(0), _default_slot_ids(), "the_world"))
	for i in range(1, SKILL_SET_COUNT):
		skill_sets.append(_make_set(default_skill_set_name(i), _blank_slot_ids(), ""))
	skill_set_index = 0
	_mirror_selected()


func _default_slot_ids() -> Array[String]:
	return ["carry_boost", "move_boost", "metal_rush", "checkout_speed", "instant_restock"]


func _blank_slot_ids() -> Array[String]:
	return ["", "", "", "", ""]


func _make_set(set_name: String, slot_ids: Array[String], ult: String, levels: Dictionary = {}) -> Dictionary:
	var copied := _blank_slot_ids()
	for i in mini(5, slot_ids.size()):
		copied[i] = String(slot_ids[i])
	return {"name": set_name, "slots": copied, "ult_id": ult, "levels": levels.duplicate()}


func _mirror_selected() -> void:
	if skill_sets.is_empty():
		return
	skill_set_index = clampi(skill_set_index, 0, skill_sets.size() - 1)
	var pack: Dictionary = skill_sets[skill_set_index]
	var src: Array = pack.get("slots", [])
	slots = _blank_slot_ids()
	for i in mini(5, src.size()):
		slots[i] = String(src[i])
	ult_id = String(pack.get("ult_id", ""))


func _after_set_edit(set_i: int) -> void:
	if set_i == skill_set_index:
		_mirror_selected()
	_persist_skill_edit()


func _persist_skill_edit() -> void:
	var err := save_to_disk()
	if err != "":
		push_warning("skill set save failed: %s" % err)


func _cost_of_ids(ids) -> int:
	var n := 0
	if not (ids is Array):
		return 0
	for id in ids:
		if String(id) == "":
			continue
		n += int(Skills.by_id(String(id)).get("cost", 1))
	return n


func _is_english_letters(set_name: String) -> bool:
	if set_name == "":
		return false
	for i in set_name.length():
		var c := set_name.unicode_at(i)
		var upper := c >= 65 and c <= 90
		var lower := c >= 97 and c <= 122
		if not upper and not lower:
			return false
	return true


func _sanitize_ult_id(id: String) -> String:
	if id == "":
		return ""
	var sk := Skills.by_id(id)
	if sk.is_empty() or String(sk.get("kind")) != "ultimate":
		return "the_world"
	return id


func _migrate_single_loadout(loaded_slots: Array[String], loaded_ult: String) -> void:
	skill_sets.clear()
	skill_sets.append(_make_set(default_skill_set_name(0), loaded_slots, loaded_ult))
	for i in range(1, SKILL_SET_COUNT):
		skill_sets.append(_make_set(default_skill_set_name(i), _blank_slot_ids(), ""))


func _load_skill_sets(raw) -> bool:
	if not (raw is Array) or (raw as Array).is_empty():
		return false
	var incoming: Array = raw
	skill_sets.clear()
	for i in SKILL_SET_COUNT:
		if i < incoming.size() and incoming[i] is Dictionary:
			var src: Dictionary = incoming[i]
			var slot_ids := _blank_slot_ids()
			var raw_slots = src.get("slots", [])
			if raw_slots is Array:
				for s in mini(5, raw_slots.size()):
					slot_ids[s] = String(raw_slots[s])
			var ult := ""
			if src.has("ult_id"):
				ult = _sanitize_ult_id(String(src.get("ult_id")))
			var set_name := String(src.get("name", ""))
			skill_sets.append(_make_set(set_name, slot_ids, ult, _levels_from_save(src.get("levels", {}))))
		else:
			skill_sets.append(_make_set(default_skill_set_name(i), _blank_slot_ids(), ""))
	return true


func _repair_set_names() -> void:
	var used := {}
	for i in skill_sets.size():
		var set_name := String(skill_sets[i].get("name", ""))
		var keep := set_name == default_skill_set_name(i) or skill_set_name_is_custom(set_name)
		if keep and used.has(set_name.to_lower()):
			keep = false
		if not keep:
			set_name = default_skill_set_name(i)
		used[set_name.to_lower()] = true
		skill_sets[i]["name"] = set_name


func _skill_sets_for_save() -> Array:
	var out: Array = []
	for pack in skill_sets:
		var slot_list: Array = []
		var src: Array = pack.get("slots", [])
		for i in mini(5, src.size()):
			slot_list.append(String(src[i]))
		while slot_list.size() < 5:
			slot_list.append("")
		var saved_levels := {}
		var raw_levels = pack.get("levels", {})
		if raw_levels is Dictionary:
			for key in raw_levels.keys():
				saved_levels[String(key)] = int(raw_levels[key])
		out.append({
			"name": String(pack.get("name", "")),
			"slots": slot_list,
			"ult_id": String(pack.get("ult_id", "")),
			"levels": saved_levels,
		})
	return out


func _levels_from_save(raw) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for key in raw.keys():
		var id := String(key)
		var sk := Skills.by_id(id)
		if sk.is_empty() or not bool(sk.get("dark_side", false)):
			continue
		out[id] = clampi(int(raw[key]), 1, 3)
	return out


func save_to_disk() -> String:
	var text := JSON.stringify(to_dict(), "\t")
	return PlatformServices.write_save(text)


func load_from_disk() -> String:
	if not PlatformServices.has_save():
		return "沒有存檔"
	var text := PlatformServices.read_save()
	if text.strip_edges() == "":
		return "存檔是空的"
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return "存檔不是有效 JSON"
	return from_dict(parsed as Dictionary)


func has_save() -> bool:
	return PlatformServices.has_save()


func delete_save() -> void:
	PlatformServices.delete_save()


func _string_bool_dict(raw) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for k in raw.keys():
		out[String(k)] = bool(raw[k])
	return out


func _string_int_dict(raw) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for k in raw.keys():
		out[String(k)] = int(raw[k])
	return out
