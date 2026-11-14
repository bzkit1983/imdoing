extends Node2D
## Short Alpha VFX burst (suck / spray / coin / …). Pooled (tech-review J2).

var _frames: Array = []
var _i: int = 0
var _t: float = 0.0
var _fps: float = 12.0
var _spr: Sprite2D
var _fx_id: String = ""

const POOL_CAP := 24
static var _pool: Array = []
## Cache textures per fx_id so reuse does not reload PNGs.
static var _frames_cache: Dictionary = {}


static func spawn(parent: Node, fx_id: String, world_pos: Vector2, fps: float = 12.0) -> void:
	if parent == null:
		return
	var n: Node2D = _acquire()
	n.name = "Fx_%s" % fx_id
	n.z_index = 12
	n.visible = true
	n.set("_fps", fps)
	n.set("_fx_id", fx_id)
	n.set("_i", 0)
	n.set("_t", 0.0)
	parent.add_child(n)
	n.global_position = world_pos
	n.call("_load_frames", fx_id)
	n.set_process(true)


static func _acquire() -> Node2D:
	while not _pool.is_empty():
		var n = _pool.pop_back()
		if n != null and is_instance_valid(n):
			return n as Node2D
	return (load("res://scripts/fx_burst.gd") as Script).new() as Node2D


func _load_frames(fx_id: String) -> void:
	if _spr == null:
		_spr = Sprite2D.new()
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_spr.centered = true
		add_child(_spr)
	_spr.modulate = Color.WHITE
	_fx_id = fx_id
	if _frames_cache.has(fx_id):
		_frames = _frames_cache[fx_id]
	else:
		_frames = []
		for i in range(8):
			var path := "res://art/sprites/fx_%s_%d.png" % [fx_id, i]
			if not ResourceLoader.exists(path):
				break
			_frames.append(load(path) as Texture2D)
		_frames_cache[fx_id] = _frames
	if _frames.is_empty():
		_recycle()
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
			_recycle()
			return
		_spr.texture = _frames[_i]
	if _i == _frames.size() - 1:
		_spr.modulate.a = clampf(1.0 - _t * _fps, 0.0, 1.0)


func _recycle() -> void:
	set_process(false)
	visible = false
	_frames = []
	_i = 0
	_t = 0.0
	if _spr != null:
		_spr.modulate = Color.WHITE
	if get_parent() != null:
		get_parent().remove_child(self)
	if _pool.size() >= POOL_CAP:
		queue_free()
		return
	_pool.append(self)
