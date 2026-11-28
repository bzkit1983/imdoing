extends RefCounted
## Prep-phase progress. Persist with to_dict / save_to_disk via PlatformServices.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const XpRules = preload("res://scripts/session/xp_rules.gd")

## Bump when the save schema changes; from_dict must migrate or reject.
## 2+: stock is pieces. v1 saves store boxes and are multiplied by BOX_SIZE on load.
## 3+: shop_rating / rating_history / difficulty / last_* rating fields.
## 4+: day_index / active_tasks_by_seat / task test selection (tasksystem.md).
## 5+: pending goods cultivation.
## 6+: completion of the Genesis quiz.
## 7+: unlocked_skus / unlocked_furniture / prologue_boss_unlocked (content gates).
## 8+: fish_stock / fishing_taro_played (theme_historic fish tank).
## 9+: elite_clerks (named upgradeable staff; see eliteclerk.md).
## 10+: branch / theme stores (active_theme_id, theme_stores, origin_store, elite assignment).
const SAVE_VERSION := 10
const EliteClerkCatalog = preload("res://scripts/session/elite_clerk_catalog.gd")
const BranchRules = preload("res://scripts/session/branch_rules.gd")
const ThemeStoreSnapshot = preload("res://scripts/session/theme_store_snapshot.gd")
const BranchState = preload("res://scripts/session/branch_state.gd")
const LIGHT_ULTIMATE := "let_there_be_light"
const RatingRules = preload("res://scripts/session/rating_rules.gd")

## Prologue hold-cash goals (story/prologue.md). Evaluated as shop_money.
## Must stay strictly above PROLOGUE_START_MONEY so day-1 shop_money tasks do not auto-clear.
const PROLOGUE_MONEY_GOAL_1 := 3500
const PROLOGUE_MONEY_GOAL_2 := 4500
const PROLOGUE_MONEY_GOAL_3 := 5500
const PROLOGUE_PROCURE_CAN_PIECES := 4
## Bare open path before money_goal_1:
## cashier 1000 + restock_dry×2 1000 + shelf_dry_4×2 80 + snack develop 200 + can×4 10 = 2290.
## Start uses rounded floor above that bare min, and below goal_1.
const PROLOGUE_START_MONEY_MIN := 2290
const PROLOGUE_START_MONEY := 2500
const PROLOGUE_BOSS_FUND_REWARD := 2000
const SCENARIO_PROLOGUE := 8
## Test: theme_historic cooked-stall sandbox (blueprint from scenario 4).
const SCENARIO_HISTORIC_COOKED := 9
## Test: elite-clerk ops-day on 安桃山 blueprint (scenario 9 layout + full catalog unlocked).
const SCENARIO_ELITE_CLERK := 10
## Test: branch-store vertical slice — HQ theme_historic, branch origin.
const SCENARIO_BRANCH := 11

const CELL := 64.0
const WAGE := 100
const LEVEL_CAP := XpRules.LEVEL_CAP
## Legacy float-text fallbacks; settle uses XpRules.rates_for_level(level).
const XP_CLOSE := 80
const XP_SERVE := 3
const XP_CATCH := 15
const XP_CLEAN := 6
const XP_ELITE_SERVE := 12
## Total area cap (cells²). Default square side = floor(sqrt(area)).
const SCALE_AREA := {1: 100, 2: 180, 3: 280, 4: 400, 5: 560, 6: 720}
const SCALE_COST := {2: 4000, 3: 8000, 4: 15000, 5: 25000, 6: 40000}
const HIRE_CAP := {1: 0, 2: 2, 3: 2, 4: 3, 5: 4, 6: 5}
const SCALE_MAX_LV := 6
## Default grid side after expand (floor √area). Kept as SCALE_MAX for callers.
const SCALE_MAX := {1: 10, 2: 13, 3: 16, 4: 20, 5: 23, 6: 26}
const CULTIVATION_WAIT := [0, 2, 4, 8]
## Preview weights in hundredths of a percent. Reward pools are not active yet.
const CULTIVATION_REWARD_WEIGHTS := {
	"ultimate": 1,
	"skill": 5,
	"facility": 10,
	"appearance": 10,
	"consumable": 2000,
	"goods": 3000,
	"ingredient": 4974,
}
## Keys contain sorted SKU IDs, including duplicate pieces.
const CULTIVATION_RECIPES := {
	"can": ["drink", "icecream"],
	"can,can": ["snack", "cup"],
	"can,drink": ["soda"],
	"drink,icecream": ["milk"],
	"can,icecream,milk": ["meat"],
	"can,cup,meat": ["rice"],
}

## Display names live in locale/data.csv (`furniture.<id>`).
const FURNITURE := {
	"cashier": {"price": 1000, "w": 2, "h": 1, "unlock": 1},
	## Test: fully buyable. Story place_cap later; afterstory uncapped (shopitem.md).
	"self_cashier": {"price": 2500, "w": 2, "h": 1, "unlock": 1},
	"restock_dry": {"price": 500, "w": 2, "h": 2, "unlock": 1},
	"restock_frozen": {"price": 700, "w": 2, "h": 2, "unlock": 4},
	"restock_ice": {"price": 800, "w": 2, "h": 2, "unlock": 7},
	"shelf_dry_4": {"price": 40, "w": 2, "h": 1, "unlock": 1, "cap": 4},
	"shelf_dry_8": {"price": 70, "w": 2, "h": 1, "unlock": 1, "cap": 8},
	"shelf_dry_12": {"price": 100, "w": 2, "h": 1, "unlock": 1, "cap": 12},
	"shelf_dry_24": {"price": 200, "w": 2, "h": 1, "unlock": 1, "cap": 24},
	"shelf_frozen_4": {"price": 70, "w": 2, "h": 1, "unlock": 4, "cap": 4},
	"shelf_frozen_8": {"price": 130, "w": 2, "h": 1, "unlock": 4, "cap": 8},
	"shelf_frozen_12": {"price": 200, "w": 2, "h": 1, "unlock": 4, "cap": 12},
	"shelf_frozen_24": {"price": 400, "w": 2, "h": 1, "unlock": 4, "cap": 24},
	"shelf_ice_4": {"price": 100, "w": 2, "h": 1, "unlock": 7, "cap": 4},
	"shelf_ice_8": {"price": 200, "w": 2, "h": 1, "unlock": 7, "cap": 8},
	"shelf_ice_12": {"price": 300, "w": 2, "h": 1, "unlock": 7, "cap": 12},
	"shelf_ice_24": {"price": 600, "w": 2, "h": 1, "unlock": 7, "cap": 24},
	## Event-grant only (shopitem.md). Cap 4 ends = 2 pairs. Test: grant owned freely.
	"portal": {"price": 0, "w": 2, "h": 1, "unlock": 1, "grant_only": true, "owned_cap": 4},
	## theme_historic: cooked stall (buy after unlock) + fish tank (grant after fishing).
	"cooked_stall": {"price": 1000, "w": 2, "h": 1, "unlock": 99, "cap": 8},
	"fish_tank": {"price": 0, "w": 2, "h": 2, "unlock": 1, "grant_only": true, "owned_cap": 1},
}

## Warehouse `stock` dict changed (restock pull / closeout credit). Demo broadcasts on LAN.
signal warehouse_changed()

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
## Appearance palette 0..3 (CharacterSheet.TINT_COUNT).
var tint: int = 0
## Appearance model id (see session/skin_catalog.gd).
var skin_id: String = "player"
## Unlocked skin ids. Empty ⇒ all catalog skins unlocked (BETA).
var unlocked_skins: Array = []
var developed: Dictionary = {}
## Per developed SKU: true = offer for sale this ops round. Missing key ⇒ sellable.
var for_sale: Dictionary = {}
var stock: Dictionary = {}
## theme_historic fish materials: fish_id → piece count (not sellable SKUs).
var fish_stock: Dictionary = {}
## First completed fishing_taro visit grants fish_tank.
var fishing_taro_played: bool = false
var owned: Dictionary = {}
var placed: Array[Dictionary] = []
var shop_scale: int = 1
var grid_w: int = 10
var grid_h: int = 10
var clerks: Array[Dictionary] = []
## Owned elite clerks: {id, level, on_duty, roles, register, source, assignment?}. See eliteclerk.md.
var elite_clerks: Array[Dictionary] = []
## Branch / theme-store model (branchstore.md). Shared money stays top-level.
var active_theme_id: String = BranchRules.ORIGIN_ID
var themes_cleared: Array = []
var theme_stores: Dictionary = {}
var origin_store: Dictionary = {}
## Live HQ policy / posts (mirrored into active ThemeStoreDict on write-back).
var policy: String = BranchRules.POLICY_BALANCED
var branch_posts: Dictionary = BranchRules.empty_posts()
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
## Host shop rating (floor 0). See ratingsystem.md.
var shop_rating: int = 0
## Recent day grades (−3…+3), newest last; max RatingRules.HISTORY_MAX.
var rating_history: Array = []
## Persist difficulty enum: easy / normal / hard (gameplay tables still stub).
var difficulty: String = RatingRules.DIFF_NORMAL
var last_ops_rating: int = RatingRules.OPS_START
var last_grade: int = 0
## Last difficulty-suggestion streak key that was accepted or dismissed.
var difficulty_prompt_acked: String = ""
## Support-other-shop rating when this character visits online (multiplayer.md §12.8).
var support_rating: int = 0
## Closed ops days (increments on every close including early close).
var day_index: int = 0
var cultivation: Dictionary = {}
var light_quiz_passed := false
## seat id string → Array of task runtime rows (see session/task_tracker.gd).
var active_tasks_by_seat: Dictionary = {}
## Prep「測試任務」: off | pack | random
var task_test_mode: String = "off"
var task_test_pack_id: String = "OP-TUT-001"
var task_test_seed: int = 1
## Tutorial progress: lesson_id → { status, step_id?, pages_acked? } (tutorial.md).
var tutorial_progress: Dictionary = {}
## Product H2: player declined／skipped the tutorial campaign (persist across days).
var tutorial_skipped: bool = false
## Content gates (product: level never unlocks directly). Missing key ⇒ locked.
var unlocked_skus: Dictionary = {}
var unlocked_furniture: Dictionary = {}
## Prologue money_goal_3 cleared → boss ops day eligible.
var prologue_boss_unlocked: bool = false


func _init() -> void:
	_install_new_game_sets()


