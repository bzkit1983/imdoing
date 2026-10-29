extends Node
## Headless: Dark Side drafts temp clerks and keeps the locked rules.


const PlayerScript = preload("res://scripts/player.gd")
const Skills = preload("res://scripts/skills.gd")
const Tuning = preload("res://scripts/tuning.gd")
const DarkSide = preload("res://scripts/dark_side.gd")
const CustomerScript = preload("res://scripts/customer.gd")
const StateScript = preload("res://scripts/game_state.gd")
const DemoScript = preload("res://scripts/demo.gd")
const Fundraise = preload("res://scripts/fundraise.gd")
const PrepPages = preload("res://scripts/prep/prep_pages.gd")
const PrepMenu = preload("res://scripts/prep_menu.gd")

var _done := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	_check_catalog(errors)
	_check_levels(errors)
	_check_registers(errors)
	_check_guest(errors)
	_check_pool(errors)
	_check_cast_cd(errors)
	_need(errors, _done == 6, "every check finished")
	if errors.is_empty():
		print("OK dark side")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _check_catalog(errors: PackedStringArray) -> void:
	var sk: Dictionary = Skills.by_id("dark_side")
	_need(errors, PrepPages != null and PrepMenu != null, "prep scripts parse")
	_need(errors, not sk.is_empty(), "skill exists")
	_need(errors, String(sk.get("name")) == "Dark Side", "short name")
	_need(errors, int(sk.get("cost", 0)) == 2, "cost 2")
	_need(errors, bool(sk.get("dark_side", false)), "flag")
	_need(errors, is_equal_approx(float(sk.get("cd", 0.0)), 30.0), "listed cd 30")
	_need(errors, is_equal_approx(float(sk.get("duration", 0.0)), 30.0), "duration 30")
	_need(errors, int(sk.get("lv", 0)) == 3, "catalog default lv 3")
	_need(errors, DarkSide.draft_count(1) == 1 and DarkSide.draft_count(3) == 3, "draft count")
	_need(errors, is_equal_approx(DarkSide.DURATION, 30.0), "shared duration")
	_done += 1


func _check_levels(errors: PackedStringArray) -> void:
	var gs: RefCounted = StateScript.new()
	_need(errors, gs.skill_level_of(1, "dark_side") == 3, "unset level is lv3")
	var equip_err := String(gs.equip_set(1, 0, "dark_side"))
	_need(errors, equip_err == "", "equip dark side: %s" % equip_err)
	gs.select_skill_set(1)
	var equipped: Dictionary = gs.loadout()[0]
	_need(errors, int(equipped.get("lv", 0)) == 3, "loadout default lv3")
	gs.set_skill_level(1, "dark_side", 1)
	equipped = gs.loadout()[0]
	_need(errors, int(equipped.get("lv", 0)) == 1, "loadout uses chosen lv1")
	var saved: Dictionary = gs.to_dict()
	var sets: Array = saved["skill_sets"]
	_need(errors, int(sets[1]["levels"]["dark_side"]) == 1, "save stores level")
	var again: RefCounted = StateScript.new()
	_need(errors, String(again.from_dict(saved)) == "", "load save")
	_need(errors, again.skill_level_of(1, "dark_side") == 1, "loaded level sticks")
	sets[1].erase("levels")
	var legacy: RefCounted = StateScript.new()
	_need(errors, String(legacy.from_dict(saved)) == "", "load save without levels")
	_need(errors, legacy.skill_level_of(1, "dark_side") == 3, "missing level falls back to lv3")
	_done += 1


