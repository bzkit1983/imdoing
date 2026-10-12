extends Node2D

var progress: float = 0.0
var blocked: bool = false


func _process(_delta: float) -> void:
	visible = progress > 0.0 or blocked
	queue_redraw()


func _draw() -> void:
	if blocked:
		draw_arc(Vector2(0, -36), 22, 0.0, TAU, 36, Color("c45c26", 0.9), 5.0)
		draw_line(Vector2(-10, -46), Vector2(10, -26), Color("f4f1ea"), 3.0)
		draw_line(Vector2(10, -46), Vector2(-10, -26), Color("f4f1ea"), 3.0)
		return
	if progress <= 0.0:
		return
	draw_arc(Vector2(0, -36), 22, 0.0, TAU, 36, Color(0.1, 0.1, 0.1, 0.45), 5.0)
	var end := -PI / 2.0 + progress * TAU
	draw_arc(Vector2(0, -36), 22, -PI / 2.0, end, 36, Color("f4d35e"), 5.0)
