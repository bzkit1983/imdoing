extends Node
## Headless: test-build easy difficulty scales lists, dirt, thieves, and dissatisfaction.


const Tuning = preload("res://scripts/tuning.gd")
const StateScript = preload("res://scripts/game_state.gd")
const CustomerScript = preload("res://scripts/customer.gd")


class EasyHost extends Node:
	func play_is_easy() -> bool:
		return true


class NormalHost extends Node:
	func play_is_easy() -> bool:
		return false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	var state := StateScript.new()
	state.apply_scenario(1)
	_need(errors, Tuning.list_hi(state.customer_list_max(), true) == 3, "scenario 1 easy list stays at 3")
	state.apply_scenario(2)
	_need(errors, state.customer_list_max() == Tuning.LIST_MAX, "normal scenario list max")
	_need(errors, Tuning.list_hi(state.customer_list_max(), false) == Tuning.LIST_MAX, "normal does not cap")
	_need(errors, Tuning.list_hi(state.customer_list_max(), true) == Tuning.EASY_LIST_CAP, "easy caps guest lists at 5")
	_need(errors, Tuning.list_lo(2, 5) == 2, "list floor stays")
	_need(errors, is_equal_approx(Tuning.dirt_interval(Tuning.DIRT_SPAWN_SEC, false), Tuning.DIRT_SPAWN_SEC), "normal dirt interval")
	_need(errors, is_equal_approx(Tuning.dirt_interval(Tuning.DIRT_SPAWN_SEC, true), Tuning.DIRT_SPAWN_SEC * 2.0), "easy dirt interval doubles")
	_need(errors, is_equal_approx(Tuning.dirt_interval(Tuning.DIRT_SPAWN_SEC * 2.0, true), Tuning.DIRT_SPAWN_SEC * 4.0), "easy stacks on scenario 1")
	_need(errors, Tuning.dirt_start(false) == Tuning.DIRT_START_COUNT and Tuning.dirt_start(true) == 1, "easy starts with one dirt")
	_need(errors, is_equal_approx(Tuning.thief_rate(1.0, false), 1.0), "normal thief rate")
	_need(errors, is_equal_approx(Tuning.thief_rate(1.0, true), 0.5), "easy thief rate halves")
	_need(errors, is_equal_approx(Tuning.thief_rate(0.5, true), 0.25), "easy stacks with haki")
	_need(errors, is_equal_approx(Tuning.dissat_gain(18.0, false), 18.0), "normal dissatisfaction")
	_need(errors, is_equal_approx(Tuning.dissat_gain(18.0, true), 9.0), "easy dissatisfaction halves")
	_need(errors, Tuning.dissat_gain(0.0, true) == 0.0, "zero gain stays zero")
	var guest: CharacterBody2D = CustomerScript.new()
	guest._game = EasyHost.new()
	guest.gain_dissat(Tuning.DISSAT_MISS)
	_need(errors, is_equal_approx(guest.dissatisfaction, Tuning.DISSAT_MISS * 0.5), "guest applies easy gain")
	guest.temp_clerk = true
	guest.gain_dissat(Tuning.DISSAT_MISS)
	_need(errors, is_equal_approx(guest.dissatisfaction, Tuning.DISSAT_MISS * 0.5), "temp clerk dissatisfaction stays locked")
	guest._game = NormalHost.new()
	guest.temp_clerk = false
	guest.dissatisfaction = 0.0
	guest.gain_dissat(Tuning.DISSAT_MISS)
	_need(errors, is_equal_approx(guest.dissatisfaction, Tuning.DISSAT_MISS), "normal guest gain is full")
	if errors.is_empty():
		print("OK difficulty")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _need(errors: PackedStringArray, ok: bool, msg: String) -> void:
	if not ok:
		errors.append(msg)
