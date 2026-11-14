extends "res://scripts/host/game_host.gd"
## Living v1 line (from Alpha v0.1): Demo v0.6 shop loop with voxel sprites.
## Extends GameHost — stable surface for player/customer/HUD/Session.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const StateScript = preload("res://scripts/game_state.gd")
const PlayerScript = preload("res://scripts/player.gd")
const RestockScript = preload("res://scripts/restock_point.gd")
const ShelfScript = preload("res://scripts/shelf.gd")
const Fundraise = preload("res://scripts/fundraise.gd")
const DarkSide = preload("res://scripts/dark_side.gd")
const ShadowCloneCast = preload("res://scripts/shadow_clone_cast.gd")
const ShadowCloneScript = preload("res://scripts/shadow_clone.gd")
const DirtScript = preload("res://scripts/dirt.gd")
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
const TaskCatalog = preload("res://scripts/session/task_catalog.gd")
const TaskTrackerScript = preload("res://scripts/session/task_tracker.gd")
const ThreeVolleyVisualScript = preload("res://scripts/three_volley_visual.gd")

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
var _combo = null
var _tasks = null
var _settled: bool = false
## After closeout, block confirm/cancel return until this game time (msec).
var _closeout_ready_msec: int = 0
const CLOSEOUT_HOLD_MSEC := 2000
var _prep: CanvasLayer
var _pause: CanvasLayer
var _world: Node2D
var cashiers: Array[Node2D] = []
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
var _clerks: Array[Node2D] = []
## M2.2: Host agent_id → node; client puppets share the same map.
var _net_agents: Dictionary = {}
var _next_agent_id: int = 1
var _agent_xform_tick: int = 0
const AGENT_XFORM_EVERY := 2
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


func _ready() -> void:
	add_to_group("game")
	state = StateScript.new()
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
	if not SessionService.agent_spawn_received.is_connected(_on_agent_spawn_received):
		SessionService.agent_spawn_received.connect(_on_agent_spawn_received)
	if not SessionService.agent_despawn_received.is_connected(_on_agent_despawn_received):
		SessionService.agent_despawn_received.connect(_on_agent_despawn_received)
	if not SessionService.agent_state_received.is_connected(_on_agent_state_received):
		SessionService.agent_state_received.connect(_on_agent_state_received)
	if not SessionService.flight_received.is_connected(_on_flight_received):
		SessionService.flight_received.connect(_on_flight_received)
	if not SessionService.stock_state_received.is_connected(_on_stock_state_received):
		SessionService.stock_state_received.connect(_on_stock_state_received)
	if not SessionService.carry_state_received.is_connected(_on_carry_state_received):
		SessionService.carry_state_received.connect(_on_carry_state_received)
	if not SessionService.prompt_state_received.is_connected(_on_prompt_state_received):
		SessionService.prompt_state_received.connect(_on_prompt_state_received)
	_hook_warehouse_changed()
	_pause = PauseScene.instantiate()
	add_child(_pause)
	_pause.setup(self)
	_pause.end_day_requested.connect(_on_pause_end_day)


