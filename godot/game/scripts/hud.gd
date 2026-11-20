extends CanvasLayer

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")
const SkillHudChip = preload("res://scripts/ui/skill_hud_chip.gd")
const OpsItems = preload("res://scripts/ops_items.gd")
const OpsItemIcons = preload("res://scripts/ops_item_icons.gd")

## Ops HUD palette — dark shop plate + warm gold accent (not purple / cream-serif clichés).
const COL_INK := Color(0.045, 0.055, 0.06, 1.0)
const COL_PANEL := Color(0.07, 0.09, 0.10, 0.94)
const COL_PANEL_EDGE := Color(0.42, 0.48, 0.44, 0.65)
const COL_TEXT := Color(0.97, 0.96, 0.93, 1.0)
const COL_MUTED := Color(0.78, 0.80, 0.76, 1.0)
const COL_GOLD := Color(0.96, 0.83, 0.37, 1.0)
const COL_TEAL := Color(0.42, 0.78, 0.68, 1.0)
const COL_STAMINA := Color(0.38, 0.82, 0.58, 0.95)
const COL_STAMINA_LOW := Color(0.92, 0.55, 0.32, 0.95)
const COL_STAMINA_BG := Color(0.08, 0.10, 0.10, 0.75)

var game: Node
var player: CharacterBody2D
var _skip: Button
var _pause_btn: Button
var _left_fp: String = ""
var _right_dirty: bool = true
var _skip_running: bool = false
var _font_debounce: float = 0.0
var _font_pending: bool = false
## Skip rebuilding store/role when game hud_rev + clock bucket unchanged.
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
var _stamina_std: ProgressBar
var _carry_std: Label
var _carry_icons_std: HBoxContainer
var _carry_std_fp: String = ""
var _tr_panel: PanelContainer
var _skills_list: VBoxContainer
var _skills_chip_fp := ""
var _skills_panel: PanelContainer
var _bag_panel: Control
var _bag_slots: Array = [] ## TextureRect ×4: up, right, down, left
var _bag_fp := ""
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
@onready var _close_dim: ColorRect = $Root/CloseoutDim
@onready var _close: PanelContainer = $Root/Closeout
@onready var _close_tasks_card: PanelContainer = $Root/Closeout/Margin/Columns/TasksCard
@onready var _close_settle_card: PanelContainer = $Root/Closeout/Margin/Columns/SettleCard
@onready var _close_tasks_header: Label = $Root/Closeout/Margin/Columns/TasksCard/CardMargin/TasksCol/TasksHeader
@onready var _close_tasks: Label = $Root/Closeout/Margin/Columns/TasksCard/CardMargin/TasksCol/TasksText
@onready var _close_settle_header: Label = $Root/Closeout/Margin/Columns/SettleCard/CardMargin/SettleCol/SettleHeader
@onready var _close_text: Label = $Root/Closeout/Margin/Columns/SettleCard/CardMargin/SettleCol/CloseText
var _closeout_styled: bool = false
var _stamina_low_paint: bool = false


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
	_style_right_panel()
	_restyle_ops_labels()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_style_closeout()
	_set_closeout_visible(false)
	_cast.modulate.a = 0.0
	_build_skip()
	_build_pause()
	if not InputMode.show_vj_changed.is_connected(_on_show_vj_changed_pause):
		InputMode.show_vj_changed.connect(_on_show_vj_changed_pause)
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
	## Sit under guests — action feedback after shop vitals.
	left.add_child(_combo)
	left.move_child(_combo, _guests.get_index() + 1)


func _wrap_left_status_panel() -> void:
	## Left vitals plate: time → money → floor → combo.
	var left: VBoxContainer = $Root/Left
	var root: Control = $Root
	var idx := left.get_index()
	root.remove_child(left)
	_left_panel = _make_hud_panel(COL_TEAL)
	_left_panel.name = "LeftStatusPanel"
	_left_panel.position = Vector2(12, 10)
	left.layout_mode = 2
	left.offset_left = 0.0
	left.offset_top = 0.0
	left.offset_right = 0.0
	left.offset_bottom = 0.0
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 5)
	if _clock:
		_clock.custom_minimum_size = Vector2(108, 108)
	_left_panel.add_child(left)
	root.add_child(_left_panel)
	root.move_child(_left_panel, idx)
	_restyle_ops_labels()


