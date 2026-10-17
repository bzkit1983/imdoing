extends RefCounted
## Gameplay sprites baked from art/src. 16 voxels = one 64 px tile.
## Facing index: 0 south, 1 east, 2 north, 3 west.

const _DIR := "res://art/sprites/"

static var _anchors: Dictionary = {}


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


static func fit(spr: Sprite2D, target: Vector2) -> void:
	var fw := maxf(float(spr.get_meta("fw", 64.0)), 1.0)
	var fh := maxf(float(spr.get_meta("fh", 64.0)), 1.0)
	var s := minf(target.x / fw, target.y / fh)
	spr.scale = Vector2(s, s)


static func texture(id: String, k: int = 0) -> Texture2D:
	return load(_DIR + _key(id, k) + ".png")


static func _key(id: String, k: int) -> String:
	var four := "%s_%d" % [id, k]
	if _meta().has(four):
		return four
	return "%s_0" % id


static func _meta() -> Dictionary:
	if _anchors.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(_DIR + "anchors.json"))
		_anchors = parsed if parsed is Dictionary else {}
	return _anchors
