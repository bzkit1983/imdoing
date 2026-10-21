extends RefCounted
## Gameplay sprites baked from art/src (+ character anims from tools/voxel_character_anims.py).
## Facing index: 0 south, 1 east, 2 north, 3 west.
## Anim frames: {id}_{anim}_{facing}_{frame}.png — see art/sprites/anim_manifest.json.

const _DIR := "res://art/sprites/"
const _MANIFEST := "res://art/sprites/anim_manifest.json"

static var _anchors: Dictionary = {}
static var _manifest: Dictionary = {}
static var _frames_cache: Dictionary = {} ## char_id -> SpriteFrames


static func k_from_rot(rot: int) -> int:
	match posmod(rot, 4):
		1:
			return 1
		2:
			return 0
		3:
			return 3
		_:
			return 2


static func k_from_facing(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return 1 if v.x > 0.0 else 3
	return 0 if v.y > 0.0 else 2


static func sprite(id: String, k: int = 0) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	apply(spr, id, k)
	return spr


## Animated character body. Plays `{anim}_{facing}` from anim_manifest.
static func animated(id: String) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	spr.sprite_frames = _sprite_frames(id)
	spr.animation = "idle_0"
	_apply_anchor(spr, id, "idle", 0, 0)
	spr.play()
	return spr


## Switch action + facing. `anim` e.g. walk / idle / fight. Falls back to idle / static.
static func play_anim(spr: AnimatedSprite2D, id: String, anim: String, facing: Vector2, speed_scale: float = 1.0) -> void:
	if spr == null:
		return
	var k := k_from_facing(facing)
	var frames: SpriteFrames = spr.sprite_frames
	if frames == null:
		frames = _sprite_frames(id)
		spr.sprite_frames = frames
	var key := "%s_%d" % [anim, k]
	if not frames.has_animation(key):
		key = "idle_%d" % k
	if not frames.has_animation(key):
		key = "idle_0"
	if spr.animation != key or not spr.is_playing():
		_apply_anchor(spr, id, anim if frames.has_animation("%s_%d" % [anim, k]) else "idle", k, 0)
		spr.play(key)
	spr.speed_scale = speed_scale


static func apply(spr: Sprite2D, id: String, k: int) -> void:
	if String(spr.get_meta("vox_id", "")) == id and int(spr.get_meta("vox_k", -1)) == k and spr.texture != null:
		return
	var key := _key(id, k)
	var info: Dictionary = _meta().get(key, {})
	spr.texture = load(_DIR + key + ".png")
	spr.offset = Vector2(-float(info.get("ax", 0)), -float(info.get("ay", 0)))
	spr.set_meta("fw", float(info.get("fw", 64)))
	spr.set_meta("fh", float(info.get("fh", 64)))
	spr.set_meta("vox_id", id)
	spr.set_meta("vox_k", k)


static func fit(spr: CanvasItem, target: Vector2) -> void:
	var fw := maxf(float(spr.get_meta("fw", 64.0)), 1.0)
	var fh := maxf(float(spr.get_meta("fh", 64.0)), 1.0)
	var s := minf(target.x / fw, target.y / fh)
	spr.scale = Vector2(s, s)


static func texture(id: String, k: int = 0) -> Texture2D:
	return load(_DIR + _key(id, k) + ".png")


static func has_anim(id: String, anim: String) -> bool:
	var ch: Dictionary = _anim_manifest().get("characters", {}).get(id, {})
	return ch.has(anim)


static func _key(id: String, k: int) -> String:
	var four := "%s_%d" % [id, k]
	if _meta().has(four):
		return four
	return "%s_0" % id


static func _anim_tex_key(id: String, anim: String, facing: int, frame: int) -> String:
	return "%s_%s_%d_%d" % [id, anim, facing, frame]


static func _sprite_frames(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	var frames := SpriteFrames.new()
	# Drop default empty anim if present.
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var ch: Dictionary = _anim_manifest().get("characters", {}).get(id, {})
	if ch.is_empty():
		# Fallback: static four-way as idle.
		for k in range(4):
			var anim_name := "idle_%d" % k
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, 1.0)
			frames.set_animation_loop(anim_name, true)
			var tex: Texture2D = texture(id, k)
			frames.add_frame(anim_name, tex)
		_frames_cache[id] = frames
		return frames
	for anim in ch.keys():
		var spec: Dictionary = ch[anim]
		var n: int = int(spec.get("frames", 1))
		var fps: float = float(spec.get("fps", 8))
		for facing in range(4):
			var anim_name := "%s_%d" % [anim, facing]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, fps)
			frames.set_animation_loop(anim_name, anim in ["walk", "run", "leave", "idle", "clean", "fight", "restock", "dash", "fly"])
			for fi in range(n):
				var path := _DIR + _anim_tex_key(id, anim, facing, fi) + ".png"
				if ResourceLoader.exists(path):
					frames.add_frame(anim_name, load(path) as Texture2D)
				elif fi == 0:
					# Fall back to static facing sprite.
					frames.add_frame(anim_name, texture(id, facing))
	_frames_cache[id] = frames
	return frames


static func _apply_anchor(spr: AnimatedSprite2D, id: String, anim: String, facing: int, frame: int) -> void:
	var key := _anim_tex_key(id, anim, facing, frame)
	var info: Dictionary = _meta().get(key, {})
	if info.is_empty():
		info = _meta().get(_key(id, facing), {})
	spr.offset = Vector2(-float(info.get("ax", 0)), -float(info.get("ay", 0)))
	spr.set_meta("fw", float(info.get("fw", 64)))
	spr.set_meta("fh", float(info.get("fh", 64)))
	spr.set_meta("vox_id", id)


static func _meta() -> Dictionary:
	if _anchors.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(_DIR + "anchors.json"))
		_anchors = parsed if parsed is Dictionary else {}
	return _anchors


static func _anim_manifest() -> Dictionary:
	if _manifest.is_empty():
		if FileAccess.file_exists(_MANIFEST):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(_MANIFEST))
			_manifest = parsed if parsed is Dictionary else {}
		else:
			_manifest = {"characters": {}}
	return _manifest
