extends Node2D

var progress: float = 0.0
var blocked: bool = false


func _process(_delta: float) -> void:
	visible = progress > 0.0 or blocked
	queue_redraw()


func _draw() -> void:
	var c := Vector2(0, -40)
	if blocked:
		draw_arc(c, 24, 0.0, TAU, 40, Color("c45c26", 0.95), 5.5)
		draw_line(c + Vector2(-11, -11), c + Vector2(11, 11), Color("f4f1ea"), 3.5)
		draw_line(c + Vector2(11, -11), c + Vector2(-11, 11), Color("f4f1ea"), 3.5)
		return
	if progress <= 0.0:
		return
	draw_arc(c, 24, 0.0, TAU, 40, Color(0.05, 0.05, 0.05, 0.5), 5.5)
	draw_arc(c, 24, -PI / 2.0, -PI / 2.0 + progress * TAU, 40, Color("f4d35e"), 5.5)
