extends Node2D
## Short Alpha VFX burst (suck / spray / coin / …). Auto-frees when done.
## World-space by default; optional facing aims the burst and leaves a short smear trail.

var _frames: Array = []
var _i: int = 0
var _t: float = 0.0
var _fps: float = 12.0
var _spr: Sprite2D
var _facing: Vector2 = Vector2.ZERO
var _trails: Array = [] ## Sprite2D ghosts


static func spawn(
	parent: Node,
	fx_id: String,
	world_pos: Vector2,
	fps: float = 12.0,
	facing: Vector2 = Vector2.ZERO
) -> void:
	if parent == null:
		return
	var script: Script = load("res://scripts/fx_burst.gd") as Script
	var n: Node2D = script.new() as Node2D
	n.name = "Fx_%s" % fx_id
	n.z_index = 12
	n.global_position = world_pos
	n.set("_fps", fps)
	n.set("_facing", facing)
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
	if _facing.length_squared() > 0.0001:
		## Aim burst along facing (Godot +Y down; art faces "up" of sprite = -Y locally).
		_spr.rotation = _facing.angle() + PI * 0.5
	_spawn_trail_ghosts()


func _spawn_trail_ghosts() -> void:
	## Two smear copies behind the main burst when moving-facing is known.
	if _facing.length_squared() < 0.0001 or _frames.is_empty():
		return
	var back := -_facing.normalized()
	for ti in range(2):
		var ghost := Sprite2D.new()
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.centered = true
		ghost.texture = _frames[0]
		ghost.rotation = _spr.rotation
		ghost.modulate = Color(1, 1, 1, 0.45 - float(ti) * 0.18)
		ghost.position = back * float(6 + ti * 5)
		ghost.z_index = -1 - ti
		add_child(ghost)
		_trails.append(ghost)


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
		for ti in range(_trails.size()):
			var ghost: Sprite2D = _trails[ti] as Sprite2D
			if ghost != null and is_instance_valid(ghost):
				var src_i := clampi(_i - 1 - ti, 0, _frames.size() - 1)
				ghost.texture = _frames[src_i]
				ghost.modulate.a = maxf(0.0, (0.4 - float(ti) * 0.15) * (1.0 - float(_i) / float(_frames.size())))
	if _i == _frames.size() - 1:
		_spr.modulate.a = clampf(1.0 - _t * _fps, 0.0, 1.0)
