extends "res://scripts/shadow_clone.gd"
## Mobile purple clone that delivers one stocked need to every elite guest in range.

const GameState = preload("res://scripts/game_state.gd")

const RANGE_CELLS := 3.0
const RANGE_PX := RANGE_CELLS * GameState.CELL
const RING_COLOR := Color("9d5b8b")
const TARGET_SCAN_SEC := 0.25
const DURATION := 30.0

var owner_seat: int = 0
var level: int = 3
var kind := "elite_guest_specialist"
var _pulse_left: float = 0.0
var _target_scan_left: float = 0.0
var _target: Node2D
var _range_ring: Line2D


func setup_specialist(game: Node, at: Vector2, snap: Dictionary, seat: int, new_level: int) -> void:
	super.setup(game, at, snap)
	owner_seat = seat
	level = clampi(new_level, 1, 3)
	temp_left = DURATION
	role = "elite_specialist"
	is_shadow_clone = false
	## Keep collision against walls only; this unit never blocks characters.
	collision_layer = 0
	collision_mask = Tuning.LAYER_WALLS
	if is_instance_valid(_sprite):
		_sprite.modulate = Color(0.72, 0.38, 0.94, ShadowCloneCast.ALPHA)
	_sync_label()
	_create_range_ring()


func is_shadow_clone_unit() -> bool:
	## This specialist is immune to the dash / toss interruption rules for regular clones.
	return false


func dash_knock() -> void:
	pass


func apply_toss_hit() -> void:
	pass


func _sync_label() -> void:
	if is_instance_valid(_label):
		_label.text = Loc.t("world.clone.elite_specialist")


func _create_range_ring() -> void:
	_range_ring = Line2D.new()
	_range_ring.name = "EliteSpecialistRange"
	_range_ring.z_index = -7
	_range_ring.width = 3.0
	_range_ring.closed = true
	_range_ring.antialiased = true
	_range_ring.default_color = Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, 0.9)
	for i in 64:
		var angle := TAU * float(i) / 64.0
		_range_ring.add_point(Vector2(cos(angle), sin(angle)) * RANGE_PX)
	add_child(_range_ring)


func interval() -> float:
	match level:
		1:
			return 3.0
		2:
			return 2.0
		_:
			return 0.5


func _physics_process(delta: float) -> void:
	if _vanishing or net_puppet or not is_instance_valid(_game):
		return
	var phase := String(_game.get("phase"))
	if phase in ["closed", "prep"]:
		vanish()
		return
	temp_left = maxf(0.0, temp_left - delta)
	if temp_left <= 0.0:
		vanish()
		return
	if _game.has_method("asking_early_close") and bool(_game.call("asking_early_close")):
		velocity = Vector2.ZERO
		_sync_visual("idle", _facing)
		return

	_pulse_left = maxf(0.0, _pulse_left - delta)
	_target_scan_left -= delta
	if _target_scan_left <= 0.0 or not _is_serviceable(_target):
		_target_scan_left = TARGET_SCAN_SEC
		_target = _nearest_serviceable_guest()
	var target_reached := false
	if is_instance_valid(_target):
		target_reached = _follow(_target.global_position, delta)
	else:
		velocity = Vector2.ZERO
	if target_reached and _pulse_left <= 0.00001:
		var delivered := _pulse_range()
		if delivered > 0:
			_pulse_left = interval()
	if velocity.length() <= 8.0:
		_sync_visual("idle", _facing)


func _is_serviceable(guest: Node) -> bool:
	return _sku_if_available(guest) != ""


func _sku_if_available(guest: Node) -> String:
	if not is_instance_valid(guest):
		return ""
	if not guest.has_method("can_receive_delivery"):
		return ""
	if guest.get("is_elite") != true or guest.get("temp_clerk") == true:
		return ""
	if not bool(guest.call("can_receive_delivery")):
		return ""
	var shopping = guest.get("shopping")
	var game_state = _game.get("state") if is_instance_valid(_game) else null
	if not (shopping is Array) or game_state == null:
		return ""
	var stock = game_state.get("stock")
	if not (stock is Dictionary):
		return ""
	for raw_sku in shopping:
		var sku := String(raw_sku)
		if sku == "":
			continue
		var wanted := 0
		for requested in shopping:
			if String(requested) == sku:
				wanted += 1
		var reserved := 0
		if _game.has_method("elite_guest_cannon_reserved_count"):
			reserved = int(_game.call("elite_guest_cannon_reserved_count", guest, sku))
		if wanted <= reserved or int(stock.get(sku, 0)) <= 0:
			continue
		return sku
	return ""


func _nearest_serviceable_guest() -> Node2D:
	if not is_instance_valid(_game):
		return null
	var customers = _game.get("_customers")
	if not is_instance_valid(customers):
		return null
	var best: Node2D
	var best_distance := INF
	for candidate in customers.get_children():
		if not candidate is Node2D or _sku_if_available(candidate) == "":
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance or (
			is_equal_approx(distance, best_distance)
			and (best == null or candidate.get_instance_id() < best.get_instance_id())
		):
			best = candidate
			best_distance = distance
	return best


func _pulse_range() -> int:
	if not is_instance_valid(_game):
		return 0
	var customers = _game.get("_customers")
	if not is_instance_valid(customers):
		return 0
	var candidates: Array[Dictionary] = []
	var range_sq := RANGE_PX * RANGE_PX
	for guest in customers.get_children():
		if not guest is Node2D:
			continue
		var node := guest as Node2D
		var distance := global_position.distance_squared_to(node.global_position)
		if distance > range_sq:
			continue
		var sku := _sku_if_available(node)
		if sku == "":
			continue
		candidates.append({"guest": node, "sku": sku, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := float(a["distance"])
		var db := float(b["distance"])
		if not is_equal_approx(da, db):
			return da < db
		return int(a["guest"].get_instance_id()) < int(b["guest"].get_instance_id())
	)
	var delivered := 0
	for row in candidates:
		var guest: Node2D = row["guest"]
		if not is_instance_valid(guest):
			continue
		var sku := _sku_if_available(guest)
		if sku == "":
			continue
		if bool(_game.call("deliver_elite_guest_specialist_item", guest, sku, owner_seat)):
			delivered += 1
	return delivered
