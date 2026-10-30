extends Node2D

## Hold-to-act ring. Drawn on a viewport-root CanvasLayer so y-sorted shelves
## cannot cover it. The overlay is a Control with a real rect: a Node2D that
## only custom-draws is culled on that layer, so the ring never appeared.

const OVERLAY_LAYER := 40

var progress: float = 0.0
var blocked: bool = false

var _layer: CanvasLayer
var _overlay: Control


class Overlay extends Control:
	var host: Node

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(120, 120)

	func _process(_delta: float) -> void:
		if host == null or not is_instance_valid(host):
			return
		var show := float(host.get("progress")) > 0.0 or bool(host.get("blocked"))
		visible = show
		if not show:
			return
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
	_overlay = Overlay.new()
	_overlay.name = "LoadingCircleOverlay"
	_overlay.host = self
	_layer.add_child(_overlay)
	# Root may still be entering the tree when the player is spawned.
	get_tree().root.add_child.call_deferred(_layer)


func _exit_tree() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
		_layer = null


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
