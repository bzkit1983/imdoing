extends RefCounted
## Gameplay sprites baked from art/src (+ character anims from tools/voxel_character_anims.py).
## Character facing (8-way): 0 S, 1 SE, 2 E, 3 NE, 4 N, 5 NW, 6 W, 7 SW.
## Furniture / static 4-way still uses 0 S, 1 E, 2 N, 3 W via k_from_facing(..., 4).
## Anim frames: {id}_{anim}_{facing}_{frame}.png — see art/sprites/anim_manifest.json.

const _DIR := "res://art/sprites/"
const _MANIFEST := "res://art/sprites/anim_manifest.json"
const FACING_FADE_SEC := 0.09
## Stick noise near 8-way sector edges: stay on prev until ~20% into the neighbor.
const FACING_HYSTERESIS := 0.20

static var _anchors: Dictionary = {}
static var _manifest: Dictionary = {}
static var _frames_cache: Dictionary = {} ## char_id -> SpriteFrames


static func facing_count() -> int:
	var n := int(_anim_manifest().get("facings", 0))
	if n >= 4:
		return n
	var names: Variant = _anim_manifest().get("facing", [])
	if names is Array and names.size() >= 4:
		return names.size()
	return 8


static func k_from_rot(rot: int) -> int:
	## Furniture placement rot → 4-way sprite index (unchanged).
	match posmod(rot, 4):
		1:
			return 1
		2:
			return 0
		3:
			return 3
		_:
			return 2


static func k_from_facing(v: Vector2, facings: int = -1) -> int:
	var n := facings if facings > 0 else facing_count()
	if n <= 4:
		## Legacy cardinal snap (furniture / 4-way props).
		if absf(v.x) > absf(v.y):
			return 1 if v.x > 0.0 else 3
		return 0 if v.y > 0.0 else 2
	if v.length_squared() < 0.0001:
		return 0
	## 0 = south (+Y). Positive atan2(x,y) sweeps toward east (+X).
	var ang := atan2(v.x, v.y)
	var step := TAU / float(n)
	var k := int(floor((ang + step * 0.5) / step)) % n
	if k < 0:
		k += n
	return k


## 8-way facing with hysteresis so analog edges don't flicker every frame.
static func k_from_facing_stable(v: Vector2, prev: int, facings: int = -1) -> int:
	var n := facings if facings > 0 else facing_count()
	if n <= 4:
		return k_from_facing(v, n)
	if v.length_squared() < 0.0001:
		return prev if prev >= 0 and prev < n else 0
	var raw := k_from_facing(v, n)
	if prev < 0 or prev >= n or raw == prev:
		return raw
	var ang := atan2(v.x, v.y)
	var step := TAU / float(n)
	var prev_center := float(prev) * step
	var delta := ang - prev_center
	while delta > PI:
		delta -= TAU
	while delta < -PI:
		delta += TAU
	## Sector half-width is 0.5*step; require FACING_HYSTERESIS past the boundary.
	if absf(delta) < step * (0.5 + FACING_HYSTERESIS):
		return prev
	return raw


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
	spr.set_meta("vox_anim_facing", 0)
	spr.set_meta("vox_anim_name", "idle")
	spr.play()
	return spr


## Switch action + facing. `anim` e.g. walk / idle / fight. Falls back to idle / static.
static func play_anim(spr: AnimatedSprite2D, id: String, anim: String, facing: Vector2, speed_scale: float = 1.0) -> void:
	if spr == null:
		return
	var prev_k := int(spr.get_meta("vox_anim_facing", -1))
	var prev_anim := String(spr.get_meta("vox_anim_name", ""))
	var k := k_from_facing_stable(facing, prev_k)
	var frames: SpriteFrames = spr.sprite_frames
	if frames == null:
		frames = _sprite_frames(id)
		spr.sprite_frames = frames
	var key := _anim_key_with_frames(frames, anim, k, facing)
	var anim_for_anchor := anim if _has_anim_frames(frames, "%s_%d" % [anim, k]) else "idle"
	if key == String(spr.animation) and spr.is_playing() and prev_k == k and prev_anim == anim:
		spr.speed_scale = speed_scale
		return
	## Facing crossfade disabled: leftover fade sprites from older builds cleared.
	if spr.has_meta("vox_fade_spr") and is_instance_valid(spr.get_meta("vox_fade_spr")):
		var leftover: Sprite2D = spr.get_meta("vox_fade_spr")
		leftover.visible = false
		leftover.modulate.a = 0.0
	if spr.has_meta("vox_fade_tw"):
		var old_tw = spr.get_meta("vox_fade_tw")
		if old_tw is Tween:
			(old_tw as Tween).kill()
		spr.remove_meta("vox_fade_tw")
	if spr.animation != key or not spr.is_playing():
		_apply_anchor(spr, id, anim_for_anchor, k, 0)
		spr.play(key)
	spr.speed_scale = speed_scale
	spr.set_meta("vox_anim_facing", k)
	spr.set_meta("vox_anim_name", anim)


static func _has_anim_frames(frames: SpriteFrames, key: String) -> bool:
	return frames != null and frames.has_animation(key) and frames.get_frame_count(key) > 0


