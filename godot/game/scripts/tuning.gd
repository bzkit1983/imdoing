extends RefCounted
## Demo v0.6 playable defaults. See docs/demo/demov0_6scope.md.

const STR := 20
const AGI := 20
const INT := 20

const CAT_DRY := "dry"
const CAT_FROZEN := "frozen"
const CAT_ICE := "ice"

const DRY_SKUS: Array[String] = ["can", "snack", "cup"]
const FROZEN_SKUS: Array[String] = ["drink", "milk", "soda"]
const ICE_SKUS: Array[String] = ["icecream", "meat", "rice"]
const SELLABLE_SKUS: Array[String] = ["can", "snack", "cup", "drink", "milk", "soda", "icecream", "meat", "rice"]

const SKU_NAME := {
	"can": "罐頭", "snack": "零食", "cup": "杯麵",
	"drink": "支裝凍飲", "milk": "牛奶", "soda": "汽水",
	"icecream": "雪糕", "meat": "凍肉", "rice": "叮叮飯",
}
const SKU_COLOR := {
	"can": Color("c45c26"),
	"snack": Color("e8c36a"),
	"cup": Color("3d7ea6"),
	"drink": Color("7ec8e3"),
	"milk": Color("3a7ca5"),
	"soda": Color("c0392b"),
	"icecream": Color("f4a4c0"),
	"meat": Color("7a3048"),
	"rice": Color("e07a3d"),
}
const SKU_PRICE := {
	"can": 30, "snack": 15, "cup": 8,
	"drink": 8, "milk": 10, "soda": 20,
	"icecream": 50, "meat": 45, "rice": 70,
}
const SKU_COST := {
	"can": 10, "snack": 5, "cup": 3,
	"drink": 2, "milk": 3, "soda": 6,
	"icecream": 20, "meat": 15, "rice": 50,
}
const SKU_DEVELOP := {
	"can": 0, "snack": 200, "cup": 300,
	"drink": 400, "milk": 500, "soda": 600,
	"icecream": 700, "meat": 800, "rice": 900,
}
## Canned goods are initial stock: no develop fee. Microwave rice unlocks at character LV10.
const SKU_UNLOCK_LV := {
	"can": 1, "snack": 2, "cup": 3,
	"drink": 4, "milk": 5, "soda": 6,
	"icecream": 7, "meat": 8, "rice": 10,
}

const BOX_SIZE := 4
const SHELF_CAP := 12
const RESTOCK_BOXES := 99
const STR_EFFECT_CAP := 50

