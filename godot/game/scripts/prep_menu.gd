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

const PREP_TITLE := PrepWidgets.PREP_TITLE
const PREP_INFO := PrepWidgets.PREP_INFO
const PREP_LIST := PrepWidgets.PREP_LIST
const PREP_HINT := PrepWidgets.PREP_HINT

signal start_day

var demo: Node
var state: StateScript

var _page: String = "scenario"
var _index: int = 0
var _rows: Array[Dictionary] = []
var _qty_sku: String = ""
var _qty_boxes: int = 1
var _qty_focus: int = 2
var _hold_type: String = ""
var _hold_rot: int = 0
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
var _open_focus: int = -1 ## -1 tiles · 0 open main · 1 elite
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
var _building: bool = false
var _suppress_select: bool = false


func setup(host: Node) -> void:
	demo = host
	state = host.state
	layer = 30
	_bind_nodes()
	var load_err := state.load_from_disk()
	if load_err == "":
		_msg = "已讀取存檔（劇本 %d　LV%d　$%d）" % [state.scenario, state.level, state.money]
		_show_page("home")
	else:
		_show_page("scenario")


func _bind_nodes() -> void:
	_title = %Title
	_info = %Info
	_list = %List
	_back_btn = %BackBtn
	_hub_panel = %HubPanel
	_open_bar = %OpenBar
	_open_main = %OpenMain
	_open_elite = %OpenElite
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
	_dlg_yes.pressed.connect(_on_dlg_yes)
	_dlg_no.pressed.connect(_on_dlg_no)
	UiFont.apply_label(_title, PREP_TITLE)
	_title.add_theme_color_override("font_color", Color("f4d35e"))
	UiFont.apply_label(_info, PREP_INFO)
	_info.add_theme_color_override("font_color", Color("f4f1ea"))
	_list.add_theme_font_override("font", UiFont.font())
	_list.add_theme_font_size_override("font_size", UiFont.px(PREP_LIST))
	_list.add_theme_constant_override("v_separation", 10)
	_list.add_theme_constant_override("icon_margin", 12)
	_list.add_theme_color_override("font_color", Color("f4f1ea"))
	_list.add_theme_color_override("font_selected_color", Color("1c241f"))
	_list.add_theme_color_override("font_hovered_color", Color("f4d35e"))
	var bar := _list.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(36, 0)
	_back_btn.text = Loc.t("prep.chrome.back")
	PrepWidgets.paint_btn(_back_btn, true)
	UiFont.apply_button(_back_btn, PrepWidgets.PREP_BTN)
	_back_btn.custom_minimum_size = Vector2(200, 52)
	UiFont.apply_label(%Hint, PREP_HINT)
	%Hint.text = Loc.t("prep.chrome.hint")
	%Hint.add_theme_color_override("font_color", Color("c8d4c5"))
	_open_main.text = Loc.t("prep.home.open")
	_open_elite.text = Loc.t("prep.home.elite_test")
	UiFont.apply_button(_open_main, 26)
	UiFont.apply_button(_open_elite, 20)
	_open_main.custom_minimum_size = Vector2(0, PrepWidgets.OPEN_MAIN_H)
	_open_elite.custom_minimum_size = Vector2(0, PrepWidgets.OPEN_ELITE_H)
	_open_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_elite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PrepWidgets.paint_open_main(_open_main, false)
	PrepWidgets.paint_open_elite(_open_elite, false)
	UiFont.apply_label(_dlg_title, PREP_TITLE)
	_dlg_title.add_theme_color_override("font_color", Color("f4d35e"))
	UiFont.apply_label(_dlg_body, PREP_INFO)
	_dlg_body.add_theme_color_override("font_color", Color("f4f1ea"))
	_dlg_yes.text = Loc.t("prep.chrome.dialog_yes")
	_dlg_no.text = Loc.t("prep.chrome.dialog_no")
	UiFont.apply_button(_dlg_yes, PrepWidgets.PREP_BTN)
	UiFont.apply_button(_dlg_no, PrepWidgets.PREP_BTN)
	PrepWidgets.paint_btn(_dlg_yes, true)
	PrepWidgets.paint_btn(_dlg_no, false)


