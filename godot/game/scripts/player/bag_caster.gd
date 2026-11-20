extends RefCounted
## Hold X / I → ops bag radial around player (center ❌ cancel).

const BagMenuScript = preload("res://scripts/bag_menu.gd")
const OpsItems = preload("res://scripts/ops_items.gd")
const Skills = preload("res://scripts/skills.gd")

var host: CharacterBody2D
var menu: Node2D


func _init(p_host: CharacterBody2D) -> void:
	host = p_host


func ensure_menu() -> void:
	if menu != null and is_instance_valid(menu):
		return
	menu = BagMenuScript.new()
	menu.name = "BagMenu"
	menu.z_index = 40
	host.add_child(menu)
	menu.open = false


func on_bag_hold(pressed: bool) -> void:
	if pressed:
		if host._sick_left > 0.0 or host._stun_left > 0.0 or host._fighting:
			return
		if host.skill_menu_open or host.ult_prep:
			return
		if host.has_method("_in_dir_mode") and host._in_dir_mode() and not host.bag_menu_open:
			## Don't steal checkout etc. unless already in bag menu.
			if host.command_lock or host._restock_picking:
				return
		host._bag_held = true
		host._bag_time = 0.0
		host._bag_aim = BagMenuScript.AIM_CANCEL
		return
	if host._bag_release_ignore:
		host._bag_release_ignore = false
		host._bag_held = false
		return
	if not host._bag_held:
		return
	if host.bag_menu_open:
		if SessionService.is_networked() and SessionService.is_server() and not host.controls_locally():
			close_bag_menu()
			return
		sync_hold_aim()
		confirm_bag(host._bag_aim)
		return
	var short: bool = float(host._bag_time) < Skills.HOLD_MENU_SEC
	host._bag_held = false
	if short:
		## Short tap on bag button: no-op (plan).
		return


func open_bag_menu() -> void:
	if host.skill_menu_open and host.has_method("_close_skill_menu"):
		host._close_skill_menu()
	ensure_menu()
	host.bag_menu_open = true
	host._bag_aim = BagMenuScript.AIM_CANCEL
	host._move_locked_until_neutral = true
	host._running = false
	host.velocity = Vector2.ZERO
	if menu and host.controls_locally():
		menu.open = true
		_refresh_slots()
		menu.set_aim(BagMenuScript.AIM_CANCEL)
	if host.controls_locally():
		SfxBus.play("sfx_skill_menu_open")


func close_bag_menu() -> void:
	host._bag_held = false
	host._bag_time = 0.0
	host._bag_aim = BagMenuScript.AIM_CANCEL
	host.bag_menu_open = false
	if menu:
		menu.open = false
		menu.set_aim(BagMenuScript.AIM_CANCEL)


func sync_hold_aim() -> void:
	set_bag_aim(BagMenuScript.aim_from_stick(_stick()))


func set_bag_aim(slot: int) -> void:
	if slot == host._bag_aim:
		if menu:
			menu.set_aim(slot)
		return
	host._bag_aim = slot
	if menu:
		menu.set_aim(slot)
	SfxBus.play("sfx_skill_menu_move")


func confirm_bag(slot: int) -> void:
	close_bag_menu()
	if slot < 0:
		return
	if host.has_method("_try_use_ops_bag_slot"):
		host._try_use_ops_bag_slot(slot)


func tick(delta: float) -> void:
	if host._bag_held and host._sick_left <= 0.0 and host._stun_left <= 0.0:
		host._bag_time += delta
		if not host.bag_menu_open and float(host._bag_time) >= Skills.HOLD_MENU_SEC:
			open_bag_menu()
		if host.bag_menu_open:
			sync_hold_aim()
	if host.bag_menu_open and menu and host.controls_locally():
		_refresh_slots()
		menu.open = true


func _refresh_slots() -> void:
	if menu == null:
		return
	var bag: Array = host.ops_bag_ids() if host.has_method("ops_bag_ids") else []
	menu.set_bag(bag, OpsItems.unlocked_count())


func _stick() -> Vector2:
	return host._move_vector() + host.stick_axis
