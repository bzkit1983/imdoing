extends Area2D

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")

var kind: String = "drop"
var sku: String = ""
var count: int = 0


func setup(id: String, n: int) -> void:
	sku = id
	count = n
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	z_index = 2
	var poly := Polygon2D.new()
	poly.color = Tuning.SKU_COLOR.get(id, Color("c45c26"))
	poly.polygon = PackedVector2Array([
		Vector2(-16, -12), Vector2(16, -12), Vector2(16, 12), Vector2(-16, 12)
	])
	add_child(poly)
	var lab := Label.new()
	lab.text = "%s×%d" % [Tuning.sku_name(id), n]
	lab.position = Vector2(-28, -28)
	UiFont.apply_label(lab, UiFont.WORLD)
	lab.add_theme_color_override("font_color", Color("fff4c2"))
	lab.add_theme_color_override("font_outline_color", Color("121212"))
	lab.add_theme_constant_override("outline_size", 5)
	add_child(lab)


func take_all() -> int:
	var n := count
	count = 0
	queue_free()
	return n
