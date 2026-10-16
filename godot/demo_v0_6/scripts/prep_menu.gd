extends CanvasLayer
## Shop-prep menus. Stick / WASD move, J or A confirms, ; or B goes back.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const StateScript = preload("res://scripts/game_state.gd")

signal start_day

var demo: Node
var state: StateScript

var _page: String = "scenario"
var _index: int = 0
var _rows: Array[Dictionary] = []
var _qty_sku: String = ""
var _qty_tens: int = 0
var _qty_ones: int = 1
var _hold_type: String = ""
var _hold_rot: int = 0
var _cursor := Vector2i(2, 2)
var _msg: String = ""
var _list: ItemList
var _info: Label
var _title: Label
var _grid: Control


func setup(host: Node) -> void:
	demo = host
	state = host.state
	layer = 30
	_build()
	_show_page("scenario")


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("141c18")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_title = Label.new()
	_title.position = Vector2(28, 16)
	_title.size = Vector2(1220, 36)
	UiFont.apply_label(_title, UiFont.TITLE)
	_title.add_theme_color_override("font_color", Color("f4d35e"))
	add_child(_title)
	_info = Label.new()
	_info.position = Vector2(28, 56)
	_info.size = Vector2(1220, 72)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFont.apply_label(_info, UiFont.BODY)
	_info.add_theme_color_override("font_color", Color("f4f1ea"))
	add_child(_info)
	_list = ItemList.new()
	_list.position = Vector2(28, 140)
	_list.size = Vector2(520, 500)
	_list.allow_reselect = true
	_list.focus_mode = Control.FOCUS_NONE
	_list.add_theme_font_override("font", UiFont.font())
	_list.add_theme_font_size_override("font_size", UiFont.px(UiFont.BODY))
	_list.add_theme_color_override("font_color", Color("f4f1ea"))
	_list.add_theme_color_override("font_selected_color", Color("1c241f"))
	_list.add_theme_color_override("font_hovered_color", Color("f4d35e"))
	_list.item_selected.connect(_on_click)
	add_child(_list)
	_grid = GridView.new()
	_grid.position = Vector2(570, 140)
	_grid.size = Vector2(680, 540)
	_grid.host = self
	add_child(_grid)
	var hint := Label.new()
	hint.position = Vector2(28, 660)
	hint.size = Vector2(1220, 40)
	hint.text = "WASD／搖桿移動　J／A 確定　;／B 返回　店舖設計時 X／K 轉向"
	UiFont.apply_label(hint, UiFont.WORLD)
	hint.add_theme_color_override("font_color", Color("c8d4c5"))
	add_child(hint)


func _show_page(page: String) -> void:
	_page = page
	_index = 0
	_msg = ""
	_qty_sku = ""
	if page != "layout":
		_hold_type = ""
	_refresh()


func _refresh() -> void:
	_rows.clear()
	_list.clear()
	_grid.visible = _page == "layout"
	_list.size.x = 520 if _page == "layout" else 1220
	match _page:
		"scenario":
			_title.text = "Demo v0.6　選擇劇本"
			_info.text = "劇本1 從空店開始，資金 $10000。劇本2、3 帶現成店面和店員。"
			_add("劇本1　從新開始　資金 $10000　LV1　空店", "sc", 1)
			_add("劇本2　LV5　資金 $10000　店規模 2　1 名店員", "sc", 2)
			_add("劇本3　LV10　資金 $99999　三圍 30　店規模 3　2 名店員", "sc", 3)
		"home":
			_title.text = "營運準備　%s" % _header()
			_info.text = _msg if _msg != "" else _home_info()
			_add("角色能力", "go", "stats")
			_add("裝備技能　COST %d/5" % state.cost_sum(), "go", "skills")
			_add("開發／採購貨品", "go", "stock")
			_add("購入商店物品", "go", "furn")
			_add("擴張店面　現時 LV%d　%d×%d" % [state.shop_scale, state.grid_w, state.grid_h], "go", "expand")
			_add("店舖設計", "go", "layout")
			_add("店員　%d 人" % state.clerks.size(), "go", "clerks")
			_add("開始營業", "go", "confirm")
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
	if _rows.size() > 0:
		_index = clampi(_index, 0, _rows.size() - 1)
		_list.select(_index)
		_list.ensure_current_is_visible()
	_grid.queue_redraw()


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
	_title.text = "角色能力　" + _header()
	_info.text = "加點立刻生效。重置退回本劇本基底（劇本3 基底是 10，不是 30）。"
	_add("STR %d　＋" % state.str_stat, "stat", ["str", 1])
	_add("STR %d　－" % state.str_stat, "stat", ["str", -1])
	_add("AGI %d　＋" % state.agi_stat, "stat", ["agi", 1])
	_add("AGI %d　－" % state.agi_stat, "stat", ["agi", -1])
	_add("INT %d　＋" % state.int_stat, "stat", ["int", 1])
	_add("INT %d　－" % state.int_stat, "stat", ["int", -1])
	_add("重置能力值", "reset", null)
	_add("返回", "go", "home")