func apply_scenario(id: int) -> void:
	scenario = id
	developed.clear()
	for_sale.clear()
	stock.clear()
	fish_stock.clear()
	fishing_taro_played = false
	owned.clear()
	placed.clear()
	clerks.clear()
	elite_clerks.clear()
	day_procurement = 0
	last_loss = false
	level_note = ""
	shop_rating = 0
	rating_history.clear()
	difficulty = RatingRules.DIFF_NORMAL
	last_ops_rating = RatingRules.OPS_START
	last_grade = 0
	day_index = 0
	cultivation.clear()
	light_quiz_passed = false
	active_tasks_by_seat.clear()
	task_test_mode = "off"
	task_test_pack_id = "OP-TUT-001"
	task_test_seed = 1
	difficulty_prompt_acked = ""
	support_rating = 0
	tutorial_progress.clear()
	tutorial_skipped = false
	unlocked_skus.clear()
	unlocked_furniture.clear()
	prologue_boss_unlocked = false
	active_theme_id = BranchRules.ORIGIN_ID
	themes_cleared.clear()
	theme_stores.clear()
	origin_store.clear()
	policy = BranchRules.POLICY_BALANCED
	branch_posts = BranchRules.empty_posts()
	_install_new_game_sets()
	match id:
		2:
			_scenario_mid()
		3:
			_scenario_late()
		4:
			_scenario_skill()
		5:
			_scenario_tutorial()
		6:
			## Boss-battle test day — same shop blueprint as skill sandbox (scenario 4).
			_scenario_skill()
		7:
			## New furniture test: scenario 4 blueprint, one self-checkout instead of cashiers.
			_scenario_self_cashier_test()
		SCENARIO_HISTORIC_COOKED:
			## 安桃山時代：熟食檔測試（藍本同劇本4，乾貨／魚缸／熟食檔）。
			_scenario_historic_cooked()
		SCENARIO_ELITE_CLERK:
			## 精英店員營運日測試（藍本同劇本4；目錄全員 debug 解鎖）。
			_scenario_elite_clerk()
		SCENARIO_BRANCH:
			## 分店垂直切片：本店安桃山、分店起源。
			_scenario_branch()
		SCENARIO_PROLOGUE:
			_scenario_prologue()
		_:
			_scenario_new()
	_ensure_test_portal_owned()
	_grant_initial_goods()
	_seed_content_unlocks_for_scenario()
	_default_for_sale_for_developed()
	if scenario == SCENARIO_ELITE_CLERK:
		_finalize_elite_clerk_scenario()
	elif scenario == SCENARIO_HISTORIC_COOKED:
		_finalize_historic_cooked_scenario()
	elif scenario == SCENARIO_BRANCH:
		_finalize_branch_scenario()


func is_boss_test_scenario() -> bool:
	return scenario == 6


func is_prologue_story_scenario() -> bool:
	return scenario == SCENARIO_PROLOGUE


## 安桃山 place shell／熟食閘（劇本9、10、11）。
func uses_historic_place_scenario() -> bool:
	return (
		scenario == SCENARIO_HISTORIC_COOKED
		or scenario == SCENARIO_ELITE_CLERK
		or scenario == SCENARIO_BRANCH
	)


func branch_system_unlocked() -> bool:
	return BranchState.branch_system_unlocked(self)


func _grant_initial_goods() -> void:
	## Starter SKU always developed; stock key may be 0.
	## Do NOT force for_sale on — prep／scenario may set can 不可售 (e.g. 安桃山).
	developed["can"] = true
	if not stock.has("can"):
		stock["can"] = 0
	if not for_sale.has("can"):
		for_sale["can"] = true


## Intro／序章-like scenarios use gated unlocks; demo sandboxes unlock everything.
func uses_prologue_content_gates() -> bool:
	return scenario == 1 or scenario == 5 or scenario == SCENARIO_PROLOGUE


func _seed_content_unlocks_for_scenario() -> void:
	unlocked_skus.clear()
	unlocked_furniture.clear()
	prologue_boss_unlocked = false
	if uses_prologue_content_gates():
		_seed_prologue_starter_unlocks()
	else:
		unlock_all_content()


func _seed_prologue_starter_unlocks() -> void:
	unlock_sku("can")
	unlock_furniture("cashier")
	unlock_furniture("restock_dry")
	unlock_furniture("shelf_dry_4")


func unlock_all_content() -> void:
	for sku in Tuning.SELLABLE_SKUS:
		unlocked_skus[sku] = true
	for type in FURNITURE.keys():
		if bool(FURNITURE[type].get("grant_only", false)):
			continue
		unlocked_furniture[type] = true
	prologue_boss_unlocked = true


func unlock_sku(sku: String) -> bool:
	if sku == "" or not Tuning.SELLABLE_SKUS.has(sku):
		return false
	if unlocked_skus.has(sku):
		return false
	unlocked_skus[sku] = true
	return true


func unlock_furniture(type: String) -> bool:
	if type == "" or not FURNITURE.has(type):
		return false
	if bool(FURNITURE[type].get("grant_only", false)):
		return false
	if unlocked_furniture.has(type):
		return false
	unlocked_furniture[type] = true
	return true


func unlock_prologue_boss() -> bool:
	if prologue_boss_unlocked:
		return false
	prologue_boss_unlocked = true
	return true


## Apply task／story reward rows: {type, id?} — unlock_sku｜unlock_furniture｜unlock_prologue_boss.
func apply_content_rewards(rewards: Array) -> void:
	for raw in rewards:
		if not (raw is Dictionary):
			continue
		var row: Dictionary = raw
		var kind := String(row.get("type", ""))
		match kind:
			"unlock_sku":
				unlock_sku(String(row.get("id", "")))
			"unlock_furniture":
				unlock_furniture(String(row.get("id", "")))
			"unlock_prologue_boss":
				unlock_prologue_boss()
			_:
				pass


func _prologue_essentials_owned() -> bool:
	return (
		int(owned.get("cashier", 0)) >= 1
		and int(owned.get("restock_dry", 0)) >= 1
		and int(owned.get("shelf_dry_4", 0)) >= 1
	)


## Mirror prologue.md step grants when story packs are not yet driving unlocks.
## Safe to call often from Prep after buy／develop／load.
func sync_prologue_progress_grants() -> void:
	if not uses_prologue_content_gates():
		return
	_seed_prologue_starter_unlocks()
	for sku_v in developed.keys():
		unlock_sku(String(sku_v))
	## Step 2→3: procure can → snack develop eligibility.
	if _prologue_essentials_owned() and int(stock.get("can", 0)) >= PROLOGUE_PROCURE_CAN_PIECES:
		unlock_sku("snack")
	## money_goal_1 → drink + frozen 4-slot line (after snack＋dry expand).
	if (
		developed.has("snack")
		and int(owned.get("shelf_dry_4", 0)) >= 2
		and int(owned.get("restock_dry", 0)) >= 2
		and money >= PROLOGUE_MONEY_GOAL_1
	):
		unlock_sku("drink")
		unlock_furniture("shelf_frozen_4")
		unlock_furniture("restock_frozen")
	## money_goal_2 → milk (after drink＋first frozen set).
	if (
		developed.has("drink")
		and int(owned.get("shelf_frozen_4", 0)) >= 1
		and int(owned.get("restock_frozen", 0)) >= 1
		and money >= PROLOGUE_MONEY_GOAL_2
	):
		unlock_sku("milk")
	## money_goal_3 → boss day (after milk＋second frozen set).
	if (
		developed.has("milk")
		and int(owned.get("shelf_frozen_4", 0)) >= 2
		and int(owned.get("restock_frozen", 0)) >= 2
		and money >= PROLOGUE_MONEY_GOAL_3
	):
		unlock_prologue_boss()


func _migrate_unlocks_from_level() -> void:
	for sku in Tuning.SELLABLE_SKUS:
		if level >= int(Tuning.SKU_UNLOCK_LV.get(sku, 99)):
			unlocked_skus[sku] = true
	for type in FURNITURE.keys():
		if bool(FURNITURE[type].get("grant_only", false)):
			continue
		if level >= int(FURNITURE[type].get("unlock", 99)):
			unlocked_furniture[type] = true
	for sku_v in developed.keys():
		unlocked_skus[String(sku_v)] = true
	if unlocked_skus.is_empty():
		_seed_content_unlocks_for_scenario()


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
	## Test／ALPHA：傳送門事件授予（4 端＝2 對），未預放；店舖設計可自由配置。
	## 劇本 5 教學不加（見 `_ensure_test_portal_owned`）。
	_ensure_test_portal_owned()


## Test-only tutorial campaign: empty shop like new game, $3000 (tutorial.md).
## Can stock comes from prep buy-stock lesson (no free gift).
## Skill loadouts start empty so equip-skills lesson teaches from a blank slate.
## Always 簡易（persist difficulty + prep play difficulty forced in demo／prep_menu）.
## No portals — tutorial stay focused on core prep／ops.
func _scenario_tutorial() -> void:
	_scenario_new()
	money = 3000
	difficulty = RatingRules.DIFF_EASY
	_install_blank_skill_sets()
	_clear_portals_for_tutorial()


## Story-mode prologue (story/prologue.md): empty shop, design start cash, content gates.
## Skips tutorial campaign; money goals／SKU／furniture progress via sync＋ST-PROLOGUE-MONEY.
func _scenario_prologue() -> void:
	_scenario_new()
	money = PROLOGUE_START_MONEY
	_clear_portals_for_tutorial()
	task_test_mode = "pack"
	task_test_pack_id = "ST-PROLOGUE-MONEY"
	task_test_seed = 1


## ALPHA／測試：非序章閘劇本可擁有最多 4 端傳送門以便店舖設計配置。序章／教學不加。
func _ensure_test_portal_owned() -> void:
	if uses_prologue_content_gates():
		_clear_portals_for_tutorial()
		return
	var cap := furniture_owned_cap("portal")
	if int(owned.get("portal", 0)) < cap:
		owned["portal"] = cap


func _clear_portals_for_tutorial() -> void:
	owned.erase("portal")
	var i := placed.size() - 1
	while i >= 0:
		if is_portal_type(String(placed[i].get("type", ""))):
			placed.remove_at(i)
		i -= 1


func is_intro_scenario() -> bool:
	return scenario == 1 or scenario == 5 or scenario == SCENARIO_PROLOGUE


func tutorial_status(lesson_id: String) -> String:
	var row = tutorial_progress.get(lesson_id, null)
	if row is Dictionary:
		return String(row.get("status", "unseen"))
	return "unseen"


func tutorial_row(lesson_id: String) -> Dictionary:
	var row = tutorial_progress.get(lesson_id, null)
	if row is Dictionary:
		return (row as Dictionary).duplicate(true)
	return {"status": "unseen"}


func set_tutorial_row(lesson_id: String, row: Dictionary) -> void:
	if lesson_id == "":
		return
	tutorial_progress[lesson_id] = row.duplicate(true)


func mark_tutorial_done(lesson_id: String) -> void:
	if lesson_id == "":
		return
	tutorial_progress[lesson_id] = {"status": "done", "pages_acked": true}


func mark_tutorial_skipped() -> void:
	## Skip remaining／all campaign lessons; Director must not start new ones.
	tutorial_skipped = true
	const Catalog = preload("res://scripts/tutorial/tutorial_catalog.gd")
	for lesson in Catalog.all_lessons():
		if not (lesson is Dictionary):
			continue
		var lid := String((lesson as Dictionary).get("id", ""))
		if lid != "":
			mark_tutorial_done(lid)


