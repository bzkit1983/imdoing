extends RefCounted
## Dark Side / shadow clone / restock-hold helpers peeled out of demo.gd (tech-review L1).

const DarkSide = preload("res://scripts/dark_side.gd")
const ShadowCloneCast = preload("res://scripts/shadow_clone_cast.gd")
const ShadowCloneScript = preload("res://scripts/shadow_clone.gd")

var host: Node


func bind(day_host: Node) -> void:
	host = day_host

func cast_dark_side(level: int, seat: int = -1) -> void:
	if SessionService.is_networked() and SessionService.is_client():
		return
	if host._customers == null:
		return
	var caster := host._seat_actor(seat) if seat >= 0 else host._player
	var need := DarkSide.draft_count(level)
	var locked = _checkout_locked_guest()
	var pool: Array = []
	for c in host._customers.get_children():
		if DarkSide.eligible(c, locked):
			pool.append(c)
	pool.shuffle()
	var drafted: Array = []
	for i in mini(need, pool.size()):
		drafted.append(pool[i])
	var rolls: Array = []
	for c in drafted:
		if DarkSide.roll_cashier():
			rolls.append(c)
	var empties: Array = DarkSide.open_registers(
		host.cashiers,
		_hired_cashier_registers(),
		_temp_cashier_registers(),
		_caster_pos(caster),
		_player_lock_register(),
	)
	var jobs: Dictionary = DarkSide.plan(drafted, rolls, empties)
	for c in drafted:
		var row: Dictionary = jobs[c]
		var reg = row.get("register", null)
		c.call("begin_temp_clerk", String(row.get("role", "restock")), reg)
	if caster != null and caster.has_signal("log_line"):
		caster.log_line.emit(Loc.t("log.demo.dark_side", [drafted.size()]))

func cast_shadow_clone(level: int, seat: int = -1) -> void:
	if SessionService.is_networked() and SessionService.is_client():
		return
	dismiss_shadow_clones()
	var caster := host._seat_actor(seat) if seat >= 0 else host._player
	var need := ShadowCloneCast.clone_count(level)
	var snap := {}
	if caster != null and caster.has_method("clone_snapshot"):
		snap = caster.call("clone_snapshot")
	var facing := Vector2.RIGHT
	if caster != null:
		facing = Vector2(caster.get("facing"))
	var origin := _caster_pos(caster)
	var spots: Array = ShadowCloneCast.spawn_positions(
		origin, facing, need, host._obstacles, _clone_spawn_people_for(caster)
	)
	var drafted: Array = []
	for i in need:
		var clone: CharacterBody2D = ShadowCloneScript.new()
		if host._world != null:
			host._world.add_child(clone)
		else:
			host.add_child(clone)
		var at: Vector2 = spots[i] if i < spots.size() else origin
		clone.setup(host, at, snap)
		drafted.append(clone)
	var rolls: Array = []
	for c in drafted:
		if DarkSide.roll_cashier():
			rolls.append(c)
	var empties: Array = DarkSide.open_registers(
		host.cashiers,
		_hired_cashier_registers(),
		_temp_cashier_registers(),
		origin,
		_player_lock_register(),
	)
	var jobs: Dictionary = DarkSide.plan(drafted, rolls, empties)
	for c in drafted:
		var row: Dictionary = jobs[c]
		var role := String(row.get("role", "restock"))
		c.call("begin_job", role, row.get("register", null))
		var skin := String(c.get("_model_id")) if c.get("_model_id") != null else "player"
		host._register_net_agent(c, "shadow_clone", {
			"role": role,
			"skin_id": skin,
		})
	if caster != null and caster.has_signal("log_line"):
		caster.log_line.emit(Loc.t("log.demo.shadow_clone", [drafted.size()]))

func dismiss_shadow_clones() -> void:
	for c in shadow_clones():
		if c != null and is_instance_valid(c) and c.has_method("vanish"):
			c.call("vanish")

