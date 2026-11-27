extends RefCounted
## Startup wiring and per-frame ticks extracted from player.gd (#175).
## Host-bound: call bind(player) from Player._ready. State stays on the player host.

const CircleScript = preload("res://scripts/loading_circle.gd")
const PromptScript = preload("res://scripts/command_prompt.gd")
const MenuScript = preload("res://scripts/skill_menu.gd")
const BoxStackScript = preload("res://scripts/box_stack.gd")
const BagCasterScript = preload("res://scripts/player/bag_caster.gd")
const CarryCasterScript = preload("res://scripts/player/carry_caster.gd")
const FloorBarsScript = preload("res://scripts/player/player_floor_bars.gd")
const CarryStripScript = preload("res://scripts/player/player_carry_strip.gd")
const BagDiamondScript = preload("res://scripts/player/player_bag_diamond.gd")
const SkillPipsScript = preload("res://scripts/player/player_skill_pips.gd")
const Tuning = preload("res://scripts/tuning.gd")

var host: CharacterBody2D = null


func bind(player: CharacterBody2D) -> void:
	host = player


func ready() -> void:
	host.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	host.stamina = host.stamina_max_now()
	host._circle = CircleScript.new()
	host.add_child(host._circle)
	host._prompt = PromptScript.new()
	host.add_child(host._prompt)
	host._menu = MenuScript.new()
	host.add_child(host._menu)
	var stack: Variant = BoxStackScript.new()
	stack.position = Vector2(0, -6)
	stack.setup(host.inventory)
	host.add_child(stack)
	if host.inventory.has_signal("changed"):
		host.inventory.changed.connect(host._mark_hud_dirty)
	host._toss.bind(host)
	host._fight_ctrl.bind(host)
	host._skills.bind(host)
	host._checkout.bind(host)
	host._view.bind(host)
	host._interact.bind(host)
	host._work.bind(host)
	host._input_ctrl.bind(host)
	host._bags = BagCasterScript.new(host)
	host._bags.ensure_menu()
	host._carries = CarryCasterScript.new(host)
	host._carries.ensure_menu()
	host._floor_bars = FloorBarsScript.new()
	host._floor_bars.setup(host)
	host.add_child(host._floor_bars)
	host._carry_strip = CarryStripScript.new()
	host._carry_strip.setup(host)
	host.add_child(host._carry_strip)
	host._bag_diamond = BagDiamondScript.new()
	host._bag_diamond.setup(host)
	host.add_child(host._bag_diamond)
	host._skill_pips = SkillPipsScript.new()
	host._skill_pips.setup(host)
	host.add_child(host._skill_pips)
	host._setup_drop_aim()
	host._setup_must_deliver_ring()
	host._setup_magneto_ring()
	host._setup_monk_tornado()
	host._setup_crowd_say()
	host._refresh_passive_checkout()

