extends RefCounted
## Multiple Shadow Clone: spawn count, facing-relative cells, occupancy.

const StateScript = preload("res://scripts/game_state.gd")

const DURATION := 30.0
const ALPHA := 0.65
const PERSON_RADIUS := 28.0


static func clone_count(level: int) -> int:
	return clampi(level, 1, 3)


## Snap analog/diagonal facing to one shop cardinal.
static func cardinal_facing(facing: Vector2) -> Vector2:
	if facing.length_squared() < 0.0001:
		return Vector2.RIGHT
	if absf(facing.x) >= absf(facing.y):
		return Vector2.RIGHT if facing.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if facing.y >= 0.0 else Vector2.UP


## 左、右、再前 relative to cardinal facing.
static func spawn_offsets(facing: Vector2) -> Array[Vector2]:
	var front := cardinal_facing(facing)
	var left := Vector2(-front.y, front.x)
	var right := Vector2(front.y, -front.x)
	return [left, right, front]


static func spawn_positions(
	origin: Vector2,
	facing: Vector2,
	count: int,
	obstacles: Array,
	people: Array,
) -> Array[Vector2]:
	var n := clone_count(count)
	var out: Array[Vector2] = []
	var taken: Array[Vector2] = []
	for off in spawn_offsets(facing):
		if out.size() >= n:
			break
		var at: Vector2 = origin + off * StateScript.CELL
		if _cell_blocked(at, obstacles, people, taken):
			continue
		out.append(at)
		taken.append(at)
	while out.size() < n:
		out.append(origin)
	return out


static func _cell_blocked(
	at: Vector2,
	obstacles: Array,
	people: Array,
	taken: Array,
) -> bool:
	for r in obstacles:
		if r is Rect2 and (r as Rect2).has_point(at):
			return true
	var r2 := PERSON_RADIUS * PERSON_RADIUS
	for p in people:
		if p is Vector2 and at.distance_squared_to(p) <= r2:
			return true
		elif p is Node2D and is_instance_valid(p) and at.distance_squared_to((p as Node2D).global_position) <= r2:
			return true
	for t in taken:
		if at.distance_squared_to(t) <= r2:
			return true
	return false
