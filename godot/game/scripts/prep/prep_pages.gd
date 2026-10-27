extends RefCounted
## Prep menu page fillers — one match arm per page id.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const PrepWidgets = preload("res://scripts/prep/prep_widgets.gd")
const ProductVersion = preload("res://scripts/product_version.gd")
const SfxCatalog = preload("res://scripts/sfx_catalog.gd")


static func is_hub_page(page: String) -> bool:
	return page == "home" or page.begins_with("hub_")


static func parent_page(page: String) -> String:
	match page:
		"hub_char", "hub_goods", "hub_shop", "hub_sys", "clerks", "confirm", "elite_test":
			return "home"
		"stats", "skills":
			return "hub_char"
		"skill_set", "skill_rename":
			return "skills"
		"skill_pick":
			return "skill_set"
		"develop", "buy":
			return "hub_goods"
		"furn", "expand", "layout":
			return "hub_shop"
		"sfx":
			return "hub_sys"
		_:
			return "home"


static func apply_panel_layout(menu: CanvasLayer) -> void:
	var qty_on: bool = menu._page == "buy" and menu._qty_sku != ""
	var hub := is_hub_page(menu._page)
	menu._grid.visible = menu._page == "layout"
	menu._stats_panel.visible = menu._page == "stats"
	menu._size_panel.visible = menu._page == "layout"
	menu._qty_panel.visible = qty_on
	menu._list.visible = not qty_on and not hub
	if menu._hub_panel:
		menu._hub_panel.visible = hub
	if menu._open_bar:
		menu._open_bar.visible = menu._page == "home"
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
	elif hub:
		menu._list.z_index = 0
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
		"hub_char":
			_hub_char(menu)
		"hub_goods":
			_hub_goods(menu)
		"hub_shop":
			_hub_shop(menu)
		"hub_sys":
			_hub_sys(menu)
		"stats":
			_stats(menu)
		"skills":
			_skills(menu)
		"skill_set":
			_skill_set(menu)
		"skill_rename":
			_skill_rename(menu)
		"develop":
			_develop(menu)
		"buy":
			_buy(menu)
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
		"sfx":
			_sfx(menu)
		"elite_test":
			_elite_test(menu)
		"skill_pick":
			pass
		_:
			menu._title.text = page
			menu._info.text = ""
			menu._add(Loc.t("prep.back"), "go", parent_page(page))


static func fill_skill_pick(menu: CanvasLayer, slot_i: int) -> void:
	menu._page = "skill_pick"
	menu._qty_panel.visible = false
	menu._size_panel.visible = false
	menu._stats_panel.visible = false
	menu._grid.visible = false
	if menu._hub_panel:
		menu._hub_panel.visible = false
	if menu._open_bar:
		menu._open_bar.visible = false
	menu._list.visible = true
	menu._list.position = Vector2(24, 168)
	menu._list.size = Vector2(1232, 430)
	menu._rows.clear()
	menu._list.clear()
	menu._title.text = Loc.t("prep.skill_pick.title")
	var slot_lbl := Loc.t("prep.skill_pick.ult_slot") if slot_i == 5 else str(slot_i + 1)
	var set_name: String = menu.state.skill_set_name(menu._skill_set)
	menu._info.text = Loc.t("prep.skill_pick.info", [set_name, slot_lbl])
	var pool: Array = []
	if slot_i == 5:
		pool.append_array(Skills.ULTS)
	else:
		pool.append_array(Skills.ACTIVES)
		pool.append_array(Skills.PASSIVES)
	for sk in pool:
		menu._add("%s　%s　COST%d　%s" % [_kind_label(String(sk["kind"])), sk["name"], int(sk["cost"]), sk["blurb"]], "equip", [slot_i, sk["id"]])
	menu._add(Loc.t("prep.skill_pick.unequip"), "unequip", slot_i)
	menu._add(Loc.t("prep.back"), "go", "skill_set")
	menu._index = 0
	if menu._rows.size():
		menu._select_row(0)


