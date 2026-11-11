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
		"hub_char", "hub_goods", "hub_shop", "hub_sys", "clerks", "confirm", "elite_test", "rating_history", "lobby", "lan_join", "steam_join":
			return "home"
		"stats", "skills", "look":
			return "hub_char"
		"skill_set", "skill_rename":
			return "skills"
		"skill_pick":
			return "skill_set"
		"develop", "buy":
			return "hub_goods"
		"furn", "expand", "layout":
			return "hub_shop"
		"sfx", "locale":
			return "hub_sys"
		_:
			return "home"


static func apply_panel_layout(menu: CanvasLayer) -> void:
	menu._info.position = Vector2(24, 72)
	menu._info.size = Vector2(976, 76)
	menu._info.clip_contents = false
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
	if menu._diff_bar:
		menu._diff_bar.visible = menu._page == "home" and ProductVersion.test_tools_enabled()
	if menu._back_btn:
		menu._back_btn.visible = menu._page != "scenario" and menu._page != "home"
	if menu._page == "stats":
		menu._list.position = Vector2(24, 430)
		menu._list.size = Vector2(1232, 220)
		menu._list.z_index = 2
	elif menu._page == "layout":
		## Compact size strip (2×44 rows + area + gaps) then furniture list below — no overlap.
		var size_top := 156.0
		var size_h := 148.0
		var gap := 10.0
		menu._size_panel.position = Vector2(24, size_top)
		menu._size_panel.size = Vector2(520, size_h)
		menu._size_panel.custom_minimum_size = Vector2(520, size_h)
		menu._size_panel.clip_contents = true
		menu._list.z_index = 0
		menu._list.position = Vector2(24, size_top + size_h + gap)
		menu._list.size = Vector2(520, 668.0 - (size_top + size_h + gap))
	elif hub:
		menu._list.z_index = 0
	else:
		menu._list.z_index = 0
		if menu._page == "confirm":
			menu._info.position = Vector2(24, 72)
			menu._info.size = Vector2(980, 220)
			menu._info.clip_contents = true
			menu._list.position = Vector2(24, 300)
			menu._list.size = Vector2(1232, 350)
		elif menu._page == "lobby" or menu._page == "lan_join" or menu._page == "steam_join":
			## Seat rows / join hints are multi-line — keep list below info (no overlap).
			_layout_lobby_panels(menu, 6)
		elif menu._page == "look":
			menu._info.position = Vector2(24, 72)
			menu._info.size = Vector2(760, 76)
			menu._list.position = Vector2(24, 168)
			menu._list.size = Vector2(760, 430)
		else:
			menu._info.position = Vector2(24, 72)
			menu._info.size = Vector2(976, 76)
			menu._list.position = Vector2(24, 168)
			menu._list.size = Vector2(1232, 430)


