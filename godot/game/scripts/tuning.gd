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

## Display names live in locale/data.csv (`sku.<id>`).
const SKU_IDS: Array[String] = [
	"can", "snack", "cup", "drink", "milk", "soda", "icecream", "meat", "rice",
]
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
## Price for BOX_SIZE pieces (legacy per-box). Charge with cost_for_pieces().
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

## Visual chunk / legacy save scale. Gameplay units are pieces.
const BOX_SIZE := 4
const SHELF_CAP := 12
## Starting / max warehouse display scale in pieces (was 99 boxes).
const RESTOCK_PIECES := 99 * BOX_SIZE
const RESTOCK_BOXES := 99 ## legacy alias; prefer RESTOCK_PIECES
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
## Tap-release shorter than this → dash; hold past this → run (no dash on that press).
const RUN_HOLD_THRESHOLD := 0.12
## Long-press cancel (B or ;) enters drop aim. A tap tosses focused pieces.
const DROP_HOLD_SEC := 0.2
## Player toss distance (10 身位 = 2× legacy 5). Future drop-range skills multiply via player.drop_toss_dist().
const DROP_TOSS_BODY_LENGTHS := 10.0
const DROP_TOSS_DIST := DROP_TOSS_BODY_LENGTHS * BODY_LENGTH
const DROP_DIR_DEADZONE := 0.35
## Legacy / cannon default flight time (small arc era). Player toss uses player_drop_flight_sec().
const DROP_FLIGHT_SEC := 0.28
## Baseline for player toss speed: old 5 身位 / 0.28s; then ×0.55 half-speed, then +20%.
const DROP_FLIGHT_BASELINE_BODY_LENGTHS := 5.0
const DROP_FLIGHT_SPEED_FACTOR := 0.66
## Short / charged toss: brief walk freeze so the player does not overtake the box.
const DROP_TOSS_MOVE_PAUSE_SEC := 0.16
## Player toss visual: full spins during flight (sprite only; trail stays straight).
const DROP_FLIGHT_SPINS := 2.0
const DROP_FEET_OFFSET := Vector2(0.0, 22.0)
## 投籃高手：第二件延遲出手 + 落點沿投向法線微偏，避免兩箱完全重疊。
const HOOP_ACE_SECOND_DELAY_SEC := 0.1
const HOOP_ACE_SIDE_OFFSET := 0.55 * BODY_LENGTH

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
## Dash hit (guests / thieves / clones). Wider than crowd so a dash into an aisle still registers.
const DASH_HIT_RANGE := 5.0 * BODY_LENGTH
const DASH_HIT_RANGE_SQ := DASH_HIT_RANGE * DASH_HIT_RANGE
## Crowd slow: guests/thieves within this radius of the player.
const CROWD_RADIUS := 3.0 * BODY_LENGTH
const CROWD_RADIUS_SQ := CROWD_RADIUS * CROWD_RADIUS
const CROWD_SPEED_MULT := 0.5
## Dash into a shopping guest: +dissat (base), stun, cart drops in place.
const DASH_GUEST_DISSAT := 50.0
const DASH_GUEST_STUN_SEC := 2.0
## Hand delivery, single toss, and box toss: each correct piece −15; a total miss +15.
const DELIVER_PIECE_DISSAT := 15.0
## Toss hit normal guest: wrong SKU dissatisfaction. Same step as DELIVER_PIECE_DISSAT.
const TOSS_GUEST_WRONG_DISSAT := 15.0
## Directional toss: guest within this of flight path / landing.
const DROP_GUEST_HIT_RADIUS := 72.0
## Prep: reset STR/AGI/INT costs level × this.
const STAT_RESET_FEE_PER_LEVEL := 1000
const SPEED_MAX_MULT := 5.0
const SPEED_FLOOR := 48.0

