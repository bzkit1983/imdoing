extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const BoxFaceplate = preload("res://scripts/box_faceplate.gd")

var inventory
var _drawn_rev: int = -1


func setup(inv) -> void:
	if inventory != null and inventory.has_signal("changed") and inventory.changed.is_connected(_on_inv_changed):
		inventory.changed.disconnect(_on_inv_changed)
	inventory = inv
	_drawn_rev = -1
	if inventory != null and inventory.has_signal("changed"):
		inventory.changed.connect(_on_inv_changed)
	queue_redraw()


func _on_inv_changed() -> void:
	queue_redraw()


func _draw() -> void:
	if inventory == null:
		return
	_drawn_rev = int(inventory.get("revision"))
	var tex := Vox.texture("box", 0)
	var info := Vox.anchor_info("box", 0)
	## Display size from bake anchors (legacy ~32×28; hi-res display ~ same after scale).
	var bw := maxf(float(info.get("fw", 32.0)), 8.0)
	var bh := maxf(float(info.get("fh", 28.0)), 8.0)
	## Cap held-box on-screen size near legacy footprint.
	var max_w := 32.0
	var max_h := 28.0
	var s := minf(1.0, minf(max_w / bw, max_h / bh))
	var dw := bw * s
	var dh := bh * s
	var boxes: Array = inventory.boxes()
	var top_i := boxes.size() - 1
	for i in boxes.size():
		var box: Dictionary = boxes[i]
		var sku := String(box["id"])
		var y := -36.0 - float(i) * (dh * 0.8)
		var rect := Rect2(Vector2(-dw * 0.5, y), Vector2(dw, dh))
		draw_texture_rect(tex, rect, false, BoxFaceplate.carton_tint(sku))
		var emphasize := i == top_i
		BoxFaceplate.draw_carton_face(self, sku, rect, BoxFaceplate.HELD_ICON_PX, emphasize)
