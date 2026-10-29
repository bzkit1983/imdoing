extends Node
## Headless: guest sniper homes thrown goods to guests who still want that SKU.


const PlayerScript = preload("res://scripts/player.gd")
const Skills = preload("res://scripts/skills.gd")
const Tuning = preload("res://scripts/tuning.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	var sk: Dictionary = Skills.by_id("guest_sniper")
	_need(errors, not sk.is_empty(), "skill exists")
	_need(errors, int(sk.get("cost", 0)) == 2, "cost 2")
	_need(errors, is_equal_approx(float(sk.get("duration", 0.0)), 30.0), "duration 30")
	_need(errors, is_equal_approx(float(sk.get("cd", 0.0)), 10.0), "cd 10")
	_need(errors, bool(sk.get("guest_sniper", false)), "flag")

	var host := Node.new()
	host.name = "Game"
	host.set_script(_host_script())
	add_child(host)
	var customers := Node2D.new()
	customers.name = "Customers"
	host.add_child(customers)
	host.set("_customers", customers)
	host.set("_floor_n", 0)
	host.set("_taken", 0)

	var near_done := _guest(Vector2(80, 0), ["snack"])
	customers.add_child(near_done)
	var far_want := _guest(Vector2(400, 0), ["can", "can", "can", "can"])
	customers.add_child(far_want)
	var near_want_one := _guest(Vector2(120, 0), ["can"])
	customers.add_child(near_want_one)

	var pick: Node2D = host.call("_sniper_guest_for", "can", Vector2.ZERO)
	_need(errors, pick == near_want_one, "nearest guest who wants can")

	near_want_one.set("shopping", [])
	pick = host.call("_sniper_guest_for", "can", Vector2.ZERO)
	_need(errors, pick == far_want, "skips guest who no longer wants can")

	far_want.set("shopping", [])
	_need(errors, host.call("_sniper_guest_for", "can", Vector2.ZERO) == null, "no willing guests → null")

	var queued := _guest(Vector2(50, 0), ["can"])
	queued.set("can_recv", false)
	customers.add_child(queued)
	_need(errors, host.call("_sniper_guest_for", "can", Vector2.ZERO) == null, "queued guest is not a target")

	var player: CharacterBody2D = PlayerScript.new()
	add_child(player)
	await get_tree().process_frame
	_need(errors, not player.sniper_guest_active(), "inactive before cast")
	player.set("stats", _stats_with_guest_sniper())
	player._cast_slot(0)
	_need(errors, player.sniper_guest_active(), "active after cast")
	_need(errors, player.buff_left("guest_sniper") > 29.0, "buff ~30s")
	_need(errors, player.cd_left("guest_sniper") > 0.0, "on cooldown")

	far_want.set("shopping", ["can", "can", "can", "can"])
	host.set("_floor_n", 0)
	host.set("_taken", 0)
	host.call("_resolve_sniper_guest_landing", far_want, far_want.global_position, "can", 1)
	_need(errors, int(host.get("_taken")) == 1, "piece delivers one")
	_need(errors, int(host.get("_floor_n")) == 0, "piece has no leftover")

	host.set("_taken", 0)
	host.set("_floor_n", 0)
	far_want.set("shopping", ["can", "can"])
	host.call("_resolve_sniper_guest_landing", far_want, far_want.global_position, "can", 4)
	_need(errors, int(host.get("_taken")) == 2, "box delivers what the list wants")
	_need(errors, int(host.get("_floor_n")) == 2, "box leftover drops beside")

	host.set("_taken", 0)
	host.set("_floor_n", 0)
	far_want.set("shopping", [])
	far_want.set("can_recv", false)
	host.call("_resolve_sniper_guest_landing", far_want, far_want.global_position, "can", 4)
	_need(errors, int(host.get("_taken")) == 0, "finished guest takes nothing")
	_need(errors, int(host.get("_floor_n")) == 4, "finished guest drops the whole throw")

	if errors.is_empty():
		print("OK guest sniper")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _guest(at: Vector2, want: Array) -> Node2D:
	var g := Node2D.new()
	g.set_script(_guest_script())
	g.global_position = at
	g.set("shopping", want.duplicate())
	g.set("can_recv", true)
	g.set("is_thief", false)
	return g


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func _stats_with_guest_sniper() -> RefCounted:
	var st := RefCounted.new()
	st.set_script(_stats_script())
	return st


func _stats_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends RefCounted
const Skills = preload(\"res://scripts/skills.gd\")
func loadout() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(Skills.by_id(\"guest_sniper\"))
	return out
func ult_skill() -> Dictionary:
	return {}
"""
	scr.reload()
	return scr


func _guest_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node2D
var shopping: Array = []
var can_recv: bool = true
var is_thief: bool = false
func can_receive_delivery() -> bool:
	return can_recv and not shopping.is_empty() and not is_thief
func accept_toss_box(sku: String, n: int) -> int:
	var want := 0
	for s in shopping:
		if String(s) == sku:
			want += 1
	var take := mini(n, want)
	for _i in take:
		var idx := shopping.find(sku)
		if idx >= 0:
			shopping.remove_at(idx)
	return take
"""
	scr.reload()
	return scr


func _host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
const Tuning = preload(\"res://scripts/tuning.gd\")
var _customers: Node2D
var _player
var _floor_n: int = 0
var _taken: int = 0
func _sniper_guest_for(sku: String, from: Vector2) -> Node2D:
	if _customers == null or sku == \"\":
		return null
	var best: Node2D = null
	var best_d := INF
	for c in _customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if bool(c.get(\"is_thief\")):
			continue
		if not c.has_method(\"can_receive_delivery\") or not bool(c.call(\"can_receive_delivery\")):
			continue
		if _guest_wants_sku(c, sku) <= 0:
			continue
		var d := from.distance_squared_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best
func _guest_wants_sku(guest: Node2D, sku: String) -> int:
	var shopping = guest.get(\"shopping\")
	if not (shopping is Array):
		return 0
	var want := 0
	for s in shopping:
		if String(s) == sku:
			want += 1
	return want
func _resolve_sniper_guest_landing(guest: Node2D, dest: Vector2, sku: String, n: int) -> void:
	if n <= 0:
		return
	if not guest.has_method(\"can_receive_delivery\") or not bool(guest.call(\"can_receive_delivery\")) or _guest_wants_sku(guest, sku) <= 0:
		_place_dropped_box(dest, sku, n)
		return
	var taken := 0
	if guest.has_method(\"accept_toss_box\"):
		taken = int(guest.call(\"accept_toss_box\", sku, n))
	_taken += taken
	var left := n - taken
	if left > 0:
		_place_dropped_box(dest, sku, left)
func _place_dropped_box(_dest: Vector2, _sku: String, n: int) -> void:
	_floor_n += n
"""
	scr.reload()
	return scr
