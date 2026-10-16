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
	pull_stock()
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 128
		add_child(_layer)
		_list = ListOverlay.new()
		_list.host = self
		_layer.add_child(_list)
	_refresh()


func skus() -> Array[String]:
	var game := get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	if game != null and game.get("state") != null:
		return game.state.developed_of(category)
	return []


func selected_sku() -> String:
	var list := skus()
	if list.is_empty():
		return ""
	return list[clampi(highlight, 0, list.size() - 1)]


func cycle(dir: int) -> void:
	if skus().is_empty():
		return
	if picking:
		move_pick(dir)
		return
	highlight = posmod(highlight + dir, skus().size())
	_refresh()


func set_highlight(index: int) -> void:
	if skus().is_empty():
		highlight = 0
		_refresh()
		return
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
	if skus().is_empty():
		return
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
	if sku == "":
		return false
	var game := get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	if game == null or game.get("state") == null:
		return false
	if not bool(game.state.consume_box(sku)):
		return false
	pull_stock()
	return true


func pull_stock() -> void:
	stock.clear()
	var game := get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	if game != null and game.get("state") != null:
		for sku in skus():
			stock[sku] = int(game.state.stock.get(sku, 0))
	_refresh()


func remaining(sku: String) -> int:
	return int(stock.get(sku, 0))


func _draw_sku_list(canvas: CanvasItem) -> void:
	if not picking:
		return
	var list := skus()
	var fs := UiFont.px(UiFont.BODY)
	var w := float(maxi(280, fs * 8))
	var row := float(fs + 12)
	var h := float(fs + 16) + row * float(list.size())
	var hy := 40.0
	if body:
		for pt in body.polygon:
			hy = maxf(hy, -pt.y)
	var origin := Vector2(-w * 0.5, -hy - h - 10.0)
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), Color(0.07, 0.08, 0.07, 0.94))
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), Color("f4d35e"), false, 2.0)
	var font := UiFont.font()
	canvas.draw_string(font, origin + Vector2(12, fs + 4), "選貨  ↑↓", HORIZONTAL_ALIGNMENT_LEFT, w - 24, fs, Color("f4d35e"))
	for i in list.size():
		var sku := list[i]
		var p := origin + Vector2(12, float(fs + 20) + row * float(i))
		var col := Color("f4d35e") if i == cursor else Color("f4f1ea")
		if i == cursor:
			canvas.draw_rect(Rect2(origin + Vector2(4, float(fs + 8) + row * float(i)), Vector2(w - 8, row)), Color("f4d35e", 0.22))
		var line := "%s  %d箱" % [Tuning.sku_name(sku), remaining(sku)]
		canvas.draw_string(font, p, line, HORIZONTAL_ALIGNMENT_LEFT, w - 24, UiFont.px(UiFont.WORLD), col)


func _refresh() -> void:
	var sku := selected_sku()
	if body and Tuning.SKU_COLOR.has(sku):
		body.color = Tuning.SKU_COLOR[sku]
	var title := "乾貨補貨點"
	if category == Tuning.CAT_FROZEN:
		title = "凍櫃補貨點"
	elif category == Tuning.CAT_ICE:
		title = "冰櫃補貨點"
	if label:
		if sku == "":
			label.text = "%s\n尚未開發\n先在準備頁開發商品" % title
		else:
			label.text = "%s\n%s  %d箱\n輕放執貨 · 長按選貨" % [title, Tuning.sku_name(sku), remaining(sku)]
