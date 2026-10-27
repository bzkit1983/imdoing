extends StaticBody2D

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")

var kind: String = "restock"
var category: String = Tuning.CAT_DRY
var highlight: int = 0
var cursor: int = 0
var picking: bool = false
var stock: Dictionary = {}
var label: Label
var body: CanvasItem
var _list: Node2D
var _layer: CanvasLayer
var _sku_icon: Sprite2D


class ListOverlay extends Node2D:
	var host: Node

	func _process(_delta: float) -> void:
		if host == null:
			return
		visible = bool(host.get("picking"))
		## Anchor on the clerk. A high shelf used to draw the panel off the top of the view.
		if host.has_method("_list_anchor"):
			position = host.call("_list_anchor")
		else:
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
	if _sku_icon:
		_sku_icon.visible = false
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


func _list_anchor() -> Vector2:
	## Screen position of the clerk. Fall back to this shelf if the round has no player yet.
	var fallback := get_global_transform_with_canvas().origin
	if not is_inside_tree():
		return fallback
	var game := get_tree().get_first_node_in_group("game")
	if game != null:
		var player = game.get("_player")
		if player is Node2D and is_instance_valid(player):
			return (player as Node2D).get_global_transform_with_canvas().origin
	return fallback


func _draw_sku_list(canvas: CanvasItem) -> void:
	if not picking:
		return
	var list := skus()
	var fs := UiFont.px(UiFont.BODY)
	var icon_px := 24.0
	var w := float(maxi(300, fs * 8 + int(icon_px) + 16))
	var row := float(maxi(fs + 12, int(icon_px) + 8))
	var h := float(fs + 16) + row * float(list.size())
	## Prefer just above the clerk. Clamp into the viewport so a tall list stays visible.
	var origin := Vector2(-w * 0.5, -h - 56.0)
	var anchor := Vector2.ZERO
	if canvas is Node2D:
		anchor = (canvas as Node2D).position
	var vp := get_viewport().get_visible_rect().size
	var margin := 8.0
	var screen := anchor + origin
	if screen.y < margin:
		origin.y = 40.0
		screen = anchor + origin
	if screen.x < margin:
		origin.x += margin - screen.x
	elif screen.x + w > vp.x - margin:
		origin.x -= screen.x + w - (vp.x - margin)
	screen = anchor + origin
	if screen.y + h > vp.y - margin:
		origin.y -= screen.y + h - (vp.y - margin)
	if anchor.y + origin.y < margin:
		origin.y = margin - anchor.y
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), Color(0.07, 0.08, 0.07, 0.94))
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), Color("f4d35e"), false, 2.0)
	var font := UiFont.font()
	canvas.draw_string(font, origin + Vector2(12, fs + 4), "選貨  ↑↓", HORIZONTAL_ALIGNMENT_LEFT, w - 24, fs, Color("f4d35e"))
	for i in list.size():
		var sku := list[i]
		var row_y := float(fs + 8) + row * float(i)
		var col := Color("f4d35e") if i == cursor else Color("f4f1ea")
		if i == cursor:
			canvas.draw_rect(Rect2(origin + Vector2(4, row_y), Vector2(w - 8, row)), Color("f4d35e", 0.22))
		var tex: Texture2D = SkuIcons.texture(sku)
		var icon_pos := origin + Vector2(10, row_y + (row - icon_px) * 0.5)
		canvas.draw_texture_rect(tex, Rect2(icon_pos, Vector2(icon_px, icon_px)), false)
		var line := "%s  %d箱" % [Tuning.sku_name(sku), remaining(sku)]
		var text_x := 10.0 + icon_px + 8.0
		canvas.draw_string(
			font,
			origin + Vector2(text_x, row_y + row * 0.72),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			w - text_x - 12.0,
			UiFont.px(UiFont.WORLD),
			col,
		)


func _refresh() -> void:
	var sku := selected_sku()
	var title := "乾貨補貨點"
	if category == Tuning.CAT_FROZEN:
		title = "凍櫃補貨點"
	elif category == Tuning.CAT_ICE:
		title = "冰櫃補貨點"
	if _sku_icon == null:
		_sku_icon = Sprite2D.new()
		_sku_icon.name = "SkuIcon"
		_sku_icon.centered = true
		_sku_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sku_icon.z_index = 2
		add_child(_sku_icon)
	if sku == "":
		_sku_icon.visible = false
	else:
		_sku_icon.visible = not picking
		_sku_icon.texture = SkuIcons.texture(sku)
		var s := 26.0 / float(SkuIcons.SIZE)
		_sku_icon.scale = Vector2(s, s)
		_sku_icon.position = Vector2(0, -40)
	if label:
		if sku == "":
			label.text = "%s\n尚未開發\n先在準備頁開發商品" % title
		else:
			## Icon shows SKU; caption keeps box count + hints.
			label.text = "%s\n%d箱\n輕放執貨 · 長按選貨" % [title, remaining(sku)]