func _fill_skills() -> void:
	_title.text = "裝備技能　COST %d/5　奧義 %s" % [state.cost_sum(), state.ult_skill().get("name", "")]
	_info.text = "選一格再選技能。奧義不佔 COST。Yes! My Lord! 與全體集資可裝備但不會發動。"
	for i in 5:
		var id := state.slots[i]
		var name := "空" if id == "" else String(Skills.by_id(id).get("name"))
		_add("技能%d　%s" % [i + 1, name], "pick_slot", i)
	_add("奧義　%s" % String(state.ult_skill().get("name")), "pick_slot", 5)
	_add("返回", "go", "home")


func _fill_stock() -> void:
	_title.text = "開發／採購　" + _header()
	if _qty_sku != "":
		var boxes := _qty_tens * 10 + _qty_ones
		var cost := int(Tuning.SKU_COST.get(_qty_sku, 0)) * boxes
		_info.text = "上／下改十位，左／右改個位，確定購買 %s ×%d 箱　$%d" % [Tuning.sku_name(_qty_sku), boxes, cost]
		_add("十位 %d　個位 %d" % [_qty_tens, _qty_ones], "noop", null)
		_add("確定購買", "buy_qty", null)
		_add("取消", "cancel_qty", null)
		return
	_info.text = _msg if _msg != "" else "未開發的先付開發費。已開發的進入數量（0–99 箱）。"
	for sku in Tuning.SELLABLE_SKUS:
		if not state.sku_unlocked(sku):
			_add("%s　LV%d 開放" % [Tuning.sku_name(sku), int(Tuning.SKU_UNLOCK_LV[sku])], "noop", null)
		elif not state.developed.has(sku):
			_add("開發 %s　$%d" % [Tuning.sku_name(sku), int(Tuning.SKU_DEVELOP[sku])], "dev", sku)
		else:
			_add("採購 %s　庫存 %d 箱　$%d/箱" % [Tuning.sku_name(sku), int(state.stock.get(sku, 0)), int(Tuning.SKU_COST[sku])], "qty", sku)
	_add("返回", "go", "home")


func _fill_furn() -> void:
	_title.text = "購入商店物品　" + _header()
	_info.text = _msg if _msg != "" else "買入後到店舖設計才放進店裡。凍櫃 LV4、冰櫃 LV7 才開放。"
	for type in state.FURNITURE.keys():
		var spec: Dictionary = state.FURNITURE[type]
		if not state.furniture_unlocked(type):
			_add("%s　LV%d 開放　$%d" % [spec["name"], int(spec["unlock"]), int(spec["price"])], "noop", null)
		else:
			_add("購入 %s　$%d　擁有 %d　未放置 %d" % [spec["name"], int(spec["price"]), int(state.owned.get(type, 0)), state.unplaced(type)], "buy_f", type)
	_add("返回", "go", "home")


func _fill_expand() -> void:
	_title.text = "擴張　規模 LV%d　地圖 %d×%d" % [state.shop_scale, state.grid_w, state.grid_h]
	_info.text = "LV2＝$3000、15×15，要角色 LV4。LV3＝$6000、20×20，要角色 LV7。每格 64px（文件寫約 9 身位，手機放不下，本 Demo 縮小）。"
	if state.shop_scale < 3:
		var nxt := state.shop_scale + 1
		_add("擴張到規模 LV%d　$%d" % [nxt, int(state.SCALE_COST[nxt])], "expand", null)
	_add("闊度 −", "grid", ["w", -1])
	_add("闊度 ＋", "grid", ["w", 1])
	_add("長度 −", "grid", ["h", -1])
	_add("長度 ＋", "grid", ["h", 1])
	_add("返回", "go", "home")


