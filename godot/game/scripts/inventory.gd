extends RefCounted

const Tuning = preload("res://scripts/tuning.gd")

signal changed

## Merged slots in recent-touch order (last = most recently touched).
## Each entry: {"id": String, "count": int}
var slots: Array[Dictionary] = []
## Index into slots for shelve / toss / cannon load. -1 when empty.
var focus_index: int = -1
## Expanded piece list (slot order) for legacy iterators / net payloads.
var items: Array[String] = []
## Bumps on every mutation — HUD / box_stack dirty without rebuilding every frame.
var revision: int = 0


func count() -> int:
	return items.size()


func is_empty() -> bool:
	return slots.is_empty()


func can_take_pieces(n: int = 1, cap: int = Tuning.carry_items_from_str()) -> bool:
	return n > 0 and cap - items.size() >= n


func can_take_box(cap: int = Tuning.carry_items_from_str()) -> bool:
	## Legacy name: one free piece slot (player restock is 1 piece).
	return can_take_pieces(1, cap)


func focused_sku() -> String:
	if focus_index < 0 or focus_index >= slots.size():
		return ""
	return String(slots[focus_index].get("id", ""))


func focused_count() -> int:
	if focus_index < 0 or focus_index >= slots.size():
		return 0
	return int(slots[focus_index].get("count", 0))


func focused_run() -> Dictionary:
	return {"id": focused_sku(), "count": focused_count()}


## Alias used by older shelve/toss paths — now the focused SKU, not LIFO trailing.
func trailing_run() -> Dictionary:
	return focused_run()


func cycle_focus(delta: int) -> void:
	if slots.is_empty():
		focus_index = -1
		return
	var n := slots.size()
	if focus_index < 0:
		focus_index = n - 1
	focus_index = posmod(focus_index + delta, n)
	_bump()


func set_focus_index(idx: int) -> void:
	if slots.is_empty():
		focus_index = -1
		_bump()
		return
	var next := clampi(idx, 0, slots.size() - 1)
	if next == focus_index:
		return
	focus_index = next
	_bump()


func touch_sku(sku: String, n: int = 1) -> void:
	if sku == "" or n <= 0:
		return
	var idx := _find_slot(sku)
	if idx >= 0:
		slots[idx]["count"] = int(slots[idx]["count"]) + n
		_move_slot_to_end(idx)
	else:
		slots.append({"id": sku, "count": n})
	focus_index = slots.size() - 1
	_rebuild_items()
	_bump()


func take_pieces(sku: String, n: int) -> void:
	touch_sku(sku, n)


func take_box(sku: String) -> void:
	## Legacy name: take one piece.
	touch_sku(sku, 1)


func add_one(sku: String) -> void:
	touch_sku(sku, 1)


func count_of(sku: String) -> int:
	var idx := _find_slot(sku)
	if idx < 0:
		return 0
	return int(slots[idx].get("count", 0))


## Remove up to `n` of `sku` (any slot). Touches that SKU to end if any remain.
func remove_sku(sku: String, n: int) -> int:
	if n <= 0 or sku == "":
		return 0
	var idx := _find_slot(sku)
	if idx < 0:
		return 0
	var have := int(slots[idx].get("count", 0))
	var taken := mini(n, have)
	var left := have - taken
	var old_focus := focus_index
	if left <= 0:
		_remove_slot_at(idx)
		if slots.is_empty():
			focus_index = -1
		elif old_focus == idx:
			## Removed the focused slot → move left like remove_focused.
			focus_index = clampi(idx - 1, 0, slots.size() - 1)
		elif old_focus > idx:
			focus_index = old_focus - 1
		else:
			focus_index = clampi(old_focus, 0, slots.size() - 1)
	else:
		slots[idx]["count"] = left
		_move_slot_to_end(idx)
		## Keep focus on the depleted-but-remaining SKU (now at end) only if it was focused;
		## otherwise keep prior focus index adjusted after move.
		if old_focus == idx:
			focus_index = slots.size() - 1
		elif old_focus > idx:
			focus_index = clampi(old_focus - 1, 0, slots.size() - 1)
		else:
			focus_index = clampi(old_focus, 0, slots.size() - 1)
	_rebuild_items()
	if taken > 0:
		_bump()
	return taken


func remove_focused(n: int) -> int:
	if n <= 0 or focus_index < 0 or focus_index >= slots.size():
		return 0
	var have := int(slots[focus_index].get("count", 0))
	var taken := mini(n, have)
	var left := have - taken
	if left <= 0:
		var old := focus_index
		_remove_slot_at(old)
		## Depleted → focus moves left (previous index).
		if slots.is_empty():
			focus_index = -1
		else:
			focus_index = clampi(old - 1, 0, slots.size() - 1)
	else:
		slots[focus_index]["count"] = left
	_rebuild_items()
	_bump()
	return taken


