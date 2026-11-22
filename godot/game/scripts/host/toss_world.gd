extends RefCounted
## Toss / sniper landing and drop-flight peeled out of demo.gd (tech-review L1).

const Tuning = preload("res://scripts/tuning.gd")
const DroppedBoxScript = preload("res://scripts/dropped_box.gd")
const DropFlightScript = preload("res://scripts/drop_flight.gd")

var host: Node


func bind(day_host: Node) -> void:
	host = day_host

func spawn_dropped_box(
	pos: Vector2,
	sku: String,
	n: int,
	toss_dir: Vector2 = Vector2.ZERO,
	toss_dist: float = -1.0,
	on_landed: Callable = Callable(),
	land_nudge: Vector2 = Vector2.ZERO,
	toss_player: CharacterBody2D = null,
) -> void:
	## Player tosses must never foot-drop: fall back to facing if dir was lost.
	if toss_player != null and is_instance_valid(toss_player) and toss_dir.length_squared() < 0.0001:
		var face: Vector2 = toss_player.facing if toss_player.get("facing") != null else Vector2.RIGHT
		if face.length_squared() < 0.0001:
			face = Vector2.RIGHT
		toss_dir = face.normalized()
	var dest := pos + Tuning.drop_offset(toss_dir, toss_dist)
	## Instant place when no flight needed (e.g. legacy callers).
	if not on_landed.is_valid() and toss_dir.length_squared() < 0.0001:
		_place_dropped_box(dest + land_nudge, sku, n)
		return
	var sniper_guest: Node2D = null
	var sniper_thief: Node2D = null
	var sniper_shelf: Node2D = null
	## Sniper buffs belong to the tossing seat — never fall back to global `_player`
	## (Client seats on Host would otherwise miss guest／thief／shelf sniper).
	var sniper_src: CharacterBody2D = toss_player
	if toss_dir.length_squared() > 0.0001 and sniper_src != null and is_instance_valid(sniper_src):
		## Priority when several snipers are armed: thief → guest → shelf.
		if sniper_src.has_method("sniper_thief_active") and bool(sniper_src.call("sniper_thief_active")):
			sniper_thief = _sniper_thief_for(pos)
			if sniper_thief != null:
				dest = _sniper_thief_drop_pos(sniper_thief)
		if sniper_thief == null and sniper_src.has_method("sniper_guest_active") and bool(sniper_src.call("sniper_guest_active")):
			sniper_guest = _sniper_guest_for(sku, pos)
			if sniper_guest != null:
				dest = _sniper_guest_drop_pos(sniper_guest)
		if (
			sniper_thief == null
			and sniper_guest == null
			and sniper_src.has_method("sniper_shelf_active")
			and bool(sniper_src.call("sniper_shelf_active"))
		):
			sniper_shelf = _sniper_shelf_for(sku, pos)
			if sniper_shelf != null:
				dest = _sniper_drop_pos(sniper_shelf)
	## Optional side offset (投籃高手第二件) after sniper dest so piles do not stack.
	dest += land_nudge
	## Player directional toss: clip walls / furniture / shelves / thieves before flight.
	var clip_shelf: Node2D = null
	var clip_thief: Node2D = null
	var clip_floor := false
	if toss_dir.length_squared() > 0.0001 and toss_player != null and is_instance_valid(toss_player):
		var clip: Dictionary = _clip_player_toss_path_ex(pos, dest, sku, toss_player)
		dest = clip["dest"]
		clip_shelf = clip["shelf"]
		clip_thief = clip["thief"]
		clip_floor = bool(clip["floor_block"])
	var flight_dist := pos.distance_to(dest)
	var flight_sec := Tuning.player_drop_flight_sec(flight_dist) if toss_player != null else Tuning.DROP_FLIGHT_SEC
	host._emit_net_flight(sku, n, pos, dest, flight_sec)
	var flight: Node2D = DropFlightScript.acquire()
	## Player tosses fly straight; other callers keep a small arc.
	flight.setup(sku, pos, dest, flight_sec, n, toss_player == null)
	host._world.add_child(flight)
	flight.finished.connect(func() -> void:
		if sniper_thief != null and is_instance_valid(sniper_thief):
			_resolve_sniper_thief_landing(sniper_thief, dest, sku, n, toss_dir, sniper_src)
		elif sniper_guest != null and is_instance_valid(sniper_guest):
			_resolve_sniper_guest_landing(sniper_guest, dest, sku, n, sniper_src)
		elif sniper_shelf != null and is_instance_valid(sniper_shelf):
			_resolve_sniper_landing(sniper_shelf, dest, sku, n, sniper_src)
		else:
			_resolve_toss_landing(
				pos, dest, sku, n, toss_dir, sniper_src, clip_shelf, clip_floor, clip_thief
			)
		if on_landed.is_valid():
			on_landed.call()
	, CONNECT_ONE_SHOT)


