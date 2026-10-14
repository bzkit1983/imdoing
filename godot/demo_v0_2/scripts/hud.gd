extends CanvasLayer

const Tuning = preload("res://scripts/tuning.gd")

var game: Node
var player: CharacterBody2D

@onready var _clock: Control = $Root/Left/Clock
@onready var _time: Label = $Root/Left/Time
@onready var _phase: Label = $Root/Left/Phase
@onready var _rev: Label = $Root/Left/Revenue
@onready var _guests: Label = $Root/Left/Guests
@onready var _store: Label = $Root/Left/Store
@onready var _role: Label = $Root/Left/Role
@onready var _state: Label = $Root/Right/Margin/VBox/State
@onready var _stamina: ProgressBar = $Root/Right/Margin/VBox/Stamina
@onready var _carry: Label = $Root/Right/Margin/VBox/Carry
@onready var _hud_list: ItemList = $Root/Right/Margin/VBox/HudList
@onready var _target: Label = $Root/Right/Margin/VBox/Target
@onready var _progress: ProgressBar = $Root/Right/Margin/VBox/Progress
@onready var _log: ItemList = $Root/Right/Margin/VBox/Log
@onready var _banner: Label = $Root/Banner
@onready var _close: PanelContainer = $Root/Closeout
@onready var _close_text: Label = $Root/Closeout/Margin/CloseText


func setup(g: Node, p: CharacterBody2D) -> void:
	game = g
	player = p
	player.connect("stats_changed", _refresh)
	player.connect("log_line", _on_log)
	_close.visible = false
	_banner.text = "店鋪經營回合  ·  Demo v0.2"
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.7)
	_refresh()


func show_closeout() -> void:
	_close.visible = true
	_close_text.text = "關店結算\n營業額 $%d\n成功收銀 %d 人\n生氣離開 %d 人\n（資金於結算後才入帳，v0.2 先顯示營業額）" % [
		game.revenue, game.served, game.angry_left
	]


func _process(_delta: float) -> void:
	_refresh_left()


func _on_log(text: String) -> void:
	_log.add_item(text)
	while _log.item_count > 8:
		_log.remove_item(0)
	if _log.item_count:
		_log.select(_log.item_count - 1)
		_log.ensure_current_is_visible()


func _refresh_left() -> void:
	if game == null:
		return
	_clock.game_hours = float(game.game_hours)
	_time.text = game.clock_text()
	_phase.text = game.phase_text()
	_rev.text = "營業額  $%d" % int(game.revenue)
	_guests.text = "在店客人  %d" % int(game.guest_count())
	_store.text = "商店狀態  無技能效果"
	_role.text = "角色狀態  STR%d AGI%d INT%d" % [Tuning.STR, Tuning.AGI, Tuning.INT]


func _refresh() -> void:
	if player == null:
		return
	_state.text = "狀態  %s" % player.call("move_state")
	_stamina.max_value = Tuning.stamina_max()
	_stamina.value = float(player.get("stamina"))
	var inv = player.get("inventory")
	_carry.text = "負重  %d / %d" % [inv.count(), Tuning.CARRY_CAP]
	_hud_list.clear()
	if inv.is_empty():
		_hud_list.add_item("空手")
	else:
		for g in inv.grouped():
			_hud_list.add_item("%s ×%d" % [Tuning.sku_name(String(g["id"])), int(g["count"])])
	var t: Node = player.get("target")
	if t == null:
		_target.text = "目標  補貨 / 貨架 / 收銀機後方"
	elif String(t.get("kind")) == "restock":
		_target.text = "目標  %s補貨 · J 即時 [%s]" % [
			"凍櫃" if String(t.get("category")) == Tuning.CAT_FROZEN else "乾貨",
			Tuning.sku_name(String(t.call("selected_sku")))
		]
	elif String(t.get("kind")) == "cashier":
		_target.text = "目標  收銀機 · 長按 J 再 WASD 指令"
	else:
		var sku := String(t.get("sku"))
		_target.text = "目標  貨架 · %s" % ("空架" if sku == "" else "%s %d/%d" % [Tuning.sku_name(sku), int(t.get("count")), Tuning.SHELF_CAP])
	_progress.value = float(player.get("hold_progress")) * 100.0
	_progress.modulate = Color("e07a5f") if bool(player.get("blocked_mismatch")) else Color("f4d35e")
