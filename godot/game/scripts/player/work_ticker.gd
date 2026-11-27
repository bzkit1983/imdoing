extends RefCounted
## Work ticks (action, restock, clean, monk sweep, triggers) extracted from player.gd (#175).
## Host-bound: call bind(player) from Player._ready. State stays on the player host.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")

var host: CharacterBody2D = null


func bind(player: CharacterBody2D) -> void:
	host = player


func tick_action(delta: float) -> void:
	host.blocked_mismatch = false
	if host._fighting:
		host._tick_fight(delta)
		return
	if host._stun_left > 0.0 or host._slip_left > 0.0:
		if is_instance_valid(host.target) and host._obj_str(host.target, "kind") == "dirt":
			host.target.call("set_cleaning", false, Vector2.ZERO, 0.0, host.seat_id)
		return
	if not host._j_held:
		host.hold_progress = 0.0
		host._clear_clean_hint()
		return
	host._j_time += delta
	var turret: Node2D = host._usable_turret()
	if host._j_held and is_instance_valid(host._lock_node) and host._obj_str(host._lock_node, "kind") in ["universal_cannon", "shelf_cannon", "kind_cannon"]:
		turret = host._lock_node as Node2D
	if is_instance_valid(host._lock_node) and host._obj_str(host._lock_node, "kind") in ["universal_cannon", "shelf_cannon", "kind_cannon"] and host._lock_node != turret:
		host._interact_release_held()
		host.hold_progress = 0.0
		host._pickup_used = false
	if turret != null:
		host.target = turret
		if not host._interact_try(turret):
			host.hold_progress = 0.0
			return
		if host._j_time >= Tuning.SKU_PICK_HOLD:
			host._long_committed = true
			host._tick_cannon(delta, turret)
		return
	## Sticky long actions: a passing thief (or other higher-priority target)
	## must not yank checkout / clean / shelve mid-hold. Thief still wins when
	## *starting* an Interact press (`playeraction.md` priority).
	if host._long_committed and is_instance_valid(host.target):
		match host._obj_str(host.target, "kind"):
			"cashier":
				host._tick_cashier(delta)
				return
			"dirt":
				tick_clean(delta)
				return
			"shelf":
				if host._shelve_done:
					host._long_committed = false
				else:
					tick_restock(delta)
					return
	if not host._long_committed and not host._restock_picking and not host._cooked_picking:
		var thief: Node2D = host._nearest_active_thief()
		if thief != null:
			host.target = thief
			host._begin_fight()
			return
	var long_kind: String = host._long_kind()
	if long_kind == "restock" or long_kind == "fish_tank":
		host.target = host._nearest_kind(long_kind)
		host._tick_sku_pick(delta)
		return
	if long_kind == "cooked_stall":
		host.target = host._nearest_kind("cooked_stall")
		host._tick_cooked_pick(delta)
		return
	if host._j_time < Tuning.SKU_PICK_HOLD:
		return
	match long_kind:
		"dirt":
			host._long_committed = true
			host.target = host._nearest_kind("dirt")
			tick_clean(delta)
		"guest":
			var guests: Array = host._faced_guests()
			if not guests.is_empty():
				host.target = guests[0]
			## One hand-deliver per Interact hold; leftover hold is idle.
			if host._deliver_done:
				host._long_committed = false
			else:
				host._long_committed = true
				host._deliver_done = true
				host._hand_deliver(guests, true)
		"shelf":
			host.target = host._nearest_kind("shelf")
			## Hold past a finished Circle is "not released yet", not a new stock attempt.
			if host._shelve_done:
				host._long_committed = false
			else:
				host._long_committed = true
				tick_restock(delta)
		"cashier":
			host.target = host._nearest_kind("cashier")
			## Hold with no payable guest: walk free. A ready guest resumes checkout.
			if host._checkout_hold_idle:
				if host._cashier_has_ready(host.target):
					host._checkout_hold_idle = false
					host._long_committed = true
					host._tick_cashier(delta)
				else:
					host._long_committed = false
			else:
				host._long_committed = true
				host._tick_cashier(delta)