func _restyle_ops_labels() -> void:
	## Time primary → phase gold → money → floor muted → combo punch.
	_style_label(_time, COL_TEXT, UiFont.TITLE, 7)
	_style_label(_phase, COL_GOLD, UiFont.BODY, 5)
	_style_label(_rev, COL_TEXT, UiFont.BODY, 6)
	_style_label(_guests, COL_MUTED, UiFont.WORLD, 5)
	_style_label(_combo, COL_GOLD, UiFont.BODY, 6)
	_style_label(_store, COL_MUTED, UiFont.WORLD, 4)
	_style_label(_role, COL_MUTED, UiFont.WORLD, 4)
	_style_label(_tasks, COL_TEXT, UiFont.WORLD, 5)
	_style_label(_carry_std, COL_TEXT, UiFont.WORLD, 5)


func _style_label(lab: Label, color: Color, size: int = UiFont.BODY, outline: int = 5) -> void:
	if lab == null:
		return
	lab.set_meta("cjk_design", size)
	UiFont.apply_label(lab, size)
	lab.add_theme_color_override("font_color", color)
	lab.add_theme_color_override("font_outline_color", COL_INK)
	lab.add_theme_constant_override("outline_size", outline)


func _apply_readable_label(lab: Label) -> void:
	_style_label(lab, COL_TEXT, UiFont.BODY, 6)


func _build_tr_std() -> void:
	## Stamina + carry — top-right, tucked under pause.
	_tr_panel = _make_hud_panel(COL_GOLD)
	_tr_panel.name = "TopRightStd"
	_tr_panel.anchor_left = 1.0
	_tr_panel.anchor_right = 1.0
	_tr_panel.anchor_top = 0.0
	_tr_panel.anchor_bottom = 0.0
	_tr_panel.offset_left = -236.0
	_tr_panel.offset_right = -12.0
	_tr_panel.offset_top = 92.0
	_tr_panel.offset_bottom = 200.0
	_tr_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tr_panel.grow_vertical = Control.GROW_DIRECTION_END
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	_tr_panel.add_child(vbox)
	_stamina_std = ProgressBar.new()
	_stamina_std.name = "StaminaStd"
	_stamina_std.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_std.show_percentage = false
	_stamina_std.max_value = 100.0
	_stamina_std.value = 100.0
	_stamina_std.custom_minimum_size = Vector2(196, 16)
	_paint_stamina_bar(_stamina_std, 1.0)
	vbox.add_child(_stamina_std)
	_carry_std = _make_hud_label("CarryStd")
	_carry_std.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_carry_std.text = Loc.t("hud.carry", [0, 0])
	_style_label(_carry_std, COL_TEXT, UiFont.WORLD, 5)
	vbox.add_child(_carry_std)
	_carry_icons_std = _make_carry_icons()
	_carry_icons_std.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(_carry_icons_std)
	$Root.add_child(_tr_panel)
	$Root.move_child(_tr_panel, _banner.get_index())
	_apply_cjk_fonts(_carry_std)
	_fit_tr_panel()
	## Personal stamina/carry moved to world-space (player_floor_bars / carry_strip).
	_tr_panel.visible = false


func _paint_stamina_bar(bar: ProgressBar, ratio: float) -> void:
	if bar == null:
		return
	var low := ratio <= 0.28
	if bar == _stamina_std and bar.get_theme_stylebox("fill") != null and low == _stamina_low_paint:
		return
	if bar == _stamina_std:
		_stamina_low_paint = low
	var fill := StyleBoxFlat.new()
	fill.bg_color = COL_STAMINA_LOW if low else COL_STAMINA
	fill.set_corner_radius_all(5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_STAMINA_BG
	bg.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)


func _make_hud_panel(accent: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_PANEL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if accent.a > 0.01:
		sb.border_width_left = 3
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.9)
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _make_hud_label(name: String) -> Label:
	var lab := Label.new()
	lab.name = name
	lab.text = ""
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(lab, COL_TEXT, UiFont.BODY, 5)
	return lab


