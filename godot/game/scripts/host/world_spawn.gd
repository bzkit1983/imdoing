extends RefCounted
## Guest / thief spawn helpers peeled out of demo.gd (tech-review L1).

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const CustomerScript = preload("res://scripts/customer.gd")
const OpsItems = preload("res://scripts/ops_items.gd")

var host: Node


func bind(day_host: Node) -> void:
	host = day_host

func _tick_guest_dusk(delta: float) -> void:
	if host._guest_dusk_left <= 0.0 and host._guest_dusk_remain <= 0:
		return
	if host.phase != "open":
		host.clear_guest_dusk()
		return
	host._guest_dusk_left = maxf(0.0, host._guest_dusk_left - delta)
	if host._guest_dusk_remain <= 0:
		return
	if host._guest_dusk_left <= 0.0:
		host.clear_guest_dusk()
		return
	host._guest_dusk_in -= delta
	## Empty sellable: retry next frame (skip, do not burn a slot or the interval).
	while host._guest_dusk_remain > 0 and host._guest_dusk_in <= 0.0:
		if host.state.sellable().is_empty():
			host._guest_dusk_in = 0.0
			break
		if _spawn_customer(true):
			host._guest_dusk_remain -= 1
			host._guest_dusk_in += Skills.GUEST_DUSK_INTERVAL
		else:
			host._guest_dusk_in = 0.0
			break
	if host._guest_dusk_remain <= 0:
		host._guest_dusk_remain = 0


## Returns true when a guest was spawned. `ignore_cap` for 諸客的黃昏.

func _spawn_customer(ignore_cap: bool = false) -> bool:
	if host.state.sellable().is_empty():
		return false
	if not ignore_cap and host.guest_count() >= host.state.guest_cap():
		return false
	## EliteCustomer only during open host.phase (not restock).
	var make_elite := false
	var elite_lv := 1
	if host.phase == "open":
		if host.elite_test_active and host.elite_test_need_one:
			make_elite = true
			host.elite_test_need_one = false
		elif host.elite_test_active:
			## Test mode: elevated chance after the guaranteed first elite.
			make_elite = randf() < Tuning.ELITE_TEST_SPAWN_CHANCE
		else:
			make_elite = randf() < Tuning.elite_spawn_chance()
		if make_elite:
			if host.elite_test_active:
				elite_lv = host.elite_test_lv if host.elite_test_lv >= 1 else randi_range(1, 6)
			else:
				elite_lv = Tuning.elite_roll_level()
	var c: CharacterBody2D = CustomerScript.new()
	host._customers.add_child(c)
	c.setup(host, host.door_pos())
	if make_elite:
		c.call("become_elite", elite_lv)
		host.announce_elite_customer(c)
	host.register_customer(c)
	var cust_extra := {
		"pace": String(c.get("pace")),
		"elite": bool(c.get("is_elite")),
		"elite_lv": int(c.get("elite_lv")),
		"model": String(c.get("_model_id")),
		"shopping": c.shopping.duplicate() if c.get("shopping") != null else [],
	}
	if c.has_meta("checkout_seq_init") and bool(c.get_meta("checkout_seq_init")):
		var dirs: Array = []
		for d in c.checkout_seq:
			dirs.append(int(d))
		cust_extra["checkout_seq"] = dirs
		cust_extra["checkout_init"] = true
	host._register_net_agent(c, "customer", cust_extra)
	SfxBus.play("sfx_guest_enter")
	## Rating tutorial tip arms on first normal／elite guest (not thieves).
	if host._tutorial != null and is_instance_valid(host._tutorial) and host._tutorial.has_method("notify_flag"):
		host._tutorial.notify_flag("guest_present")
	return true


## Soft-attach a task pack for tutorial practice HUD (does not set task_test_mode).

func _tutorial_blocks_thief_spawn() -> bool:
	if host.state == null or int(host.state.scenario) != 5:
		return false
	return host.state.tutorial_status("tut.ops.checkout") != "done"


## After checkout lesson (or escape during catch lesson): force one thief in.

func seed_thief_for_tutorial() -> void:
	if _tutorial_blocks_thief_spawn():
		return
	if not (SessionService.is_server() or SessionService.is_local_transport()):
		return
	_spawn_thief(true)

func _spawn_thief(force: bool = false) -> void:
	if _tutorial_blocks_thief_spawn():
		return
	if host.state.sellable().is_empty():
		return
	if not force and randf() > host.thief_appear_rate():
		return
	var thief_cap := Tuning.THIEF_CAP
	if host.state != null and host.state.has_method("thief_cap"):
		thief_cap = int(host.state.thief_cap())
	if host.thief_count() >= thief_cap:
		return
	var c: CharacterBody2D = CustomerScript.new()
	host._customers.add_child(c)
	c.setup(host, host.door_pos(), true)
	host._add_interactable(c)
	c.tree_exiting.connect(func() -> void: host._remove_interactable(c))
	host.register_customer(c)
	host._register_net_agent(c, "thief", {
		"pace": "normal",
		"elite": false,
		"elite_lv": 0,
		"model": String(c.get("_model_id")),
		"shopping": c.shopping.duplicate() if c.get("shopping") != null else [],
	})
	SfxBus.play("sfx_thief_spawn")
	if host._player:
		host._player.log_line.emit(Loc.t("demo.thief_enter"))
	if host._tutorial != null and is_instance_valid(host._tutorial) and host._tutorial.has_method("notify_flag"):
		host._tutorial.notify_flag("thief_present")


## Open-phase guest／thief／dirt／ops-item cadence (boss day suppresses ambient).
func tick_ambient(delta: float) -> void:
	if not (SessionService.is_server() or SessionService.is_local_transport()):
		return
	var boss = host.get("_boss_world")
	var suppress: bool = (
		boss != null
		and boss.has_method("should_suppress_ambient")
		and bool(boss.should_suppress_ambient())
	)
	if host.phase == "open":
		if suppress:
			if boss != null and boss.has_method("tick_open_spawn"):
				boss.tick_open_spawn()
		else:
			_tick_guest_dusk(delta)
			host._spawn_in -= host.world_delta(delta)
			if host._spawn_in <= 0.0:
				host._spawn_customer()
				host._spawn_in = host.state.spawn_every()
			host._thief_spawn_in -= host.world_delta(delta)
			if host._thief_spawn_in <= 0.0:
				_spawn_thief()
				host._thief_spawn_in = host.state.thief_spawn_sec()
	if not suppress:
		host._dirt_spawn_in -= host.world_delta(delta)
		if host._dirt_spawn_in <= 0.0:
			host._try_spawn_dirt()
			host._dirt_spawn_in = host.dirt_spawn_interval()
		if host.phase == "open":
			host._ops_item_spawn_in -= host.world_delta(delta)
			if host._ops_item_spawn_in <= 0.0:
				host._try_spawn_ops_item()
				host._ops_item_spawn_in = randf_range(OpsItems.SPAWN_EVERY_MIN, OpsItems.SPAWN_EVERY_MAX)

