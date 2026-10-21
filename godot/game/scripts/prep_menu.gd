extends CanvasLayer
## Shop-prep menus. Uses InputMap: move_*, interact, cancel, rotate.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const StateScript = preload("res://scripts/game_state.gd")

const PREP_TITLE := 40
const PREP_INFO := 28
const PREP_LIST := 32
const PREP_HINT := 24
const PREP_BTN := 32
const PREP_NUM := 44

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
var _click_arm: int = -1
var _list_dragging: bool = false
var _list_press := Vector2.ZERO
var _info: Label
var _title: Label
var _grid: Control
var _stats_panel: VBoxContainer
var _stat_row: int = 0
var _stat_side: int = 1
var _on_stats_btns: bool = false
var _size_panel: VBoxContainer
var _size_row: int = 0
var _size_side: int = 1
var _on_size_btns: bool = false
var _qty_panel: VBoxContainer
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
	_build()
	var load_err := state.load_from_disk()
	if load_err == "":
		_msg = "已讀取存檔（劇本 %d　LV%d　$%d）" % [state.scenario, state.level, state.money]
		_show_page("home")
	else:
		_show_page("scenario")


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("141c18")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_title = Label.new()
	_title.position = Vector2(24, 16)
	_title.size = Vector2(1232, 56)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFont.apply_label(_title, PREP_TITLE)
	_title.add_theme_color_override("font_color", Color("f4d35e"))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_info = Label.new()
	_info.position = Vector2(24, 76)
	_info.size = Vector2(960, 100)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFont.apply_label(_info, PREP_INFO)
	_info.add_theme_color_override("font_color", Color("f4f1ea"))
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)
	_list = ItemList.new()
	_list.position = Vector2(24, 168)
	_list.size = Vector2(1232, 430)
	_list.clip_contents = true
	_list.allow_reselect = true
	_list.focus_mode = Control.FOCUS_NONE
	_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_list.add_theme_font_override("font", UiFont.font())
	_list.add_theme_font_size_override("font_size", UiFont.px(PREP_LIST))
	_list.add_theme_constant_override("v_separation", 6)
	_list.add_theme_color_override("font_color", Color("f4f1ea"))
	_list.add_theme_color_override("font_selected_color", Color("1c241f"))
	_list.add_theme_color_override("font_hovered_color", Color("f4d35e"))
	_list.item_selected.connect(_on_click)
	_list.gui_input.connect(_on_list_gui_input)
	var bar := _list.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(36, 0)
	add_child(_list)
	_back_btn = _bare_button("返回", 240, 56)
	_back_btn.position = Vector2(1000, 88)
	_back_btn.z_index = 8
	_paint_btn(_back_btn, true)
	_back_btn.button_down.connect(_on_back_button)
	add_child(_back_btn)
	_stats_panel = VBoxContainer.new()
	_stats_panel.position = Vector2(24, 186)
	_stats_panel.size = Vector2(720, 360)
	_stats_panel.clip_contents = true
	_stats_panel.add_theme_constant_override("separation", 8)
	_stats_panel.visible = false
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats_panel)
	_size_panel = VBoxContainer.new()
	_size_panel.position = Vector2(24, 186)
	_size_panel.size = Vector2(520, 180)
	_size_panel.add_theme_constant_override("separation", 12)
	_size_panel.visible = false
	_size_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_size_panel)
	_qty_panel = VBoxContainer.new()
	_qty_panel.position = Vector2(24, 190)
	_qty_panel.size = Vector2(1100, 320)
	_qty_panel.add_theme_constant_override("separation", 18)
	_qty_panel.visible = false
	_qty_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_qty_panel)
	_grid = GridView.new()
	_grid.position = Vector2(560, 186)
	_grid.size = Vector2(690, 470)
	_grid.host = self
	add_child(_grid)
	var hint := Label.new()
	hint.position = Vector2(24, 668)
	hint.size = Vector2(1232, 40)
	hint.text = "方向移動　行動確定　取消返回　店舖設計時 轉向（預設 K／X）"
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFont.apply_label(hint, PREP_HINT)
	hint.add_theme_color_override("font_color", Color("c8d4c5"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	_build_dialog()


func _build_dialog() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.62)
	_shade.visible = false
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.z_index = 20
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = Control.new()
	_box.position = Vector2(190, 150)
	_box.size = Vector2(900, 400)
	_box.visible = false
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.z_index = 21
	add_child(_box)
	var card := ColorRect.new()
	card.color = Color("1c241f")
	card.position = Vector2.ZERO
	card.size = _box.size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.add_child(card)
	_dlg_title = Label.new()
	_dlg_title.position = Vector2(36, 28)
	_dlg_title.size = Vector2(828, 52)
	UiFont.apply_label(_dlg_title, PREP_TITLE)
	_dlg_title.add_theme_color_override("font_color", Color("f4d35e"))
	_box.add_child(_dlg_title)
	_dlg_body = Label.new()
	_dlg_body.position = Vector2(36, 100)
	_dlg_body.size = Vector2(828, 140)
	_dlg_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFont.apply_label(_dlg_body, PREP_INFO)
	_dlg_body.add_theme_color_override("font_color", Color("f4f1ea"))
	_box.add_child(_dlg_body)
	_dlg_yes = _bare_button("確定", 280, 80)
	_dlg_yes.position = Vector2(140, 280)
	_dlg_yes.pressed.connect(_on_dlg_yes)
	_box.add_child(_dlg_yes)
	_dlg_no = _bare_button("取消", 280, 80)
	_dlg_no.position = Vector2(480, 280)
	_dlg_no.pressed.connect(_on_dlg_no)
	_box.add_child(_dlg_no)


func _show_page(page: String) -> void:
	# The confirm key that opened this page must not also activate the new page.
	_confirm_latch = true
	_close_dialog()
	_page = page
	_index = 0
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
	var qty_on := _page == "stock" and _qty_sku != ""
	_grid.visible = _page == "layout"
	_stats_panel.visible = _page == "stats"
	_size_panel.visible = _page == "layout"
	_qty_panel.visible = qty_on
	_list.visible = not qty_on
	if _back_btn:
		_back_btn.visible = _page != "scenario" and _page != "home"
	if _page == "stats":
		_list.position = Vector2(24, 430)
		_list.size = Vector2(1232, 220)
		_list.z_index = 2
	elif _page == "layout":
		_list.z_index = 0
		_list.position = Vector2(24, 360)
		_list.size = Vector2(520, 276)
	else:
		_list.z_index = 0
		_list.position = Vector2(24, 168)
		_list.size = Vector2(1232, 430)
	match _page:
		"scenario":
			_title.text = "選擇劇本"
			_info.text = "劇本1 從空店開始，資金 $10000。劇本2、3 帶現成店面和店員。"
			_add("劇本1　從新開始　資金 $10000　LV1　空店", "sc", 1)
			_add("劇本2　LV5　資金 $10000　店規模 2　1 名店員", "sc", 2)
			_add("劇本3　LV10　資金 $99999　三圍 30　店規模 3　2 名店員", "sc", 3)
		"home":
			_title.text = "營運準備"
			_info.text = _pair(_header(), _msg if _msg != "" else _home_info())
			_add("角色能力", "go", "stats")
			_add("裝備技能　COST %d/5" % state.cost_sum(), "go", "skills")
			_add("開發／採購貨品", "go", "stock")
			_add("購入商店物品", "go", "furn")
			_add("擴張店面　現時 LV%d　%d×%d" % [state.shop_scale, state.grid_w, state.grid_h], "go", "expand")
			_add("店舖設計", "go", "layout")
			_add("店員　%d 人" % state.clerks.size(), "go", "clerks")
			_add("開始營業", "try_open", null)
			_add("清除存檔並重選劇本", "wipe_save", null)
		"stats":
			_fill_stats()
		"skills":
			_fill_skills()
		"stock":
			_fill_stock()
		"furn":
			_fill_furn()
		"expand":
			_fill_expand()
		"layout":
			_fill_layout()
		"clerks":
			_fill_clerks()
		"confirm":
			_fill_confirm()
	if _rows.size() > 0 and _list.visible:
		_index = clampi(_index, 0, _rows.size() - 1)
		var on_btns := (_page == "stats" and _on_stats_btns) or (_page == "layout" and _on_size_btns)
		if on_btns:
			_list.deselect_all()
		else:
			_select_row(_index)
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
	_rows.append({"label": label, "action": action, "arg": arg})
	_list.add_item(label)


func _fill_stats() -> void:
	_title.text = "角色能力"
	_info.text = _pair(_header(), _msg if _msg != "" else "按 + 加一點，按 - 減一點。向下可到重置和返回。")
	_list.visible = false
	_clear(_stats_panel)
	_add_stat_row("STR", "str", state.str_stat, 0)
	_add_stat_row("AGI", "agi", state.agi_stat, 1)
	_add_stat_row("INT", "int", state.int_stat, 2)
	_stats_panel.add_child(_step_button("重置能力值", _stat_row == 3, _on_stat_reset, 64, 420))
	_stats_panel.add_child(_step_button("返回", _stat_row == 4, _on_stat_back, 64, 420))


func _add_stat_row(title: String, stat: String, value: int, row: int) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_name_label("%s  %d" % [title, value], 220, 64))
	line.add_child(_step_button("+", _stat_row == row and _stat_side == 1, _on_stat_pressed.bind(stat, 1, row), 64))
	line.add_child(_step_button("-", _stat_row == row and _stat_side == -1, _on_stat_pressed.bind(stat, -1, row), 64))
	_stats_panel.add_child(line)


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
	state.reset_stats()
	_msg = ""
	_refresh()


