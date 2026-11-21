extends RefCounted
## Ultimate prep + cast body (skill_caster L2).

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")

var host: CharacterBody2D = null
var orc: RefCounted = null


func bind(player: CharacterBody2D, orchestrator: RefCounted) -> void:
	host = player
	orc = orchestrator


func lord_seconds(lv: int) -> float:
	match lv:
		1:
			return 3.0
		2:
			return 5.0
		_:
			return 10.0


func on_ult_hold(pressed: bool) -> void:
	if pressed:
		if host._sick_left > 0.0 or host._stun_left > 0.0 or host._fighting:
			host.log_line.emit(Loc.t("log.player.cant_ult"))
			return
		var ult = host._ult_sk()
		if ult.is_empty() or String(ult.get("id", "")) == "":
			host.log_line.emit(Loc.t("log.player.no_ult"))
			return
		if bool(ult.get("unimplemented", false)):
			host.log_line.emit(Loc.t("log.player.demo_no_cd", [String(ult.get("name"))]))
			return
		var ult_id := String(ult.get("id"))
		if host.cd_left(ult_id) > 0.05:
			SfxBus.play("sfx_skill_cd_deny")
			host.log_line.emit(Loc.t("log.player.ult_cd", [host.cd_left(ult_id)]))
			return
		host._u_held = true
		host.ult_prep = true
		host._ult_index = 0
		SfxBus.play("sfx_ult_prep")
		host._prompt.active = true
		var seq: Array[int] = []
		for d in ult.get("seq", []):
			seq.append(int(d))
		host._prompt.sequence = seq
		host._prompt.index = 0
		host._prompt.fail_at = -1
		host.log_line.emit(Loc.t("log.player.ult_prep", [String(host._ult_sk().get("name"))]))
		return
	if host.ult_prep:
		SfxBus.play("sfx_ult_cancel")
		host.log_line.emit(Loc.t("log.player.ult_cancel"))
	host._u_held = false
	host.ult_prep = false
	if not host.command_lock:
		host._prompt.active = false
		host._prompt.fail_at = -1


func try_ult_dir(dir: int) -> void:
	var seq: Array = host._ult_sk().get("seq", [])
	if seq.is_empty() or host._ult_index < 0 or host._ult_index >= seq.size():
		return
	if dir == int(seq[host._ult_index]):
		host._prompt.fail_at = -1
		host._ult_index += 1
		host._prompt.index = host._ult_index
		SfxBus.play("sfx_ult_dir_ok")
		if host._ult_index >= seq.size():
			cast_ultimate()
			host._u_held = false
			host.ult_prep = false
			host._ult_chord_active = false
	else:
		host._prompt.fail_at = host._ult_index
		host._ult_index = 0
		host._prompt.index = 0
		SfxBus.play("sfx_ult_dir_fail")
		host.log_line.emit(Loc.t("log.player.ult_cmds_fail"))


