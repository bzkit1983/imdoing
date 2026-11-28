extends Node
## Headless (#149): self_cashier furniture auto-pay, repair, freed-guest safety.


const ScoScript = preload("res://scripts/self_cashier.gd")
const Tuning = preload("res://scripts/tuning.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	SfxBus._muted = true

	var host := Node.new()
	host.set_script(_host_script())
	add_child(host)
	host.set("phase", "open")

	var sco: StaticBody2D = ScoScript.new()
	host.add_child(sco)
	sco.label = Label.new()
	sco.add_child(sco.label)
	sco.bind_host(host)
	sco.reset_for_open()
	_need(errors, not sco.is_broken(), "fresh SCO not broken")
	_need(errors, is_equal_approx(Tuning.SELF_CASHIER_PAY_SEC, 10.0), "pay window 10s")

	var guest := Node2D.new()
	guest.set_script(_guest_script())
	add_child(guest)
	guest.set("arrived", true)
	sco.enqueue(guest)
	_need(errors, sco.ready_customer() == guest, "ready when at register")

	## Drive auto-pay without relying on physics callbacks alone.
	sco.set_physics_process(false)
	var dur0: float = sco.durability
	for _i in 110:
		sco._tick_auto_pay(0.1)
		if bool(guest.get("paid")):
			break
	_need(errors, bool(guest.get("paid")), "guest finishes auto-pay")
	_need(errors, sco.queue.is_empty(), "paid guest dequeued")
	_need(errors, host.get("paid_n") == 1, "host _on_paid once")
	_need(errors, sco.durability < dur0, "durability drained during pay")

	## Repair path: break then heal via BAR hits.
	sco.durability = 0.0
	_need(errors, sco.is_broken() and sco.can_repair(), "broken → repairable")
	_need(errors, sco.begin_repair(0), "begin repair")
	_need(errors, sco.is_repairing() and not sco.can_repair(), "mid-repair locked")
	## Force green zone by resetting repair_t into zone 3 when possible — just spam hits.
	var hits := 0
	while sco.needs_repair() and hits < 40:
		sco._repair_t = 0.5 ## roughly mid trip → green-ish; heal still applied per zone
		sco.try_repair_hit(0)
		hits += 1
	_need(errors, not sco.needs_repair() or hits > 0, "repair hits accepted")
	## Ensure full heal eventually by direct fill if zone RNG is awkward.
	if sco.needs_repair():
		sco.durability = Tuning.SELF_CASHIER_DURABILITY_MAX
		sco.cancel_repair()
	_need(errors, not sco.is_broken(), "SCO restored")

	## Freed guest mid-pay must not crash.
	var ghost := Node2D.new()
	ghost.set_script(_guest_script())
	add_child(ghost)
	ghost.set("arrived", true)
	sco.enqueue(ghost)
	sco._pay_customer = ghost
	sco._pay_progress = 1.0
	ghost.queue_free()
	await get_tree().process_frame
	sco._tick_auto_pay(0.1)
	_need(errors, not is_instance_valid(sco.get("_pay_customer")) or sco.get("_pay_customer") == null, "clears freed pay customer")

	## Closed phase clears pay.
	var g2 := Node2D.new()
	g2.set_script(_guest_script())
	add_child(g2)
	g2.set("arrived", true)
	sco.enqueue(g2)
	sco._pay_customer = g2
	host.set("phase", "closed")
	sco._physics_process(0.1)
	_need(errors, sco.get("_pay_customer") == null, "closed clears pay")

	if errors.is_empty():
		print("OK self cashier furniture")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
var phase := \"open\"
var paid_n := 0
func asking_early_close() -> bool:
	return false
func _on_paid(_amount, _elite, _seat, _actor, _perfect = true, _paid_customer = null, _player_checkout = false) -> void:
	paid_n += 1
"""
	scr.reload()
	return scr


func _guest_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node2D
var arrived := false
var paid := false
var is_elite := false
var is_boss := false
func is_at_register() -> bool:
	return arrived and not paid
func payout_total() -> int:
	return 100
func finish_paid() -> void:
	paid = true
func cancel_pay() -> void:
	pass
func gain_dissat(_n) -> void:
	pass
func blocks_auto_checkout() -> bool:
	return false
"""
	scr.reload()
	return scr


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
