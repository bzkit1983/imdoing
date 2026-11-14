extends RefCounted
## Skill cast / aim / VFX controller extracted from player.gd (Tech Review F2).
## Host-bound: call bind(player) from Player._ready. State stays on the player host.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const FloatTextScript = preload("res://scripts/ui/float_text.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")

var host: CharacterBody2D = null


func bind(player: CharacterBody2D) -> void:
	host = player

func setup_must_deliver_ring() -> void:
	host._must_deliver_ring = Line2D.new()
	host._must_deliver_ring.name = "MustDeliverRing"
	host._must_deliver_ring.width = 2.0
	host._must_deliver_ring.default_color = Color(0.35, 0.9, 1.0, 0.55)
	host._must_deliver_ring.visible = false
	host._must_deliver_ring.z_index = 5
	host.add_child(host._must_deliver_ring)

func setup_magneto_ring() -> void:
	host._magneto_ring = Line2D.new()
	host._magneto_ring.name = "MagnetoRing"
	host._magneto_ring.width = 2.0
	host._magneto_ring.default_color = Color(0.75, 0.45, 1.0, 0.55)
	host._magneto_ring.visible = false
	host._magneto_ring.z_index = 5
	host.add_child(host._magneto_ring)

func begin_must_deliver_aim(sk: Dictionary) -> void:
	host._must_deliver_aim = true
	host._must_deliver_lv = int(sk.get("lv", 3))
	host._must_deliver_sid = String(sk.get("id"))
	host._must_deliver_cd = float(sk.get("cd", Skills.ACTIVE_CD))
	host._must_deliver_name = String(sk.get("name"))
	rebuild_must_deliver_ring(Skills.must_deliver_range(host._must_deliver_lv))
	if host._must_deliver_ring:
		host._must_deliver_ring.visible = true
	SfxBus.play("sfx_skill_cast")
	host.log_line.emit(Loc.t("log.player.aim_preview", [host._must_deliver_name]))

func cancel_must_deliver_aim() -> void:
	if not host._must_deliver_aim:
		return
	host._must_deliver_aim = false
	if host._must_deliver_ring:
		host._must_deliver_ring.visible = false
	SfxBus.play("sfx_skill_menu_cancel")
	host.log_line.emit(Loc.t("log.player.cancel_named", [host._must_deliver_name]))

func rebuild_must_deliver_ring(radius: float) -> void:
	if host._must_deliver_ring == null:
		return
	var pts := PackedVector2Array()
	var n := 48
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	host._must_deliver_ring.points = pts

func finish_must_deliver_aim() -> void:
	if not host._must_deliver_aim:
		return
	var lv = host._must_deliver_lv
	var sid = host._must_deliver_sid
	var name = host._must_deliver_name
	var cd_base = host._must_deliver_cd
	if not cast_must_deliver(lv):
		host._must_deliver_aim = false
		if host._must_deliver_ring:
			host._must_deliver_ring.visible = false
		return
	host._must_deliver_aim = false
	if host._must_deliver_ring:
		host._must_deliver_ring.visible = false
	host._cd[sid] = Tuning.cd_seconds(cd_base, host._int_now())
	host._buffs.erase(sid)
	host._buff_cache_valid = false
	SfxBus.play("sfx_skill_cast")
	host.log_line.emit(Loc.t("log.player.cast", [name, lv]))
	begin_cast_pose(false)
	host.skill_cast.emit(name, false)
	play_zoom(false)


## Complete-first fill for guests in range. False = fail (no CD).

## Complete-first fill for guests in range. False = fail (no CD).
func cast_must_deliver(lv: int) -> bool:
	if host.inventory.is_empty():
		host.log_line.emit(Loc.t("log.player.must_fail_empty"))
		return false
	if not host._store_open():
		host.log_line.emit(Loc.t("log.player.must_fail_guest"))
		return false
	var radius := Skills.must_deliver_range(lv)
	var max_n := Skills.must_deliver_max_guests(lv)
	var guests := must_deliver_guests(radius)
	if guests.is_empty():
		host.log_line.emit(Loc.t("log.player.must_fail_guest"))
		return false
	var ordered = must_deliver_order_guests(guests, host.inventory.items)
	var counts = must_deliver_count_map(host.inventory.items)
	var plan: Array = []
	for g in ordered:
		if plan.size() >= max_n:
			break
		var pieces := must_deliver_match_pieces(g.shopping, counts)
		if pieces.is_empty():
			continue
		plan.append({"guest": g, "pieces": pieces})
	if plan.is_empty():
		host.log_line.emit(Loc.t("log.player.must_fail_match"))
		return false
	var total := 0
	var vfx: Array = []
	var touched: Array = []
	for entry in plan:
		var guest: Node = entry["guest"]
		var pieces: Array = entry["pieces"]
		if guest == null or not is_instance_valid(guest) or not guest.has_method("accept_must_deliver"):
			continue
		## D3 L — skill delivery host.target.
		if not host._interact_try(guest):
			continue
		touched.append(guest)
		var before := int((guest.shopping as Array).size()) if guest.get("shopping") != null else 0
		for sku in pieces:
			host.inventory.remove_sku(String(sku), 1)
		var taken := int(guest.call("accept_must_deliver", pieces))
		if taken <= 0:
			for sku in pieces:
				host.inventory.add_one(String(sku))
			continue
		total += taken
		if before >= 1 and guest.shopping.is_empty():
			guest.set_meta("combo_cleared_n", before)
		var shown: Array = []
		for j in taken:
			shown.append(String(pieces[j]))
		vfx.append({"pos": guest.global_position, "skus": shown})
	for g in touched:
		host._interact_release(g)
	if total <= 0:
		host.log_line.emit(Loc.t("log.player.must_fail_match"))
		return false
	play_must_deliver_vfx(vfx)
	host.log_line.emit(Loc.t("log.player.must_n", [total]))
	host._deliver_pose_left = 0.4
	host._note_delivery_combo(touched, total)
	return true

