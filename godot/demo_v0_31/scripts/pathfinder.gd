extends RefCounted
## Grid A* over the shop floor so guests walk aisles instead of through shelves.

const CELL := 20.0
const PAD := 10.0

var grid := AStarGrid2D.new()
var origin := Vector2.ZERO


func setup(floor_origin: Vector2, floor_size: Vector2, obstacles: Array[Rect2]) -> void:
	origin = floor_origin + Vector2(0, -80)
	var size := floor_size + Vector2(0, 80)
	var cols := int(ceil(size.x / CELL))
	var rows := int(ceil(size.y / CELL))
	grid = AStarGrid2D.new()
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = origin
	grid.region = Rect2i(0, 0, cols, rows)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	for r in obstacles:
		_mark_rect(r.grow(PAD))


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _open_cell(from)
	var b := _open_cell(to)
	if a == Vector2i(-999, -999) or b == Vector2i(-999, -999):
		return PackedVector2Array([to])
	var pts := grid.get_point_path(a, b)
	if pts.is_empty():
		return PackedVector2Array([to])
	return pts


func _mark_rect(r: Rect2) -> void:
	var x0 := int(floor((r.position.x - origin.x) / CELL))
	var y0 := int(floor((r.position.y - origin.y) / CELL))
	var x1 := int(floor((r.end.x - origin.x) / CELL))
	var y1 := int(floor((r.end.y - origin.y) / CELL))
	var region := grid.region
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			if x < region.position.x or y < region.position.y:
				continue
			if x >= region.end.x or y >= region.end.y:
				continue
			grid.set_point_solid(Vector2i(x, y), true)


func _world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(
		int(floor((p.x - origin.x) / CELL)),
		int(floor((p.y - origin.y) / CELL))
	)


func _open_cell(p: Vector2) -> Vector2i:
	var id := _world_to_cell(p)
	if _is_open(id):
		return id
	var region := grid.region
	for rad in range(1, 14):
		for dx in range(-rad, rad + 1):
			for dy in range(-rad, rad + 1):
				if maxi(absi(dx), absi(dy)) != rad:
					continue
				var n := id + Vector2i(dx, dy)
				if n.x < region.position.x or n.y < region.position.y:
					continue
				if n.x >= region.end.x or n.y >= region.end.y:
					continue
				if _is_open(n):
					return n
	return Vector2i(-999, -999)


func _is_open(id: Vector2i) -> bool:
	var region := grid.region
	if id.x < region.position.x or id.y < region.position.y:
		return false
	if id.x >= region.end.x or id.y >= region.end.y:
		return false
	return not grid.is_point_solid(id)
