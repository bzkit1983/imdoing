extends Node
## Headless check for the skill-test scenario (id 4).


const StateScript = preload("res://scripts/game_state.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	var state = StateScript.new()
	state.apply_scenario(4)
	_expect(errors, int(state.scenario) == 4, "scenario id")
	_expect(errors, int(state.money) == 99999, "money %d" % int(state.money))
	_expect(errors, int(state.level) == 10, "level")
	_expect(errors, int(state.xp) == 0, "xp")
	_expect(errors, int(state.unspent) == 15, "unspent %d" % int(state.unspent))
	_expect(errors, int(state.base_str) == 10 and int(state.base_agi) == 10 and int(state.base_int) == 10, "bases")
	_expect(errors, int(state.str_stat) == 20 and int(state.agi_stat) == 20 and int(state.int_stat) == 20, "stats")
	_expect(errors, int(state.shop_scale) == 3, "scale")
	_expect(errors, int(state.grid_w) == 18 and int(state.grid_h) == 10, "grid %dx%d" % [int(state.grid_w), int(state.grid_h)])
	_expect(errors, int(state.grid_w) * int(state.grid_h) <= int(state.area_cap()), "area cap")
	_expect(errors, int(state.guest_cap()) == 10, "guest cap stays the normal 10")
	_expect(errors, float(state.spawn_every()) == 10.0, "spawn interval")

	var want := ["can", "snack", "drink", "milk"]
	var developed: Array = state.developed.keys()
	developed.sort()
	var sorted_want := want.duplicate()
	sorted_want.sort()
	_expect(errors, developed == sorted_want, "developed %s" % str(developed))
	for sku in want:
		_expect(errors, int(state.stock.get(sku, -1)) == 50, "stock %s" % sku)

	var furn: Dictionary = state.FURNITURE
	for type in furn.keys():
		_expect(errors, int(state.owned.get(type, 0)) == 2, "owned %s = %d" % [type, int(state.owned.get(type, 0))])

	_expect(errors, state.placed.size() == 10, "placed count %d" % state.placed.size())
	_expect(errors, int(state.placed_count("cashier")) == 2, "two cashiers")
	_expect(errors, int(state.placed_count("restock_dry")) == 2, "two dry restock")
	_expect(errors, int(state.placed_count("restock_frozen")) == 2, "two frozen restock")
	_expect(errors, int(state.placed_count("shelf_dry_12")) == 2, "two dry shelves")
	_expect(errors, int(state.placed_count("shelf_frozen_12")) == 2, "two frozen shelves")
	_expect(errors, int(state.unplaced("restock_ice")) == 2, "ice restock stays in storage")
	_expect(errors, state.open_blockers().is_empty(), "open blockers: %s" % str(state.open_blockers()))

	var roles := {"cashier": 0, "restock": 0}
	_expect(errors, state.clerks.size() == 2, "two clerks")
	for c in state.clerks:
		var role := String(c.get("role", ""))
		roles[role] = int(roles.get(role, 0)) + 1
		_expect(errors, int(c.get("register", -1)) == 0, "clerk register")
	_expect(errors, int(roles["cashier"]) == 1 and int(roles["restock"]) == 1, "clerk roles")
	_expect(errors, int(state.hire_limit()) == 2, "hire limit")

	var door: Array = state.door_cells()
	var cashiers_beside := 0
	var rects: Array[Rect2i] = []
	for it in state.placed:
		var rect := Rect2i(int(it["x"]), int(it["y"]), int(it["w"]), int(it["h"]))
		rects.append(rect)
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > int(state.grid_w) or rect.end.y > int(state.grid_h):
			errors.append("out of grid %s" % str(it))
		for cell_y in rect.size.y:
			for cell_x in rect.size.x:
				if Vector2i(rect.position.x + cell_x, rect.position.y + cell_y) in door:
					errors.append("covers door %s" % str(it))
		var kind := String(it["type"])
		if kind == "cashier":
			var beside := false
			for cell_y in rect.size.y:
				for cell_x in rect.size.x:
					var cell := Vector2i(rect.position.x + cell_x, rect.position.y + cell_y)
					for d in door:
						if absi(cell.x - d.x) + absi(cell.y - d.y) == 1:
							beside = true
			if beside:
				cashiers_beside += 1
			_expect(errors, int(it["y"]) == 0, "cashier on the door row")
		elif kind == "restock_frozen":
			_expect(errors, int(it["x"]) == 0, "frozen restock on the left edge")
		elif kind == "restock_dry":
			_expect(errors, int(it["x"]) + int(it["w"]) == int(state.grid_w), "dry restock on the right edge")
		elif kind == "shelf_frozen_12":
			_expect(errors, int(it["x"]) + int(it["w"]) <= int(state.grid_w) / 2, "frozen shelf on the left half")
		elif kind == "shelf_dry_12":
			_expect(errors, int(it["x"]) >= int(state.grid_w) / 2, "dry shelf on the right half")
	_expect(errors, cashiers_beside == 2, "both cashiers beside the door")
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				errors.append("overlap %s %s" % [str(rects[i]), str(rects[j])])

	var snapshot: Array = state.placed.duplicate(true)
	state.placed.clear()
	for it in snapshot:
		var err := String(state.place_item(String(it["type"]), int(it["x"]), int(it["y"]), int(it["rot"])))
		if err != "":
			errors.append("place_item %s @ %d,%d -> %s" % [it["type"], int(it["x"]), int(it["y"]), err])
	_expect(errors, state.placed.size() == snapshot.size(), "replayed layout")

	var opened := String(state.begin_day())
	_expect(errors, opened == "", "begin_day %s" % opened)
	_expect(errors, int(state.money) == 99999 - int(state.WAGE) * 2, "wage")

	state.apply_scenario(1)
	_expect(errors, int(state.level) == 1 and int(state.money) == 10000 and state.placed.is_empty(), "scenario 1 unchanged")
	state.apply_scenario(2)
	_expect(errors, int(state.level) == 5 and state.clerks.size() == 1 and state.open_blockers().is_empty(), "scenario 2 unchanged")
	state.apply_scenario(3)
	_expect(errors, int(state.str_stat) == 30 and int(state.grid_w) == 20 and int(state.guest_cap()) == 15, "scenario 3 unchanged")

	if errors.is_empty():
		print("OK skill scenario")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _expect(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
