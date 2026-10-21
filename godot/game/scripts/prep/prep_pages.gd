extends RefCounted
## Prep menu page fillers — one match arm per page id.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const PrepWidgets = preload("res://scripts/prep/prep_widgets.gd")


static func apply_panel_layout(menu: CanvasLayer) -> void:
	var qty_on := menu._page == "stock" and menu._qty_sku != ""
	menu._grid.visible = menu._page == "layout"
	menu._stats_panel.visible = menu._page == "stats"
	menu._size_panel.visible = menu._page == "layout"
	menu._qty_panel.visible = qty_on
	menu._list.visible = not qty_on
	if menu._back_btn:
		menu._back_btn.visible = menu._page != "scenario" and menu._page != "home"
	if menu._page == "stats":
		menu._list.position = Vector2(24, 430)
		menu._list.size = Vector2(1232, 220)
		menu._list.z_index = 2
	elif menu._page == "layout":
		menu._list.z_index = 0
		menu._list.position = Vector2(24, 360)
		menu._list.size = Vector2(520, 276)
	else:
		menu._list.z_index = 0
		menu._list.position = Vector2(24, 168)
		menu._list.size = Vector2(1232, 430)


static func fill(menu: CanvasLayer, page: String) -> void:
	match page:
		"scenario":
			_scenario(menu)
		"home":
			_home(menu)
		"stats":
			_stats(menu)
		"skills":
			_skills(menu)
		"stock":
			_stock(menu)
		"furn":
			_furn(menu)
		"expand":
			_expand(menu)
		"layout":
			_layout(menu)
		"clerks":
			_clerks(menu)
		"confirm":
			_confirm(menu)
		"skill_pick":
			pass
		_:
			menu._title.text = page
			menu._info.text = ""
			menu._add("返回", "go", "home")


static func fill_skill_pick(menu: CanvasLayer, slot_i: int) -> void:
	menu._page = "skill_pick"
	menu._qty_panel.visible = false
	menu._size_panel.visible = false
	menu._stats_panel.visible = false
	menu._grid.visible = false
	menu._list.visible = true
	menu._list.position = Vector2(24, 168)
	menu._list.size = Vector2(1232, 430)
	menu._rows.clear()
	menu._list.clear()
	menu._title.text = "選擇技能"
	menu._info.text = "格 %s。名字前面是性質：主動、被動或奧義。COST 合計不能超過 5。" % ("奧義" if slot_i == 5 else str(slot_i + 1))
	var pool: Array = []
	if slot_i == 5:
		pool.append_array(Skills.ULTS)
	else:
		pool.append_array(Skills.ACTIVES)
		pool.append_array(Skills.PASSIVES)
	for sk in pool:
		menu._add("%s　%s　COST%d　%s" % [_kind_label(String(sk["kind"])), sk["name"], int(sk["cost"]), sk["blurb"]], "equip", [slot_i, sk["id"]])
	if slot_i < 5:
		menu._add("卸下", "unequip", slot_i)
	menu._add("返回", "go", "skills")
	menu._index = 0
	if menu._rows.size():
		menu._select_row(0)


static func _scenario(menu: CanvasLayer) -> void:
	menu._title.text = "選擇劇本"
	menu._info.text = "劇本1 從空店開始，資金 $10000。劇本2、3 帶現成店面和店員。"
	menu._add("劇本1　從新開始　資金 $10000　LV1　空店", "sc", 1)
	menu._add("劇本2　LV5　資金 $10000　店規模 2　1 名店員", "sc", 2)
	menu._add("劇本3　LV10　資金 $99999　三圍 30　店規模 3　2 名店員", "sc", 3)


