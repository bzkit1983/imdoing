extends CanvasLayer

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")

var game: Node
var player: CharacterBody2D
var _skip: Button
var _pause_btn: Button
var _left_fp: String = ""
var _right_dirty: bool = true
var _skip_running: bool = false
var _font_debounce: float = 0.0
var _font_pending: bool = false
var _skills_cd_fp: String = ""
var _skills_cd_txt: String = ""
## Skip rebuilding store/role when game hud_rev + clock bucket + skill fp unchanged.
var _left_hud_rev: int = -1
var _left_hour_bucket: int = -1
## Per-seat right panes: {player, title, state, stamina, carry, icons, target, progress, icons_fp}.
var _panes: Array = []

@onready var _clock: Control = $Root/Left/Clock
@onready var _time: Label = $Root/Left/Time
@onready var _phase: Label = $Root/Left/Phase
@onready var _rev: Label = $Root/Left/Revenue
@onready var _guests: Label = $Root/Left/Guests
@onready var _store: Label = $Root/Left/Store
@onready var _role: Label = $Root/Left/Role
@onready var _skills: Label = $Root/Left/Skills
var _combo: Label
var _ops_rating: Label
var _stamina_std: ProgressBar
var _carry_std: Label
var _carry_icons_std: HBoxContainer
var _carry_std_fp: String = ""
var _tr_panel: PanelContainer
var _skills_std: Label
var _skills_panel: PanelContainer
var _tasks: Label
var _tasks_panel: PanelContainer
var _left_panel: PanelContainer
@onready var _right: PanelContainer = $Root/Right
@onready var _right_vbox: VBoxContainer = $Root/Right/Margin/VBox
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
	## Icon strip replaces text HudList (P0 ops SKU UI).
	_hud_list.visible = false
	_build_combo_label()
	_build_ops_rating_label()
	_wrap_left_status_panel()
	_build_tr_std()
	_build_bottom_left_panel()
	## Scene Skills row stays as legacy; standard skills live bottom-right.
	if _skills:
		_skills.visible = false
	if not PlatformServices.show_dev_hud_changed.is_connected(_on_show_dev_hud_changed):
		PlatformServices.show_dev_hud_changed.connect(_on_show_dev_hud_changed)
	_apply_dev_hud_visibility()
	## No round-start demo banner; hide legacy scope copy on the right panel.
	_banner.visible = false
	var title := $Root/Right/Margin/VBox/Title
	var hint := $Root/Right/Margin/VBox/Hint
	var out := $Root/Right/Margin/VBox/Out
	if title:
		title.visible = false
	if hint:
		hint.visible = false
	if out:
		out.visible = false
	_setup_seat_panes()
	if _panes.size() >= 2:
		## Dual seat panes need room; shrink shared log min height.
		_log.custom_minimum_size = Vector2(0, 64)
	_apply_cjk_fonts($Root)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_close.visible = false
	_cast.modulate.a = 0.0
	_build_skip()
	_build_pause()
	_right_dirty = true
	_left_fp = ""
	_sync_left()
	_sync_right()


## Coop: also listen to seat1+ for cast name / log lines.
func bind_cast_events(p: CharacterBody2D) -> void:
	if p == null:
		return
	if p.has_signal("log_line") and not p.is_connected("log_line", _on_log):
		p.connect("log_line", _on_log)
	if p.has_signal("skill_cast") and not p.is_connected("skill_cast", _on_skill_cast):
		p.connect("skill_cast", _on_skill_cast)


func _setup_seat_panes() -> void:
	_panes.clear()
	var seats: Array = _collect_seat_players()
	## Seat 0 reuses scene nodes; add a title above State.
	var title0 := _make_seat_title(0 if seats.is_empty() else int(seats[0].get("seat_id")))
	_right_vbox.add_child(title0)
	_right_vbox.move_child(title0, _state.get_index())
	var icons0 := _make_carry_icons()
	_right_vbox.add_child(icons0)
	_right_vbox.move_child(icons0, _hud_list.get_index())
	var p0: CharacterBody2D = seats[0] if not seats.is_empty() else player
	_panes.append(_pane_dict(p0, title0, _state, _stamina, _carry, icons0, _target, _progress))
	_wire_seat_player(p0)
	## Extra seats: stacked panes before the shared log.
	for i in range(1, seats.size()):
		var p: CharacterBody2D = seats[i]
		var pane := _build_extra_seat_pane(p)
		_panes.append(pane)
		_wire_seat_player(p)


