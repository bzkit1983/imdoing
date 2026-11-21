extends RefCounted
## Sniper actives: duration buff chrome only (skill_caster L2).

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")

var host: CharacterBody2D = null
var orc: RefCounted = null


func bind(player: CharacterBody2D, orchestrator: RefCounted) -> void:
	host = player
	orc = orchestrator


func try_cast_slot(sk: Dictionary, sid: String) -> bool:
	if not (
		bool(sk.get("shelf_sniper", false))
		or bool(sk.get("guest_sniper", false))
		or bool(sk.get("thief_sniper", false))
	):
		return false
	if host._must_deliver_aim:
		orc.cancel_must_deliver_aim()
	if host._magneto_aim:
		orc.cancel_magneto_aim()
	host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), host._int_now())
	host._buffs[sid] = float(sk.get("duration", Skills.ACTIVE_DURATION))
	host._buff_cache_valid = false
	SfxBus.play("sfx_skill_cast")
	host.log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
	orc.begin_cast_pose(false)
	host.skill_cast.emit(String(sk.get("name")), false)
	orc.play_zoom(false)
	return true