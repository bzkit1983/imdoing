extends CanvasLayer
## Shop-prep coordinator. Shell UI lives in scenes/prep_menu.tscn; pages in scripts/prep/.
## InputMap via Controls: move_*, interact, cancel, rotate.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const StateScript = preload("res://scripts/game_state.gd")
const PrepWidgets = preload("res://scripts/prep/prep_widgets.gd")
const PrepPages = preload("res://scripts/prep/prep_pages.gd")
const PrepGridView = preload("res://scripts/prep/prep_grid_view.gd")
const ProductVersion = preload("res://scripts/product_version.gd")
const SkinCatalog = preload("res://scripts/session/skin_catalog.gd")
const CharacterSheet = preload("res://scripts/session/character_sheet.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const RatingRules = preload("res://scripts/session/rating_rules.gd")

const PREP_TITLE := PrepWidgets.PREP_TITLE
const PREP_INFO := PrepWidgets.PREP_INFO
const PREP_LIST := PrepWidgets.PREP_LIST
const PREP_HINT := PrepWidgets.PREP_HINT

signal start_day

var demo: Node
var state: StateScript

## LAN join address draft (M2).
var _lan_address: String = "127.0.0.1"
var _lan_addr_edit: LineEdit = null
## Steam lobby id draft (M3).
var _steam_lobby_draft: String = "0"
var _steam_lobby_edit: LineEdit = null

var _page: String = "scenario"
var _index: int = 0
var _skill_set: int = 0
var _rename_draft: String = ""
var _rename_lower: bool = false
var _rows: Array[Dictionary] = []
var _qty_sku: String = ""
var _qty_boxes: int = 1
var _qty_focus: int = 2
var _hold_type: String = ""
var _hold_rot: int = 0
## Pad/keyboard layout: "map" moves the grid cursor; "list" is size row + inventory list.
var _layout_focus: String = "map"
## True when the held piece was lifted off the grid (cancel restores origin).
var _hold_from_map: bool = false
var _hold_origin := Vector2i.ZERO
## Preserved when picking up a restock rack so place/cancel keeps its default SKU.
var _hold_default_sku: String = ""
## Layout interact hold: short = pick up / place; long on restock = default SKU picker.
var _layout_act_held: bool = false
var _layout_act_time: float = 0.0
var _layout_act_long: bool = false
## Layout cancel hold while lifting from map: short = restore; long = recall to stock.
var _layout_cancel_held: bool = false
var _layout_cancel_time: float = 0.0
var _layout_cancel_long: bool = false
## ≥0 while choosing default_sku for placed[index].
var _sku_pick_i: int = -1
var _sku_pick_cursor: int = 0
var _cursor := Vector2i(2, 2)
var _drag_on: bool = false
var _drag_moved: bool = false
var _drag_inside: bool = false
var _drag_type: String = ""
var _drag_rot: int = 0
var _drag_from: int = -1
var _drag_grab := Vector2i.ZERO
var _drag_press := Vector2.ZERO
var _msg: String = ""
var _list: ItemList
var _back_btn: Button
var _hub_panel: GridContainer
var _open_bar: HBoxContainer
var _open_main: Button
var _open_elite: Button
var _diff_bar: HBoxContainer
var _diff_easy: Button
var _diff_normal: Button
var _diff_cursor: int = 1
var _click_arm: int = -1
var _list_dragging: bool = false
var _list_press := Vector2.ZERO
var _info: Label
var _title: Label
var _grid: PrepGridView
var _stats_panel: VBoxContainer
var _stat_row: int = 0
var _stat_side: int = 1
var _on_stats_btns: bool = false
var _size_panel: VBoxContainer
var _size_row: int = 0
var _size_side: int = 1
var _on_size_btns: bool = false
var _qty_panel: VBoxContainer
var _hub_cols: int = 3
var _open_focus: int = -1 ## -1 tiles · 10 difficulty · 0 open main · 1 elite
var _shade: ColorRect
var _box: Control
var _dlg_title: Label
var _dlg_body: Label
var _dlg_yes: Button
var _dlg_no: Button
var _dlg_open: bool = false
var _dlg_info: bool = false
var _dlg_focus: int = 0
var _dlg_gate: int = 0
var _dlg_wait: int = 0
var _pending: Dictionary = {}
var _swallow_click: bool = false
var _confirm_latch: bool = false
## M1 local coop seat claim for the next day (1 = solo, 2 = local duo). Web forced to 1.
var _local_seats: int = 1
## GuestSlots index for P2 when seats=2 (−1 = none yet).
var _guest_slot_index: int = -1
var _guest_store = null
var _building: bool = false
var _suppress_select: bool = false
## Look-page idle preview (freed when leaving the page).
var _look_preview_root: Node2D = null
var _look_preview_spr: AnimatedSprite2D = null
var _look_preview_id: String = ""


func setup(host: Node) -> void:
	demo = host
	state = host.state
	layer = 30
	_bind_nodes()
	if not SessionService.lobby_changed.is_connected(_on_lobby_changed):
		SessionService.lobby_changed.connect(_on_lobby_changed)
	if not SessionService.net_error.is_connected(_on_net_error):
		SessionService.net_error.connect(_on_net_error)
	if not SessionService.start_day.is_connected(_on_session_start_day):
		SessionService.start_day.connect(_on_session_start_day)
	var load_err := state.load_from_disk()
	if load_err == "":
		_msg = Loc.t("prep.msg.loaded", [state.scenario, state.level, state.money])
		_show_page("home")
	else:
		_show_page("scenario")


func _on_lobby_changed() -> void:
	if _page == "lobby" and visible:
		_refresh()


func _on_net_error(message: String) -> void:
	## Mid-day Host drop is handled by demo._dissolve_room_to_prep (disconnect_session).
	if not visible and SessionService.day_started:
		return
	_popup_info(Loc.t("lobby.error_title"), Loc.t("lobby.error_body", [message]))
	if _page == "lobby" or _page == "lan_join":
		_show_page("confirm")


func _on_session_start_day() -> void:
	## Client path: hide prep; demo listens to SessionService.start_day for _begin_day.
	if SessionService.is_client():
		visible = false
		set_process_unhandled_input(false)


func _ensure_lan_address_edit(addr: String) -> void:
	if _lan_addr_edit == null:
		_lan_addr_edit = LineEdit.new()
		_lan_addr_edit.name = "LanAddressEdit"
		_lan_addr_edit.position = Vector2(24, 160)
		_lan_addr_edit.size = Vector2(480, 40)
		_lan_addr_edit.placeholder_text = "127.0.0.1"
		add_child(_lan_addr_edit)
		_lan_addr_edit.text_changed.connect(func(t: String) -> void: _lan_address = t.strip_edges())
	_lan_addr_edit.visible = true
	_lan_addr_edit.text = addr
	_lan_address = addr


func _hide_lan_address_edit() -> void:
	if _lan_addr_edit != null:
		_lan_addr_edit.visible = false


func _ensure_steam_lobby_edit(lobby_s: String) -> void:
	if _steam_lobby_edit == null:
		_steam_lobby_edit = LineEdit.new()
		_steam_lobby_edit.name = "SteamLobbyEdit"
		_steam_lobby_edit.position = Vector2(24, 160)
		_steam_lobby_edit.size = Vector2(480, 40)
		_steam_lobby_edit.placeholder_text = "Lobby ID"
		add_child(_steam_lobby_edit)
		_steam_lobby_edit.text_changed.connect(func(t: String) -> void: _steam_lobby_draft = t.strip_edges())
	_steam_lobby_edit.visible = true
	_steam_lobby_edit.text = lobby_s
	_steam_lobby_draft = lobby_s


func _hide_steam_lobby_edit() -> void:
	if _steam_lobby_edit != null:
		_steam_lobby_edit.visible = false


func _bind_nodes() -> void:
	_title = %Title
	_info = %Info
	_list = %List
	_back_btn = %BackBtn
	_hub_panel = %HubPanel
	_open_bar = %OpenBar
	_open_main = %OpenMain
	_open_elite = %OpenElite
	_diff_bar = %DiffBar
	_diff_easy = %DiffEasy
	_diff_normal = %DiffNormal
	_stats_panel = %StatsPanel
	_size_panel = %SizePanel
	_qty_panel = %QtyPanel
	_grid = %LayoutGrid
	_shade = %DialogShade
	_box = %DialogBox
	_dlg_title = %DialogTitle
	_dlg_body = %DialogBody
	_dlg_yes = %DialogYes
	_dlg_no = %DialogNo
	_grid.host = self
	_list.item_selected.connect(_on_click)
	_list.gui_input.connect(_on_list_gui_input)
	_back_btn.button_down.connect(_on_back_button)
	_open_main.pressed.connect(_on_open_main_pressed)
	_open_elite.pressed.connect(_on_open_elite_pressed)
	_diff_easy.pressed.connect(_on_diff_easy_pressed)
	_diff_normal.pressed.connect(_on_diff_normal_pressed)
	_dlg_yes.pressed.connect(_on_dlg_yes)
	_dlg_no.pressed.connect(_on_dlg_no)
	UiFont.apply_label(_title, PREP_TITLE)
	_title.add_theme_color_override("font_color", Color("f4d35e"))
	UiFont.apply_label(_info, PREP_INFO)
	_info.add_theme_color_override("font_color", Color("f4f1ea"))
	_list.add_theme_font_override("font", UiFont.font())
	_list.add_theme_font_size_override("font_size", UiFont.px(PREP_LIST))
	_list.add_theme_constant_override("v_separation", PrepWidgets.LIST_V_SEP)
	_list.add_theme_constant_override("icon_margin", 10)
	_list.fixed_icon_size = Vector2i(8, PrepWidgets.LIST_ROW_H)
	_list.add_theme_color_override("font_color", Color("f4f1ea"))
	_list.add_theme_color_override("font_selected_color", Color("1c241f"))
	_list.add_theme_color_override("font_hovered_color", Color("f4d35e"))
	var bar := _list.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(44, 0)
	PrepWidgets.paint_btn(_back_btn, true)
	UiFont.apply_button(_back_btn, PrepWidgets.PREP_BTN)
	_back_btn.custom_minimum_size = Vector2(200, 52)
	UiFont.apply_label(%Hint, PREP_HINT)
	%Hint.add_theme_color_override("font_color", Color("c8d4c5"))
	UiFont.apply_label(%DiffLabel, 26)
	%DiffLabel.add_theme_color_override("font_color", Color("f4f1ea"))
	%DiffLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	## Fixed-height chrome: use UiFont.px, not px_btn (×2 blows DiffBar/OpenBar).
	_apply_chrome_button_font(_diff_easy, 26)
	_apply_chrome_button_font(_diff_normal, 26)
	_apply_chrome_button_font(_open_main, 26)
	_apply_chrome_button_font(_open_elite, 20)
	_diff_easy.custom_minimum_size = Vector2(0, PrepWidgets.DIFF_H)
	_diff_normal.custom_minimum_size = Vector2(0, PrepWidgets.DIFF_H)
	_open_main.custom_minimum_size = Vector2(0, PrepWidgets.OPEN_MAIN_H)
	_open_elite.custom_minimum_size = Vector2(0, PrepWidgets.OPEN_ELITE_H)
	_open_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_elite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PrepWidgets.paint_open_main(_open_main, false)
	PrepWidgets.paint_open_elite(_open_elite, false)
	_paint_diff()
	UiFont.apply_label(_dlg_title, PREP_TITLE)
	_dlg_title.add_theme_color_override("font_color", Color("f4d35e"))
	UiFont.apply_label(_dlg_body, PREP_INFO)
	_dlg_body.add_theme_color_override("font_color", Color("f4f1ea"))
	UiFont.apply_button(_dlg_yes, PrepWidgets.PREP_BTN)
	UiFont.apply_button(_dlg_no, PrepWidgets.PREP_BTN)
	PrepWidgets.paint_btn(_dlg_yes, true)
	PrepWidgets.paint_btn(_dlg_no, false)
	_refresh_chrome_copy()
	if not Loc.locale_changed.is_connected(_on_locale_changed):
		Loc.locale_changed.connect(_on_locale_changed)


func _show_page(page: String) -> void:
	# The confirm key that opened this page must not also activate the new page.
	_confirm_latch = true
	_close_dialog()
	if page == "stock":
		page = "hub_goods"
	if page != "look":
		_clear_look_preview()
	if page != "lan_join":
		_hide_lan_address_edit()
	if page != "steam_join":
		_hide_steam_lobby_edit()
	_page = page
	_index = 0
	_open_focus = -1
	_msg = ""
	_qty_sku = ""
	_on_size_btns = false
	if page != "layout":
		_clear_hold()
		_cancel_sku_pick(false)
		_cancel_drag()
		_layout_act_held = false
	else:
		_layout_focus = "map"
		_on_size_btns = false
		_cancel_sku_pick(false)
		_layout_act_held = false
		_cursor.x = clampi(_cursor.x, 0, maxi(0, state.grid_w - 1))
		_cursor.y = clampi(_cursor.y, 0, maxi(0, state.grid_h - 1))
	if page == "stats":
		_on_stats_btns = true
		_stat_row = 0
		_stat_side = 1
	else:
		_on_stats_btns = false
	_refresh()


func _refresh_chrome_copy() -> void:
	## Persistent chrome is not rebuilt by page fill — refresh Loc.t after locale change.
	if _back_btn:
		_back_btn.text = Loc.t("prep.chrome.back")
	if %Hint:
		%Hint.text = Loc.t("prep.chrome.hint")
	if _open_main:
		_open_main.text = Loc.t("prep.home.open")
	if _open_elite:
		_open_elite.text = Loc.t("prep.home.elite_test")
	if %DiffLabel:
		%DiffLabel.text = Loc.t("prep.difficulty.label")
	if _diff_easy:
		_diff_easy.text = Loc.t("prep.difficulty.easy")
	if _diff_normal:
		_diff_normal.text = Loc.t("prep.difficulty.normal")
	if _dlg_yes:
		_dlg_yes.text = Loc.t("prep.chrome.dialog_yes")
	if _dlg_no:
		_dlg_no.text = Loc.t("prep.chrome.dialog_no")


func _on_locale_changed(_code: String) -> void:
	if not visible:
		return
	_refresh_chrome_copy()
	_refresh()


func _refresh() -> void:
	_building = true
	_refresh_chrome_copy()
	_rows.clear()
	_list.clear()
	if _hub_panel:
		PrepWidgets.clear(_hub_panel)
	PrepPages.apply_panel_layout(self)
	PrepPages.fill(self, _page)
	if _rows.size() > 0 and _list.visible:
		_index = clampi(_index, 0, _rows.size() - 1)
		var on_btns := (_page == "stats" and _on_stats_btns) or (_page == "layout" and _on_size_btns)
		if on_btns:
			_list.deselect_all()
		else:
			_select_row(_index)
	elif PrepPages.is_hub_page(_page) and _rows.size() > 0:
		_index = clampi(_index, 0, _rows.size() - 1)
		_paint_hub_selection()
	_building = false
	if _page == "look":
		_refresh_look_preview_from_index()
	_grid.queue_redraw()


func _pair(top: String, bottom: String) -> String:
	if bottom == "":
		return top
	return top + "\n" + bottom


func _header() -> String:
	var nxt := state.xp_to_next()
	var xp_txt := Loc.t("prep.msg.max_lv") if nxt <= 0 else "XP %d/%d" % [state.xp, nxt]
	var shop_r := int(state.shop_rating) if state != null and "shop_rating" in state else 0
	var support_r := int(state.support_rating) if state != null and "support_rating" in state else 0
	return Loc.t("prep.header", [
		state.money, state.level, xp_txt,
		state.str_stat, state.agi_stat, state.int_stat, state.unspent, shop_r, support_r,
	])


func _home_info() -> String:
	if state.level_note != "":
		return state.level_note
	var shop_r := int(state.shop_rating) if state != null and "shop_rating" in state else 0
	var support_r := int(state.support_rating) if state != null and "support_rating" in state else 0
	var hist_n := 0
	if state != null and state.get("rating_history") is Array:
		hist_n = (state.rating_history as Array).size()
	return Loc.t("prep.home.info_rating", [shop_r, support_r, hist_n])


func _add(label: String, action: String, arg = null) -> void:
	_rows.append({"label": label, "action": action, "arg": arg, "icon": "", "locked": false, "tag": ""})
	if _list.visible:
		_list.add_item(label, PrepWidgets.list_row_spacer())


func _add_hub(label: String, action: String, arg = null, icon: String = "", locked: bool = false, tag: String = "") -> void:
	_rows.append({
		"label": label,
		"action": action,
		"arg": arg,
		"icon": icon,
		"locked": locked,
		"tag": tag,
	})


func _rebuild_hub_tiles() -> void:
	if _hub_panel == null:
		return
	PrepWidgets.clear(_hub_panel)
	_hub_panel.columns = maxi(1, _hub_cols)
	_hub_panel.clip_contents = true
	var as_rows := _hub_cols <= 1
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var locked := bool(row.get("locked", false))
		var on := i == _index and _open_focus < 0
		var cb := _on_hub_pressed.bind(i)
		var btn: Button
		if as_rows:
			btn = PrepWidgets.hub_row(
				String(row["label"]),
				String(row.get("icon", "")),
				on,
				locked,
				String(row.get("tag", "")),
				cb,
			)
		else:
			btn = PrepWidgets.hub_tile(
				String(row["label"]),
				String(row.get("icon", "")),
				on,
				locked,
				cb,
			)
		_hub_panel.add_child(btn)
	_layout_hub_chrome()


func _setup_open_bar() -> void:
	if _open_bar == null:
		return
	_refresh_chrome_copy()
	_open_elite.visible = ProductVersion.test_tools_enabled()
	_sync_diff_from_demo()
	_open_main.custom_minimum_size = Vector2(0, PrepWidgets.OPEN_MAIN_H)
	_open_elite.custom_minimum_size = Vector2(0, PrepWidgets.OPEN_ELITE_H)
	## Keep open bar from eating vertical space above the tiles.
	_open_main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_open_elite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paint_open_selection()
	_layout_hub_chrome()


func _apply_chrome_button_font(btn: Button, size: int) -> void:
	UiFont.apply_button(btn, size)
	btn.add_theme_font_size_override("font_size", UiFont.px(size))


func _layout_hub_chrome() -> void:
	## Pack hub to content height; stack diff + open below (no overlap).
	if _hub_panel == null:
		return
	var top := 156.0
	var gap := 10.0
	var cols := maxi(1, _hub_cols)
	var n := maxi(1, _rows.size())
	var row_n := int(ceil(float(n) / float(cols)))
	var cell_h := PrepWidgets.HUB_ROW_H if cols <= 1 else PrepWidgets.HUB_TILE_H
	if _hub_panel.get_child_count() > 0:
		var c0 := _hub_panel.get_child(0) as Control
		if c0 != null:
			cell_h = maxf(cell_h, c0.get_combined_minimum_size().y)
	var hub_h := float(row_n) * cell_h + float(maxi(0, row_n - 1)) * gap
	## Undersizing a free GridContainer below its minimum balloons the panel.
	hub_h = maxf(hub_h, _hub_panel.get_combined_minimum_size().y)
	_hub_panel.position = Vector2(24, top)
	_hub_panel.size = Vector2(1232, hub_h)
	_hub_panel.add_theme_constant_override("h_separation", int(gap))
	_hub_panel.add_theme_constant_override("v_separation", int(gap))
	if _open_bar == null:
		return
	if _page != "home":
		return
	var y := top + hub_h + 12.0
	var open_h := PrepWidgets.OPEN_MAIN_H
	if _diff_bar != null and _diff_bar.visible:
		var diff_h := PrepWidgets.DIFF_H
		var preferred_open := 600.0 - open_h
		var diff_top := preferred_open - 10.0 - diff_h
		if diff_top < y:
			diff_top = y
		_diff_bar.position = Vector2(24, diff_top)
		_diff_bar.size = Vector2(1232, diff_h)
		_diff_bar.clip_contents = true
		y = diff_top + diff_h + 10.0
	var preferred := 600.0 - open_h
	var open_top := preferred if preferred > y else y
	_open_bar.position = Vector2(24, open_top)
	_open_bar.size = Vector2(1232, open_h)
	_open_bar.clip_contents = true


func _paint_hub_selection() -> void:
	if _hub_panel == null:
		return
	var as_rows := _hub_cols <= 1
	for i in _hub_panel.get_child_count():
		var btn := _hub_panel.get_child(i) as Button
		if btn == null or i >= _rows.size():
			continue
		var row: Dictionary = _rows[i]
		var locked := bool(row.get("locked", false))
		var on := i == _index and _open_focus < 0
		PrepWidgets.paint_hub_surface(btn, on, locked, as_rows)
	_paint_open_selection()


func _paint_open_selection() -> void:
	if _open_main == null:
		return
	PrepWidgets.paint_open_main(_open_main, _page == "home" and _open_focus == 0)
	PrepWidgets.paint_open_elite(_open_elite, _page == "home" and _open_focus == 1)
	_paint_diff()


func _on_hub_pressed(i: int) -> void:
	if _dlg_open or _swallow_click or _confirm_latch or _building:
		return
	if i < 0 or i >= _rows.size():
		return
	if bool(_rows[i].get("locked", false)):
		_activate_locked_row(_rows[i])
		return
	_index = i
	_open_focus = -1
	_activate()


func _on_open_main_pressed() -> void:
	if _dlg_open or _swallow_click or _confirm_latch or _building:
		return
	_open_focus = 0
	_paint_open_selection()
	_index = 0
	## Synthesize try_open without needing a hub row.
	if demo != null and demo.has_method("clear_elite_test"):
		demo.call("clear_elite_test")
	var blocks := state.open_blockers()
	if blocks.is_empty():
		_show_page("confirm")
	else:
		_popup_info(Loc.t("prep.msg.cant_open"), "\n".join(blocks))


func _diff_on() -> bool:
	return _diff_bar != null and _diff_bar.visible and _page == "home"


func _sync_diff_from_demo() -> void:
	var easy := false
	if demo != null and demo.has_method("play_is_easy"):
		easy = bool(demo.call("play_is_easy"))
	_diff_cursor = 0 if easy else 1
	_paint_diff()


func _choose_difficulty(easy: bool) -> void:
	if demo != null and demo.has_method("set_play_difficulty"):
		demo.call("set_play_difficulty", "easy" if easy else "normal")
	_diff_cursor = 0 if easy else 1
	_paint_diff()


func _paint_diff() -> void:
	if _diff_easy == null or _diff_normal == null:
		return
	var focus := _page == "home" and _open_focus == 10
	PrepWidgets.paint_choice(_diff_easy, _diff_cursor == 0, focus and _diff_cursor == 0)
	PrepWidgets.paint_choice(_diff_normal, _diff_cursor == 1, focus and _diff_cursor == 1)


func _on_diff_easy_pressed() -> void:
	if _dlg_open or _swallow_click or _confirm_latch or _building:
		return
	if not ProductVersion.test_tools_enabled():
		return
	_open_focus = 10
	_choose_difficulty(true)
	SfxBus.play("sfx_ui_confirm")


func _on_diff_normal_pressed() -> void:
	if _dlg_open or _swallow_click or _confirm_latch or _building:
		return
	if not ProductVersion.test_tools_enabled():
		return
	_open_focus = 10
	_choose_difficulty(false)
	SfxBus.play("sfx_ui_confirm")


func _on_open_elite_pressed() -> void:
	if _dlg_open or _swallow_click or _confirm_latch or _building:
		return
	if not ProductVersion.test_tools_enabled():
		return
	_open_focus = 1
	_paint_open_selection()
	_show_page("elite_test")


func _activate_locked_row(row: Dictionary) -> void:
	var action := String(row.get("action", ""))
	if action == "locked_look":
		_popup_info(Loc.t("prep.locked_title"), Loc.t("prep.look.locked_body"))


func _on_stat_pressed(stat: String, delta: int, row: int) -> void:
	if _dlg_open or _swallow_click or _confirm_latch or _building:
		return
	_on_stats_btns = true
	_stat_row = row
	_stat_side = delta
	_msg = state.spend_point(stat, delta)
	_refresh()


func _on_stat_reset() -> void:
	if _dlg_open or _swallow_click:
		return
	_stat_row = 3
	var fee := state.reset_stats_cost()
	var err := state.reset_stats()
	if err != "":
		_popup_info(Loc.t("prep.msg.cant_reset"), err)
		return
	_msg = Loc.t("prep.msg.reset_ok", [fee])
	_refresh()


func _on_stat_back() -> void:
	if _dlg_open or _swallow_click:
		return
	_show_page("hub_char")


func _on_qty_pressed(focus_i: int) -> void:
	if _dlg_open:
		return
	_qty_focus = focus_i
	_qty_apply(focus_i)


func _qty_apply(focus_i: int) -> void:
	match focus_i:
		0:
			_qty_boxes = maxi(1, _qty_boxes - 10)
		1:
			_qty_boxes = maxi(1, _qty_boxes - 1)
		2:
			_qty_boxes = mini(99, _qty_boxes + 1)
		3:
			_qty_boxes = mini(99, _qty_boxes + 10)
		4:
			_refresh()
			_ask_buy()
			return
		5:
			_qty_sku = ""
	_refresh()


func _on_size_pressed(axis: String, delta: int, row: int) -> void:
	if _dlg_open:
		return
	_on_size_btns = true
	_size_row = row
	_size_side = delta
	_nudge_grid(axis, delta)


func _nudge_grid(axis: String, delta: int) -> void:
	var w := state.grid_w
	var h := state.grid_h
	var cur := w if axis == "w" else h
	var label := Loc.t("prep.layout.width") if axis == "w" else Loc.t("prep.layout.height")
	var nxt := cur + delta
	if nxt < 8:
		_popup_info(Loc.t("prep.msg.cant_adjust"), Loc.t("prep.msg.dim_min", [label]))
		_refresh()
		return
	if axis == "w":
		w = nxt
	else:
		h = nxt
	if w * h > state.area_cap():
		_popup_info(Loc.t("prep.msg.cant_adjust"), Loc.t("prep.msg.area_over", [label, w * h, state.shop_scale, state.area_cap()]))
		_refresh()
		return
	var msg := state.set_grid(w, h)
	if msg != "":
		_popup_info(Loc.t("prep.msg.cant_adjust"), Loc.t("prep.msg.furniture_oob"))
	else:
		_msg = ""
	_refresh()


func _select_row(index: int) -> void:
	_suppress_select = true
	_list.select(index)
	_list.ensure_current_is_visible()
	_suppress_select = false


func _on_click(index: int) -> void:
	if _dlg_open or _swallow_click or _suppress_select or _list_dragging:
		return
	_index = index
	_on_size_btns = false
	if _page == "look":
		_refresh_look_preview_from_index()
	# Wait until the finger lifts, so a scroll does not also open the row.
	_click_arm = index


func _on_back_button() -> void:
	if _dlg_open:
		return
	_back()


func _try_back_click(event: InputEvent) -> bool:
	if _back_btn == null or not _back_btn.visible or not visible or _dlg_open:
		return false
	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return false
	if not _back_btn.get_global_rect().has_point(mb.position):
		return false
	get_viewport().set_input_as_handled()
	_back()
	return true


func _on_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_list_press = event.position
			_list_dragging = false
		return
	if not (event is InputEventMouseMotion):
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var motion := event as InputEventMouseMotion
	if not _list_dragging and _list_press.distance_to(motion.position) < 18.0:
		return
	_list_dragging = true
	_click_arm = -1
	# A layout drag is placing an item, so the list itself should stay still.
	if _drag_on:
		return
	var scroll := _list.get_v_scroll_bar()
	scroll.value -= motion.relative.y
	_list.accept_event()


func _activate() -> void:
	if _dlg_open:
		_dialog_accept()
		return
	if _confirm_latch:
		return
	if _page != "sfx":
		SfxBus.play("sfx_ui_confirm")
	if _page == "stats":
		if _stat_row <= 2:
			var keys := ["str", "agi", "int"]
			_msg = state.spend_point(keys[_stat_row], _stat_side)
			_refresh()
		elif _stat_row == 3:
			var fee := state.reset_stats_cost()
			var err := state.reset_stats()
			if err != "":
				_popup_info(Loc.t("prep.msg.cant_reset"), err)
			else:
				_msg = Loc.t("prep.msg.reset_ok", [fee])
			_refresh()
		else:
			_show_page("hub_char")
		return
	if _page == "home" and _open_focus == 10:
		_choose_difficulty(_diff_cursor == 0)
		return
	if _page == "home" and _open_focus == 0:
		_on_open_main_pressed()
		return
	if _page == "home" and _open_focus == 1:
		_on_open_elite_pressed()
		return
	if _page == "layout" and (_layout_focus == "map" or _hold_type != ""):
		try_place()
		return
	if _page == "layout" and _on_size_btns:
		_nudge_grid("w" if _size_row == 0 else "h", _size_side)
		return
	if _page == "buy" and _qty_sku != "":
		_qty_apply(_qty_focus)
		return
	if _index < 0 or _index >= _rows.size():
		return
	var row: Dictionary = _rows[_index]
	if bool(row.get("locked", false)):
		_activate_locked_row(row)
		return
	var action := String(row["action"])
	var arg = row["arg"]
	match action:
		"sc":
			state.apply_scenario(int(arg))
			_msg = ""
			_show_page("home")
		"wipe_save":
			state.delete_save()
			_guest_store = null
			_guest_slot_index = -1
			_msg = Loc.t("prep.msg.save_cleared")
			_show_page("scenario")
		"go":
			var dest := String(arg)
			## Leaving confirm／選單回 home 時清掉麻煩客人測試旗標（未按開始則不生效）。
			if dest == "home" and demo != null and demo.has_method("clear_elite_test"):
				demo.call("clear_elite_test")
			_show_page(dest)
		"reset":
			var fee := state.reset_stats_cost()
			var err := state.reset_stats()
			if err != "":
				_popup_info(Loc.t("prep.msg.cant_reset"), err)
			else:
				_msg = Loc.t("prep.msg.reset_ok", [fee])
			_refresh()
		"edit_set":
			_skill_set = int(arg)
			_show_page("skill_set")
		"use_set":
			if int(state.skill_set_index) == _skill_set:
				_popup_info(Loc.t("prep.skills.title"), Loc.t("prep.skill_set.already"))
			else:
				state.select_skill_set(_skill_set)
				_msg = Loc.t("prep.skill_set.selected_msg", [state.skill_set_name(_skill_set)])
				_refresh()
		"rename_open":
			var current := state.skill_set_name(_skill_set)
			_rename_draft = current if state.skill_set_name_is_custom(current) else ""
			_rename_lower = false
			_show_page("skill_rename")
		"rename_ch":
			if _rename_draft.length() >= state.SKILL_NAME_MAX:
				_popup_info(Loc.t("prep.skill_rename.title"), Loc.t("prep.skill_rename.too_long"))
			else:
				_rename_draft += String(arg)
				_refresh()
		"rename_backspace":
			if _rename_draft.length() > 0:
				_rename_draft = _rename_draft.substr(0, _rename_draft.length() - 1)
				_refresh()
		"rename_clear":
			_rename_draft = ""
			_refresh()
		"rename_case":
			_rename_lower = not _rename_lower
			_refresh()
		"rename_save":
			var rename_err := state.rename_skill_set(_skill_set, _rename_draft)
			if rename_err != "":
				_popup_info(Loc.t("prep.skill_rename.title"), rename_err)
			else:
				_show_page("skill_set")
				_msg = Loc.t("prep.skill_rename.saved", [state.skill_set_name(_skill_set)])
				_refresh()
		"pick_slot":
			PrepPages.fill_skill_pick(self, int(arg))
		"equip":
			var equip_msg := state.equip_set(_skill_set, int(arg[0]), String(arg[1]))
			_show_page("skill_set")
			if equip_msg != "":
				_popup_info(Loc.t("prep.msg.cant_equip"), equip_msg)
		"unequip":
			state.unequip_set(_skill_set, int(arg))
			_show_page("skill_set")
		"cycle_skill_lv":
			var skill_id := String(arg)
			var cur := state.skill_level_of(_skill_set, skill_id)
			state.set_skill_level(_skill_set, skill_id, 1 if cur >= 3 else cur + 1)
			_show_page("skill_set")
		"dev":
			_ask_develop(String(arg))
		"locked_sku":
			_popup_info(Loc.t("prep.msg.locked_title"), _locked_sku_body(String(arg)))
		"need_develop":
			_popup_info(Loc.t("prep.locked_title"), Loc.t("prep.buy.need_develop", [Tuning.sku_name(String(arg))]))
		"locked_look":
			_popup_info(Loc.t("prep.locked_title"), Loc.t("prep.look.locked_body"))
		"set_skin":
			_set_host_skin(String(arg))
		"cycle_look_tint":
			_cycle_look_tint()
		"qty":
			_qty_sku = String(arg)
			_qty_boxes = 1
			_qty_focus = 2
			_refresh()
		"buy_f":
			_ask_furniture(String(arg))
		"locked_furn":
			_popup_locked_furn(String(arg))
		"expand":
			_ask_expand()
		"expand_max":
			_popup_info(Loc.t("prep.msg.locked_title"), Loc.t("prep.msg.max_scale_detail"))
		"hold":
			_begin_hold_from_list(String(arg))
		"map_focus":
			_layout_focus = "map"
			_on_size_btns = false
			_msg = ""
			_refresh()
		"hire":
			_try_hire()
		"role":
			state.cycle_role(int(arg))
			_refresh()
		"reg":
			state.cycle_register(int(arg))
			_refresh()
		"fire":
			state.fire(int(arg))
			_refresh()
		"try_open":
			if demo != null and demo.has_method("clear_elite_test"):
				demo.call("clear_elite_test")
			var blocks := state.open_blockers()
			if blocks.is_empty():
				_show_page("confirm")
			else:
				_popup_info(Loc.t("prep.msg.cant_open"), "\n".join(blocks))
		"elite_open":
			_try_elite_open(int(arg))
		"set_seats":
			if OS.has_feature("web"):
				_local_seats = 1
				_guest_slot_index = -1
			else:
				_local_seats = clampi(int(arg), 1, 2)
				if _local_seats < 2:
					_guest_slot_index = -1
				else:
					_ensure_guest_store()
					_auto_pick_guest_slot()
			_refresh()
		"pick_guest_slot":
			_ensure_guest_store()
			_guest_slot_index = clampi(int(arg), 0, 2)
			_refresh()
		"clone_guest_slot":
			_ensure_guest_store()
			var ci := clampi(int(arg), 0, 2)
			_guest_store.clone_host_into(ci, state)
			_guest_store.save_to_disk()
			_guest_slot_index = ci
			_msg = Loc.t("prep.confirm.guest_cloned", [ci + 1])
			_refresh()
		"blank_guest_slot":
			_ensure_guest_store()
			var bi := clampi(int(arg), 0, 2)
			_guest_store.create_blank_at(bi)
			_guest_store.save_to_disk()
			_guest_slot_index = bi
			_msg = Loc.t("prep.confirm.guest_blank", [bi + 1])
			_refresh()
		"cycle_guest_tint":
			_ensure_guest_store()
			if _guest_slot_index < 0 or _guest_store.is_empty(_guest_slot_index):
				_refresh()
				return
			var sheet = _guest_store.get_sheet(_guest_slot_index)
			if sheet == null:
				_refresh()
				return
			sheet.tint = (int(sheet.tint) + 1) % 4
			_guest_store.set_sheet(_guest_slot_index, sheet)
			_guest_store.save_to_disk()
			_refresh()
		"cycle_host_tint":
			## Host tint lives on Look page; keep action as no-op fallback.
			_cycle_look_tint()
		"open":
			var open_msg := state.begin_day()
			if open_msg != "":
				_popup_info(Loc.t("prep.msg.cant_open"), open_msg)
				return
			var save_err := state.save_to_disk()
			if save_err != "":
				push_warning("prep end save failed: %s" % save_err)
			if not _configure_local_seats_for_day():
				return
			visible = false
			set_process_unhandled_input(false)
			start_day.emit()
		"lan_host":
			_start_lan_host()
		"lan_join_do":
			_start_lan_join()
		"lan_addr":
			_lan_address = String(arg)
			_refresh()
		"steam_host":
			_start_steam_host()
		"steam_join_do":
			_start_steam_join()
		"lobby_ready":
			SessionService.set_ready(int(arg), not SeatTable.is_seat_ready(int(arg)))
			_refresh()
		"lobby_start":
			_lobby_start_day()
		"lobby_close":
			SessionService.close()
			_show_page("confirm")
		"test_money":
			_grant_test_money()
		"toggle_virtual_stick":
			_toggle_virtual_stick()
		"set_locale":
			_set_locale(String(arg))
		"play_sfx":
			SfxBus.play(String(arg))
		"noop":
			pass
		_:
			pass


func _toggle_virtual_stick() -> void:
	var on := PlatformServices.toggle_virtual_stick()
	SfxBus.play("sfx_ui_confirm")
	_msg = Loc.t("prep.sys.virtual_stick_on" if on else "prep.sys.virtual_stick_off")
	## Visibility updates via InputMode.show_vj_changed → demo._on_show_vj_changed.
	_refresh()


func _set_locale(code: String) -> void:
	PlatformServices.set_locale(code)
	SfxBus.play("sfx_ui_confirm")
	## Keep page; _show_page would clear _msg. locale_changed also refreshes chrome.
	var lang_name := Loc.t("locale.name.%s" % Loc.get_locale())
	_msg = Loc.t("prep.locale.changed", [lang_name])
	_refresh_chrome_copy()
	_refresh()


func _grant_test_money() -> void:
	const ProductVersion = preload("res://scripts/product_version.gd")
	if not ProductVersion.test_tools_enabled():
		return
	state.money += 1000
	_msg = Loc.t("prep.home.test_money_ok", [state.money])
	_refresh()


func _ensure_guest_store() -> void:
	if _guest_store != null:
		return
	var GuestSlots = load("res://scripts/session/guest_slots.gd")
	_guest_store = GuestSlots.create()


func _auto_pick_guest_slot() -> void:
	_ensure_guest_store()
	if _guest_slot_index >= 0 and not _guest_store.is_empty(_guest_slot_index):
		return
	for i in 3:
		if not _guest_store.is_empty(i):
			_guest_slot_index = i
			return
	_guest_slot_index = -1


func _configure_local_seats_for_day() -> bool:
	## Web: always solo. Desktop: 1｜2; seat1 loads selected guest slot.
	var seats := 1 if OS.has_feature("web") else clampi(_local_seats, 1, 2)
	if seats < 2:
		SessionService.create_room(1)
		return true
	_ensure_guest_store()
	if _guest_slot_index < 0 or _guest_store.is_empty(_guest_slot_index):
		## Prefer first empty for clone; else require UI pick.
		var empty_i := -1
		for i in 3:
			if _guest_store.is_empty(i):
				empty_i = i
				break
		if empty_i < 0:
			_popup_info(Loc.t("prep.confirm.guest_need_title"), Loc.t("prep.confirm.guest_need_body"))
			return false
		_guest_store.clone_host_into(empty_i, state)
		_guest_store.save_to_disk()
		_guest_slot_index = empty_i
	var guest = _guest_store.get_sheet(_guest_slot_index)
	if guest == null:
		_popup_info(Loc.t("prep.confirm.guest_need_title"), Loc.t("prep.confirm.guest_need_body"))
		return false
	SessionService.create_room(2, guest, _guest_slot_index)
	return true


func _resolve_local_guest_for_lan():
	## Same guest resolution as local open; returns [ok, guest_or_null, slot_index].
	var seats := 1 if OS.has_feature("web") else clampi(_local_seats, 1, 2)
	if seats < 2:
		return [true, null, -1]
	_ensure_guest_store()
	if _guest_slot_index < 0 or _guest_store.is_empty(_guest_slot_index):
		var empty_i := -1
		for i in 3:
			if _guest_store.is_empty(i):
				empty_i = i
				break
		if empty_i < 0:
			return [false, null, -1]
		_guest_store.clone_host_into(empty_i, state)
		_guest_store.save_to_disk()
		_guest_slot_index = empty_i
	var guest = _guest_store.get_sheet(_guest_slot_index)
	if guest == null:
		return [false, null, -1]
	return [true, guest, _guest_slot_index]


func _start_lan_host() -> void:
	if not SessionService.lan_available():
		_popup_info(Loc.t("lobby.error_title"), Loc.t("lobby.error_body", ["web_no_enet"]))
		return
	var resolved = _resolve_local_guest_for_lan()
	if not bool(resolved[0]):
		_popup_info(Loc.t("prep.confirm.guest_need_title"), Loc.t("prep.confirm.guest_need_body"))
		return
	var seats := 1 if OS.has_feature("web") else clampi(_local_seats, 1, 2)
	var err := SessionService.host_lan(seats, resolved[1], int(resolved[2]))
	if err != "":
		_popup_info(Loc.t("lobby.error_title"), Loc.t("lobby.error_body", [err]))
		return
	_show_page("lobby")


func _start_lan_join() -> void:
	if _lan_addr_edit != null:
		_lan_address = _lan_addr_edit.text.strip_edges()
	if _lan_address.is_empty():
		_lan_address = "127.0.0.1"
	## Reuse confirm-page 1｜2 + guest pick as join claim_seats (M2 second slice).
	var claim := 1 if OS.has_feature("web") else clampi(_local_seats, 1, 2)
	var guest = null
	var guest_slot := -1
	if claim >= 2:
		var resolved = _resolve_local_guest_for_lan()
		if not bool(resolved[0]):
			_popup_info(Loc.t("prep.confirm.guest_need_title"), Loc.t("prep.confirm.guest_need_body"))
			return
		guest = resolved[1]
		guest_slot = int(resolved[2])
	var err := SessionService.join_room(claim, _lan_address, SessionService.lan_port, guest, guest_slot)
	if err != "":
		_popup_info(Loc.t("lobby.error_title"), Loc.t("lobby.error_body", [err]))
		return
	_hide_lan_address_edit()
	_show_page("lobby")


func _lobby_err_text(code: String) -> String:
	var key := "lobby.err.%s" % code
	if Loc.has_key(key):
		return Loc.t(key)
	if code.begins_with("steam_init_"):
		return Loc.t("lobby.err.steam_init_failed")
	return Loc.t("lobby.error_body", [code])


func _start_steam_host() -> void:
	if OS.has_feature("web"):
		_popup_info(Loc.t("lobby.error_title"), _lobby_err_text("web_no_steam"))
		return
	var resolved = _resolve_local_guest_for_lan()
	if not bool(resolved[0]):
		_popup_info(Loc.t("prep.confirm.guest_need_title"), Loc.t("prep.confirm.guest_need_body"))
		return
	var seats := clampi(_local_seats, 1, 2)
	var err: String = await SessionService.host_steam(seats, resolved[1], int(resolved[2]))
	if err != "":
		_popup_info(Loc.t("lobby.error_title"), _lobby_err_text(err))
		return
	_show_page("lobby")


func _start_steam_join() -> void:
	if _steam_lobby_edit != null:
		_steam_lobby_draft = _steam_lobby_edit.text.strip_edges()
	var lobby_id := int(_steam_lobby_draft) if _steam_lobby_draft.is_valid_int() else 0
	var claim := 1 if OS.has_feature("web") else clampi(_local_seats, 1, 2)
	var guest = null
	var guest_slot := -1
	if claim >= 2:
		var resolved = _resolve_local_guest_for_lan()
		if not bool(resolved[0]):
			_popup_info(Loc.t("prep.confirm.guest_need_title"), Loc.t("prep.confirm.guest_need_body"))
			return
		guest = resolved[1]
		guest_slot = int(resolved[2])
	var err: String = await SessionService.join_steam_lobby(lobby_id, claim, guest, guest_slot)
	if err != "":
		_popup_info(Loc.t("lobby.error_title"), _lobby_err_text(err))
		return
	_hide_steam_lobby_edit()
	_show_page("lobby")


func _lobby_start_day() -> void:
	if not SessionService.is_server():
		return
	if not SessionService.all_ready():
		return
	var open_msg := state.begin_day()
	if open_msg != "":
		_popup_info(Loc.t("prep.msg.cant_open"), open_msg)
		return
	var save_err := state.save_to_disk()
	if save_err != "":
		push_warning("prep end save failed: %s" % save_err)
	var snap := {
		"world": state.to_dict(),
		"seed": int(Time.get_ticks_msec()),
	}
	visible = false
	set_process_unhandled_input(false)
	SessionService.start_run(snap)
	## start_run emits SessionService.start_day → _on_session_start_day may no-op (hidden);
	## still emit prep signal for demo if demo listens to prep only.
	start_day.emit()


func _try_elite_open(lv: int) -> void:
	const ProductVersion = preload("res://scripts/product_version.gd")
	if not ProductVersion.test_tools_enabled():
		return
	var blocks := state.open_blockers()
	if not blocks.is_empty():
		_popup_info(Loc.t("prep.msg.cant_open"), "\n".join(blocks))
		return
	if demo != null and demo.has_method("configure_elite_test"):
		demo.call("configure_elite_test", lv)
	_show_page("confirm")


func _locked_sku_body(sku: String) -> String:
	return Loc.t("prep.msg.locked_sku", [Tuning.sku_name(sku), int(Tuning.SKU_UNLOCK_LV.get(sku, 99)), state.level])


func _popup_locked_furn(type: String) -> void:
	var spec: Dictionary = state.FURNITURE[type]
	_popup_info(Loc.t("prep.msg.locked_title"), Loc.t("prep.msg.locked_furn", [state.furniture_name(type), int(spec["unlock"]), state.level]))


func _funds_line(what: String, price: int) -> String:
	return Loc.t("prep.msg.need_funds", [what, price, state.money])


func _ask_develop(sku: String) -> void:
	var name := Tuning.sku_name(sku)
	if not state.sku_unlocked(sku):
		_popup_info(Loc.t("prep.msg.locked_title"), _locked_sku_body(sku))
		return
	if state.developed.has(sku):
		_popup_info(Loc.t("prep.msg.cant_develop"), Loc.t("prep.msg.already_dev_buy", [name]))
		return
	var fee := int(Tuning.SKU_DEVELOP.get(sku, 0))
	if state.money < fee:
		_popup_info(Loc.t("err.funds"), _funds_line(Loc.t("prep.msg.develop_what", [name]), fee))
		return
	_popup_confirm(Loc.t("prep.msg.confirm_title"), Loc.t("prep.msg.develop_ask", [name, fee]), {"action": "dev", "sku": sku})


func _ask_buy() -> void:
	var name := Tuning.sku_name(_qty_sku)
	var pieces := _qty_boxes
	if not state.developed.has(_qty_sku):
		_popup_info(Loc.t("prep.msg.locked_title"), Loc.t("prep.msg.need_dev_buy", [name]))
		return
	var cost := Tuning.cost_for_pieces(_qty_sku, pieces)
	if state.money < cost:
		_popup_info(Loc.t("err.funds"), _funds_line(Loc.t("prep.msg.buy_what", [name, pieces]), cost))
		return
	_popup_confirm(Loc.t("prep.msg.confirm_title"), Loc.t("prep.msg.buy_ask", [name, pieces, cost]), {"action": "buy", "sku": _qty_sku, "boxes": pieces})


func _ask_furniture(type: String) -> void:
	var spec: Dictionary = state.FURNITURE[type]
	var name := state.furniture_name(type)
	if not state.furniture_unlocked(type):
		_popup_locked_furn(type)
		return
	var price := int(spec["price"])
	if state.money < price:
		_popup_info(Loc.t("err.funds"), _funds_line(Loc.t("prep.msg.furn_what", [name]), price))
		return
	_popup_confirm(Loc.t("prep.msg.confirm_title"), Loc.t("prep.msg.furn_ask", [name, price]), {"action": "furn", "type": type})


func _ask_expand() -> void:
	if state.shop_scale >= 3:
		_popup_info(Loc.t("prep.msg.locked_title"), Loc.t("prep.msg.max_scale_detail"))
		return
	var nxt := state.shop_scale + 1
	var need := int(state.SCALE_NEED_LV[nxt])
	if state.level < need:
		_popup_info(Loc.t("prep.msg.locked_title"), Loc.t("prep.msg.expand_locked", [nxt, need, state.level]))
		return
	var price := int(state.SCALE_COST[nxt])
	if state.money < price:
		_popup_info(Loc.t("err.funds"), _funds_line(Loc.t("prep.msg.expand_what", [nxt]), price))
		return
	var cap := int(state.SCALE_MAX[nxt])
	_popup_confirm(Loc.t("prep.msg.confirm_title"), Loc.t("prep.msg.expand_ask", [nxt, cap * cap, cap, cap, price]), {"action": "expand"})


func _try_hire() -> void:
	var before := state.clerks.size()
	var msg := state.hire()
	if msg == "" and state.clerks.size() > before:
		SfxBus.play("sfx_ui_purchase")
		_msg = Loc.t("prep.msg.hired")
		_refresh()
		return
	if msg == Loc.t("err.hire_full"):
		var cap := int(state.HIRE_CAP.get(state.shop_scale, 0))
		var body := Loc.t("prep.msg.hire_cap", [state.shop_scale, cap])
		if state.shop_scale < 3:
			body += Loc.t("prep.msg.hire_expand_hint")
		_popup_info(Loc.t("prep.msg.locked_title"), body)
	elif msg == Loc.t("err.clerks_gt_registers"):
		_popup_info(Loc.t("prep.msg.cant_hire"), Loc.t("prep.msg.hire_need_register"))
	else:
		_popup_info(Loc.t("prep.msg.cant_hire"), msg if msg != "" else Loc.t("prep.msg.hire_now"))


func _run_pending(pending: Dictionary) -> void:
	match String(pending.get("action", "")):
		"dev":
			var sku := String(pending["sku"])
			var msg := state.develop(sku)
			if msg != "":
				_popup_info(Loc.t("prep.msg.cant_develop"), msg)
			else:
				SfxBus.play("sfx_ui_purchase")
				_msg = Loc.t("prep.msg.developed", [Tuning.sku_name(sku)])
				_refresh()
		"buy":
			var sku2 := String(pending["sku"])
			var boxes := int(pending["boxes"])
			var msg2 := state.buy_stock(sku2, boxes)
			if msg2 != "":
				_popup_info(Loc.t("prep.msg.cant_buy"), msg2)
			else:
				SfxBus.play("sfx_ui_purchase")
				_qty_sku = ""
				_msg = Loc.t("prep.msg.bought_sku", [Tuning.sku_name(sku2), boxes])
				_refresh()
		"furn":
			var type := String(pending["type"])
			var msg3 := state.buy_furniture(type)
			if msg3 != "":
				_popup_info(Loc.t("prep.msg.cant_buy_furn"), msg3)
			else:
				SfxBus.play("sfx_ui_purchase")
				_msg = Loc.t("prep.msg.bought_furn", [state.furniture_name(type)])
				_refresh()
		"expand":
			var msg4 := state.expand()
			if msg4 != "":
				_popup_info(Loc.t("prep.msg.cant_expand"), msg4)
			else:
				SfxBus.play("sfx_ui_purchase")
				_msg = Loc.t("prep.msg.expanded", [state.shop_scale])
				_refresh()
		"difficulty":
			_apply_difficulty_prompt(pending, true)


func _popup_info(title: String, body: String) -> void:
	SfxBus.play("sfx_ui_deny")
	_open_dialog(title, body, true, {})


func _popup_confirm(title: String, body: String, pending: Dictionary) -> void:
	_open_dialog(title, body, false, pending)


## After closeout → home: suggest difficulty change on 3-day grade streak.
func maybe_offer_difficulty_prompt() -> void:
	if state == null or _dlg_open:
		return
	var sug := RatingRules.difficulty_suggestion(state.rating_history)
	if sug == "":
		return
	var key := RatingRules.streak_key(state.rating_history)
	if key == "" or key == String(state.difficulty_prompt_acked):
		return
	var toward_harder := sug == "up"
	var cur := RatingRules.normalize_difficulty(state.difficulty)
	var nxt := RatingRules.nudge_difficulty(cur, toward_harder)
	if nxt == cur:
		## Already at bound — ack so we do not re-prompt the same streak.
		state.difficulty_prompt_acked = key
		state.save_to_disk()
		return
	var body_key := "rating.diff.body_up" if toward_harder else "rating.diff.body_down"
	var body := Loc.t(body_key, [_diff_label(cur), _diff_label(nxt)])
	_popup_confirm(Loc.t("rating.diff.title"), body, {
		"action": "difficulty",
		"toward_harder": toward_harder,
		"streak_key": key,
		"next": nxt,
	})
	_dlg_yes.text = Loc.t("rating.diff.accept")
	_dlg_no.text = Loc.t("rating.diff.dismiss")
	_paint_dialog()


func _diff_label(id: String) -> String:
	match RatingRules.normalize_difficulty(id):
		RatingRules.DIFF_EASY:
			return Loc.t("rating.diff.name.easy")
		RatingRules.DIFF_HARD:
			return Loc.t("rating.diff.name.hard")
		_:
			return Loc.t("rating.diff.name.normal")


func _apply_difficulty_prompt(pending: Dictionary, accepted: bool) -> void:
	if state == null:
		return
	var key := String(pending.get("streak_key", ""))
	if key != "":
		state.difficulty_prompt_acked = key
	if accepted:
		var nxt := String(pending.get("next", ""))
		if nxt == "":
			nxt = RatingRules.nudge_difficulty(
				state.difficulty, bool(pending.get("toward_harder", false))
			)
		state.difficulty = RatingRules.normalize_difficulty(nxt)
		_msg = Loc.t("rating.diff.title") + " → " + _diff_label(state.difficulty)
	state.save_to_disk()
	_refresh()


func _open_dialog(title: String, body: String, info: bool, pending: Dictionary) -> void:
	_dlg_info = info
	_dlg_focus = 0
	_dlg_gate = 1
	_dlg_wait = 0
	_pending = pending
	_dlg_title.text = title
	_dlg_body.text = body
	_dlg_yes.text = Loc.t("prep.msg.ok") if info else Loc.t("prep.msg.confirm_btn")
	_dlg_no.visible = not info
	if info:
		_dlg_yes.position = Vector2(310, 280)
	else:
		_dlg_yes.position = Vector2(140, 280)
		_dlg_no.position = Vector2(480, 280)
	_paint_dialog()
	_dlg_open = true
	_shade.visible = true
	_box.visible = true
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.mouse_filter = Control.MOUSE_FILTER_STOP


func _paint_dialog() -> void:
	PrepWidgets.paint_btn(_dlg_yes, _dlg_info or _dlg_focus == 0)
	PrepWidgets.paint_btn(_dlg_no, not _dlg_info and _dlg_focus == 1)


func _close_dialog() -> void:
	_dlg_open = false
	_dlg_gate = 0
	_dlg_wait = 0
	_pending = {}
	if _shade:
		_shade.visible = false
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _box:
		_box.visible = false
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_dlg_yes() -> void:
	if _dlg_gate != 2:
		return
	if _dlg_info:
		_close_dialog()
		return
	var pending := _pending.duplicate()
	_close_dialog()
	_run_pending(pending)


func _on_dlg_no() -> void:
	if _dlg_gate != 2:
		return
	var pending := _pending.duplicate()
	_close_dialog()
	if String(pending.get("action", "")) == "difficulty":
		_apply_difficulty_prompt(pending, false)


func _dialog_accept() -> void:
	if _dlg_gate != 2:
		return
	if _dlg_info or _dlg_focus == 0:
		_on_dlg_yes()
	else:
		_on_dlg_no()


func _dialog_move(x: int, _y: int) -> void:
	if _dlg_gate != 2 or _dlg_info:
		return
	if x < 0:
		_dlg_focus = 0
	elif x > 0:
		_dlg_focus = 1
	_paint_dialog()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_echo():
		return
	if _dlg_open:
		if _dlg_gate == 2 and event.is_pressed() and not (event is InputEventJoypadMotion):
			_dialog_action(event)
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed() or event is InputEventJoypadMotion:
		return
	if event.is_action_pressed(Controls.MOVE_UP):
		_move(0, -1)
	elif event.is_action_pressed(Controls.MOVE_DOWN):
		_move(0, 1)
	elif event.is_action_pressed(Controls.MOVE_LEFT):
		_move(-1, 0)
	elif event.is_action_pressed(Controls.MOVE_RIGHT):
		_move(1, 0)
	elif event.is_action_pressed(Controls.INTERACT):
		if _sku_pick_i >= 0:
			_commit_sku_pick()
		elif _page == "layout" and _layout_focus == "map" and _hold_type == "":
			## Defer short/long until release / hold threshold (restock default SKU).
			_layout_act_held = true
			_layout_act_time = 0.0
			_layout_act_long = false
		else:
			_activate()
	elif event.is_action_pressed(Controls.CANCEL):
		## Map-lifted hold: defer short/long — short restores, long recalls to stock.
		if _page == "layout" and _hold_type != "" and _hold_from_map:
			_layout_cancel_held = true
			_layout_cancel_time = 0.0
			_layout_cancel_long = false
		else:
			_back()
	elif event.is_action_pressed(Controls.ROTATE):
		if _sku_pick_i < 0:
			_rotate()
	else:
		return
	get_viewport().set_input_as_handled()


func _dialog_action(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.MOVE_LEFT):
		_dialog_move(-1, 0)
	elif event.is_action_pressed(Controls.MOVE_RIGHT):
		_dialog_move(1, 0)
	elif event.is_action_pressed(Controls.INTERACT):
		_dialog_accept()
	elif event.is_action_pressed(Controls.CANCEL):
		if _dlg_info:
			_close_dialog()
		else:
			_on_dlg_no()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _layout_act_held and _page == "layout":
		if Input.is_action_pressed(Controls.INTERACT):
			_layout_act_time += _delta
			if not _layout_act_long and _layout_act_time >= Tuning.SKU_PICK_HOLD:
				if _try_begin_restock_sku_pick():
					_layout_act_long = true
		else:
			if not _layout_act_long:
				_activate()
			_layout_act_held = false
			_layout_act_time = 0.0
			_layout_act_long = false
	if _layout_cancel_held and _page == "layout":
		if _hold_type == "" or not _hold_from_map:
			_layout_cancel_held = false
			_layout_cancel_time = 0.0
			_layout_cancel_long = false
		elif Input.is_action_pressed(Controls.CANCEL):
			_layout_cancel_time += _delta
			if not _layout_cancel_long and _layout_cancel_time >= Tuning.SKU_PICK_HOLD:
				_layout_cancel_long = true
				_discard_hold()
		else:
			if not _layout_cancel_long:
				_back()
			_layout_cancel_held = false
			_layout_cancel_time = 0.0
			_layout_cancel_long = false
	if _swallow_click and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_swallow_click = false
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _click_arm >= 0:
			var armed := _click_arm
			_click_arm = -1
			if not _list_dragging:
				_swallow_click = true
				_index = armed
				_on_size_btns = false
				_activate()
		_list_dragging = false
	if _confirm_latch:
		_confirm_latch = false
	if _dlg_open:
		if _dlg_gate == 1:
			_dlg_wait += 1
			var mouse_up := not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			if (mouse_up and _dlg_wait > 1) or _dlg_wait > 20:
				_dlg_gate = 2
		if _dlg_gate != 2:
			return
		var stick := Controls.stick_vector()
		if stick.length() < 0.55:
			_stick_armed = true
			return
		if not _stick_armed:
			return
		_stick_armed = false
		if absf(stick.x) > absf(stick.y):
			_dialog_move(1 if stick.x > 0 else -1, 0)
		return
	## Stick only — WASD / arrows / d-pad already handled in `_unhandled_input`.
	## Using `move_vector()` here double-steps on Web (key event + same-frame poll).
	var v := Controls.stick_vector()
	if v.length() < _STICK_DEAD:
		_stick_armed = true
		_stick_hold = 0.0
		_stick_repeats = 0
		return
	var dx := 0
	var dy := 0
	if absf(v.x) > absf(v.y):
		dx = 1 if v.x > 0.0 else -1
	else:
		dy = 1 if v.y > 0.0 else -1
	## Layout map: hold stick to keep stepping. Other pages: one step then recenter.
	var map_hold := (
		_page == "layout"
		and _sku_pick_i < 0
		and (_layout_focus == "map" or _hold_type != "")
	)
	if map_hold:
		if _stick_armed:
			_stick_armed = false
			_stick_hold = 0.0
			_stick_repeats = 0
			_move(dx, dy)
			return
		_stick_hold += _delta
		var need := _STICK_REPEAT_FIRST if _stick_repeats == 0 else _STICK_REPEAT
		if _stick_hold >= need:
			_stick_hold = 0.0
			_stick_repeats += 1
			_move(dx, dy)
		return
	if not _stick_armed:
		return
	_stick_armed = false
	_move(dx, dy)


var _stick_armed: bool = true
var _stick_hold: float = 0.0
var _stick_repeats: int = 0
const _STICK_DEAD := 0.55
const _STICK_REPEAT_FIRST := 0.22
const _STICK_REPEAT := 0.07


func _move(x: int, y: int) -> void:
	if _dlg_open:
		_dialog_move(x, y)
		return
	if _sku_pick_i >= 0:
		_nudge_sku_pick(y if y != 0 else x)
		return
	if _page == "layout" and (_layout_focus == "map" or _hold_type != ""):
		_cursor.x = clampi(_cursor.x + x, 0, state.grid_w - 1)
		_cursor.y = clampi(_cursor.y + y, 0, state.grid_h - 1)
		_grid.queue_redraw()
		return
	if _page == "stats":
		_move_stats(x, y)
		return
	if _page == "layout":
		_move_layout(x, y)
		return
	if _qty_sku != "" and _page == "buy":
		_move_qty(x, y)
		return
	if PrepPages.is_hub_page(_page):
		_move_hub(x, y)
		return
	if _rows.is_empty():
		return
	if y < 0 or x < 0:
		_index = posmod(_index - 1, _rows.size())
		SfxBus.play("sfx_ui_move")
	elif y > 0 or x > 0:
		_index = posmod(_index + 1, _rows.size())
		SfxBus.play("sfx_ui_move")
	_select_row(_index)
	if _page == "look":
		_refresh_look_preview_from_index()


func _move_hub(x: int, y: int) -> void:
	if _rows.is_empty() and _page != "home":
		return
	if _page == "home" and _open_focus == 10:
		if y < 0:
			_open_focus = -1
			SfxBus.play("sfx_ui_move")
			_paint_hub_selection()
			return
		if y > 0:
			_open_focus = 0
			SfxBus.play("sfx_ui_move")
			_paint_open_selection()
			return
		if x < 0:
			_choose_difficulty(true)
			SfxBus.play("sfx_ui_move")
		elif x > 0:
			_choose_difficulty(false)
			SfxBus.play("sfx_ui_move")
		return
	if _page == "home" and _open_focus >= 0:
		if y < 0:
			_open_focus = 10 if _diff_on() else -1
			SfxBus.play("sfx_ui_move")
			_paint_hub_selection()
			return
		if x != 0 and _open_elite.visible:
			_open_focus = 1 if x > 0 else 0
			SfxBus.play("sfx_ui_move")
			_paint_open_selection()
		return
	if _rows.is_empty():
		return
	var cols := maxi(1, _hub_cols)
	var n := _rows.size()
	var next := _index
	if cols > 1:
		if x < 0:
			next = posmod(_index - 1, n)
		elif x > 0:
			next = posmod(_index + 1, n)
		elif y < 0:
			next = posmod(_index - cols, n)
		elif y > 0:
			var cand := _index + cols
			if _page == "home" and cand >= n:
				_open_focus = 10 if _diff_on() else 0
				SfxBus.play("sfx_ui_move")
				_paint_hub_selection()
				return
			next = posmod(cand, n)
	else:
		if y < 0 or x < 0:
			next = posmod(_index - 1, n)
		elif y > 0 or x > 0:
			next = posmod(_index + 1, n)
	if next != _index:
		_index = next
		SfxBus.play("sfx_ui_move")
		_paint_hub_selection()


func _move_qty(x: int, y: int) -> void:
	if y < 0 and _qty_focus >= 4:
		_qty_focus = 2
	elif y > 0 and _qty_focus <= 3:
		_qty_focus = 4
	elif x < 0:
		if _qty_focus > 0 and _qty_focus <= 3:
			_qty_focus -= 1
		elif _qty_focus == 5:
			_qty_focus = 4
	elif x > 0:
		if _qty_focus < 3:
			_qty_focus += 1
		elif _qty_focus == 4:
			_qty_focus = 5
	_refresh()


func _move_stats(x: int, y: int) -> void:
	_msg = ""
	if y < 0:
		_stat_row = maxi(0, _stat_row - 1)
	elif y > 0:
		_stat_row = mini(4, _stat_row + 1)
	elif x < 0 and _stat_row <= 2:
		_stat_side = -1
	elif x > 0 and _stat_row <= 2:
		_stat_side = 1
	_refresh()


func _move_layout(x: int, y: int) -> void:
	if _on_size_btns:
		## Left/right immediately nudge width/height (pad-friendly).
		if x != 0:
			_size_side = 1 if x > 0 else -1
			_nudge_grid("w" if _size_row == 0 else "h", _size_side)
			return
		if y < 0:
			_size_row = maxi(0, _size_row - 1)
		elif y > 0:
			if _size_row < 1:
				_size_row += 1
			else:
				_on_size_btns = false
				_index = 0
				if not _rows.is_empty():
					_select_row(_index)
		_refresh()
		return
	if y < 0 and _index <= 0:
		_on_size_btns = true
		_size_row = 1
		_size_side = 1
		_refresh()
		return
	if _rows.is_empty():
		return
	if y < 0 or x < 0:
		_index = posmod(_index - 1, _rows.size())
	elif y > 0 or x > 0:
		_index = posmod(_index + 1, _rows.size())
	_select_row(_index)


func _rotate() -> void:
	if _drag_on:
		_drag_rot = (_drag_rot + 1) % 4
		SfxBus.play("sfx_ui_rotate")
		_grid.queue_redraw()
		return
	if _hold_type == "":
		return
	_hold_rot = (_hold_rot + 1) % 4
	SfxBus.play("sfx_ui_rotate")
	_grid.queue_redraw()


func _back() -> void:
	SfxBus.play("sfx_ui_cancel")
	if _dlg_open:
		if _dlg_info:
			_close_dialog()
		else:
			_on_dlg_no()
		return
	if _sku_pick_i >= 0:
		_cancel_sku_pick(true)
		return
	if _page == "layout" and _hold_type != "":
		_cancel_hold()
		return
	if _page == "layout" and _layout_focus == "map":
		_layout_focus = "list"
		## Land on size controls so pad can change width/height without hunting.
		_on_size_btns = true
		_size_row = 0
		_size_side = 1
		_msg = ""
		_refresh()
		return
	if _qty_sku != "":
		_qty_sku = ""
		_refresh()
		return
	if _page != "home" and _page != "scenario":
		_show_page(PrepPages.parent_page(_page))


func _input(event: InputEvent) -> void:
	if _try_back_click(event):
		return
	if not visible or _page != "layout" or _dlg_open or state == null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_press_layout(mb.position)
		else:
			_release_layout(mb.position)
	elif event is InputEventMouseMotion and _drag_on:
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(_drag_press) >= 6.0:
			_drag_moved = true
		if _drag_moved:
			_track_drag(mm.position)
			get_viewport().set_input_as_handled()


func _press_layout(screen: Vector2) -> void:
	_cancel_drag()
	var grid_local := _to_local(_grid, screen)
	if Rect2(Vector2.ZERO, _grid.size).has_point(grid_local):
		var cell := _cell_of(grid_local)
		var hit := state.item_at(cell.x, cell.y)
		if hit >= 0:
			var it: Dictionary = state.placed[hit]
			_drag_on = true
			_drag_type = String(it["type"])
			_drag_rot = int(it["rot"])
			_drag_from = hit
			_drag_grab = cell - Vector2i(int(it["x"]), int(it["y"]))
			_drag_press = screen
			_drag_inside = true
			_cursor = Vector2i(int(it["x"]), int(it["y"]))
			get_viewport().set_input_as_handled()
		return
	var list_local := _to_local(_list, screen)
	if not Rect2(Vector2.ZERO, _list.size).has_point(list_local):
		return
	var row := _row_at(list_local)
	if row < 0 or row >= _rows.size():
		return
	if String(_rows[row]["action"]) != "hold":
		return
	_drag_on = true
	_drag_type = String(_rows[row]["arg"])
	_drag_rot = 0
	_drag_from = -1
	_drag_grab = Vector2i.ZERO
	_drag_press = screen
	_drag_inside = false


func _release_layout(screen: Vector2) -> void:
	if not _drag_on:
		return
	var from := _drag_from
	var typ := _drag_type
	var rot := _drag_rot
	var moved := _drag_moved
	var grab := _drag_grab
	if moved:
		_list_dragging = true
		_click_arm = -1
	_cancel_drag()
	if not moved:
		if from >= 0 and _drag_index_still(from, typ):
			state.remove_at(from)
			_msg = Loc.t("prep.msg.picked_up")
			_clear_hold()
			_refresh()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	var grid_local := _to_local(_grid, screen)
	var inside := Rect2(Vector2.ZERO, _grid.size).has_point(grid_local)
	if not inside:
		if from >= 0 and _drag_index_still(from, typ):
			state.remove_at(from)
			_msg = Loc.t("prep.msg.picked_up")
		_clear_hold()
		_refresh()
		return
	var cell := _cell_of(grid_local) - grab
	if from >= 0:
		if not _drag_index_still(from, typ):
			_msg = Loc.t("err.no_fit")
			_clear_hold()
			_refresh()
			return
		_msg = state.move_item(from, cell.x, cell.y, rot)
		if _msg == "":
			_msg = Loc.t("prep.msg.moved")
	else:
		_msg = state.place_item(typ, cell.x, cell.y, rot)
		if _msg == "":
			_msg = Loc.t("prep.msg.placed")
	_clear_hold()
	_cursor = cell
	_refresh()


func _track_drag(screen: Vector2) -> void:
	var grid_local := _to_local(_grid, screen)
	_drag_inside = Rect2(Vector2.ZERO, _grid.size).has_point(grid_local)
	if not _drag_inside:
		_grid.queue_redraw()
		return
	_cursor = _cell_of(grid_local) - _drag_grab
	_grid.queue_redraw()


func _cancel_drag() -> void:
	_drag_on = false
	_drag_moved = false
	_drag_inside = false
	_drag_type = ""
	_drag_from = -1
	_drag_grab = Vector2i.ZERO


## True if placed[from] is still the piece we started dragging (guards stale index).
func _drag_index_still(from: int, typ: String) -> bool:
	if state == null or from < 0 or from >= state.placed.size():
		return false
	return String(state.placed[from].get("type", "")) == typ


func _to_local(ctrl: Control, screen: Vector2) -> Vector2:
	return ctrl.get_global_transform_with_canvas().affine_inverse() * screen


func _cell_of(local: Vector2) -> Vector2i:
	var cell := _cell_px()
	return Vector2i(int(floor(local.x / cell)), int(floor(local.y / cell)))


func _row_at(local: Vector2) -> int:
	## get_item_rect is in content space; mouse local is viewport space — add scroll.
	var scroll_y := 0.0
	var bar := _list.get_v_scroll_bar()
	if bar != null:
		scroll_y = bar.value
	var content_pt := Vector2(local.x, local.y + scroll_y)
	for i in _list.item_count:
		if _list.get_item_rect(i).has_point(content_pt):
			return i
	return -1


func try_place() -> void:
	if _dlg_open or _sku_pick_i >= 0:
		return
	if _hold_type == "":
		_pickup_at_cursor()
		return
	var from_map := _hold_from_map
	var def := _hold_default_sku
	_msg = state.place_item(_hold_type, _cursor.x, _cursor.y, _hold_rot, def)
	if _msg == "":
		SfxBus.play("sfx_ui_place")
		_clear_hold()
		_layout_focus = "map"
		_msg = Loc.t("prep.msg.moved") if from_map else Loc.t("prep.msg.placed")
	_refresh()


func _begin_hold_from_list(type: String) -> void:
	_hold_type = type
	_hold_rot = 0
	_hold_from_map = false
	_hold_origin = Vector2i.ZERO
	_hold_default_sku = ""
	_layout_focus = "map"
	_on_size_btns = false
	_msg = ""
	_refresh()


func _pickup_at_cursor() -> void:
	var hit := state.item_at(_cursor.x, _cursor.y)
	if hit < 0:
		_msg = Loc.t("prep.msg.cursor_empty")
		_refresh()
		return
	var it: Dictionary = state.placed[hit]
	_hold_type = String(it["type"])
	_hold_rot = int(it["rot"])
	_hold_from_map = true
	_hold_origin = Vector2i(int(it["x"]), int(it["y"]))
	_hold_default_sku = String(it.get("default_sku", "")) if state.is_restock_type(_hold_type) else ""
	_cursor = _hold_origin
	state.remove_at(hit)
	SfxBus.play("sfx_ui_pickup_item")
	_layout_focus = "map"
	_msg = ""
	_refresh()


func _cancel_hold() -> void:
	if _hold_type == "":
		return
	if _hold_from_map:
		var err := state.place_item(_hold_type, _hold_origin.x, _hold_origin.y, _hold_rot, _hold_default_sku)
		if err != "":
			## Origin should be free; if not, still drop the hold so the item is not lost from stock counts.
			_msg = err
		else:
			_msg = Loc.t("prep.msg.put_back")
			SfxBus.play("sfx_ui_place")
		_clear_hold()
		_layout_focus = "map"
	else:
		_clear_hold()
		_layout_focus = "list"
		_msg = ""
	_refresh()


## Drop a map-lifted hold back into unplaced stock (pad long-cancel; mouse tap/drag-off).
func _discard_hold() -> void:
	if _hold_type == "":
		return
	_msg = Loc.t("prep.msg.picked_up")
	SfxBus.play("sfx_ui_pickup_item")
	_clear_hold()
	_layout_focus = "map"
	_refresh()


func _clear_hold() -> void:
	_hold_type = ""
	_hold_rot = 0
	_hold_from_map = false
	_hold_origin = Vector2i.ZERO
	_hold_default_sku = ""
	_layout_cancel_held = false
	_layout_cancel_time = 0.0
	_layout_cancel_long = false


func _set_host_skin(skin_id: String) -> void:
	var sid := SkinCatalog.normalize(skin_id)
	var unlocked := SkinCatalog.is_unlocked(sid, state.unlocked_skins)
	if state.has_method("is_skin_unlocked"):
		unlocked = bool(state.is_skin_unlocked(sid))
	if not unlocked:
		_popup_info(Loc.t("prep.locked_title"), Loc.t("prep.look.locked_skin"))
		return
	state.skin_id = sid
	var save_err := state.save_to_disk()
	if save_err != "":
		push_warning("look skin save failed: %s" % save_err)
	_msg = Loc.t("prep.look.equipped", [SkinCatalog.display_name(sid)])
	_refresh()


func _cycle_look_tint() -> void:
	state.tint = (int(state.tint) + 1) % CharacterSheet.TINT_COUNT
	var save_err := state.save_to_disk()
	if save_err != "":
		push_warning("look tint save failed: %s" % save_err)
	_msg = Loc.t("prep.look.tint_set", [int(state.tint)])
	_refresh()


func _ensure_look_preview() -> void:
	if _look_preview_root != null and is_instance_valid(_look_preview_root):
		return
	_look_preview_root = Node2D.new()
	_look_preview_root.name = "LookPreview"
	_look_preview_root.position = Vector2(980, 220)
	_look_preview_root.z_index = 5
	add_child(_look_preview_root)
	_look_preview_spr = null
	_look_preview_id = ""


func _clear_look_preview() -> void:
	if _look_preview_root != null and is_instance_valid(_look_preview_root):
		_look_preview_root.queue_free()
	_look_preview_root = null
	_look_preview_spr = null
	_look_preview_id = ""


func _refresh_look_preview_from_index() -> void:
	if _page != "look":
		return
	var focus_id := String(state.appearance_skin_id()) if state.has_method("appearance_skin_id") else String(state.skin_id)
	if _index >= 0 and _index < _rows.size():
		var row: Dictionary = _rows[_index]
		if String(row.get("action", "")) == "set_skin":
			focus_id = String(row.get("arg", focus_id))
	_refresh_look_preview(focus_id)


func _refresh_look_preview(skin_id: String) -> void:
	_ensure_look_preview()
	var sid := SkinCatalog.normalize(skin_id)
	if not SkinCatalog.is_unlocked(sid, state.unlocked_skins):
		sid = SkinCatalog.DEFAULT_SKIN
	var tint_col := CharacterSheet.tint_color(int(state.tint))
	if _look_preview_spr != null and is_instance_valid(_look_preview_spr) and _look_preview_id == sid:
		_look_preview_spr.modulate = tint_col
		return
	if _look_preview_spr != null and is_instance_valid(_look_preview_spr):
		_look_preview_spr.queue_free()
	_look_preview_spr = null
	_look_preview_id = sid
	if not Vox.has_anim(sid, "idle"):
		sid = SkinCatalog.DEFAULT_SKIN
		_look_preview_id = sid
	if not Vox.has_anim(sid, "idle"):
		return
	_look_preview_spr = Vox.animated(sid)
	_look_preview_spr.scale = Vector2(2.0, 2.0)
	_look_preview_spr.modulate = tint_col
	Vox.play_anim(_look_preview_spr, sid, "idle", Vector2(0, 1))
	_look_preview_root.add_child(_look_preview_spr)


func _try_begin_restock_sku_pick() -> bool:
	if _dlg_open or _hold_type != "" or _layout_focus != "map" or state == null:
		return false
	var hit := state.item_at(_cursor.x, _cursor.y)
	if hit < 0:
		return false
	var it: Dictionary = state.placed[hit]
	var typ := String(it.get("type", ""))
	if not state.is_restock_type(typ):
		return false
	var cat := state.restock_category_of_type(typ)
	var list: Array[String] = state.developed_of(cat)
	if list.is_empty():
		_msg = Loc.t("prep.msg.cat_locked")
		_refresh()
		return true
	_sku_pick_i = hit
	var cur := String(it.get("default_sku", ""))
	var idx := list.find(cur)
	_sku_pick_cursor = idx if idx >= 0 else 0
	_msg = ""
	_refresh()
	SfxBus.play("sfx_ui_confirm")
	return true


func _sku_pick_list() -> Array[String]:
	if _sku_pick_i < 0 or _sku_pick_i >= state.placed.size():
		return []
	var typ := String(state.placed[_sku_pick_i].get("type", ""))
	return state.developed_of(state.restock_category_of_type(typ))


func _nudge_sku_pick(dir: int) -> void:
	var list := _sku_pick_list()
	if list.is_empty() or dir == 0:
		return
	_sku_pick_cursor = posmod(_sku_pick_cursor + (1 if dir > 0 else -1), list.size())
	SfxBus.play("sfx_ui_move")
	_refresh()


func _commit_sku_pick() -> void:
	var list := _sku_pick_list()
	if list.is_empty() or _sku_pick_i < 0:
		_cancel_sku_pick(false)
		_refresh()
		return
	var sku := list[clampi(_sku_pick_cursor, 0, list.size() - 1)]
	state.set_restock_default_sku(_sku_pick_i, sku)
	_sku_pick_i = -1
	_sku_pick_cursor = 0
	_msg = Loc.t("prep.layout.sku_set", [Tuning.sku_name(sku)])
	SfxBus.play("sfx_ui_confirm")
	_refresh()


func _cancel_sku_pick(play_sfx: bool) -> void:
	_sku_pick_i = -1
	_sku_pick_cursor = 0
	if play_sfx:
		_msg = ""
		_refresh()



func _cell_px() -> float:
	var side := maxi(state.grid_w, state.grid_h)
	return minf(32.0, 520.0 / float(side))
