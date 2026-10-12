extends CanvasLayer

const Tuning = preload("res://scripts/tuning.gd")

var player: CharacterBody2D

@onready var _state: Label = $Root/Right/Margin/VBox/State
@onready var _stamina: ProgressBar = $Root/Right/Margin/VBox/Stamina
@onready var _speed: Label = $Root/Right/Margin/VBox/Speed
@onready var _carry: Label = $Root/Right/Margin/VBox/Carry
@onready var _hud_list: ItemList = $Root/Right/Margin/VBox/HudList
@onready var _target: Label = $Root/Right/Margin/VBox/Target
@onready var _progress: ProgressBar = $Root/Right/Margin/VBox/Progress
@onready var _stock: Label = $Root/Right/Margin/VBox/Stock
@onready var _log: ItemList = $Root/Right/Margin/VBox/Log
@onready var _banner: Label = $Root/Banner


func setup(p: CharacterBody2D) -> void:
	player = p
	player.connect("stats_changed", _refresh)
	player.connect("log_line", _on_log)
	var tw := create_tween()
	_banner.modulate.a = 1.0
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)
	_refresh()


func _on_log(text: String) -> void:
	_log.add_item(text)
	while _log.item_count > 10:
		_log.remove_item(0)
	if _log.item_count:
		_log.select(_log.item_count - 1)
		_log.ensure_current_is_visible()


func _refresh() -> void:
	if player == null:
		return
	_state.text = "狀態  %s" % player.call("move_state")
	_stamina.max_value = Tuning.stamina_max()
	_stamina.value = float(player.get("stamina"))
	_speed.text = "速度  %.0f px/s   倍率 ×%.2f" % [player.velocity.length(), float(player.call("speed_mult"))]
	var inv = player.get("inventory")
	_carry.text = "負重  %d / %d 件  STR %d" % [inv.count(), Tuning.CARRY_CAP, Tuning.STR]
	_hud_list.clear()
	if inv.is_empty():
		_hud_list.add_item("空手")
	else:
		for g in inv.grouped():
			_hud_list.add_item("%s  ×%d" % [Tuning.sku_name(String(g["id"])), int(g["count"])])
	var t: Node = player.get("target")
	if t == null:
		_target.text = "目標  走近並面向補貨點或貨架"
		_stock.text = "補貨點  —"
	elif String(t.get("kind")) == "restock":
		_target.text = "目標  補貨點 · J 即時提取 [%s]" % Tuning.sku_name(String(t.call("selected_sku")))
		_stock.text = "庫存  罐頭 %d箱  零食 %d箱  杯麵 %d箱" % [
			t.call("remaining", "can"), t.call("remaining", "snack"), t.call("remaining", "cup")
		]
	else:
		var sku := String(t.get("sku"))
		_target.text = "目標  貨架 %s · %s" % [
			str(t.get("shelf_index")),
			"空架，長按 J 上架清單最後貨" if sku == "" else "%s %d/%d" % [Tuning.sku_name(sku), int(t.get("count")), Tuning.SHELF_CAP]
		]
		_stock.text = "貨架品質容量  %d 件" % Tuning.SHELF_CAP
	_progress.value = float(player.get("hold_progress")) * 100.0
	_progress.modulate = Color("e07a5f") if bool(player.get("blocked_mismatch")) else Color("f4d35e")