static func _layout_lobby_panels(menu: CanvasLayer, line_n: int) -> void:
	## Push ItemList under multi-line lobby／join info so ready buttons never cover seat rows.
	var lines := maxi(1, line_n)
	var line_h := 34.0
	var info_h := clampf(float(lines) * line_h + 16.0, 120.0, 300.0)
	var info_top := 72.0
	menu._info.position = Vector2(24, info_top)
	menu._info.size = Vector2(1232, info_h)
	menu._info.clip_contents = true
	var gap := 12.0
	var list_top := info_top + info_h + gap
	## Join pages place a LineEdit between info and list.
	if menu._page == "lan_join" or menu._page == "steam_join":
		var edit_top := info_top + info_h + 8.0
		if menu._page == "lan_join" and menu._lan_addr_edit != null and menu._lan_addr_edit.visible:
			menu._lan_addr_edit.position = Vector2(24, edit_top)
			menu._lan_addr_edit.size = Vector2(480, 40)
		if menu._page == "steam_join" and menu._steam_lobby_edit != null and menu._steam_lobby_edit.visible:
			menu._steam_lobby_edit.position = Vector2(24, edit_top)
			menu._steam_lobby_edit.size = Vector2(480, 40)
		list_top = edit_top + 48.0
	menu._list.position = Vector2(24, list_top)
	menu._list.size = Vector2(1232, maxf(160.0, 668.0 - list_top))


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
		"locale":
			_locale(menu)
		"stats":
			_stats(menu)
		"look":
			_look(menu)
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
		"lobby":
			_lobby(menu)
		"lan_join":
			_lan_join(menu)
		"steam_join":
			_steam_join(menu)
		"sfx":
			_sfx(menu)
		"elite_test":
			_elite_test(menu)
		"rating_history":
			_rating_history(menu)
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
	## ACTIVES/PASSIVES/ULTS are mechanical-only; name/blurb live in locale via localize().
	for raw in pool:
		var sk: Dictionary = Skills.localize(raw)
		menu._add(
			"%s　%s　COST%d　%s" % [
				_kind_label(String(sk.get("kind", ""))),
				String(sk.get("name", "")),
				int(sk.get("cost", 1)),
				String(sk.get("blurb", "")),
			],
			"equip",
			[slot_i, String(sk.get("id", ""))],
		)
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
	menu._add(Loc.t("prep.scenario.s4"), "sc", 4)


static func _home(menu: CanvasLayer) -> void:
	menu._hub_cols = 3
	menu._title.text = Loc.t("prep.home.title")
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else menu._home_info())
	menu._add_hub(Loc.t("prep.hub.char"), "go", "hub_char", "char")
	menu._add_hub(Loc.t("prep.hub.goods"), "go", "hub_goods", "goods")
	menu._add_hub(Loc.t("prep.hub.shop"), "go", "hub_shop", "shop")
	menu._add_hub(Loc.t("prep.hub.staff", [menu.state.clerks.size()]), "go", "clerks", "staff")
	menu._add_hub(Loc.t("prep.hub.rating"), "go", "rating_history", "rating")
	menu._add_hub(Loc.t("prep.hub.sys"), "go", "hub_sys", "sys")
	menu._rebuild_hub_tiles()
	menu._setup_open_bar()


static func _rating_history(menu: CanvasLayer) -> void:
	const RatingRules = preload("res://scripts/session/rating_rules.gd")
	menu._title.text = Loc.t("prep.rating.title")
	var shop_r := int(menu.state.shop_rating) if "shop_rating" in menu.state else 0
	var support_r := int(menu.state.support_rating) if "support_rating" in menu.state else 0
	var hist: Array = menu.state.rating_history if menu.state.get("rating_history") is Array else []
	var last_ops := int(menu.state.last_ops_rating) if "last_ops_rating" in menu.state else RatingRules.OPS_START
	var last_g := int(menu.state.last_grade) if "last_grade" in menu.state else 0
	var info := Loc.t("prep.rating.info", [
		shop_r,
		support_r,
		hist.size(),
		RatingRules.HISTORY_MAX,
		last_ops,
		Loc.t(RatingRules.grade_label_key(last_g)),
		last_g,
	])
	if menu._msg != "":
		info = menu._pair(info, menu._msg)
	menu._info.text = info
	if hist.is_empty():
		menu._add(Loc.t("prep.rating.empty"), "noop", null)
	else:
		## Newest first; day index = hist.size() (most recent = Day N).
		for i in range(hist.size() - 1, -1, -1):
			var grade := clampi(int(hist[i]), -3, 3)
			var day_n := i + 1
			var ago := hist.size() - 1 - i
			var when := Loc.t("prep.rating.day_latest") if ago == 0 else Loc.t("prep.rating.day_ago", [ago])
			menu._add(
				Loc.t("prep.rating.row", [
					when,
					day_n,
					Loc.t(RatingRules.grade_label_key(grade)),
					grade,
				]),
				"noop",
				null
			)
	menu._add(Loc.t("prep.back"), "go", "home")


