extends RefCounted
## Ultimate / world skill casts peeled out of demo.gd (tech-review L1).

const Fundraise = preload("res://scripts/fundraise.gd")
const Skills = preload("res://scripts/skills.gd")
const CustomerScript = preload("res://scripts/customer.gd")
const ThreeVolleyVisualScript = preload("res://scripts/three_volley_visual.gd")

var host: Node


func bind(day_host: Node) -> void:
	host = day_host

func cast_fundraise(level: int, seat: int = 0) -> void:
	if SessionService.is_networked() and SessionService.is_client():
		return
	if host._customers == null:
		return
	var picked: Array = Fundraise.choose(host._customers.get_children(), level)
	var total := 0
	for c in picked:
		var amount := int(c.call("payout_total")) if c.has_method("payout_total") else int(c.call("cart_total"))
		total += amount
		host._on_paid(amount, c.get("is_elite") == true, seat, null, false, c, true)
		c.finish_paid()
	host.release_player_checkout()
	if host._player:
		host._player.log_line.emit(Loc.t("demo.fundraise", [picked.size(), total]))


## 割韭菜: cash up to `max_n` QUEUE/PAYING on one register (queue order). Returns how many paid.

func cast_harvest_chives(reg: Node, max_n: int, seat: int = 0) -> int:
	if SessionService.is_networked() and SessionService.is_client():
		return 0
	if reg == null or not is_instance_valid(reg) or max_n <= 0:
		return 0
	if str(reg.get("kind")) != "cashier":
		return 0
	var q: Array = reg.get("queue") if reg.get("queue") != null else []
	var picked: Array = Fundraise.choose_from_register_queue(q, max_n)
	if picked.is_empty():
		return 0
	var total := 0
	for c in picked:
		if c == null or not is_instance_valid(c):
			continue
		var amount := int(c.call("payout_total")) if c.has_method("payout_total") else int(c.call("cart_total"))
		total += amount
		host._on_paid(amount, c.get("is_elite") == true, seat, null, false, c, true)
		c.finish_paid()
	host.release_player_checkout()
	var n := picked.size()
	host._play_banner_flash(
		Loc.t("log.demo.chives", [n]),
		Color(0.95, 0.92, 0.35, 1.0),
		56,
		Color(0.08, 0.12, 0.04, 0.55),
		0.85,
	)
	if host._player:
		host._player.log_line.emit(Loc.t("log.demo.chives_cash", [n, total]))
	return n


## Short skill feedback banner (攝石人 etc.).

func play_skill_banner(text: String) -> void:
	host._play_banner_flash(
		text,
		Color(0.85, 0.95, 1.0, 1.0),
		52,
		Color(0.04, 0.08, 0.14, 0.5),
		0.8,
	)


## Instant summon at door; ignore guest_cap. Returns how many guests spawned.

func cast_summon_guest(n: int) -> int:
	if SessionService.is_networked() and SessionService.is_client():
		return 0
	if host.phase != "open" or n <= 0:
		return 0
	var spawned := 0
	for _i in n:
		if host.state.sellable().is_empty():
			break
		if host._spawn_customer(true):
			spawned += 1
		else:
			break
	return spawned

func cast_guest_dusk() -> bool:
	## 諸客的黃昏: 30 real seconds, up to 15 successful guest entries (ignore cap).
	if SessionService.is_networked() and SessionService.is_client():
		return host.phase == "open"
	if host.phase != "open":
		clear_guest_dusk()
		return false
	host._guest_dusk_left = Skills.GUEST_DUSK_DURATION
	host._guest_dusk_remain = Skills.GUEST_DUSK_COUNT
	host._guest_dusk_in = 0.0
	return true

func clear_guest_dusk() -> void:
	host._guest_dusk_left = 0.0
	host._guest_dusk_remain = 0
	host._guest_dusk_in = 0.0

