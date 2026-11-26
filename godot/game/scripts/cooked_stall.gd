extends StaticBody2D
## Cooked-food stall (theme_historic): face stock + craft pick UI + craft Circle.

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")

var kind: String = "cooked_stall"
## Face slots: Array[{sku_id, count}].
var face_slots: Array = []
var capacity_total: int = 8
## Raw materials deposited at this stall before craft (grain／soy／fish_id → count).
var pantry: Dictionary = {}
## Soft cap on total pantry pieces.
var pantry_capacity: int = 24
var label: Label
## Guest stall queue (independent of cashier).
var queue: Array = []
var facing: Vector2 = Vector2.DOWN
var front_offset: Vector2 = Vector2(0, 78)
var slot_gap: float = 36.0

var picking: bool = false
var pick_seat: int = -1
var cursor: int = 0
var fish_cursor: int = 0
var crafting: bool = false
var craft_sku: String = ""
var craft_fish: String = ""
var craft_left: float = 0.0
var craft_total: float = Tuning.COOKED_CRAFT_SEC

var _list: Node2D
var _layer: CanvasLayer


class ListOverlay extends Node2D:
	var host: Node

	func _process(_delta: float) -> void:
		if host == null:
			return
		visible = host.get("picking") == true or host.get("crafting") == true
		if host.has_method("_list_anchor"):
			position = host.call("_list_anchor")
		else:
			position = host.get_global_transform_with_canvas().origin
		queue_redraw()

	func _draw() -> void:
		if host == null:
			return
		if host.get("crafting") == true:
			host.call("_draw_craft_progress", self)
		elif host.get("picking") == true:
			host.call("_draw_craft_list", self)


func setup_overlay() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_list = ListOverlay.new()
	_list.host = self
	_layer.add_child(_list)


func set_facing(dir: Vector2) -> void:
	facing = dir.normalized() if dir.length_squared() > 0.01 else Vector2.DOWN
	front_offset = facing * 78.0


func stand_position() -> Vector2:
	## Join / front stand for guests seeking this stall.
	return global_position + front_offset


func front_customer():
	if queue.is_empty():
		return null
	return queue[0]


func enqueue(customer) -> void:
	if customer in queue:
		return
	queue.append(customer)


func dequeue(customer) -> void:
	queue.erase(customer)
	_compact_queue_stands()


func queue_index_of(customer) -> int:
	return int(queue.find(customer))


func slot_position(index: int) -> Vector2:
	return global_position + front_offset + facing * slot_gap * float(index)


func _compact_queue_stands() -> void:
	const CustomerScript = preload("res://scripts/customer.gd")
	for i in queue.size():
		var c = queue[i]
		if c == null or not is_instance_valid(c):
			continue
		if c.get("_stall_queue_idx") != null:
			c.set("_stall_queue_idx", i)
		var st := int(c.get("state")) if c.get("state") != null else -1
		if st != CustomerScript.State.QUEUE_STALL and st != CustomerScript.State.WAITING_CRAFT:
			continue
		if c.has_method("snap_to_stall_slot"):
			c.call("snap_to_stall_slot", slot_position(i))


func face_total() -> int:
	var n := 0
	for row in face_slots:
		if row is Dictionary:
			n += int(row.get("count", 0))
	return n


func can_accept_face(sku: String) -> bool:
	if Tuning.category_of(sku) != Tuning.CAT_COOKED:
		return false
	return face_total() < capacity_total


func add_face(sku: String, n: int = 1) -> int:
	if n <= 0 or not can_accept_face(sku):
		return 0
	var room := capacity_total - face_total()
	var take := mini(n, room)
	for row in face_slots:
		if row is Dictionary and String(row.get("sku_id", "")) == sku:
			row["count"] = int(row.get("count", 0)) + take
			_refresh_label()
			return take
	face_slots.append({"sku_id": sku, "count": take})
	_refresh_label()
	return take


