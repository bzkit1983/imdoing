extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

var inventory


func setup(inv) -> void:
	inventory = inv


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if inventory == null:
		return
	var tex := Vox.texture("box", 0)
	var boxes: Array = inventory.boxes()
	for i in boxes.size():
		var box: Dictionary = boxes[i]
		var col: Color = Tuning.SKU_COLOR.get(String(box["id"]), Color.WHITE)
		var y := -36 - i * 22
		draw_texture_rect(tex, Rect2(Vector2(-16, y), Vector2(32, 28)), false, col.lerp(Color.WHITE, 0.35))
