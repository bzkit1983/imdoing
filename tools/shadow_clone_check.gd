extends Node
## Headless: Multiple Shadow Clone catalog, spawn, jobs, recast, hits, closeout.


const PlayerScript = preload("res://scripts/player.gd")
const Skills = preload("res://scripts/skills.gd")
const Tuning = preload("res://scripts/tuning.gd")
const DarkSide = preload("res://scripts/dark_side.gd")
const ShadowCloneCast = preload("res://scripts/shadow_clone_cast.gd")
const ShadowCloneScript = preload("res://scripts/shadow_clone.gd")
const CustomerScript = preload("res://scripts/customer.gd")
const StateScript = preload("res://scripts/game_state.gd")
const DemoScript = preload("res://scripts/demo.gd")
const PrepPages = preload("res://scripts/prep/prep_pages.gd")
const PrepMenu = preload("res://scripts/prep_menu.gd")

var _done := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	_check_catalog(errors)
	_check_levels(errors)
	_check_spawn(errors)
	_check_clone(errors)
	_check_cast(errors)
	_check_hits(errors)
	_need(errors, _done == 6, "every check finished")
	if errors.is_empty():
		print("OK shadow clone")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _check_catalog(errors: PackedStringArray) -> void:
	var sk: Dictionary = Skills.by_id("shadow_clone")
	_need(errors, PrepPages != null and PrepMenu != null, "prep scripts parse")
	_need(errors, not sk.is_empty(), "skill exists")
	_need(errors, String(sk.get("name")) == "多重影分身", "full name equals short name")
	_need(errors, int(sk.get("cost", 0)) == 3, "cost 3")
	_need(errors, bool(sk.get("shadow_clone", false)), "flag")
	_need(errors, Skills.prep_picks_level(sk), "prep picks level")
	_need(errors, is_equal_approx(float(sk.get("cd", 0.0)), 30.0), "listed cd 30")
	_need(errors, is_equal_approx(float(sk.get("duration", 0.0)), 30.0), "duration 30")
	_need(errors, int(sk.get("lv", 0)) == 3, "catalog default lv 3")
	_need(errors, ShadowCloneCast.clone_count(1) == 1 and ShadowCloneCast.clone_count(3) == 3, "clone count")
	_need(errors, is_equal_approx(ShadowCloneCast.DURATION, 30.0), "shared duration")
	var equipped := false
	for row in Skills.EQUIPPED:
		if String(row.get("id")) == "shadow_clone":
			equipped = true
	_need(errors, not equipped, "not in default 5-cost loadout")
	_done += 1


func _check_levels(errors: PackedStringArray) -> void:
	var gs: RefCounted = StateScript.new()
	_need(errors, gs.skill_level_of(1, "shadow_clone") == 3, "unset level is lv3")
	var equip_err := String(gs.equip_set(1, 0, "shadow_clone"))
	_need(errors, equip_err == "", "equip shadow clone: %s" % equip_err)
	gs.select_skill_set(1)
	var equipped: Dictionary = gs.loadout()[0]
	_need(errors, int(equipped.get("lv", 0)) == 3, "loadout default lv3")
	gs.set_skill_level(1, "shadow_clone", 1)
	equipped = gs.loadout()[0]
	_need(errors, int(equipped.get("lv", 0)) == 1, "loadout uses chosen lv1")
	var saved: Dictionary = gs.to_dict()
	var sets: Array = saved["skill_sets"]
	_need(errors, int(sets[1]["levels"]["shadow_clone"]) == 1, "save stores level")
	var again: RefCounted = StateScript.new()
	_need(errors, String(again.from_dict(saved)) == "", "load save")
	_need(errors, again.skill_level_of(1, "shadow_clone") == 1, "loaded level sticks")
	sets[1].erase("levels")
	var legacy: RefCounted = StateScript.new()
	_need(errors, String(legacy.from_dict(saved)) == "", "load save without levels")
	_need(errors, legacy.skill_level_of(1, "shadow_clone") == 3, "missing level falls back to lv3")
	_need(errors, gs.skill_level_of(1, "dark_side") == 3, "dark side still defaults lv3")
	_done += 1