func _show_page(page: String) -> void:
	# The confirm key that opened this page must not also activate the new page.
	_confirm_latch = true
	_close_dialog()
	if page == "stock":
		page = "hub_goods"
	_page = page
	_index = 0
	_open_focus = -1
	_msg = ""
	_qty_sku = ""
	_on_size_btns = false
	if page != "layout":
		_hold_type = ""
		_cancel_drag()
	if page == "stats":
		_on_stats_btns = true
		_stat_row = 0
		_stat_side = 1
	else:
		_on_stats_btns = false
	_refresh()


func _refresh() -> void:
	_building = true
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
	_grid.queue_redraw()


func _pair(top: String, bottom: String) -> String:
	if bottom == "":
		return top
	return top + "\n" + bottom


func _header() -> String:
	var nxt := state.xp_to_next()
	var xp_txt := "已滿 LV10" if nxt <= 0 else "XP %d/%d" % [state.xp, nxt]
	return "資金 $%d　LV%d　%s　STR%d AGI%d INT%d　點數 %d" % [
		state.money, state.level, xp_txt, state.str_stat, state.agi_stat, state.int_stat, state.unspent
	]


func _home_info() -> String:
	if state.level_note != "":
		return state.level_note
	return "開店前配置角色、進貨、店面和店員。關店後回到這裡，營業額入帳。"


func _add(label: String, action: String, arg = null) -> void:
	_rows.append({"label": label, "action": action, "arg": arg, "icon": "", "locked": false, "tag": ""})
	if _list.visible:
		_list.add_item(label)


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


func _setup_open_bar() -> void:
	if _open_bar == null:
		return
	_open_main.text = Loc.t("prep.home.open")
	_open_elite.text = Loc.t("prep.home.elite_test")
	_open_elite.visible = ProductVersion.test_tools_enabled()
	_paint_open_selection()


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
		_popup_info("不能開店", "\n".join(blocks))


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
		_popup_info("不能重置", err)
		return
	_msg = "已重置能力值（−$%d）" % fee
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
	var label := "闊度" if axis == "w" else "長度"
	var nxt := cur + delta
	if nxt < 8:
		_popup_info("不能調整", "%s最少是 8。" % label)
		_refresh()
		return
	if axis == "w":
		w = nxt
	else:
		h = nxt
	if w * h > state.area_cap():
		_popup_info("不能調整", "加了%s之後總面積是 %d，超過規模 LV%d 的上限 %d。先縮小另一邊，或擴張店面。" % [label, w * h, state.shop_scale, state.area_cap()])
		_refresh()
		return
	var msg := state.set_grid(w, h)
	if msg != "":
		_popup_info("不能調整", "有傢俬超出新的邊界，先在圖上收回再縮小。")
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
				_popup_info("不能重置", err)
			else:
				_msg = "已重置能力值（−$%d）" % fee
			_refresh()
		else:
			_show_page("hub_char")
		return
	if _page == "home" and _open_focus == 0:
		_on_open_main_pressed()
		return
	if _page == "home" and _open_focus == 1:
		_on_open_elite_pressed()
		return
	if _page == "layout" and _hold_type != "":
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
			_msg = "已清除存檔"
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
				_popup_info("不能重置", err)
			else:
				_msg = "已重置能力值（−$%d）" % fee
			_refresh()
		"pick_slot":
			PrepPages.fill_skill_pick(self, int(arg))
		"equip":
			var equip_msg := state.equip(int(arg[0]), String(arg[1]))
			_show_page("skills")
			if equip_msg != "":
				_popup_info("不能裝備", equip_msg)
		"unequip":
			state.unequip(int(arg))
			_show_page("skills")
		"dev":
			_ask_develop(String(arg))
		"locked_sku":
			_popup_info("尚未開放", _locked_sku_body(String(arg)))
		"need_develop":
			_popup_info(Loc.t("prep.locked_title"), Loc.t("prep.buy.need_develop", [Tuning.sku_name(String(arg))]))
		"locked_look":
			_popup_info(Loc.t("prep.locked_title"), Loc.t("prep.look.locked_body"))
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
			_popup_info("尚未開放", "店舖已是最大規模 LV3，不能再擴張。")
		"hold":
			_hold_type = String(arg)
			_hold_rot = 0
			_refresh()
		"pickup":
			var hit := state.item_at(_cursor.x, _cursor.y)
			if hit >= 0:
				state.remove_at(hit)
				SfxBus.play("sfx_ui_pickup_item")
				_msg = "已收回"
			else:
				_msg = "游標上沒有物品"
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
				_popup_info("不能開店", "\n".join(blocks))
		"elite_open":
			_try_elite_open(int(arg))
		"open":
			var open_msg := state.begin_day()
			if open_msg != "":
				_popup_info("不能開店", open_msg)
				return
			var save_err := state.save_to_disk()
			if save_err != "":
				push_warning("prep end save failed: %s" % save_err)
			visible = false
			set_process_unhandled_input(false)
			start_day.emit()
		"test_money":
			_grant_test_money()
		"play_sfx":
			SfxBus.play(String(arg))
		"noop":
			pass
		_:
			pass


