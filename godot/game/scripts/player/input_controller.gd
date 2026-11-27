extends RefCounted
## Input hold edges, cancel, and move axis extracted from player.gd (#175).
## Host-bound: call bind(player) from Player._ready. State stays on the player host.

const Tuning = preload("res://scripts/tuning.gd")

var host: CharacterBody2D = null


func bind(player: CharacterBody2D) -> void:
	host = player


func set_hold(action: String, pressed: bool) -> void:
	## LAN Host applies intents every tick as levels — must edge-trigger.
	## Otherwise interact=false spam calls _do_short_interact every frame (auto-loot).
	match action:
		"interact":
			if host._interact_ignore_until_up:
				if pressed:
					return
				host._interact_ignore_until_up = false
				host._j_held = false
				host._j_time = 0.0
				host._long_committed = false
				host._deliver_done = false
				host._shelve_done = false
				host._checkout_hold_idle = false
				## Do not short-interact on the release that ends the latch.
				return
			if host._fighting:
				## Keep `_j_held` truthful during mash so fight-end knows if the
				## physical Interact is still down (vs already released).
				if pressed:
					if not host._fight_release:
						host._fight_tap()
					host._fight_release = true
					host._j_held = true
				else:
					host._fight_release = false
					host._j_held = false
				return
			if pressed:
				if host._j_held:
					return
				host._j_held = true
				host._j_time = 0.0
				host._long_committed = false
				host._deliver_done = false
				host._shelve_done = false
				host._checkout_hold_idle = false
				host._restock_hold = 0.0
				host._restock_aborted = false
				host._pickup_used = false
				host._no_queue_logged = false
			else:
				if not host._j_held:
					return
				## `_release_interact` still needs `_long_committed` to skip short-take.
				host._release_interact()
				host._j_held = false
				## Action finished / released — clear so a later short Cancel can toss.
				## (Clean/deliver used to leave `_long_committed` stuck until next Interact.)
				host._long_committed = false
				host._deliver_done = false
				host._shelve_done = false
				host._checkout_hold_idle = false
				host._reset_hold()
				host._pickup_used = false
				host._no_queue_logged = false
		"dash":
			if host.command_lock or host.skill_menu_open or host.bag_menu_open or host.carry_menu_open or host.ult_prep or host._fighting:
				return
			if pressed:
				if host._k_held:
					return
				host._k_held = true
				host._k_time = 0.0
				host._k_run_committed = false
			else:
				if not host._k_held:
					return
				## 輕放＝衝刺；已過門檻／committed 的這次按鍵不再補衝（起跑不會先衝一記）。
				if not host._k_run_committed and not host._running and host._k_time < Tuning.RUN_HOLD_THRESHOLD:
					host._try_dash()
				host._k_held = false
				host._k_run_committed = false
				host._running = false
		"skill":
			## LB → carry-select hold (expand strip; X/B cycle).
			if pressed and host._carry_select_held:
				return
			host._on_carry_select_hold(pressed)
		"bag_menu":
			## RB → skill ring long-press (action name historical).
			if pressed and host._l_held:
				return
			host._on_skill_hold(pressed)
		"carry_menu":
			## Face Y / U spare in ops.
			return
		"ult":
			## Keyboard K / touch ult button. Xbox pad uses LT+RT chord instead.
			## Edge-only: repeat ult=true intents must not re-fire prep.
			if pressed and host._u_held:
				return
			if pressed:
				host._ult_chord_active = false
			host._on_ult_hold(pressed)
		"cancel":
			if pressed:
				if host._cancel_held:
					return
				host._cancel_held = true
				host._cancel_time = 0.0
				host._cancel_drop_ready = false
				host._cancel_dropped = false
				host._cancel_drop_dir = Vector2.ZERO
				host._cancel_swallowed = false
				## Seed facing immediately so a standing short-tap still has a toss dir.
				host._sample_cancel_drop_dir()
				cancel_input()
			else:
				if not host._cancel_held:
					return
				host._cancel_held = false
				host._on_cancel_release()