## Collision edge of the clerk; 1 身位. Shared AGI 10 rate = 3 body-lengths / sec.
## The player walks at twice that rate. Customers and clerks stay on WALK_SPEED.
const BODY_LENGTH := 26.0
const WALK_SPEED := 3.0 * BODY_LENGTH
const PLAYER_MOVE_MULT := 2.0
const AGI_MOVE_REF := 10
const AGI_EFFECT_CAP := 50
const RUN_SPEED_MULT := 1.75
const DASH_DISTANCE := 140.0
const DASH_TIME := 0.12
const RUN_HOLD_THRESHOLD := 0.18
## Long-press cancel (B or ;) drops the top carried box. A tap still only cancels.
const DROP_HOLD_SEC := 0.45
## Base toss distance (5 身位). Future drop-range skills multiply via player.drop_toss_dist().
const DROP_TOSS_BODY_LENGTHS := 5.0
const DROP_TOSS_DIST := DROP_TOSS_BODY_LENGTHS * BODY_LENGTH
const DROP_DIR_DEADZONE := 0.35
## Flight time for the tossed box (movement stays locked until it lands).
const DROP_FLIGHT_SEC := 0.28
const DROP_FEET_OFFSET := Vector2(0.0, 22.0)
## Aim / flight trail — cool cyan so it reads on warm floor tiles.
const DROP_AIM_LINE_COLOR := Color(0.2, 0.92, 1.0, 0.9)
const DROP_AIM_MARK_COLOR := Color(0.15, 0.85, 0.98, 0.85)
const DROP_FLIGHT_TRAIL_COLOR := Color(0.25, 0.95, 1.0, 0.6)
## Directional toss landing within this radius of a matching shelf → restock.
const DROP_SHELF_HIT_RADIUS := 78.0
## Directional toss: thief within this distance of the flight path / landing → KO.
const DROP_THIEF_HIT_RADIUS := 72.0
## Box-hit KO: stolen goods drop at the thief's feet (tiny ring so piles don't stack).
const LOOT_INPLACE_MAX := 0.35 * BODY_LENGTH
const STAMINA_PER_STR := 10.0
const RUN_STAMINA_PER_SEC := 20.0
const DASH_STAMINA_COST := 50.0
const STAMINA_REGEN_PER_SEC := 16.0
const STAMINA_REGEN_DELAY := 0.35
const OVERWEIGHT_AT_CAP_MULT := 0.62
const OVERWEIGHT_OVER_CAP_MULT := 0.42
const DIRT_MULT := 0.5
const DIRT_TRASH := "trash"
const DIRT_PUDDLE := "puddle"
const DIRT_VOMIT := "vomit"
const DIRT_SIZE := Vector2(88, 62)
const DIRT_START_COUNT := 2
const DIRT_CAP := 6
const DIRT_SPAWN_SEC := 12.0
const TRASH_STAMINA_PER_SEC := 8.0
const DISSAT_DIRT_TRASH := 4.0
const DISSAT_DIRT_PUDDLE := 8.0
const DISSAT_DIRT_VOMIT := 16.0
const SLIP_BODY_LENGTHS := 3.0
const SLIP_TIME := 0.28
const STUN_SEC := 3.0
const SICK_SEC := 10.0
const SICK_ABILITY_MULT := 0.7
const CLEAN_WIGGLE_PER_SEC := TAU
const THIEF_CAP := 2
const THIEF_SPAWN_FIRST := 8.0
const THIEF_SPAWN_SEC := 22.0
const THIEF_LIST_MIN := 2
const THIEF_LIST_MAX := 4
const FIGHT_SEC := 5.0
const FIGHT_DOWN_SEC := 5.0
## Closer than default shop zoom (1.22) for grab/fight framing.
const FIGHT_ZOOM := 2.45
const FIGHT_KO_ZOOM := 2.85
const FIGHT_HIT_SHAKE := 5.5
const FIGHT_HIT_SHAKE_SEC := 0.09
const FIGHT_KO_SHAKE := 12.0
const FIGHT_KO_FLASH_SEC := 0.55
## Melee KO loot: short ground scatter. Dash: farther, still ≤ 5 身位.
const LOOT_SCATTER_MELEE_MIN := 0.55 * BODY_LENGTH
const LOOT_SCATTER_MELEE_MAX := 1.75 * BODY_LENGTH
const LOOT_SCATTER_DASH_MIN := 2.2 * BODY_LENGTH
const LOOT_SCATTER_DASH_MAX := 5.0 * BODY_LENGTH
const LOOT_SCATTER_MIN_GAP := 30.0
const LOOT_SCATTER_FLIGHT_SEC := 0.38
const HIT_AT_10 := 3.5
const HIT_AT_50 := 12.0
const DASH_HIT_RANGE := 32.0
## Crowd slow: guests/thieves within this radius of the player.
const CROWD_RADIUS := 3.0 * BODY_LENGTH
const CROWD_RADIUS_SQ := CROWD_RADIUS * CROWD_RADIUS
const CROWD_SPEED_MULT := 0.5
## Dash into a shopping guest: +dissat (base), stun, cart drops in place.
const DASH_GUEST_DISSAT := 50.0
const DASH_GUEST_STUN_SEC := 2.0
## Toss hit normal guest: wrong SKU dissatisfaction.
const TOSS_GUEST_WRONG_DISSAT := 15.0
## Directional toss: guest within this of flight path / landing.
const DROP_GUEST_HIT_RADIUS := 72.0
## Prep: reset STR/AGI/INT costs level × this.
const STAT_RESET_FEE_PER_LEVEL := 1000
const SPEED_MAX_MULT := 5.0
const SPEED_FLOOR := 48.0

