extends RefCounted
## Demo v0.31 skill table. Equipped set uses LV3. Speed bonuses are percent.

const Tuning = preload("res://scripts/tuning.gd")

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
		"carry_add": 240,  # pieces; stacks on top of STR cap (was +60 boxes)
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
	{"id": "carry_boost", "name": "頂硬上", "kind": "active", "lv": 3, "cost": 1, "carry_add": 240, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD, "blurb": "負重 +240 件，20 秒"},
	{"id": "move_boost", "name": "無人可以喺我前面", "kind": "active", "lv": 3, "cost": 1, "move_pct": 0.60, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD, "blurb": "移速 +60%，20 秒"},
	{"id": "checkout_rush", "name": "人肉數錢機", "kind": "active", "lv": 3, "cost": 1, "checkout_pct": 0.60, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD, "blurb": "收銀 +60%，20 秒"},
	{"id": "senior_cashier", "name": "資深收銀員", "kind": "active", "lv": 3, "cost": 2, "senior_cashier": true, "duration": 45.0, "cd": 15.0, "blurb": "減指令次數／LV3免指令且Circle×0.5。準備頁選 LV1／2／3，沒選預設 LV3"},
	{"id": "instant_restock", "name": "瞬間補貨", "kind": "active", "lv": 3, "cost": 1, "restock_instant": true, "restock_circle_mult": 0.0, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD, "blurb": "上架瞬間完成，20 秒"},
	{"id": "soothe", "name": "安撫", "kind": "active", "lv": 3, "cost": 1, "soothe_keep": 0.0, "duration": 0.0, "cd": ACTIVE_CD, "blurb": "全店不滿歸零（已離開不拉回）"},
	{"id": "metal_rush", "name": "金屬狂潮", "kind": "active", "lv": 3, "cost": 1, "customer_move_pct": 1.50, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD, "blurb": "客人移速 +150%，20 秒"},
	{"id": "hoop_ace", "name": "投籃高手", "kind": "active", "lv": 3, "cost": 1, "hoop_ace": true, "duration": 30.0, "cd": 15.0, "blurb": "短按方向一次投最上 2 件；LV3＝30 秒。準備頁選 LV1／2／3，沒選預設 LV3"},
	{"id": "dash_deliver", "name": "衝刺交付", "kind": "active", "lv": 1, "cost": 2, "dash_deliver": true, "duration": 5.0, "cd": 5.0, "blurb": "5 秒內每記衝刺把對的貨交給客人且不 KO。沒對上則照常撞飛。技能不扣氣"},
	{"id": "dasher", "name": "Dasher", "kind": "active", "lv": 3, "cost": 2, "dasher": true, "duration": 15.0, "cd": 15.0, "blurb": "衝刺與奔跑不扣氣（氣 0 也能）；LV3＝15 秒。準備頁選 LV1／2／3，沒選預設 LV3"},
	{"id": "force_sell", "name": "我都賺夠啦比啲你賺", "kind": "active", "lv": 3, "cost": 2, "force_sell": true, "duration": 0.0, "cd": 15.0, "blurb": "瞬發強塞手上貨進最近可交付客人 cart；LV3＝最多 20 件。準備頁選 LV1／2／3，沒選預設 LV3"},
	{"id": "must_deliver", "name": "使命必達", "kind": "active", "lv": 3, "cost": 2, "must_deliver": true, "duration": 0.0, "cd": 15.0, "blurb": "兩段施放：範圍內完成優先交清單貨；LV3＝15 身位／最多 4 人。準備頁選 LV1／2／3，沒選預設 LV3"},
	{"id": "summon_guest", "name": "召喚客人", "kind": "active", "lv": 3, "cost": 2, "summon_guest": true, "duration": 0.0, "cd": 15.0, "blurb": "瞬發門口召喚客人（可超 cap）；LV3＝3 人。準備頁選 LV1／2／3，沒選預設 LV3"},
	{"id": "harvest_chives", "name": "割韭菜", "kind": "active", "lv": 3, "cost": 2, "harvest_chives": true, "duration": 0.0, "cd": 15.0, "blurb": "對準一台收銀機瞬發清隊 QUEUE／PAYING；LV3＝最多 10 人。準備頁選 LV1／2／3，沒選預設 LV3"},
	{"id": "magneto", "name": "攝石人", "kind": "active", "lv": 3, "cost": 2, "magneto": true, "duration": 0.0, "cd": 15.0, "blurb": "兩段：預覽範圍後吸地上貨飛入手（可拆堆）；LV3＝15 身位。準備頁選 LV1／2／3，沒選預設 LV3"},
	{"id": "shelf_sniper", "name": "狙擊手（貨架）", "kind": "active", "lv": 1, "cost": 2, "shelf_sniper": true, "duration": 30.0, "cd": ACTIVE_CD, "blurb": "30 秒內投出的貨自動飛向最近同 SKU 貨架補貨；已滿則改飛下一格，全滿則飛最近架旁掉落"},
	{"id": "guest_sniper", "name": "狙擊手（客人）", "kind": "active", "lv": 1, "cost": 2, "guest_sniper": true, "duration": 30.0, "cd": ACTIVE_CD, "blurb": "30 秒內投出的貨自動飛向最近清單需要該貨的客人；該客不要了就改飛下一位，全店沒目標則普通丟掉"},
	{"id": "thief_sniper", "name": "狙擊手（小偷）", "kind": "active", "lv": 1, "cost": 2, "thief_sniper": true, "duration": 30.0, "cd": ACTIVE_CD, "blurb": "30 秒內投出的貨自動飛向最近小偷擊中並趕走；投 1 件／一段都算一擊，擊中後貨品掉落；全店沒小偷則普通丟掉"},
	{"id": "dark_side", "name": "Dark Side", "kind": "active", "lv": 3, "cost": 2, "dark_side": true, "duration": 30.0, "cd": 30.0, "blurb": "You don't know the power of the dark side。抽客人當臨時員工 30 秒（準備頁選 LV1／2／3，沒選預設 LV3）"},
	{"id": "shadow_clone", "name": "多重影分身", "kind": "active", "lv": 3, "cost": 3, "shadow_clone": true, "duration": 30.0, "cd": 30.0, "blurb": "身旁生出玩家分身當收銀／補貨 30 秒（準備頁選 LV1／2／3，沒選預設 LV3）"},
]

