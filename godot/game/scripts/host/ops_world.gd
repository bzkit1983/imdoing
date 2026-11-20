extends RefCounted
## Dirt spawn grid + ops-item world bombs peeled out of demo.gd (tech-review L1).

const Tuning = preload("res://scripts/tuning.gd")
const DirtScript = preload("res://scripts/dirt.gd")
const OpsItemPickupScript = preload("res://scripts/ops_item_pickup.gd")
const OpsItems = preload("res://scripts/ops_items.gd")
const CustomerScript = preload("res://scripts/customer.gd")

var host: Node


func bind(day_host: Node) -> void:
	host = day_host

func _dirt_cell_key(p: Vector2) -> int:
	var cx := int(floor(p.x / host.DIRT_CELL))
	var cy := int(floor(p.y / host.DIRT_CELL))
	return cx + cy * 4096

func _mark_dirt_rect_cells(r: Rect2, blocked: bool) -> void:
	var grow := r.grow(18.0)
	var x0 := int(floor(grow.position.x / host.DIRT_CELL))
	var y0 := int(floor(grow.position.y / host.DIRT_CELL))
	var x1 := int(floor(grow.end.x / host.DIRT_CELL))
	var y1 := int(floor(grow.end.y / host.DIRT_CELL))
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var key := x + y * 4096
			if blocked:
				host._dirt_block_cells[key] = int(host._dirt_block_cells.get(key, 0)) + 1
			else:
				var n := int(host._dirt_block_cells.get(key, 0)) - 1
				if n <= 0:
					host._dirt_block_cells.erase(key)
				else:
					host._dirt_block_cells[key] = n

func _rebuild_dirt_block_cells() -> void:
	host._dirt_block_cells.clear()
	_mark_dirt_rect_cells(Rect2(host.door_pos() + Vector2(-70, -20), Vector2(140, 110)), true)
	for o in host._obstacles:
		_mark_dirt_rect_cells(o, true)
	for d in host._dirts:
		if d != null and is_instance_valid(d):
			_mark_dirt_rect_cells(Rect2(d.global_position - Tuning.DIRT_SIZE * 0.5, Tuning.DIRT_SIZE), true)


## Scenario 5: no dirt until shelve lesson is done (clean lesson waits on dirt_present).

func _tutorial_blocks_dirt_spawn() -> bool:
	if host.state == null or int(host.state.scenario) != 5:
		return false
	return host.state.tutorial_status("tut.ops.shelve") != "done"


## Called after shelve tutorial completes so clean can arm on first dirt.

func seed_dirt_if_tutorial_allows() -> void:
	if _tutorial_blocks_dirt_spawn():
		return
	if SessionService.is_server() or SessionService.is_local_transport():
		_try_spawn_dirt()

func _try_spawn_dirt() -> void:
	if _tutorial_blocks_dirt_spawn():
		return
	if host._dirts.size() >= Tuning.DIRT_CAP:
		return
	if host._dirt_block_cells.is_empty() and not host._obstacles.is_empty():
		_rebuild_dirt_block_cells()
	var size := Tuning.DIRT_SIZE
	## Sample free coarse cells first; full rect check only on candidates.
	for _i in 12:
		var origin := host.FLOOR_ORIGIN + Vector2(
			randf_range(36.0, host.FLOOR_SIZE.x - size.x - 36.0),
			randf_range(48.0, host.FLOOR_SIZE.y - size.y - 36.0)
		)
		var center := origin + size * 0.5
		if host._dirt_block_cells.has(_dirt_cell_key(center)):
			continue
		var r := Rect2(origin, size)
		if _blocked_rect(r):
			continue
		_spawn_dirt(r, Tuning.random_dirt_type())
		return