func take_face(sku: String, n: int = 1) -> int:
	if n <= 0:
		return 0
	for i in face_slots.size():
		var row = face_slots[i]
		if not (row is Dictionary):
			continue
		if String(row.get("sku_id", "")) != sku:
			continue
		var have := int(row.get("count", 0))
		var take := mini(n, have)
		row["count"] = have - take
		if int(row["count"]) <= 0:
			face_slots.remove_at(i)
		_refresh_label()
		return take
	return 0


func face_count_of(sku: String) -> int:
	for row in face_slots:
		if row is Dictionary and String(row.get("sku_id", "")) == sku:
			return int(row.get("count", 0))
	return 0


func pantry_total() -> int:
	var n := 0
	for k in pantry.keys():
		n += int(pantry[k])
	return n


func ingredient_count(id: String) -> int:
	return int(pantry.get(id, 0))


func can_accept_ingredient(id: String, n: int = 1) -> bool:
	if n <= 0 or not Tuning.is_cooked_ingredient(id):
		return false
	return pantry_total() + n <= pantry_capacity


func add_ingredient(id: String, n: int = 1) -> int:
	if not can_accept_ingredient(id, n):
		## Partial fill up to capacity.
		if n <= 0 or not Tuning.is_cooked_ingredient(id):
			return 0
		var room := pantry_capacity - pantry_total()
		n = mini(n, room)
		if n <= 0:
			return 0
	pantry[id] = int(pantry.get(id, 0)) + n
	_refresh_label()
	return n


func take_ingredient(id: String, n: int = 1) -> int:
	if n <= 0 or id == "":
		return 0
	var have := int(pantry.get(id, 0))
	var take := mini(n, have)
	if take <= 0:
		return 0
	var left := have - take
	if left <= 0:
		pantry.erase(id)
	else:
		pantry[id] = left
	_refresh_label()
	return take


func take_all_pantry() -> Dictionary:
	var out: Dictionary = pantry.duplicate()
	pantry.clear()
	_refresh_label()
	return out


func take_all_face() -> Dictionary:
	var out: Dictionary = {}
	for row in face_slots:
		if not (row is Dictionary):
			continue
		var sid := String(row.get("sku_id", ""))
		var n := int(row.get("count", 0))
		if sid == "" or n <= 0:
			continue
		out[sid] = int(out.get(sid, 0)) + n
	face_slots.clear()
	_refresh_label()
	return out


func can_afford_from_pantry(sku: String, fish_id: String = "") -> bool:
	if not Tuning.is_craft_only(sku):
		return false
	for raw in Tuning.cooked_recipe(sku):
		if not (raw is Dictionary):
			continue
		var kind := String(raw.get("kind", ""))
		var n := int(raw.get("n", 1))
		if kind == "sku":
			if ingredient_count(String(raw.get("id", ""))) < n:
				return false
		elif kind == "fish":
			var fid := fish_id
			if fid == "":
				fid = _first_pantry_fish()
			if fid == "" or ingredient_count(fid) < n:
				return false
		else:
			return false
	return true


func consume_from_pantry(sku: String, fish_id: String = "") -> String:
	if not can_afford_from_pantry(sku, fish_id):
		return Loc.t("err.cooked_ingredients")
	for raw in Tuning.cooked_recipe(sku):
		if not (raw is Dictionary):
			continue
		var kind := String(raw.get("kind", ""))
		var n := int(raw.get("n", 1))
		if kind == "sku":
			var sid := String(raw.get("id", ""))
			if take_ingredient(sid, n) < n:
				return Loc.t("err.cooked_ingredients")
		elif kind == "fish":
			var fid := fish_id if fish_id != "" else _first_pantry_fish()
			if take_ingredient(fid, n) < n:
				return Loc.t("err.cooked_ingredients")
	return ""


