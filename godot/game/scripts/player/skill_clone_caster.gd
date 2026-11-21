extends RefCounted
## Dark Side + shadow clone from cast_slot generic tail (skill_caster L2).

var host: CharacterBody2D = null
var orc: RefCounted = null


func bind(player: CharacterBody2D, orchestrator: RefCounted) -> void:
	host = player
	orc = orchestrator


func buff_rule_erases_active_buff(sk: Dictionary) -> bool:
	return bool(sk.get("dark_side", false)) or bool(sk.get("shadow_clone", false))


func play_cast_sfx(sk: Dictionary) -> bool:
	if bool(sk.get("dark_side", false)):
		var game = host._game()
		if game and not orc._net_client_predicting():
			game.cast_dark_side(int(sk.get("lv", 3)), host.seat_id)
		return true
	if bool(sk.get("shadow_clone", false)):
		var clone_host = host._game()
		if clone_host and not orc._net_client_predicting():
			clone_host.cast_shadow_clone(int(sk.get("lv", 3)), host.seat_id)
		return true
	return false