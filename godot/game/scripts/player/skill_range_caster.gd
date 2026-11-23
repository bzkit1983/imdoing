extends RefCounted
## Must-deliver + magneto aim/cast (skill_caster L2).

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")

var host: CharacterBody2D = null
var orc: RefCounted = null


func bind(player: CharacterBody2D, orchestrator: RefCounted) -> void:
	host = player
	orc = orchestrator


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
	var lv: int = host._must_deliver_lv
	var sid: String = host._must_deliver_sid
	var skill_name: String = host._must_deliver_name
	var cd_base: float = host._must_deliver_cd
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
	host.log_line.emit(Loc.t("log.player.cast", [skill_name, lv]))
	orc.begin_cast_pose(false)
	host.skill_cast.emit(skill_name, false)
	orc.play_zoom(false)


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
	if orc._net_client_predicting():
		host.log_line.emit(Loc.t("log.player.must_n", [plan.size()]))
		host._deliver_pose_left = 0.4
		return true
	var total := 0
	var vfx: Array = []
	var touched: Array = []
	for entry in plan:
		var guest: Node = entry["guest"]
		var pieces: Array = entry["pieces"]
		if guest == null or not is_instance_valid(guest) or not guest.has_method("accept_must_deliver"):
			continue
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
	var lv: int = host._magneto_lv
	var sid: String = host._magneto_sid
	var skill_name: String = host._magneto_name
	var cd_base: float = host._magneto_cd
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
	host._cd[sid] = Tuning.cd_seconds(cd_base, host._int_now())
	host._buffs.erase(sid)
	host._buff_cache_valid = false
	SfxBus.play("sfx_skill_cast")
	host.log_line.emit(Loc.t("log.player.cast", [skill_name, lv]))
	orc.begin_cast_pose(false)
	host.skill_cast.emit(skill_name, false)
	orc.play_zoom(false)


func cast_magneto(lv: int) -> void:
	if orc._net_client_predicting():
		var game_p = host._game()
		if game_p != null:
			game_p.play_skill_banner(Loc.t("log.player.magneto_n", [0]))
		host.log_line.emit(Loc.t("log.player.magneto_n", [0]))
		return
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
	if game != null:
		game.play_skill_banner(Loc.t("log.player.magneto_n", [taken_total]))
	host.log_line.emit(Loc.t("log.player.magneto_n", [taken_total]))


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
		if i >= 48:
			break


func try_cast_slot(sk: Dictionary, _sid: String) -> bool:
	if bool(sk.get("magneto", false)):
		if host._magneto_aim:
			finish_magneto_aim()
			return true
		begin_magneto_aim(sk)
		return true
	if bool(sk.get("must_deliver", false)):
		if host._must_deliver_aim:
			finish_must_deliver_aim()
			return true
		if host._magneto_aim:
			cancel_magneto_aim()
		begin_must_deliver_aim(sk)
		return true
	return false