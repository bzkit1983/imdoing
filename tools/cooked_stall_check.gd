extends Node
## Headless (#149): cooked stall pantry → craft → face／guest fulfill + cancel refund.


const StallScript = preload("res://scripts/cooked_stall.gd")
const Tuning = preload("res://scripts/tuning.gd")
const GameStateScript = preload("res://scripts/game_state.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	SfxBus._muted = true

	var host := Node.new()
	host.name = "Game"
	host.set_script(_host_script())
	host.add_to_group("game")
	var state: RefCounted = GameStateScript.new()
	host.set("state", state)
	add_child(host)

	var stall: StaticBody2D = StallScript.new()
	host.add_child(stall)
	stall.label = Label.new()
	stall.add_child(stall.label)

	_need(errors, stall.add_ingredient("grain", 2) == 2, "pantry accepts grain")
	_need(errors, stall.ingredient_count("grain") == 2, "grain stocked")
	_need(errors, stall.can_afford_from_pantry("onigiri"), "onigiri affordable")
	_need(errors, stall.try_begin_craft("onigiri") == "", "craft begins")
	_need(errors, stall.crafting and stall.craft_sku == "onigiri", "crafting onigiri")
	_need(errors, stall.ingredient_count("grain") == 0, "recipe consumed from pantry")

	## Cancel refunds ingredients.
	stall.cancel_craft()
	_need(errors, not stall.crafting, "cancel clears crafting")
	_need(errors, stall.ingredient_count("grain") == 2, "cancel refunds grain")

	_need(errors, stall.try_begin_craft("onigiri") == "", "craft again")
	var done := false
	for _i in 40:
		if stall.tick_craft(0.1):
			done = true
			break
	_need(errors, done, "craft finishes within budget")
	_need(errors, stall.face_count_of("onigiri") == 1, "no guest → face stocked")

	## Guest fulfill path + freed guest safety.
	stall.add_ingredient("grain", 2)
	var guest := Node2D.new()
	guest.set_script(_guest_script())
	add_child(guest)
	stall.enqueue(guest)
	_need(errors, stall.try_begin_craft("onigiri") == "", "craft for guest")
	done = false
	for _i in 40:
		if stall.tick_craft(0.1):
			done = true
			break
	_need(errors, done and bool(guest.get("got")), "front guest receives craft")
	_need(errors, stall.face_count_of("onigiri") == 1, "fulfilled guest does not double face")
	stall.dequeue(guest)
	guest.queue_free()
	await get_tree().process_frame

	stall.add_ingredient("grain", 2)
	var ghost := Node2D.new()
	ghost.set_script(_guest_script())
	add_child(ghost)
	stall.enqueue(ghost)
	_need(errors, stall.try_begin_craft("onigiri") == "", "craft with doomed guest")
	ghost.queue_free()
	await get_tree().process_frame
	done = false
	for _i in 40:
		if stall.tick_craft(0.1):
			done = true
			break
	_need(errors, done, "craft finishes after guest freed")
	_need(errors, stall.face_count_of("onigiri") == 2, "freed guest → face deposit")

	_need(errors, is_equal_approx(Tuning.COOKED_CRAFT_SEC, 2.0), "craft sec unchanged")

	if errors.is_empty():
		print("OK cooked stall")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
var state
"""
	scr.reload()
	return scr


func _guest_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node2D
var got := false
func receive_stall_craft(_sku: String) -> bool:
	got = true
	return true
"""
	scr.reload()
	return scr


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