static func _home(menu: CanvasLayer) -> void:
	menu._title.text = "營運準備"
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else menu._home_info())
	menu._add("角色能力", "go", "stats")
	menu._add("裝備技能　COST %d/5" % menu.state.cost_sum(), "go", "skills")
	menu._add("開發／採購貨品", "go", "stock")
	menu._add("購入商店物品", "go", "furn")
	menu._add("擴張店面　現時 LV%d　%d×%d" % [menu.state.shop_scale, menu.state.grid_w, menu.state.grid_h], "go", "expand")
	menu._add("店舖設計", "go", "layout")
	menu._add("店員　%d 人" % menu.state.clerks.size(), "go", "clerks")
	menu._add("開始營業", "try_open", null)
	menu._add("清除存檔並重選劇本", "wipe_save", null)


static func _stats(menu: CanvasLayer) -> void:
	menu._title.text = "角色能力"
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else "按 + 加一點，按 - 減一點。向下可到重置和返回。")
	menu._list.visible = false
	PrepWidgets.clear(menu._stats_panel)
	_add_stat_row(menu, "STR", "str", menu.state.str_stat, 0)
	_add_stat_row(menu, "AGI", "agi", menu.state.agi_stat, 1)
	_add_stat_row(menu, "INT", "int", menu.state.int_stat, 2)
	menu._stats_panel.add_child(PrepWidgets.step_button("重置能力值", menu._stat_row == 3, menu._on_stat_reset, 64, 420))
	menu._stats_panel.add_child(PrepWidgets.step_button("返回", menu._stat_row == 4, menu._on_stat_back, 64, 420))


static func _add_stat_row(menu: CanvasLayer, title: String, stat: String, value: int, row: int) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(PrepWidgets.name_label("%s  %d" % [title, value], 220, 64))
	line.add_child(PrepWidgets.step_button("+", menu._stat_row == row and menu._stat_side == 1, menu._on_stat_pressed.bind(stat, 1, row), 64))
	line.add_child(PrepWidgets.step_button("-", menu._stat_row == row and menu._stat_side == -1, menu._on_stat_pressed.bind(stat, -1, row), 64))
	menu._stats_panel.add_child(line)


static func _skills(menu: CanvasLayer) -> void:
	menu._title.text = "裝備技能"
	var ult_name := String(menu.state.ult_skill().get("name", ""))
	menu._info.text = "COST %d/5　奧義 %s\n選一格再選技能。奧義不佔 COST。" % [menu.state.cost_sum(), ult_name]
	for i in 5:
		var id := menu.state.slots[i]
		var name := "空"
		var kind := ""
		if id != "":
			var sk := Skills.by_id(id)
			name = String(sk.get("name"))
			kind = _kind_label(String(sk.get("kind"))) + "　"
		menu._add("技能%d　%s%s" % [i + 1, kind, name], "pick_slot", i)
	var ult := menu.state.ult_skill()
	menu._add("奧義　%s" % String(ult.get("name")), "pick_slot", 5)
	menu._add("返回", "go", "home")


static func _stock(menu: CanvasLayer) -> void:
	if menu._qty_sku != "":
		var name := Tuning.sku_name(menu._qty_sku)
		var each := int(Tuning.SKU_COST.get(menu._qty_sku, 0))
		menu._title.text = "採購 %s" % name
		menu._info.text = "庫存 %d 箱　$%d／箱。中間是箱數（01–99），按按鈕加減。" % [int(menu.state.stock.get(menu._qty_sku, 0)), each]
		_build_qty(menu, each * menu._qty_boxes)
		return
	menu._title.text = "開發／採購"
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else "罐頭是初始貨物，不用開發就能採購。其他未開發的先付開發費。")
	for sku in Tuning.SELLABLE_SKUS:
		if not menu.state.sku_unlocked(sku):
			menu._add("%s　LV%d 開放" % [Tuning.sku_name(sku), int(Tuning.SKU_UNLOCK_LV[sku])], "locked_sku", sku)
		elif not menu.state.developed.has(sku):
			menu._add("開發 %s　$%d" % [Tuning.sku_name(sku), int(Tuning.SKU_DEVELOP[sku])], "dev", sku)
		else:
			menu._add("採購 %s　庫存 %d 箱　$%d/箱" % [Tuning.sku_name(sku), int(menu.state.stock.get(sku, 0)), int(Tuning.SKU_COST[sku])], "qty", sku)
	menu._add("返回", "go", "home")


