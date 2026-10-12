extends StaticBody2D

const Tuning = preload("res://scripts/tuning.gd")

var kind: String = "restock"
var highlight: int = 0
var stock := {"can": Tuning.RESTOCK_BOXES, "snack": Tuning.RESTOCK_BOXES, "cup": Tuning.RESTOCK_BOXES}
var label: Label
var body: Polygon2D


func selected_sku() -> String:
	return Tuning.SKUS[clampi(highlight, 0, Tuning.SKUS.size() - 1)]


func cycle(dir: int) -> void:
	highlight = posmod(highlight + dir, Tuning.SKUS.size())
	_refresh()


func set_highlight(index: int) -> void:
	highlight = clampi(index, 0, Tuning.SKUS.size() - 1)
	_refresh()


func take_box() -> bool:
	var sku := selected_sku()
	if int(stock[sku]) <= 0:
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
	if label:
		label.text = "乾貨補貨點\n%s  %d箱\nQ/E 或 1-3 選貨" % [Tuning.sku_name(sku), remaining(sku)]
