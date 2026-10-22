extends CharacterBody2D

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

enum State { ENTER, SEEK, LINGER, THINK, TO_CASHIER, QUEUE, PAYING, LEAVE, FIGHT, FLEE, RAID }

var state: int = State.ENTER
var shopping: Array[String] = []
var cart: Array[String] = []
var dissatisfaction: float = 0.0
var checkout_seq: Array[int] = []
var dirt_contacts: int = 0
var _dirt_areas: Array[Node] = []
var mood: String = "購物"
var is_thief: bool = false
var kind: String = ""
var fight_hp: float = 100.0
var fight_left: float = 0.0

var _timer: float = 0.0
var _target_shelf: Node2D
var _game: Node
var register: Node2D
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0
var _goal: Vector2 = Vector2.ZERO
var _stuck: float = 0.0
var _body: CanvasItem
var _list_label: Label
var _mood_label: Label
var _bar: ColorRect
var _hp_track: ColorRect
var _hp_bar: ColorRect
var _timer_lab: Label
var _flee_dir: Vector2 = Vector2.UP
var _flee_left: float = 0.0
var raided: bool = false
## Cached label / chrome values — only write nodes when these change.
var _shown_list: String = "\u0001"
var _shown_mood: String = "\u0001"
var _shown_bar_w: float = -1.0
var _shown_bar_t: float = -1.0
var _shown_fighting: bool = false
var _shown_timer: String = "\u0001"
var _shown_hp_w: float = -1.0
var _shown_facing: int = -999
var _shown_tint: Color = Color(0, 0, 0, 0)


func setup(game: Node, door: Vector2, thief: bool = false) -> void:
	_game = game
	is_thief = thief
	kind = "thief" if thief else ""
	global_position = door + Vector2(randf_range(-20, 20), -40)
	shopping = _roll_list()
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = Tuning.LAYER_CUSTOMERS
	collision_mask = Tuning.LAYER_WALLS
	_build_visual()
	_sync_labels()


func add_dirt(delta_count: int) -> void:
	dirt_contacts = maxi(0, dirt_contacts + delta_count)


func enter_dirt(area: Node) -> void:
	if area != null and not _dirt_areas.has(area):
		_dirt_areas.append(area)
	dirt_contacts = _dirt_areas.size()


func exit_dirt(area: Node) -> void:
	_dirt_areas.erase(area)
	dirt_contacts = _dirt_areas.size()


func on_dirt() -> bool:
	var keep: Array[Node] = []
	for a in _dirt_areas:
		if is_instance_valid(a):
			keep.append(a)
	_dirt_areas = keep
	dirt_contacts = _dirt_areas.size()
	return dirt_contacts > 0


func _dirt_dissat_rate() -> float:
	var rate := 0.0
	for a in _dirt_areas:
		if is_instance_valid(a):
			rate = maxf(rate, float(a.call("diss_per_sec")))
	return rate


func _dirt_mood() -> String:
	var worst := ""
	var rate := 0.0
	for a in _dirt_areas:
		if not is_instance_valid(a):
			continue
		var r := float(a.call("diss_per_sec"))
		if r >= rate:
			rate = r
			worst = String(a.call("type_name"))
	return "踩到%s！" % worst if worst != "" else "踩到污物！"


func cart_total() -> int:
	var n := 0
	for sku in cart:
		n += Tuning.sku_price(sku)
	return n


func begin_paying() -> void:
	state = State.PAYING
	mood = "付款中"
	_sync_labels()


func cancel_pay() -> void:
	if state == State.PAYING:
		state = State.QUEUE
		mood = "排隊中"


func finish_paid() -> void:
	mood = "謝謝"
	_leave(false)


func occupies_store() -> bool:
	return state != State.LEAVE and state != State.FLEE and not is_thief


func is_active_thief() -> bool:
	## Catchable / dashable until fully off-map — including shopping-done LEAVE.
	## FLEE is already being knocked away (KO / dash).
	return is_thief and state != State.FLEE


