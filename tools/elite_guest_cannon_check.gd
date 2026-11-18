extends Node

const Cannon = preload("res://scripts/elite_guest_cannon.gd")
const Shot = preload("res://scripts/elite_guest_cannon_shot.gd")
const Skills = preload("res://scripts/skills.gd")
const Tuning = preload("res://scripts/tuning.gd")
const StateScript = preload("res://scripts/game_state.gd")
const Sheet = preload("res://scripts/session/character_sheet.gd")

class LiveHost extends "res://scripts/demo.gd":
	var delivered: Array = []
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func note_deliver(seat: int, mode: String, n: int = 1, perfect: bool = false) -> void:
		delivered.append([seat, mode, n, perfect])

class Guest extends Node2D:
	var is_elite: bool = true
	var is_thief: bool = false
	var temp_clerk: bool = false
	var state: int = 1
	var shopping: Array[String] = []
	var cart: Array[String] = []
	var dissatisfaction: float = 25.0
	var checkout_started: bool = false
	func can_receive_delivery() -> bool:
		return is_elite and not temp_clerk and not is_thief and not shopping.is_empty() and state not in [5, 6, 7, 8, 9]
	func accept_toss_box(sku: String, n: int) -> int:
		if not can_receive_delivery() or not shopping.has(sku):
			return 0
		var take := mini(n, shopping.count(sku))
		for _i in take:
			cart.append(sku)
			shopping.erase(sku)
		dissatisfaction = maxf(0.0, dissatisfaction - 15.0 * take)
		if shopping.is_empty():
			checkout_started = true
			state = 5
		return take

var errors: Array[String] = []
var host: LiveHost

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
		flight._process(Tuning.DROP_FLIGHT_SEC + 0.1)

func make_guest(pos: Vector2, skus: Array[String], elite: bool = true) -> Guest:
	var guest := Guest.new()
	guest.position = pos
	guest.is_elite = elite
	guest.shopping.assign(skus)
	host._customers.add_child(guest)
	return guest

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
	host.state = StateScript.new()
	host.state.stock = {"milk": 3, "snack": 1, "can": 0}
	host._net.bind(host)
	need(Skills.by_id("elite_guest_cannon").cost == 2, "COST 2 catalog")
	need(Skills.prep_picks_level(Skills.by_id("elite_guest_cannon")), "prep level choice")
	need(Skills.by_id("elite_guest_cannon").duration == 30.0, "30s duration catalog")
	need(Skills.by_id("elite_guest_cannon").cd == 45.0, "45s cooldown catalog")
	need(Tuning.cd_seconds(45.0, 10) == 45.0, "baseline skill cooldown")
	need(Tuning.cd_seconds(45.0, 50) == 30.0, "INT-scaled cooldown")
	var cannon: Node2D = host.deploy_elite_guest_cannon(Vector2.ZERO, 1, 0)
	need(is_instance_valid(cannon) and cannon.position == Vector2.ZERO, "deploy at player position")
	need(not cannon is CollisionObject2D, "turret does not block movement")
	need(cannon.interval() == 3.0, "LV1 fire interval")
	cannon.level = 2
	need(cannon.interval() == 2.0, "LV2 fire interval")
	cannon.level = 3
	need(cannon.interval() == 0.5, "LV3 fire interval")
	# Nearest eligible means skip a closer normal guest and a closer out-of-stock elite.
	make_guest(Vector2(30, 0), ["milk"], false)
	var empty := make_guest(Vector2(50, 0), ["can"])
	var served := make_guest(Vector2(500, 0), ["milk"])
	need(cannon.choose_target().get("guest") == served, "nearest stocked elite selected shop-wide")
	# A second cannon cannot reserve the same single pending SKU.
	var refreshed := host.deploy_elite_guest_cannon(Vector2(5, 0), 3, 0)
	need(refreshed == cannon, "recast refreshes the same seat turret")
	need(cannon.remaining == 30.0 and cannon.owner_seat == 0 and cannon.position == Vector2.ZERO, "refresh preserves owner and position")
	cannon.cooldown_left = 1.5
	cannon.refresh_level(3)
	need(cannon.cooldown_left == 1.5, "refresh preserves current firing interval")
	var second := host.deploy_elite_guest_cannon(Vector2(5, 0), 3, 1)
	need(second != cannon and second.owner_seat == 1, "each player can place one turret")
	need(host.reserve_elite_guest_cannon_need(served, "milk"), "first delivery reserves item")
	need(host.elite_guest_cannon_reserved_count(served, "milk") == 1, "reservation count tracked")
	need(not host.reserve_elite_guest_cannon_need(served, "milk"), "duplicate single demand reservation denied")
	host.release_elite_guest_cannon_need(served.get_instance_id(), "milk")
	# Launch one valid shot. Warehouse decreases once and the item is reserved until impact.
	cannon.cooldown_left = 0.0
	cannon._physics_process(0.01)
	need(host.state.stock["milk"] == 2, "warehouse stock deducted at launch")
	need(host.elite_guest_cannon_reserved_count(served, "milk") == 1, "flight holds target reservation")
	need(flights().size() == 1, "one projectile launched")
	second._physics_process(0.01)
	need(flights().size() == 1 and host.state.stock["milk"] == 2, "other player's turret cannot duplicate reserved demand")
	finish_flights()
	need(served.cart == ["milk"] and served.shopping.is_empty(), "hit completes one actual requested SKU")
	need(served.dissatisfaction == 10.0, "successful item reduces elite dissatisfaction")
	need(host.delivered.size() == 1 and host.delivered[0] == [0, "cannon", 1, false], "delivery attribution excludes perfect combo")
	need(host.elite_guest_cannon_reserved_count(served, "milk") == 0, "reservation released at impact")
	# Missing SKUs are skipped in list order while later stocked items remain serviceable.
	var skipper := make_guest(Vector2(120, 0), ["can", "snack"])
	cannon.cooldown_left = 0.0
	cannon._physics_process(0.01)
	need(host.state.stock["snack"] == 0 and skipper.cart == ["snack"] and skipper.shopping == ["can"], "later stocked item skips unavailable need")
	finish_flights()
	need(served.checkout_started, "completed list proceeds to checkout")
	# Invalidating a target in flight drops the already-paid item instead of completing twice.
	var invalid := make_guest(Vector2(80, 0), ["milk"])
	cannon.cooldown_left = 0.0
	cannon._physics_process(0.01)
	need(not flights().is_empty(), "second target projectile launched")
	invalid.shopping.clear()
	finish_flights()
	var dropped := false
	for child in host._world.get_children():
		if str(child.get("kind")) == "drop" and child.get("sku") == "milk":
			dropped = true
	need(dropped, "invalid target leaves cargo on floor")
	# End/refresh timing and closed-day cleanup.
	cannon.remaining = 0.1
	cannon._physics_process(0.2)
	need(cannon.dismissed, "30s effect expiration dismisses turret")
	host._elite_guest_cannon_reservations.clear()
	if errors.is_empty():
		print("OK elite guest cannon")
	else:
		for error in errors:
			push_error(error)
	quit(0 if errors.is_empty() else 1)
