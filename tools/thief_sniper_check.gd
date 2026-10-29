extends Node
## Headless: thief sniper homes thrown goods to the nearest active thief and KO.


const PlayerScript = preload("res://scripts/player.gd")
const Skills = preload("res://scripts/skills.gd")
const Tuning = preload("res://scripts/tuning.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	var sk: Dictionary = Skills.by_id("thief_sniper")
	_need(errors, not sk.is_empty(), "skill exists")
	_need(errors, int(sk.get("cost", 0)) == 2, "cost 2")
	_need(errors, is_equal_approx(float(sk.get("duration", 0.0)), 30.0), "duration 30")
	_need(errors, is_equal_approx(float(sk.get("cd", 0.0)), 10.0), "cd 10")
	_need(errors, bool(sk.get("thief_sniper", false)), "flag")

	var host := Node.new()
	host.name = "Game"
	host.set_script(_host_script())
	add_child(host)
	host.set("_floor_n", 0)
	host.set("_ko_n", 0)

	var far := _thief(Vector2(400, 0), true)
	host.call("register_thief", far)
	var near := _thief(Vector2(120, 0), true)
	host.call("register_thief", near)
	var fled := _thief(Vector2(40, 0), false)
	host.call("register_thief", fled)

	var pick: Node2D = host.call("_sniper_thief_for", Vector2.ZERO)
	_need(errors, pick == near, "nearest active thief")

	near.set("active", false)
	pick = host.call("_sniper_thief_for", Vector2.ZERO)
	_need(errors, pick == far, "skips inactive / fled thief")

	far.set("active", false)
	_need(errors, host.call("_sniper_thief_for", Vector2.ZERO) == null, "no active thieves → null")

	var player: CharacterBody2D = PlayerScript.new()
	add_child(player)
	await get_tree().process_frame
	host.set("_player", player)
	_need(errors, not player.sniper_thief_active(), "inactive before cast")
	player.set("stats", _stats_with_thief_sniper())
	player._cast_slot(0)
	_need(errors, player.sniper_thief_active(), "active after cast")
	_need(errors, player.buff_left("thief_sniper") > 29.0, "buff ~30s")
	_need(errors, player.cd_left("thief_sniper") > 0.0, "on cooldown")

	far.set("active", true)
	host.set("_floor_n", 0)
	host.set("_ko_n", 0)
	host.call("_resolve_sniper_thief_landing", far, far.global_position, "can", 1, Vector2.RIGHT)
	_need(errors, int(host.get("_ko_n")) == 1, "piece hits and KO")
	_need(errors, int(host.get("_floor_n")) == 1, "piece drops after hit")
	_need(errors, not bool(far.get("active")), "thief no longer active after KO")

	var box_thief := _thief(Vector2(200, 0), true)
	host.call("register_thief", box_thief)
	host.set("_floor_n", 0)
	host.set("_ko_n", 0)
	host.call("_resolve_sniper_thief_landing", box_thief, box_thief.global_position, "can", 4, Vector2.RIGHT)
	_need(errors, int(host.get("_ko_n")) == 1, "box hits once")
	_need(errors, int(host.get("_floor_n")) == 4, "whole box drops after hit")

	var gone := _thief(Vector2(300, 0), false)
	host.call("register_thief", gone)
	host.set("_floor_n", 0)
	host.set("_ko_n", 0)
	host.call("_resolve_sniper_thief_landing", gone, gone.global_position + Vector2(8, 0), "can", 4, Vector2.RIGHT)
	_need(errors, int(host.get("_ko_n")) == 0, "fled thief is not KO'd again")
	_need(errors, int(host.get("_floor_n")) == 4, "fled thief drops the whole throw")

	if errors.is_empty():
		print("OK thief sniper")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _thief(at: Vector2, active: bool) -> Node2D:
	var t := Node2D.new()
	t.set_script(_thief_script())
	t.global_position = at
	t.set("active", active)
	t.set("is_thief", true)
	return t


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func _stats_with_thief_sniper() -> RefCounted:
	var st := RefCounted.new()
	st.set_script(_stats_script())
	return st


func _stats_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends RefCounted
const Skills = preload(\"res://scripts/skills.gd\")
var str_stat: int = 10
var agi_stat: int = 10
var int_stat: int = 10
func loadout() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(Skills.by_id(\"thief_sniper\"))
	return out
func ult_skill() -> Dictionary:
	return {}
"""
	scr.reload()
	return scr


func _thief_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node2D
var active: bool = true
var is_thief: bool = true
func is_active_thief() -> bool:
	return is_thief and active
func ko_box_hit_and_flee(_dir: Vector2) -> void:
	active = false
"""
	scr.reload()
	return scr


func _host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Node
const Tuning = preload(\"res://scripts/tuning.gd\")
var _thieves: Array = []
var _player
var _floor_n: int = 0
var _ko_n: int = 0
func register_thief(t: Node2D) -> void:
	_thieves.append(t)
func thieves() -> Array:
	return _thieves
func _sniper_thief_for(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for t in thieves():
		if t == null or not is_instance_valid(t):
			continue
		if not t.has_method(\"is_active_thief\") or not bool(t.call(\"is_active_thief\")):
			continue
		var d := from.distance_squared_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best
func _resolve_sniper_thief_landing(thief: Node2D, dest: Vector2, sku: String, n: int, toss_dir: Vector2) -> void:
	if n <= 0:
		return
	if not thief.has_method(\"is_active_thief\") or not bool(thief.call(\"is_active_thief\")):
		_place_dropped_box(dest, sku, n)
		return
	_place_dropped_box(thief.global_position + Tuning.DROP_FEET_OFFSET, sku, n)
	if thief.has_method(\"ko_box_hit_and_flee\"):
		var dir := toss_dir
		if dir.length_squared() < 0.01:
			dir = Vector2.RIGHT
		thief.call(\"ko_box_hit_and_flee\", dir.normalized())
		_ko_n += 1
func _place_dropped_box(_dest: Vector2, _sku: String, n: int) -> void:
	_floor_n += n
"""
	scr.reload()
	return scr
