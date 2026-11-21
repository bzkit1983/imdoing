extends RefCounted
## Instant actives: force_sell / harvest / summon / self_checkout / calm_zone (skill_caster L2).

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")

var host: CharacterBody2D = null
var orc: RefCounted = null


func bind(player: CharacterBody2D, orchestrator: RefCounted) -> void:
	host = player
	orc = orchestrator


func cast_self_checkout(level: int) -> bool:
	var game = host._game()
	var count := 0
	if game != null:
		for reg in game.get("cashiers"):
			if is_instance_valid(reg) and host.global_position.distance_squared_to(reg.global_position) <= pow(5.0 * Tuning.BODY_LENGTH, 2):
				count += 1
				if not orc._net_client_predicting():
					reg.activate_self_checkout(game, level, host.seat_id)
	if count == 0:
		host.log_line.emit(Loc.t("self_checkout.no_register"))
	else:
		var ring_script = preload("res://scripts/self_checkout_ring.gd")
		ring_script.spawn(game, host.global_position)
	return count > 0


func cast_calm_zone(level: int) -> bool:
	var game = host._game()
	if game == null:
		return false
	if SessionService.is_networked() and SessionService.is_client():
		return String(game.get("phase")) in ["open", "restock"]
	return game.deploy_calm_zone(host.global_position, level, host.seat_id) != null


func cast_harvest_chives(lv: int) -> bool:
	var reg: Node2D = null
	if is_instance_valid(host.target) and host._obj_str(host.target, "kind") == "cashier":
		reg = host.target
	else:
		reg = host._nearest_kind("cashier")
	if reg == null or host._interact_dist(reg) < 0.0:
		host.log_line.emit(Loc.t("log.player.chives_aim"))
		return false
	if not host._interact_try(reg):
		host.log_line.emit(Loc.t("log.player.chives_busy"))
		return false
	var want := Skills.harvest_chives_count(lv)
	var game = host._game()
	if game == null:
		host._interact_release(reg)
		host.log_line.emit(Loc.t("log.player.chives_fail"))
		return false
	if orc._net_client_predicting():
		host._interact_release(reg)
		return true
	var n := int(game.cast_harvest_chives(reg, want, host.seat_id))
	host._interact_release(reg)
	if n <= 0:
		host.log_line.emit(Loc.t("log.player.chives_empty"))
		return false
	return true


func cast_force_sell(lv: int) -> bool:
	if host.inventory.is_empty():
		host.log_line.emit(Loc.t("log.player.force_empty"))
		return false
	var guest: Node = null
	for g in host._faced_guests():
		if g == null or not is_instance_valid(g):
			continue
		if g.get("temp_clerk"):
			continue
		guest = g
		break
	if guest == null or not guest.has_method("accept_force_sell"):
		host.log_line.emit(Loc.t("log.player.force_no_guest"))
		return false
	if not host._interact_try(guest):
		host.log_line.emit(Loc.t("log.player.force_busy"))
		return false
	if orc._net_client_predicting():
		var pred_n := mini(Skills.force_sell_count(lv), host.inventory.count())
		host._interact_release(guest)
		host.log_line.emit(Loc.t("log.player.force_n", [pred_n]))
		host._deliver_pose_left = 0.4
		return pred_n > 0
	var before := int((guest.shopping as Array).size()) if guest.get("shopping") != null else 0
	var n = mini(Skills.force_sell_count(lv), host.inventory.count())
	var pieces: Array[String] = host.inventory.pop_trailing(n)
	if pieces.is_empty():
		host._interact_release(guest)
		host.log_line.emit(Loc.t("log.player.force_empty"))
		return false
	var taken := int(guest.call("accept_force_sell", pieces))
	if taken <= 0:
		for sku in pieces:
			host.inventory.add_one(String(sku))
		host._interact_release(guest)
		host.log_line.emit(Loc.t("log.player.force_no_guest"))
		return false
	if before >= 1 and guest.shopping.is_empty():
		guest.set_meta("combo_cleared_n", before)
	host._interact_release(guest)
	host.log_line.emit(Loc.t("log.player.force_n", [taken]))
	host._deliver_pose_left = 0.4
	host._note_delivery_combo([guest], taken)
	return true


func cast_summon_guest(lv: int) -> bool:
	var want := Skills.summon_guest_count(lv)
	var game = host._game()
	if game == null:
		host.log_line.emit(Loc.t("log.player.summon_fail"))
		return false
	if orc._net_client_predicting():
		if String(game.get("phase")) != "open":
			host.log_line.emit(Loc.t("log.player.summon_fail_phase"))
			return false
		host.log_line.emit(Loc.t("log.player.summon_n", [want]))
		return true
	var n := int(game.cast_summon_guest(want))
	if n <= 0:
		host.log_line.emit(Loc.t("log.player.summon_fail_phase"))
		return false
	host.log_line.emit(Loc.t("log.player.summon_n", [n]))
	return true


func _cancel_range_previews() -> void:
	orc.cancel_must_deliver_aim()
	orc.cancel_magneto_aim()


func _finish_instant_cast(sk: Dictionary, sid: String, cd_sec: float) -> void:
	host._cd[sid] = Tuning.cd_seconds(cd_sec, host._int_now())
	host._buffs.erase(sid)
	host._buff_cache_valid = false
	SfxBus.play("sfx_skill_cast")
	host.log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
	orc.begin_cast_pose(false)
	host.skill_cast.emit(String(sk.get("name")), false)
	orc.play_zoom(false)


func try_cast_slot(sk: Dictionary, sid: String) -> bool:
	if bool(sk.get("self_checkout", false)):
		if not cast_self_checkout(int(sk.get("lv", 3))):
			return true
		_cancel_range_previews()
		host._cd[sid] = Tuning.cd_seconds(30.0, host._int_now())
		SfxBus.play("sfx_skill_cast")
		orc.begin_cast_pose(false)
		host.skill_cast.emit(Loc.t("self_checkout.active"), false)
		orc.play_zoom(false)
		return true
	if bool(sk.get("calm_zone", false)):
		_cancel_range_previews()
		if not cast_calm_zone(int(sk.get("lv", 3))):
			return true
		host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", 30.0)), host._int_now())
		SfxBus.play("sfx_skill_cast")
		host.log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
		orc.begin_cast_pose(false)
		host.skill_cast.emit(String(sk.get("name")), false)
		orc.play_zoom(false)
		return true
	if bool(sk.get("force_sell", false)):
		if host._must_deliver_aim:
			orc.cancel_must_deliver_aim()
		if host._magneto_aim:
			orc.cancel_magneto_aim()
		if not cast_force_sell(int(sk.get("lv", 3))):
			return true
		_finish_instant_cast(sk, sid, float(sk.get("cd", Skills.ACTIVE_CD)))
		return true
	if bool(sk.get("harvest_chives", false)):
		if host._must_deliver_aim:
			orc.cancel_must_deliver_aim()
		if host._magneto_aim:
			orc.cancel_magneto_aim()
		if not cast_harvest_chives(int(sk.get("lv", 3))):
			return true
		_finish_instant_cast(sk, sid, float(sk.get("cd", Skills.ACTIVE_CD)))
		return true
	if bool(sk.get("summon_guest", false)):
		if host._must_deliver_aim:
			orc.cancel_must_deliver_aim()
		if host._magneto_aim:
			orc.cancel_magneto_aim()
		if not cast_summon_guest(int(sk.get("lv", 3))):
			return true
		_finish_instant_cast(sk, sid, float(sk.get("cd", Skills.ACTIVE_CD)))
		return true
	return false