func _collect_seat_players() -> Array:
	var out: Array = []
	if game != null and game.get("_players") is Array:
		for p in game._players:
			if p != null and is_instance_valid(p):
				out.append(p)
	if out.is_empty() and player != null:
		out.append(player)
	return out


func _wire_seat_player(p: CharacterBody2D) -> void:
	if p == null:
		return
	if p.has_signal("stats_changed") and not p.is_connected("stats_changed", _mark_right_dirty):
		p.connect("stats_changed", _mark_right_dirty)
	bind_cast_events(p)


func _pane_dict(
	p: CharacterBody2D,
	title: Label,
	state: Label,
	stamina: ProgressBar,
	carry: Label,
	icons: HBoxContainer,
	target: Label,
	progress: ProgressBar,
) -> Dictionary:
	return {
		"player": p,
		"title": title,
		"state": state,
		"stamina": stamina,
		"carry": carry,
		"icons": icons,
		"target": target,
		"progress": progress,
		"icons_fp": "",
	}


func _make_seat_title(seat: int) -> Label:
	var lab := Label.new()
	lab.name = "SeatTitle%d" % seat
	lab.text = Loc.t("hud.seat", [seat + 1])
	UiFont.apply_label(lab, UiFont.BODY)
	lab.add_theme_color_override("font_color", Color("f4d35e"))
	return lab


func _make_carry_icons() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "CarryIcons"
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 40)
	return row


func _build_extra_seat_pane(p: CharacterBody2D) -> Dictionary:
	var seat := int(p.get("seat_id")) if p != null else _panes.size()
	var box := VBoxContainer.new()
	box.name = "SeatPane%d" % seat
	box.add_theme_constant_override("separation", 5)
	var sep := HSeparator.new()
	box.add_child(sep)
	var title := _make_seat_title(seat)
	box.add_child(title)
	var state := Label.new()
	state.text = Loc.t("hud.state", ["—"])
	box.add_child(state)
	var stamina := ProgressBar.new()
	stamina.custom_minimum_size = Vector2(0, 22)
	stamina.show_percentage = false
	box.add_child(stamina)
	var carry := Label.new()
	carry.text = Loc.t("hud.carry", [0, 0])
	box.add_child(carry)
	var icons := _make_carry_icons()
	box.add_child(icons)
	var target := Label.new()
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target.text = Loc.t("hud.target_none")
	box.add_child(target)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 20)
	progress.show_percentage = false
	box.add_child(progress)
	## Insert before shared Log so log stays at the bottom.
	_right_vbox.add_child(box)
	_right_vbox.move_child(box, _log.get_index())
	_apply_cjk_fonts(box)
	return _pane_dict(p, title, state, stamina, carry, icons, target, progress)


func _build_combo_label() -> void:
	_combo = Label.new()
	_combo.name = "Combo"
	_combo.text = Loc.t("hud.combo", [0, 0])
	var left: VBoxContainer = $Root/Left
	var skills_i := _skills.get_index()
	left.add_child(_combo)
	left.move_child(_combo, skills_i + 1)


func _build_ops_rating_label() -> void:
	_ops_rating = Label.new()
	_ops_rating.name = "OpsRating"
	_ops_rating.text = Loc.t("hud.ops_rating", [50])
	var left: VBoxContainer = $Root/Left
	var rev_i := _rev.get_index()
	left.add_child(_ops_rating)
	left.move_child(_ops_rating, rev_i + 1)
	_apply_cjk_fonts(_ops_rating)