func physics_process(delta: float) -> void:
	if host.is_net_puppet():
		## Presentation only — Host already wrote facing／position; still refresh Vox.
		host.velocity = Vector2.ZERO
		if host._net_puppet_pos == Vector2.INF:
			host._net_puppet_moving = false
		else:
			host._net_puppet_moving = host.global_position.distance_squared_to(host._net_puppet_pos) > 2.25
		host._net_puppet_pos = host.global_position
		host._sync_interact_glow()
		host._update_visuals()
		return
	if SeatTable.is_frozen(host.seat_id):
		host.velocity = Vector2.ZERO
		host._sync_interact_glow()
		host._update_visuals()
		return
	## Tutorial explain modal — freeze local play without get_tree().paused.
	if host.game != null and host.game.has_method("tutorial_freezes_play") and bool(host.game.tutorial_freezes_play()):
		host.velocity = Vector2.ZERO
		host._sync_interact_glow()
		host._update_visuals()
		return
	if host._asking_early():
		host.velocity = Vector2.ZERO
		host._sync_interact_glow()
		return
	if host._elite_focus_left > 0.0:
		host._elite_focus_left = maxf(0.0, host._elite_focus_left - delta)
		host.velocity = Vector2.ZERO
		tick_buffs(delta)
		tick_status(delta)
		host._tick_camera_shake(delta)
		host._sync_interact_glow()
		return
	if host._portal_beam_left > 0.0:
		host._tick_portal_beam(delta)
		host.velocity = Vector2.ZERO
		tick_buffs(delta)
		tick_status(delta)
		host._tick_camera_shake(delta)
		host._sync_interact_glow()
		host._update_visuals()
		return
	if host.has_meta("boss_cutscene_lock"):
		host.velocity = Vector2.ZERO
		tick_buffs(delta)
		tick_status(delta)
		host._tick_camera_shake(delta)
		host._sync_interact_glow()
		host._update_visuals()
		return
	tick_buffs(delta)
	tick_status(delta)
	if host._cast_pose_left > 0.0:
		host._cast_pose_left = maxf(0.0, host._cast_pose_left - delta)
	if host._deliver_pose_left > 0.0:
		host._deliver_pose_left = maxf(0.0, host._deliver_pose_left - delta)
	host.command_lock = (
		(host._long_committed and host._j_held and is_instance_valid(host.target) and host._obj_str(host.target, "kind") == "cashier")
		or is_instance_valid(host._self_repair_reg)
	) and not host.skill_menu_open and not host.ult_prep
	if not host.command_lock and not host.ult_prep:
		host._prompt.active = false
	## Dash/run via InputMap (face X / Space) — no RT dash.
	if host._k_held and not host._cancel_held and not host._cancel_drop_ready and not host.command_lock and not host.skill_menu_open and not host.bag_menu_open and not host.carry_menu_open and not host.ult_prep and not host._fighting and host._stun_left <= 0.0 and host._slip_left <= 0.0:
		host._k_time += delta
		if host._k_time >= Tuning.RUN_HOLD_THRESHOLD:
			host._running = host._dasher_active() or host.stamina > 1.0
			host._k_run_committed = true
	if host._cancel_held:
		host._tick_cancel_hold(delta)
	if host._toss_move_pause_left > 0.0:
		host._toss_move_pause_left = maxf(0.0, host._toss_move_pause_left - delta)
		host._running = false
		if not host._dashing and host._slip_left <= 0.0:
			host.velocity = Vector2.ZERO
	## Long-press aim only: freeze locomotion. In-flight boxes do not lock move.
	if host._cancel_drop_ready and host._slip_left <= 0.0:
		host._running = false
		host._dashing = false
		host.velocity = Vector2.ZERO
	host._tick_carry_select(delta)
	if host._l_held and host._sick_left <= 0.0 and host._stun_left <= 0.0:
		if host._skills != null and host._skills.has_method("tick_hold_open"):
			host._skills.tick_hold_open(delta)
		else:
			host._l_time += delta
	host._tick_skill_right_stick()
	if host._bags != null:
		host._bags.tick(delta)
	if host._carries != null:
		host._carries.tick(delta)
	## Pad LT/RT ult chord only on locally owned seats.
	if host.controls_locally() and host._round_active() and not host._asking_early():
		host._tick_triggers(delta)
	## Skill / ult / checkout dir modes: hard-stop so held WASD cannot coast.
	## Cooked craft also roots the player until done or cancel.
	if host._in_dir_mode() or host._move_locked_until_neutral or host._cooked_craft_stall != null:
		host._running = false
		if not host._dashing and host._slip_left <= 0.0:
			host.velocity = Vector2.ZERO
	if host._fighting:
		host.velocity = Vector2.ZERO
	elif host._slip_left > 0.0:
		tick_slip(delta)
	elif host._dashing:
		tick_dash(delta)
	else:
		tick_move(delta)
	poll_stick_cardinal()
	regen(delta)
	update_target()
	host._tick_cooked_craft(delta)
	host._tick_action(delta)
	tick_sweeping_monk(delta)
	host._sync_interact_glow()
	if host._circle:
		## Clean uses dirt StickHint (blue meter + stick), not the yellow hold Circle.
		if host._cleaning():
			host._circle.progress = 0.0
			host._circle.blocked = false
		else:
			host._circle.progress = host.hold_progress
			host._circle.blocked = host.blocked_mismatch
	if host._menu:
		## Host／他機 seat：邏輯可開選單瞄準，但不畫 radial（避免殘留 P2 選單）。
		host._menu.open = host.skill_menu_open and host.controls_locally()
		if host.skill_menu_open and host.controls_locally():
			var mfp: String = "%s|%s" % [str(host._cd), str(host._loadout())]
			if mfp != host._menu_fp:
				host._menu_fp = mfp
				host._menu.set_slots(host._loadout(), host._cd)
	sync_crowd_say()
	host._update_visuals()
	host._emit_stats_if_changed()