func _check_spawn(errors: PackedStringArray) -> void:
	var origin := Vector2(320, 320)
	var cell := StateScript.CELL
	var down := ShadowCloneCast.spawn_positions(origin, Vector2.DOWN, 3, [], [])
	_need(errors, down.size() == 3, "lv3 three spots")
	_need(errors, down[0].is_equal_approx(origin + Vector2(-cell, 0)), "left first")
	_need(errors, down[1].is_equal_approx(origin + Vector2(cell, 0)), "right second")
	_need(errors, down[2].is_equal_approx(origin + Vector2(0, cell)), "front third")
	var blocked_left: Array = [Rect2(origin + Vector2(-cell, 0) - Vector2(8, 8), Vector2(16, 16))]
	var skip := ShadowCloneCast.spawn_positions(origin, Vector2.DOWN, 2, blocked_left, [])
	_need(errors, skip[0].is_equal_approx(origin + Vector2(cell, 0)), "skip occupied left")
	var walls: Array = [
		Rect2(origin + Vector2(-cell, 0) - Vector2(8, 8), Vector2(16, 16)),
		Rect2(origin + Vector2(cell, 0) - Vector2(8, 8), Vector2(16, 16)),
		Rect2(origin + Vector2(0, cell) - Vector2(8, 8), Vector2(16, 16)),
	]
	var overlap := ShadowCloneCast.spawn_positions(origin, Vector2.DOWN, 3, walls, [])
	_need(errors, overlap[0].is_equal_approx(origin) and overlap[2].is_equal_approx(origin), "all blocked overlaps player cell")
	var person := ShadowCloneCast.spawn_positions(origin, Vector2.DOWN, 1, [], [origin + Vector2(-cell, 0)])
	_need(errors, person[0].is_equal_approx(origin + Vector2(cell, 0)), "skip person then take next")
	_done += 1


func _check_clone(errors: PackedStringArray) -> void:
	var host := _host()
	add_child(host)
	var clone: CharacterBody2D = ShadowCloneScript.new()
	add_child(clone)
	clone.set_physics_process(false)
	clone.setup(host, Vector2(40, 40), {
		"str": 20, "agi": 30, "int": 50,
		"move_pct": 0.20, "restock_pct": 0.20, "checkout_pct": 0.20, "wave_step": true,
	})
	clone.begin_job("restock", null)
	_need(errors, clone.is_shadow_clone, "flag")
	_need(errors, clone.role == "restock", "restock job")
	_need(errors, clone._label.text == "分身補貨", "restock label")
	_need(errors, is_equal_approx(clone._sprite.modulate.a, ShadowCloneCast.ALPHA), "slight transparency")
	_need(errors, is_equal_approx(clone.temp_left, 30.0), "fresh timer")
	var spd: float = clone.walk_speed()
	host.customer_move_mult = 5.0
	_need(errors, is_equal_approx(clone.walk_speed(), spd), "the world / metal rush do not change clone walk")
	clone.dirt_contacts = 1
	_need(errors, is_equal_approx(clone.walk_speed(), spd), "wave step ignores dirt slow")
	clone.wave_step = false
	_need(errors, clone.walk_speed() < spd * 0.6, "dirt slows without wave step")
	clone.dirt_contacts = 0
	clone.wave_step = true
	var need_int10 := Tuning.checkout_seconds(10)
	_need(errors, clone._checkout_need() < need_int10 * 0.55, "snapshot int 50 plus checkout passive shortens circle")
	var left_before: float = clone.temp_left
	clone._physics_process(4.0)
	_need(errors, is_equal_approx(clone.temp_left, left_before - 4.0), "timer uses real seconds")
	_need(errors, not clone._vanishing, "still up after partial timer")
	clone._box_sku = "can"
	clone._box_n = 4
	clone.dash_knock()
	_need(errors, clone._dash_stun_left > 0.0, "dash stuns")
	_need(errors, clone._box_n == 0, "dash drops the box")
	_need(errors, host.drops.size() == 1, "dropped box lands")
	var stun_left: float = clone._dash_stun_left
	clone._physics_process(0.5)
	_need(errors, is_equal_approx(clone.temp_left, left_before - 4.5), "stun does not pause the 30s")
	_need(errors, clone._dash_stun_left < stun_left, "stun ticks down")
	clone.apply_toss_hit()
	_need(errors, clone._dash_stun_left > 0.0, "toss does not stun")
	var guest := _guest(host, CustomerScript.State.SEEK)
	guest.begin_temp_clerk("restock", null)
	_need(errors, guest.temp_clerk, "dark side temp stays a guest")
	clone.vanish()
	_need(errors, clone._vanishing, "smoke despawn")
	_need(errors, guest.temp_clerk, "vanishing a clone does not end dark side")
	_done += 1