static func _scenario(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.scenario.title")
	menu._info.text = Loc.t("prep.scenario.info")
	menu._add(Loc.t("prep.scenario.s1"), "sc", 1)
	menu._add(Loc.t("prep.scenario.s2"), "sc", 2)
	menu._add(Loc.t("prep.scenario.s3"), "sc", 3)


static func _home(menu: CanvasLayer) -> void:
	menu._hub_cols = 3
	menu._title.text = Loc.t("prep.home.title")
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else menu._home_info())
	menu._add_hub(Loc.t("prep.hub.char"), "go", "hub_char", "char")
	menu._add_hub(Loc.t("prep.hub.goods"), "go", "hub_goods", "goods")
	menu._add_hub(Loc.t("prep.hub.shop"), "go", "hub_shop", "shop")
	menu._add_hub(Loc.t("prep.hub.staff", [menu.state.clerks.size()]), "go", "clerks", "staff")
	menu._add_hub(Loc.t("prep.hub.sys"), "go", "hub_sys", "sys")
	menu._rebuild_hub_tiles()
	menu._setup_open_bar()


static func _hub_char(menu: CanvasLayer) -> void:
	menu._hub_cols = 1
	menu._title.text = Loc.t("prep.hub.char")
	menu._info.text = menu._pair(menu._header(), Loc.t("prep.hub.char_info"))
	menu._add_hub(Loc.t("prep.home.stats"), "go", "stats", "stats")
	menu._add_hub(Loc.t("prep.home.skills_short", [menu.state.cost_sum()]), "go", "skills", "skills")
	menu._add_hub(Loc.t("prep.home.look"), "locked_look", null, "look", true, Loc.t("prep.locked"))
	menu._rebuild_hub_tiles()


static func _hub_goods(menu: CanvasLayer) -> void:
	menu._hub_cols = 1
	menu._title.text = Loc.t("prep.hub.goods")
	menu._info.text = menu._pair(menu._header(), Loc.t("prep.hub.goods_info"))
	menu._add_hub(Loc.t("prep.home.develop"), "go", "develop", "develop")
	menu._add_hub(Loc.t("prep.home.buy"), "go", "buy", "buy")
	menu._rebuild_hub_tiles()


static func _hub_shop(menu: CanvasLayer) -> void:
	menu._hub_cols = 1
	menu._title.text = Loc.t("prep.hub.shop")
	menu._info.text = menu._pair(menu._header(), Loc.t("prep.hub.shop_info", [
		menu.state.shop_scale, menu.state.grid_w, menu.state.grid_h,
	]))
	menu._add_hub(Loc.t("prep.home.furn"), "go", "furn", "furn")
	menu._add_hub(Loc.t("prep.home.expand_short"), "go", "expand", "expand")
	menu._add_hub(Loc.t("prep.home.layout"), "go", "layout", "layout")
	menu._rebuild_hub_tiles()


static func _hub_sys(menu: CanvasLayer) -> void:
	menu._hub_cols = 1
	menu._title.text = Loc.t("prep.hub.sys")
	menu._info.text = menu._pair(menu._header(), Loc.t("prep.hub.sys_info"))
	if ProductVersion.test_tools_enabled():
		menu._add_hub(Loc.t("prep.home.test_money"), "test_money", null, "money")
		menu._add_hub(Loc.t("prep.home.sfx_test"), "go", "sfx", "sfx")
	menu._add_hub(Loc.t("prep.home.wipe"), "wipe_save", null, "wipe")
	menu._rebuild_hub_tiles()


static func _stats(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.stats.title")
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else Loc.t("prep.stats.info"))
	menu._list.visible = false
	PrepWidgets.clear(menu._stats_panel)
	_add_stat_row(menu, "STR", "str", menu.state.str_stat, 0)
	_add_stat_row(menu, "AGI", "agi", menu.state.agi_stat, 1)
	_add_stat_row(menu, "INT", "int", menu.state.int_stat, 2)
	var reset_lbl := "%s（$%d）" % [Loc.t("prep.stats.reset"), menu.state.reset_stats_cost()]
	menu._stats_panel.add_child(PrepWidgets.step_button(reset_lbl, menu._stat_row == 3, menu._on_stat_reset, PrepWidgets.STEP_BTN_H, 480))
	menu._stats_panel.add_child(PrepWidgets.step_button(Loc.t("prep.back"), menu._stat_row == 4, menu._on_stat_back, PrepWidgets.STEP_BTN_H, 480))

