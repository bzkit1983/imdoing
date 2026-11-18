extends RefCounted
## Ops-item HUD / floor glyphs. Prefer art/ui/ops_item/<id>.png; else colored fallback.

const OpsItems = preload("res://scripts/ops_items.gd")

const SIZE := 64

static var _cache: Dictionary = {}
static var _glow: Texture2D


static func texture(id: String) -> Texture2D:
	id = String(id)
	if id == "":
		return _blank()
	if _cache.has(id):
		return _cache[id] as Texture2D
	var path := "res://art/ui/ops_item/%s.png" % id
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			var tex := ImageTexture.create_from_image(img)
			_cache[id] = tex
			return tex
	var drawn := _fallback(id)
	_cache[id] = drawn
	return drawn


static func glow_texture() -> Texture2D:
	if _glow != null:
		return _glow
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in SIZE:
		for x in SIZE:
			var dx := float(x - 32)
			var dy := float(y - 32)
			var d := sqrt(dx * dx + dy * dy) / 28.0
			if d < 1.0:
				var a := (1.0 - d) * (1.0 - d) * 0.85
				img.set_pixel(x, y, Color(1.0, 0.95, 0.55, a))
	_glow = ImageTexture.create_from_image(img)
	return _glow


static func _blank() -> Texture2D:
	if _cache.has(""):
		return _cache[""] as Texture2D
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_cache[""] = tex
	return tex


static func _fallback(id: String) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill := Color(0.9, 0.85, 0.4)
	match id:
		OpsItems.COMFORT_BOMB:
			fill = Color(1.0, 0.72, 0.82)
		OpsItems.CLEAN_BOMB:
			fill = Color(0.45, 0.88, 0.95)
		OpsItems.VILLAIN_BOMB:
			fill = Color(0.95, 0.42, 0.38)
	var ink := Color(0.12, 0.1, 0.08)
	for y in SIZE:
		for x in SIZE:
			var dx := x - 32
			var dy := y - 32
			var r2 := dx * dx + dy * dy
			if r2 <= 26 * 26:
				img.set_pixel(x, y, fill if r2 <= 22 * 22 else ink)
			## Fuse nub on top.
			if abs(dx) <= 3 and dy >= -30 and dy <= -18:
				img.set_pixel(x, y, Color(0.95, 0.85, 0.35))
	return ImageTexture.create_from_image(img)
