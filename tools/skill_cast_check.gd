extends Node
## Headless: skill key opens the menu. It does not cast until a choice is confirmed.

const PlayerScript = preload("res://scripts/player.gd")
const Skills = preload("res://scripts/skills.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	var player: CharacterBody2D = PlayerScript.new()
	add_child(player)
	await get_tree().process_frame

	_short_open(player)
	_need(errors, player.skill_menu_open and player._skill_latch, "short tap opens the menu")
	_need(errors, not player._cd.has("carry_boost"), "short tap does not cast the center skill")
	_need(errors, int(player._menu.aim) == 0, "center slot starts highlighted")
	_need(errors, String(player._menu.names[0]) == "頂硬上", "center shows skill 1")
	_need(errors, String(player._menu.names[2]) == "金屬狂潮", "right shows skill 3")
	_need(errors, String(player._menu.names[4]) == "瞬間補貨", "left shows skill 5")

	player._try_dir(Skills.DIR_UP)
	_need(errors, not player.skill_menu_open, "direction on the tap menu closes it")
	_need(errors, player._cd.has("move_boost"), "up casts skill 2")
	_need(errors, not player._cd.has("carry_boost"), "up does not also cast the center")

	player._cd.clear()
	_short_open(player)
	player._on_skill_hold(true)
	_need(errors, player._cd.has("carry_boost"), "skill key again casts the center")
	_need(errors, not player.skill_menu_open, "second press closes the menu")
	player._on_skill_hold(false)
	_need(errors, not player.skill_menu_open and player._cd.size() == 1, "release after confirm does not reopen")

	player._cd.clear()
	player._on_skill_hold(true)
	player._open_skill_menu(false)
	player._try_dir(Skills.DIR_RIGHT)
	_need(errors, player.skill_menu_open, "direction while holding does not close")
	_need(errors, player._skill_aim == 2, "right previews skill 3")
	_need(errors, not player._cd.has("metal_rush"), "preview does not cast")
	player.stick_axis = Vector2.ZERO
	player._on_skill_hold(false)
	_need(errors, player._cd.has("carry_boost"), "release with no direction casts skill 1")
	_need(errors, not player._cd.has("metal_rush"), "center release does not cast the preview")
	_need(errors, not player.skill_menu_open, "hold release closes the menu")

	player._cd.clear()
	player._on_skill_hold(true)
	player._open_skill_menu(false)
	player.stick_axis = Vector2(1, 0)
	player._on_skill_hold(false)
	player.stick_axis = Vector2.ZERO
	_need(errors, player._cd.has("metal_rush"), "release while aiming right casts skill 3")
	_need(errors, not player._cd.has("carry_boost"), "aimed release does not also cast the center")

	player._cd.clear()
	_short_open(player)
	player._try_dir(Skills.DIR_DOWN)
	_need(errors, not player.skill_menu_open, "choosing a passive closes the menu")
	_need(errors, player._cd.is_empty(), "a passive slot does not start a cooldown")

	_short_open(player)
	player._cancel_input()
	_need(errors, not player.skill_menu_open and not player._skill_latch, "cancel closes the tap menu")
	_need(errors, player._cd.is_empty(), "cancel does not cast")

	player._on_skill_hold(true)
	player._open_skill_menu(false)
	player._set_skill_aim(4)
	player._cancel_input()
	player._on_skill_hold(false)
	_need(errors, player._cd.is_empty() and not player.skill_menu_open, "cancel during a hold does not cast on release")

	_need(errors, player._skill_aim_slot() == 0, "no direction aims at the center")

	if errors.is_empty():
		print("OK skill cast")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _short_open(player: Node) -> void:
	player._on_skill_hold(true)
	player._l_time = 0.05
	player._on_skill_hold(false)


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
