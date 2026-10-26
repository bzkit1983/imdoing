extends RefCounted
## Placeholder prep-hub icons. Prefer art/ui/prep/<id>.png when a designer drops one in.


## Draw canvas size; downscaled for hub buttons so tiles stay compact.
const SIZE := 96
const DISPLAY := 44
static var _cache: Dictionary = {}


static func icon_tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id] as Texture2D
	var path := "res://art/ui/prep/%s.png" % id
	if ResourceLoader.exists(path):
		var loaded: Texture2D = load(path)
		var img := loaded.get_image()
		if img != null and (img.get_width() != DISPLAY or img.get_height() != DISPLAY):
			img.resize(DISPLAY, DISPLAY, Image.INTERPOLATE_LANCZOS)
			var scaled := ImageTexture.create_from_image(img)
			_cache[id] = scaled
			return scaled
		_cache[id] = loaded
		return loaded
	var drawn := _draw(id)
	_cache[id] = drawn
	return drawn


static func _draw(id: String) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.12, 0.10, 1))
	match id:
		"char":
			_disk(img, 48, 28, 14, Color("f4d35e"))
			_body(img, 48, 78, 22, Color("f4f1ea"))
		"goods":
			_box(img, 14, 44, 30, 30, Color("c45c26"))
			_box(img, 50, 30, 30, 44, Color("f4d35e"))
		"shop":
			_tri_roof(img)
			_box(img, 18, 40, 60, 36, Color("3d5a46"))
			_box(img, 40, 50, 16, 26, Color("f4d35e"))
		"staff":
			_disk(img, 34, 30, 12, Color("8ecae6"))
			_body(img, 34, 78, 18, Color("f4f1ea"))
			_box(img, 58, 40, 20, 30, Color("f4d35e"))
		"sys":
			_box(img, 18, 30, 60, 42, Color("5a655e"))
			_ring(img, 48, 50, 12, Color("f4f1ea"))
		"stats":
			_box(img, 22, 22, 16, 52, Color("f4d35e"))
			_box(img, 42, 36, 16, 38, Color("f4f1ea"))
			_box(img, 62, 28, 16, 46, Color("c45c26"))
		"skills":
			_star(img, 48, 48, 28, Color("f4d35e"))
		"look":
			_disk(img, 48, 34, 14, Color("5a655e"))
			_body(img, 48, 82, 20, Color("5a655e"))
		"develop":
			_box(img, 22, 22, 52, 52, Color("24302a"))
			_plus(img, 48, 48, 18, Color("f4d35e"))
		"buy":
			_box(img, 16, 40, 28, 28, Color("c45c26"))
			_box(img, 48, 28, 28, 40, Color("f4d35e"))
		"furn":
			_box(img, 18, 28, 60, 40, Color("3d5a46"))
			_box(img, 28, 40, 16, 20, Color("f4d35e"))
		"expand":
			_box(img, 18, 50, 16, 24, Color("f4f1ea"))
			_box(img, 40, 36, 16, 38, Color("f4f1ea"))
			_box(img, 62, 22, 16, 52, Color("f4d35e"))
		"layout":
			_box(img, 16, 16, 64, 64, Color("24302a"))
			_hline(img, 16, 48, 64, Color("f4d35e"))
			_vline(img, 48, 16, 64, Color("f4d35e"))
		"money":
			_disk(img, 48, 48, 26, Color("f4d35e"))
			_disk(img, 48, 48, 16, Color("1c241f"))
		"sfx":
			_disk(img, 48, 48, 22, Color("24302a"))
			_disk(img, 36, 42, 5, Color("f4f1ea"))
			_disk(img, 60, 42, 5, Color("f4f1ea"))
		"wipe":
			_box(img, 28, 22, 40, 12, Color("c45c26"))
			_box(img, 34, 34, 28, 36, Color("c45c26"))
		_:
			_disk(img, 48, 48, 20, Color("f4d35e"))
	img.resize(DISPLAY, DISPLAY, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	return tex


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	img.set_pixel(x, y, c)


static func _disk(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	var r2 := r * r
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				_px(img, x, y, c)


static func _ring(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	var r2 := r * r
	var inner := (r - 4) * (r - 4)
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var d := (x - cx) * (x - cx) + (y - cy) * (y - cy)
			if d <= r2 and d >= inner:
				_px(img, x, y, c)


static func _box(img: Image, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_px(img, x, y, c)


static func _body(img: Image, cx: int, bottom: int, half_w: int, c: Color) -> void:
	for y in range(bottom - 28, bottom):
		var t := float(y - (bottom - 28)) / 28.0
		var w := int(lerpf(float(half_w), float(half_w + 8), t))
		for x in range(cx - w, cx + w):
			_px(img, x, y, c)


static func _tri_roof(img: Image) -> void:
	for y in range(12, 40):
		var t := float(y - 12) / 28.0
		var half := int(lerpf(2.0, 30.0, t))
		for x in range(48 - half, 48 + half):
			_px(img, x, y, Color("5a7a62"))


static func _plus(img: Image, cx: int, cy: int, arm: int, c: Color) -> void:
	_box(img, cx - 4, cy - arm, 8, arm * 2, c)
	_box(img, cx - arm, cy - 4, arm * 2, 8, c)


static func _hline(img: Image, x0: int, y: int, w: int, c: Color) -> void:
	_box(img, x0, y - 1, w, 3, c)


static func _vline(img: Image, x: int, y0: int, h: int, c: Color) -> void:
	_box(img, x - 1, y0, 3, h, c)


static func _star(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	## Soft diamond + arms — readable at 96px without true polygon fill.
	_disk(img, cx, cy, int(r * 0.45), c)
	_box(img, cx - 4, cy - r, 8, r * 2, c)
	_box(img, cx - r, cy - 4, r * 2, 8, c)
	_box(img, cx - int(r * 0.7), cy - int(r * 0.7), 10, 10, c)
	_box(img, cx + int(r * 0.55), cy - int(r * 0.7), 10, 10, c)
	_box(img, cx - int(r * 0.7), cy + int(r * 0.55), 10, 10, c)
	_box(img, cx + int(r * 0.55), cy + int(r * 0.55), 10, 10, c)
