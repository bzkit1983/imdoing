extends Node2D
## Timed full-shop turret that fulfills elite guests from warehouse stock.

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Shot = preload("res://scripts/elite_guest_cannon_shot.gd")
const DURATION := 30.0

var kind := "elite_guest_cannon"
var host: Node
var owner_seat: int = 0
var level: int = 3
var remaining: float = DURATION
var cooldown_left: float = 0.0
var dismissed: bool = false
var net_agent_id: int = -1
var net_puppet: bool = false
var _label: Label
var _visual: Node2D
var _barrel: Node2D


func is_net_puppet() -> bool:
	return net_puppet


func interval() -> float:
	match clampi(level, 1, 3):
		1:
			return 3.0
		2:
			return 2.0
		_:
			return 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 110
	_visual = preload("res://scripts/cannon_visual.gd").new()
	add_child(_visual)
	_barrel = _visual.barrel
	_label = Label.new()
	_label.position = Vector2(-108, 10)
	_label.size.x = 216
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.apply_label(_label, UiFont.WORLD)
	add_child(_label)
	refresh_label()


func refresh_level(new_level: int) -> void:
	level = clampi(new_level, 1, 3)
	remaining = DURATION
	dismissed = false
	refresh_label()
	if net_agent_id >= 0 and SessionService.is_networked() and SessionService.is_server():
		SessionService.broadcast_agent_state({
			"id": net_agent_id,
			"elite_guest_cannon_remaining": remaining,
			"level": level,
		})


func apply_net_refresh(seconds: float, new_level: int) -> void:
	if not net_puppet:
		return
	remaining = clampf(seconds, 0.0, DURATION)
	level = clampi(new_level, 1, 3)
	refresh_label()


func refresh_label() -> void:
	if is_instance_valid(_label):
		_label.text = Loc.t("elite_guest_cannon.status", [owner_seat + 1, level])
	if is_instance_valid(_visual) and _visual.has_method("set_ammo"):
		_visual.call("set_ammo", "")


func _guest_sku_if_available(guest: Node) -> String:
	if not is_instance_valid(guest) or not guest.get("is_elite") or guest.get("temp_clerk"):
		return ""
	if not guest.has_method("can_receive_delivery") or not bool(guest.call("can_receive_delivery")):
		return ""
	var shopping = guest.get("shopping")
	var game_state = host.get("state") if is_instance_valid(host) else null
	if not (shopping is Array) or game_state == null:
		return ""
	var stock = game_state.get("stock")
	if not (stock is Dictionary):
		return ""
	for raw_sku in shopping:
		var sku := String(raw_sku)
		if sku == "":
			continue
		var wanted := 0
		for requested in shopping:
			if String(requested) == sku:
				wanted += 1
		var reserved := int(host.call("elite_guest_cannon_reserved_count", guest, sku))
		if wanted <= reserved or int(stock.get(sku, 0)) <= 0:
			continue
		return sku
	return ""


func choose_target() -> Dictionary:
	if not is_instance_valid(host):
		return {}
	var customers = host.get("_customers")
	if not is_instance_valid(customers):
		return {}
	var best: Node2D = null
	var best_sku := ""
	var best_d := INF
	for candidate in customers.get_children():
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var sku := _guest_sku_if_available(candidate)
		if sku == "":
			continue
		var d: float = global_position.distance_squared_to(candidate.global_position)
		if d < best_d or (
			is_equal_approx(d, best_d)
			and (best == null or candidate.get_instance_id() < best.get_instance_id())
		):
			best = candidate
			best_sku = sku
			best_d = d
	return {"guest": best, "sku": best_sku} if best != null else {}


func _physics_process(delta: float) -> void:
	if net_puppet or dismissed or not is_instance_valid(host):
		return
	if str(host.get("phase")) not in ["open", "restock"]:
		return
	if host.has_method("asking_early_close") and host.call("asking_early_close"):
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		dismiss()
		return
	cooldown_left = maxf(0.0, cooldown_left - delta)
	var target_data := choose_target()
	if target_data.is_empty() or cooldown_left > 0.00001:
		return
	var guest: Node2D = target_data["guest"]
	var sku := String(target_data["sku"])
	if guest == null or not is_instance_valid(guest) or sku == "":
		return
	if not bool(host.call("reserve_elite_guest_cannon_need", guest, sku)):
		return
	var target_id := guest.get_instance_id()
	var game_state = host.get("state")
	if game_state == null or not bool(game_state.call("consume_stock", sku, 1)):
		host.call("release_elite_guest_cannon_need", target_id, sku)
		return
	var shot: Node2D = Shot.new()
	shot.host = host
	shot.target = guest
	shot.owner_seat = owner_seat
	shot.reservation_target_id = target_id
	shot.setup(sku, global_position, guest.global_position, Tuning.DROP_FLIGHT_SEC, 1)
	host.get("_world").add_child(shot)
	if SessionService.is_networked() and SessionService.is_server():
		SessionService.broadcast_flight({
			"sku": sku,
			"n": 1,
			"fx": global_position.x,
			"fy": global_position.y,
			"tx": guest.global_position.x,
			"ty": guest.global_position.y,
			"dur": Tuning.DROP_FLIGHT_SEC,
		})
	if is_instance_valid(_visual) and _visual.has_method("fire"):
		_visual.call("fire")
	SfxBus.play("sfx_box_toss")
	cooldown_left = interval()


func dismiss() -> void:
	if dismissed:
		return
	dismissed = true
	queue_free()