static func _build_qty(menu: CanvasLayer, total: int) -> void:
	PrepWidgets.clear(menu._qty_panel)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 16)
	steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	steps.add_child(_qty_button(menu, "-10", 0))
	steps.add_child(_qty_button(menu, "-1", 1))
	steps.add_child(_qty_figure(menu))
	steps.add_child(_qty_button(menu, "+1", 2))
	steps.add_child(_qty_button(menu, "+10", 3))
	menu._qty_panel.add_child(steps)
	var sum := Label.new()
	sum.text = "合計 $%d" % total
	sum.custom_minimum_size = Vector2(400, 48)
	UiFont.apply_label(sum, PrepWidgets.PREP_TITLE)
	sum.add_theme_color_override("font_color", Color("e07a5f") if total > menu.state.money else Color("f4d35e"))
	menu._qty_panel.add_child(sum)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 24)
	acts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ok := PrepWidgets.bare_button("確定購買", 280, 80)
	PrepWidgets.paint_btn(ok, menu._qty_focus == 4)
	ok.pressed.connect(menu._on_qty_pressed.bind(4))
	acts.add_child(ok)
	var cancel := PrepWidgets.bare_button("取消", 280, 80)
	PrepWidgets.paint_btn(cancel, menu._qty_focus == 5)
	cancel.pressed.connect(menu._on_qty_pressed.bind(5))
	acts.add_child(cancel)
	menu._qty_panel.add_child(acts)


static func _qty_figure(menu: CanvasLayer) -> Control:
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
	num.text = "%02d 箱" % menu._qty_boxes
	num.position = Vector2(0, 0)
	num.size = Vector2(210, 84)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiFont.apply_label(num, PrepWidgets.PREP_NUM)
	num.add_theme_color_override("font_color", Color("f4f1ea"))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(num)
	return holder


static func _qty_button(menu: CanvasLayer, text: String, focus_i: int) -> Button:
	var btn := PrepWidgets.bare_button(text, 120, 84)
	PrepWidgets.paint_btn(btn, menu._qty_focus == focus_i)
	btn.pressed.connect(menu._on_qty_pressed.bind(focus_i))
	return btn


static func _furn(menu: CanvasLayer) -> void:
	menu._title.text = "購入商店物品"
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else "買入後到店舖設計才放進店裡。展示貨架有 4、8、12、24 件，越大越貴。凍櫃 LV4、冰櫃 LV7 才開放。")
	for type in menu.state.FURNITURE.keys():
		var spec: Dictionary = menu.state.FURNITURE[type]
		if not menu.state.furniture_unlocked(type):
			menu._add("%s　LV%d 開放　$%d" % [spec["name"], int(spec["unlock"]), int(spec["price"])], "locked_furn", type)
		else:
			menu._add("購入 %s　$%d　擁有 %d　未放置 %d" % [spec["name"], int(spec["price"]), int(menu.state.owned.get(type, 0)), menu.state.unplaced(type)], "buy_f", type)
	menu._add("返回", "go", "home")


static func _expand(menu: CanvasLayer) -> void:
	menu._title.text = "擴張店面"
	menu._info.text = "現時規模 LV%d　地圖 %d×%d　總面積 %d／%d。闊度和長度在店舖設計裡調，一邊減少就能加另一邊。\nLV2＝$3000、總面積 225，要角色 LV4。LV3＝$6000、總面積 400，要角色 LV7。" % [menu.state.shop_scale, menu.state.grid_w, menu.state.grid_h, menu.state.grid_w * menu.state.grid_h, menu.state.area_cap()]
	if menu.state.shop_scale < 3:
		var nxt := menu.state.shop_scale + 1
		menu._add("擴張到規模 LV%d　$%d" % [nxt, int(menu.state.SCALE_COST[nxt])], "expand", null)
	else:
		menu._add("已是最大規模", "expand_max", null)
	menu._add("返回", "go", "home")