func in_fight() -> bool:
	return state == State.FIGHT


func _reg() -> Node2D:
	if register != null and is_instance_valid(register):
		return register
	return null


func is_at_register() -> bool:
	if state != State.QUEUE and state != State.PAYING:
		return false
	var reg := _reg()
	if reg == null:
		return false
	if reg.front_customer() != self:
		return false
	var slot: Vector2 = reg.slot_position(0)
	return global_position.distance_to(slot) <= Tuning.CUSTOMER_ARRIVE_DIST + 6.0


func _physics_process(delta: float) -> void:
	if _game == null:
		return
	if _game.has_method("asking_early_close") and bool(_game.asking_early_close()):
		velocity = Vector2.ZERO
		return
	var td := float(_game.call("world_delta", delta))
	if String(_game.get("phase")) == "closed" and state != State.LEAVE and state != State.FLEE and state != State.FIGHT:
		if is_thief:
			escape_with_loot()
		else:
			_leave(true)
	if on_dirt() and state != State.LEAVE and state != State.FIGHT and state != State.FLEE and not is_thief:
		dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + _dirt_dissat_rate() * td)
		mood = _dirt_mood()
	if _lord_pull():
		if state != State.RAID:
			if state == State.PAYING and _game.has_method("release_player_checkout"):
				_game.call("release_player_checkout")
			if _reg():
				_reg().dequeue(self)
			state = State.RAID
			mood = "搶購！"
			_clear_route()
	elif state == State.RAID:
		_end_raid()
	match state:
		State.ENTER:
			if _follow_to(_game.inside_pos(), delta):
				state = State.SEEK
				_clear_route()
		State.SEEK:
			_tick_seek(delta)
		State.LINGER:
			_timer -= td
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_take_current()
		State.THINK:
			velocity = Vector2.ZERO
			_timer -= td
			if _timer <= 0.0:
				_after_think()
		State.TO_CASHIER:
			if _reg() == null:
				_leave(false)
			elif _follow_to(_reg().slot_position(_queue_index_guess()), delta):
				state = State.QUEUE
				_clear_route()
		State.QUEUE:
			_tick_queue(delta, td)
		State.PAYING:
			velocity = Vector2.ZERO
		State.FIGHT:
			velocity = Vector2.ZERO
		State.FLEE:
			_tick_flee(delta)
		State.LEAVE:
			if _follow_to(_game.call("exit_pos"), delta):
				if is_thief:
					_finish_thief_exit()
				queue_free()
		State.RAID:
			_tick_raid(delta)
	if not is_thief and dissatisfaction >= Tuning.DISSAT_MAX and state != State.LEAVE:
		_leave(true)
	_sync_labels()


func _tick_seek(delta: float) -> void:
	if shopping.is_empty():
		if is_thief:
			escape_with_loot()
			return
		if not _join_register():
			mood = "沒有收銀機"
			_leave(false)
			return
		state = State.TO_CASHIER
		mood = "去付款"
		return
	var want := shopping[0]
	var shelf: Node2D = _game.find_shelf(want)
	_target_shelf = shelf
	if shelf == null:
		state = State.THINK
		_timer = Tuning.THINK_SEC
		if not is_thief:
			dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + Tuning.DISSAT_MISS)
		mood = "找不到%s" % Tuning.sku_name(want)
		return
	var stand: Vector2 = _game.call("shelf_stand", shelf)
	if _follow_to(stand, delta):
		state = State.LINGER
		_timer = Tuning.LINGER_SEC
		mood = "取貨"
		_clear_route()


func _take_current() -> void:
	var want := shopping[0]
	var shelf: Node2D = _target_shelf
	if shelf == null or not bool(_game.callv("shelf_has", [shelf, want])):
		shelf = _game.find_shelf(want)
		_target_shelf = shelf
	if shelf and bool(_game.callv("take_from_shelf", [shelf, want])):
		cart.append(want)
		shopping.remove_at(0)
		mood = "拿到%s" % Tuning.sku_name(want)
		state = State.SEEK
		_target_shelf = null
	else:
		state = State.THINK
		_timer = Tuning.THINK_SEC
		if not is_thief:
			dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + Tuning.DISSAT_MISS)
		mood = "找不到%s" % Tuning.sku_name(want)
		_target_shelf = null


