extends "res://scripts/host/game_host.gd"
## Living v1 line (from Alpha v0.1): Demo v0.6 shop loop with voxel sprites.
## Extends GameHost — stable surface for player/customer/HUD/Session.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const StateScript = preload("res://scripts/game_state.gd")
const XpRules = preload("res://scripts/session/xp_rules.gd")
const PlayerScript = preload("res://scripts/player.gd")
const RestockScript = preload("res://scripts/restock_point.gd")
const ShelfScript = preload("res://scripts/shelf.gd")
const Fundraise = preload("res://scripts/fundraise.gd")
const DarkSide = preload("res://scripts/dark_side.gd")
const ShadowCloneCast = preload("res://scripts/shadow_clone_cast.gd")
const ShadowCloneScript = preload("res://scripts/shadow_clone.gd")
const DirtScript = preload("res://scripts/dirt.gd")
const OpsItemPickupScript = preload("res://scripts/ops_item_pickup.gd")
const OpsItems = preload("res://scripts/ops_items.gd")
const DroppedBoxScript = preload("res://scripts/dropped_box.gd")
const DropFlightScript = preload("res://scripts/drop_flight.gd")
const CashierScript = preload("res://scripts/cashier.gd")
const CustomerScript = preload("res://scripts/customer.gd")
const ClerkScript = preload("res://scripts/clerk.gd")
const PathfinderScript = preload("res://scripts/pathfinder.gd")
const PrepScene = preload("res://scenes/prep_menu.tscn")
const PauseScene = preload("res://scenes/pause_menu.tscn")
const UiFont = preload("res://scripts/ui_font.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const RatingRules = preload("res://scripts/session/rating_rules.gd")
const FloorTilesScript = preload("res://scripts/floor_tiles.gd")
const ProductVersion = preload("res://scripts/product_version.gd")
const DaySettle = preload("res://scripts/host/day_settle.gd")
const WorldBuildScript = preload("res://scripts/host/world_build.gd")
const BgmBusScript = preload("res://scripts/bgm_bus.gd")
const NetWorldScript = preload("res://scripts/host/net_world.gd")
const NetDayChromeScript = preload("res://scripts/host/net_day_chrome.gd")
const SkillDeployScript = preload("res://scripts/host/skill_deploy.gd")
const SkillCastScript = preload("res://scripts/host/skill_cast.gd")
const ClerkCastScript = preload("res://scripts/host/clerk_cast.gd")
const OpsWorldScript = preload("res://scripts/host/ops_world.gd")
const WorldSpawnScript = preload("res://scripts/host/world_spawn.gd")
const TossWorldScript = preload("res://scripts/host/toss_world.gd")
const BossWorldScript = preload("res://scripts/host/boss_world.gd")
const NetPresentationScript = preload("res://scripts/session/net_presentation.gd")
const TaskCatalog = preload("res://scripts/session/task_catalog.gd")
const TaskTrackerScript = preload("res://scripts/session/task_tracker.gd")
const ThreeVolleyVisualScript = preload("res://scripts/three_volley_visual.gd")
const TutorialDirectorScript = preload("res://scripts/tutorial/tutorial_director.gd")

var FLOOR_SIZE := Vector2(640, 640)
var FLOOR_ORIGIN := Vector2(48, 36)

var _sfx_phase: String = "prep"
var state: StateScript
var cleaned: int = 0
## Per-seat day XP inputs (seat 0 = host). Summed then averaged at settle.
var seat_cleaned: Array[int] = [0]
var seat_served: Array[int] = [0]
var seat_caught: Array[int] = [0]
var seat_elite: Array[int] = [0]
var seat_kind_converted: Array[int] = [0]
var kind_converted_total: int = 0
var _combo = null
var _tasks = null
var _tutorial: Node = null
var _settled: bool = false
## After closeout, block confirm/cancel return until this game time (msec).
var _closeout_ready_msec: int = 0
const CLOSEOUT_HOLD_MSEC := 2000
var _prep: CanvasLayer
var _pause: CanvasLayer
var _world: Node2D
var _door_caption: Label = null
var cashiers: Array[Node2D] = []
## Self-checkout furniture (not clerk-bindable). Merged in pick_register.
var self_cashiers: Array[Node2D] = []
var portals: Array[Node2D] = []
## SKU id → Array of stocked shelves (maintained via shelf.stock_sku_changed).
var _shelves_by_sku: Dictionary = {}
var real_time: float = 0.0
var revenue: int = 0
var served: int = 0
var elite_served: int = 0
var angry_left: int = 0
## Day-session ops rating (reset to 50 each open). Host shop only.
var ops_rating: int = RatingRules.OPS_START
## EliteCustomer zoom queue (fight/dash camera has priority).
var _elite_zoom_queue: Array = []
var _elite_zoom_busy: bool = false
## Prep test difficulty（TEST_TOOLS）: "normal" keeps current rules, "easy" eases the day.
var play_difficulty: String = "normal"
## Prep test: 麻煩客人模式（TEST_TOOLS）. lv 0 = mixed 1–6; else fixed LV.
var elite_test_active: bool = false
var elite_test_lv: int = 0
var elite_test_need_one: bool = false
var stolen_count: int = 0
var stolen_value: int = 0
var thieves_caught: int = 0
var thieves_escaped: int = 0
var cashier: Node2D
var shelves: Array[Node2D] = []
var pathfinder
var _obstacles: Array[Rect2] = []
var _spawn_in: float = 2.0
## 諸客的黃昏: real-second inject window (ignore guest_cap; never thieves).
var _guest_dusk_left: float = 0.0
var _guest_dusk_remain: int = 0
var _guest_dusk_in: float = 0.0
## 三段火槍陣: per-cast follow-up volleys use real seconds, unaffected by The World.
var _three_volley_casts: Array[Dictionary] = []
var _three_volley_visuals: Array[Node2D] = []
## Host-only pending deliveries keyed by customer instance id then SKU.
var _elite_guest_cannon_reservations: Dictionary = {}
## Ultimate: store-wide self-service; raw real seconds, Host-owned.
var _self_service_operation_left: float = 0.0
var _self_service_operation_owner: int = -1
var _player: CharacterBody2D
## M1 local coop: all seated players. `_player` stays seat0 alias.
var _players: Array[CharacterBody2D] = []
const COOP_SOFT_RADIUS := 28.0
const COOP_SOFT_PUSH := 220.0
## Ignore hairline overlap so soft push does not idle-nudge at the radius edge.
const COOP_SOFT_MIN_PEN := 2.0
var _customers: Node2D
var _hud: CanvasLayer
var _dirts: Array[Node2D] = []
var _ops_items: Array[Node2D] = []
var _ops_item_spawn_in: float = OpsItems.SPAWN_FIRST_SEC
var _clerks: Array[Node2D] = []
## M2.2: Host agent_id → node; client puppets share the same map.
var _net_agents: Dictionary = {}
var _next_agent_id: int = 1
## §8.4: fixed-rate net tick + presentation buffer (replaces EVERY=2 hard snaps).
var _net_pres = NetPresentationScript.new()
var _net_accum: float = 0.0
var _agent_xform_accum: float = 0.0
## Client: last Host pose for owned-seat soft reconcile (not delayed interp).
var _owned_host_pose: Dictionary = {}
## Client: spawn RPCs that arrived before `_world` existed.
var _pending_agent_spawns: Array = []
var _pending_flights: Array = []
var _pending_agent_states: Array = []
## M2.4: net_shelf_id → shelf node; client pending stock RPCs before world ready.
var _shelves_by_net_id: Dictionary = {}
var _next_net_shelf_id: int = 0
var _pending_stock_states: Array = []
var _warehouse_hooked: bool = false
## M2.6: client pending carry RPCs before world ready.
var _pending_carry_states: Array = []
## M2.9: client pending checkout prompt RPCs before world ready.
var _pending_prompt_states: Array = []
## Client pending day HUD economy RPCs before world ready.
var _pending_day_hud_states: Array = []
## Client pending day clock／phase RPCs before world ready.
var _pending_day_clock_states: Array = []
## Client pending skill CD／buff RPCs before world ready.
var _pending_skill_cd_states: Array = []
## Host fingerprint to throttle skill CD broadcasts.
var _skill_cd_net_fp: String = ""
## Host fingerprint／accum for day clock broadcasts (~4 Hz).
var _day_clock_net_fp: String = ""
var _day_clock_accum: float = 0.0
var _next_net_restock_id: int = 0
var _next_net_portal_id: int = 0
var _dirt_spawn_in: float = Tuning.DIRT_SPAWN_SEC
var _thief_spawn_in: float = Tuning.THIEF_SPAWN_FIRST
var _early_open: bool = false
var _early_latched: bool = false
var _early_closed: bool = false
var _skip_xp: int = 0
var _early_focus: int = 0
var _early_layer: CanvasLayer
var _early_yes: Button
var _early_no: Button
## Maintained thief list (no per-frame alloc).
var _thieves: Array[Node2D] = []
## Guests currently occupying the store (excludes leave/flee/thieves).
var _guest_n: int = 0
## Active thieves (is_active_thief).
var _active_thief_n: int = 0
## Empty shelves by category for toss restock.
var _empty_by_cat: Dictionary = {}
## Coarse cells blocked for dirt spawn (furniture + door + existing dirt).
const DIRT_CELL := 40.0
var _dirt_block_cells: Dictionary = {}
var _world_build = WorldBuildScript.new()
var _net = NetWorldScript.new()
var _day_chrome = NetDayChromeScript.new()
var _skill_deploy = SkillDeployScript.new()
var _skill_cast = SkillCastScript.new()
var _clerk_cast = ClerkCastScript.new()
var _ops_world = OpsWorldScript.new()
var _world_spawn = WorldSpawnScript.new()
var _toss_world = TossWorldScript.new()
var _boss_world = BossWorldScript.new()


func _ready() -> void:
	add_to_group("game")
	state = StateScript.new()
	_tutorial = TutorialDirectorScript.new()
	_tutorial.name = "TutorialDirector"
	_tutorial.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tutorial)
	_tutorial.setup(state)
	_prep = PrepScene.instantiate()
	add_child(_prep)
	_prep.setup(self)
	_prep.start_day.connect(_begin_day)
	SessionService.start_day.connect(_begin_day)
	SessionService.room_paused_changed.connect(_on_room_paused_changed)
	SessionService.peer_left.connect(_on_session_peer_left)
	SessionService.seats_changed.connect(_on_session_seats_changed)
	SessionService.settle_payload_received.connect(_on_settle_payload)
	SessionService.disconnect_session.connect(_on_session_disconnect)
	_world_build.bind(self)
	_net.bind(self)
	_day_chrome.bind(self)
	_skill_deploy.bind(self)
	_skill_cast.bind(self)
	_clerk_cast.bind(self)
	_ops_world.bind(self)
	_world_spawn.bind(self)
	_toss_world.bind(self)
	_boss_world.bind(self)
	_net.connect_session()
	_day_chrome.connect_session()
	if not SessionService.carry_state_received.is_connected(_on_carry_state_received):
		SessionService.carry_state_received.connect(_on_carry_state_received)
	if not SessionService.prompt_state_received.is_connected(_on_prompt_state_received):
		SessionService.prompt_state_received.connect(_on_prompt_state_received)
	_hook_warehouse_changed()
	_pause = PauseScene.instantiate()
	add_child(_pause)
	_pause.setup(self)
	_pause.end_day_requested.connect(_on_pause_end_day)
	if not PlatformServices.show_dev_hud_changed.is_connected(_on_show_dev_hud_changed):
		PlatformServices.show_dev_hud_changed.connect(_on_show_dev_hud_changed)
	var bgm := BgmBusScript.bus()
	if bgm:
		bgm.play_prep()


func tutorial() -> Node:
	return _tutorial


## True while tutorial explain modal is up — freeze day clock／player input (no tree pause).
func tutorial_freezes_play() -> bool:
	return _tutorial != null and is_instance_valid(_tutorial) and _tutorial.is_modal_open()


func _on_show_dev_hud_changed(_enabled: bool) -> void:
	refresh_world_dev_labels()


## Toggle object-name chrome instantly when 「顯示開發用資訊」 flips mid-day.
func refresh_world_dev_labels() -> void:
	if _door_caption != null and is_instance_valid(_door_caption):
		_door_caption.visible = PlatformServices.is_show_dev_hud()
		if _door_caption.visible:
			_door_caption.text = Loc.t("world.door")
	for s in shelves:
		if s != null and is_instance_valid(s) and s.has_method("_refresh"):
			s.call("_refresh")
	if _world != null and is_instance_valid(_world):
		for n in _world.get_children():
			if n == null or not is_instance_valid(n):
				continue
			if n.has_method("refresh_dev_labels"):
				n.call("refresh_dev_labels")
			elif n.has_method("_refresh"):
				n.call("_refresh")
			elif n.has_method("refresh"):
				n.call("refresh")
			elif n.has_method("pull_stock"):
				n.call("pull_stock")
	for c in _clerks:
		if c != null and is_instance_valid(c) and c.has_method("refresh_dev_labels"):
			c.call("refresh_dev_labels")
	for d in _dirts:
		if d != null and is_instance_valid(d) and d.has_method("refresh_dev_labels"):
			d.call("refresh_dev_labels")
	if _customers != null and is_instance_valid(_customers):
		for n in _customers.get_children():
			if n != null and is_instance_valid(n) and n.has_method("refresh_dev_labels"):
				n.call("refresh_dev_labels")
	if _hud != null and _hud.has_method("_refresh"):
		_hud.call("_refresh")