static func _add_stat_row(menu: CanvasLayer, title: String, stat: String, value: int, row: int) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(PrepWidgets.name_label("%s  %d" % [title, value], 240, PrepWidgets.STEP_BTN_H))
	line.add_child(PrepWidgets.step_button("+", menu._stat_row == row and menu._stat_side == 1, menu._on_stat_pressed.bind(stat, 1, row)))
	line.add_child(PrepWidgets.step_button("-", menu._stat_row == row and menu._stat_side == -1, menu._on_stat_pressed.bind(stat, -1, row)))
	menu._stats_panel.add_child(line)


static func _skills(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.skills.title")
	var selected := int(menu.state.skill_set_index)
	var using: String = menu.state.skill_set_name(selected)
	menu._info.text = Loc.t("prep.skills.info", [using, menu.state.cost_sum(), _ult_label(menu.state.ult_skill())])
	if menu._msg != "":
		menu._info.text = menu._pair(menu._info.text, menu._msg)
	for i in menu.state.skill_sets.size():
		var mark := "▶ " if i == selected else "　"
		var ult := _ult_label(menu.state.ult_of(i))
		menu._add(Loc.t("prep.skills.set_row", [mark, menu.state.skill_set_name(i), menu.state.cost_sum_of(i), ult]), "edit_set", i)
	menu._add(Loc.t("prep.back"), "go", "hub_char")


static func _skill_set(menu: CanvasLayer) -> void:
	var i := int(menu._skill_set)
	var set_name: String = menu.state.skill_set_name(i)
	menu._title.text = set_name
	var using := i == int(menu.state.skill_set_index)
	var status := Loc.t("prep.skill_set.using") if using else Loc.t("prep.skill_set.not_using")
	menu._info.text = Loc.t("prep.skill_set.info", [menu.state.cost_sum_of(i), status])
	if menu._msg != "":
		menu._info.text = menu._pair(menu._info.text, menu._msg)
	if using:
		menu._add(Loc.t("prep.skill_set.using"), "use_set", i)
	else:
		menu._add(Loc.t("prep.skill_set.use"), "use_set", i)
	menu._add(Loc.t("prep.skill_set.rename"), "rename_open", i)
	var pack: Dictionary = menu.state.skill_sets[i]
	var set_slots: Array = pack.get("slots", [])
	for s in 5:
		var id := ""
		if s < set_slots.size():
			id = String(set_slots[s])
		var skill_name := Loc.t("prep.skill_set.empty")
		var kind := ""
		if id != "":
			var sk: Dictionary = Skills.by_id(id)
			skill_name = String(sk.get("name", id))
			kind = _kind_label(String(sk.get("kind"))) + "　"
		menu._add(Loc.t("prep.skill_set.slot", [s + 1, kind, skill_name]), "pick_slot", s)
	menu._add(Loc.t("prep.skill_set.ult", [_ult_label(menu.state.ult_of(i))]), "pick_slot", 5)
	menu._add(Loc.t("prep.back"), "go", "skills")


static func _skill_rename(menu: CanvasLayer) -> void:
	var i := int(menu._skill_set)
	var draft := String(menu._rename_draft)
	var shown := draft if draft != "" else Loc.t("prep.skill_rename.draft_empty")
	menu._title.text = Loc.t("prep.skill_rename.title")
	menu._info.text = Loc.t("prep.skill_rename.info", [shown, menu.state.default_skill_set_name(i)])
	menu._add(Loc.t("prep.skill_rename.save"), "rename_save", i)
	menu._add(Loc.t("prep.skill_rename.backspace"), "rename_backspace", null)
	menu._add(Loc.t("prep.skill_rename.clear"), "rename_clear", null)
	if bool(menu._rename_lower):
		menu._add(Loc.t("prep.skill_rename.upper"), "rename_case", null)
	else:
		menu._add(Loc.t("prep.skill_rename.lower"), "rename_case", null)
	var letters := "abcdefghijklmnopqrstuvwxyz" if bool(menu._rename_lower) else "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for n in letters.length():
		var ch := letters.substr(n, 1)
		menu._add(ch, "rename_ch", ch)
	menu._add(Loc.t("prep.back"), "go", "skill_set")


static func _ult_label(sk: Dictionary) -> String:
	if sk.is_empty():
		return "空"
	var n := String(sk.get("name", ""))
	return n if n != "" else "空"


static func _develop(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.develop.title")
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else Loc.t("prep.develop.info"))
	for sku in Tuning.SELLABLE_SKUS:
		if not menu.state.sku_unlocked(sku):
			menu._add("%s　LV%d 開放" % [Tuning.sku_name(sku), int(Tuning.SKU_UNLOCK_LV[sku])], "locked_sku", sku)
		elif menu.state.developed.has(sku):
			menu._add("%s　已開發" % Tuning.sku_name(sku), "noop", sku)
		else:
			menu._add("開發 %s　$%d" % [Tuning.sku_name(sku), int(Tuning.SKU_DEVELOP[sku])], "dev", sku)
	menu._add(Loc.t("prep.back"), "go", "hub_goods")


static func _buy(menu: CanvasLayer) -> void:
	if menu._qty_sku != "":
		var name := Tuning.sku_name(menu._qty_sku)
		var each := int(Tuning.SKU_COST.get(menu._qty_sku, 0))
		menu._title.text = Loc.t("prep.stock.qty_title", [name])
		menu._info.text = Loc.t("prep.stock.qty_info", [int(menu.state.stock.get(menu._qty_sku, 0)), each])
		_build_qty(menu, each * menu._qty_boxes)
		return
	menu._title.text = Loc.t("prep.buy.title")
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else Loc.t("prep.buy.info"))
	for sku in Tuning.SELLABLE_SKUS:
		if not menu.state.sku_unlocked(sku):
			menu._add("%s　LV%d 開放" % [Tuning.sku_name(sku), int(Tuning.SKU_UNLOCK_LV[sku])], "locked_sku", sku)
		elif not menu.state.developed.has(sku):
			menu._add("%s　尚未開發" % Tuning.sku_name(sku), "need_develop", sku)
		else:
			menu._add("採購 %s　庫存 %d 箱　$%d/箱" % [Tuning.sku_name(sku), int(menu.state.stock.get(sku, 0)), int(Tuning.SKU_COST[sku])], "qty", sku)
	menu._add(Loc.t("prep.back"), "go", "hub_goods")

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
	var ok := PrepWidgets.bare_button("確定購買", 300, 88)
	PrepWidgets.paint_btn(ok, menu._qty_focus == 4)
	ok.pressed.connect(menu._on_qty_pressed.bind(4))
	acts.add_child(ok)
	var cancel := PrepWidgets.bare_button(Loc.t("prep.chrome.dialog_no"), 300, 88)
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
	var btn := PrepWidgets.bare_button(text, 128, 88)
	PrepWidgets.paint_btn(btn, menu._qty_focus == focus_i)
	btn.pressed.connect(menu._on_qty_pressed.bind(focus_i))
	return btn