func _begin_day() -> void:
	if _prep:
		_prep.set_process_unhandled_input(false)
	if _pause and _pause.has_method("close_menu"):
		_pause.close_menu()
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
	cleaned = 0
	var sn := maxi(1, SeatTable.seat_count)
	seat_cleaned = []
	seat_served = []
	seat_caught = []
	seat_elite = []
	for _i in sn:
		seat_cleaned.append(0)
		seat_served.append(0)
		seat_caught.append(0)
		seat_elite.append(0)
	_settled = false
	_closeout_ready_msec = 0
	real_time = 0.0
	game_hours = Tuning.GAME_START_HOUR
	hud_rev = 0
	phase = "restock"
	var ComboState = preload("res://scripts/session/combo_state.gd")
	_combo = ComboState.new()
	_combo.reset(SeatTable.seat_count)
	_setup_day_tasks()
	var il := get_node_or_null("/root/InteractLock")
	if il != null and il.has_method("clear"):
		il.clear()
	_sfx_phase = "restock"
	SfxBus.play("sfx_phase_restock")
	_spawn_in = 2.0
	clear_guest_dusk()
	_clear_three_volley()
	_dirt_spawn_in = dirt_spawn_interval()
	_thief_spawn_in = state.thief_spawn_first()
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
		if seat == 1 and SeatTable.guest_stats == null:
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
	## Camera follows local owned seats; attach to first local player (fallback seat0).
	var cam_host: CharacterBody2D = _player
	for p in _players:
		if p != null and SeatTable.seat_owned_locally(int(p.seat_id)):
			cam_host = p
			break
	var cam := Camera2D.new()
	cam.zoom = Vector2(Tuning.CAMERA_ZOOM, Tuning.CAMERA_ZOOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.5
	if cam_host:
		cam_host.add_child(cam)
		cam.make_current()
	for p in _players:
		if p != null:
			p.camera = cam
	if not PlatformServices.camera_view_changed.is_connected(_on_camera_view_changed):
		PlatformServices.camera_view_changed.connect(_on_camera_view_changed)
	apply_camera_view()
	_hud = preload("res://scenes/hud.tscn").instantiate()
	add_child(_hud)
	## setup binds every seat in `_players` (right panes + cast/log).
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
	if SessionService.is_server() or SessionService.is_local_transport():
		_spawn_clerks()
		for i in Tuning.dirt_start(_play_easy()):
			_try_spawn_dirt()
		## Align client shelf／warehouse／carry／prompt presentation after world exists (M2.4／M2.6／M2.9).
		if SessionService.is_networked() and SessionService.is_server():
			_dump_all_stock()
			_dump_all_carry()
			_dump_all_prompt()
	else:
		## Apply spawn／flight／state RPCs that raced ahead of world build (M2.2～M2.9).
		_flush_pending_agent_spawns()
		_flush_pending_flights()
		_flush_pending_agent_states()
		_flush_pending_stock_states()
		_flush_pending_carry_states()
		_flush_pending_prompt_states()


func _local_touch_player() -> CharacterBody2D:
	for p in _players:
		if p != null and is_instance_valid(p) and SeatTable.seat_owned_locally(int(p.seat_id)):
			return p
	return _player


func _clear_world() -> void:
	_clear_three_volley()
	var kill: Array[Node] = []
	for c in get_children():
		if c == _prep or c == _pause:
			continue
		kill.append(c)
	for c in kill:
		c.queue_free()
	_world = null
	_hud = null
	shelves.clear()
	_shelves_by_sku.clear()
	_empty_by_cat.clear()
	_shelves_by_net_id.clear()
	_next_net_shelf_id = 0
	_dirt_block_cells.clear()
	_thieves.clear()
	_guest_n = 0
	_active_thief_n = 0
	cashiers.clear()
	_dirts.clear()
	_clerks.clear()
	_net_agents.clear()
	_next_agent_id = 1
	_agent_xform_tick = 0
	_pending_agent_spawns.clear()
	_pending_flights.clear()
	_pending_agent_states.clear()
	_pending_stock_states.clear()
	_pending_carry_states.clear()
	_pending_prompt_states.clear()
	_obstacles.clear()
	cashier = null
	_player = null
	_players.clear()
	_customers = null
	_early_open = false
	_early_latched = false
	_early_layer = null
	_early_yes = null
	_early_no = null


func _build_furniture(nodes: Array[Node2D]) -> void:
	var shelf_i := 1
	var reg_i := 0
	for it in state.placed:
		var cell := StateScript.CELL
		var r := Rect2(FLOOR_ORIGIN + Vector2(int(it["x"]), int(it["y"])) * cell, Vector2(int(it["w"]), int(it["h"])) * cell)
		var t := String(it["type"])
		var rot := int(it["rot"])
		if t.begins_with("restock"):
			var cat := Tuning.CAT_DRY
			if t.ends_with("frozen"):
				cat = Tuning.CAT_FROZEN
			elif t.ends_with("ice"):
				cat = Tuning.CAT_ICE
			nodes.append(_restock(r, cat, String(it.get("default_sku", ""))))
		elif t.begins_with("shelf"):
			var cat := Tuning.CAT_DRY
			if t.contains("frozen"):
				cat = Tuning.CAT_FROZEN
			elif t.contains("ice"):
				cat = Tuning.CAT_ICE
			nodes.append(_make_shelf(r, cat, shelf_i, rot, state.shelf_capacity(t)))
			shelf_i += 1
		elif t == "cashier":
			var node := _make_cashier(r, rot, reg_i)
			nodes.append(node)
			reg_i += 1
	if not cashiers.is_empty():
		cashier = cashiers[0]


func _spawn_clerks() -> void:
	var i := 0
	for c in state.clerks:
		var clerk: CharacterBody2D = ClerkScript.new()
		var reg: Node2D = null
		if String(c["role"]) == "cashier" and not cashiers.is_empty():
			reg = cashiers[mini(int(c["register"]), cashiers.size() - 1)]
		_world.add_child(clerk)
		clerk.setup(self, FLOOR_ORIGIN + Vector2(80 + i * 36, FLOOR_SIZE.y - 120), String(c["role"]), reg)
		_clerks.append(clerk)
		_register_net_agent(clerk, "clerk", {
			"role": String(c["role"]),
		})
		i += 1


func note_clean(seat: int = 0) -> void:
	cleaned += 1
	_seat_bump(seat_cleaned, seat, 1)
	var FloatText = preload("res://scripts/ui/float_text.gd")
	var actor := _seat_actor(seat)
	if actor != null:
		FloatText.spawn_xp(actor, StateScript.XP_CLEAN)
	apply_ops_rating(RatingRules.P4_CLEAN, actor)
	if _tasks != null:
		_tasks.note_metric(seat, "clean_count", 1)
		bump_hud()


func _seat_bump(arr: Array, seat: int, n: int) -> void:
	while arr.size() <= seat:
		arr.append(0)
	arr[seat] = int(arr[seat]) + n


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
	return _player != null and _player.buff_left("yes_my_lord") > 0.05


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


func cast_fundraise(level: int) -> void:
	if _customers == null:
		return
	var picked: Array = Fundraise.choose(_customers.get_children(), level)
	var total := 0
	for c in picked:
		var amount := int(c.call("payout_total")) if c.has_method("payout_total") else int(c.call("cart_total"))
		total += amount
		_on_paid(amount, c.get("is_elite") == true, 0, null, false)
		c.finish_paid()
	release_player_checkout()
	if _player:
		_player.log_line.emit(Loc.t("demo.fundraise", [picked.size(), total]))


## 割韭菜: cash up to `max_n` QUEUE/PAYING on one register (queue order). Returns how many paid.
func cast_harvest_chives(reg: Node, max_n: int) -> int:
	if reg == null or not is_instance_valid(reg) or max_n <= 0:
		return 0
	if str(reg.get("kind")) != "cashier":
		return 0
	var q: Array = reg.get("queue") if reg.get("queue") != null else []
	var picked: Array = Fundraise.choose_from_register_queue(q, max_n)
	if picked.is_empty():
		return 0
	var total := 0
	for c in picked:
		if c == null or not is_instance_valid(c):
			continue
		var amount := int(c.call("payout_total")) if c.has_method("payout_total") else int(c.call("cart_total"))
		total += amount
		_on_paid(amount, c.get("is_elite") == true, 0, null, false)
		c.finish_paid()
	release_player_checkout()
	var n := picked.size()
	_play_banner_flash(
		Loc.t("log.demo.chives", [n]),
		Color(0.95, 0.92, 0.35, 1.0),
		56,
		Color(0.08, 0.12, 0.04, 0.55),
		0.85,
	)
	if _player:
		_player.log_line.emit(Loc.t("log.demo.chives_cash", [n, total]))
	return n


## Short skill feedback banner (攝石人 etc.).
func play_skill_banner(text: String) -> void:
	_play_banner_flash(
		text,
		Color(0.85, 0.95, 1.0, 1.0),
		52,
		Color(0.04, 0.08, 0.14, 0.5),
		0.8,
	)


## Instant summon at door; ignore guest_cap. Returns how many guests spawned.
func cast_summon_guest(n: int) -> int:
	if phase != "open" or n <= 0:
		return 0
	var spawned := 0
	for _i in n:
		if state.sellable().is_empty():
			break
		if _spawn_customer(true):
			spawned += 1
		else:
			break
	return spawned


func cast_guest_dusk() -> bool:
	## 諸客的黃昏: 30 real seconds, up to 15 successful guest entries (ignore cap).
	if phase != "open":
		clear_guest_dusk()
		return false
	_guest_dusk_left = Skills.GUEST_DUSK_DURATION
	_guest_dusk_remain = Skills.GUEST_DUSK_COUNT
	_guest_dusk_in = 0.0
	return true


func clear_guest_dusk() -> void:
	_guest_dusk_left = 0.0
	_guest_dusk_remain = 0
	_guest_dusk_in = 0.0


func cast_close_gate() -> void:
	## 落閘放狗：有貨清 shopping 排隊；空車離店；小偷掉贓離店（不計逃走）。
	if _customers == null:
		return
	var queued := 0
	var left := 0
	var thieves := 0
	for c in _customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## FloatText / other non-customer siblings: Object.get → null → bool()/int() crash.
		if not c.has_method("occupies_store"):
			continue
		if c.is_thief:
			var st: int = c.state
			if st == CustomerScript.State.FLEE:
				continue
			if c.has_method("drop_loot_and_leave"):
				c.call("drop_loot_and_leave")
			thieves += 1
			continue
		if not c.has_method("apply_close_gate"):
			continue
		var result := String(c.call("apply_close_gate"))
		if result == "leave":
			left += 1
		elif result == "queue":
			queued += 1
	release_player_checkout()
	if _player:
		_player.log_line.emit(Loc.t("demo.close_gate", [queued, left, thieves]))


func cast_three_volley() -> void:
	## Host resolves shopping and thief outcomes; clients only receive the volley visual.
	if SessionService.is_client() or _customers == null or _world == null:
		return
	var effect: Node2D = ThreeVolleyVisualScript.new()
	effect.name = "ThreeVolleyEffect"
	_world.add_child(effect)
	effect.call("setup", FLOOR_ORIGIN, FLOOR_SIZE)
	_track_three_volley_visual(effect)
	_register_net_agent(effect, "three_volley", {
		"ox": FLOOR_ORIGIN.x,
		"oy": FLOOR_ORIGIN.y,
		"fw": FLOOR_SIZE.x,
		"fh": FLOOR_SIZE.y,
	})
	var hit_thieves: Array[int] = []
	_resolve_three_volley_wave(hit_thieves)
	_three_volley_casts.append({
		"until_next": 2.0,
		"waves_left": 2,
		"hit_thieves": hit_thieves,
		"effect": effect,
	})


func _track_three_volley_visual(effect: Node2D) -> void:
	_three_volley_visuals.append(effect)
	effect.tree_exiting.connect(_on_three_volley_visual_exiting.bind(effect))


func _on_three_volley_visual_exiting(effect: Node2D) -> void:
	_three_volley_visuals.erase(effect)


func _clear_three_volley() -> void:
	_three_volley_casts.clear()
	for effect in _three_volley_visuals.duplicate():
		if effect != null and is_instance_valid(effect):
			effect.queue_free()
	_three_volley_visuals.clear()


func _tick_three_volley(delta: float) -> void:
	if _three_volley_casts.is_empty():
		return
	for cast_i in range(_three_volley_casts.size() - 1, -1, -1):
		var cast: Dictionary = _three_volley_casts[cast_i]
		var until_next := float(cast.get("until_next", 0.0)) - delta
		var waves_left := int(cast.get("waves_left", 0))
		var hit_thieves: Array[int] = []
		var hit_thieves_v = cast.get("hit_thieves", [])
		if hit_thieves_v is Array:
			for thief_id_v in hit_thieves_v:
				hit_thieves.append(int(thief_id_v))
		while until_next <= 0.0 and waves_left > 0:
			_resolve_three_volley_wave(hit_thieves)
			waves_left -= 1
			until_next += 2.0
		if waves_left <= 0:
			_three_volley_casts.remove_at(cast_i)
		else:
			cast["until_next"] = until_next
			cast["waves_left"] = waves_left
			cast["hit_thieves"] = hit_thieves
			_three_volley_casts[cast_i] = cast


func _resolve_three_volley_wave(hit_thieves: Array[int]) -> void:
	if _customers == null or not is_instance_valid(_customers):
		return
	for target in _customers.get_children():
		if target == null or not is_instance_valid(target):
			continue
		if target.has_method("is_active_thief") and bool(target.call("is_active_thief")):
			var thief_id := int(target.get_instance_id())
			if hit_thieves.has(thief_id):
				continue
			hit_thieves.append(thief_id)
			if target.has_method("drop_loot_and_leave"):
				target.call("drop_loot_and_leave")
			continue
		if not target.has_method("can_receive_delivery") or not bool(target.call("can_receive_delivery")):
			continue
		if target.get("temp_clerk") == true:
			continue
		var shopping_v = target.get("shopping")
		if not (shopping_v is Array) or shopping_v.is_empty():
			continue
		if target.has_method("accept_must_deliver"):
			target.call("accept_must_deliver", [String(shopping_v[0])])


func sellable() -> Array[String]:
	return state.sellable()


func customer_list_bounds() -> Vector2i:
	var hi := Tuning.list_hi(state.customer_list_max(), _play_easy())
	var lo := Tuning.list_lo(state.customer_list_min(), hi)
	return Vector2i(lo, hi)


func set_play_difficulty(id: String) -> void:
	play_difficulty = "easy" if id == "easy" else "normal"


func play_is_easy() -> bool:
	return _play_easy()


func dissat_gain_mult() -> float:
	return Tuning.EASY_DISSAT_MULT if _play_easy() else 1.0


func dirt_spawn_interval() -> float:
	return Tuning.dirt_interval(state.dirt_spawn_sec(), _play_easy())


func thief_appear_rate() -> float:
	return Tuning.thief_rate(state.thief_spawn_rate(), _play_easy())


func _play_easy() -> bool:
	return ProductVersion.test_tools_enabled() and play_difficulty == "easy"


func queue_dissat_blocked() -> bool:
	return state.has_flag("no_queue_dissat")


func soothe_all(keep: float) -> void:
	if _customers == null:
		return
	for c in _customers.get_children():
		if c.has_method("apply_soothe"):
			c.call("apply_soothe", keep)


func cast_dark_side(level: int) -> void:
	if _customers == null:
		return
	var need := DarkSide.draft_count(level)
	var locked = _checkout_locked_guest()
	var pool: Array = []
	for c in _customers.get_children():
		if DarkSide.eligible(c, locked):
			pool.append(c)
	pool.shuffle()
	var drafted: Array = []
	for i in mini(need, pool.size()):
		drafted.append(pool[i])
	var rolls: Array = []
	for c in drafted:
		if DarkSide.roll_cashier():
			rolls.append(c)
	var empties: Array = DarkSide.open_registers(
		cashiers,
		_hired_cashier_registers(),
		_temp_cashier_registers(),
		_dark_side_player_pos(),
		_player_lock_register(),
	)
	var jobs: Dictionary = DarkSide.plan(drafted, rolls, empties)
	for c in drafted:
		var row: Dictionary = jobs[c]
		var reg = row.get("register", null)
		c.call("begin_temp_clerk", String(row.get("role", "restock")), reg)
	if _player and _player.has_signal("log_line"):
		_player.log_line.emit(Loc.t("log.demo.dark_side", [drafted.size()]))


func cast_shadow_clone(level: int) -> void:
	dismiss_shadow_clones()
	var need := ShadowCloneCast.clone_count(level)
	var snap := {}
	if _player != null and _player.has_method("clone_snapshot"):
		snap = _player.call("clone_snapshot")
	var facing := Vector2.RIGHT
	if _player != null:
		facing = Vector2(_player.get("facing"))
	var origin := _dark_side_player_pos()
	var spots: Array = ShadowCloneCast.spawn_positions(
		origin, facing, need, _obstacles, _clone_spawn_people()
	)
	var drafted: Array = []
	for i in need:
		var clone: CharacterBody2D = ShadowCloneScript.new()
		if _world != null:
			_world.add_child(clone)
		else:
			add_child(clone)
		var at: Vector2 = spots[i] if i < spots.size() else origin
		clone.setup(self, at, snap)
		drafted.append(clone)
	var rolls: Array = []
	for c in drafted:
		if DarkSide.roll_cashier():
			rolls.append(c)
	var empties: Array = DarkSide.open_registers(
		cashiers,
		_hired_cashier_registers(),
		_temp_cashier_registers(),
		origin,
		_player_lock_register(),
	)
	var jobs: Dictionary = DarkSide.plan(drafted, rolls, empties)
	for c in drafted:
		var row: Dictionary = jobs[c]
		var role := String(row.get("role", "restock"))
		c.call("begin_job", role, row.get("register", null))
		var skin := String(c.get("_model_id")) if c.get("_model_id") != null else "player"
		_register_net_agent(c, "shadow_clone", {
			"role": role,
			"skin_id": skin,
		})
	if _player and _player.has_signal("log_line"):
		_player.log_line.emit(Loc.t("log.demo.shadow_clone", [drafted.size()]))


func dismiss_shadow_clones() -> void:
	for c in shadow_clones():
		if c != null and is_instance_valid(c) and c.has_method("vanish"):
			c.call("vanish")


func shadow_clones() -> Array:
	var out: Array = []
	if _world == null:
		return out
	for c in _world.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.has_method("is_shadow_clone_unit") or not bool(c.call("is_shadow_clone_unit")):
			continue
		## Truthiness: Object.get missing → null; bool(null) crashes in Godot 4.
		if c.get("_vanishing"):
			continue
		out.append(c)
	return out


func _clone_spawn_people() -> Array:
	var people: Array = []
	if _player != null and is_instance_valid(_player):
		people.append(_player.global_position)
	if _world != null:
		for c in _world.get_children():
			if c == null or not is_instance_valid(c):
				continue
			if c is CharacterBody2D:
				people.append(c.global_position)
	if _customers != null:
		for c in _customers.get_children():
			if c == null or not is_instance_valid(c):
				continue
			people.append(c.global_position)
	return people


func restock_holds(except: Node) -> Dictionary:
	var sku := {}
	var shelf := {}
	if _world != null:
		for c in _world.get_children():
			if c == null or c == except or not is_instance_valid(c):
				continue
			## str() — String(null) throws in Godot 4.7 and aborts the whole scan,
			## so hired clerks never finish _find_job.
			if str(c.get("role")) != "restock":
				continue
			_note_restock_hold(sku, shelf, c.get("_plan_sku"), c.get("_box_sku"), c.get("_shelf"))
	if _customers != null:
		for c in _customers.get_children():
			if c == null or c == except or not is_instance_valid(c):
				continue
			if not c.get("temp_clerk") or str(c.get("temp_role")) != "restock":
				continue
			_note_restock_hold(sku, shelf, c.get("_temp_plan_sku"), c.get("_temp_box_sku"), c.get("_temp_shelf"))
	return {"sku": sku, "shelf": shelf}


func _note_restock_hold(sku: Dictionary, shelf: Dictionary, planned, carried, target) -> void:
	var plan_s := str(planned) if planned != null else ""
	if plan_s != "":
		sku[plan_s] = true
	var carry_s := str(carried) if carried != null else ""
	if carry_s != "":
		sku[carry_s] = true
	if target != null:
		shelf[target] = true


func _hired_cashier_registers() -> Array:
	var out: Array = []
	if _world == null:
		return out
	for c in _world.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if str(c.get("role")) != "cashier":
			continue
		var reg = c.get("register")
		if reg != null:
			out.append(reg)
	return out


func _temp_cashier_registers() -> Array:
	var out: Array = []
	if _customers == null:
		return out
	for c in _customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.get("temp_clerk") or str(c.get("temp_role")) != "cashier":
			continue
		var reg = c.get("temp_register")
		if reg != null:
			out.append(reg)
	return out


func _dark_side_player_pos() -> Vector2:
	if _player == null:
		return Vector2(1.0e8, 1.0e8)
	return _player.global_position


func _player_lock_register():
	## Any seat holding a cashier under command_lock (A4).
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		if not p.get("command_lock"):
			continue
		var target = p.get("target")
		if target != null and str(target.get("kind")) == "cashier":
			return target
	return null


func _checkout_locked_guest():
	var reg = _player_lock_register()
	if reg == null or not reg.has_method("ready_customer"):
		return null
	return reg.call("ready_customer")


func pick_register(cust: Node) -> Node2D:
	if cashiers.is_empty():
		return null
	var best_n := 999
	for c in cashiers:
		best_n = mini(best_n, int(c.queue.size()))
	var tied: Array[Node2D] = []
	for c in cashiers:
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
	var out: Dictionary = {}
	_add_pieces(out, _collect_shelf_floor_pieces())
	_add_pieces(out, _collect_player_carry_pieces())
	_add_pieces(out, _collect_clerk_held_pieces())
	_add_pieces(out, _collect_unpaid_checkout_pieces())
	return out


func _add_pieces(dst: Dictionary, src: Dictionary) -> void:
	for sku_v in src.keys():
		var n := int(src[sku_v])
		if n <= 0:
			continue
		var sku := String(sku_v)
		dst[sku] = int(dst.get(sku, 0)) + n


func _collect_shelf_floor_pieces() -> Dictionary:
	var out: Dictionary = {}
	for s in shelves:
		if s == null or not is_instance_valid(s):
			continue
		## str() — String(null) throws in Godot 4 when Object.get misses.
		var sku := str(s.get("sku"))
		var n_v = s.get("count")
		var n := int(n_v) if n_v != null else 0
		if sku == "" or n <= 0:
			continue
		out[sku] = int(out.get(sku, 0)) + n
	if _world == null:
		return out
	for c in _world.get_children():
		if c == null or not is_instance_valid(c) or c.is_queued_for_deletion():
			continue
		var kind := str(c.get("kind"))
		if kind in ["universal_cannon", "shelf_cannon"]:
			for item in c.ammo:
				out[item] = int(out.get(item, 0)) + 1
			continue
		## Floor / Labels / Customers / FloatText lack kind — already using str() above.
		if kind != "drop" and kind != "drop_flight":
			continue
		var sku := str(c.get("sku"))
		var n_v = c.get("count")
		var n := int(n_v) if n_v != null else 0
		if sku == "" or n <= 0:
			continue
		out[sku] = int(out.get(sku, 0)) + n
	return out


func _collect_player_carry_pieces() -> Dictionary:
	var out: Dictionary = {}
	var seats: Array = _players.duplicate()
	if seats.is_empty() and is_instance_valid(_player):
		seats.append(_player)
	for player in seats:
		if not is_instance_valid(player):
			continue
		for sku_v in player.inventory.items:
			var sku := str(sku_v)
			if sku != "":
				out[sku] = int(out.get(sku, 0)) + 1
	return out

func _collect_clerk_held_pieces() -> Dictionary:
	var out: Dictionary = {}
	if _world != null:
		for c in _world.get_children():
			if c == null or not is_instance_valid(c):
				continue
			if str(c.get("role")) != "restock":
				continue
			var sku := str(c.get("_box_sku"))
			var n := int(c.get("_box_n"))
			if sku == "" or n <= 0:
				continue
			out[sku] = int(out.get(sku, 0)) + n
	if _customers == null:
		return out
	for c in _customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.get("temp_clerk") or str(c.get("temp_role")) != "restock":
			continue
		var held := str(c.get("_temp_box_sku"))
		var pieces := int(c.get("_temp_box_n"))
		if held == "" or pieces <= 0:
			continue
		out[held] = int(out.get(held, 0)) + pieces
	return out


func _collect_unpaid_checkout_pieces() -> Dictionary:
	var out: Dictionary = {}
	if _customers == null:
		return out
	for c in _customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.has_method("unsold_checkout_cart"):
			continue
		var cart: Array = c.call("unsold_checkout_cart")
		for sku_v in cart:
			var sku := String(sku_v)
			if sku == "":
				continue
			out[sku] = int(out.get(sku, 0)) + 1
	return out


func _return_unsold_to_warehouse() -> void:
	var pieces := _collect_unsold_pieces()
	if pieces.is_empty():
		return
	state.credit_unsold_pieces(pieces)
	_clear_credited_unsold()
	sync_stock()


## Clear credited world / carry goods after warehouse credit so closeout
## does not leave orphan drops or double-count if somehow re-entered.
func _clear_credited_unsold() -> void:
	for s in shelves:
		if s == null or not is_instance_valid(s):
			continue
		if s.has_method("take_all"):
			s.call("take_all")
	var seats: Array = _players.duplicate()
	if seats.is_empty() and is_instance_valid(_player):
		seats.append(_player)
	for player in seats:
		if is_instance_valid(player):
			player.inventory.clear()
	if _customers != null:
		for c in _customers.get_children():
			if c != null and is_instance_valid(c) and c.has_method("clear_unsold_checkout_cart"):
				c.call("clear_unsold_checkout_cart")
	if _world == null:
		return
	var kill: Array[Node] = []
	for c in _world.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## Mixed world children: String(null) on missing kind aborts the sweep.
		var kind := str(c.get("kind"))
		if kind in ["universal_cannon", "shelf_cannon"]:
			c.ammo.clear()
			c.dismiss()
			continue
		if kind == "drop" or kind == "drop_flight":
			kill.append(c)
			continue
		if str(c.get("role")) == "restock":
			c.set("_box_n", 0)
			c.set("_box_sku", "")
	for c in kill:
		c.queue_free()


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
	## Capture before close() clears settlement_applied.
	var settled_ok := SessionService.settlement_applied
	SessionService.close()
	## Client still holds Host world in `state` until we restore home save.
	_reload_local_save_for_prep(settled_ok)
	_clear_world()
	_prep.visible = true
	_prep.set_process_unhandled_input(true)
	_prep._show_page("home")
	if _prep.has_method("maybe_offer_difficulty_prompt"):
		_prep.call("maybe_offer_difficulty_prompt")


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
	var head := Loc.t("demo.closeout_head")
	var xp_line: String
	if ok:
		xp_line = Loc.t("lobby.client_settle_ok", [shared_xp, support, grade])
		if revenue_gain > 0 or money_after > 0:
			xp_line += "\n" + Loc.t("lobby.client_settle_revenue", [revenue_gain, money_after])
	else:
		xp_line = Loc.t("lobby.client_settle_fail")
	_hud._close_text.text = "\n".join([
		head,
		xp_line,
		Loc.t("lobby.client_settle_hint"),
	])


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
		_player.set_hold("ult", false)
	if _player:
		_player.stick_axis = Vector2.ZERO


func _on_pause_end_day() -> void:
	skip_operate()


func _consider_early_close() -> bool:
	if not _restocks_cleared() or not _registers_idle():
		_early_latched = false
		return false
	if _early_latched:
		return false
	_show_early_dialog()
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
	for c in cashiers:
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
	var press := false
	if event.is_echo():
		get_viewport().set_input_as_handled()
		return
	if not (
		event.is_action(Controls.MOVE_LEFT)
		or event.is_action(Controls.MOVE_RIGHT)
		or event.is_action(Controls.INTERACT)
		or event.is_action(Controls.CANCEL)
	):
		return
	press = event.is_pressed()
	get_viewport().set_input_as_handled()
	if not press:
		return
	if event.is_action_pressed(Controls.MOVE_LEFT):
		_early_focus = 0
		_paint_early_focus()
	elif event.is_action_pressed(Controls.MOVE_RIGHT):
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
	if not _early_open:
		return
	_hide_early_dialog()
	_early_closed = true
	clear_guest_dusk()
	phase = "closed"
	game_hours = Tuning.CLOSE_HOUR
	_finish_day()


func _decline_early_close() -> void:
	if not _early_open:
		return
	_early_latched = true
	_hide_early_dialog()


func _hide_early_dialog() -> void:
	_early_open = false
	if _early_layer != null and is_instance_valid(_early_layer):
		_early_layer.visible = false


func world_delta(delta: float) -> float:
	if _early_open:
		return 0.0
	if _player == null:
		return delta
	return delta * float(_player.get("clock_scale"))


func customer_move_mult() -> float:
	if _player == null:
		return 1.0
	return float(_player.get("customer_move_mult"))


func _process(delta: float) -> void:
	if phase == "prep" or phase == "closed" or _early_open:
		return
	_poll_camera_view_hotkey()
	_maintain_overview_camera()
	_maintain_coop_camera()
	_soft_push_players(delta)
	_net_tick_intents_and_sync()
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
		_finish_day()
		return
	_tick_three_volley(delta)
	if phase == "open":
		if bool(tick["open_sfx"]) and _sfx_phase != "open":
			_sfx_phase = "open"
			SfxBus.play("sfx_phase_open")
		if _consider_early_close():
			return
		## Listen-server: only host / local spawn agents.
		if SessionService.is_server() or SessionService.is_local_transport():
			_tick_guest_dusk(delta)
			_spawn_in -= world_delta(delta)
			if _spawn_in <= 0.0:
				_spawn_customer()
				_spawn_in = state.spawn_every()
			_thief_spawn_in -= world_delta(delta)
			if _thief_spawn_in <= 0.0:
				_spawn_thief()
				_thief_spawn_in = state.thief_spawn_sec()
	if phase != prev_phase:
		bump_hud()
		host_phase_changed.emit(phase)
	if SessionService.is_server() or SessionService.is_local_transport():
		_dirt_spawn_in -= world_delta(delta)
		if _dirt_spawn_in <= 0.0:
			_try_spawn_dirt()
			_dirt_spawn_in = dirt_spawn_interval()


func _net_tick_intents_and_sync() -> void:
	if not SessionService.is_networked() or not SessionService.day_started:
		return
	if SessionService.is_client():
		## Send local seat intents; apply host transforms to puppets.
		for p in _players:
			if p == null or not is_instance_valid(p):
				continue
			var sid := int(p.seat_id)
			if SeatTable.seat_owned_locally(sid):
				var mv := Controls.move_vector_for(sid)
				## dash = run/dash hold (_k_held); skill = _l_held; ult = _u_held (M2.5).
				var hotkey := -1
				if p.has_method("take_pending_skill_hotkey"):
					hotkey = int(p.call("take_pending_skill_hotkey"))
				SessionService.send_intent(sid, {
					"mx": mv.x,
					"my": mv.y,
					"interact": p.get("_j_held") == true,
					"cancel": p.get("_cancel_held") == true,
					"dash": p.get("_k_held") == true,
					"skill": p.get("_l_held") == true,
					"ult": p.get("_u_held") == true,
					"hotkey": hotkey,
				})
		var xforms: Array = SessionService.peek_player_transforms()
		for row in xforms:
			if row is Dictionary:
				var sid2 := int(row.get("seat", -1))
				var pos := Vector2(float(row.get("px", 0.0)), float(row.get("py", 0.0)))
				var fac := Vector2(float(row.get("fx", 1.0)), float(row.get("fy", 0.0)))
				for p2 in _players:
					if p2 != null and is_instance_valid(p2) and int(p2.seat_id) == sid2:
						if SeatTable.seat_owned_locally(sid2):
							## Host is authority. Soft-reconcile local prediction so fight/KO
							## dual-sim cannot leave CLIENT permanently offset from HOST.
							if p2.global_position.distance_squared_to(pos) > 64.0:
								p2.global_position = pos
								p2.facing = fac
						else:
							p2.global_position = pos
							p2.facing = fac
						break
		_apply_agent_transforms(SessionService.peek_agent_transforms())
		return
	## Host: apply remote intents + broadcast transforms.
	for p in _players:
		if p == null or not is_instance_valid(p):
			continue
		var sid3 := int(p.seat_id)
		if SeatTable.seat_owned_locally(sid3) or SeatTable.is_frozen(sid3):
			continue
		var intent: Dictionary = SessionService.take_remote_intent(sid3)
		if intent.is_empty():
			continue
		p.remote_move = Vector2(float(intent.get("mx", 0.0)), float(intent.get("my", 0.0)))
		## Hold edges: apply pressed state from remote (M2.5: dash/skill/ult correct).
		if p.has_method("set_hold"):
			p.set_hold("interact", intent.get("interact", false) == true)
			p.set_hold("cancel", intent.get("cancel", false) == true)
			p.set_hold("dash", intent.get("dash", false) == true)
			p.set_hold("skill", intent.get("skill", false) == true)
			p.set_hold("ult", intent.get("ult", false) == true)
		var hotkey := int(intent.get("hotkey", -1))
		if hotkey >= 0 and p.has_method("_try_skill_hotkey"):
			p.call("_try_skill_hotkey", hotkey)
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
		})
	SessionService.broadcast_player_transforms(out)
	_agent_xform_tick += 1
	if _agent_xform_tick >= AGENT_XFORM_EVERY:
		_agent_xform_tick = 0
		SessionService.broadcast_agent_transforms(_collect_agent_transforms())


