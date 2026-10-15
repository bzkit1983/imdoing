extends Node2D

const Tuning = preload("res://scripts/tuning.gd")

var sequence: Array[int] = []
var index: int = 0
var fail_at: int = -1
var active: bool = false


func _process(_delta: float) -> void:
	visible = active and sequence.size() > 0
	queue_redraw()


func _draw() -> void:
	if not active or sequence.is_empty():
		return
	var origin := Vector2(-18.0 * float(sequence.size() - 1), -92)
	for i in sequence.size():
		var p := origin + Vector2(36.0 * float(i), 0)
		var col := Color("8a8a8a")
		if i < index:
			col = Color("2a9d8f")
		elif i == index:
			col = Color("f4d35e")
		if i == fail_at:
			col = Color("c45c26")
		_draw_arrow(p, sequence[i], col)
		if i == fail_at:
			draw_line(p + Vector2(-12, -12), p + Vector2(12, 12), Color("f4f1ea"), 3.75)
			draw_line(p + Vector2(12, -12), p + Vector2(-12, 12), Color("f4f1ea"), 3.75)


func _draw_arrow(p: Vector2, code: int, col: Color) -> void:
	var pts: PackedVector2Array
	match code:
		0:
			pts = PackedVector2Array([p + Vector2(0, -15), p + Vector2(-12, 9), p + Vector2(12, 9)])
		1:
			pts = PackedVector2Array([p + Vector2(0, 15), p + Vector2(-12, -9), p + Vector2(12, -9)])
		2:
			pts = PackedVector2Array([p + Vector2(-15, 0), p + Vector2(9, -12), p + Vector2(9, 12)])
		_:
			pts = PackedVector2Array([p + Vector2(15, 0), p + Vector2(-9, -12), p + Vector2(-9, 12)])
	draw_colored_polygon(pts, col)
