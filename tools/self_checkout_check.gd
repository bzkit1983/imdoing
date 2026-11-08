extends Node

const Cashier = preload("res://scripts/cashier.gd")
const Skills = preload("res://scripts/skills.gd")
const Tuning = preload("res://scripts/tuning.gd")
const Player = preload("res://scripts/player.gd")
const Customer = preload("res://scripts/customer.gd")

class Host extends Node:
	var phase := "open"
	var cashiers: Array = []
	var payments: Array = []
	var locked := false
	func seat_locks_register(_reg) -> bool:
		return locked
	func _on_paid(amount, elite, seat, actor) -> void:
		payments.append([amount, elite, seat, actor])

class Guest extends Node:
	var arrived := true
	var paid := false
	var is_elite := false
	func is_at_register() -> bool:
		return arrived and not paid
	func payout_total() -> int:
		return 120 if is_elite else 100
	func finish_paid() -> void:
		paid = true

var errors: Array[String] = []
func need(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)

func guest(reg):
	var c := Guest.new()
	add_child(c)
	reg.enqueue(c)
	return c

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	SfxBus._muted = true
	var host := Host.new()
	add_child(host)
	var reg = Cashier.new()
	host.add_child(reg)
	reg.set_physics_process(false)
	reg.label = Label.new()
	reg.add_child(reg.label)
	host.cashiers = [reg]
	need(Skills.by_id("self_checkout").cost == 2, "COST 2")
	need(Skills.prep_picks_level(Skills.by_id("self_checkout")), "level selection")
	need(is_equal_approx(Tuning.cd_seconds(30.0, 50), 20.0), "INT cooldown")
	for lv in [1, 2, 3]:
		var c = guest(reg)
		reg.activate_self_checkout(host, lv, 1)
		reg._tick_self_checkout(float(6-lv)-0.1)
		need(not c.paid, "not early LV%d" % lv)
		reg._tick_self_checkout(0.1)
		need(c.paid, "correct duration LV%d" % lv)
		need(host.payments.back()[2] == 1 and host.payments.back()[3] == reg, "seat and popup actor")
	var a = guest(reg)
	var b = guest(reg)
	reg.activate_self_checkout(host, 3, 0)
	reg._tick_self_checkout(2.0)
	reg.dequeue(a)
	reg._tick_self_checkout(1.0)
	need(not b.paid and is_equal_approx(reg._self_progress, 1.0), "removed guest cannot transfer progress")
	reg.operator_checkout()
	reg._tick_self_checkout(1.0)
	need(reg._self_progress == 0.0, "same frame operator wins")
	reg._operator_frame = -1
	host.locked = true
	reg._tick_self_checkout(1.0)
	need(reg._self_progress == 0.0, "player lock wins")
	host.locked = false
	reg.activate_self_checkout(host, 3, 0)
	reg._self_left = 1.0
	reg._tick_self_checkout(0.5)
	reg._tick_self_checkout(0.5)
	need(not b.paid and reg.label.text.contains(Loc.t("self_checkout.tail")), "tail survives expiry")
	reg._tick_self_checkout(2.0)
	need(b.paid, "tail completes")
	var c = guest(reg)
	reg._tick_self_checkout(5.0)
	need(not c.paid, "no new guest after expiry")
	reg.activate_self_checkout(host, 1, 0)
	reg._tick_self_checkout(2.0)
	reg.activate_self_checkout(host, 3, 1)
	need(reg._self_progress == 0.0 and reg._self_left == 15.0 and reg._self_seconds == 3.0 and reg._self_seat == 1, "recast replaces all state")
	c.arrived = false
	reg._tick_self_checkout(1.0)
	need(reg._self_customer == null, "must reach register")
	c.arrived = true
	reg._self_left = 0.1
	reg._tick_self_checkout(0.1)
	need(reg._self_customer == null, "no new tail at exact expiry")
	reg.activate_self_checkout(host, 3, 0)
	reg._tick_self_checkout(1.0)
	reg._self_left = 0.0
	reg.operator_checkout()
	reg._tick_self_checkout(1.0)
	reg._operator_frame = -1
	reg._tick_self_checkout(5.0)
	need(not c.paid, "interrupted tail cannot resume")
	host.phase = "closed"
	reg._physics_process(0.1)
	need(reg._self_left == 0.0 and reg._self_customer == null, "close clears")
	var player = Player.new()
	player.game = host
	player.seat_id = 1
	var far_reg = Cashier.new()
	host.add_child(far_reg)
	far_reg.set_physics_process(false)
	host.phase = "open"
	host.cashiers = [reg, far_reg]
	reg.position = Vector2(130, 0)
	far_reg.position = Vector2(130.1, 0)
	need(player._cast_self_checkout(2), "boundary cast succeeds")
	var rings: Array = []
	for child in host.get_children():
		if child is Line2D:
			rings.append(child)
	need(rings.size() == 1, "successful cast creates one ring")
	var ring: Line2D = rings[0]
	ring.set_physics_process(false)
	var origin := ring.global_position
	need(ring.get_point_count() == 64 and ring.closed, "complete outline")
	need(is_equal_approx(ring.get_point_position(0).length(), 130.0), "ring matches effect radius")
	need(ring.z_index == -7, "ring above floor below actors")
	need(reg._self_left == 15.0 and far_reg._self_left == 0.0, "130px boundary inclusive")
	player.position = Vector2(1000, 1000)
	need(not player._cast_self_checkout(2), "no nearby register fails")
	need(ring.global_position == origin, "ring remains at cast position after movement")
	var ring_count := 0
	for child in host.get_children():
		if child is Line2D:
			ring_count += 1
	need(ring_count == 1, "failed cast creates no ring")
	player.position = Vector2.ZERO
	need(player._cast_self_checkout(3), "second caster window succeeds")
	var second_ring: Line2D
	for child in host.get_children():
		if child is Line2D and child != ring:
			second_ring = child
	need(second_ring != null, "each successful cast has independent ring")
	second_ring.set_physics_process(false)
	second_ring._physics_process(14.9)
	need(not second_ring.is_queued_for_deletion(), "ring lasts until 15 seconds")
	second_ring._physics_process(0.1)
	need(second_ring.is_queued_for_deletion() and not second_ring.visible, "expiry removes ring")
	need(not ring.is_queued_for_deletion(), "other ring is independent")
	reg._tick_self_checkout(1.0)
	need(reg._self_left == 14.0 and far_reg._self_left == 0.0, "leaving does not change targets")
	far_reg.activate_self_checkout(host, 3, 0)
	var far_guest = guest(far_reg)
	reg.activate_self_checkout(host, 3, 1)
	reg._tick_self_checkout(3.0)
	far_reg._tick_self_checkout(3.0)
	need(c.paid and far_guest.paid, "multiple registers independently complete")
	need(host.payments[-1][2] == 0 and host.payments[-2][2] == 1, "independent caster attribution")
	player.free()
	# Actual guest payout includes both elite and delivery bonus.
	var real = Customer.new()
	real.cart.assign(["can"])
	real.is_elite = true
	real._combo_pay_bonus = true
	var expected := int(ceil(float(Tuning.sku_price("can") * 2) * 1.2))
	need(real.payout_total() == expected, "normal payout preserves elite and delivery bonus")
	real.free()
	# A physics-disabled register stays unchanged while the scene tree is paused.
	var before: float = reg._self_left
	reg.set_physics_process(true)
	ring.set_physics_process(true)
	var ring_elapsed: float = ring.elapsed
	var ring_alpha: float = ring.default_color.a
	get_tree().paused = true
	await get_tree().process_frame
	need(reg._self_left == before, "pause freezes timer")
	need(ring.elapsed == ring_elapsed and ring.default_color.a == ring_alpha, "pause freezes ring and breathing")
	get_tree().paused = false
	ring.set_physics_process(false)
	host.phase = "closed"
	ring._physics_process(0.1)
	need(ring.is_queued_for_deletion() and not ring.visible, "closing removes ring immediately")
	reg.set_physics_process(false)

	if errors.is_empty():
		print("OK self checkout")
	else:
		for error in errors:
			push_error(error)
	host.free()
	get_tree().quit(0 if errors.is_empty() else 1)
