extends StaticBody2D
## Ops fish warehouse mouth (fishingtaro.md §4.2). Light-tap take 1; long-hold pick fish_id.

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")

var kind: String = "fish_tank"
var label: Label
var selected_fish: String = "saba"
var cursor: int = 0
var picking: bool = false
var pick_seat: int = -1
var stock: Dictionary = {}
var _list: Node2D
var _layer: CanvasLayer
var _fish_icon: Sprite2D


class ListOverlay extends Node2D:
	var host: Node

	func _process(_delta: float) -> void:
		if host == null:
			return
		visible = host.get("picking") == true
		if host.has_method("_list_anchor"):
			position = host.call("_list_anchor")
		else:
			position = host.get_global_transform_with_canvas().origin
		queue_redraw()

	func _draw() -> void:
		if host == null or host.get("picking") != true:
			return
		host.call("_draw_fish_list", self)


func setup_default_fish(state: RefCounted) -> void:
	setup_overlay()
	pull_stock()
	if state != null:
		for fid in Tuning.FISH_IDS:
			if int(state.fish_count(fid)) > 0:
				selected_fish = fid
				break
	_refresh_label()


func setup_overlay() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_list = ListOverlay.new()
	_list.host = self
	_layer.add_child(_list)


## Full species list — pick UI and cursor always share this order (avoids stocked-only index mismatch).
func _pick_list() -> Array[String]:
	var out: Array[String] = []
	for fid in Tuning.FISH_IDS:
		out.append(fid)
	return out


## Restock-compatible API: same order as the pick menu.
func skus() -> Array[String]:
	return _pick_list()


func selected_sku() -> String:
	if Tuning.is_fish_id(selected_fish):
		return selected_fish
	var list := _pick_list()
	return list[0] if not list.is_empty() else ""


func cycle(dir: int) -> void:
	if picking:
		move_pick(dir)
		return
	var list := _pick_list()
	if list.is_empty():
		return
	var idx := list.find(selected_fish)
	if idx < 0:
		idx = 0
	selected_fish = list[posmod(idx + dir, list.size())]
	pull_stock()


func begin_pick(seat_id: int = -1) -> void:
	setup_overlay()
	picking = true
	pick_seat = seat_id
	if pick_seat < 0:
		var lock = get_node_or_null("/root/InteractLock")
		if lock != null and lock.has_method("holder_of"):
			pick_seat = int(lock.holder_of(self))
	var list := _pick_list()
	cursor = list.find(selected_fish)
	if cursor < 0:
		cursor = 0
	if label:
		label.visible = false
	if _fish_icon:
		_fish_icon.visible = false
	if _list:
		_list.queue_redraw()


func move_pick(delta_index: int) -> void:
	var list := _pick_list()
	if list.is_empty():
		return
	cursor = posmod(cursor + delta_index, list.size())
	if _list:
		_list.queue_redraw()


func commit_pick() -> String:
	var list := _pick_list()
	if not list.is_empty():
		selected_fish = list[clampi(cursor, 0, list.size() - 1)]
	picking = false
	pick_seat = -1
	if label:
		label.visible = true
	pull_stock()
	if _list:
		_list.queue_redraw()
	return selected_sku()


func abort_pick() -> void:
	picking = false
	pick_seat = -1
	if label:
		label.visible = true
	_refresh_label()
	if _list:
		_list.queue_redraw()


func take_box() -> bool:
	return take_pieces(1) == 1


func take_pieces(requested: int) -> int:
	## §8.2: networked Client must not consume fish_stock.
	if SessionService.is_networked() and SessionService.is_client():
		return 0
	if requested <= 0:
		return 0
	var fid := selected_sku()
	if fid == "" or not Tuning.is_fish_id(fid):
		return 0
	var state := _game_state()
	if state == null:
		return 0
	var available := int(state.fish_count(fid))
	var taken := mini(requested, available)
	if taken <= 0 or not bool(state.consume_fish(fid, taken)):
		return 0
	pull_stock()
	return taken


func pull_stock() -> void:
	stock.clear()
	var state := _game_state()
	if state != null:
		for fid in Tuning.FISH_IDS:
			stock[fid] = int(state.fish_count(fid))
	_refresh_label()


func remaining(sku: String) -> int:
	return int(stock.get(sku, 0))


func stand_position() -> Vector2:
	return global_position + Vector2(0, 78)


func _game_state() -> RefCounted:
	var game := get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	if game == null:
		return null
	return game.get("state") as RefCounted


func _list_anchor() -> Vector2:
	var fallback := get_global_transform_with_canvas().origin
	if not is_inside_tree():
		return fallback
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return fallback
	var player = null
	if pick_seat >= 0 and game.has_method("_player_for_seat"):
		player = game.call("_player_for_seat", pick_seat)
	if player == null:
		player = game.get("_player")
	if player is Node2D and is_instance_valid(player):
		return (player as Node2D).get_global_transform_with_canvas().origin
	return fallback


func _draw_fish_list(canvas: CanvasItem) -> void:
	if not picking:
		return
	var list := _pick_list()
	var fs := UiFont.px(UiFont.BODY)
	var icon_px := 24.0
	var w := float(maxi(300, fs * 8 + int(icon_px) + 16))
	var row := float(maxi(fs + 12, int(icon_px) + 8))
	var h := float(fs + 16) + row * float(list.size())
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
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), Color("7ec8e3"), false, 2.0)
	var font := UiFont.font()
	canvas.draw_string(
		font,
		origin + Vector2(12, fs + 4),
		Loc.t("world.fish_tank.pick"),
		HORIZONTAL_ALIGNMENT_LEFT,
		w - 24,
		fs,
		Color("7ec8e3"),
	)
	for i in list.size():
		var fid := list[i]
		var row_y := float(fs + 8) + row * float(i)
		var col := Color("7ec8e3") if i == cursor else Color("f4f1ea")
		if i == cursor:
			canvas.draw_rect(Rect2(origin + Vector2(4, row_y), Vector2(w - 8, row)), Color("7ec8e3", 0.22))
		var tex: Texture2D = SkuIcons.texture(fid)
		var icon_pos := origin + Vector2(10, row_y + (row - icon_px) * 0.5)
		canvas.draw_texture_rect(tex, Rect2(icon_pos, Vector2(icon_px, icon_px)), false)
		var line := Loc.t("world.fish_tank.stock_line", [Tuning.fish_name(fid), remaining(fid)])
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


func _refresh_label(state: RefCounted = null) -> void:
	if state == null:
		state = _game_state()
	if _fish_icon == null:
		_fish_icon = Sprite2D.new()
		_fish_icon.name = "FishIcon"
		_fish_icon.centered = true
		_fish_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_fish_icon.z_index = 2
		add_child(_fish_icon)
	var fid := selected_sku()
	if fid == "":
		_fish_icon.visible = false
	else:
		_fish_icon.visible = not picking
		_fish_icon.texture = SkuIcons.texture(fid)
		var s := 52.0 / float(SkuIcons.SIZE)
		_fish_icon.scale = Vector2(s, s)
		_fish_icon.position = Vector2(0, -48)
	if label == null:
		return
	if state == null:
		label.text = Loc.t("furniture.fish_tank")
		return
	if fid == "":
		label.text = Loc.t("world.fish_tank.empty")
		return
	var n := int(state.fish_count(fid))
	label.text = Loc.t("world.fish_tank.count", [Tuning.fish_name(fid), n])
	if _list:
		_list.queue_redraw()