static func _layout(menu: CanvasLayer) -> void:
	menu._title.text = "店舖設計"
	if menu._hold_type != "":
		menu._info.text = "正在放 %s。拖到右圖放開，或移動游標後確定。X／K 轉向。" % menu.state.FURNITURE[menu._hold_type]["name"]
	elif menu._msg != "":
		menu._info.text = menu._msg
	else:
		menu._info.text = "拖動左邊的物品放到右圖。圖上的物品可以拖去別的格子，拖出圖外或輕點就收回。"
	PrepWidgets.clear(menu._size_panel)
	_add_size_row(menu, "闊度", "w", menu.state.grid_w, 0)
	_add_size_row(menu, "長度", "h", menu.state.grid_h, 1)
	var area := PrepWidgets.name_label("總面積  %d／%d" % [menu.state.grid_w * menu.state.grid_h, menu.state.area_cap()], 420, 48)
	area.add_theme_color_override("font_color", Color("f4d35e"))
	menu._size_panel.add_child(area)
	for type in menu.state.FURNITURE.keys():
		var n := menu.state.unplaced(type)
		if n > 0:
			menu._add("拖放 %s　×%d" % [menu.state.FURNITURE[type]["name"], n], "hold", type)
	menu._add("收回游標上的物品", "pickup", null)
	menu._add("返回", "go", "home")
	menu._grid.queue_redraw()


static func _add_size_row(menu: CanvasLayer, title: String, axis: String, value: int, row: int) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(PrepWidgets.name_label("%s  %d" % [title, value], 180))
	line.add_child(PrepWidgets.step_button("+", menu._on_size_btns and menu._size_row == row and menu._size_side == 1, menu._on_size_pressed.bind(axis, 1, row)))
	line.add_child(PrepWidgets.step_button("-", menu._on_size_btns and menu._size_row == row and menu._size_side == -1, menu._on_size_pressed.bind(axis, -1, row)))
	menu._size_panel.add_child(line)


static func _clerks(menu: CanvasLayer) -> void:
	menu._title.text = "店員"
	menu._info.text = "現有 %d／上限 %d　每日開工每人扣 $%d\n人數不能多過已放置的收銀機，也不能超過店舖規模。" % [menu.state.clerks.size(), menu.state.hire_limit(), menu.state.WAGE]
	menu._add("召募", "hire", null)
	for i in menu.state.clerks.size():
		var c: Dictionary = menu.state.clerks[i]
		var role := "收銀" if String(c["role"]) == "cashier" else "補貨"
		menu._add("店員%d　%s　收銀機 %d　（確定切崗位）" % [i + 1, role, int(c["register"]) + 1], "role", i)
		if String(c["role"]) == "cashier":
			menu._add("　改派收銀機", "reg", i)
		menu._add("　解僱店員%d" % (i + 1), "fire", i)
	menu._add("返回", "go", "home")


static func _confirm(menu: CanvasLayer) -> void:
	menu._title.text = "開始營業？"
	var wage := menu.state.WAGE * menu.state.clerks.size()
	menu._info.text = "開工扣工資 $%d。結算時營業額入帳；若營業額低於本輪進貨成本會標虧損，遊戲繼續。" % wage
	menu._add("開始　工資後資金約 $%d" % (menu.state.money - wage), "open", null)
	menu._add("返回", "go", "home")


static func _kind_label(kind: String) -> String:
	match kind:
		"active":
			return "主動"
		"passive":
			return "被動"
		"ultimate":
			return "奧義"
		_:
			return kind
