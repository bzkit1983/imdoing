extends Node2D
## Soft halo parented to the current interact target. Additive, slow pulse.

const TEX_SIZE := 64

static var _tex: Texture2D


static func _texture() -> Texture2D:
	if _tex != null:
		return _tex
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var center := (float(TEX_SIZE) - 1.0) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var d := Vector2(float(x), float(y)).distance_to(Vector2(center, center)) / center
			## Bright ring sits outside the sprite; a softer fill covers the body.
			var ring := clampf(1.0 - absf(d - 0.58) / 0.34, 0.0, 1.0)
			var fill := clampf(1.0 - d, 0.0, 1.0)
			var a := maxf(fill * fill * 0.55, ring * ring)
			img.set_pixel(x, y, Color(1.0, 0.9, 0.45, a))
	_tex = ImageTexture.create_from_image(img)
	return _tex


func _ready() -> void:
	var spr := Sprite2D.new()
	spr.name = "Halo"
	spr.texture = _texture()
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = mat
	add_child(spr)
	z_index = -1


func set_span(span: Vector2) -> void:
	var sx := maxf(span.x, 16.0) / float(TEX_SIZE)
	var sy := maxf(span.y, 16.0) / float(TEX_SIZE)
	scale = Vector2(sx, sy)


func _process(_delta: float) -> void:
	var w := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.05)
	modulate = Color(1, 1, 1, lerpf(0.72, 1.0, w))