func move_state() -> String:
	if host._stun_left > 0.0:
		return Loc.t("hud.move.stun")
	if host._slip_left > 0.0:
		return Loc.t("hud.move.slip")
	## Aim prep locks move; short-toss pause is a brief hitch (reuse drop_aim copy).
	if host._toss_move_pause_left > 0.0:
		return Loc.t("hud.move.drop_aim")
	if host._cancel_drop_ready and host._cancel_held and not host._cancel_dropped:
		return Loc.t("hud.move.drop_aim")
	if host._cancel_held and not host._cancel_dropped:
		return Loc.t("hud.move.drop_aim")
	if host.ult_prep:
		return Loc.t("hud.move.ult_cmd")
	if host._must_deliver_aim:
		return Loc.t("hud.move.must_deliver")
	if host._magneto_aim:
		return Loc.t("hud.move.magneto")
	if host.skill_menu_open:
		return Loc.t("hud.move.skill_menu")
	if host.bag_menu_open:
		return Loc.t("hud.move.bag_menu")
	if host.carry_menu_open:
		return Loc.t("hud.move.carry_menu")
	if host._restock_picking:
		return Loc.t("hud.move.pick_sku")
	if host._cooked_picking:
		return Loc.t("hud.move.cooked_craft")
	if host._cooked_craft_stall != null:
		return Loc.t("hud.move.cooked_busy")
	if host._cleaning():
		return Loc.t("hud.move.clean")
	if host._fighting:
		return Loc.t("hud.move.fight")
	if host.command_lock:
		return Loc.t("hud.move.checkout_cmd")
	if host._dashing:
		return "DASH"
	if host._running and host.velocity.length() > 8.0:
		return "RUN"
	if host.velocity.length() > 8.0:
		return "WALK"
	return "IDLE"

func input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not host.controls_locally():
		return
	## Let TutorialModal own A／方向 while explain pages are up.
	var game_freeze: Node = host._game()
	if (
		game_freeze != null
		and game_freeze.has_method("tutorial_freezes_play")
		and bool(game_freeze.tutorial_freezes_play())
	):
		return
	if not Controls.event_for_seat(event, host.seat_id):
		return
	# Early-close dialog and closeout own confirm / cancel.
	if host._asking_early():
		return
	if not host._round_active() and (event.is_action(Controls.INTERACT) or event.is_action(Controls.CANCEL)):
		return
	# Discrete directions only here; analog stick uses _poll_stick_cardinal.
	# Mode-steal: while command mode open, D-PAD / arrows (bag_slot_*) feed QTEs
	# — not bag use (see Controls.dir_from_event + _bag_use_suppressed).
	if host._in_dir_mode() and event.is_pressed() and (
		event is InputEventKey or event is InputEventJoypadButton
	):
		var dir: int = Controls.dir_from_event(event)
		if dir >= 0:
			host._try_dir(dir)
			host.get_viewport().set_input_as_handled()
			return
	## D-Pad / arrows → ops bag slots (free ops only; suppressed in dir mode).
	if event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton):
		var bag_slot: int = Controls.bag_slot_from_event(event)
		if bag_slot >= 0:
			if host._try_use_ops_bag_slot(bag_slot):
				host.get_viewport().set_input_as_handled()
				return
	## LB carry-select borrows X / B (dash / cancel).
	if host._carry_select_on and event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton):
		if event.is_action_pressed(Controls.DASH):
			host._cycle_carry_focus(-1)
			host.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(Controls.CANCEL):
			host._cycle_carry_focus(1)
			host.get_viewport().set_input_as_handled()
			return
	for action in Controls.HOLD_ACTIONS:
		if event.is_action(action) and (event is InputEventKey or event is InputEventJoypadButton):
			## While carry-select, borrow dash/cancel presses; always forward releases
			## so sticky B drop-aim / X run holds can clear.
			if host._carry_select_on and (action == Controls.DASH or action == Controls.CANCEL):
				if not event.is_pressed():
					set_hold(action, false)
				host.get_viewport().set_input_as_handled()
				return
			set_hold(action, event.is_pressed())
			host.get_viewport().set_input_as_handled()
			return
	if event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton):
		host._handle_hotkey_actions(event)

