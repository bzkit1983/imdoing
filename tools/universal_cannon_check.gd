extends Node
const Cannon = preload("res://scripts/universal_cannon.gd")
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
		return Skills.by_id("universal_cannon")

class Guest extends Node2D:
	var kind := ""
	var is_thief := false
	var temp_clerk := false
	var active := true
	var accepting := true
	var shopping: Array[String] = []
	var received := 0
	func is_active_thief() -> bool:
		return is_thief and active
	func can_receive_delivery() -> bool:
		return accepting and not is_thief and not shopping.is_empty()
	func accept_toss_box(sku: String, _n: int) -> int:
		if not can_receive_delivery() or not shopping.has(sku):
			return 0
		shopping.erase(sku)
		received += 1
		return 1
	func ko_box_hit_and_flee(_direction: Vector2) -> void:
		active = false

var errors: Array[String] = []
var host
var player
var other

func need(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)

func make_guest(pos: Vector2, thief: bool = false):
	var c := Guest.new()
	c.position = pos
	c.is_thief = thief
	c.shopping.assign(["can", "snack"])
	host._customers.add_child(c)
	return c

func flights() -> Array:
	var out: Array = []
	for c in host._world.get_children():
		if c is Shot and not c.is_queued_for_deletion():
			out.append(c)
	return out

