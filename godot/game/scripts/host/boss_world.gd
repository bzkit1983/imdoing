extends RefCounted
## Boss-day FSM + cutscenes (see docs/systemdesign/bossbattle.md).

const Tuning = preload("res://scripts/tuning.gd")
const CustomerScript = preload("res://scripts/customer.gd")

const BOSS_ALIEN_TYCOON := "alien_tycoon"
const ALIEN_LIST_SIZES: Array[int] = [5, 8, 10, 15, 20]
const ALIEN_PAY_WAVES: Array[int] = [5, 6, 10]
const BOSS_MODEL_ID := "player_alt1"
const REWARD_XP := 200
const REWARD_MONEY := 500

var host: Node
var active: bool = false
var boss_id: String = ""
var stages_total: int = 0
var stages_done: int = 0
var list_stage: int = 0
var pay_wave: int = 0
var time_frozen: bool = false
var cutscene_busy: bool = false
var boss_spawned: bool = false
var won: bool = false
var failed: bool = false
var _boss: Node = null
var _pending_fail: bool = false
var _pending_win: bool = false


func bind(day_host: Node) -> void:
	host = day_host


func clear() -> void:
	active = false
	boss_id = ""
	stages_total = 0
	stages_done = 0
	list_stage = 0
	pay_wave = 0
	time_frozen = false
	cutscene_busy = false
	boss_spawned = false
	won = false
	failed = false
	_boss = null
	_pending_fail = false
	_pending_win = false


func configure(id: String) -> void:
	clear()
	active = true
	boss_id = id if id != "" else BOSS_ALIEN_TYCOON
	match boss_id:
		_:
			stages_total = ALIEN_LIST_SIZES.size() + ALIEN_PAY_WAVES.size()


func is_active() -> bool:
	return active


func progress_remaining() -> float:
	if stages_total <= 0:
		return 0.0
	return float(stages_total - stages_done) / float(stages_total)


func progress_done() -> int:
	return stages_done


func progress_total() -> int:
	return stages_total


func should_skip_cashier_clerks() -> bool:
	return active


func should_suppress_ambient() -> bool:
	return active


func should_spawn_open_dirt() -> bool:
	return not active


func tick_open_spawn() -> void:
	if not active or boss_spawned or cutscene_busy or failed or won:
		return
	if host == null or host.phase != "open":
		return
	if not (SessionService.is_server() or SessionService.is_local_transport()):
		return
	_spawn_boss()


func _spawn_boss() -> void:
	if host.state == null or host.state.sellable().is_empty():
		return
	boss_spawned = true
	var c: CharacterBody2D = CustomerScript.new()
	host._customers.add_child(c)
	c.setup(host, host.door_pos())
	c.call("become_boss", boss_id, ALIEN_LIST_SIZES[0])
	_boss = c
	list_stage = 0
	pay_wave = 0
	stages_done = 0
	host.register_customer(c)
	var cust_extra := {
		"pace": String(c.get("pace")),
		"elite": false,
		"elite_lv": 0,
		"boss": true,
		"boss_id": boss_id,
		"model": String(c.get("_model_id")),
		"shopping": c.shopping.duplicate() if c.get("shopping") != null else [],
	}
	host._register_net_agent(c, "customer", cust_extra)
	SfxBus.play("sfx_guest_enter")
	if host._hud != null and host._hud.has_method("show_boss_progress"):
		host._hud.call("show_boss_progress")
	var BgmBusScript = preload("res://scripts/bgm_bus.gd")
	var bgm := BgmBusScript.bus()
	if bgm != null and bgm.has_method("enter_boss"):
		bgm.call("enter_boss")
	host.call_deferred("_boss_run_enter_cutscene")


func on_list_cleared(cust: Node) -> bool:
	## Return true = handled (do not go to checkout yet).
	if not active or cust == null or cust != _boss or failed or won:
		return false
	## Already past all shopping lists — allow real checkout.
	if list_stage >= ALIEN_LIST_SIZES.size():
		return false
	if cutscene_busy:
		return true
	_complete_stage()
	var completed_1based := list_stage + 1
	list_stage = completed_1based
	host.call_deferred("_boss_run_list_cutscene", completed_1based)
	return true


func after_list_cutscene_allow_checkout() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	if list_stage < ALIEN_LIST_SIZES.size():
		var n: int = ALIEN_LIST_SIZES[list_stage]
		_boss.call("boss_start_list_stage", n)
		_boss.set("dissatisfaction", 0.0)
		if _boss.has_method("_sync_labels"):
			_boss.call("_sync_labels")
	else:
		## Begin checkout path.
		_boss.set("dissatisfaction", 0.0)
		if _boss.has_method("_sync_labels"):
			_boss.call("_sync_labels")
		if _boss.has_method("_begin_checkout"):
			_boss.call("_begin_checkout", Loc.t("mood.to_pay"))


func checkout_wave_count(cust: Node) -> int:
	if not active or cust == null or cust != _boss:
		return -1
	var idx := clampi(pay_wave, 0, ALIEN_PAY_WAVES.size() - 1)
	return ALIEN_PAY_WAVES[idx]


func on_checkout_wave_done(cust: Node) -> bool:
	## Return true = more waves remain (do not finish checkout / pay yet).
	if not active or cust == null or cust != _boss or failed or won:
		return false
	_complete_stage()
	pay_wave += 1
	if pay_wave < ALIEN_PAY_WAVES.size():
		host.call_deferred("_boss_run_pay_wave_cutscene", pay_wave)
		return true
	## Last wave complete — allow normal finish_checkout, then win flow.
	_pending_win = true
	return false


