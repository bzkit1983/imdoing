extends RefCounted
## Skill cast / aim / VFX orchestrator (Tech Review L2). Family logic in skill_*_caster.gd.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")

const SkillRangeCasterScript = preload("res://scripts/player/skill_range_caster.gd")
const SkillInstantCasterScript = preload("res://scripts/player/skill_instant_caster.gd")
const SkillCannonCasterScript = preload("res://scripts/player/skill_cannon_caster.gd")
const SkillUltimateCasterScript = preload("res://scripts/player/skill_ultimate_caster.gd")
const SkillCloneCasterScript = preload("res://scripts/player/skill_clone_caster.gd")
const SkillSniperCasterScript = preload("res://scripts/player/skill_sniper_caster.gd")

var host: CharacterBody2D = null
var _range: RefCounted
var _instant: RefCounted
var _cannon: RefCounted
var _ultimate: RefCounted
var _clone: RefCounted
var _sniper: RefCounted


func _init() -> void:
	_range = SkillRangeCasterScript.new()
	_instant = SkillInstantCasterScript.new()
	_cannon = SkillCannonCasterScript.new()
	_ultimate = SkillUltimateCasterScript.new()
	_clone = SkillCloneCasterScript.new()
	_sniper = SkillSniperCasterScript.new()


func bind(player: CharacterBody2D) -> void:
	host = player
	_range.bind(player, self)
	_instant.bind(player, self)
	_cannon.bind(player, self)
	_ultimate.bind(player, self)
	_clone.bind(player, self)
	_sniper.bind(player, self)


func _net_client_predicting() -> bool:
	return SessionService.is_networked() and SessionService.is_client()


func setup_must_deliver_ring() -> void:
	_range.setup_must_deliver_ring()


func setup_magneto_ring() -> void:
	_range.setup_magneto_ring()


func begin_must_deliver_aim(sk: Dictionary) -> void:
	_range.begin_must_deliver_aim(sk)


func cancel_must_deliver_aim() -> void:
	_range.cancel_must_deliver_aim()


func rebuild_must_deliver_ring(radius: float) -> void:
	_range.rebuild_must_deliver_ring(radius)


func finish_must_deliver_aim() -> void:
	_range.finish_must_deliver_aim()


func cast_must_deliver(lv: int) -> bool:
	return _range.cast_must_deliver(lv)


func must_deliver_guests(radius: float) -> Array:
	return _range.must_deliver_guests(radius)


func must_deliver_count_map(items: Array) -> Dictionary:
	return _range.must_deliver_count_map(items)


func must_deliver_can_complete(shopping: Array, sim: Dictionary) -> bool:
	return _range.must_deliver_can_complete(shopping, sim)


func must_deliver_deduct_shopping(shopping: Array, sim: Dictionary) -> void:
	_range.must_deliver_deduct_shopping(shopping, sim)


func must_deliver_order_guests(guests: Array, inv_items: Array) -> Array:
	return _range.must_deliver_order_guests(guests, inv_items)


func must_deliver_match_pieces(shopping: Array, counts: Dictionary) -> Array[String]:
	return _range.must_deliver_match_pieces(shopping, counts)


func play_must_deliver_vfx(deliveries: Array) -> void:
	_range.play_must_deliver_vfx(deliveries)


func cast_summon_guest(lv: int) -> bool:
	return _instant.cast_summon_guest(lv)


func begin_magneto_aim(sk: Dictionary) -> void:
	_range.begin_magneto_aim(sk)


func cancel_magneto_aim() -> void:
	_range.cancel_magneto_aim()


func rebuild_magneto_ring(radius: float) -> void:
	_range.rebuild_magneto_ring(radius)


func finish_magneto_aim() -> void:
	_range.finish_magneto_aim()


func cast_magneto(lv: int) -> void:
	_range.cast_magneto(lv)


func play_magneto_vfx(flights: Array) -> void:
	_range.play_magneto_vfx(flights)


func cast_self_checkout(level: int) -> bool:
	return _instant.cast_self_checkout(level)


func cast_calm_zone(level: int) -> bool:
	return _instant.cast_calm_zone(level)


func cast_harvest_chives(lv: int) -> bool:
	return _instant.cast_harvest_chives(lv)


func cast_force_sell(lv: int) -> bool:
	return _instant.cast_force_sell(lv)