func _check_registers(errors: PackedStringArray) -> void:
	var near := _body_at(Vector2(10, 0))
	var far := _body_at(Vector2(400, 0))
	var reg_a := _register_at(Vector2(0, 0))
	var reg_b := _register_at(Vector2(500, 0))
	var jobs: Dictionary = DarkSide.plan([near, far], [near, far], [reg_a])
	_need(errors, String(jobs[near]["role"]) == "cashier", "nearer cashier takes the only register")
	_need(errors, jobs[near]["register"] == reg_a, "nearer register binding")
	_need(errors, String(jobs[far]["role"]) == "restock", "loser stays restock")
	jobs = DarkSide.plan([near, far], [near, far], [reg_a, reg_b])
	_need(errors, jobs[near]["register"] == reg_a and jobs[far]["register"] == reg_b, "each empty register goes to the nearer roll")
	var tie_a := _body_at(Vector2(0, 0))
	var tie_b := _body_at(Vector2(0, 0))
	jobs = DarkSide.plan([tie_a, tie_b], [tie_a, tie_b], [reg_a])
	var cashiers := 0
	if String(jobs[tie_a]["role"]) == "cashier":
		cashiers += 1
	if String(jobs[tie_b]["role"]) == "cashier":
		cashiers += 1
	_need(errors, cashiers == 1, "tie assigns exactly one cashier")
	jobs = DarkSide.plan([near], [near], [])
	_need(errors, String(jobs[near]["role"]) == "restock", "no empty register forces restock")
	var blocked: Array = DarkSide.open_registers([reg_a], [], [], reg_a.global_position, null)
	_need(errors, blocked.is_empty(), "player standing on the back blocks the register")
	var open: Array = DarkSide.open_registers([reg_a], [], [], Vector2(0, 800), null)
	_need(errors, open.size() == 1, "player far away leaves the register empty")
	var locked: Array = DarkSide.open_registers([reg_a], [], [], Vector2(0, 800), reg_a)
	_need(errors, locked.is_empty(), "player checkout lock blocks that register")
	var hired: Array = DarkSide.open_registers([reg_a], [reg_a], [], Vector2(0, 800), null)
	_need(errors, hired.is_empty(), "hired cashier binding blocks the register")
	_done += 1


func _check_guest(errors: PackedStringArray) -> void:
	var host := _host()
	add_child(host)
	var guest := _guest(host, CustomerScript.State.SEEK)
	guest.shopping.append("can")
	guest.cart.append("snack")
	guest.dissatisfaction = 40.0
	var reg := _register_at(Vector2(20, 20))
	reg.queue.append(guest)
	guest.register = reg
	guest.state = CustomerScript.State.QUEUE
	guest.begin_temp_clerk("restock", null)
	_need(errors, guest.temp_clerk, "became temp")
	_need(errors, guest.state == CustomerScript.State.TEMP, "temp state")
	_need(errors, guest.occupies_store(), "still counts as in-store guest")
	_need(errors, guest.mood == "臨時補貨", "restock label")
	_need(errors, reg.queue.is_empty(), "left the queue")
	_need(errors, guest.cart.is_empty(), "cart cleared onto the floor")
	_need(errors, host.drops.size() == 1, "cart dropped once")
	_need(errors, int(host.stock.get("snack", 0)) == 3, "drop does not put shelf stock back")
	_need(errors, guest.can_receive_delivery(), "still accepts delivery")
	_need(errors, not guest._list_icons.visible and not guest._bar.visible and not guest._dissat_track.visible, "hides list and dissat bar")
	var before: float = guest.dissatisfaction
	guest.accept_toss_box("can", 1)
	guest.apply_toss_reject("snack")
	guest.apply_soothe(0.0)
	guest.dash_knock_guest(50.0)
	_need(errors, is_equal_approx(guest.dissatisfaction, before), "dissat locked while hit")
	_need(errors, guest.temp_clerk and guest.state == CustomerScript.State.TEMP, "dash does not end the job")
	_need(errors, guest._dash_stun_left > 0.0, "dash still stuns")
	var left_before: float = guest.temp_left
	guest._physics_process(4.0)
	_need(errors, is_equal_approx(guest.temp_left, left_before - 4.0), "timer uses real seconds")
	_need(errors, guest.temp_clerk, "still working after partial timer")
	guest._temp_box_sku = "can"
	guest._temp_box_n = 4
	guest.end_temp_clerk()
	_need(errors, not guest.temp_clerk, "reverted")
	_need(errors, guest.state == CustomerScript.State.SEEK, "back to shopping")
	_need(errors, guest.cart.is_empty(), "extra holdings dropped")
	_need(errors, guest.shopping.size() == 2, "original list restored")
	_need(errors, String(guest.shopping[0]) == "snack" and String(guest.shopping[1]) == "can", "snapshot was cart then shopping")
	_need(errors, is_equal_approx(guest.dissatisfaction, 40.0), "dissat resumes from the lock")
	_need(errors, guest._list_icons.visible and guest._bar.visible, "icons and bar return")
	var box_drop := false
	for pile_set in host.drops:
		for pile in pile_set:
			if String(pile.get("sku")) == "can" and int(pile.get("n")) == 4:
				box_drop = true
	_need(errors, box_drop, "leftover restock box drops at feet")

	var clerk := _guest(host, CustomerScript.State.SEEK)
	var back := Vector2(reg.call("back_position"))
	clerk.global_position = back
	var payer := Node.new()
	payer.set_script(_payer_script())
	reg._front = payer
	clerk.begin_temp_clerk("cashier", reg)
	_need(errors, clerk.mood == "臨時收銀", "cashier label")
	clerk._temp_work = 1.0
	host._player = _lock_player(reg, true)
	clerk._physics_process(5.0)
	_need(errors, host.paid_n == 0, "yields while the player is checking out")
	_need(errors, is_equal_approx(clerk._temp_work, 1.0), "checkout circle pauses for the player")
	host._player = _lock_player(reg, false)
	clerk._physics_process(1.1)
	_need(errors, host.paid_n == 1 and host.paid == 18, "temp checkout pays like a hired clerk")
	_need(errors, bool(payer.get("finished")), "guest is finished")

	var walker := _guest(host, CustomerScript.State.SEEK)
	walker.set_physics_process(false)
	walker.global_position = Vector2.ZERO
	walker.temp_clerk = true
	walker._clear_route()
	walker._follow_to(Vector2(500, 0), 0.05)
	var slowed: float = walker.velocity.length()
	walker.temp_clerk = false
	walker.global_position = Vector2.ZERO
	walker._clear_route()
	walker._follow_to(Vector2(500, 0), 0.05)
	_need(errors, walker.velocity.length() > slowed * 2.0, "metal rush does not speed a temp clerk")
	_done += 1


