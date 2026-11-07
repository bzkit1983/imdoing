extends Control
## Shop layout grid drawn inside the prep menu.

const StateScript = preload("res://scripts/game_state.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")

var host: CanvasLayer


func _gui_input(event: InputEvent) -> void:
	if host == null or host._drag_on:
		return
	if int(host.get("_sku_pick_i")) >= 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: float = host._cell_px()
		host._cursor = Vector2i(int(event.position.x / cell), int(event.position.y / cell))
		## Mouse place/pickup/drag is owned by prep_menu._input (_press_layout /
		## _release_layout). Calling try_place here double-fired: pickup removed the
		## item then release remove_at(stale index) hit a different piece — e.g. ice
		## shelf click could surface as dry. Only place when already holding.
		if String(host.get("_hold_type")) != "":
			host.try_place()


func _draw() -> void:
	if host == null or not host.state or host._page != "layout":
		return
	var st: StateScript = host.state
	var cell: float = host._cell_px()
	for y in st.grid_h:
		for x in st.grid_w:
			var r := Rect2(Vector2(x, y) * cell, Vector2(cell - 1, cell - 1))
			draw_rect(r, Color("24302a"))
	for d in st.door_cells():
		draw_rect(Rect2(Vector2(d.x, d.y) * cell, Vector2(cell - 1, cell - 1)), Color("3a2a1e"))
	var skip := -1
	if host._drag_on and host._drag_moved:
		skip = int(host._drag_from)
	var pick_i: int = int(host.get("_sku_pick_i"))
	for i in st.placed.size():
		if i == skip:
			continue
		var it: Dictionary = st.placed[i]
		var col := Color("5c4033")
		var t := String(it["type"])
		if t.begins_with("shelf"):
			## Distinct fills: dry green · frozen deep cyan · ice pale lavender.
			if t.contains("frozen"):
				col = Color("1a7a8c")
			elif t.contains("ice"):
				col = Color("c8d4f0")
			else:
				col = Color("2f5d50")
		elif t.begins_with("restock"):
			if t.ends_with("frozen"):
				col = Color("148a9e")
			elif t.ends_with("ice"):
				col = Color("dde4f7")
			else:
				col = Color("c45c26")
		var rect := Rect2(Vector2(int(it["x"]), int(it["y"])) * cell, Vector2(int(it["w"]), int(it["h"])) * cell - Vector2(2, 2))
		draw_rect(rect, col)
		if t.begins_with("restock"):
			var sku := String(it.get("default_sku", ""))
			if pick_i == i:
				var list: Array = host.call("_sku_pick_list")
				if list is Array and not list.is_empty():
					var cidx: int = clampi(int(host.get("_sku_pick_cursor")), 0, list.size() - 1)
					sku = String(list[cidx])
				draw_rect(rect, Color("f4d35e", 0.35))
			if sku != "":
				var tex: Texture2D = SkuIcons.texture(sku)
				var icon_px := mini(cell * 0.7, 28.0)
				var icon_r := Rect2(rect.position + (rect.size - Vector2(icon_px, icon_px)) * 0.5, Vector2(icon_px, icon_px))
				draw_texture_rect(tex, icon_r, false)
	var ghost := ""
	var rot := 0
	var ignore := -1
	if host._drag_on and host._drag_moved and host._drag_inside:
		ghost = host._drag_type
		rot = host._drag_rot
		ignore = host._drag_from
	elif host._hold_type != "":
		ghost = host._hold_type
		rot = host._hold_rot
	if ghost != "":
		var fp: Vector2i = st.footprint(ghost, rot)
		var ok: bool = st.can_place(ghost, host._cursor.x, host._cursor.y, rot, ignore)
		draw_rect(Rect2(Vector2(host._cursor) * cell, Vector2(fp) * cell), Color("7ec8e3" if ok else "c0392b", 0.65))
	elif not host._drag_on and pick_i < 0:
		draw_rect(Rect2(Vector2(host._cursor) * cell, Vector2(cell - 1, cell - 1)), Color("f4d35e", 0.8), false, 2.0)
