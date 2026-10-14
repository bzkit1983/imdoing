extends StaticBody2D

const Tuning = preload("res://scripts/tuning.gd")

var kind: String = "restock"
var category: String = Tuning.CAT_DRY
var highlight: int = 0
var stock: Dictionary = {}
var label: Label
var body: Polygon2D


func setup(cat: String) -> void:
	category = cat
	stock.clear()
	for sku in Tuning.skus_for(category):
		stock[sku] = Tuning.RESTOCK_BOXES
	_refresh()


func skus() -> Array[String]:
	return Tuning.skus_for(category)


func selected_sku() -> String:
	var list := skus()
	return list[clampi(highlight, 0, list.size() - 1)]


func cycle(dir: int) -> void:
	highlight = posmod(highlight + dir, skus().size())
	_refresh()


func set_highlight(index: int) -> void:
	highlight = clampi(index, 0, skus().size() - 1)
	_refresh()


func take_box() -> bool:
	var sku := selected_sku()
	if int(stock.get(sku, 0)) <= 0:
		return false
	stock[sku] = int(stock[sku]) - 1
	_refresh()
	return true


func remaining(sku: String) -> int:
	return int(stock.get(sku, 0))


func _refresh() -> void:
	var sku := selected_sku()
	if body and Tuning.SKU_COLOR.has(sku):
		body.color = Tuning.SKU_COLOR[sku]
	var title := "乾貨補貨點" if category == Tuning.CAT_DRY else "凍櫃補貨點"
	if label:
		label.text = "%s\n%s  %d箱\nQ/E 或 1-3 選貨" % [title, Tuning.sku_name(sku), remaining(sku)]