func cast_ultimate() -> void:
	var sk: Dictionary = host._ult_sk()
	if sk.is_empty() or String(sk.get("id", "")) == "":
		host.log_line.emit(Loc.t("log.player.no_ult"))
		host._prompt.active = false
		return
	if bool(sk.get("unimplemented", false)):
		host.log_line.emit(Loc.t("log.player.demo_missing", [String(sk.get("name"))]))
		host._prompt.active = false
		return
	var sid := String(sk.get("id"))
	if host.cd_left(sid) > 0.05:
		host._prompt.active = false
		return
	var game = host._game()
	var predict: bool = orc._net_client_predicting()
	if sid == "self_service_operation":
		if game == null or not bool(game.can_cast_self_service_operation()):
			host.log_line.emit(Loc.t("log.player.ult_self_service_unavailable"))
			SfxBus.play("sfx_skill_cd_deny")
			host._prompt.active = false
			return
		if not predict and not bool(game.cast_self_service_operation(host.seat_id)):
			if game.has_method("_dump_all_skill_cds"):
				game.call("_dump_all_skill_cds")
			host.log_line.emit(Loc.t("log.player.ult_self_service_unavailable"))
			SfxBus.play("sfx_skill_cd_deny")
			host._prompt.active = false
			return
	if host.controls_locally() and SessionService.is_networked() and SessionService.is_client():
		host.pending_ult_cast = true
	var lv := int(sk.get("lv", 3))
	host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ULT_CD)), host._int_now())
	host._buff_cache_valid = false
	if sid == "self_service_operation":
		SfxBus.play("sfx_ult_yes_my_lord")
		host.log_line.emit(Loc.t("log.player.ult_self_service"))
		orc.begin_cast_pose(true)
		host.skill_cast.emit(String(sk.get("name")), true)
		orc.play_zoom(true)
		host._prompt.active = false
		return
	if sid == "fundraise":
		if game and not predict:
			game.cast_fundraise(lv, host.seat_id)
		SfxBus.play("sfx_ult_fundraise")
		host.log_line.emit(Loc.t("log.player.ult_fundraise", [lv]))
		orc.begin_cast_pose(true)
		host.skill_cast.emit(String(sk.get("name")), true)
		orc.play_zoom(true)
		host._prompt.active = false
		return
	if sid == "close_gate":
		if game and not predict:
			game.cast_close_gate()
		SfxBus.play("sfx_ult_close_gate")
		host.log_line.emit(Loc.t("log.player.ult_close_gate"))
		orc.begin_cast_pose(true)
		host.skill_cast.emit(String(sk.get("name")), true)
		orc.play_zoom(true)
		host._prompt.active = false
		return
	if sid == "three_volley":
		if game:
			game.cast_three_volley()
		SfxBus.play("sfx_ult_yes_my_lord")
		host.log_line.emit(Loc.t("log.player.ult_three_volley"))
		orc.begin_cast_pose(true)
		host.skill_cast.emit(String(sk.get("name")), true)
		orc.play_zoom(true)
		host._prompt.active = false
		return
	if sid == "guest_dusk":
		var dusk_ok := false
		if predict:
			dusk_ok = game != null and String(game.get("phase")) == "open"
		elif game:
			dusk_ok = bool(game.cast_guest_dusk())
		if dusk_ok:
			host._buffs[sid] = Skills.GUEST_DUSK_DURATION
			host.log_line.emit(Loc.t("log.player.ult_dusk", [Skills.GUEST_DUSK_COUNT]))
		else:
			host._buffs.erase(sid)
			host.log_line.emit(Loc.t("log.player.ult_dusk_closed"))
		host._buff_cache_valid = false
		SfxBus.play("sfx_ult_guest_dusk")
		orc.begin_cast_pose(true)
		host._spawn_fx("combo", host.global_position + Vector2(0, -36))
		host.skill_cast.emit(String(sk.get("name")), true)
		orc.play_zoom(true)
		host._prompt.active = false
		return
	if sid == "yes_my_lord":
		host._buffs[sid] = lord_seconds(lv)
		host._buff_cache_valid = false
		SfxBus.play("sfx_ult_yes_my_lord")
		host.log_line.emit(Loc.t("log.player.ult_lord", [lv, lord_seconds(lv)]))
		orc.begin_cast_pose(true)
		host._spawn_fx("combo", host.global_position + Vector2(0, -36))
		host.skill_cast.emit(String(sk.get("name")), true)
		orc.play_zoom(true)
		host._prompt.active = false
		return
	host._buffs[sid] = float(sk.get("duration", Skills.ULT_DURATION))
	host._buff_cache_valid = false
	host._enqueue_cust_speed(sid)
	SfxBus.play("sfx_ult_the_world")
	host.log_line.emit(Loc.t("log.player.ult_world", [String(sk.get("name")), lv]))
	orc.begin_cast_pose(true)
	host._spawn_fx("timestop", host.global_position + Vector2(0, -40))
	host.skill_cast.emit(String(sk.get("name")), true)
	orc.play_zoom(true)
	host._prompt.active = false