static func _anim_key_with_frames(frames: SpriteFrames, anim: String, k: int, facing: Vector2) -> String:
	var key := "%s_%d" % [anim, k]
	if _has_anim_frames(frames, key):
		return key
	## Fallback: nearest cardinal if an old 4-way pack is still loaded.
	var k4 := k_from_facing(facing, 4)
	var mapped := k4 * 2 if facing_count() >= 8 else k4
	key = "%s_%d" % [anim, mapped]
	if _has_anim_frames(frames, key):
		return key
	key = "idle_%d" % k
	if _has_anim_frames(frames, key):
		return key
	if _has_anim_frames(frames, "idle_0"):
		return "idle_0"
	return key


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


static func _kick_facing_fade(spr: AnimatedSprite2D) -> void:
	var parent := spr.get_parent()
	if parent == null:
		return
	var tex: Texture2D = null
	var frames: SpriteFrames = spr.sprite_frames
	if frames != null and frames.has_animation(spr.animation):
		var fc := frames.get_frame_count(spr.animation)
		if fc > 0:
			tex = frames.get_frame_texture(spr.animation, clampi(spr.frame, 0, fc - 1))
	if tex == null:
		return
	## Kill stacked tweens — rapid facing changes used to leave an opaque ghost
	## or hide the fade mid-blend (blank / wrong-facing flashes).
	if spr.has_meta("vox_fade_tw"):
		var prev_tw = spr.get_meta("vox_fade_tw")
		if prev_tw is Tween:
			(prev_tw as Tween).kill()
		spr.remove_meta("vox_fade_tw")
	var fade: Sprite2D = null
	if spr.has_meta("vox_fade_spr"):
		fade = spr.get_meta("vox_fade_spr") as Sprite2D
	if fade == null or not is_instance_valid(fade):
		fade = Sprite2D.new()
		fade.name = "VoxFacingFade"
		fade.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fade.centered = false
		parent.add_child(fade)
		spr.set_meta("vox_fade_spr", fade)
	fade.z_index = spr.z_index - 1
	fade.position = spr.position
	fade.offset = spr.offset
	fade.scale = spr.scale
	fade.texture = tex
	fade.visible = true
	fade.modulate = Color(1, 1, 1, 0.85)
	## Draw fade under the live sprite for the blend window.
	if fade.get_index() > spr.get_index():
		parent.move_child(fade, spr.get_index())
	var tw := spr.create_tween()
	spr.set_meta("vox_fade_tw", tw)
	tw.tween_property(fade, "modulate:a", 0.0, FACING_FADE_SEC)
	tw.tween_callback(func() -> void:
		if is_instance_valid(fade):
			fade.visible = false
			fade.modulate.a = 0.0
		if is_instance_valid(spr) and spr.has_meta("vox_fade_tw"):
			spr.remove_meta("vox_fade_tw")
	)


static func _key(id: String, k: int) -> String:
	var exact := "%s_%d" % [id, k]
	if _meta().has(exact):
		return exact
	## Furniture / props already pass 4-way k (0..3). Prefer that file before
	## treating k as an 8-way index (k>>1 would map east/west wrongly).
	if k >= 0 and k <= 3:
		var as4 := "%s_%d" % [id, k]
		if _meta().has(as4):
			return as4
		## Texture may exist even if anchors were wiped — keep k so callers
		## still load the correct PNG (offset may be zero until anchors return).
		var tex4 := _DIR + as4 + ".png"
		if ResourceLoader.exists(tex4):
			return as4
	## Missing diagonal / 8-way → nearest cardinal file (0,2,4,6 → 0,1,2,3).
	if facing_count() >= 8:
		var cardinal := clampi(k >> 1, 0, 3)
		var mapped := "%s_%d" % [id, cardinal]
		if _meta().has(mapped):
			return mapped
		var tex_c := _DIR + mapped + ".png"
		if ResourceLoader.exists(tex_c):
			return mapped
	return "%s_0" % id


static func _anim_tex_key(id: String, anim: String, facing: int, frame: int) -> String:
	return "%s_%s_%d_%d" % [id, anim, facing, frame]


static func _sprite_frames(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var n_face := facing_count()
	var ch: Dictionary = _anim_manifest().get("characters", {}).get(id, {})
	if ch.is_empty():
		for k in range(n_face):
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
		for facing in range(n_face):
			var anim_name := "%s_%d" % [anim, facing]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, fps)
			frames.set_animation_loop(
				anim_name,
				anim in [
					"walk", "run", "leave", "idle", "clean", "fight", "restock", "dash", "fly",
					"walk_carry", "angry", "checkout", "cast", "deliver", "slip",
				]
			)
			for fi in range(n):
				var path := _DIR + _anim_tex_key(id, anim, facing, fi) + ".png"
				var tex: Texture2D = null
				## exists() can be true while .ctex is missing (stale .import) —
				## load then returns null and the sprite vanishes for that facing.
				if ResourceLoader.exists(path):
					tex = load(path) as Texture2D
				if tex == null and fi == 0:
					tex = texture(id, facing)
				if tex != null:
					frames.add_frame(anim_name, tex)
				elif fi == 0:
					## Last resort: nearest imported cardinal so the body stays visible.
					tex = texture(id, (facing >> 1) * 2 if facing_count() >= 8 else facing)
					if tex != null:
						frames.add_frame(anim_name, tex)
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
			_manifest = {"characters": {}, "facings": 8}
	return _manifest