func _wrap_left_status_panel() -> void:
	## Dark plate + outline so clock／revenue／guests stay readable over floor tiles.
	var left: VBoxContainer = $Root/Left
	var root: Control = $Root
	var idx := left.get_index()
	root.remove_child(left)
	_left_panel = _make_hud_panel()
	_left_panel.name = "LeftStatusPanel"
	_left_panel.position = Vector2(12, 8)
	left.layout_mode = 2
	left.offset_left = 0.0
	left.offset_top = 0.0
	left.offset_right = 0.0
	left.offset_bottom = 0.0
	left.custom_minimum_size = Vector2(360, 0)
	_left_panel.add_child(left)
	root.add_child(_left_panel)
	root.move_child(_left_panel, idx)
	for lab in [_time, _phase, _rev, _guests, _store, _role, _combo, _ops_rating]:
		if lab:
			_apply_readable_label(lab)


func _apply_readable_label(lab: Label) -> void:
	lab.add_theme_color_override("font_color", Color(0.98, 0.97, 0.94, 1))
	lab.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1))
	lab.add_theme_constant_override("outline_size", 6)


func _build_tr_std() -> void:
	## Standard stamina + carry — top-right (below pause button).
	_tr_panel = _make_hud_panel()
	_tr_panel.name = "TopRightStd"
	_tr_panel.anchor_left = 1.0
	_tr_panel.anchor_right = 1.0
	_tr_panel.anchor_top = 0.0
	_tr_panel.anchor_bottom = 0.0
	_tr_panel.offset_left = -248.0
	_tr_panel.offset_right = -12.0
	_tr_panel.offset_top = 88.0
	_tr_panel.offset_bottom = 200.0
	_tr_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tr_panel.grow_vertical = Control.GROW_DIRECTION_END
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	_tr_panel.add_child(vbox)
	_stamina_std = ProgressBar.new()
	_stamina_std.name = "StaminaStd"
	_stamina_std.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_std.show_percentage = false
	_stamina_std.max_value = 100.0
	_stamina_std.value = 100.0
	_stamina_std.custom_minimum_size = Vector2(200, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.78, 0.55, 0.95)
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.1, 0.1, 0.7)
	bg.set_corner_radius_all(4)
	_stamina_std.add_theme_stylebox_override("fill", fill)
	_stamina_std.add_theme_stylebox_override("background", bg)
	vbox.add_child(_stamina_std)
	_carry_std = _make_hud_label("CarryStd")
	_carry_std.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_carry_std.text = Loc.t("hud.carry", [0, 0])
	vbox.add_child(_carry_std)
	_carry_icons_std = _make_carry_icons()
	_carry_icons_std.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(_carry_icons_std)
	$Root.add_child(_tr_panel)
	$Root.move_child(_tr_panel, _banner.get_index())
	_apply_cjk_fonts(_carry_std)
	_fit_tr_panel()


func _make_hud_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.82)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _make_hud_label(name: String) -> Label:
	var lab := Label.new()
	lab.name = name
	lab.text = ""
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92, 1))
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 1))
	lab.add_theme_constant_override("outline_size", 4)
	return lab


func _build_bottom_left_panel() -> void:
	## Tasks — bottom-left. Skills／CD — bottom-right.
	_tasks_panel = _make_hud_panel()
	_tasks_panel.name = "TasksPanel"
	_tasks_panel.visible = false
	_tasks_panel.anchor_left = 0.0
	_tasks_panel.anchor_right = 0.0
	_tasks_panel.anchor_top = 1.0
	_tasks_panel.anchor_bottom = 1.0
	_tasks_panel.offset_left = 12.0
	_tasks_panel.offset_right = 360.0
	_tasks_panel.offset_top = -48.0
	_tasks_panel.offset_bottom = -12.0
	_tasks_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_tasks_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var t_margin := MarginContainer.new()
	t_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tasks_panel.add_child(t_margin)
	_tasks = _make_hud_label("Tasks")
	t_margin.add_child(_tasks)
	$Root.add_child(_tasks_panel)
	$Root.move_child(_tasks_panel, _banner.get_index())
	_apply_cjk_fonts(_tasks)

	_skills_panel = _make_hud_panel()
	_skills_panel.name = "SkillsPanel"
	_skills_panel.anchor_left = 1.0
	_skills_panel.anchor_right = 1.0
	_skills_panel.anchor_top = 1.0
	_skills_panel.anchor_bottom = 1.0
	_skills_panel.offset_left = -380.0
	_skills_panel.offset_right = -12.0
	_skills_panel.offset_top = -48.0
	_skills_panel.offset_bottom = -12.0
	_skills_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skills_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var s_margin := MarginContainer.new()
	s_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skills_panel.add_child(s_margin)
	_skills_std = _make_hud_label("SkillsStd")
	_skills_std.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s_margin.add_child(_skills_std)
	$Root.add_child(_skills_panel)
	$Root.move_child(_skills_panel, _banner.get_index())
	_apply_cjk_fonts(_skills_std)


