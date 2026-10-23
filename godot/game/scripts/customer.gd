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
## Alpha pace variant: normal / hurry / slow → distinct model (not full recolor).
var pace: String = "normal"
var _model_id: String = "customer"
var fight_hp: float = 100.0
var fight_left: float = 0.0
var _pace_speed: float = 1.0

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
## Wall-clock while leaving; force-despawn if wedged at the door.
var _leave_elapsed: float = 0.0
const LEAVE_TIMEOUT_SEC := 5.0
var raided: bool = false
var _list_rev: int = 0
var _list_rev_drawn: int = -1
var _list_cache: String = ""
var _queue_idx: int = -1
var _seek_shelf_refresh: float = 0.0
var _occupy_counted: bool = false
var _on_dirt_cached: bool = false
## After dash Screen KO: freeze actions this long (seconds).
var _dash_stun_left: float = 0.0
var _dash_ko_tween: Tween
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
	if thief:
		pace = "normal"
		_model_id = "thief"
		_pace_speed = 1.0
	else:
		_roll_pace()
	global_position = door + Vector2(randf_range(-20, 20), -40)
	shopping = _roll_list()
	_bump_list()
	_occupy_counted = not thief
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = Tuning.LAYER_CUSTOMERS
	collision_mask = Tuning.LAYER_WALLS
	_build_visual()
	_sync_labels()


func _roll_pace() -> void:
	var roll := randf()
	if roll < 0.34:
		pace = "hurry"
		_model_id = "customer_hurry"
		_pace_speed = 1.22
	elif roll < 0.67:
		pace = "slow"
		_model_id = "customer_slow"
		_pace_speed = 0.78
	else:
		pace = "normal"
		_model_id = "customer"
		_pace_speed = 1.0
	if not Vox.has_anim(_model_id, "walk"):
		_model_id = "customer"


func add_dirt(delta_count: int) -> void:
	dirt_contacts = maxi(0, dirt_contacts + delta_count)


func exit_dirt(area: Node) -> void:
	_dirt_areas.erase(area)
	dirt_contacts = _dirt_areas.size()
	_on_dirt_cached = dirt_contacts > 0


func enter_dirt(area: Node) -> void:
	if area != null and not _dirt_areas.has(area):
		_dirt_areas.append(area)
	dirt_contacts = _dirt_areas.size()
	_on_dirt_cached = dirt_contacts > 0


func on_dirt() -> bool:
	## Trust enter/exit; freed areas prune on exit_dirt / _unoccupy.
	return _on_dirt_cached


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
	SfxBus.play("sfx_guest_paid_leave")
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
	if _dash_stun_left > 0.0:
		_dash_stun_left = maxf(0.0, _dash_stun_left - delta)
		velocity = Vector2.ZERO
		_sync_labels()
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
			_tick_leave(delta, td)
		State.RAID:
			_tick_raid(delta)
	if not is_thief and dissatisfaction >= Tuning.DISSAT_MAX and state != State.LEAVE:
		_leave(true)
	_sync_labels()


func _tick_seek(delta: float) -> void:
	if shopping.is_empty():
		_begin_checkout("去付款")
		return
	var want := shopping[0]
	_seek_shelf_refresh -= delta
	if _target_shelf == null or not is_instance_valid(_target_shelf) or not _game.shelf_has(_target_shelf, want) or _seek_shelf_refresh <= 0.0:
		_target_shelf = _game.find_shelf(want)
		_seek_shelf_refresh = Tuning.SEEK_SHELF_REFRESH_SEC
	var shelf: Node2D = _target_shelf
	if shelf == null:
		state = State.THINK
		_timer = Tuning.THINK_SEC
		SfxBus.play("sfx_guest_think")
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
		_bump_list()
		mood = "拿到%s" % Tuning.sku_name(want)
		SfxBus.play("sfx_guest_take")
		state = State.SEEK
		_target_shelf = null
	else:
		state = State.THINK
		_timer = Tuning.THINK_SEC
		SfxBus.play("sfx_guest_think")
		if not is_thief:
			dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + Tuning.DISSAT_MISS)
		mood = "找不到%s" % Tuning.sku_name(want)
		_target_shelf = null