const CAMERA_ZOOM := 1.22
## Pause / View-button Loc.t("world.toss_range.farther") — slightly more shop in frame than CAMERA_ZOOM.
const CAMERA_ZOOM_FAR := 0.95
const INTERACT_RANGE := 100.0
const INTERACT_RANGE_SQ := INTERACT_RANGE * INTERACT_RANGE
const FACE_DOT := 0.18
## Customer seek: re-resolve shelf at most this often (seconds).
const SEEK_SHELF_REFRESH_SEC := 0.28
## Clerk idle job search throttle.
const CLERK_JOB_SEARCH_SEC := 0.35
## Security clerk: detect / catch radii and post-catch cooldown.
const SECURITY_DETECT_PX := 160.0
const SECURITY_CATCH_PX := 36.0
const SECURITY_CATCH_COOLDOWN_SEC := 0.6
## Slightly faster than AGI-10 walk while chasing.
const SECURITY_CHASE_SPEED_MULT := 1.25
## Cleaner clerk: detect / arrive radii (scrub uses clean_seconds(10)).
const CLEANER_DETECT_PX := 160.0
const CLEANER_ARRIVE_PX := 36.0
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
## Test-build「簡易」. Normal keeps the scenario rules. See storepreparationphase.md.
const EASY_LIST_CAP := 5
const EASY_DIRT_INTERVAL_MULT := 2.0
const EASY_DIRT_START := 1
const EASY_THIEF_RATE_MULT := 0.5
const EASY_DISSAT_MULT := 0.5
const LINGER_SEC := 1.0
const THINK_SEC := 3.0
const DISSAT_MAX := 100.0
const DISSAT_MISS := 18.0
const DISSAT_QUEUE_PER_SEC := 100.0 / 15.0
const DISSAT_DIRT_PER_SEC := 8.0
const CUSTOMER_ARRIVE_DIST := 40.0
## Must stay below cashier `slot_gap` (48): otherwise a one-slot advance is
## already "arrived" and queued guests never step forward after dequeue.
const QUEUE_SLOT_ARRIVE_DIST := 14.0
## Within this range of the assigned slot, walk straight (no A*) so queue
## compacting cannot detour around register solids toward another cashier.
const QUEUE_DIRECT_FOLLOW_DIST := 120.0
const CUSTOMER_SHELF_REACH := 80.0
## EliteCustomer（麻煩客人）— see docs/systemdesign/elitecustomer.md
const ELITE_SPAWN_CHANCE_MIN := 0.01
const ELITE_SPAWN_CHANCE_MAX := 0.05
## Prep「麻煩客人模式」：保證一名後，後續進店仍用此較高機率（方便測詞綴）。
const ELITE_TEST_SPAWN_CHANCE := 0.40
const ELITE_CONTACT_DIST := BODY_LENGTH
const ELITE_INCITE_RADIUS := 5.0 * BODY_LENGTH
const ELITE_AFFIX_CD_MIN := 5.0
const ELITE_AFFIX_CD_MAX := 15.0
const ELITE_ZOOM_SEC := 1.0
const ELITE_REVENUE_MULT := 2
const ELITE_LIST_MULT := {1: 2.0, 2: 2.5, 3: 3.0, 4: 3.5, 5: 4.0, 6: 5.0}
const ELITE_AFFIX_IDS: Array[String] = [
	"smash_shelf", "incite", "ruck_cart", "drive_off", "litterbug", "passive_shop",
]
## Live line: only LV1 unlocked until Beta story table. TEST / events may raise.
const ELITE_MAX_UNLOCKED_LV := 1
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
	## Legacy box-count formula; carry_items_from_str is the piece cap.
	return 1 + str_for_effects(str_stat) / 5


static func carry_items_from_str(str_stat: int = STR) -> int:
	return carry_boxes_from_str(str_stat) * BOX_SIZE


static func cost_for_pieces(sku: String, pieces: int) -> int:
	## Buying BOX_SIZE pieces costs SKU_COST (old 1-box price).
	return int(SKU_COST.get(sku, 0)) * maxi(pieces, 0) / BOX_SIZE


static func sku_piece_price_label(sku: String) -> int:
	## Floored display $/piece; line totals use cost_for_pieces.
	return int(SKU_COST.get(sku, 0)) / BOX_SIZE


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
	## Legacy NPC pacing helper; player checkout no longer uses Loading Circle.
	var a := float(int_for_effects(int_stat))
	return CHECKOUT_SECONDS_AT_10 + (CHECKOUT_SECONDS_AT_50 - CHECKOUT_SECONDS_AT_10) * (a - 10.0) / 40.0


