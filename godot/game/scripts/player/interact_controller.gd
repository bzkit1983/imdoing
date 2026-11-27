extends RefCounted
## Short interact, deliver, pickup, and cooked-stall deposit extracted from player.gd (#175).
## Host-bound: call bind(player) from Player._ready. State stays on the player host.

const Tuning = preload("res://scripts/tuning.gd")
const OpsItems = preload("res://scripts/ops_items.gd")

var host: CharacterBody2D = null


func bind(player: CharacterBody2D) -> void:
	host = player


func preview_target() -> Node2D:
	var turret: Node2D = host._usable_turret()
	if turret != null:
		return turret
	var thief: Node2D = host._nearest_active_thief()
	if thief != null:
		return thief
	var stocked: Node2D = host._nearest_stocked_shelf()
	if stocked != null:
		return stocked
	var restock: Node2D = host._nearest_kind("restock")
	if restock != null:
		return restock
	var tank: Node2D = host._nearest_kind("fish_tank")
	if tank != null:
		return tank
	var cooked: Node2D = host._nearest_kind("cooked_stall")
	if cooked != null and (host._cooked_stall_craftable(cooked) or host._cooked_deposit_sku() != ""):
		return cooked
	var ops: Node2D = host._nearest_kind("ops_item")
	if ops != null:
		return ops
	var drop: Node2D = host._nearest_kind("drop")
	if drop != null:
		return drop
	match host._long_kind():
		"dirt":
			return host._nearest_kind("dirt")
		"guest":
			var guests: Array = host._faced_guests()
			return guests[0] if not guests.is_empty() else null
		"shelf":
			return host._nearest_kind("shelf")
		"cashier":
			return host._nearest_kind("cashier")
		"self_cashier":
			return host._nearest_repairable_self_cashier()
		"fish_tank":
			return host._nearest_kind("fish_tank")
		"cooked_stall":
			return host._nearest_kind("cooked_stall")
	var sco: Node2D = host._nearest_repairable_self_cashier()
	if sco != null:
		return sco
	var portal: Node2D = host._nearest_usable_portal()
	if portal != null:
		return portal
	return null

func release_interact() -> void:
	if is_instance_valid(host._lock_node) and host._obj_str(host._lock_node, "kind") in ["shelf_cannon", "kind_cannon"]:
		host._interact_release_held()
	if host._restock_aborted:
		host._restock_aborted = false
		host._restock_picking = false
		host._restock_hold = 0.0
		return
	if host._cooked_aborted:
		host._cooked_aborted = false
		host._cooked_picking = false
		host._cooked_hold = 0.0
		return
	if host._fighting or host._long_committed or host._deliver_done or host._shelve_done or host._restock_picking or host._cooked_picking:
		if host._restock_picking and host.target != null and host._obj_str(host.target, "kind") in ["restock", "fish_tank"]:
			if host._world_authority():
				var sku: String = String(host.target.call("commit_pick"))
				SfxBus.play("sfx_box_sku_confirm")
				var set_key: String = (
					"log.player.fish_set"
					if host._obj_str(host.target, "kind") == "fish_tank"
					else "log.player.restock_set"
				)
				host.log_line.emit(Loc.t(set_key, [Tuning.sku_name(sku)]))
			else:
				## Client: close local pick chrome; Host commits via restock_commit intent.
				host.pending_restock_commit = true
				host.target.picking = false
				SfxBus.play("sfx_box_sku_confirm")
		elif host._cooked_picking and host.target != null and host._obj_str(host.target, "kind") == "cooked_stall":
			host._commit_cooked_craft()
		host._restock_picking = false
		host._restock_hold = 0.0
		host._cooked_picking = false
		host._cooked_hold = 0.0
		return
	do_short_interact()
	host._restock_picking = false
	host._restock_hold = 0.0
	host._cooked_picking = false
	host._cooked_hold = 0.0


## Tap: thief (already grabbed), else one piece off a stocked shelf, else a restock box, else ops item / floor box.

