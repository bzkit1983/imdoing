extends CanvasLayer

const MoveTuning = preload("res://scripts/move_tuning.gd")

var player

@onready var _state: Label = $Panel/Margin/VBox/State
@onready var _stamina: ProgressBar = $Panel/Margin/VBox/Stamina
@onready var _speed: Label = $Panel/Margin/VBox/Speed
@onready var _carry: Label = $Panel/Margin/VBox/Carry
@onready var _slider: HSlider = $Panel/Margin/VBox/CarrySlider
@onready var _mult: Label = $Panel/Margin/VBox/Mult
@onready var _dirt: Label = $Panel/Margin/VBox/Dirt


func setup(p: CharacterBody2D) -> void:
	player = p
	_slider.min_value = 0
	_slider.max_value = MoveTuning.CARRY_CAP_ITEMS + 8
	_slider.step = 1
	_slider.value = player.carry_items
	_slider.value_changed.connect(_on_carry_changed)
	player.stats_changed.connect(_refresh)
	player.state_changed.connect(func(s: String) -> void: _state.text = "狀態  %s" % s)
	_refresh()


func _on_carry_changed(value: float) -> void:
	if player:
		player.carry_items = int(value)
		_refresh()


func _refresh() -> void:
	if player == null:
		return
	_stamina.max_value = MoveTuning.stamina_max()
	_stamina.value = player.stamina
	_speed.text = "速度  %.0f px/s" % player.current_speed()
	_carry.text = "負重  %d / %d 件（STR %d）" % [
		player.carry_items, MoveTuning.CARRY_CAP_ITEMS, MoveTuning.STR
	]
	var over := ""
	if player.carry_items > MoveTuning.CARRY_CAP_ITEMS:
		over = "  · 超出上限減速"
	elif player.carry_items >= MoveTuning.CARRY_CAP_ITEMS:
		over = "  · 達上限減速"
	_mult.text = "倍率  ×%.2f  AGI %d%s" % [player.speed_mult(), MoveTuning.AGI, over]
	_dirt.text = "污物  踩中減速中" if player.on_dirt else "污物  未接觸"
	_dirt.modulate = Color("e07a5f") if player.on_dirt else Color("c8d4c5")