func _alloc_agent_id() -> int:
	var id := _next_agent_id
	_next_agent_id += 1
	return id


func _register_net_agent(node: Node, kind: String, extra: Dictionary = {}) -> void:
	## Host-only: assign id, track, broadcast spawn to clients (M2.2).
	if node == null or not is_instance_valid(node):
		return
	if SessionService.is_networked() and SessionService.is_client():
		return
	var aid := _alloc_agent_id()
	node.set("net_agent_id", aid)
	_net_agents[aid] = node
	if not node.tree_exiting.is_connected(_on_net_agent_tree_exiting):
		node.tree_exiting.connect(_on_net_agent_tree_exiting.bind(aid))
	if not SessionService.is_networked() or not SessionService.is_server():
		return
	var payload := {
		"id": aid,
		"kind": kind,
		"px": float(node.global_position.x) if node is Node2D else 0.0,
		"py": float(node.global_position.y) if node is Node2D else 0.0,
		"fx": 0.0,
		"fy": 1.0,
	}
	if node is CharacterBody2D:
		var vel: Vector2 = (node as CharacterBody2D).velocity
		if vel.length_squared() > 1.0:
			payload["fx"] = vel.x
			payload["fy"] = vel.y
	for k in extra.keys():
		payload[k] = extra[k]
	SessionService.broadcast_agent_spawn(payload)


