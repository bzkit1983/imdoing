extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

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
	for i in boxes.size():
		var box: Dictionary = boxes[i]
		var col: Color = Tuning.SKU_COLOR.get(String(box["id"]), Color.WHITE)
		var y := -36.0 - float(i) * (dh * 0.8)
		draw_texture_rect(tex, Rect2(Vector2(-dw * 0.5, y), Vector2(dw, dh)), false, col.lerp(Color.WHITE, 0.35))