func cancel_input() -> void:
	var used: bool = host._fighting or host._stun_left > 0.0 or host._slip_left > 0.0 or host._long_committed or host.command_lock
	if is_instance_valid(host._self_repair_reg):
		host._end_self_cashier_repair()
		used = true
	if host._restock_picking:
		host._abort_restock_pick()
		host._restock_aborted = true
		host._j_held = false
		host.log_line.emit(Loc.t("log.player.cancel_pick"))
		used = true
	if host._cooked_picking:
		host._abort_cooked_pick()
		host._cooked_aborted = true
		host._j_held = false
		host.log_line.emit(Loc.t("log.player.cancel_pick"))
		used = true
	if host._cooked_craft_stall != null:
		host._cancel_cooked_craft()
		used = true
	if host._must_deliver_aim:
		host._cancel_must_deliver_aim()
		used = true
	if host._magneto_aim:
		host._cancel_magneto_aim()
		used = true
	if host.skill_menu_open or host._l_held or host._skill_latch:
		host._close_skill_menu()
		SfxBus.play("sfx_skill_menu_cancel")
		host.log_line.emit(Loc.t("log.player.cancel_skill_menu"))
		used = true
	if host.bag_menu_open or host._bag_held:
		host._close_bag_menu()
		SfxBus.play("sfx_skill_menu_cancel")
		used = true
	if host.carry_menu_open or host._carry_held:
		host._close_carry_menu()
		SfxBus.play("sfx_skill_menu_cancel")
		used = true
	if host._carry_select_on or host._carry_select_held:
		host._carry_select_held = false
		host._end_carry_select()
		used = true
	if host.ult_prep:
		host._on_ult_hold(false)
		used = true
	if host._j_held:
		set_hold("interact", false)
		used = true
	if used:
		host._cancel_swallowed = true

func move_axis() -> Vector2:
	## Long-press drop aim only — in-flight boxes do not block walk.
	if host._cancel_drop_ready:
		return Vector2.ZERO
	## Short toss hitch: keep feet planted briefly so walk does not overtake the box.
	if host._toss_move_pause_left > 0.0:
		return Vector2.ZERO
	if host._elite_focus_left > 0.0 or host._portal_beam_left > 0.0:
		return Vector2.ZERO
	if host._stun_left > 0.0 or host._slip_left > 0.0 or host._fighting or host._shelving() or host._cleaning():
		return Vector2.ZERO
	## Cooked craft Circle: lock feet; cancel key refunds pantry (not move).
	if host._cooked_craft_stall != null:
		return Vector2.ZERO
	## Charging restock SKU list (before `_restock_picking`): freeze walk but do not
	## arm the neutral latch — short-tap pulls while holding a direction must resume.
	if (
		host._j_held
		and not host._restock_picking
		and is_instance_valid(host.target)
		and host._obj_str(host.target, "kind") in ["restock", "fish_tank"]
	):
		return Vector2.ZERO
	if (
		host._j_held
		and not host._cooked_picking
		and is_instance_valid(host.target)
		and host._obj_str(host.target, "kind") == "cooked_stall"
	):
		return Vector2.ZERO
	if host._in_dir_mode():
		## Arm latch: skill menu / ult / checkout / restock pick consume move_* .
		host._move_locked_until_neutral = true
		return Vector2.ZERO
	var v: Vector2 = host._move_vector() + host.stick_axis
	if host._move_locked_until_neutral:
		if v.length() < Controls.MOVE_DEADZONE:
			host._move_locked_until_neutral = false
		else:
			return Vector2.ZERO
	if v.length() < Controls.MOVE_DEADZONE:
		return Vector2.ZERO
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v