func _mark_right_dirty() -> void:
	_right_dirty = true


func _on_viewport_resized() -> void:
	_font_pending = true
	_font_debounce = 0.2


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
	_close_text.text = Loc.t("settle.hud_legacy", [
		game.revenue, game.served, game.angry_left,
		int(game.stolen_count), int(game.stolen_value),
		int(game.thieves_caught), int(game.thieves_escaped)
	])


func _process(delta: float) -> void:
	if _font_pending:
		_font_debounce -= delta
		if _font_debounce <= 0.0:
			_font_pending = false
			_apply_cjk_fonts($Root)
	_sync_left()
	_sync_right()
	if _skip or _pause_btn:
		var running := game != null and (String(game.phase) == "restock" or String(game.phase) == "open")
		if running != _skip_running:
			_skip_running = running
			_apply_dev_hud_visibility()
			if _pause_btn:
				_pause_btn.visible = running


func _build_skip() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var btn := Button.new()
	btn.text = Loc.t("hud.skip_operate")
	btn.focus_mode = Control.FOCUS_NONE
	host.add_child(btn)
	btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	btn.offset_left = -210.0
	btn.offset_top = 10.0
	btn.offset_right = 210.0
	btn.offset_bottom = 78.0
	UiFont.apply_button(btn, 20)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f4d35e")
	box.set_corner_radius_all(10)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state_name, box)
	btn.add_theme_color_override("font_color", Color("1c241f"))
	btn.pressed.connect(_on_skip_operate)
	_skip = btn
	_apply_dev_hud_visibility()


func _on_show_dev_hud_changed(_enabled: bool) -> void:
	_apply_dev_hud_visibility()


func _apply_dev_hud_visibility() -> void:
	## Developer chrome: store／role／ops + right action／log + skip. Default off.
	## Standard: left status plate, stamina／carry (top-right), skills／CD (bottom-right), tasks (bottom-left).
	var show := PlatformServices.is_show_dev_hud()
	if _store:
		_store.visible = show
	if _role:
		_role.visible = show
	if _skills:
		_skills.visible = false
	if _ops_rating:
		_ops_rating.visible = show
	if _right:
		_right.visible = show
	if _skip:
		var ProductVersion = preload("res://scripts/product_version.gd")
		var running := game != null and (String(game.phase) == "restock" or String(game.phase) == "open")
		_skip.visible = show and ProductVersion.test_tools_enabled() and running


func _build_pause() -> void:
	## Top-right pause control — required for Web / touch (no Esc / Start).
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var btn := Button.new()
	btn.text = Loc.t("hud.pause")
	btn.focus_mode = Control.FOCUS_NONE
	host.add_child(btn)
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = -168.0
	btn.offset_top = 10.0
	btn.offset_right = -16.0
	btn.offset_bottom = 78.0
	UiFont.apply_button(btn, 20)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("24302a")
	box.set_corner_radius_all(10)
	box.border_color = Color("f4d35e")
	box.set_border_width_all(2)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state_name, box)
	btn.add_theme_color_override("font_color", Color("f4f1ea"))
	btn.pressed.connect(_on_pause_pressed)
	_pause_btn = btn


func _on_skip_operate() -> void:
	SfxBus.play("sfx_ui_test_skip")
	if game and game.has_method("skip_operate"):
		game.skip_operate()


func _on_pause_pressed() -> void:
	if game and game.has_method("request_pause"):
		game.call("request_pause")


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


