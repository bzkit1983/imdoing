extends CharacterBody2D

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")

enum State { ENTER, SEEK, LINGER, THINK, TO_CASHIER, QUEUE, PAYING, LEAVE }

var state: int = State.ENTER
var shopping: Array[String] = []
var cart: Array[String] = []
var dissatisfaction: float = 0.0
var checkout_seq: Array[int] = []
var dirt_contacts: int = 0
var mood: String = "購物"

var _timer: float = 0.0
var _target_shelf: Node2D
var _game: Node
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0
var _goal: Vector2 = Vector2.ZERO
var _stuck: float = 0.0
var _body: Polygon2D
var _list_label: Label
var _mood_label: Label
var _bar: ColorRect


func setup(game: Node, door: Vector2) -> void:
	_game = game
	global_position = door + Vector2(randf_range(-20, 20), -40)
	shopping = _roll_list()
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = Tuning.LAYER_CUSTOMERS
	collision_mask = Tuning.LAYER_WALLS
	_build_visual()
	_refresh_labels()


func add_dirt(delta_count: int) -> void:
	dirt_contacts = maxi(0, dirt_contacts + delta_count)


func on_dirt() -> bool:
	return dirt_contacts > 0


func cart_total() -> int:
	var n := 0
	for sku in cart:
		n += Tuning.sku_price(sku)
	return n


func begin_paying() -> void:
	state = State.PAYING
	mood = "付款中"
	_refresh_labels()


func cancel_pay() -> void:
	if state == State.PAYING:
		state = State.QUEUE
		mood = "排隊中"


func finish_paid() -> void:
	mood = "謝謝"
	_leave(false)


func occupies_store() -> bool:
	return state != State.LEAVE


func is_at_register() -> bool:
	if state != State.QUEUE and state != State.PAYING:
		return false
	if _game == null or _game.cashier == null:
		return false
	if _game.cashier.front_customer() != self:
		return false
	var slot: Vector2 = _game.cashier.slot_position(0)
	return global_position.distance_to(slot) <= Tuning.CUSTOMER_ARRIVE_DIST + 6.0


func _physics_process(delta: float) -> void:
	if _game == null:
		return
	var td := float(_game.call("world_delta", delta))
	if String(_game.get("phase")) == "closed" and state != State.LEAVE:
		_leave(true)
	if on_dirt() and state != State.LEAVE:
		dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + Tuning.DISSAT_DIRT_PER_SEC * td)
		mood = "踩到污物！"
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
			if _follow_to(_game.cashier.slot_position(_queue_index_guess()), delta):
				state = State.QUEUE
				_clear_route()
		State.QUEUE:
			_tick_queue(delta, td)
		State.PAYING:
			velocity = Vector2.ZERO
		State.LEAVE:
			if _follow_to(_game.call("exit_pos"), delta):
				queue_free()
	if dissatisfaction >= Tuning.DISSAT_MAX and state != State.LEAVE:
		_leave(true)
	_refresh_labels()


func _tick_seek(delta: float) -> void:
	if shopping.is_empty():
		state = State.TO_CASHIER
		mood = "去付款"
		_game.cashier.enqueue(self)
		return
	var want := shopping[0]
	var shelf: Node2D = _game.find_shelf(want)
	_target_shelf = shelf
	if shelf == null:
		state = State.THINK
		_timer = Tuning.THINK_SEC
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
		state = State.THINK
		_timer = Tuning.THINK_SEC
		dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + Tuning.DISSAT_MISS)
		mood = "還是找不到…"


func _tick_queue(delta: float, td: float) -> void:
	_game.cashier.enqueue(self)
	var idx: int = int(_game.cashier.queue.find(self))
	if idx < 0:
		idx = int(_game.cashier.queue.size())
	var slot: Vector2 = _game.cashier.slot_position(idx)
	if _follow_to(slot, delta):
		velocity = Vector2.ZERO
	dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + Tuning.DISSAT_QUEUE_PER_SEC * td)
	mood = "排隊中"


func _queue_index_guess() -> int:
	var idx: int = int(_game.cashier.queue.find(self))
	return idx if idx >= 0 else int(_game.cashier.queue.size())


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
	if _game and _game.cashier:
		_game.cashier.dequeue(self)
	state = State.LEAVE
	mood = "生氣離開" if angry else "離開"
	collision_layer = 0
	collision_mask = Tuning.LAYER_WALLS
	z_index = -1
	modulate.a = 0.75
	_clear_route()
	if angry and _game:
		_game.angry_left += 1


func _roll_list() -> Array[String]:
	var n := randi_range(Tuning.LIST_MIN, Tuning.LIST_MAX)
	n = mini(n, Tuning.LIST_HARD_MAX)
	var out: Array[String] = []
	for i in n:
		out.append(Tuning.SELLABLE_SKUS[randi() % Tuning.SELLABLE_SKUS.size()])
	return out


func _build_visual() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 22)
	shape.shape = rect
	add_child(shape)
	_body = Polygon2D.new()
	_body.color = Color("6b5b95")
	_body.polygon = PackedVector2Array([
		Vector2(-11, -11), Vector2(11, -11), Vector2(11, 11), Vector2(-11, 11)
	])
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
	_bar = ColorRect.new()
	_bar.size = Vector2(28, 4)
	_bar.position = Vector2(-14, 14)
	_bar.color = Color("2a9d8f")
	add_child(_bar)


func _refresh_labels() -> void:
	if _list_label:
		var bits: PackedStringArray = []
		for sku in shopping:
			bits.append(Tuning.sku_name(sku))
		_list_label.text = "、".join(bits) if bits.size() else "（清單完成）"
	if _mood_label:
		_mood_label.text = mood
	if _bar:
		var t := clampf(dissatisfaction / Tuning.DISSAT_MAX, 0.0, 1.0)
		var remain := 1.0 - t
		_bar.size.x = 28.0 * remain
		var green := Color("2a9d8f")
		var yellow := Color("e8c36a")
		var red := Color("c45c26")
		_bar.color = green.lerp(yellow, t / 0.5) if t < 0.5 else yellow.lerp(red, (t - 0.5) / 0.5)
	if _body:
		_body.color = Color("c45c26") if dissatisfaction > Tuning.DISSAT_MAX * 0.7 else Color("6b5b95")
