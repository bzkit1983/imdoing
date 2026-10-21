extends Control

var game_hours: float = 6.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.42
	draw_circle(c, r + 4.0, Color("1b2420"))
	draw_arc(c, r, 0.0, TAU, 48, Color("e8c36a"), 3.0)
	for i in 12:
		var a := -PI / 2.0 + float(i) / 12.0 * TAU
		draw_line(c + Vector2.from_angle(a) * (r - 8.0), c + Vector2.from_angle(a) * r, Color("f4f1ea"), 2.0)
	var hour_a := -PI / 2.0 + (game_hours / 12.0) * TAU
	var minute := (game_hours - floorf(game_hours)) * 60.0
	var min_a := -PI / 2.0 + (minute / 60.0) * TAU
	draw_line(c, c + Vector2.from_angle(hour_a) * (r * 0.55), Color("f4f1ea"), 3.5)
	draw_line(c, c + Vector2.from_angle(min_a) * (r * 0.82), Color("e8c36a"), 2.0)
	draw_circle(c, 3.5, Color("c45c26"))
