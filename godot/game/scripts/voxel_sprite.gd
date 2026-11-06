extends RefCounted
## Gameplay sprites baked from art/src (+ character anims from tools/voxel_character_anims.py).
## Character facing (8-way): 0 S, 1 SE, 2 E, 3 NE, 4 N, 5 NW, 6 W, 7 SW.
## Furniture / static 4-way still uses 0 S, 1 E, 2 N, 3 W via k_from_facing(..., 4).
## Anim frames: {id}_{anim}_{facing}_{frame}.png — see art/sprites/anim_manifest.json.

const _DIR := "res://art/sprites/"
const _MANIFEST := "res://art/sprites/anim_manifest.json"
const FACING_FADE_SEC := 0.09
const TURN_STEP_FADE_SEC := 0.12

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
	var k := k_from_facing(facing)
	var frames: SpriteFrames = spr.sprite_frames
	if frames == null:
		frames = _sprite_frames(id)
		spr.sprite_frames = frames
	var key := "%s_%d" % [anim, k]
	if not frames.has_animation(key):
		## Fallback: nearest cardinal if an old 4-way pack is still loaded.
		var k4 := k_from_facing(facing, 4)
		var mapped := k4 * 2 if facing_count() >= 8 else k4
		key = "%s_%d" % [anim, mapped]
	if not frames.has_animation(key):
		key = "idle_%d" % k
	if not frames.has_animation(key):
		key = "idle_0"
	var prev_k := int(spr.get_meta("vox_anim_facing", -1))
	var n_face := facing_count()
	if prev_k >= 0 and prev_k != k and spr.is_playing():
		_kick_facing_fade(spr)
		## Large turns (≥2 octants): flash one mid-facing ghost before the new anim.
		if _facing_delta(prev_k, k, n_face) >= 2:
			var mid := _facing_midpoint(prev_k, k, n_face)
			_kick_facing_ghost(spr, id, anim if frames.has_animation("%s_%d" % [anim, mid]) else "idle", mid)
	var anim_for_anchor := anim if frames.has_animation("%s_%d" % [anim, k]) else "idle"
	if spr.animation != key or not spr.is_playing():
		_apply_anchor(spr, id, anim_for_anchor, k, 0)
		spr.play(key)
	spr.speed_scale = speed_scale
	spr.set_meta("vox_anim_facing", k)
	spr.set_meta("vox_anim_name", anim)


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


static func _facing_delta(a: int, b: int, n: int) -> int:
	var d := absi(a - b) % n
	return mini(d, n - d)


static func _facing_midpoint(from_k: int, to_k: int, n: int) -> int:
	var forward := posmod(to_k - from_k, n)
	var backward := posmod(from_k - to_k, n)
	if forward == 0 and backward == 0:
		return from_k
	if forward <= backward:
		return posmod(from_k + maxi(forward >> 1, 1), n)
	return posmod(from_k - maxi(backward >> 1, 1), n)


static func _kick_facing_fade(spr: AnimatedSprite2D) -> void:
	var tex: Texture2D = null
	var frames: SpriteFrames = spr.sprite_frames
	if frames != null and frames.has_animation(spr.animation):
		var fc := frames.get_frame_count(spr.animation)
		if fc > 0:
			tex = frames.get_frame_texture(spr.animation, clampi(spr.frame, 0, fc - 1))
	if tex == null:
		return
	_spawn_fade_sprite(spr, "vox_fade_spr", "VoxFacingFade", tex, spr.offset, FACING_FADE_SEC)


static func _kick_facing_ghost(spr: AnimatedSprite2D, id: String, anim: String, facing: int) -> void:
	var frames: SpriteFrames = spr.sprite_frames
	if frames == null:
		return
	var key := "%s_%d" % [anim, facing]
	if not frames.has_animation(key):
		key = "idle_%d" % facing
	if not frames.has_animation(key):
		return
	var fc := frames.get_frame_count(key)
	if fc <= 0:
		return
	var tex := frames.get_frame_texture(key, 0)
	if tex == null:
		return
	var info: Dictionary = _meta().get(_anim_tex_key(id, anim, facing, 0), {})
	if info.is_empty():
		info = _meta().get(_key(id, facing), {})
	var off := Vector2(-float(info.get("ax", 0)), -float(info.get("ay", 0)))
	_spawn_fade_sprite(spr, "vox_turn_ghost", "VoxTurnGhost", tex, off, TURN_STEP_FADE_SEC)


