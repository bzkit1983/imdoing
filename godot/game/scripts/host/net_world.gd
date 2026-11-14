extends RefCounted
## Net world agent / stock / flight sync peeled out of demo.gd (tech-review F1).
## Puppet spawn bodies remain on the day host; this module owns dispatch + stock chrome.

const Tuning = preload("res://scripts/tuning.gd")
const DropFlightScript = preload("res://scripts/drop_flight.gd")

var host: Node


func bind(day_host: Node) -> void:
	host = day_host


func connect_session() -> void:
	if not SessionService.agent_spawn_received.is_connected(on_agent_spawn_received):
		SessionService.agent_spawn_received.connect(on_agent_spawn_received)
	if not SessionService.agent_despawn_received.is_connected(on_agent_despawn_received):
		SessionService.agent_despawn_received.connect(on_agent_despawn_received)
	if not SessionService.agent_state_received.is_connected(on_agent_state_received):
		SessionService.agent_state_received.connect(on_agent_state_received)
	if not SessionService.flight_received.is_connected(on_flight_received):
		SessionService.flight_received.connect(on_flight_received)
	if not SessionService.stock_state_received.is_connected(on_stock_state_received):
		SessionService.stock_state_received.connect(on_stock_state_received)


func clear_runtime() -> void:
	host._net_agents.clear()
	host._next_agent_id = 1
	host._agent_xform_tick = 0
	host._pending_agent_spawns.clear()
	host._pending_flights.clear()
	host._pending_agent_states.clear()
	host._pending_stock_states.clear()
	host._pending_carry_states.clear()
	host._pending_prompt_states.clear()
	host._shelves_by_net_id.clear()
	host._next_net_shelf_id = 0
	## Keep `_warehouse_hooked` — state signal stays connected across days.

func alloc_agent_id() -> int:
	var id: int = int(host._next_agent_id)
	host._next_agent_id = id + 1
	return id

func register_net_agent(node: Node, kind: String, extra: Dictionary = {}) -> void:
	## Host-only: assign id, track, broadcast spawn to clients (M2.2).
	if node == null or not is_instance_valid(node):
		return
	if SessionService.is_networked() and SessionService.is_client():
		return
	var aid := alloc_agent_id()
	node.set("net_agent_id", aid)
	host._net_agents[aid] = node
	if not node.tree_exiting.is_connected(on_net_agent_tree_exiting):
		node.tree_exiting.connect(on_net_agent_tree_exiting.bind(aid))
	if not SessionService.is_networked() or not SessionService.is_server():
		return
	var payload := {
		"id": aid,
		"kind": kind,
		"px": float(node.global_position.x) if node is Node2D else 0.0,
		"py": float(node.global_position.y) if node is Node2D else 0.0,
		"fx": 0.0,
		"fy": 1.0,
	}
	if node is CharacterBody2D:
		var vel: Vector2 = (node as CharacterBody2D).velocity
		if vel.length_squared() > 1.0:
			payload["fx"] = vel.x
			payload["fy"] = vel.y
	for k in extra.keys():
		payload[k] = extra[k]
	SessionService.broadcast_agent_spawn(payload)

func on_net_agent_tree_exiting(agent_id: int) -> void:
	host._net_agents.erase(agent_id)
	if SessionService.is_networked() and SessionService.is_server() and SessionService.day_started:
		SessionService.broadcast_agent_despawn(agent_id, "gone")

func collect_agent_transforms() -> Array:
	var out: Array = []
	var stale: Array[int] = []
	for aid in host._net_agents.keys():
		var n = host._net_agents[aid]
		if n == null or not is_instance_valid(n):
			stale.append(int(aid))
			continue
		if not (n is Node2D):
			continue
		## Static presentation agents — pose fixed after spawn (M2.3).
		var kind := String(n.get("kind")) if n.get("kind") != null else ""
		if kind in ["drop", "dirt", "universal_cannon", "shelf_cannon", "calm_zone", "three_volley"]:
			continue
		var fx := 0.0
		var fy := 1.0
		if n is CharacterBody2D:
			var vel: Vector2 = (n as CharacterBody2D).velocity
			if vel.length_squared() > 16.0:
				fx = vel.x
				fy = vel.y
			elif "facing" in n:
				var f: Vector2 = n.facing
				fx = f.x
				fy = f.y
		out.append({
			"id": int(aid),
			"px": (n as Node2D).global_position.x,
			"py": (n as Node2D).global_position.y,
			"fx": fx,
			"fy": fy,
		})
	for sid in stale:
		host._net_agents.erase(sid)
	return out