func tick_restock(delta: float) -> void:
	if host.inventory.is_empty():
		host.log_line.emit(Loc.t("log.player.empty_hands_shelf"))
		host._j_held = false
		return
	if not is_instance_valid(host.target) or not host.target.has_method("can_accept"):
		host.hold_progress = 0.0
		return
	var sku: String = host._shelve_sku_for(host.target)
	var empty_shelf: bool = true
	if host.target.has_method("occupied_sku"):
		empty_shelf = String(host.target.call("occupied_sku")) == ""
	else:
		empty_shelf = host._obj_int(host.target, "count") <= 0 or host._obj_str(host.target, "sku") == ""
	var have: int = host.inventory.count_of(sku) if sku != "" else 0
	## A2 L — shelf stocking Circle.
	if not host._interact_try(host.target):
		host.log_line.emit(Loc.t("log.player.shelf_busy"))
		host.hold_progress = 0.0
		return
	if sku == "" or have <= 0 or not bool(host.target.call("can_accept", sku)):
		if host._obj_int(host.target, "count") >= host._obj_int(host.target, "capacity"):
			SfxBus.play("sfx_shelf_stock_blocked")
			host.log_line.emit(Loc.t("log.player.shelf_full"))
			host._j_held = false
			host._reset_hold()
			return
		if not host.blocked_mismatch:
			SfxBus.play("sfx_shelf_stock_blocked")
		host.blocked_mismatch = true
		host.hold_progress = 0.0
		return
	## Duration: AGI baseline only. Instant ONLY while 瞬間補貨 buff is active.
	## Equipped loadout always includes instant_restock with restock_circle_mult=0 —
	## never multiply that in when the buff is off.
	var dur: float = float(Tuning.restock_seconds(host._agi_now()))
	if host.buff_left("instant_restock") > 0.05:
		var lv: int = 3
		for sk in host._loadout():
			if str(sk.get("id", "")) == "instant_restock":
				lv = int(sk.get("lv", 3))
				break
		var mult: float = float(Skills.restock_circle_mult(lv))
		if mult <= 0.0:
			dur = 0.0
		else:
			dur *= mult
	else:
		var restock_pct: float = 0.0
		for sk in host._loadout():
			## Godot 4.7: String(null) throws — empty slots have no "kind".
			if str(sk.get("kind", "")) == "passive":
				restock_pct += float(sk.get("restock_pct", 0.0))
		if restock_pct > 0.0:
			dur /= 1.0 + restock_pct
		dur = maxf(dur, 0.05)
	if dur <= 0.001:
		host.hold_progress = 1.0
	else:
		host.hold_progress = minf(1.0, host.hold_progress + delta / dur)
		if host.hold_progress < 1.0:
			SfxBus.play_stock_loop()
	if host.hold_progress >= 1.0:
		## Client: Circle chrome only; Host applies shelf／inventory via interact intent.
		if not host._world_authority():
			host._spawn_fx("spray", host.target.global_position + Vector2(0, -20))
			if dur <= 0.001:
				SfxBus.play("sfx_shelf_stock_instant")
			else:
				SfxBus.play("sfx_shelf_stock_done")
			host.hold_progress = 0.0
			host.blocked_mismatch = false
			host._shelve_done = true
			host._interact_release(host.target)
			return
		var placed: int = int(host.target.call("add_items", sku, have))
		if empty_shelf:
			host.inventory.remove_focused(placed)
		else:
			host.inventory.remove_sku(sku, placed)
		host._spawn_fx("spray", host.target.global_position + Vector2(0, -20))
		if dur <= 0.001:
			SfxBus.play("sfx_shelf_stock_instant")
		else:
			SfxBus.play("sfx_shelf_stock_done")
		host.log_line.emit(Loc.t("log.player.shelve", [Tuning.sku_name(sku), placed]))
		var game_shelve: Node = host._game()
		if placed > 0 and game_shelve != null and game_shelve.has_method("note_shelve"):
			game_shelve.call("note_shelve", host.seat_id, String(sku), placed)
		host.hold_progress = 0.0
		host.blocked_mismatch = false
		host._shelve_done = true
		host._interact_release(host.target)