func dismiss_elite_guest_specialists() -> void:
	if host._world == null:
		return
	for child in host._world.get_children():
		if str(child.get("kind")) == "elite_guest_specialist" and child.has_method("vanish"):
			child.call("vanish")

func shadow_clones() -> Array:
	var out: Array = []
	if host._world == null:
		return out
	for c in host._world.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.has_method("is_shadow_clone_unit") or not bool(c.call("is_shadow_clone_unit")):
			continue
		## Truthiness: Object.get missing → null; bool(null) crashes in Godot 4.
		if c.get("_vanishing"):
			continue
		out.append(c)
	return out

func _clone_spawn_people() -> Array:
	return _clone_spawn_people_for(host._player)

func _clone_spawn_people_for(caster: Node2D) -> Array:
	var people: Array = []
	if caster != null and is_instance_valid(caster):
		people.append(caster.global_position)
	for p in host._players:
		if p == null or not is_instance_valid(p) or p == caster:
			continue
		people.append(p.global_position)
	if host._world != null:
		for c in host._world.get_children():
			if c == null or not is_instance_valid(c):
				continue
			if c is CharacterBody2D:
				people.append(c.global_position)
	if host._customers != null:
		for c in host._customers.get_children():
			if c == null or not is_instance_valid(c):
				continue
			people.append(c.global_position)
	return people

func restock_holds(except: Node) -> Dictionary:
	var sku := {}
	var shelf := {}
	if host._world != null:
		for c in host._world.get_children():
			if c == null or c == except or not is_instance_valid(c):
				continue
			## str() — String(null) throws in Godot 4.7 and aborts the whole scan,
			## so hired clerks never finish _find_job.
			if str(c.get("role")) != "restock":
				continue
			_note_restock_hold(sku, shelf, c.get("_plan_sku"), c.get("_box_sku"), c.get("_shelf"))
	if host._customers != null:
		for c in host._customers.get_children():
			if c == null or c == except or not is_instance_valid(c):
				continue
			if not c.get("temp_clerk") or str(c.get("temp_role")) != "restock":
				continue
			_note_restock_hold(sku, shelf, c.get("_temp_plan_sku"), c.get("_temp_box_sku"), c.get("_temp_shelf"))
	return {"sku": sku, "shelf": shelf}

func _note_restock_hold(sku: Dictionary, shelf: Dictionary, planned, carried, target) -> void:
	var plan_s := str(planned) if planned != null else ""
	if plan_s != "":
		sku[plan_s] = true
	var carry_s := str(carried) if carried != null else ""
	if carry_s != "":
		sku[carry_s] = true
	if target != null:
		shelf[target] = true

func _hired_cashier_registers() -> Array:
	var out: Array = []
	if host._world == null:
		return out
	for c in host._world.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if str(c.get("role")) != "cashier":
			continue
		var reg = c.get("register")
		if reg != null:
			out.append(reg)
	return out

func _temp_cashier_registers() -> Array:
	var out: Array = []
	if host._customers == null:
		return out
	for c in host._customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.get("temp_clerk") or str(c.get("temp_role")) != "cashier":
			continue
		var reg = c.get("temp_register")
		if reg != null:
			out.append(reg)
	return out

func _dark_side_player_pos() -> Vector2:
	return _caster_pos(host._player)

func _caster_pos(caster: Node2D) -> Vector2:
	if caster == null or not is_instance_valid(caster):
		return Vector2(1.0e8, 1.0e8)
	return caster.global_position

func _player_lock_register():
	## Any seat holding a cashier under command_lock (A4).
	for p in host._players:
		if p == null or not is_instance_valid(p):
			continue
		if not p.get("command_lock"):
			continue
		var target = p.get("target")
		if target != null and str(target.get("kind")) == "cashier":
			return target
	return null

func _checkout_locked_guest():
	var reg = _player_lock_register()
	if reg == null or not reg.has_method("ready_customer"):
		return null
	return reg.call("ready_customer")

