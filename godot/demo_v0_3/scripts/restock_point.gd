extends StaticBody2D

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")

var kind: String = "restock"
var category: String = Tuning.CAT_DRY
var highlight: int = 0
var cursor: int = 0
var picking: bool = false
var stock: Dictionary = {}
var label: Label
var body: Polygon2D
var _list: Node2D
var _layer: CanvasLayer


class ListOverlay extends Node2D:
	var host: Node

	func _process(_delta: float) -> void:
		if host == null:
			return
		visible = bool(host.get("picking"))
		position = host.get_global_transform_with_canvas().origin
		queue_redraw()

	func _draw() -> void:
		if host == null or not bool(host.get("picking")):
			return
		host.call("_draw_sku_list", self)


func setup(cat: String) -> void:
	category = cat
	stock.clear()
	for sku in Tuning.skus_for(category):
		stock[sku] = Tuning.RESTOCK_BOXES
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 128
		add_child(_layer)
		_list = ListOverlay.new()
		_list.host = self
		_layer.add_child(_list)
	_refresh()


func skus() -> Array[String]:
	return Tuning.skus_for(category)


func selected_sku() -> String:
	var list := skus()
	return list[clampi(highlight, 0, list.size() - 1)]


func cycle(dir: int) -> void:
	if picking:
		move_pick(dir)
		return
	highlight = posmod(highlight + dir, skus().size())
	_refresh()


func set_highlight(index: int) -> void:
	highlight = clampi(index, 0, skus().size() - 1)
	_refresh()


func begin_pick() -> void:
	picking = true
	cursor = highlight
	if label:
		label.visible = false
	if _list:
		_list.queue_redraw()


func move_pick(delta_index: int) -> void:
	cursor = posmod(cursor + delta_index, skus().size())
	if _list:
		_list.queue_redraw()


func commit_pick() -> String:
	highlight = cursor
	picking = false
	if label:
		label.visible = true
	_refresh()
	if _list:
		_list.queue_redraw()
	return selected_sku()


func abort_pick() -> void:
	picking = false
	if label:
		label.visible = true
	_refresh()
	if _list:
		_list.queue_redraw()


func take_box() -> bool:
	var sku := selected_sku()
	if int(stock.get(sku, 0)) <= 0:
		return false
	stock[sku] = int(stock[sku]) - 1
	_refresh()
	return true


func remaining(sku: String) -> int:
	return int(stock.get(sku, 0))


func _draw_sku_list(canvas: CanvasItem) -> void:
	if not picking:
		return
	var list := skus()
	var w := 240.0
	var row := 36.0
	var h := 44.0 + row * float(list.size())
	var hy := 40.0
	if body:
		for pt in body.polygon:
			hy = maxf(hy, -pt.y)
	var origin := Vector2(-w * 0.5, -hy - h - 10.0)
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), Color(0.07, 0.08, 0.07, 0.94))
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), Color("f4d35e"), false, 2.0)
	var font := UiFont.font()
	canvas.draw_string(font, origin + Vector2(10, 28), "選貨  ↑↓", HORIZONTAL_ALIGNMENT_LEFT, w - 20, UiFont.BODY, Color("f4d35e"))
	for i in list.size():
		var sku := list[i]
		var p := origin + Vector2(10, 56 + row * float(i))
		var col := Color("f4d35e") if i == cursor else Color("f4f1ea")
		if i == cursor:
			canvas.draw_rect(Rect2(origin + Vector2(4, 36 + row * float(i)), Vector2(w - 8, row)), Color("f4d35e", 0.22))
		var line := "%s  %d箱" % [Tuning.sku_name(sku), remaining(sku)]
		canvas.draw_string(font, p, line, HORIZONTAL_ALIGNMENT_LEFT, w - 20, UiFont.WORLD, col)


func _refresh() -> void:
	var sku := selected_sku()
	if body and Tuning.SKU_COLOR.has(sku):
		body.color = Tuning.SKU_COLOR[sku]
	var title := "乾貨補貨點" if category == Tuning.CAT_DRY else "凍櫃補貨點"
	if label:
		label.text = "%s\n%s  %d箱\n輕放執貨 · 長按選貨" % [title, Tuning.sku_name(sku), remaining(sku)]
