extends CanvasLayer

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const UiFont = preload("res://scripts/ui_font.gd")

var game: Node
var player: CharacterBody2D

@onready var _clock: Control = $Root/Left/Clock
@onready var _time: Label = $Root/Left/Time
@onready var _phase: Label = $Root/Left/Phase
@onready var _rev: Label = $Root/Left/Revenue
@onready var _guests: Label = $Root/Left/Guests
@onready var _store: Label = $Root/Left/Store
@onready var _role: Label = $Root/Left/Role
@onready var _skills: Label = $Root/Left/Skills
@onready var _state: Label = $Root/Right/Margin/VBox/State
@onready var _stamina: ProgressBar = $Root/Right/Margin/VBox/Stamina
@onready var _carry: Label = $Root/Right/Margin/VBox/Carry
@onready var _hud_list: ItemList = $Root/Right/Margin/VBox/HudList
@onready var _target: Label = $Root/Right/Margin/VBox/Target
@onready var _progress: ProgressBar = $Root/Right/Margin/VBox/Progress
@onready var _log: ItemList = $Root/Right/Margin/VBox/Log
@onready var _banner: Label = $Root/Banner
@onready var _cast: Label = $Root/CastName
@onready var _close: PanelContainer = $Root/Closeout
@onready var _close_text: Label = $Root/Closeout/Margin/CloseText


func setup(g: Node, p: CharacterBody2D) -> void:
	game = g
	player = p
	_hud_list.focus_mode = Control.FOCUS_NONE
	_log.focus_mode = Control.FOCUS_NONE
	_hud_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_cjk_fonts($Root)
	get_viewport().size_changed.connect(func() -> void: _apply_cjk_fonts($Root))
	player.connect("stats_changed", _refresh)
	player.connect("log_line", _on_log)
	player.connect("skill_cast", _on_skill_cast)
	_close.visible = false
	_cast.modulate.a = 0.0
	_banner.text = "店鋪經營回合  ·  Demo v0.4"
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.7)
	_refresh()


func _apply_cjk_fonts(node: Node) -> void:
	if node is Label:
		var lab := node as Label
		var size := int(lab.get_meta("cjk_design", 0))
		if size <= 0:
			size = lab.get_theme_font_size("font_size")
			if size <= 0:
				size = UiFont.BODY
			lab.set_meta("cjk_design", size)
		UiFont.apply_label(lab, size)
	if node is ItemList:
		var lst := node as ItemList
		lst.add_theme_font_override("font", UiFont.font())
		lst.add_theme_font_size_override("font_size", UiFont.px(UiFont.BODY))
	for child in node.get_children():
		_apply_cjk_fonts(child)


func show_closeout() -> void:
	_close.visible = true
	_close_text.text = "關店結算\n營業額 $%d\n成功收銀 %d 人\n生氣離開 %d 人\n（資金於結算後才入帳，v0.4 先顯示營業額）" % [
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


func _on_skill_cast(skill_name: String, is_ult: bool) -> void:
	_cast.text = skill_name
	_cast.add_theme_font_size_override("font_size", UiFont.px(44 if is_ult else 34))
	_cast.modulate = Color("c0392b" if is_ult else "f4d35e")
	_cast.modulate.a = 1.0
	_cast.scale = Vector2(0.55, 0.55)
	var tw := create_tween()
	tw.tween_property(_cast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.55 if is_ult else 0.35)
	tw.tween_property(_cast, "modulate:a", 0.0, 0.28)


func _refresh_left() -> void:
	if game == null or player == null:
		return
	_clock.game_hours = float(game.game_hours)
	_time.text = game.clock_text()
	_phase.text = game.phase_text()
	_rev.text = "營業額  $%d" % int(game.revenue)
	_guests.text = "在店客人  %d" % int(game.guest_count())
	_store.text = String(player.call("store_status_text"))
	_role.text = String(player.call("role_status_text"))
	_skills.text = _skill_cd_text()


func _skill_cd_text() -> String:
	var lines: PackedStringArray = []
	for i in Skills.EQUIPPED.size():
		var sk: Dictionary = Skills.EQUIPPED[i]
		var name := String(sk.get("name"))
		if String(sk.get("kind")) == "passive":
			lines.append("%d %s 被動" % [i + 1, name])
		else:
			var cd := float(player.call("cd_left", String(sk.get("id"))))
			lines.append("%d %s  %s" % [i + 1, name, "CD %.0f" % cd if cd > 0.05 else "就緒"])
	var ult: Dictionary = Skills.ULTIMATE
	var ucd := float(player.call("cd_left", String(ult.get("id"))))
	lines.append("奧義 %s  %s" % [String(ult.get("name")), "CD %.0f" % ucd if ucd > 0.05 else "就緒"])
	return "\n".join(lines)


func _refresh() -> void:
	if player == null:
		return
	_state.text = "狀態  %s" % player.call("move_state")
	_stamina.max_value = float(player.call("stamina_max_now"))
	_stamina.value = float(player.get("stamina"))
	var inv = player.get("inventory")
	_carry.text = "負重  %d / %d 箱" % [
		int(inv.count()) / Tuning.BOX_SIZE,
		int(player.call("carry_boxes")),
	]
	_hud_list.clear()
	if inv.is_empty():
		_hud_list.add_item("空手")
	else:
		for g in inv.grouped():
			_hud_list.add_item("%s ×%d" % [Tuning.sku_name(String(g["id"])), int(g["count"])])
	var t: Node = player.get("target")
	if t == null:
		_target.text = "目標  補貨 / 貨架 / 污物 / 收銀機後方"
	elif String(t.get("kind")) == "restock":
		_target.text = "目標  %s補貨 · 輕放執貨 · 長按選貨 [%s]" % [
			"凍櫃" if String(t.get("category")) == Tuning.CAT_FROZEN else "乾貨",
			Tuning.sku_name(String(t.call("selected_sku")))
		]
	elif String(t.get("kind")) == "cashier":
		_target.text = "目標  收銀機 · 長按行動再 WASD／搖桿"
	elif String(t.get("kind")) == "dirt":
		_target.text = "目標  %s · 空手長按行動並轉搖桿清潔" % String(t.call("type_name"))
	elif String(t.get("kind")) == "drop":
		_target.text = "目標  掉落 %s ×%d · 輕放撿起" % [Tuning.sku_name(String(t.get("sku"))), int(t.get("count"))]
	else:
		var sku := String(t.get("sku"))
		_target.text = "目標  貨架 · %s" % ("空架" if sku == "" else "%s %d/%d" % [Tuning.sku_name(sku), int(t.get("count")), Tuning.SHELF_CAP])
	_progress.value = float(player.get("hold_progress")) * 100.0
	_progress.modulate = Color("e07a5f") if bool(player.get("blocked_mismatch")) else Color("f4d35e")