func _build_bottom_left_panel() -> void:
	## Tasks — bottom-left (teal). Skills／CD — bottom-right (gold).
	_tasks_panel = _make_hud_panel(COL_TEAL)
	_tasks_panel.name = "TasksPanel"
	_tasks_panel.visible = false
	_tasks_panel.anchor_left = 0.0
	_tasks_panel.anchor_right = 0.0
	_tasks_panel.anchor_top = 1.0
	_tasks_panel.anchor_bottom = 1.0
	_tasks_panel.offset_left = 12.0
	_tasks_panel.offset_right = 380.0
	_tasks_panel.offset_top = -52.0
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

	_skills_panel = _make_hud_panel(COL_GOLD)
	_skills_panel.name = "SkillsPanel"
	_skills_panel.anchor_left = 1.0
	_skills_panel.anchor_right = 1.0
	_skills_panel.anchor_top = 1.0
	_skills_panel.anchor_bottom = 1.0
	_skills_panel.offset_left = -280.0
	_skills_panel.offset_right = -12.0
	_skills_panel.offset_top = -52.0
	_skills_panel.offset_bottom = -12.0
	_skills_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skills_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var s_margin := MarginContainer.new()
	s_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s_margin.add_theme_constant_override("margin_left", 8)
	s_margin.add_theme_constant_override("margin_right", 8)
	s_margin.add_theme_constant_override("margin_top", 6)
	s_margin.add_theme_constant_override("margin_bottom", 6)
	_skills_panel.add_child(s_margin)
	_skills_list = VBoxContainer.new()
	_skills_list.name = "SkillList"
	_skills_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skills_list.alignment = BoxContainer.ALIGNMENT_END
	_skills_list.add_theme_constant_override("separation", 4)
	s_margin.add_child(_skills_list)
	$Root.add_child(_skills_panel)
	$Root.move_child(_skills_panel, _banner.get_index())
	## Skill chips replaced by character radial (player-context-ui).
	_skills_panel.visible = false
	_build_bag_cross()


func _build_bag_cross() -> void:
	## Cross of 4 slots immediately left of the skills panel.
	_bag_panel = Control.new()
	_bag_panel.name = "OpsBagCross"
	_bag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_panel.anchor_left = 1.0
	_bag_panel.anchor_right = 1.0
	_bag_panel.anchor_top = 1.0
	_bag_panel.anchor_bottom = 1.0
	_bag_panel.offset_left = -400.0
	_bag_panel.offset_right = -292.0
	_bag_panel.offset_top = -120.0
	_bag_panel.offset_bottom = -12.0
	_bag_slots.clear()
	var cell := 36.0
	var gap := 4.0
	var positions := [
		Vector2(cell + gap, 0.0), ## up
		Vector2((cell + gap) * 2.0, cell + gap), ## right
		Vector2(cell + gap, (cell + gap) * 2.0), ## down
		Vector2(0.0, cell + gap), ## left
	]
	for i in 4:
		var plate := Panel.new()
		plate.position = positions[i]
		plate.size = Vector2(cell, cell)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.09, 0.10, 0.96)
		sb.set_corner_radius_all(7)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.32, 0.36, 0.34, 0.90)
		plate.add_theme_stylebox_override("panel", sb)
		var icon := TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(icon)
		_bag_panel.add_child(plate)
		_bag_slots.append(icon)
	$Root.add_child(_bag_panel)
	$Root.move_child(_bag_panel, _banner.get_index())
	## Bag cross replaced by character radial (player-context-ui).
	_bag_panel.visible = false


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


func _flat_panel(bg: Color, border: Color, radius: int = 10, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


func _style_closeout_label(lab: Label, size: int, color: Color, outline: int = 5) -> void:
	if lab == null:
		return
	UiFont.apply_label(lab, size)
	lab.add_theme_color_override("font_color", color)
	lab.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.06, 1))
	lab.add_theme_constant_override("outline_size", outline)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _style_closeout() -> void:
	if _closeout_styled or _close == null:
		return
	_closeout_styled = true
	## Outer shell — near-opaque so shop floor never bleeds through type.
	_close.add_theme_stylebox_override(
		"panel",
		_flat_panel(Color(0.07, 0.09, 0.10, 0.98), Color(0.42, 0.48, 0.44, 0.95), 14, 2)
	)
	if _close_tasks_card:
		_close_tasks_card.add_theme_stylebox_override(
			"panel",
			_flat_panel(Color(0.11, 0.13, 0.14, 1.0), Color(0.28, 0.32, 0.30, 0.85), 10, 1)
		)
	if _close_settle_card:
		_close_settle_card.add_theme_stylebox_override(
			"panel",
			_flat_panel(Color(0.12, 0.14, 0.13, 1.0), Color(0.55, 0.48, 0.28, 0.75), 10, 1)
		)
	## Headers: warm accent; body: high-contrast cream + outline.
	_style_closeout_label(_close_tasks_header, UiFont.TITLE, Color(0.96, 0.83, 0.37, 1), 6)
	_style_closeout_label(_close_settle_header, UiFont.TITLE, Color(0.96, 0.83, 0.37, 1), 6)
	_style_closeout_label(_close_tasks, UiFont.BODY, Color(0.96, 0.95, 0.92, 1), 5)
	_style_closeout_label(_close_text, UiFont.BODY, Color(0.96, 0.95, 0.92, 1), 5)
	if _close_dim:
		_close_dim.color = Color(0.02, 0.03, 0.04, 0.74)
		_close_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_close_dim.z_index = 7


