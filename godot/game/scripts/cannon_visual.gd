extends Node2D
## Code-native low-poly turret art; decorative only, with no collision.
## Loaded ammo shows as a carton faceplate on the turret crown (炮頂).
const BoxFaceplate = preload("res://scripts/box_faceplate.gd")

const TOP_FACE_POS := Vector2(0.0, -46.0)
const TOP_ICON_PX := 22.0

var barrel: Node2D
var _gun: Node2D
var _flash: Polygon2D
var _lamp: Polygon2D
var _top_face: Node2D
var _recoil: Tween
var green_theme := false
var purple_theme := false


func _tone(default_color: String, green_color: String, purple_color: String) -> String:
	if purple_theme:
		return purple_color
	return green_color if green_theme else default_color

func _poly(parent: Node, points: Array, color: String) -> Polygon2D:
	var part := Polygon2D.new()
	part.polygon = PackedVector2Array(points)
	part.color = Color(color)
	parent.add_child(part)
	return part

func _ready() -> void:
	# Contact shadow, feet and three shaded faces of the plinth.
	_poly(self, [Vector2(-30,-1), Vector2(-18,-12), Vector2(19,-12), Vector2(31,0), Vector2(18,10), Vector2(-17,10)], "172a2960")
	for x in [-22, 15]:
		_poly(self, [Vector2(x,-5), Vector2(x+8,-5), Vector2(x+8,5), Vector2(x,5)], _tone("233b3c", "173b20", "35204b"))
	_poly(self, [Vector2(-25,-12), Vector2(0,-25), Vector2(25,-12), Vector2(0,1)], _tone("668c89", "397d3b", "8958b8"))
	_poly(self, [Vector2(-25,-12), Vector2(0,1), Vector2(0,8), Vector2(-25,-5)], _tone("304f52", "23572c", "59347d"))
	_poly(self, [Vector2(0,1), Vector2(25,-12), Vector2(25,-5), Vector2(0,8)], _tone("223c42", "174326", "40265e"))
	# Copper corner guards and a recessed loader on the front face.
	_poly(self, [Vector2(-22,-11), Vector2(-16,-8), Vector2(-16,-1), Vector2(-22,-4)], "e8ac50")
	_poly(self, [Vector2(16,-8), Vector2(22,-11), Vector2(22,-4), Vector2(16,-1)], "b77a37")
	_poly(self, [Vector2(-8,-6), Vector2(0,-2), Vector2(8,-6), Vector2(8,0), Vector2(0,4), Vector2(-8,0)], _tone("152c31", "102d18", "241534"))
	# Turntable is visibly raised above the fixed base.
	_poly(self, [Vector2(-17,-18), Vector2(-8,-27), Vector2(10,-27), Vector2(18,-18), Vector2(10,-8), Vector2(-8,-8)], _tone("253f45", "1c4825", "482b66"))
	_poly(self, [Vector2(-17,-21), Vector2(-8,-30), Vector2(10,-30), Vector2(18,-21), Vector2(10,-12), Vector2(-8,-12)], _tone("83aaa0", "4a9145", "a36bd0"))
	barrel = Node2D.new()
	barrel.position = Vector2(0,-21)
	add_child(barrel)
	_gun = Node2D.new()
	barrel.add_child(_gun)
	# Squared twin-tone barrel, reinforcing band, bright top edge and dark bore.
	_poly(_gun, [Vector2(-9,-3), Vector2(-9,-32), Vector2(8,-36), Vector2(10,-5), Vector2(0,2)], _tone("304e55", "1e542b", "4e2e70"))
	_poly(_gun, [Vector2(-7,-5), Vector2(-7,-31), Vector2(1,-34), Vector2(1,-2)], _tone("e3ad55", "78b64a", "c28bf0"))
	_poly(_gun, [Vector2(1,-34), Vector2(7,-32), Vector2(7,-5), Vector2(1,-2)], _tone("b77b36", "34743a", "7645a8"))
	_poly(_gun, [Vector2(-10,-24), Vector2(9,-25), Vector2(9,-20), Vector2(-10,-19)], _tone("8eaca5", "8dbd64", "d0a6ed"))
	_poly(_gun, [Vector2(-10,-34), Vector2(-1,-39), Vector2(10,-34), Vector2(10,-28), Vector2(-10,-28)], _tone("253b44", "173d22", "38214f"))
	_poly(_gun, [Vector2(-6,-33), Vector2(0,-36), Vector2(6,-33), Vector2(6,-30), Vector2(-6,-30)], "0e222b")
	_poly(_gun, [Vector2(-6,-33), Vector2(0,-36), Vector2(6,-33), Vector2(3,-32), Vector2(0,-33), Vector2(-3,-31)], _tone("6b9690", "4d8e46", "b279df"))
	_flash = _poly(_gun, [Vector2(-5,-39), Vector2(-9,-48), Vector2(-3,-46), Vector2(0,-56), Vector2(4,-46), Vector2(10,-49), Vector2(6,-39)], _tone("fff0a4", "fff0a4", "f1ddff"))
	_flash.visible = false
	# Fixed cap and status lamp; next-SKU faceplate sits on the crown.
	_poly(self, [Vector2(-8,-25), Vector2(0,-29), Vector2(8,-25), Vector2(8,-18), Vector2(0,-14), Vector2(-8,-18)], _tone("476b70", "285a30", "68418d"))
	_poly(self, [Vector2(-6,-26), Vector2(0,-29), Vector2(6,-26), Vector2(0,-23)], _tone("a1c6b6", "9bcf6b", "dcc1f2"))
	_lamp = _poly(self, [Vector2(12,-22), Vector2(16,-24), Vector2(19,-22), Vector2(16,-20)], _tone("5c6f6b", "47624a", "4a3062"))
	set_ammo("")

func set_ammo(sku: String) -> void:
	sku = str(sku)
	if _lamp == null:
		return
	_lamp.color = Color(_tone("71f0b3", "9de45e", "dc9aff")) if sku != "" else Color(_tone("5c6f6b", "47624a", "4a3062"))
	if _top_face != null and is_instance_valid(_top_face):
		_top_face.queue_free()
		_top_face = null
	if sku == "":
		return
	_top_face = BoxFaceplate.attach_carton_face(self, sku, TOP_ICON_PX, TOP_FACE_POS)
	if _top_face != null:
		_top_face.z_index = 8
		_top_face.name = "AmmoTopFace"

func fire() -> void:
	if _recoil != null:
		_recoil.kill()
	_gun.position = Vector2(0,4)
	_flash.visible = true
	_recoil = create_tween()
	_recoil.tween_interval(0.08)
	_recoil.tween_callback(func(): _flash.visible = false)
	_recoil.tween_property(_gun, "position", Vector2.ZERO, 0.16)