const PASSIVES: Array[Dictionary] = [
	{"id": "carry_passive", "name": "負重增加", "kind": "passive", "lv": 3, "cost": 1, "carry_add": 80, "blurb": "負重 +80 件"},
	{"id": "move_passive", "name": "移動速度增加", "kind": "passive", "lv": 3, "cost": 1, "move_pct": 0.20, "blurb": "移速 +20%"},
	{"id": "checkout_speed", "name": "收銀速度增加", "kind": "passive", "lv": 3, "cost": 1, "checkout_pct": 0.20, "blurb": "收銀 +20%"},
	{"id": "restock_speed", "name": "上架速度增加", "kind": "passive", "lv": 3, "cost": 1, "restock_pct": 0.20, "blurb": "上架 +20%"},
	{"id": "polite_dash", "name": "禮貌衝撞", "kind": "passive", "lv": 1, "cost": 2, "polite_dash": true, "blurb": "衝刺撞客人不滿不增加"},
	{"id": "wave_step", "name": "凌波微步", "kind": "passive", "lv": 1, "cost": 2, "ignore_dirt_slow": true, "ignore_trash_stamina": true, "ignore_puddle_slip": true, "ignore_vomit_sick": true, "blurb": "污物不減速；垃圾不扣氣；水漬不滑；嘔吐不禁技能"},
	{"id": "cold_smile", "name": "笑到你心寒", "kind": "passive", "lv": 1, "cost": 3, "no_queue_dissat": true, "blurb": "排隊不增加不滿"},
	{"id": "haki", "name": "霸王色", "kind": "passive", "lv": 1, "cost": 3, "thief_rate": 0.5, "blurb": "小偷出現率 ×0.5"},
]

