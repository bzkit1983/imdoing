extends Control

signal changed

const SIZE := Vector2(640, 240)
const ORIGIN := Vector2(52, 193)
const FLOOR := 220.0
const GRAVITY := 320.0
const COLORS := [Color("e99a56"), Color("74cadf"), Color("f0ca69")]
const LIMITS := [4, 5, 4]
const FINAL_TOWERS := [320.0, 380.0]
const REINFORCED_HITS := 3
const PATROL_SPEED := 58.0
const PATROL_LENGTH := 52.0
const TOWER_HIT_RADIUS := 11.0
const THIEF_HIT_RADIUS := 10.0

var level := 0
var shots := 0
var settled := true
var won := false
var reveals := false
var fake_side := 0
var aim := Vector2(230, -155)
var aiming := false
var preview_sku := 0
var shelves: Array[Dictionary] = []
var people: Array[Dictionary] = []
var boxes: Array[Dictionary] = []
var shot_time := 0.0
var chain := 0
var best := 0
var bursts: Array[Dictionary] = []


func reset_board(index: int, side: int) -> void:
	level = index
	fake_side = side
	shots = LIMITS[level]
	settled = true
	won = false
	reveals = false
	aiming = false
	boxes.clear()
	bursts.clear()
	shelves.clear()
	people.clear()
	match level:
		0:
			_shelf(255, 56, 2)
			_shelf(321, 76, 1)
			_thief(407)
		1:
			_shelf(270, 80, 2)
			_shelf(326, 57, 1)
			_shelf(385, 86, 0, false, true)
			_thief(430)
		2:
			_shelf(FINAL_TOWERS[0], 80, 1 if side == 0 else 0, side == 0, side != 0)
			_shelf(FINAL_TOWERS[1], 86, 1 if side == 1 else 0, side == 1, side != 1)
			_thief(_thief_start())
	queue_redraw()
	changed.emit()


func _shelf(x: float, height: float, ammo: int, fake: bool = false, reinforced: bool = false) -> void:
	shelves.append({"base": Vector2(x, FLOOR), "height": height,
		"fake": fake, "fall": 0.0, "tilting": false,
		"ammo": ammo, "reinforced": reinforced, "armor": REINFORCED_HITS if reinforced else 0})


func _thief_start() -> float:
	return FINAL_TOWERS[fake_side] + 18.0


func _thief(x: float) -> void:
	people.append({"point": Vector2(x, FLOOR - 22), "start": x,
		"patrol_time": 0.0, "done": false, "fall": 0.0})


func launch(velocity: Vector2, sku: int, second: int) -> void:
	if not settled or won or shots <= 0:
		return
	shots -= 1
	settled = false
	chain = 0
	shot_time = 0.0
	_spawn(ORIGIN, velocity, sku, sku != 1)
	if second >= 0:
		_spawn(ORIGIN + Vector2(0, -8), velocity + Vector2(0, -22), second, second != 1)
	changed.emit()


func _spawn(point: Vector2, velocity: Vector2, sku: int, power: bool = false) -> void:
	boxes.append({"point": point, "velocity": velocity, "sku": sku, "alive": true, "blocked": [], "power": power})


func activate_power() -> void:
	if settled:
		return
	for box in boxes.duplicate():
		if not box.alive or not box.power:
			continue
		box.power = false
		var p: Vector2 = box.point
		box.alive = false
		if box.sku == 0:
			bursts.append({"point": p, "left": 0.35})
			for shelf in shelves:
				if shelf.ammo == 0 and _near(shelf.base, _tip(shelf), p, 76):
					if shelf.armor > 0:
						shelf.armor -= 1
					_tip_over(shelf)
			for person in people:
				if person.point.distance_to(p) <= 76.0:
					_stop_thief(person)
		elif box.sku == 2:
			var velocity: Vector2 = box.velocity
			for spread in [-0.35, -0.17, 0.0, 0.17, 0.35]:
				_spawn(p, velocity.rotated(spread) * 1.05, 2)


func _stop_thief(person: Dictionary) -> void:
	if person.done or (level == 2 and not reveals):
		return
	person.done = true
	_count_hit()


func _physics_process(delta: float) -> void:
	for person in people:
		if person.done and person.fall < 1.0:
			person.fall = minf(1.0, person.fall + delta * 4.0)
			queue_redraw()
	for i in range(bursts.size() - 1, -1, -1):
		bursts[i].left -= delta
		if bursts[i].left <= 0.0:
			bursts.remove_at(i)
		queue_redraw()
	if settled:
		return
	shot_time += delta
	for shelf in shelves:
		if shelf.tilting and shelf.fall < 1.0:
			shelf.fall = minf(1.0, shelf.fall + delta * 1.8)
			if not shelf.fake:
				var tip := _tip(shelf)
				for neighbor in shelves:
					if neighbor != shelf and neighbor.ammo == shelf.ammo and not neighbor.fake and not neighbor.tilting and _near(shelf.base, tip, _target(neighbor), 24):
						_tip_over(neighbor)
	for person in people:
		if not person.done and (level < 2 or reveals):
			person.patrol_time += delta
			person.point.x = person.start + pingpong(person.patrol_time * PATROL_SPEED, PATROL_LENGTH)
	for box in boxes:
		if not box.alive:
			continue
		var from: Vector2 = box.point
		box.velocity.y += GRAVITY * delta
		box.point += box.velocity * delta
		_contact(box, from)
		var point: Vector2 = box.point
		if point.x > SIZE.x + 16 or point.x < -16 or point.y >= FLOOR:
			box.alive = false
	if shot_time >= 9.0 or (not boxes.any(func(box: Dictionary): return box.alive)
			and not shelves.any(func(shelf: Dictionary): return shelf.tilting and shelf.fall < 1.0)):
		boxes.clear()
		settled = true
		won = _complete()
		changed.emit()
	queue_redraw()