func _set_closeout_visible(on: bool) -> void:
	_style_closeout()
	if _close_dim:
		_close_dim.visible = on
	_close.visible = on
	## Keep live HUD chrome from fighting the settle card.
	if on:
		if _tasks_panel:
			_tasks_panel.visible = false
		if _skills_panel:
			_skills_panel.visible = false
		if _bag_panel:
			_bag_panel.visible = false


func show_closeout() -> void:
	_set_closeout_visible(true)
	if _close_tasks_header:
		_close_tasks_header.text = Loc.t("settle.tasks_header")
	if _close_settle_header:
		_close_settle_header.text = Loc.t("settle.results_header")
	if _close_tasks:
		_close_tasks.text = Loc.t("settle.tasks_empty")
	_close_text.text = Loc.t("settle.hud_legacy", [
		game.revenue, game.served, game.angry_left,
		int(game.stolen_count), int(game.stolen_value),
		int(game.thieves_caught), int(game.thieves_escaped)
	])


## Left = task results; right = day settle body.
func set_closeout_panels(settle_body: String, tasks_body: String = "") -> void:
	_set_closeout_visible(true)
	if _close_tasks_header:
		_close_tasks_header.text = Loc.t("settle.tasks_header")
	if _close_settle_header:
		_close_settle_header.text = Loc.t("settle.results_header")
	if _close_tasks:
		_close_tasks.text = tasks_body if tasks_body.strip_edges() != "" else Loc.t("settle.tasks_empty")
	_close_text.text = settle_body


func _process(delta: float) -> void:
	if _font_pending:
		_font_debounce -= delta
		if _font_debounce <= 0.0:
			_font_pending = false
			_apply_cjk_fonts($Root)
			_restyle_ops_labels()
	_sync_left()
	_sync_right()
	if _skip or _pause_btn:
		var running := game != null and (String(game.phase) == "restock" or String(game.phase) == "open")
		if running != _skip_running:
			_skip_running = running
			_apply_dev_hud_visibility()
		if _pause_btn:
			## Esc/Start always work; on-screen pause only when virtual stick is shown.
			var show_pause := running and InputMode.show_vj()
			if _pause_btn.visible != show_pause:
				_pause_btn.visible = show_pause


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
	## Target／carry chrome may include SKU names — rebuild immediately.
	_left_fp = ""
	_right_dirty = true
	_refresh()


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
	btn.offset_left = -156.0
	btn.offset_top = 12.0
	btn.offset_right = -12.0
	btn.offset_bottom = 76.0
	UiFont.apply_button(btn, 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_GOLD
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var hover := normal.duplicate()
	hover.bg_color = Color(0.12, 0.15, 0.14, 0.96)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.05, 0.07, 0.07, 0.98)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.pressed.connect(_on_pause_pressed)
	_pause_btn = btn


func _style_right_panel() -> void:
	if _right == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.85)
	sb.set_corner_radius_all(10)
	_right.add_theme_stylebox_override("panel", sb)


func _on_skip_operate() -> void:
	SfxBus.play("sfx_ui_test_skip")
	if game:
		game.skip_operate()


func _on_pause_pressed() -> void:
	if game:
		game.request_pause()


