extends RefCounted
## Demo v0.3 playable defaults. See docs/demo/demov0_3scope.md.

const STR := 20
const AGI := 20
const INT := 20

const CAT_DRY := "dry"
const CAT_FROZEN := "frozen"

const DRY_SKUS: Array[String] = ["can", "snack", "cup"]
const FROZEN_SKUS: Array[String] = ["drink", "milk", "soda"]
const SELLABLE_SKUS: Array[String] = ["can", "snack", "cup", "drink", "milk", "soda"]

const SKU_NAME := {
	"can": "罐頭", "snack": "零食", "cup": "杯麵",
	"drink": "支裝凍飲", "milk": "牛奶", "soda": "汽水",
}
const SKU_COLOR := {
	"can": Color("c45c26"),
	"snack": Color("e8c36a"),
	"cup": Color("3d7ea6"),
	"drink": Color("7ec8e3"),
	"milk": Color("3a7ca5"),
	"soda": Color("c0392b"),
}
const SKU_PRICE := {
	"can": 30, "snack": 15, "cup": 8,
	"drink": 8, "milk": 10, "soda": 20,
}
const SKU_COST := {
	"can": 10, "snack": 5, "cup": 3,
	"drink": 2, "milk": 3, "soda": 6,
}

const BOX_SIZE := 4
const SHELF_CAP := 12
const RESTOCK_BOXES := 99
const CARRY_CAP := 16

const WALK_SPEED := 180.0
const RUN_SPEED_MULT := 1.75
const DASH_DISTANCE := 140.0
const DASH_TIME := 0.12
const RUN_HOLD_THRESHOLD := 0.18
const STAMINA_MAX := 100.0
const RUN_STAMINA_PER_SEC := 22.0
const DASH_STAMINA_COST := 28.0
const STAMINA_REGEN_PER_SEC := 16.0
const STAMINA_REGEN_DELAY := 0.35
const OVERWEIGHT_AT_CAP_MULT := 0.62
const OVERWEIGHT_OVER_CAP_MULT := 0.42
const DIRT_MULT := 0.55
const SPEED_MAX_MULT := 5.0
const SPEED_FLOOR := 48.0

const INTERACT_RANGE := 100.0
const FACE_DOT := 0.18
const SKU_PICK_HOLD := 0.18
const RESTOCK_SECONDS_AT_10 := 0.9
const CHECKOUT_SECONDS_AT_10 := 0.85

const RESTOCK_REAL_SEC := 30.0
const OPEN_REAL_SEC := 180.0
const GAME_START_HOUR := 6.0
const OPEN_HOUR := 8.0
const CLOSE_HOUR := 22.0

const CUSTOMER_AGI := 10
const CUSTOMER_SPAWN_MIN := 5.0
const CUSTOMER_SPAWN_MAX := 5.0
const CUSTOMER_CAP := 15
const LIST_MIN := 2
const LIST_MAX := 8
const LIST_HARD_MAX := 15
const LINGER_SEC := 1.0
const THINK_SEC := 3.0
const DISSAT_MAX := 100.0
const DISSAT_MISS := 18.0
const DISSAT_QUEUE_PER_SEC := 5.0
const DISSAT_DIRT_PER_SEC := 8.0
const CUSTOMER_ARRIVE_DIST := 40.0
const CUSTOMER_SHELF_REACH := 80.0
const LAYER_WALLS := 1
const LAYER_FURNITURE := 2
const LAYER_CUSTOMERS := 4


static func agi_mult(agi: int = AGI) -> float:
	return float(agi) / 10.0


static func stamina_max(str_stat: int = STR) -> float:
	return STAMINA_MAX * (float(str_stat) / 10.0)


static func restock_seconds(agi: int = AGI) -> float:
	return RESTOCK_SECONDS_AT_10 * (10.0 / float(maxi(1, agi)))


static func checkout_seconds(int_stat: int = INT) -> float:
	return CHECKOUT_SECONDS_AT_10 * (10.0 / float(maxi(1, int_stat)))


static func sku_name(id: String) -> String:
	return String(SKU_NAME.get(id, id))


static func sku_price(id: String) -> int:
	return int(SKU_PRICE.get(id, 0))


static func category_of(sku: String) -> String:
	if sku in DRY_SKUS:
		return CAT_DRY
	if sku in FROZEN_SKUS:
		return CAT_FROZEN
	return ""


static func skus_for(category: String) -> Array[String]:
	if category == CAT_FROZEN:
		return FROZEN_SKUS
	return DRY_SKUS


static func command_count(item_count: int) -> int:
	if item_count <= 2:
		return 1
	if item_count <= 5:
		return 2
	if item_count <= 8:
		return 3
	if item_count <= 10:
		return 4
	return 5


static func dir_name(code: int) -> String:
	match code:
		0:
			return "上"
		1:
			return "下"
		2:
			return "左"
		3:
			return "右"
	return "?"
