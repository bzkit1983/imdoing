extends RefCounted
## Interact targeting helpers peeled out of player.gd (facing cone + nearest kind).

const Tuning = preload("res://scripts/tuning.gd")


static func kind_of(node: Object) -> StringName:
	if node == null:
		return &""
	var k = node.get("kind")
	if typeof(k) == TYPE_STRING_NAME:
		return k
	if typeof(k) == TYPE_STRING:
		return StringName(k)
	return &""


## Facing and range test. Returns distance, or -1 when invalid.
static func interact_dist(
	host: Node2D,
	node: Node2D,
	facing: Vector2,
	dirt_areas: Array,
) -> float:
	if host == null or node == null or not is_instance_valid(node):
		return -1.0
	var to_obj: Vector2 = node.global_position - host.global_position
	var dist_sq := to_obj.length_squared()
	if dist_sq > Tuning.INTERACT_RANGE_SQ or dist_sq < 0.000001:
		return -1.0
	var dist := sqrt(dist_sq)
	var kind := kind_of(node)
	var dot := facing.dot(to_obj / dist)
	if kind == &"dirt" and dirt_areas.has(node):
		dot = 1.0
	elif kind == &"thief":
		dot = maxf(dot, 0.85)
	if kind == &"cashier":
		if host.global_position.y < node.global_position.y - 8.0:
			return -1.0
		dot = 1.0
	elif dot < Tuning.FACE_DOT:
		return -1.0
	return dist


static func nearest_kind(
	host: Node2D,
	interactables: Array,
	kind: String,
	facing: Vector2,
	dirt_areas: Array,
) -> Node2D:
	var want := StringName(kind)
	var best: Node2D = null
	var best_d := 1000000.0
	for node in interactables:
		if node == null or not is_instance_valid(node):
			continue
		if kind_of(node) != want:
			continue
		var d := interact_dist(host, node, facing, dirt_areas)
		if d < 0.0 or d >= best_d:
			continue
		best_d = d
		best = node
	return best


static func nearest_active_thief(
	host: Node2D,
	interactables: Array,
	facing: Vector2,
	dirt_areas: Array,
) -> Node2D:
	var best: Node2D = null
	var best_d := 1000000.0
	for node in interactables:
		if node == null or not is_instance_valid(node):
			continue
		if kind_of(node) != &"thief":
			continue
		if not node.has_method("is_active_thief") or not bool(node.call("is_active_thief")):
			continue
		var d := interact_dist(host, node, facing, dirt_areas)
		if d < 0.0 or d >= best_d:
			continue
		best_d = d
		best = node
	return best


static func nearest_stocked_shelf(
	host: Node2D,
	interactables: Array,
	facing: Vector2,
	dirt_areas: Array,
) -> Node2D:
	var best: Node2D = null
	var best_d := 1000000.0
	for node in interactables:
		if node == null or not is_instance_valid(node):
			continue
		if kind_of(node) != &"shelf":
			continue
		if int(node.get("count")) <= 0:
			continue
		var d := interact_dist(host, node, facing, dirt_areas)
		if d < 0.0 or d >= best_d:
			continue
		best_d = d
		best = node
	return best
