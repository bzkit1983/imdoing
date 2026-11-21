extends Control
## Dynamic hour／minute hands only — pair with a TextureRect clock face (Canva PNG).

@export var hour_color := Color(0.55, 0.42, 0.22, 1.0)
@export var minute_color := Color(0.78, 0.58, 0.18, 1.0)
@export var hub_color := Color(0.72, 0.45, 0.18, 1.0)

var _game_hours: float = 6.0
var game_hours: float:
	get:
		return _game_hours
	set(value):
		if is_equal_approx(_game_hours, value):
			return
		_game_hours = value
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.42
	if r < 2.0:
		return
	## 12h face: hour hand completes a circle every 12 game hours.
	var hour_a := -PI / 2.0 + (_game_hours / 12.0) * TAU
	var minute := (_game_hours - floorf(_game_hours)) * 60.0
	var min_a := -PI / 2.0 + (minute / 60.0) * TAU
	draw_line(c, c + Vector2.from_angle(hour_a) * (r * 0.52), hour_color, 3.0)
	draw_line(c, c + Vector2.from_angle(min_a) * (r * 0.78), minute_color, 2.0)
	draw_circle(c, 2.5, hub_color)
