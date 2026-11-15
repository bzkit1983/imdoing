extends Node2D
## Non-blocking mint-and-gold turret that converts active thieves into guests.
const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Shot = preload("res://scripts/kind_cannon_shot.gd")
const RADIUS := 3.0 * Tuning.BODY_LENGTH
const CAPACITY := 10

var kind := "kind_cannon"
var host: Node
var owner_seat: int = 0
var level: int = 3
var ammo: Array[String] = []
var cooldown_left: float = 0.0
var dismissed := false
var net_agent_id: int = -1
var net_puppet: bool = false
var _label: Label
var _barrel: Node2D


func is_net_puppet() -> bool:
	return net_puppet


func apply_net_pose(pos: Vector2, _facing: Vector2 = Vector2.ZERO) -> void:
	global_position = pos


func interval() -> float:
	match clampi(level, 1, 3):
		1:
			return 12.0
		2:
			return 10.0
		_:
			return 8.0


func apply_net_ammo(ammo_n: int, _next_sku: String = "") -> void:
	if not net_puppet:
		return
	ammo.resize(maxi(0, ammo_n))
	refresh()


func _broadcast_ammo_state() -> void:
	if net_agent_id < 0 or net_puppet:
		return
	if not SessionService.is_networked() or not SessionService.is_server():
		return
	SessionService.broadcast_agent_state({"id": net_agent_id, "ammo_n": ammo.size()})


func capacity() -> int:
	return CAPACITY


func _poly(parent: Node, points: Array[Vector2], color: Color) -> Polygon2D:
	var part := Polygon2D.new()
	part.polygon = PackedVector2Array(points)
	part.color = color
	parent.add_child(part)
	return part


func _ready() -> void:
	process_physics_priority = 110
	var ring := Line2D.new()
	ring.name = "KindCannonRange"
	ring.z_index = -7
	ring.width = 2.5
	ring.default_color = Color("77dfc5", 0.64)
	for i in 64:
		var angle := TAU * float(i) / 64.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * RADIUS)
	add_child(ring)
	var visual := Node2D.new()
	visual.name = "MintGoldTurret"
	visual.z_index = 1
	add_child(visual)
	_poly(visual, [Vector2(-27, 0), Vector2(-18, -11), Vector2(18, -11), Vector2(27, 0), Vector2(15, 10), Vector2(-15, 10)], Color("183c38"))
	_poly(visual, [Vector2(-23, -12), Vector2(0, -26), Vector2(23, -12), Vector2(0, 1)], Color("76d9bd"))
	_poly(visual, [Vector2(-23, -12), Vector2(0, 1), Vector2(0, 8), Vector2(-23, -5)], Color("408f80"))
	_poly(visual, [Vector2(0, 1), Vector2(23, -12), Vector2(23, -5), Vector2(0, 8)], Color("28675f"))
	_poly(visual, [Vector2(-16, -20), Vector2(-8, -29), Vector2(9, -29), Vector2(17, -20), Vector2(9, -10), Vector2(-8, -10)], Color("b78c47"))
	_poly(visual, [Vector2(-13, -22), Vector2(-7, -29), Vector2(8, -29), Vector2(14, -22), Vector2(8, -14), Vector2(-7, -14)], Color("a6edda"))
	_barrel = Node2D.new()
	_barrel.position = Vector2(0, -22)
	visual.add_child(_barrel)
	_poly(_barrel, [Vector2(-5, -2), Vector2(-5, -24), Vector2(5, -24), Vector2(6, -2), Vector2(0, 2)], Color("28675f"))
	_poly(_barrel, [Vector2(-6, -19), Vector2(6, -19), Vector2(6, -15), Vector2(-6, -15)], Color("e4c77d"))
	_poly(visual, [Vector2(-4, -5), Vector2(0, -8), Vector2(4, -5), Vector2(0, -1)], Color("fff2c6"))
	_label = Label.new()
	_label.position = Vector2(-90, 10)
	_label.size.x = 180
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.apply_label(_label, UiFont.WORLD)
	add_child(_label)
	refresh()


func refresh() -> void:
	if is_instance_valid(_label):
		_label.text = Loc.t("kind_cannon.status", [owner_seat + 1, ammo.size(), CAPACITY])


func available_for(player) -> bool:
	return not dismissed and ammo.size() < CAPACITY and not player.inventory.is_empty()


func load_from(player) -> int:
	if dismissed or net_puppet:
		return 0
	var run: Dictionary = player.inventory.trailing_run()
	var n := mini(int(run["count"]), CAPACITY - ammo.size())
	for _i in n:
		ammo.append(str(run["id"]))
	player.inventory.remove_trailing(n)
	refresh()
	_broadcast_ammo_state()
	return n


func _line_clear(target: Node2D) -> bool:
	if not is_inside_tree() or not is_instance_valid(target):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, Tuning.LAYER_WALLS)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func choose_target() -> Node2D:
	if ammo.is_empty() or not is_instance_valid(host) or not host.has_method("thieves"):
		return null
	var best: Node2D
	var best_d := INF
	for candidate in host.thieves():
		if not is_instance_valid(candidate) or not candidate.has_method("is_active_thief") or not candidate.is_active_thief():
			continue
		var d := global_position.distance_squared_to(candidate.global_position)
		if d > RADIUS * RADIUS or d > best_d or not _line_clear(candidate):
			continue
		if is_equal_approx(d, best_d) and best != null and candidate.get_instance_id() >= best.get_instance_id():
			continue
		best = candidate
		best_d = d
	return best


func _physics_process(delta: float) -> void:
	if net_puppet or dismissed or not is_instance_valid(host):
		return
	if str(host.get("phase")) not in ["open", "restock"]:
		return
	if host.has_method("asking_early_close") and host.asking_early_close():
		return
	var lock = get_node_or_null("/root/InteractLock")
	if lock != null and lock.holder_of(self) >= 0:
		cooldown_left = interval()
		return
	## The fire interval elapses even when no thief is in range. This stores no
	## shots: a target arriving after the cannon is ready is hit immediately.
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)
	var target := choose_target()
	if target == null:
		return
	if cooldown_left > 0.0:
		return
	_barrel.rotation = (target.global_position - global_position).angle() + PI / 2.0
	var sku: String = ammo.pop_front()
	var shot: Node2D = Shot.new()
	shot.host = host
	shot.target = target
	shot.owner_seat = owner_seat
	shot.setup(sku, global_position, target.global_position, Tuning.DROP_FLIGHT_SEC, 1)
	host.get("_world").add_child(shot)
	if SessionService.is_networked() and SessionService.is_server():
		SessionService.broadcast_flight({
			"sku": sku, "n": 1,
			"fx": global_position.x, "fy": global_position.y,
			"tx": target.global_position.x, "ty": target.global_position.y,
			"dur": Tuning.DROP_FLIGHT_SEC,
		})
	cooldown_left = interval()
	SfxBus.play("sfx_box_toss")
	refresh()
	_broadcast_ammo_state()


func dismiss() -> void:
	if dismissed:
		return
	dismissed = true
	for sku in ammo:
		if is_instance_valid(host):
			host.spawn_dropped_box(global_position, sku, 1)
	ammo.clear()
	if is_instance_valid(host) and host.has_method("_remove_cannon_interactable"):
		host._remove_cannon_interactable(self)
	queue_free()