func _grant_test_money() -> void:
	const ProductVersion = preload("res://scripts/product_version.gd")
	if not ProductVersion.test_tools_enabled():
		return
	state.money += 1000
	_msg = Loc.t("prep.home.test_money_ok", [state.money])
	_refresh()


func _try_elite_open(lv: int) -> void:
	const ProductVersion = preload("res://scripts/product_version.gd")
	if not ProductVersion.test_tools_enabled():
		return
	var blocks := state.open_blockers()
	if not blocks.is_empty():
		_popup_info("不能開店", "\n".join(blocks))
		return
	if demo != null and demo.has_method("configure_elite_test"):
		demo.call("configure_elite_test", lv)
	_show_page("confirm")


func _locked_sku_body(sku: String) -> String:
	return "%s要角色 LV%d 才開放，現在是 LV%d。" % [Tuning.sku_name(sku), int(Tuning.SKU_UNLOCK_LV.get(sku, 99)), state.level]


func _popup_locked_furn(type: String) -> void:
	var spec: Dictionary = state.FURNITURE[type]
	_popup_info("尚未開放", "%s要角色 LV%d 才開放購入，現在是 LV%d。" % [spec["name"], int(spec["unlock"]), state.level])


func _funds_line(what: String, price: int) -> String:
	return "%s要 $%d，現有 $%d。" % [what, price, state.money]


func _ask_develop(sku: String) -> void:
	var name := Tuning.sku_name(sku)
	if not state.sku_unlocked(sku):
		_popup_info("尚未開放", _locked_sku_body(sku))
		return
	if state.developed.has(sku):
		_popup_info("不能開發", "%s已經開發，可以直接採購。" % name)
		return
	var fee := int(Tuning.SKU_DEVELOP.get(sku, 0))
	if state.money < fee:
		_popup_info("資金不足", _funds_line("開發%s" % name, fee))
		return
	_popup_confirm("確認購入", "開發%s，支付 $%d？" % [name, fee], {"action": "dev", "sku": sku})


func _ask_buy() -> void:
	var name := Tuning.sku_name(_qty_sku)
	var boxes := _qty_boxes
	if not state.developed.has(_qty_sku):
		_popup_info("尚未開放", "%s尚未開發，不能採購。" % name)
		return
	var cost := int(Tuning.SKU_COST.get(_qty_sku, 0)) * boxes
	if state.money < cost:
		_popup_info("資金不足", _funds_line("採購%s %d 箱" % [name, boxes], cost))
		return
	_popup_confirm("確認購入", "採購%s %d 箱，支付 $%d？" % [name, boxes, cost], {"action": "buy", "sku": _qty_sku, "boxes": boxes})