static func _hub_char(menu: CanvasLayer) -> void:
	menu._hub_cols = 1
	menu._title.text = Loc.t("prep.hub.char")
	menu._info.text = menu._pair(menu._header(), Loc.t("prep.hub.char_info"))
	menu._add_hub(Loc.t("prep.home.stats"), "go", "stats", "stats")
	menu._add_hub(Loc.t("prep.home.skills_short"), "go", "skills", "skills")
	menu._add_hub(Loc.t("prep.home.look"), "go", "look", "look")
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
	var stick_on := PlatformServices.is_virtual_stick_enabled()
	menu._add_hub(
		Loc.t("prep.sys.virtual_stick_on" if stick_on else "prep.sys.virtual_stick_off"),
		"toggle_virtual_stick",
		null,
		"stick"
	)
	var lang_name := Loc.t("locale.name.%s" % Loc.get_locale())
	menu._add_hub(Loc.t("prep.sys.language", [lang_name]), "go", "locale", "lang")
	if ProductVersion.test_tools_enabled():
		menu._add_hub(Loc.t("prep.home.test_money"), "test_money", null, "money")
		menu._add_hub(Loc.t("prep.home.sfx_test"), "go", "sfx", "sfx")
	menu._add_hub(Loc.t("prep.home.wipe"), "wipe_save", null, "wipe")
	menu._rebuild_hub_tiles()


static func _locale(menu: CanvasLayer) -> void:
	var current := Loc.get_locale()
	var current_name := Loc.t("locale.name.%s" % current)
	menu._title.text = Loc.t("prep.locale.title")
	menu._info.text = menu._pair(menu._header(), Loc.t("prep.locale.info", [current_name]))
	if menu._msg != "":
		menu._info.text = menu._pair(menu._info.text, menu._msg)
	for code in Loc.locales():
		var endonym := Loc.t("locale.name.%s" % code)
		var row := Loc.t("prep.locale.row_current" if code == current else "prep.locale.row", [endonym])
		menu._add(row, "set_locale", String(code))
	menu._add(Loc.t("prep.back"), "go", "hub_sys")


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


static func _look(menu: CanvasLayer) -> void:
	const SkinCatalog = preload("res://scripts/session/skin_catalog.gd")
	menu._title.text = Loc.t("prep.look.title")
	var cur_id := String(menu.state.appearance_skin_id()) if menu.state.has_method("appearance_skin_id") else String(menu.state.skin_id)
	var cur_name := SkinCatalog.display_name(cur_id)
	var info := Loc.t("prep.look.info", [cur_name, int(menu.state.tint)])
	if menu._msg != "":
		info = menu._pair(info, menu._msg)
	menu._info.text = info
	var unlocks = menu.state.unlocked_skins if "unlocked_skins" in menu.state else []
	for e in SkinCatalog.unlocked_entries(unlocks):
		var sid := String(e.get("id", ""))
		var mark := "▶ " if sid == cur_id else "　"
		menu._add(mark + SkinCatalog.display_name(sid), "set_skin", sid)
	menu._add(Loc.t("prep.look.cycle_tint", [int(menu.state.tint)]), "cycle_look_tint", null)
	menu._add(Loc.t("prep.back"), "go", "hub_char")
	menu._ensure_look_preview()
	menu._refresh_look_preview_from_index()


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
			if Skills.prep_picks_level(sk):
				skill_name = "%s　LV%d" % [skill_name, menu.state.skill_level_of(i, id)]
		menu._add(Loc.t("prep.skill_set.slot", [s + 1, kind, skill_name]), "pick_slot", s)
	for sid in set_slots:
		var level_id := String(sid)
		if level_id == "":
			continue
		var level_sk: Dictionary = Skills.by_id(level_id)
		if not Skills.prep_picks_level(level_sk):
			continue
		menu._add(Loc.t("prep.skill.level_row", [String(level_sk.get("name")), menu.state.skill_level_of(i, level_id)]), "cycle_skill_lv", level_id)
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
		return Loc.t("prep.ult.empty")
	var n := String(sk.get("name", ""))
	return n if n != "" else Loc.t("prep.ult.empty")