func apply_agent_transforms(rows: Array) -> void:
	for row in rows:
		if not (row is Dictionary):
			continue
		var aid := int(row.get("id", -1))
		if aid < 0 or not host._net_agents.has(aid):
			continue
		var n = host._net_agents[aid]
		if n == null or not is_instance_valid(n):
			host._net_agents.erase(aid)
			continue
		var pos := Vector2(float(row.get("px", 0.0)), float(row.get("py", 0.0)))
		var fac := Vector2(float(row.get("fx", 0.0)), float(row.get("fy", 1.0)))
		if n.has_method("apply_net_pose"):
			n.call("apply_net_pose", pos, fac)
		elif n is Node2D:
			(n as Node2D).global_position = pos

func on_agent_spawn_received(payload: Dictionary) -> void:
	## Client: instantiate presentation puppet from Host spawn event.
	if not SessionService.is_client():
		return
	if host._world == null or not is_instance_valid(host._world) or host._customers == null:
		host._pending_agent_spawns.append(payload.duplicate(true))
		return
	apply_agent_spawn_payload(payload)

func flush_pending_agent_spawns() -> void:
	if host._pending_agent_spawns.is_empty():
		return
	var queued: Array = host._pending_agent_spawns.duplicate(true)
	host._pending_agent_spawns.clear()
	for payload in queued:
		if payload is Dictionary:
			apply_agent_spawn_payload(payload)

func apply_agent_spawn_payload(payload: Dictionary) -> void:
	var aid := int(payload.get("id", -1))
	if aid < 0 or host._net_agents.has(aid):
		return
	var kind := String(payload.get("kind", ""))
	var pos := Vector2(float(payload.get("px", 0.0)), float(payload.get("py", 0.0)))
	match kind:
		"customer", "thief":
			host._spawn_customer_puppet(aid, kind == "thief", pos, payload)
		"clerk":
			host._spawn_clerk_puppet(aid, pos, payload)
		"dirt":
			host._spawn_dirt_puppet(aid, pos, payload)
		"drop":
			host._spawn_drop_puppet(aid, pos, payload)
		"shadow_clone":
			host._spawn_shadow_clone_puppet(aid, pos, payload)
		"universal_cannon":
			host._spawn_cannon_puppet(aid, pos, payload)
		"shelf_cannon":
			host._spawn_shelf_cannon_puppet(aid, pos, payload)
		"calm_zone":
			host._spawn_calm_zone_puppet(aid, pos, payload)
		"three_volley":
			host._spawn_three_volley_puppet(aid, pos, payload)
		_:
			pass

func on_agent_state_received(payload: Dictionary) -> void:
	if not SessionService.is_client():
		return
	if host._world == null or not is_instance_valid(host._world):
		host._pending_agent_states.append(payload.duplicate(true))
		return
	apply_agent_state_payload(payload)

func flush_pending_agent_states() -> void:
	if host._pending_agent_states.is_empty():
		return
	var queued: Array = host._pending_agent_states.duplicate(true)
	host._pending_agent_states.clear()
	for payload in queued:
		if payload is Dictionary:
			apply_agent_state_payload(payload)

