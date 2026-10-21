extends StaticBody2D
## Floor shelf. Emits stock_sku_changed when occupied SKU identity changes
## (empty↔stocked) so the game host can keep an O(1) SKU→shelf index.

const Tuning = preload("res://scripts/tuning.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

## old_sku / new_sku are "" when the shelf is empty.
signal stock_sku_changed(shelf: Node, old_sku: String, new_sku: String)

var kind: String = "shelf"
var category: String = Tuning.CAT_DRY
var sku: String = ""
var count: int = 0
var capacity: int = Tuning.SHELF_CAP
var shelf_index: int = 1
var label: Label
var body: CanvasItem
var _goods: Sprite2D
var facing: Vector2 = Vector2.UP


func can_accept(item_sku: String) -> bool:
	if Tuning.category_of(item_sku) != category:
		return false
	if count >= capacity:
		return false
	return sku == "" or sku == item_sku


func occupied_sku() -> String:
	return sku if count > 0 and sku != "" else ""


func add_items(item_sku: String, n: int) -> int:
	if not can_accept(item_sku):
		return 0
	var old_sku := occupied_sku()
	var space := capacity - count
	var placed := mini(n, space)
	sku = item_sku
	count += placed
	_refresh()
	_emit_sku_change(old_sku)
	return placed


func take_all() -> Array[String]:
	var out: Array[String] = []
	if sku == "" or count <= 0:
		return out
	var old_sku := occupied_sku()
	for _i in count:
		out.append(sku)
	sku = ""
	count = 0
	_refresh()
	_emit_sku_change(old_sku)
	return out


func take_one(want: String) -> bool:
	if not has_sku(want):
		return false
	var old_sku := occupied_sku()
	count -= 1
	if count <= 0:
		sku = ""
		count = 0
	_refresh()
	_emit_sku_change(old_sku)
	return true


func has_sku(want: String) -> bool:
	return sku == want and count > 0


func _emit_sku_change(old_sku: String) -> void:
	var new_sku := occupied_sku()
	if old_sku == new_sku:
		return
	stock_sku_changed.emit(self, old_sku, new_sku)


func stand_position() -> Vector2:
	return global_position + facing * 58.0


func _refresh() -> void:
	if _goods == null:
		_goods = Vox.sprite("can", 0)
		_goods.scale = Vector2(0.55, 0.55)
		_goods.z_index = 1
		add_child(_goods)
	if sku == "":
		_goods.visible = false
	else:
		_goods.visible = true
		Vox.apply(_goods, sku, 0)
		_goods.scale = Vector2(0.55, 0.55)
		_goods.position = facing * -8.0 + Vector2(0, -28)
	var kind_name := "乾貨架"
	if category == Tuning.CAT_FROZEN:
		kind_name = "凍櫃貨架"
	elif category == Tuning.CAT_ICE:
		kind_name = "冰櫃貨架"
	if label:
		if sku == "":
			label.text = "%s %d\n空架　%d件" % [kind_name, shelf_index, capacity]
		else:
			label.text = "%s %d\n%s %d/%d" % [kind_name, shelf_index, Tuning.sku_name(sku), count, capacity]