func _sync_left() -> void:
	if game == null or player == null:
		return
	var hours := float(game.game_hours)
	## ~1 game-minute buckets so the clock label still ticks without full rebuild spam.
	var hour_bucket := int(floor(hours * 60.0))
	var rev := int(game.get("hud_rev")) if game.get("hud_rev") != null else 0
	## Stamina updates every frame; other left chrome is fingerprint-gated.
	_sync_stamina_std()
	var skills_txt := _skill_cd_text_all()
	var skills_shown := _skills_std.text if _skills_std else ""
	if rev == _left_hud_rev and hour_bucket == _left_hour_bucket and skills_txt == skills_shown:
		return
	_left_hud_rev = rev
	_left_hour_bucket = hour_bucket
	var time_txt: String = game.clock_text()
	var phase_txt: String = game.phase_text()
	var rev_n := int(game.revenue)
	var stolen_n := int(game.stolen_value)
	var guests_n := int(game.guest_count())
	var thieves_n := int(game.call("thief_count"))
	var store_txt := String(player.call("store_status_text"))
	var role_txt := _role_status_all()
	var p1 := int(game.call("combo_personal", 0)) if game.has_method("combo_personal") else 0
	var p2 := int(game.call("combo_personal", 1)) if game.has_method("combo_personal") else 0
	var team := int(game.call("combo_team")) if game.has_method("combo_team") else 0
	var ops_n := int(game.get("ops_rating")) if game.get("ops_rating") != null else 50
	var tasks_txt := _tasks_status_text()
	var fp := "%s|%s|%d|%d|%d|%d|%s|%s|%s|%d|%d|%d|%d|%d|%d|%s" % [
		time_txt, phase_txt, rev_n, stolen_n, guests_n, thieves_n,
		store_txt, role_txt, skills_txt, p1, p2, team, rev, hour_bucket, ops_n, tasks_txt,
	]
	if fp == _left_fp:
		return
	_left_fp = fp
	_clock.game_hours = hours
	_time.text = time_txt
	_phase.text = phase_txt
	_rev.text = Loc.t("hud.revenue", [rev_n, stolen_n])
	if _ops_rating:
		_ops_rating.text = Loc.t("hud.ops_rating", [ops_n])
	_guests.text = Loc.t("hud.guests", [guests_n, thieves_n])
	_store.text = store_txt
	_role.text = role_txt
	if _skills_std:
		_skills_std.text = skills_txt
	if _skills_panel:
		_skills_panel.visible = skills_txt != ""
		if skills_txt != "":
			var skill_lines := skills_txt.count("\n") + 1
			var sh := float(24 + skill_lines * 22)
			_skills_panel.offset_bottom = -12.0
			_skills_panel.offset_top = -12.0 - maxf(sh, 48.0)
	if _combo:
		if SeatTable.is_coop():
			_combo.text = Loc.t("hud.combo_coop", [p1, p2, team])
		else:
			_combo.text = Loc.t("hud.combo", [p1, team])
	if _tasks:
		_tasks.text = tasks_txt
	if _tasks_panel:
		_tasks_panel.visible = tasks_txt != ""
		if tasks_txt != "":
			var task_lines := tasks_txt.count("\n") + 1
			var th := float(24 + task_lines * 22)
			_tasks_panel.offset_bottom = -12.0
			_tasks_panel.offset_top = -12.0 - maxf(th, 48.0)


func _pane_player(pane: Dictionary) -> CharacterBody2D:
	## Freed peers leave a dangling Variant in the pane — typed assign crashes before is_instance_valid.
	var raw = pane.get("player")
	if raw == null or not is_instance_valid(raw):
		return null
	return raw as CharacterBody2D


func _role_status_all() -> String:
	if _panes.size() <= 1:
		if player == null or not is_instance_valid(player):
			return ""
		return String(player.call("role_status_text"))
	var lines: PackedStringArray = []
	for pane in _panes:
		var p := _pane_player(pane)
		if p == null:
			continue
		var seat := int(p.get("seat_id")) + 1
		lines.append("P%d %s" % [seat, String(p.call("role_status_text"))])
	return "\n".join(lines)