func _after_think() -> void:
	if shopping.size() > 1:
		var first := shopping[0]
		shopping.remove_at(0)
		shopping.append(first)
		state = State.SEEK
		mood = "先找下一件"
	else:
		if is_thief:
			escape_with_loot()
			return
		state = State.THINK
		_timer = Tuning.THINK_SEC
		dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + Tuning.DISSAT_MISS)
		mood = "還是找不到…"


func _lord_pull() -> bool:
	if is_thief or _game == null:
		return false
	if state == State.LEAVE or state == State.FLEE or state == State.FIGHT:
		return false
	return _game.has_method("yes_my_lord_on") and bool(_game.call("yes_my_lord_on"))


func grab_items(items: Array) -> void:
	for sku in items:
		cart.append(String(sku))
	if items.size() > 0:
		raided = true


func _tick_raid(delta: float) -> void:
	var shelf: Node2D = _game.call("nearest_stocked_shelf", global_position)
	if shelf == null:
		velocity = Vector2.ZERO
		return
	var stand: Vector2 = _game.call("shelf_stand", shelf)
	if _follow_to(stand, delta):
		var items: Array = shelf.call("take_all")
		grab_items(items)
		if items.size() > 0:
			mood = "搶到%d件" % items.size()
		_clear_route()


func _end_raid() -> void:
	_clear_route()
	if not _join_register():
		mood = "沒有收銀機"
		_leave(false)
		return
	state = State.TO_CASHIER
	mood = "去付款"


func _join_register() -> bool:
	if _game == null or not _game.has_method("pick_register"):
		return false
	register = _game.pick_register(self)
	if register == null:
		return false
	register.enqueue(self)
	return true


func _tick_queue(delta: float, td: float) -> void:
	var reg := _reg()
	if reg == null:
		_leave(false)
		return
	reg.enqueue(self)
	var idx: int = int(reg.queue.find(self))
	if idx < 0:
		idx = int(reg.queue.size())
	var slot: Vector2 = reg.slot_position(idx)
	if _follow_to(slot, delta):
		velocity = Vector2.ZERO
	var blocked := _game and _game.has_method("queue_dissat_blocked") and bool(_game.queue_dissat_blocked())
	if not is_thief and not blocked:
		dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + Tuning.DISSAT_QUEUE_PER_SEC * td)
	mood = "排隊中"


func _queue_index_guess() -> int:
	var reg := _reg()
	if reg == null:
		return 0
	var idx: int = int(reg.queue.find(self))
	return idx if idx >= 0 else int(reg.queue.size())


func _follow_to(pos: Vector2, delta: float) -> bool:
	if global_position.distance_to(pos) <= Tuning.CUSTOMER_ARRIVE_DIST:
		velocity = Vector2.ZERO
		return true
	if _path.is_empty() or pos.distance_to(_goal) > 18.0:
		_goal = pos
		_path = _game.call("find_path", global_position, pos)
		_path_i = 0
	while _path_i < _path.size() and global_position.distance_to(_path[_path_i]) <= 16.0:
		_path_i += 1
	var next := pos
	if _path_i < _path.size():
		next = _path[_path_i]
	var to := next - global_position
	if to.length() < 1.0:
		velocity = Vector2.ZERO
		return global_position.distance_to(pos) <= Tuning.CUSTOMER_ARRIVE_DIST
	var spd := Tuning.WALK_SPEED * Tuning.agi_mult(Tuning.CUSTOMER_AGI)
	spd *= float(_game.call("customer_move_mult"))
	if on_dirt() and state != State.LEAVE:
		spd *= Tuning.DIRT_MULT
	if spd <= 0.01:
		velocity = Vector2.ZERO
		return false
	spd = maxf(Tuning.SPEED_FLOOR, spd)
	velocity = to.normalized() * spd
	move_and_slide()
	if get_real_velocity().length() < 12.0:
		_stuck += delta
		if _stuck > 0.35:
			_clear_route()
			_stuck = 0.0
	else:
		_stuck = 0.0
	return false


