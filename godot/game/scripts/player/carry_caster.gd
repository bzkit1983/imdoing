extends RefCounted
## Short-press face Y / U → carry radial (select focus SKU).

const CarryMenuScript = preload("res://scripts/carry_menu.gd")

var host: CharacterBody2D
var menu: Node2D


func _init(p_host: CharacterBody2D) -> void:
	host = p_host


func ensure_menu() -> void:
	if menu != null and is_instance_valid(menu):
		return
	menu = CarryMenuScript.new()
	menu.name = "CarryMenu"
	menu.z_index = 40
	host.add_child(menu)
	menu.open = false


func on_carry_hold(pressed: bool) -> void:
	if pressed:
		if host._sick_left > 0.0 or host._stun_left > 0.0 or host._fighting:
			return
		if host.ult_prep:
			return
		if host.carry_menu_open and host._carry_latch:
			close_carry_menu()
			host._carry_release_ignore = true
			return
		if host.skill_menu_open and host.has_method("_close_skill_menu"):
			host._close_skill_menu()
		if host.bag_menu_open and host.has_method("_close_bag_menu"):
			host._close_bag_menu()
		if host.has_method("_in_dir_mode") and host._in_dir_mode() and not host.carry_menu_open:
			if host.command_lock or host._restock_picking:
				return
		if host.inventory == null or host.inventory.is_empty():
			return
		host._carry_held = true
		host._carry_time = 0.0
		host._carry_aim = CarryMenuScript.AIM_CANCEL
		return
	if host._carry_release_ignore:
		host._carry_release_ignore = false
		host._carry_held = false
		return
	if not host._carry_held:
		return
	if host.carry_menu_open and host._carry_latch:
		host._carry_held = false
		return
	host._carry_held = false
	if host.controls_locally():
		open_carry_menu(true)


func open_carry_menu(latch: bool = true) -> void:
	if host.inventory == null or host.inventory.is_empty():
		return
	if host.skill_menu_open and host.has_method("_close_skill_menu"):
		host._close_skill_menu()
	if host.bag_menu_open and host.has_method("_close_bag_menu"):
		host._close_bag_menu()
	ensure_menu()
	host.carry_menu_open = true
	host._carry_latch = latch
	host._carry_aim = CarryMenuScript.AIM_CANCEL
	host._move_locked_until_neutral = true
	host._running = false
	host.velocity = Vector2.ZERO
	if latch and (host.stick_axis.length() >= 0.42 or host._joy_stick_vector().length() >= 0.42):
		host._cardinal_armed = false
	if menu and host.controls_locally():
		menu.open = true
		_refresh_slots()
		menu.set_aim(CarryMenuScript.AIM_CANCEL)
	if host.controls_locally():
		SfxBus.play("sfx_skill_menu_open")
		host.log_line.emit(Loc.t("log.player.carry_menu_tap"))


func close_carry_menu() -> void:
	host._carry_held = false
	host._carry_time = 0.0
	host._carry_aim = CarryMenuScript.AIM_CANCEL
	host._carry_latch = false
	host.carry_menu_open = false
	if menu:
		menu.open = false
		menu.set_aim(CarryMenuScript.AIM_CANCEL)


func set_carry_aim(slot: int) -> void:
	if slot == host._carry_aim:
		if menu:
			menu.set_aim(slot)
		return
	host._carry_aim = slot
	if menu:
		menu.set_aim(slot)
	SfxBus.play("sfx_skill_menu_move")


func confirm_carry(slot: int) -> void:
	close_carry_menu()
	if slot < 0:
		return
	if host.inventory != null and host.inventory.has_method("set_focus_index"):
		host.inventory.set_focus_index(slot)
	if host._carry_strip != null and host._carry_strip.has_method("pulse"):
		host._carry_strip.pulse()
	if host.has_method("_mark_hud_dirty"):
		host._mark_hud_dirty()


func tick(_delta: float) -> void:
	if host.carry_menu_open and menu and host.controls_locally():
		_refresh_slots()
		menu.open = true


func _refresh_slots() -> void:
	if menu == null or host.inventory == null:
		return
	var g: Array = host.inventory.grouped() if host.inventory.has_method("grouped") else []
	menu.set_groups(g)
