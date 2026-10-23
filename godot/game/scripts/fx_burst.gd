extends Node2D
## Short Alpha VFX burst (suck / spray / coin / …). Auto-frees when done.

var _frames: Array = []
var _i: int = 0
var _t: float = 0.0
var _fps: float = 12.0
var _spr: Sprite2D


static func spawn(parent: Node, fx_id: String, world_pos: Vector2, fps: float = 12.0) -> void:
	if parent == null:
		return
	var script: Script = load("res://scripts/fx_burst.gd") as Script
	var n: Node2D = script.new() as Node2D
	n.name = "Fx_%s" % fx_id
	n.z_index = 12
	n.global_position = world_pos
	n.set("_fps", fps)
	parent.add_child(n)
	n.call("_load_frames", fx_id)


func _load_frames(fx_id: String) -> void:
	_spr = Sprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.centered = true
	add_child(_spr)
	_frames.clear()
	for i in range(8):
		var path := "res://art/sprites/fx_%s_%d.png" % [fx_id, i]
		if not ResourceLoader.exists(path):
			break
		_frames.append(load(path) as Texture2D)
	if _frames.is_empty():
		queue_free()
		return
	_spr.texture = _frames[0]


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_t += delta
	var step := 1.0 / maxf(_fps, 1.0)
	while _t >= step:
		_t -= step
		_i += 1
		if _i >= _frames.size():
			queue_free()
			return
		_spr.texture = _frames[_i]
	if _i == _frames.size() - 1:
		_spr.modulate.a = clampf(1.0 - _t * _fps, 0.0, 1.0)