func refund_to_pantry(sku: String, fish_id: String = "") -> void:
	for raw in Tuning.cooked_recipe(sku):
		if not (raw is Dictionary):
			continue
		var kind := String(raw.get("kind", ""))
		var n := int(raw.get("n", 1))
		if kind == "sku":
			add_ingredient(String(raw.get("id", "")), n)
		elif kind == "fish" and fish_id != "":
			add_ingredient(fish_id, n)


func _first_pantry_fish() -> String:
	for fid in Tuning.FISH_IDS:
		if ingredient_count(fid) > 0:
			return fid
	return ""


func _game_state() -> RefCounted:
	var game := get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	if game == null:
		return null
	return game.get("state") as RefCounted


## Developed＋for_sale cooked recipes (menu rows).
func craftable_skus() -> Array[String]:
	var out: Array[String] = []
	var state := _game_state()
	if state == null:
		return out
	for sku in Tuning.COOKED_SKUS:
		if state.developed.has(sku) and state.is_for_sale(sku):
			out.append(sku)
	return out


func has_craftable() -> bool:
	return not craftable_skus().is_empty()


func selected_sku() -> String:
	var list := craftable_skus()
	if list.is_empty():
		return ""
	return list[clampi(cursor, 0, list.size() - 1)]


## Fish species already deposited in this stall's pantry.
func available_fish() -> Array[String]:
	var out: Array[String] = []
	for fid in Tuning.FISH_IDS:
		if ingredient_count(fid) > 0:
			out.append(fid)
	return out


func selected_fish() -> String:
	var list := available_fish()
	if list.is_empty():
		return ""
	return list[clampi(fish_cursor, 0, list.size() - 1)]


func _craft_player() -> Variant:
	var game := get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	if game == null:
		return null
	if pick_seat >= 0 and game.has_method("_player_for_seat"):
		var seat_p = game.call("_player_for_seat", pick_seat)
		if seat_p != null and is_instance_valid(seat_p):
			return seat_p
	return game.get("_player")


func begin_pick(seat_id: int = -1) -> void:
	if crafting:
		return
	setup_overlay()
	picking = true
	pick_seat = seat_id
	if pick_seat < 0:
		var lock = get_node_or_null("/root/InteractLock")
		if lock != null and lock.has_method("holder_of"):
			pick_seat = int(lock.holder_of(self))
	var list := craftable_skus()
	## Prefer the front waiting guest's order.
	var prefer := _waiting_order_sku()
	if prefer != "" and list.has(prefer):
		cursor = list.find(prefer)
	cursor = clampi(cursor, 0, maxi(0, list.size() - 1))
	_sync_fish_cursor()
	if label:
		label.visible = false
	if _list:
		_list.queue_redraw()


func _waiting_order_sku() -> String:
	var guest = front_customer()
	if guest == null or not is_instance_valid(guest):
		return ""
	const CustomerScript = preload("res://scripts/customer.gd")
	var st := int(guest.get("state")) if guest.get("state") != null else -1
	if st != CustomerScript.State.WAITING_CRAFT and st != CustomerScript.State.QUEUE_STALL:
		return ""
	var shopping = guest.get("shopping")
	if shopping is Array and not shopping.is_empty():
		return String(shopping[0])
	return ""


func move_pick(delta_index: int) -> void:
	var list := craftable_skus()
	if list.is_empty():
		return
	cursor = posmod(cursor + delta_index, list.size())
	_sync_fish_cursor()
	if _list:
		_list.queue_redraw()


func move_fish(delta_index: int) -> void:
	if selected_sku() != "nigiri":
		return
	var list := available_fish()
	if list.is_empty():
		return
	fish_cursor = posmod(fish_cursor + delta_index, list.size())
	if _list:
		_list.queue_redraw()


func _sync_fish_cursor() -> void:
	var list := available_fish()
	if list.is_empty():
		fish_cursor = 0
		return
	fish_cursor = clampi(fish_cursor, 0, list.size() - 1)


