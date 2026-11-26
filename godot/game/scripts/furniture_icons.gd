extends RefCounted
## Prep list icons for shop furniture. Prefer art/ui/furniture/<type>.png;
## else downsample world sprites; else a solid category swatch.


const SIZE := 40
const ROW_W := 48
const ROW_H := 72

static var _tex: Dictionary = {}
static var _rows: Dictionary = {}


static func texture(type: String) -> Texture2D:
	type = String(type)
	if type == "":
		return _blank()
	if _tex.has(type):
		return _tex[type] as Texture2D
	var ui_path := "res://art/ui/furniture/%s.png" % type
	if FileAccess.file_exists(ui_path):
		var loaded := Image.new()
		if loaded.load(ui_path) == OK:
			var tex := _fit_square(loaded)
			_tex[type] = tex
			return tex
	var sprite_path := _sprite_path(type)
	if sprite_path != "" and FileAccess.file_exists(sprite_path):
		var spr := Image.new()
		if spr.load(sprite_path) == OK:
			var tex2 := _fit_square(spr)
			_tex[type] = tex2
			return tex2
	var drawn := _procedural(type)
	_tex[type] = drawn
	return drawn


static func row_texture(type: String) -> Texture2D:
	type = String(type)
	if type == "":
		return _blank_row()
	if _rows.has(type):
		return _rows[type] as Texture2D
	var src := texture(type).get_image()
	var img := Image.create(ROW_W, ROW_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if src != null:
		var copy := src.duplicate()
		copy.resize(40, 40, Image.INTERPOLATE_NEAREST)
		img.blit_rect(copy, Rect2i(0, 0, 40, 40), Vector2i(4, 16))
	var tex := ImageTexture.create_from_image(img)
	_rows[type] = tex
	return tex


static func _sprite_path(type: String) -> String:
	if type == "cashier":
		return "res://art/sprites/register_0.png"
	if type == "self_cashier":
		return "res://art/sprites/self_cashier_0.png"
	if type == "portal":
		return "res://art/sprites/portal_0.png"
	if type.begins_with("restock_"):
		var cat := _category(type)
		return "res://art/sprites/restock_%s_0.png" % cat
	if type.begins_with("shelf_"):
		return "res://art/sprites/shelf_%s_0.png" % _category(type)
	if type == "cooked_stall":
		return "res://art/sprites/cooked_stall_0.png"
	if type == "fish_tank":
		return "res://art/sprites/fish_tank_0.png"
	return ""


static func _category(type: String) -> String:
	if type.contains("frozen"):
		return "frozen"
	if type.contains("ice"):
		return "ice"
	return "dry"


static func _fit_square(src: Image) -> Texture2D:
	var copy: Image = src.duplicate()
	## Keep aspect: letterbox into SIZE×SIZE.
	var tw: int = copy.get_width()
	var th: int = copy.get_height()
	if tw <= 0 or th <= 0:
		return _procedural("")
	var scale := minf(float(SIZE) / float(tw), float(SIZE) / float(th))
	var nw := maxi(1, int(round(float(tw) * scale)))
	var nh := maxi(1, int(round(float(th) * scale)))
	copy.resize(nw, nh, Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var ox := (SIZE - nw) / 2
	var oy := (SIZE - nh) / 2
	canvas.blit_rect(copy, Rect2i(0, 0, nw, nh), Vector2i(ox, oy))
	return ImageTexture.create_from_image(canvas)


static func _procedural(type: String) -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color("5c4033")
	if type == "cashier":
		col = Color("5c4033")
	elif type == "self_cashier":
		col = Color("4a90a4")
	elif type.begins_with("restock"):
		if type.ends_with("frozen"):
			col = Color("148a9e")
		elif type.ends_with("ice"):
			col = Color("dde4f7")
		else:
			col = Color("c45c26")
	elif type.begins_with("shelf"):
		if type.contains("frozen"):
			col = Color("1a7a8c")
		elif type.contains("ice"):
			col = Color("c8d4f0")
		else:
			col = Color("2f5d50")
	elif type == "portal":
		col = Color("4ecdc4")
	elif type == "cooked_stall":
		col = Color("c4783a")
	elif type == "fish_tank":
		col = Color("2a7bb0")
	for y in range(6, SIZE - 6):
		for x in range(6, SIZE - 6):
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _blank() -> Texture2D:
	if _tex.has(""):
		return _tex[""] as Texture2D
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_tex[""] = tex
	return tex


static func _blank_row() -> Texture2D:
	if _rows.has(""):
		return _rows[""] as Texture2D
	var img := Image.create(ROW_W, ROW_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_rows[""] = tex
	return tex