func _on_show_vj_changed_pause(_show: bool = false) -> void:
	if _pause_btn == null:
		return
	var running := game != null and (String(game.phase) == "restock" or String(game.phase) == "open")
	_pause_btn.visible = running and InputMode.show_vj()


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
	## Stamina + skill chips + bag cross update every frame; other left chrome is fingerprint-gated.
	_sync_stamina_std()
	_sync_skill_hud()
	_sync_bag_hud()
	if rev == _left_hud_rev and hour_bucket == _left_hour_bucket:
		return
	_left_hud_rev = rev
	_left_hour_bucket = hour_bucket
	var time_txt: String = game.clock_text()
	var phase_txt: String = game.phase_text()
	var rev_n := int(game.revenue)
	var stolen_n := int(game.stolen_value)
	var guests_n := int(game.guest_count())
	var thieves_n := int(game.thief_count())
	var store_txt := String(player.call("store_status_text"))
	var role_txt := _role_status_all()
	var p1 := int(game.combo_personal(0))
	var p2 := int(game.combo_personal(1))
	var team := int(game.combo_team())
	var ops_n := int(game.get("ops_rating")) if game.get("ops_rating") != null else 50
	var tasks_txt := _tasks_status_text()
	var fp := "%s|%s|%d|%d|%d|%d|%s|%s|%d|%d|%d|%d|%d|%d|%s" % [
		time_txt, phase_txt, rev_n, stolen_n, guests_n, thieves_n,
		store_txt, role_txt, p1, p2, team, rev, hour_bucket, ops_n, tasks_txt,
	]
	if fp == _left_fp:
		return
	_left_fp = fp
	_clock.game_hours = hours
	_time.text = time_txt
	_phase.text = phase_txt
	_rev.text = Loc.t("hud.revenue", [rev_n, ops_n, stolen_n])
	## Guests / store / role / combo: hide from shared Overcooked HUD (dev panel still has detail).
	var show_extra := PlatformServices.is_show_dev_hud()
	_guests.visible = show_extra
	_store.visible = show_extra
	_role.visible = show_extra
	if show_extra:
		_guests.text = Loc.t("hud.guests", [guests_n, thieves_n])
		_store.text = store_txt
		_role.text = role_txt
	if _combo:
		_combo.visible = show_extra
		if show_extra:
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
			var th := float(28 + task_lines * 24)
			_tasks_panel.offset_bottom = -12.0
			_tasks_panel.offset_top = -12.0 - maxf(th, 52.0)


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
	var mx := maxf(_stamina_std.max_value, 1.0)
	_paint_stamina_bar(_stamina_std, _stamina_std.value / mx)
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
	var h := 68.0 if not has_icons else 124.0
	_tr_panel.offset_top = 92.0
	_tr_panel.offset_bottom = 92.0 + h


func _tasks_status_text() -> String:
	if game == null:
		return ""
	var seat := 0
	if player != null and is_instance_valid(player):
		seat = int(player.seat_id)
	var rows: Array = game.task_hud_lines(seat)
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
		var label := String(row.get("name", ""))
		if label == "":
			var key := String(row.get("name_key", row.get("loc_key", "")))
			label = Loc.t(key) if key != "" else String(row.get("id", ""))
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


func _sync_skill_hud() -> void:
	if _skills_list == null or _skills_panel == null:
		return
	var entries: Array = _skill_hud_entries()
	var ids: PackedStringArray = []
	for e in entries:
		ids.append(String(e.get("id", "")))
	var fp := "|".join(ids)
	if fp != _skills_chip_fp:
		_skills_chip_fp = fp
		while _skills_list.get_child_count() > 0:
			var old: Node = _skills_list.get_child(0)
			_skills_list.remove_child(old)
			old.free()
		for e in entries:
			var chip = SkillHudChip.new()
			_skills_list.add_child(chip)
			chip.setup(String(e["id"]), String(e["name"]), String(e["kind"]))
	var chips := _skills_list.get_children()
	var n := mini(chips.size(), entries.size())
	for i in n:
		var chip2 = chips[i]
		var e2: Dictionary = entries[i]
		if chip2.has_method("set_timers"):
			chip2.call(
				"set_timers",
				float(e2.get("cd_left", 0.0)),
				float(e2.get("cd_max", 0.0)),
				float(e2.get("buff_left", 0.0)),
				float(e2.get("buff_max", 0.0)),
			)
	## Always hide screen skill chips — use world radial.
	_skills_panel.visible = false