func _on_stat_back() -> void:
	if _dlg_open or _swallow_click:
		return
	_show_page("home")


func _fill_skills() -> void:
	_title.text = "裝備技能"
	var ult_name := String(state.ult_skill().get("name", ""))
	_info.text = "COST %d/5　奧義 %s\n選一格再選技能。奧義不佔 COST。" % [state.cost_sum(), ult_name]
	for i in 5:
		var id := state.slots[i]
		var name := "空"
		var kind := ""
		if id != "":
			var sk := Skills.by_id(id)
			name = String(sk.get("name"))
			kind = _kind_label(String(sk.get("kind"))) + "　"
		_add("技能%d　%s%s" % [i + 1, kind, name], "pick_slot", i)
	var ult := state.ult_skill()
	_add("奧義　%s" % String(ult.get("name")), "pick_slot", 5)
	_add("返回", "go", "home")


func _fill_stock() -> void:
	if _qty_sku != "":
		var name := Tuning.sku_name(_qty_sku)
		var each := int(Tuning.SKU_COST.get(_qty_sku, 0))
		_title.text = "採購 %s" % name
		_info.text = "庫存 %d 箱　$%d／箱。中間是箱數（01–99），按按鈕加減。" % [int(state.stock.get(_qty_sku, 0)), each]
		_build_qty(each * _qty_boxes)
		return
	_title.text = "開發／採購"
	_info.text = _pair(_header(), _msg if _msg != "" else "罐頭是初始貨物，不用開發就能採購。其他未開發的先付開發費。")
	for sku in Tuning.SELLABLE_SKUS:
		if not state.sku_unlocked(sku):
			_add("%s　LV%d 開放" % [Tuning.sku_name(sku), int(Tuning.SKU_UNLOCK_LV[sku])], "locked_sku", sku)
		elif not state.developed.has(sku):
			_add("開發 %s　$%d" % [Tuning.sku_name(sku), int(Tuning.SKU_DEVELOP[sku])], "dev", sku)
		else:
			_add("採購 %s　庫存 %d 箱　$%d/箱" % [Tuning.sku_name(sku), int(state.stock.get(sku, 0)), int(Tuning.SKU_COST[sku])], "qty", sku)
	_add("返回", "go", "home")