func _near(from: Vector2, to: Vector2, center: Vector2, radius: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(center, from, to).distance_squared_to(center) <= radius * radius


func _tip(shelf: Dictionary) -> Vector2:
	return shelf.base + Vector2.UP.rotated(float(shelf.fall) * PI * 0.48) * float(shelf.height)


func _target(shelf: Dictionary) -> Vector2:
	return shelf.base.lerp(_tip(shelf), 0.72)


func _tip_over(shelf: Dictionary) -> void:
	if shelf.tilting or shelf.armor > 0:
		return
	shelf.tilting = true
	if shelf.fake:
		reveals = true
	else:
		_count_hit()


func _count_hit() -> void:
	chain += 1
	best = maxi(chain, best)


func _contact(box: Dictionary, from: Vector2) -> void:
	for shelf in shelves:
		if shelf in box.blocked:
			continue
		if shelf.fake and shelf.tilting:
			continue
		if not shelf.tilting and (_near(from, box.point, _target(shelf), TOWER_HIT_RADIUS) or _near(from, box.point, shelf.base.lerp(_tip(shelf), 0.35), TOWER_HIT_RADIUS)):
			if shelf.ammo == box.sku:
				_tip_over(shelf)
			box.blocked.append(shelf)
			if box.sku != 1:
				box.velocity *= 0.60
	for person in people:
		if person.done or (level == 2 and not reveals):
			continue
		if _near(from, box.point, person.point, THIEF_HIT_RADIUS):
			_stop_thief(person)
			if box.sku != 1:
				box.alive = false
				return


func _complete() -> bool:
	for shelf in shelves:
		if not shelf.tilting or shelf.fall < 1.0:
			return false
	for person in people:
		if not person.done:
			return false
	return true


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / SIZE)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("3d615f"))
	for i in 16:
		draw_rect(Rect2(i * 40, 19, 36, 32), Color("5f8280"))
		draw_rect(Rect2(i * 40 + 4, 39, 26, 3), Color("c6a17a"))
	draw_rect(Rect2(0, FLOOR, SIZE.x, 20), Color("c89667"))
	draw_rect(Rect2(33, 186, 5, 34), Color("f0c785"))
	draw_rect(Rect2(60, 186, 5, 34), Color("f0c785"))
	draw_line(Vector2(35, 190), ORIGIN, Color("804858"), 3)
	draw_line(ORIGIN, Vector2(63, 190), Color("804858"), 3)
	if settled and not won and shots > 0:
		_box(ORIGIN, preview_sku, true)
	for shelf in shelves:
		var shade := Color("809eae") if shelf.reinforced else Color("cfad82") if shelf.fake else Color("a77d63")
		draw_line(shelf.base, _tip(shelf), shade, 14)
		var p := _target(shelf)
		var ammo_color: Color = COLORS[shelf.ammo]
		draw_rect(Rect2(p - Vector2(19, 4), Vector2(38, 8)), ammo_color)
		if shelf.reinforced and not shelf.tilting:
			for hit in REINFORCED_HITS:
				var pip := p + Vector2(-14 + hit * 10, -17)
				draw_rect(Rect2(pip, Vector2(8, 5)), Color("ffd43b") if hit < shelf.armor else Color("455967"))
		if shelf.fake and not shelf.tilting:
			draw_colored_polygon(PackedVector2Array([p+Vector2(7,-4), p+Vector2(15,-4),p+Vector2(15,4)]), Color("f7dbc2"))
	for person in people:
		if level == 2 and not reveals:
			continue
		var p: Vector2 = person.point
		var shirt := Color("af7792")
		if person.done:
			var fall: float = person.fall
			var pivot := p + Vector2(0, 17)
			var swing := Vector2.UP.rotated(PI * 0.48 * fall)
			draw_line(pivot, pivot + swing * 20, shirt, 14)
			draw_circle(pivot + swing * 25, 6, Color("efbc92"))
			draw_line(pivot + swing * 25, pivot + swing * 31, Color("383345"), 3)
			continue
		draw_rect(Rect2(p - Vector2(9, 4), Vector2(18, 22)), shirt)
		draw_rect(Rect2(p - Vector2(6, 13), Vector2(12, 10)), Color("efbc92"))
		draw_rect(Rect2(p - Vector2(6, 10), Vector2(12, 3)), Color("383345"))
		for x in range(int(person.start), int(person.start + PATROL_LENGTH) + 1, 8):
			draw_rect(Rect2(x, FLOOR - 3, 4, 2), Color("ffe2a2"))
		if level == 2:
			draw_rect(Rect2(p + Vector2(8, -15), Vector2(9, 26)), Color("cfad82"))
	for box in boxes:
		if box.alive:
			_box(box.point, box.sku, true)
	for burst in bursts:
		draw_arc(burst.point, lerpf(76.0, 8.0, burst.left / 0.35), 0.0, TAU, 24, Color("ffce78"), 4.0)
	if aiming and settled and not won:
		for i in range(1, 12):
			var t := i * 0.055
			var p := ORIGIN + aim * t + Vector2.DOWN * GRAVITY * t * t * 0.5
			draw_rect(Rect2(p, Vector2(3, 3)), Color("fff0bb"))


func _box(point: Vector2, sku: int, filled: bool) -> void:
	var square := Rect2(point - Vector2(6, 6), Vector2(12, 12))
	draw_rect(square, Color("273944"))
	if filled:
		draw_rect(square.grow(-2), COLORS[sku])
	else:
		draw_rect(square.grow(-2), COLORS[sku], false, 2)