static func _develop(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.develop.title")
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else Loc.t("prep.develop.info"))
	for sku in Tuning.SELLABLE_SKUS:
		if not menu.state.sku_unlocked(sku):
			menu._add(Loc.t("prep.sku.locked", [Tuning.sku_name(sku), int(Tuning.SKU_UNLOCK_LV[sku])]), "locked_sku", sku)
		elif menu.state.developed.has(sku):
			menu._add(Loc.t("prep.sku.developed", [Tuning.sku_name(sku)]), "noop", sku)
		else:
			menu._add(Loc.t("prep.sku.develop_row", [Tuning.sku_name(sku), int(Tuning.SKU_DEVELOP[sku])]), "dev", sku)
	menu._add(Loc.t("prep.back"), "go", "hub_goods")


static func _buy(menu: CanvasLayer) -> void:
	if menu._qty_sku != "":
		var name := Tuning.sku_name(menu._qty_sku)
		var each := Tuning.sku_piece_price_label(menu._qty_sku)
		menu._title.text = Loc.t("prep.stock.qty_title", [name])
		menu._info.text = Loc.t("prep.stock.qty_info", [int(menu.state.stock.get(menu._qty_sku, 0)), each])
		_build_qty(menu, Tuning.cost_for_pieces(menu._qty_sku, menu._qty_boxes))
		return
	menu._title.text = Loc.t("prep.buy.title")
	menu._info.text = menu._pair(menu._header(), menu._msg if menu._msg != "" else Loc.t("prep.buy.info"))
	for sku in Tuning.SELLABLE_SKUS:
		if not menu.state.sku_unlocked(sku):
			menu._add(Loc.t("prep.sku.locked", [Tuning.sku_name(sku), int(Tuning.SKU_UNLOCK_LV[sku])]), "locked_sku", sku)
		elif not menu.state.developed.has(sku):
			menu._add(Loc.t("prep.sku.need_dev", [Tuning.sku_name(sku)]), "need_develop", sku)
		else:
			menu._add(
				Loc.t("prep.sku.buy_row", [
					Tuning.sku_name(sku),
					int(menu.state.stock.get(sku, 0)),
					Tuning.sku_piece_price_label(sku),
					int(Tuning.SKU_COST[sku]),
				]),
				"qty",
				sku,
			)
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
	sum.text = Loc.t("prep.sku.total", [total])
	sum.custom_minimum_size = Vector2(400, 48)
	UiFont.apply_label(sum, PrepWidgets.PREP_TITLE)
	sum.add_theme_color_override("font_color", Color("e07a5f") if total > menu.state.money else Color("f4d35e"))
	menu._qty_panel.add_child(sum)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 24)
	acts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ok := PrepWidgets.bare_button(Loc.t("prep.sku.confirm_buy"), 300, 88)
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
	num.text = Loc.t("prep.sku.qty", [menu._qty_boxes])
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
		var fname := String(menu.state.furniture_name(type))
		if not menu.state.furniture_unlocked(type):
			menu._add(Loc.t("prep.furn.locked_row", [fname, int(spec["unlock"]), int(spec["price"])]), "locked_furn", type)
		else:
			menu._add(Loc.t("prep.furn.buy_row", [fname, int(spec["price"]), int(menu.state.owned.get(type, 0)), menu.state.unplaced(type)]), "buy_f", type)
	menu._add(Loc.t("prep.back"), "go", "hub_shop")