func abort_pick() -> void:
	picking = false
	pick_seat = -1
	if label and not crafting:
		label.visible = true
	_refresh_label()
	if _list:
		_list.queue_redraw()


## Close pick UI and start craft Circle. Returns "" or error message.
func commit_craft() -> String:
	var sku := selected_sku()
	var fish := selected_fish() if sku == "nigiri" else ""
	picking = false
	var err := try_begin_craft(sku, fish)
	if err != "":
		pick_seat = -1
		if label:
			label.visible = true
		_refresh_label()
		if _list:
			_list.queue_redraw()
		return err
	return ""


func try_begin_craft(sku: String, fish_id: String = "") -> String:
	if crafting:
		return Loc.t("err.cooked_busy")
	if sku == "nigiri" and fish_id == "":
		fish_id = _first_pantry_fish()
	## Craft only from stall pantry — never warehouse / fish_stock / hands.
	var err := consume_from_pantry(sku, fish_id)
	if err != "":
		return err
	crafting = true
	craft_sku = sku
	craft_fish = fish_id if sku == "nigiri" else ""
	craft_total = Tuning.COOKED_CRAFT_SEC
	craft_left = craft_total
	if label:
		label.visible = false
	if _list:
		_list.queue_redraw()
	return ""


func tick_craft(delta: float) -> bool:
	if not crafting:
		return false
	craft_left = maxf(0.0, craft_left - delta)
	if _list:
		_list.queue_redraw()
	if craft_left > 0.001:
		return false
	_finish_craft()
	return true


func craft_progress() -> float:
	if not crafting or craft_total <= 0.001:
		return 0.0
	return 1.0 - (craft_left / craft_total)


func cancel_craft() -> void:
	if not crafting:
		return
	refund_to_pantry(craft_sku, craft_fish)
	crafting = false
	craft_sku = ""
	craft_fish = ""
	craft_left = 0.0
	pick_seat = -1
	if label:
		label.visible = true
	_refresh_label()
	if _list:
		_list.queue_redraw()


func _finish_craft() -> void:
	var state := _game_state()
	var sku := craft_sku
	crafting = false
	craft_left = 0.0
	## Prefer fulfilling the waiting front guest before stocking the face.
	var fulfilled := false
	var guest = front_customer()
	if guest != null and is_instance_valid(guest) and guest.has_method("receive_stall_craft"):
		fulfilled = bool(guest.call("receive_stall_craft", sku))
	if not fulfilled and state != null:
		state.deposit_cooked_result(self, sku)
	craft_sku = ""
	craft_fish = ""
	pick_seat = -1
	if label:
		label.visible = true
	_refresh_label()
	if _list:
		_list.queue_redraw()


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


func _ingredient_line(sku: String, _state: RefCounted = null) -> String:
	var parts: PackedStringArray = []
	for raw in Tuning.cooked_recipe(sku):
		if not (raw is Dictionary):
			continue
		var kind := String(raw.get("kind", ""))
		var n := int(raw.get("n", 1))
		if kind == "sku":
			var sid := String(raw.get("id", ""))
			parts.append("%s×%d(%d)" % [Tuning.sku_name(sid), n, ingredient_count(sid)])
		elif kind == "fish":
			var fid := selected_fish()
			var name := Tuning.fish_name(fid) if fid != "" else Loc.t("ui.cooked.need_fish")
			var have := ingredient_count(fid) if fid != "" else 0
			parts.append("%s×%d(%d)" % [name, n, have])
	return " + ".join(parts)


