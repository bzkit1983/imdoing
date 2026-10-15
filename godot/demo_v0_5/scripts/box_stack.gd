extends Node2D

const Tuning = preload("res://scripts/tuning.gd")

var inventory


func setup(inv) -> void:
	inventory = inv


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if inventory == null:
		return
	var boxes: Array = inventory.boxes()
	for i in boxes.size():
		var box: Dictionary = boxes[i]
		var col: Color = Tuning.SKU_COLOR.get(String(box["id"]), Color.WHITE)
		var y := -18 - i * 11
		var rect := Rect2(Vector2(-11, y - 8), Vector2(22, 10))
		draw_rect(rect, col)
		draw_rect(rect, Color(0, 0, 0, 0.35), false, 1.2)