func _build_qty(total: int) -> void:
	_clear(_qty_panel)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 16)
	steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	steps.add_child(_qty_button("-10", 0))
	steps.add_child(_qty_button("-1", 1))
	steps.add_child(_qty_figure())
	steps.add_child(_qty_button("+1", 2))
	steps.add_child(_qty_button("+10", 3))
	_qty_panel.add_child(steps)
	var sum := Label.new()
	sum.text = "合計 $%d" % total
	sum.custom_minimum_size = Vector2(400, 48)
	UiFont.apply_label(sum, PREP_TITLE)
	sum.add_theme_color_override("font_color", Color("e07a5f") if total > state.money else Color("f4d35e"))
	_qty_panel.add_child(sum)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 24)
	acts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ok := _bare_button("確定購買", 280, 80)
	_paint_btn(ok, _qty_focus == 4)
	ok.pressed.connect(_on_qty_pressed.bind(4))
	acts.add_child(ok)
	var cancel := _bare_button("取消", 280, 80)
	_paint_btn(cancel, _qty_focus == 5)
	cancel.pressed.connect(_on_qty_pressed.bind(5))
	acts.add_child(cancel)
	_qty_panel.add_child(acts)


func _qty_figure() -> Control:
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(210, 84)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0e1612")
	sb.border_color = Color("f4d35e")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	holder.add_theme_stylebox_override("panel", sb)
	var num := Label.new()
	num.text = "%02d 箱" % _qty_boxes
	num.position = Vector2(0, 0)
	num.size = Vector2(210, 84)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiFont.apply_label(num, PREP_NUM)
	num.add_theme_color_override("font_color", Color("f4f1ea"))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(num)
	return holder


