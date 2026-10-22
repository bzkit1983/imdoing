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


func can_take_box(cap: int = Tuning.carry_items_from_str()) -> bool:
	return cap - items.size() >= Tuning.BOX_SIZE


func take_box(sku: String) -> void:
	var i := 0
	while i < Tuning.BOX_SIZE:
		items.append(sku)
		i += 1
	_bump()


func add_one(sku: String) -> void:
	items.append(sku)
	_bump()


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


func clear() -> void:
	if items.is_empty():
		return
	items.clear()
	_bump()


func grouped() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for id in items:
		if groups.size() and String(groups[groups.size() - 1]["id"]) == id:
			groups[groups.size() - 1]["count"] = int(groups[groups.size() - 1]["count"]) + 1
		else:
			groups.append({"id": id, "count": 1})
	return groups


func boxes() -> Array[Dictionary]:
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