func list_tutorial_done_ids() -> Array[String]:
	var out: Array[String] = []
	for id in tutorial_progress.keys():
		var row = tutorial_progress[id]
		if row is Dictionary and String(row.get("status", "")) == "done":
			out.append(String(id))
	out.sort()
	return out


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
		stock[sku] = 50 * Tuning.BOX_SIZE
	owned = {
		"cashier": 1, "restock_dry": 1, "restock_frozen": 1,
		"shelf_dry_12": 2, "shelf_frozen_12": 2, "portal": 4,
	}
	_place("restock_frozen", 1, 1, 0)
	_place("restock_dry", 1, 5, 0)
	_place("shelf_frozen_12", 5, 2, 0)
	_place("shelf_frozen_12", 8, 2, 0)
	_place("shelf_dry_12", 5, 6, 0)
	_place("shelf_dry_12", 8, 6, 0)
	_place("cashier", 10, 12, 0)
	_place("portal", 3, 12, 0, "", "p1")
	_place("portal", 12, 3, 0, "", "p1")
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
		stock[sku] = Tuning.RESTOCK_PIECES
	owned = {
		"cashier": 2,
		"restock_dry": 1, "restock_frozen": 1, "restock_ice": 1,
		"shelf_dry_12": 2, "shelf_frozen_12": 2, "shelf_ice_12": 2,
		"portal": 4,
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
	_place("portal", 16, 2, 1, "", "p1")
	_place("portal", 16, 16, 1, "", "p1")
	clerks.append({"role": "cashier", "register": 0})
	clerks.append({"role": "restock", "register": 0})


## Skill sandbox. LV10 budget is 45 points (9 level-ups × 5).
## Stats sit at 20 (30 points spent from base 10); 15 stay unspent.
## Every shop item is owned twice. The floor is 18×10 so a round can start:
## two cashiers beside the door, two frozen restock racks on the left,
## two dry restock racks on the right, and a matching pair of 12-slot shelves
## for each of those categories (the open check needs a shelf with its restock).
## Also grants／pre-places 2 portal pairs (4 ends) for travel tests.
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
		stock[sku] = 50 * Tuning.BOX_SIZE
	for type in FURNITURE.keys():
		owned[type] = 2
	## Scenario 4／6：傳送門 2 對對角（左上↔右下、右上↔左下）；可於店舖設計改位。
	owned["portal"] = 4
	# Door is cells (8,0) and (9,0). Cashiers one row below, one cell away.
	_place("cashier", 6, 1, 0)
	_place("cashier", 10, 1, 0)
	_place("restock_frozen", 0, 2, 0, "milk")
	_place("restock_frozen", 0, 5, 0, "drink")
	_place("restock_dry", 16, 2, 0, "snack")
	_place("restock_dry", 16, 5, 0, "can")
	_place("shelf_frozen_12", 4, 3, 0)
	_place("shelf_frozen_12", 4, 6, 0)
	_place("shelf_dry_12", 12, 3, 0)
	_place("shelf_dry_12", 12, 6, 0)
	## p1: top-left → bottom-right. Face into the floor.
	_place("portal", 2, 1, 2, "", "p1")
	_place("portal", 14, 8, 0, "", "p1")
	## p2: top-right → bottom-left.
	_place("portal", 14, 1, 2, "", "p2")
	_place("portal", 2, 8, 0, "", "p2")
	clerks.append({"role": "restock", "register": 0})
	clerks.append({"role": "cashier", "register": 0})


## Scenario 10：精英店員營運日測試。安桃山 place shell；店鋪／已開發商品 bake 自 2026-11-26 活線存檔。
func _scenario_elite_clerk() -> void:
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
	grid_h = 13
	fishing_taro_played = true
	## Developed retail + cooked craft（can 開發但不可售，見 finalize）。
	for sku in [
		"can", "grain", "soy_sauce", "snack", "drink", "milk", "icecream",
		"onigiri", "yakimochi", "nigiri",
	]:
		developed[sku] = true
		if not Tuning.is_craft_only(sku) and sku != "can":
			stock[sku] = 50 * Tuning.BOX_SIZE
	stock["can"] = 0
	for fid in Tuning.FISH_IDS:
		fish_stock[fid] = 40
	owned.clear()
	owned["cashier"] = 1
	owned["cooked_stall"] = 1
	owned["fish_tank"] = 1
	owned["restock_dry"] = 3
	owned["restock_frozen"] = 2
	owned["restock_ice"] = 1
	owned["shelf_dry_12"] = 3
	owned["shelf_frozen_24"] = 2
	owned["shelf_ice_24"] = 1
	owned["portal"] = 2
	## Live prep layout（2026-11-26 save）：魚缸門口左、熟食檔、乾貨左排、冷藏／冰櫃右排。
	_place("fish_tank", 1, 0, 0)
	_place("cooked_stall", 4, 2, 0)
	_place("restock_dry", 1, 3, 0, "grain")
	_place("cashier", 8, 5, 0)
	_place("shelf_dry_12", 4, 5, 0)
	_place("shelf_frozen_24", 12, 5, 0)
	_place("restock_dry", 1, 6, 0, "soy_sauce")
	_place("restock_frozen", 15, 3, 0, "drink")
	_place("restock_frozen", 15, 6, 0, "milk")
	_place("shelf_dry_12", 4, 7, 0)
	_place("shelf_frozen_24", 12, 7, 0)
	_place("restock_dry", 1, 9, 0, "snack")
	_place("shelf_dry_12", 4, 9, 0)
	_place("shelf_ice_24", 12, 9, 0)
	_place("restock_ice", 15, 9, 0, "icecream")
	## 一對傳送門：右上 ↔ 右下（面向店內）。
	_place("portal", 16, 0, 2, "", "p1")
	_place("portal", 16, 12, 0, "", "p1")
	clerks.append({"role": "cashier", "register": 0})
	clerks.append({"role": "restock", "register": 0})
	for eid in EliteClerkCatalog.all_ids():
		var id := String(eid)
		unlock_elite_clerk(id, "debug")
		var i := _elite_index(id)
		if i >= 0:
			## 多數 level_max＝10；個別（如 kiko＝8）夾在目錄上限。
			elite_clerks[i]["level"] = EliteClerkCatalog.level_max(id)


## Scenario 11：分店垂直切片。本店＝安桃山（theme_historic）；分店＝起源店。
func _scenario_branch() -> void:
	## HQ shop = historic cooked blueprint (same as scenario 9).
	_scenario_historic_cooked()
	active_theme_id = "theme_historic"
	themes_cleared = ["theme_historic"]
	policy = BranchRules.POLICY_BALANCED
	branch_posts = BranchRules.empty_posts()
	## Origin branch: small operable shop with stock + one hiree as manager.
	var origin := ThemeStoreSnapshot.default_theme_store()
	origin["shop_scale"] = 2
	origin["grid_w"] = 10
	origin["grid_h"] = 10
	origin["shop_rating"] = 2
	origin["policy"] = BranchRules.POLICY_BALANCED
	origin["developed"] = {"can": true, "snack": true, "drink": true}
	origin["for_sale"] = {"can": true, "snack": true, "drink": true}
	origin["stock"] = {
		"can": 8,
		"snack": 8,
		"drink": 8,
	}
	origin["owned"] = {
		"cashier": 1,
		"restock_dry": 1,
		"shelf_dry_8": 2,
	}
	origin["placed"] = [
		{"type": "cashier", "x": 4, "y": 4, "rot": 0, "w": 2, "h": 1},
		{"type": "restock_dry", "x": 1, "y": 2, "rot": 0, "w": 2, "h": 2, "default_sku": "snack"},
		{"type": "shelf_dry_8", "x": 4, "y": 2, "rot": 0, "w": 2, "h": 1},
		{"type": "shelf_dry_8", "x": 6, "y": 2, "rot": 0, "w": 2, "h": 1},
	]
	origin["clerks"] = [
		{"role": "cashier", "register": 0},
		{"role": "restock", "register": 0},
	]
	origin["branch_posts"] = {
		"manager": {"kind": "clerk", "id": 0},
		"cashier": null,
		"restock": {"kind": "clerk", "id": 1},
		"cleaner": null,
		"security": null,
	}
	origin_store = origin
	## Unlock one elite for Prep assignment tests (off HQ duty).
	unlock_elite_clerk("yayoi", "debug")
	var yi := _elite_index("yayoi")
	if yi >= 0:
		elite_clerks[yi]["on_duty"] = false
		elite_clerks[yi]["level"] = EliteClerkCatalog.level_max("yayoi")


func _finalize_branch_scenario() -> void:
	## Mirror scenario 9 finalize for HQ sell flags, then snapshot HQ.
	_finalize_historic_cooked_scenario()
	theme_stores["theme_historic"] = ThemeStoreSnapshot.pack_from_state(self)
	## origin_store already baked in _scenario_branch.
	active_theme_id = "theme_historic"
	ThemeStoreSnapshot.hydrate_into_state(self, theme_stores["theme_historic"])


## Scenario 7：劇本4 藍本；收起普通收銀機，門口下一台自助收銀機。無收銀店員（自助機不可綁）。
func _scenario_self_cashier_test() -> void:
	_scenario_skill()
	var kept: Array[Dictionary] = []
	for it in placed:
		if String(it.get("type", "")) == "cashier":
			continue
		kept.append(it)
	placed = kept
	## Door cells (8,0)–(9,0); one self-checkout three rows below the door.
	_place("self_cashier", 8, 4, 0)
	if int(owned.get("self_cashier", 0)) < 1:
		owned["self_cashier"] = 1
	var kept_clerks: Array[Dictionary] = []
	for c in clerks:
		if String(c.get("role", "")) == "cashier":
			continue
		kept_clerks.append(c)
	clerks = kept_clerks


## Scenario 9：安桃山時代 — 熟食檔功能測試。藍本同劇本4 規模／三圍／資金；無凍櫃／傳送門。
func _scenario_historic_cooked() -> void:
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
	## Shelf retail: grain／soy／snack. Cooked three developed for stall guests.
	for sku in ["grain", "soy_sauce", "snack", "onigiri", "yakimochi", "nigiri"]:
		developed[sku] = true
		if not Tuning.is_craft_only(sku):
			stock[sku] = 50 * Tuning.BOX_SIZE
	for fid in Tuning.FISH_IDS:
		fish_stock[fid] = 12
	fishing_taro_played = true
	owned.clear()
	owned["cashier"] = 1
	owned["restock_dry"] = 3
	owned["shelf_dry_12"] = 3
	owned["cooked_stall"] = 1
	owned["fish_tank"] = 1
	## Door (8,0)–(9,0). Layout from live 安桃山 prep save (2026-11-25).
	_place("cashier", 8, 1, 0)
	_place("restock_dry", 16, 2, 0, "snack")
	_place("restock_dry", 1, 3, 0, "grain")
	_place("restock_dry", 1, 6, 0, "soy_sauce")
	_place("shelf_dry_12", 12, 3, 0)
	_place("shelf_dry_12", 4, 5, 0)
	_place("shelf_dry_12", 4, 7, 0)
	_place("cooked_stall", 8, 5, 0)
	_place("fish_tank", 8, 8, 0)
	clerks.append({"role": "cashier", "register": 0})
	clerks.append({"role": "restock", "register": 0})


## After shared apply_scenario helpers: no portals, can 不可售, lock for_sale set.
func _finalize_historic_cooked_scenario() -> void:
	_clear_portals_for_tutorial()
	## Starter can stays developed (採購／庫存可用) but not for sale this scenario.
	developed["can"] = true
	if not stock.has("can"):
		stock["can"] = 0
	## User retail list + cooked craft SKUs (needed for stall guest lists).
	var allow := {
		"can": false,
		"grain": true,
		"soy_sauce": true,
		"snack": true,
		"onigiri": true,
		"yakimochi": true,
		"nigiri": true,
	}
	for sku in Tuning.SELLABLE_SKUS:
		if developed.has(sku):
			for_sale[sku] = bool(allow.get(sku, false))
		else:
			for_sale.erase(sku)
	if int(owned.get("fish_tank", 0)) < 1:
		owned["fish_tank"] = 1
	if int(owned.get("cooked_stall", 0)) < 1:
		owned["cooked_stall"] = 1


## Scenario 10：安桃山殼＋擴充凍／冰線；for_sale 跟活線存檔。保留預放傳送門。
func _finalize_elite_clerk_scenario() -> void:
	developed["can"] = true
	if not stock.has("can"):
		stock["can"] = 0
	var allow := {
		"can": false,
		"grain": true,
		"soy_sauce": true,
		"snack": true,
		"drink": true,
		"milk": true,
		"icecream": true,
		"onigiri": true,
		"yakimochi": true,
		"nigiri": true,
	}
	for sku in Tuning.SELLABLE_SKUS:
		if developed.has(sku):
			for_sale[sku] = bool(allow.get(sku, false))
		else:
			for_sale.erase(sku)
	if int(owned.get("fish_tank", 0)) < 1:
		owned["fish_tank"] = 1
	if int(owned.get("cooked_stall", 0)) < 1:
		owned["cooked_stall"] = 1


func _place(type: String, x: int, y: int, rot: int, default_sku: String = "", pair_id: String = "") -> void:
	var fp := footprint(type, rot)
	var row := {"type": type, "x": x, "y": y, "rot": rot, "w": fp.x, "h": fp.y}
	if is_restock_type(type):
		row["default_sku"] = String(default_sku)
	if is_portal_type(type) and pair_id != "":
		row["pair_id"] = pair_id
	placed.append(row)


func is_restock_type(type: String) -> bool:
	return String(type).begins_with("restock")


func restock_category_of_type(type: String) -> String:
	var t := String(type)
	if t.ends_with("frozen"):
		return Tuning.CAT_FROZEN
	if t.ends_with("ice"):
		return Tuning.CAT_ICE
	return Tuning.CAT_DRY


func set_restock_default_sku(index: int, sku: String) -> void:
	if index < 0 or index >= placed.size():
		return
	if not is_restock_type(String(placed[index].get("type", ""))):
		return
	placed[index]["default_sku"] = String(sku)


func xp_to_next() -> int:
	return XpRules.xp_to_next(level)


func _xp_need(target_lv: int) -> int:
	return XpRules.xp_need(target_lv)


## Grant EXP as needed and level up until `level >= min_lv` (cap LEVEL_CAP). Returns levels gained.
func ensure_min_level(min_lv: int) -> int:
	min_lv = clampi(min_lv, 1, LEVEL_CAP)
	var ups := 0
	while level < min_lv:
		var need := _xp_need(level + 1)
		if need <= 0:
			break
		if xp < need:
			xp = need
		xp -= need
		level += 1
		unspent += 5
		ups += 1
	return ups


## Top up cash until `money >= min_amount`. Returns the amount granted.
func ensure_min_money(min_amount: int) -> int:
	min_amount = maxi(0, min_amount)
	if money >= min_amount:
		return 0
	var granted := min_amount - money
	money = min_amount
	return granted


## Raise shop_scale／grid to min_scale without charging SCALE_COST. Returns steps raised.
func ensure_min_shop_scale(min_scale: int) -> int:
	min_scale = clampi(min_scale, 1, SCALE_MAX_LV)
	var ups := 0
	while shop_scale < min_scale:
		shop_scale += 1
		var side := scale_default_side(shop_scale)
		grid_w = side
		grid_h = side
		ups += 1
	return ups


static func scale_default_side(scale: int) -> int:
	return int(SCALE_MAX.get(clampi(scale, 1, SCALE_MAX_LV), 10))


func spend_point(stat: String, delta: int) -> String:
	if delta > 0:
		if unspent <= 0:
			return Loc.t("err.no_unspent")
		unspent -= 1
		_add_stat(stat, 1)
		return ""
	if _stat_value(stat) <= _base_value(stat):
		return Loc.t("err.below_base")
	unspent += 1
	_add_stat(stat, -1)
	return ""


func reset_stats_cost() -> int:
	return maxi(1, level) * Tuning.STAT_RESET_FEE_PER_LEVEL


## Returns "" on success, or an error message (e.g. not enough money).
func reset_stats() -> String:
	var fee := reset_stats_cost()
	if money < fee:
		return Loc.t("err.reset_cost", [fee, money])
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
	return unlocked_skus.has(sku)


func develop(sku: String) -> String:
	if sku == "can":
		developed["can"] = true
		for_sale["can"] = true
		unlock_sku("can")
		if not stock.has("can"):
			stock["can"] = 0
		return Loc.t("err.can_free")
	if developed.has(sku):
		return Loc.t("err.already_developed")
	if not sku_unlocked(sku):
		return Loc.t("err.locked_level")
	var fee := int(Tuning.SKU_DEVELOP.get(sku, 0))
	if money < fee:
		return Loc.t("err.funds")
	money -= fee
	developed[sku] = true
	for_sale[sku] = true
	unlock_sku(sku)
	if not stock.has(sku):
		stock[sku] = 0
	sync_prologue_progress_grants()
	return ""


func start_cultivation(inputs: Array[String]) -> String:
	if not cultivation.is_empty() or inputs.is_empty() or inputs.size() >= CULTIVATION_WAIT.size():
		return Loc.t("prep.cultivate.unavailable")
	var required := {}
	for sku in inputs:
		required[sku] = int(required.get(sku, 0)) + 1
		if (
			not Tuning.SELLABLE_SKUS.has(sku)
			or Tuning.is_craft_only(sku)
			or int(stock.get(sku, 0)) < int(required[sku])
		):
			return Loc.t("prep.cultivate.stock_short")
	var sorted_inputs := inputs.duplicate()
	sorted_inputs.sort()
	var choices: Array = CULTIVATION_RECIPES.get(",".join(sorted_inputs), sorted_inputs)
	cultivation = {
		"inputs": inputs.duplicate(),
		"result": choices.pick_random(),
		"ready_day": day_index + CULTIVATION_WAIT[inputs.size()],
	}
	for sku in required:
		stock[sku] -= required[sku]
	var err := save_to_disk()
	if err != "":
		for sku in required:
			stock[sku] += required[sku]
		cultivation.clear()
		return err
	warehouse_changed.emit()
	return ""


func cultivation_remaining() -> int:
	return maxi(0, int(cultivation.get("ready_day", day_index)) - day_index)


func harvest_cultivation() -> Dictionary:
	if cultivation.is_empty() or cultivation_remaining() > 0:
		return {"error": Loc.t("prep.cultivate.unavailable")}
	var batch := cultivation
	var sku := String(batch["result"])
	var is_new := not developed.has(sku)
	var previous_stock = stock.get(sku)
	var previous_for_sale = for_sale.get(sku)
	var granted_unlock := false
	if is_new:
		developed[sku] = true
		for_sale[sku] = true
		granted_unlock = unlock_sku(sku)
	stock[sku] = int(stock.get(sku, 0)) + 1
	cultivation = {}
	var err := save_to_disk()
	if err != "":
		cultivation = batch
		if previous_stock == null:
			stock.erase(sku)
		else:
			stock[sku] = previous_stock
		if is_new:
			developed.erase(sku)
			if granted_unlock:
				unlocked_skus.erase(sku)
			if previous_for_sale == null:
				for_sale.erase(sku)
			else:
				for_sale[sku] = previous_for_sale
		return {"error": err}
	warehouse_changed.emit()
	return {"sku": sku, "is_new": is_new}


func buy_stock(sku: String, pieces: int) -> String:
	if not developed.has(sku):
		return Loc.t("err.not_developed")
	if Tuning.is_craft_only(sku):
		return Loc.t("err.craft_only")
	if not is_for_sale(sku):
		return Loc.t("err.not_for_sale")
	pieces = clampi(pieces, 1, Tuning.RESTOCK_PIECES)
	var cost := Tuning.cost_for_pieces(sku, pieces)
	if money < cost:
		return Loc.t("err.funds")
	money -= cost
	stock[sku] = int(stock.get(sku, 0)) + pieces
	day_procurement += cost
	sync_prologue_progress_grants()
	return ""


## Consume `n` warehouse pieces. Returns false if stock is insufficient.
func consume_stock(sku: String, n: int = 1) -> bool:
	if n <= 0:
		return false
	if int(stock.get(sku, 0)) < n:
		return false
	stock[sku] = int(stock[sku]) - n
	warehouse_changed.emit()
	return true


func consume_box(sku: String) -> bool:
	## Legacy alias: one piece (was one box). Prefer consume_stock.
	return consume_stock(sku, 1)


## Credit unsold shop pieces back to warehouse at closeout (exact pieces).
## Fish ids return to fish_stock (fishingtaro.md §4.2); others to stock.
## Returns total pieces added.
func credit_unsold_pieces(pieces_by_sku: Dictionary) -> int:
	var total := 0
	for sku_v in pieces_by_sku.keys():
		var sku := String(sku_v)
		var pieces := int(pieces_by_sku[sku_v])
		if sku == "" or pieces <= 0:
			continue
		if Tuning.is_fish_id(sku):
			fish_stock[sku] = int(fish_stock.get(sku, 0)) + pieces
		else:
			stock[sku] = int(stock.get(sku, 0)) + pieces
		total += pieces
	if total > 0:
		warehouse_changed.emit()
	return total


func furniture_unlocked(type: String) -> bool:
	if not FURNITURE.has(type):
		return false
	## Grant-only pieces appear in layout when owned; buy page handles them separately.
	if bool(FURNITURE[type].get("grant_only", false)):
		return true
	return unlocked_furniture.has(type)


func is_grant_only_furniture(type: String) -> bool:
	return FURNITURE.has(type) and bool(FURNITURE[type].get("grant_only", false))


func furniture_owned_cap(type: String) -> int:
	if not FURNITURE.has(type):
		return 0
	if FURNITURE[type].has("owned_cap"):
		return int(FURNITURE[type]["owned_cap"])
	return 99


func buy_furniture(type: String) -> String:
	if not FURNITURE.has(type):
		return Loc.t("err.no_such_item")
	if is_grant_only_furniture(type):
		return Loc.t("err.furniture_event_only")
	if not furniture_unlocked(type):
		return Loc.t("err.locked_level")
	var price := int(FURNITURE[type]["price"])
	if money < price:
		return Loc.t("err.funds")
	var cap := furniture_owned_cap(type)
	if int(owned.get(type, 0)) >= cap:
		return Loc.t("err.furniture_cap")
	money -= price
	owned[type] = int(owned.get(type, 0)) + 1
	sync_prologue_progress_grants()
	return ""


func grant_furniture(type: String, amount: int = 1) -> void:
	if not FURNITURE.has(type) or amount <= 0:
		return
	var cap := furniture_owned_cap(type)
	owned[type] = mini(cap, int(owned.get(type, 0)) + amount)


## Mark fishing minigame played; grants `fish_tank` once (fishingtaro.md).
func mark_fishing_taro_played() -> bool:
	var first := not fishing_taro_played
	fishing_taro_played = true
	if first:
		grant_furniture("fish_tank", 1)
	return first


func add_fish(fish_id: String, n: int = 1) -> bool:
	if not Tuning.is_fish_id(fish_id) or n <= 0:
		return false
	fish_stock[fish_id] = int(fish_stock.get(fish_id, 0)) + n
	warehouse_changed.emit()
	return true


func consume_fish(fish_id: String, n: int = 1) -> bool:
	if not Tuning.is_fish_id(fish_id) or n <= 0:
		return false
	if int(fish_stock.get(fish_id, 0)) < n:
		return false
	fish_stock[fish_id] = int(fish_stock[fish_id]) - n
	warehouse_changed.emit()
	return true


func fish_count(fish_id: String) -> int:
	return int(fish_stock.get(fish_id, 0))


## First fish_id with stock, else "".
func first_fish_with_stock() -> String:
	for fid in Tuning.FISH_IDS:
		if fish_count(fid) > 0:
			return fid
	return ""


## True when warehouse／fish_stock (+ optional held fish) cover the cooked recipe.
## `held_fish` = pieces of `fish_id` already in the clerk's hands.
func can_afford_cooked_recipe(sku: String, fish_id: String = "", held_fish: int = 0) -> bool:
	if not Tuning.is_craft_only(sku):
		return false
	if not developed.has(sku) or not is_for_sale(sku):
		return false
	for raw in Tuning.cooked_recipe(sku):
		if not (raw is Dictionary):
			continue
		var kind := String(raw.get("kind", ""))
		var n := int(raw.get("n", 1))
		if kind == "sku":
			if int(stock.get(String(raw.get("id", "")), 0)) < n:
				return false
		elif kind == "fish":
			var fid := fish_id if fish_id != "" else first_fish_with_stock()
			if fid == "" or fish_count(fid) + maxi(0, held_fish) < n:
				return false
		else:
			return false
	return true


## Deduct recipe inputs. `use_held_fish` skips fish_stock for that many pieces
## (caller already removed them from inventory). Returns "" on success.
func consume_cooked_ingredients(sku: String, fish_id: String = "", use_held_fish: int = 0) -> String:
	if not can_afford_cooked_recipe(sku, fish_id, use_held_fish):
		return Loc.t("err.cooked_ingredients")
	for raw in Tuning.cooked_recipe(sku):
		if not (raw is Dictionary):
			continue
		var kind := String(raw.get("kind", ""))
		var n := int(raw.get("n", 1))
		if kind == "sku":
			var sid := String(raw.get("id", ""))
			if not consume_stock(sid, n):
				return Loc.t("err.cooked_ingredients")
		elif kind == "fish":
			var used_fish := fish_id if fish_id != "" else first_fish_with_stock()
			var need := n - clampi(use_held_fish, 0, n)
			if need > 0 and not consume_fish(used_fish, need):
				return Loc.t("err.cooked_ingredients")
	return ""


## Refund after cancelled craft. Pass the same fish_id used at consume time.
func refund_cooked_ingredients(sku: String, fish_id: String = "") -> void:
	for raw in Tuning.cooked_recipe(sku):
		if not (raw is Dictionary):
			continue
		var kind := String(raw.get("kind", ""))
		var n := int(raw.get("n", 1))
		if kind == "sku":
			var sid := String(raw.get("id", ""))
			stock[sid] = int(stock.get(sid, 0)) + n
		elif kind == "fish" and fish_id != "":
			add_fish(fish_id, n)
	warehouse_changed.emit()


## Put finished cooked piece on stall face, else warehouse stock.
func deposit_cooked_result(stall: Object, sku: String) -> String:
	if not Tuning.is_craft_only(sku):
		return Loc.t("err.cooked_ingredients")
	if stall != null and is_instance_valid(stall) and stall.has_method("add_face"):
		if int(stall.call("add_face", sku, 1)) > 0:
			return ""
	stock[sku] = int(stock.get(sku, 0)) + 1
	if not developed.has(sku):
		developed[sku] = true
	warehouse_changed.emit()
	return ""


func is_portal_type(type: String) -> bool:
	return String(type) == "portal"


func alloc_portal_pair_id() -> String:
	var used := {}
	for it in placed:
		var pid := String(it.get("pair_id", ""))
		if pid != "":
			used[pid] = true
	var n := 1
	while used.has("p%d" % n):
		n += 1
	return "p%d" % n


func portal_pair_color_index(pair_id: String) -> int:
	## Stable 0/1 tint for up to two pairs (red / blue).
	if pair_id == "":
		return -1
	var ids: Array[String] = []
	for it in placed:
		var pid := String(it.get("pair_id", ""))
		if pid == "" or pid in ids:
			continue
		ids.append(pid)
	ids.sort()
	return ids.find(pair_id)


func orphan_portal_partner(index: int) -> void:
	if index < 0 or index >= placed.size():
		return
	var it: Dictionary = placed[index]
	if not is_portal_type(String(it.get("type", ""))):
		return
	var pid := String(it.get("pair_id", ""))
	if pid == "":
		return
	for i in placed.size():
		if i == index:
			continue
		var other: Dictionary = placed[i]
		if not is_portal_type(String(other.get("type", ""))):
			continue
		if String(other.get("pair_id", "")) != pid:
			continue
		placed[i].erase("pair_id")


func remove_portals_with_pair_id(pair_id: String) -> void:
	if pair_id == "":
		return
	var i := placed.size() - 1
	while i >= 0:
		var it: Dictionary = placed[i]
		if is_portal_type(String(it.get("type", ""))) and String(it.get("pair_id", "")) == pair_id:
			placed.remove_at(i)
		i -= 1


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


func place_item(type: String, x: int, y: int, rot: int, default_sku: String = "", pair_id: String = "") -> String:
	if not can_place(type, x, y, rot):
		return Loc.t("err.no_fit")
	var fp := footprint(type, rot)
	var row := {"type": type, "x": x, "y": y, "rot": rot, "w": fp.x, "h": fp.y}
	if is_restock_type(type):
		row["default_sku"] = String(default_sku)
	if is_portal_type(type) and pair_id != "":
		row["pair_id"] = pair_id
	placed.append(row)
	return ""


func move_item(index: int, x: int, y: int, rot: int) -> String:
	if index < 0 or index >= placed.size():
		return Loc.t("err.no_fit")
	var type := String(placed[index]["type"])
	if not can_place(type, x, y, rot, index):
		return Loc.t("err.no_fit")
	var fp := footprint(type, rot)
	placed[index]["x"] = x
	placed[index]["y"] = y
	placed[index]["rot"] = rot
	placed[index]["w"] = fp.x
	placed[index]["h"] = fp.y
	return ""


func remove_at(index: int) -> void:
	if index < 0 or index >= placed.size():
		return
	orphan_portal_partner(index)
	placed.remove_at(index)


func item_at(x: int, y: int) -> int:
	for i in placed.size():
		var it: Dictionary = placed[i]
		var r := Rect2i(int(it["x"]), int(it["y"]), int(it["w"]), int(it["h"]))
		if r.has_point(Vector2i(x, y)):
			return i
	return -1


func area_cap() -> int:
	return int(SCALE_AREA.get(clampi(shop_scale, 1, SCALE_MAX_LV), 100))


func set_grid(w: int, h: int) -> String:
	if w < 8 or h < 8:
		return Loc.t("err.grid_min")
	if w * h > area_cap():
		return Loc.t("err.area_cap")
	for it in placed:
		if int(it["x"]) + int(it["w"]) > w or int(it["y"]) + int(it["h"]) > h:
			return Loc.t("err.furniture_oob")
	grid_w = w
	grid_h = h
	return ""


func expand() -> String:
	if shop_scale >= SCALE_MAX_LV:
		return Loc.t("err.max_scale")
	var nxt := shop_scale + 1
	## Money-only until story/event unlock gates land.
	var price := int(SCALE_COST[nxt])
	if money < price:
		return Loc.t("err.funds")
	money -= price
	shop_scale = nxt
	var side := scale_default_side(nxt)
	grid_w = side
	grid_h = side
	return ""


func cashier_count() -> int:
	return placed_count("cashier")


func self_cashier_count() -> int:
	return placed_count("self_cashier")


## Ordinary + self-checkout counts for open gate (shopitem.md).
func register_kind_count() -> int:
	return cashier_count() + self_cashier_count()


## Reasons the operate round cannot start. Empty means the layout is ready.
## A pair is one placed restock point plus one placed shelf of the same category.
func open_blockers() -> PackedStringArray:
	var out: PackedStringArray = []
	if register_kind_count() < 1:
		out.append(Loc.t("err.need_cashier"))
	if not _has_matching_pair():
		out.append(Loc.t("err.need_restock_pair"))
	if _cooked_for_sale_active() and placed_count("cooked_stall") < 1:
		out.append(Loc.t("err.need_cooked_stall"))
	return out


func _cooked_for_sale_active() -> bool:
	for sku in Tuning.COOKED_SKUS:
		if developed.has(sku) and is_for_sale(sku):
			return true
	return false


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
		return Loc.t("err.hire_full")
	if clerks.size() >= cashier_count():
		return Loc.t("err.clerks_gt_registers")
	clerks.append({"role": "restock", "register": 0})
	return ""


func fire(index: int) -> void:
	if index >= 0 and index < clerks.size():
		clerks.remove_at(index)


func cycle_role(index: int) -> void:
	if index < 0 or index >= clerks.size():
		return
	## restock → cashier → security → cleaner → restock
	match String(clerks[index]["role"]):
		"restock":
			clerks[index]["role"] = "cashier"
		"cashier":
			clerks[index]["role"] = "security"
		"security":
			clerks[index]["role"] = "cleaner"
		_:
			clerks[index]["role"] = "restock"


func cycle_register(index: int) -> void:
	if index < 0 or index >= clerks.size():
		return
	var n := maxi(1, cashier_count())
	clerks[index]["register"] = (int(clerks[index]["register"]) + 1) % n


## Public index into `elite_clerks` (−1 if not owned). Prefer this over private `_elite_index`.
func elite_index(elite_id: String) -> int:
	return _elite_index(elite_id)


func has_elite_clerk(elite_id: String) -> bool:
	return elite_index(elite_id) >= 0


func elite_clerk_row(elite_id: String) -> Dictionary:
	var i := elite_index(elite_id)
	if i < 0:
		return {}
	return elite_clerks[i]


func unlock_elite_clerk(elite_id: String, source: String = "event") -> String:
	var id := String(elite_id)
	if not EliteClerkCatalog.exists(id):
		return Loc.t("err.elite_clerk_unknown", [id])
	if has_elite_clerk(id):
		return ""
	elite_clerks.append({
		"id": id,
		"level": 1,
		"on_duty": true,
		"roles": EliteClerkCatalog.default_roles(id),
		"register": 0,
		"source": String(source),
		"assignment": null,
	})
	return ""


func elite_upgrade_cost(elite_id: String) -> int:
	var row := elite_clerk_row(elite_id)
	if row.is_empty():
		return 0
	return EliteClerkCatalog.upgrade_cost(elite_id, int(row.get("level", 1)))


func upgrade_elite_clerk(elite_id: String) -> String:
	var i := _elite_index(elite_id)
	if i < 0:
		return Loc.t("err.elite_clerk_not_owned")
	var id := String(elite_clerks[i].get("id", ""))
	var lv := int(elite_clerks[i].get("level", 1))
	var lv_max := EliteClerkCatalog.level_max(id)
	if lv >= lv_max:
		return Loc.t("err.elite_clerk_max_level")
	var cost := EliteClerkCatalog.upgrade_cost(id, lv)
	if cost <= 0:
		return Loc.t("err.elite_clerk_max_level")
	if money < cost:
		return Loc.t("err.elite_clerk_no_money", [cost])
	money -= cost
	elite_clerks[i]["level"] = lv + 1
	return ""


func set_elite_on_duty(elite_id: String, on: bool) -> void:
	var i := _elite_index(elite_id)
	if i < 0:
		return
	if on and _elite_assignment(elite_clerks[i]) != null:
		## Mutual exclusion: clear branch assignment when reporting to HQ.
		elite_clerks[i]["assignment"] = null
		_clear_elite_from_branch_posts(String(elite_clerks[i].get("id", "")))
	elite_clerks[i]["on_duty"] = on


func toggle_elite_on_duty(elite_id: String) -> void:
	var i := _elite_index(elite_id)
	if i < 0:
		return
	set_elite_on_duty(elite_id, not bool(elite_clerks[i].get("on_duty", true)))


func _elite_assignment(row: Dictionary) -> Variant:
	return BranchState.elite_assignment(row)


func _clear_elite_from_branch_posts(elite_id: String) -> void:
	BranchState.clear_elite_from_branch_posts(self, elite_id)


func _clear_elite_posts_in_store(snap: Dictionary, elite_id: String) -> void:
	BranchState.clear_elite_posts_in_store(snap, elite_id)


## Assign elite to a branch post. Clears HQ on_duty. Returns error string or "".
func assign_elite_to_branch(elite_id: String, theme_id: String, post: String) -> String:
	return BranchState.assign_elite_to_branch(self, elite_id, theme_id, post)


func clear_elite_branch_assignment(elite_id: String) -> void:
	BranchState.clear_elite_branch_assignment(self, elite_id)


func _set_branch_post(theme_id: String, post: String, ref: Variant) -> void:
	BranchState.set_branch_post(self, theme_id, post, ref)


## Assign a regular clerk index from that store's clerks[] to a branch post.
func assign_clerk_to_branch(theme_id: String, post: String, clerk_index: int) -> String:
	return BranchState.assign_clerk_to_branch(self, theme_id, post, clerk_index)


func set_branch_policy(theme_id: String, new_policy: String) -> void:
	BranchState.set_branch_policy(self, theme_id, new_policy)


func buy_branch_stock(theme_id: String, sku: String, pieces: int) -> String:
	return BranchState.buy_branch_stock(self, theme_id, sku, pieces)


func set_branch_for_sale(theme_id: String, sku: String, on: bool) -> String:
	return BranchState.set_branch_for_sale(self, theme_id, sku, on)


func toggle_elite_role(elite_id: String, role: String) -> String:
	var i := _elite_index(elite_id)
	if i < 0:
		return Loc.t("err.elite_clerk_not_owned")
	var id := String(elite_clerks[i].get("id", ""))
	var r := String(role)
	var allowed := EliteClerkCatalog.allowed_roles(id)
	if not allowed.has(r):
		return Loc.t("err.elite_clerk_role_blocked")
	var roles: Array = []
	var raw = elite_clerks[i].get("roles", [])
	if raw is Array:
		for x in raw:
			roles.append(String(x))
	if roles.has(r):
		if roles.size() <= 1:
			return Loc.t("err.elite_clerk_need_one_role")
		roles.erase(r)
	else:
		var cap := EliteClerkCatalog.max_posts(id)
		if roles.size() >= cap:
			return Loc.t("err.elite_clerk_max_posts", [cap])
		roles.append(r)
	elite_clerks[i]["roles"] = roles
	return ""


func cycle_elite_register(elite_id: String) -> void:
	var i := _elite_index(elite_id)
	if i < 0:
		return
	var n := maxi(1, cashier_count())
	elite_clerks[i]["register"] = (int(elite_clerks[i].get("register", 0)) + 1) % n


func elite_stats(elite_id: String) -> Dictionary:
	var row := elite_clerk_row(elite_id)
	if row.is_empty():
		return {"str": 0, "agi": 0, "int": 0}
	return EliteClerkCatalog.stats_at(elite_id, int(row.get("level", 1)))


func on_duty_elite_clerks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in elite_clerks:
		if not bool(row.get("on_duty", true)):
			continue
		## Assigned elites stay off the HQ floor even if on_duty was left true.
		if _elite_assignment(row) != null:
			continue
		var roles = row.get("roles", [])
		if not (roles is Array) or roles.is_empty():
			continue
		out.append(row)
	return out


func _elite_index(elite_id: String) -> int:
	var id := String(elite_id)
	for i in elite_clerks.size():
		if String(elite_clerks[i].get("id", "")) == id:
			return i
	return -1


func _normalize_elite_roles(elite_id: String, raw) -> Array[String]:
	var allowed := EliteClerkCatalog.allowed_roles(elite_id)
	var out: Array[String] = []
	if raw is Array:
		for x in raw:
			var s := String(x)
			if allowed.has(s) and not out.has(s):
				out.append(s)
	var cap := EliteClerkCatalog.max_posts(elite_id)
	while out.size() > cap:
		out.pop_back()
	if out.is_empty():
		return EliteClerkCatalog.default_roles(elite_id)
	return out


func default_skill_set_name(i: int) -> String:
	return Loc.t("skill_set.default", [i + 1])


func furniture_name(type: String) -> String:
	if type == "" or not FURNITURE.has(type):
		return type
	return Loc.t("furniture.%s" % type)


func skill_set_name(i: int) -> String:
	if i < 0 or i >= skill_sets.size():
		return ""
	return String(skill_sets[i].get("name", ""))


func skill_set_name_is_custom(set_name: String) -> bool:
	return _is_english_letters(set_name) and set_name.length() <= SKILL_NAME_MAX and set_name.length() > 0


func equip(slot_i: int, skill_id: String) -> String:
	return equip_set(skill_set_index, slot_i, skill_id)


func unlock_light_ultimate() -> String:
	if light_quiz_passed:
		return ""
	light_quiz_passed = true
	var err := save_to_disk()
	if err != "":
		light_quiz_passed = false
	return err


func can_equip_skill(skill_id: String) -> bool:
	return skill_id != LIGHT_ULTIMATE or light_quiz_passed


func equip_set(set_i: int, slot_i: int, skill_id: String) -> String:
	if set_i < 0 or set_i >= skill_sets.size():
		return ""
	var sk := Skills.by_id(skill_id)
	if sk.is_empty():
		return Loc.t("err.no_skill")
	if not can_equip_skill(skill_id):
		return Loc.t("prep.light_quiz.locked")
	var pack: Dictionary = skill_sets[set_i]
	if slot_i == 5:
		if String(sk.get("kind")) != "ultimate":
			return Loc.t("err.ult_slot_only")
		if String(pack.get("ult_id", "")) == skill_id:
			return ""
		pack["ult_id"] = skill_id
		_after_set_edit(set_i)
		return ""
	if String(sk.get("kind")) == "ultimate":
		return Loc.t("err.ult_needs_slot")
	if slot_i < 0 or slot_i > 4:
		return ""
	var set_slots: Array = pack["slots"]
	for i in set_slots.size():
		if i != slot_i and String(set_slots[i]) == skill_id:
			return Loc.t("err.already_equipped")
	if String(set_slots[slot_i]) == skill_id:
		return ""
	var prev := String(set_slots[slot_i])
	set_slots[slot_i] = skill_id
	if _cost_of_ids(set_slots) > 5:
		set_slots[slot_i] = prev
		return Loc.t("err.cost_over")
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
			return Loc.t("err.name_letters")
		var folded := set_name.to_lower()
		for i in skill_sets.size():
			if i == set_i:
				continue
			if String(skill_sets[i].get("name", "")).to_lower() == folded:
				return Loc.t("err.name_taken")
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


## Skills that expose LV1–3 pick their level on the prep page.
## Missing choice means LV3. Other skills keep the catalog level.
func skill_level_of(set_i: int, skill_id: String) -> int:
	var sk := Skills.by_id(skill_id)
	var fallback := 3 if Skills.prep_picks_level(sk) else int(sk.get("lv", 1))
	var levels := _levels_of(set_i)
	if not levels.has(skill_id):
		return fallback
	return clampi(int(levels[skill_id]), 1, 3)


func set_skill_level(set_i: int, skill_id: String, lv: int) -> void:
	var sk := Skills.by_id(skill_id)
	if sk.is_empty() or not Skills.prep_picks_level(sk):
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
	if sk.is_empty() or not Skills.prep_picks_level(sk):
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
		return Skills.localize(Skills.ULTIMATE)
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
	xp_override: int = -1,
	ops_rating: int = RatingRules.OPS_START,
) -> Dictionary:
	var gain_xp := XpRules.raw_xp_for_counts(
		level, served, caught, cleaned, elite_served, bonus_xp
	)
	if xp_override >= 0:
		gain_xp = xp_override
	xp += gain_xp
	var ups := XpRules.apply_level_ups(self)
	money += revenue
	last_loss = revenue < day_procurement
	var note := ""
	if ups > 0:
		note = Loc.t("err.level_up", [ups, ups * 5])
	if level >= LEVEL_CAP:
		note += Loc.t("err.level_cap_note")
	level_note = note
	var loss := last_loss
	var spent := day_procurement
	day_procurement = 0
	var shop_before := shop_rating
	var grade := RatingRules.grade_for_ops(ops_rating)
	last_ops_rating = ops_rating
	last_grade = grade
	shop_rating = maxi(0, shop_rating + grade)
	rating_history.append(grade)
	while rating_history.size() > RatingRules.HISTORY_MAX:
		rating_history.remove_at(0)
	## Every close (including early) advances the ops day counter.
	day_index += 1
	return {
		"xp": gain_xp,
		"ups": ups,
		"loss": loss,
		"spent": spent,
		"wage_note": note,
		"ops_rating": ops_rating,
		"grade": grade,
		"shop_before": shop_before,
		"shop_rating": shop_rating,
		"day_index": day_index,
	}