## INT milestones → fewer checkout arrows (effect cap 50; allocate higher freely).
static func checkout_int_cmd_reduce(int_stat: int = INT) -> int:
	var a := int_for_effects(int_stat)
	var reduce := 0
	if a >= 20:
		reduce += 2
	if a >= 30:
		reduce += 1
	if a >= 40:
		reduce += 1
	if a >= 50:
		reduce += 1
	return reduce


const CHECKOUT_CMD_FLOOR := 2


static func checkout_command_count(item_count: int, int_stat: int = INT) -> int:
	return maxi(CHECKOUT_CMD_FLOOR, command_count(item_count) - checkout_int_cmd_reduce(int_stat))


## INT revenue bonus on personal checkout (0.0 … 0.20 at effect cap).
static func checkout_int_revenue_bonus(int_stat: int = INT) -> float:
	var a := int_for_effects(int_stat)
	if a >= 50:
		return 0.20
	if a >= 40:
		return 0.15
	if a >= 30:
		return 0.10
	if a >= 20:
		return 0.05
	return 0.0


const CHECKOUT_PERFECT_REVENUE_MULT := 1.05


static func checkout_perfect_revenue_mult() -> float:
	return CHECKOUT_PERFECT_REVENUE_MULT


## Apply INT + optional rush % then Perfect mult. `rush_bonus` is additive with INT %.
static func checkout_revenue_amount(base: int, int_stat: int, perfect: bool, rush_bonus: float = 0.0) -> int:
	if base <= 0:
		return 0
	var mult := 1.0 + checkout_int_revenue_bonus(int_stat) + maxf(0.0, rush_bonus)
	if perfect:
		mult *= checkout_perfect_revenue_mult()
	return maxi(0, int(round(float(base) * mult)))


static func cd_rate(int_stat: int = INT) -> float:
	var a := float(int_for_effects(int_stat))
	return CD_RATE_AT_10 + (CD_RATE_AT_50 - CD_RATE_AT_10) * (a - 10.0) / 40.0


static func cd_seconds(listed: float, int_stat: int = INT) -> float:
	return listed / cd_rate(int_stat)


static func sku_name(id: String) -> String:
	if id == "":
		return id
	return Loc.t("sku.%s" % id)


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


## Base checkout arrow count from cart size (before INT reduce / floor).
static func command_count(item_count: int) -> int:
	if item_count <= 5:
		return 7
	return 8


static func hit_damage(str_stat: int = STR) -> float:
	var a := float(str_for_effects(str_stat))
	return HIT_AT_10 + (HIT_AT_50 - HIT_AT_10) * (a - 10.0) / 40.0


static func dirt_type_name(dtype: String) -> String:
	match dtype:
		DIRT_TRASH:
			return Loc.t("dirt.trash")
		DIRT_PUDDLE:
			return Loc.t("dirt.puddle")
		DIRT_VOMIT:
			return Loc.t("dirt.vomit")
	return Loc.t("dirt.generic")


## Offset from player origin to drop destination.
## Zero / tiny toss_dir → push along facing via caller; here ZERO dir still returns feet offset for legacy.
## Prefer always passing a unit facing for player tosses.
static func drop_offset(toss_dir: Vector2, toss_dist: float = -1.0) -> Vector2:
	var dist := DROP_TOSS_DIST if toss_dist < 0.0 else toss_dist
	if toss_dir.length_squared() < 0.0001:
		return DROP_FEET_OFFSET
	return toss_dir.normalized() * dist


## Player toss flight time: half of legacy ground speed, scaled by actual distance.
static func player_drop_flight_sec(dist: float) -> float:
	var baseline_dist := DROP_FLIGHT_BASELINE_BODY_LENGTHS * BODY_LENGTH
	var baseline_speed := baseline_dist / DROP_FLIGHT_SEC
	var speed := maxf(1.0, baseline_speed * DROP_FLIGHT_SPEED_FACTOR)
	return maxf(0.05, absf(dist) / speed)