func after_pay_wave_cutscene() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	## Clear seq so player rolls the next absolute wave.
	_boss.checkout_seq.clear()
	if _boss.has_meta("checkout_seq_init"):
		_boss.remove_meta("checkout_seq_init")
	if _boss.has_meta("checkout_seq_full"):
		_boss.remove_meta("checkout_seq_full")
	if _boss.has_meta("checkout_seq_trimmed"):
		_boss.remove_meta("checkout_seq_trimmed")


func on_boss_paid(cust: Node) -> void:
	if not active or cust == null or cust != _boss:
		return
	if _pending_win:
		host.call_deferred("_boss_run_win_flow")


func on_boss_angry_leave(cust: Node) -> void:
	if not active or failed or won:
		return
	if cust != null and cust == _boss:
		_pending_fail = true
		host.call_deferred("_boss_run_fail_flow", "dissat")


func on_day_time_up() -> bool:
	## Return true if boss world consumed the finish (async fail instead of settle now).
	if not active or won or failed:
		return false
	if _pending_win:
		return false
	_pending_fail = true
	host.call_deferred("_boss_run_fail_flow", "time")
	return true


func _complete_stage() -> void:
	stages_done = mini(stages_done + 1, stages_total)
	if host != null and host._hud != null and host._hud.has_method("set_boss_progress"):
		host._hud.call("set_boss_progress", stages_done, stages_total)


func apply_win_rewards() -> void:
	if host == null or host.state == null:
		return
	host.state.xp = int(host.state.xp) + REWARD_XP
	host.state.money = int(host.state.money) + REWARD_MONEY


func line_key_for_list_stage(completed_stage_1based: int) -> String:
	## completed_stage_1based: 1..5 after that list finished.
	match completed_stage_1based:
		1:
			return "boss.alien_tycoon.line.list_1"
		2:
			return "boss.alien_tycoon.line.list_2"
		3:
			return "boss.alien_tycoon.line.list_3"
		4:
			return "boss.alien_tycoon.line.list_4"
		5:
			return "boss.alien_tycoon.line.list_5"
		_:
			return "boss.alien_tycoon.line.list_1"


## Restock open: freeze clock, foreshadow dialog, resume (no zoom — boss not in yet).
func run_restock_intro_cutscene() -> void:
	_freeze(true)
	var tree: SceneTree = host.get_tree() if host != null else null
	var hud = host.get("_hud") if host != null else null
	if hud != null and hud.has_method("show_boss_dialog"):
		await hud.call("show_boss_dialog", "", Loc.t("boss.alien_tycoon.line.restock_intro"), false)
	elif tree != null:
		await tree.create_timer(1.2).timeout
	_freeze(false)


func run_enter_cutscene() -> void:
	await _play_cutscene(Loc.t("boss.alien_tycoon.name"), Loc.t("boss.alien_tycoon.line.enter"), true)


func run_list_cutscene(stage_1based: int) -> void:
	await _play_cutscene("", Loc.t(line_key_for_list_stage(stage_1based)), false)
	after_list_cutscene_allow_checkout()


func run_pay_wave_cutscene(_wave_idx: int) -> void:
	await _play_cutscene("", Loc.t("boss.alien_tycoon.line.pay_wave"), false)
	after_pay_wave_cutscene()


func run_win_flow() -> void:
	if won or failed:
		return
	won = true
	await _play_cutscene("", Loc.t("boss.alien_tycoon.line.pay_done"), false)
	await _show_mission_complete()
	apply_win_rewards()
	if host != null and host.has_method("_finish_day"):
		host.call("_finish_day")


func run_fail_flow(reason: String) -> void:
	if won or failed:
		return
	failed = true
	var line := Loc.t("boss.alien_tycoon.fail_time") if reason == "time" else Loc.t("boss.alien_tycoon.fail_dissat")
	await _play_cutscene(Loc.t("boss.hud.fail_title"), line, false)
	if host != null and host.has_method("_finish_day"):
		host.call("_finish_day")


func _freeze(on: bool) -> void:
	time_frozen = on
	cutscene_busy = on
	if host == null:
		return
	var players = host.get("_players")
	if players == null:
		return
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		if on:
			p.set_meta("boss_cutscene_lock", true)
		elif p.has_meta("boss_cutscene_lock"):
			p.remove_meta("boss_cutscene_lock")


func _play_cutscene(title: String, body: String, typewriter_title: bool) -> void:
	_freeze(true)
	var tree: SceneTree = host.get_tree() if host != null else null
	var target: Node = _boss if _boss != null and is_instance_valid(_boss) else null
	var player = host.get("_player") if host != null else null
	if player != null and player.has_method("play_elite_focus") and target != null:
		await player.call("play_elite_focus", target, Tuning.ELITE_ZOOM_SEC)
	elif tree != null:
		await tree.create_timer(Tuning.ELITE_ZOOM_SEC).timeout
	var hud = host.get("_hud") if host != null else null
	if hud != null and hud.has_method("show_boss_dialog"):
		await hud.call("show_boss_dialog", title, body, typewriter_title)
	elif tree != null:
		await tree.create_timer(1.2).timeout
	_freeze(false)


func _show_mission_complete() -> void:
	_freeze(true)
	var tree: SceneTree = host.get_tree() if host != null else null
	var hud = host.get("_hud") if host != null else null
	if hud != null and hud.has_method("show_boss_mission_complete"):
		await hud.call("show_boss_mission_complete")
	elif tree != null:
		await tree.create_timer(3.0).timeout
	_freeze(false)