func _check_cast(errors: PackedStringArray) -> void:
	var demo: Node2D = DemoScript.new()
	demo.set_process(false)
	demo.phase = "open"
	demo._world = Node2D.new()
	add_child(demo._world)
	demo._customers = Node2D.new()
	add_child(demo._customers)
	demo.cashiers.clear()
	var player: CharacterBody2D = PlayerScript.new()
	add_child(player)
	player.set_physics_process(false)
	player.game = demo
	player.global_position = Vector2(200, 200)
	player.facing = Vector2.DOWN
	player.stats = _stats(10, 10, 10, "shadow_clone", 3)
	demo._player = player
	demo.cast_shadow_clone(3)
	_freeze_clones(demo)
	_need(errors, demo.shadow_clones().size() == 3, "lv3 spawns three")
	var guest := _guest(demo, CustomerScript.State.SEEK)
	_reparent(guest, demo._customers)
	guest.begin_temp_clerk("restock", null)
	demo.cast_shadow_clone(1)
	_freeze_clones(demo)
	_need(errors, demo.shadow_clones().size() == 1, "recast despawns old then spawns new count")
	_need(errors, guest.temp_clerk, "recast does not dismiss dark side temps")
	var clone: Node = demo.shadow_clones()[0]
	clone._plan_sku = "can"
	clone._box_sku = "snack"
	clone._shelf = player
	clone.role = "restock"
	var holds: Dictionary = demo.restock_holds(null)
	_need(errors, bool(holds["sku"].get("can", false)) and bool(holds["sku"].get("snack", false)), "clone restock reserves sku")
	_need(errors, holds["shelf"].has(player), "clone restock reserves the shelf")
	var cashier_clone: Node = demo.shadow_clones()[0]
	var reg := _register_at(Vector2.ZERO)
	cashier_clone.begin_job("cashier", reg)
	var hired: Array = demo._hired_cashier_registers()
	_need(errors, hired.has(reg), "clone cashier occupies the register for dark side")
	demo.dismiss_shadow_clones()
	_need(errors, demo.shadow_clones().is_empty(), "dismiss clears clones")
	var host := Node.new()
	host.set_script(_cast_host_script())
	add_child(host)
	var caster: CharacterBody2D = PlayerScript.new()
	add_child(caster)
	caster.game = host
	caster.stats = _stats(10, 10, 10, "shadow_clone", 3)
	caster._cast_slot(0)
	_need(errors, caster.buff_left("shadow_clone") <= 0.0, "no shared buff window")
	_need(errors, caster.cd_left("shadow_clone") > 29.0, "int 10 keeps the 30s cd")
	_need(errors, int(host.levels[0]) == 3, "cast passes lv3")
	caster.stats = _stats(10, 10, 50, "shadow_clone", 1)
	caster._cd.erase("shadow_clone")
	caster._cast_slot(0)
	_need(errors, caster.cd_left("shadow_clone") > 19.0 and caster.cd_left("shadow_clone") < 21.0, "int 50 shortens cd to about 20s")
	_need(errors, int(host.levels[1]) == 1, "cast passes the chosen level")
	_done += 1