func must_deliver_guests(radius: float) -> Array:
	var found: Array = []
	var g = host._game()
	if g == null:
		return found
	var custs = g.get("_customers")
	if custs == null:
		return found
	var r2 := radius * radius
	for c in custs.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if c.get("temp_clerk"):
			continue
		if not c.has_method("can_receive_delivery") or not bool(c.call("can_receive_delivery")):
			continue
		if host.global_position.distance_squared_to(c.global_position) > r2:
			continue
		found.append(c)
	found.sort_custom(func(a, b) -> bool:
		return host.global_position.distance_squared_to(a.global_position) < host.global_position.distance_squared_to(b.global_position)
	)
	return found

func must_deliver_count_map(items: Array) -> Dictionary:
	var counts := {}
	for s in items:
		var sku := String(s)
		counts[sku] = int(counts.get(sku, 0)) + 1
	return counts

func must_deliver_can_complete(shopping: Array, sim: Dictionary) -> bool:
	if shopping.is_empty():
		return false
	var need := {}
	for s in shopping:
		var sku := String(s)
		need[sku] = int(need.get(sku, 0)) + 1
	for sku in need:
		if int(sim.get(sku, 0)) < int(need[sku]):
			return false
	return true

func must_deliver_deduct_shopping(shopping: Array, sim: Dictionary) -> void:
	for s in shopping:
		var sku := String(s)
		sim[sku] = int(sim.get(sku, 0)) - 1


## Completable guests first (near→far with host.inventory reservation), then partials near→far.

## Completable guests first (near→far with host.inventory reservation), then partials near→far.
func must_deliver_order_guests(guests: Array, inv_items: Array) -> Array:
	var sim := must_deliver_count_map(inv_items)
	var completable: Array = []
	var rest: Array = []
	for g in guests:
		var shopping: Array = g.shopping if g != null else []
		if must_deliver_can_complete(shopping, sim):
			must_deliver_deduct_shopping(shopping, sim)
			completable.append(g)
		else:
			rest.append(g)
	return completable + rest


## Match shopping needs against counts (mutates counts). Any host.inventory order.

## Match shopping needs against counts (mutates counts). Any host.inventory order.
func must_deliver_match_pieces(shopping: Array, counts: Dictionary) -> Array[String]:
	var pieces: Array[String] = []
	for s in shopping:
		var sku := String(s)
		if int(counts.get(sku, 0)) <= 0:
			continue
		pieces.append(sku)
		counts[sku] = int(counts.get(sku, 0)) - 1
	return pieces