const CAMERA_ZOOM := 1.22
const INTERACT_RANGE := 100.0
const INTERACT_RANGE_SQ := INTERACT_RANGE * INTERACT_RANGE
const FACE_DOT := 0.18
## Customer seek: re-resolve shelf at most this often (seconds).
const SEEK_SHELF_REFRESH_SEC := 0.28
## Clerk idle job search throttle.
const CLERK_JOB_SEARCH_SEC := 0.35
const SKU_PICK_HOLD := 0.18
const RESTOCK_SECONDS_AT_10 := 2.0
const RESTOCK_SECONDS_AT_50 := 0.2
const CLEAN_SECONDS_AT_10 := 5.0
const CLEAN_SECONDS_AT_50 := 1.0
const CHECKOUT_SECONDS_AT_10 := 2.0
const CHECKOUT_SECONDS_AT_50 := 0.2
const CD_RATE_AT_10 := 1.0
const CD_RATE_AT_50 := 1.5
const INT_EFFECT_CAP := 50

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
const DISSAT_QUEUE_PER_SEC := 100.0 / 15.0
const DISSAT_DIRT_PER_SEC := 8.0
const CUSTOMER_ARRIVE_DIST := 40.0
const CUSTOMER_SHELF_REACH := 80.0
const LAYER_WALLS := 1
const LAYER_FURNITURE := 2
const LAYER_CUSTOMERS := 4


static func agi_mult(agi: int = AGI) -> float:
	return float(agi) / float(AGI_MOVE_REF)


static func str_for_effects(str_stat: int = STR) -> int:
	return mini(maxi(str_stat, 0), STR_EFFECT_CAP)


static func stamina_max(str_stat: int = STR) -> float:
	return STAMINA_PER_STR * float(str_for_effects(str_stat))


static func dash_charges_from_str(str_stat: int = STR) -> int:
	return str_for_effects(str_stat) / 5


static func run_seconds_from_str(str_stat: int = STR) -> float:
	return float(str_for_effects(str_stat)) / 2.0


static func carry_boxes_from_str(str_stat: int = STR) -> int:
	return 1 + str_for_effects(str_stat) / 5


static func carry_items_from_str(str_stat: int = STR) -> int:
	return carry_boxes_from_str(str_stat) * BOX_SIZE


static func agi_for_effects(agi: int = AGI) -> int:
	return mini(maxi(agi, 0), AGI_EFFECT_CAP)


static func _agi_circle_seconds(at_10: float, at_50: float, agi: int) -> float:
	var a := float(agi_for_effects(agi))
	return at_10 + (at_50 - at_10) * (a - 10.0) / 40.0


static func restock_seconds(agi: int = AGI) -> float:
	return _agi_circle_seconds(RESTOCK_SECONDS_AT_10, RESTOCK_SECONDS_AT_50, agi)


static func clean_seconds(agi: int = AGI) -> float:
	return _agi_circle_seconds(CLEAN_SECONDS_AT_10, CLEAN_SECONDS_AT_50, agi)


static func int_for_effects(int_stat: int = INT) -> int:
	return mini(maxi(int_stat, 0), INT_EFFECT_CAP)


static func checkout_seconds(int_stat: int = INT) -> float:
	var a := float(int_for_effects(int_stat))
	return CHECKOUT_SECONDS_AT_10 + (CHECKOUT_SECONDS_AT_50 - CHECKOUT_SECONDS_AT_10) * (a - 10.0) / 40.0


static func cd_rate(int_stat: int = INT) -> float:
	var a := float(int_for_effects(int_stat))
	return CD_RATE_AT_10 + (CD_RATE_AT_50 - CD_RATE_AT_10) * (a - 10.0) / 40.0


static func cd_seconds(listed: float, int_stat: int = INT) -> float:
	return listed / cd_rate(int_stat)


static func sku_name(id: String) -> String:
	return String(SKU_NAME.get(id, id))


static func sku_price(id: String) -> int:
	return int(SKU_PRICE.get(id, 0))


static func category_of(sku: String) -> String:
	if sku in DRY_SKUS:
		return CAT_DRY
	if sku in FROZEN_SKUS:
		return CAT_FROZEN
	if sku in ICE_SKUS:
		return CAT_ICE
	return ""


