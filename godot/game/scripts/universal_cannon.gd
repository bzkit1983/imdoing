extends Node2D
## FIFO stock turret; intentionally no physics body, area, avoidance or navigation obstacle.
const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Shot = preload("res://scripts/cannon_shot.gd")
const RADIUS := 5.0 * Tuning.BODY_LENGTH
var kind := "universal_cannon"
var host: Node
var owner_seat: int = 0
var level: int = 3
var ammo: Array[String] = []
var elapsed: float = 0.0
var aiming: Node2D
var _label: Label
var _barrel: Node2D
var _visual: Node2D
var dismissed := false
## M2.3 LAN presentation.
var net_agent_id: int = -1
var net_puppet: bool = false


func is_net_puppet() -> bool:
	return net_puppet


func apply_net_pose(pos: Vector2, _facing: Vector2 = Vector2.ZERO) -> void:
	global_position = pos


func apply_net_ammo(ammo_n: int, next_sku: String = "") -> void:
	## Client puppet: refresh label only (ammo array not authoritative here).
	if not net_puppet:
		return
	ammo.clear()
	for _i in maxi(0, ammo_n):
		ammo.append(next_sku if next_sku != "" else "box")
	if next_sku != "" and ammo_n > 0:
		ammo[0] = next_sku
	refresh()


func _broadcast_ammo_state() -> void:
	if net_agent_id < 0 or net_puppet:
		return
	if not SessionService.is_lan() or not SessionService.is_server():
		return
	SessionService.broadcast_agent_state({
		"id": net_agent_id,
		"ammo_n": ammo.size(),
		"sku": ammo[0] if not ammo.is_empty() else "",
	})

func capacity() -> int:
	return 8 + 4 * clampi(level, 1, 3)

func interval() -> float:
	return float(6 - clampi(level, 1, 3))

func _ready() -> void:
	process_physics_priority = 110
	var ring := Line2D.new()
	ring.z_index = -7
	ring.width = 2.0
	ring.closed = true
	ring.default_color = Color(0.95, 0.65, 0.20, 0.40)
	for i in 64:
		var angle := TAU * float(i) / 64.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * RADIUS)
	add_child(ring)
	_visual = preload("res://scripts/cannon_visual.gd").new()
	add_child(_visual)
	_barrel = _visual.barrel
	_label = Label.new()
	_label.position = Vector2(-85, 10)
	_label.size.x = 170
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.apply_label(_label, UiFont.WORLD)
	add_child(_label)
	refresh()

func refresh() -> void:
	if is_instance_valid(_visual):
		_visual.set_ammo(ammo[0] if not ammo.is_empty() else "")
	if is_instance_valid(_label):
		var next := Tuning.sku_name(ammo[0]) if not ammo.is_empty() else Loc.t("cannon.empty")
		_label.text = Loc.t("cannon.status", [owner_seat + 1, ammo.size(), capacity(), next])

func available_for(player) -> bool:
	return not dismissed and ((not ammo.is_empty() and player.inventory.count() < player.carry_cap()) or (not player.inventory.is_empty() and ammo.size() < capacity()))

func load_from(player) -> int:
	if dismissed or net_puppet:
		return 0
	var run: Dictionary = player.inventory.trailing_run()
	var n := mini(int(run["count"]), capacity() - ammo.size())
	for _i in n:
		ammo.append(str(run["id"]))
	player.inventory.remove_trailing(n)
	reset_aim()
	refresh()
	_broadcast_ammo_state()
	return n

func retrieve_to(player) -> bool:
	if dismissed or net_puppet or ammo.is_empty() or player.inventory.count() >= player.carry_cap():
		return false
	player.inventory.add_one(ammo.pop_front())
	reset_aim()
	refresh()
	_broadcast_ammo_state()
	return true

func reset_aim() -> void:
	elapsed = 0.0
	aiming = null

func _nearest(candidates: Array, mode: int) -> Node2D:
	var best: Node2D
	var best_d := INF
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var good := false
		if mode == 0:
			good = candidate.has_method("is_active_thief") and candidate.is_active_thief()
		elif mode == 1:
			good = candidate.has_method("can_receive_delivery") and not candidate.get("is_thief") and not candidate.get("temp_clerk") and candidate.can_receive_delivery() and candidate.shopping.has(ammo[0])
		else:
			good = candidate.has_method("can_accept") and candidate.can_accept(ammo[0])
		if not good:
			continue
		var d: float = global_position.distance_squared_to(candidate.global_position)
		if d > RADIUS * RADIUS:
			continue
		if d < best_d or (is_equal_approx(d, best_d) and (best == null or candidate.get_instance_id() < best.get_instance_id())):
			best = candidate
			best_d = d
	return best

func choose_target() -> Node2D:
	if ammo.is_empty() or not is_instance_valid(host):
		return null
	var guests: Array = []
	var customers = host.get("_customers")
	if is_instance_valid(customers):
		guests = customers.get_children()
	var found := _nearest(guests, 0)
	if found == null:
		found = _nearest(guests, 1)
	if found == null:
		found = _nearest(host.get("shelves"), 2)
	return found

func _physics_process(delta: float) -> void:
	if net_puppet:
		return
	if dismissed or not is_instance_valid(host) or str(host.get("phase")) not in ["open", "restock"]:
		return
	if host.has_method("asking_early_close") and host.asking_early_close():
		return
	var lock = get_node_or_null("/root/InteractLock")
	if lock != null and lock.holder_of(self) >= 0:
		reset_aim()
		return
	tick_fire(delta)

func tick_fire(delta: float) -> void:
	var next := choose_target()
	if next == null:
		reset_aim()
		return
	if aiming != next:
		reset_aim()
		aiming = next
	elapsed += delta
	if _barrel != null:
		_barrel.rotation = (next.global_position - global_position).angle() + PI / 2.0
	if elapsed + 0.00001 < interval():
		return
	var sku: String = ammo.pop_front()
	var projectile: Node2D = Shot.new()
	projectile.host = host
	projectile.target = next
	projectile.owner_seat = owner_seat
	projectile.setup(sku, global_position, next.global_position, Tuning.DROP_FLIGHT_SEC, 1)
	host.get("_world").add_child(projectile)
	## M2.3: client VFX only — Host resolves hit.
	if SessionService.is_lan() and SessionService.is_server():
		SessionService.broadcast_flight({
			"sku": sku,
			"n": 1,
			"fx": global_position.x,
			"fy": global_position.y,
			"tx": next.global_position.x,
			"ty": next.global_position.y,
			"dur": Tuning.DROP_FLIGHT_SEC,
		})
	_visual.fire()
	SfxBus.play("sfx_box_toss")
	reset_aim()
	refresh()
	_broadcast_ammo_state()

func dismiss() -> void:
	if dismissed:
		return
	dismissed = true
	reset_aim()
	# Individual floor pieces preserve exact stock; normal closeout returns them.
	for sku in ammo:
		host.spawn_dropped_box(global_position, sku, 1)
	ammo.clear()
	host._remove_cannon_interactable(self)
	queue_free()
