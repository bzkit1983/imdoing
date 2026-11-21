extends RefCounted
## Skill deploy / cannon world effects peeled out of demo.gd (tech-review L1).

const ShadowCloneCast = preload("res://scripts/shadow_clone_cast.gd")

var host: Node


func bind(day_host: Node) -> void:
	host = day_host

func deploy_universal_cannon(at: Vector2, level: int, seat: int) -> Node2D:
	if host._world == null or host.phase not in ["open", "restock"]:
		return null
	if SessionService.is_networked() and SessionService.is_client():
		return null
	# Defensive ownership gate in addition to the player's runtime reference.
	for child in host._world.get_children():
		if str(child.get("kind")) == "universal_cannon" and child.owner_seat == seat and not child.dismissed:
			return child
	var cannon: Node2D = preload("res://scripts/universal_cannon.gd").new()
	cannon.host = host
	cannon.level = clampi(level, 1, 3)
	cannon.owner_seat = seat
	host._world.add_child(cannon)
	cannon.global_position = at
	for player in host._players:
		if not player.interactables.has(cannon):
			player.interactables.append(cannon)
	host._register_net_agent(cannon, "universal_cannon", {
		"owner_seat": seat,
		"level": cannon.level,
		"ammo_n": 0,
		"sku": "",
	})
	return cannon

func deploy_shelf_cannon(at: Vector2, level: int, seat: int) -> Node2D:
	if host._world == null or host.phase not in ["open", "restock"]:
		return null
	if SessionService.is_networked() and SessionService.is_client():
		return null
	for child in host._world.get_children():
		if str(child.get("kind")) == "shelf_cannon" and child.owner_seat == seat and not child.dismissed:
			return child
	var cannon: Node2D = preload("res://scripts/shelf_cannon.gd").new()
	cannon.host = host
	cannon.level = clampi(level, 1, 3)
	cannon.owner_seat = seat
	host._world.add_child(cannon)
	cannon.global_position = at
	for player in host._players:
		if not player.interactables.has(cannon):
			player.interactables.append(cannon)
	host._register_net_agent(cannon, "shelf_cannon", {
		"owner_seat": seat,
		"level": cannon.level,
		"ammo_n": 0,
		"sku": "",
	})
	return cannon

func deploy_kind_cannon(at: Vector2, level: int, seat: int) -> Node2D:
	if host._world == null or host.phase not in ["open", "restock"]:
		return null
	if SessionService.is_networked() and SessionService.is_client():
		return null
	for child in host._world.get_children():
		if str(child.get("kind")) == "kind_cannon" and child.owner_seat == seat and not child.dismissed:
			return child
	var cannon: Node2D = preload("res://scripts/kind_cannon.gd").new()
	cannon.host = host
	cannon.level = clampi(level, 1, 3)
	cannon.owner_seat = seat
	host._world.add_child(cannon)
	cannon.global_position = at
	for player in host._players:
		if player != null and is_instance_valid(player) and not player.interactables.has(cannon):
			player.interactables.append(cannon)
	host._register_net_agent(cannon, "kind_cannon", {
		"owner_seat": seat,
		"level": cannon.level,
		"ammo_n": 0,
	})
	return cannon

func deploy_elite_guest_cannon(at: Vector2, level: int, seat: int) -> Node2D:
	if host._world == null or host.phase not in ["open", "restock"]:
		return null
	if SessionService.is_networked() and SessionService.is_client():
		return null
	for child in host._world.get_children():
		if str(child.get("kind")) != "elite_guest_cannon" or int(child.get("owner_seat")) != seat:
			continue
		if child.get("dismissed") == true:
			continue
		child.refresh_level(level)
		return child
	var cannon: Node2D = preload("res://scripts/elite_guest_cannon.gd").new()
	cannon.host = host
	cannon.level = clampi(level, 1, 3)
	cannon.owner_seat = seat
	host._world.add_child(cannon)
	cannon.global_position = at
	host._register_net_agent(cannon, "elite_guest_cannon", {
		"owner_seat": seat,
		"level": cannon.level,
		"remaining": 30.0,
	})
	return cannon