func on_skill_hold(pressed: bool) -> void:
	if pressed:
		if host._sick_left > 0.0 or host._stun_left > 0.0 or host._fighting:
			host.log_line.emit(Loc.t("log.player.cant_skill"))
			return
		if host._must_deliver_aim:
			## Client: local chrome + aim_confirm intent; Host finishes authority cast.
			if SessionService.is_networked() and SessionService.is_client():
				host.pending_aim_confirm = true
			finish_must_deliver_aim()
			host._skill_release_ignore = true
			return
		if host._magneto_aim:
			if SessionService.is_networked() and SessionService.is_client():
				host.pending_aim_confirm = true
			finish_magneto_aim()
			host._skill_release_ignore = true
			return
		if host._skill_latch:
			close_skill_menu()
			host._skill_release_ignore = true
			return
		if host.bag_menu_open and host.has_method("_close_bag_menu"):
			host._close_bag_menu()
		host._l_held = true
		host._l_time = 0.0
		host._skill_aim = -1
		return
	if host._skill_release_ignore:
		host._skill_release_ignore = false
		host._l_held = false
		return
	if not host._l_held:
		return
	if host.skill_menu_open:
		if SessionService.is_networked() and SessionService.is_server() and not host.controls_locally():
			close_skill_menu()
			return
		if not host._skill_latch:
			sync_hold_aim()
		confirm_skill(host._skill_aim)
		return
	var short = host._l_time < Skills.HOLD_MENU_SEC
	var from_pad = host._skill_from_pad
	host._l_held = false
	host._skill_from_pad = false
	if short:
		if not host.controls_locally():
			return
		if from_pad:
			confirm_skill(0)
		else:
			open_skill_menu(true)


func open_skill_menu(latch: bool) -> void:
	if host.bag_menu_open and host.has_method("_close_bag_menu"):
		host._close_bag_menu()
	host.skill_menu_open = true
	host._skill_latch = latch
	host._skill_aim = -1
	host._move_locked_until_neutral = true
	host._running = false
	host.velocity = Vector2.ZERO
	if host._menu:
		host._menu.open = host.controls_locally()
		if host.controls_locally():
			host._menu.call("set_slots", host._loadout(), host._cd)
			if host._menu.has_method("set_aim"):
				host._menu.call("set_aim", -1)
	host._menu_fp = "%s|%s" % [str(host._cd), str(host._loadout())]
	if latch and (host.stick_axis.length() >= 0.42 or host._joy_stick_vector().length() >= 0.42):
		host._cardinal_armed = false
	if host.controls_locally():
		SfxBus.play("sfx_skill_menu_open")
		if latch:
			host.log_line.emit(Loc.t("log.player.skill_menu_tap"))
		else:
			host.log_line.emit(Loc.t("log.player.skill_menu_hold"))


func sync_hold_aim() -> void:
	set_skill_aim(skill_aim_slot())


func skill_aim_slot() -> int:
	var SkillMenu = preload("res://scripts/skill_menu.gd")
	var v = host._move_vector() + host.stick_axis
	return SkillMenu.aim_from_stick(v)


func set_skill_aim(slot: int) -> void:
	slot = clampi(slot, -1, 4)
	if slot == host._skill_aim:
		if host._menu and host._menu.has_method("set_aim"):
			host._menu.call("set_aim", slot)
		return
	host._skill_aim = slot
	if host._menu and host._menu.has_method("set_aim"):
		host._menu.call("set_aim", slot)
	SfxBus.play("sfx_skill_menu_move")


func _queue_client_skill_intent(slot: int) -> void:
	if host.controls_locally() and SessionService.is_networked() and SessionService.is_client():
		host.pending_skill_hotkey = clampi(slot, 0, 4)


func confirm_skill(slot: int) -> void:
	close_skill_menu()
	if slot < 0:
		host._move_locked_until_neutral = true
		host.velocity = Vector2.ZERO
		return
	_queue_client_skill_intent(slot)
	cast_slot(slot)
	host._move_locked_until_neutral = true
	host.velocity = Vector2.ZERO


func try_skill_hotkey(slot: int) -> void:
	if host._sick_left > 0.0 or host._stun_left > 0.0 or host._fighting:
		host.log_line.emit(Loc.t("log.player.cant_skill"))
		return
	if host.ult_prep or host._elite_focus_left > 0.0:
		return
	_queue_client_skill_intent(slot)
	if host._must_deliver_aim:
		if SessionService.is_networked() and SessionService.is_client():
			host.pending_aim_confirm = true
		finish_must_deliver_aim()
		return
	if host._magneto_aim:
		if SessionService.is_networked() and SessionService.is_client():
			host.pending_aim_confirm = true
		finish_magneto_aim()
		return
	confirm_skill(slot)


func close_skill_menu() -> void:
	host._l_held = false
	host._l_time = 0.0
	host._skill_latch = false
	host._skill_aim = -1
	host.skill_menu_open = false
	if host._menu:
		host._menu.open = false
		if host._menu.has_method("set_aim"):
			host._menu.call("set_aim", -1)


