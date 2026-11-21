extends RefCounted
## Universal / shelf / kind / elite_guest cannons + specialist deploy (skill_caster L2).

const Tuning = preload("res://scripts/tuning.gd")

var host: CharacterBody2D = null
var orc: RefCounted = null


func bind(player: CharacterBody2D, orchestrator: RefCounted) -> void:
	host = player
	orc = orchestrator


func _cancel_range_previews() -> void:
	orc.cancel_must_deliver_aim()
	orc.cancel_magneto_aim()


func try_cast_slot(sk: Dictionary, sid: String) -> bool:
	if bool(sk.get("universal_cannon", false)):
		if not host._round_active():
			return true
		_cancel_range_previews()
		if is_instance_valid(host._cannon) and not host._cannon.dismissed:
			host._cannon.dismiss()
			host._cannon = null
			host._cd[sid] = Tuning.cd_seconds(60.0, host._int_now())
			host.log_line.emit(Loc.t("cannon.cancelled"))
		elif orc._net_client_predicting():
			host.log_line.emit(Loc.t("cannon.deployed"))
		else:
			var game = host._game()
			if game == null:
				return true
			host._cannon = game.deploy_universal_cannon(host.global_position, int(sk.get("lv", 3)), host.seat_id)
			if host._cannon == null:
				return true
			host.log_line.emit(Loc.t("cannon.deployed"))
		SfxBus.play("sfx_skill_cast")
		orc.begin_cast_pose(false)
		host.skill_cast.emit(Loc.t("cannon.name"), false)
		return true
	if bool(sk.get("shelf_cannon", false)):
		if not host._round_active():
			return true
		_cancel_range_previews()
		if is_instance_valid(host._shelf_cannon) and not host._shelf_cannon.dismissed:
			host._shelf_cannon.dismiss()
			host._shelf_cannon = null
			host._cd[sid] = Tuning.cd_seconds(60.0, host._int_now())
			host.log_line.emit(Loc.t("shelf_cannon.cancelled"))
		elif orc._net_client_predicting():
			host.log_line.emit(Loc.t("shelf_cannon.deployed"))
		else:
			var game = host._game()
			if game == null:
				return true
			host._shelf_cannon = game.deploy_shelf_cannon(host.global_position, int(sk.get("lv", 3)), host.seat_id)
			if host._shelf_cannon == null:
				return true
			host.log_line.emit(Loc.t("shelf_cannon.deployed"))
		SfxBus.play("sfx_skill_cast")
		orc.begin_cast_pose(false)
		host.skill_cast.emit(Loc.t("skill.shelf_cannon.name"), false)
		return true
	if bool(sk.get("kind_cannon", false)):
		if not host._round_active():
			return true
		_cancel_range_previews()
		if is_instance_valid(host._kind_cannon) and not host._kind_cannon.dismissed:
			host._kind_cannon.dismiss()
			host._kind_cannon = null
			host._cd[sid] = Tuning.cd_seconds(90.0, host._int_now())
			host.log_line.emit(Loc.t("kind_cannon.cancelled"))
		elif orc._net_client_predicting():
			host.log_line.emit(Loc.t("kind_cannon.deployed"))
		else:
			var game = host._game()
			if game == null:
				return true
			host._kind_cannon = game.deploy_kind_cannon(host.global_position, int(sk.get("lv", 3)), host.seat_id)
			if host._kind_cannon == null:
				return true
			host.log_line.emit(Loc.t("kind_cannon.deployed"))
		SfxBus.play("sfx_skill_cast")
		orc.begin_cast_pose(false)
		host.skill_cast.emit(Loc.t("skill.kind_cannon.name"), false)
		return true
	if bool(sk.get("elite_guest_specialist", false)):
		var game = host._game()
		if game == null or String(game.get("phase")) != "open":
			return true
		_cancel_range_previews()
		if orc._net_client_predicting():
			host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", 60.0)), host._int_now())
		else:
			if game == null:
				return true
			var specialist = game.deploy_elite_guest_specialist(
				host.global_position, int(sk.get("lv", 3)), host.seat_id
			)
			if specialist == null:
				return true
			host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", 60.0)), host._int_now())
		SfxBus.play("sfx_skill_cast")
		host.log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
		orc.begin_cast_pose(false)
		host.skill_cast.emit(String(sk.get("name")), false)
		orc.play_zoom(false)
		return true
	if bool(sk.get("elite_guest_cannon", false)):
		if not host._round_active():
			return true
		_cancel_range_previews()
		var game = host._game()
		if orc._net_client_predicting():
			host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", 45.0)), host._int_now())
			host.log_line.emit(Loc.t("elite_guest_cannon.deployed"))
		else:
			if game == null:
				return true
			var was_active := (
				is_instance_valid(host._elite_guest_cannon)
				and not bool(host._elite_guest_cannon.get("dismissed"))
			)
			host._elite_guest_cannon = game.deploy_elite_guest_cannon(
				host.global_position, int(sk.get("lv", 3)), host.seat_id
			)
			if host._elite_guest_cannon == null:
				return true
			host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", 45.0)), host._int_now())
			host.log_line.emit(
				Loc.t("elite_guest_cannon.refreshed")
				if was_active
				else Loc.t("elite_guest_cannon.deployed")
			)
		SfxBus.play("sfx_skill_cast")
		orc.begin_cast_pose(false)
		host.skill_cast.emit(Loc.t("skill.elite_guest_cannon.name"), false)
		orc.play_zoom(false)
		return true
	return false