func _qty_button(text: String, focus_i: int) -> Button:
	var btn := _bare_button(text, 120, 84)
	_paint_btn(btn, _qty_focus == focus_i)
	btn.pressed.connect(_on_qty_pressed.bind(focus_i))
	return btn


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


func _fill_furn() -> void:
	_title.text = "購入商店物品"
	_info.text = _pair(_header(), _msg if _msg != "" else "買入後到店舖設計才放進店裡。展示貨架有 4、8、12、24 件，越大越貴。凍櫃 LV4、冰櫃 LV7 才開放。")
	for type in state.FURNITURE.keys():
		var spec: Dictionary = state.FURNITURE[type]
		if not state.furniture_unlocked(type):
			_add("%s　LV%d 開放　$%d" % [spec["name"], int(spec["unlock"]), int(spec["price"])], "locked_furn", type)
		else:
			_add("購入 %s　$%d　擁有 %d　未放置 %d" % [spec["name"], int(spec["price"]), int(state.owned.get(type, 0)), state.unplaced(type)], "buy_f", type)
	_add("返回", "go", "home")


func _fill_expand() -> void:
	_title.text = "擴張店面"
	_info.text = "現時規模 LV%d　地圖 %d×%d　總面積 %d／%d。闊度和長度在店舖設計裡調，一邊減少就能加另一邊。\nLV2＝$3000、總面積 225，要角色 LV4。LV3＝$6000、總面積 400，要角色 LV7。" % [state.shop_scale, state.grid_w, state.grid_h, state.grid_w * state.grid_h, state.area_cap()]
	if state.shop_scale < 3:
		var nxt := state.shop_scale + 1
		_add("擴張到規模 LV%d　$%d" % [nxt, int(state.SCALE_COST[nxt])], "expand", null)
	else:
		_add("已是最大規模", "expand_max", null)
	_add("返回", "go", "home")


func _fill_layout() -> void:
	_title.text = "店舖設計"
	if _hold_type != "":
		_info.text = "正在放 %s。拖到右圖放開，或移動游標後確定。X／K 轉向。" % state.FURNITURE[_hold_type]["name"]
	elif _msg != "":
		_info.text = _msg
	else:
		_info.text = "拖動左邊的物品放到右圖。圖上的物品可以拖去別的格子，拖出圖外或輕點就收回。"
	_build_size()
	for type in state.FURNITURE.keys():
		var n := state.unplaced(type)
		if n > 0:
			_add("拖放 %s　×%d" % [state.FURNITURE[type]["name"], n], "hold", type)
	_add("收回游標上的物品", "pickup", null)
	_add("返回", "go", "home")


func _build_size() -> void:
	_clear(_size_panel)
	_add_size_row("闊度", "w", state.grid_w, 0)
	_add_size_row("長度", "h", state.grid_h, 1)
	var area := _name_label("總面積  %d／%d" % [state.grid_w * state.grid_h, state.area_cap()], 420, 48)
	area.add_theme_color_override("font_color", Color("f4d35e"))
	_size_panel.add_child(area)


func _add_size_row(title: String, axis: String, value: int, row: int) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_name_label("%s  %d" % [title, value], 180))
	line.add_child(_step_button("+", _on_size_btns and _size_row == row and _size_side == 1, _on_size_pressed.bind(axis, 1, row)))
	line.add_child(_step_button("-", _on_size_btns and _size_row == row and _size_side == -1, _on_size_pressed.bind(axis, -1, row)))
	_size_panel.add_child(line)


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


func _fill_clerks() -> void:
	_title.text = "店員"
	_info.text = "現有 %d／上限 %d　每日開工每人扣 $%d\n人數不能多過已放置的收銀機，也不能超過店舖規模。" % [state.clerks.size(), state.hire_limit(), state.WAGE]
	_add("召募", "hire", null)
	for i in state.clerks.size():
		var c: Dictionary = state.clerks[i]
		var role := "收銀" if String(c["role"]) == "cashier" else "補貨"
		_add("店員%d　%s　收銀機 %d　（確定切崗位）" % [i + 1, role, int(c["register"]) + 1], "role", i)
		if String(c["role"]) == "cashier":
			_add("　改派收銀機", "reg", i)
		_add("　解僱店員%d" % (i + 1), "fire", i)
	_add("返回", "go", "home")