func _on_net_agent_tree_exiting(agent_id: int) -> void:
	_net_agents.erase(agent_id)
	if SessionService.is_networked() and SessionService.is_server() and SessionService.day_started:
		SessionService.broadcast_agent_despawn(agent_id, "gone")


func _collect_agent_transforms() -> Array:
	var out: Array = []
	var stale: Array[int] = []
	for aid in _net_agents.keys():
		var n = _net_agents[aid]
		if n == null or not is_instance_valid(n):
			stale.append(int(aid))
			continue
		if not (n is Node2D):
			continue
		## Static presentation agents — pose fixed after spawn (M2.3).
		var kind := String(n.get("kind")) if n.get("kind") != null else ""
		if kind in ["drop", "dirt", "universal_cannon", "shelf_cannon", "calm_zone", "three_volley"]:
			continue
		var fx := 0.0
		var fy := 1.0
		if n is CharacterBody2D:
			var vel: Vector2 = (n as CharacterBody2D).velocity
			if vel.length_squared() > 16.0:
				fx = vel.x
				fy = vel.y
			elif "facing" in n:
				var f: Vector2 = n.facing
				fx = f.x
				fy = f.y
		out.append({
			"id": int(aid),
			"px": (n as Node2D).global_position.x,
			"py": (n as Node2D).global_position.y,
			"fx": fx,
			"fy": fy,
		})
	for sid in stale:
		_net_agents.erase(sid)
	return out


func _apply_agent_transforms(rows: Array) -> void:
	for row in rows:
		if not (row is Dictionary):
			continue
		var aid := int(row.get("id", -1))
		if aid < 0 or not _net_agents.has(aid):
			continue
		var n = _net_agents[aid]
		if n == null or not is_instance_valid(n):
			_net_agents.erase(aid)
			continue
		var pos := Vector2(float(row.get("px", 0.0)), float(row.get("py", 0.0)))
		var fac := Vector2(float(row.get("fx", 0.0)), float(row.get("fy", 1.0)))
		if n.has_method("apply_net_pose"):
			n.call("apply_net_pose", pos, fac)
		elif n is Node2D:
			(n as Node2D).global_position = pos


func _on_agent_spawn_received(payload: Dictionary) -> void:
	## Client: instantiate presentation puppet from Host spawn event.
	if not SessionService.is_client():
		return
	if _world == null or not is_instance_valid(_world) or _customers == null:
		_pending_agent_spawns.append(payload.duplicate(true))
		return
	_apply_agent_spawn_payload(payload)


func _flush_pending_agent_spawns() -> void:
	if _pending_agent_spawns.is_empty():
		return
	var queued: Array = _pending_agent_spawns.duplicate(true)
	_pending_agent_spawns.clear()
	for payload in queued:
		if payload is Dictionary:
			_apply_agent_spawn_payload(payload)


func _apply_agent_spawn_payload(payload: Dictionary) -> void:
	var aid := int(payload.get("id", -1))
	if aid < 0 or _net_agents.has(aid):
		return
	var kind := String(payload.get("kind", ""))
	var pos := Vector2(float(payload.get("px", 0.0)), float(payload.get("py", 0.0)))
	match kind:
		"customer", "thief":
			_spawn_customer_puppet(aid, kind == "thief", pos, payload)
		"clerk":
			_spawn_clerk_puppet(aid, pos, payload)
		"dirt":
			_spawn_dirt_puppet(aid, pos, payload)
		"drop":
			_spawn_drop_puppet(aid, pos, payload)
		"shadow_clone":
			_spawn_shadow_clone_puppet(aid, pos, payload)
		"universal_cannon":
			_spawn_cannon_puppet(aid, pos, payload)
		"shelf_cannon":
			_spawn_shelf_cannon_puppet(aid, pos, payload)
		"calm_zone":
			_spawn_calm_zone_puppet(aid, pos, payload)
		"three_volley":
			_spawn_three_volley_puppet(aid, pos, payload)
		_:
			pass


func _on_agent_state_received(payload: Dictionary) -> void:
	if not SessionService.is_client():
		return
	if _world == null or not is_instance_valid(_world):
		_pending_agent_states.append(payload.duplicate(true))
		return
	_apply_agent_state_payload(payload)


func _flush_pending_agent_states() -> void:
	if _pending_agent_states.is_empty():
		return
	var queued: Array = _pending_agent_states.duplicate(true)
	_pending_agent_states.clear()
	for payload in queued:
		if payload is Dictionary:
			_apply_agent_state_payload(payload)


func _apply_agent_state_payload(payload: Dictionary) -> void:
	var aid := int(payload.get("id", -1))
	if aid < 0 or not _net_agents.has(aid):
		return
	var n = _net_agents[aid]
	if n == null or not is_instance_valid(n):
		_net_agents.erase(aid)
		return
	## Drop remaining count.
	if payload.has("n") and n.has_method("apply_net_count"):
		n.call("apply_net_count", int(payload.get("n", 0)))
		if int(payload.get("n", 0)) <= 0:
			_net_agents.erase(aid)
		return
	## Guest／thief shopping pictogram chrome (M2.7).
	if payload.has("shopping") and n.has_method("apply_net_shopping"):
		n.call("apply_net_shopping", payload.get("shopping", []))
		return
	## Guest checkout dir sequence (M2.9).
	if payload.has("checkout_seq") and n.has_method("apply_net_checkout_seq"):
		n.call(
			"apply_net_checkout_seq",
			payload.get("checkout_seq", []),
			bool(payload.get("checkout_init", false)),
		)
		return
	## Dirt clean StickHint／meter chrome (M2.8).
	if payload.has("cleaning") and n.has_method("apply_net_clean"):
		n.call(
			"apply_net_clean",
			bool(payload.get("cleaning", false)),
			float(payload.get("meter", 0.0)),
			Vector2(float(payload.get("sx", 0.0)), float(payload.get("sy", 0.0))),
			int(payload.get("seat", -1)),
		)
		return
	## Dark Side temp morph on customer puppet.
	if payload.has("temp") and n.has_method("apply_net_temp_state"):
		n.call("apply_net_temp_state", bool(payload.get("temp", false)), String(payload.get("role", "")))
		return
	## Cannon ammo label.
	if payload.has("ammo_n") and n.has_method("apply_net_ammo"):
		n.call("apply_net_ammo", int(payload.get("ammo_n", 0)), String(payload.get("sku", "")))
		return
	## Host fight outcome for a presentation thief (unlock client mash / pending KO).
	if payload.has("fight_clear"):
		_resolve_net_fight_clear(n, bool(payload.get("caught", false)))


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
	if not SessionService.is_client():
		return
	if _world == null or not is_instance_valid(_world):
		_pending_flights.append(payload.duplicate(true))
		return
	_play_net_flight(payload)


func _flush_pending_flights() -> void:
	if _pending_flights.is_empty():
		return
	var queued: Array = _pending_flights.duplicate(true)
	_pending_flights.clear()
	for payload in queued:
		if payload is Dictionary:
			_play_net_flight(payload)


func _play_net_flight(payload: Dictionary) -> void:
	## Client VFX only — do NOT place a floor box on land (Host sends drop spawn).
	if _world == null:
		return
	var sku := String(payload.get("sku", ""))
	var n := int(payload.get("n", 0))
	if sku == "" or n <= 0:
		return
	var from := Vector2(float(payload.get("fx", 0.0)), float(payload.get("fy", 0.0)))
	var to := Vector2(float(payload.get("tx", 0.0)), float(payload.get("ty", 0.0)))
	var dur := float(payload.get("dur", Tuning.DROP_FLIGHT_SEC))
	var flight: Node2D = DropFlightScript.new()
	flight.setup(sku, from, to, dur, n)
	_world.add_child(flight)


func _on_agent_despawn_received(agent_id: int, _reason: String) -> void:
	if not SessionService.is_client():
		return
	## Drop matching pending spawn if despawn raced ahead.
	var i := 0
	while i < _pending_agent_spawns.size():
		var row = _pending_agent_spawns[i]
		if row is Dictionary and int(row.get("id", -1)) == agent_id:
			_pending_agent_spawns.remove_at(i)
			continue
		i += 1
	if not _net_agents.has(agent_id):
		return
	var n = _net_agents[agent_id]
	_net_agents.erase(agent_id)
	## Free local seats still mashed against this presentation thief.
	if n != null and is_instance_valid(n):
		var was_thief := _obj_truthy(n, "is_thief")
		for p in _players:
			if p == null or not is_instance_valid(p):
				continue
			if p.get("target") != n:
				continue
			if _obj_truthy(p, "_fighting") or _obj_truthy(p, "_net_ko_pending") or _obj_truthy(p, "_fight_ko"):
				if was_thief and not _obj_truthy(p, "_fight_ko"):
					play_ko_banner()
				if p.has_method("_end_fight"):
					p.call("_end_fight", true)
		_clerks.erase(n)
		_dirts.erase(n)
		_remove_interactable(n)
		n.queue_free()


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
	if bool(payload.get("elite", false)):
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


func take_from_shelf(shelf: Node2D, sku: String) -> bool:
	if shelf == null or not is_instance_valid(shelf):
		return false
	if shelf.has_method("take_one"):
		return bool(shelf.call("take_one", sku))
	if not shelf_has(shelf, sku):
		return false
	var n := int(shelf.get("count")) - 1
	shelf.set("count", n)
	if n <= 0:
		shelf.set("sku", "")
		shelf.set("count", 0)
	shelf.call("_refresh")
	return true


func _index_shelf_sku(sku: String, shelf: Node) -> void:
	if sku == "" or shelf == null:
		return
	var list: Array = _shelves_by_sku.get(sku, [])
	if not list.has(shelf):
		list.append(shelf)
	_shelves_by_sku[sku] = list


func _unindex_shelf_sku(sku: String, shelf: Node) -> void:
	if sku == "" or not _shelves_by_sku.has(sku):
		return
	var list: Array = _shelves_by_sku[sku]
	list.erase(shelf)
	if list.is_empty():
		_shelves_by_sku.erase(sku)
	else:
		_shelves_by_sku[sku] = list


func _on_shelf_stock_sku_changed(shelf: Node, old_sku: String, new_sku: String) -> void:
	if old_sku != "":
		_unindex_shelf_sku(old_sku, shelf)
	if new_sku != "":
		_index_shelf_sku(new_sku, shelf)
		_unindex_empty_shelf(shelf)
	else:
		_index_empty_shelf(shelf)


