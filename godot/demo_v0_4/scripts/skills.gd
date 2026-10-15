extends RefCounted
## Demo v0.31 skill table. Equipped set uses LV3. Speed bonuses are percent.

const HOLD_MENU_SEC := 0.18
const ACTIVE_DURATION := 20.0
const ACTIVE_CD := 10.0
const ULT_DURATION := 10.0
const ULT_CD := 60.0

## Instant restock circle multipliers (not used at LV3 — LV3 is instant).
const RESTOCK_CIRCLE_LV1 := 0.35
const RESTOCK_CIRCLE_LV2 := 0.15

const DIR_UP := 0
const DIR_DOWN := 1
const DIR_LEFT := 2
const DIR_RIGHT := 3

## Slot 1–5. Cost 1 each = 5 COST.
const EQUIPPED: Array[Dictionary] = [
	{
		"id": "carry_boost",
		"name": "頂硬上",
		"kind": "active",
		"lv": 3,
		"carry_add": 60,  # boxes; stacks on top of STR cap
		"duration": ACTIVE_DURATION,
		"cd": ACTIVE_CD,
	},
	{
		"id": "move_boost",
		"name": "無人可以喺我前面",
		"kind": "active",
		"lv": 3,
		"move_pct": 0.60,
		"duration": ACTIVE_DURATION,
		"cd": ACTIVE_CD,
	},
	{
		"id": "metal_rush",
		"name": "金屬狂潮",
		"kind": "active",
		"lv": 3,
		"customer_move_pct": 1.50,
		"duration": ACTIVE_DURATION,
		"cd": ACTIVE_CD,
	},
	{
		"id": "checkout_speed",
		"name": "收銀速度增加",
		"kind": "passive",
		"lv": 3,
		"checkout_pct": 0.20,
	},
	{
		"id": "instant_restock",
		"name": "瞬間補貨",
		"kind": "active",
		"lv": 3,
		"restock_instant": true,
		"restock_circle_mult": 0.0,
		"duration": ACTIVE_DURATION,
		"cd": ACTIVE_CD,
	},
]

const ULTIMATE := {
	"id": "the_world",
	"name": "The World!",
	"kind": "ultimate",
	"lv": 3,
	# Remaining world rate. LV1 0.5, LV2 0.2, LV3 0. Player actions stay at real-time.
	"clock_scale": 0.0,
	"duration": ULT_DURATION,
	"cd": ULT_CD,
	"seq": [DIR_UP, DIR_UP, DIR_DOWN, DIR_DOWN, DIR_LEFT, DIR_RIGHT, DIR_LEFT, DIR_RIGHT],
}

## Menu: up=slot2, right=slot3, down=slot4, left=slot5
const DIR_TO_SLOT := {DIR_UP: 1, DIR_RIGHT: 2, DIR_DOWN: 3, DIR_LEFT: 4}


static func slot(i: int) -> Dictionary:
	if i < 0 or i >= EQUIPPED.size():
		return {}
	return EQUIPPED[i]


static func is_active(skill: Dictionary) -> bool:
	return String(skill.get("kind", "")) == "active"


static func restock_circle_mult(lv: int) -> float:
	match lv:
		1:
			return RESTOCK_CIRCLE_LV1
		2:
			return RESTOCK_CIRCLE_LV2
		_:
			return 0.0
