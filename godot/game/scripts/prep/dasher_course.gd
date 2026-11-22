extends Node2D

const Route = preload("res://scripts/prep/dasher_route.gd")
const RUN_SPEED := 120.0
const JUMP_SPEED := 275.0
const GRAVITY := 780.0
const DASH_SPEED := 310.0
const DASH_DURATION := 0.24
const DASH_LIMIT := 10
const LIFE_LIMIT := 3
const START := Vector2(28, 117)

class Trap:
	var rect: Rect2
	var body: StaticBody2D
	var triggered := false
	var countdown := -1.0

class Enemy:
	var body: AnimatableBody2D
	var home: Vector2
	var patrol := false

var lives := LIFE_LIMIT
var elapsed := 0.0
var dashes := DASH_LIMIT
var running := false
var won := false
var checkpoint_index := -1
var life_loss_notice := 0.0
var hit_enemy := false
var player: CharacterBody2D
var seed_value := 0
var sections: Array[Dictionary] = []
var checkpoints: Array[Vector2] = []
var finish: Rect2
var store_offset: Vector2
var course_width := 0
var _random := RandomNumberGenerator.new()
var _camera: Camera2D
var _obstacles: Node2D
var _platforms: Array[Rect2] = []
var _hidden: Array[Trap] = []
var _collapsing: Array[Trap] = []
var _fake: Array[Trap] = []
var _enemies: Array[Enemy] = []
var _shutter: Trap
var _facing := 1.0
var _dash_direction := 1.0
var _dash_left := 0.0
var _vertical_speed := 0.0
var _patrol_time := 0.0


func _ready() -> void:
	_random.randomize()
	player = CharacterBody2D.new()
	player.platform_floor_layers = 0
	player.floor_snap_length = 1.0
	add_child(player)
	_shape(player, Vector2(12, 18))
	_camera = Camera2D.new()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_bottom = 180
	add_child(_camera)
	reset()
	running = false


func reset(chosen_seed: int = -1) -> void:
	if chosen_seed < 0:
		chosen_seed = _random.randi()
		if chosen_seed == seed_value:
			chosen_seed += 1
	seed_value = chosen_seed
	_build_route()
	lives = LIFE_LIMIT
	elapsed = 0.0
	dashes = DASH_LIMIT
	running = true
	won = false
	checkpoint_index = -1
	life_loss_notice = 0.0
	hit_enemy = false
	_patrol_time = 0.0
	_respawn(START)
	_camera.position = Vector2(player.position.x, 90)
	_camera.reset_smoothing()
	queue_redraw()


func _build_route() -> void:
	if _obstacles != null:
		remove_child(_obstacles)
		_obstacles.queue_free()
	_obstacles = Node2D.new()
	add_child(_obstacles)
	_platforms.clear()
	_hidden.clear()
	_collapsing.clear()
	_fake.clear()
	_enemies.clear()
	checkpoints.clear()
	var route := Route.generate(seed_value)
	sections = route["sections"]
	for i in sections.size():
		var section := sections[i]
		var left: int = section["start"]
		var y: int = section["ground"]
		var edge: int = section["edge"]
		var hazard_x: int = section["hazard_x"]
		if i in [2, 4]:
			checkpoints.append(Vector2(left + 25, y - 10))
		match int(section["hazard"]):
			Route.Hazard.COLLAPSE:
				_platform(Rect2(left, y, hazard_x - left, 180 - y))
				_collapsing.append(_trap(Rect2(hazard_x, y, 34, 180 - y)))
				_platform(Rect2(hazard_x + 34, y, edge - hazard_x - 34, 180 - y))
			Route.Hazard.HIDDEN:
				_platform(Rect2(left, y, edge - left, 180 - y))
				_hidden.append(_trap(Rect2(hazard_x, y - 36, 16, 14)))
				_hidden.append(_trap(Rect2(hazard_x + 38, y - 11, 12, 11)))
			Route.Hazard.FAKE:
				_platform(Rect2(left, y, edge - left, 180 - y))
				var step_rect := Rect2(edge + 34, y - 4, 33, 18)
				if section["solid_step"]:
					_platform(step_rect)
				else:
					var fake := Trap.new()
					fake.rect = step_rect
					_fake.append(fake)
		if section["gap_brick"]:
			# A late jump meets the underside or side. An earlier jump clears the top.
			_hidden.append(_trap(Rect2(edge + 13, y - 32, 12, 16)))
		_add_enemy(Vector2(section["enemy_x"], y - 10), section["patrol"])
	var final_x: int = route["finish_start"]
	var final_y: int = route["finish_ground"]
	course_width = final_x + 375
	_platform(Rect2(final_x, final_y, 375, 180 - final_y))
	store_offset = Vector2(final_x - 985, final_y - 107)
	finish = Rect2(Vector2(1251, 73) + store_offset, Vector2(22, 34))
	_shutter = _trap(Rect2(Vector2(1211, 75) + store_offset, Vector2(9, 32)))
	_shutter.body.collision_layer = 0
	_camera.limit_right = course_width