static func _expand(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.expand.title")
	menu._info.text = Loc.t("prep.expand.info", [
		menu.state.shop_scale, menu.state.grid_w, menu.state.grid_h,
		menu.state.grid_w * menu.state.grid_h, menu.state.area_cap(),
	])
	if menu.state.shop_scale < 3:
		var nxt: int = int(menu.state.shop_scale) + 1
		menu._add(Loc.t("prep.expand.row", [nxt, int(menu.state.SCALE_COST[nxt])]), "expand", null)
	else:
		menu._add(Loc.t("err.max_scale"), "expand_max", null)
	menu._add(Loc.t("prep.back"), "go", "hub_shop")


static func _layout(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.layout.title")
	var pick_i: int = int(menu.get("_sku_pick_i"))
	if pick_i >= 0 and menu.state != null and pick_i < menu.state.placed.size():
		var list: Array = menu.call("_sku_pick_list")
		var cur := ""
		if list is Array and not list.is_empty():
			var cidx: int = clampi(int(menu.get("_sku_pick_cursor")), 0, list.size() - 1)
			cur = Tuning.sku_name(String(list[cidx]))
		menu._info.text = Loc.t("prep.layout.sku_pick", [cur])
	elif menu._hold_type != "":
		menu._info.text = Loc.t("prep.layout.holding", [menu.state.furniture_name(menu._hold_type)])
	elif menu._msg != "":
		menu._info.text = menu._msg
	else:
		menu._info.text = Loc.t("prep.layout.info")
	PrepWidgets.clear(menu._size_panel)
	menu._size_panel.add_theme_constant_override("separation", 6)
	_add_size_row(menu, Loc.t("prep.layout.width"), "w", menu.state.grid_w, 0)
	_add_size_row(menu, Loc.t("prep.layout.height"), "h", menu.state.grid_h, 1)
	## Compact area line — default text_label tall=84 was expanding SizePanel over the list.
	var area := PrepWidgets.name_label(
		Loc.t("prep.layout.area", [menu.state.grid_w * menu.state.grid_h, menu.state.area_cap()]),
		500,
		36
	)
	UiFont.apply_label(area, 22)
	area.add_theme_color_override("font_color", Color("f4d35e"))
	menu._size_panel.add_child(area)
	for type in menu.state.FURNITURE.keys():
		var n: int = int(menu.state.unplaced(type))
		if n > 0:
			menu._add(Loc.t("prep.layout.drag", [menu.state.furniture_name(type), n]), "hold", type)
	menu._add(Loc.t("prep.layout.focus_map"), "map_focus", null)
	menu._add(Loc.t("prep.back"), "go", "hub_shop")
	## Re-clamp after children (VBox min-size must not push into the ItemList).
	menu._size_panel.custom_minimum_size = Vector2(520, 148)
	menu._size_panel.size = Vector2(520, 148)
	menu._size_panel.clip_contents = true
	menu._grid.queue_redraw()


static func _add_size_row(menu: CanvasLayer, title: String, axis: String, value: int, row: int) -> void:
	const ROW_H := 44.0
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.custom_minimum_size = Vector2(0, ROW_H)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := PrepWidgets.name_label("%s  %d" % [title, value], 160, ROW_H)
	UiFont.apply_label(lab, 24)
	line.add_child(lab)
	line.add_child(PrepWidgets.step_button(
		"+",
		menu._on_size_btns and menu._size_row == row and menu._size_side == 1,
		menu._on_size_pressed.bind(axis, 1, row),
		ROW_H,
		72.0
	))
	line.add_child(PrepWidgets.step_button(
		"-",
		menu._on_size_btns and menu._size_row == row and menu._size_side == -1,
		menu._on_size_pressed.bind(axis, -1, row),
		ROW_H,
		72.0
	))
	menu._size_panel.add_child(line)


static func _clerks(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.clerks.title")
	menu._info.text = Loc.t("prep.hire.info", [menu.state.clerks.size(), menu.state.hire_limit(), menu.state.WAGE])
	menu._add(Loc.t("prep.hire.recruit"), "hire", null)
	for i in menu.state.clerks.size():
		var c: Dictionary = menu.state.clerks[i]
		var role := Loc.t("prep.role.cashier") if String(c["role"]) == "cashier" else Loc.t("prep.role.restock")
		menu._add(Loc.t("prep.hire.clerk_row", [i + 1, role, int(c["register"]) + 1]), "role", i)
		if String(c["role"]) == "cashier":
			menu._add(Loc.t("prep.hire.reassign"), "reg", i)
		menu._add(Loc.t("prep.hire.fire", [(i + 1)]), "fire", i)
	menu._add(Loc.t("prep.back"), "go", "home")


static func _confirm(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("prep.confirm.title") + "？"
	var wage: int = int(menu.state.WAGE) * menu.state.clerks.size()
	var info := Loc.t("prep.open.wage_info", [wage])
	if menu.demo != null and bool(menu.demo.get("elite_test_active")):
		var mode := String(menu.demo.call("elite_test_label"))
		info += "\n" + Loc.t("prep.elite_test.confirm_note", [mode])
	if ProductVersion.test_tools_enabled() and menu.demo != null and menu.demo.has_method("play_is_easy"):
		var easy := bool(menu.demo.call("play_is_easy"))
		info += "\n" + Loc.t("prep.difficulty.confirm_easy" if easy else "prep.difficulty.confirm_normal")
	var web_solo := OS.has_feature("web")
	if web_solo:
		menu._local_seats = 1
		info += "\n" + Loc.t("prep.confirm.players_web")
	else:
		info += "\n" + Loc.t("prep.confirm.players") + "：" + (
			Loc.t("prep.confirm.players_2") if menu._local_seats >= 2 else Loc.t("prep.confirm.players_1")
		)
		info += "\n" + _confirm_host_look_line(menu)
		if menu._local_seats >= 2:
			menu._ensure_guest_store()
			menu._auto_pick_guest_slot()
			var gi: int = int(menu._guest_slot_index)
			if gi >= 0 and not menu._guest_store.is_empty(gi):
				info += "\n" + Loc.t("prep.confirm.guest_selected", [gi + 1, menu._guest_store.label_for(gi)])
				info += "\n" + _confirm_guest_look_line(menu, gi)
			else:
				info += "\n" + Loc.t("prep.confirm.guest_none")
	menu._info.text = info
	if not web_solo:
		menu._add(Loc.t("prep.confirm.players_1"), "set_seats", 1)
		menu._add(Loc.t("prep.confirm.players_2"), "set_seats", 2)
		if menu._local_seats >= 2:
			menu._ensure_guest_store()
			for i in 3:
				var lab := Loc.t("prep.confirm.guest_slot", [i + 1, menu._guest_store.label_for(i)])
				if menu._guest_store.is_empty(i):
					menu._add(Loc.t("prep.confirm.guest_clone", [i + 1]), "clone_guest_slot", i)
					menu._add(Loc.t("prep.confirm.guest_blank_btn", [i + 1]), "blank_guest_slot", i)
				else:
					menu._add(lab, "pick_guest_slot", i)
			if menu._guest_slot_index >= 0 and not menu._guest_store.is_empty(menu._guest_slot_index):
				menu._add(Loc.t("prep.confirm.cycle_guest_tint"), "cycle_guest_tint", null)
	menu._add(Loc.t("prep.open.start_funds", [(menu.state.money - wage)]), "open", null)
	if not web_solo and SessionService.lan_available():
		menu._add(Loc.t("lobby.host"), "lan_host", null)
		menu._add(Loc.t("lobby.join"), "go", "lan_join")
	if not web_solo:
		## Always offer Steam entry; errors if GodotSteam missing (§13).
		menu._add(Loc.t("lobby.steam_host"), "steam_host", null)
		menu._add(Loc.t("lobby.steam_join"), "go", "steam_join")
	menu._add(Loc.t("prep.back"), "go", "home")


static func _lobby(menu: CanvasLayer) -> void:
	if SessionService.is_steam():
		menu._title.text = Loc.t("lobby.title_steam")
	elif SessionService.is_lan():
		menu._title.text = Loc.t("lobby.title")
	else:
		menu._title.text = Loc.t("lobby.title_local")
	var lines: PackedStringArray = []
	if SessionService.is_steam():
		if SessionService.is_server():
			lines.append(Loc.t("lobby.steam_host_info", [SessionService.steam_lobby_id]))
		else:
			lines.append(Loc.t("lobby.steam_joined", [SessionService.steam_lobby_id]))
	elif SessionService.is_lan():
		if SessionService.is_server():
			lines.append(Loc.t("lobby.host_port", [SessionService.lan_port]))
		else:
			lines.append(Loc.t("lobby.joined", [SessionService.join_address, SessionService.lan_port]))
	else:
		lines.append(Loc.t("lobby.local_info"))
	lines.append(Loc.t("lobby.remaining", [SessionService.seats_remaining()]))
	for s in SeatTable.seat_ids():
		var ready := Loc.t("lobby.ready_yes" if SeatTable.is_seat_ready(s) else "lobby.ready_no")
		var mine := SeatTable.seat_owned_locally(s)
		var tag := Loc.t("lobby.you") if mine else Loc.t("lobby.peer", [SeatTable.owner_peer_of(s)])
		lines.append(Loc.t("lobby.seat_row", [s + 1, tag, ready]))
	menu._info.text = "\n".join(lines)
	_layout_lobby_panels(menu, lines.size())
	## Toggle ready for locally owned seats (list sits below seat status).
	for s in SeatTable.seat_ids():
		if SeatTable.seat_owned_locally(s):
			var lab := Loc.t("lobby.toggle_ready", [s + 1])
			menu._add(lab, "lobby_ready", s)
	if SessionService.is_server():
		if SessionService.all_ready():
			menu._add(Loc.t("lobby.start"), "lobby_start", null)
		else:
			menu._add(Loc.t("lobby.start_blocked"), "noop", null)
		menu._add(Loc.t("lobby.close"), "lobby_close", null)
	else:
		menu._add(Loc.t("lobby.leave"), "lobby_close", null)


static func _lan_join(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("lobby.join_title")
	var addr := String(menu._lan_address)
	if addr.is_empty():
		addr = "127.0.0.1"
	var web_solo := OS.has_feature("web")
	if web_solo:
		menu._local_seats = 1
	var claim := 1 if web_solo else clampi(menu._local_seats, 1, 2)
	var info := Loc.t("lobby.join_info", [addr])
	info += "\n" + Loc.t("lobby.join_claim", [
		Loc.t("lobby.claim_2") if claim >= 2 else Loc.t("lobby.claim_1")
	])
	if claim >= 2:
		menu._ensure_guest_store()
		menu._auto_pick_guest_slot()
		var gi: int = int(menu._guest_slot_index)
		if gi >= 0 and not menu._guest_store.is_empty(gi):
			info += "\n" + Loc.t("prep.confirm.guest_selected", [gi + 1, menu._guest_store.label_for(gi)])
			info += "\n" + _confirm_guest_look_line(menu, gi)
		else:
			info += "\n" + Loc.t("prep.confirm.guest_none")
		info += "\n" + Loc.t("lobby.join_claim2_hint")
	menu._info.text = info
	menu._ensure_lan_address_edit(addr)
	_layout_lobby_panels(menu, info.split("\n").size())
	if not web_solo:
		menu._add(Loc.t("lobby.claim_1"), "set_seats", 1)
		menu._add(Loc.t("lobby.claim_2"), "set_seats", 2)
		if claim >= 2:
			menu._ensure_guest_store()
			for i in 3:
				var lab := Loc.t("prep.confirm.guest_slot", [i + 1, menu._guest_store.label_for(i)])
				if menu._guest_store.is_empty(i):
					menu._add(Loc.t("prep.confirm.guest_clone", [i + 1]), "clone_guest_slot", i)
					menu._add(Loc.t("prep.confirm.guest_blank_btn", [i + 1]), "blank_guest_slot", i)
				else:
					menu._add(lab, "pick_guest_slot", i)
			if menu._guest_slot_index >= 0 and not menu._guest_store.is_empty(menu._guest_slot_index):
				menu._add(Loc.t("prep.confirm.cycle_guest_tint"), "cycle_guest_tint", null)
	menu._add(Loc.t("lobby.join_confirm"), "lan_join_do", null)
	menu._add(Loc.t("lobby.addr_localhost"), "lan_addr", "127.0.0.1")
	menu._add(Loc.t("prep.back"), "go", "confirm")


static func _steam_join(menu: CanvasLayer) -> void:
	menu._title.text = Loc.t("lobby.steam_join_title")
	var web_solo := OS.has_feature("web")
	if web_solo:
		menu._local_seats = 1
	var claim := 1 if web_solo else clampi(menu._local_seats, 1, 2)
	var lobby_s := String(menu._steam_lobby_draft)
	if lobby_s.is_empty():
		lobby_s = "0"
	var info := Loc.t("lobby.steam_join_info", [lobby_s])
	info += "\n" + Loc.t("lobby.join_claim", [
		Loc.t("lobby.claim_2") if claim >= 2 else Loc.t("lobby.claim_1")
	])
	if not SessionService.steam_available():
		info += "\n" + Loc.t("lobby.steam_sdk_hint")
	if claim >= 2:
		menu._ensure_guest_store()
		menu._auto_pick_guest_slot()
		var gi: int = int(menu._guest_slot_index)
		if gi >= 0 and not menu._guest_store.is_empty(gi):
			info += "\n" + Loc.t("prep.confirm.guest_selected", [gi + 1, menu._guest_store.label_for(gi)])
			info += "\n" + _confirm_guest_look_line(menu, gi)
		else:
			info += "\n" + Loc.t("prep.confirm.guest_none")
		info += "\n" + Loc.t("lobby.join_claim2_hint")
	menu._info.text = info
	menu._ensure_steam_lobby_edit(lobby_s)
	_layout_lobby_panels(menu, info.split("\n").size())
	if not web_solo:
		menu._add(Loc.t("lobby.claim_1"), "set_seats", 1)
		menu._add(Loc.t("lobby.claim_2"), "set_seats", 2)
		if claim >= 2:
			menu._ensure_guest_store()
			for i in 3:
				var lab := Loc.t("prep.confirm.guest_slot", [i + 1, menu._guest_store.label_for(i)])
				if menu._guest_store.is_empty(i):
					menu._add(Loc.t("prep.confirm.guest_clone", [i + 1]), "clone_guest_slot", i)
					menu._add(Loc.t("prep.confirm.guest_blank_btn", [i + 1]), "blank_guest_slot", i)
				else:
					menu._add(lab, "pick_guest_slot", i)
			if menu._guest_slot_index >= 0 and not menu._guest_store.is_empty(menu._guest_slot_index):
				menu._add(Loc.t("prep.confirm.cycle_guest_tint"), "cycle_guest_tint", null)
	menu._add(Loc.t("lobby.steam_join_confirm"), "steam_join_do", null)
	menu._add(Loc.t("prep.back"), "go", "confirm")


static func _confirm_host_look_line(menu: CanvasLayer) -> String:
	const SkinCatalog = preload("res://scripts/session/skin_catalog.gd")
	var sid := String(menu.state.appearance_skin_id()) if menu.state.has_method("appearance_skin_id") else String(menu.state.skin_id)
	return Loc.t("prep.confirm.host_look", [SkinCatalog.display_name(sid), int(menu.state.tint)])


static func _confirm_guest_look_line(menu: CanvasLayer, slot_i: int) -> String:
	const SkinCatalog = preload("res://scripts/session/skin_catalog.gd")
	var sheet = menu._guest_store.get_sheet(slot_i)
	if sheet == null:
		return ""
	var sid := String(sheet.appearance_skin_id()) if sheet.has_method("appearance_skin_id") else String(sheet.skin_id)
	return Loc.t("prep.confirm.guest_look", [SkinCatalog.display_name(sid), int(sheet.tint)])


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