func apply_agent_state_payload(payload: Dictionary) -> void:
	var aid := int(payload.get("id", -1))
	if aid < 0 or not host._net_agents.has(aid):
		return
	var n = host._net_agents[aid]
	if n == null or not is_instance_valid(n):
		host._net_agents.erase(aid)
		return
	## Drop remaining count.
	if payload.has("n") and n.has_method("apply_net_count"):
		n.call("apply_net_count", int(payload.get("n", 0)))
		if int(payload.get("n", 0)) <= 0:
			host._net_agents.erase(aid)
		return
	## Guest／thief shopping pictogram chrome (M2.7).
	if payload.has("shopping") and n.has_method("apply_net_shopping"):
		n.call("apply_net_shopping", payload.get("shopping", []))
		return
	## Guest checkout dir sequence (M2.9).
	if payload.has("checkout_seq") and n.has_method("apply_net_checkout_seq"):
		n.call(
			"apply_net_checkout_seq",
			payload.get("checkout_seq", []),
			bool(payload.get("checkout_init", false)),
		)
		return
	## Dirt clean StickHint／meter chrome (M2.8).
	if payload.has("cleaning") and n.has_method("apply_net_clean"):
		n.call(
			"apply_net_clean",
			bool(payload.get("cleaning", false)),
			float(payload.get("meter", 0.0)),
			Vector2(float(payload.get("sx", 0.0)), float(payload.get("sy", 0.0))),
			int(payload.get("seat", -1)),
		)
		return
	## Dark Side temp morph on customer puppet.
	if payload.has("temp") and n.has_method("apply_net_temp_state"):
		n.call("apply_net_temp_state", bool(payload.get("temp", false)), String(payload.get("role", "")))
		return
	## Cannon ammo label.
	if payload.has("ammo_n") and n.has_method("apply_net_ammo"):
		n.call("apply_net_ammo", int(payload.get("ammo_n", 0)), String(payload.get("sku", "")))
		return
	## Host fight outcome for a presentation thief (unlock client mash / pending KO).
	if payload.has("fight_clear"):
		host._resolve_net_fight_clear(n, bool(payload.get("caught", false)))

func on_flight_received(payload: Dictionary) -> void:
	if not SessionService.is_client():
		return
	if host._world == null or not is_instance_valid(host._world):
		host._pending_flights.append(payload.duplicate(true))
		return
	play_net_flight(payload)

func flush_pending_flights() -> void:
	if host._pending_flights.is_empty():
		return
	var queued: Array = host._pending_flights.duplicate(true)
	host._pending_flights.clear()
	for payload in queued:
		if payload is Dictionary:
			play_net_flight(payload)

func play_net_flight(payload: Dictionary) -> void:
	## Client VFX only — do NOT place a floor box on land (Host sends drop spawn).
	if host._world == null:
		return
	var sku := String(payload.get("sku", ""))
	var n := int(payload.get("n", 0))
	if sku == "" or n <= 0:
		return
	var from := Vector2(float(payload.get("fx", 0.0)), float(payload.get("fy", 0.0)))
	var to := Vector2(float(payload.get("tx", 0.0)), float(payload.get("ty", 0.0)))
	var dur := float(payload.get("dur", Tuning.DROP_FLIGHT_SEC))
	var flight: Node2D = DropFlightScript.new()
	flight.setup(sku, from, to, dur, n)
	host._world.add_child(flight)

func emit_net_flight(sku: String, n: int, from: Vector2, to: Vector2, duration: float) -> void:
	if not SessionService.is_networked() or not SessionService.is_server():
		return
	SessionService.broadcast_flight({
		"sku": sku,
		"n": n,
		"fx": from.x,
		"fy": from.y,
		"tx": to.x,
		"ty": to.y,
		"dur": duration,
	})


## Directional toss: thief hit → KO; else matching shelf restock; else floor.

func on_agent_despawn_received(agent_id: int, _reason: String) -> void:
	if not SessionService.is_client():
		return
	## Drop matching pending spawn if despawn raced ahead.
	var i := 0
	while i < host._pending_agent_spawns.size():
		var row = host._pending_agent_spawns[i]
		if row is Dictionary and int(row.get("id", -1)) == agent_id:
			host._pending_agent_spawns.remove_at(i)
			continue
		i += 1
	if not host._net_agents.has(agent_id):
		return
	var n = host._net_agents[agent_id]
	host._net_agents.erase(agent_id)
	## Free local seats still mashed against this presentation thief.
	if n != null and is_instance_valid(n):
		var was_thief: bool = bool(host._obj_truthy(n, "is_thief"))
		for p in host._players:
			if p == null or not is_instance_valid(p):
				continue
			if p.get("target") != n:
				continue
			if host._obj_truthy(p, "_fighting") or host._obj_truthy(p, "_net_ko_pending") or host._obj_truthy(p, "_fight_ko"):
				if was_thief and not host._obj_truthy(p, "_fight_ko"):
					host.play_ko_banner()
				if p.has_method("_end_fight"):
					p.call("_end_fight", true)
		host._clerks.erase(n)
		host._dirts.erase(n)
		host._remove_interactable(n)
		n.queue_free()