## Per-seat raw XP (includes close bonus). Coop averages these.
## `for_level` selects the day-settle rate band (growth-character level proxy).
static func raw_xp_for_counts(
	served: int,
	caught: int,
	cleaned: int,
	elite_served: int = 0,
	bonus_xp: int = 0,
	for_level: int = 1,
) -> int:
	return XpRules.raw_xp_for_counts(
		for_level, served, caught, cleaned, elite_served, bonus_xp
	)


func developed_of(category: String) -> Array[String]:
	var out: Array[String] = []
	for sku in Tuning.skus_for(category):
		if developed.has(sku):
			out.append(sku)
	return out


## Developed SKUs in `category` that are currently for sale.
func sellable_of(category: String) -> Array[String]:
	var out: Array[String] = []
	for sku in Tuning.skus_for(category):
		if developed.has(sku) and is_for_sale(sku):
			out.append(sku)
	return out


func is_for_sale(sku: String) -> bool:
	if not developed.has(sku):
		return false
	## Missing key ⇒ sellable (legacy saves / new develop).
	if not for_sale.has(sku):
		return true
	return bool(for_sale[sku])


## Empty string = ok. Turning off the last sellable SKU is rejected.
func set_for_sale(sku: String, on: bool) -> String:
	if not developed.has(sku):
		return Loc.t("err.not_developed")
	if not on and is_for_sale(sku) and sellable().size() <= 1:
		return Loc.t("err.last_for_sale")
	for_sale[sku] = on
	if not on:
		_sanitize_restock_defaults()
	return ""