static func _furn(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.furn.title")
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else Loc.t("prep.furn.info"))
	for type in menu.state.FURNITURE.keys():
		var spec: Dictionary = menu.state.FURNITURE[type]
		if not menu.state.furniture_unlocked(type):
			menu._add("%s　LV%d 開放　$%d" % [spec["name"], int(spec["unlock"]), int(spec["price"])], "locked_furn", type)
		else:
			menu._add("購入 %s　$%d　擁有 %d　未放置 %d" % [spec["name"], int(spec["price"]), int(menu.state.owned.get(type, 0)), menu.state.unplaced(type)], "buy_f", type)
	menu._add(Loc.t("prep.back"), "go", "hub_shop")


static func _expand(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.expand.title")
	menu._info.text = Loc.t("prep.expand.info", [
		menu.state.shop_scale, menu.state.grid_w, menu.state.grid_h,
		menu.state.grid_w * menu.state.grid_h, menu.state.area_cap(),
	])
	if menu.state.shop_scale < 3:
		var nxt: int = int(menu.state.shop_scale) + 1
		menu._add("擴張到規模 LV%d　$%d" % [nxt, int(menu.state.SCALE_COST[nxt])], "expand", null)
	else:
		menu._add("已是最大規模", "expand_max", null)
	menu._add(Loc.t("prep.back"), "go", "hub_shop")


static func _layout(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.layout.title")
	if menu._hold_type != "":
		menu._info.text = Loc.t("prep.layout.holding", [menu.state.FURNITURE[menu._hold_type]["name"]])
	elif menu._msg != "":
		menu._info.text = menu._msg
	else:
		menu._info.text = Loc.t("prep.layout.info")
	PrepWidgets.clear(menu._size_panel)
	_add_size_row(menu, "闊度", "w", menu.state.grid_w, 0)
	_add_size_row(menu, "長度", "h", menu.state.grid_h, 1)
	var area := PrepWidgets.name_label("總面積  %d／%d" % [menu.state.grid_w * menu.state.grid_h, menu.state.area_cap()], 420, 48)
	area.add_theme_color_override("font_color", Color("f4d35e"))
	menu._size_panel.add_child(area)
	for type in menu.state.FURNITURE.keys():
		var n: int = int(menu.state.unplaced(type))
		if n > 0:
			menu._add("拖放 %s　×%d" % [menu.state.FURNITURE[type]["name"], n], "hold", type)
	menu._add("收回游標上的物品", "pickup", null)
	menu._add(Loc.t("prep.back"), "go", "hub_shop")
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
	menu._title.text = Loc.t("prep.clerks.title")
	menu._info.text = "現有 %d／上限 %d　每日開工每人扣 $%d\n人數不能多過已放置的收銀機，也不能超過店舖規模。" % [menu.state.clerks.size(), menu.state.hire_limit(), menu.state.WAGE]
	menu._add("召募", "hire", null)
	for i in menu.state.clerks.size():
		var c: Dictionary = menu.state.clerks[i]
		var role := "收銀" if String(c["role"]) == "cashier" else "補貨"
		menu._add("店員%d　%s　收銀機 %d　（確定切崗位）" % [i + 1, role, int(c["register"]) + 1], "role", i)
		if String(c["role"]) == "cashier":
			menu._add("　改派收銀機", "reg", i)
		menu._add("　解僱店員%d" % (i + 1), "fire", i)
	menu._add(Loc.t("prep.back"), "go", "home")


static func _confirm(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.confirm.title") + "？"
	var wage: int = int(menu.state.WAGE) * menu.state.clerks.size()
	var info := "開工扣工資 $%d。結算時營業額入帳；若營業額低於本輪進貨成本會標虧損，遊戲繼續。" % wage
	if menu.demo != null and bool(menu.demo.get("elite_test_active")):
		var mode := String(menu.demo.call("elite_test_label"))
		info += "\n" + Loc.t("prep.elite_test.confirm_note", [mode])
	menu._info.text = info
	menu._add("開始　工資後資金約 $%d" % (menu.state.money - wage), "open", null)
	menu._add(Loc.t("prep.back"), "go", "home")


static func _elite_test(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.elite_test.title")
	menu._info.text = Loc.t("prep.elite_test.info")
	for lv in range(1, 7):
		menu._add(Loc.t("prep.elite_test.lv", [lv]), "elite_open", lv)
	menu._add(Loc.t("prep.elite_test.mixed"), "elite_open", 0)
	menu._add(Loc.t("prep.back"), "go", "home")


static func _sfx(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.sfx.title")
	menu._info.text = Loc.t("prep.sfx.info")
	for pri in ["P0", "P1", "P2"]:
		menu._add("—— %s ——" % pri, "noop", null)
		for e in SfxCatalog.by_priority(pri):
			var sid := String(e["id"])
			var group := String(e.get("group", ""))
			var trigger := String(e.get("trigger", ""))
			if trigger == "":
				menu._add("[%s] %s　▶" % [group, sid], "play_sfx", sid)
			else:
				menu._add("[%s] %s　▶　%s" % [group, sid, trigger], "play_sfx", sid)
	menu._add(Loc.t("prep.back"), "go", "hub_sys")


static func _kind_label(kind: String) -> String:
	match kind:
		"active":
			return Loc.t("prep.kind.active")
		"passive":
			return Loc.t("prep.kind.passive")
		"ultimate":
			return Loc.t("prep.kind.ult")
		_:
			return kind
