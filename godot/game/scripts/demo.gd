extends Node2D
## Living v1 line (from Alpha v0.1): Demo v0.6 shop loop with voxel sprites.

const Tuning = preload("res://scripts/tuning.gd")
const StateScript = preload("res://scripts/game_state.gd")
const PlayerScript = preload("res://scripts/player.gd")
const RestockScript = preload("res://scripts/restock_point.gd")
const ShelfScript = preload("res://scripts/shelf.gd")
const Fundraise = preload("res://scripts/fundraise.gd")
const DirtScript = preload("res://scripts/dirt.gd")
const DroppedBoxScript = preload("res://scripts/dropped_box.gd")
const CashierScript = preload("res://scripts/cashier.gd")
const CustomerScript = preload("res://scripts/customer.gd")
const ClerkScript = preload("res://scripts/clerk.gd")
const PathfinderScript = preload("res://scripts/pathfinder.gd")
const PrepScene = preload("res://scenes/prep_menu.tscn")
const UiFont = preload("res://scripts/ui_font.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

var FLOOR_SIZE := Vector2(640, 640)
var FLOOR_ORIGIN := Vector2(48, 36)

var phase: String = "prep"
var state: StateScript
var cleaned: int = 0
var _settled: bool = false
var _prep: CanvasLayer
var _world: Node2D
var cashiers: Array[Node2D] = []
var real_time: float = 0.0
var game_hours: float = Tuning.GAME_START_HOUR
var revenue: int = 0
var served: int = 0
var angry_left: int = 0
var stolen_count: int = 0
var stolen_value: int = 0
var thieves_caught: int = 0
var thieves_escaped: int = 0
var cashier: Node2D
var shelves: Array[Node2D] = []
var pathfinder
var _obstacles: Array[Rect2] = []
var _spawn_in: float = 2.0
var _player: CharacterBody2D
var _customers: Node2D
var _hud: CanvasLayer
var _dirts: Array[Node2D] = []
var _dirt_spawn_in: float = Tuning.DIRT_SPAWN_SEC
var _thief_spawn_in: float = Tuning.THIEF_SPAWN_FIRST
var _early_open: bool = false
var _early_latched: bool = false
var _early_closed: bool = false
var _skip_xp: int = 0
var _early_focus: int = 0
var _early_layer: CanvasLayer
var _early_yes: Button
var _early_no: Button


func _ready() -> void:
	add_to_group("game")
	state = StateScript.new()
	_prep = PrepScene.instantiate()
	add_child(_prep)
	_prep.setup(self)
	_prep.start_day.connect(_begin_day)


func _begin_day() -> void:
	if _prep:
		_prep.set_process_unhandled_input(false)
	_clear_world()
	_early_closed = false
	_skip_xp = 0
	revenue = 0
	served = 0
	angry_left = 0
	stolen_count = 0
	stolen_value = 0
	thieves_caught = 0
	thieves_escaped = 0
	cleaned = 0
	_settled = false
	real_time = 0.0
	phase = "restock"
	_spawn_in = 2.0
	_dirt_spawn_in = state.dirt_spawn_sec()
	_thief_spawn_in = state.thief_spawn_first()
	FLOOR_SIZE = Vector2(state.grid_w, state.grid_h) * StateScript.CELL
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	add_child(_world)
	move_child(_world, 0)
	_floor()
	_walls_and_door()
	var nodes: Array[Node2D] = []
	_build_furniture(nodes)
	pathfinder = PathfinderScript.new()
	pathfinder.setup(FLOOR_ORIGIN, FLOOR_SIZE, _obstacles)
	_customers = Node2D.new()
	_customers.name = "Customers"
	_customers.y_sort_enabled = true
	_world.add_child(_customers)
	_player = _make_player()
	_player.stats = state
	_world.add_child(_player)
	_player.global_position = FLOOR_ORIGIN + Vector2(FLOOR_SIZE.x * 0.5, FLOOR_SIZE.y - 80)
	_player.interactables = nodes
	_player.paid.connect(_on_paid)
	var cam := Camera2D.new()
	cam.zoom = Vector2(Tuning.CAMERA_ZOOM, Tuning.CAMERA_ZOOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.5
	_player.add_child(cam)
	cam.make_current()
	_player.camera = cam
	_hud = preload("res://scenes/hud.tscn").instantiate()
	add_child(_hud)
	_hud.setup(self, _player)
	var pad = preload("res://scripts/touch_pad.gd").new()
	pad.name = "TouchPad"
	add_child(pad)
	pad.visible = PlatformServices.wants_touch_pad()
	pad.stick_changed.connect(func(axis: Vector2) -> void: _player.stick_axis = axis)
	pad.hold_changed.connect(func(action: String, pressed: bool) -> void:
		if _early_open and pressed:
			if action == "interact":
				if _early_focus == 0:
					_confirm_early_close()
				else:
					_decline_early_close()
			elif action == "cancel":
				_decline_early_close()
			return
		if phase == "closed" and pressed and (action == "interact" or action == "cancel"):
			_return_to_prep()
			return
		if _player:
			_player.set_hold(action, pressed)
	)
	_spawn_clerks()
	for i in Tuning.DIRT_START_COUNT:
		_try_spawn_dirt()


func _clear_world() -> void:
	var kill: Array[Node] = []
	for c in get_children():
		if c == _prep:
			continue
		kill.append(c)
	for c in kill:
		c.queue_free()
	_world = null
	_hud = null
	shelves.clear()
	cashiers.clear()
	_dirts.clear()
	_obstacles.clear()
	cashier = null
	_player = null
	_customers = null
	_early_open = false
	_early_latched = false
	_early_layer = null
	_early_yes = null
	_early_no = null


func _build_furniture(nodes: Array[Node2D]) -> void:
	var shelf_i := 1
	var reg_i := 0
	for it in state.placed:
		var cell := StateScript.CELL
		var r := Rect2(FLOOR_ORIGIN + Vector2(int(it["x"]), int(it["y"])) * cell, Vector2(int(it["w"]), int(it["h"])) * cell)
		var t := String(it["type"])
		var rot := int(it["rot"])
		if t.begins_with("restock"):
			var cat := Tuning.CAT_DRY
			if t.ends_with("frozen"):
				cat = Tuning.CAT_FROZEN
			elif t.ends_with("ice"):
				cat = Tuning.CAT_ICE
			nodes.append(_restock(r, cat))
		elif t.begins_with("shelf"):
			var cat := Tuning.CAT_DRY
			if t.contains("frozen"):
				cat = Tuning.CAT_FROZEN
			elif t.contains("ice"):
				cat = Tuning.CAT_ICE
			nodes.append(_make_shelf(r, cat, shelf_i, rot, state.shelf_capacity(t)))
			shelf_i += 1
		elif t == "cashier":
			var node := _make_cashier(r, rot, reg_i)
			nodes.append(node)
			reg_i += 1
	if not cashiers.is_empty():
		cashier = cashiers[0]


func _spawn_clerks() -> void:
	var i := 0
	for c in state.clerks:
		var clerk: CharacterBody2D = ClerkScript.new()
		var reg: Node2D = null
		if String(c["role"]) == "cashier" and not cashiers.is_empty():
			reg = cashiers[mini(int(c["register"]), cashiers.size() - 1)]
		_world.add_child(clerk)
		clerk.setup(self, FLOOR_ORIGIN + Vector2(80 + i * 36, FLOOR_SIZE.y - 120), String(c["role"]), reg)
		i += 1


func note_clean() -> void:
	cleaned += 1


func yes_my_lord_on() -> bool:
	return _player != null and _player.buff_left("yes_my_lord") > 0.05


func release_player_checkout() -> void:
	if _player and _player.has_method("release_checkout"):
		_player.release_checkout()


func nearest_stocked_shelf(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for s in shelves:
		if s == null or not is_instance_valid(s):
			continue
		if int(s.get("count")) <= 0:
			continue
		var d := from.distance_squared_to(s.global_position)
		if d < best_d:
			best = s
			best_d = d
	return best


func cast_fundraise(level: int) -> void:
	if _customers == null:
		return
	var picked: Array = Fundraise.choose(_customers.get_children(), level)
	var total := 0
	for c in picked:
		var amount := int(c.call("cart_total"))
		total += amount
		_on_paid(amount)
		c.finish_paid()
	release_player_checkout()
	if _player:
		_player.log_line.emit("全體集資　%d 人　+$%d" % [picked.size(), total])


func sellable() -> Array[String]:
	return state.sellable()


func customer_list_bounds() -> Vector2i:
	return Vector2i(state.customer_list_min(), state.customer_list_max())


func queue_dissat_blocked() -> bool:
	return state.has_flag("no_queue_dissat")


func soothe_all(keep: float) -> void:
	if _customers == null:
		return
	for c in _customers.get_children():
		if bool(c.get("is_thief")):
			continue
		if int(c.get("state")) == 7:
			continue
		c.dissatisfaction = float(c.dissatisfaction) * keep


func pick_register(cust: Node) -> Node2D:
	if cashiers.is_empty():
		return null
	var best: Node2D = cashiers[0]
	var best_n := 999
	for c in cashiers:
		var n: int = c.queue.size()
		if n < best_n:
			best_n = n
			best = c
	return best


func restock_for(cat: String) -> Node2D:
	for n in _player.interactables if _player else []:
		if n != null and String(n.get("kind")) == "restock" and String(n.get("category")) == cat:
			return n
	return null


func sync_stock() -> void:
	if _player == null:
		return
	for n in _player.interactables:
		if n != null and String(n.get("kind")) == "restock" and n.has_method("pull_stock"):
			n.call("pull_stock")


func _unhandled_input(event: InputEvent) -> void:
	if _early_open:
		_early_input(event)
		return
	if phase != "closed":
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		go = k == KEY_J or k == KEY_ENTER or k == KEY_SEMICOLON or k == KEY_BACKSPACE
	elif event is InputEventJoypadButton and event.pressed:
		var b := (event as InputEventJoypadButton).button_index
		go = b == JOY_BUTTON_A or b == JOY_BUTTON_B
	if not go:
		return
	_return_to_prep()
	get_viewport().set_input_as_handled()


func _return_to_prep() -> void:
	if phase != "closed":
		return
	phase = "prep"
	_clear_world()
	_prep.visible = true
	_prep.set_process_unhandled_input(true)
	_prep._show_page("home")


func asking_early_close() -> bool:
	return _early_open


func _consider_early_close() -> bool:
	if not _restocks_cleared() or not _registers_idle():
		_early_latched = false
		return false
	if _early_latched:
		return false
	_show_early_dialog()
	return true


func _restocks_cleared() -> bool:
	if _player == null or state == null:
		return false
	var saw := false
	for n in _player.interactables:
		if n == null or not is_instance_valid(n):
			continue
		if String(n.get("kind")) != "restock":
			continue
		saw = true
		if not n.has_method("skus"):
			return false
		for sku in n.skus():
			if int(state.stock.get(sku, 0)) > 0:
				return false
	return saw


func _registers_idle() -> bool:
	for c in cashiers:
		if c != null and is_instance_valid(c) and c.queue.size() > 0:
			return false
	return true


func _show_early_dialog() -> void:
	_early_open = true
	_early_focus = 0
	if _player and _player.has_method("set_hold"):
		_player.set_hold("interact", false)
		_player.set_hold("cancel", false)
		_player.set_hold("dash", false)
		_player.set_hold("skill", false)
		_player.set_hold("ult", false)
	if _early_layer != null and is_instance_valid(_early_layer):
		_early_layer.visible = true
		_paint_early_focus()
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := ColorRect.new()
	card.color = Color("1c241f")
	card.position = Vector2(240, 150)
	card.size = Vector2(800, 420)
	layer.add_child(card)
	var title := Label.new()
	title.text = "提早關店"
	title.position = Vector2(36, 28)
	title.size = Vector2(720, 56)
	UiFont.apply_label(title, 36)
	title.add_theme_color_override("font_color", Color("f4d35e"))
	card.add_child(title)
	var body := Label.new()
	body.text = "所有補貨架都沒有貨了，收銀機也沒有人排隊。\n要提早關店，並結算今天嗎？"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(36, 108)
	body.size = Vector2(720, 110)
	UiFont.apply_label(body, 26)
	body.add_theme_color_override("font_color", Color("f4f1ea"))
	card.add_child(body)
	var hint := Label.new()
	hint.text = "A／D 選擇　　J 確定　　; 取消"
	hint.position = Vector2(36, 228)
	hint.size = Vector2(720, 40)
	UiFont.apply_label(hint, 22)
	hint.add_theme_color_override("font_color", Color("c8c2b4"))
	card.add_child(hint)
	_early_yes = _early_choice("提早關店", Vector2(36, 290), _confirm_early_close)
	_early_no = _early_choice("繼續營業", Vector2(400, 290), _decline_early_close)
	card.add_child(_early_yes)
	card.add_child(_early_no)
	_early_layer = layer
	_paint_early_focus()


func _early_choice(text: String, at: Vector2, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = at
	btn.size = Vector2(360, 88)
	btn.focus_mode = Control.FOCUS_NONE
	UiFont.apply_button(btn, 22)
	btn.pressed.connect(cb)
	return btn


func _paint_early_focus() -> void:
	_style_early_btn(_early_yes, _early_focus == 0)
	_style_early_btn(_early_no, _early_focus == 1)


func _style_early_btn(btn: Button, on: bool) -> void:
	if btn == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f4d35e") if on else Color("24302a")
	box.set_corner_radius_all(10)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state_name, box)
	btn.add_theme_color_override("font_color", Color("1c241f") if on else Color("f4f1ea"))


func _early_input(event: InputEvent) -> void:
	var press := false
	var key := 0
	var joy := -1
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.echo:
			get_viewport().set_input_as_handled()
			return
		press = k.pressed
		key = k.physical_keycode
	elif event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		press = pad.pressed
		joy = pad.button_index
	else:
		return
	get_viewport().set_input_as_handled()
	if not press:
		return
	if key == KEY_A or key == KEY_LEFT or joy == JOY_BUTTON_DPAD_LEFT:
		_early_focus = 0
		_paint_early_focus()
	elif key == KEY_D or key == KEY_RIGHT or joy == JOY_BUTTON_DPAD_RIGHT:
		_early_focus = 1
		_paint_early_focus()
	elif key == KEY_J or key == KEY_ENTER or joy == JOY_BUTTON_A:
		if _early_focus == 0:
			_confirm_early_close()
		else:
			_decline_early_close()
	elif key == KEY_SEMICOLON or key == KEY_BACKSPACE or joy == JOY_BUTTON_B:
		_decline_early_close()


func _confirm_early_close() -> void:
	if not _early_open:
		return
	_hide_early_dialog()
	_early_closed = true
	phase = "closed"
	game_hours = Tuning.CLOSE_HOUR
	_finish_day()


func _decline_early_close() -> void:
	if not _early_open:
		return
	_early_latched = true
	_hide_early_dialog()


func _hide_early_dialog() -> void:
	_early_open = false
	if _early_layer != null and is_instance_valid(_early_layer):
		_early_layer.visible = false


func world_delta(delta: float) -> float:
	if _early_open:
		return 0.0
	if _player == null:
		return delta
	return delta * float(_player.get("clock_scale"))


func customer_move_mult() -> float:
	if _player == null:
		return 1.0
	return float(_player.get("customer_move_mult"))


func _process(delta: float) -> void:
	if phase == "prep" or phase == "closed" or _early_open:
		return
	real_time += world_delta(delta)
	if real_time < Tuning.RESTOCK_REAL_SEC:
		phase = "restock"
		var t := real_time / Tuning.RESTOCK_REAL_SEC
		game_hours = lerpf(Tuning.GAME_START_HOUR, Tuning.OPEN_HOUR, t)
	elif real_time < Tuning.RESTOCK_REAL_SEC + Tuning.OPEN_REAL_SEC:
		phase = "open"
		var t := (real_time - Tuning.RESTOCK_REAL_SEC) / Tuning.OPEN_REAL_SEC
		game_hours = lerpf(Tuning.OPEN_HOUR, Tuning.CLOSE_HOUR, t)
		if _consider_early_close():
			return
		_spawn_in -= world_delta(delta)
		if _spawn_in <= 0.0:
			_spawn_customer()
			_spawn_in = state.spawn_every()
		_thief_spawn_in -= world_delta(delta)
		if _thief_spawn_in <= 0.0:
			_spawn_thief()
			_thief_spawn_in = state.thief_spawn_sec()
	else:
		phase = "closed"
		game_hours = Tuning.CLOSE_HOUR
		_finish_day()
		return
	_dirt_spawn_in -= world_delta(delta)
	if _dirt_spawn_in <= 0.0:
		_try_spawn_dirt()
		_dirt_spawn_in = state.dirt_spawn_sec()


func find_shelf(sku: String) -> Node2D:
	for s in shelves:
		if shelf_has(s, sku):
			return s
	return null


func shelf_has(shelf: Node2D, sku: String) -> bool:
	if shelf == null:
		return false
	return String(shelf.get("sku")) == sku and int(shelf.get("count")) > 0


func take_from_shelf(shelf: Node2D, sku: String) -> bool:
	if not shelf_has(shelf, sku):
		return false
	var n := int(shelf.get("count")) - 1
	shelf.set("count", n)
	if n <= 0:
		shelf.set("sku", "")
		shelf.set("count", 0)
	shelf.call("_refresh")
	return true


func shelf_stand(shelf: Node2D) -> Vector2:
	if shelf and shelf.has_method("stand_position"):
		return shelf.stand_position()
	return shelf.global_position + Vector2(0, -58)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if pathfinder == null:
		return PackedVector2Array([to])
	return pathfinder.find_path(from, to)


func exit_pos() -> Vector2:
	return door_pos() + Vector2(0, -90)


func door_pos() -> Vector2:
	return FLOOR_ORIGIN + Vector2(FLOOR_SIZE.x * 0.5, 8)


func inside_pos() -> Vector2:
	return door_pos() + Vector2(0, 70)


func guest_count() -> int:
	if _customers == null:
		return 0
	var n := 0
	for c in _customers.get_children():
		if c.has_method("occupies_store") and not bool(c.call("occupies_store")):
			continue
		n += 1
	return n


func thief_count() -> int:
	var n := 0
	for c in thieves():
		if c.has_method("is_active_thief") and bool(c.call("is_active_thief")):
			n += 1
	return n


func thieves() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if _customers == null:
		return out
	for c in _customers.get_children():
		if bool(c.get("is_thief")):
			out.append(c)
	return out


func record_stolen(items: Array) -> void:
	for sku in items:
		stolen_count += 1
		stolen_value += Tuning.sku_price(String(sku))
	thieves_escaped += 1


func record_caught() -> void:
	thieves_caught += 1


func clock_text() -> String:
	var h := int(floor(game_hours)) % 24
	var m := int(floor((game_hours - floorf(game_hours)) * 60.0))
	return "%02d:%02d" % [h, m]


func phase_text() -> String:
	match phase:
		"restock":
			return "補貨時段  06:00–08:00  無客人"
		"open":
			return "營運時段  08:00–22:00"
		_:
			return "關店結算"


func _on_paid(amount: int) -> void:
	revenue += amount
	served += 1


func skip_operate() -> void:
	if _settled or (phase != "restock" and phase != "open"):
		return
	if _early_open:
		_hide_early_dialog()
	_skip_xp = 400
	phase = "closed"
	game_hours = Tuning.CLOSE_HOUR
	_finish_day()


func _finish_day() -> void:
	if _settled:
		return
	_settled = true
	var result: Dictionary = state.settle(revenue, served, thieves_caught, cleaned, _skip_xp)
	var save_err := state.save_to_disk()
	if _hud:
		_hud.show_closeout()
		var loss := "虧損（營業額低於進貨）" if bool(result["loss"]) else "未虧損"
		var head := "關店結算"
		if _early_closed:
			head = "提早關店結算"
		elif _skip_xp > 0:
			head = "測試結算"
		var bonus := "（含測試 +%d）" % _skip_xp if _skip_xp > 0 else ""
		var save_line := "已寫入存檔" if save_err == "" else ("存檔失敗：" + save_err)
		_hud._close_text.text = "%s　%s\n營業額 $%d　入帳後資金 $%d\n進貨成本 $%d\n成功收銀 %d　生氣離開 %d\n被偷 %d 件 $%d　抓住 %d／逃走 %d\n經驗 +%d%s　%s\n%s\n按 J／A 返回準備" % [
			head, loss, revenue, state.money, int(result["spent"]), served, angry_left,
			stolen_count, stolen_value, thieves_caught, thieves_escaped,
			int(result["xp"]), bonus, state.level_note, save_line
		]


func _spawn_customer() -> void:
	if state.sellable().is_empty():
		return
	if guest_count() >= state.guest_cap():
		return
	var c: CharacterBody2D = CustomerScript.new()
	_customers.add_child(c)
	c.setup(self, door_pos())


func _spawn_thief() -> void:
	if state.sellable().is_empty():
		return
	if randf() > state.thief_spawn_rate():
		return
	if thief_count() >= Tuning.THIEF_CAP:
		return
	var c: CharacterBody2D = CustomerScript.new()
	_customers.add_child(c)
	c.setup(self, door_pos(), true)
	_add_interactable(c)
	c.tree_exiting.connect(func() -> void: _remove_interactable(c))
	if _player:
		_player.log_line.emit("小偷進店！")


func _floor() -> void:
	var step := StateScript.CELL
	var x := 0.0
	while x < FLOOR_SIZE.x - 0.5:
		var y := 0.0
		while y < FLOOR_SIZE.y - 0.5:
			var tile := Vox.sprite("floor_tile", 0)
			tile.z_index = -8
			tile.position = FLOOR_ORIGIN + Vector2(x + step * 0.5, y + step * 0.5)
			_world.add_child(tile)
			y += step
		x += step


func _walls_and_door() -> void:
	var t := 18.0
	var o := FLOOR_ORIGIN
	var s := FLOOR_SIZE
	var door_w := 90.0
	var mid := o.x + s.x * 0.5
	_solid(Rect2(o.x - t, o.y - t, mid - door_w * 0.5 - (o.x - t), t))
	_solid(Rect2(mid + door_w * 0.5, o.y - t, (o.x + s.x + t) - (mid + door_w * 0.5), t))
	_solid(Rect2(o.x - t, o.y + s.y, s.x + t * 2.0, t))
	_solid(Rect2(o.x - t, o.y, t, s.y))
	_solid(Rect2(o.x + s.x, o.y, t, s.y))
	var north_y := o.y - t * 0.5
	var south_y := o.y + s.y + t * 0.5
	var west_x := o.x - t * 0.5
	var east_x := o.x + s.x + t * 0.5
	_run_wall(Vector2(o.x, north_y), Vector2(mid - door_w * 0.5, north_y), 0)
	_run_wall(Vector2(mid + door_w * 0.5, north_y), Vector2(o.x + s.x, north_y), 0)
	_run_wall(Vector2(o.x, south_y), Vector2(o.x + s.x, south_y), 2)
	_run_wall(Vector2(west_x, o.y), Vector2(west_x, o.y + s.y), 1)
	_run_wall(Vector2(east_x, o.y), Vector2(east_x, o.y + s.y), 3)
	var door := Vox.sprite("door", 0)
	door.z_index = -4
	door.position = Vector2(mid, north_y)
	_world.add_child(door)
	_caption(Vector2(mid - 28, o.y + 6), "大門")


func _run_wall(a: Vector2, b: Vector2, k: int) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 8.0:
		return
	var dir := delta / length
	var count := maxi(1, int(round(length / 64.0)))
	var each := length / float(count)
	for i in count:
		var spr := Vox.sprite("wall", k)
		spr.z_index = -5
		spr.position = a + dir * (each * (float(i) + 0.5))
		_world.add_child(spr)


func _restock(r: Rect2, cat: String) -> Node2D:
	_obstacles.append(r)
	var node: StaticBody2D = RestockScript.new()
	_fit_body(node, r, "restock_" + cat, 0, 2)
	node.body = node.get_node("Body")
	node.label = _caption(r.position + Vector2(4, 18), "")
	node.setup(cat)
	_world.add_child(node)
	node.pull_stock()
	return node


func _make_shelves(cat: String, start: Vector2, count: int, start_index: int) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for i in count:
		var r := Rect2(start + Vector2(i * 168.0, 0), Vector2(140, 70))
		_obstacles.append(r)
		var node: StaticBody2D = ShelfScript.new()
		node.category = cat
		node.shelf_index = start_index + i
		_fit_body(node, r, "shelf_" + cat, 0, 2)
		node.body = node.get_node("Body")
		var lab := Label.new()
		lab.position = Vector2(-58, -18)
		UiFont.apply_label(lab, UiFont.WORLD)
		lab.add_theme_color_override("font_color", Color("fff4c2"))
		lab.add_theme_color_override("font_outline_color", Color("121212"))
		lab.add_theme_constant_override("outline_size", 5)
		node.add_child(lab)
		node.label = lab
		add_child(node)
		node._refresh()
		shelves.append(node)
		out.append(node)
	return out


func _facing(rot: int) -> Vector2:
	match posmod(rot, 4):
		1:
			return Vector2.RIGHT
		2:
			return Vector2.DOWN
		3:
			return Vector2.LEFT
		_:
			return Vector2.UP


func _make_shelf(r: Rect2, cat: String, index: int, rot: int, cap: int = Tuning.SHELF_CAP) -> Node2D:
	_obstacles.append(r)
	var node: StaticBody2D = ShelfScript.new()
	node.category = cat
	node.capacity = cap
	node.shelf_index = index
	node.facing = _facing(rot)
	_fit_body(node, r, "shelf_" + cat, rot, 2)
	node.body = node.get_node("Body")
	var lab := Label.new()
	lab.position = Vector2(-58, -18)
	UiFont.apply_label(lab, UiFont.WORLD)
	lab.add_theme_color_override("font_color", Color("fff4c2"))
	lab.add_theme_color_override("font_outline_color", Color("121212"))
	lab.add_theme_constant_override("outline_size", 5)
	node.add_child(lab)
	node.label = lab
	_world.add_child(node)
	node._refresh()
	shelves.append(node)
	return node


func _make_cashier(r: Rect2, rot: int, index: int) -> Node2D:
	_obstacles.append(r)
	var node: StaticBody2D = CashierScript.new()
	_fit_body(node, r, "register", rot, 2)
	node.register_index = index
	node.set_facing(_facing(rot))
	node.label = _caption(r.position + Vector2(8, 4), "")
	_world.add_child(node)
	cashiers.append(node)
	return node


func _try_spawn_dirt() -> void:
	if _dirts.size() >= Tuning.DIRT_CAP:
		return
	var size := Tuning.DIRT_SIZE
	for _i in 28:
		var origin := FLOOR_ORIGIN + Vector2(
			randf_range(36.0, FLOOR_SIZE.x - size.x - 36.0),
			randf_range(48.0, FLOOR_SIZE.y - size.y - 36.0)
		)
		var r := Rect2(origin, size)
		if _blocked_rect(r):
			continue
		_spawn_dirt(r, Tuning.random_dirt_type())
		return


func _blocked_rect(r: Rect2) -> bool:
	var grow := r.grow(18.0)
	for o in _obstacles:
		if grow.intersects(o):
			return true
	for d in _dirts:
		if not is_instance_valid(d):
			continue
		var other := Rect2(d.global_position - Tuning.DIRT_SIZE * 0.5, Tuning.DIRT_SIZE).grow(24.0)
		if grow.intersects(other):
			return true
	var door := Rect2(door_pos() + Vector2(-70, -20), Vector2(140, 110))
	return grow.intersects(door)


func _spawn_dirt(r: Rect2, dtype: String) -> void:
	var area: Area2D = DirtScript.new()
	area.setup(dtype, r.size)
	area.global_position = r.position + r.size * 0.5
	_world.add_child(area)
	_dirts.append(area)
	_add_interactable(area)
	area.tree_exiting.connect(_on_dirt_gone.bind(area))


func _on_dirt_gone(area: Node2D) -> void:
	_dirts.erase(area)
	_remove_interactable(area)


func _add_interactable(node: Node2D) -> void:
	if _player == null:
		return
	if not _player.interactables.has(node):
		_player.interactables.append(node)


func _remove_interactable(node: Node2D) -> void:
	if _player == null:
		return
	_player.interactables.erase(node)


func spawn_dropped_box(pos: Vector2, sku: String, n: int) -> void:
	var drop: Area2D = DroppedBoxScript.new()
	drop.setup(sku, n)
	drop.global_position = pos + Vector2(randf_range(-18, 18), 22)
	_world.add_child(drop)
	_add_interactable(drop)
	drop.tree_exiting.connect(func() -> void: _remove_interactable(drop))


func _make_player() -> CharacterBody2D:
	var p: CharacterBody2D = PlayerScript.new()
	p.name = "Clerk"
	p.collision_layer = 1
	p.collision_mask = 1 | 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 26)
	shape.shape = rect
	p.add_child(shape)
	var body := Vox.sprite("player", Vox.k_from_facing(Vector2.DOWN))
	body.name = "Body"
	p.add_child(body)
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.color = Color("f4f1ea")
	arrow.polygon = PackedVector2Array([Vector2(-6, 4), Vector2(6, 4), Vector2(0, 14)])
	p.add_child(arrow)
	p.bind_visuals(body, arrow)
	return p


func _solid(r: Rect2) -> void:
	_obstacles.append(r)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	col.shape = shape
	body.add_child(col)
	_world.add_child(body)


func _fit_body(body: StaticBody2D, r: Rect2, model_id: String, rot: int, layer: int = 1) -> void:
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var spr := Vox.sprite(model_id, Vox.k_from_rot(rot))
	spr.name = "Body"
	Vox.fit(spr, r.size)
	body.add_child(spr)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	col.shape = shape
	body.add_child(col)


func _caption(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.z_index = 3
	UiFont.apply_label(l, UiFont.WORLD)
	l.add_theme_color_override("font_color", Color("fff4c2"))
	l.add_theme_color_override("font_outline_color", Color("121212"))
	l.add_theme_constant_override("outline_size", 5)
	_world.add_child(l)
	return l