## If a restock rack default_sku is no longer for sale, fall back to first sellable in category.
func _sanitize_restock_defaults() -> void:
	for it in placed:
		if not (it is Dictionary):
			continue
		var typ := String(it.get("type", ""))
		if not is_restock_type(typ):
			continue
		var cat := restock_category_of_type(typ)
		var pool := sellable_of(cat)
		var cur := String(it.get("default_sku", ""))
		if pool.is_empty():
			it["default_sku"] = ""
			continue
		if cur == "" or pool.find(cur) < 0:
			it["default_sku"] = pool[0]


func guest_cap() -> int:
	return 15 if scenario == 3 else 10


func spawn_every() -> float:
	return 5.0 if scenario == 3 else 10.0


func customer_list_min() -> int:
	return 1 if is_intro_scenario() else Tuning.LIST_MIN


func customer_list_max() -> int:
	return 3 if is_intro_scenario() else Tuning.LIST_MAX


func dirt_spawn_sec() -> float:
	return Tuning.DIRT_SPAWN_SEC * 2.0 if is_intro_scenario() else Tuning.DIRT_SPAWN_SEC


func thief_spawn_first() -> float:
	## Story prologue: even softer than generic intro (STR 10 mash is harsh).
	if is_prologue_story_scenario():
		return Tuning.THIEF_SPAWN_FIRST * 3.0
	return Tuning.THIEF_SPAWN_FIRST * 2.0 if is_intro_scenario() else Tuning.THIEF_SPAWN_FIRST