func _check_pool(errors: PackedStringArray) -> void:
	var demo: Node2D = DemoScript.new()
	var folder := Node2D.new()
	add_child(folder)
	demo._customers = folder
	demo.cashiers.clear()
	var seek := _guest(demo, CustomerScript.State.SEEK)
	var paying := _guest(demo, CustomerScript.State.PAYING)
	var elite := _guest(demo, CustomerScript.State.SEEK)
	elite.is_elite = true
	var thief := _guest(demo, CustomerScript.State.SEEK)
	thief.is_thief = true
	var walking := _guest(demo, CustomerScript.State.TO_CASHIER)
	var raid := _guest(demo, CustomerScript.State.RAID)
	var reg := _register_at(Vector2.ZERO)
	var locked := _guest(demo, CustomerScript.State.QUEUE)
	var other := _guest(demo, CustomerScript.State.QUEUE)
	reg._front = locked
	var player := PlayerScript.new()
	player.command_lock = true
	player.target = reg
	demo._player = player
	for c in [seek, paying, elite, thief, walking, raid, locked, other]:
		_reparent(c, folder)
	demo.cast_dark_side(3)
	_need(errors, seek.temp_clerk and other.temp_clerk, "drafts a shopper and another queued guest")
	_need(errors, not paying.temp_clerk, "skips paying")
	_need(errors, not elite.temp_clerk, "skips elite")
	_need(errors, not thief.temp_clerk, "skips thief")
	_need(errors, not walking.temp_clerk, "skips list-done walker")
	_need(errors, not raid.temp_clerk, "skips raider")
	_need(errors, not locked.temp_clerk, "skips the guest being checked out")
	var temps := 0
	for c in folder.get_children():
		if bool(c.get("temp_clerk")):
			temps += 1
	_need(errors, temps == 2, "short pool still drafts who it can")
	var seek_left: float = seek.temp_left
	seek._physics_process(9.0)
	seek_left = seek.temp_left
	var fresh := _guest(demo, CustomerScript.State.SEEK)
	_reparent(fresh, folder)
	demo.cast_dark_side(1)
	_need(errors, fresh.temp_clerk and is_equal_approx(fresh.temp_left, 30.0), "recast drafts a new guest at 30s")
	_need(errors, is_equal_approx(seek.temp_left, seek_left), "recast does not refresh the first wave")
	_need(errors, not DarkSide.eligible(seek, null), "temps leave the next pool")
	var raised := Fundraise.choose(folder.get_children(), 3)
	_need(errors, not raised.has(seek) and not raised.has(fresh), "fundraise skips temps")
	demo.cast_dark_side(3)
	_need(errors, not paying.temp_clerk, "empty extra pool does not draft the excluded")
	seek._temp_plan_sku = "can"
	seek._temp_box_sku = "snack"
	seek._temp_shelf = reg
	var holds: Dictionary = demo.restock_holds(null)
	_need(errors, bool(holds["sku"].get("can", false)) and bool(holds["sku"].get("snack", false)), "temp restock reserves sku")
	_need(errors, holds["shelf"].has(reg), "temp restock reserves the shelf")
	var mine: Dictionary = demo.restock_holds(seek)
	_need(errors, not bool(mine["sku"].get("can", false)), "reservation skips the clerk who is holding it")
	_done += 1