func _clear_route() -> void:
	_path = PackedVector2Array()
	_path_i = 0
	_goal = Vector2.ZERO
	_stuck = 0.0


func _leave(angry: bool) -> void:
	if state == State.LEAVE:
		return
	if _reg():
		_reg().dequeue(self)
	state = State.LEAVE
	if is_thief:
		## Stay fully present so the clerk can still grab / dash until exit.
		if mood != "得手離開":
			mood = "離開"
		collision_layer = Tuning.LAYER_CUSTOMERS
		collision_mask = Tuning.LAYER_WALLS
		z_index = 0
		modulate.a = 1.0
	else:
		mood = "生氣離開" if angry else "離開"
		collision_layer = 0
		collision_mask = Tuning.LAYER_WALLS
		z_index = -1
		modulate.a = 0.75
	_clear_route()
	if angry and _game:
		_game.angry_left += 1


func begin_fight() -> void:
	state = State.FIGHT
	fight_hp = 100.0
	fight_left = Tuning.FIGHT_SEC
	velocity = Vector2.ZERO
	mood = "被抓住！"
	## Restore full presence if grabbed while walking out.
	collision_layer = Tuning.LAYER_CUSTOMERS
	collision_mask = Tuning.LAYER_WALLS
	z_index = 0
	modulate.a = 1.0
	_clear_route()
	_sync_labels()


func take_hit(amount: float) -> bool:
	fight_hp = maxf(0.0, fight_hp - amount)
	_sync_labels()
	return fight_hp <= 0.0


func drop_loot_and_leave() -> void:
	## Legacy path: near scatter + walk off (KO fight uses ko_scatter_and_flee).
	_scatter_cart(Tuning.LOOT_SCATTER_MELEE_MIN, Tuning.LOOT_SCATTER_MELEE_MAX)
	mood = "丟下贓物跑了"
	_leave(false)


func escape_with_loot() -> void:
	## Defer stolen stats / banner until the thief actually reaches the exit.
	## Cart stays so grab / dash on the way out can still recover loot.
	mood = "得手離開"
	_leave(false)


## Called when a leaving thief reaches the door — only then count as stolen.
func _finish_thief_exit() -> void:
	if cart.is_empty():
		return
	if _game and _game.has_method("record_stolen"):
		_game.call("record_stolen", cart)
	if _game and _game.has_method("show_stolen_banner"):
		_game.call("show_stolen_banner")
	cart.clear()


## Fight mash win: loot scatters nearby, then thief is KO-flown off-screen.
func ko_scatter_and_flee(dir: Vector2) -> void:
	if state == State.FLEE:
		return
	if _reg():
		_reg().dequeue(self)
	_scatter_cart(Tuning.LOOT_SCATTER_MELEE_MIN, Tuning.LOOT_SCATTER_MELEE_MAX)
	_begin_flee(dir, "被打飛！")


func dash_knock_away(dir: Vector2) -> void:
	if state == State.FLEE:
		return
	if _reg():
		_reg().dequeue(self)
	## Dash: loot scatters farther (≤ 5 身位); not counted as stolen or catch.
	_scatter_cart(Tuning.LOOT_SCATTER_DASH_MIN, Tuning.LOOT_SCATTER_DASH_MAX)
	_begin_flee(dir, "被撞飛！")


func _scatter_cart(min_r: float, max_r: float) -> void:
	if cart.is_empty() or _game == null:
		cart.clear()
		return
	var piles: Array[Dictionary] = Tuning.loot_piles_from_cart(cart)
	cart.clear()
	if piles.is_empty():
		return
	if _game.has_method("spawn_loot_scatter"):
		_game.call("spawn_loot_scatter", global_position, piles, min_r, max_r)
	elif _game.has_method("spawn_dropped_box"):
		for pile in piles:
			_game.call("spawn_dropped_box", global_position, String(pile["sku"]), int(pile["n"]))