static func _spawn_fade_sprite(
	spr: AnimatedSprite2D,
	meta_key: String,
	node_name: String,
	tex: Texture2D,
	offset: Vector2,
	duration: float
) -> void:
	var parent := spr.get_parent()
	if parent == null:
		return
	var fade: Sprite2D = null
	if spr.has_meta(meta_key):
		fade = spr.get_meta(meta_key) as Sprite2D
	if fade == null or not is_instance_valid(fade):
		fade = Sprite2D.new()
		fade.name = node_name
		fade.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fade.centered = false
		parent.add_child(fade)
		spr.set_meta(meta_key, fade)
	fade.z_index = spr.z_index
	fade.position = spr.position
	fade.offset = offset
	fade.scale = spr.scale
	fade.texture = tex
	fade.visible = true
	fade.modulate = Color(1, 1, 1, 1)
	if fade.get_index() > spr.get_index():
		parent.move_child(fade, spr.get_index())
	var tw := spr.create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, duration)
	tw.tween_callback(func() -> void:
		if is_instance_valid(fade):
			fade.visible = false
	)


static func _key(id: String, k: int) -> String:
	var exact := "%s_%d" % [id, k]
	if _meta().has(exact):
		return exact
	## Missing diagonal / 8-way → nearest cardinal file (0,2,4,6 → 0,1,2,3).
	var cardinal := clampi(k >> 1, 0, 3) if facing_count() >= 8 else clampi(k, 0, 3)
	var mapped := "%s_%d" % [id, cardinal]
	if _meta().has(mapped):
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
	## Collect raw textures first, then pack into one atlas (fewer GPU binds).
	var slots: Array = [] ## {anim_name, fps, loop, textures: Array}
	if ch.is_empty():
		for k in range(n_face):
			var anim_name := "idle_%d" % k
			slots.append({
				"anim_name": anim_name,
				"fps": 1.0,
				"loop": true,
				"textures": [texture(id, k)],
			})
	else:
		for anim in ch.keys():
			var spec: Dictionary = ch[anim]
			var n: int = int(spec.get("frames", 1))
			var fps: float = float(spec.get("fps", 8))
			var loop := anim in [
				"walk", "run", "leave", "idle", "clean", "fight", "restock", "dash", "fly",
				"walk_carry", "angry", "checkout", "cast", "deliver", "slip",
			]
			for facing in range(n_face):
				var anim_name := "%s_%d" % [anim, facing]
				var texes: Array = []
				for fi in range(n):
					var path := _DIR + _anim_tex_key(id, anim, facing, fi) + ".png"
					if ResourceLoader.exists(path):
						texes.append(load(path) as Texture2D)
					elif fi == 0:
						texes.append(texture(id, facing))
				slots.append({"anim_name": anim_name, "fps": fps, "loop": loop, "textures": texes})
	var packed: Dictionary = _pack_slot_atlas(slots)
	for slot in slots:
		var anim_name: String = slot["anim_name"]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(slot["fps"]))
		frames.set_animation_loop(anim_name, bool(slot["loop"]))
		var texes: Array = packed.get(anim_name, slot["textures"])
		for tex in texes:
			if tex != null:
				frames.add_frame(anim_name, tex as Texture2D)
	_frames_cache[id] = frames
	return frames


## Pack every frame of a character into one ImageTexture; returns anim_name -> AtlasTexture[].
static func _pack_slot_atlas(slots: Array) -> Dictionary:
	var all_tex: Array = []
	var index_of: Dictionary = {} ## anim_name -> Array[int] into all_tex
	for slot in slots:
		var anim_name: String = slot["anim_name"]
		var idxs: Array = []
		for tex in slot["textures"]:
			idxs.append(all_tex.size())
			all_tex.append(tex)
		index_of[anim_name] = idxs
	if all_tex.is_empty():
		return {}
	var cell_w := 1
	var cell_h := 1
	var images: Array = []
	for tex in all_tex:
		var img: Image = null
		if tex is Texture2D:
			img = (tex as Texture2D).get_image()
		if img == null:
			img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		elif img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		images.append(img)
		cell_w = maxi(cell_w, img.get_width())
		cell_h = maxi(cell_h, img.get_height())
	var cols := int(ceil(sqrt(float(images.size()))))
	cols = maxi(cols, 1)
	var rows := int(ceil(float(images.size()) / float(cols)))
	var atlas_img := Image.create(cols * cell_w, rows * cell_h, false, Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0, 0, 0, 0))
	for i in range(images.size()):
		var img: Image = images[i]
		var cx := i % cols
		var cy := int(i / cols)
		var dx := cx * cell_w + ((cell_w - img.get_width()) >> 1)
		var dy := cy * cell_h + ((cell_h - img.get_height()) >> 1)
		atlas_img.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(dx, dy))
	var atlas_tex := ImageTexture.create_from_image(atlas_img)
	var out: Dictionary = {}
	for anim_name in index_of.keys():
		var atlases: Array = []
		for i in index_of[anim_name]:
			var cx: int = int(i) % cols
			var cy: int = int(int(i) / cols)
			var at := AtlasTexture.new()
			at.atlas = atlas_tex
			at.region = Rect2(cx * cell_w, cy * cell_h, cell_w, cell_h)
			at.filter_clip = true
			atlases.append(at)
		out[anim_name] = atlases
	return out


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
