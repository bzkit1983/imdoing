extends Control

signal changed

const SIZE := Vector2(640, 240)
const ORIGIN := Vector2(52, 193)
const FLOOR := 220.0
const GRAVITY := 320.0
const COLORS := [Color("e99a56"), Color("74cadf"), Color("f0ca69")]
const LIMITS := [4, 5, 4]

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


func reset_board(index: int, side: int) -> void:
	level = index
	fake_side = side
	shots = LIMITS[level]
	settled = true
	won = false
	reveals = false
	aiming = false
	boxes.clear()
	shelves.clear()
	people.clear()
	match level:
		0:
			_shelf(203, 56, 0)
			_shelf(371, 98, 1)
			_person(520, 2)
		1:
			_shelf(205, 80, -1, false, 0)
			_shelf(295, 57, 0)
			_shelf(375, 86, 1)
			_person(456, 1)
			_person(520, 2)
			_person(588, -1)
		2:
			_shelf(250, 80, -1, side == 0)
			_shelf(407, 86, -1, side == 1)
			_person(545, 1)
			_person(268 if side == 0 else 425, -1)
	queue_redraw()
	changed.emit()


func _shelf(x: float, height: float, sku: int, fake: bool = false, loose: int = -1) -> void:
	shelves.append({"base": Vector2(x, FLOOR), "height": height, "sku": sku,
		"fake": fake, "loose": loose, "fill": false, "fall": 0.0, "tilting": false})


func _person(x: float, sku: int) -> void:
	people.append({"point": Vector2(x, FLOOR - 22), "sku": sku, "done": false})


func launch(velocity: Vector2, sku: int, second: int) -> void:
	if not settled or won or shots <= 0:
		return
	shots -= 1
	settled = false
	chain = 0
	shot_time = 0.0
	_spawn(ORIGIN, velocity, sku)
	if second >= 0:
		_spawn(ORIGIN + Vector2(0, -8), velocity + Vector2(0, -22), second)
	changed.emit()


func _spawn(point: Vector2, velocity: Vector2, sku: int) -> void:
	boxes.append({"point": point, "velocity": velocity, "sku": sku, "alive": true, "blocked": []})


func _physics_process(delta: float) -> void:
	if settled:
		return
	shot_time += delta
	for shelf in shelves:
		if shelf.tilting and shelf.fall < 1.0:
			shelf.fall = minf(1.0, shelf.fall + delta * 1.8)
			if not shelf.fake:
				var tip := _tip(shelf)
				for neighbor in shelves:
					if neighbor != shelf and not neighbor.fake and not neighbor.tilting and _near(shelf.base, tip, _target(neighbor), 24):
						_tip_over(neighbor)
	for person in people:
		if level == 2 and reveals and person.sku < 0 and not person.done and shot_time > 0.65:
			var start := 268.0 if fake_side == 0 else 425.0
			var stop := start + 52.0
			person.point.x += delta * 29.0
			if person.point.x > stop:
				person.point.x = start
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
	if shelf.tilting:
		return
	shelf.tilting = true
	if shelf.fake:
		reveals = true
	else:
		_count_hit()
		if shelf.loose >= 0:
			_spawn(_tip(shelf), Vector2(155, -34), shelf.loose)
			shelf.loose = -1


func _count_hit() -> void:
	chain += 1
	best = maxi(chain, best)


func _contact(box: Dictionary, from: Vector2) -> void:
	for shelf in shelves:
		if shelf in box.blocked:
			continue
		if shelf.fake and shelf.tilting:
			continue
		if shelf.sku == box.sku and not shelf.fill and _near(from, box.point, _target(shelf), 16):
			shelf.fill = true
			box.alive = false
			_count_hit()
			return
		if not shelf.tilting and _near(from, box.point, shelf.base.lerp(_tip(shelf), 0.42), 22):
			_tip_over(shelf)
			box.blocked.append(shelf)
			if shelf.fake:
				box.alive = false
				return
			box.velocity *= 0.7
	for person in people:
		if person.done or person in box.blocked or (level == 2 and person.sku < 0 and not reveals):
			continue
		if _near(from, box.point, person.point, 19):
			if person.sku == box.sku or (person.sku < 0 and box.sku == 0):
				person.done = true
				box.alive = false
				_count_hit()
				return
			box.blocked.append(person)
			box.velocity = Vector2(-absf(box.velocity.x) * 0.35, -65)


func _complete() -> bool:
	for shelf in shelves:
		if shelf.sku >= 0 and not shelf.fill:
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
		var shade := Color("cfad82") if shelf.fake else Color("a77d63")
		draw_line(shelf.base, _tip(shelf), shade, 14)
		var p := _target(shelf)
		draw_rect(Rect2(p - Vector2(19, 4), Vector2(38, 8)), Color("e1b18a"))
		if shelf.fake and not shelf.tilting:
			draw_colored_polygon(PackedVector2Array([p+Vector2(7,-4), p+Vector2(15,-4),p+Vector2(15,4)]), Color("f7dbc2"))
		if shelf.sku >= 0:
			_box(p, shelf.sku, shelf.fill)
		elif shelf.loose >= 0:
			_box(_tip(shelf), shelf.loose, true)
	for person in people:
		if level == 2 and person.sku < 0 and not reveals:
			continue
		var p: Vector2 = person.point
		var shirt := Color("af7792") if person.sku < 0 else Color("88a4c2")
		draw_rect(Rect2(p - Vector2(9, 4), Vector2(18, 22)), shirt)
		draw_rect(Rect2(p - Vector2(6, 13), Vector2(12, 10)), Color("efbc92"))
		if person.sku < 0:
			draw_rect(Rect2(p - Vector2(6, 10), Vector2(12, 3)), Color("383345"))
			if level == 2 and not person.done:
				var start := 268.0 if fake_side == 0 else 425.0
				for x in range(int(start), int(start) + 53, 8):
					draw_rect(Rect2(x, FLOOR - 3, 4, 2), Color("ffe2a2"))
				draw_rect(Rect2(p + Vector2(8, -15), Vector2(9, 26)), Color("cfad82"))
		_box(p + Vector2(-12, 5), maxi(0, person.sku), person.done)
	for box in boxes:
		if box.alive:
			_box(box.point, box.sku, true)
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
