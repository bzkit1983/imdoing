extends RefCounted
## Programmatic SKU silhouettes (v1). Swap textures later without changing call sites.
## Contract: docs/systemdesign/ops-sku-icon-ui.md

const Tuning = preload("res://scripts/tuning.gd")

const SIZE := 32
const KIND_MISS := "miss"
const KIND_OK := "ok"
const KIND_BAD := "bad"

static var _tex: Dictionary = {}
static var _badge: Dictionary = {}


static func texture(sku: String) -> Texture2D:
	sku = String(sku)
	if _tex.has(sku):
		return _tex[sku]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col: Color = Tuning.SKU_COLOR.get(sku, Color(0.85, 0.85, 0.85))
	_draw_sku(img, sku, col)
	var tex := ImageTexture.create_from_image(img)
	_tex[sku] = tex
	return tex


static func badge_texture(kind: String) -> Texture2D:
	kind = String(kind)
	if _badge.has(kind):
		return _badge[kind]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		KIND_OK:
			_fill_circle(img, 8, 8, 7, Color(0.15, 0.55, 0.35, 0.92))
			_draw_tick(img, Color(0.95, 1.0, 0.95, 1.0))
		KIND_BAD:
			_fill_circle(img, 8, 8, 7, Color(0.65, 0.18, 0.18, 0.92))
			_draw_cross(img, Color(1.0, 0.95, 0.95, 1.0))
		_:
			## Crossed question mark (miss).
			_fill_circle(img, 8, 8, 7, Color(0.2, 0.22, 0.28, 0.92))
			_draw_qmark(img, Color(1.0, 0.92, 0.45, 1.0))
			_draw_cross(img, Color(0.95, 0.35, 0.35, 1.0))
	var tex := ImageTexture.create_from_image(img)
	_badge[kind] = tex
	return tex


static func make_tex_rect(sku: String, px: int = 28) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = texture(sku)
	tr.custom_minimum_size = Vector2(px, px)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func make_sprite(sku: String, px: float = 24.0) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = texture(sku)
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var s := px / float(SIZE)
	spr.scale = Vector2(s, s)
	return spr


static func _draw_sku(img: Image, sku: String, col: Color) -> void:
	var ink := col.darkened(0.15)
	ink.a = 1.0
	var fill := col.lightened(0.12)
	fill.a = 0.95
	match sku:
		"can":
			_fill_ellipse(img, 16, 10, 7, 3, fill)
			_fill_rect(img, 9, 10, 14, 12, fill)
			_fill_ellipse(img, 16, 22, 7, 3, ink)
			_stroke_ellipse(img, 16, 10, 7, 3, ink)
		"snack":
			## Soft wide bag + zigzag crimp (distinct from milk gable).
			_fill_soft_bag(img, fill, ink)
		"cup":
			_fill_trap_cup(img, fill, ink)
		"drink":
			_fill_rect(img, 13, 5, 6, 4, ink)
			_fill_rect(img, 11, 9, 10, 16, fill)
			_stroke_rect(img, 11, 9, 10, 16, ink)
		"milk":
			## Tall rigid carton + sharp gable + spout.
			_fill_milk_carton(img, fill, ink)
		"soda":
			_fill_ellipse(img, 16, 8, 5, 2, ink)
			_fill_rect(img, 11, 8, 10, 14, fill)
			_fill_ellipse(img, 16, 22, 5, 2, ink)
			_fill_rect(img, 14, 5, 4, 2, ink)
		"icecream":
			_fill_circle(img, 13, 11, 4, fill)
			_fill_circle(img, 19, 11, 4, fill)
			_fill_triangle(img, 10, 14, 16, 28, 22, 14, ink)
		"meat":
			_fill_rect(img, 7, 13, 18, 9, fill)
			_stroke_rect(img, 7, 13, 18, 9, ink)
		"rice":
			_fill_rect(img, 7, 10, 18, 14, fill)
			_stroke_rect(img, 7, 10, 18, 14, ink)
			_hline(img, 7, 17, 18, ink)
			_vline(img, 16, 10, 14, ink)
		_:
			_fill_rect(img, 8, 8, 16, 16, fill)
			_stroke_rect(img, 8, 8, 16, 16, ink)


static func _fill_soft_bag(img: Image, fill: Color, ink: Color) -> void:
	## Body under zigzag.
	for y in range(11, 26):
		var t := float(y - 11) / 14.0
		var inset := int(1.5 + absf(t - 0.55) * 2.0)
		_hline(img, 8 + inset, y, 16 - inset * 2, fill)
	## Zigzag crimp top.
	var zs := [8, 11, 10, 13, 12, 15, 14, 17, 16, 19, 18, 21, 20, 23]
	var i := 0
	while i + 1 < zs.size():
		_line(img, zs[i], 8, zs[i + 1], 11, ink)
		_line(img, zs[i], 9, zs[i + 1], 12, fill)
		i += 2
	## Chip oval.
	_fill_ellipse(img, 16, 18, 4, 2, ink.lightened(0.25))
	_stroke_ellipse(img, 16, 18, 4, 2, ink)