func _ask_furniture(type: String) -> void:
	var spec: Dictionary = state.FURNITURE[type]
	var name := String(spec["name"])
	if not state.furniture_unlocked(type):
		_popup_locked_furn(type)
		return
	var price := int(spec["price"])
	if state.money < price:
		_popup_info("資金不足", _funds_line("購入%s" % name, price))
		return
	_popup_confirm("確認購入", "購入%s，支付 $%d？" % [name, price], {"action": "furn", "type": type})


func _ask_expand() -> void:
	if state.shop_scale >= 3:
		_popup_info("尚未開放", "店舖已是最大規模 LV3，不能再擴張。")
		return
	var nxt := state.shop_scale + 1
	var need := int(state.SCALE_NEED_LV[nxt])
	if state.level < need:
		_popup_info("尚未開放", "擴張到規模 LV%d 要角色 LV%d，現在是 LV%d。" % [nxt, need, state.level])
		return
	var price := int(state.SCALE_COST[nxt])
	if state.money < price:
		_popup_info("資金不足", _funds_line("擴張到規模 LV%d" % nxt, price))
		return
	var cap := int(state.SCALE_MAX[nxt])
	_popup_confirm("確認購入", "擴張到規模 LV%d，總面積上限變為 %d（現成 %d×%d），支付 $%d？" % [nxt, cap * cap, cap, cap, price], {"action": "expand"})


func _try_hire() -> void:
	var before := state.clerks.size()
	var msg := state.hire()
	if msg == "" and state.clerks.size() > before:
		SfxBus.play("sfx_ui_purchase")
		_msg = "已召募"
		_refresh()
		return
	if msg == "店舖規模雇員已滿":
		var cap := int(state.HIRE_CAP.get(state.shop_scale, 0))
		var body := "規模 LV%d 最多召募 %d 人。" % [state.shop_scale, cap]
		if state.shop_scale < 3:
			body += "擴張店面後上限才會提高。"
		_popup_info("尚未開放", body)
	elif msg == "店員不能多過收銀機":
		_popup_info("不能召募", "店員不能多過已放置的收銀機。請先在店舖設計放一台收銀機。")
	else:
		_popup_info("不能召募", msg if msg != "" else "現在不能召募。")


func _run_pending(pending: Dictionary) -> void:
	match String(pending.get("action", "")):
		"dev":
			var sku := String(pending["sku"])
			var msg := state.develop(sku)
			if msg != "":
				_popup_info("不能開發", msg)
			else:
				SfxBus.play("sfx_ui_purchase")
				_msg = "已開發 %s" % Tuning.sku_name(sku)
				_refresh()
		"buy":
			var sku2 := String(pending["sku"])
			var boxes := int(pending["boxes"])
			var msg2 := state.buy_stock(sku2, boxes)
			if msg2 != "":
				_popup_info("不能採購", msg2)
			else:
				SfxBus.play("sfx_ui_purchase")
				_qty_sku = ""
				_msg = "已採購 %s ×%d 箱" % [Tuning.sku_name(sku2), boxes]
				_refresh()
		"furn":
			var type := String(pending["type"])
			var msg3 := state.buy_furniture(type)
			if msg3 != "":
				_popup_info("不能購入", msg3)
			else:
				SfxBus.play("sfx_ui_purchase")
				_msg = "已購入 %s" % String(state.FURNITURE[type]["name"])
				_refresh()
		"expand":
			var msg4 := state.expand()
			if msg4 != "":
				_popup_info("不能擴張", msg4)
			else:
				SfxBus.play("sfx_ui_purchase")
				_msg = "已擴張到規模 LV%d" % state.shop_scale
				_refresh()