func _check_hits(errors: PackedStringArray) -> void:
	var demo: Node2D = DemoScript.new()
	demo.set_process(false)
	demo.phase = "open"
	demo._world = Node2D.new()
	add_child(demo._world)
	demo._customers = Node2D.new()
	add_child(demo._customers)
	demo.shelves.clear()
	var clone: CharacterBody2D = ShadowCloneScript.new()
	demo._world.add_child(clone)
	clone.set_physics_process(false)
	clone.setup(demo, Vector2(100, 100), {})
	clone.begin_job("restock", null)
	clone._box_sku = "can"
	clone._box_n = 4
	demo._resolve_toss_landing(Vector2(100, 0), Vector2(100, 200), "snack", 4, Vector2.DOWN)
	_need(errors, clone._box_n == 0, "toss after shelf miss interrupts the clone")
	demo._resolve_toss_landing(Vector2(100, 0), Vector2(100, 200), "snack", 2, Vector2.ZERO)
	_need(errors, clone._dash_stun_left <= 0.0, "foot drop does not stun a clone")
	var guest := _guest(demo, CustomerScript.State.SEEK)
	_reparent(guest, demo._customers)
	guest.global_position = Vector2(300, 100)
	guest.shopping.append("milk")
	guest.shopping.append("can")
	clone.global_position = Vector2(300, 140)
	clone._box_n = 4
	clone._box_sku = "can"
	demo._resolve_toss_landing(Vector2(300, 0), Vector2(300, 200), "milk", 1, Vector2.DOWN)
	_need(errors, clone._box_n == 4, "guest hit wins over clone")
	_need(errors, guest.cart.has("milk"), "guest still receives the toss")
	var dash_guest := _guest(demo, CustomerScript.State.SEEK)
	_reparent(dash_guest, demo._customers)
	dash_guest.shopping.append("snack")
	var player: CharacterBody2D = PlayerScript.new()
	player.set_physics_process(false)
	player.game = demo
	player.global_position = Vector2(10, 10)
	clone.global_position = Vector2(20, 10)
	dash_guest.global_position = Vector2(400, 400)
	dash_guest._dash_stun_left = 0.0
	_need(errors, player._dash_guests().is_empty(), "far guest is not a dash target")
	_need(errors, player._dash_clone() == clone, "dash picker finds the clone")
	clone.dash_knock()
	_need(errors, clone._dash_stun_left > 0.0, "dash knocks the clone")
	clone._dash_stun_left = 0.0
	dash_guest.global_position = Vector2(12, 10)
	dash_guest._dash_stun_left = 0.0
	_need(errors, not player._dash_guests().is_empty(), "near guest is the dash target")
	_need(errors, player._dash_clone() == clone, "clone still in range after guest")
	_done += 1


func _freeze_clones(demo: Node) -> void:
	for c in demo.shadow_clones():
		c.set_physics_process(false)


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


func _register_at(at: Vector2) -> Node2D:
	var reg := Node2D.new()
	reg.set_script(_register_script())
	add_child(reg)
	reg.global_position = at
	return reg


func _stats(str_stat: int, agi_stat: int, int_stat: int, skill_id: String, lv: int) -> RefCounted:
	var st := RefCounted.new()
	st.set_script(_stats_script())
	st.str_stat = str_stat
	st.agi_stat = agi_stat
	st.int_stat = int_stat
	st.skill_id = skill_id
	st.lv = lv
	return st


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func _host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
var phase := \"open\"
var customer_move_mult := 1.0
var drops: Array = []
var _world: Node2D
var _player = null
func asking_early_close() -> bool:
	return false
func spawn_loot_inplace(_origin: Vector2, piles: Array) -> void:
	drops.append(piles)
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


func _stats_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends RefCounted
const Skills = preload(\"res://scripts/skills.gd\")
var str_stat := 10
var agi_stat := 10
var int_stat := 10
var skill_id := \"shadow_clone\"
var lv := 3
func loadout() -> Array[Dictionary]:
	var sk := Skills.by_id(skill_id)
	sk[\"lv\"] = lv
	var out: Array[Dictionary] = []
	out.append(sk)
	return out
func ult_skill() -> Dictionary:
	return {}
func has_flag(_flag: String) -> bool:
	return false
"""
	scr.reload()
	return scr


func _cast_host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
var levels: Array = []
func cast_shadow_clone(level: int) -> void:
	levels.append(level)
"""
	scr.reload()
	return scr