func remove_trailing(n: int) -> void:
	remove_focused(n)


## Focused SKU first. Returns removed piece ids.
func pop_trailing(n: int) -> Array[String]:
	var out: Array[String] = []
	var sku := focused_sku()
	var taken := remove_focused(n)
	for _i in taken:
		out.append(sku)
	return out


func clear() -> void:
	if slots.is_empty() and items.is_empty():
		return
	slots.clear()
	items.clear()
	focus_index = -1
	_bump()


## Client presentation: Host absolute pieces + optional focus (M2.6).
## `next` may be Array of sku strings (expanded) or Array of {id,count} slots.
func apply_net_items(next: Array, focus: Variant = null) -> bool:
	var next_slots: Array[Dictionary] = _slots_from_net(next)
	var next_focus := _resolve_net_focus(next_slots, focus)
	if _slots_equal(slots, next_slots) and focus_index == next_focus:
		return false
	slots = next_slots
	focus_index = next_focus
	_rebuild_items()
	_bump()
	return true


func grouped() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for s in slots:
		groups.append({"id": String(s.get("id", "")), "count": int(s.get("count", 0))})
	return groups


func boxes() -> Array[Dictionary]:
	## Visual layers: chunk each merged slot into BOX_SIZE pieces (focus = last layer of focused slot).
	var out: Array[Dictionary] = []
	for s in slots:
		var id := String(s.get("id", ""))
		var left := int(s.get("count", 0))
		while left > 0:
			var n := mini(left, Tuning.BOX_SIZE)
			out.append({"id": id, "count": n})
			left -= n
	return out


func net_payload_items() -> Array:
	return items.duplicate()


func _find_slot(sku: String) -> int:
	for i in slots.size():
		if String(slots[i].get("id", "")) == sku:
			return i
	return -1


func _move_slot_to_end(idx: int) -> void:
	if idx < 0 or idx >= slots.size():
		return
	if idx == slots.size() - 1:
		return
	var entry: Dictionary = slots[idx]
	slots.remove_at(idx)
	slots.append(entry)


func _remove_slot_at(idx: int) -> void:
	if idx < 0 or idx >= slots.size():
		return
	slots.remove_at(idx)


func _rebuild_items() -> void:
	items.clear()
	for s in slots:
		var id := String(s.get("id", ""))
		var n := int(s.get("count", 0))
		for _i in n:
			items.append(id)


func _slots_from_net(next: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if next.is_empty():
		return out
	## Slot dictionaries from host.
	if next[0] is Dictionary:
		for v in next:
			if not (v is Dictionary):
				continue
			var id := String(v.get("id", ""))
			var n := int(v.get("count", 0))
			if id == "" or n <= 0:
				continue
			out.append({"id": id, "count": n})
		return out
	## Expanded piece list — merge identical runs in order (unique SKUs kept separate only if non-contiguous; we merge all same SKU into first-seen then re-touch order by last occurrence).
	## Prefer: rebuild by scanning and merging into recent-touch via last append order.
	var order: Array[String] = []
	var counts: Dictionary = {}
	for v in next:
		var sku := String(v)
		if sku == "":
			continue
		if not counts.has(sku):
			order.append(sku)
			counts[sku] = 0
		counts[sku] = int(counts[sku]) + 1
		## Recent-touch: move to end of order.
		var oi := order.find(sku)
		if oi >= 0 and oi != order.size() - 1:
			order.remove_at(oi)
			order.append(sku)
	for sku in order:
		out.append({"id": sku, "count": int(counts[sku])})
	return out


func _resolve_net_focus(next_slots: Array[Dictionary], focus: Variant) -> int:
	if next_slots.is_empty():
		return -1
	if focus == null:
		return next_slots.size() - 1
	if typeof(focus) == TYPE_INT or typeof(focus) == TYPE_FLOAT:
		return clampi(int(focus), 0, next_slots.size() - 1)
	var sku := String(focus)
	if sku == "":
		return next_slots.size() - 1
	for i in next_slots.size():
		if String(next_slots[i].get("id", "")) == sku:
			return i
	return next_slots.size() - 1


func _slots_equal(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if String(a[i].get("id", "")) != String(b[i].get("id", "")):
			return false
		if int(a[i].get("count", 0)) != int(b[i].get("count", 0)):
			return false
	return true


func _bump() -> void:
	revision += 1
	changed.emit()