func _begin_day() -> void:
	_clear_self_service_operation()
	if _prep:
		_prep.set_process_unhandled_input(false)
	if _pause and _pause.has_method("close_menu"):
		_pause.close_menu()
	## Safety: leftover tree pause must never carry into ops.
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false
	## Client applies host world snapshot before building the floor.
	## Stash home save first — live `state` becomes Host shop for presentation only.
	if SessionService.is_client():
		if state != null:
			SessionService.stash_client_home_save(state.to_dict())
		var snap: Dictionary = SessionService.take_pending_day_snapshot()
		var world = snap.get("world", {})
		if world is Dictionary and not world.is_empty():
			var err := state.from_dict(world)
			if err != "":
				push_warning("client day snapshot failed: %s" % err)
	_clear_world()
	_early_closed = false
	_skip_xp = 0
	revenue = 0
	served = 0
	elite_served = 0
	_elite_zoom_queue.clear()
	_elite_zoom_busy = false
	angry_left = 0
	ops_rating = RatingRules.OPS_START
	stolen_count = 0
	stolen_value = 0
	thieves_caught = 0
	thieves_escaped = 0
	kind_converted_total = 0
	cleaned = 0
	var sn := maxi(1, SeatTable.seat_count)
	seat_cleaned = []
	seat_served = []
	seat_caught = []
	seat_elite = []
	seat_kind_converted = []
	for _i in sn:
		seat_cleaned.append(0)
		seat_served.append(0)
		seat_caught.append(0)
		seat_elite.append(0)
		seat_kind_converted.append(0)
	_settled = false
	_closeout_ready_msec = 0
	real_time = 0.0
	game_hours = Tuning.GAME_START_HOUR
	hud_rev = 0
	phase = "restock"
	_boss_world.clear()
	if state != null and state.has_method("is_boss_test_scenario") and bool(state.is_boss_test_scenario()):
		_boss_world.configure("alien_tycoon")
	_net_pres.clear()
	_owned_host_pose.clear()
	_net_accum = 0.0
	_agent_xform_accum = 0.0
	var ComboState = preload("res://scripts/session/combo_state.gd")
	_combo = ComboState.new()
	_combo.reset(SeatTable.seat_count)
	_setup_day_tasks()
	if _tutorial != null:
		_tutorial.setup(state)
		if not _tutorial.progress_changed.is_connected(_on_tutorial_progress):
			_tutorial.progress_changed.connect(_on_tutorial_progress)
		## Do not open／pause mid-build — wait until world／HUD exist (see end of _begin_day).
	var il := get_node_or_null("/root/InteractLock")
	if il != null and il.has_method("clear"):
		il.clear()
	_sfx_phase = "restock"
	SfxBus.play("sfx_phase_restock")
	var bgm_op := BgmBusScript.bus()
	if bgm_op:
		bgm_op.play_operation(true)
	_spawn_in = 2.0
	clear_guest_dusk()
	_clear_three_volley()
	_dirt_spawn_in = dirt_spawn_interval()
	_thief_spawn_in = state.thief_spawn_first()
	_ops_item_spawn_in = OpsItems.SPAWN_FIRST_SEC
	_ops_items.clear()
	FLOOR_SIZE = Vector2(state.grid_w, state.grid_h) * StateScript.CELL
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	add_child(_world)
	move_child(_world, 0)
	_floor()
	_walls_and_door()
	var nodes: Array[Node2D] = []
	_build_furniture(nodes)
	pathfinder = PathfinderScript.new()
	pathfinder.setup(FLOOR_ORIGIN, FLOOR_SIZE, _obstacles)
	_customers = Node2D.new()
	_customers.name = "Customers"
	_customers.y_sort_enabled = true
	_world.add_child(_customers)
	_players.clear()
	var spawn0 := FLOOR_ORIGIN + Vector2(FLOOR_SIZE.x * 0.5, FLOOR_SIZE.y - 80)
	for seat in SeatTable.seat_ids():
		var stats_src = state if seat == 0 else SeatTable.sheet_of(seat)
		if stats_src == null:
			stats_src = load("res://scripts/session/character_sheet.gd").from_game_state(state)
			SeatTable.set_sheet(seat, stats_src)
		## Bind guest_stats only for this machine's claim2 seat (local_index 1), not global seat 1.
		if SeatTable.seat_owned_locally(seat) and SeatTable.local_index_of(seat) == 1 and SeatTable.guest_stats == null:
			SeatTable.guest_stats = stats_src
		var spawn := spawn0 + Vector2(40.0 * float(seat), 0.0)
		_spawn_seated_player(seat, stats_src, nodes, spawn)
	_player = _players[0] if not _players.is_empty() else null
	## Soft collision exceptions between all seated players.
	for i in _players.size():
		for j in range(i + 1, _players.size()):
			var a: CharacterBody2D = _players[i]
			var b: CharacterBody2D = _players[j]
			if a and b:
				a.add_collision_exception_with(b)
				b.add_collision_exception_with(a)
	## Local seat for HUD／camera／prompts (Client is often seat 1+, not seat 0).
	for p in _players:
		if p != null and SeatTable.seat_owned_locally(int(p.seat_id)):
			_player = p
			break
	var cam := Camera2D.new()
	cam.zoom = Vector2(Tuning.CAMERA_ZOOM, Tuning.CAMERA_ZOOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.5
	if _player:
		_player.add_child(cam)
		cam.make_current()
	for p in _players:
		if p != null:
			p.camera = cam
	if not PlatformServices.camera_view_changed.is_connected(_on_camera_view_changed):
		PlatformServices.camera_view_changed.connect(_on_camera_view_changed)
	apply_camera_view()
	_hud = preload("res://scenes/hud.tscn").instantiate()
	add_child(_hud)
	## setup binds every seat in `_players` (right panes + cast/log); primary = local seat.
	_hud.setup(self, _player)
	_bind_player_task_signals()
	var pad = preload("res://scripts/touch_pad.gd").new()
	pad.name = "TouchPad"
	add_child(pad)
	pad.visible = InputMode.show_vj()
	pad.stick_changed.connect(func(axis: Vector2) -> void:
		var lp := _local_touch_player()
		if lp:
			lp.stick_axis = axis
	)
	pad.hold_changed.connect(func(action: String, pressed: bool) -> void:
		if _early_open and pressed:
			if action == "interact":
				if _early_focus == 0:
					_confirm_early_close()
				else:
					_decline_early_close()
			elif action == "cancel":
				_decline_early_close()
			return
		if phase == "closed" and pressed and (action == "interact" or action == "cancel"):
			if _closeout_input_ready():
				_return_to_prep()
			return
		var lp2 := _local_touch_player()
		if lp2:
			lp2.set_hold(action, pressed)
	)
	pad.skill_hotkey.connect(func(slot: int) -> void:
		var lp3 := _local_touch_player()
		if lp3 and lp3.has_method("cast_skill_hotkey"):
			lp3.call("cast_skill_hotkey", slot)
	)
	if not InputMode.show_vj_changed.is_connected(_on_show_vj_changed):
		InputMode.show_vj_changed.connect(_on_show_vj_changed)
	if not InputMode.clear_virtual_holds.is_connected(_clear_virtual_holds):
		InputMode.clear_virtual_holds.connect(_clear_virtual_holds)
	## Clients skip clerk/dirt AI seeds — host owns world agents (§12 / listen-server).
	if _tutorial != null and is_instance_valid(_tutorial) and _tutorial.has_method("clear_runtime_flags"):
		## Clear before dirt seed so `dirt_present` is re-armed for this day only.
		_tutorial.clear_runtime_flags()
	if SessionService.is_server() or SessionService.is_local_transport():
		_spawn_clerks()
		if _boss_world.should_spawn_open_dirt():
			for i in Tuning.dirt_start(_play_easy()):
				_try_spawn_dirt()
		if _hud != null and _hud.has_method("setup_boss_progress") and _boss_world.is_active():
			_hud.call("setup_boss_progress", _boss_world.progress_total())
		## Align client shelf／warehouse／carry／prompt presentation after world exists (M2.4／M2.6／M2.9).
		if SessionService.is_networked() and SessionService.is_server():
			_dump_all_stock()
			_dump_all_carry()
			_dump_all_prompt()
			_broadcast_day_hud_state()
			_dump_all_skill_cds()
	else:
		## Apply spawn／flight／state RPCs that raced ahead of world build (M2.2～M2.9).
		_flush_pending_agent_spawns()
		_flush_pending_flights()
		_flush_pending_agent_states()
		_flush_pending_stock_states()
		_flush_pending_carry_states()
		_flush_pending_prompt_states()
		_day_chrome.flush_pending_day_hud_states()
		_day_chrome.flush_pending_day_clock_states()
		_day_chrome.flush_pending_skill_cd_states()
	## Ops tutorial after world／HUD exist (director survives _clear_world).
	if _tutorial != null and is_instance_valid(_tutorial):
		_tutorial.call_deferred("consider_ops")
	## Boss day: restock foreshadow dialog after HUD／world ready.
	if _boss_world != null and _boss_world.is_active():
		call_deferred("_boss_run_restock_intro")


func _local_touch_player() -> CharacterBody2D:
	for p in _players:
		if p != null and is_instance_valid(p) and SeatTable.seat_owned_locally(int(p.seat_id)):
			return p
	return _player


func _clear_world() -> void:
	_clear_self_service_operation()
	_clear_three_volley()
	## TutorialDirector owns the explain modal — must survive day rebuild
	## (same as prep／pause). Killing it left a freed ref and soft-locked ops.
	if _tutorial != null and is_instance_valid(_tutorial) and _tutorial.has_method("close_modal_if_open"):
		_tutorial.close_modal_if_open()
	var kill: Array[Node] = []
	for c in get_children():
		if c == _prep or c == _pause or c == _tutorial:
			continue
		kill.append(c)
	for c in kill:
		c.queue_free()
	_world = null
	_door_caption = null
	_hud = null
	shelves.clear()
	_shelves_by_sku.clear()
	_empty_by_cat.clear()
	_dirt_block_cells.clear()
	_thieves.clear()
	_guest_n = 0
	_active_thief_n = 0
	cashiers.clear()
	self_cashiers.clear()
	portals.clear()
	_next_net_portal_id = 0
	_dirts.clear()
	_ops_items.clear()
	_clerks.clear()
	_net.clear_runtime()
	_obstacles.clear()
	cashier = null
	_player = null
	_players.clear()
	_customers = null
	_net_pres.clear()
	_owned_host_pose.clear()
	_net_accum = 0.0
	_agent_xform_accum = 0.0
	_skill_cd_net_fp = ""
	_pending_skill_cd_states.clear()
	_early_open = false
	_early_latched = false
	_early_layer = null
	_early_yes = null
	_early_no = null


func _build_furniture(nodes: Array[Node2D]) -> void:
	_world_build.build_furniture(nodes)

func _spawn_clerks() -> void:
	_world_build.spawn_clerks()

func _on_tutorial_progress() -> void:
	bump_hud()


func note_clean(seat: int = 0, actor_override: Node2D = null) -> void:
	## seat < 0: NPC / store clean (e.g. cleaner clerk) — day tally + rating only.
	cleaned += 1
	var actor: Node2D = actor_override
	if actor == null and seat >= 0:
		actor = _seat_actor(seat)
	var FloatText = preload("res://scripts/ui/float_text.gd")
	if seat >= 0:
		_seat_bump(seat_cleaned, seat, 1)
		if actor != null:
			FloatText.spawn_xp(actor, _xp_float("clean", seat))
	apply_ops_rating(RatingRules.P4_CLEAN, actor)
	bump_hud()
	if seat < 0:
		return
	if _tasks != null:
		_tasks.note_metric(seat, "clean_count", 1)
	if _tutorial != null:
		_tutorial.note_metric("clean_count", 1)


func _seat_level(seat: int) -> int:
	var sheet = SeatTable.sheet_of(seat)
	if sheet != null and "level" in sheet:
		return int(sheet.level)
	if seat <= 0:
		return int(state.level) if state != null else 1
	return int(state.level) if state != null else 1


func _xp_float(kind: String, seat: int = 0) -> int:
	var r: Dictionary = XpRules.rates_for_level(_seat_level(seat))
	return int(r.get(kind, 0))


func _seat_bump(arr: Array, seat: int, n: int) -> void:
	while arr.size() <= seat:
		arr.append(0)
	arr[seat] = int(arr[seat]) + n


func kind_cannon_closeout_text(seat_n: int) -> String:
	var lines := PackedStringArray()
	lines.append(Loc.t("settle.kind_cannon_total", [kind_converted_total]))
	for seat in mini(seat_n, seat_kind_converted.size()):
		lines.append(Loc.t("settle.kind_cannon_seat", [seat + 1, int(seat_kind_converted[seat])]))
	return "\n".join(lines)


func combo_note_qualify(seat: int) -> void:
	## +1 COMBO streak only; ops P5 is on perfect clear-list via combo_note_perfect.
	if _combo == null:
		return
	_combo.note_qualify(seat)
	bump_hud()
	if _tasks != null:
		_tasks.set_metric_absolute(seat, "deliver_combo", int(_combo.personal_of(seat)))


func combo_note_perfect(seat: int) -> void:
	apply_ops_rating(RatingRules.P5_COMBO, _seat_actor(seat))


func combo_break_personal(seat: int) -> void:
	if _combo == null:
		return
	_combo.note_break_personal(seat)
	bump_hud()
	if _tasks != null:
		_tasks.set_metric_absolute(seat, "deliver_combo", 0)


func combo_personal(seat: int) -> int:
	if _combo == null:
		return 0
	return int(_combo.personal_of(seat))


func combo_team() -> int:
	if _combo == null:
		return 0
	return int(_combo.team)


func yes_my_lord_on() -> bool:
	## Any seated clerk with the buff (coop: not only game._player).
	for p in _players:
		if p != null and is_instance_valid(p) and p.buff_left("yes_my_lord") > 0.05:
			return true
	return false


## Force-release checkout command UI.
## `guest == null`: clear every seat mid-cashier (global skills).
## `guest` set: only the seat whose locked register is serving that guest (coop-safe).
func release_player_checkout(guest = null) -> void:
	var seats: Array = _players
	if seats.is_empty() and _player != null:
		seats = [_player]
	for p in seats:
		if p == null or not is_instance_valid(p):
			continue
		if not p.has_method("release_checkout"):
			continue
		if guest != null:
			if not p.get("command_lock"):
				continue
			var reg = p.get("target")
			if reg == null or not reg.has_method("ready_customer"):
				continue
			if reg.call("ready_customer") != guest:
				continue
		p.release_checkout()


## True if any seated player has A4 command_lock on this cashier.
func seat_locks_register(reg: Node) -> bool:
	if reg == null:
		return false
	var seats: Array = _players
	if seats.is_empty() and _player != null:
		seats = [_player]
	for p in seats:
		if p == null or not is_instance_valid(p):
			continue
		if p.get("command_lock") and p.get("target") == reg:
			return true
	return false


func nearest_stocked_shelf(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for s in shelves:
		if s == null or not is_instance_valid(s):
			continue
		if int(s.get("count")) <= 0:
			continue
		var d := from.distance_squared_to(s.global_position)
		if d < best_d:
			best = s
			best_d = d
	return best


func cast_fundraise(level: int, seat: int = 0) -> void:
	_skill_cast.cast_fundraise(level, seat)

func cast_harvest_chives(reg: Node, max_n: int, seat: int = 0) -> int:
	return _skill_cast.cast_harvest_chives(reg, max_n, seat)

func play_skill_banner(text: String) -> void:
	_skill_cast.play_skill_banner(text)

func cast_summon_guest(n: int) -> int:
	return _skill_cast.cast_summon_guest(n)

func cast_guest_dusk() -> bool:
	return _skill_cast.cast_guest_dusk()

func clear_guest_dusk() -> void:
	_skill_cast.clear_guest_dusk()

func cast_close_gate() -> void:
	_skill_cast.cast_close_gate()

func cast_three_volley() -> void:
	_skill_cast.cast_three_volley()

func _track_three_volley_visual(effect: Node2D) -> void:
	_skill_cast._track_three_volley_visual(effect)

func _on_three_volley_visual_exiting(effect: Node2D) -> void:
	_skill_cast._on_three_volley_visual_exiting(effect)

func _clear_three_volley() -> void:
	_skill_cast._clear_three_volley()

func _tick_three_volley(delta: float) -> void:
	_skill_cast._tick_three_volley(delta)

func _resolve_three_volley_wave(hit_thieves: Array[int]) -> void:
	_skill_cast._resolve_three_volley_wave(hit_thieves)

func sellable() -> Array[String]:
	return state.sellable()


func customer_list_bounds() -> Vector2i:
	var hi := Tuning.list_hi(state.customer_list_max(), _play_easy())
	var lo := Tuning.list_lo(state.customer_list_min(), hi)
	return Vector2i(lo, hi)


func set_play_difficulty(id: String) -> void:
	## Scenario 5 tutorial always runs Easy.
	if state != null and int(state.scenario) == 5:
		play_difficulty = "easy"
		return
	play_difficulty = "easy" if id == "easy" else "normal"


func play_is_easy() -> bool:
	return _play_easy()


func dissat_gain_mult() -> float:
	return Tuning.EASY_DISSAT_MULT if _play_easy() else 1.0


func dirt_spawn_interval() -> float:
	return Tuning.dirt_interval(state.dirt_spawn_sec(), _play_easy())


func thief_appear_rate() -> float:
	## Shop-wide haki: any seated loadout with thief_rate applies (design: 全店效果).
	var rate := _seat_thief_rate()
	return Tuning.thief_rate(rate, _play_easy())


func _seat_thief_rate() -> float:
	var best := 1.0
	var found := false
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		var stats = p.get("stats")
		if stats == null:
			continue
		if stats.has_method("thief_spawn_rate"):
			var r := float(stats.call("thief_spawn_rate"))
			best = minf(best, r)
			found = true
			continue
		## CharacterSheet: scan loadout for thief_rate.
		if stats.has_method("loadout"):
			for sk in stats.loadout():
				if sk is Dictionary and sk.has("thief_rate"):
					best = minf(best, float(sk["thief_rate"]))
					found = true
	if found:
		return best
	return state.thief_spawn_rate() if state != null else 1.0


func _play_easy() -> bool:
	if not ProductVersion.test_tools_enabled():
		return false
	## Scenario 5: locked to Easy regardless of the prep toggle.
	if state != null and int(state.scenario) == 5:
		return true
	return play_difficulty == "easy"


func queue_dissat_blocked() -> bool:
	## Shop-wide cold_smile: any seated clerk with the flag.
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		if p.has_method("_has_flag") and bool(p.call("_has_flag", "no_queue_dissat")):
			return true
		var stats = p.get("stats")
		if stats != null and stats.has_method("has_flag") and bool(stats.has_flag("no_queue_dissat")):
			return true
	return state != null and state.has_flag("no_queue_dissat")


func soothe_all(keep: float) -> void:
	if SessionService.is_networked() and SessionService.is_client():
		return
	if _customers == null:
		return
	for c in _customers.get_children():
		if c.has_method("apply_soothe"):
			c.call("apply_soothe", keep)


func cast_dark_side(level: int, seat: int = -1) -> void:
	_clerk_cast.cast_dark_side(level, seat)

func cast_shadow_clone(level: int, seat: int = -1) -> void:
	_clerk_cast.cast_shadow_clone(level, seat)

func dismiss_shadow_clones() -> void:
	_clerk_cast.dismiss_shadow_clones()

func dismiss_elite_guest_specialists() -> void:
	_clerk_cast.dismiss_elite_guest_specialists()

func shadow_clones() -> Array:
	return _clerk_cast.shadow_clones()

func _clone_spawn_people() -> Array:
	return _clerk_cast._clone_spawn_people()

func _clone_spawn_people_for(caster: Node2D) -> Array:
	return _clerk_cast._clone_spawn_people_for(caster)

func restock_holds(except: Node) -> Dictionary:
	return _clerk_cast.restock_holds(except)

func _note_restock_hold(sku: Dictionary, shelf: Dictionary, planned, carried, target) -> void:
	_clerk_cast._note_restock_hold(sku, shelf, planned, carried, target)

func _hired_cashier_registers() -> Array:
	return _clerk_cast._hired_cashier_registers()

func _temp_cashier_registers() -> Array:
	return _clerk_cast._temp_cashier_registers()

func _dark_side_player_pos() -> Vector2:
	return _clerk_cast._dark_side_player_pos()

func _caster_pos(caster: Node2D) -> Vector2:
	return _clerk_cast._caster_pos(caster)

func _player_lock_register():
	_clerk_cast._player_lock_register()

func _checkout_locked_guest():
	_clerk_cast._checkout_locked_guest()

func all_registers() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for c in cashiers:
		if c != null and is_instance_valid(c):
			out.append(c)
	for c in self_cashiers:
		if c != null and is_instance_valid(c):
			out.append(c)
	return out


func pick_register(cust: Node) -> Node2D:
	var regs := all_registers()
	if regs.is_empty():
		return null
	var best_n := 999
	for c in regs:
		best_n = mini(best_n, int(c.queue.size()))
	var tied: Array[Node2D] = []
	for c in regs:
		if int(c.queue.size()) == best_n:
			tied.append(c)
	if tied.size() == 1:
		return tied[0]
	var origin: Vector2 = cust.global_position if cust != null and cust is Node2D else Vector2.ZERO
	var best_d := INF
	var nearest: Array[Node2D] = []
	for c in tied:
		var d := origin.distance_squared_to(c.global_position)
		if d < best_d - 0.01:
			best_d = d
			nearest = [c]
		elif absf(d - best_d) <= 0.01:
			nearest.append(c)
	if nearest.is_empty():
		return tied[0]
	if nearest.size() == 1:
		return nearest[0]
	return nearest[randi() % nearest.size()]


func customers_near(origin: Vector2, radius_sq: float) -> bool:
	## 「唔該借借」擁擠＝附近至少 2 人（設計／sfx：多人）。單一名交付對象不算擁擠。
	if _customers == null:
		return false
	var n := 0
	for c in _customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## Non-customer children: Object.get returns null → int()/bool() constructors explode.
		if not c.has_method("occupies_store"):
			continue
		if c.temp_clerk:
			continue
		## Leave / flee / temp job are not blocking the aisle.
		var st: int = c.state
		if st == CustomerScript.State.LEAVE or st == CustomerScript.State.FLEE or st == CustomerScript.State.TEMP:
			continue
		if origin.distance_squared_to(c.global_position) <= radius_sq:
			n += 1
			if n >= 2:
				return true
	return false


func customers_in_radius(origin: Vector2, radius_sq: float) -> Array:
	var out: Array = []
	if _customers == null:
		return out
	for c in _customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## Ops FloatText siblings live under Customers; skip non-guests.
		if not c.has_method("occupies_store"):
			continue
		if origin.distance_squared_to(c.global_position) <= radius_sq:
			out.append(c)
	return out


func nearest_shelf(origin: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 1.0e12
	for s in shelves:
		if s == null or not is_instance_valid(s):
			continue
		var d := origin.distance_squared_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func random_shelf_stand() -> Vector2:
	if shelves.is_empty():
		return Vector2.ZERO
	var s: Node2D = shelves[randi() % shelves.size()]
	if s != null and is_instance_valid(s) and has_method("shelf_stand"):
		return shelf_stand(s)
	return Vector2.ZERO


func spawn_dirt_at(at: Vector2, dtype: String) -> bool:
	if _tutorial_blocks_dirt_spawn():
		return false
	if _dirts.size() >= Tuning.DIRT_CAP:
		return false
	var size := Tuning.DIRT_SIZE
	var origin := at - size * 0.5
	var r := Rect2(origin, size)
	if _blocked_rect(r):
		## Nudge a few times for open floor near the elite.
		for _i in 6:
			origin = at + Vector2(randf_range(-36, 36), randf_range(-36, 36)) - size * 0.5
			r = Rect2(origin, size)
			if not _blocked_rect(r):
				_spawn_dirt(r, dtype)
				return true
		return false
	_spawn_dirt(r, dtype)
	return true


func restock_for(cat: String) -> Node2D:
	for n in _player.interactables if _player else []:
		if n != null and str(n.get("kind")) == "restock" and str(n.get("category")) == cat:
			return n
	return null


func sync_stock() -> void:
	## Refresh restock-point warehouse mirrors (M2.4 client warehouse apply).
	var seen: Dictionary = {}
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		for n in p.interactables:
			if n == null or not is_instance_valid(n) or seen.has(n):
				continue
			seen[n] = true
			if str(n.get("kind")) == "restock" and n.has_method("pull_stock"):
				n.call("pull_stock")


## Aggregate unsold pieces: shelves, floor, in-flight, player carry,
## clerk-held boxes, and guests who finished their list but have not paid.

func _collect_unsold_pieces() -> Dictionary:
	return DaySettle.collect_unsold_pieces(self)

func _add_pieces(dst: Dictionary, src: Dictionary) -> void:
	DaySettle.add_pieces(dst, src)

func _collect_shelf_floor_pieces() -> Dictionary:
	return DaySettle.collect_shelf_floor_pieces(self)

func _collect_player_carry_pieces() -> Dictionary:
	return DaySettle.collect_player_carry_pieces(self)

func _collect_clerk_held_pieces() -> Dictionary:
	return DaySettle.collect_clerk_held_pieces(self)

func _collect_unpaid_checkout_pieces() -> Dictionary:
	return DaySettle.collect_unpaid_checkout_pieces(self)

func _return_unsold_to_warehouse() -> void:
	DaySettle.return_unsold_to_warehouse(self)

func _clear_credited_unsold() -> void:
	DaySettle.clear_credited_unsold(self)
func _unhandled_input(event: InputEvent) -> void:
	if _early_open:
		_early_input(event)
		return
	if phase != "closed":
		return
	if event.is_echo() or not event.is_pressed():
		return
	if not (event.is_action_pressed(Controls.INTERACT) or event.is_action_pressed(Controls.CANCEL)):
		return
	if not _closeout_input_ready():
		get_viewport().set_input_as_handled()
		return
	_return_to_prep()
	get_viewport().set_input_as_handled()


func _closeout_input_ready() -> bool:
	return _settled and Time.get_ticks_msec() >= _closeout_ready_msec


func _return_to_prep() -> void:
	if phase != "closed":
		return
	if not _closeout_input_ready():
		return
	phase = "prep"
	clear_elite_test()
	if _boss_world != null:
		_boss_world.clear()
	## Capture before close() clears settlement_applied.
	var settled_ok := SessionService.settlement_applied or _settled
	var keep_room := SessionService.keeps_room_after_settle()
	if keep_room:
		## §12.10: stay in lobby — do not tear down peer／Steam lobby.
		SessionService.return_to_lobby_after_settle()
	else:
		SessionService.close()
	## Client still holds Host world in `state` until we restore home save.
	_reload_local_save_for_prep(settled_ok)
	_clear_world()
	_prep.visible = true
	_prep.set_process_unhandled_input(true)
	if keep_room:
		if _prep.has_method("refresh_room_sheets_from_state"):
			_prep.call("refresh_room_sheets_from_state")
		_prep._show_page("lobby")
	else:
		_prep._show_page("home")
		if _prep.has_method("maybe_offer_difficulty_prompt"):
			_prep.call("maybe_offer_difficulty_prompt")
	var bgm_prep := BgmBusScript.bus()
	if bgm_prep:
		bgm_prep.play_prep()


func _reload_local_save_for_prep(settled_ok: bool = false) -> void:
	## Client day mutates `state` into Host world; never leave that in prep／disk.
	if state == null:
		return
	if settled_ok == false:
		settled_ok = SessionService.settlement_applied
	if SessionService.has_client_home_stash():
		if settled_ok:
			## Settle already wrote stash + XP／money／support to disk.
			var err := state.load_from_disk()
			if err != "":
				push_warning("reload save for prep failed: %s" % err)
				var stash_err := state.from_dict(SessionService.peek_client_home_stash())
				if stash_err != "":
					push_warning("restore home stash failed: %s" % stash_err)
		else:
			## Host abort／dissolve: restore home shop (fixes same-machine Host clobber).
			var stash_err2 := state.from_dict(SessionService.peek_client_home_stash())
			if stash_err2 != "":
				push_warning("restore home stash failed: %s" % stash_err2)
			else:
				var save_err := state.save_to_disk()
				if save_err != "":
					push_warning("rewrite home save after dissolve failed: %s" % save_err)
		SessionService.clear_client_home_stash()
		return
	var err2 := state.load_from_disk()
	if err2 != "":
		push_warning("reload save for prep failed: %s" % err2)


func configure_elite_test(lv: int) -> void:
	## lv 0 = mixed (roll 1–6 each elite); 1–6 = fixed level. Guarantees ≥1 elite.
	elite_test_active = true
	elite_test_lv = clampi(lv, 0, 6)
	elite_test_need_one = true


func clear_elite_test() -> void:
	elite_test_active = false
	elite_test_lv = 0
	elite_test_need_one = false


func boss_skip_cashier_clerks() -> bool:
	return _boss_world != null and _boss_world.should_skip_cashier_clerks()


func boss_on_list_cleared(cust: Node) -> bool:
	return _boss_world != null and bool(_boss_world.on_list_cleared(cust))


func boss_checkout_wave_count(cust: Node) -> int:
	return int(_boss_world.checkout_wave_count(cust)) if _boss_world != null else -1


func boss_on_checkout_wave_done(cust: Node) -> bool:
	return _boss_world != null and bool(_boss_world.on_checkout_wave_done(cust))


func boss_on_paid(cust: Node) -> void:
	if _boss_world != null:
		_boss_world.on_boss_paid(cust)


func boss_on_angry_leave(cust: Node) -> void:
	if _boss_world != null:
		_boss_world.on_boss_angry_leave(cust)


func boss_hand_deliver(player: Node, cust: Node) -> Dictionary:
	if _boss_world == null:
		return {"handled": false, "given": 0}
	return _boss_world.try_hand_deliver(player, cust)


func boss_on_wrong_toss(player: Node, cust: Node, sku: String, n: int, dest: Vector2) -> bool:
	return _boss_world != null and bool(_boss_world.on_wrong_toss(player, cust, sku, n, dest))


func spawn_loot_even_ring(origin: Vector2, piles: Array, radius: float) -> void:
	_toss_world.spawn_loot_even_ring(origin, piles, radius)


## Deferred entry points (Node) → presentation lives in boss_world.
func _boss_run_reject_flow(dialog_key: String, player: Node, knock_player: bool, origin: Vector2) -> void:
	if _boss_world != null:
		await _boss_world.run_reject_flow(dialog_key, player, knock_player, origin)


func _boss_run_restock_intro() -> void:
	if _boss_world != null and _boss_world.is_active():
		await _boss_world.run_restock_intro_cutscene()


func _boss_run_enter_cutscene() -> void:
	await _boss_world.run_enter_cutscene()


func _boss_run_list_cutscene(stage_1based: int) -> void:
	await _boss_world.run_list_cutscene(stage_1based)


func _boss_run_pay_wave_cutscene(wave_idx: int) -> void:
	await _boss_world.run_pay_wave_cutscene(wave_idx)


func _boss_run_win_flow() -> void:
	await _boss_world.run_win_flow()


func _boss_run_fail_flow(reason: String) -> void:
	await _boss_world.run_fail_flow(reason)


func elite_test_label() -> String:
	if not elite_test_active:
		return ""
	if elite_test_lv <= 0:
		return Loc.t("prep.elite_test.mixed")
	return Loc.t("prep.elite_test.lv", [elite_test_lv])


func asking_early_close() -> bool:
	return _early_open


func can_open_pause() -> bool:
	if _early_open:
		return false
	if _tutorial != null and _tutorial.is_modal_open():
		return false
	return phase == "restock" or phase == "open"


func request_pause() -> void:
	if SessionService.is_networked():
		var open_now := _pause != null and _pause.has_method("is_open") and bool(_pause.call("is_open"))
		SessionService.request_pause(not open_now)
		return
	if _pause == null or not _pause.has_method("open_menu"):
		return
	if _pause.has_method("is_open") and bool(_pause.call("is_open")):
		return
	_pause.call("open_menu", false)


func _on_room_paused_changed(paused: bool) -> void:
	if _pause == null:
		return
	if _pause.has_method("apply_net_pause"):
		_pause.call("apply_net_pause", paused)
		return
	var open_now := _pause.has_method("is_open") and bool(_pause.call("is_open"))
	if paused and not open_now and _pause.has_method("open_menu"):
		_pause.call("open_menu", false)
	elif not paused and open_now and _pause.has_method("close_menu"):
		_pause.call("close_menu")


func _on_session_peer_left(_peer_id: int) -> void:
	_prune_frozen_players()


func _on_session_seats_changed() -> void:
	if phase == "restock" or phase == "open":
		_prune_frozen_players()


func _on_session_disconnect(during_day: bool = false) -> void:
	## Host left mid-run (§12.7): abort day and return to prep — do not keep playing as P1.
	## If settle already applied, Host closing the lobby is normal — keep closeout UI.
	if SessionService.settlement_applied:
		return
	if not during_day:
		return
	if phase == "prep":
		return
	_dissolve_room_to_prep()


func _dissolve_room_to_prep() -> void:
	## Immediate room dissolve (no Host settle). Stops input on leftover avatars first.
	if _pause != null and _pause.has_method("apply_net_pause"):
		_pause.call("apply_net_pause", false)
	elif _pause != null and _pause.has_method("close_menu"):
		_pause.call("close_menu")
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		p.set_process(false)
		p.set_physics_process(false)
		p.set_process_input(false)
		p.set_process_unhandled_input(false)
	_players.clear()
	_player = null
	phase = "closed"
	_settled = true
	_closeout_ready_msec = 0
	_early_open = false
	clear_elite_test()
	_clear_world()
	_reload_local_save_for_prep(SessionService.settlement_applied)
	phase = "prep"
	if _prep:
		_prep.visible = true
		_prep.set_process_unhandled_input(true)
		_prep._show_page("home")
		if _prep.has_method("_popup_info"):
			_prep.call("_popup_info", Loc.t("lobby.error_title"), Loc.t("lobby.host_left"))


func _prune_frozen_players() -> void:
	var keep: Array[CharacterBody2D] = []
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		if SeatTable.is_frozen(int(p.seat_id)):
			p.queue_free()
			continue
		keep.append(p)
	_players = keep
	if not _players.is_empty():
		_player = _players[0]
	bump_hud()


func _on_settle_payload(payload: Dictionary) -> void:
	## Client: Host settle RPC applied (or failed) — show closeout, do not treat later room close as abort.
	_settled = true
	_closeout_ready_msec = Time.get_ticks_msec() + CLOSEOUT_HOLD_MSEC
	phase = "closed"
	if _hud == null:
		return
	_hud.show_closeout()
	var apply: Dictionary = payload.get("_apply", {})
	var ok := bool(apply.get("ok", false))
	var shared_xp := int(apply.get("shared_xp", payload.get("shared_xp", 0)))
	var support := int(apply.get("support_rating", 0))
	var grade := int(apply.get("grade", payload.get("host_grade", 0)))
	var revenue_gain := int(apply.get("revenue", payload.get("revenue", 0)))
	var money_after := int(apply.get("money", 0))
	var converted_total := int(payload.get("kind_cannon_total", 0))
	var converted_personal := 0
	var converted_seat := int(apply.get("seat", -1))
	var converted_by_seat: Dictionary = payload.get("per_seat", {})
	if converted_seat >= 0:
		var personal_row: Dictionary = converted_by_seat.get(converted_seat, converted_by_seat.get(str(converted_seat), {}))
		converted_personal = int(personal_row.get("kind_cannon_converted", 0))
	var head := Loc.t("demo.closeout_head")
	var xp_line: String
	if ok:
		xp_line = Loc.t("lobby.client_settle_ok", [shared_xp, support, grade])
		if revenue_gain > 0 or money_after > 0:
			xp_line += "\n" + Loc.t("lobby.client_settle_revenue", [revenue_gain, money_after])
	else:
		xp_line = Loc.t("lobby.client_settle_fail")
	_hud.set_closeout_panels("\n".join([
		head,
		xp_line,
		Loc.t("settle.kind_cannon_client", [converted_personal, converted_total]),
		Loc.t("lobby.client_settle_hint"),
	]), Loc.t("settle.tasks_host_only"))


func on_pause_opened() -> void:
	_clear_virtual_holds()


func on_pause_closed() -> void:
	apply_camera_view()


func shop_camera_center() -> Vector2:
	return FLOOR_ORIGIN + FLOOR_SIZE * 0.5


func coop_camera_midpoint() -> Vector2:
	var pts: Array[Vector2] = []
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		## LAN: follow seats owned on this machine; local coop: all seats.
		if SessionService.is_networked() and not SeatTable.seat_owned_locally(int(p.seat_id)):
			continue
		if SeatTable.is_frozen(int(p.seat_id)):
			continue
		pts.append(p.global_position)
	if pts.is_empty():
		for p2 in _players:
			if p2 != null and is_instance_valid(p2) and not SeatTable.is_frozen(int(p2.seat_id)):
				pts.append(p2.global_position)
	if pts.is_empty():
		if _player != null and is_instance_valid(_player):
			return _player.global_position
		return shop_camera_center()
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	return mid / float(pts.size())


func is_local_coop() -> bool:
	return SeatTable.is_coop()


func overview_camera_zoom() -> float:
	## Fit the whole floor in the viewport with a small margin (Godot zoom: smaller = wider).
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0 or FLOOR_SIZE.x <= 1.0 or FLOOR_SIZE.y <= 1.0:
		return Tuning.CAMERA_ZOOM_FAR
	var margin := 1.08
	var zx := vp.x / (FLOOR_SIZE.x * margin)
	var zy := vp.y / (FLOOR_SIZE.y * margin)
	return minf(zx, zy)


func apply_camera_view() -> void:
	if _player == null:
		return
	if _player.has_method("camera_priority_busy") and bool(_player.call("camera_priority_busy")):
		return
	if _elite_zoom_busy:
		return
	if _player.has_method("restore_base_camera"):
		_player.call("restore_base_camera")


func _on_camera_view_changed(_mode: String) -> void:
	apply_camera_view()


func _poll_camera_view_hotkey() -> void:
	if phase != "restock" and phase != "open":
		return
	if _pause != null and _pause.has_method("is_open") and bool(_pause.call("is_open")):
		return
	if not Input.is_action_just_pressed(Controls.CAMERA_VIEW):
		return
	PlatformServices.cycle_camera_view()


func _maintain_overview_camera() -> void:
	if PlatformServices.get_camera_view() != PlatformServices.CAMERA_VIEW_OVERVIEW:
		return
	if _player == null or _player.camera == null:
		return
	if _player.has_method("camera_priority_busy") and bool(_player.call("camera_priority_busy")):
		return
	if _elite_zoom_busy:
		return
	var cam: Camera2D = _player.camera
	if not cam.top_level:
		return
	cam.global_position = shop_camera_center()


func _maintain_coop_camera() -> void:
	if not SeatTable.is_coop():
		return
	if PlatformServices.get_camera_view() == PlatformServices.CAMERA_VIEW_OVERVIEW:
		return
	if _player == null or _player.camera == null:
		return
	if _player.has_method("camera_priority_busy") and bool(_player.call("camera_priority_busy")):
		return
	if _elite_zoom_busy:
		return
	## Seat1 fight/elite may also busy the shared cam — treat any seated priority as busy.
	for p in _players:
		if p != null and p != _player and p.has_method("camera_priority_busy") and bool(p.call("camera_priority_busy")):
			return
	var cam: Camera2D = _player.camera
	cam.top_level = true
	cam.global_position = coop_camera_midpoint()


func _soft_push_players(delta: float) -> void:
	if _players.size() < 2:
		return
	## Only host / local sim owns physics positions.
	if SessionService.is_client():
		return
	for i in _players.size():
		var a: CharacterBody2D = _players[i]
		if a == null or not is_instance_valid(a) or SeatTable.is_frozen(int(a.seat_id)):
			continue
		for j in range(i + 1, _players.size()):
			var b: CharacterBody2D = _players[j]
			if b == null or not is_instance_valid(b) or SeatTable.is_frozen(int(b.seat_id)):
				continue
			var delta_pos := b.global_position - a.global_position
			var dist := delta_pos.length()
			if dist <= 0.001:
				continue
			var pen := COOP_SOFT_RADIUS - dist
			if pen < COOP_SOFT_MIN_PEN:
				continue
			var n := delta_pos / dist
			var push := pen / COOP_SOFT_RADIUS * COOP_SOFT_PUSH * delta
			a.global_position -= n * push
			b.global_position += n * push


func _on_show_vj_changed(visible_now: bool) -> void:
	var pad := get_node_or_null("TouchPad")
	if pad:
		pad.visible = visible_now
	if not visible_now:
		_clear_virtual_holds()


func _clear_virtual_holds() -> void:
	if _player and _player.has_method("set_hold"):
		_player.set_hold("interact", false)
		_player.set_hold("cancel", false)
		_player.set_hold("dash", false)
		_player.set_hold("skill", false)
		_player.set_hold("bag_menu", false)
		_player.set_hold("ult", false)
	if _player:
		_player.stick_axis = Vector2.ZERO


func _on_pause_end_day() -> void:
	skip_operate()


func _consider_early_close() -> bool:
	## §8.1: only Host evaluates early-close (Client clock is presentation-only).
	if SessionService.is_networked() and SessionService.is_client():
		return false
	if not _restocks_cleared() or not _registers_idle():
		_early_latched = false
		return false
	if _early_latched:
		return false
	_show_early_dialog()
	_day_chrome.broadcast_day_clock_state(true)
	return true


func _restocks_cleared() -> bool:
	if _player == null or state == null:
		return false
	var saw := false
	for n in _player.interactables:
		if n == null or not is_instance_valid(n):
			continue
		if str(n.get("kind")) != "restock":
			continue
		saw = true
		if not n.has_method("skus"):
			return false
		for sku in n.skus():
			if int(state.stock.get(sku, 0)) > 0:
				return false
	return saw


func _registers_idle() -> bool:
	for c in all_registers():
		if c != null and is_instance_valid(c) and c.queue.size() > 0:
			return false
	return true


func _show_early_dialog() -> void:
	_early_open = true
	_early_focus = 0
	SfxBus.play("sfx_early_close_ask")
	if _player and _player.has_method("set_hold"):
		_player.set_hold("interact", false)
		_player.set_hold("cancel", false)
		_player.set_hold("dash", false)
		_player.set_hold("skill", false)
		_player.set_hold("bag_menu", false)
		_player.set_hold("ult", false)
	if _early_layer != null and is_instance_valid(_early_layer):
		_early_layer.visible = true
		_paint_early_focus()
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := ColorRect.new()
	card.color = Color("1c241f")
	card.position = Vector2(240, 150)
	card.size = Vector2(800, 420)
	layer.add_child(card)
	var title := Label.new()
	title.text = Loc.t("early.title")
	title.position = Vector2(36, 28)
	title.size = Vector2(720, 56)
	UiFont.apply_label(title, 36)
	title.add_theme_color_override("font_color", Color("f4d35e"))
	card.add_child(title)
	var body := Label.new()
	body.text = Loc.t("early.body")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(36, 108)
	body.size = Vector2(720, 110)
	UiFont.apply_label(body, 26)
	body.add_theme_color_override("font_color", Color("f4f1ea"))
	card.add_child(body)
	var hint := Label.new()
	hint.text = Loc.t("early.hint")
	hint.position = Vector2(36, 228)
	hint.size = Vector2(720, 40)
	UiFont.apply_label(hint, 22)
	hint.add_theme_color_override("font_color", Color("c8c2b4"))
	card.add_child(hint)
	_early_yes = _early_choice(Loc.t("early.yes"), Vector2(36, 290), _confirm_early_close)
	_early_no = _early_choice(Loc.t("early.no"), Vector2(400, 290), _decline_early_close)
	card.add_child(_early_yes)
	card.add_child(_early_no)
	_early_layer = layer
	_paint_early_focus()


func _early_choice(text: String, at: Vector2, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = at
	btn.size = Vector2(360, 88)
	btn.focus_mode = Control.FOCUS_NONE
	UiFont.apply_button(btn, 22)
	btn.pressed.connect(cb)
	return btn


func _paint_early_focus() -> void:
	_style_early_btn(_early_yes, _early_focus == 0)
	_style_early_btn(_early_no, _early_focus == 1)


func _style_early_btn(btn: Button, on: bool) -> void:
	if btn == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f4d35e") if on else Color("24302a")
	box.set_corner_radius_all(10)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state_name, box)
	btn.add_theme_color_override("font_color", Color("1c241f") if on else Color("f4f1ea"))


func _early_input(event: InputEvent) -> void:
	if event.is_echo():
		get_viewport().set_input_as_handled()
		return
	var early_dir := Controls.dir_from_event(event)
	if not (
		early_dir == 2
		or early_dir == 3
		or event.is_action(Controls.INTERACT)
		or event.is_action(Controls.CANCEL)
	):
		return
	var press := event.is_pressed()
	get_viewport().set_input_as_handled()
	if not press:
		return
	if early_dir == 2:
		_early_focus = 0
		_paint_early_focus()
	elif early_dir == 3:
		_early_focus = 1
		_paint_early_focus()
	elif event.is_action_pressed(Controls.INTERACT):
		if _early_focus == 0:
			_confirm_early_close()
		else:
			_decline_early_close()
	elif event.is_action_pressed(Controls.CANCEL):
		_decline_early_close()


func _confirm_early_close() -> void:
	## Same Host-only gate as skip_operate / pause end-day.
	if SessionService.is_networked() and not SessionService.request_end_day():
		return
	if _tutorial != null and _tutorial.blocks_settle():
		_decline_early_close()
		return

	if not _early_open:
		return
	_hide_early_dialog()
	_early_closed = true
	clear_guest_dusk()
	phase = "closed"
	game_hours = Tuning.CLOSE_HOUR
	_day_chrome.broadcast_day_clock_state(true)
	_finish_day()


func _decline_early_close() -> void:
	if SessionService.is_networked() and SessionService.is_client():
		## Client mirrors Host chrome only — cannot dismiss Host prompt.
		return
	if not _early_open:
		return
	_early_latched = true
	_hide_early_dialog()
	_day_chrome.broadcast_day_clock_state(true)


func _hide_early_dialog() -> void:
	_early_open = false
	if _early_layer != null and is_instance_valid(_early_layer):
		_early_layer.visible = false


## Boss dialog／zoom: stop guests／clerks／clones／players (world clock also frozen).
func cutscene_freezes_actors() -> bool:
	return _boss_world != null and _boss_world.time_frozen


func world_delta(delta: float) -> float:
	if _early_open:
		return 0.0
	if _boss_world != null and _boss_world.time_frozen:
		return 0.0
	## the_world: strongest freeze wins (min clock_scale across seats).
	var scale := 1.0
	var any := false
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		any = true
		scale = minf(scale, float(p.get("clock_scale")))
	if not any and _player != null:
		scale = float(_player.get("clock_scale"))
	return delta * scale


func customer_move_mult() -> float:
	## metal_rush: strongest speed-up wins (max mult across seats).
	var mult := 1.0
	var any := false
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		any = true
		mult = maxf(mult, float(p.get("customer_move_mult")))
	if not any and _player != null:
		return float(_player.get("customer_move_mult"))
	return mult


func _process(delta: float) -> void:
	if phase == "prep" or phase == "closed":
		return
	## Early-close dialog freezes clock via world_delta=0 but keeps net ticks (boss pattern).
	if _early_open:
		_poll_camera_view_hotkey()
		_maintain_overview_camera()
		_maintain_coop_camera()
		_net_tick_intents_and_sync(delta)
		return
	## Tutorial pages open: hold the day still without get_tree().paused.
	if tutorial_freezes_play():
		return
	## Boss cutscenes freeze ops clock (guests／dissat still pause via world_delta=0).
	if _boss_world != null and _boss_world.time_frozen:
		_poll_camera_view_hotkey()
		_maintain_overview_camera()
		_maintain_coop_camera()
		_net_tick_intents_and_sync(delta)
		return
	_tick_self_service_operation(delta)
	_poll_camera_view_hotkey()
	_maintain_overview_camera()
	_maintain_coop_camera()
	_soft_push_players(delta)
	_net_tick_intents_and_sync(delta)
	## §8.1: Client never drives DayPhase／early-close／_finish_day — Host broadcasts clock.
	if SessionService.is_networked() and SessionService.is_client():
		return
	real_time += world_delta(delta)
	var prev_phase := phase
	var tick: Dictionary = DayPhase.advance(real_time)
	phase = String(tick["phase"])
	game_hours = float(tick["game_hours"])
	if bool(tick["finished"]):
		clear_guest_dusk()
		_clear_three_volley()
		if phase != prev_phase:
			bump_hud()
			host_phase_changed.emit(phase)
			_day_chrome.broadcast_day_clock_state(true)
		## Avoid end-of-day spin while a forced ops tutorial still blocks settle.
		if _tutorial != null and _tutorial.blocks_settle():
			real_time = maxf(0.0, Tuning.RESTOCK_REAL_SEC + Tuning.OPEN_REAL_SEC - 0.35)
			phase = "open"
			game_hours = maxf(game_hours, Tuning.CLOSE_HOUR - 0.05)
			return
		if _boss_world != null and _boss_world.is_active() and _boss_world.on_day_time_up():
			return
		_day_chrome.broadcast_day_clock_state(true)
		_finish_day()
		return
	_tick_three_volley(delta)
	if phase == "open":
		if bool(tick["open_sfx"]) and _sfx_phase != "open":
			_sfx_phase = "open"
			SfxBus.play("sfx_phase_open")
		if _consider_early_close():
			return
	if phase != prev_phase:
		bump_hud()
		host_phase_changed.emit(phase)
		_day_chrome.broadcast_day_clock_state(true)
	else:
		_day_chrome.maybe_broadcast_day_clock(delta)
	_world_spawn.tick_ambient(delta)


func _net_tick_intents_and_sync(delta: float) -> void:
	if not SessionService.is_networked() or not SessionService.day_started:
		_net_accum = 0.0
		_agent_xform_accum = 0.0
		return
	## §8.4: fixed net ticks first (ingest／broadcast), then render presentation.
	_net_accum += delta
	var steps := 0
	while _net_accum >= NetPresentationScript.NET_DT and steps < 3:
		_net_accum -= NetPresentationScript.NET_DT
		steps += 1
		_net_tick_once()
	if SessionService.is_server():
		_agent_xform_accum += delta
		if _agent_xform_accum >= NetPresentationScript.AGENT_DT:
			_agent_xform_accum = 0.0
			SessionService.broadcast_agent_transforms(_collect_agent_transforms())
	_net_apply_presentation(delta)


func _net_tick_once() -> void:
	if SessionService.is_client():
		_net_client_send_intents()
		_net_client_ingest_poses()
		return
	_net_host_apply_intents()
	_net_host_broadcast_players()
	_day_chrome.maybe_broadcast_skill_cds()


func _net_client_send_intents() -> void:
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		var sid := int(p.seat_id)
		if not SeatTable.seat_owned_locally(sid):
			continue
		var mv := Controls.move_vector_for(sid)
		var hotkey := -1
		if p.has_method("take_pending_skill_hotkey"):
			hotkey = int(p.call("take_pending_skill_hotkey"))
		var bag_slot := -1
		if p.has_method("take_pending_ops_bag_slot"):
			bag_slot = int(p.call("take_pending_ops_bag_slot"))
		var ult_cast := false
		if p.has_method("take_pending_ult_cast"):
			ult_cast = bool(p.call("take_pending_ult_cast"))
		var aim_confirm := false
		if p.has_method("take_pending_aim_confirm"):
			aim_confirm = bool(p.call("take_pending_aim_confirm"))
		var toss_dx := 0.0
		var toss_dy := 0.0
		var toss_charge := 1.0
		var toss_release := false
		if p.has_method("toss_intent_snapshot"):
			var toss: Dictionary = p.call("toss_intent_snapshot")
			toss_dx = float(toss.get("dx", 0.0))
			toss_dy = float(toss.get("dy", 0.0))
			toss_charge = float(toss.get("charge", 1.0))
			toss_release = bool(toss.get("release", false))
		var restock_cursor := -1
		var restock_commit := false
		var restock_abort := false
		if p.has_method("restock_intent_snapshot"):
			var rp: Dictionary = p.call("restock_intent_snapshot")
			restock_cursor = int(rp.get("cursor", -1))
			restock_commit = bool(rp.get("commit", false))
			restock_abort = bool(rp.get("abort", false))
		SessionService.send_intent(sid, {
			"mx": mv.x,
			"my": mv.y,
			"interact": p.get("_j_held") == true,
			"cancel": p.get("_cancel_held") == true,
			"dash": p.get("_k_held") == true or p.get("_rt_dash_held") == true,
			"skill": p.get("_l_held") == true,
			"bag_menu": p.get("_bag_held") == true,
			"ult": p.get("_u_held") == true,
			"hotkey": hotkey,
			"bag_slot": bag_slot,
			"ult_cast": ult_cast,
			"aim_confirm": aim_confirm,
			"toss_dx": toss_dx,
			"toss_dy": toss_dy,
			"toss_charge": toss_charge,
			"toss_release": toss_release,
			"restock_cursor": restock_cursor,
			"restock_commit": restock_commit,
			"restock_abort": restock_abort,
		})


func _net_client_ingest_poses() -> void:
	var now := Time.get_ticks_msec() * 0.001
	var xforms: Array = SessionService.peek_player_transforms()
	for row in xforms:
		if not (row is Dictionary):
			continue
		var sid2 := int(row.get("seat", -1))
		var pos := Vector2(float(row.get("px", 0.0)), float(row.get("py", 0.0)))
		var fac := Vector2(float(row.get("fx", 1.0)), float(row.get("fy", 0.0)))
		var t := float(row.get("t", now))
		if SeatTable.seat_owned_locally(sid2):
			_owned_host_pose[sid2] = {"pos": pos, "facing": fac}
		else:
			_net_pres.push_sample(NetPresentationScript.seat_key(sid2), t, pos, fac)
	var agents: Array = SessionService.peek_agent_transforms()
	for row2 in agents:
		if not (row2 is Dictionary):
			continue
		var aid := int(row2.get("id", -1))
		if aid < 0:
			continue
		var apos := Vector2(float(row2.get("px", 0.0)), float(row2.get("py", 0.0)))
		var afac := Vector2(float(row2.get("fx", 0.0)), float(row2.get("fy", 1.0)))
		var at := float(row2.get("t", now))
		_net_pres.push_sample(NetPresentationScript.agent_key(aid), at, apos, afac)


func _net_apply_presentation(delta: float) -> void:
	if not SessionService.is_client():
		return
	var render_t := Time.get_ticks_msec() * 0.001
	for p2 in _players:
		if p2 == null or not is_instance_valid(p2):
			continue
		var sid2 := int(p2.seat_id)
		if SeatTable.seat_owned_locally(sid2):
			if not _owned_host_pose.has(sid2):
				continue
			var host_row: Dictionary = _owned_host_pose[sid2]
			var hpos: Vector2 = host_row.get("pos", p2.global_position)
			var hfac: Vector2 = host_row.get("facing", p2.facing if "facing" in p2 else Vector2.RIGHT)
			var in_combat: bool = _obj_truthy(p2, "_fighting") or _obj_truthy(p2, "_fight_ko")
			p2.global_position = _net_pres.reconcile_owned(p2.global_position, hpos, delta, in_combat)
			if in_combat or p2.global_position.distance_squared_to(hpos) >= NetPresentationScript.OWNED_BLEND_PX_SQ:
				p2.facing = hfac
			continue
		var samp: Dictionary = _net_pres.sample(NetPresentationScript.seat_key(sid2), render_t)
		if not bool(samp.get("ok", false)):
			continue
		p2.global_position = samp["pos"]
		p2.facing = samp["facing"]
	## Agents: interpolate into presentation poses.
	for aid in _net_agents.keys():
		var n = _net_agents[aid]
		if n == null or not is_instance_valid(n):
			continue
		var asamp: Dictionary = _net_pres.sample(NetPresentationScript.agent_key(int(aid)), render_t)
		if not bool(asamp.get("ok", false)):
			continue
		var apos: Vector2 = asamp["pos"]
		var afac: Vector2 = asamp["facing"]
		if n.has_method("apply_net_pose"):
			n.call("apply_net_pose", apos, afac)
		elif n is Node2D:
			(n as Node2D).global_position = apos


func _net_host_apply_intents() -> void:
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		var sid3 := int(p.seat_id)
		if SeatTable.seat_owned_locally(sid3) or SeatTable.is_frozen(sid3):
			continue
		var intent: Dictionary = SessionService.take_remote_intent(sid3)
		if intent.is_empty():
			if SessionService.intent_is_stale(sid3, NetPresentationScript.INTENT_STALE_TICKS):
				p.remote_move = Vector2.ZERO
			continue
		p.remote_move = Vector2(float(intent.get("mx", 0.0)), float(intent.get("my", 0.0)))
		## Apply toss aim／charge before cancel hold edges so Host release uses Client dir.
		if p.has_method("apply_toss_intent"):
			p.call("apply_toss_intent", {
				"dx": float(intent.get("toss_dx", 0.0)),
				"dy": float(intent.get("toss_dy", 0.0)),
				"charge": float(intent.get("toss_charge", 1.0)),
				"release": intent.get("toss_release", false) == true,
			})
		if p.has_method("apply_restock_intent"):
			p.call("apply_restock_intent", {
				"cursor": int(intent.get("restock_cursor", -1)),
				"commit": intent.get("restock_commit", false) == true,
				"abort": intent.get("restock_abort", false) == true,
			})
		var ult_cast: bool = intent.get("ult_cast", false) == true
		## Clear prep before ult=false hold so we do not emit a spurious cancel.
		if ult_cast:
			p.ult_prep = false
			p.set("_u_held", false)
		if p.has_method("set_hold"):
			p.set_hold("interact", intent.get("interact", false) == true)
			p.set_hold("cancel", intent.get("cancel", false) == true)
			p.set_hold("dash", intent.get("dash", false) == true)
			p.set_hold("skill", intent.get("skill", false) == true)
			p.set_hold("bag_menu", intent.get("bag_menu", false) == true)
			if not ult_cast:
				p.set_hold("ult", intent.get("ult", false) == true)
		var hotkey := int(intent.get("hotkey", -1))
		if hotkey >= 0 and p.has_method("_try_skill_hotkey"):
			p.call("_try_skill_hotkey", hotkey)
		if intent.get("aim_confirm", false) == true and p.has_method("apply_aim_confirm_intent"):
			p.call("apply_aim_confirm_intent")
		var bag_slot := int(intent.get("bag_slot", -1))
		if bag_slot >= 0:
			use_ops_item(sid3, bag_slot)
		## Client finished ult sequence locally — Host must fire world effect／net visual.
		if ult_cast and p.has_method("_cast_ultimate"):
			p.call("_cast_ultimate")


func _net_host_broadcast_players() -> void:
	var now := Time.get_ticks_msec() * 0.001
	var out: Array = []
	for p3 in _players:
		if p3 == null or not is_instance_valid(p3):
			continue
		var fac2: Vector2 = p3.facing if "facing" in p3 else Vector2.RIGHT
		out.append({
			"seat": int(p3.seat_id),
			"px": p3.global_position.x,
			"py": p3.global_position.y,
			"fx": fac2.x,
			"fy": fac2.y,
			"t": now,
		})
	SessionService.broadcast_player_transforms(out)


func _alloc_agent_id() -> int:
	return _net.alloc_agent_id()

func _register_net_agent(node: Node, kind: String, extra: Dictionary = {}) -> void:
	_net.register_net_agent(node, kind, extra)

func _on_net_agent_tree_exiting(agent_id: int) -> void:
	_net.on_net_agent_tree_exiting(agent_id)

func _collect_agent_transforms() -> Array:
	return _net.collect_agent_transforms()

func _apply_agent_transforms(rows: Array) -> void:
	_net.apply_agent_transforms(rows)

func _on_agent_spawn_received(payload: Dictionary) -> void:
	_net.on_agent_spawn_received(payload)

func _flush_pending_agent_spawns() -> void:
	_net.flush_pending_agent_spawns()

func _apply_agent_spawn_payload(payload: Dictionary) -> void:
	_net.apply_agent_spawn_payload(payload)

func _on_agent_state_received(payload: Dictionary) -> void:
	_net.on_agent_state_received(payload)

func _flush_pending_agent_states() -> void:
	_net.flush_pending_agent_states()

func _apply_agent_state_payload(payload: Dictionary) -> void:
	_net.apply_agent_state_payload(payload)
func _obj_truthy(obj: Object, prop: String) -> bool:
	## Object.get missing → null; Godot 4 has no bool(null) constructor.
	if obj == null or not is_instance_valid(obj):
		return false
	var v = obj.get(prop)
	return v != null and v == true


func _resolve_net_fight_clear(thief: Node, caught: bool) -> void:
	if thief == null or not is_instance_valid(thief):
		return
	if thief.has_method("apply_net_fight_clear"):
		thief.call("apply_net_fight_clear", caught)
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		if p.get("target") != thief:
			continue
		if not (_obj_truthy(p, "_fighting") or _obj_truthy(p, "_net_ko_pending") or _obj_truthy(p, "_fight_ko")):
			continue
		if caught:
			if not _obj_truthy(p, "_fight_ko"):
				play_ko_banner()
			if p.has_method("_end_fight"):
				p.call("_end_fight", true)
		elif p.has_method("apply_net_fight_fail"):
			p.call("apply_net_fight_fail")
		elif p.has_method("_end_fight"):
			p.call("_end_fight", false)


func _on_flight_received(payload: Dictionary) -> void:
	_net.on_flight_received(payload)

func _flush_pending_flights() -> void:
	_net.flush_pending_flights()

func _play_net_flight(payload: Dictionary) -> void:
	_net.play_net_flight(payload)

func _on_agent_despawn_received(agent_id: int, _reason: String) -> void:
	_net.on_agent_despawn_received(agent_id, _reason)
func _spawn_customer_puppet(aid: int, thief: bool, pos: Vector2, payload: Dictionary) -> void:
	if _customers == null:
		return
	var c: CharacterBody2D = CustomerScript.new()
	_customers.add_child(c)
	c.setup(self, pos, thief)
	c.global_position = pos
	c.net_puppet = true
	c.net_agent_id = aid
	## setup marks occupy for guests but we never register_customer — clear the flag only.
	if not thief:
		c._occupy_counted = false
	var puppet_elite := bool(payload.get("elite", false))
	if puppet_elite:
		c.call("become_elite", int(payload.get("elite_lv", 1)))
	var model := String(payload.get("model", ""))
	if model != "":
		c._model_id = model
	## Host absolute shopping — overwrite local setup/elite re-roll (M2.7).
	if c.has_method("apply_net_shopping"):
		c.call("apply_net_shopping", payload.get("shopping", []))
	## Host checkout seq if already init mid-session (M2.9).
	if payload.has("checkout_seq") and c.has_method("apply_net_checkout_seq"):
		c.call(
			"apply_net_checkout_seq",
			payload.get("checkout_seq", []),
			bool(payload.get("checkout_init", false)),
		)
	_net_agents[aid] = c
	if puppet_elite:
		announce_elite_customer(c)
		## Puppets skip register_customer — still clear elite BGM on despawn.
		c.tree_exiting.connect(func() -> void: _refresh_elite_bgm(c))
	if thief:
		_add_interactable(c)
		c.tree_exiting.connect(func() -> void: _remove_interactable(c))


func _spawn_clerk_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var role := String(payload.get("role", "restock"))
	var reg: Node2D = null
	if role == "cashier" and not cashiers.is_empty():
		reg = cashiers[0]
	var clerk: CharacterBody2D = ClerkScript.new()
	_world.add_child(clerk)
	clerk.setup(self, pos, role, reg)
	clerk.net_puppet = true
	clerk.net_agent_id = aid
	_clerks.append(clerk)
	_net_agents[aid] = clerk


func _spawn_dirt_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var dtype := String(payload.get("dirt_type", Tuning.DIRT_TRASH))
	var sz := Vector2(float(payload.get("sx", Tuning.DIRT_SIZE.x)), float(payload.get("sy", Tuning.DIRT_SIZE.y)))
	var area: Area2D = DirtScript.new()
	area.setup(dtype, sz)
	area.global_position = pos
	area.net_puppet = true
	area.net_agent_id = aid
	_world.add_child(area)
	_dirts.append(area)
	_add_interactable(area)
	_net_agents[aid] = area
	area.tree_exiting.connect(func() -> void:
		_dirts.erase(area)
		_remove_interactable(area)
		_net_agents.erase(aid)
	)


func _spawn_ops_item_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var item_id := String(payload.get("item_id", ""))
	if item_id == "" or not OpsItems.is_known(item_id):
		return
	var area: Area2D = OpsItemPickupScript.new()
	area.setup(item_id)
	area.global_position = pos
	area.net_puppet = true
	area.net_agent_id = aid
	_world.add_child(area)
	_ops_items.append(area)
	_add_interactable(area)
	_net_agents[aid] = area
	area.tree_exiting.connect(func() -> void:
		_ops_items.erase(area)
		_remove_interactable(area)
		_net_agents.erase(aid)
	)


func _spawn_drop_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var sku := String(payload.get("sku", ""))
	var n := int(payload.get("n", 0))
	if sku == "" or n <= 0:
		return
	var drop: Area2D = DroppedBoxScript.new()
	drop.setup(sku, n)
	drop.global_position = pos
	drop.net_puppet = true
	drop.net_agent_id = aid
	_world.add_child(drop)
	_add_interactable(drop)
	_net_agents[aid] = drop
	drop.tree_exiting.connect(func() -> void:
		_remove_interactable(drop)
		_net_agents.erase(aid)
	)


func _spawn_shadow_clone_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var snap := {
		"skin_id": String(payload.get("skin_id", "player")),
	}
	var clone: CharacterBody2D = ShadowCloneScript.new()
	_world.add_child(clone)
	clone.setup(self, pos, snap)
	clone.net_puppet = true
	clone.net_agent_id = aid
	var role := String(payload.get("role", "restock"))
	clone.call("begin_job", role, null)
	_net_agents[aid] = clone


func _spawn_elite_guest_specialist_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var snap := {"skin_id": String(payload.get("skin_id", "player"))}
	var specialist = preload("res://scripts/elite_guest_specialist.gd").new()
	_world.add_child(specialist)
	specialist.setup_specialist(
		self,
		pos,
		snap,
		int(payload.get("owner_seat", 0)),
		int(payload.get("level", 3)),
	)
	specialist.net_puppet = true
	specialist.net_agent_id = aid
	_net_agents[aid] = specialist


func _spawn_cannon_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var cannon: Node2D = preload("res://scripts/universal_cannon.gd").new()
	cannon.host = self
	cannon.level = clampi(int(payload.get("level", 3)), 1, 3)
	cannon.owner_seat = int(payload.get("owner_seat", 0))
	cannon.net_puppet = true
	cannon.net_agent_id = aid
	_world.add_child(cannon)
	cannon.global_position = pos
	var ammo_n := int(payload.get("ammo_n", 0))
	var sku := String(payload.get("sku", ""))
	if ammo_n > 0 and cannon.has_method("apply_net_ammo"):
		cannon.call("apply_net_ammo", ammo_n, sku)
	for player in _players:
		if player != null and is_instance_valid(player) and not player.interactables.has(cannon):
			player.interactables.append(cannon)
	_net_agents[aid] = cannon


func _spawn_shelf_cannon_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var cannon: Node2D = preload("res://scripts/shelf_cannon.gd").new()
	cannon.host = self
	cannon.level = clampi(int(payload.get("level", 3)), 1, 3)
	cannon.owner_seat = int(payload.get("owner_seat", 0))
	cannon.net_puppet = true
	cannon.net_agent_id = aid
	_world.add_child(cannon)
	cannon.global_position = pos
	var ammo_n := int(payload.get("ammo_n", 0))
	var sku := String(payload.get("sku", ""))
	if ammo_n > 0:
		cannon.apply_net_ammo(ammo_n, sku)
	for player in _players:
		if player != null and is_instance_valid(player) and not player.interactables.has(cannon):
			player.interactables.append(cannon)
	_net_agents[aid] = cannon


func _spawn_kind_cannon_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var cannon: Node2D = preload("res://scripts/kind_cannon.gd").new()
	cannon.host = self
	cannon.level = clampi(int(payload.get("level", 3)), 1, 3)
	cannon.owner_seat = int(payload.get("owner_seat", 0))
	cannon.net_puppet = true
	cannon.net_agent_id = aid
	_world.add_child(cannon)
	cannon.global_position = pos
	cannon.apply_net_ammo(int(payload.get("ammo_n", 0)))
	for player in _players:
		if player != null and is_instance_valid(player) and not player.interactables.has(cannon):
			player.interactables.append(cannon)
	_net_agents[aid] = cannon


func _spawn_elite_guest_cannon_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var cannon: Node2D = preload("res://scripts/elite_guest_cannon.gd").new()
	cannon.host = self
	cannon.level = clampi(int(payload.get("level", 3)), 1, 3)
	cannon.owner_seat = int(payload.get("owner_seat", 0))
	cannon.remaining = clampf(float(payload.get("remaining", 30.0)), 0.0, 30.0)
	cannon.net_puppet = true
	cannon.net_agent_id = aid
	_world.add_child(cannon)
	cannon.global_position = pos
	_net_agents[aid] = cannon


func _spawn_calm_zone_puppet(aid: int, pos: Vector2, payload: Dictionary) -> void:
	var zone: Node2D = preload("res://scripts/calm_zone.gd").new()
	zone.host = self
	zone.level = clampi(int(payload.get("level", 3)), 1, 3)
	zone.owner_seat = int(payload.get("owner_seat", 0))
	zone.visual_only = true
	zone.net_agent_id = aid
	_world.add_child(zone)
	zone.global_position = pos
	_net_agents[aid] = zone


func _spawn_three_volley_puppet(aid: int, _pos: Vector2, payload: Dictionary) -> void:
	var effect: Node2D = ThreeVolleyVisualScript.new()
	effect.name = "ThreeVolleyEffectPuppet"
	effect.set("net_agent_id", aid)
	_world.add_child(effect)
	_track_three_volley_visual(effect)
	effect.call(
		"setup",
		Vector2(float(payload.get("ox", FLOOR_ORIGIN.x)), float(payload.get("oy", FLOOR_ORIGIN.y))),
		Vector2(float(payload.get("fw", FLOOR_SIZE.x)), float(payload.get("fh", FLOOR_SIZE.y))),
	)
	_net_agents[aid] = effect


func find_shelf(sku: String) -> Node2D:
	if sku == "":
		return null
	var list = _shelves_by_sku.get(sku)
	if list == null:
		return null
	var i := 0
	while i < list.size():
		var s: Node2D = list[i]
		if s != null and is_instance_valid(s) and shelf_has(s, sku):
			return s
		list.remove_at(i)
	if list.is_empty():
		_shelves_by_sku.erase(sku)
	return null


func shelf_has(shelf: Node2D, sku: String) -> bool:
	if shelf == null:
		return false
	if shelf.has_method("has_sku"):
		return bool(shelf.call("has_sku", sku))
	return String(shelf.get("sku")) == sku and int(shelf.get("count")) > 0


func take_from_shelf(shelf: Node2D, sku: String, customer_purchase: bool = false) -> bool:
	if shelf == null or not is_instance_valid(shelf):
		return false
	var refill := customer_purchase and _self_service_operation_left > 0.0 and int(state.stock.get(sku, 0)) > 0
	if refill and not state.consume_stock(sku, 1):
		refill = false
	if shelf.has_method("take_one"):
		if refill and not shelf.has_method("take_one_and_refill"):
			state.credit_unsold_pieces({sku: 1})
			refill = false
		var ok := bool(shelf.call("take_one_and_refill", sku, refill)) if shelf.has_method("take_one_and_refill") else bool(shelf.call("take_one", sku))
		if not ok and refill:
			state.credit_unsold_pieces({sku: 1})
		return ok
	if not shelf_has(shelf, sku):
		if refill:
			state.credit_unsold_pieces({sku: 1})
		return false
	var n := int(shelf.get("count")) if refill else int(shelf.get("count")) - 1
	shelf.set("count", n)
	if n <= 0:
		shelf.set("sku", "")
		shelf.set("count", 0)
	shelf.call("_refresh")
	return true


func can_cast_self_service_operation() -> bool:
	if _world == null or not is_instance_valid(_world) or phase != "open":
		return false
	for reg in cashiers:
		if reg != null and is_instance_valid(reg):
			return true
	return false


func cast_self_service_operation(seat: int) -> bool:
	if not (SessionService.is_server() or SessionService.is_local_transport()) or not can_cast_self_service_operation():
		return false
	_self_service_operation_left = 30.0
	_self_service_operation_owner = seat
	for reg in cashiers:
		if reg == null or not is_instance_valid(reg):
			continue
		reg.activate_self_checkout(self, 3, seat, 30.0, true)
	if _customers != null and is_instance_valid(_customers):
		for customer in _customers.get_children():
			if customer != null and is_instance_valid(customer) and customer.has_method("resume_unpaid_leave_for_self_service"):
				customer.call("resume_unpaid_leave_for_self_service")
	bump_hud()
	return true


## Ultimate: refill stocked shelves first, then randomly seed empty shelves.
## All stock and shelf mutations are Host-owned and use the normal broadcast hooks.
func can_cast_light_shelves() -> bool:
	if state == null or (phase != "restock" and phase != "open"):
		return false
	if (SessionService.is_server() or SessionService.is_local_transport()) and not state.light_quiz_passed:
		return false
	for shelf in shelves:
		if shelf == null or not is_instance_valid(shelf):
			continue
		var count := int(shelf.get("count"))
		var item_sku := String(shelf.get("sku"))
		if count > 0 and item_sku != "":
			if int(shelf.get("capacity")) > count and int(state.stock.get(item_sku, 0)) > 0:
				return true
		elif not _light_shelf_candidates(String(shelf.get("category")), state.stock).is_empty():
			return true
	return false


func cast_light_shelves() -> Dictionary:
	if not (SessionService.is_server() or SessionService.is_local_transport()):
		return {}
	if not can_cast_light_shelves():
		return {}
	var plan := _light_shelf_fill_plan()
	if plan.is_empty():
		return {}
	var required: Dictionary = {}
	for entry in plan:
		var sku := String(entry["sku"])
		required[sku] = int(required.get(sku, 0)) + int(entry["count"])
	var consumed: Dictionary = {}
	for sku_value in required.keys():
		var sku := String(sku_value)
		var amount := int(required[sku])
		if not state.consume_stock(sku, amount):
			if not consumed.is_empty():
				state.credit_unsold_pieces(consumed)
			return {}
		consumed[sku] = amount
	var filled_shelves := 0
	var filled_pieces := 0
	for entry in plan:
		var shelf: Node = entry["shelf"]
		if shelf == null or not is_instance_valid(shelf):
			state.credit_unsold_pieces({String(entry["sku"]): int(entry["count"])})
			continue
		var placed := int(shelf.call("add_items", String(entry["sku"]), int(entry["count"])))
		if placed > 0:
			filled_shelves += 1
			filled_pieces += placed
		if placed < int(entry["count"]):
			state.credit_unsold_pieces({String(entry["sku"]): int(entry["count"]) - placed})
	if filled_pieces <= 0:
		return {}
	return {"ok": true, "shelves": filled_shelves, "pieces": filled_pieces}


func _light_shelf_fill_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	if state == null:
		return plan
	var remaining: Dictionary = state.stock.duplicate(true)
	## First preserve and replenish every shelf's existing SKU.
	for shelf in shelves:
		if shelf == null or not is_instance_valid(shelf):
			continue
		var item_sku := String(shelf.get("sku"))
		var count := int(shelf.get("count"))
		if count <= 0 or item_sku == "":
			continue
		var space := maxi(0, int(shelf.get("capacity")) - count)
		var amount := mini(space, int(remaining.get(item_sku, 0)))
		if amount <= 0 or (shelf.has_method("can_accept") and not bool(shelf.call("can_accept", item_sku))):
			continue
		plan.append({"shelf": shelf, "sku": item_sku, "count": amount})
		remaining[item_sku] = int(remaining.get(item_sku, 0)) - amount
	## Then assign one random compatible, stocked SKU to each empty shelf.
	for shelf in shelves:
		if shelf == null or not is_instance_valid(shelf):
			continue
		if int(shelf.get("count")) > 0 and String(shelf.get("sku")) != "":
			continue
		var candidates := _light_shelf_candidates(String(shelf.get("category")), remaining)
		if candidates.is_empty():
			continue
		var item_sku: String = candidates.pick_random()
		var capacity := maxi(0, int(shelf.get("capacity")))
		var amount := mini(capacity, int(remaining.get(item_sku, 0)))
		if amount <= 0:
			continue
		plan.append({"shelf": shelf, "sku": item_sku, "count": amount})
		remaining[item_sku] = int(remaining.get(item_sku, 0)) - amount
	return plan


func _light_shelf_candidates(category: String, available_stock: Dictionary) -> Array[String]:
	var candidates: Array[String] = []
	if state == null:
		return candidates
	for sku in Tuning.SELLABLE_SKUS:
		if Tuning.category_of(sku) != category:
			continue
		if not state.developed.has(sku) or not state.is_for_sale(sku):
			continue
		if int(available_stock.get(sku, 0)) > 0:
			candidates.append(sku)
	return candidates


func self_service_operation_active() -> bool:
	return _self_service_operation_left > 0.0


func _tick_self_service_operation(delta: float) -> void:
	if not (SessionService.is_server() or SessionService.is_local_transport()) or _self_service_operation_left <= 0.0:
		return
	_self_service_operation_left = maxf(0.0, _self_service_operation_left - delta)
	if _self_service_operation_left <= 0.0:
		_self_service_operation_owner = -1
		bump_hud()


func _clear_self_service_operation() -> void:
	_self_service_operation_left = 0.0
	_self_service_operation_owner = -1
	for reg in cashiers:
		if reg != null and is_instance_valid(reg) and reg.has_method("clear_self_checkout"):
			reg.clear_self_checkout()


func _index_shelf_sku(sku: String, shelf: Node) -> void:
	_world_build.index_shelf_sku(sku, shelf)

func _unindex_shelf_sku(sku: String, shelf: Node) -> void:
	_world_build.unindex_shelf_sku(sku, shelf)

func _on_shelf_stock_sku_changed(shelf: Node, old_sku: String, new_sku: String) -> void:
	_world_build.on_shelf_stock_sku_changed(shelf, old_sku, new_sku)
	## Stocked → empty: tip lesson flag (S5 after checkout).
	if old_sku != "" and new_sku == "":
		if _tutorial != null and is_instance_valid(_tutorial) and _tutorial.has_method("notify_flag"):
			_tutorial.notify_flag("shelf_empty")

func _index_empty_shelf(shelf: Node) -> void:
	_world_build.index_empty_shelf(shelf)

func _unindex_empty_shelf(shelf: Node) -> void:
	_world_build.unindex_empty_shelf(shelf)

func _register_shelf(node: Node2D) -> void:
	_world_build.register_shelf(node)

func _hook_warehouse_changed() -> void:
	_net.hook_warehouse_changed()

func _on_shelf_stock_changed(shelf: Node) -> void:
	_net.on_shelf_stock_changed(shelf)

func _on_warehouse_changed() -> void:
	_net.on_warehouse_changed()

func _broadcast_shelf_stock(shelf: Node) -> void:
	_net.broadcast_shelf_stock(shelf)

func _broadcast_warehouse_stock() -> void:
	_net.broadcast_warehouse_stock()

func _dump_all_stock() -> void:
	_net.dump_all_stock()

func _on_stock_state_received(payload: Dictionary) -> void:
	_net.on_stock_state_received(payload)

func _flush_pending_stock_states() -> void:
	_net.flush_pending_stock_states()

func _apply_stock_state_payload(payload: Dictionary) -> void:
	_net.apply_stock_state_payload(payload)
func shelf_stand(shelf: Node2D) -> Vector2:
	if shelf and shelf.has_method("stand_position"):
		return shelf.stand_position()
	return shelf.global_position + Vector2(0, -58)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if pathfinder == null:
		return PackedVector2Array([to])
	if pathfinder.has_method("try_find_path"):
		var pts: PackedVector2Array = pathfinder.try_find_path(from, to)
		## Empty = budget exhausted; callers keep prior path.
		return pts
	return pathfinder.find_path(from, to)


func exit_pos() -> Vector2:
	## Stay inside the pathfinder pad north of the floor (80px) so leave
	## paths resolve to a real outdoor cell instead of snapping oddly.
	return door_pos() + Vector2(0, -70)


func door_pos() -> Vector2:
	return FLOOR_ORIGIN + Vector2(FLOOR_SIZE.x * 0.5, 8)


func inside_pos() -> Vector2:
	return door_pos() + Vector2(0, 70)


func guest_count() -> int:
	return _guest_n


func thief_count() -> int:
	return _active_thief_n


func thieves() -> Array[Node2D]:
	## Prune stale refs lazily; no fresh alloc of the full customer list.
	var i := 0
	while i < _thieves.size():
		var c: Node2D = _thieves[i]
		if c == null or not is_instance_valid(c):
			_thieves.remove_at(i)
			continue
		i += 1
	return _thieves


func dirts() -> Array[Node2D]:
	## Prune stale dirt refs lazily for cleaner AI / scans.
	var i := 0
	while i < _dirts.size():
		var d: Node2D = _dirts[i]
		if d == null or not is_instance_valid(d):
			_dirts.remove_at(i)
			continue
		i += 1
	return _dirts


func register_customer(c: Node) -> void:
	if c == null:
		return
	if c.get("is_thief"):
		if not _thieves.has(c):
			_thieves.append(c)
		_recount_active_thieves()
	else:
		_guest_n += 1
		bump_hud()
	if not c.tree_exiting.is_connected(_on_customer_exiting):
		c.tree_exiting.connect(_on_customer_exiting.bind(c))


func note_customer_occupy_changed(c: Node, occupies: bool) -> void:
	if c == null or c.get("is_thief"):
		return
	## Guests: occupy flips leave/flee; keep counter non-negative.
	if occupies:
		_guest_n += 1
	else:
		_guest_n = maxi(0, _guest_n - 1)
	bump_hud()


func note_thief_active_changed() -> void:
	_recount_active_thieves()


func _on_customer_exiting(c: Node) -> void:
	if c == null:
		return
	var was_elite: bool = c.get("is_elite") == true
	if c.get("is_thief"):
		_thieves.erase(c)
		_recount_active_thieves()
	else:
		## If still counted as occupying when freed, drop one.
		if c.has_method("occupies_store") and bool(c.call("occupies_store")):
			_guest_n = maxi(0, _guest_n - 1)
			bump_hud()
	if was_elite:
		_refresh_elite_bgm(c)


func _count_live_elites(exclude: Node = null) -> int:
	if _customers == null or not is_instance_valid(_customers):
		return 0
	var n := 0
	for child in _customers.get_children():
		if child == null or not is_instance_valid(child) or child == exclude:
			continue
		if child.get("is_elite") == true:
			n += 1
	return n


func _refresh_elite_bgm(exclude: Node = null) -> void:
	if _count_live_elites(exclude) <= 0:
		var bgm := BgmBusScript.bus()
		if bgm:
			bgm.exit_elite_if_clear()


func _recount_active_thieves() -> void:
	var n := 0
	for c in _thieves:
		if c != null and is_instance_valid(c) and c.has_method("is_active_thief") and bool(c.call("is_active_thief")):
			n += 1
	if n != _active_thief_n:
		_active_thief_n = n
		bump_hud()


func record_stolen(items: Array) -> void:
	## Host authority — client HUD gets stolen／ops via day_hud_state.
	if SessionService.is_networked() and SessionService.is_client():
		return
	var pieces := 0
	for sku in items:
		stolen_count += 1
		stolen_value += Tuning.sku_price(String(sku))
		pieces += 1
	thieves_escaped += 1
	bump_hud()
	var delta := pieces * RatingRules.N2_STOLEN_PIECE + RatingRules.N3_THIEF_ESCAPE
	apply_ops_rating(delta, _player)
	## Catch tutorial: respawn another thief immediately after escape.
	if (
		_tutorial != null
		and is_instance_valid(_tutorial)
		and _tutorial.has_method("active_lesson_id")
		and String(_tutorial.active_lesson_id()) == "tut.ops.thief"
		and bool(_tutorial.has_forced_step())
	):
		call_deferred("seed_thief_for_tutorial")


func record_caught(seat: int = 0, method: String = "any", actor_override: Node2D = null) -> void:
	## seat < 0: NPC / store catch (e.g. security guard) — day tally + rating only.
	var actor: Node2D = actor_override
	if actor == null and seat >= 0:
		actor = _seat_actor(seat)
	var FloatText = preload("res://scripts/ui/float_text.gd")
	if seat >= 0 and actor != null:
		FloatText.spawn_xp(actor, _xp_float("catch", seat))
	if SessionService.is_networked() and SessionService.is_client():
		apply_ops_rating(RatingRules.P3_CATCH, actor)
		return
	thieves_caught += 1
	if seat >= 0:
		_seat_bump(seat_caught, seat, 1)
	bump_hud()
	apply_ops_rating(RatingRules.P3_CATCH, actor)
	if seat < 0:
		return
	if _tasks != null:
		_tasks.note_metric(seat, "thief_caught", 1)
		match String(method):
			"melee":
				_tasks.note_metric(seat, "thief_caught_melee", 1)
			"dash":
				_tasks.note_metric(seat, "thief_caught_dash", 1)
	if _tutorial != null and is_instance_valid(_tutorial):
		_tutorial.note_metric("thief_caught", 1)


func apply_ops_rating(delta: int, actor: Node2D = null) -> void:
	if delta == 0:
		return
	## Client: float only — Host owns ops_rating and pushes absolute HUD (§ ratingsystem Host 店).
	var net_client := SessionService.is_networked() and SessionService.is_client()
	if not net_client:
		ops_rating += delta
		bump_hud()
		if _tasks != null:
			_tasks.sync_absolute_for_all_seats("ops_rating", ops_rating)
		_broadcast_day_hud_state()
	var body: Node2D = actor if actor != null and is_instance_valid(actor) else _player
	if body != null and is_instance_valid(body):
		var FloatText = preload("res://scripts/ui/float_text.gd")
		FloatText.spawn_rating(body, delta)


func note_angry_leave(actor: Node2D = null) -> void:
	apply_ops_rating(RatingRules.N1_ANGRY, actor)
	if SessionService.is_networked() and SessionService.is_client():
		return
	if _tasks != null:
		_tasks.sync_absolute_for_all_seats("angry_leave", angry_left)
		bump_hud()
	_broadcast_day_hud_state()


func note_wrong_deliver(actor: Node2D = null) -> void:
	apply_ops_rating(RatingRules.N4_WRONG_DELIVER, actor)
	if SessionService.is_networked() and SessionService.is_client():
		return
	var seat := _actor_seat(actor)
	if _tasks != null:
		_tasks.note_metric(seat, "wrong_deliver", 1)
		bump_hud()


func note_dash_guest(actor: Node2D = null) -> void:
	apply_ops_rating(RatingRules.N5_DASH_GUEST, actor)
	if SessionService.is_networked() and SessionService.is_client():
		return
	var seat := _actor_seat(actor)
	if _tasks != null:
		_tasks.note_metric(seat, "dash_knock_guest", 1)
		bump_hud()


func note_fight_fail(actor: Node2D = null) -> void:
	apply_ops_rating(RatingRules.N6_FIGHT_FAIL, actor)


func _on_paid(
	amount: int,
	from_elite: bool = false,
	seat: int = 0,
	actor: Node2D = null,
	perfect: bool = true,
	paid_customer: Node2D = null,
	player_checkout: bool = false,
) -> void:
	var body: Node2D = actor if actor != null and is_instance_valid(actor) else _seat_actor(seat)
	if body == null:
		body = _player
	var actor_kind := str(actor.get("kind")) if actor != null and is_instance_valid(actor) else ""
	var FloatText = preload("res://scripts/ui/float_text.gd")
	if body != null and is_instance_valid(body):
		var stagger := 0
		if amount > 0:
			FloatText.spawn_money(body, amount, stagger)
			stagger += 1
		## Furniture self-checkout: money pop only (no seat XP float).
		if actor_kind != "self_cashier":
			FloatText.spawn_xp(body, _xp_float("serve", seat), stagger)
			stagger += 1
			if from_elite:
				FloatText.spawn_xp(body, _xp_float("elite", seat), stagger)
	## Client: presentation only — Host absolute day_hud overwrites revenue／ops.
	if SessionService.is_networked() and SessionService.is_client():
		apply_ops_rating(RatingRules.checkout_delta(from_elite, perfect), body)
		return
	if player_checkout and paid_customer != null and is_instance_valid(paid_customer):
		_source_waste_after_checkout(seat, paid_customer)
	revenue += amount
	served += 1
	if actor_kind != "self_cashier":
		_seat_bump(seat_served, seat, 1)
	if from_elite:
		elite_served += 1
		if actor_kind != "self_cashier":
			_seat_bump(seat_elite, seat, 1)
	bump_hud()
	apply_ops_rating(RatingRules.checkout_delta(from_elite, perfect), body)
	## Checkout task credit: player seat only — player body or that seat's skill SCO ring.
	## Furniture self_cashier credits seat 0 metric only (no seat XP). Skip clerk／mass-pay null actor.
	if _tasks != null:
		_tasks.sync_absolute_for_all_seats("sales_revenue", revenue)
		_tasks.sync_absolute_for_all_seats("ops_rating", ops_rating)
		var kind := actor_kind
		var credit := false
		if kind == "self_cashier":
			credit = true
			seat = 0
		else:
			credit = _is_player_seat(seat) and (
				_is_player_actor(actor) or kind == "cashier"
			)
		if credit:
			_tasks.note_metric(seat, "checkout_count", 1)
			if perfect:
				_tasks.note_metric(seat, "checkout_perfect", 1)
			if _tutorial != null:
				_tutorial.note_metric("checkout_count", 1)
				if perfect:
					_tutorial.note_metric("checkout_perfect", 1)
		bump_hud()
	_broadcast_day_hud_state()
	if _player != null:
		var FxBurst = preload("res://scripts/fx_burst.gd")
		var at: Vector2 = _player.global_position + Vector2(0, -28)
		if body != null and str(body.get("kind")) in ["cashier", "self_cashier"]:
			at = body.global_position + Vector2(0, -24)
		elif _player.get("target") != null and is_instance_valid(_player.target):
			at = _player.target.global_position + Vector2(0, -24)
		elif body != null and is_instance_valid(body):
			at = body.global_position + Vector2(0, -24)
		FxBurst.spawn(self, "coin", at)


func _source_waste_after_checkout(seat: int, customer: Node2D) -> void:
	if customer == null or not is_instance_valid(customer) or not _is_player_seat(seat):
		return
	var player: Node2D = _players[seat]
	var stats = player.get("stats")
	if stats == null or not stats.has_method("loadout"):
		return
	var equipped := false
	for sk in stats.loadout():
		if sk is Dictionary and String(sk.get("id", "")) == "source_waste":
			equipped = true
			break
	if not equipped:
		return
	var nearest: Node2D = null
	var nearest_dist_sq: float = INF
	for dirt in dirts():
		if dirt == null or not is_instance_valid(dirt):
			continue
		if bool(dirt.get_meta("source_waste_claimed", false)):
			continue
		var dist_sq: float = customer.global_position.distance_squared_to(dirt.global_position)
		if dist_sq < nearest_dist_sq:
			nearest = dirt
			nearest_dist_sq = dist_sq
	if nearest != null:
		nearest.set_meta("source_waste_claimed", true)
		nearest.queue_free()


func _seat_actor(seat: int) -> Node2D:
	var by_id := _player_for_seat(seat)
	if by_id != null:
		return by_id
	if seat >= 0 and seat < _players.size():
		var p: CharacterBody2D = _players[seat]
		if p != null and is_instance_valid(p):
			return p
	if _player != null and is_instance_valid(_player):
		return _player
	return null


func _actor_seat(actor: Node2D = null) -> int:
	if actor != null and is_instance_valid(actor) and actor.get("seat_id") != null:
		return int(actor.seat_id)
	return 0


func _is_player_seat(seat: int) -> bool:
	## Clerk/NPC seats are not in `_players`; only controllable seats count for tasks.
	return seat >= 0 and seat < _players.size() and _players[seat] != null


func _is_player_actor(actor: Node2D = null) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	for p in _players:
		if p == actor:
			return true
	return false


func note_shelve(seat: int, sku: String, n: int) -> void:
	if n <= 0 or not _is_player_seat(seat):
		return
	if _tasks != null:
		_tasks.note_metric(seat, "shelve_count", n)
		_tasks.note_metric(seat, "shelve_count_sku", n, {"sku": String(sku)})
	if _tutorial != null:
		_tutorial.note_metric("shelve_count", n)
		_tutorial.note_metric("shelve_count_sku", n, {"sku": String(sku)})
	bump_hud()


func note_deliver(seat: int, mode: String, n: int = 1, perfect: bool = false) -> void:
	if n <= 0 or not _is_player_seat(seat):
		return
	if _tasks != null:
		_tasks.note_metric(seat, "deliver_count", n)
		match String(mode):
			"hand":
				_tasks.note_metric(seat, "hand_deliver_count", n)
			"toss":
				_tasks.note_metric(seat, "toss_deliver_count", n)
		if perfect:
			_tasks.note_metric(seat, "perfect_deliver_count", 1)
	if _tutorial != null:
		_tutorial.note_metric("deliver_count", n)
		match String(mode):
			"hand":
				_tutorial.note_metric("hand_deliver_count", n)
			"toss":
				_tutorial.note_metric("toss_deliver_count", n)
		if perfect:
			_tutorial.note_metric("perfect_deliver_count", 1)
	bump_hud()


func note_skill_cast(seat: int, skill_id: String, is_ult: bool) -> void:
	if not _is_player_seat(seat):
		return
	if _tasks != null:
		if is_ult:
			_tasks.note_metric(seat, "ult_cast", 1, {"skill_id": skill_id})
		else:
			_tasks.note_metric(seat, "skill_cast", 1, {"skill_id": skill_id})
	if _tutorial != null and is_instance_valid(_tutorial):
		if is_ult:
			_tutorial.note_metric("ult_cast", 1, {"skill_id": skill_id})
		else:
			_tutorial.note_metric("skill_cast", 1, {"skill_id": skill_id})
	bump_hud()


func task_hud_lines(seat: int = 0) -> Array:
	var lines: Array = []
	if _tutorial != null:
		for row in _tutorial.hud_lines():
			lines.append(row)
	if _tasks != null:
		for row in _tasks.hud_lines(seat):
			lines.append(row)
	return lines


func _setup_day_tasks() -> void:
	_tasks = TaskTrackerScript.new()
	_tasks.reset_seats(SeatTable.seat_count)
	_tasks.day_index = int(state.day_index) if state != null else 0
	var mode := String(state.task_test_mode) if state != null else "off"
	## Test packs replace the bag; do not carry leftover accumulate／in-progress rows.
	if mode == "pack" or mode == "random":
		if state != null:
			state.active_tasks_by_seat = {}
	else:
		_tasks.load_from_save(state.active_tasks_by_seat if state != null else {})
		_tasks.clear_day_tasks()
	var seats: Array = []
	for s in SeatTable.seat_ids():
		seats.append(int(s))
	if seats.is_empty():
		seats.append(0)
	var pack: Dictionary = {}
	match mode:
		"pack":
			pack = TaskCatalog.pack_by_id(String(state.task_test_pack_id))
		"random":
			var seed := int(state.task_test_seed) if state != null else 1
			pack = TaskCatalog.generate_ops(seed, 3, int(state.day_index), int(state.level))
		_:
			pack = {}
	if not pack.is_empty():
		_tasks.attach_pack(pack, seats, int(state.day_index))
	if not _tasks.changed.is_connected(_on_tasks_changed):
		_tasks.changed.connect(_on_tasks_changed)


func _on_tasks_changed() -> void:
	bump_hud()


func _bind_player_task_signals() -> void:
	for p in _players:
		if p == null:
			continue
		var seat := int(p.seat_id)
		p.skill_cast.connect(func(skill_name: String, is_ult: bool) -> void:
			var sid := _skill_id_from_cast_name(skill_name, is_ult)
			note_skill_cast(seat, sid, is_ult)
		)


func _skill_id_from_cast_name(skill_name: String, is_ult: bool) -> String:
	## Prefer matching localized name to catalog id; fall back to raw string.
	var SkillsScript = preload("res://scripts/skills.gd")
	var pool: Array = SkillsScript.ULTS if is_ult else SkillsScript.ACTIVES
	for sk in pool:
		if not (sk is Dictionary):
			continue
		var nm := String(sk.get("name", ""))
		if nm == skill_name or Loc.t(nm) == skill_name:
			return String(sk.get("id", skill_name))
		var id := String(sk.get("id", ""))
		if id != "" and Loc.t("skill.%s.name" % id) == skill_name:
			return id
	return skill_name


func skip_operate() -> void:
	if SessionService.is_networked() and not SessionService.request_end_day():
		return
	if _settled or (phase != "restock" and phase != "open"):
		return
	if _tutorial != null and _tutorial.blocks_settle():
		play_skill_banner(Loc.t("tut.gate.ops"))
		return
	if _early_open:
		_hide_early_dialog()
	_skip_xp = 400
	phase = "closed"
	game_hours = Tuning.CLOSE_HOUR
	_finish_day()


func tutorial_blocks_settle() -> bool:
	return _tutorial != null and _tutorial.blocks_settle()


func _finish_day() -> void:
	_clear_three_volley()
	if _settled:
		return
	if _tutorial != null and _tutorial.blocks_settle():
		## Keep day running until forced tutorial step is done.
		if phase == "closed":
			phase = "open"
			game_hours = maxf(game_hours, Tuning.CLOSE_HOUR - 0.05)
		return
	_clear_self_service_operation()
	## Closeout owns INTERACT／CANCEL → prep. Boss win／fail call us mid-open without DayPhase.
	phase = "closed"
	if _boss_world != null:
		_boss_world.time_frozen = false
		_boss_world.cutscene_busy = false
	## Clients wait for Host settle RPC (_on_settle_payload); do not invent a local shop settle.
	if SessionService.is_client():
		clear_ops_items_world()
		if _hud:
			if _hud.has_method("hide_boss_progress"):
				_hud.call("hide_boss_progress")
			_hud.show_closeout()
			_hud.set_closeout_panels(Loc.t("lobby.client_waiting_settle"), Loc.t("settle.tasks_host_only"))
		## Keep _settled false until settle RPC (or Host abort).
		return
	_settled = true
	clear_ops_items_world()
	_closeout_ready_msec = Time.get_ticks_msec() + CLOSEOUT_HOLD_MSEC
	if _tutorial != null and is_instance_valid(_tutorial):
		_tutorial.note_metric("day_settled", 1)
	SfxBus.play("sfx_phase_close")
	## Clones drop held boxes onto the floor before unsold collect, then vanish.
	dismiss_shadow_clones()
	dismiss_elite_guest_specialists()
	dismiss_universal_cannons()
	dismiss_shelf_cannons()
	dismiss_kind_cannons()
	dismiss_elite_guest_cannons()
	_elite_guest_cannon_reservations.clear()
	## Unsold shelf + floor (+ in-flight) pieces → warehouse boxes before save.
	_return_unsold_to_warehouse()
	var seat_n := maxi(1, SessionService.open_day_seat_n if SessionService.is_networked() else SeatTable.seat_count)
	var seat_levels: Array = []
	for s in seat_n:
		seat_levels.append(_seat_level(s))
	var xp_pack: Dictionary = DaySettle.shared_xp_for_seats(
		seat_served, seat_caught, seat_cleaned, seat_elite, seat_n, _skip_xp, seat_levels
	)
	var shared_xp: int = int(xp_pack["shared_xp"])
	## Evaluate tasks against the ending day before day_index increments in settle().
	var ending_day := int(state.day_index)
	var pending_grade := RatingRules.grade_for_ops(ops_rating)
	if _tasks != null:
		_tasks.settle_day(ending_day, {
			"sales_revenue": revenue,
			"shop_money": int(state.money) + revenue,
			"ops_rating": ops_rating,
			"day_grade": pending_grade,
			"shop_rating": maxi(0, int(state.shop_rating) + pending_grade),
			"angry_leave": angry_left,
		})
		_tasks.apply_pending_rewards(state)
		if state.has_method("sync_prologue_progress_grants"):
			state.sync_prologue_progress_grants()
		state.active_tasks_by_seat = _tasks.to_save()
	var result: Dictionary = state.settle(
		revenue, served, thieves_caught, cleaned, _skip_xp, elite_served, shared_xp, ops_rating
	)
	var grade: int = int(result.get("grade", 0))
	var guest_pack: Dictionary = DaySettle.persist_guest_xp(shared_xp, grade)
	var guest_xp_line: String = String(guest_pack["guest_xp_line"])
	var guest_ups: int = int(guest_pack["guest_ups"])
	if int(result.get("ups", 0)) > 0 or guest_ups > 0:
		SfxBus.play("sfx_ui_level_up")
	var save_err := state.save_to_disk()
	if SessionService.is_networked() and SessionService.is_server():
		var per_seat := {}
		for s in range(seat_n):
			## Offline peers skip writeback (§12.8); still list for connected clients.
			if SeatTable.is_frozen(s) and SeatTable.owner_peer_of(s) != SessionService.local_peer_id:
				## Frozen remote: only write if peer still in multiplayer peers list.
				var owner := SeatTable.owner_peer_of(s)
				var online := false
				for pid in multiplayer.get_peers():
					if int(pid) == owner:
						online = true
						break
				if not online:
					continue
			per_seat[s] = {
				"shared_xp": shared_xp,
				"kind_cannon_converted": int(seat_kind_converted[s]) if s < seat_kind_converted.size() else 0,
			}
		SessionService.send_settle_to_clients({
			"host_grade": grade,
			"per_seat": per_seat,
			"shared_xp": shared_xp,
			## M2.1：每位仍連線訪客本店同等加這筆營業額（非平分）。
			"revenue": revenue,
			"kind_cannon_total": kind_converted_total,
		})
	elif SessionService.keeps_room_after_settle():
		## Local coop：日結後進局間大廳（§12.10）。
		SessionService.begin_post_settle_lobby()
	if _hud:
		if _hud.has_method("hide_boss_progress"):
			_hud.call("hide_boss_progress")
		_hud.show_closeout()
		var loss := Loc.t("settle.loss") if bool(result["loss"]) else Loc.t("settle.no_loss")
		var head := Loc.t("demo.closeout_head")
		if _early_closed:
			head = Loc.t("demo.closeout_early")
		elif _skip_xp > 0:
			head = Loc.t("demo.closeout_test")
		var bonus := Loc.t("settle.test_bonus", [_skip_xp]) if _skip_xp > 0 else ""
		var save_line := Loc.t("settle.saved") if save_err == "" else (Loc.t("settle.save_fail_prefix") + save_err)
		var xp_line := Loc.t("settle.host_xp", [int(result["xp"]), bonus, state.level_note])
		if SeatTable.is_coop() or (SessionService.is_networked() and seat_n > 1):
			xp_line = Loc.t("settle.split_xp", [
				shared_xp, bonus, state.level_note, guest_xp_line
			])
		var grade_line := Loc.t(
			"rating.closeout_line",
			[
				int(result.get("ops_rating", ops_rating)),
				Loc.t(RatingRules.grade_label_key(grade)),
				grade,
				int(result.get("shop_before", 0)),
				int(result.get("shop_rating", 0)),
			]
		)
		var tasks_body := ""
		if _tasks != null:
			var tlines: PackedStringArray = _tasks.closeout_lines(0)
			if not tlines.is_empty():
				tasks_body = "\n".join(tlines)
		_hud.set_closeout_panels(
			DaySettle.closeout_body(
				head, loss, revenue, state.money, int(result["spent"]), served, angry_left,
				stolen_count, stolen_value, thieves_caught, thieves_escaped,
				xp_line, save_line, grade_line, kind_cannon_closeout_text(seat_n)
			),
			tasks_body
		)
	## Prep will check difficulty suggestion after closeout returns.


func _tick_guest_dusk(delta: float) -> void:
	_world_spawn._tick_guest_dusk(delta)

func _spawn_customer(ignore_cap: bool = false) -> bool:
	return _world_spawn._spawn_customer(ignore_cap)

func attach_tutorial_practice_pack(pack_id: String) -> void:
	if pack_id == "" or _tasks == null:
		return
	var pack: Dictionary = TaskCatalog.pack_by_id(pack_id)
	if pack.is_empty():
		return
	var seats: Array = []
	for s in SeatTable.seat_ids():
		seats.append(int(s))
	if seats.is_empty():
		seats.append(0)
	var day_i := int(state.day_index) if state != null else 0
	_tasks.attach_pack(pack, seats, day_i)
	bump_hud()


func announce_elite_customer(c: Node) -> void:
	_play_banner_flash(
		Loc.t("demo.elite_banner"),
		Color(1.0, 0.55, 0.95, 1.0),
		56,
		Color(0.12, 0.02, 0.12, 0.65),
		1.05,
	)
	if _player:
		_player.log_line.emit(Loc.t("demo.elite_banner"))
	var bgm_elite := BgmBusScript.bus()
	if bgm_elite:
		bgm_elite.enter_elite()
	queue_elite_zoom(c)


func queue_elite_zoom(c: Node) -> void:
	if c == null or not is_instance_valid(c):
		return
	_elite_zoom_queue.append(c)
	_try_play_elite_zoom()


func notify_camera_priority_idle() -> void:
	_try_play_elite_zoom()


func _try_play_elite_zoom() -> void:
	if _elite_zoom_busy:
		return
	if _player != null and _player.has_method("camera_priority_busy") and bool(_player.call("camera_priority_busy")):
		return
	while not _elite_zoom_queue.is_empty():
		var c = _elite_zoom_queue.pop_front()
		if c != null and is_instance_valid(c):
			_play_elite_zoom(c)
			return


func _play_elite_zoom(c: Node) -> void:
	_elite_zoom_busy = true
	if _player != null and _player.has_method("play_elite_focus"):
		await _player.call("play_elite_focus", c, Tuning.ELITE_ZOOM_SEC)
	else:
		await get_tree().create_timer(Tuning.ELITE_ZOOM_SEC).timeout
	_elite_zoom_busy = false
	_try_play_elite_zoom()


## Scenario 5: no thieves until checkout tutorial is done.
func _tutorial_blocks_thief_spawn() -> bool:
	return _world_spawn._tutorial_blocks_thief_spawn()

func seed_thief_for_tutorial() -> void:
	_world_spawn.seed_thief_for_tutorial()

func _spawn_thief(force: bool = false) -> void:
	_world_spawn._spawn_thief(force)

func _floor() -> void:
	_world_build.build_floor()

func _walls_and_door() -> void:
	_world_build.walls_and_door()

func _run_wall(a: Vector2, b: Vector2, k: int) -> void:
	_world_build.run_wall(a, b, k)

func _restock(r: Rect2, cat: String, default_sku: String = "") -> Node2D:
	return _world_build.restock(r, cat, default_sku)
func _make_shelves(cat: String, start: Vector2, count: int, start_index: int) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for i in count:
		var r := Rect2(start + Vector2(i * 168.0, 0), Vector2(140, 70))
		_obstacles.append(r)
		var node: StaticBody2D = ShelfScript.new()
		node.category = cat
		node.shelf_index = start_index + i
		_fit_body(node, r, "shelf_" + cat, 0, 2)
		node.body = node.get_node("Body")
		var lab := Label.new()
		lab.position = Vector2(-58, -18)
		UiFont.apply_label(lab, UiFont.WORLD)
		lab.add_theme_color_override("font_color", Color("fff4c2"))
		lab.add_theme_color_override("font_outline_color", Color("121212"))
		lab.add_theme_constant_override("outline_size", 5)
		node.add_child(lab)
		node.label = lab
		add_child(node)
		node._refresh()
		_register_shelf(node)
		out.append(node)
	return out


func _facing(rot: int) -> Vector2:
	return _world_build.facing(rot)

func _make_shelf(r: Rect2, cat: String, index: int, rot: int, cap: int = Tuning.SHELF_CAP) -> Node2D:
	return _world_build.make_shelf(r, cat, index, rot, cap)

func _make_cashier(r: Rect2, rot: int, index: int) -> Node2D:
	return _world_build.make_cashier(r, rot, index)
func _dirt_cell_key(p: Vector2) -> int:
	return _ops_world._dirt_cell_key(p)

func _mark_dirt_rect_cells(r: Rect2, blocked: bool) -> void:
	_ops_world._mark_dirt_rect_cells(r, blocked)

func _rebuild_dirt_block_cells() -> void:
	_ops_world._rebuild_dirt_block_cells()

func _tutorial_blocks_dirt_spawn() -> bool:
	return _ops_world._tutorial_blocks_dirt_spawn()

func seed_dirt_if_tutorial_allows() -> void:
	_ops_world.seed_dirt_if_tutorial_allows()

func _try_spawn_dirt() -> void:
	_ops_world._try_spawn_dirt()

func _blocked_rect(r: Rect2) -> bool:
	return _ops_world._blocked_rect(r)

func _spawn_dirt(r: Rect2, dtype: String) -> void:
	_ops_world._spawn_dirt(r, dtype)

func _on_dirt_gone(area: Node2D) -> void:
	_ops_world._on_dirt_gone(area)

func _try_spawn_ops_item() -> void:
	_ops_world._try_spawn_ops_item()

func _spawn_ops_item(pos: Vector2, item_id: String) -> void:
	_ops_world._spawn_ops_item(pos, item_id)

func _on_ops_item_gone(area: Node2D) -> void:
	_ops_world._on_ops_item_gone(area)

func _prune_ops_items() -> void:
	_ops_world._prune_ops_items()

func clear_ops_items_world() -> void:
	_ops_world.clear_ops_items_world()

func use_ops_item(seat: int, slot: int) -> bool:
	return _ops_world.use_ops_item(seat, slot)

func _use_comfort_bomb(_seat: int, actor: Node2D) -> void:
	_ops_world._use_comfort_bomb(_seat, actor)

func _use_clean_bomb(seat: int, actor: Node2D) -> void:
	_ops_world._use_clean_bomb(seat, actor)

func _use_villain_bomb(seat: int, actor: Node2D) -> void:
	_ops_world._use_villain_bomb(seat, actor)

func _play_ops_bomb_flash(title: String, flash_color: Color) -> void:
	_ops_world._play_ops_bomb_flash(title, flash_color)

func _add_interactable(node: Node2D) -> void:
	_ops_world._add_interactable(node)

func _remove_interactable(node: Node2D) -> void:
	_ops_world._remove_interactable(node)

func spawn_dropped_box(
	pos: Vector2,
	sku: String,
	n: int,
	toss_dir: Vector2 = Vector2.ZERO,
	toss_dist: float = -1.0,
	on_landed: Callable = Callable(),
	land_nudge: Vector2 = Vector2.ZERO,
	toss_player: CharacterBody2D = null,
) -> void:
	_toss_world.spawn_dropped_box(
		pos, sku, n, toss_dir, toss_dist, on_landed, land_nudge, toss_player
	)


func spawn_loot_scatter(
	origin: Vector2,
	piles: Array,
	min_r: float,
	max_r: float,
) -> void:
	_toss_world.spawn_loot_scatter(origin, piles, min_r, max_r)


func spawn_loot_inplace(origin: Vector2, piles: Array) -> void:
	_toss_world.spawn_loot_inplace(origin, piles)


func _spawn_box_flight(
	from: Vector2,
	to: Vector2,
	sku: String,
	n: int,
	duration: float,
	on_landed: Callable,
) -> void:
	_toss_world._spawn_box_flight(from, to, sku, n, duration, on_landed)


func _emit_net_flight(sku: String, n: int, from: Vector2, to: Vector2, duration: float) -> void:
	_net.emit_net_flight(sku, n, from, to, duration)


func _clip_player_toss_path(from: Vector2, dest: Vector2, sku: String) -> Vector2:
	return _toss_world._clip_player_toss_path(from, dest, sku)


func _clip_player_toss_path_ex(
	from: Vector2, dest: Vector2, sku: String, toss_player: CharacterBody2D = null
) -> Dictionary:
	return _toss_world._clip_player_toss_path_ex(from, dest, sku, toss_player)


func _resolve_toss_landing(
	from: Vector2,
	dest: Vector2,
	sku: String,
	n: int,
	toss_dir: Vector2,
	toss_player: CharacterBody2D = null,
	clip_shelf: Node2D = null,
	clip_floor: bool = false,
	clip_thief: Node2D = null,
) -> void:
	_toss_world._resolve_toss_landing(
		from, dest, sku, n, toss_dir, toss_player, clip_shelf, clip_floor, clip_thief
	)


func _guest_wants_sku(guest: Node2D, sku: String) -> int:
	return _toss_world._guest_wants_sku(guest, sku)


func _sniper_thief_for(from: Vector2) -> Node2D:
	return _toss_world._sniper_thief_for(from)


func _resolve_sniper_thief_landing(
	thief: Node2D,
	dest: Vector2,
	sku: String,
	n: int,
	toss_dir: Vector2,
	toss_player: CharacterBody2D = null,
) -> void:
	_toss_world._resolve_sniper_thief_landing(thief, dest, sku, n, toss_dir, toss_player)


func _sniper_guest_for(sku: String, from: Vector2) -> Node2D:
	return _toss_world._sniper_guest_for(sku, from)


func _resolve_sniper_guest_landing(
	guest: Node2D, dest: Vector2, sku: String, n: int, toss_player: CharacterBody2D = null
) -> void:
	_toss_world._resolve_sniper_guest_landing(guest, dest, sku, n, toss_player)


func _sniper_shelf_for(sku: String, from: Vector2) -> Node2D:
	return _toss_world._sniper_shelf_for(sku, from)


func _resolve_sniper_landing(
	shelf: Node2D, dest: Vector2, sku: String, n: int, toss_player: CharacterBody2D = null
) -> void:
	_toss_world._resolve_sniper_landing(shelf, dest, sku, n, toss_player)


func _place_dropped_box(dest: Vector2, sku: String, n: int) -> void:
	_toss_world._place_dropped_box(dest, sku, n)


## Full-screen KO flash used when a fight mash finishes the thief.
func play_ko_banner() -> void:
	_play_banner_flash(
		"KO",
		Color(1.0, 0.9, 0.15, 1.0),
		112,
		Color(1, 1, 1, 0.75),
		Tuning.FIGHT_KO_FLASH_SEC,
	)


## Banner when a thief walks out the door still carrying loot.
func show_stolen_banner() -> void:
	SfxBus.play("sfx_thief_escape")
	_play_banner_flash(
		Loc.t("demo.stolen_banner"),
		Color(1.0, 0.35, 0.28, 1.0),
		64,
		Color(0.05, 0.02, 0.02, 0.7),
		1.15,
	)
	if _player:
		_player.log_line.emit(Loc.t("demo.stolen_banner"))


func _play_banner_flash(
	text: String,
	text_color: Color,
	font_px: int,
	flash_color: Color,
	hold_sec: float,
) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	layer.add_child(flash)
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.apply_label(lab, UiFont.HUGE)
	lab.add_theme_font_size_override("font_size", font_px)
	lab.add_theme_color_override("font_color", text_color)
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	lab.add_theme_constant_override("outline_size", 12)
	lab.modulate.a = 0.0
	layer.add_child(lab)
	var peak_a := flash_color.a
	var tw := create_tween()
	tw.tween_property(flash, "color:a", peak_a, 0.08)
	tw.parallel().tween_property(lab, "modulate:a", 1.0, 0.1)
	tw.tween_interval(maxf(0.12, hold_sec * 0.35))
	tw.tween_property(flash, "color:a", 0.0, hold_sec * 0.55)
	tw.parallel().tween_property(lab, "modulate:a", 0.0, hold_sec * 0.55)
	tw.tween_callback(layer.queue_free)


func _make_player(skin_id: String = "player") -> CharacterBody2D:
	var p: CharacterBody2D = PlayerScript.new()
	p.set("game", self)
	p.name = "Clerk"
	p.collision_layer = 1
	p.collision_mask = 1 | 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 26)
	shape.shape = rect
	p.add_child(shape)
	const SkinCatalog = preload("res://scripts/session/skin_catalog.gd")
	var mid := SkinCatalog.normalize(skin_id)
	var body := Vox.animated(mid)
	body.name = "Body"
	p.add_child(body)
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.color = Color("f4f1ea")
	arrow.polygon = PackedVector2Array([Vector2(-6, 4), Vector2(6, 4), Vector2(0, 14)])
	p.add_child(arrow)
	p.bind_visuals(body, arrow)
	return p


func _spawn_seated_player(seat: int, stats_src, nodes: Array[Node2D], spawn: Vector2) -> CharacterBody2D:
	const SkinCatalog = preload("res://scripts/session/skin_catalog.gd")
	var skin := "player"
	if stats_src != null and stats_src.has_method("appearance_skin_id"):
		skin = String(stats_src.appearance_skin_id())
	elif stats_src != null and "skin_id" in stats_src:
		skin = String(stats_src.skin_id)
	var p := _make_player(SkinCatalog.normalize(skin))
	p.name = "Clerk" if seat == 0 else "Clerk%d" % (seat + 1)
	p.set("seat_id", seat)
	p.stats = stats_src
	_world.add_child(p)
	p.global_position = spawn
	p.interactables = nodes
	p.paid.connect(_on_paid)
	_players.append(p)
	if seat == 0:
		_player = p
	_hook_player_carry(p)
	return p


func _hook_player_carry(p: CharacterBody2D) -> void:
	if p == null or not is_instance_valid(p):
		return
	var inv = p.get("inventory")
	if inv == null or not inv.has_signal("changed"):
		return
	var sid := int(p.seat_id)
	var cb := _on_player_inventory_changed.bind(sid)
	if not inv.changed.is_connected(cb):
		inv.changed.connect(cb)


func _on_player_inventory_changed(seat_id: int) -> void:
	## Host only — client prediction is overwritten by absolute carry_state.
	if SessionService.is_networked() and SessionService.is_client():
		return
	_broadcast_seat_carry(seat_id)


func _broadcast_seat_carry(seat_id: int) -> void:
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var p := _player_for_seat(seat_id)
	if p == null:
		return
	var inv = p.get("inventory")
	if inv == null:
		return
	var items: Array = []
	for sku in inv.items:
		items.append(String(sku))
	var focus_sku := ""
	if inv.has_method("focused_sku"):
		focus_sku = String(inv.call("focused_sku"))
	SessionService.broadcast_carry_state({
		"seats": [{"seat": seat_id, "items": items, "focus": focus_sku, "focus_index": int(inv.get("focus_index"))}],
	})


func _dump_all_carry() -> void:
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var rows: Array = []
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		var inv = p.get("inventory")
		if inv == null:
			continue
		var items: Array = []
		for sku in inv.items:
			items.append(String(sku))
		var focus_sku := ""
		if inv.has_method("focused_sku"):
			focus_sku = String(inv.call("focused_sku"))
		rows.append({
			"seat": int(p.seat_id),
			"items": items,
			"focus": focus_sku,
			"focus_index": int(inv.get("focus_index")),
		})
	if rows.is_empty():
		return
	SessionService.broadcast_carry_state({"seats": rows})


func _broadcast_seat_prompt(seat_id: int) -> void:
	## Host checkout prompt chrome for one seat (M2.9).
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var p := _player_for_seat(seat_id)
	if p == null or not p.has_method("prompt_net_row"):
		return
	SessionService.broadcast_prompt_state({
		"seats": [p.call("prompt_net_row")],
	})


func _dump_all_prompt() -> void:
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var rows: Array = []
	for p in _players:
		if p == null or not is_instance_valid(p) or not p.has_method("prompt_net_row"):
			continue
		rows.append(p.call("prompt_net_row"))
	if rows.is_empty():
		return
	SessionService.broadcast_prompt_state({"seats": rows})


func _on_prompt_state_received(payload: Dictionary) -> void:
	if not SessionService.is_client():
		return
	if _world == null or not is_instance_valid(_world):
		_pending_prompt_states.append(payload.duplicate(true))
		return
	_apply_prompt_state_payload(payload)


func _flush_pending_prompt_states() -> void:
	if _pending_prompt_states.is_empty():
		return
	var queued: Array = _pending_prompt_states.duplicate(true)
	_pending_prompt_states.clear()
	for payload in queued:
		if payload is Dictionary:
			_apply_prompt_state_payload(payload)


func _broadcast_day_hud_state() -> void:
	_day_chrome.broadcast_day_hud_state()


func _dump_all_skill_cds() -> void:
	_day_chrome.dump_all_skill_cds()


func _apply_prompt_state_payload(payload: Dictionary) -> void:
	var rows = payload.get("seats", [])
	if not (rows is Array):
		return
	for row in rows:
		if not (row is Dictionary):
			continue
		var sid := int(row.get("seat", -1))
		if sid < 0:
			continue
		var p := _player_for_seat(sid)
		if p == null or not p.has_method("apply_net_checkout_prompt"):
			continue
		var raw = row.get("seq", [])
		var dirs: Array = []
		if raw is Array or raw is PackedInt32Array:
			for v in raw:
				dirs.append(int(v))
		p.call(
			"apply_net_checkout_prompt",
			bool(row.get("on", false)),
			dirs,
			int(row.get("idx", 0)),
			int(row.get("fail", -1)),
			bool(row.get("done", false)),
			float(row.get("hold", 0.0)),
		)


func _player_for_seat(seat_id: int) -> CharacterBody2D:
	for p in _players:
		if p != null and is_instance_valid(p) and int(p.seat_id) == seat_id:
			return p
	return null


func _on_carry_state_received(payload: Dictionary) -> void:
	if not SessionService.is_client():
		return
	if _world == null or not is_instance_valid(_world):
		_pending_carry_states.append(payload.duplicate(true))
		return
	_apply_carry_state_payload(payload)


func _flush_pending_carry_states() -> void:
	if _pending_carry_states.is_empty():
		return
	var queued: Array = _pending_carry_states.duplicate(true)
	_pending_carry_states.clear()
	for payload in queued:
		if payload is Dictionary:
			_apply_carry_state_payload(payload)


func _apply_carry_state_payload(payload: Dictionary) -> void:
	var rows = payload.get("seats", [])
	if not (rows is Array):
		return
	for row in rows:
		if not (row is Dictionary):
			continue
		var sid := int(row.get("seat", -1))
		if sid < 0:
			continue
		var p := _player_for_seat(sid)
		if p == null:
			continue
		var inv = p.get("inventory")
		if inv == null or not inv.has_method("apply_net_items"):
			continue
		var raw = row.get("items", [])
		var items: Array = []
		if raw is Array or raw is PackedStringArray:
			for v in raw:
				items.append(String(v))
		var focus = row.get("focus", row.get("focus_index", null))
		## Absolute Host snapshot: puppets always; owned seats soft-reconcile (skip if equal).
		inv.call("apply_net_items", items, focus)


func _solid(r: Rect2) -> void:
	_world_build.solid(r)

func _fit_body(body: StaticBody2D, r: Rect2, model_id: String, rot: int, layer: int = 1) -> void:
	_world_build.fit_body(body, r, model_id, rot, layer)

func _caption(pos: Vector2, text: String) -> Label:
	return _world_build.caption(pos, text)
func deploy_universal_cannon(at: Vector2, level: int, seat: int) -> Node2D:
	return _skill_deploy.deploy_universal_cannon(at, level, seat)

func deploy_shelf_cannon(at: Vector2, level: int, seat: int) -> Node2D:
	return _skill_deploy.deploy_shelf_cannon(at, level, seat)

func deploy_kind_cannon(at: Vector2, level: int, seat: int) -> Node2D:
	return _skill_deploy.deploy_kind_cannon(at, level, seat)

func deploy_elite_guest_cannon(at: Vector2, level: int, seat: int) -> Node2D:
	return _skill_deploy.deploy_elite_guest_cannon(at, level, seat)

func deploy_elite_guest_specialist(at: Vector2, level: int, seat: int) -> Node2D:
	return _skill_deploy.deploy_elite_guest_specialist(at, level, seat)

func deliver_elite_guest_specialist_item(guest: Node, sku: String, seat: int) -> bool:
	return _skill_deploy.deliver_elite_guest_specialist_item(guest, sku, seat)

func elite_guest_cannon_reserved_count(guest: Node, sku: String) -> int:
	return _skill_deploy.elite_guest_cannon_reserved_count(guest, sku)

func reserve_elite_guest_cannon_need(guest: Node, sku: String) -> bool:
	return _skill_deploy.reserve_elite_guest_cannon_need(guest, sku)

func release_elite_guest_cannon_need(target_id: int, sku: String) -> void:
	_skill_deploy.release_elite_guest_cannon_need(target_id, sku)

func resolve_elite_guest_cannon_delivery(
	guest: Node, sku: String, seat: int, target_id: int
) -> bool:
	return _skill_deploy.resolve_elite_guest_cannon_delivery(guest, sku, seat, target_id)

func deploy_calm_zone(at: Vector2, level: int, seat: int) -> Node2D:
	return _skill_deploy.deploy_calm_zone(at, level, seat)

func _remove_cannon_interactable(cannon: Node2D) -> void:
	_skill_deploy._remove_cannon_interactable(cannon)

func dismiss_universal_cannons() -> void:
	_skill_deploy.dismiss_universal_cannons()

func dismiss_shelf_cannons() -> void:
	_skill_deploy.dismiss_shelf_cannons()

func dismiss_kind_cannons() -> void:
	_skill_deploy.dismiss_kind_cannons()

func dismiss_elite_guest_cannons() -> void:
	_skill_deploy.dismiss_elite_guest_cannons()

func _resolve_net_kind_conversion(thief: Node) -> void:
	_skill_deploy._resolve_net_kind_conversion(thief)

func convert_thief_to_guest(thief: Node2D, seat: int) -> bool:
	return _skill_deploy.convert_thief_to_guest(thief, seat)

func cannon_hit_thief(thief: Node2D, seat: int, direction: Vector2) -> void:
	_skill_deploy.cannon_hit_thief(thief, seat, direction)