func _blocked_rect(r: Rect2) -> bool:
	var grow := r.grow(18.0)
	var door := Rect2(host.door_pos() + Vector2(-70, -20), Vector2(140, 110))
	if grow.intersects(door):
		return true
	for d in host._dirts:
		if not is_instance_valid(d):
			continue
		var other := Rect2(d.global_position - Tuning.DIRT_SIZE * 0.5, Tuning.DIRT_SIZE).grow(24.0)
		if grow.intersects(other):
			return true
	## Obstacles last (largest list).
	for o in host._obstacles:
		if grow.intersects(o):
			return true
	return false

func _spawn_dirt(r: Rect2, dtype: String) -> void:
	var area: Area2D = DirtScript.new()
	area.setup(dtype, r.size)
	area.global_position = r.position + r.size * 0.5
	host._world.add_child(area)
	host._dirts.append(area)
	_add_interactable(area)
	_mark_dirt_rect_cells(r, true)
	area.tree_exiting.connect(_on_dirt_gone.bind(area))
	host._register_net_agent(area, "dirt", {
		"dirt_type": dtype,
		"sx": r.size.x,
		"sy": r.size.y,
	})
	SfxBus.play("sfx_dirt_spawn")
	if host._tutorial != null and is_instance_valid(host._tutorial) and host._tutorial.has_method("notify_flag"):
		host._tutorial.notify_flag("dirt_present")

func _on_dirt_gone(area: Node2D) -> void:
	if area != null and is_instance_valid(area):
		_mark_dirt_rect_cells(Rect2(area.global_position - Tuning.DIRT_SIZE * 0.5, Tuning.DIRT_SIZE), false)
	host._dirts.erase(area)
	_remove_interactable(area)

func _try_spawn_ops_item() -> void:
	if OpsItems.unlocked_count() <= 0:
		return
	_prune_ops_items()
	if host._ops_items.size() >= OpsItems.SPAWN_CAP:
		return
	var size := OpsItems.PICKUP_SIZE
	for _i in 12:
		var origin := host.FLOOR_ORIGIN + Vector2(
			randf_range(36.0, host.FLOOR_SIZE.x - size.x - 36.0),
			randf_range(48.0, host.FLOOR_SIZE.y - size.y - 48.0)
		)
		var r := Rect2(origin, size)
		if _blocked_rect(r):
			continue
		_spawn_ops_item(r.position + r.size * 0.5, OpsItems.random_id())
		return

func _spawn_ops_item(pos: Vector2, item_id: String) -> void:
	var area: Area2D = OpsItemPickupScript.new()
	area.setup(item_id)
	area.global_position = pos
	host._world.add_child(area)
	host._ops_items.append(area)
	_add_interactable(area)
	area.tree_exiting.connect(_on_ops_item_gone.bind(area))
	host._register_net_agent(area, "ops_item", {"item_id": item_id})

func _on_ops_item_gone(area: Node2D) -> void:
	host._ops_items.erase(area)
	_remove_interactable(area)

func _prune_ops_items() -> void:
	var keep: Array[Node2D] = []
	for n in host._ops_items:
		if n != null and is_instance_valid(n):
			keep.append(n)
	host._ops_items = keep

func clear_ops_items_world() -> void:
	_prune_ops_items()
	for n in host._ops_items.duplicate():
		if n != null and is_instance_valid(n):
			n.queue_free()
	host._ops_items.clear()
	for p in host._players:
		if p != null and is_instance_valid(p) and p.has_method("clear_ops_bag"):
			p.clear_ops_bag()
	host._ops_item_spawn_in = OpsItems.SPAWN_FIRST_SEC


## Host: consume bag slot and apply bomb. Returns true if consumed.