func deploy_elite_guest_specialist(at: Vector2, level: int, seat: int) -> Node2D:
	if host._world == null or host.phase != "open":
		return null
	if SessionService.is_networked() and SessionService.is_client():
		return null
	for child in host._world.get_children():
		if str(child.get("kind")) != "elite_guest_specialist" or int(child.get("owner_seat")) != seat:
			continue
		if not bool(child.get("_vanishing")):
			return null
	var caster: Node2D = host._seat_actor(seat)
	if caster == null or not caster.has_method("clone_snapshot"):
		return null
	var snap: Dictionary = caster.call("clone_snapshot")
	var facing := Vector2(caster.get("facing"))
	var spots: Array[Vector2] = ShadowCloneCast.spawn_positions(
		at, facing, 1, host._obstacles, host._clone_spawn_people_for(caster)
	)
	var spawn_at := spots[0] if not spots.is_empty() else at
	var specialist = preload("res://scripts/elite_guest_specialist.gd").new()
	host._world.add_child(specialist)
	specialist.setup_specialist(host, spawn_at, snap, seat, clampi(level, 1, 3))
	host._register_net_agent(specialist, "elite_guest_specialist", {
		"owner_seat": seat,
		"level": specialist.level,
		"skin_id": String(snap.get("skin_id", "player")),
	})
	return specialist

func deliver_elite_guest_specialist_item(guest: Node, sku: String, seat: int) -> bool:
	if SessionService.is_networked() and SessionService.is_client():
		return false
	if (
		guest == null
		or not is_instance_valid(guest)
		or not guest.has_method("can_receive_delivery")
		or guest.get("is_elite") != true
		or guest.get("temp_clerk") == true
		or not bool(guest.call("can_receive_delivery"))
		or not guest.has_method("accept_toss_box")
		or sku == ""
	):
		return false
	var guest_2d := guest as Node2D
	if (
		guest_2d == null
		or host._guest_wants_sku(guest_2d, sku) <= elite_guest_cannon_reserved_count(guest, sku)
	):
		return false
	if int(host.state.stock.get(sku, 0)) <= 0 or not bool(host.state.consume_stock(sku, 1)):
		return false
	if int(guest.call("accept_toss_box", sku, 1)) != 1:
		host.state.credit_unsold_pieces({sku: 1})
		host.sync_stock()
		return false
	host.sync_stock()
	host.note_deliver(seat, "specialist", 1, false)
	return true

func elite_guest_cannon_reserved_count(guest: Node, sku: String) -> int:
	if guest == null or not is_instance_valid(guest) or sku == "":
		return 0
	var by_sku = host._elite_guest_cannon_reservations.get(guest.get_instance_id(), {})
	return int(by_sku.get(sku, 0)) if by_sku is Dictionary else 0

func reserve_elite_guest_cannon_need(guest: Node, sku: String) -> bool:
	if (
		guest == null
		or not is_instance_valid(guest)
		or sku == ""
		or guest.get("is_elite") != true
		or guest.get("temp_clerk") == true
		or not guest.has_method("can_receive_delivery")
		or not bool(guest.call("can_receive_delivery"))
	):
		return false
	var shopping = guest.get("shopping")
	if not (shopping is Array):
		return false
	var needed := 0
	for requested in shopping:
		if String(requested) == sku:
			needed += 1
	if needed <= elite_guest_cannon_reserved_count(guest, sku):
		return false
	var target_id := guest.get_instance_id()
	var by_sku: Dictionary = host._elite_guest_cannon_reservations.get(target_id, {})
	by_sku[sku] = int(by_sku.get(sku, 0)) + 1
	host._elite_guest_cannon_reservations[target_id] = by_sku
	return true

func release_elite_guest_cannon_need(target_id: int, sku: String) -> void:
	if target_id <= 0 or not host._elite_guest_cannon_reservations.has(target_id):
		return
	var by_sku: Dictionary = host._elite_guest_cannon_reservations[target_id]
	var left := int(by_sku.get(sku, 0)) - 1
	if left > 0:
		by_sku[sku] = left
	else:
		by_sku.erase(sku)
	if by_sku.is_empty():
		host._elite_guest_cannon_reservations.erase(target_id)
	else:
		host._elite_guest_cannon_reservations[target_id] = by_sku