func _fill_confirm() -> void:
	_title.text = "開始營業？"
	var wage := state.WAGE * state.clerks.size()
	_info.text = "開工扣工資 $%d。結算時營業額入帳；若營業額低於本輪進貨成本會標虧損，遊戲繼續。" % wage
	_add("開始　工資後資金約 $%d" % (state.money - wage), "open", null)
	_add("返回", "go", "home")


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
	if _page == "stats":
		if _stat_row <= 2:
			var keys := ["str", "agi", "int"]
			_msg = state.spend_point(keys[_stat_row], _stat_side)
			_refresh()
		elif _stat_row == 3:
			state.reset_stats()
			_msg = ""
			_refresh()
		else:
			_show_page("home")
		return
	if _page == "layout" and _hold_type != "":
		try_place()
		return
	if _page == "layout" and _on_size_btns:
		_nudge_grid("w" if _size_row == 0 else "h", _size_side)
		return
	if _page == "stock" and _qty_sku != "":
		_qty_apply(_qty_focus)
		return
	if _index < 0 or _index >= _rows.size():
		return
	var row: Dictionary = _rows[_index]
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
			_show_page(String(arg))
		"reset":
			state.reset_stats()
			_refresh()
		"pick_slot":
			_fill_skill_pick(int(arg))
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
			var blocks := state.open_blockers()
			if blocks.is_empty():
				_show_page("confirm")
			else:
				_popup_info("不能開店", "\n".join(blocks))
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
		_:
			pass


func _fill_skill_pick(slot_i: int) -> void:
	_page = "skill_pick"
	_qty_panel.visible = false
	_size_panel.visible = false
	_stats_panel.visible = false
	_grid.visible = false
	_list.visible = true
	_list.position = Vector2(24, 168)
	_list.size = Vector2(1232, 430)
	_rows.clear()
	_list.clear()
	_title.text = "選擇技能"
	_info.text = "格 %s。名字前面是性質：主動、被動或奧義。COST 合計不能超過 5。" % ("奧義" if slot_i == 5 else str(slot_i + 1))
	var pool: Array = []
	if slot_i == 5:
		pool.append_array(Skills.ULTS)
	else:
		pool.append_array(Skills.ACTIVES)
		pool.append_array(Skills.PASSIVES)
	for sk in pool:
		_add("%s　%s　COST%d　%s" % [_kind_label(String(sk["kind"])), sk["name"], int(sk["cost"]), sk["blurb"]], "equip", [slot_i, sk["id"]])
	if slot_i < 5:
		_add("卸下", "unequip", slot_i)
	_add("返回", "go", "skills")
	_index = 0
	if _rows.size():
		_select_row(0)


func _kind_label(kind: String) -> String:
	match kind:
		"active":
			return "主動"
		"passive":
			return "被動"
		"ultimate":
			return "奧義"
		_:
			return kind


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
				_msg = "已開發 %s" % Tuning.sku_name(sku)
				_refresh()
		"buy":
			var sku2 := String(pending["sku"])
			var boxes := int(pending["boxes"])
			var msg2 := state.buy_stock(sku2, boxes)
			if msg2 != "":
				_popup_info("不能採購", msg2)
			else:
				_qty_sku = ""
				_msg = "已採購 %s ×%d 箱" % [Tuning.sku_name(sku2), boxes]
				_refresh()
		"furn":
			var type := String(pending["type"])
			var msg3 := state.buy_furniture(type)
			if msg3 != "":
				_popup_info("不能購入", msg3)
			else:
				_msg = "已購入 %s" % String(state.FURNITURE[type]["name"])
				_refresh()
		"expand":
			var msg4 := state.expand()
			if msg4 != "":
				_popup_info("不能擴張", msg4)
			else:
				_msg = "已擴張到規模 LV%d" % state.shop_scale
				_refresh()


