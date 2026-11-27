extends RefCounted
## Day start / world rebuild peeled out of demo.gd (#148).

const Tuning = preload("res://scripts/tuning.gd")
const StateScript = preload("res://scripts/game_state.gd")
const PathfinderScript = preload("res://scripts/pathfinder.gd")
const OpsItems = preload("res://scripts/ops_items.gd")
const RatingRules = preload("res://scripts/session/rating_rules.gd")
const BgmBusScript = preload("res://scripts/bgm_bus.gd")

var host: Node


func bind(day_host: Node) -> void:
	host = day_host


func begin_day() -> void:
	host._clear_self_service_operation()
	if host._prep:
		host._prep.set_process_unhandled_input(false)
	if host._pause and host._pause.has_method("close_menu"):
		host._pause.close_menu()
	## Safety: leftover tree pause must never carry into ops.
	if host.get_tree() != null and host.get_tree().paused:
		host.get_tree().paused = false
	## Client applies host world snapshot before building the floor.
	## Stash home save first — live `state` becomes Host shop for presentation only.
	if SessionService.is_client():
		if host.state != null:
			SessionService.stash_client_home_save(host.state.to_dict())
		var snap: Dictionary = SessionService.take_pending_day_snapshot()
		var world = snap.get("world", {})
		if world is Dictionary and not world.is_empty():
			var err: String = host.state.from_dict(world)
			if err != "":
				push_warning("client day snapshot failed: %s" % err)
	host._clear_world()
	host._early_closed = false
	host._skip_xp = 0
	host.revenue = 0
	host.served = 0
	host.elite_served = 0
	host._elite_zoom_queue.clear()
	host._elite_zoom_busy = false
	host.angry_left = 0
	host.ops_rating = RatingRules.OPS_START
	host.stolen_count = 0
	host.stolen_value = 0
	host.thieves_caught = 0
	host.thieves_escaped = 0
	host.kind_converted_total = 0
	host.cleaned = 0
	var sn: int = maxi(1, SeatTable.seat_count)
	## Typed Array[int] on demo — bare [] assignment fails at runtime through host.
	host.seat_cleaned.clear()
	host.seat_served.clear()
	host.seat_caught.clear()
	host.seat_elite.clear()
	host.seat_kind_converted.clear()
	for _i in sn:
		host.seat_cleaned.append(0)
		host.seat_served.append(0)
		host.seat_caught.append(0)
		host.seat_elite.append(0)
		host.seat_kind_converted.append(0)
	host._settled = false
	host._closeout_ready_msec = 0
	host.real_time = 0.0
	host.game_hours = Tuning.GAME_START_HOUR
	host.hud_rev = 0
	host.phase = "restock"
	host._boss_world.clear()
	if host.state != null and host.state.has_method("is_boss_test_scenario") and bool(host.state.is_boss_test_scenario()):
		host._boss_world.configure("alien_tycoon")
	host._net_pres.clear()
	host._owned_host_pose.clear()
	host._net_accum = 0.0
	host._agent_xform_accum = 0.0
	var ComboState = preload("res://scripts/session/combo_state.gd")
	host._combo = ComboState.new()
	host._combo.reset(SeatTable.seat_count)
	host._setup_day_tasks()
	if host._tutorial != null:
		host._tutorial.setup(host.state)
		if not host._tutorial.progress_changed.is_connected(host._on_tutorial_progress):
			host._tutorial.progress_changed.connect(host._on_tutorial_progress)
		## Do not open／pause mid-build — wait until world／HUD exist (see end of begin_day).
	var il := host.get_node_or_null("/root/InteractLock")
	if il != null and il.has_method("clear"):
		il.clear()
	host._sfx_phase = "restock"
	SfxBus.play("sfx_phase_restock")
	var bgm_op := BgmBusScript.bus()
	if bgm_op:
		bgm_op.play_operation(true)
	host._spawn_in = 2.0
	host.clear_guest_dusk()
	host._clear_three_volley()
	host._dirt_spawn_in = host.dirt_spawn_interval()
	host._thief_spawn_in = host.state.thief_spawn_first()
	host._ops_item_spawn_in = OpsItems.SPAWN_FIRST_SEC
	host._ops_items.clear()
	host.FLOOR_SIZE = Vector2(host.state.grid_w, host.state.grid_h) * StateScript.CELL
	host._world = Node2D.new()
	host._world.name = "World"
	host._world.y_sort_enabled = true
	host.add_child(host._world)
	host.move_child(host._world, 0)
	host._floor()
	host._walls_and_door()
	var nodes: Array[Node2D] = []
	host._build_furniture(nodes)
	host.pathfinder = PathfinderScript.new()
	host.pathfinder.setup(host.FLOOR_ORIGIN, host.FLOOR_SIZE, host._obstacles)
	host._customers = Node2D.new()
	host._customers.name = "Customers"
	host._customers.y_sort_enabled = true
	host._world.add_child(host._customers)
	host._players.clear()
	var spawn0: Vector2 = host.FLOOR_ORIGIN + Vector2(host.FLOOR_SIZE.x * 0.5, host.FLOOR_SIZE.y - 80)
	for seat in SeatTable.seat_ids():
		var stats_src = host.state if seat == 0 else SeatTable.sheet_of(seat)
		if stats_src == null:
			stats_src = load("res://scripts/session/character_sheet.gd").from_game_state(host.state)
			SeatTable.set_sheet(seat, stats_src)
		## Bind guest_stats only for this machine's claim2 seat (local_index 1), not global seat 1.
		if SeatTable.seat_owned_locally(seat) and SeatTable.local_index_of(seat) == 1 and SeatTable.guest_stats == null:
			SeatTable.guest_stats = stats_src
		var spawn: Vector2 = spawn0 + Vector2(40.0 * float(seat), 0.0)
		host._spawn_seated_player(seat, stats_src, nodes, spawn)
	host._player = host._players[0] if not host._players.is_empty() else null
	## Soft collision exceptions between all seated players.
	for i in host._players.size():
		for j in range(i + 1, host._players.size()):
			var a: CharacterBody2D = host._players[i]
			var b: CharacterBody2D = host._players[j]
			if a and b:
				a.add_collision_exception_with(b)
				b.add_collision_exception_with(a)
	## Local seat for HUD／camera／prompts (Client is often seat 1+, not seat 0).
	for p in host._players:
		if p != null and SeatTable.seat_owned_locally(int(p.seat_id)):
			host._player = p
			break
	var cam := Camera2D.new()
	cam.zoom = Vector2(Tuning.CAMERA_ZOOM, Tuning.CAMERA_ZOOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.5
	if host._player:
		host._player.add_child(cam)
		cam.make_current()
	for p in host._players:
		if p != null:
			p.camera = cam
	if not PlatformServices.camera_view_changed.is_connected(host._on_camera_view_changed):
		PlatformServices.camera_view_changed.connect(host._on_camera_view_changed)
	host.apply_camera_view()
	host._hud = preload("res://scenes/hud.tscn").instantiate()
	host.add_child(host._hud)
	## setup binds every seat in `_players` (right panes + cast/log); primary = local seat.
	host._hud.setup(host, host._player)
	host._bind_player_task_signals()
	var pad = preload("res://scripts/touch_pad.gd").new()
	pad.name = "TouchPad"
	host.add_child(pad)
	pad.visible = InputMode.show_vj()
	pad.stick_changed.connect(func(axis: Vector2) -> void:
		var lp := _local_touch_player()
		if lp:
			lp.stick_axis = axis
	)
	pad.hold_changed.connect(func(action: String, pressed: bool) -> void:
		if host._early_open and pressed:
			if action == "interact":
				if host._early_focus == 0:
					host._confirm_early_close()
				else:
					host._decline_early_close()
			elif action == "cancel":
				host._decline_early_close()
			return
		if host.phase == "closed" and pressed and (action == "interact" or action == "cancel"):
			if host._closeout_input_ready():
				host._return_to_prep()
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
	if not InputMode.show_vj_changed.is_connected(host._on_show_vj_changed):
		InputMode.show_vj_changed.connect(host._on_show_vj_changed)
	if not InputMode.clear_virtual_holds.is_connected(host._clear_virtual_holds):
		InputMode.clear_virtual_holds.connect(host._clear_virtual_holds)
	## Clients skip clerk/dirt AI seeds — host owns world agents (§12 / listen-server).
	if host._tutorial != null and is_instance_valid(host._tutorial) and host._tutorial.has_method("clear_runtime_flags"):
		## Clear before dirt seed so `dirt_present` is re-armed for this day only.
		host._tutorial.clear_runtime_flags()
	if SessionService.is_server() or SessionService.is_local_transport():
		host._spawn_clerks()
		if host._boss_world.should_spawn_open_dirt():
			for i in Tuning.dirt_start(host._play_easy()):
				host._try_spawn_dirt()
		if host._hud != null and host._hud.has_method("setup_boss_progress") and host._boss_world.is_active():
			host._hud.call("setup_boss_progress", host._boss_world.progress_total())
		## Align client shelf／warehouse／carry／prompt presentation after world exists (M2.4／M2.6／M2.9).
		if SessionService.is_networked() and SessionService.is_server():
			host._dump_all_stock()
			host._dump_all_carry()
			host._dump_all_prompt()
			host._broadcast_day_hud_state()
			host._dump_all_skill_cds()
	else:
		## Apply spawn／flight／state RPCs that raced ahead of world build (M2.2～M2.9).
		host._flush_pending_agent_spawns()
		host._flush_pending_flights()
		host._flush_pending_agent_states()
		host._flush_pending_stock_states()
		host._flush_pending_carry_states()
		host._flush_pending_prompt_states()
		host._day_chrome.flush_pending_day_hud_states()
		host._day_chrome.flush_pending_day_clock_states()
		host._day_chrome.flush_pending_skill_cd_states()
	## Ops tutorial after world／HUD exist (director survives _clear_world).
	if host._tutorial != null and is_instance_valid(host._tutorial):
		host._tutorial.call_deferred("consider_ops")
	## Boss day: restock foreshadow dialog after HUD／world ready.
	if host._boss_world != null and host._boss_world.is_active():
		host.call_deferred("_boss_run_restock_intro")


func _local_touch_player() -> CharacterBody2D:
	for p in host._players:
		if p != null and is_instance_valid(p) and SeatTable.seat_owned_locally(int(p.seat_id)):
			return p
	return host._player
