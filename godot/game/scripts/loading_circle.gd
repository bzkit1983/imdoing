extends Node2D

## Hold-to-act ring. Drawn on a viewport-root CanvasLayer so y-sorted world
## sprites (shelves, player) cannot cover it.

const OVERLAY_LAYER := 40

var progress: float = 0.0
var blocked: bool = false

var _layer: CanvasLayer
var _overlay: Node2D


class Overlay extends Node2D:
	var host: Node

	func _process(_delta: float) -> void:
		if host == null or not is_instance_valid(host):
			return
		var show := float(host.get("progress")) > 0.0 or bool(host.get("blocked"))
		visible = show
		if not show:
			return
		position = host.get_global_transform_with_canvas().origin
		queue_redraw()

	func _draw() -> void:
		if host == null or not is_instance_valid(host):
			return
		host.call("_draw_ring", self)


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "LoadingCircleLayer"
	_layer.layer = OVERLAY_LAYER
	# Sibling of the main scene under the viewport — not under World y-sort.
	get_tree().root.add_child(_layer)
	_overlay = Overlay.new()
	_overlay.name = "LoadingCircleOverlay"
	_overlay.host = self
	_layer.add_child(_overlay)


func _exit_tree() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
		_layer = null


func _draw_ring(canvas: CanvasItem) -> void:
	## Sit above the sprite so the hold ring does not cover character anims.
	var c := Vector2(0, -78)
	if blocked:
		canvas.draw_arc(c, 22, 0.0, TAU, 40, Color("c45c26", 0.95), 5.0)
		canvas.draw_line(c + Vector2(-10, -10), c + Vector2(10, 10), Color("f4f1ea"), 3.2)
		canvas.draw_line(c + Vector2(10, -10), c + Vector2(-10, 10), Color("f4f1ea"), 3.2)
		return
	if progress <= 0.0:
		return
	canvas.draw_arc(c, 22, 0.0, TAU, 40, Color(0.05, 0.05, 0.05, 0.45), 5.0)
	canvas.draw_arc(c, 22, -PI / 2.0, -PI / 2.0 + progress * TAU, 40, Color("f4d35e"), 5.0)
