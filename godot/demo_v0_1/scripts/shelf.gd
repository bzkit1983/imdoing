extends StaticBody2D

const Tuning = preload("res://scripts/tuning.gd")

var kind: String = "shelf"
var sku: String = ""
var count: int = 0
var shelf_index: int = 1
var label: Label
var body: Polygon2D
var fill: Polygon2D


func can_accept(item_sku: String) -> bool:
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


func _refresh() -> void:
	if body:
		body.color = Color("2f5d50") if sku == "" else Tuning.SKU_COLOR.get(sku, Color("2f5d50"))
	if fill:
		var t := 0.0 if Tuning.SHELF_CAP <= 0 else float(count) / float(Tuning.SHELF_CAP)
		fill.scale = Vector2(t, 1.0)
		fill.color = Color("f4f1ea", 0.35)
	if label:
		if sku == "":
			label.text = "乾貨架 %d\n空架" % shelf_index
		else:
			label.text = "乾貨架 %d\n%s %d/%d" % [shelf_index, Tuning.sku_name(sku), count, Tuning.SHELF_CAP]