func _sync_bag_hud() -> void:
	if _bag_panel == null or _bag_slots.is_empty():
		return
	## Always hide screen bag cross — use world radial.
	_bag_panel.visible = false
	return
	var running := game != null and (String(game.phase) == "restock" or String(game.phase) == "open")
	var unlocked := OpsItems.unlocked_count()
	if not (running and unlocked > 0 and not _close.visible):
		return
	var bag: Array[String] = []
	if player != null and player.has_method("ops_bag_ids"):
		bag = player.ops_bag_ids()
	var parts: PackedStringArray = []
	for i in 4:
		var id := String(bag[i]) if i < bag.size() else ""
		if i >= unlocked:
			id = ""
		parts.append(id)
		var icon: TextureRect = _bag_slots[i]
		if id == "":
			icon.texture = null
			icon.modulate = Color(1, 1, 1, 0.35)
		else:
			icon.texture = OpsItemIcons.texture(id)
			icon.modulate = Color(1, 1, 1, 1)
	var fp := "|".join(parts)
	_bag_fp = fp


func _skill_hud_entries() -> Array:
	var out: Array = []
	if _panes.size() <= 1:
		_append_skill_hud_entries(out, player, "")
		return out
	for pane in _panes:
		var p := _pane_player(pane)
		if p == null:
			continue
		var seat := int(p.get("seat_id")) + 1
		_append_skill_hud_entries(out, p, "P%d " % seat)
	return out


func _append_skill_hud_entries(out: Array, p: CharacterBody2D, prefix: String) -> void:
	if p == null:
		return
	var equipped: Array = []
	if p.has_method("_loadout"):
		equipped = p.call("_loadout")
	else:
		for raw in Skills.EQUIPPED:
			equipped.append(Skills.localize(raw))
	for sk in equipped:
		if not (sk is Dictionary) or (sk as Dictionary).is_empty():
			continue
		var row := _skill_hud_entry_from(p, sk as Dictionary, prefix)
		if not row.is_empty():
			out.append(row)
	var ult: Dictionary = (
		p.call("_ult_sk") if p.has_method("_ult_sk") else Skills.localize(Skills.ULTIMATE)
	)
	if not ult.is_empty() and String(ult.get("id", "")) != "":
		var urow := _skill_hud_entry_from(p, ult, prefix)
		if not urow.is_empty():
			out.append(urow)


func _skill_hud_entry_from(p: CharacterBody2D, sk: Dictionary, prefix: String) -> Dictionary:
	var sid := String(sk.get("id", ""))
	if sid == "":
		return {}
	var kind := String(sk.get("kind", "active"))
	var nm := String(sk.get("name", ""))
	if nm == "":
		nm = Loc.t("skill.%s.name" % sid)
	var cd_left := 0.0
	var buff_left := 0.0
	if p.has_method("cd_left"):
		cd_left = float(p.call("cd_left", sid))
	if p.has_method("buff_left"):
		buff_left = float(p.call("buff_left", sid))
	var cd_max := maxf(float(sk.get("cd", 0.0)), cd_left)
	var buff_max := _skill_buff_max(sk, buff_left)
	return {
		"id": sid,
		"name": prefix + nm,
		"kind": kind,
		"cd_left": cd_left,
		"cd_max": cd_max,
		"buff_left": buff_left,
		"buff_max": buff_max,
	}