func _fill_layout() -> void:
	_title.text = "店舖設計　%d×%d　大門在北面中央" % [state.grid_w, state.grid_h]
	if _hold_type != "":
		_info.text = "正在放 %s。移動游標後確定放置，X／K 轉向，取消返回清單。" % state.FURNITURE[_hold_type]["name"]
	else:
		_info.text = _msg if _msg != "" else "選未放置的物品再拿到右圖。游標在物品上按確定可收回。"
	for type in state.FURNITURE.keys():
		var n := state.unplaced(type)
		if n > 0:
			_add("拿起 %s　×%d" % [state.FURNITURE[type]["name"], n], "hold", type)
	_add("收回游標上的物品", "pickup", null)
	_add("返回", "go", "home")


func _fill_clerks() -> void:
	_title.text = "店員　%d／上限 %d　每日開工每人扣 $%d" % [state.clerks.size(), state.hire_limit(), state.WAGE]
	_info.text = "人數不能多過已放置的收銀機，也不能超過店舖規模（LV1＝0、LV2＝1、LV3＝2）。補貨只補已有貨的架。收銀不玩方向指令。"
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
	_info.text = "開工扣工資 $%d。結算時營業額入帳；若營業額低於本輪進貨成本會標虧損，遊戲繼續。被偷不入帳。" % wage
	_add("開始　工資後資金約 $%d" % (state.money - wage), "open", null)
	_add("返回", "go", "home")


func _on_click(index: int) -> void:
	_index = index
	_activate()


func _activate() -> void:
	if _page == "layout" and _hold_type != "":
		try_place()
		return
	if _index < 0 or _index >= _rows.size():
		return
	var row: Dictionary = _rows[_index]
	var action := String(row["action"])
	var arg = row["arg"]
	match action:
		"sc":
			state.apply_scenario(int(arg))
			_show_page("home")
		"go":
			_show_page(String(arg))
		"stat":
			_msg = state.spend_point(String(arg[0]), int(arg[1]))
			_refresh()
		"reset":
			state.reset_stats()
			_refresh()
		"pick_slot":
			_page = "skill_pick"
			_fill_skill_pick(int(arg))
		"equip":
			_msg = state.equip(int(arg[0]), String(arg[1]))
			_show_page("skills")
			if _msg != "":
				_info.text = _msg
		"unequip":
			state.unequip(int(arg))
			_show_page("skills")
		"dev":
			_msg = state.develop(String(arg))
			_refresh()
		"qty":
			_qty_sku = String(arg)
			_qty_tens = 0
			_qty_ones = 1
			_refresh()
		"buy_qty":
			_msg = state.buy_stock(_qty_sku, _qty_tens * 10 + _qty_ones)
			_qty_sku = ""
			_refresh()
		"cancel_qty":
			_qty_sku = ""
			_refresh()
		"buy_f":
			_msg = state.buy_furniture(String(arg))
			_refresh()
		"expand":
			_msg = state.expand()
			_refresh()
		"grid":
			var w := state.grid_w
			var h := state.grid_h
			if String(arg[0]) == "w":
				w += int(arg[1])
			else:
				h += int(arg[1])
			_msg = state.set_grid(w, h)
			_refresh()
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
			_msg = state.hire()
			_refresh()
		"role":
			state.cycle_role(int(arg))
			_refresh()
		"reg":
			state.cycle_register(int(arg))
			_refresh()
		"fire":
			state.fire(int(arg))
			_refresh()
		"open":
			state.begin_day()
			visible = false
			set_process_unhandled_input(false)
			start_day.emit()
		_:
			pass


