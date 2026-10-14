extends StaticBody2D

const Tuning = preload("res://scripts/tuning.gd")

var kind: String = "shelf"
var category: String = Tuning.CAT_DRY
var sku: String = ""
var count: int = 0
var shelf_index: int = 1
var label: Label
var body: Polygon2D


func can_accept(item_sku: String) -> bool:
	if Tuning.category_of(item_sku) != category:
		return false
	if count >= Tuning.SHELF_CAP:
		return false
	return sku == "" or sku == item_sku


func add_items(item_sku: String, n: int) -> int:
	if not can_accept(item_sku):
		return 0
	var space := Tuning.SHELF_CAP - count
	var placed := mini(n, space)
	sku = item_sku
	count += placed
	_refresh()
	return placed


func take_one(want: String) -> bool:
	if not has_sku(want):
		return false
	count -= 1
	if count <= 0:
		sku = ""
		count = 0
	_refresh()
	return true


func has_sku(want: String) -> bool:
	return sku == want and count > 0


func stand_position() -> Vector2:
	# Door is north of the store; stop in the aisle in front of the shelf.
	return global_position + Vector2(0, -58)


func _refresh() -> void:
	var empty := Color("2f5d50") if category == Tuning.CAT_DRY else Color("355a6a")
	if body:
		body.color = empty if sku == "" else Tuning.SKU_COLOR.get(sku, empty)
	var kind_name := "乾貨架" if category == Tuning.CAT_DRY else "凍櫃貨架"
	if label:
		if sku == "":
			label.text = "%s %d\n空架" % [kind_name, shelf_index]
		else:
			label.text = "%s %d\n%s %d/%d" % [kind_name, shelf_index, Tuning.sku_name(sku), count, Tuning.SHELF_CAP]