func play_must_deliver_vfx(deliveries: Array) -> void:
	if deliveries.is_empty():
		return
	var parent: Node = host.get_parent()
	var g = host._game()
	if g != null:
		var world = g.get("_world")
		if world != null:
			parent = world
	var gather: Vector2 = host.global_position + Vector2(0.0, -72.0)
	var i := 0
	for d in deliveries:
		var dest_base: Vector2 = d.get("pos", host.global_position)
		var skus: Array = d.get("skus", [])
		for sku_v in skus:
			var sku := String(sku_v)
			var spr: Sprite2D = SkuIcons.make_sprite(sku, 20.0)
			spr.z_index = 12
			parent.add_child(spr)
			spr.global_position = host.global_position + Vector2(randf_range(-10.0, 10.0), -18.0)
			var gather_pt: Vector2 = gather + Vector2(randf_range(-22.0, 22.0), randf_range(-12.0, 12.0))
			var land: Vector2 = dest_base + Vector2(randf_range(-8.0, 8.0), -44.0)
			var tw := spr.create_tween()
			tw.tween_interval(0.02 * float(i))
			tw.tween_property(spr, "global_position", gather_pt, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.1)
			tw.tween_property(spr, "global_position", land, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(spr.queue_free)
			i += 1


## Instant door summon. False = 0 guests (no CD).

## Instant door summon. False = 0 guests (no CD).
func cast_summon_guest(lv: int) -> bool:
	var want := Skills.summon_guest_count(lv)
	var game = host._game()
	if game == null or not game.has_method("cast_summon_guest"):
		host.log_line.emit(Loc.t("log.player.summon_fail"))
		return false
	var n := int(game.call("cast_summon_guest", want))
	if n <= 0:
		host.log_line.emit(Loc.t("log.player.summon_fail_phase"))
		return false
	host.log_line.emit(Loc.t("log.player.summon_n", [n]))
	return true

func begin_magneto_aim(sk: Dictionary) -> void:
	if host.inventory.count() >= host.carry_cap():
		host.log_line.emit(Loc.t("log.player.magneto_full"))
		return
	if host._must_deliver_aim:
		cancel_must_deliver_aim()
	host._magneto_aim = true
	host._magneto_lv = int(sk.get("lv", 3))
	host._magneto_sid = String(sk.get("id"))
	host._magneto_cd = float(sk.get("cd", Skills.ACTIVE_CD))
	host._magneto_name = String(sk.get("name"))
	rebuild_magneto_ring(Skills.magneto_range(host._magneto_lv))
	if host._magneto_ring:
		host._magneto_ring.visible = true
	SfxBus.play("sfx_skill_cast")
	host.log_line.emit(Loc.t("log.player.aim_preview", [host._magneto_name]))

func cancel_magneto_aim() -> void:
	if not host._magneto_aim:
		return
	host._magneto_aim = false
	if host._magneto_ring:
		host._magneto_ring.visible = false
	SfxBus.play("sfx_skill_menu_cancel")
	host.log_line.emit(Loc.t("log.player.cancel_named", [host._magneto_name]))

func rebuild_magneto_ring(radius: float) -> void:
	if host._magneto_ring == null:
		return
	var pts := PackedVector2Array()
	var n := 48
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	host._magneto_ring.points = pts

func finish_magneto_aim() -> void:
	if not host._magneto_aim:
		return
	var lv = host._magneto_lv
	var sid = host._magneto_sid
	var name = host._magneto_name
	var cd_base = host._magneto_cd
	## Full carry: abort without CD (preview shouldn't have started, but re-check).
	if host.inventory.count() >= host.carry_cap():
		host._magneto_aim = false
		if host._magneto_ring:
			host._magneto_ring.visible = false
		host.log_line.emit(Loc.t("log.player.magneto_full"))
		return
	cast_magneto(lv)
	host._magneto_aim = false
	if host._magneto_ring:
		host._magneto_ring.visible = false
	## Empty absorb still starts CD.
	host._cd[sid] = Tuning.cd_seconds(cd_base, host._int_now())
	host._buffs.erase(sid)
	host._buff_cache_valid = false
	SfxBus.play("sfx_skill_cast")
	host.log_line.emit(Loc.t("log.player.cast", [name, lv]))
	begin_cast_pose(false)
	host.skill_cast.emit(name, false)
	play_zoom(false)


## Absorb landed drops in radius until carry_cap. Always "succeeds" for CD (0 pieces ok).

## Absorb landed drops in radius until carry_cap. Always "succeeds" for CD (0 pieces ok).
func cast_magneto(lv: int) -> void:
	var range_px := Skills.magneto_range(lv)
	var range_sq := range_px * range_px
	var piles: Array = []
	for node in host.interactables:
		if node == null or not is_instance_valid(node):
			continue
		if host._obj_str(node, "kind") != "drop":
			continue
		if host._obj_int(node, "count") <= 0:
			continue
		if host.global_position.distance_squared_to(node.global_position) > range_sq:
			continue
		piles.append(node)
	piles.sort_custom(func(a, b) -> bool:
		return host.global_position.distance_squared_to(a.global_position) < host.global_position.distance_squared_to(b.global_position)
	)
	var flights: Array = []
	var locked_piles: Array = []
	for pile in piles:
		if not is_instance_valid(pile):
			continue
		var room = host.carry_cap() - host.inventory.count()
		if room <= 0:
			break
		if not pile.has_method("take_count"):
			continue
		## D4 L — magneto floor pile.
		if not host._interact_try(pile):
			continue
		locked_piles.append(pile)
		var sku = host._obj_str(pile, "sku")
		var at: Vector2 = pile.global_position
		var got := int(pile.call("take_count", room))
		if got <= 0:
			continue
		for _i in got:
			host.inventory.add_one(sku)
			flights.append({"sku": sku, "from": at})
		host._spawn_fx("suck", at)
	for pile in locked_piles:
		host._interact_release(pile)
	host._spawn_fx("suck", host.global_position)
	play_magneto_vfx(flights)
	var taken_total := flights.size()
	var game = host._game()
	if game != null and game.has_method("play_skill_banner"):
		game.call("play_skill_banner", Loc.t("log.player.magneto_n", [taken_total]))
	host.log_line.emit(Loc.t("log.player.magneto_n", [taken_total]))


## One-by-one fly from pile toward player (visual only; host.inventory already updated).

## One-by-one fly from pile toward player (visual only; host.inventory already updated).
func play_magneto_vfx(flights: Array) -> void:
	if flights.is_empty():
		return
	var parent: Node = host.get_parent()
	var g = host._game()
	if g != null:
		var world = g.get("_world")
		if world != null:
			parent = world
	var i := 0
	for f in flights:
		var sku := String(f.get("sku", ""))
		var from: Vector2 = f["from"] as Vector2 if f.has("from") else host.global_position
		var spr: Sprite2D = SkuIcons.make_sprite(sku, 18.0)
		spr.z_index = 12
		parent.add_child(spr)
		spr.global_position = from + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		## Capture landing host.target each tween start so it tracks a walking player.
		var delay := 0.035 * float(i)
		var dur := 0.22
		var tw := spr.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(spr):
				return
			var land = host.global_position + Vector2(randf_range(-10.0, 10.0), -20.0)
			var fly := spr.create_tween()
			fly.tween_property(spr, "global_position", land, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fly.tween_property(spr, "scale", Vector2(0.35, 0.35), dur * 0.85)
			fly.tween_callback(spr.queue_free)
		)
		i += 1
		## Soft cap so huge pulls stay readable.
		if i >= 48:
			break


## Instant harvest_chives on aimed cashier queue. False = fail (no CD).

## Instant harvest_chives on aimed cashier queue. False = fail (no CD).
func cast_self_checkout(level: int) -> bool:
	var game = host._game()
	var count := 0
	if game != null:
		for reg in game.get("cashiers"):
			if is_instance_valid(reg) and host.global_position.distance_squared_to(reg.global_position) <= pow(5.0 * Tuning.BODY_LENGTH, 2):
				reg.activate_self_checkout(game, level, host.seat_id)
				count += 1
	if count == 0:
		host.log_line.emit(Loc.t("self_checkout.no_register"))
	else:
		var ring_script = preload("res://scripts/self_checkout_ring.gd")
		ring_script.spawn(game, host.global_position)
	return count > 0

func cast_calm_zone(level: int) -> bool:
	var game = host._game()
	if game == null:
		return false
	if SessionService.is_networked() and SessionService.is_client():
		## Cast is predicted locally; Host creates and broadcasts the authoritative field.
		return String(game.get("phase")) in ["open", "restock"]
	if not game.has_method("deploy_calm_zone"):
		return false
	return game.call("deploy_calm_zone", host.global_position, level, host.seat_id) != null

func cast_harvest_chives(lv: int) -> bool:
	var reg: Node2D = null
	if is_instance_valid(host.target) and host._obj_str(host.target, "kind") == "cashier":
		reg = host.target
	else:
		reg = host._nearest_kind("cashier")
	if reg == null or host._interact_dist(reg) < 0.0:
		host.log_line.emit(Loc.t("log.player.chives_aim"))
		return false
	## D4 L — harvest register.
	if not host._interact_try(reg):
		host.log_line.emit(Loc.t("log.player.chives_busy"))
		return false
	var want := Skills.harvest_chives_count(lv)
	var game = host._game()
	if game == null or not game.has_method("cast_harvest_chives"):
		host._interact_release(reg)
		host.log_line.emit(Loc.t("log.player.chives_fail"))
		return false
	var n := int(game.call("cast_harvest_chives", reg, want))
	host._interact_release(reg)
	if n <= 0:
		host.log_line.emit(Loc.t("log.player.chives_empty"))
		return false
	return true


## Instant force_sell into nearest hand-deliverable guest cart. False = fail (no CD).

## Instant force_sell into nearest hand-deliverable guest cart. False = fail (no CD).
func cast_force_sell(lv: int) -> bool:
	if host.inventory.is_empty():
		host.log_line.emit(Loc.t("log.player.force_empty"))
		return false
	var guest: Node = null
	for g in host._faced_guests():
		if g == null or not is_instance_valid(g):
			continue
		if g.get("temp_clerk"):
			continue
		guest = g
		break
	if guest == null or not guest.has_method("accept_force_sell"):
		host.log_line.emit(Loc.t("log.player.force_no_guest"))
		return false
	## D3 L — force_sell guest.
	if not host._interact_try(guest):
		host.log_line.emit(Loc.t("log.player.force_busy"))
		return false
	var before := int((guest.shopping as Array).size()) if guest.get("shopping") != null else 0
	var n = mini(Skills.force_sell_count(lv), host.inventory.count())
	var pieces: Array[String] = host.inventory.pop_trailing(n)
	if pieces.is_empty():
		host._interact_release(guest)
		host.log_line.emit(Loc.t("log.player.force_empty"))
		return false
	var taken := int(guest.call("accept_force_sell", pieces))
	if taken <= 0:
		for sku in pieces:
			host.inventory.add_one(String(sku))
		host._interact_release(guest)
		host.log_line.emit(Loc.t("log.player.force_no_guest"))
		return false
	if before >= 1 and guest.shopping.is_empty():
		guest.set_meta("combo_cleared_n", before)
	host._interact_release(guest)
	host.log_line.emit(Loc.t("log.player.force_n", [taken]))
	host._deliver_pose_left = 0.4
	host._note_delivery_combo([guest], taken)
	return true


## Nearest guest first. `penalize_miss` adds +15 on the nearest guest when nothing matched.

func on_skill_hold(pressed: bool) -> void:
	if pressed:
		if host._sick_left > 0.0 or host._stun_left > 0.0 or host._fighting:
			host.log_line.emit(Loc.t("log.player.cant_skill"))
			return
		## Second skill press confirms range preview skills.
		if host._must_deliver_aim:
			finish_must_deliver_aim()
			host._skill_release_ignore = true
			return
		if host._magneto_aim:
			finish_magneto_aim()
			host._skill_release_ignore = true
			return
		if host._skill_latch:
			confirm_skill(0)
			host._skill_release_ignore = true
			return
		host._l_held = true
		host._l_time = 0.0
		host._skill_aim = 0
		return
	if host._skill_release_ignore:
		host._skill_release_ignore = false
		host._l_held = false
		return
	## Cancel already dropped the hold, or this release is not ours.
	if not host._l_held:
		return
	if host.skill_menu_open:
		if not host._skill_latch:
			sync_hold_aim()
		confirm_skill(host._skill_aim)
		return
	var short = host._l_time < Skills.HOLD_MENU_SEC
	var from_pad = host._skill_from_pad
	host._l_held = false
	host._skill_from_pad = false
	if short:
		## Remote LAN seat on Host: short release must not leave a latch menu nobody can close.
		if not host.controls_locally():
			return
		if from_pad:
			confirm_skill(0)
		else:
			open_skill_menu(true)

func open_skill_menu(latch: bool) -> void:
	host.skill_menu_open = true
	host._skill_latch = latch
	host._skill_aim = 0
	host._move_locked_until_neutral = true
	host._running = false
	host.velocity = Vector2.ZERO
	if host._menu:
		## Only the piloting machine draws the radial; Host still tracks aim for remote seats.
		host._menu.open = host.controls_locally()
		if host.controls_locally():
			host._menu.call("set_slots", host._loadout(), host._cd)
			if host._menu.has_method("set_aim"):
				host._menu.call("set_aim", 0)
	host._menu_fp = "%s|%s" % [str(host._cd), str(host._loadout())]
	## A stick already pushed for walking must not count as the tap-menu choice.
	if latch and (host.stick_axis.length() >= 0.42 or host._joy_stick_vector().length() >= 0.42):
		host._cardinal_armed = false
	if host.controls_locally():
		SfxBus.play("sfx_skill_menu_open")
		if latch:
			host.log_line.emit(Loc.t("log.player.skill_menu_tap"))
		else:
			host.log_line.emit(Loc.t("log.player.skill_menu_hold"))

func sync_hold_aim() -> void:
	set_skill_aim(skill_aim_slot())

func skill_aim_slot() -> int:
	var v = host._move_vector() + host.stick_axis
	if v.length() < 0.42:
		return 0
	var dir := Skills.DIR_DOWN if v.y > 0.0 else Skills.DIR_UP
	if absf(v.x) > absf(v.y):
		dir = Skills.DIR_RIGHT if v.x > 0.0 else Skills.DIR_LEFT
	return int(Skills.DIR_TO_SLOT.get(dir, 0))

func set_skill_aim(slot: int) -> void:
	slot = clampi(slot, 0, 4)
	if slot == host._skill_aim:
		if host._menu and host._menu.has_method("set_aim"):
			host._menu.call("set_aim", slot)
		return
	host._skill_aim = slot
	if host._menu and host._menu.has_method("set_aim"):
		host._menu.call("set_aim", slot)
	SfxBus.play("sfx_skill_menu_move")

func confirm_skill(slot: int) -> void:
	close_skill_menu()
	cast_slot(slot)
	host._move_locked_until_neutral = true
	host.velocity = Vector2.ZERO

func try_skill_hotkey(slot: int) -> void:
	if host._sick_left > 0.0 or host._stun_left > 0.0 or host._fighting:
		host.log_line.emit(Loc.t("log.player.cant_skill"))
		return
	if host.ult_prep or host._elite_focus_left > 0.0:
		return
	if host._must_deliver_aim:
		finish_must_deliver_aim()
		return
	if host._magneto_aim:
		finish_magneto_aim()
		return
	## Queue for Host sim when this seat is piloted on a LAN client.
	if host.controls_locally() and SessionService.is_networked() and SessionService.is_client():
		host.pending_skill_hotkey = clampi(slot, 0, 4)
	confirm_skill(slot)

func close_skill_menu() -> void:
	host._l_held = false
	host._l_time = 0.0
	host._skill_latch = false
	host._skill_aim = 0
	host.skill_menu_open = false
	if host._menu:
		host._menu.open = false
		if host._menu.has_method("set_aim"):
			host._menu.call("set_aim", 0)

func on_ult_hold(pressed: bool) -> void:
	if pressed:
		if host._sick_left > 0.0 or host._stun_left > 0.0 or host._fighting:
			host.log_line.emit(Loc.t("log.player.cant_ult"))
			return
		var ult = host._ult_sk()
		if ult.is_empty() or String(ult.get("id", "")) == "":
			host.log_line.emit(Loc.t("log.player.no_ult"))
			return
		if bool(ult.get("unimplemented", false)):
			host.log_line.emit(Loc.t("log.player.demo_no_cd", [String(ult.get("name"))]))
			return
		var ult_id := String(ult.get("id"))
		if host.cd_left(ult_id) > 0.05:
			SfxBus.play("sfx_skill_cd_deny")
			host.log_line.emit(Loc.t("log.player.ult_cd", [host.cd_left(ult_id)]))
			return
		host._u_held = true
		host.ult_prep = true
		host._ult_index = 0
		SfxBus.play("sfx_ult_prep")
		host._prompt.active = true
		var seq: Array[int] = []
		for d in ult.get("seq", []):
			seq.append(int(d))
		host._prompt.sequence = seq
		host._prompt.index = 0
		host._prompt.fail_at = -1
		host.log_line.emit(Loc.t("log.player.ult_prep", [String(host._ult_sk().get("name"))]))
		return
	if host.ult_prep:
		SfxBus.play("sfx_ult_cancel")
		host.log_line.emit(Loc.t("log.player.ult_cancel"))
	host._u_held = false
	host.ult_prep = false
	if not host.command_lock:
		host._prompt.active = false
		host._prompt.fail_at = -1

func try_ult_dir(dir: int) -> void:
	var seq: Array = host._ult_sk().get("seq", [])
	if seq.is_empty() or host._ult_index < 0 or host._ult_index >= seq.size():
		return
	if dir == int(seq[host._ult_index]):
		host._prompt.fail_at = -1
		host._ult_index += 1
		host._prompt.index = host._ult_index
		SfxBus.play("sfx_ult_dir_ok")
		if host._ult_index >= seq.size():
			cast_ultimate()
			host._u_held = false
			host.ult_prep = false
			host._ult_chord_active = false
	else:
		host._prompt.fail_at = host._ult_index
		host._ult_index = 0
		host._prompt.index = 0
		SfxBus.play("sfx_ult_dir_fail")
		host.log_line.emit(Loc.t("log.player.ult_cmds_fail"))

func cast_slot(i: int) -> void:
	if host._sick_left > 0.0 or host._stun_left > 0.0 or host._fighting:
		host.log_line.emit(Loc.t("log.player.cant_skill"))
		return
	var sk: Dictionary = host._skill_at(i)
	if sk.is_empty():
		return
	if bool(sk.get("unimplemented", false)):
		host.log_line.emit(Loc.t("log.player.demo_no_cd", [String(sk.get("name"))]))
		return
	if str(sk.get("kind", "")) != "active":
		host.log_line.emit(Loc.t("log.player.passive", [String(sk.get("name"))]))
		return
	var sid := String(sk.get("id"))
	if host.cd_left(sid) > 0.05:
		SfxBus.play("sfx_skill_cd_deny")
		host.log_line.emit(Loc.t("log.player.skill_cd", [String(sk.get("name")), host.cd_left(sid)]))
		return
	if bool(sk.get("universal_cannon", false)):
		if not host._round_active():
			return
		cancel_must_deliver_aim()
		cancel_magneto_aim()
		if is_instance_valid(host._cannon) and not host._cannon.dismissed:
			host._cannon.dismiss()
			host._cannon = null
			host._cd[sid] = Tuning.cd_seconds(60.0, host._int_now())
			host.log_line.emit(Loc.t("cannon.cancelled"))
		else:
			var game = host._game()
			if game == null or not game.has_method("deploy_universal_cannon"):
				return
			host._cannon = game.deploy_universal_cannon(host.global_position, int(sk.get("lv", 3)), host.seat_id)
			if host._cannon == null:
				return
			host.log_line.emit(Loc.t("cannon.deployed"))
		SfxBus.play("sfx_skill_cast")
		begin_cast_pose(false)
		host.skill_cast.emit(Loc.t("cannon.name"), false)
		return
	if bool(sk.get("shelf_cannon", false)):
		if not host._round_active():
			return
		cancel_must_deliver_aim()
		cancel_magneto_aim()
		if is_instance_valid(host._shelf_cannon) and not host._shelf_cannon.dismissed:
			host._shelf_cannon.dismiss()
			host._shelf_cannon = null
			host._cd[sid] = Tuning.cd_seconds(60.0, host._int_now())
			host.log_line.emit(Loc.t("shelf_cannon.cancelled"))
		else:
			var game = host._game()
			if game == null or not game.has_method("deploy_shelf_cannon"):
				return
			host._shelf_cannon = game.deploy_shelf_cannon(host.global_position, int(sk.get("lv", 3)), host.seat_id)
			if host._shelf_cannon == null:
				return
			host.log_line.emit(Loc.t("shelf_cannon.deployed"))
		SfxBus.play("sfx_skill_cast")
		begin_cast_pose(false)
		host.skill_cast.emit(Loc.t("skill.shelf_cannon.name"), false)
		return
	if bool(sk.get("self_checkout", false)):
		if not cast_self_checkout(int(sk.get("lv", 3))):
			return
		cancel_must_deliver_aim()
		cancel_magneto_aim()
		host._cd[sid] = Tuning.cd_seconds(30.0, host._int_now())
		SfxBus.play("sfx_skill_cast")
		begin_cast_pose(false)
		host.skill_cast.emit(Loc.t("self_checkout.active"), false)
		play_zoom(false)
		return
	if bool(sk.get("calm_zone", false)):
		cancel_must_deliver_aim()
		cancel_magneto_aim()
		if not cast_calm_zone(int(sk.get("lv", 3))):
			return
		host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", 30.0)), host._int_now())
		SfxBus.play("sfx_skill_cast")
		host.log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
		begin_cast_pose(false)
		host.skill_cast.emit(String(sk.get("name")), false)
		play_zoom(false)
		return
	## Instant force_sell: empty hands / no host.target must not start CD.
	if bool(sk.get("force_sell", false)):
		if host._must_deliver_aim:
			cancel_must_deliver_aim()
		if host._magneto_aim:
			cancel_magneto_aim()
		if not cast_force_sell(int(sk.get("lv", 3))):
			return
		host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), host._int_now())
		host._buffs.erase(sid)
		host._buff_cache_valid = false
		SfxBus.play("sfx_skill_cast")
		host.log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
		begin_cast_pose(false)
		host.skill_cast.emit(String(sk.get("name")), false)
		play_zoom(false)
		return
	## Instant harvest_chives: must aim a cashier with QUEUE/PAYING; 0 must not start CD.
	if bool(sk.get("harvest_chives", false)):
		if host._must_deliver_aim:
			cancel_must_deliver_aim()
		if host._magneto_aim:
			cancel_magneto_aim()
		if not cast_harvest_chives(int(sk.get("lv", 3))):
			return
		host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), host._int_now())
		host._buffs.erase(sid)
		host._buff_cache_valid = false
		SfxBus.play("sfx_skill_cast")
		host.log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
		begin_cast_pose(false)
		host.skill_cast.emit(String(sk.get("name")), false)
		play_zoom(false)
		return
	## Instant summon_guest: 0 spawned must not start CD.
	if bool(sk.get("summon_guest", false)):
		if host._must_deliver_aim:
			cancel_must_deliver_aim()
		if host._magneto_aim:
			cancel_magneto_aim()
		if not cast_summon_guest(int(sk.get("lv", 3))):
			return
		host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), host._int_now())
		host._buffs.erase(sid)
		host._buff_cache_valid = false
		SfxBus.play("sfx_skill_cast")
		host.log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
		begin_cast_pose(false)
		host.skill_cast.emit(String(sk.get("name")), false)
		play_zoom(false)
		return
	## 攝石人: first cast = range preview (no CD); confirm via skill press while aiming.
	if bool(sk.get("magneto", false)):
		if host._magneto_aim:
			finish_magneto_aim()
			return
		begin_magneto_aim(sk)
		return
	## 使命必達: first cast = range preview (no CD); confirm is via skill press while aiming.
	if bool(sk.get("must_deliver", false)):
		if host._must_deliver_aim:
			finish_must_deliver_aim()
			return
		if host._magneto_aim:
			cancel_magneto_aim()
		begin_must_deliver_aim(sk)
		return
	if host._must_deliver_aim:
		cancel_must_deliver_aim()
	if host._magneto_aim:
		cancel_magneto_aim()
	host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), host._int_now())
	## 衝刺交付: the armed window is the cooldown itself, and INT does not shorten this 5s.
	## Dark Side / Multiple Shadow Clone: CD still eats INT, but each body keeps its own 30s.
	## Recast must not refresh people already working (clones despawn then respawn).
	if bool(sk.get("dash_deliver", false)):
		var window := float(sk.get("cd", 5.0))
		host._cd[sid] = window
		host._buffs[sid] = window
	elif bool(sk.get("dasher", false)):
		host._buffs[sid] = Skills.dasher_seconds(int(sk.get("lv", 3)))
	elif bool(sk.get("hoop_ace", false)):
		host._buffs[sid] = Skills.hoop_ace_seconds(int(sk.get("lv", 3)))
	elif bool(sk.get("senior_cashier", false)):
		host._senior_cashier_lv = int(sk.get("lv", 3))
		host._buffs[sid] = Skills.senior_cashier_seconds(host._senior_cashier_lv)
	elif bool(sk.get("sweeping_monk", false)):
		host._buffs[sid] = Skills.sweeping_monk_seconds(int(sk.get("lv", 3)))
	elif bool(sk.get("dark_side", false)) or bool(sk.get("shadow_clone", false)):
		host._buffs.erase(sid)
	else:
		host._buffs[sid] = float(sk.get("duration", Skills.ACTIVE_DURATION))
	host._buff_cache_valid = false
	if sk.has("customer_move_pct"):
		host._enqueue_cust_speed(sid)
	if sk.has("soothe_keep"):
		var game = host._game()
		if game and game.has_method("soothe_all"):
			game.soothe_all(float(sk.get("soothe_keep")))
		SfxBus.play("sfx_skill_soothe")
	else:
		if bool(sk.get("dark_side", false)):
			var game = host._game()
			if game and game.has_method("cast_dark_side"):
				game.call("cast_dark_side", int(sk.get("lv", 3)))
		elif bool(sk.get("shadow_clone", false)):
			var clone_host = host._game()
			if clone_host and clone_host.has_method("cast_shadow_clone"):
				clone_host.call("cast_shadow_clone", int(sk.get("lv", 3)))
		elif bool(sk.get("sweeping_monk", false)):
			host._activate_sweeping_monk()
			SfxBus.play("sfx_skill_sweeping_monk")
		else:
			SfxBus.play("sfx_skill_cast")
	host.log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
	begin_cast_pose(false)
	host.skill_cast.emit(String(sk.get("name")), false)
	play_zoom(false)

