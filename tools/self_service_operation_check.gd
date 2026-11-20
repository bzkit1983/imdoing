extends Node

const Skills = preload("res://scripts/skills.gd")
const Tuning = preload("res://scripts/tuning.gd")
const GameState = preload("res://scripts/game_state.gd")
const Demo = preload("res://scripts/demo.gd")
const Shelf = preload("res://scripts/shelf.gd")
const Cashier = preload("res://scripts/cashier.gd")
const Customer = preload("res://scripts/customer.gd")

class LiveDemo extends "res://scripts/demo.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass

class ResumeHost extends Node:
	var occupied := false
	func note_customer_occupy_changed(_customer: Node, value: bool) -> void:
		occupied = value

class ReadyGuest extends Node:
	func is_at_register() -> bool:
		return true

var errors: Array[String] = []

func need(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	SfxBus._muted = true
	var skill := Skills.by_id("self_service_operation")
	need(skill.get("kind", "") == "ultimate" and skill.get("cost", -1) == 0, "ultimate slot has no active COST")
	need(skill.get("seq", []) == [2, 2, 3, 3, 0, 1, 0, 1], "eight-direction command")
	need(not Skills.prep_picks_level(skill), "one level; no level picker")
	need(is_equal_approx(Tuning.cd_seconds(60.0, 10), 60.0), "INT 10 cooldown")
	need(is_equal_approx(Tuning.cd_seconds(60.0, 50), 40.0), "INT 50 cooldown")
	var sheet := GameState.new()
	sheet.skill_sets[0]["ult_id"] = "self_service_operation"
	var reloaded := GameState.new()
	need(reloaded.from_dict(sheet.to_dict()) == "" and reloaded.ult_skill().get("id", "") == "self_service_operation", "uses existing ultimate loadout save and load")

	var game := LiveDemo.new()
	add_child(game)
	game.phase = "open"
	game._world = Node2D.new()
	game.add_child(game._world)
	game.state = GameState.new()
	game.state.stock["can"] = 4
	var shelf = Shelf.new()
	shelf.sku = "can"
	shelf.count = 8
	game.add_child(shelf)
	game._self_service_operation_left = 30.0
	need(game.take_from_shelf(shelf, "can", true), "customer purchase succeeds")
	need(shelf.count == 8 and game.state.stock["can"] == 3, "same SKU refills immediately from warehouse")
	need(game.take_from_shelf(shelf, "can", false), "non-customer shelf pickup succeeds")
	need(shelf.count == 7 and game.state.stock["can"] == 3, "player or cannon pickup does not trigger refill")
	game.state.stock["snack"] = 0
	var snack_shelf = Shelf.new()
	snack_shelf.sku = "snack"
	snack_shelf.count = 1
	game.add_child(snack_shelf)
	need(game.take_from_shelf(snack_shelf, "snack", true), "guest can buy shelf stock when warehouse is empty")
	need(snack_shelf.count == 0 and game.state.stock["snack"] == 0, "empty warehouse does not create stock")

	var reg = Cashier.new()
	game.add_child(reg)
	reg.set_physics_process(false)
	reg.label = Label.new()
	reg.add_child(reg.label)
	var reg_two := Cashier.new()
	game.add_child(reg_two)
	reg_two.set_physics_process(false)
	game.cashiers = [reg, reg_two]
	need(game.can_cast_self_service_operation(), "open store with register is valid")
	need(game.cast_self_service_operation(1), "valid cast activates mode")
	need(reg._self_left == 30.0 and reg._self_seconds == 3.0 and reg._self_seat == 1 and reg_two._self_left == 30.0, "cast activates every register for 30s at fixed 3s payment")
	var fake_guest := ReadyGuest.new()
	add_child(fake_guest)
	reg.enqueue(fake_guest)
	reg._self_customer = fake_guest
	reg._self_progress = 1.25
	need(game.cast_self_service_operation(0), "another player's cast refreshes active mode")
	need(reg._self_customer == fake_guest and is_equal_approx(reg._self_progress, 1.25) and reg._self_seat == 0, "refresh preserves progress and attributes future service to newest caster")
	game._tick_self_service_operation(30.0)
	need(not game.self_service_operation_active() and reg._self_left > 0.0, "mode expires while register may finish its active customer")
	reg._self_left = 0.0
	game.phase = "restock"
	need(not game.can_cast_self_service_operation(), "cannot cast before open")
	game.phase = "open"
	game.cashiers.clear()
	need(not game.can_cast_self_service_operation(), "cannot cast without a register")

	var resume_host := ResumeHost.new()
	add_child(resume_host)
	var guest := Customer.new()
	add_child(guest)
	guest._game = resume_host
	guest.state = Customer.State.LEAVE
	guest.shopping.assign(["can"])
	guest.cart.assign(["snack"])
	guest.dissatisfaction = Tuning.DISSAT_MAX
	need(guest.resume_unpaid_leave_for_self_service(), "unpaid leave customer is recovered")
	need(guest.state == Customer.State.SEEK and guest.shopping == ["can"] and guest.cart == ["snack"], "recovered guest continues same list and cart")
	need(guest.dissatisfaction < Tuning.DISSAT_MAX and resume_host.occupied, "recovery resets leave state and occupancy")
	var paid_leave := Customer.new()
	add_child(paid_leave)
	paid_leave.state = Customer.State.LEAVE
	need(not paid_leave.resume_unpaid_leave_for_self_service(), "paid leave customer is not recovered")

	if errors.is_empty():
		print("OK self service operation")
	else:
		for error in errors:
			push_error(error)
	get_tree().quit(0 if errors.is_empty() else 1)