func use_ops_item(seat: int, slot: int) -> bool:
	if SessionService.is_networked() and SessionService.is_client():
		return false
	var actor := host._seat_actor(seat)
	if actor == null or not actor.has_method("ops_bag_ids"):
		return false
	var bag: Array = actor.ops_bag_ids()
	if slot < 0 or slot >= bag.size():
		return false
	var id := String(bag[slot])
	if id == "" or not OpsItems.is_known(id):
		return false
	match id:
		OpsItems.COMFORT_BOMB:
			_use_comfort_bomb(seat, actor)
		OpsItems.CLEAN_BOMB:
			_use_clean_bomb(seat, actor)
		OpsItems.VILLAIN_BOMB:
			_use_villain_bomb(seat, actor)
		_:
			return false
	if actor.ops_bag.size() > slot:
		actor.ops_bag[slot] = ""
	if actor.has_signal("stats_changed"):
		actor.stats_changed.emit()
	return true

func _use_comfort_bomb(_seat: int, actor: Node2D) -> void:
	host.soothe_all(0.0)
	_play_ops_bomb_flash(Loc.t("ops_item.comfort_bomb.name"), Color(1.0, 0.75, 0.85, 0.7))
	if host._customers != null:
		## `host._customers` also parents float_text siblings — only touch real guests.
		for c in host._customers.get_children():
			if c == null or not is_instance_valid(c):
				continue
			if not (c is CustomerScript):
				continue
			var guest := c as CustomerScript
			if guest.is_thief or guest.temp_clerk:
				continue
			if guest.state == CustomerScript.State.LEAVE or guest.state == CustomerScript.State.FLEE:
				continue
			guest.mood = Loc.t("mood.ops_happy")
	if actor != null and actor.has_signal("log_line"):
		actor.log_line.emit(Loc.t("log.ops_item.used", [OpsItems.display_name(OpsItems.COMFORT_BOMB)]))

func _use_clean_bomb(seat: int, actor: Node2D) -> void:
	_play_ops_bomb_flash(Loc.t("ops_item.clean_bomb.name"), Color(0.55, 0.9, 1.0, 0.7))
	var snapshot: Array = host._dirts.duplicate()
	var FxBurst = preload("res://scripts/fx_burst.gd")
	for d in snapshot:
		if d == null or not is_instance_valid(d):
			continue
		FxBurst.spawn(host, "clean_spark", d.global_position)
		host.note_clean(seat, actor)
		d.queue_free()
	if actor != null and actor.has_signal("log_line"):
		actor.log_line.emit(Loc.t("log.ops_item.used", [OpsItems.display_name(OpsItems.CLEAN_BOMB)]))

func _use_villain_bomb(seat: int, actor: Node2D) -> void:
	_play_ops_bomb_flash(Loc.t("ops_item.villain_bomb.name"), Color(1.0, 0.45, 0.35, 0.75))
	if host._customers == null:
		return
	var thieves: Array = []
	for c in host._customers.get_children():
		if c != null and is_instance_valid(c) and c.has_method("is_active_thief") and bool(c.call("is_active_thief")):
			thieves.append(c)
	if not thieves.is_empty():
		host.play_ko_banner()
	for t in thieves:
		var dir := Vector2.RIGHT
		if actor != null:
			dir = (t.global_position - actor.global_position).normalized()
			if dir.length_squared() < 0.01:
				dir = Vector2.RIGHT
		if t.has_method("ko_box_hit_and_flee"):
			t.call("ko_box_hit_and_flee", dir)
		host.record_caught(seat, "ops_item", actor)
	if actor != null and actor.has_signal("log_line"):
		actor.log_line.emit(Loc.t("log.ops_item.used", [OpsItems.display_name(OpsItems.VILLAIN_BOMB)]))

func _play_ops_bomb_flash(title: String, flash_color: Color) -> void:
	host._play_banner_flash(title, Color(1.0, 0.98, 0.9, 1.0), 72, flash_color, 0.85)

func _add_interactable(node: Node2D) -> void:
	if host._player == null:
		return
	if not host._player.interactables.has(node):
		host._player.interactables.append(node)

func _remove_interactable(node: Node2D) -> void:
	if host._player == null:
		return
	host._player.interactables.erase(node)