func tick_buffs(delta: float) -> void:
	var gone: Array[String] = []
	for id in host._buffs.keys():
		host._buffs[id] = float(host._buffs[id]) - delta
		if float(host._buffs[id]) <= 0.0:
			gone.append(String(id))
	var changed: bool = not gone.is_empty()
	for id in gone:
		if id == "the_world":
			SfxBus.play("sfx_ult_the_world_end")
		if id == "senior_cashier":
			host._senior_cashier_lv = 0
		if id == "checkout_rush":
			host._checkout_rush_lv = 0
		if id == "sweeping_monk":
			host._sync_monk_tornado(false)
		host._buffs.erase(id)
	for id in host._cd.keys():
		host._cd[id] = maxf(0.0, float(host._cd[id]) - delta)
	var keep_q: Array[String] = []
	for id in host._cust_speed_q:
		if host._buffs.has(id):
			keep_q.append(id)
	if keep_q.size() != host._cust_speed_q.size():
		changed = true
	host._cust_speed_q = keep_q
	if changed or not host._buff_cache_valid:
		host._cached_clock = host._world_clock_now()
		host._cached_cust_mult = host._customer_move_mult_now()
		host._buff_cache_valid = true
	host.clock_scale = host._cached_clock
	host.customer_move_mult = host._cached_cust_mult

func poll_stick_cardinal() -> void:
	# Analog only (touch stick / left stick). Discrete move_* taps are handled in _input.
	# Host remote seats: use intent remote_move (M2.5) — no local stick on this machine.
	if not host._in_dir_mode():
		host._cardinal_armed = true
		return
	var v: Vector2
	if SessionService.is_networked() and SessionService.is_server() and not host.controls_locally():
		v = host.remote_move
	else:
		v = host.stick_axis + host._joy_stick_vector()
	if v.length() < 0.42:
		host._cardinal_armed = true
		return
	if not host._cardinal_armed:
		return
	host._cardinal_armed = false
	var dir: int = 0
	if absf(v.x) > absf(v.y):
		dir = 3 if v.x > 0.0 else 2
	else:
		dir = 1 if v.y > 0.0 else 0
	host._try_dir(dir)

func tick_move(delta: float) -> void:
	var axis: Vector2 = host._move_axis()
	if axis != Vector2.ZERO:
		host.facing = axis
		if host._j_held and not host.command_lock and not host._shelving() and not host._cleaning():
			host._reset_hold()
	if host._can_slip():
		host._begin_slip()
		return
	var want_run: bool = host._running and axis != Vector2.ZERO
	var free_stam: bool = host._dasher_active()
	if want_run and not free_stam:
		if host.stamina <= 0.0:
			want_run = false
			host._running = false
		else:
			host.stamina = maxf(0.0, host.stamina - Tuning.RUN_STAMINA_PER_SEC * delta)
			host._regen_delay = Tuning.STAMINA_REGEN_DELAY
	var walk: float = Tuning.WALK_SPEED * Tuning.PLAYER_MOVE_MULT * host.speed_mult()
	var target_speed: Variant = walk * (Tuning.RUN_SPEED_MULT if want_run else 1.0)
	var speed_cap: Variant = Tuning.WALK_SPEED * Tuning.PLAYER_MOVE_MULT * Tuning.SPEED_MAX_MULT
	target_speed = clampf(target_speed, Tuning.SPEED_FLOOR, speed_cap)
	if axis == Vector2.ZERO:
		host.velocity = host.velocity.move_toward(Vector2.ZERO, walk * 8.0 * delta)
	else:
		host.velocity = axis * target_speed
		if host.velocity.length() > 8.0:
			SfxBus.play_foot(want_run)
			if host.inventory.count() > host.carry_cap():
				SfxBus.play_overcarry()
	host.move_and_slide()