static func _fill_milk_carton(img: Image, fill: Color, ink: Color) -> void:
	## Body.
	_fill_rect(img, 10, 12, 12, 14, fill)
	## Gable roof (triangle).
	_fill_triangle(img, 10, 12, 16, 5, 22, 12, fill)
	_line(img, 10, 12, 16, 5, ink)
	_line(img, 16, 5, 22, 12, ink)
	_hline(img, 10, 12, 12, ink)
	_vline(img, 16, 5, 7, ink)
	## Spout on right.
	_fill_rect(img, 22, 14, 3, 4, ink)
	## Face circle.
	_stroke_ellipse(img, 16, 19, 2, 2, ink)


static func _fill_trap_cup(img: Image, fill: Color, ink: Color) -> void:
	for y in range(12, 24):
		var t := float(y - 12) / 12.0
		var w := int(12 - t * 3)
		var x0 := 16 - w / 2
		_hline(img, x0, y, w, fill)
	_hline(img, 9, 12, 14, ink)
	## Steam.
	_line(img, 13, 7, 13, 11, ink)
	_line(img, 17, 6, 17, 11, ink)


static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(img, xx, yy, col)


static func _stroke_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	_hline(img, x, y, w, col)
	_hline(img, x, y + h - 1, w, col)
	_vline(img, x, y, h, col)
	_vline(img, x + w - 1, y, h, col)


static func _fill_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	_fill_ellipse(img, cx, cy, r, r, col)


static func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	var rx2 := float(rx * rx)
	var ry2 := float(ry * ry)
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := float(x - cx)
			var dy := float(y - cy)
			if (dx * dx) / maxf(rx2, 0.001) + (dy * dy) / maxf(ry2, 0.001) <= 1.0:
				_put(img, x, y, col)


static func _stroke_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	var rx2 := float(rx * rx)
	var ry2 := float(ry * ry)
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := float(x - cx)
			var dy := float(y - cy)
			var v := (dx * dx) / maxf(rx2, 0.001) + (dy * dy) / maxf(ry2, 0.001)
			if v <= 1.0 and v >= 0.72:
				_put(img, x, y, col)


static func _fill_triangle(img: Image, x0: int, y0: int, x1: int, y1: int, x2: int, y2: int, col: Color) -> void:
	var min_y := mini(y0, mini(y1, y2))
	var max_y := maxi(y0, maxi(y1, y2))
	for y in range(min_y, max_y + 1):
		var xs: Array[int] = []
		_edge_x(xs, x0, y0, x1, y1, y)
		_edge_x(xs, x1, y1, x2, y2, y)
		_edge_x(xs, x2, y2, x0, y0, y)
		if xs.size() < 2:
			continue
		xs.sort()
		_hline(img, xs[0], y, xs[xs.size() - 1] - xs[0] + 1, col)


static func _edge_x(out: Array[int], x0: int, y0: int, x1: int, y1: int, y: int) -> void:
	if (y < y0 and y < y1) or (y > y0 and y > y1) or y0 == y1:
		return
	var t := float(y - y0) / float(y1 - y0)
	out.append(int(round(float(x0) + t * float(x1 - x0))))


static func _hline(img: Image, x: int, y: int, w: int, col: Color) -> void:
	for i in w:
		_put(img, x + i, y, col)


static func _vline(img: Image, x: int, y: int, h: int, col: Color) -> void:
	for i in h:
		_put(img, x, y + i, col)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		_put(img, x, y, col)
		if x == x1 and y == y1:
			break
		var e2 := err * 2
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


static func _draw_tick(img: Image, col: Color) -> void:
	_line(img, 4, 8, 7, 11, col)
	_line(img, 7, 11, 12, 5, col)
	_line(img, 4, 9, 7, 12, col)
	_line(img, 7, 12, 12, 6, col)


static func _draw_cross(img: Image, col: Color) -> void:
	_line(img, 5, 5, 11, 11, col)
	_line(img, 11, 5, 5, 11, col)


static func _draw_qmark(img: Image, col: Color) -> void:
	_line(img, 6, 5, 10, 5, col)
	_line(img, 10, 5, 10, 8, col)
	_line(img, 10, 8, 8, 9, col)
	_put(img, 8, 11, col)
	_put(img, 8, 12, col)


static func _put(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, col)