func thief_spawn_sec() -> float:
	if is_prologue_story_scenario():
		return Tuning.THIEF_SPAWN_SEC * 3.0
	return Tuning.THIEF_SPAWN_SEC * 2.0 if is_intro_scenario() else Tuning.THIEF_SPAWN_SEC


func thief_cap() -> int:
	return 1 if is_prologue_story_scenario() else Tuning.THIEF_CAP


## Near-fight mash window (reality seconds). Prologue gives more time at low STR.
func fight_sec() -> float:
	return Tuning.FIGHT_SEC * 1.6 if is_prologue_story_scenario() else Tuning.FIGHT_SEC


## Multiplier on Tuning.hit_damage during mash. Prologue ≈ STR10 → ~7／hit.
func fight_damage_mult() -> float:
	return 2.0 if is_prologue_story_scenario() else 1.0


func sellable() -> Array[String]:
	var out: Array[String] = []
	var has_cooked_stall := placed_count("cooked_stall") >= 1
	for sku in Tuning.SELLABLE_SKUS:
		if not developed.has(sku) or not is_for_sale(sku):
			continue
		## Cooked goods need a placed stall (cookedfoodsystem.md).
		if Tuning.category_of(sku) == Tuning.CAT_COOKED and not has_cooked_stall:
			continue
		out.append(sku)
	return out