func cast_close_gate() -> void:
	## 落閘放狗：有貨清 shopping 排隊；空車離店；小偷掉贓離店（不計逃走）。
	if SessionService.is_networked() and SessionService.is_client():
		return
	if host._customers == null:
		return
	var queued := 0
	var left := 0
	var thieves := 0
	for c in host._customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## FloatText / other non-customer siblings: Object.get → null → bool()/int() crash.
		if not c.has_method("occupies_store"):
			continue
		if c.is_thief:
			var st: int = c.state
			if st == CustomerScript.State.FLEE:
				continue
			if c.has_method("drop_loot_and_leave"):
				c.call("drop_loot_and_leave")
			thieves += 1
			continue
		if not c.has_method("apply_close_gate"):
			continue
		var result := String(c.call("apply_close_gate"))
		if result == "leave":
			left += 1
		elif result == "queue":
			queued += 1
	host.release_player_checkout()
	if host._player:
		host._player.log_line.emit(Loc.t("demo.close_gate", [queued, left, thieves]))

func cast_three_volley() -> void:
	## Host resolves shopping and thief outcomes; clients only receive the volley visual.
	if SessionService.is_client() or host._customers == null or host._world == null:
		return
	var effect: Node2D = ThreeVolleyVisualScript.new()
	effect.name = "ThreeVolleyEffect"
	host._world.add_child(effect)
	effect.call("setup", host.FLOOR_ORIGIN, host.FLOOR_SIZE)
	_track_three_volley_visual(effect)
	host._register_net_agent(effect, "three_volley", {
		"ox": host.FLOOR_ORIGIN.x,
		"oy": host.FLOOR_ORIGIN.y,
		"fw": host.FLOOR_SIZE.x,
		"fh": host.FLOOR_SIZE.y,
	})
	var hit_thieves: Array[int] = []
	_resolve_three_volley_wave(hit_thieves)
	host._three_volley_casts.append({
		"until_next": 2.0,
		"waves_left": 2,
		"hit_thieves": hit_thieves,
		"effect": effect,
	})

func _track_three_volley_visual(effect: Node2D) -> void:
	host._three_volley_visuals.append(effect)
	effect.tree_exiting.connect(_on_three_volley_visual_exiting.bind(effect))

func _on_three_volley_visual_exiting(effect: Node2D) -> void:
	host._three_volley_visuals.erase(effect)

func _clear_three_volley() -> void:
	host._three_volley_casts.clear()
	for effect in host._three_volley_visuals.duplicate():
		if effect != null and is_instance_valid(effect):
			effect.queue_free()
	host._three_volley_visuals.clear()

func _tick_three_volley(delta: float) -> void:
	if host._three_volley_casts.is_empty():
		return
	for cast_i in range(host._three_volley_casts.size() - 1, -1, -1):
		var cast: Dictionary = host._three_volley_casts[cast_i]
		var until_next := float(cast.get("until_next", 0.0)) - delta
		var waves_left := int(cast.get("waves_left", 0))
		var hit_thieves: Array[int] = []
		var hit_thieves_v = cast.get("hit_thieves", [])
		if hit_thieves_v is Array:
			for thief_id_v in hit_thieves_v:
				hit_thieves.append(int(thief_id_v))
		while until_next <= 0.0 and waves_left > 0:
			_resolve_three_volley_wave(hit_thieves)
			waves_left -= 1
			until_next += 2.0
		if waves_left <= 0:
			host._three_volley_casts.remove_at(cast_i)
		else:
			cast["until_next"] = until_next
			cast["waves_left"] = waves_left
			cast["hit_thieves"] = hit_thieves
			host._three_volley_casts[cast_i] = cast

func _resolve_three_volley_wave(hit_thieves: Array[int]) -> void:
	if host._customers == null or not is_instance_valid(host._customers):
		return
	for target in host._customers.get_children():
		if target == null or not is_instance_valid(target):
			continue
		if target.has_method("is_active_thief") and bool(target.call("is_active_thief")):
			var thief_id := int(target.get_instance_id())
			if hit_thieves.has(thief_id):
				continue
			hit_thieves.append(thief_id)
			if target.has_method("drop_loot_and_leave"):
				target.call("drop_loot_and_leave")
			continue
		if not target.has_method("can_receive_delivery") or not bool(target.call("can_receive_delivery")):
			continue
		if target.get("temp_clerk") == true:
			continue
		var shopping_v = target.get("shopping")
		if not (shopping_v is Array) or shopping_v.is_empty():
			continue
		if target.has_method("accept_must_deliver"):
			target.call("accept_must_deliver", [String(shopping_v[0])])

