extends Node

const Player = preload("res://scripts/player.gd")
const Shelf = preload("res://scripts/shelf.gd")
const Skills = preload("res://scripts/skills.gd")
const Sheet = preload("res://scripts/session/character_sheet.gd")
const RestockPoint = preload("res://scripts/restock_point.gd")
const Tuning = preload("res://scripts/tuning.gd")
const GameState = preload("res://scripts/game_state.gd")


class StockState extends RefCounted:
	signal warehouse_changed
	var stock := {"can": 7, "snack": 3}

	func developed_of(_category: String) -> Array[String]:
		return ["can", "snack"]

	func consume_stock(sku: String, requested: int) -> bool:
		if int(stock.get(sku, 0)) < requested:
			return false
		stock[sku] = int(stock.get(sku, 0)) - requested
		warehouse_changed.emit()
		return true


class GameNode extends Node:
	var state = StockState.new()


class RestockSource extends Node2D:
	var pieces := 8
	var sku := "can"

	func selected_sku() -> String:
		return sku

	func take_pieces(requested: int) -> int:
		var taken := mini(requested, pieces)
		pieces -= taken
		return taken


var errors: Array[String] = []


func need(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func make_player(lv: int):
	var player = Player.new()
	var sheet = Sheet.blank()
	sheet.slots = ["quick_swallow", "", "", "", ""]
	sheet.skill_sets = [{
		"name": "test",
		"slots": sheet.slots.duplicate(),
		"ult_id": "the_world",
		"levels": {"quick_swallow": lv},
	}]
	sheet.skill_set_index = 0
	player.stats = sheet
	player.set_physics_process(false)
	add_child(player)
	return player


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	SfxBus._muted = true
	var skill := Skills.by_id("quick_swallow")
	need(skill.get("cost", 0) == 2 and skill.get("kind", "") == "passive", "COST 2 passive catalog entry")
	need(not Skills.prep_picks_level(skill), "level selection remains outside this update")
	var cost_state = GameState.new()
	var cost_sets: Array[Dictionary] = [{"slots": ["quick_swallow", "self_checkout", "instant_restock", "", ""]}]
	cost_state.skill_sets = cost_sets
	need(cost_state.cost_sum_of(0) == 5, "quick swallow fits the existing COST 5 budget")
	cost_state.skill_sets[0]["slots"] = ["quick_swallow", "self_checkout", "universal_cannon", "", ""]
	need(cost_state.cost_sum_of(0) == 6, "COST 2 skill combinations still obey the existing budget check")
	for lv in [1, 2, 3]:
		need(Skills.quick_swallow_pieces(lv) == [2, 3, 5][lv - 1], "LV%d pickup amount" % lv)
		var player = make_player(lv)
		var source := RestockSource.new()
		add_child(source)
		player.target = source
		player._try_pickup()
		var expected: int = [2, 3, 5][lv - 1]
		need(player.inventory.count() == expected, "restock takes LV%d amount" % lv)
		need(source.pieces == 8 - expected, "restock decrements LV%d amount" % lv)
		player.queue_free()
		source.queue_free()
	await get_tree().process_frame

	var partial = make_player(3)
	var scarce := RestockSource.new()
	scarce.pieces = 2
	add_child(scarce)
	partial.target = scarce
	partial._try_pickup()
	need(partial.inventory.count() == 2 and scarce.pieces == 0, "partial restock when source is short")
	partial.queue_free()
	scarce.queue_free()
	await get_tree().process_frame

	var host := GameNode.new()
	host.add_to_group("game")
	add_child(host)
	var real_point := RestockPoint.new()
	add_child(real_point)
	real_point.setup(Tuning.CAT_DRY)
	var restock_player = make_player(2)
	restock_player.target = real_point
	restock_player._try_pickup()
	need(restock_player.inventory.count() == 3, "actual restock point takes LV2 amount")
	need(int(host.state.stock["can"]) == 4, "actual warehouse stock decrements by LV2 amount")
	need(real_point.take_box(), "legacy one-piece restock API remains compatible")
	need(int(host.state.stock["can"]) == 3, "legacy restock API consumes one piece")
	restock_player.queue_free()
	real_point.queue_free()
	host.queue_free()
	await get_tree().process_frame

	var shelf_player = make_player(3)
	var shelf := Shelf.new()
	shelf.sku = "snack"
	shelf.count = 4
	add_child(shelf)
	shelf_player._take_shelf_piece(shelf)
	need(shelf_player.inventory.count() == 4 and shelf.count == 0, "shelf pickup is limited by shelf stock")
	shelf_player.queue_free()
	shelf.queue_free()
	await get_tree().process_frame
	need(Skills.quick_swallow_pieces(0) == 5, "missing level safely defaults to LV3 amount")
	var no_skill = Player.new()
	add_child(no_skill)
	need(no_skill._manual_pickup_limit() == 1, "players without the passive keep one-piece pickup")
	no_skill.queue_free()
	await get_tree().process_frame

	var capped = make_player(3)
	capped.inventory.take_pieces("milk", capped.carry_cap() - 2)
	var cap_source := RestockSource.new()
	add_child(cap_source)
	capped.target = cap_source
	capped._try_pickup()
	need(capped.inventory.count() == capped.carry_cap(), "pickup is limited by remaining carry capacity")
	need(cap_source.pieces == 6, "only carried pieces are removed from stock")
	capped.queue_free()
	cap_source.queue_free()
	await get_tree().process_frame

	if errors.is_empty():
		print("OK quick swallow")
	else:
		for error in errors:
			push_error(error)
		get_tree().quit(1)
		return
	get_tree().quit(0)
