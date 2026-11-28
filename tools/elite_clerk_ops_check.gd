extends Node
## Headless (#149): elite catalog parse + multi-role priority + freed chase target.


const ClerkScript = preload("res://scripts/clerk.gd")
const EliteClerkCatalog = preload("res://scripts/session/elite_clerk_catalog.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	SfxBus._muted = true

	var ids: Array[String] = EliteClerkCatalog.all_ids()
	_need(errors, not ids.is_empty(), "catalog has entries")
	for eid in ids:
		var stats: Dictionary = EliteClerkCatalog.stats_at(eid, 1)
		_need(errors, stats.has("str") and stats.has("agi") and stats.has("int"), "stats_at %s" % eid)
		var roles: Array[String] = EliteClerkCatalog.allowed_roles(eid)
		_need(errors, not roles.is_empty(), "allowed_roles %s" % eid)
		var defaults: Array[String] = EliteClerkCatalog.default_roles(eid)
		_need(errors, not defaults.is_empty(), "default_roles %s" % eid)
		for r in defaults:
			_need(errors, roles.has(r), "default ⊆ allowed %s/%s" % [eid, r])

	## Prefer a multi-role elite if present; else synthesize roles on first id.
	var pick := ids[0]
	for eid in ids:
		if EliteClerkCatalog.allowed_roles(eid).size() >= 2:
			pick = eid
			break
	var job_roles: Array = EliteClerkCatalog.default_roles(pick)
	if job_roles.size() < 2:
		job_roles = ["security", "cleaner", "cashier", "restock"]
		## Trim to allowed when catalog constrains.
		var allowed: Array[String] = EliteClerkCatalog.allowed_roles(pick)
		if not allowed.is_empty():
			var filtered: Array = []
			for r in job_roles:
				if allowed.has(String(r)):
					filtered.append(r)
			if filtered.size() >= 2:
				job_roles = filtered

	var host := Node.new()
	host.set_script(_host_script())
	add_child(host)
	host.set("phase", "open")

	var reg := Node2D.new()
	reg.set_script(_register_script())
	host.add_child(reg)

	var clerk: CharacterBody2D = ClerkScript.new()
	host.add_child(clerk)
	clerk.setup_elite(
		host,
		Vector2(100, 100),
		job_roles,
		reg,
		pick,
		EliteClerkCatalog.stats_at(pick, 1),
		{},
		EliteClerkCatalog.model_id(pick),
	)
	_need(errors, clerk.is_elite and clerk.elite_id == pick, "setup_elite marks elite")
	_need(errors, clerk.roles.size() >= 1, "roles installed")

	## No threats → falls through toward restock／cashier／security idle branch.
	clerk.set_physics_process(false)
	clerk._tick_multi(0.05)
	_need(errors, String(clerk.role) != "", "tick picks a role")

	## Security interrupt when a catchable thief is present.
	if clerk._has_role("security"):
		var thief := Node2D.new()
		thief.set_script(_thief_script())
		host.add_child(thief)
		thief.global_position = clerk.global_position + Vector2(20, 0)
		host.call("set_thieves", [thief])
		clerk._chase_target = null
		clerk._tick_multi(0.05)
		_need(errors, clerk.role == "security", "security outranks other jobs")
		## Freed chase target must not crash (untyped guard).
		clerk._chase_target = thief
		thief.queue_free()
		await get_tree().process_frame
		clerk._tick_multi(0.05)
		_need(errors, true, "tick after freed thief")

	## Cashier when register has a ready guest and no higher priority.
	if clerk._has_role("cashier"):
		host.call("set_thieves", [])
		clerk._chase_target = null
		clerk._scrubbing = false
		clerk._box_n = 0
		clerk._clean_target = null
		var guest := Node2D.new()
		guest.set_script(_guest_script())
		host.add_child(guest)
		reg.call("set_ready", guest)
		clerk._tick_multi(0.05)
		## Only assert cashier if security／cleaner had nothing — we cleared those.
		if not clerk._has_role("security") or host.call("thieves").is_empty():
			_need(errors, clerk.role == "cashier" or clerk.role == "restock" or clerk.role == "cleaner", "cashier／fallback role after clear")

	if errors.is_empty():
		print("OK elite clerk ops")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
var phase := \"open\"
var FLOOR_ORIGIN := Vector2.ZERO
var FLOOR_SIZE := Vector2(640, 480)
var shelves: Array = []
var _thieves: Array = []
var state = null
func _ready() -> void:
	var st := RefCounted.new()
	st.set(\"stock\", {})
	st.set(\"developed\", {})
	state = st
func asking_early_close() -> bool:
	return false
func cutscene_freezes_actors() -> bool:
	return false
func thieves() -> Array:
	return _thieves
func set_thieves(list: Array) -> void:
	_thieves = list
func dirts() -> Array:
	return []
func seat_locks_register(_reg) -> bool:
	return false
func restock_for(_cat) -> Node2D:
	return null
func restock_holds(_clerk) -> Array:
	return []
func shelf_stand(shelf: Node2D) -> Vector2:
	return shelf.global_position + Vector2(0, 40)
func sync_stock() -> void:
	pass
func note_clean(_seat, _actor) -> void:
	pass
func record_caught(_seat, _by, _actor) -> void:
	pass
func _on_paid(_amount, _elite, _seat, _actor, _perfect = true, _paid_customer = null, _player_checkout = false) -> void:
	pass
func customer_move_mult() -> float:
	return 1.0
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return PackedVector2Array([from, to])
"""
	scr.reload()
	return scr


func _register_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node2D
var _ready_guest = null
func ready_customer():
	return _ready_guest
func set_ready(g) -> void:
	_ready_guest = g
func back_position() -> Vector2:
	return global_position + Vector2(0, 52)
"""
	scr.reload()
	return scr


func _thief_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node2D
func is_active_thief() -> bool:
	return true
func in_fight() -> bool:
	return false
"""
	scr.reload()
	return scr


func _guest_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node2D
var is_boss := false
func blocks_auto_checkout() -> bool:
	return false
"""
	scr.reload()
	return scr


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
