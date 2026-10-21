extends Node2D
## Flies a box sprite from `from` to `to`, then notifies via `finished`.

const Tuning = preload("res://scripts/tuning.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

signal finished

var _spr: Sprite2D
var _trail: Line2D
var _elapsed: float = 0.0
var _duration: float = Tuning.DROP_FLIGHT_SEC
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO


func setup(sku: String, from: Vector2, to: Vector2, duration: float = Tuning.DROP_FLIGHT_SEC) -> void:
	_from = from
	_to = to
	_duration = maxf(0.05, duration)
	z_index = 8
	_trail = Line2D.new()
	_trail.width = 3.0
	_trail.default_color = Color(1.0, 0.92, 0.45, 0.55)
	_trail.z_index = -1
	_trail.points = PackedVector2Array([Vector2.ZERO, to - from])
	add_child(_trail)
	_spr = Vox.sprite("box", 0)
	_spr.scale = Vector2(0.65, 0.65)
	var tint: Color = Tuning.SKU_COLOR.get(sku, Color.WHITE)
	_spr.modulate = tint.lerp(Color.WHITE, 0.35)
	add_child(_spr)
	global_position = from


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	## Ease-out along ground + small arc.
	var ease := 1.0 - (1.0 - t) * (1.0 - t)
	var pos := _from.lerp(_to, ease)
	var arc := -42.0 * sin(PI * t)
	global_position = pos + Vector2(0.0, arc)
	_trail.points = PackedVector2Array([_from - global_position, _to - global_position])
	_trail.default_color.a = 0.55 * (1.0 - t * 0.35)
	if t >= 1.0:
		finished.emit()
		queue_free()
