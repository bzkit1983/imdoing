extends StaticBody2D

const Tuning = preload("res://scripts/act_tuning.gd")

var kind: String = "restock"
var selected_sku: String = "罐頭"
var label: Label


func _process(_delta: float) -> void:
	if label:
		label.text = "乾貨補貨點\n選：%s\n1/2/3 換貨" % selected_sku
		var vis: Polygon2D = get_node_or_null("Body")
		if vis and Tuning.SKU_COLORS.has(selected_sku):
			vis.color = Tuning.SKU_COLORS[selected_sku]
