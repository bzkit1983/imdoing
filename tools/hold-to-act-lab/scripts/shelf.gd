extends StaticBody2D

const Tuning = preload("res://scripts/act_tuning.gd")

var kind: String = "shelf"
var sku: String = ""
var count: int = 0
var shelf_index: int = 1
var label: Label


func add_item(item_sku: String) -> void:
	if sku == "":
		sku = item_sku
	if sku != item_sku:
		return
	count = mini(Tuning.SHELF_CAP, count + 1)
	_refresh()


func _refresh() -> void:
	var vis: Polygon2D = get_node_or_null("Body")
	if vis:
		if sku == "":
			vis.color = Color("2f5d50")
		else:
			vis.color = Tuning.SKU_COLORS.get(sku, Color("2f5d50"))
	if label:
		if sku == "":
			label.text = "乾貨架 %d\n空架" % shelf_index
		else:
			label.text = "乾貨架 %d\n%s %d/%d" % [shelf_index, sku, count, Tuning.SHELF_CAP]
