extends RefCounted
## Unified Demo v0.1 numbers. Design locks STR/AGI/INT at 10 and does not
## publish conversion tables; these are the playable defaults used by the labs.

const STR := 10
const AGI := 10
const INT := 10

const SKUS: Array[String] = ["can", "snack", "cup"]
const SKU_NAME := {"can": "罐頭", "snack": "零食", "cup": "杯麵"}
const SKU_COLOR := {
	"can": Color("c45c26"),
	"snack": Color("e8c36a"),
	"cup": Color("3d7ea6"),
}

const BOX_SIZE := 4
const SHELF_COUNT := 6
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
const RESTOCK_SECONDS_AT_10 := 0.9


static func agi_mult(agi: int = AGI) -> float:
	return float(agi) / 10.0


static func stamina_max(str_stat: int = STR) -> float:
	return STAMINA_MAX * (float(str_stat) / 10.0)


static func restock_seconds(agi: int = AGI) -> float:
	return RESTOCK_SECONDS_AT_10 * (10.0 / float(maxi(1, agi)))


static func sku_name(id: String) -> String:
	return String(SKU_NAME.get(id, id))