## Long-press drop charge rate (pieces / sec). STR_eff capped at 50 like carry.
static func drop_charge_per_sec(str_stat: float) -> float:
	return 2.0 + minf(str_stat, 50.0) / 5.0


## Evenly spaced points on a circle (boss reject ring, etc.).
static func loot_even_ring_positions(origin: Vector2, count: int, radius: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if count <= 0:
		return out
	var r := maxf(radius, 1.0)
	if count == 1:
		out.append(origin + Vector2(r, 0))
		return out
	for i in count:
		var ang := TAU * float(i) / float(count) - PI * 0.5
		out.append(origin + Vector2(cos(ang), sin(ang)) * r)
	return out


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


## Guest list upper bound. Easy never raises a scenario that is already under the cap.
static func list_hi(hi: int, easy: bool) -> int:
	return mini(hi, EASY_LIST_CAP) if easy else hi


static func list_lo(lo: int, hi: int) -> int:
	return mini(lo, hi)


static func dirt_interval(sec: float, easy: bool) -> float:
	return sec * EASY_DIRT_INTERVAL_MULT if easy else sec


static func dirt_start(easy: bool) -> int:
	return EASY_DIRT_START if easy else DIRT_START_COUNT


static func thief_rate(rate: float, easy: bool) -> float:
	return rate * EASY_THIEF_RATE_MULT if easy else rate


static func dissat_gain(amount: float, easy: bool) -> float:
	if amount <= 0.0:
		return 0.0
	return amount * EASY_DISSAT_MULT if easy else amount


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


static func elite_spawn_chance() -> float:
	return randf_range(ELITE_SPAWN_CHANCE_MIN, ELITE_SPAWN_CHANCE_MAX)


static func elite_list_mult(lv: int) -> float:
	return float(ELITE_LIST_MULT.get(clampi(lv, 1, 6), 2.0))


static func elite_affix_count(lv: int) -> int:
	return clampi(lv, 1, 6)


## Default: effect LV == guest LV. Beta may remap per affix.
static func elite_affix_effect_lv(guest_lv: int, _affix: String) -> int:
	return clampi(guest_lv, 1, 6)


static func elite_smash_pct(effect_lv: int) -> float:
	match clampi(effect_lv, 1, 6):
		1:
			return 0.5
		2:
			return 0.6
		3:
			return 0.7
		4:
			return 0.8
		5:
			return 0.9
		_:
			return 1.0


static func elite_ruck_pct(effect_lv: int) -> float:
	return elite_smash_pct(effect_lv)


static func elite_incite_per_sec(effect_lv: int) -> float:
	return float(clampi(effect_lv, 1, 6))


static func elite_drive_dissat(effect_lv: int) -> float:
	return 40.0 + 10.0 * float(clampi(effect_lv, 1, 6))


static func elite_litter_pool(guest_lv: int) -> Array[String]:
	var lv := clampi(guest_lv, 1, 6)
	if lv <= 2:
		return [DIRT_TRASH] as Array[String]
	if lv <= 4:
		return [DIRT_TRASH, DIRT_PUDDLE] as Array[String]
	return [DIRT_TRASH, DIRT_PUDDLE, DIRT_VOMIT] as Array[String]


static func elite_roll_affixes(lv: int) -> Array[String]:
	var need := elite_affix_count(lv)
	var pool: Array[String] = ELITE_AFFIX_IDS.duplicate()
	pool.shuffle()
	var out: Array[String] = []
	for i in mini(need, pool.size()):
		out.append(pool[i])
	return out


static func elite_roll_level(max_unlocked: int = ELITE_MAX_UNLOCKED_LV) -> int:
	return clampi(randi_range(1, maxi(1, max_unlocked)), 1, 6)


static func dir_name(code: int) -> String:
	match code:
		0:
			return Loc.t("dir.up")
		1:
			return Loc.t("dir.down")
		2:
			return Loc.t("dir.left")
		3:
			return Loc.t("dir.right")
	return "?"