func do_short_interact() -> void:
	var turret: Node2D = host._usable_turret()
	if turret != null:
		if host._interact_try(turret):
			if host._obj_str(turret, "kind") == "universal_cannon" and not turret.retrieve_to(host):
				host.log_line.emit(Loc.t("cannon.take_failed"))
			host._interact_release(turret)
		return
	if host._nearest_active_thief() != null:
		return
	var shelf: Node2D = host._nearest_stocked_shelf()
	if shelf != null:
		host._take_shelf_piece(shelf)
		return
	var restock: Node2D = host._nearest_kind("restock")
	if restock != null:
		host.target = restock
		host._pickup_used = false
		try_pickup()
		return
	var tank: Node2D = host._nearest_kind("fish_tank")
	if tank != null:
		host.target = tank
		host._pickup_used = false
		try_pickup()
		return
	var stall: Node2D = host._nearest_kind("cooked_stall")
	if stall != null and host._cooked_deposit_sku() != "":
		deposit_to_cooked_stall(stall)
		return
	var ops: Node2D = host._nearest_kind("ops_item")
	if ops != null:
		host.target = ops
		host._pickup_used = false
		host._tick_ops_item()
		return
	var drop: Node2D = host._nearest_kind("drop")
	if drop != null:
		host.target = drop
		host._pickup_used = false
		host._tick_drop()
		return
	if is_instance_valid(host._self_repair_reg):
		host._try_self_cashier_repair_hit()
		return
	var broken_sco: Node2D = host._nearest_repairable_self_cashier()
	if broken_sco != null:
		host._try_self_cashier_repair_begin(broken_sco)
		return
	var portal: Node2D = host._nearest_usable_portal()
	if portal != null:
		host._try_portal_teleport(portal)
		return
	if host._store_open() and not host.inventory.is_empty() and not host._faced_guests().is_empty():
		host.log_line.emit(Loc.t("log.player.hold_deliver_hint"))

func give_guest(guest: Node) -> int:
	if guest == null or not guest.has_method("accept_toss_box"):
		return 0
	var before: int = 0
	if guest.get("shopping") != null:
		before = int((guest.shopping as Array).size())
	var given: int = 0
	var seen: Dictionary = {}
	var wants: Array[String] = []
	for s in guest.shopping:
		var sku: String = String(s)
		if seen.has(sku):
			continue
		seen[sku] = true
		wants.append(sku)
	for sku in wants:
		if guest.has_method("can_receive_delivery") and not bool(guest.call("can_receive_delivery")):
			break
		var need: int = 0
		for s in guest.shopping:
			if String(s) == sku:
				need += 1
		var n: int = mini(need, host.inventory.count_of(sku))
		if n <= 0:
			continue
		var taken: int = int(guest.call("accept_toss_box", sku, n))
		if taken > 0:
			host.inventory.remove_sku(sku, taken)
			given += taken
	## Perfect deliver: cleared remaining list in this burst (any count ≥1).
	if given > 0 and before >= 1 and guest.shopping.is_empty():
		guest.set_meta("combo_cleared_n", before)
	return given

func hand_deliver(guests: Array, penalize_miss: bool) -> int:
	## §8.2: Client chrome only — Host applies delivery via interact intent.
	if not host._world_authority():
		return 0
	var total: int = 0
	var nearest: Node = null
	var locked: Array = []
	var boss_rejected: bool = false
	for guest in guests:
		if guest == null or not is_instance_valid(guest):
			continue
		if not guest.has_method("can_receive_delivery") or not bool(guest.call("can_receive_delivery")):
			continue
		## A7 L — hand delivery target.
		if not host._interact_try(guest):
			continue
		locked.append(guest)
		if nearest == null:
			nearest = guest
		## Boss 序4／序5 hand rules (all-at-once / toss-only).
		if guest.get("is_boss") == true:
			var game_b: Node = host._game()
			if game_b != null and game_b.has_method("boss_hand_deliver"):
				var r: Dictionary = game_b.call("boss_hand_deliver", host, guest)
				if bool(r.get("handled", false)):
					var g: int = int(r.get("given", 0))
					total += g
					if g <= 0:
						boss_rejected = true
					continue
		total += give_guest(guest)
	if total > 0:
		SfxBus.play("sfx_box_hit_guest_ok")
		host.log_line.emit(Loc.t("log.player.deliver_n", [total]))
		host._deliver_pose_left = 0.4
		host._note_delivery_combo(guests, total)
		for g in locked:
			host._interact_release(g)
		return total
	if boss_rejected:
		var game_r: Node = host._game()
		if game_r != null:
			game_r.combo_break_personal(host.seat_id)
		for g in locked:
			host._interact_release(g)
		return 0
	if penalize_miss and nearest != null and nearest.has_method("apply_toss_reject"):
		nearest.call("apply_toss_reject", "")
		SfxBus.play("sfx_box_hit_guest_reject")
		if nearest.get("temp_clerk"):
			host.log_line.emit(Loc.t("log.player.wrong_temp"))
		else:
			host.log_line.emit(Loc.t("log.player.wrong_dissat"))
	var game: Node = host._game()
	if game != null:
		game.combo_break_personal(host.seat_id)
	for g in locked:
		host._interact_release(g)
	return 0


