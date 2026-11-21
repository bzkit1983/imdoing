extends RefCounted
## Temporary skill glyphs for HUD and prep. Prefer art/ui/skill/<id>.png.
## Contract: docs/systemdesign/art-interim-v1.5.md


const SIZE := 64
const ROW_W := 48
const ROW_H := 72

static var _cache: Dictionary = {}
static var _rows: Dictionary = {}
static var _locked_rows: Dictionary = {}


static func texture(id: String) -> Texture2D:
	id = String(id)
	if id == "":
		return _blank()
	if _cache.has(id):
		return _cache[id] as Texture2D
	var path := "res://art/ui/skill/%s.png" % id
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			var tex := ImageTexture.create_from_image(img)
			_cache[id] = tex
			return tex
	var drawn := _fallback(id)
	_cache[id] = drawn
	return drawn


static func row_texture(id: String) -> Texture2D:
	## Icon centered in a list-row slot so ItemList rows stay touch-tall.
	id = String(id)
	if id == "":
		return _blank_row()
	if _rows.has(id):
		return _rows[id] as Texture2D
	var src := texture(id).get_image()
	var img := Image.create(ROW_W, ROW_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if src != null:
		var copy := src.duplicate()
		copy.resize(40, 40, Image.INTERPOLATE_NEAREST)
		img.blit_rect(copy, Rect2i(0, 0, 40, 40), Vector2i(4, 16))
	var tex := ImageTexture.create_from_image(img)
	_rows[id] = tex
	return tex


static func locked_row_texture(id: String) -> Texture2D:
	if id.is_empty():
		return row_texture(id)
	if _locked_rows.has(id):
		return _locked_rows[id] as Texture2D
	var img := row_texture(id).get_image()
	for y in range(16, 56):
		for x in range(4, 44):
			var pixel := img.get_pixel(x, y)
			var shade := 0.12 + pixel.get_luminance() * 0.38
			img.set_pixel(x, y, Color(shade, shade, shade, pixel.a))
	## Contrasting padlock badge, inset from the upper-left edge of the row.
	img.fill_rect(Rect2i(4, 14, 16, 17), Color("171a19"))
	var ink := Color("e0e0e0")
	img.fill_rect(Rect2i(9, 16, 6, 2), ink)
	img.fill_rect(Rect2i(8, 18, 2, 5), ink)
	img.fill_rect(Rect2i(14, 18, 2, 5), ink)
	img.fill_rect(Rect2i(6, 21, 12, 8), ink)
	img.fill_rect(Rect2i(11, 23, 2, 4), Color("171a19"))
	var tex := ImageTexture.create_from_image(img)
	_locked_rows[id] = tex
	return tex


static func _blank() -> Texture2D:
	if _cache.has(""):
		return _cache[""] as Texture2D
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_cache[""] = tex
	return tex


static func _blank_row() -> Texture2D:
	if _rows.has(""):
		return _rows[""] as Texture2D
	var img := Image.create(ROW_W, ROW_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_rows[""] = tex
	return tex


static func _fallback(id: String) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hue := float(absi(id.hash()) % 360) / 360.0
	var fill := Color.from_hsv(hue, 0.45, 0.92)
	var ink := Color("1a1a1a")
	for y in SIZE:
		for x in SIZE:
			var dx := x - 32
			var dy := y - 32
			if dx * dx + dy * dy <= 24 * 24:
				img.set_pixel(x, y, fill)
			if dx * dx + dy * dy <= 26 * 26 and dx * dx + dy * dy >= 20 * 20:
				img.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(img)
