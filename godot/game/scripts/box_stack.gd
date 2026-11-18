extends Node2D

const Tuning = preload("res://scripts/tuning.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const BoxFaceplate = preload("res://scripts/box_faceplate.gd")

## Focused carton / faceplate scale vs other held layers (1.14 × 1.10).
const FOCUS_SCALE := 1.25
## Focus hop: abs(sin) so it reads as a bounce, not a float.
const FOCUS_BOUNCE_PX := 3.2
const FOCUS_BOUNCE_HZ := 2.4

var inventory
var _drawn_rev: int = -1


func setup(inv) -> void:
	if inventory != null and inventory.has_signal("changed") and inventory.changed.is_connected(_on_inv_changed):
		inventory.changed.disconnect(_on_inv_changed)
	inventory = inv
	_drawn_rev = -1
	if inventory != null and inventory.has_signal("changed"):
		inventory.changed.connect(_on_inv_changed)
	set_process(inventory != null)
	queue_redraw()


func _on_inv_changed() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	## Keep redrawing while carrying so the focus hop animates.
	if inventory == null:
		return
	if inventory.has_method("is_empty") and bool(inventory.call("is_empty")):
		return
	queue_redraw()


## Layout bottom→top: focus layers first (near body), then the rest.
## Caller paints non-focus first and focus last so focus stays on top.
func _layout_boxes() -> Dictionary:
	var raw: Array = inventory.boxes() if inventory != null else []
	var focus_sku := ""
	if inventory != null and inventory.has_method("focused_sku"):
		focus_sku = String(inventory.call("focused_sku"))
	var focus_layers: Array = []
	var other: Array = []
	if focus_sku == "":
		return {"focus_sku": "", "focus": [], "other": raw, "ordered": raw}
	for box in raw:
		if String(box.get("id", "")) == focus_sku:
			focus_layers.append(box)
		else:
			other.append(box)
	var ordered: Array = []
	ordered.append_array(focus_layers)
	ordered.append_array(other)
	return {
		"focus_sku": focus_sku,
		"focus": focus_layers,
		"other": other,
		"ordered": ordered,
	}


func _focus_bounce_y() -> float:
	## Hop upward from the grounded shelf line (negative Y).
	var t := float(Time.get_ticks_msec()) * 0.001
	return -absf(sin(t * TAU * FOCUS_BOUNCE_HZ)) * FOCUS_BOUNCE_PX


func _draw_box_at(
	tex: Texture2D,
	box: Dictionary,
	stack_i: int,
	dw: float,
	dh: float,
	focus_sku: String,
	bounce_y: float,
) -> void:
	var sku := String(box["id"])
	var is_focus := focus_sku != "" and sku == focus_sku
	var sc := FOCUS_SCALE if is_focus else 1.0
	var w := dw * sc
	var h := dh * sc
	## Stack step uses base size so focus swell does not shove the whole pile.
	var y := -36.0 - float(stack_i) * (dh * 0.8)
	if is_focus:
		y += bounce_y
	## Grow upward a bit so the larger focus carton stays grounded on the same shelf line.
	var rect := Rect2(Vector2(-w * 0.5, y - (h - dh)), Vector2(w, h))
	draw_texture_rect(tex, rect, false, BoxFaceplate.carton_tint(sku))
	var icon_px := BoxFaceplate.HELD_ICON_PX * sc
	BoxFaceplate.draw_carton_face(self, sku, rect, icon_px, is_focus)


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
	var layout: Dictionary = _layout_boxes()
	var focus_sku: String = String(layout["focus_sku"])
	var bounce_y := _focus_bounce_y() if focus_sku != "" else 0.0
	var ordered: Array = layout["ordered"]
	## Index in `ordered` = vertical slot (0 = lowest). Paint others first, focus last.
	var focus_indices: Dictionary = {}
	for i in ordered.size():
		var box: Dictionary = ordered[i]
		if focus_sku != "" and String(box["id"]) == focus_sku:
			focus_indices[i] = box
			continue
		_draw_box_at(tex, box, i, dw, dh, focus_sku, bounce_y)
	for i in focus_indices.keys():
		_draw_box_at(tex, focus_indices[i], int(i), dw, dh, focus_sku, bounce_y)