const ULTS: Array[Dictionary] = [
	{"id": "the_world", "name": "The World!", "kind": "ultimate", "lv": 3, "cost": 0, "clock_scale": 0.0, "duration": ULT_DURATION, "cd": ULT_CD, "seq": [0, 0, 1, 1, 2, 3, 2, 3], "blurb": "時停 10 秒。指令上上下下左右左右"},
	{"id": "yes_my_lord", "name": "Yes! My Lord!", "kind": "ultimate", "lv": 3, "cost": 0, "duration": 10.0, "cd": ULT_CD, "seq": [0, 2, 1, 3, 0, 2, 1, 3], "blurb": "LV3：客人搶空最近貨架 10 秒，然後去排隊。指令上左下右上左下右"},
	{"id": "fundraise", "name": "全體集資", "kind": "ultimate", "lv": 3, "cost": 0, "duration": 0.0, "cd": ULT_CD, "seq": [0, 1, 0, 1, 2, 3, 2, 3], "blurb": "LV3：在店客人立刻按已取貨全額付款，不含離開與小偷。指令上下上下左右左右"},
	{"id": "close_gate", "name": "落閘放狗", "kind": "ultimate", "lv": 1, "cost": 0, "duration": 0.0, "cd": 120.0, "seq": [0, 1, 0, 1, 2, 3, 2, 3], "blurb": "有貨趕去排隊（只付已取）；空車離店；小偷掉贓離店。單階 CD120。指令上下上下左右左右"},
	{"id": "guest_dusk", "name": "諸客的黃昏", "kind": "ultimate", "lv": 1, "cost": 0, "duration": 30.0, "cd": 120.0, "seq": [0, 2, 3, 1, 1, 2, 3, 0], "blurb": "30 現實秒內成功進店 15 人（可超 cap、無小偷）。單階 CD120。指令上左右下下左右上"},
]


const GUEST_DUSK_DURATION := 30.0
const GUEST_DUSK_COUNT := 15
const GUEST_DUSK_INTERVAL := 2.0


## Prep page picks LV1/2/3 for these actives. Unset means LV3.
static func prep_picks_level(sk: Dictionary) -> bool:
	if sk.is_empty():
		return false
	return (
		bool(sk.get("dark_side", false))
		or bool(sk.get("shadow_clone", false))
		or bool(sk.get("dasher", false))
		or bool(sk.get("senior_cashier", false))
		or bool(sk.get("hoop_ace", false))
		or bool(sk.get("force_sell", false))
		or bool(sk.get("must_deliver", false))
		or bool(sk.get("summon_guest", false))
		or bool(sk.get("harvest_chives", false))
		or bool(sk.get("magneto", false))
	)


static func dasher_seconds(lv: int) -> float:
	match lv:
		1:
			return 5.0
		2:
			return 10.0
		_:
			return 15.0


static func hoop_ace_seconds(lv: int) -> float:
	match lv:
		1:
			return 10.0
		2:
			return 20.0
		_:
			return 30.0


static func senior_cashier_seconds(lv: int) -> float:
	match lv:
		1:
			return 15.0
		2:
			return 30.0
		_:
			return 45.0


static func force_sell_count(lv: int) -> int:
	match lv:
		1:
			return 5
		2:
			return 10
		_:
			return 20


static func summon_guest_count(lv: int) -> int:
	match lv:
		1:
			return 1
		2:
			return 2
		_:
			return 3


static func harvest_chives_count(lv: int) -> int:
	match lv:
		1:
			return 3
		2:
			return 6
		_:
			return 10


static func magneto_body_lengths(lv: int) -> float:
	match lv:
		1:
			return 5.0
		2:
			return 10.0
		_:
			return 15.0


static func magneto_range(lv: int) -> float:
	return magneto_body_lengths(lv) * Tuning.BODY_LENGTH


static func must_deliver_body_lengths(lv: int) -> float:
	match lv:
		1:
			return 5.0
		2:
			return 10.0
		_:
			return 15.0


static func must_deliver_range(lv: int) -> float:
	return must_deliver_body_lengths(lv) * Tuning.BODY_LENGTH


static func must_deliver_max_guests(lv: int) -> int:
	match lv:
		1:
			return 2
		2:
			return 3
		_:
			return 4


## Apply LV1/2 keep ratios; LV3 → 0 (skip commands). lv≤0 = no buff.
static func senior_cashier_command_count(base: int, lv: int) -> int:
	if lv <= 0:
		return base
	if lv >= 3:
		return 0
	var keep := 0.7 if lv == 1 else 0.4
	return maxi(1, int(ceil(float(base) * keep)))


static func restock_circle_mult(lv: int) -> float:
	match lv:
		1:
			return RESTOCK_CIRCLE_LV1
		2:
			return RESTOCK_CIRCLE_LV2
		_:
			return 0.0