func _check_cast_cd(errors: PackedStringArray) -> void:
	var host := Node.new()
	host.set_script(_cast_host_script())
	add_child(host)
	var player: CharacterBody2D = PlayerScript.new()
	add_child(player)
	player.game = host
	player.stats = _stats(10, 3)
	player._cast_slot(0)
	_need(errors, player.buff_left("dark_side") <= 0.0, "no shared buff window")
	_need(errors, player.cd_left("dark_side") > 29.0, "int 10 keeps the 30s cd")
	_need(errors, int(host.levels[0]) == 3, "cast passes lv3")
	player.stats = _stats(50, 1)
	player._cd.erase("dark_side")
	player._cast_slot(0)
	_need(errors, player.cd_left("dark_side") > 19.0 and player.cd_left("dark_side") < 21.0, "int 50 shortens cd to about 20s")
	_need(errors, int(host.levels[1]) == 1, "cast passes the chosen level")
	_done += 1


func _reparent(node: Node, parent: Node) -> void:
	var old := node.get_parent()
	if old != null:
		old.remove_child(node)
	parent.add_child(node)


func _guest(game: Node, state: int) -> CharacterBody2D:
	var guest: CharacterBody2D = CustomerScript.new()
	guest._game = game
	guest.state = state
	guest._list_icons = Node2D.new()
	guest.add_child(guest._list_icons)
	guest._bar = ColorRect.new()
	guest.add_child(guest._bar)
	guest._dissat_track = ColorRect.new()
	guest.add_child(guest._dissat_track)
	add_child(guest)
	guest.set_physics_process(false)
	return guest


func _host() -> Node:
	var host := Node.new()
	host.set_script(_host_script())
	host._world = Node2D.new()
	host.add_child(host._world)
	return host


func _body_at(at: Vector2) -> Node2D:
	var body := Node2D.new()
	add_child(body)
	body.global_position = at
	return body


func _register_at(at: Vector2) -> Node2D:
	var reg := Node2D.new()
	reg.set_script(_register_script())
	add_child(reg)
	reg.global_position = at
	return reg


func _lock_player(reg: Node, locked: bool) -> Node:
	var player := Node.new()
	player.set_script(_player_stub_script())
	player.command_lock = locked
	player.target = reg
	return player


func _stats(int_stat: int, lv: int) -> RefCounted:
	var st := RefCounted.new()
	st.set_script(_stats_script())
	st.int_stat = int_stat
	st.lv = lv
	return st


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func _host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
var phase := \"open\"
var stock := {\"snack\": 3}
var drops: Array = []
var paid := 0
var paid_n := 0
var _player = null
var _world: Node2D
func asking_early_close() -> bool:
	return false
func world_delta(_delta: float) -> float:
	return 0.0
func customer_move_mult() -> float:
	return 5.0
func spawn_loot_inplace(_origin: Vector2, piles: Array) -> void:
	drops.append(piles)
func _on_paid(amount: int, _from_elite: bool = false) -> void:
	paid += amount
	paid_n += 1
func find_path(_from: Vector2, to: Vector2) -> PackedVector2Array:
	return PackedVector2Array([to])
"""
	scr.reload()
	return scr


func _register_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node2D
var kind := \"cashier\"
var queue: Array = []
var _front = null
func back_position() -> Vector2:
	return global_position
func ready_customer():
	return _front
func dequeue(customer) -> void:
	queue.erase(customer)
	if _front == customer:
		_front = null
"""
	scr.reload()
	return scr


func _payer_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
var is_elite := false
var finished := false
func payout_total() -> int:
	return 18
func finish_paid() -> void:
	finished = true
"""
	scr.reload()
	return scr


func _player_stub_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
var command_lock := false
var target = null
"""
	scr.reload()
	return scr


func _stats_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends RefCounted
const Skills = preload(\"res://scripts/skills.gd\")
var str_stat := 10
var agi_stat := 10
var int_stat := 10
var lv := 3
func loadout() -> Array[Dictionary]:
	var sk := Skills.by_id(\"dark_side\")
	sk[\"lv\"] = lv
	var out: Array[Dictionary] = []
	out.append(sk)
	return out
func ult_skill() -> Dictionary:
	return {}
"""
	scr.reload()
	return scr


func _cast_host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
var levels: Array = []
func cast_dark_side(level: int) -> void:
	levels.append(level)
"""
	scr.reload()
	return scr
