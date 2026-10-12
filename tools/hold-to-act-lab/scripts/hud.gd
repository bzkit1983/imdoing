extends CanvasLayer

const Tuning = preload("res://scripts/act_tuning.gd")

var player: CharacterBody2D

@onready var _target: Label = $Panel/Margin/VBox/Target
@onready var _carry: Label = $Panel/Margin/VBox/Carry
@onready var _progress: ProgressBar = $Panel/Margin/VBox/Progress
@onready var _agi: Label = $Panel/Margin/VBox/Agi
@onready var _slider: HSlider = $Panel/Margin/VBox/AgiSlider
@onready var _time: Label = $Panel/Margin/VBox/Time
@onready var _log: ItemList = $Panel/Margin/VBox/Log


func setup(p: CharacterBody2D) -> void:
	player = p
	_slider.min_value = 1
	_slider.max_value = 20
	_slider.step = 1
	_slider.value = int(player.get("agi"))
	_slider.value_changed.connect(_on_agi)
	player.connect("stats_changed", _refresh)
	player.connect("log_line", _on_log)
	_refresh()


func _on_agi(value: float) -> void:
	player.set("agi", int(value))
	_refresh()


func _on_log(text: String) -> void:
	_log.add_item(text)
	while _log.item_count > 12:
		_log.remove_item(0)
	_log.select(_log.item_count - 1)
	_log.ensure_current_is_visible()


func _refresh() -> void:
	if player == null:
		return
	var t: Node = player.get("target")
	if t == null:
		_target.text = "目標  （走近並面向物件）"
	elif String(t.get("kind")) == "restock":
		_target.text = "目標  補貨點 · 選 %s · J 即時執貨" % String(t.get("selected_sku"))
	else:
		var sku := String(t.get("sku"))
		_target.text = "目標  貨架 %s · %s" % [
			str(t.get("shelf_index")),
			"空架" if sku == "" else "%s %d/%d" % [sku, int(t.get("count")), Tuning.SHELF_CAP]
		]
	var csku := String(player.get("carry_sku"))
	var cc := int(player.get("carry_count"))
	_carry.text = "攜帶  空手" if cc <= 0 else "攜帶  %s ×%d / %d" % [csku, cc, Tuning.CARRY_CAP]
	_progress.value = float(player.get("hold_progress")) * 100.0
	if bool(player.get("blocked_mismatch")):
		_progress.modulate = Color("e07a5f")
	else:
		_progress.modulate = Color("f4d35e")
	var agi := int(player.get("agi"))
	_agi.text = "AGI  %d（預設 10）" % agi
	_time.text = "上架圈  %.2fs  放手即重置" % Tuning.restock_seconds(agi)