static func skus_for(category: String) -> Array[String]:
	if category == CAT_FROZEN:
		return FROZEN_SKUS
	if category == CAT_ICE:
		return ICE_SKUS
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


static func hit_damage(str_stat: int = STR) -> float:
	var a := float(str_for_effects(str_stat))
	return HIT_AT_10 + (HIT_AT_50 - HIT_AT_10) * (a - 10.0) / 40.0


static func dirt_type_name(dtype: String) -> String:
	match dtype:
		DIRT_TRASH:
			return "垃圾"
		DIRT_PUDDLE:
			return "水漬"
		DIRT_VOMIT:
			return "嘔吐物"
	return "污物"


## Offset from player origin to drop destination.
## Zero / tiny toss_dir → at feet. Else push `toss_dist` (default base 5 身位) along dir.
static func drop_offset(toss_dir: Vector2, toss_dist: float = -1.0) -> Vector2:
	var dist := DROP_TOSS_DIST if toss_dist < 0.0 else toss_dist
	if toss_dir.length_squared() < 0.0001:
		return DROP_FEET_OFFSET
	return toss_dir.normalized() * dist


## Non-overlapping scatter points in a ring between min_r and max_r (pixels).
static func loot_scatter_positions(
	origin: Vector2,
	count: int,
	min_r: float,
	max_r: float,
	min_gap: float = LOOT_SCATTER_MIN_GAP,
) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if count <= 0:
		return out
	var lo := minf(min_r, max_r)
	var hi := maxf(min_r, max_r)
	hi = maxf(hi, lo + 0.01)
	## Widen ring if needed so N points can sit at min_gap on a circle.
	var need_r := (min_gap * float(count)) / TAU
	if need_r > hi:
		hi = need_r
	var golden := PI * (3.0 - sqrt(5.0))
	for i in count:
		var t := (float(i) + 0.55) / float(count)
		var r := lerpf(lo, hi, sqrt(t))
		var ang := float(i) * golden
		var p := origin + Vector2(cos(ang), sin(ang)) * r
		for _pass in 8:
			var pushed := false
			for j in out.size():
				var d := p - out[j]
				var gap := d.length()
				if gap < min_gap:
					var push_dir := d.normalized() if gap > 0.01 else Vector2.RIGHT.rotated(ang + float(j))
					p = out[j] + push_dir * min_gap
					pushed = true
			if not pushed:
				break
			## Prefer separation over hard max clamp (dash still capped by caller max_r).
			var from_o := p - origin
			var dist := from_o.length()
			if dist > hi * 1.15 and dist > 0.01:
				p = origin + from_o.normalized() * (hi * 1.15)
		out.append(p)
	return out


## Split cart SKUs into box-sized piles for scatter drops.
static func loot_piles_from_cart(cart: Array) -> Array[Dictionary]:
	var groups: Dictionary = {}
	for sku in cart:
		var id := String(sku)
		groups[id] = int(groups.get(id, 0)) + 1
	var piles: Array[Dictionary] = []
	for id in groups.keys():
		var left := int(groups[id])
		while left > 0:
			var n := mini(BOX_SIZE, left)
			piles.append({"sku": String(id), "n": n})
			left -= n
	return piles


static func dirt_color(dtype: String) -> Color:
	match dtype:
		DIRT_TRASH:
			return Color(0.34, 0.27, 0.16, 0.88)
		DIRT_PUDDLE:
			return Color(0.35, 0.62, 0.82, 0.55)
		DIRT_VOMIT:
			return Color(0.55, 0.72, 0.22, 0.82)
	return Color(0.34, 0.27, 0.16, 0.8)


static func dirt_dissat(dtype: String) -> float:
	match dtype:
		DIRT_TRASH:
			return DISSAT_DIRT_TRASH
		DIRT_PUDDLE:
			return DISSAT_DIRT_PUDDLE
		DIRT_VOMIT:
			return DISSAT_DIRT_VOMIT
	return DISSAT_DIRT_PER_SEC


static func random_dirt_type() -> String:
	var kinds: Array[String] = [DIRT_TRASH, DIRT_PUDDLE, DIRT_VOMIT]
	return kinds[randi() % kinds.size()]


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