func _begin_flee(dir: Vector2, flee_mood: String) -> void:
	state = State.FLEE
	_flee_dir = dir.normalized() if dir.length_squared() > 0.01 else Vector2.UP
	_flee_left = 0.55
	collision_layer = 0
	collision_mask = 0
	mood = flee_mood
	z_index = 8
	_clear_route()


func _tick_flee(delta: float) -> void:
	_flee_left -= delta
	velocity = _flee_dir * 520.0
	move_and_slide()
	rotation += delta * 14.0
	if _flee_left <= 0.0:
		queue_free()


func _roll_list() -> Array[String]:
	var pool: Array[String] = []
	if _game and _game.has_method("sellable"):
		pool = _game.sellable()
	if pool.is_empty():
		return []
	var lo := Tuning.LIST_MIN
	var hi := Tuning.LIST_MAX
	if is_thief:
		lo = Tuning.THIEF_LIST_MIN
		hi = Tuning.THIEF_LIST_MAX
	elif _game and _game.has_method("customer_list_bounds"):
		var bounds: Vector2i = _game.customer_list_bounds()
		lo = bounds.x
		hi = bounds.y
	var n := randi_range(lo, hi)
	n = mini(n, Tuning.LIST_HARD_MAX)
	var out: Array[String] = []
	for i in n:
		out.append(pool[randi() % pool.size()])
	return out


func _build_visual() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 22)
	shape.shape = rect
	add_child(shape)
	_body = Vox.animated("thief" if is_thief else "customer")
	add_child(_body)
	_mood_label = Label.new()
	_mood_label.position = Vector2(-72, -78)
	UiFont.apply_label(_mood_label, UiFont.WORLD)
	_mood_label.add_theme_color_override("font_color", Color("7ecbff"))
	_mood_label.add_theme_color_override("font_outline_color", Color("121212"))
	_mood_label.add_theme_constant_override("outline_size", 6)
	add_child(_mood_label)
	_list_label = Label.new()
	_list_label.position = Vector2(-80, -52)
	UiFont.apply_label(_list_label, UiFont.WORLD)
	_list_label.add_theme_color_override("font_color", Color("ffe566"))
	_list_label.add_theme_color_override("font_outline_color", Color("121212"))
	_list_label.add_theme_constant_override("outline_size", 6)
	add_child(_list_label)
	var track := ColorRect.new()
	track.size = Vector2(28, 4)
	track.position = Vector2(-14, 14)
	track.color = Color("1b2420")
	add_child(track)
	if is_thief:
		track.visible = false
	_bar = ColorRect.new()
	_bar.size = Vector2(28, 4)
	_bar.position = Vector2(-14, 14)
	_bar.color = Color("2a9d8f")
	add_child(_bar)
	_hp_track = ColorRect.new()
	_hp_track.size = Vector2(40, 6)
	_hp_track.position = Vector2(-20, -88)
	_hp_track.color = Color("1b2420")
	_hp_track.visible = false
	add_child(_hp_track)
	_hp_bar = ColorRect.new()
	_hp_bar.size = Vector2(40, 6)
	_hp_bar.position = Vector2(-20, -88)
	_hp_bar.color = Color("c0392b")
	_hp_bar.visible = false
	add_child(_hp_bar)
	_timer_lab = Label.new()
	_timer_lab.position = Vector2(-18, -108)
	_timer_lab.visible = false
	UiFont.apply_label(_timer_lab, UiFont.WORLD)
	_timer_lab.add_theme_color_override("font_color", Color("f4d35e"))
	_timer_lab.add_theme_color_override("font_outline_color", Color("121212"))
	_timer_lab.add_theme_constant_override("outline_size", 6)
	add_child(_timer_lab)
	if is_thief:
		_bar.visible = false