func _after_think() -> void:
	## Toss / other paths may empty the list while still in THINK.
	if shopping.is_empty():
		_begin_checkout("去付款")
		return
	if shopping.size() > 1:
		var first := shopping[0]
		shopping.remove_at(0)
		shopping.append(first)
		_bump_list()
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


## Shopping done → join a register and walk to pay (shared by seek / think / toss / raid).
func _begin_checkout(pay_mood: String = "去付款") -> void:
	if is_thief:
		escape_with_loot()
		return
	if state == State.TO_CASHIER or state == State.QUEUE or state == State.PAYING:
		mood = pay_mood
		return
	_clear_route()
	if not _join_register():
		mood = "沒有收銀機"
		_leave(false)
		return
	state = State.TO_CASHIER
	mood = pay_mood
	_timer = 0.0


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
		_bump_list()


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
	_begin_checkout("去付款")


func _join_register() -> bool:
	if _game == null or not _game.has_method("pick_register"):
		return false
	register = _game.pick_register(self)
	if register == null:
		return false
	register.enqueue(self)
	SfxBus.play("sfx_guest_queue")
	return true


func _tick_queue(delta: float, td: float) -> void:
	var reg := _reg()
	if reg == null:
		_leave(false)
		return
	if _queue_idx < 0:
		reg.enqueue(self)
	var idx := _resolve_queue_idx(reg)
	_queue_idx = idx
	var slot: Vector2 = reg.slot_position(idx)
	if _follow_to(slot, delta):
		velocity = Vector2.ZERO
	var blocked := _game and _game.has_method("queue_dissat_blocked") and bool(_game.queue_dissat_blocked())
	if not is_thief and not blocked:
		dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + Tuning.DISSAT_QUEUE_PER_SEC * td)
	mood = "排隊中"


func _resolve_queue_idx(reg: Node) -> int:
	## Prefer cached slot; re-find only when the queue mutated ahead of us.
	var q: Array = reg.queue
	if _queue_idx >= 0 and _queue_idx < q.size() and q[_queue_idx] == self:
		return _queue_idx
	var idx := int(reg.call("queue_index_of", self)) if reg.has_method("queue_index_of") else int(q.find(self))
	if idx < 0:
		return int(q.size())
	return idx


func _queue_index_guess() -> int:
	var reg := _reg()
	if reg == null:
		return 0
	return _resolve_queue_idx(reg)


func _follow_to(pos: Vector2, delta: float) -> bool:
	var arrive_sq := Tuning.CUSTOMER_ARRIVE_DIST * Tuning.CUSTOMER_ARRIVE_DIST
	if global_position.distance_squared_to(pos) <= arrive_sq:
		velocity = Vector2.ZERO
		return true
	if _path.is_empty() or pos.distance_squared_to(_goal) > 324.0:
		var pts: PackedVector2Array = _game.call("find_path", global_position, pos)
		if pts.is_empty() and not _path.is_empty():
			## Path budget exhausted — keep walking prior path.
			pass
		else:
			_goal = pos
			_path = pts if not pts.is_empty() else PackedVector2Array([pos])
			_path_i = 0
	var step_sq := 256.0
	while _path_i < _path.size() and global_position.distance_squared_to(_path[_path_i]) <= step_sq:
		_path_i += 1
	var next := pos
	if _path_i < _path.size():
		next = _path[_path_i]
	var to := next - global_position
	if to.length_squared() < 1.0:
		velocity = Vector2.ZERO
		return global_position.distance_squared_to(pos) <= arrive_sq
	var spd := Tuning.WALK_SPEED * Tuning.agi_mult(Tuning.CUSTOMER_AGI) * _pace_speed
	spd *= float(_game.customer_move_mult()) if _game.has_method("customer_move_mult") else float(_game.call("customer_move_mult"))
	if on_dirt() and state != State.LEAVE and not is_thief:
		spd *= Tuning.DIRT_MULT
	if spd <= 0.01:
		velocity = Vector2.ZERO
		return false
	spd = maxf(Tuning.SPEED_FLOOR, spd)
	velocity = to.normalized() * spd
	move_and_slide()
	if get_real_velocity().length_squared() < 144.0:
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
	_queue_idx = -1
	_notify_unoccupy()
	state = State.LEAVE
	_leave_elapsed = 0.0
	if is_thief:
		## Stay targetable, but ghost walls — door solids otherwise wedge bodies
		## in the gap and leave paths never reach exit_pos.
		if mood != "得手離開":
			mood = "離開"
		collision_layer = Tuning.LAYER_CUSTOMERS
		collision_mask = 0
		z_index = 0
		modulate.a = 1.0
	else:
		mood = "生氣離開" if angry else "離開"
		collision_layer = 0
		collision_mask = 0
		z_index = -1
		modulate.a = 0.75
	_clear_route()
	if angry and _game:
		_game.angry_left += 1
		SfxBus.play("sfx_guest_angry_leave")