func _sync_stamina_std() -> void:
	if _stamina_std == null or player == null or not is_instance_valid(player):
		return
	if player.has_method("stamina_max_now"):
		_stamina_std.max_value = float(player.call("stamina_max_now"))
	_stamina_std.value = float(player.get("stamina"))
	_sync_carry_std()


func _sync_carry_std() -> void:
	if _carry_std == null or player == null or not is_instance_valid(player):
		return
	var inv = player.get("inventory")
	var n := int(inv.count()) if inv != null else 0
	var cap := int(player.call("carry_cap")) if player.has_method("carry_cap") else 0
	_carry_std.text = Loc.t("hud.carry", [n, cap])
	var before := _carry_std_fp
	_sync_carry_icons_into(_carry_icons_std, inv, true)
	if _carry_std_fp != before:
		_fit_tr_panel(n > 0)


func _fit_tr_panel(has_icons: bool = false) -> void:
	if _tr_panel == null:
		return
	## Stamina + carry line + optional icon strip.
	var h := 72.0 if not has_icons else 128.0
	_tr_panel.offset_top = 88.0
	_tr_panel.offset_bottom = 88.0 + h


func _tasks_status_text() -> String:
	if game == null or not game.has_method("task_hud_lines"):
		return ""
	var seat := 0
	if player != null and is_instance_valid(player):
		seat = int(player.seat_id)
	var rows: Array = game.call("task_hud_lines", seat)
	if rows.is_empty():
		return ""
	const TaskTracker = preload("res://scripts/session/task_tracker.gd")
	var lines: PackedStringArray = PackedStringArray()
	lines.append(Loc.t("hud.tasks_header"))
	for row in rows:
		if not (row is Dictionary):
			continue
		var st := String(row.get("status", "active"))
		var unwired := bool(row.get("unwired", false))
		var mark := TaskTracker.status_mark(st, unwired)
		var key := String(row.get("loc_key", ""))
		var label := Loc.t(key) if key != "" else String(row.get("id", ""))
		if unwired:
			lines.append("%s %s (%s)" % [mark, label, Loc.t("hud.tasks_unwired")])
			continue
		var cur := int(row.get("current", 0))
		var tgt := int(row.get("target", 0))
		var op := String(row.get("op", ">="))
		var prog := TaskTracker.progress_text(op, cur, tgt, st)
		if st == "done":
			lines.append("%s %s %s %s" % [mark, label, prog, Loc.t("hud.tasks_done")])
		else:
			lines.append("%s %s %s" % [mark, label, prog])
	return "\n".join(lines)


func _sync_right() -> void:
	if not _right_dirty:
		return
	_right_dirty = false
	_refresh()


func _skill_cd_label(cd: float) -> String:
	## Match cast gate (cd > 0.05). Never show "CD 0" while not ready — ceil whole seconds.
	if cd <= 0.05:
		return Loc.t("hud.skill.ready")
	return "CD %d" % maxi(1, int(ceil(cd)))


func _skill_cd_fp_bit(cd: float) -> String:
	## Ready bit must flip when crossing 0.05 even if 0.25s snap stays at 0.00.
	if cd <= 0.05:
		return "R"
	return "%.2f" % snappedf(cd, 0.25)


func _skill_cd_text_all() -> String:
	if _panes.size() <= 1:
		return _skill_cd_text_for(player, "")
	var blocks: PackedStringArray = []
	for pane in _panes:
		var p := _pane_player(pane)
		if p == null:
			continue
		var seat := int(p.get("seat_id")) + 1
		blocks.append(_skill_cd_text_for(p, "P%d " % seat))
	var joined := "\n".join(blocks)
	## Keep left fingerprint path simple via shared cache key.
	if joined == _skills_cd_txt:
		return _skills_cd_txt
	_skills_cd_fp = joined
	_skills_cd_txt = joined
	return _skills_cd_txt


