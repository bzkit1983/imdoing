extends Node
## Headless (#149): fish tank take／pick + Fishing Taro one-catch smoke.


const TankScript = preload("res://scripts/fish_tank.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const FishingTaro = preload("res://scripts/prep/fishing_taro.gd")
const Tuning = preload("res://scripts/tuning.gd")


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

	state.add_fish("saba", 5)
	state.add_fish("tai", 2)
	_need(errors, state.fish_count("saba") == 5, "state saba stock")

	var tank: StaticBody2D = TankScript.new()
	host.add_child(tank)
	tank.label = Label.new()
	tank.add_child(tank.label)
	tank.setup_default_fish(state)
	_need(errors, tank.selected_sku() != "", "tank selects a fish")
	tank.selected_fish = "saba"
	tank.pull_stock()
	_need(errors, tank.take_pieces(2) == 2, "take two saba")
	_need(errors, state.fish_count("saba") == 3, "stock decremented")
	_need(errors, tank.take_pieces(99) == 3, "take caps at remaining")
	_need(errors, state.fish_count("saba") == 0, "saba emptied")

	tank.begin_pick(0)
	_need(errors, tank.picking, "pick UI open")
	var list: Array[String] = tank.skus()
	_need(errors, list == Tuning.FISH_IDS, "pick list is full FISH_IDS order")
	tank.cursor = list.find("tai")
	_need(errors, tank.commit_pick() == "tai", "commit selects tai")
	_need(errors, not tank.picking and tank.selected_fish == "tai", "pick closed on tai")

	## Fishing Taro: force one successful catch without input polling.
	var before := 0
	for fid in Tuning.FISH_IDS:
		before += int(state.fish_count(fid))
	var game := FishingTaro.new()
	game.setup(state)
	add_child(game)
	await get_tree().process_frame
	game._begin_play()
	_need(errors, game.phase == FishingTaro.Phase.IDLE, "taro enters IDLE")
	game._succeed()
	_need(errors, game.phase == FishingTaro.Phase.SHOW, "taro SHOW after catch")
	_need(errors, game._caught_total == 1 and game._last_catch != "", "one catch recorded")
	var after := 0
	for fid in Tuning.FISH_IDS:
		after += int(state.fish_count(fid))
	_need(errors, after == before + 1, "catch deposited into fish_stock")
	game.queue_free()
	await get_tree().process_frame

	if errors.is_empty():
		print("OK ops fishing")
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


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