## Scatter cart piles from `origin` with flight anim; destinations do not overlap.
func spawn_loot_scatter(
	origin: Vector2,
	piles: Array,
	min_r: float,
	max_r: float,
) -> void:
	if piles.is_empty():
		return
	SfxBus.play("sfx_loot_scatter")
	var dests := Tuning.loot_scatter_positions(origin, piles.size(), min_r, max_r)
	for i in piles.size():
		var pile: Dictionary = piles[i]
		var sku := String(pile.get("sku", ""))
		var n := int(pile.get("n", 0))
		if sku == "" or n <= 0:
			continue
		var dest: Vector2 = dests[i] if i < dests.size() else origin + Vector2(0, Tuning.LOOT_SCATTER_MELEE_MIN)
		var dur := Tuning.LOOT_SCATTER_FLIGHT_SEC + float(i) * 0.04
		_spawn_box_flight(origin, dest, sku, n, dur, Callable())


## Even ring scatter (boss 序4／序5 reject): piles fly to equal angles at `radius`.
func spawn_loot_even_ring(origin: Vector2, piles: Array, radius: float) -> void:
	if piles.is_empty():
		return
	SfxBus.play("sfx_loot_scatter")
	var dests := Tuning.loot_even_ring_positions(origin, piles.size(), radius)
	for i in piles.size():
		var pile: Dictionary = piles[i]
		var sku := String(pile.get("sku", ""))
		var n := int(pile.get("n", 0))
		if sku == "" or n <= 0:
			continue
		var dest: Vector2 = dests[i] if i < dests.size() else origin + Vector2(radius, 0)
		var dur := Tuning.LOOT_SCATTER_FLIGHT_SEC + float(i) * 0.04
		_spawn_box_flight(origin, dest, sku, n, dur, Callable())


## Instant foot-drop of loot piles at `origin` (box-hit KO — no scatter flight).
func spawn_loot_inplace(origin: Vector2, piles: Array) -> void:
	if piles.is_empty():
		return
	SfxBus.play("sfx_loot_inplace")
	var dests := Tuning.loot_scatter_positions(
		origin, piles.size(), 0.0, Tuning.LOOT_INPLACE_MAX
	)
	for i in piles.size():
		var pile: Dictionary = piles[i]
		var sku := String(pile.get("sku", ""))
		var n := int(pile.get("n", 0))
		if sku == "" or n <= 0:
			continue
		var dest: Vector2 = dests[i] if i < dests.size() else origin
		_place_dropped_box(dest, sku, n)


func _spawn_box_flight(
	from: Vector2,
	to: Vector2,
	sku: String,
	n: int,
	duration: float,
	on_landed: Callable,
) -> void:
	host._emit_net_flight(sku, n, from, to, duration)
	var flight: Node2D = DropFlightScript.acquire()
	flight.setup(sku, from, to, duration, n, true)
	host._world.add_child(flight)
	flight.finished.connect(func() -> void:
		_place_dropped_box(to, sku, n)
		if on_landed.is_valid():
			on_landed.call()
	, CONNECT_ONE_SHOT)