func _draw_craft_list(canvas: CanvasItem) -> void:
	if not picking:
		return
	var list := craftable_skus()
	var fs := UiFont.px(UiFont.BODY)
	var icon_px := 24.0
	var w := float(maxi(340, fs * 10 + int(icon_px) + 16))
	var row := float(maxi(fs + 14, int(icon_px) + 10))
	var extra := 0.0
	if selected_sku() == "nigiri":
		extra = row
	var h := float(fs + 16) + row * float(list.size()) + extra
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
	canvas.draw_string(
		font,
		origin + Vector2(12, fs + 4),
		Loc.t("ui.cooked.craft_title"),
		HORIZONTAL_ALIGNMENT_LEFT,
		w - 24,
		fs,
		Color("f4d35e"),
	)
	for i in list.size():
		var sku := list[i]
		var row_y := float(fs + 8) + row * float(i)
		var afford: bool = can_afford_from_pantry(sku, selected_fish() if sku == "nigiri" else "")

		var col := Color("f4d35e") if i == cursor else Color("f4f1ea")
		if not afford:
			col = Color("9a9080")
		if i == cursor:
			canvas.draw_rect(Rect2(origin + Vector2(4, row_y), Vector2(w - 8, row)), Color("f4d35e", 0.22))
		var tex: Texture2D = SkuIcons.texture(sku)
		var icon_pos := origin + Vector2(10, row_y + (row - icon_px) * 0.5)
		canvas.draw_texture_rect(tex, Rect2(icon_pos, Vector2(icon_px, icon_px)), false)
		var line := "%s  %s" % [Tuning.sku_name(sku), _ingredient_line(sku)]
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
	if selected_sku() == "nigiri":
		var fish_y := float(fs + 8) + row * float(list.size())
		var fish := selected_fish()
		var fish_line := Loc.t("ui.cooked.fish_pick", [
			Tuning.fish_name(fish) if fish != "" else Loc.t("ui.cooked.need_fish"),
		])
		canvas.draw_string(
			font,
			origin + Vector2(12, fish_y + row * 0.72),
			fish_line,
			HORIZONTAL_ALIGNMENT_LEFT,
			w - 24,
			UiFont.px(UiFont.WORLD),
			Color("7ec8e3"),
		)


func _draw_craft_progress(canvas: CanvasItem) -> void:
	if not crafting:
		return
	var fs := UiFont.px(UiFont.BODY)
	var w := 220.0
	var h := float(fs + 36)
	var origin := Vector2(-w * 0.5, -h - 48.0)
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), Color(0.07, 0.08, 0.07, 0.94))
	canvas.draw_rect(Rect2(origin, Vector2(w, h)), Color("f4d35e"), false, 2.0)
	var font := UiFont.font()
	canvas.draw_string(
		font,
		origin + Vector2(12, fs + 4),
		Loc.t("ui.cooked.crafting", [Tuning.sku_name(craft_sku)]),
		HORIZONTAL_ALIGNMENT_LEFT,
		w - 24,
		fs,
		Color("f4d35e"),
	)
	var bar := Rect2(origin + Vector2(12, h - 18), Vector2(w - 24, 8))
	canvas.draw_rect(bar, Color(0.2, 0.2, 0.18, 1.0))
	var fill := bar
	fill.size.x *= clampf(craft_progress(), 0.0, 1.0)
	canvas.draw_rect(fill, Color("e8a838"))


func _refresh_label() -> void:
	if label == null:
		return
	var face_parts: PackedStringArray = []
	for row in face_slots:
		if row is Dictionary:
			var sid := String(row.get("sku_id", ""))
			face_parts.append("%s×%d" % [Tuning.sku_name(sid), int(row.get("count", 0))])
	var pan_parts: PackedStringArray = []
	for id_v in pantry.keys():
		var id := String(id_v)
		var n := int(pantry[id_v])
		if n <= 0:
			continue
		pan_parts.append("%s×%d" % [Tuning.sku_name(id), n])
	if face_parts.is_empty() and pan_parts.is_empty():
		label.text = Loc.t("furniture.cooked_stall")
		return
	var face_txt := " · ".join(face_parts) if not face_parts.is_empty() else "—"
	if pan_parts.is_empty():
		label.text = face_txt
	else:
		label.text = Loc.t("ui.cooked.stall_label", [face_txt, " · ".join(pan_parts)])
