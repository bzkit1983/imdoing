extends Node
## Headless: shelf sniper homes thrown goods to same-SKU shelves.


const PlayerScript = preload("res://scripts/player.gd")
const ShelfScript = preload("res://scripts/shelf.gd")
const Skills = preload("res://scripts/skills.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	var sk: Dictionary = Skills.by_id("shelf_sniper")
	_need(errors, not sk.is_empty(), "skill exists")
	_need(errors, int(sk.get("cost", 0)) == 2, "cost 2")
	_need(errors, is_equal_approx(float(sk.get("duration", 0.0)), 30.0), "duration 30")
	_need(errors, is_equal_approx(float(sk.get("cd", 0.0)), 10.0), "cd 10")
	_need(errors, bool(sk.get("shelf_sniper", false)), "flag")

	var host := Node.new()
	host.name = "Game"
	host.set_script(_host_script())
	add_child(host)
	host.set("_world", host)
	host.set("_shelves_by_sku", {})
	host.set("shelves", [])
	host.set("_floor_n", 0)

	var near_full: StaticBody2D = ShelfScript.new()
	near_full.sku = "can"
	near_full.count = 12
	near_full.capacity = 12
	near_full.global_position = Vector2(100, 0)
	host.add_child(near_full)

	var far_open: StaticBody2D = ShelfScript.new()
	far_open.sku = "can"
	far_open.count = 2
	far_open.capacity = 12
	far_open.global_position = Vector2(400, 0)
	host.add_child(far_open)

	var other: StaticBody2D = ShelfScript.new()
	other.sku = "snack"
	other.count = 4
	other.capacity = 12
	other.global_position = Vector2(80, 0)
	host.add_child(other)

	host.call("_index_shelf", near_full, "can")
	host.call("_index_shelf", far_open, "can")
	host.call("_index_shelf", other, "snack")

	var pick: Node2D = host.call("_sniper_shelf_for", "can", Vector2.ZERO)
	_need(errors, pick == far_open, "skips the full near shelf for an open farther one")

	far_open.count = 12
	pick = host.call("_sniper_shelf_for", "can", Vector2.ZERO)
	_need(errors, pick == near_full, "all full → nearest same-SKU shelf")

	_need(errors, host.call("_sniper_shelf_for", "milk", Vector2.ZERO) == null, "no same-SKU shelves")

	var player: CharacterBody2D = PlayerScript.new()
	add_child(player)
	await get_tree().process_frame
	_need(errors, not player.sniper_shelf_active(), "inactive before cast")
	## Cast through the public slot path with a temporary one-skill loadout.
	player.set("stats", _stats_with_sniper())
	player._cast_slot(0)
	_need(errors, player.sniper_shelf_active(), "active after cast")
	_need(errors, player.buff_left("shelf_sniper") > 29.0, "buff ~30s")
	_need(errors, player.cd_left("shelf_sniper") > 0.0, "on cooldown")

	far_open.count = 2
	host.call("_resolve_sniper_landing", far_open, far_open.stand_position(), "can", 1)
	_need(errors, int(far_open.count) == 3, "piece restocks one")

	far_open.count = 10
	host.set("_floor_n", 0)
	host.call("_resolve_sniper_landing", far_open, far_open.stand_position(), "can", 4)
	_need(errors, int(far_open.count) == 12, "box fills remaining space")
	_need(errors, int(host.get("_floor_n")) == 2, "leftover box pieces drop beside")

	near_full.count = 12
	host.set("_floor_n", 0)
	host.call("_resolve_sniper_landing", near_full, near_full.stand_position(), "can", 4)
	_need(errors, int(near_full.count) == 12, "full shelf unchanged")
	_need(errors, int(host.get("_floor_n")) == 4, "full shelf drops the whole throw")

	if errors.is_empty():
		print("OK shelf sniper")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func _stats_with_sniper() -> RefCounted:
	var st := RefCounted.new()
	st.set_script(_stats_script())
	return st


func _stats_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends RefCounted
const Skills = preload(\"res://scripts/skills.gd\")
func loadout() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(Skills.by_id(\"shelf_sniper\"))
	return out
func ult_skill() -> Dictionary:
	return {}
"""
	scr.reload()
	return scr


func _host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
var _world: Node
var _player
var shelves: Array = []
var _shelves_by_sku: Dictionary = {}
var _floor_n: int = 0
func _sniper_shelf_for(sku: String, from: Vector2) -> Node2D:
	var list = _shelves_by_sku.get(sku)
	if list == null:
		return null
	var best_open: Node2D = null
	var best_open_d := INF
	var best_any: Node2D = null
	var best_any_d := INF
	for s in list:
		if s == null or not is_instance_valid(s):
			continue
		if String(s.get(\"sku\")) != sku or int(s.get(\"count\")) <= 0:
			continue
		var d := from.distance_squared_to(s.global_position)
		if d < best_any_d:
			best_any_d = d
			best_any = s
		if s.has_method(\"can_accept\") and bool(s.call(\"can_accept\", sku)) and d < best_open_d:
			best_open_d = d
			best_open = s
	return best_open if best_open != null else best_any
func _resolve_sniper_landing(shelf: Node2D, dest: Vector2, sku: String, n: int) -> void:
	if n <= 0:
		return
	var placed := 0
	if shelf.has_method(\"can_accept\") and bool(shelf.call(\"can_accept\", sku)) and shelf.has_method(\"add_items\"):
		placed = int(shelf.call(\"add_items\", sku, n))
	var left := n - placed
	if left > 0:
		_place_dropped_box(dest, sku, left)
func _place_dropped_box(_dest: Vector2, _sku: String, n: int) -> void:
	_floor_n += n
func _index_shelf(shelf: Node2D, sku: String) -> void:
	shelves.append(shelf)
	var list: Array = _shelves_by_sku.get(sku, [])
	list.append(shelf)
	_shelves_by_sku[sku] = list
"""
	scr.reload()
	return scr
