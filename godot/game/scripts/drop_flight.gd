extends Node2D
## Flies a box sprite from `from` to `to`, then notifies via `finished`.
## Tech-review J2: instances are pooled (acquire / release) instead of new/free each toss.

const Tuning = preload("res://scripts/tuning.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const BoxFaceplate = preload("res://scripts/box_faceplate.gd")

signal finished

## Identifies in-flight payloads for closeout unsold return (not a floor interactable).
var kind: String = "drop_flight"
var sku: String = ""
var count: int = 0

var _spr: Sprite2D
var _face: Node2D
var _trail: Line2D
var _elapsed: float = 0.0
var _duration: float = Tuning.DROP_FLIGHT_SEC
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _pts := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])

const POOL_CAP := 32
static var _pool: Array = []


static func acquire() -> Node2D:
	while not _pool.is_empty():
		var n = _pool.pop_back()
		if n != null and is_instance_valid(n):
			return n as Node2D
	return (load("res://scripts/drop_flight.gd") as Script).new() as Node2D


func setup(
	id: String,
	from: Vector2,
	to: Vector2,
	duration: float = Tuning.DROP_FLIGHT_SEC,
	n: int = 0,
) -> void:
	sku = id
	count = maxi(0, n)
	_from = from
	_to = to
	_duration = maxf(0.05, duration)
	_elapsed = 0.0
	z_index = 8
	visible = true
	if _trail == null:
		_trail = Line2D.new()
		_trail.width = 3.0
		_trail.z_index = -1
		add_child(_trail)
	_trail.default_color = Tuning.DROP_FLIGHT_TRAIL_COLOR
	_pts[0] = Vector2.ZERO
	_pts[1] = to - from
	_trail.points = _pts
	if _spr == null:
		_spr = Vox.sprite("box", 0)
		_spr.scale = Vector2(0.65, 0.65)
		add_child(_spr)
	_spr.modulate = BoxFaceplate.carton_tint(id)
	if _face != null and is_instance_valid(_face):
		_face.queue_free()
	_face = BoxFaceplate.attach_carton_face(self, id, BoxFaceplate.FLOOR_ICON_PX, Vector2(0.0, -2.0))
	global_position = from
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	## Ease-out along ground + small arc.
	var ease := 1.0 - (1.0 - t) * (1.0 - t)
	var pos := _from.lerp(_to, ease)
	var arc := -42.0 * sin(PI * t)
	global_position = pos + Vector2(0.0, arc)
	_pts[0] = _from - global_position
	_pts[1] = _to - global_position
	_trail.points = _pts
	_trail.default_color.a = 0.55 * (1.0 - t * 0.35)
	if t >= 1.0:
		set_process(false)
		finished.emit()
		_recycle()


func _recycle() -> void:
	visible = false
	_elapsed = 0.0
	for c in finished.get_connections():
		finished.disconnect(c["callable"])
	if get_parent() != null:
		get_parent().remove_child(self)
	if _pool.size() >= POOL_CAP:
		queue_free()
		return
	_pool.append(self)
