extends RefCounted
## World carton + SKU faceplate. Carton stays a light-tinted Vox box; the faceplate
## (cream plate + SkuIcons, never icon-modulated) carries SKU identity.
## Contract: docs/systemdesign/ops-sku-icon-ui.md

const Tuning = preload("res://scripts/tuning.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")

const HELD_ICON_PX := 18.0
const FLOOR_ICON_PX := 16.0
const PLATE_SCALE := 1.18
const PLATE_COLOR := Color(0.96, 0.93, 0.86, 0.94)
const PLATE_EDGE := Color(0.22, 0.2, 0.16, 0.55)
## Carton tint: keep silhouette, push toward white so the faceplate reads.
const CARTON_TINT_LERP := 0.6
const HELD_CARTON_SIZE := Vector2(22, 20)
const HELD_OFFSET := Vector2(12, -30)

static var _plate_tex: Texture2D


static func carton_tint(sku: String) -> Color:
	var col: Color = Tuning.SKU_COLOR.get(String(sku), Color.WHITE)
	return col.lerp(Color.WHITE, CARTON_TINT_LERP)


## Draw faceplate centered on an already-drawn carton rect (CanvasItem._draw).
static func draw_carton_face(ci: CanvasItem, sku: String, carton_rect: Rect2, icon_px: float = HELD_ICON_PX, emphasize: bool = false) -> void:
	sku = String(sku)
	if sku == "" or ci == null:
		return
	var px := icon_px * (1.05 if emphasize else 1.0)
	var plate_s := px * PLATE_SCALE
	var center := carton_rect.get_center() + Vector2(0.0, -1.0)
	var plate := Rect2(center - Vector2(plate_s, plate_s) * 0.5, Vector2(plate_s, plate_s))
	ci.draw_texture_rect(_plate_texture(), plate, false, PLATE_COLOR)
	## Soft edge.
	ci.draw_rect(plate.grow(0.5), PLATE_EDGE, false, 1.0)
	var icon := SkuIcons.texture(sku)
	if icon == null:
		return
	var icon_rect := Rect2(center - Vector2(px, px) * 0.5, Vector2(px, px))
	## White modulate = identity; never recolor SKU art.
	ci.draw_texture_rect(icon, icon_rect, false, Color.WHITE)


## Attach a faceplate node (plate + icon) as child of `parent`. Returns the root.
static func attach_carton_face(parent: Node2D, sku: String, icon_px: float = FLOOR_ICON_PX, local_pos: Vector2 = Vector2.ZERO) -> Node2D:
	sku = String(sku)
	if parent == null or sku == "":
		return null
	var root := Node2D.new()
	root.name = "SkuFaceplate"
	root.position = local_pos
	root.z_index = 2
	parent.add_child(root)
	var plate_px := icon_px * PLATE_SCALE
	var plate := Sprite2D.new()
	plate.name = "Plate"
	plate.texture = _plate_texture()
	plate.centered = true
	plate.modulate = PLATE_COLOR
	var ps := plate_px / 16.0
	plate.scale = Vector2(ps, ps)
	root.add_child(plate)
	var icon := SkuIcons.make_sprite(sku, icon_px)
	icon.name = "Icon"
	icon.z_index = 1
	root.add_child(icon)
	return root


## Held carton for clerks／clones／temp restock: Vox box + faceplate. Call `sync_held_carton`.
static func ensure_held_carton(host: Node2D) -> Node2D:
	if host == null:
		return null
	var existing := host.get_node_or_null("HeldCarton") as Node2D
	if existing != null:
		return existing
	var root := Node2D.new()
	root.name = "HeldCarton"
	root.position = HELD_OFFSET
	root.z_index = 3
	root.visible = false
	host.add_child(root)
	var spr := Vox.sprite("box", 0)
	spr.name = "Carton"
	Vox.fit(spr, HELD_CARTON_SIZE)
	root.add_child(spr)
	return root


## Show／hide／retarget held carton. Empty sku or n<=0 hides.
static func sync_held_carton(host: Node2D, sku: String, n: int) -> void:
	if host == null:
		return
	var root := ensure_held_carton(host)
	if root == null:
		return
	sku = String(sku)
	if n <= 0 or sku == "":
		root.visible = false
		return
	root.visible = true
	var spr := root.get_node_or_null("Carton") as Sprite2D
	if spr != null:
		spr.modulate = carton_tint(sku)
	var face := root.get_node_or_null("SkuFaceplate") as Node2D
	if face != null:
		root.remove_child(face)
		face.free()
	## Center face on the fitted carton.
	attach_carton_face(root, sku, HELD_ICON_PX, Vector2(0.0, -2.0))


static func _plate_texture() -> Texture2D:
	if _plate_tex != null:
		return _plate_tex
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	## Soft rounded square.
	for y in s:
		for x in s:
			var dx := mini(x, s - 1 - x)
			var dy := mini(y, s - 1 - y)
			var corner := 3
			var inside := true
			if dx < corner and dy < corner:
				var cx := float(corner - dx)
				var cy := float(corner - dy)
				inside = cx * cx + cy * cy <= float(corner * corner) + 0.25
			if inside:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	_plate_tex = ImageTexture.create_from_image(img)
	return _plate_tex