func _popup_info(title: String, body: String) -> void:
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
	_paint_btn(_dlg_yes, _dlg_info or _dlg_focus == 0)
	_paint_btn(_dlg_no, not _dlg_info and _dlg_focus == 1)


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
		if _dlg_gate == 2 and event.is_pressed():
			_dialog_action(event)
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed():
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
		var stick := Controls.move_vector()
		if stick.length() < 0.55:
			_stick_armed = true
			return
		if not _stick_armed:
			return
		_stick_armed = false
		if absf(stick.x) > absf(stick.y):
			_dialog_move(1 if stick.x > 0 else -1, 0)
		return
	var v := Controls.move_vector()
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
	if _qty_sku != "" and _page == "stock":
		_move_qty(x, y)
		return
	if _rows.is_empty():
		return
	if y < 0 or x < 0:
		_index = posmod(_index - 1, _rows.size())
	elif y > 0 or x > 0:
		_index = posmod(_index + 1, _rows.size())
	_select_row(_index)


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
		_grid.queue_redraw()
		return
	if _hold_type == "":
		return
	_hold_rot = (_hold_rot + 1) % 4
	_grid.queue_redraw()


func _back() -> void:
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
		_show_page("home")


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
		_hold_type = ""
	_refresh()


func _clear(node: Node) -> void:
	for c in node.get_children():
		c.set_block_signals(true)
		node.remove_child(c)
		c.free()


func _name_label(text: String, width: float, tall: float = 72.0) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.custom_minimum_size = Vector2(width, tall)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiFont.apply_label(lab, PREP_TITLE)
	lab.add_theme_color_override("font_color", Color("f4f1ea"))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


func _step_button(text: String, on: bool, cb: Callable, tall: float = 72.0, wide: float = 84.0) -> Button:
	var btn := _bare_button(text, wide, tall)
	_paint_btn(btn, on)
	btn.pressed.connect(cb)
	return btn


func _bare_button(text: String, wide: float, tall: float) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(wide, tall)
	btn.size = Vector2(wide, tall)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_font_override("font", UiFont.font())
	btn.add_theme_font_size_override("font_size", UiFont.px(PREP_BTN))
	return btn


func _paint_btn(btn: Button, on: bool) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("f4d35e") if on else Color("24302a")
	bg.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)
	var col := Color("1c241f") if on else Color("f4f1ea")
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", Color("1c241f") if on else Color("f4d35e"))
	btn.add_theme_color_override("font_pressed_color", Color("1c241f"))


class GridView extends Control:
	var host: CanvasLayer

	func _gui_input(event: InputEvent) -> void:
		if host._drag_on:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var cell: float = host._cell_px()
			host._cursor = Vector2i(int(event.position.x / cell), int(event.position.y / cell))
			host.try_place()

	func _draw() -> void:
		if host == null or not host.state or host._page != "layout":
			return
		var st: StateScript = host.state
		var cell: float = host._cell_px()
		for y in st.grid_h:
			for x in st.grid_w:
				var r := Rect2(Vector2(x, y) * cell, Vector2(cell - 1, cell - 1))
				draw_rect(r, Color("24302a"))
		for d in st.door_cells():
			draw_rect(Rect2(Vector2(d.x, d.y) * cell, Vector2(cell - 1, cell - 1)), Color("3a2a1e"))
		var skip := -1
		if host._drag_on and host._drag_moved:
			skip = int(host._drag_from)
		for i in st.placed.size():
			if i == skip:
				continue
			var it: Dictionary = st.placed[i]
			var col := Color("5c4033")
			var t := String(it["type"])
			if t.begins_with("shelf"):
				col = Color("2f5d50")
			elif t.begins_with("restock"):
				col = Color("c45c26")
			draw_rect(Rect2(Vector2(int(it["x"]), int(it["y"])) * cell, Vector2(int(it["w"]), int(it["h"])) * cell - Vector2(2, 2)), col)
		var ghost := ""
		var rot := 0
		var ignore := -1
		if host._drag_on and host._drag_moved and host._drag_inside:
			ghost = host._drag_type
			rot = host._drag_rot
			ignore = host._drag_from
		elif host._hold_type != "":
			ghost = host._hold_type
			rot = host._hold_rot
		if ghost != "":
			var fp: Vector2i = st.footprint(ghost, rot)
			var ok: bool = st.can_place(ghost, host._cursor.x, host._cursor.y, rot, ignore)
			draw_rect(Rect2(Vector2(host._cursor) * cell, Vector2(fp) * cell), Color("7ec8e3" if ok else "c0392b", 0.65))
		elif not host._drag_on:
			draw_rect(Rect2(Vector2(host._cursor) * cell, Vector2(cell - 1, cell - 1)), Color("f4d35e", 0.8), false, 2.0)


func _cell_px() -> float:
	var side := maxi(state.grid_w, state.grid_h)
	return minf(32.0, 520.0 / float(side))
