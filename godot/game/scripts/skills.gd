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

## Slot 1–5. Cost 1 each = 5 COST. Display names come from Loc via localize().
const EQUIPPED: Array[Dictionary] = [
	{
		"id": "carry_boost",
		"kind": "active",
		"lv": 3,
		"carry_add": 240,  # pieces; stacks on top of STR cap (was +60 boxes)
		"duration": ACTIVE_DURATION,
		"cd": ACTIVE_CD,
	},
	{
		"id": "move_boost",
		"kind": "active",
		"lv": 3,
		"move_pct": 0.60,
		"duration": ACTIVE_DURATION,
		"cd": ACTIVE_CD,
	},
	{
		"id": "metal_rush",
		"kind": "active",
		"lv": 3,
		"customer_move_pct": 1.50,
		"duration": ACTIVE_DURATION,
		"cd": ACTIVE_CD,
	},
	{
		"id": "checkout_speed",
		"kind": "passive",
		"lv": 3,
		"checkout_pct": 0.20,
	},
	{
		"id": "instant_restock",
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
	return localize(EQUIPPED[i])


static func is_active(skill: Dictionary) -> bool:
	return String(skill.get("kind", "")) == "active"


## Fill player-facing name/blurb from locale/data.csv (`skill.<id>.*`).
static func localize(skill: Dictionary) -> Dictionary:
	if skill.is_empty():
		return {}
	var out := skill.duplicate(true)
	var id := String(out.get("id", ""))
	if id == "":
		return out
	out["name"] = Loc.t("skill.%s.name" % id)
	out["blurb"] = Loc.t("skill.%s.blurb" % id)
	return out


static func by_id(id: String) -> Dictionary:
	for sk in ACTIVES:
		if String(sk.get("id")) == id:
			return localize(sk)
	for sk in PASSIVES:
		if String(sk.get("id")) == id:
			return localize(sk)
	for sk in ULTS:
		if String(sk.get("id")) == id:
			return localize(sk)
	return {}


static func catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sk in ACTIVES:
		out.append(localize(sk))
	for sk in PASSIVES:
		out.append(localize(sk))
	for sk in ULTS:
		out.append(localize(sk))
	return out


## Mechanical catalogs only — display strings live in locale/data.csv.
const ACTIVES: Array[Dictionary] = [
	{"id": "carry_boost", "kind": "active", "lv": 3, "cost": 1, "carry_add": 240, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD},
	{"id": "move_boost", "kind": "active", "lv": 3, "cost": 1, "move_pct": 0.60, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD},
	{"id": "checkout_rush", "kind": "active", "lv": 3, "cost": 1, "checkout_pct": 0.60, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD},
	{"id": "universal_cannon", "kind": "active", "lv": 3, "cost": 2, "universal_cannon": true, "cd": 60.0},
	{"id": "self_checkout", "kind": "active", "lv": 3, "cost": 2, "self_checkout": true, "duration": 15.0, "cd": 30.0},
	{"id": "senior_cashier", "kind": "active", "lv": 3, "cost": 2, "senior_cashier": true, "duration": 45.0, "cd": 15.0},
	{"id": "instant_restock", "kind": "active", "lv": 3, "cost": 1, "restock_instant": true, "restock_circle_mult": 0.0, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD},
	{"id": "soothe", "kind": "active", "lv": 3, "cost": 1, "soothe_keep": 0.0, "duration": 0.0, "cd": ACTIVE_CD},
	{"id": "metal_rush", "kind": "active", "lv": 3, "cost": 1, "customer_move_pct": 1.50, "duration": ACTIVE_DURATION, "cd": ACTIVE_CD},
	{"id": "hoop_ace", "kind": "active", "lv": 3, "cost": 1, "hoop_ace": true, "duration": 30.0, "cd": 15.0},
	{"id": "dash_deliver", "kind": "active", "lv": 1, "cost": 1, "dash_deliver": true, "duration": 5.0, "cd": 5.0},
	{"id": "dasher", "kind": "active", "lv": 3, "cost": 2, "dasher": true, "duration": 15.0, "cd": 15.0},
	{"id": "force_sell", "kind": "active", "lv": 3, "cost": 2, "force_sell": true, "duration": 0.0, "cd": 15.0},
	{"id": "must_deliver", "kind": "active", "lv": 3, "cost": 2, "must_deliver": true, "duration": 0.0, "cd": 15.0},
	{"id": "summon_guest", "kind": "active", "lv": 3, "cost": 2, "summon_guest": true, "duration": 0.0, "cd": 15.0},
	{"id": "harvest_chives", "kind": "active", "lv": 3, "cost": 2, "harvest_chives": true, "duration": 0.0, "cd": 15.0},
	{"id": "magneto", "kind": "active", "lv": 3, "cost": 2, "magneto": true, "duration": 0.0, "cd": 15.0},
	{"id": "sweeping_monk", "kind": "active", "lv": 3, "cost": 2, "sweeping_monk": true, "duration": 15.0, "cd": 30.0},
	{"id": "shelf_sniper", "kind": "active", "lv": 1, "cost": 2, "shelf_sniper": true, "duration": 30.0, "cd": ACTIVE_CD},
	{"id": "guest_sniper", "kind": "active", "lv": 1, "cost": 2, "guest_sniper": true, "duration": 30.0, "cd": ACTIVE_CD},
	{"id": "thief_sniper", "kind": "active", "lv": 1, "cost": 2, "thief_sniper": true, "duration": 30.0, "cd": ACTIVE_CD},
	{"id": "dark_side", "kind": "active", "lv": 3, "cost": 2, "dark_side": true, "duration": 30.0, "cd": 30.0},
	{"id": "shadow_clone", "kind": "active", "lv": 3, "cost": 3, "shadow_clone": true, "duration": 30.0, "cd": 30.0},
]

const PASSIVES: Array[Dictionary] = [
	{"id": "carry_passive", "kind": "passive", "lv": 3, "cost": 1, "carry_add": 80},
	{"id": "move_passive", "kind": "passive", "lv": 3, "cost": 1, "move_pct": 0.20},
	{"id": "checkout_speed", "kind": "passive", "lv": 3, "cost": 1, "checkout_pct": 0.20},
	{"id": "restock_speed", "kind": "passive", "lv": 3, "cost": 1, "restock_pct": 0.20},
	{"id": "quick_swallow", "kind": "passive", "lv": 3, "cost": 2, "quick_swallow": true},
	{"id": "polite_dash", "kind": "passive", "lv": 1, "cost": 2, "polite_dash": true},
	{"id": "wave_step", "kind": "passive", "lv": 1, "cost": 2, "ignore_dirt_slow": true, "ignore_trash_stamina": true, "ignore_puddle_slip": true, "ignore_vomit_sick": true},
	{"id": "cold_smile", "kind": "passive", "lv": 1, "cost": 3, "no_queue_dissat": true},
	{"id": "haki", "kind": "passive", "lv": 1, "cost": 3, "thief_rate": 0.5},
]


static func quick_swallow_pieces(lv: int) -> int:
	match lv:
		1:
			return 2
		2:
			return 3
		_:
			return 5

const ULTS: Array[Dictionary] = [
	{"id": "the_world", "kind": "ultimate", "lv": 3, "cost": 0, "clock_scale": 0.0, "duration": ULT_DURATION, "cd": ULT_CD, "seq": [0, 0, 1, 1, 2, 3, 2, 3]},
	{"id": "yes_my_lord", "kind": "ultimate", "lv": 3, "cost": 0, "duration": 10.0, "cd": ULT_CD, "seq": [0, 2, 1, 3, 0, 2, 1, 3]},
	{"id": "fundraise", "kind": "ultimate", "lv": 3, "cost": 0, "duration": 0.0, "cd": ULT_CD, "seq": [0, 1, 0, 1, 2, 3, 2, 3]},
	{"id": "close_gate", "kind": "ultimate", "lv": 1, "cost": 0, "duration": 0.0, "cd": 120.0, "seq": [0, 1, 0, 1, 2, 3, 2, 3]},
	{"id": "guest_dusk", "kind": "ultimate", "lv": 1, "cost": 0, "duration": 30.0, "cd": 120.0, "seq": [0, 2, 3, 1, 1, 2, 3, 0]},
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
		or bool(sk.get("universal_cannon", false))
		or bool(sk.get("self_checkout", false))
		or bool(sk.get("senior_cashier", false))
		or bool(sk.get("hoop_ace", false))
		or bool(sk.get("force_sell", false))
		or bool(sk.get("must_deliver", false))
		or bool(sk.get("summon_guest", false))
		or bool(sk.get("harvest_chives", false))
		or bool(sk.get("magneto", false))
		or bool(sk.get("sweeping_monk", false))
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


## 掃地僧: fixed clear radius (LV only changes duration).
const SWEEPING_MONK_BODY_LENGTHS := 3.0
const SWEEPING_MONK_RANGE := SWEEPING_MONK_BODY_LENGTHS * Tuning.BODY_LENGTH
const SWEEPING_MONK_RANGE_SQ := SWEEPING_MONK_RANGE * SWEEPING_MONK_RANGE


static func sweeping_monk_seconds(lv: int) -> float:
	match lv:
		1:
			return 5.0
		2:
			return 10.0
		_:
			return 15.0


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
