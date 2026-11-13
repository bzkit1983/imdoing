extends Node2D
## Fixed-position customer calm field. The Host simulates reductions; clients render it only.

const Skills = preload("res://scripts/skills.gd")

const EFFECT_DURATION := 15.0
const FLAG_DURATION := 5.0

var kind: String = "calm_zone"
var host: Node
var level: int = 3
var owner_seat: int = 0
var visual_only: bool = false
var net_agent_id: int = -1
var elapsed: float = 0.0
var _ring: Line2D
var _flag: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ring = Line2D.new()
	_ring.name = "CalmZoneRing"
	_ring.z_index = -7
	_ring.width = 2.5
	_ring.closed = true
	_ring.antialiased = true
	_ring.default_color = Color(0.26, 0.62, 1.0, 0.72)
	var radius := Skills.calm_zone_radius(level)
	for i in 64:
		var angle := TAU * float(i) / 64.0
		_ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
	add_child(_ring)
	_flag = _make_smile_flag()
	add_child(_flag)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(host):
		queue_free()
		return
	var phase := String(host.get("phase"))
	if phase in ["closed", "prep"]:
		queue_free()
		return
	if host.has_method("asking_early_close") and bool(host.call("asking_early_close")):
		return

	elapsed += delta
	if elapsed >= FLAG_DURATION and is_instance_valid(_flag):
		_flag.queue_free()
		_flag = null
	if elapsed >= EFFECT_DURATION:
		_ring.visible = false
		queue_free()
		return

	if visual_only:
		return
	var world_delta := delta
	if host.has_method("world_delta"):
		world_delta = float(host.call("world_delta", delta))
	if world_delta <= 0.0:
		return

	var customers = host.get("_customers")
	if customers == null or not is_instance_valid(customers):
		return
	var radius_squared := Skills.calm_zone_radius(level) * Skills.calm_zone_radius(level)
	var reduction := Skills.calm_zone_dissat_per_sec(level) * world_delta
	for customer in customers.get_children():
		if customer == null or not is_instance_valid(customer):
			continue
		if not customer.has_method("apply_calm_zone"):
			continue
		if global_position.distance_squared_to(customer.global_position) > radius_squared:
			continue
		customer.call("apply_calm_zone", reduction)


func _make_smile_flag() -> Node2D:
	var marker := Node2D.new()
	marker.name = "HappyFaceFlag"
	marker.z_index = 8
	var base := Polygon2D.new()
	base.color = Color(0.05, 0.12, 0.25, 0.62)
	var base_points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		base_points.append(Vector2(cos(angle) * 10.0, sin(angle) * 4.0))
	base.polygon = base_points
	marker.add_child(base)

	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -46)])
	pole.width = 3.0
	pole.default_color = Color(0.9, 0.96, 1.0)
	pole.antialiased = true
	marker.add_child(pole)

	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([
		Vector2(2, -45), Vector2(31, -42), Vector2(27, -32),
		Vector2(31, -22), Vector2(2, -25),
	])
	flag.color = Color(0.18, 0.48, 0.92, 0.98)
	marker.add_child(flag)

	var face := Polygon2D.new()
	face.color = Color(1.0, 0.9, 0.4)
	var face_points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		face_points.append(Vector2(15.0 + cos(angle) * 7.2, -33.5 + sin(angle) * 7.2))
	face.polygon = face_points
	marker.add_child(face)

	for eye_x in [12.0, 18.0]:
		var eye := Polygon2D.new()
		eye.color = Color(0.08, 0.16, 0.28)
		eye.polygon = PackedVector2Array([
			Vector2(eye_x - 0.9, -36.0), Vector2(eye_x + 0.9, -36.0),
			Vector2(eye_x + 0.9, -33.8), Vector2(eye_x - 0.9, -33.8),
		])
		marker.add_child(eye)

	var smile := Line2D.new()
	smile.points = PackedVector2Array([
		Vector2(10.5, -31.5), Vector2(12.5, -29.3), Vector2(15.0, -28.5),
		Vector2(17.5, -29.3), Vector2(19.5, -31.5),
	])
	smile.width = 1.5
	smile.default_color = Color(0.08, 0.16, 0.28)
	smile.antialiased = true
	marker.add_child(smile)
	return marker