func interact_available(node: Node2D) -> bool:
	var kind: String = host._obj_str(node, "kind")
	if kind in ["universal_cannon", "shelf_cannon", "kind_cannon"]:
		return node.available_for(host)
	if kind == "thief":
		## Carry allowed; goods stay in hand during the fight.
		return node.has_method("is_active_thief") and bool(node.call("is_active_thief"))
	if kind == "shelf":
		return host._shelf_interactable(node)
	if kind == "restock":
		return host._restock_interactable(node)
	if kind == "fish_tank":
		return true
	if kind == "cooked_stall":
		return host._cooked_stall_interactable(node)
	if kind == "drop":
		var n: int = host._obj_int(node, "count")
		return n > 0 and host.inventory.count() + n <= host.carry_cap()
	if kind == "ops_item":
		return OpsItems.first_empty_slot(host.ops_bag) >= 0 and String(node.get("item_id")) != ""
	if kind == "dirt":
		## Carry allowed; goods stay in hand while cleaning.
		return true
	if kind == "cashier":
		return node.has_method("ready_customer") and node.call("ready_customer") != null
	if kind == "self_cashier":
		if node.has_method("can_repair") and bool(node.call("can_repair")):
			return true
		return bool(node.get("_repairing")) and int(node.get("_repair_seat")) == host.seat_id
	if kind == "portal":
		return host._portal_interactable(node)
	if kind == "elite" or kind == "":
		if not host._store_open() or host.inventory.is_empty():
			return false
		if not node.has_method("can_receive_delivery"):
			return false
		return bool(node.call("can_receive_delivery"))
	return false

func deposit_to_cooked_stall(stall: Node2D) -> void:
	if stall == null or not is_instance_valid(stall) or bool(stall.get("crafting")):
		return
	var id: String = host._cooked_deposit_sku()
	if id == "":
		return
	if not host._world_authority():
		SfxBus.play("sfx_box_pull")
		return
	if not stall.has_method("add_ingredient") or not stall.has_method("can_accept_ingredient"):
		return
	if not bool(stall.call("can_accept_ingredient", id, 1)):
		SfxBus.play("sfx_box_pull_fail")
		host.log_line.emit(Loc.t("log.player.cooked_pantry_full"))
		return
	var room: int = 1
	if stall.get("pantry_capacity") != null and stall.has_method("pantry_total"):
		room = maxi(0, int(stall.get("pantry_capacity")) - int(stall.call("pantry_total")))
	var want: int = mini(host._manual_pickup_limit(), mini(host.inventory.count_of(id), room))
	if want <= 0:
		SfxBus.play("sfx_box_pull_fail")
		host.log_line.emit(Loc.t("log.player.cooked_pantry_full"))
		return
	var taken: int = int(stall.call("add_ingredient", id, want))
	if taken <= 0:
		SfxBus.play("sfx_box_pull_fail")
		host.log_line.emit(Loc.t("log.player.cooked_pantry_full"))
		return
	host.inventory.remove_sku(id, taken)
	host._spawn_fx("spray", stall.global_position + Vector2(0, -20))
	SfxBus.play("sfx_shelf_stock_done")
	host.log_line.emit(Loc.t("log.player.cooked_deposit", [Tuning.sku_name(id), taken]))

func try_pickup() -> void:
	if host._pickup_used:
		return
	host._pickup_used = true
	var room: int = maxi(0, host.carry_cap() - host.inventory.count())
	if room <= 0:
		SfxBus.play("sfx_box_pull_fail")
		host.log_line.emit(Loc.t("log.player.carry_need", [host.inventory.count(), host.carry_cap()]))
		return
	## §8.2: Client must not declare warehouse consume — Host owns stock.
	if not host._world_authority():
		SfxBus.play("sfx_box_pull")
		return
	var sku: String = String(host.target.call("selected_sku"))
	var requested: int = mini(host._manual_pickup_limit(), room)
	var taken: int = int(host.target.call("take_pieces", requested))
	if taken <= 0:
		SfxBus.play("sfx_box_pull_fail")
		var empty_key: String = (
			"log.player.fish_empty"
			if host._obj_str(host.target, "kind") == "fish_tank"
			else "log.player.restock_empty"
		)
		host.log_line.emit(Loc.t(empty_key, [Tuning.sku_name(sku)]))
		return
	host.inventory.take_pieces(sku, taken)
	host._spawn_fx("suck", host.target.global_position)
	SfxBus.play("sfx_box_pull")
	var pull_key: String = (
		"log.player.fish_pull"
		if host._obj_str(host.target, "kind") == "fish_tank"
		else "log.player.pull_instant"
	)
	host.log_line.emit(Loc.t(pull_key, [Tuning.sku_name(sku), taken]))
