extends Node
const Cannon = preload("res://scripts/shelf_cannon.gd")
const Shot = preload("res://scripts/cannon_shot.gd")
const Shelf = preload("res://scripts/shelf.gd")
const Skills = preload("res://scripts/skills.gd")
const Tuning = preload("res://scripts/tuning.gd")
const Sheet = preload("res://scripts/session/character_sheet.gd")

class LiveHost extends "res://scripts/demo.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func play_ko_banner() -> void:
		pass

class TestPlayer extends "res://scripts/player.gd":
	func _skill_at(_i: int) -> Dictionary:
		return Skills.by_id("shelf_cannon")

var errors: Array[String] = []
var host
var player

func need(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)

func flights() -> Array:
	var out: Array = []
	for child in host._world.get_children():
		if child is Shot and not child.is_queued_for_deletion():
			out.append(child)
	return out

func finish_flights() -> void:
	for flight in flights():
		flight._process(1.0)

func make_shelf(pos: Vector2, category: String = Tuning.CAT_DRY):
	var shelf = Shelf.new()
	shelf.position = pos
	shelf.category = category
	host._world.add_child(shelf)
	host.shelves.append(shelf)
	return shelf

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	SfxBus._muted = true
	host = LiveHost.new()
	add_child(host)
	host.phase = "open"
	host._world = Node2D.new()
	host.add_child(host._world)
	host._customers = Node2D.new()
	host._world.add_child(host._customers)
	player = TestPlayer.new()
	player.game = host
	player.stats = Sheet.blank()
	host._world.add_child(player)
	player.set_physics_process(false)
	host._players.assign([player])
	host._player = player
	need(Skills.by_id("shelf_cannon").cost == 2, "COST 2 catalog")
	need(Skills.prep_picks_level(Skills.by_id("shelf_cannon")), "prep level selection")
	for lv in [1, 2, 3]:
		var c = Cannon.new()
		c.level = lv
		need(c.interval() == float(5 - lv) and c.capacity() == 50, "level rate and fixed capacity")
		c.free()
	player._cast_slot(0)
	var cannon = player._shelf_cannon
	cannon.set_physics_process(false)
	need(is_instance_valid(cannon) and not player._cd.has("shelf_cannon"), "deploy without cooldown")
	need(cannon.global_position == player.global_position, "deploy at feet")
	need(not cannon is CollisionObject2D and cannon.find_children("*", "CollisionShape2D").is_empty(), "no solid collision")
	need(host._obstacles.is_empty(), "no navigation obstacles")
	player.inventory.take_pieces("can", 30)
	need(cannon.load_from(player) == 30 and player.inventory.is_empty(), "loads hand top run")
	player.inventory.take_pieces("snack", 30)
	need(cannon.load_from(player) == 20 and player.inventory.count() == 10, "partial load at 50 capacity")
	need(cannon.ammo.size() == 50 and cannon.ammo[0] == "can" and cannon.ammo[29] == "can" and cannon.ammo[30] == "snack", "FIFO keeps load order")
	var shelf_near = make_shelf(Vector2(260, 0))
	var shelf_far = make_shelf(Vector2(150, 0))
	need(cannon.choose_target() == shelf_far, "nearest compatible shelf selected")
	shelf_far.category = Tuning.CAT_FROZEN
	need(cannon.choose_target() == shelf_near, "incompatible shelf excluded")
	shelf_near.position.x = 260
	need(cannon.choose_target() == shelf_near, "260px boundary is inclusive")
	shelf_near.position.x = 260.1
	need(cannon.choose_target() == null, "range excludes beyond 260px")
	# No target never banks elapsed time; new target starts a full interval.
	cannon.tick_fire(20.0)
	need(cannon.elapsed == 0.0 and flights().is_empty(), "no target does not bank fire time")
	shelf_near.position.x = 200
	shelf_near.category = Tuning.CAT_DRY
	cannon.level = 3
	cannon.ammo.assign(["can"])
	cannon.tick_fire(1.9)
	need(flights().is_empty(), "first shot waits full interval")
	cannon.tick_fire(0.1)
	need(flights().size() == 1 and cannon.ammo.is_empty(), "one item launched and deducted")
	var flight = flights()[0]
	flight.set_process(false)
	shelf_near.add_items("can", shelf_near.capacity)
	flight._process(1.0)
	need(shelf_near.count == shelf_near.capacity, "impact revalidates full shelf")
	need(host._collect_shelf_floor_pieces().get("can", 0) >= 1, "failed impact drops projectile item")
	# Load-only input and loaded stock cancellation.
	shelf_near.take_all()
	player.inventory.clear()
	player.inventory.take_pieces("milk", 2)
	cannon.ammo.clear()
	player.target = cannon
	player._pickup_used = false
	player._buffs["instant_restock"] = 20.0
	player._j_held = true
	player._j_time = Tuning.SKU_PICK_HOLD
	player._tick_action(0.01)
	need(player.hold_progress > 0.0 and cannon.ammo.is_empty(), "loading starts Circle")
	player._tick_action(10.0)
	need(cannon.ammo == ["milk", "milk"] and player.inventory.is_empty(), "long hold loads once")
	player._release_interact()
	player._j_held = false
	need(cannon.ammo.size() == 2 and player.inventory.is_empty(), "short tap cannot retrieve ammunition")
	need(get_node("/root/InteractLock").holder_of(cannon) == -1, "release unlocks shelf cannon")
	var puppet = Cannon.new()
	puppet.host = host
	puppet.net_puppet = true
	host._world.add_child(puppet)
	puppet.set_physics_process(false)
	puppet.apply_net_ammo(5, "can")
	player.inventory.take_pieces("milk", 1)
	var carry_before: int = player.inventory.count()
	need(puppet.available_for(player), "network puppet remains interactable for Host intent")
	need(puppet.load_from(player) == 0 and puppet.ammo.size() == 5 and player.inventory.count() == carry_before, "network puppet cannot mutate client stock")
	player.inventory.clear()
	puppet.free()
	# Concurrent skill pieces and cancel cooldown.
	var universal = host.deploy_universal_cannon(player.global_position, 3, 0)
	need(is_instance_valid(universal) and is_instance_valid(cannon), "universal and shelf turrets coexist")
	var before: Dictionary = host._collect_shelf_floor_pieces()
	player._cast_slot(0)
	need(cannon.dismissed and is_equal_approx(player._cd["shelf_cannon"], 60.0), "cancel starts base cooldown")
	need(is_equal_approx(Tuning.cd_seconds(60.0, 50), 40.0), "INT scales cooldown to 40s")
	var after: Dictionary = host._collect_shelf_floor_pieces()
	need(before == after, "cancellation moves ammo to floor without loss")
	# Day close drops cannon stock before unsold collection, then clears it once.
	var remaining = host.deploy_shelf_cannon(Vector2(20, 20), 2, 0)
	remaining.set_physics_process(false)
	remaining.ammo.assign(["snack", "snack"])
	var close_before: Dictionary = host._collect_shelf_floor_pieces()
	host.dismiss_shelf_cannons()
	need(close_before == host._collect_shelf_floor_pieces(), "closeout dismissal preserves unsold stock")
	host._clear_credited_unsold()
	need(host._collect_unsold_pieces().is_empty(), "credited stock cannot return twice")
	if errors.is_empty():
		print("OK shelf cannon")
	else:
		for error in errors:
			push_error(error)
	host.free()
	get_tree().quit(0 if errors.is_empty() else 1)