func tick_dash(delta: float) -> void:
	host._dash_from = host.global_position
	host._dash_left -= delta
	var speed: Variant = Tuning.DASH_DISTANCE / Tuning.DASH_TIME
	host.velocity = host._dash_dir * speed
	host.move_and_slide()
	host._try_dash_thief()
	if host._can_slip():
		host._dashing = false
		host._begin_slip()
		return
	if host._dash_left <= 0.0:
		host._dashing = false
		host.velocity *= 0.35

func tick_slip(delta: float) -> void:
	host._slip_left -= delta
	var dist: Variant = Tuning.SLIP_BODY_LENGTHS * Tuning.BODY_LENGTH
	var dir: Vector2 = host.facing
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	host.velocity = dir.normalized() * (dist / Tuning.SLIP_TIME)
	host.move_and_slide()
	if host._slip_left <= 0.0:
		host.velocity = Vector2.ZERO
		host._stun_left = host._stun_pending
		SfxBus.play("sfx_move_stun")

func tick_status(delta: float) -> void:
	if host._stun_left > 0.0:
		host._stun_left = maxf(0.0, host._stun_left - delta)
		host.velocity = Vector2.ZERO
	if host._sick_left > 0.0:
		host._sick_left = maxf(0.0, host._sick_left - delta)
	if host._has_dirt_type(Tuning.DIRT_VOMIT) and not host._has_flag("ignore_vomit_sick"):
		if host._sick_left <= 0.0:
			host.log_line.emit(Loc.t("log.player.vomit"))
		host._sick_left = Tuning.SICK_SEC
	if host._has_dirt_type(Tuning.DIRT_TRASH) and not host._has_flag("ignore_trash_stamina"):
		host.stamina = maxf(0.0, host.stamina - Tuning.TRASH_STAMINA_PER_SEC * delta)
		host._regen_delay = Tuning.STAMINA_REGEN_DELAY
	if host._wave_vfx_cd > 0.0:
		host._wave_vfx_cd = maxf(0.0, host._wave_vfx_cd - delta)

func regen(delta: float) -> void:
	if host._dashing or host._slip_left > 0.0 or (host._running and host._move_axis() != Vector2.ZERO) or (host._has_dirt_type(Tuning.DIRT_TRASH) and not host._has_flag("ignore_trash_stamina")):
		return
	if host._regen_delay > 0.0:
		host._regen_delay -= delta
		return
	host.stamina = minf(host.stamina_max_now(), host.stamina + Tuning.STAMINA_REGEN_PER_SEC * delta)

func update_target() -> void:
	if host._fighting:
		return
	## Aim / slip / held interact: keep the action target (no full rescan).
	## In-flight toss does not freeze target scan.
	if host._j_held or host._cancel_drop_ready or host._slip_left > 0.0 or is_instance_valid(host._self_repair_reg):
		return
	var best: Node2D = host._preview_target()
	if host.target != best:
		if host._restock_picking and host.target != null and host._obj_str(host.target, "kind") in ["restock", "fish_tank"]:
			host.target.call("abort_pick")
		if host._cooked_picking and host.target != null and host._obj_str(host.target, "kind") == "cooked_stall":
			if host.target.has_method("abort_pick"):
				host.target.call("abort_pick")
		host._restock_picking = false
		host._restock_hold = 0.0
		host._cooked_picking = false
		host._cooked_hold = 0.0
		host._reset_hold()
		host._pickup_used = false
		host._hud_dirty = true
	host.target = best

func tick_sweeping_monk(delta: float) -> void:
	if host.buff_left("sweeping_monk") <= 0.05:
		host._sync_monk_tornado(false)
		return
	host._sync_monk_tornado(true)
	if host._monk_tornado != null:
		host._monk_tornado.rotation += delta * 7.5
	host._clear_dirt_in_monk_range()

func sync_crowd_say() -> void:
	## Hide during dash so「唔該借借」is not mistaken for a failed 衝刺交付.
	var on: bool = (not host._dashing) and host._crowd_near()
	if on and not host._crowd_active:
		SfxBus.play("sfx_move_crowd")
	host._crowd_active = on
	if host._crowd_say:
		host._crowd_say.visible = on