func hook_warehouse_changed() -> void:
	if host.state == null or host._warehouse_hooked:
		return
	if host.state.has_signal("warehouse_changed") and not host.state.warehouse_changed.is_connected(on_warehouse_changed):
		host.state.warehouse_changed.connect(on_warehouse_changed)
		host._warehouse_hooked = true

func on_shelf_stock_changed(shelf: Node) -> void:
	## Host only — client prediction is overwritten by absolute stock_state.
	if SessionService.is_networked() and SessionService.is_client():
		return
	broadcast_shelf_stock(shelf)

func on_warehouse_changed() -> void:
	if SessionService.is_networked() and SessionService.is_client():
		return
	broadcast_warehouse_stock()

func broadcast_shelf_stock(shelf: Node) -> void:
	if shelf == null or not is_instance_valid(shelf):
		return
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var nid := int(shelf.get("net_shelf_id")) if shelf.get("net_shelf_id") != null else -1
	if nid < 0:
		return
	SessionService.broadcast_stock_state({
		"shelves": [{
			"id": nid,
			"sku": String(shelf.get("sku")),
			"count": int(shelf.get("count")),
		}],
	})

func broadcast_warehouse_stock() -> void:
	if host.state == null:
		return
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	SessionService.broadcast_stock_state({
		"warehouse": host.state.stock.duplicate(true),
	})

func dump_all_stock() -> void:
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var rows: Array = []
	for shelf in host.shelves:
		if shelf == null or not is_instance_valid(shelf):
			continue
		var nid := int(shelf.get("net_shelf_id")) if shelf.get("net_shelf_id") != null else -1
		if nid < 0:
			continue
		rows.append({
			"id": nid,
			"sku": String(shelf.get("sku")),
			"count": int(shelf.get("count")),
		})
	var payload := {}
	if not rows.is_empty():
		payload["shelves"] = rows
	if host.state != null:
		payload["warehouse"] = host.state.stock.duplicate(true)
	if not payload.is_empty():
		SessionService.broadcast_stock_state(payload)

func on_stock_state_received(payload: Dictionary) -> void:
	if not SessionService.is_client():
		return
	if host._world == null or not is_instance_valid(host._world):
		host._pending_stock_states.append(payload.duplicate(true))
		return
	apply_stock_state_payload(payload)

func flush_pending_stock_states() -> void:
	if host._pending_stock_states.is_empty():
		return
	var queued: Array = host._pending_stock_states.duplicate(true)
	host._pending_stock_states.clear()
	for payload in queued:
		if payload is Dictionary:
			apply_stock_state_payload(payload)

func apply_stock_state_payload(payload: Dictionary) -> void:
	var wh_changed := false
	if payload.has("warehouse") and host.state != null:
		var wh = payload.get("warehouse")
		if wh is Dictionary:
			## Absolute warehouse dict from Host — replace presentation stock.
			host.state.stock.clear()
			for k in wh.keys():
				host.state.stock[String(k)] = int(wh[k])
			wh_changed = true
	var rows = payload.get("shelves", [])
	if rows is Array:
		for row in rows:
			if not (row is Dictionary):
				continue
			var nid := int(row.get("id", -1))
			if nid < 0 or not host._shelves_by_net_id.has(nid):
				continue
			var shelf = host._shelves_by_net_id[nid]
			if shelf == null or not is_instance_valid(shelf):
				host._shelves_by_net_id.erase(nid)
				continue
			if shelf.has_method("apply_net_stock"):
				shelf.call("apply_net_stock", String(row.get("sku", "")), int(row.get("count", 0)))
	if wh_changed:
		host.sync_stock()

