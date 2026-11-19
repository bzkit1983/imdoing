extends Node

const Specialist = preload("res://scripts/elite_guest_specialist.gd")
const Skills = preload("res://scripts/skills.gd")
const Tuning = preload("res://scripts/tuning.gd")
const StateScript = preload("res://scripts/game_state.gd")

class LiveHost extends "res://scripts/demo.gd":
	var delivered: Array = []
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func note_deliver(seat: int, mode: String, n: int = 1, perfect: bool = false) -> void:
		delivered.append([seat, mode, n, perfect])

class TestPlayer extends CharacterBody2D:
	var seat_id: int = 0
	var interactables: Array = []
	var facing := Vector2.RIGHT
	func clone_snapshot() -> Dictionary:
		return {"skin_id": "player", "str": 10, "agi": 10, "int": 10}

class Guest extends Node2D:
	var is_elite: bool = true
	var is_thief: bool = false
	var temp_clerk: bool = false
	var state: int = 1
	var shopping: Array[String] = []
	var cart: Array[String] = []
	var dissatisfaction: float = 30.0
	func can_receive_delivery() -> bool:
		return is_elite and not is_thief and not temp_clerk and not shopping.is_empty() and state not in [5, 6, 7, 8, 9]
	func accept_toss_box(sku: String, n: int) -> int:
		if not can_receive_delivery() or not shopping.has(sku):
			return 0
		var take := mini(n, shopping.count(sku))
		for _i in take:
			cart.append(sku)
			shopping.erase(sku)
		dissatisfaction = maxf(0.0, dissatisfaction - 15.0 * take)
		if shopping.is_empty():
			state = 5
		return take

var errors: Array[String] = []
var host: LiveHost
var specialist


func need(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func make_guest(pos: Vector2, sku: String, elite: bool = true, temp: bool = false) -> Guest:
	var guest := Guest.new()
	guest.position = pos
	guest.is_elite = elite
	guest.temp_clerk = temp
	guest.shopping = [sku]
	host._customers.add_child(guest)
	return guest


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	SfxBus._muted = true
	host = LiveHost.new()
	add_child(host)
	host.phase = "restock"
	host._world = Node2D.new()
	host.add_child(host._world)
	host._customers = Node2D.new()
	host._world.add_child(host._customers)
	host._obstacles = []
	host.state = StateScript.new()
	host.state.stock = {"milk": 5, "snack": 2, "can": 1}
	host._net.bind(host)
	var caster := TestPlayer.new()
	host._players.append(caster)
	host._player = caster
	need(Skills.by_id("elite_guest_specialist").cost == 2, "COST 2 catalog")
	need(Skills.prep_picks_level(Skills.by_id("elite_guest_specialist")), "prep level choice")
	need(Skills.by_id("elite_guest_specialist").duration == 30.0, "30s duration")
	need(Skills.by_id("elite_guest_specialist").cd == 60.0, "60s cooldown")
	need(Tuning.cd_seconds(60.0, 10) == 60.0, "INT 10 cooldown")
	need(is_equal_approx(Tuning.cd_seconds(60.0, 50), 40.0), "INT 50 cooldown")
	need(host.deploy_elite_guest_specialist(Vector2.ZERO, 3, 0) == null, "restock cast denied")
	host.phase = "open"
	specialist = host.deploy_elite_guest_specialist(Vector2.ZERO, 1, 0)
	need(is_instance_valid(specialist), "cast succeeds with no current target")
	need(specialist.level == 1 and specialist.interval() == 3.0, "LV1 interval")
	specialist.level = 2
	need(specialist.interval() == 2.0, "LV2 interval")
	specialist.level = 3
	need(specialist.interval() == 0.5, "LV3 interval")
	need(specialist.collision_layer == 0, "specialist does not block characters")
	need(not specialist.is_shadow_clone_unit(), "specialist is immune to regular clone hit rules")
	var ring := specialist.get_node_or_null("EliteSpecialistRange") as Line2D
	need(ring != null and ring.points.size() == 64, "range ring is visible")
	if ring != null and not ring.points.is_empty():
		need(is_equal_approx(ring.points[0].length(), 3.0 * StateScript.CELL), "range is three map cells")
	var near := make_guest(Vector2(40, 0), "milk")
	var second := make_guest(Vector2(100, 0), "snack")
	var edge := make_guest(Vector2(3.0 * StateScript.CELL, 0), "can")
	var outside := make_guest(Vector2(3.0 * StateScript.CELL + 1.0, 0), "milk")
	var normal := make_guest(Vector2(20, 0), "milk", false)
	var temp := make_guest(Vector2(30, 0), "milk", true, true)
	var reserved := make_guest(Vector2(80, 0), "milk")
	need(host.reserve_elite_guest_cannon_need(reserved, "milk"), "shared cannon reservation created")
	need(specialist._nearest_serviceable_guest() == near, "nearest eligible target selected")
	need(specialist._pulse_range() == 3, "pulse serves every eligible guest in range")
	need(near.cart == ["milk"] and second.cart == ["snack"] and edge.cart == ["can"], "one needed item delivered per guest")
	need(outside.cart.is_empty() and normal.cart.is_empty() and temp.cart.is_empty() and reserved.cart.is_empty(), "range and target exclusions")
	need(near.dissatisfaction == 15.0 and host.state.stock["milk"] == 4, "normal delivery effect and stock debit")
	need(host.delivered.size() == 3 and host.delivered[0] == [0, "specialist", 1, false], "owner attribution without perfect combo")
	host.release_elite_guest_cannon_need(reserved.get_instance_id(), "milk")
	need(specialist._pulse_range() == 1 and reserved.cart == ["milk"], "reservation releases after cannon demand ends")
	if errors.is_empty():
		print("OK elite guest specialist")
	else:
		for error in errors:
			push_error(error)
	quit(0 if errors.is_empty() else 1)