func _platform(rect: Rect2) -> void:
	_platforms.append(rect)
	_solid(rect)


func _trap(rect: Rect2) -> Trap:
	var trap := Trap.new()
	trap.rect = rect
	trap.body = _solid(rect)
	return trap


func _solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	_obstacles.add_child(body)
	body.position = rect.get_center()
	_shape(body, rect.size)
	return body


func _shape(body: PhysicsBody2D, size_px: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size_px
	shape.shape = box
	body.add_child(shape)


func _add_enemy(point: Vector2, patrol: bool) -> void:
	var enemy := Enemy.new()
	enemy.body = AnimatableBody2D.new()
	enemy.body.sync_to_physics = false
	_obstacles.add_child(enemy.body)
	enemy.body.position = point
	enemy.home = point
	enemy.patrol = patrol
	_shape(enemy.body, Vector2(14 if patrol else 18, 20))
	_enemies.append(enemy)


func step(delta: float, direction: float, jump: bool, dash: bool) -> void:
	if not running:
		return
	elapsed += delta
	life_loss_notice = maxf(0, life_loss_notice - delta)
	_patrol_time += delta
	_tick_obstacles(delta)
	if direction != 0.0:
		_facing = signf(direction)
	if jump and player.is_on_floor() and _dash_left <= 0:
		_vertical_speed = -JUMP_SPEED
	if dash and _dash_left <= 0 and dashes > 0:
		dashes -= 1
		_dash_direction = _facing
		_dash_left = DASH_DURATION
	if _dash_left > 0:
		player.velocity = Vector2(DASH_SPEED * _dash_direction, 0)
		_dash_left = maxf(0, _dash_left - delta)
	else:
		_vertical_speed += GRAVITY * delta
		player.velocity = Vector2(RUN_SPEED * direction, _vertical_speed)
	player.move_and_slide()
	var enemy_collision := _handle_contacts()
	if player.is_on_wall() or player.is_on_ceiling():
		_dash_left = 0
	if player.is_on_floor() or player.is_on_ceiling():
		_vertical_speed = 0
	player.position.x = clampf(player.position.x, 6, course_width - 6)
	if player.is_on_floor():
		for i in range(checkpoint_index + 1, checkpoints.size()):
			var point := checkpoints[i]
			if player.position.x >= point.x and player.position.x < point.x + 70 and absf(player.position.y - point.y) <= 2:
				checkpoint_index = i
	if enemy_collision or player.position.y > 205:
		_lose_life(enemy_collision)
	elif player.is_on_floor() and finish.has_point(player.position):
		won = true
		running = false
	_camera.position = Vector2(roundf(player.position.x), 90)
	queue_redraw()


func _tick_obstacles(delta: float) -> void:
	for enemy in _enemies:
		if enemy.patrol:
			enemy.body.position.x = enemy.home.x + pingpong(_patrol_time * 26.0, 24.0) - 12.0
	for trap in _collapsing:
		if trap.countdown < 0 and player.position.x >= trap.rect.position.x - 24 and player.position.x < trap.rect.end.x:
			trap.countdown = 0.16
		if trap.countdown > 0:
			trap.countdown = maxf(0, trap.countdown - delta)
			if trap.countdown == 0:
				trap.body.collision_layer = 0
	for fake in _fake:
		if fake.rect.has_point(player.position + Vector2(0, 8)):
			fake.triggered = true
	if _shutter.countdown < 0 and player.position.x >= _shutter.rect.position.x - 36:
		_shutter.countdown = 0.85
		_shutter.body.collision_layer = 1
	if _shutter.countdown > 0:
		_shutter.countdown = maxf(0, _shutter.countdown - delta)
		if _shutter.countdown == 0:
			_shutter.body.collision_layer = 0


func _handle_contacts() -> bool:
	for i in player.get_slide_collision_count():
		var collider := player.get_slide_collision(i).get_collider()
		for trap in _hidden:
			if collider == trap.body:
				trap.triggered = true
		for enemy in _enemies:
			if collider == enemy.body:
				return true
	return false


func _lose_life(enemy_collision: bool) -> void:
	lives -= 1
	hit_enemy = enemy_collision
	life_loss_notice = 1.25
	_dash_left = 0
	if lives == 0:
		running = false
	else:
		_respawn(checkpoints[checkpoint_index] if checkpoint_index >= 0 else START)


func _respawn(point: Vector2) -> void:
	player.position = point
	player.velocity = Vector2.ZERO
	_facing = 1.0
	_vertical_speed = 0
	_dash_left = 0


func _draw() -> void:
	for band in 8:
		draw_rect(Rect2(0, band * 21, course_width, 21), Color("191f43").lerp(Color("765877"), band / 7.0))
	for x in range(18, course_width, 41):
		draw_rect(Rect2(x, 9 + (x * 7) % 46, 2, 1), Color("cfabc4"))
	for x in range(0, course_width, 34):
		var roof := 49 + (x * 13) % 36
		draw_rect(Rect2(x, roof, 30, 116), Color("40375e"))
		draw_rect(Rect2(x + 4, roof - 4, 15, 4), Color("40375e"))
		for y in range(roof + 8, 120, 14):
			draw_rect(Rect2(x + 5, y, 3, 2), Color("806980"))
	for x in range(6, course_width, 54):
		var roof := 70 + (x * 11) % 27
		draw_rect(Rect2(x, roof, 44, 96), Color("292944"))
		draw_rect(Rect2(x - 2, roof, 47, 3), Color("534665"))
		draw_rect(Rect2(x + 40, roof + 3, 4, 87), Color("38324f"))
		for y in range(roof + 10, 144, 16):
			for column in 3:
				var wx := x + 6 + column * 12
				draw_rect(Rect2(wx, y, 8, 8), Color("1c2340"))
				draw_rect(Rect2(wx + 1, y + 1, 6, 5), Color("b48a82") if (wx + y) % 3 == 0 else Color("525776"))
				draw_rect(Rect2(wx + 3, y + 1, 1, 5), Color("343651"))
	draw_rect(Rect2(0, 166, course_width, 14), Color("14162a"))
	for x in range(4, course_width, 24):
		draw_rect(Rect2(x, 173, 12, 2), Color("615371"))
	for platform in _platforms:
		_draw_platform(platform)
	for trap in _collapsing:
		if trap.countdown != 0:
			_draw_platform(trap.rect)
			if trap.countdown > 0:
				var crack := trap.rect.position + Vector2(9, 0)
				draw_polyline(PackedVector2Array([crack, crack + Vector2(8, 6), crack + Vector2(4, 10), crack + Vector2(15, 18)]), Color("4c283e"), 2)
	for fake in _fake:
		if fake.triggered:
			draw_rect(fake.rect, Color("e1a06a80"), false)
		else:
			_draw_platform(fake.rect)
	for trap in _hidden:
		if trap.triggered:
			draw_rect(trap.rect, Color("563d63"))
			draw_rect(Rect2(trap.rect.position + Vector2(1, 1), Vector2(trap.rect.size.x - 2, 2)), Color("ffca85"))
	for i in checkpoints.size():
		var pole := checkpoints[i] - Vector2(0, 12)
		draw_rect(Rect2(pole, Vector2(2, 22)), Color("f3cd88"))
		draw_rect(Rect2(pole + Vector2(2, 0), Vector2(12, 7)), Color("80dbc0") if i <= checkpoint_index else Color("a480a8"))
	_draw_store()
	if _shutter.countdown > 0:
		draw_rect(_shutter.rect, Color("42556f"))
		for y in range(3, int(_shutter.rect.size.y), 5):
			draw_rect(Rect2(_shutter.rect.position + Vector2(1, y), Vector2(7, 2)), Color("bac5d6"))
	for enemy in _enemies:
		var point := enemy.body.position.round()
		if enemy.patrol:
			_draw_actor(point, Color("765184"), Color("d39a78"), Color("33273d"), 1.0, true)
			draw_rect(Rect2(point - Vector2(3, 7), Vector2(7, 2)), Color("211d35"))
			draw_rect(Rect2(point + Vector2(-9, 2), Vector2(5, 7)), Color("d59b68"))
		else:
			_draw_actor(point, Color("d06b78"), Color("edbd8d"), Color("702e62"), -1.0, false)
			draw_rect(Rect2(point + Vector2(-8, -1), Vector2(3, 7)), Color("b04e6d"))
			draw_rect(Rect2(point - Vector2(0, 22), Vector2(2, 5)), Color("f6b97c"))
			draw_rect(Rect2(point - Vector2(0, 15), Vector2(2, 2)), Color("f6b97c"))
	_draw_actor(player.position, Color("65d2b7"), Color("f5cb9c"), Color("35548a"), _facing, absf(player.velocity.x) > 1)
	var cap := player.position.round() + Vector2(-5, -11)
	draw_rect(Rect2(cap, Vector2(10, 3)), Color("96e6be"))
	draw_rect(Rect2(cap + Vector2(3 * _facing, 2), Vector2(10, 2)), Color("408e8e"))
	if _dash_left > 0:
		var p := player.position.round() - Vector2(_dash_direction * 14, 3)
		draw_rect(Rect2(p, Vector2(9, 2)), Color("d2f6bd"))
		draw_rect(Rect2(p + Vector2(-3 * _dash_direction, 6), Vector2(7, 2)), Color("65d2b7"))
		for spark in 3:
			draw_rect(Rect2(p + Vector2(-_dash_direction * (8 + spark * 5), spark * 3), Vector2(3, 1)), Color("8bc8b1"))


func _draw_platform(platform: Rect2) -> void:
	draw_rect(platform, Color("313143"))
	draw_rect(Rect2(platform.position, Vector2(platform.size.x, 4)), Color("e1a06a"))
	draw_rect(Rect2(platform.position + Vector2(0, 4), Vector2(platform.size.x, 4)), Color("8a5964"))
	for row_y in range(9, int(platform.size.y) - 3, 8):
		for x in range(4 + row_y % 7, int(platform.size.x) - 2, 15):
			var width := minf(11, platform.size.x - x)
			draw_rect(Rect2(platform.position + Vector2(x, row_y), Vector2(width, 2)), Color("57506a"))
	draw_rect(Rect2(platform.position, Vector2(platform.size.x, 1)), Color("ffd599"))


func _draw_actor(center: Vector2, shirt: Color, skin: Color, hair: Color, direction: float, walking: bool) -> void:
	var pos := center.round() - Vector2(6, 10)
	draw_rect(Rect2(pos + Vector2(2, 0), Vector2(8, 7)), skin)
	draw_rect(Rect2(pos + Vector2(2, 0), Vector2(8, 2)), hair)
	draw_rect(Rect2(pos + Vector2(5 + direction * 2, 3), Vector2(2, 2)), Color("201d36"))
	draw_rect(Rect2(pos + Vector2(0, 7), Vector2(12, 8)), shirt)
	draw_rect(Rect2(pos + Vector2(1, 8), Vector2(8, 2)), shirt.lightened(0.3))
	draw_rect(Rect2(pos + Vector2(1, 13), Vector2(10, 2)), shirt.darkened(0.3))
	var stride := 1 if walking and int(elapsed * 12.0) % 2 == 0 else 0
	draw_rect(Rect2(pos + Vector2(1 - stride, 15), Vector2(4, 4)), hair)
	draw_rect(Rect2(pos + Vector2(7 + stride, 15 - stride), Vector2(4, 4)), hair)


func _draw_store() -> void:
	draw_set_transform(store_offset)
	draw_rect(Rect2(1178, 49, 121, 58), Color("bc795e"))
	draw_rect(Rect2(1173, 48, 131, 5), Color("f3cd88"))
	draw_rect(Rect2(1180, 55, 117, 15), Color("23665e"))
	draw_string(ThemeDB.fallback_font, Vector2(1205, 66), Loc.t("prep.dasher.store"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fff1b9"))
	for x in range(1178, 1298, 10):
		draw_rect(Rect2(x, 72, 10, 6), Color("ea8374") if x % 20 == 18 else Color("fff1b9"))
	draw_rect(Rect2(1191, 85, 39, 16), Color("405b74"))
	for x in range(1194, 1228, 8):
		draw_rect(Rect2(x, 94, 5, 4), Color("e9b778"))
	draw_rect(Rect2(1192, 86, 37, 1), Color("85afb2"))
	draw_rect(Rect2(1250, 80, 25, 27), Color("f3cd88"))
	draw_rect(Rect2(1253, 83, 19, 24), Color("27776b"))
	draw_rect(Rect2(1268, 94, 2, 3), Color("fff1b9"))
	draw_set_transform(Vector2.ZERO)

