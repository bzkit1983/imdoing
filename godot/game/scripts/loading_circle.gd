extends Node2D

## Hold-to-act ring. CanvasLayer child (same pattern as restock SKU list) so
## y-sorted shelves cannot cover it. Overlay is a sized Control so the draw
## is not culled. Screen position tracks the clerk via canvas transform.

const OVERLAY_LAYER := 128
const RING_SIZE := Vector2(120, 120)

var progress: float = 0.0
var blocked: bool = false

var _layer: CanvasLayer
var _overlay: Control


class Overlay extends Control:
	var host: Node

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = RING_SIZE
		size = RING_SIZE

	func _process(_delta: float) -> void:
		if host == null or not is_instance_valid(host):
			return
		## Keep a real rect — layout can clear size and cull draws.
		custom_minimum_size = RING_SIZE
		size = RING_SIZE
		var prog = host.get("progress")
		var show: bool = (prog != null and float(prog) > 0.0) or host.get("blocked") == true
		visible = show
		if not show:
			return
		## CanvasLayer without follow_viewport is screen-space; use local position.
		var origin: Vector2 = host.get_global_transform_with_canvas().origin + Vector2(0, -78)
		position = origin - size * 0.5
		queue_redraw()

	func _draw() -> void:
		if host == null or not is_instance_valid(host):
			return
		host.call("_draw_ring", self, size * 0.5)


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "LoadingCircleLayer"
	_layer.layer = OVERLAY_LAYER
	## Child of the clerk (not viewport root) — matches working restock list overlays.
	add_child(_layer)
	_overlay = Overlay.new()
	_overlay.name = "LoadingCircleOverlay"
	_overlay.host = self
	_overlay.visible = false
	_layer.add_child(_overlay)


func _draw_ring(canvas: CanvasItem, c: Vector2) -> void:
	## Sit above the sprite so the hold ring does not cover character anims.
	if blocked:
		canvas.draw_arc(c, 22, 0.0, TAU, 40, Color("c45c26", 0.95), 5.0)
		canvas.draw_line(c + Vector2(-10, -10), c + Vector2(10, 10), Color("f4f1ea"), 3.2)
		canvas.draw_line(c + Vector2(10, -10), c + Vector2(-10, 10), Color("f4f1ea"), 3.2)
		return
	if progress <= 0.0:
		return
	canvas.draw_arc(c, 22, 0.0, TAU, 40, Color(0.05, 0.05, 0.05, 0.45), 5.0)
	canvas.draw_arc(c, 22, -PI / 2.0, -PI / 2.0 + progress * TAU, 40, Color("f4d35e"), 5.0)