func _default_for_sale_for_developed() -> void:
	for sku in developed.keys():
		var id := String(sku)
		if not for_sale.has(id):
			for_sale[id] = true


## Never leave developed shops with an empty sellable pool.
## Public for branch／prep callers; keeps at least one sellable when possible.
func ensure_one_for_sale() -> void:
	_ensure_one_for_sale()


func _ensure_one_for_sale() -> void:
	_default_for_sale_for_developed()
	if not developed.is_empty() and sellable().is_empty():
		## Prefer any developed sellable SKU; do not specially force `can`
		## (historic／prep may keep cans off while other goods sell).
		var fixed := false
		for sku in Tuning.SELLABLE_SKUS:
			if developed.has(sku):
				for_sale[sku] = true
				## Cooked still needs a stall — retry if still empty.
				if not sellable().is_empty():
					fixed = true
					break
				for_sale[sku] = false
		if not fixed:
			for sku in developed.keys():
				for_sale[String(sku)] = true
				if not sellable().is_empty():
					break
	_sanitize_restock_defaults()


func to_dict() -> Dictionary:
	if skill_sets.is_empty():
		_install_new_game_sets()
	_mirror_selected()
	var slot_list: Array = []
	for id in slots:
		slot_list.append(String(id))
	var placed_list: Array = []
	for it in placed:
		var row := {
			"type": String(it.get("type", "")),
			"x": int(it.get("x", 0)),
			"y": int(it.get("y", 0)),
			"rot": int(it.get("rot", 0)),
			"w": int(it.get("w", 1)),
			"h": int(it.get("h", 1)),
		}
		if is_restock_type(String(row["type"])):
			row["default_sku"] = String(it.get("default_sku", ""))
		if is_portal_type(String(row["type"])):
			var pid := String(it.get("pair_id", ""))
			if pid != "":
				row["pair_id"] = pid
		placed_list.append(row)
	var clerk_list: Array = []
	for c in clerks:
		clerk_list.append({
			"role": String(c.get("role", "restock")),
			"register": int(c.get("register", 0)),
		})
	var elite_list: Array = []
	for e in elite_clerks:
		var roles_out: Array = []
		var raw_roles = e.get("roles", [])
		if raw_roles is Array:
			for r in raw_roles:
				roles_out.append(String(r))
		var elite_row := {
			"id": String(e.get("id", "")),
			"level": int(e.get("level", 1)),
			"on_duty": bool(e.get("on_duty", true)),
			"roles": roles_out,
			"register": int(e.get("register", 0)),
			"source": String(e.get("source", "")),
		}
		var asn = _elite_assignment(e)
		if asn != null:
			elite_row["assignment"] = asn
		else:
			elite_row["assignment"] = null
		elite_list.append(elite_row)
	var themes_cleared_out: Array = []
	for t in themes_cleared:
		themes_cleared_out.append(String(t))
	var theme_stores_out: Dictionary = {}
	for tid in theme_stores.keys():
		theme_stores_out[String(tid)] = ThemeStoreSnapshot.normalize_theme_store(theme_stores[tid])
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
		"tint": clampi(tint, 0, 3),
		"skin_id": _normalized_skin_id(),
		"unlocked_skins": _parsed_unlocked_skins(),
		"unlocked_skus": unlocked_skus.duplicate(true),
		"unlocked_furniture": unlocked_furniture.duplicate(true),
		"prologue_boss_unlocked": prologue_boss_unlocked,
		"developed": developed.duplicate(true),
		"for_sale": for_sale.duplicate(true),
		"stock": stock.duplicate(true),
		"fish_stock": fish_stock.duplicate(true),
		"fishing_taro_played": fishing_taro_played,
		"cultivation": cultivation.duplicate(true),
		"light_quiz_passed": light_quiz_passed,
		"owned": owned.duplicate(true),
		"placed": placed_list,
		"shop_scale": shop_scale,
		"grid_w": grid_w,
		"grid_h": grid_h,
		"clerks": clerk_list,
		"elite_clerks": elite_list,
		"slots": slot_list,
		"ult_id": ult_id,
		"skill_sets": _skill_sets_for_save(),
		"skill_set_index": skill_set_index,
		"day_procurement": day_procurement,
		"last_loss": last_loss,
		"level_note": level_note,
		"shop_rating": shop_rating,
		"rating_history": rating_history.duplicate(),
		"difficulty": RatingRules.normalize_difficulty(difficulty),
		"last_ops_rating": last_ops_rating,
		"last_grade": last_grade,
		"difficulty_prompt_acked": difficulty_prompt_acked,
		"support_rating": support_rating,
		"day_index": day_index,
		"active_tasks_by_seat": active_tasks_by_seat.duplicate(true),
		"task_test_mode": task_test_mode,
		"task_test_pack_id": task_test_pack_id,
		"task_test_seed": task_test_seed,
		"tutorial_progress": tutorial_progress.duplicate(true),
		"tutorial_skipped": tutorial_skipped,
		"active_theme_id": String(active_theme_id) if active_theme_id != "" else BranchRules.ORIGIN_ID,
		"themes_cleared": themes_cleared_out,
		"theme_stores": theme_stores_out,
		"origin_store": ThemeStoreSnapshot.normalize_theme_store(origin_store) if not origin_store.is_empty() else {},
		"policy": BranchRules.normalize_policy(policy),
		"branch_posts": BranchRules.normalize_posts(branch_posts),
	}