func _index_empty_shelf(shelf: Node) -> void:
	if shelf == null:
		return
	var cat := String(shelf.get("category"))
	var list: Array = _empty_by_cat.get(cat, [])
	if not list.has(shelf):
		list.append(shelf)
	_empty_by_cat[cat] = list


func _unindex_empty_shelf(shelf: Node) -> void:
	if shelf == null:
		return
	var cat := String(shelf.get("category"))
	if not _empty_by_cat.has(cat):
		return
	var list: Array = _empty_by_cat[cat]
	list.erase(shelf)
	if list.is_empty():
		_empty_by_cat.erase(cat)
	else:
		_empty_by_cat[cat] = list


func _register_shelf(node: Node2D) -> void:
	shelves.append(node)
	var nid := int(node.get("net_shelf_id")) if node.get("net_shelf_id") != null else -1
	if nid >= 0:
		_shelves_by_net_id[nid] = node
	if node.has_signal("stock_sku_changed"):
		node.connect("stock_sku_changed", _on_shelf_stock_sku_changed)
	if node.has_signal("stock_changed"):
		node.connect("stock_changed", _on_shelf_stock_changed)
	var sku := ""
	if node.has_method("occupied_sku"):
		sku = String(node.call("occupied_sku"))
	elif int(node.get("count")) > 0:
		sku = String(node.get("sku"))
	if sku != "":
		_index_shelf_sku(sku, node)
	else:
		_index_empty_shelf(node)


func _hook_warehouse_changed() -> void:
	if state == null or _warehouse_hooked:
		return
	if state.has_signal("warehouse_changed") and not state.warehouse_changed.is_connected(_on_warehouse_changed):
		state.warehouse_changed.connect(_on_warehouse_changed)
		_warehouse_hooked = true


func _on_shelf_stock_changed(shelf: Node) -> void:
	## Host only — client prediction is overwritten by absolute stock_state.
	if SessionService.is_networked() and SessionService.is_client():
		return
	_broadcast_shelf_stock(shelf)


func _on_warehouse_changed() -> void:
	if SessionService.is_networked() and SessionService.is_client():
		return
	_broadcast_warehouse_stock()


func _broadcast_shelf_stock(shelf: Node) -> void:
	if shelf == null or not is_instance_valid(shelf):
		return
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var nid := int(shelf.get("net_shelf_id")) if shelf.get("net_shelf_id") != null else -1
	if nid < 0:
		return
	SessionService.broadcast_stock_state({
		"shelves": [{
			"id": nid,
			"sku": String(shelf.get("sku")),
			"count": int(shelf.get("count")),
		}],
	})


func _broadcast_warehouse_stock() -> void:
	if state == null:
		return
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	SessionService.broadcast_stock_state({
		"warehouse": state.stock.duplicate(true),
	})


func _dump_all_stock() -> void:
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var rows: Array = []
	for shelf in shelves:
		if shelf == null or not is_instance_valid(shelf):
			continue
		var nid := int(shelf.get("net_shelf_id")) if shelf.get("net_shelf_id") != null else -1
		if nid < 0:
			continue
		rows.append({
			"id": nid,
			"sku": String(shelf.get("sku")),
			"count": int(shelf.get("count")),
		})
	var payload := {}
	if not rows.is_empty():
		payload["shelves"] = rows
	if state != null:
		payload["warehouse"] = state.stock.duplicate(true)
	if not payload.is_empty():
		SessionService.broadcast_stock_state(payload)


func _on_stock_state_received(payload: Dictionary) -> void:
	if not SessionService.is_client():
		return
	if _world == null or not is_instance_valid(_world):
		_pending_stock_states.append(payload.duplicate(true))
		return
	_apply_stock_state_payload(payload)


func _flush_pending_stock_states() -> void:
	if _pending_stock_states.is_empty():
		return
	var queued: Array = _pending_stock_states.duplicate(true)
	_pending_stock_states.clear()
	for payload in queued:
		if payload is Dictionary:
			_apply_stock_state_payload(payload)


func _apply_stock_state_payload(payload: Dictionary) -> void:
	var wh_changed := false
	if payload.has("warehouse") and state != null:
		var wh = payload.get("warehouse")
		if wh is Dictionary:
			## Absolute warehouse dict from Host — replace presentation stock.
			state.stock.clear()
			for k in wh.keys():
				state.stock[String(k)] = int(wh[k])
			wh_changed = true
	var rows = payload.get("shelves", [])
	if rows is Array:
		for row in rows:
			if not (row is Dictionary):
				continue
			var nid := int(row.get("id", -1))
			if nid < 0 or not _shelves_by_net_id.has(nid):
				continue
			var shelf = _shelves_by_net_id[nid]
			if shelf == null or not is_instance_valid(shelf):
				_shelves_by_net_id.erase(nid)
				continue
			if shelf.has_method("apply_net_stock"):
				shelf.call("apply_net_stock", String(row.get("sku", "")), int(row.get("count", 0)))
	if wh_changed:
		sync_stock()


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
	if c.get("is_thief"):
		_thieves.erase(c)
		_recount_active_thieves()
	else:
		## If still counted as occupying when freed, drop one.
		if c.has_method("occupies_store") and bool(c.call("occupies_store")):
			_guest_n = maxi(0, _guest_n - 1)
			bump_hud()


func _recount_active_thieves() -> void:
	var n := 0
	for c in _thieves:
		if c != null and is_instance_valid(c) and c.has_method("is_active_thief") and bool(c.call("is_active_thief")):
			n += 1
	if n != _active_thief_n:
		_active_thief_n = n
		bump_hud()


func record_stolen(items: Array) -> void:
	var pieces := 0
	for sku in items:
		stolen_count += 1
		stolen_value += Tuning.sku_price(String(sku))
		pieces += 1
	thieves_escaped += 1
	bump_hud()
	var delta := pieces * RatingRules.N2_STOLEN_PIECE + RatingRules.N3_THIEF_ESCAPE
	apply_ops_rating(delta, _player)


func record_caught(seat: int = 0, method: String = "any") -> void:
	thieves_caught += 1
	_seat_bump(seat_caught, seat, 1)
	bump_hud()
	var FloatText = preload("res://scripts/ui/float_text.gd")
	var actor := _seat_actor(seat)
	if actor != null:
		FloatText.spawn_xp(actor, StateScript.XP_CATCH)
	apply_ops_rating(RatingRules.P3_CATCH, actor)
	if _tasks != null:
		_tasks.note_metric(seat, "thief_caught", 1)
		match String(method):
			"melee":
				_tasks.note_metric(seat, "thief_caught_melee", 1)
			"dash":
				_tasks.note_metric(seat, "thief_caught_dash", 1)


func apply_ops_rating(delta: int, actor: Node2D = null) -> void:
	if delta == 0:
		return
	ops_rating += delta
	bump_hud()
	if _tasks != null:
		_tasks.sync_absolute_for_all_seats("ops_rating", ops_rating)
	var body: Node2D = actor if actor != null and is_instance_valid(actor) else _player
	if body != null and is_instance_valid(body):
		var FloatText = preload("res://scripts/ui/float_text.gd")
		FloatText.spawn_rating(body, delta)


func note_angry_leave(actor: Node2D = null) -> void:
	apply_ops_rating(RatingRules.N1_ANGRY, actor)
	if _tasks != null:
		_tasks.sync_absolute_for_all_seats("angry_leave", angry_left)
		bump_hud()


func note_wrong_deliver(actor: Node2D = null) -> void:
	apply_ops_rating(RatingRules.N4_WRONG_DELIVER, actor)
	var seat := _actor_seat(actor)
	if _tasks != null:
		_tasks.note_metric(seat, "wrong_deliver", 1)
		bump_hud()


func note_dash_guest(actor: Node2D = null) -> void:
	apply_ops_rating(RatingRules.N5_DASH_GUEST, actor)
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
) -> void:
	revenue += amount
	served += 1
	_seat_bump(seat_served, seat, 1)
	if from_elite:
		elite_served += 1
		_seat_bump(seat_elite, seat, 1)
	bump_hud()
	var body: Node2D = actor if actor != null and is_instance_valid(actor) else _seat_actor(seat)
	if body == null:
		body = _player
	var FloatText = preload("res://scripts/ui/float_text.gd")
	if body != null and is_instance_valid(body):
		var stagger := 0
		if amount > 0:
			FloatText.spawn_money(body, amount, stagger)
			stagger += 1
		FloatText.spawn_xp(body, StateScript.XP_SERVE, stagger)
		stagger += 1
		if from_elite:
			FloatText.spawn_xp(body, StateScript.XP_ELITE_SERVE, stagger)
	apply_ops_rating(RatingRules.checkout_delta(from_elite, perfect), body)
	## Checkout task credit: player seat only — player body or that seat's self-checkout ring.
	## Skip clerk NPC and skill mass-pay (actor null).
	if _tasks != null:
		_tasks.sync_absolute_for_all_seats("sales_revenue", revenue)
		_tasks.sync_absolute_for_all_seats("ops_rating", ops_rating)
		var kind := str(actor.get("kind")) if actor != null and is_instance_valid(actor) else ""
		var credit := _is_player_seat(seat) and (
			_is_player_actor(actor) or kind == "cashier"
		)
		if credit:
			_tasks.note_metric(seat, "checkout_count", 1)
			if perfect:
				_tasks.note_metric(seat, "checkout_perfect", 1)
		bump_hud()
	if _player != null:
		var FxBurst = preload("res://scripts/fx_burst.gd")
		var at: Vector2 = _player.global_position + Vector2(0, -28)
		if body != null and str(body.get("kind")) == "cashier":
			at = body.global_position + Vector2(0, -24)
		elif _player.get("target") != null and is_instance_valid(_player.target):
			at = _player.target.global_position + Vector2(0, -24)
		elif body != null and is_instance_valid(body):
			at = body.global_position + Vector2(0, -24)
		FxBurst.spawn(self, "coin", at)


func _seat_actor(seat: int) -> Node2D:
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
	if n <= 0 or _tasks == null or not _is_player_seat(seat):
		return
	_tasks.note_metric(seat, "shelve_count", n)
	_tasks.note_metric(seat, "shelve_count_sku", n, {"sku": String(sku)})
	bump_hud()


func note_deliver(seat: int, mode: String, n: int = 1, perfect: bool = false) -> void:
	if n <= 0 or _tasks == null or not _is_player_seat(seat):
		return
	_tasks.note_metric(seat, "deliver_count", n)
	match String(mode):
		"hand":
			_tasks.note_metric(seat, "hand_deliver_count", n)
		"toss":
			_tasks.note_metric(seat, "toss_deliver_count", n)
	if perfect:
		_tasks.note_metric(seat, "perfect_deliver_count", 1)
	bump_hud()


func note_skill_cast(seat: int, skill_id: String, is_ult: bool) -> void:
	if _tasks == null or not _is_player_seat(seat):
		return
	if is_ult:
		_tasks.note_metric(seat, "ult_cast", 1, {"skill_id": skill_id})
	else:
		_tasks.note_metric(seat, "skill_cast", 1, {"skill_id": skill_id})
	bump_hud()


func task_hud_lines(seat: int = 0) -> Array:
	if _tasks == null:
		return []
	return _tasks.hud_lines(seat)


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
	if _early_open:
		_hide_early_dialog()
	_skip_xp = 400
	phase = "closed"
	game_hours = Tuning.CLOSE_HOUR
	_finish_day()


