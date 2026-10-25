extends Node2D
## Short SKU icon + status badge popup (miss / ok / bad). Auto-frees.

const SkuIcons = preload("res://scripts/sku_icons.gd")

const HOLD_SEC := 0.85
const RISE_PX := 18.0


static func play(parent: Node, at: Vector2, sku: String, kind: String) -> void:
	if parent == null or sku == "":
		return
	var n: Node2D = (load("res://scripts/sku_popup.gd") as Script).new() as Node2D
	n.name = "SkuPopup"
	n.z_index = 14
	n.global_position = at
	parent.add_child(n)
	n.call("_boot", sku, kind)


func _boot(sku: String, kind: String) -> void:
	var icon := Sprite2D.new()
	icon.texture = SkuIcons.texture(sku)
	icon.centered = true
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.scale = Vector2(1.25, 1.25)
	add_child(icon)
	var badge := Sprite2D.new()
	badge.texture = SkuIcons.badge_texture(kind)
	badge.centered = true
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.position = Vector2(14, 12)
	badge.scale = Vector2(1.1, 1.1)
	add_child(badge)
	modulate.a = 1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position:y", global_position.y - RISE_PX, HOLD_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, HOLD_SEC * 0.45).set_delay(HOLD_SEC * 0.55)
	tw.chain().tween_callback(queue_free)