func _popup_info(title: String, body: String) -> void:
	SfxBus.play("sfx_ui_deny")
	_open_dialog(title, body, true, {})


func _popup_confirm(title: String, body: String, pending: Dictionary) -> void:
	_open_dialog(title, body, false, pending)


func _open_dialog(title: String, body: String, info: bool, pending: Dictionary) -> void:
	_dlg_info = info
	_dlg_focus = 0
	_dlg_gate = 1
	_dlg_wait = 0
	_pending = pending
	_dlg_title.text = title
	_dlg_body.text = body
	_dlg_yes.text = "知道了" if info else "確定"
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
	_close_dialog()


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
		_activate()
	elif event.is_action_pressed(Controls.CANCEL):
		_back()
	elif event.is_action_pressed(Controls.ROTATE):
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
	if v.length() < 0.55:
		_stick_armed = true
		return
	if not _stick_armed:
		return
	_stick_armed = false
	if absf(v.x) > absf(v.y):
		_move(1 if v.x > 0 else -1, 0)
	else:
		_move(0, 1 if v.y > 0 else -1)


var _stick_armed: bool = true


func _move(x: int, y: int) -> void:
	if _dlg_open:
		_dialog_move(x, y)
		return
	if _page == "layout" and _hold_type != "":
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


func _move_hub(x: int, y: int) -> void:
	if _rows.is_empty() and _page != "home":
		return
	if _page == "home" and _open_focus >= 0:
		if y < 0:
			_open_focus = -1
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
				_open_focus = 0
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
		if x < 0:
			_size_side = -1
		elif x > 0:
			_size_side = 1
		elif y < 0:
			_size_row = maxi(0, _size_row - 1)
		elif y > 0:
			if _size_row < 1:
				_size_row += 1
			else:
				_on_size_btns = false
				_index = 0
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
	if _hold_type != "":
		_hold_type = ""
		_refresh()
		return
	if _qty_sku != "":
		_qty_sku = ""
		_refresh()
		return
	if _page == "skill_pick":
		_show_page("skills")
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
		if from >= 0:
			state.remove_at(from)
			_msg = "已收回"
			_hold_type = ""
			_refresh()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	var grid_local := _to_local(_grid, screen)
	var inside := Rect2(Vector2.ZERO, _grid.size).has_point(grid_local)
	if not inside:
		if from >= 0:
			state.remove_at(from)
			_msg = "已收回"
		_hold_type = ""
		_refresh()
		return
	var cell := _cell_of(grid_local) - grab
	if from >= 0:
		_msg = state.move_item(from, cell.x, cell.y, rot)
		if _msg == "":
			_msg = "已移動"
	else:
		_msg = state.place_item(typ, cell.x, cell.y, rot)
		if _msg == "":
			_msg = "已放置"
	_hold_type = ""
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


func _to_local(ctrl: Control, screen: Vector2) -> Vector2:
	return ctrl.get_global_transform_with_canvas().affine_inverse() * screen


func _cell_of(local: Vector2) -> Vector2i:
	var cell := _cell_px()
	return Vector2i(int(floor(local.x / cell)), int(floor(local.y / cell)))


func _row_at(local: Vector2) -> int:
	for i in _list.item_count:
		if _list.get_item_rect(i).has_point(local):
			return i
	return -1


func try_place() -> void:
	if _dlg_open:
		return
	if _hold_type == "":
		var hit := state.item_at(_cursor.x, _cursor.y)
		if hit >= 0:
			state.remove_at(hit)
			_msg = "已收回"
			_refresh()
		return
	_msg = state.place_item(_hold_type, _cursor.x, _cursor.y, _hold_rot)
	if _msg == "":
		SfxBus.play("sfx_ui_place")
		_hold_type = ""
	_refresh()



func _cell_px() -> float:
	var side := maxi(state.grid_w, state.grid_h)
	return minf(32.0, 520.0 / float(side))