func _skill_cd_text_for(p: CharacterBody2D, prefix: String) -> String:
	if p == null:
		return ""
	var equipped: Array = []
	if p.has_method("_loadout"):
		equipped = p.call("_loadout")
	else:
		for raw in Skills.EQUIPPED:
			equipped.append(Skills.localize(raw))
	var bits: PackedStringArray = []
	for i in equipped.size():
		var sk: Dictionary = equipped[i]
		if sk.is_empty():
			bits.append("%d:-" % i)
			continue
		var sid := String(sk.get("id"))
		if String(sk.get("kind")) == "passive":
			bits.append("%d:P" % i)
		else:
			bits.append("%d:%s" % [i, _skill_cd_fp_bit(float(p.call("cd_left", sid)))])
	var ult: Dictionary = (
		p.call("_ult_sk") if p.has_method("_ult_sk") else Skills.localize(Skills.ULTIMATE)
	)
	var ult_id := String(ult.get("id", ""))
	if ult_id == "":
		bits.append("U:-")
	else:
		bits.append("U:%s" % _skill_cd_fp_bit(float(p.call("cd_left", ult_id))))
	var fp := prefix + "|".join(bits)
	## Solo path keeps old cache; coop rebuilds each left sync via _skill_cd_text_all.
	if prefix == "" and fp == _skills_cd_fp:
		return _skills_cd_txt
	if prefix == "":
		_skills_cd_fp = fp
	var lines: PackedStringArray = []
	if prefix != "":
		lines.append(prefix.strip_edges())
	for i in equipped.size():
		var sk2: Dictionary = equipped[i]
		if sk2.is_empty():
			lines.append(Loc.t("hud.skill.empty", [i + 1]))
			continue
		var name := String(sk2.get("name"))
		if String(sk2.get("kind")) == "passive":
			lines.append(Loc.t("hud.skill.passive", [i + 1, name]))
		else:
			var cd := float(p.call("cd_left", String(sk2.get("id"))))
			lines.append("%d %s  %s" % [i + 1, name, _skill_cd_label(cd)])
	if ult_id == "":
		lines.append(Loc.t("hud.ult.empty"))
	else:
		var ucd := float(p.call("cd_left", ult_id))
		lines.append(Loc.t("hud.ult.line", [String(ult.get("name")), _skill_cd_label(ucd)]))
	var txt := "\n".join(lines)
	if prefix == "":
		_skills_cd_txt = txt
	return txt


func _refresh() -> void:
	for pane in _panes:
		_refresh_pane(pane)


func _refresh_pane(pane: Dictionary) -> void:
	var p := _pane_player(pane)
	if p == null:
		return
	var state_l: Label = pane["state"]
	var stam: ProgressBar = pane["stamina"]
	var carry_l: Label = pane["carry"]
	var target_l: Label = pane["target"]
	var prog: ProgressBar = pane["progress"]
	var title_l: Label = pane["title"]
	if title_l:
		title_l.text = Loc.t("hud.seat", [int(p.get("seat_id")) + 1])
	state_l.text = Loc.t("hud.state", [p.call("move_state")])
	stam.max_value = float(p.call("stamina_max_now"))
	stam.value = float(p.get("stamina"))
	var inv = p.get("inventory")
	carry_l.text = Loc.t("hud.carry", [
		int(inv.count()) if inv != null else 0,
		int(p.call("carry_cap")),
	])
	_sync_carry_icons(pane, inv)
	## Freed interact targets still sit on player.target until cleared; typed assign crashes.
	var t = p.get("target")
	if t == null or not is_instance_valid(t):
		target_l.text = Loc.t("hud.target_none")
	else:
		## Object.get can return null — Godot 4 String()/int()/bool() reject null.
		var kind_v = t.get("kind")
		var kind := str(kind_v) if kind_v != null else ""
		match kind:
			"restock":
				var cat_name := Loc.t("hud.cat_dry")
				var cat_v = t.get("category")
				var cat := str(cat_v) if cat_v != null else ""
				if cat == Tuning.CAT_FROZEN:
					cat_name = Loc.t("hud.cat_frozen")
				elif cat == Tuning.CAT_ICE:
					cat_name = Loc.t("hud.cat_ice")
				var pick = t.call("selected_sku") if t.has_method("selected_sku") else ""
				target_l.text = Loc.t("hud.target_restock", [
					cat_name,
					Tuning.sku_name(str(pick) if pick != null else ""),
				])
			"cashier":
				target_l.text = Loc.t("hud.target_cashier")
			"dirt":
				var dname = t.call("type_name") if t.has_method("type_name") else ""
				target_l.text = Loc.t("hud.target_dirt", [str(dname) if dname != null else ""])
			"drop":
				target_l.text = Loc.t("hud.target_drop", [
					Tuning.sku_name(_obj_str(t, "sku")),
					_obj_int(t, "count"),
				])
			"thief":
				target_l.text = Loc.t("hud.target_thief")
			"shelf":
				var sku := _obj_str(t, "sku")
				var cap := _obj_int(t, "capacity")
				if cap <= 0:
					cap = Tuning.SHELF_CAP
				var shelf_bit := Loc.t("hud.shelf_empty", [cap]) if sku == "" else "%s %d/%d" % [Tuning.sku_name(sku), _obj_int(t, "count"), cap]
				target_l.text = Loc.t("hud.target_shelf", [shelf_bit])
			"", "elite":
				target_l.text = Loc.t("hud.target_guest")
			_:
				target_l.text = Loc.t("hud.target_none")
	prog.value = float(p.get("hold_progress")) * 100.0 if p.get("hold_progress") != null else 0.0
	prog.modulate = Color("e07a5f") if p.get("blocked_mismatch") else Color("f4d35e")