func on_ult_hold(pressed: bool) -> void:
	_ultimate.on_ult_hold(pressed)


func try_ult_dir(dir: int) -> void:
	_ultimate.try_ult_dir(dir)


func cast_slot(i: int) -> void:
	if host._sick_left > 0.0 or host._stun_left > 0.0 or host._fighting:
		host.log_line.emit(Loc.t("log.player.cant_skill"))
		return
	var sk: Dictionary = host._skill_at(i)
	if sk.is_empty():
		return
	if bool(sk.get("unimplemented", false)):
		host.log_line.emit(Loc.t("log.player.demo_no_cd", [String(sk.get("name"))]))
		return
	if str(sk.get("kind", "")) != "active":
		host.log_line.emit(Loc.t("log.player.passive", [String(sk.get("name"))]))
		return
	var sid := String(sk.get("id"))
	if host.cd_left(sid) > 0.05:
		SfxBus.play("sfx_skill_cd_deny")
		host.log_line.emit(Loc.t("log.player.skill_cd", [String(sk.get("name")), host.cd_left(sid)]))
		return
	if _cannon.try_cast_slot(sk, sid):
		return
	if _instant.try_cast_slot(sk, sid):
		return
	if _range.try_cast_slot(sk, sid):
		return
	if _sniper.try_cast_slot(sk, sid):
		return
	_cast_slot_duration_buff(sk, sid)


func _cast_slot_duration_buff(sk: Dictionary, sid: String) -> void:
	if host._must_deliver_aim:
		cancel_must_deliver_aim()
	if host._magneto_aim:
		cancel_magneto_aim()
	host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), host._int_now())
	if bool(sk.get("dash_deliver", false)):
		var window := float(sk.get("cd", 5.0))
		host._cd[sid] = window
		host._buffs[sid] = window
	elif bool(sk.get("dasher", false)):
		host._buffs[sid] = Skills.dasher_seconds(int(sk.get("lv", 3)))
	elif bool(sk.get("hoop_ace", false)):
		host._buffs[sid] = Skills.hoop_ace_seconds(int(sk.get("lv", 3)))
	elif bool(sk.get("senior_cashier", false)):
		host._senior_cashier_lv = int(sk.get("lv", 3))
		host._buffs[sid] = Skills.senior_cashier_seconds(host._senior_cashier_lv)
	elif bool(sk.get("checkout_revenue", false)) or sid == "checkout_rush":
		host._checkout_rush_lv = int(sk.get("lv", 3))
		host._buffs[sid] = float(sk.get("duration", Skills.ACTIVE_DURATION))
	elif bool(sk.get("sweeping_monk", false)):
		host._buffs[sid] = Skills.sweeping_monk_seconds(int(sk.get("lv", 3)))
	elif _clone.buff_rule_erases_active_buff(sk):
		host._buffs.erase(sid)
	else:
		host._buffs[sid] = float(sk.get("duration", Skills.ACTIVE_DURATION))
	host._buff_cache_valid = false
	if sk.has("customer_move_pct"):
		host._enqueue_cust_speed(sid)
	if sk.has("soothe_keep"):
		var game = host._game()
		if game and not _net_client_predicting():
			game.soothe_all(float(sk.get("soothe_keep")))
		SfxBus.play("sfx_skill_soothe")
	elif _clone.play_cast_sfx(sk):
		pass
	elif bool(sk.get("sweeping_monk", false)):
		if not _net_client_predicting():
			host._activate_sweeping_monk()
		else:
			host._sick_left = 0.0
			if host.has_method("_sync_monk_tornado"):
				host._sync_monk_tornado(true)
		SfxBus.play("sfx_skill_sweeping_monk")
	else:
		SfxBus.play("sfx_skill_cast")
	host.log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
	begin_cast_pose(false)
	host.skill_cast.emit(String(sk.get("name")), false)
	play_zoom(false)


func lord_seconds(lv: int) -> float:
	return _ultimate.lord_seconds(lv)


func cast_ultimate() -> void:
	_ultimate.cast_ultimate()


func begin_cast_pose(ult: bool) -> void:
	host._cast_pose_left = 0.55 if ult else 0.35


func play_zoom(ult: bool) -> void:
	if not host.controls_locally():
		return
	var cam = host._shared_camera()
	if cam == null:
		return
	host.camera = cam
	var base: float = host.base_camera_zoom()
	var z: float = base * (1.28 if ult else 1.12)
	var tw = host.create_tween()
	tw.tween_property(cam, "zoom", Vector2(z, z), 0.18)
	tw.tween_interval(0.22 if ult else 0.12)
	tw.tween_callback(host.restore_base_camera)