func _tick_leave(delta: float, td: float) -> void:
	_leave_elapsed += td
	var exit_p: Vector2 = _game.call("exit_pos")
	if _follow_to(exit_p, delta) or _leave_near_exit(exit_p) or _leave_elapsed >= LEAVE_TIMEOUT_SEC:
		if is_thief:
			_finish_thief_exit()
		queue_free()


func _leave_near_exit(exit_p: Vector2) -> bool:
	## Door threshold counts as left — avoids hanging just inside the frame.
	if not _game.has_method("door_pos"):
		return false
	var door_p: Vector2 = _game.call("door_pos")
	if global_position.distance_to(door_p) <= Tuning.CUSTOMER_ARRIVE_DIST:
		## Only once they've crossed to / past the door line (north of shop).
		return global_position.y <= door_p.y + 8.0
	return global_position.distance_to(exit_p) <= Tuning.CUSTOMER_ARRIVE_DIST * 1.25


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
	_bump_list()


## Fight mash win: loot scatters nearby, then thief is KO-flown off-screen.
func ko_scatter_and_flee(dir: Vector2) -> void:
	if state == State.FLEE:
		return
	if _reg():
		_reg().dequeue(self)
	_scatter_cart(Tuning.LOOT_SCATTER_MELEE_MIN, Tuning.LOOT_SCATTER_MELEE_MAX)
	_begin_flee(dir, "被打飛！")


## Directional tossed box hit: Screen KO fly-off; loot drops in place (not scattered).
func ko_box_hit_and_flee(dir: Vector2) -> void:
	if state == State.FLEE:
		return
	if _reg():
		_reg().dequeue(self)
	_drop_cart_inplace()
	_begin_flee(dir, "被貨箱打飛！")


func dash_knock_away(dir: Vector2) -> void:
	if state == State.FLEE:
		return
	if _reg():
		_reg().dequeue(self)
	## Dash: loot scatters farther (≤ 5 身位); not stolen. Catch counted by player.
	_scatter_cart(Tuning.LOOT_SCATTER_DASH_MIN, Tuning.LOOT_SCATTER_DASH_MAX)
	_begin_flee(dir, "被撞飛！")



## Dash into shopping guest: Screen KO fly-up, land in place, stun, drop cart, re-shop.
## Shopping list stays the same; already-taken items are put back so they buy again.
func dash_knock_guest(add_dissat: float) -> void:
	if is_thief or state == State.FLEE or state == State.FIGHT:
		return
	if _reg():
		_reg().dequeue(self)
	if _game and _game.has_method("release_player_checkout"):
		_game.call("release_player_checkout")
	## Rebuild wanted list = taken (cart) + still needed (shopping), then drop cart.
	var rebuy: Array[String] = []
	for s in cart:
		rebuy.append(s)
	for s in shopping:
		rebuy.append(s)
	_drop_cart_inplace()
	dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + maxf(0.0, add_dissat))
	shopping = rebuy
	cart.clear()
	raided = false
	_target_shelf = null
	_bump_list()
	_clear_route()
	state = State.SEEK
	mood = "唔！"
	_play_dash_ko_hop()
	_dash_stun_left = Tuning.DASH_GUEST_STUN_SEC
	mood = "暈眩…"
	_sync_labels()