## Object.get has no default; typed ctors explode on null.
func _obj_str(node: Object, prop: String) -> String:
	var v = node.get(prop)
	return str(v) if v != null else ""


func _obj_int(node: Object, prop: String) -> int:
	var v = node.get(prop)
	return int(v) if v != null else 0


## Hand-carry sequence: left→right, last slot = next drop (trailing).
func _sync_carry_icons(pane: Dictionary, inv) -> void:
	var icons: HBoxContainer = pane.get("icons")
	if icons == null:
		return
	var groups: Array = []
	if inv != null and not inv.is_empty():
		groups = inv.grouped()
	var bits: PackedStringArray = []
	for g in groups:
		bits.append("%s:%d" % [String(g["id"]), int(g["count"])])
	var fp := "|".join(bits)
	if fp == String(pane.get("icons_fp", "")):
		return
	pane["icons_fp"] = fp
	_rebuild_carry_icon_row(icons, groups)


func _sync_carry_icons_into(icons: HBoxContainer, inv, use_std_fp: bool) -> void:
	if icons == null:
		return
	var groups: Array = []
	if inv != null and not inv.is_empty():
		groups = inv.grouped()
	var bits: PackedStringArray = []
	for g in groups:
		bits.append("%s:%d" % [String(g["id"]), int(g["count"])])
	var fp := "|".join(bits)
	if use_std_fp:
		if fp == _carry_std_fp:
			return
		_carry_std_fp = fp
	_rebuild_carry_icon_row(icons, groups)


func _rebuild_carry_icon_row(icons: HBoxContainer, groups: Array) -> void:
	for c in icons.get_children():
		c.queue_free()
	if groups.is_empty():
		return
	var last_i := groups.size() - 1
	for i in groups.size():
		var g: Dictionary = groups[i]
		var sku := String(g["id"])
		var n := int(g["count"])
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var icon := SkuIcons.make_tex_rect(sku, 28)
		if i == last_i:
			## Trailing / next-drop highlight.
			var frame := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color("f4d35e")
			sb.set_border_width_all(2)
			sb.set_content_margin_all(2)
			frame.add_theme_stylebox_override("panel", sb)
			frame.add_child(icon)
			cell.add_child(frame)
		else:
			cell.add_child(icon)
		var qty := Label.new()
		qty.text = "×%d" % n
		qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiFont.apply_label(qty, UiFont.WORLD)
		qty.add_theme_color_override("font_color", Color("fff4c2"))
		qty.add_theme_color_override("font_outline_color", Color("121212"))
		qty.add_theme_constant_override("outline_size", 4)
		cell.add_child(qty)
		icons.add_child(cell)
