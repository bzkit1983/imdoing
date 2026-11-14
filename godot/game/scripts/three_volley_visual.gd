extends Node2D
## Non-blocking presentation for 三段火槍陣. Host resolves all targets separately.

var net_agent_id: int = -1
var kind: String = "three_volley"
var _floor_size := Vector2.ZERO
var _elapsed: float = 0.0

const LIFETIME := 5.0
const FLASH_DURATION := 0.55
const VOLLEY_TIMES := [0.0, 2.0, 4.0]
const MUSKET_RED := Color(0.58, 0.12, 0.12, 1.0)
const MUSKET_DARK := Color(0.16, 0.12, 0.11, 1.0)
const FLASH := Color(1.0, 0.84, 0.36, 0.9)


func setup(floor_origin: Vector2, floor_size: Vector2) -> void:
	position = floor_origin
	_floor_size = floor_size
	_elapsed = 0.0
	z_index = 5
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _floor_size.x <= 0.0 or _floor_size.y <= 0.0:
		return
	var count := maxi(2, int(floor(_floor_size.x / 64.0)))
	var margin := minf(28.0, _floor_size.x / float(count * 2))
	for rank in 3:
		var row_y := _floor_size.y - 126.0 + float(rank) * 26.0
		var volley_age := _elapsed - float(VOLLEY_TIMES[rank])
		var flash_duration := FLASH_DURATION
		var line_width := 2.6
		var muzzle_radius := 5.5
		if rank == 2:
			flash_duration = 0.8
			line_width = 3.4
			muzzle_radius = 7.0
		var firing := volley_age >= 0.0 and volley_age < flash_duration
		for i in count:
			var x := lerpf(margin, _floor_size.x - margin, float(i) / float(maxi(1, count - 1)))
			_draw_musketeer(Vector2(x, row_y))
			if firing:
				var alpha := 1.0 - volley_age / flash_duration
				var flash_color := FLASH
				flash_color.a = FLASH.a * alpha
				draw_line(
					Vector2(x, row_y - 8.0),
					Vector2(x, 8.0),
					flash_color,
					line_width,
					true,
				)
				draw_circle(Vector2(x, row_y - 8.0), muzzle_radius * alpha, flash_color)


func _draw_musketeer(at: Vector2) -> void:
	draw_circle(at + Vector2(0.0, -11.0), 4.4, MUSKET_DARK)
	draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(-6.0, -13.0),
			at + Vector2(0.0, -19.0),
			at + Vector2(6.0, -13.0),
		]),
		MUSKET_RED,
	)
	draw_rect(Rect2(at + Vector2(-6.5, -7.0), Vector2(13.0, 13.0)), MUSKET_RED)
	draw_line(at + Vector2(-4.0, 6.0), at + Vector2(-5.0, 11.0), MUSKET_DARK, 3.0, true)
	draw_line(at + Vector2(4.0, 6.0), at + Vector2(5.0, 11.0), MUSKET_DARK, 3.0, true)
	draw_line(at + Vector2(0.0, -3.0), at + Vector2(0.0, -29.0), MUSKET_DARK, 2.0, true)