func lord_seconds(lv: int) -> float:
	match lv:
		1:
			return 3.0
		2:
			return 5.0
		_:
			return 10.0

func cast_ultimate() -> void:
	var sk: Dictionary = host._ult_sk()
	if sk.is_empty() or String(sk.get("id", "")) == "":
		host.log_line.emit(Loc.t("log.player.no_ult"))
		host._prompt.active = false
		return
	if bool(sk.get("unimplemented", false)):
		host.log_line.emit(Loc.t("log.player.demo_missing", [String(sk.get("name"))]))
		host._prompt.active = false
		return
	var sid := String(sk.get("id"))
	var lv := int(sk.get("lv", 3))
	host._cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ULT_CD)), host._int_now())
	host._buff_cache_valid = false
	var game = host._game()
	if sid == "fundraise":
		if game and game.has_method("cast_fundraise"):
			game.call("cast_fundraise", lv)
		SfxBus.play("sfx_ult_fundraise")
		host.log_line.emit(Loc.t("log.player.ult_fundraise", [lv]))
		begin_cast_pose(true)
		host.skill_cast.emit(String(sk.get("name")), true)
		play_zoom(true)
		host._prompt.active = false
		return
	if sid == "close_gate":
		if game and game.has_method("cast_close_gate"):
			game.call("cast_close_gate")
		SfxBus.play("sfx_ult_close_gate")
		host.log_line.emit(Loc.t("log.player.ult_close_gate"))
		begin_cast_pose(true)
		host.skill_cast.emit(String(sk.get("name")), true)
		play_zoom(true)
		host._prompt.active = false
		return
	if sid == "three_volley":
		if game and game.has_method("cast_three_volley"):
			game.call("cast_three_volley")
		SfxBus.play("sfx_ult_yes_my_lord")
		host.log_line.emit(Loc.t("log.player.ult_three_volley"))
		begin_cast_pose(true)
		host.skill_cast.emit(String(sk.get("name")), true)
		play_zoom(true)
		host._prompt.active = false
		return
	if sid == "guest_dusk":
		var dusk_ok := false
		if game and game.has_method("cast_guest_dusk"):
			dusk_ok = bool(game.call("cast_guest_dusk"))
		if dusk_ok:
			host._buffs[sid] = Skills.GUEST_DUSK_DURATION
			host.log_line.emit(Loc.t("log.player.ult_dusk", [Skills.GUEST_DUSK_COUNT]))
		else:
			host._buffs.erase(sid)
			host.log_line.emit(Loc.t("log.player.ult_dusk_closed"))
		host._buff_cache_valid = false
		SfxBus.play("sfx_ult_guest_dusk")
		begin_cast_pose(true)
		host._spawn_fx("combo", host.global_position + Vector2(0, -36))
		host.skill_cast.emit(String(sk.get("name")), true)
		play_zoom(true)
		host._prompt.active = false
		return
	if sid == "yes_my_lord":
		host._buffs[sid] = lord_seconds(lv)
		host._buff_cache_valid = false
		SfxBus.play("sfx_ult_yes_my_lord")
		host.log_line.emit(Loc.t("log.player.ult_lord", [lv, lord_seconds(lv)]))
		begin_cast_pose(true)
		host._spawn_fx("combo", host.global_position + Vector2(0, -36))
		host.skill_cast.emit(String(sk.get("name")), true)
		play_zoom(true)
		host._prompt.active = false
		return
	host._buffs[sid] = float(sk.get("duration", Skills.ULT_DURATION))
	host._buff_cache_valid = false
	host._enqueue_cust_speed(sid)
	SfxBus.play("sfx_ult_the_world")
	host.log_line.emit(Loc.t("log.player.ult_world", [String(sk.get("name")), lv]))
	begin_cast_pose(true)
	host._spawn_fx("timestop", host.global_position + Vector2(0, -40))
	host.skill_cast.emit(String(sk.get("name")), true)
	play_zoom(true)
	host._prompt.active = false

func begin_cast_pose(ult: bool) -> void:
	host._cast_pose_left = 0.55 if ult else 0.35

func play_zoom(ult: bool) -> void:
	if not host.controls_locally():
		return
	var cam = host._shared_camera()
	if cam == null:
		return
	## Keep local ref so restore_base_camera / shake also work for seat1+.
	host.camera = cam
	var base: float = host.base_camera_zoom()
	var z: float = base * (1.28 if ult else 1.12)
	var tw = host.create_tween()
	tw.tween_property(cam, "zoom", Vector2(z, z), 0.18)
	tw.tween_interval(0.22 if ult else 0.12)
	tw.tween_callback(host.restore_base_camera)