func _skill_buff_max(sk: Dictionary, buff_left: float) -> float:
	var sid := String(sk.get("id", ""))
	var lv := int(sk.get("lv", 3))
	var catalog := float(sk.get("duration", 0.0))
	match sid:
		"dasher":
			catalog = float(Skills.dasher_seconds(lv))
		"hoop_ace":
			catalog = float(Skills.hoop_ace_seconds(lv))
		"senior_cashier":
			catalog = float(Skills.senior_cashier_seconds(lv))
		"sweeping_monk":
			catalog = float(Skills.sweeping_monk_seconds(lv))
		"guest_dusk":
			catalog = float(Skills.GUEST_DUSK_DURATION)
	return maxf(catalog, buff_left)


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
		var show_names := PlatformServices.is_show_dev_hud()
		match kind:
			"restock":
				if show_names:
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
				else:
					target_l.text = Loc.t("hud.target_restock_compact")
			"cashier":
				target_l.text = Loc.t("hud.target_cashier")
			"dirt":
				if show_names:
					var dname = t.call("type_name") if t.has_method("type_name") else ""
					target_l.text = Loc.t("hud.target_dirt", [str(dname) if dname != null else ""])
				else:
					target_l.text = Loc.t("hud.target_dirt_compact")
			"drop":
				if show_names:
					target_l.text = Loc.t("hud.target_drop", [
						Tuning.sku_name(_obj_str(t, "sku")),
						_obj_int(t, "count"),
					])
				else:
					target_l.text = Loc.t("hud.target_drop_compact", [_obj_int(t, "count")])
			"ops_item":
				## Always show item name — types are hard to tell apart from the floor sprite alone.
				var oid_v = t.get("item_id")
				var oid := str(oid_v) if oid_v != null else ""
				if oid != "":
					target_l.text = Loc.t("hud.target_ops_item", [Loc.t("ops_item.%s.name" % oid)])
				else:
					target_l.text = Loc.t("hud.target_ops_item_compact")
			"thief":
				target_l.text = Loc.t("hud.target_thief")
			"shelf":
				var sku := _obj_str(t, "sku")
				var cap := _obj_int(t, "capacity")
				if cap <= 0:
					cap = Tuning.SHELF_CAP
				if show_names:
					var shelf_bit := Loc.t("hud.shelf_empty", [cap]) if sku == "" else "%s %d/%d" % [Tuning.sku_name(sku), _obj_int(t, "count"), cap]
					target_l.text = Loc.t("hud.target_shelf", [shelf_bit])
				elif sku == "":
					target_l.text = Loc.t("hud.target_shelf_empty", [cap])
				else:
					target_l.text = Loc.t("hud.target_shelf_fill", [_obj_int(t, "count"), cap])
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


## Hand-carry sequence: left→right; gold frame = focus; right = recent-touch.
func _sync_carry_icons(pane: Dictionary, inv) -> void:
	var icons: HBoxContainer = pane.get("icons")
	if icons == null:
		return
	var groups: Array = []
	var focus_i := -1
	if inv != null and not inv.is_empty():
		groups = inv.grouped()
		focus_i = int(inv.get("focus_index"))
	var bits: PackedStringArray = []
	for g in groups:
		bits.append("%s:%d" % [String(g["id"]), int(g["count"])])
	var fp := "%s@%d" % ["|".join(bits), focus_i]
	if fp == String(pane.get("icons_fp", "")):
		return
	pane["icons_fp"] = fp
	_rebuild_carry_icon_row(icons, groups, focus_i)


func _sync_carry_icons_into(icons: HBoxContainer, inv, use_std_fp: bool) -> void:
	if icons == null:
		return
	var groups: Array = []
	var focus_i := -1
	if inv != null and not inv.is_empty():
		groups = inv.grouped()
		focus_i = int(inv.get("focus_index"))
	var bits: PackedStringArray = []
	for g in groups:
		bits.append("%s:%d" % [String(g["id"]), int(g["count"])])
	var fp := "%s@%d" % ["|".join(bits), focus_i]
	if use_std_fp:
		if fp == _carry_std_fp:
			return
		_carry_std_fp = fp
	_rebuild_carry_icon_row(icons, groups, focus_i)


func _rebuild_carry_icon_row(icons: HBoxContainer, groups: Array, focus_index: int = -1) -> void:
	for c in icons.get_children():
		c.queue_free()
	if groups.is_empty():
		return
	if focus_index < 0 or focus_index >= groups.size():
		focus_index = groups.size() - 1
	for i in groups.size():
		var g: Dictionary = groups[i]
		var sku := String(g["id"])
		var n := int(g["count"])
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var icon := SkuIcons.make_tex_rect(sku, 28)
		if i == focus_index:
			## Focus highlight (gold frame).
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
		## Touch: tap cell to set carry focus.
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(_on_carry_cell_gui.bind(i))
		icons.add_child(cell)


func _on_carry_cell_gui(event: InputEvent, index: int) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if not pressed:
		return
	var seats := _collect_seat_players()
	var p: Node = seats[0] if not seats.is_empty() else null
	if p == null or not is_instance_valid(p):
		return
	var inv = p.get("inventory")
	if inv == null or not inv.has_method("set_focus_index"):
		return
	inv.call("set_focus_index", index)