func tick_clean(_delta: float) -> void:
	if host.buff_left("sweeping_monk") > 0.05:
		host._abort_manual_clean_for_monk()
		return
	if not is_instance_valid(host.target) or host._obj_str(host.target, "kind") != "dirt":
		return
	## Another seat already owns this dirt's clean cycle — do not wipe / steal it.
	if host.target.has_method("is_clean_locked_by_other") and bool(host.target.call("is_clean_locked_by_other", host.seat_id)):
		return
	## Carry allowed; goods stay in hand while scrubbing.
	var axis: Vector2 = wiggle_axis()
	if not host._clean_hint:
		host._last_wiggle = axis
	var travel: float = (axis - host._last_wiggle).length()
	host._last_wiggle = axis
	var needed: float = Tuning.CLEAN_WIGGLE_PER_SEC * Tuning.clean_seconds(host._agi_now())
	if needed <= 0.001:
		host.hold_progress = 1.0
	else:
		var before: float = host.hold_progress
		host.hold_progress = minf(1.0, host.hold_progress + travel / needed)
		if host.hold_progress > before:
			SfxBus.play_scrub()
	if not host._clean_hint:
		host._clean_hint = true
		SfxBus.play("sfx_clean_start")
		host.log_line.emit(Loc.t("log.player.clean_hint", [String(host.target.call("type_name"))]))
	if not bool(host.target.call("set_cleaning", true, axis, host.hold_progress * 100.0, host.seat_id)):
		## Lost the race to another seat this frame.
		host._clean_hint = false
		host._last_wiggle = Vector2.ZERO
		return
	if host.hold_progress >= 1.0:
		var name: String = String(host.target.call("type_name"))
		var spark_at: Vector2 = host.target.global_position
		host.target.queue_free()
		host.target = null
		host.hold_progress = 0.0
		host._clean_hint = false
		host._last_wiggle = Vector2.ZERO
		## Finished — leftover Interact hold is idle (same idea as shelve_done).
		## Leaving `_long_committed` true made the next Cancel swallow instead of toss.
		host._long_committed = false
		host._spawn_fx("clean_spark", spark_at)
		SfxBus.play("sfx_clean_done")
		var game: Node = host._game()
		if game:
			game.note_clean(host.seat_id)
		host.log_line.emit(Loc.t("log.player.clean_done", [name]))

func clear_dirt_in_monk_range() -> void:
	## Host authority — Client only shows tornado; dirt despawns via net agents.
	if SessionService.is_networked() and SessionService.is_client():
		return
	var g: Node = host._game()
	if g == null:
		return
	var dirts: Variant = g.get("_dirts")
	if dirts == null:
		return
	var rsq: float = Skills.SWEEPING_MONK_RANGE_SQ
	var hit: Array = []
	for d in dirts:
		if d == null or not is_instance_valid(d):
			continue
		## Skip nodes already queued for free this frame (avoid double note_clean).
		if d.is_queued_for_deletion():
			continue
		if host.global_position.distance_squared_to(d.global_position) > rsq:
			continue
		hit.append(d)
	for d in hit:
		if d == null or not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		var at: Vector2 = d.global_position
		var name: String = String(d.call("type_name")) if d.has_method("type_name") else Loc.t("dirt.generic")
		if is_instance_valid(host.target) and host.target == d:
			host.target = null
			host._long_committed = false
			host.hold_progress = 0.0
			host._clear_clean_hint()
		d.queue_free()
		host._spawn_fx("clean_spark", at)
		SfxBus.play("sfx_clean_done")
		if g:
			g.note_clean()
		host.log_line.emit(Loc.t("log.player.monk_clear", [name]))

func tick_triggers(delta: float) -> void:
	## LT+RT ult chord only — RT no longer drives dash/run.
	var tr: Vector2 = Controls.trigger_values_for(host.seat_id)
	var lt: bool = Controls.trigger_latched(tr.x, host._lt_held)
	var rt: bool = Controls.trigger_latched(tr.y, host._rt_held)
	if lt and not host._lt_held:
		host._lt_held = true
		host._lt_time = 0.0
		host._lt_fired = false
	if rt and not host._rt_held:
		host._rt_held = true
		host._rt_time = 0.0
		host._rt_fired = false
	if lt:
		host._lt_time += delta
	if rt:
		host._rt_time += delta
	if lt and rt:
		host._trigger_chord_block = true
		host._both_trigger_time += delta
		if not host._ult_chord_active and not host.ult_prep and host._both_trigger_time >= Skills.HOLD_MENU_SEC:
			host._on_ult_hold(true)
			if host.ult_prep:
				host._ult_chord_active = true
				host._lt_fired = true
				host._rt_fired = true
	else:
		host._both_trigger_time = 0.0
	if not lt and host._lt_held:
		host._lt_held = false
	if not rt and host._rt_held:
		host._rt_held = false
	if not lt and not rt:
		if host._ult_chord_active:
			host._on_ult_hold(false)
			host._ult_chord_active = false
		host._trigger_chord_block = false
		host._both_trigger_time = 0.0
		host._lt_fired = false
		host._rt_fired = false

func wiggle_axis() -> Vector2:
	## Clean: left stick / touch VJ / WASD (D-PAD stays bag — opsitems.md).
	## Same sources as drop aim / walk; `_move_vector` also feeds remote_move on Host.
	var v: Vector2 = host._move_vector() + host.stick_axis
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v