## Empty string means ok; otherwise a human-readable error.
func from_dict(data: Dictionary) -> String:
	if data.is_empty():
		return Loc.t("err.save_empty")
	if not data.has("version"):
		return Loc.t("err.save_no_version")
	var ver := int(data["version"])
	if ver < 1:
		return Loc.t("err.save_bad_version")
	if ver > SAVE_VERSION:
		return Loc.t("err.save_too_new", [ver, SAVE_VERSION])
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
	tint = clampi(int(data.get("tint", 0)), 0, 3)
	skin_id = _normalize_skin_id(String(data.get("skin_id", "player")))
	unlocked_skins = _parse_unlocked_skins(data.get("unlocked_skins", []))
	unlocked_skus = _string_bool_dict(data.get("unlocked_skus", {}))
	unlocked_furniture = _string_bool_dict(data.get("unlocked_furniture", {}))
	prologue_boss_unlocked = bool(data.get("prologue_boss_unlocked", false))
	developed = _string_bool_dict(data.get("developed", {}))
	for_sale = _string_bool_dict(data.get("for_sale", {}))
	stock = _string_int_dict(data.get("stock", {}))
	if ver < 2:
		## v1 stock was warehouse boxes; v2+ is pieces.
		for sku_v in stock.keys():
			stock[sku_v] = int(stock[sku_v]) * Tuning.BOX_SIZE
	fish_stock = {}
	var raw_fish = data.get("fish_stock", {})
	if raw_fish is Dictionary:
		for fid in raw_fish.keys():
			var id := String(fid)
			if Tuning.is_fish_id(id):
				fish_stock[id] = maxi(0, int(raw_fish[fid]))
	fishing_taro_played = bool(data.get("fishing_taro_played", false))
	owned = _string_int_dict(data.get("owned", {}))
	## Pre-v8 saves never had the tank; keep grant_only owned as-is after fishing flag.
	if unlocked_skus.is_empty() and unlocked_furniture.is_empty():
		## Pre-v7 saves: rebuild gates from legacy level table + developed.
		_migrate_unlocks_from_level()
	else:
		for sku_v in developed.keys():
			unlocked_skus[String(sku_v)] = true
	_ensure_test_portal_owned()
	sync_prologue_progress_grants()
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
			var row := {
				"type": t,
				"x": int(d.get("x", 0)),
				"y": int(d.get("y", 0)),
				"rot": rot,
				"w": int(d.get("w", fp.x)),
				"h": int(d.get("h", fp.y)),
			}
			if is_restock_type(t):
				row["default_sku"] = String(d.get("default_sku", ""))
			if is_portal_type(t):
				var pid := String(d.get("pair_id", ""))
				if pid != "":
					row["pair_id"] = pid
			placed.append(row)
	shop_scale = clampi(int(data.get("shop_scale", 1)), 1, SCALE_MAX_LV)
	grid_w = maxi(8, int(data.get("grid_w", 10)))
	grid_h = maxi(8, int(data.get("grid_h", 10)))
	clerks.clear()
	var raw_clerks = data.get("clerks", [])
	if raw_clerks is Array:
		for c in raw_clerks:
			if not (c is Dictionary):
				continue
			var role := String(c.get("role", "restock"))
			if role != "cashier" and role != "restock" and role != "security" and role != "cleaner":
				role = "restock"
			clerks.append({"role": role, "register": maxi(0, int(c.get("register", 0)))})
	elite_clerks.clear()
	var raw_elites = data.get("elite_clerks", [])
	if raw_elites is Array:
		for e in raw_elites:
			if not (e is Dictionary):
				continue
			var eid := String(e.get("id", ""))
			if not EliteClerkCatalog.exists(eid):
				continue
			var lv := clampi(int(e.get("level", 1)), 1, EliteClerkCatalog.level_max(eid))
			var on_duty := bool(e.get("on_duty", true))
			var asn = _elite_assignment({"assignment": e.get("assignment", null)})
			if on_duty:
				asn = null
			elite_clerks.append({
				"id": eid,
				"level": lv,
				"on_duty": on_duty,
				"roles": _normalize_elite_roles(eid, e.get("roles", [])),
				"register": maxi(0, int(e.get("register", 0))),
				"source": String(e.get("source", "")),
				"assignment": asn,
			})
	var loaded_slots: Array[String] = ["", "", "", "", ""]
	var raw_slots = data.get("slots", [])
	if raw_slots is Array:
		for i in mini(5, raw_slots.size()):
			loaded_slots[i] = String(raw_slots[i])
	_clear_retired_skill_ids(loaded_slots)
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
	shop_rating = maxi(0, int(data.get("shop_rating", 0)))
	rating_history.clear()
	var raw_hist = data.get("rating_history", [])
	if raw_hist is Array:
		for g in raw_hist:
			rating_history.append(clampi(int(g), -3, 3))
		while rating_history.size() > RatingRules.HISTORY_MAX:
			rating_history.remove_at(0)
	difficulty = RatingRules.normalize_difficulty(String(data.get("difficulty", RatingRules.DIFF_NORMAL)))
	## Scenario 5 tutorial is always Easy.
	if scenario == 5:
		difficulty = RatingRules.DIFF_EASY
	last_ops_rating = int(data.get("last_ops_rating", RatingRules.OPS_START))
	last_grade = clampi(int(data.get("last_grade", 0)), -3, 3)
	difficulty_prompt_acked = String(data.get("difficulty_prompt_acked", ""))
	support_rating = int(data.get("support_rating", 0))
	day_index = maxi(0, int(data.get("day_index", 0)))
	light_quiz_passed = ver >= 6 and data.get("light_quiz_passed", false) == true
	cultivation = {}
	var batch = data.get("cultivation", {})
	if batch is Dictionary:
		var inputs = batch.get("inputs")
		var result = batch.get("result")
		var ready_day = batch.get("ready_day")
		var valid_inputs: bool = inputs is Array and inputs.size() in [1, 2, 3]
		var valid_result: bool = result is String and Tuning.SELLABLE_SKUS.has(result)
		if valid_inputs and valid_result and (ready_day is int or ready_day is float):
			if inputs.all(func(sku): return sku is String and Tuning.SELLABLE_SKUS.has(sku)) and int(ready_day) > 0:
				cultivation = {"inputs": inputs.duplicate(), "result": result, "ready_day": int(ready_day)}
	active_tasks_by_seat = {}
	var raw_tasks = data.get("active_tasks_by_seat", {})
	if raw_tasks is Dictionary:
		for sk in raw_tasks.keys():
			var rows: Array = []
			var raw_rows = raw_tasks[sk]
			if raw_rows is Array:
				for row in raw_rows:
					if row is Dictionary:
						rows.append((row as Dictionary).duplicate(true))
			active_tasks_by_seat[str(sk)] = rows
	task_test_mode = String(data.get("task_test_mode", "off"))
	if task_test_mode != "off" and task_test_mode != "pack" and task_test_mode != "random":
		task_test_mode = "off"
	task_test_pack_id = String(data.get("task_test_pack_id", "OP-TUT-001"))
	task_test_seed = int(data.get("task_test_seed", 1))
	tutorial_progress.clear()
	var raw_tut = data.get("tutorial_progress", {})
	if raw_tut is Dictionary:
		for tid in raw_tut.keys():
			var trow = raw_tut[tid]
			if trow is Dictionary:
				tutorial_progress[String(tid)] = (trow as Dictionary).duplicate(true)
	tutorial_skipped = bool(data.get("tutorial_skipped", false))
	## v10+ branch / theme stores (missing ⇒ single-store legacy).
	active_theme_id = String(data.get("active_theme_id", BranchRules.ORIGIN_ID))
	if active_theme_id == "":
		active_theme_id = BranchRules.ORIGIN_ID
	themes_cleared.clear()
	var raw_cleared = data.get("themes_cleared", [])
	if raw_cleared is Array:
		for t in raw_cleared:
			var ts := String(t)
			if ts != "" and not themes_cleared.has(ts):
				themes_cleared.append(ts)
	theme_stores.clear()
	var raw_stores = data.get("theme_stores", {})
	if raw_stores is Dictionary:
		for tid in raw_stores.keys():
			theme_stores[String(tid)] = ThemeStoreSnapshot.normalize_theme_store(raw_stores[tid])
	var raw_origin = data.get("origin_store", {})
	if raw_origin is Dictionary and not raw_origin.is_empty():
		origin_store = ThemeStoreSnapshot.normalize_theme_store(raw_origin)
	else:
		origin_store = {}
	policy = BranchRules.normalize_policy(String(data.get("policy", BranchRules.POLICY_BALANCED)))
	branch_posts = BranchRules.normalize_posts(data.get("branch_posts", null))
	_grant_initial_goods()
	_ensure_one_for_sale()
	return ""


func _install_new_game_sets() -> void:
	skill_sets.clear()
	skill_sets.append(_make_set(default_skill_set_name(0), _default_slot_ids(), "the_world"))
	for i in range(1, SKILL_SET_COUNT):
		skill_sets.append(_make_set(default_skill_set_name(i), _blank_slot_ids(), ""))
	skill_set_index = 0
	_mirror_selected()


## Scenario 5: all five sets blank (no actives, no ultimate).
func _install_blank_skill_sets() -> void:
	skill_sets.clear()
	for i in range(SKILL_SET_COUNT):
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
	_clear_retired_skill_ids(loaded_slots)
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
			_clear_retired_skill_ids(slot_ids)
			var ult := ""
			if src.has("ult_id"):
				ult = _sanitize_ult_id(String(src.get("ult_id")))
			var set_name := String(src.get("name", ""))
			var levels := _levels_from_save(src.get("levels", {}))
			levels.erase("restock_radar")
			skill_sets.append(_make_set(set_name, slot_ids, ult, levels))
		else:
			skill_sets.append(_make_set(default_skill_set_name(i), _blank_slot_ids(), ""))
	return true


func _clear_retired_skill_ids(slot_ids: Array[String]) -> void:
	for i in slot_ids.size():
		if slot_ids[i] == "restock_radar":
			slot_ids[i] = ""


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
		if sk.is_empty() or not Skills.prep_picks_level(sk):
			continue
		out[id] = clampi(int(raw[key]), 1, 3)
	return out


func save_to_disk() -> String:
	var text := JSON.stringify(to_dict(), "\t")
	return PlatformServices.write_save(text)


func load_from_disk() -> String:
	if not PlatformServices.has_save():
		return Loc.t("err.save_missing")
	var text := PlatformServices.read_save()
	if text.strip_edges() == "":
		return Loc.t("err.save_empty")
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return Loc.t("err.save_bad_json")
	return from_dict(parsed as Dictionary)


func has_save() -> bool:
	return PlatformServices.has_save()


func delete_save() -> void:
	PlatformServices.delete_save()
	PlatformServices.delete_guest_slots()


func appearance_skin_id() -> String:
	return _normalized_skin_id()


func appearance_tint() -> Color:
	const CharacterSheet = preload("res://scripts/session/character_sheet.gd")
	return CharacterSheet.tint_color(tint)


func is_skin_unlocked(skin_id: String) -> bool:
	var SkinCatalog = load("res://scripts/session/skin_catalog.gd")
	if SkinCatalog != null and SkinCatalog.has_method("is_unlocked"):
		return bool(SkinCatalog.is_unlocked(skin_id, unlocked_skins))
	return true


func unlock_skin(skin_id: String) -> void:
	var SkinCatalog = load("res://scripts/session/skin_catalog.gd")
	var sid := _normalize_skin_id(skin_id)
	if SkinCatalog != null and SkinCatalog.has_method("entry") and SkinCatalog.entry(sid).is_empty():
		return
	var list := _parsed_unlocked_skins()
	## Empty list = all unlocked (BETA). Keep empty; only extend an explicit allow-list.
	if list.is_empty():
		return
	if sid not in list:
		list.append(sid)
		unlocked_skins = list


func _normalized_skin_id() -> String:
	return _normalize_skin_id(skin_id)


func _normalize_skin_id(raw: String) -> String:
	var SkinCatalog = load("res://scripts/session/skin_catalog.gd")
	if SkinCatalog != null and SkinCatalog.has_method("normalize"):
		return String(SkinCatalog.normalize(raw))
	return raw if raw.strip_edges() != "" else "player"


func _parsed_unlocked_skins() -> Array:
	return _parse_unlocked_skins(unlocked_skins)


func _parse_unlocked_skins(raw) -> Array:
	var SkinCatalog = load("res://scripts/session/skin_catalog.gd")
	if SkinCatalog != null and SkinCatalog.has_method("parse_unlocked"):
		return SkinCatalog.parse_unlocked(raw)
	return []


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