func _visual_anim() -> String:
	if state == State.FIGHT:
		return "fight"
	if state == State.FLEE:
		return "fly" if is_thief else "leave"
	if state == State.LEAVE:
		return "leave"
	if not is_thief and dissatisfaction > Tuning.DISSAT_MAX * 0.7 and velocity.length() <= 8.0:
		return "angry"
	if velocity.length() > 8.0:
		return "walk"
	return "idle"


## Public alias for hosts that still call `_refresh_labels` (e.g. fight tick).
func _refresh_labels() -> void:
	_sync_labels()


func _list_label_text() -> String:
	var bits: PackedStringArray = []
	for sku in shopping:
		bits.append(Tuning.sku_name(sku))
	if is_thief:
		var loot: PackedStringArray = []
		for sku in cart:
			loot.append(Tuning.sku_name(sku))
		return "小偷  " + ("、".join(bits) if bits.size() else "得手 " + ("、".join(loot) if loot.size() else "空手"))
	var line := "、".join(bits) if bits.size() else "（清單完成）"
	if raided:
		line += "　已取%d" % cart.size()
	return line


func _sync_labels() -> void:
	var list_txt := _list_label_text()
	if _list_label and list_txt != _shown_list:
		_shown_list = list_txt
		_list_label.text = list_txt
	if _mood_label and mood != _shown_mood:
		_shown_mood = mood
		_mood_label.text = mood
	if _bar and not is_thief:
		var t := clampf(dissatisfaction / Tuning.DISSAT_MAX, 0.0, 1.0)
		var bar_w := snappedf(28.0 * (1.0 - t), 0.5)
		var t_q := snappedf(t, 0.02)
		if not is_equal_approx(bar_w, _shown_bar_w):
			_shown_bar_w = bar_w
			_bar.size.x = bar_w
		if not is_equal_approx(t_q, _shown_bar_t):
			_shown_bar_t = t_q
			var green := Color("2a9d8f")
			var yellow := Color("e8c36a")
			var red := Color("c45c26")
			_bar.color = green.lerp(yellow, t_q / 0.5) if t_q < 0.5 else yellow.lerp(red, (t_q - 0.5) / 0.5)
	if _hp_bar:
		var fighting := state == State.FIGHT
		if fighting != _shown_fighting:
			_shown_fighting = fighting
			_hp_track.visible = fighting
			_hp_bar.visible = fighting
			if _timer_lab:
				_timer_lab.visible = fighting
		if fighting:
			var timer_txt := "%.1f" % fight_left
			if _timer_lab and timer_txt != _shown_timer:
				_shown_timer = timer_txt
				_timer_lab.text = timer_txt
			var hp_w := snappedf(40.0 * clampf(fight_hp / 100.0, 0.0, 1.0), 0.5)
			if not is_equal_approx(hp_w, _shown_hp_w):
				_shown_hp_w = hp_w
				_hp_bar.size.x = hp_w
	if _body:
		var tint := Color.WHITE
		if is_thief and state == State.FIGHT:
			tint = Color(1.0, 0.45, 0.5)
		elif not is_thief and dissatisfaction > Tuning.DISSAT_MAX * 0.7:
			tint = Color(1.0, 0.62, 0.4)
		if tint != _shown_tint:
			_shown_tint = tint
			_body.modulate = tint
		var face_v := velocity if velocity.length() > 8.0 else Vector2.DOWN
		var facing := Vox.k_from_facing(face_v)
		var anim := _visual_anim()
		var anim_key := "%s_%d" % [anim, facing]
		if _body is AnimatedSprite2D:
			if facing != _shown_facing or anim_key != String(_body.get_meta("shown_anim", "")):
				_shown_facing = facing
				_body.set_meta("shown_anim", anim_key)
				Vox.play_anim(_body as AnimatedSprite2D, "thief" if is_thief else "customer", anim, face_v)
		elif _body is Sprite2D and facing != _shown_facing:
			_shown_facing = facing
			Vox.apply(_body as Sprite2D, "thief" if is_thief else "customer", facing)
