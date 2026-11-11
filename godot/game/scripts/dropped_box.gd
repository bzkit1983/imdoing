extends Area2D

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

var kind: String = "drop"
var sku: String = ""
var count: int = 0
## M2.3 LAN presentation.
var net_agent_id: int = -1
var net_puppet: bool = false


func is_net_puppet() -> bool:
	return net_puppet


func apply_net_pose(pos: Vector2, _facing: Vector2 = Vector2.ZERO) -> void:
	global_position = pos


func apply_net_count(n: int) -> void:
	count = maxi(0, n)
	if count <= 0:
		queue_free()
	else:
		_refresh_label()


func setup(id: String, n: int) -> void:
	sku = id
	count = n
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	z_index = 2
	var spr := Vox.sprite("box", 0)
	spr.scale = Vector2(0.65, 0.65)
	var tint: Color = Tuning.SKU_COLOR.get(id, Color.WHITE)
	spr.modulate = tint.lerp(Color.WHITE, 0.4)
	add_child(spr)
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
	## Host: tree_exiting → agent_despawn. Client puppet: local clear only.
	queue_free()
	return n


## Partial take for 攝石人 (and similar). Remaining 0 → free.
func take_count(n: int) -> int:
	var take := mini(maxi(n, 0), count)
	if take <= 0:
		return 0
	count -= take
	if count <= 0:
		queue_free()
	else:
		_refresh_label()
		## Host partial take keeps the node — sync remaining count (M2.3).
		if net_agent_id >= 0 and not net_puppet and SessionService.is_networked() and SessionService.is_server():
			SessionService.broadcast_agent_state({"id": net_agent_id, "n": count})
	return take


func _refresh_label() -> void:
	for c in get_children():
		if c is Label:
			c.text = "%s×%d" % [Tuning.sku_name(sku), count]
			return