func _finish_day() -> void:
	_clear_three_volley()
	if _settled:
		return
	## Clients wait for Host settle RPC (_on_settle_payload); do not invent a local shop settle.
	if SessionService.is_client():
		phase = "closed"
		if _hud:
			_hud.show_closeout()
			_hud._close_text.text = Loc.t("lobby.client_waiting_settle")
		## Keep _settled false until settle RPC (or Host abort).
		return
	_settled = true
	_closeout_ready_msec = Time.get_ticks_msec() + CLOSEOUT_HOLD_MSEC
	SfxBus.play("sfx_phase_close")
	## Clones drop held boxes onto the floor before unsold collect, then vanish.
	dismiss_shadow_clones()
	dismiss_universal_cannons()
	dismiss_shelf_cannons()
	## Unsold shelf + floor (+ in-flight) pieces → warehouse boxes before save.
	_return_unsold_to_warehouse()
	var seat_n := maxi(1, SessionService.open_day_seat_n if SessionService.is_networked() else SeatTable.seat_count)
	var xp_pack: Dictionary = DaySettle.shared_xp_for_seats(
		seat_served, seat_caught, seat_cleaned, seat_elite, seat_n, _skip_xp
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
			per_seat[s] = {"shared_xp": shared_xp}
		SessionService.send_settle_to_clients({
			"host_grade": grade,
			"per_seat": per_seat,
			"shared_xp": shared_xp,
			## M2.1：每位仍連線訪客本店同等加這筆營業額（非平分）。
			"revenue": revenue,
		})
	if _hud:
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
		var task_block := ""
		if _tasks != null:
			var tlines: PackedStringArray = _tasks.closeout_lines(0)
			if not tlines.is_empty():
				task_block = "\n" + Loc.t("settle.tasks_header") + "\n" + "\n".join(tlines)
		_hud._close_text.text = DaySettle.closeout_body(
			head, loss, revenue, state.money, int(result["spent"]), served, angry_left,
			stolen_count, stolen_value, thieves_caught, thieves_escaped,
			xp_line, save_line, grade_line
		) + task_block
	## Prep will check difficulty suggestion after closeout returns.


func _seat_get(arr: Array, seat: int) -> int:
	if seat < 0 or seat >= arr.size():
		return 0
	return int(arr[seat])


## Real-second inject for 諸客的黃昏. Successful entries only count toward remain.
func _tick_guest_dusk(delta: float) -> void:
	if _guest_dusk_left <= 0.0 and _guest_dusk_remain <= 0:
		return
	if phase != "open":
		clear_guest_dusk()
		return
	_guest_dusk_left = maxf(0.0, _guest_dusk_left - delta)
	if _guest_dusk_remain <= 0:
		return
	if _guest_dusk_left <= 0.0:
		clear_guest_dusk()
		return
	_guest_dusk_in -= delta
	## Empty sellable: retry next frame (skip, do not burn a slot or the interval).
	while _guest_dusk_remain > 0 and _guest_dusk_in <= 0.0:
		if state.sellable().is_empty():
			_guest_dusk_in = 0.0
			break
		if _spawn_customer(true):
			_guest_dusk_remain -= 1
			_guest_dusk_in += Skills.GUEST_DUSK_INTERVAL
		else:
			_guest_dusk_in = 0.0
			break
	if _guest_dusk_remain <= 0:
		_guest_dusk_remain = 0


## Returns true when a guest was spawned. `ignore_cap` for 諸客的黃昏.
func _spawn_customer(ignore_cap: bool = false) -> bool:
	if state.sellable().is_empty():
		return false
	if not ignore_cap and guest_count() >= state.guest_cap():
		return false
	## EliteCustomer only during open phase (not restock).
	var make_elite := false
	var elite_lv := 1
	if phase == "open":
		if elite_test_active and elite_test_need_one:
			make_elite = true
			elite_test_need_one = false
		elif elite_test_active:
			## Test mode: elevated chance after the guaranteed first elite.
			make_elite = randf() < Tuning.ELITE_TEST_SPAWN_CHANCE
		else:
			make_elite = randf() < Tuning.elite_spawn_chance()
		if make_elite:
			if elite_test_active:
				elite_lv = elite_test_lv if elite_test_lv >= 1 else randi_range(1, 6)
			else:
				elite_lv = Tuning.elite_roll_level()
	var c: CharacterBody2D = CustomerScript.new()
	_customers.add_child(c)
	c.setup(self, door_pos())
	if make_elite:
		c.call("become_elite", elite_lv)
		announce_elite_customer(c)
	register_customer(c)
	var cust_extra := {
		"pace": String(c.get("pace")),
		"elite": bool(c.get("is_elite")),
		"elite_lv": int(c.get("elite_lv")),
		"model": String(c.get("_model_id")),
		"shopping": c.shopping.duplicate() if c.get("shopping") != null else [],
	}
	if c.has_meta("checkout_seq_init") and bool(c.get_meta("checkout_seq_init")):
		var dirs: Array = []
		for d in c.checkout_seq:
			dirs.append(int(d))
		cust_extra["checkout_seq"] = dirs
		cust_extra["checkout_init"] = true
	_register_net_agent(c, "customer", cust_extra)
	SfxBus.play("sfx_guest_enter")
	return true


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


func _spawn_thief() -> void:
	if state.sellable().is_empty():
		return
	if randf() > thief_appear_rate():
		return
	if thief_count() >= Tuning.THIEF_CAP:
		return
	var c: CharacterBody2D = CustomerScript.new()
	_customers.add_child(c)
	c.setup(self, door_pos(), true)
	_add_interactable(c)
	c.tree_exiting.connect(func() -> void: _remove_interactable(c))
	register_customer(c)
	_register_net_agent(c, "thief", {
		"pace": "normal",
		"elite": false,
		"elite_lv": 0,
		"model": String(c.get("_model_id")),
		"shopping": c.shopping.duplicate() if c.get("shopping") != null else [],
	})
	SfxBus.play("sfx_thief_spawn")
	if _player:
		_player.log_line.emit(Loc.t("demo.thief_enter"))


func _floor() -> void:
	## One canvas item that draws tiled floor (avoids 100–400 Sprite2D nodes).
	var floor: Node2D = FloorTilesScript.new()
	floor.name = "Floor"
	floor.z_index = -8
	_world.add_child(floor)
	floor.call("setup", FLOOR_ORIGIN, FLOOR_SIZE, StateScript.CELL)


func _walls_and_door() -> void:
	var t := 18.0
	var o := FLOOR_ORIGIN
	var s := FLOOR_SIZE
	var door_w := 90.0
	var mid := o.x + s.x * 0.5
	_solid(Rect2(o.x - t, o.y - t, mid - door_w * 0.5 - (o.x - t), t))
	_solid(Rect2(mid + door_w * 0.5, o.y - t, (o.x + s.x + t) - (mid + door_w * 0.5), t))
	_solid(Rect2(o.x - t, o.y + s.y, s.x + t * 2.0, t))
	_solid(Rect2(o.x - t, o.y, t, s.y))
	_solid(Rect2(o.x + s.x, o.y, t, s.y))
	var north_y := o.y - t * 0.5
	var south_y := o.y + s.y + t * 0.5
	var west_x := o.x - t * 0.5
	var east_x := o.x + s.x + t * 0.5
	_run_wall(Vector2(o.x, north_y), Vector2(mid - door_w * 0.5, north_y), 0)
	_run_wall(Vector2(mid + door_w * 0.5, north_y), Vector2(o.x + s.x, north_y), 0)
	_run_wall(Vector2(o.x, south_y), Vector2(o.x + s.x, south_y), 2)
	_run_wall(Vector2(west_x, o.y), Vector2(west_x, o.y + s.y), 1)
	_run_wall(Vector2(east_x, o.y), Vector2(east_x, o.y + s.y), 3)
	var door := Vox.sprite("door", 0)
	door.z_index = -4
	door.position = Vector2(mid, north_y)
	_world.add_child(door)
	_caption(Vector2(mid - 28, o.y + 6), Loc.t("world.door"))


func _run_wall(a: Vector2, b: Vector2, k: int) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 8.0:
		return
	var dir := delta / length
	var count := maxi(1, int(round(length / 64.0)))
	var each := length / float(count)
	for i in count:
		var spr := Vox.sprite("wall", k)
		spr.z_index = -5
		spr.position = a + dir * (each * (float(i) + 0.5))
		_world.add_child(spr)


func _restock(r: Rect2, cat: String, default_sku: String = "") -> Node2D:
	_obstacles.append(r)
	var node: StaticBody2D = RestockScript.new()
	_fit_body(node, r, "restock_" + cat, 0, 2)
	node.body = node.get_node("Body")
	node.label = _caption(r.position + Vector2(4, 18), "")
	node.setup(cat)
	## Must be in-tree before apply_default_sku — skus() reads game state via the tree.
	_world.add_child(node)
	node.apply_default_sku(default_sku)
	node.pull_stock()
	return node


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
	match posmod(rot, 4):
		1:
			return Vector2.RIGHT
		2:
			return Vector2.DOWN
		3:
			return Vector2.LEFT
		_:
			return Vector2.UP


func _make_shelf(r: Rect2, cat: String, index: int, rot: int, cap: int = Tuning.SHELF_CAP) -> Node2D:
	_obstacles.append(r)
	var node: StaticBody2D = ShelfScript.new()
	node.category = cat
	node.capacity = cap
	node.shelf_index = index
	node.net_shelf_id = _next_net_shelf_id
	_next_net_shelf_id += 1
	node.facing = _facing(rot)
	_fit_body(node, r, "shelf_" + cat, rot, 2)
	node.body = node.get_node("Body")
	var lab := Label.new()
	lab.position = Vector2(-58, -18)
	UiFont.apply_label(lab, UiFont.WORLD)
	lab.add_theme_color_override("font_color", Color("fff4c2"))
	lab.add_theme_color_override("font_outline_color", Color("121212"))
	lab.add_theme_constant_override("outline_size", 5)
	node.add_child(lab)
	node.label = lab
	_world.add_child(node)
	node._refresh()
	_register_shelf(node)
	return node


func _make_cashier(r: Rect2, rot: int, index: int) -> Node2D:
	_obstacles.append(r)
	var node: StaticBody2D = CashierScript.new()
	_fit_body(node, r, "register", rot, 2)
	node.register_index = index
	node.set_facing(_facing(rot))
	node.label = _caption(r.position + Vector2(8, 4), "")
	_world.add_child(node)
	cashiers.append(node)
	return node


func _dirt_cell_key(p: Vector2) -> int:
	var cx := int(floor(p.x / DIRT_CELL))
	var cy := int(floor(p.y / DIRT_CELL))
	return cx + cy * 4096


func _mark_dirt_rect_cells(r: Rect2, blocked: bool) -> void:
	var grow := r.grow(18.0)
	var x0 := int(floor(grow.position.x / DIRT_CELL))
	var y0 := int(floor(grow.position.y / DIRT_CELL))
	var x1 := int(floor(grow.end.x / DIRT_CELL))
	var y1 := int(floor(grow.end.y / DIRT_CELL))
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var key := x + y * 4096
			if blocked:
				_dirt_block_cells[key] = int(_dirt_block_cells.get(key, 0)) + 1
			else:
				var n := int(_dirt_block_cells.get(key, 0)) - 1
				if n <= 0:
					_dirt_block_cells.erase(key)
				else:
					_dirt_block_cells[key] = n


func _rebuild_dirt_block_cells() -> void:
	_dirt_block_cells.clear()
	_mark_dirt_rect_cells(Rect2(door_pos() + Vector2(-70, -20), Vector2(140, 110)), true)
	for o in _obstacles:
		_mark_dirt_rect_cells(o, true)
	for d in _dirts:
		if d != null and is_instance_valid(d):
			_mark_dirt_rect_cells(Rect2(d.global_position - Tuning.DIRT_SIZE * 0.5, Tuning.DIRT_SIZE), true)


func _try_spawn_dirt() -> void:
	if _dirts.size() >= Tuning.DIRT_CAP:
		return
	if _dirt_block_cells.is_empty() and not _obstacles.is_empty():
		_rebuild_dirt_block_cells()
	var size := Tuning.DIRT_SIZE
	## Sample free coarse cells first; full rect check only on candidates.
	for _i in 12:
		var origin := FLOOR_ORIGIN + Vector2(
			randf_range(36.0, FLOOR_SIZE.x - size.x - 36.0),
			randf_range(48.0, FLOOR_SIZE.y - size.y - 36.0)
		)
		var center := origin + size * 0.5
		if _dirt_block_cells.has(_dirt_cell_key(center)):
			continue
		var r := Rect2(origin, size)
		if _blocked_rect(r):
			continue
		_spawn_dirt(r, Tuning.random_dirt_type())
		return


func _blocked_rect(r: Rect2) -> bool:
	var grow := r.grow(18.0)
	var door := Rect2(door_pos() + Vector2(-70, -20), Vector2(140, 110))
	if grow.intersects(door):
		return true
	for d in _dirts:
		if not is_instance_valid(d):
			continue
		var other := Rect2(d.global_position - Tuning.DIRT_SIZE * 0.5, Tuning.DIRT_SIZE).grow(24.0)
		if grow.intersects(other):
			return true
	## Obstacles last (largest list).
	for o in _obstacles:
		if grow.intersects(o):
			return true
	return false


func _spawn_dirt(r: Rect2, dtype: String) -> void:
	var area: Area2D = DirtScript.new()
	area.setup(dtype, r.size)
	area.global_position = r.position + r.size * 0.5
	_world.add_child(area)
	_dirts.append(area)
	_add_interactable(area)
	_mark_dirt_rect_cells(r, true)
	area.tree_exiting.connect(_on_dirt_gone.bind(area))
	_register_net_agent(area, "dirt", {
		"dirt_type": dtype,
		"sx": r.size.x,
		"sy": r.size.y,
	})
	SfxBus.play("sfx_dirt_spawn")


func _on_dirt_gone(area: Node2D) -> void:
	if area != null and is_instance_valid(area):
		_mark_dirt_rect_cells(Rect2(area.global_position - Tuning.DIRT_SIZE * 0.5, Tuning.DIRT_SIZE), false)
	_dirts.erase(area)
	_remove_interactable(area)


func _add_interactable(node: Node2D) -> void:
	if _player == null:
		return
	if not _player.interactables.has(node):
		_player.interactables.append(node)


func _remove_interactable(node: Node2D) -> void:
	if _player == null:
		return
	_player.interactables.erase(node)


func spawn_dropped_box(
	pos: Vector2,
	sku: String,
	n: int,
	toss_dir: Vector2 = Vector2.ZERO,
	toss_dist: float = -1.0,
	on_landed: Callable = Callable(),
	land_nudge: Vector2 = Vector2.ZERO,
) -> void:
	var dest := pos + Tuning.drop_offset(toss_dir, toss_dist)
	## Instant place when no flight needed (e.g. legacy callers).
	if not on_landed.is_valid() and toss_dir.length_squared() < 0.0001:
		_place_dropped_box(dest + land_nudge, sku, n)
		return
	var sniper_guest: Node2D = null
	var sniper_thief: Node2D = null
	var sniper_shelf: Node2D = null
	if toss_dir.length_squared() > 0.0001 and _player != null:
		## Priority when several snipers are armed: thief → guest → shelf.
		if _player.has_method("sniper_thief_active") and bool(_player.call("sniper_thief_active")):
			sniper_thief = _sniper_thief_for(pos)
			if sniper_thief != null:
				dest = _sniper_thief_drop_pos(sniper_thief)
		if sniper_thief == null and _player.has_method("sniper_guest_active") and bool(_player.call("sniper_guest_active")):
			sniper_guest = _sniper_guest_for(sku, pos)
			if sniper_guest != null:
				dest = _sniper_guest_drop_pos(sniper_guest)
		if (
			sniper_thief == null
			and sniper_guest == null
			and _player.has_method("sniper_shelf_active")
			and bool(_player.call("sniper_shelf_active"))
		):
			sniper_shelf = _sniper_shelf_for(sku, pos)
			if sniper_shelf != null:
				dest = _sniper_drop_pos(sniper_shelf)
	## Optional side offset (投籃高手第二件) after sniper dest so piles do not stack.
	dest += land_nudge
	_emit_net_flight(sku, n, pos, dest, Tuning.DROP_FLIGHT_SEC)
	var flight: Node2D = DropFlightScript.new()
	flight.setup(sku, pos, dest, Tuning.DROP_FLIGHT_SEC, n)
	_world.add_child(flight)
	flight.finished.connect(func() -> void:
		if sniper_thief != null and is_instance_valid(sniper_thief):
			_resolve_sniper_thief_landing(sniper_thief, dest, sku, n, toss_dir)
		elif sniper_guest != null and is_instance_valid(sniper_guest):
			_resolve_sniper_guest_landing(sniper_guest, dest, sku, n)
		elif sniper_shelf != null and is_instance_valid(sniper_shelf):
			_resolve_sniper_landing(sniper_shelf, dest, sku, n)
		else:
			_resolve_toss_landing(pos, dest, sku, n, toss_dir)
		if on_landed.is_valid():
			on_landed.call()
	)


## Scatter cart piles from `origin` with flight anim; destinations do not overlap.
func spawn_loot_scatter(
	origin: Vector2,
	piles: Array,
	min_r: float,
	max_r: float,
) -> void:
	if piles.is_empty():
		return
	SfxBus.play("sfx_loot_scatter")
	var dests := Tuning.loot_scatter_positions(origin, piles.size(), min_r, max_r)
	for i in piles.size():
		var pile: Dictionary = piles[i]
		var sku := String(pile.get("sku", ""))
		var n := int(pile.get("n", 0))
		if sku == "" or n <= 0:
			continue
		var dest: Vector2 = dests[i] if i < dests.size() else origin + Vector2(0, Tuning.LOOT_SCATTER_MELEE_MIN)
		var dur := Tuning.LOOT_SCATTER_FLIGHT_SEC + float(i) * 0.04
		_spawn_box_flight(origin, dest, sku, n, dur, Callable())


## Instant foot-drop of loot piles at `origin` (box-hit KO — no scatter flight).
func spawn_loot_inplace(origin: Vector2, piles: Array) -> void:
	if piles.is_empty():
		return
	SfxBus.play("sfx_loot_inplace")
	var dests := Tuning.loot_scatter_positions(
		origin, piles.size(), 0.0, Tuning.LOOT_INPLACE_MAX
	)
	for i in piles.size():
		var pile: Dictionary = piles[i]
		var sku := String(pile.get("sku", ""))
		var n := int(pile.get("n", 0))
		if sku == "" or n <= 0:
			continue
		var dest: Vector2 = dests[i] if i < dests.size() else origin
		_place_dropped_box(dest, sku, n)


func _spawn_box_flight(
	from: Vector2,
	to: Vector2,
	sku: String,
	n: int,
	duration: float,
	on_landed: Callable,
) -> void:
	_emit_net_flight(sku, n, from, to, duration)
	var flight: Node2D = DropFlightScript.new()
	flight.setup(sku, from, to, duration, n)
	_world.add_child(flight)
	flight.finished.connect(func() -> void:
		_place_dropped_box(to, sku, n)
		if on_landed.is_valid():
			on_landed.call()
	)


func _emit_net_flight(sku: String, n: int, from: Vector2, to: Vector2, duration: float) -> void:
	if not SessionService.is_networked() or not SessionService.is_server():
		return
	SessionService.broadcast_flight({
		"sku": sku,
		"n": n,
		"fx": from.x,
		"fy": from.y,
		"tx": to.x,
		"ty": to.y,
		"dur": duration,
	})


## Directional toss: thief hit → KO; else matching shelf restock; else floor.
func _resolve_toss_landing(
	from: Vector2, dest: Vector2, sku: String, n: int, toss_dir: Vector2
) -> void:
	if n <= 0:
		return
	if toss_dir.length_squared() < 0.0001:
		_place_dropped_box(dest, sku, n)
		return
	var thief := _thief_for_toss(from, dest)
	if thief != null:
		## Thrown box lands at the hit; KO drops stolen goods in place.
		_place_dropped_box(thief.global_position + Tuning.DROP_FEET_OFFSET, sku, n)
		if _player and _player.has_method("apply_toss_ko"):
			_player.call("apply_toss_ko", thief, toss_dir)
		return
	var guest := _guest_for_toss(from, dest)
	if guest != null:
		_resolve_toss_guest(guest, dest, sku, n)
		return
	var shelf := _shelf_for_toss(dest, sku)
	if shelf == null:
		var clone := _clone_for_toss(from, dest)
		if clone != null:
			_resolve_toss_clone(clone, sku, n)
			return
		_place_dropped_box(dest, sku, n)
		return
	var placed := int(shelf.call("add_items", sku, n))
	if placed <= 0:
		_place_dropped_box(dest, sku, n)
		return
	SfxBus.play("sfx_box_shelf_toss")
	var left := n - placed
	if _player:
		if left <= 0:
			_player.log_line.emit(
				Loc.t("log.demo.toss_shelved", [Tuning.sku_name(sku), placed])
			)
		else:
			_player.log_line.emit(
				Loc.t("log.demo.toss_shelved_drop", [Tuning.sku_name(sku), placed, left])
			)
	if left > 0:
		_place_dropped_box(dest, sku, left)



func _clone_for_toss(from: Vector2, dest: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := Tuning.DROP_GUEST_HIT_RADIUS
	for c in shadow_clones():
		if c == null or not is_instance_valid(c):
			continue
		if c.get("_vanishing"):
			continue
		var p: Vector2 = c.global_position
		var d := minf(_dist_point_to_segment(p, from, dest), dest.distance_to(p))
		if d <= best_d:
			best_d = d
			best = c
	return best


func _resolve_toss_clone(clone: Node2D, sku: String, n: int) -> void:
	if clone.has_method("apply_toss_hit"):
		clone.call("apply_toss_hit")
	_place_dropped_box(clone.global_position + Tuning.DROP_FEET_OFFSET, sku, n)
	if _player:
		_player.log_line.emit(
			Loc.t("log.demo.toss_clone", [Tuning.sku_name(sku), n])
		)


func _guest_for_toss(from: Vector2, dest: Vector2) -> Node2D:
	if _customers == null:
		return null
	var best: Node2D = null
	var best_d := Tuning.DROP_GUEST_HIT_RADIUS
	for c in _customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## Ops FloatText siblings under Customers lack guest props → bool(null) crash.
		if not c.has_method("occupies_store"):
			continue
		if c.is_thief:
			continue
		var st: int = c.state
		if st == 7 or st == 9 or st == 8:
			continue
		var p: Vector2 = c.global_position
		var d := minf(_dist_point_to_segment(p, from, dest), dest.distance_to(p))
		if d <= best_d:
			best_d = d
			best = c
	return best


func _resolve_toss_guest(guest: Node2D, dest: Vector2, sku: String, n: int) -> void:
	var before := 0
	if guest != null and guest.get("shopping") != null:
		before = int((guest.shopping as Array).size())
	var taken := 0
	if guest.has_method("accept_toss_box"):
		taken = int(guest.call("accept_toss_box", sku, n))
	var toss_seat := 0
	if _player != null:
		toss_seat = int(_player.seat_id)
	if taken > 0:
		var left := n - taken
		SfxBus.play("sfx_box_hit_guest_ok")
		if _player:
			_player.log_line.emit(
				Loc.t("log.demo.toss_guest_ok", [
					Tuning.sku_name(sku), taken,
					(Loc.t("log.demo.toss_remain", [left]) if left > 0 else ""),
				])
			)
		if left > 0:
			_place_dropped_box(dest, sku, left)
		var perfect: bool = before >= 1 and guest != null and guest.get("shopping") != null and bool(guest.shopping.is_empty())
		if perfect and guest.has_method("apply_combo_bonus"):
			guest.call("apply_combo_bonus")
		combo_note_qualify(toss_seat)
		if perfect:
			combo_note_perfect(toss_seat)
		note_deliver(toss_seat, "toss", 1, perfect)
		return
	if guest.has_method("apply_toss_reject"):
		guest.call("apply_toss_reject", sku)
	SfxBus.play("sfx_box_hit_guest_reject")
	_place_dropped_box(dest, sku, n)
	combo_break_personal(toss_seat)
	if _player:
		_player.log_line.emit(Loc.t("log.demo.toss_guest_reject"))


## Active thief nearest the flight segment / landing within hit radius.
func _thief_for_toss(from: Vector2, dest: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := Tuning.DROP_THIEF_HIT_RADIUS
	for t in thieves():
		if t == null or not is_instance_valid(t):
			continue
		if not t.has_method("is_active_thief") or not bool(t.call("is_active_thief")):
			continue
		var p: Vector2 = t.global_position
		var d := minf(_dist_point_to_segment(p, from, dest), dest.distance_to(p))
		if d <= best_d:
			best_d = d
			best = t
	return best


func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Nearest active thief. No target → caller keeps the normal toss.
func _sniper_thief_for(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for t in thieves():
		if t == null or not is_instance_valid(t):
			continue
		if not t.has_method("is_active_thief") or not bool(t.call("is_active_thief")):
			continue
		var d := from.distance_squared_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best


func _sniper_thief_drop_pos(thief: Node2D) -> Vector2:
	return thief.global_position + Tuning.DROP_FEET_OFFSET


func _resolve_sniper_thief_landing(
	thief: Node2D, dest: Vector2, sku: String, n: int, toss_dir: Vector2
) -> void:
	if n <= 0:
		return
	## Thief fled / became uncatchable while the box was in the air.
	if not thief.has_method("is_active_thief") or not bool(thief.call("is_active_thief")):
		_place_dropped_box(dest, sku, n)
		if _player:
			_player.log_line.emit(
				Loc.t("log.demo.sniper_thief_gone", [Tuning.sku_name(sku), n])
			)
		return
	## Hit lands at the thief; whole throw drops (thief does not take shopping).
	_place_dropped_box(thief.global_position + Tuning.DROP_FEET_OFFSET, sku, n)
	if _player and _player.has_method("apply_toss_ko"):
		_player.call("apply_toss_ko", thief, toss_dir)
	elif _player:
		_player.log_line.emit(
			Loc.t("log.demo.sniper_thief_hit", [Tuning.sku_name(sku), n])
		)


## Guests who can still take `sku` from their shopping list. Nearest first.
## No target → caller keeps the normal toss. Unlike shelf sniper, there is no
## "fly to a full guest and dump beside them" fallback.
func _sniper_guest_for(sku: String, from: Vector2) -> Node2D:
	if _customers == null or sku == "":
		return null
	var best: Node2D = null
	var best_d := INF
	for c in _customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## Skip FloatText / non-guest children before any Object.get coercions.
		if not c.has_method("can_receive_delivery"):
			continue
		if c.is_thief:
			continue
		if not bool(c.call("can_receive_delivery")):
			continue
		if _guest_wants_sku(c, sku) <= 0:
			continue
		var d := from.distance_squared_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


func _guest_wants_sku(guest: Node2D, sku: String) -> int:
	var shopping = guest.get("shopping")
	if not (shopping is Array):
		return 0
	var want := 0
	for s in shopping:
		if String(s) == sku:
			want += 1
	return want


func _sniper_guest_drop_pos(guest: Node2D) -> Vector2:
	return guest.global_position + Tuning.DROP_FEET_OFFSET


func _resolve_sniper_guest_landing(guest: Node2D, dest: Vector2, sku: String, n: int) -> void:
	if n <= 0:
		return
	## Guest may have finished shopping while the box was in the air.
	if not guest.has_method("can_receive_delivery") or not bool(guest.call("can_receive_delivery")) or _guest_wants_sku(guest, sku) <= 0:
		_place_dropped_box(dest, sku, n)
		if _player:
			_player.log_line.emit(
				Loc.t("log.demo.sniper_guest_gone", [Tuning.sku_name(sku), n])
			)
		return
	var before := 0
	if guest.get("shopping") != null:
		before = int((guest.shopping as Array).size())
	var taken := 0
	if guest.has_method("accept_toss_box"):
		taken = int(guest.call("accept_toss_box", sku, n))
	var left := n - taken
	var toss_seat := 0
	if _player != null:
		toss_seat = int(_player.seat_id)
	if taken > 0:
		SfxBus.play("sfx_box_hit_guest_ok")
		var perfect: bool = before >= 1 and bool(guest.shopping.is_empty())
		if perfect and guest.has_method("apply_combo_bonus"):
			guest.call("apply_combo_bonus")
		combo_note_qualify(toss_seat)
		if perfect:
			combo_note_perfect(toss_seat)
		note_deliver(toss_seat, "toss", 1, perfect)
		if _player:
			if left <= 0:
				_player.log_line.emit(
					Loc.t("log.demo.sniper_guest_ok", [Tuning.sku_name(sku), taken])
				)
			else:
				_player.log_line.emit(
					Loc.t("log.demo.sniper_guest_partial", [Tuning.sku_name(sku), taken, left])
				)
	elif _player:
		_player.log_line.emit(
			Loc.t("log.demo.sniper_guest_gone", [Tuning.sku_name(sku), n])
		)
	if left > 0:
		_place_dropped_box(dest, sku, left)


## Same-SKU shelves only. Prefer the nearest with free space; otherwise the nearest full one.
func _sniper_shelf_for(sku: String, from: Vector2) -> Node2D:
	var list = _shelves_by_sku.get(sku)
	if list == null:
		return null
	var best_open: Node2D = null
	var best_open_d := INF
	var best_any: Node2D = null
	var best_any_d := INF
	for s in list:
		if s == null or not is_instance_valid(s):
			continue
		if String(s.get("sku")) != sku or int(s.get("count")) <= 0:
			continue
		var d := from.distance_squared_to(s.global_position)
		if d < best_any_d:
			best_any_d = d
			best_any = s
		if s.has_method("can_accept") and bool(s.call("can_accept", sku)) and d < best_open_d:
			best_open_d = d
			best_open = s
	return best_open if best_open != null else best_any


func _sniper_drop_pos(shelf: Node2D) -> Vector2:
	if shelf.has_method("stand_position"):
		return shelf.call("stand_position")
	return shelf.global_position + Vector2(0.0, 48.0)


func _resolve_sniper_landing(shelf: Node2D, dest: Vector2, sku: String, n: int) -> void:
	if n <= 0:
		return
	var placed := 0
	if shelf.has_method("can_accept") and bool(shelf.call("can_accept", sku)) and shelf.has_method("add_items"):
		placed = int(shelf.call("add_items", sku, n))
	var left := n - placed
	if placed > 0:
		SfxBus.play("sfx_box_shelf_toss")
		if _player:
			if left <= 0:
				_player.log_line.emit(
					Loc.t("log.demo.sniper_shelf_ok", [Tuning.sku_name(sku), placed])
				)
			else:
				_player.log_line.emit(
					Loc.t("log.demo.sniper_shelf_partial", [Tuning.sku_name(sku), placed, left])
				)
	elif _player:
		_player.log_line.emit(
			Loc.t("log.demo.sniper_shelf_full", [Tuning.sku_name(sku), n])
		)
	if left > 0:
		_place_dropped_box(dest, sku, left)


## Nearest shelf that can accept `sku` and sits under the toss landing.
func _shelf_for_toss(dest: Vector2, sku: String) -> Node2D:
	var best: Node2D = null
	var best_d := Tuning.DROP_SHELF_HIT_RADIUS
	var cat := Tuning.category_of(sku)
	## Prefer indexed stocked shelves + empty shelves of matching category.
	var candidates: Array = []
	var stocked = _shelves_by_sku.get(sku)
	if stocked != null:
		for s in stocked:
			candidates.append(s)
	var empties = _empty_by_cat.get(cat)
	if empties != null:
		for s in empties:
			candidates.append(s)
	if candidates.is_empty():
		candidates = shelves
	for s in candidates:
		if s == null or not is_instance_valid(s):
			continue
		if not s.has_method("can_accept") or not bool(s.call("can_accept", sku)):
			continue
		var shelf_sku := String(s.get("sku"))
		if shelf_sku != "" and shelf_sku != sku:
			continue
		var d := dest.distance_to(s.global_position)
		if d <= best_d:
			best_d = d
			best = s
	return best


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


func _place_dropped_box(dest: Vector2, sku: String, n: int) -> void:
	SfxBus.play("sfx_box_land")
	var drop: Area2D = DroppedBoxScript.new()
	drop.setup(sku, n)
	drop.global_position = dest
	_world.add_child(drop)
	_add_interactable(drop)
	drop.tree_exiting.connect(func() -> void: _remove_interactable(drop))
	_register_net_agent(drop, "drop", {"sku": sku, "n": n})


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
	SessionService.broadcast_carry_state({
		"seats": [{"seat": seat_id, "items": items}],
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
		rows.append({"seat": int(p.seat_id), "items": items})
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
		## Absolute Host snapshot: puppets always; owned seats soft-reconcile (skip if equal).
		inv.call("apply_net_items", items)


func _solid(r: Rect2) -> void:
	_obstacles.append(r)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	col.shape = shape
	body.add_child(col)
	_world.add_child(body)


func _fit_body(body: StaticBody2D, r: Rect2, model_id: String, rot: int, layer: int = 1) -> void:
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var spr := Vox.sprite(model_id, Vox.k_from_rot(rot))
	spr.name = "Body"
	Vox.fit(spr, r.size)
	body.add_child(spr)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	col.shape = shape
	body.add_child(col)


func _caption(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.z_index = 3
	UiFont.apply_label(l, UiFont.WORLD)
	l.add_theme_color_override("font_color", Color("fff4c2"))
	l.add_theme_color_override("font_outline_color", Color("121212"))
	l.add_theme_constant_override("outline_size", 5)
	_world.add_child(l)
	return l


func deploy_universal_cannon(at: Vector2, level: int, seat: int) -> Node2D:
	if _world == null or phase not in ["open", "restock"]:
		return null
	# Defensive ownership gate in addition to the player's runtime reference.
	for child in _world.get_children():
		if str(child.get("kind")) == "universal_cannon" and child.owner_seat == seat and not child.dismissed:
			return child
	var cannon: Node2D = preload("res://scripts/universal_cannon.gd").new()
	cannon.host = self
	cannon.level = clampi(level, 1, 3)
	cannon.owner_seat = seat
	_world.add_child(cannon)
	cannon.global_position = at
	for player in _players:
		if not player.interactables.has(cannon):
			player.interactables.append(cannon)
	_register_net_agent(cannon, "universal_cannon", {
		"owner_seat": seat,
		"level": cannon.level,
		"ammo_n": 0,
		"sku": "",
	})
	return cannon


func deploy_shelf_cannon(at: Vector2, level: int, seat: int) -> Node2D:
	if _world == null or phase not in ["open", "restock"]:
		return null
	for child in _world.get_children():
		if str(child.get("kind")) == "shelf_cannon" and child.owner_seat == seat and not child.dismissed:
			return child
	var cannon: Node2D = preload("res://scripts/shelf_cannon.gd").new()
	cannon.host = self
	cannon.level = clampi(level, 1, 3)
	cannon.owner_seat = seat
	_world.add_child(cannon)
	cannon.global_position = at
	for player in _players:
		if not player.interactables.has(cannon):
			player.interactables.append(cannon)
	_register_net_agent(cannon, "shelf_cannon", {
		"owner_seat": seat,
		"level": cannon.level,
		"ammo_n": 0,
		"sku": "",
	})
	return cannon


func deploy_calm_zone(at: Vector2, level: int, seat: int) -> Node2D:
	if _world == null or phase not in ["open", "restock"]:
		return null
	if SessionService.is_networked() and SessionService.is_client():
		return null
	var zone: Node2D = preload("res://scripts/calm_zone.gd").new()
	zone.host = self
	zone.level = clampi(level, 1, 3)
	zone.owner_seat = seat
	_world.add_child(zone)
	zone.global_position = at
	_register_net_agent(zone, "calm_zone", {
		"owner_seat": seat,
		"level": zone.level,
	})
	return zone


func _remove_cannon_interactable(cannon: Node2D) -> void:
	var lock = get_node_or_null("/root/InteractLock")
	if lock != null:
		var seat: int = lock.holder_of(cannon)
		if seat >= 0:
			lock.release(cannon, seat)
	for player in _players:
		player.interactables.erase(cannon)
		if player.target == cannon:
			player._reset_hold()
			player.target = null


func dismiss_universal_cannons() -> void:
	if _world == null:
		return
	for child in _world.get_children():
		if str(child.get("kind")) == "universal_cannon":
			child.dismiss()


func dismiss_shelf_cannons() -> void:
	if _world == null:
		return
	for child in _world.get_children():
		if str(child.get("kind")) == "shelf_cannon":
			child.dismiss()


func cannon_hit_thief(thief: Node2D, seat: int, direction: Vector2) -> void:
	if not is_instance_valid(thief) or not thief.is_active_thief():
		return
	# Resolve state immediately so concurrent projectiles cannot count the KO twice.
	thief.ko_box_hit_and_flee(direction)
	record_caught(seat)
	SfxBus.play("sfx_box_hit_thief")
	play_ko_banner()
	for player in _players:
		if player.target == thief and player._fighting:
			player._end_fight(true)