func resolve_elite_guest_cannon_delivery(
	guest: Node, sku: String, seat: int, target_id: int
) -> bool:
	release_elite_guest_cannon_need(target_id, sku)
	if (
		guest == null
		or not is_instance_valid(guest)
		or guest.get("is_elite") != true
		or guest.get("temp_clerk") == true
		or not guest.has_method("can_receive_delivery")
		or not bool(guest.call("can_receive_delivery"))
		or not guest.has_method("accept_toss_box")
	):
		return false
	var accepted := int(guest.call("accept_toss_box", sku, 1))
	if accepted != 1:
		return false
	host.note_deliver(seat, "cannon", 1, false)
	return true

func deploy_calm_zone(at: Vector2, level: int, seat: int) -> Node2D:
	if host._world == null or host.phase not in ["open", "restock"]:
		return null
	if SessionService.is_networked() and SessionService.is_client():
		return null
	var zone: Node2D = preload("res://scripts/calm_zone.gd").new()
	zone.host = host
	zone.level = clampi(level, 1, 3)
	zone.owner_seat = seat
	host._world.add_child(zone)
	zone.global_position = at
	host._register_net_agent(zone, "calm_zone", {
		"owner_seat": seat,
		"level": zone.level,
	})
	return zone

func _remove_cannon_interactable(cannon: Node2D) -> void:
	var lock = host.get_node_or_null("/root/InteractLock")
	if lock != null:
		var seat: int = lock.holder_of(cannon)
		if seat >= 0:
			lock.release(cannon, seat)
	for player in host._players:
		player.interactables.erase(cannon)
		if player.target == cannon:
			player._reset_hold()
			player.target = null

func dismiss_universal_cannons() -> void:
	if host._world == null:
		return
	for child in host._world.get_children():
		if str(child.get("kind")) == "universal_cannon":
			child.dismiss()

func dismiss_shelf_cannons() -> void:
	if host._world == null:
		return
	for child in host._world.get_children():
		if str(child.get("kind")) == "shelf_cannon":
			child.dismiss()

func dismiss_kind_cannons() -> void:
	if host._world == null:
		return
	for child in host._world.get_children():
		if str(child.get("kind")) == "kind_cannon":
			child.dismiss()

func dismiss_elite_guest_cannons() -> void:
	if host._world == null:
		return
	for child in host._world.get_children():
		if str(child.get("kind")) == "elite_guest_cannon":
			child.dismiss()

func _resolve_net_kind_conversion(thief: Node) -> void:
	if thief == null or not is_instance_valid(thief) or not thief.has_method("apply_kind_cannon_conversion"):
		return
	if not bool(thief.call("apply_kind_cannon_conversion")):
		return
	host._thieves.erase(thief)
	host._guest_n += 1
	host._recount_active_thieves()
	for player in host._players:
		if player == null or not is_instance_valid(player):
			continue
		player.interactables.erase(thief)
		if player.target == thief:
			if player._fighting:
				player._end_fight(true)
			else:
				player._reset_hold()
			player.target = null
	host.bump_hud()

func convert_thief_to_guest(thief: Node2D, seat: int) -> bool:
	if SessionService.is_networked() and SessionService.is_client():
		return false
	if not is_instance_valid(thief) or not thief.has_method("is_active_thief") or not thief.is_active_thief():
		return false
	if not thief.has_method("apply_kind_cannon_conversion") or not bool(thief.call("apply_kind_cannon_conversion")):
		return false
	host._thieves.erase(thief)
	host._guest_n += 1
	host._recount_active_thieves()
	host._seat_bump(host.seat_kind_converted, seat, 1)
	host.kind_converted_total += 1
	for player in host._players:
		if player == null or not is_instance_valid(player):
			continue
		player.interactables.erase(thief)
		if player.target == thief:
			if player._fighting:
				player._end_fight(true)
			else:
				player._reset_hold()
			player.target = null
	host.bump_hud()
	if thief.net_agent_id >= 0 and SessionService.is_networked() and SessionService.is_server():
		SessionService.broadcast_agent_state({"id": thief.net_agent_id, "kind_converted": true})
	return true

func cannon_hit_thief(thief: Node2D, seat: int, direction: Vector2) -> void:
	if not is_instance_valid(thief) or not thief.is_active_thief():
		return
	# Resolve host.state immediately so concurrent projectiles cannot count the KO twice.
	thief.ko_box_hit_and_flee(direction)
	host.record_caught(seat)
	SfxBus.play("sfx_box_hit_thief")
	host.play_ko_banner()
	for player in host._players:
		if player.target == thief and player._fighting:
			player._end_fight(true)

