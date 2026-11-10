extends RefCounted

const Tuning = preload("res://scripts/tuning.gd")

signal changed

var items: Array[String] = []
## Bumps on every mutation — HUD / box_stack dirty without rebuilding every frame.
var revision: int = 0


func count() -> int:
	return items.size()


func is_empty() -> bool:
	return items.is_empty()


func can_take_pieces(n: int = 1, cap: int = Tuning.carry_items_from_str()) -> bool:
	return n > 0 and cap - items.size() >= n


func can_take_box(cap: int = Tuning.carry_items_from_str()) -> bool:
	## Legacy name: one free piece slot (player restock is 1 piece).
	return can_take_pieces(1, cap)


func take_pieces(sku: String, n: int) -> void:
	var i := 0
	while i < n:
		items.append(sku)
		i += 1
	if n > 0:
		_bump()


func take_box(sku: String) -> void:
	## Legacy name: take one piece.
	take_pieces(sku, 1)


func add_one(sku: String) -> void:
	items.append(sku)
	_bump()


func count_of(sku: String) -> int:
	var n := 0
	for id in items:
		if id == sku:
			n += 1
	return n


## Remove up to `n` of `sku`, from the top of the stack first. Returns how many left the hand.
func remove_sku(sku: String, n: int) -> int:
	if n <= 0 or sku == "":
		return 0
	var taken := 0
	var i := items.size() - 1
	while i >= 0 and taken < n:
		if items[i] == sku:
			items.remove_at(i)
			taken += 1
		i -= 1
	if taken > 0:
		_bump()
	return taken


func trailing_run() -> Dictionary:
	if items.is_empty():
		return {"id": "", "count": 0}
	var id := items[items.size() - 1]
	var n := 0
	var i := items.size() - 1
	while i >= 0 and items[i] == id:
		n += 1
		i -= 1
	return {"id": id, "count": n}


func remove_trailing(n: int) -> void:
	n = mini(n, items.size())
	if n <= 0:
		return
	items.resize(items.size() - n)
	_bump()


## Top-of-stack first (same order as remove_trailing). Returns the removed pieces.
func pop_trailing(n: int) -> Array[String]:
	n = mini(n, items.size())
	var out: Array[String] = []
	if n <= 0:
		return out
	var start := items.size() - n
	for i in range(start, items.size()):
		out.append(items[i])
	items.resize(start)
	_bump()
	return out


func clear() -> void:
	if items.is_empty():
		return
	items.clear()
	_bump()


## Client presentation: Host absolute piece order (M2.6). No-op if equal.
func apply_net_items(next: Array) -> bool:
	var n := next.size()
	if n == items.size():
		var same := true
		for i in n:
			if String(items[i]) != String(next[i]):
				same = false
				break
		if same:
			return false
	items.clear()
	for v in next:
		var sku := String(v)
		if sku != "":
			items.append(sku)
	_bump()
	return true


func grouped() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for id in items:
		if groups.size() and String(groups[groups.size() - 1]["id"]) == id:
			groups[groups.size() - 1]["count"] = int(groups[groups.size() - 1]["count"]) + 1
		else:
			groups.append({"id": id, "count": 1})
	return groups


func boxes() -> Array[Dictionary]:
	## Visual layers only: chunk contiguous same-SKU runs into BOX_SIZE pieces.
	var out: Array[Dictionary] = []
	var i := 0
	while i < items.size():
		var id := items[i]
		var n := 0
		while i < items.size() and items[i] == id and n < Tuning.BOX_SIZE:
			n += 1
			i += 1
		out.append({"id": id, "count": n})
	return out


func _bump() -> void:
	revision += 1
	changed.emit()