func finish_flights() -> void:
	for f in flights():
		f._process(1.0)

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
	other = TestPlayer.new()
	other.game = host
	other.seat_id = 1
	host._world.add_child(other)
	other.set_physics_process(false)
	host._players.assign([player, other])
	host._player = player
	need(Skills.by_id("universal_cannon").cost == 2 and Skills.prep_picks_level(Skills.by_id("universal_cannon")), "catalog and levels")
	player._cast_slot(0)
	var cannon = player._cannon
	cannon.set_physics_process(false)
	need(is_instance_valid(cannon) and not player._cd.has("universal_cannon"), "deployment starts no cooldown")
	need(cannon.global_position == player.global_position, "deploy at feet")
	need(other.interactables.has(cannon), "all seats may interact")
	need(player._usable_cannon() == null, "empty cannon without carried goods is not usable")
	player.inventory.add_one("can")
	need(player._preview_target() == cannon, "zero-distance cannon is prioritized")
	need(not cannon is CollisionObject2D and cannon.find_children("*", "CollisionShape2D").is_empty(), "no solid collision or areas")
	need(host._obstacles.is_empty(), "no navigation obstacles added")
	for lv in [1, 2, 3]:
		cannon.level = lv
		need(cannon.capacity() == 8 + 4 * lv and cannon.interval() == float(6-lv), "level capacity and rate")
	cannon.level = 3
	player.inventory.clear()
	player.inventory.take_pieces("can", 2)
	player.inventory.take_pieces("snack", 3)
	need(cannon.load_from(player) == 3 and cannon.ammo == ["snack", "snack", "snack"], "load only top same-SKU run")
	need(player.inventory.count() == 2, "other carried SKU preserved")
	cannon.load_from(player)
	need(cannon.ammo == ["snack", "snack", "snack", "can", "can"], "new ammunition appends to FIFO tail")
	need(cannon.retrieve_to(player) and player.inventory.trailing_run().id == "snack" and cannon.ammo[0] == "snack", "retrieve next projectile to hand top")
	player.inventory.take_pieces("can", player.carry_cap() - player.inventory.count())
	var n: int = cannon.ammo.size()
	need(not cannon.retrieve_to(player) and cannon.ammo.size() == n, "full hands cannot retrieve")
	player.inventory.clear()
	cannon.ammo.clear()
	for _i in 19:
		cannon.ammo.append("can")
	player.inventory.take_pieces("snack", 3)
	need(cannon.load_from(player) == 1 and player.inventory.count() == 2 and cannon.ammo.size() == 20, "partial capacity load")
	# Real long/short input integration, ignoring instant-replenish buffs.
	cannon.ammo.clear()
	player.target = cannon
	player._pickup_used = false
	player._buffs["instant_restock"] = 20.0
	player._j_held = true
	player._j_time = Tuning.SKU_PICK_HOLD
	player._tick_action(0.01)
	need(cannon.ammo.is_empty() and player.hold_progress > 0.0 and player.hold_progress < 1.0, "loading uses base AGI circle, not instant buff")
	player._tick_action(10.0)
	need(cannon.ammo.size() == 2 and player.inventory.is_empty(), "loading circle transfers once")
	player._j_held = false
	player._do_short_interact()
	need(player.inventory.count() == 1 and cannon.ammo.size() == 1, "short action retrieves one")
	# Head-only blocking and live targets.
	var shelf = Shelf.new()
	shelf.position = Vector2(40, 0)
	host._world.add_child(shelf)
	host.shelves.append(shelf)
	cannon.ammo.assign(["milk", "can"])
	need(cannon.choose_target() == null, "unwanted front SKU blocks usable next SKU")
	cannon.retrieve_to(player)
	need(cannon.choose_target() == shelf, "removing blocked round unblocks next")
	var guest = make_guest(Vector2(80, 0))
	var thief = make_guest(Vector2(130, 0), true)
	need(cannon.choose_target() == thief, "thief priority and inclusive 130px boundary")
	thief.position.x = 130.1
	need(cannon.choose_target() == guest, "guest beats closer shelf; range excludes beyond boundary")
	guest.accepting = false
	need(cannon.choose_target() == shelf, "queue/unavailable guest excluded")
	guest.accepting = true
	guest.temp_clerk = true
	need(cannon.choose_target() == shelf, "temporary workers excluded")
	guest.temp_clerk = false
	# No time banking: unavailable target means zero accumulated interval.
	cannon.ammo.assign(["milk", "can"])
	cannon.tick_fire(30.0)
	need(flights().is_empty() and cannon.elapsed == 0.0, "no target does not bank shots")
	cannon.ammo.pop_front()
	cannon.tick_fire(2.9)
	need(flights().is_empty(), "first shot waits full interval")
	cannon.tick_fire(0.1)
	need(flights().size() == 1 and cannon.ammo.is_empty(), "one projectile emitted and ammo deducted once")
	var flight = flights()[0]
	flight.set_process(false)
	guest.accepting = false
	flight._process(1.0)
	need(guest.received == 0, "target revalidated on impact")
	guest.accepting = true
	# Explicit target unaffected by sniper states, and deliveries do not count as paid/COMBO.
	player._buffs["thief_sniper"] = 30.0
	cannon.ammo.assign(["can"])
	cannon.tick_fire(3.0)
	var delivery = flights().back()
	delivery.set_process(false)
	need(delivery.target == guest, "player sniper cannot override cannon target")
	delivery._process(1.0)
	need(guest.received == 1 and host.revenue == 0 and host.served == 0, "delivery does not checkout")
	# Lock pauses and resets firing, with another seat blocked.
	cannon.ammo.assign(["can", "can"])
	cannon.tick_fire(2.0)
	need(player._interact_try(cannon), "owner acquires interaction lock")
	need(not other._interact_try(cannon), "other seat cannot interact simultaneously")
	cannon._physics_process(3.0)
	need(cannon.elapsed == 0.0 and cannon.ammo.size() == 2, "interaction suspends firing")
	player._interact_release(cannon)
	cannon.tick_fire(2.9)
	need(cannon.ammo.size() == 2, "release restarts full interval")
	cannon.tick_fire(0.1)
	var in_air = flights().back()
	in_air.set_process(false)
	# Cancelling preserves the launched projectile and drops loaded stock.
	player._cast_slot(0)
	need(cannon.dismissed and is_instance_valid(in_air), "cancel keeps projectile alive")
	need(is_equal_approx(player._cd["universal_cannon"], 60.0), "cooldown begins only on cancel")
	in_air._process(1.0)
	need(in_air.count == 0, "projectile settles after turret cancellation")
	player._cast_slot(0)
	need(player._cannon == null, "cooldown blocks redeploy")
	need(is_equal_approx(Tuning.cd_seconds(60.0, 50), 40.0), "INT cooldown scales to forty")
	# Concurrent hits on the same thief only count once, attributed to cannon owner.
	thief.position = Vector2(90, 0)
	var second = host.deploy_universal_cannon(Vector2.ZERO, 3, 1)
	second.set_physics_process(false)
	second.ammo.assign(["can", "can"])
	second.tick_fire(3.0)
	var shot1 = flights().back()
	shot1.set_process(false)
	second.tick_fire(3.0)
	var shot2 = flights().back()
	shot2.set_process(false)
	shot1._process(1.0)
	shot2._process(1.0)
	need(host.thieves_caught == 1 and host.seat_caught[1] == 1, "single KO and per-seat XP attribution")
	# Collector sees loaded and airborne inventory; closeout removes all exactly once.
	second.ammo.assign(["snack", "snack"])
	var before: Dictionary = host._collect_shelf_floor_pieces()
	need(int(before.get("snack", 0)) >= 2, "loaded stock included in unsold accounting")
	var obstacles: int = host._obstacles.size()
	second.set_physics_process(true)
	var timer_before: float = second.elapsed
	get_tree().paused = true
	await get_tree().process_frame
	need(second.elapsed == timer_before, "pause freezes cannon")
	get_tree().paused = false
	second.set_physics_process(false)
	host.dismiss_universal_cannons()
	var after: Dictionary = host._collect_shelf_floor_pieces()
	need(before == after, "dismissal moves loaded stock to floor without creation or loss")
	need(second.dismissed and host._obstacles.size() == obstacles, "no obstacle removal needed")
	other.inventory.take_pieces("milk", 2)
	need(int(host._collect_player_carry_pieces().get("milk", 0)) == 3, "all seated players carried stock included")
	host._clear_credited_unsold()
	need(host._collect_unsold_pieces().is_empty(), "credited stock cleared everywhere and cannot return twice")
	need(other.inventory.is_empty(), "guest seat carry cleared after warehouse return")
	if errors.is_empty():
		print("OK universal cannon")
	else:
		for error in errors:
			push_error(error)
	host.free()
	get_tree().quit(0 if errors.is_empty() else 1)