func _toss_actor(toss_player: CharacterBody2D = null) -> CharacterBody2D:
	if toss_player != null and is_instance_valid(toss_player):
		return toss_player
	return host._player


## Aim preview helper — destination only.
func _clip_player_toss_path(from: Vector2, dest: Vector2, sku: String) -> Vector2:
	return _clip_player_toss_path_ex(from, dest, sku, null)["dest"]


## Clip toss path. `shelf` = accepting shelf to restock; `thief` = stop on thief;
## `floor_block` = must land as floor pile (wall / cashier / restock / blocked shelf / other character).
func _clip_player_toss_path_ex(
	from: Vector2, dest: Vector2, sku: String, toss_player: CharacterBody2D = null
) -> Dictionary:
	var best := dest
	var best_t := 1.0
	var hit_shelf: Node2D = null
	var hit_thief: Node2D = null
	var floor_block := false
	var ab := dest - from
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return {"dest": dest, "shelf": null, "thief": null, "floor_block": false}
	## Walls (layer 1) + furniture shelves/cashier/restock (layer 2).
	if host._world != null and is_instance_valid(host._world):
		var space: PhysicsDirectSpaceState2D = host._world.get_world_2d().direct_space_state
		var mask := Tuning.LAYER_WALLS | Tuning.LAYER_FURNITURE
		var query := PhysicsRayQueryParameters2D.create(from, dest, mask)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if toss_player != null and is_instance_valid(toss_player):
			query.exclude = [toss_player.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var hp: Vector2 = hit.position
			var t := from.distance_to(hp) / sqrt(len_sq)
			if t < best_t:
				best_t = t
				## Nudge slightly back so the pile sits on walkable floor.
				best = from.lerp(dest, maxf(0.0, t - 0.02))
				hit_shelf = null
				hit_thief = null
				floor_block = true
				var col = hit.get("collider")
				if col != null and is_instance_valid(col):
					var kind := str(col.get("kind"))
					if kind == "shelf" and col.has_method("can_accept") and bool(col.call("can_accept", sku)):
						hit_shelf = col as Node2D
						floor_block = false
						best = col.global_position + Tuning.DROP_FEET_OFFSET * 0.25
					elif kind == "shelf" or kind == "cashier" or kind == "restock":
						floor_block = true
					elif col is CharacterBody2D:
						## Other clerks / players on the wall layer.
						floor_block = true
						best = col.global_position + Tuning.DROP_FEET_OFFSET
	## Active thieves: stop on them so the box cannot fly through to a shelf beyond.
	var thief_r := Tuning.DROP_THIEF_HIT_RADIUS
	for tnode in host.thieves():
		if tnode == null or not is_instance_valid(tnode):
			continue
		if not tnode.has_method("is_active_thief") or not bool(tnode.call("is_active_thief")):
			continue
		var tp_pos: Vector2 = tnode.global_position
		if _dist_point_to_segment(tp_pos, from, dest) > thief_r:
			continue
		var tt := clampf((tp_pos - from).dot(ab) / len_sq, 0.0, 1.0)
		if tt < 0.05:
			continue
		if tt < best_t:
			best_t = tt
			best = tp_pos + Tuning.DROP_FEET_OFFSET
			hit_thief = tnode
			hit_shelf = null
			floor_block = false
	## Guests who still want this SKU: stop at the guest so the box does not fly past.
	var guest_r := Tuning.DROP_GUEST_HIT_RADIUS
	if host._customers != null:
		for c in host._customers.get_children():
			if c == null or not is_instance_valid(c):
				continue
			if not c.has_method("occupies_store") or bool(c.get("is_thief")):
				continue
			var st: int = int(c.get("state"))
			if st == 7 or st == 9 or st == 8:
				continue
			var shopping = c.get("shopping")
			if shopping == null or not (shopping is Array) or not (shopping as Array).has(sku):
				continue
			var gp: Vector2 = c.global_position
			if _dist_point_to_segment(gp, from, dest) > guest_r:
				continue
			var tg := clampf((gp - from).dot(ab) / len_sq, 0.0, 1.0)
			if tg < 0.05:
				continue
			if tg < best_t:
				best_t = tg
				best = gp + Tuning.DROP_FEET_OFFSET
				hit_shelf = null
				hit_thief = null
				floor_block = false
	var block_r := Tuning.DROP_SHELF_HIT_RADIUS * 0.75
	## Explicit shelf pass (accept → restock dest; reject → floor block).
	for s in host.shelves:
		if s == null or not is_instance_valid(s):
			continue
		var sp: Vector2 = s.global_position
		if _dist_point_to_segment(sp, from, dest) > block_r:
			continue
		var t2 := clampf((sp - from).dot(ab) / len_sq, 0.0, 1.0)
		if t2 < 0.08:
			continue
		if t2 < best_t:
			best_t = t2
			hit_thief = null
			if s.has_method("can_accept") and bool(s.call("can_accept", sku)):
				best = sp + Tuning.DROP_FEET_OFFSET * 0.25
				hit_shelf = s
				floor_block = false
			else:
				best = from.lerp(dest, maxf(0.0, t2 - 0.02))
				hit_shelf = null
				floor_block = true
	## Cashier / restock: stop and floor-drop (furniture layer may already have hit).
	for node in _toss_floor_block_nodes():
		if node == null or not is_instance_valid(node):
			continue
		var np: Vector2 = node.global_position
		if _dist_point_to_segment(np, from, dest) > block_r:
			continue
		var tn := clampf((np - from).dot(ab) / len_sq, 0.0, 1.0)
		if tn < 0.08:
			continue
		if tn < best_t:
			best_t = tn
			best = from.lerp(dest, maxf(0.0, tn - 0.02))
			hit_shelf = null
			hit_thief = null
			floor_block = true
	## Other seated players (wall-layer bodies) along the path.
	for p in host._players:
		if p == null or not is_instance_valid(p):
			continue
		if toss_player != null and p == toss_player:
			continue
		var pp: Vector2 = p.global_position
		if _dist_point_to_segment(pp, from, dest) > guest_r:
			continue
		var tp := clampf((pp - from).dot(ab) / len_sq, 0.0, 1.0)
		if tp < 0.08:
			continue
		if tp < best_t:
			best_t = tp
			best = pp + Tuning.DROP_FEET_OFFSET
			hit_shelf = null
			hit_thief = null
			floor_block = true
	return {"dest": best, "shelf": hit_shelf, "thief": hit_thief, "floor_block": floor_block}


func _toss_floor_block_nodes() -> Array:
	var out: Array = []
	for n in host.cashiers:
		out.append(n)
	if host._world != null:
		for child in host._world.get_children():
			if child != null and is_instance_valid(child) and str(child.get("kind")) == "restock":
				out.append(child)
	return out


func _resolve_toss_landing(
	from: Vector2,
	dest: Vector2,
	sku: String,
	n: int,
	toss_dir: Vector2,
	toss_player: CharacterBody2D = null,
	clip_shelf: Node2D = null,
	clip_floor: bool = false,
	clip_thief: Node2D = null,
) -> void:
	if n <= 0:
		return
	var actor := _toss_actor(toss_player)
	if toss_dir.length_squared() < 0.0001:
		_place_dropped_box(dest, sku, n)
		return
	## Prefer the thief locked at clip time so a mid-flight step cannot miss the hit.
	var thief: Node2D = null
	if clip_thief != null and is_instance_valid(clip_thief):
		if clip_thief.has_method("is_active_thief") and bool(clip_thief.call("is_active_thief")):
			thief = clip_thief
		else:
			## Thief fled during flight — still drop the tossed goods at the clip point.
			_place_dropped_box(dest, sku, n)
			return
	else:
		thief = _thief_for_toss(from, dest)
	if thief != null:
		## Thrown box lands at the hit; KO drops stolen goods in place.
		var land_at: Vector2 = dest
		if is_instance_valid(thief):
			land_at = thief.global_position + Tuning.DROP_FEET_OFFSET
		_place_dropped_box(land_at, sku, n)
		if actor and actor.has_method("apply_toss_ko"):
			actor.call("apply_toss_ko", thief, toss_dir)
		return
	## Wanting guest first (matches path clip). Reject guests must not steal a shelf hit.
	var guest_want := _guest_for_toss(from, dest, sku, true)
	if guest_want != null:
		_resolve_toss_guest(guest_want, dest, sku, n, actor)
		return
	## Wall / cashier / restock / blocked shelf / other character → always floor pile.
	if clip_floor:
		_place_dropped_box(dest, sku, n)
		return
	var shelf: Node2D = clip_shelf if clip_shelf != null and is_instance_valid(clip_shelf) else _shelf_for_toss(dest, sku)
	if shelf != null and shelf.has_method("can_accept") and bool(shelf.call("can_accept", sku)):
		var placed := int(shelf.call("add_items", sku, n))
		if placed > 0:
			SfxBus.play("sfx_box_shelf_toss")
			var left := n - placed
			if actor:
				if left <= 0:
					actor.log_line.emit(
						Loc.t("log.demo.toss_shelved", [Tuning.sku_name(sku), placed])
					)
				else:
					actor.log_line.emit(
						Loc.t("log.demo.toss_shelved_drop", [Tuning.sku_name(sku), placed, left])
					)
			if left > 0:
				_place_dropped_box(dest, sku, left)
			return
	var guest_reject := _guest_for_toss(from, dest, sku, false)
	if guest_reject != null:
		_resolve_toss_guest(guest_reject, dest, sku, n, actor)
		return
	var clone := _clone_for_toss(from, dest)
	if clone != null:
		_resolve_toss_clone(clone, sku, n, actor)
		return
	_place_dropped_box(dest, sku, n)


func _clone_for_toss(from: Vector2, dest: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := Tuning.DROP_GUEST_HIT_RADIUS
	for c in host.shadow_clones():
		if c == null or not is_instance_valid(c):
			continue
		if c.get("_vanishing"):
			continue
		var p: Vector2 = c.global_position
		var d := minf(_dist_point_to_segment(p, from, dest), dest.distance_to(p))
		if d <= best_d:
			best_d = d
			best = c
	return best


func _resolve_toss_clone(
	clone: Node2D, sku: String, n: int, toss_player: CharacterBody2D = null
) -> void:
	if clone.has_method("apply_toss_hit"):
		clone.call("apply_toss_hit")
	_place_dropped_box(clone.global_position + Tuning.DROP_FEET_OFFSET, sku, n)
	var actor := _toss_actor(toss_player)
	if actor:
		actor.log_line.emit(
			Loc.t("log.demo.toss_clone", [Tuning.sku_name(sku), n])
		)


## `want_only`: true → guests whose shopping still lists `sku` (deliver hit).
## false → any other in-range guest (reject hit). Pass sku="" with want_only=false for legacy any-guest.
func _guest_for_toss(
	from: Vector2, dest: Vector2, sku: String = "", want_only: bool = false
) -> Node2D:
	if host._customers == null:
		return null
	var best: Node2D = null
	var best_d := Tuning.DROP_GUEST_HIT_RADIUS
	for c in host._customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## Ops FloatText siblings under Customers lack guest props → bool(null) crash.
		if not c.has_method("occupies_store"):
			continue
		if c.is_thief:
			continue
		var st: int = c.state
		if st == 7 or st == 9 or st == 8:
			continue
		var wants := false
		if sku != "":
			wants = _guest_wants_sku(c, sku) > 0
		if want_only and not wants:
			continue
		if not want_only and sku != "" and wants:
			## Wanting guests are handled in the earlier pass.
			continue
		var p: Vector2 = c.global_position
		var d := minf(_dist_point_to_segment(p, from, dest), dest.distance_to(p))
		if d <= best_d:
			best_d = d
			best = c
	return best


func _resolve_toss_guest(
	guest: Node2D, dest: Vector2, sku: String, n: int, toss_player: CharacterBody2D = null
) -> void:
	var actor := _toss_actor(toss_player)
	var before := 0
	if guest != null and guest.get("shopping") != null:
		before = int((guest.shopping as Array).size())
	var taken := 0
	if guest.has_method("accept_toss_box"):
		taken = int(guest.call("accept_toss_box", sku, n))
	var toss_seat := int(actor.seat_id) if actor != null else 0
	if taken > 0:
		var left := n - taken
		SfxBus.play("sfx_box_hit_guest_ok")
		if actor:
			actor.log_line.emit(
				Loc.t("log.demo.toss_guest_ok", [
					Tuning.sku_name(sku), taken,
					(Loc.t("log.demo.toss_remain", [left]) if left > 0 else ""),
				])
			)
		if left > 0:
			_place_dropped_box(dest, sku, left)
		var perfect: bool = before >= 1 and guest != null and guest.get("shopping") != null and bool(guest.shopping.is_empty())
		if perfect and guest.has_method("apply_combo_bonus"):
			guest.call("apply_combo_bonus")
		host.combo_note_qualify(toss_seat)
		if perfect:
			host.combo_note_perfect(toss_seat)
		host.note_deliver(toss_seat, "toss", 1, perfect)
		return
	## Boss 序4／序5: wrong toss → even ring + dialog (no foot drop).
	if host.has_method("boss_on_wrong_toss") and bool(host.call("boss_on_wrong_toss", actor, guest, sku, n, dest)):
		host.combo_break_personal(toss_seat)
		if actor:
			actor.log_line.emit(Loc.t("log.demo.toss_guest_reject"))
		return
	if guest.has_method("apply_toss_reject"):
		guest.call("apply_toss_reject", sku)
	SfxBus.play("sfx_box_hit_guest_reject")
	_place_dropped_box(dest, sku, n)
	host.combo_break_personal(toss_seat)
	if actor:
		actor.log_line.emit(Loc.t("log.demo.toss_guest_reject"))


## Active thief nearest the flight segment / landing within hit radius.
func _thief_for_toss(from: Vector2, dest: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := Tuning.DROP_THIEF_HIT_RADIUS
	for t in host.thieves():
		if t == null or not is_instance_valid(t):
			continue
		if not t.has_method("is_active_thief") or not bool(t.call("is_active_thief")):
			continue
		var p: Vector2 = t.global_position
		var d := minf(_dist_point_to_segment(p, from, dest), dest.distance_to(p))
		if d <= best_d:
			best_d = d
			best = t
	return best


func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Nearest active thief. No target → caller keeps the normal toss.
func _sniper_thief_for(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for t in host.thieves():
		if t == null or not is_instance_valid(t):
			continue
		if not t.has_method("is_active_thief") or not bool(t.call("is_active_thief")):
			continue
		var d := from.distance_squared_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best


func _sniper_thief_drop_pos(thief: Node2D) -> Vector2:
	return thief.global_position + Tuning.DROP_FEET_OFFSET


func _resolve_sniper_thief_landing(
	thief: Node2D,
	dest: Vector2,
	sku: String,
	n: int,
	toss_dir: Vector2,
	toss_player: CharacterBody2D = null,
) -> void:
	if n <= 0:
		return
	var actor := _toss_actor(toss_player)
	## Thief fled / became uncatchable while the box was in the air.
	if not thief.has_method("is_active_thief") or not bool(thief.call("is_active_thief")):
		_place_dropped_box(dest, sku, n)
		if actor:
			actor.log_line.emit(
				Loc.t("log.demo.sniper_thief_gone", [Tuning.sku_name(sku), n])
			)
		return
	## Hit lands at the thief; whole throw drops (thief does not take shopping).
	_place_dropped_box(thief.global_position + Tuning.DROP_FEET_OFFSET, sku, n)
	if actor and actor.has_method("apply_toss_ko"):
		actor.call("apply_toss_ko", thief, toss_dir)
	elif actor:
		actor.log_line.emit(
			Loc.t("log.demo.sniper_thief_hit", [Tuning.sku_name(sku), n])
		)


## Guests who can still take `sku` from their shopping list. Nearest first.
## No target → caller keeps the normal toss. Unlike shelf sniper, there is no
## "fly to a full guest and dump beside them" fallback.
func _sniper_guest_for(sku: String, from: Vector2) -> Node2D:
	if host._customers == null or sku == "":
		return null
	var best: Node2D = null
	var best_d := INF
	for c in host._customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## Skip FloatText / non-guest children before any Object.get coercions.
		if not c.has_method("can_receive_delivery"):
			continue
		if c.is_thief:
			continue
		if not bool(c.call("can_receive_delivery")):
			continue
		if _guest_wants_sku(c, sku) <= 0:
			continue
		var d := from.distance_squared_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


func _guest_wants_sku(guest: Node2D, sku: String) -> int:
	var shopping = guest.get("shopping")
	if not (shopping is Array):
		return 0
	var want := 0
	for s in shopping:
		if String(s) == sku:
			want += 1
	return want


func _sniper_guest_drop_pos(guest: Node2D) -> Vector2:
	return guest.global_position + Tuning.DROP_FEET_OFFSET


func _resolve_sniper_guest_landing(
	guest: Node2D, dest: Vector2, sku: String, n: int, toss_player: CharacterBody2D = null
) -> void:
	if n <= 0:
		return
	var actor := _toss_actor(toss_player)
	## Guest may have finished shopping while the box was in the air.
	if not guest.has_method("can_receive_delivery") or not bool(guest.call("can_receive_delivery")) or _guest_wants_sku(guest, sku) <= 0:
		## Boss 序4／序5 wrong sniper toss → ring reject (not foot drop).
		if host.has_method("boss_on_wrong_toss") and bool(host.call("boss_on_wrong_toss", actor, guest, sku, n, dest)):
			return
		_place_dropped_box(dest, sku, n)
		if actor:
			actor.log_line.emit(
				Loc.t("log.demo.sniper_guest_gone", [Tuning.sku_name(sku), n])
			)
		return
	var before := 0
	if guest.get("shopping") != null:
		before = int((guest.shopping as Array).size())
	var taken := 0
	if guest.has_method("accept_toss_box"):
		taken = int(guest.call("accept_toss_box", sku, n))
	var left := n - taken
	var toss_seat := int(actor.seat_id) if actor != null else 0
	if taken > 0:
		SfxBus.play("sfx_box_hit_guest_ok")
		var perfect: bool = before >= 1 and bool(guest.shopping.is_empty())
		if perfect and guest.has_method("apply_combo_bonus"):
			guest.call("apply_combo_bonus")
		host.combo_note_qualify(toss_seat)
		if perfect:
			host.combo_note_perfect(toss_seat)
		host.note_deliver(toss_seat, "toss", 1, perfect)
		if actor:
			if left <= 0:
				actor.log_line.emit(
					Loc.t("log.demo.sniper_guest_ok", [Tuning.sku_name(sku), taken])
				)
			else:
				actor.log_line.emit(
					Loc.t("log.demo.sniper_guest_partial", [Tuning.sku_name(sku), taken, left])
				)
	elif actor:
		actor.log_line.emit(
			Loc.t("log.demo.sniper_guest_gone", [Tuning.sku_name(sku), n])
		)
	if left > 0:
		_place_dropped_box(dest, sku, left)


## Same-SKU shelves only. Prefer the nearest with free space; otherwise the nearest full one.
func _sniper_shelf_for(sku: String, from: Vector2) -> Node2D:
	var list = host._shelves_by_sku.get(sku)
	if list == null:
		return null
	var best_open: Node2D = null
	var best_open_d := INF
	var best_any: Node2D = null
	var best_any_d := INF
	for s in list:
		if s == null or not is_instance_valid(s):
			continue
		if String(s.get("sku")) != sku or int(s.get("count")) <= 0:
			continue
		var d := from.distance_squared_to(s.global_position)
		if d < best_any_d:
			best_any_d = d
			best_any = s
		if s.has_method("can_accept") and bool(s.call("can_accept", sku)) and d < best_open_d:
			best_open_d = d
			best_open = s
	return best_open if best_open != null else best_any


func _sniper_drop_pos(shelf: Node2D) -> Vector2:
	if shelf.has_method("stand_position"):
		return shelf.call("stand_position")
	return shelf.global_position + Vector2(0.0, 48.0)


func _resolve_sniper_landing(
	shelf: Node2D, dest: Vector2, sku: String, n: int, toss_player: CharacterBody2D = null
) -> void:
	if n <= 0:
		return
	var actor := _toss_actor(toss_player)
	var placed := 0
	if shelf.has_method("can_accept") and bool(shelf.call("can_accept", sku)) and shelf.has_method("add_items"):
		placed = int(shelf.call("add_items", sku, n))
	var left := n - placed
	if placed > 0:
		SfxBus.play("sfx_box_shelf_toss")
		if actor:
			if left <= 0:
				actor.log_line.emit(
					Loc.t("log.demo.sniper_shelf_ok", [Tuning.sku_name(sku), placed])
				)
			else:
				actor.log_line.emit(
					Loc.t("log.demo.sniper_shelf_partial", [Tuning.sku_name(sku), placed, left])
				)
	elif actor:
		actor.log_line.emit(
			Loc.t("log.demo.sniper_shelf_full", [Tuning.sku_name(sku), n])
		)
	if left > 0:
		_place_dropped_box(dest, sku, left)


## Nearest shelf that can accept `sku` at the landing (clip already snapped accept hits).
func _shelf_for_toss(dest: Vector2, sku: String) -> Node2D:
	var best: Node2D = null
	var best_d := Tuning.DROP_SHELF_HIT_RADIUS
	var cat := Tuning.category_of(sku)
	## Prefer indexed stocked shelves + empty shelves of matching category.
	var candidates: Array = []
	var stocked = host._shelves_by_sku.get(sku)
	if stocked != null:
		for s in stocked:
			candidates.append(s)
	var empties = host._empty_by_cat.get(cat)
	if empties != null:
		for s in empties:
			candidates.append(s)
	if candidates.is_empty():
		candidates = host.shelves
	for s in candidates:
		if s == null or not is_instance_valid(s):
			continue
		if not s.has_method("can_accept") or not bool(s.call("can_accept", sku)):
			continue
		var shelf_sku := String(s.get("sku"))
		if shelf_sku != "" and shelf_sku != sku:
			continue
		var d := dest.distance_to(s.global_position)
		if d <= best_d:
			best_d = d
			best = s
	return best


func _place_dropped_box(dest: Vector2, sku: String, n: int) -> void:
	SfxBus.play("sfx_box_land")
	var drop: Area2D = DroppedBoxScript.new()
	drop.setup(sku, n)
	drop.global_position = dest
	host._world.add_child(drop)
	host._add_interactable(drop)
	drop.tree_exiting.connect(func() -> void: host._remove_interactable(drop))
	host._register_net_agent(drop, "drop", {"sku": sku, "n": n})
