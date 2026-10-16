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


static func by_id(id: String) -> Dictionary:
	for sk in catalog():
		if String(sk.get("id")) == id:
			return sk.duplicate(true)
	return {}


static func catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(ACTIVES)
	out.append_array(PASSIVES)
	out.append_array(ULTS)
	return out


const ACTIVES: Array[Dictionary] = [
	{"id": "carry_boost", "name": "頂硬上", "kind": "active", "lv": 3, "cost": 1, "carry_add": 60, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD, "blurb": "負重 +60 箱，20 秒"},
	{"id": "move_boost", "name": "無人可以喺我前面", "kind": "active", "lv": 3, "cost": 1, "move_pct": 0.60, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD, "blurb": "移速 +60%，20 秒"},
	{"id": "checkout_rush", "name": "人肉數錢機", "kind": "active", "lv": 3, "cost": 1, "checkout_pct": 0.60, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD, "blurb": "收銀 +60%，20 秒"},
	{"id": "instant_restock", "name": "瞬間補貨", "kind": "active", "lv": 3, "cost": 1, "restock_instant": true, "restock_circle_mult": 0.0, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD, "blurb": "上架瞬間完成，20 秒"},
	{"id": "soothe", "name": "安撫", "kind": "active", "lv": 3, "cost": 1, "soothe_keep": 0.0, "duration": 0.0, "cd": ACTIVE_CD, "blurb": "全店不滿歸零（已離開不拉回）"},
	{"id": "metal_rush", "name": "金屬狂潮", "kind": "active", "lv": 3, "cost": 1, "customer_move_pct": 1.50, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD, "blurb": "客人移速 +150%，20 秒"},
]

const PASSIVES: Array[Dictionary] = [
	{"id": "carry_passive", "name": "負重增加", "kind": "passive", "lv": 3, "cost": 1, "carry_add": 20, "blurb": "負重 +20 箱"},
	{"id": "move_passive", "name": "移動速度增加", "kind": "passive", "lv": 3, "cost": 1, "move_pct": 0.20, "blurb": "移速 +20%"},
	{"id": "checkout_speed", "name": "收銀速度增加", "kind": "passive", "lv": 3, "cost": 1, "checkout_pct": 0.20, "blurb": "收銀 +20%"},
	{"id": "restock_speed", "name": "上架速度增加", "kind": "passive", "lv": 3, "cost": 1, "restock_pct": 0.20, "blurb": "上架 +20%"},
	{"id": "polite_dash", "name": "禮貌衝撞", "kind": "passive", "lv": 1, "cost": 2, "unimplemented": true, "blurb": "客人撞飛本 Demo 未做"},
	{"id": "wave_step", "name": "凌波微步", "kind": "passive", "lv": 1, "cost": 2, "ignore_dirt_slow": true, "blurb": "污物不減移速（滑倒／嘔吐仍在）"},
	{"id": "cold_smile", "name": "笑到你心寒", "kind": "passive", "lv": 1, "cost": 3, "no_queue_dissat": true, "blurb": "排隊不增加不滿"},
	{"id": "haki", "name": "霸王色", "kind": "passive", "lv": 1, "cost": 3, "thief_rate": 0.5, "blurb": "小偷出現率 ×0.5"},
]

const ULTS: Array[Dictionary] = [
	{"id": "the_world", "name": "The World!", "kind": "ultimate", "lv": 3, "cost": 0, "clock_scale": 0.0, "duration": ULT_DURATION, "cd": ULT_CD, "seq": [0, 0, 1, 1, 2, 3, 2, 3], "blurb": "時停 10 秒。指令上上下下左右左右"},
	{"id": "yes_my_lord", "name": "Yes! My Lord!", "kind": "ultimate", "lv": 3, "cost": 0, "unimplemented": true, "duration": 10.0, "cd": ULT_CD, "seq": [0, 2, 1, 3, 0, 2, 1, 3], "blurb": "搶購規則長線未定，裝備後不會發動"},
	{"id": "fundraise", "name": "全體集資", "kind": "ultimate", "lv": 3, "cost": 0, "unimplemented": true, "duration": 0.0, "cd": ULT_CD, "seq": [0, 1, 0, 1, 2, 3, 2, 3], "blurb": "自動收銀規則長線未定，裝備後不會發動"},
]


static func restock_circle_mult(lv: int) -> float:
	match lv:
		1:
			return RESTOCK_CIRCLE_LV1
		2:
			return RESTOCK_CIRCLE_LV2
		_:
			return 0.0
