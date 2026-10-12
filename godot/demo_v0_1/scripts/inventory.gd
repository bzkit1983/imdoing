extends RefCounted
## FILO carry queue stored one item at a time. HUD groups consecutive SKUs.

const Tuning = preload("res://scripts/tuning.gd")

var items: Array[String] = []


func count() -> int:
	return items.size()


func is_empty() -> bool:
	return items.is_empty()


func can_take_box() -> bool:
	return Tuning.CARRY_CAP - items.size() >= Tuning.BOX_SIZE


func space() -> int:
	return Tuning.CARRY_CAP - items.size()


func take_box(sku: String) -> void:
	var i := 0
	while i < Tuning.BOX_SIZE:
		items.append(sku)
		i += 1


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
	items.resize(items.size() - n)


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