func _play_dash_ko_hop() -> void:
	var base := global_position
	if _dash_ko_tween != null:
		_dash_ko_tween.kill()
	_dash_ko_tween = create_tween()
	_dash_ko_tween.tween_property(self, "global_position", base + Vector2(0, -56), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_ko_tween.tween_property(self, "global_position", base, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_dash_ko_tween.tween_callback(func() -> void: SfxBus.play("sfx_guest_dash_land"))


## Tossed box hits this guest. Returns items taken into cart from the box.
func accept_toss_box(sku: String, n: int) -> int:
	if is_thief or n <= 0 or sku == "":
		return 0
	var want := 0
	for s in shopping:
		if s == sku:
			want += 1
	if want <= 0:
		return 0
	var take := mini(n, want)
	for _i in take:
		cart.append(sku)
		var idx := shopping.find(sku)
		if idx >= 0:
			shopping.remove_at(idx)
	_bump_list()
	dissatisfaction = 0.0
	_target_shelf = null
	if shopping.is_empty():
		## List completed by toss — go pay; do not linger in THINK「找不到」.
		_begin_checkout("謝謝！去付款")
	else:
		mood = "謝謝！"
		if state == State.THINK or state == State.LINGER:
			state = State.SEEK
			_timer = 0.0
			_clear_route()
	_sync_labels()
	return take


func apply_toss_reject() -> void:
	if is_thief:
		return
	dissatisfaction = minf(Tuning.DISSAT_MAX, dissatisfaction + Tuning.TOSS_GUEST_WRONG_DISSAT)
	mood = "不想要這貨品！"
	_sync_labels()


func _scatter_cart(min_r: float, max_r: float) -> void:
	if cart.is_empty() or _game == null:
		if not cart.is_empty():
			cart.clear()
			_bump_list()
		return
	var piles: Array[Dictionary] = Tuning.loot_piles_from_cart(cart)
	cart.clear()
	_bump_list()
	if piles.is_empty():
		return
	if _game.has_method("spawn_loot_scatter"):
		_game.call("spawn_loot_scatter", global_position, piles, min_r, max_r)
	elif _game.has_method("spawn_dropped_box"):
		for pile in piles:
			_game.call("spawn_dropped_box", global_position, String(pile["sku"]), int(pile["n"]))


## Drop every cart pile at the thief's feet (no flight scatter).
func _drop_cart_inplace() -> void:
	if cart.is_empty() or _game == null:
		if not cart.is_empty():
			cart.clear()
			_bump_list()
		return
	var piles: Array[Dictionary] = Tuning.loot_piles_from_cart(cart)
	cart.clear()
	_bump_list()
	if piles.is_empty():
		return
	if _game.has_method("spawn_loot_inplace"):
		_game.call("spawn_loot_inplace", global_position, piles)
	elif _game.has_method("spawn_dropped_box"):
		for pile in piles:
			_game.call("spawn_dropped_box", global_position, String(pile["sku"]), int(pile["n"]))


func _begin_flee(dir: Vector2, flee_mood: String) -> void:
	_notify_unoccupy()
	state = State.FLEE
	## Recount after state flip so is_active_thief() is false.
	if is_thief and _game and _game.has_method("note_thief_active_changed"):
		_game.call("note_thief_active_changed")
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
	_body = Vox.animated(_model_id)
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


func _bump_list() -> void:
	_list_rev += 1


func _list_label_text() -> String:
	if _list_rev == _list_rev_drawn:
		return _list_cache
	var bits: PackedStringArray = []
	for sku in shopping:
		bits.append(Tuning.sku_name(sku))
	var line := ""
	if is_thief:
		var loot: PackedStringArray = []
		for sku in cart:
			loot.append(Tuning.sku_name(sku))
		line = "小偷  " + ("、".join(bits) if bits.size() else "得手 " + ("、".join(loot) if loot.size() else "空手"))
	else:
		line = "、".join(bits) if bits.size() else "（清單完成）"
		if raided:
			line += "　已取%d" % cart.size()
	_list_cache = line
	_list_rev_drawn = _list_rev
	return line


func _notify_unoccupy() -> void:
	if is_thief:
		return
	if not _occupy_counted or _game == null:
		return
	_occupy_counted = false
	if _game.has_method("note_customer_occupy_changed"):
		_game.call("note_customer_occupy_changed", self, false)


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
				Vox.play_anim(_body as AnimatedSprite2D, _model_id, anim, face_v)
		elif _body is Sprite2D and facing != _shown_facing:
			_shown_facing = facing
			Vox.apply(_body as Sprite2D, _model_id, facing)