func _fill_skill_pick(slot_i: int) -> void:
	_page = "skill_pick"
	_rows.clear()
	_list.clear()
	_title.text = "選擇技能　格 %s" % ("奧義" if slot_i == 5 else str(slot_i + 1))
	_info.text = "COST 合計不能超過 5。"
	var pool: Array = Skills.ULTS if slot_i == 5 else []
	if slot_i < 5:
		pool = []
		pool.append_array(Skills.ACTIVES)
		pool.append_array(Skills.PASSIVES)
	for sk in pool:
		_add("%s　COST%d　%s" % [sk["name"], int(sk["cost"]), sk["blurb"]], "equip", [slot_i, sk["id"]])
	if slot_i < 5:
		_add("卸下", "unequip", slot_i)
	_add("返回", "go", "skills")
	_index = 0
	if _rows.size():
		_list.select(0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		_key((event as InputEventKey).physical_keycode)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				_activate()
			JOY_BUTTON_B:
				_back()
			JOY_BUTTON_DPAD_UP:
				_move(0, -1)
			JOY_BUTTON_DPAD_DOWN:
				_move(0, 1)
			JOY_BUTTON_DPAD_LEFT:
				_move(-1, 0)
			JOY_BUTTON_DPAD_RIGHT:
				_move(1, 0)
			JOY_BUTTON_X:
				_rotate()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
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


func _key(key: int) -> void:
	match key:
		KEY_W, KEY_UP:
			_move(0, -1)
		KEY_S, KEY_DOWN:
			_move(0, 1)
		KEY_A, KEY_LEFT:
			_move(-1, 0)
		KEY_D, KEY_RIGHT:
			_move(1, 0)
		KEY_J, KEY_ENTER:
			_activate()
		KEY_SEMICOLON, KEY_BACKSPACE, KEY_ESCAPE:
			_back()
		KEY_K, KEY_X:
			_rotate()


func _move(x: int, y: int) -> void:
	if _page == "layout" and _hold_type != "":
		_cursor.x = clampi(_cursor.x + x, 0, state.grid_w - 1)
		_cursor.y = clampi(_cursor.y + y, 0, state.grid_h - 1)
		_grid.queue_redraw()
		if Input.is_physical_key_pressed(KEY_J):
			pass
		return
	if _qty_sku != "" and _page == "stock":
		if y < 0:
			_qty_tens = mini(9, _qty_tens + 1)
		elif y > 0:
			_qty_tens = maxi(0, _qty_tens - 1)
		elif x > 0:
			_qty_ones = mini(9, _qty_ones + 1)
		elif x < 0:
			_qty_ones = maxi(0, _qty_ones - 1)
		if _qty_tens == 0 and _qty_ones == 0:
			_qty_ones = 1
		_refresh()
		return
	if _rows.is_empty():
		return
	if y < 0 or x < 0:
		_index = posmod(_index - 1, _rows.size())
	elif y > 0 or x > 0:
		_index = posmod(_index + 1, _rows.size())
	_list.select(_index)
	_list.ensure_current_is_visible()


func _rotate() -> void:
	if _hold_type == "":
		return
	_hold_rot = (_hold_rot + 1) % 4
	_grid.queue_redraw()


func _back() -> void:
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


func try_place() -> void:
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


class GridView extends Control:
	var host: CanvasLayer

	func _gui_input(event: InputEvent) -> void:
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
		for it in st.placed:
			var col := Color("5c4033")
			var t := String(it["type"])
			if t.begins_with("shelf"):
				col = Color("2f5d50")
			elif t.begins_with("restock"):
				col = Color("c45c26")
			draw_rect(Rect2(Vector2(int(it["x"]), int(it["y"])) * cell, Vector2(int(it["w"]), int(it["h"])) * cell - Vector2(2, 2)), col)
		if host._hold_type != "":
			var fp: Vector2i = st.footprint(host._hold_type, host._hold_rot)
			var ok: bool = st.can_place(host._hold_type, host._cursor.x, host._cursor.y, host._hold_rot)
			draw_rect(Rect2(Vector2(host._cursor) * cell, Vector2(fp) * cell), Color("7ec8e3" if ok else "c0392b", 0.65))
		else:
			draw_rect(Rect2(Vector2(host._cursor) * cell, Vector2(cell - 1, cell - 1)), Color("f4d35e", 0.8), false, 2.0)


func _cell_px() -> float:
	var side := maxi(state.grid_w, state.grid_h)
	return minf(32.0, 520.0 / float(side))
