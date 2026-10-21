extends Node
## Registers and documents InputMap actions for the living game line.
## Defaults match the previous hardcoded WASD / J K L U / Xbox layout.
## If an action already has events (e.g. edited in Project Settings), defaults are left alone.

const MOVE_DEADZONE := 0.25

## Logical actions used by gameplay + prep UI.
const MOVE_UP := "move_up"
const MOVE_DOWN := "move_down"
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const INTERACT := "interact"
const CANCEL := "cancel"
const DASH := "dash"
const SKILL := "skill"
const ULT := "ult"
const ROTATE := "rotate"
const RESTOCK_PREV := "restock_prev"
const RESTOCK_NEXT := "restock_next"
const RESTOCK_SLOT_1 := "restock_slot_1"
const RESTOCK_SLOT_2 := "restock_slot_2"
const RESTOCK_SLOT_3 := "restock_slot_3"

const HOLD_ACTIONS: Array[String] = [INTERACT, CANCEL, DASH, SKILL, ULT]
const MOVE_ACTIONS: Array[String] = [MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT]


func _enter_tree() -> void:
	ensure_actions()


func ensure_actions() -> void:
	_ensure_action(MOVE_UP, MOVE_DEADZONE, [
		_key(KEY_W), _key(KEY_UP),
		_joy_btn(JOY_BUTTON_DPAD_UP),
		_joy_axis(JOY_AXIS_LEFT_Y, -1.0),
	])
	_ensure_action(MOVE_DOWN, MOVE_DEADZONE, [
		_key(KEY_S), _key(KEY_DOWN),
		_joy_btn(JOY_BUTTON_DPAD_DOWN),
		_joy_axis(JOY_AXIS_LEFT_Y, 1.0),
	])
	_ensure_action(MOVE_LEFT, MOVE_DEADZONE, [
		_key(KEY_A), _key(KEY_LEFT),
		_joy_btn(JOY_BUTTON_DPAD_LEFT),
		_joy_axis(JOY_AXIS_LEFT_X, -1.0),
	])
	_ensure_action(MOVE_RIGHT, MOVE_DEADZONE, [
		_key(KEY_D), _key(KEY_RIGHT),
		_joy_btn(JOY_BUTTON_DPAD_RIGHT),
		_joy_axis(JOY_AXIS_LEFT_X, 1.0),
	])
	_ensure_action(INTERACT, 0.5, [_key(KEY_J), _key(KEY_ENTER), _joy_btn(JOY_BUTTON_A)])
	_ensure_action(CANCEL, 0.5, [
		_key(KEY_SEMICOLON), _key(KEY_BACKSPACE), _key(KEY_ESCAPE),
		_joy_btn(JOY_BUTTON_B),
	])
	_ensure_action(DASH, 0.5, [_key(KEY_K), _joy_btn(JOY_BUTTON_X)])
	_ensure_action(SKILL, 0.5, [_key(KEY_L), _joy_btn(JOY_BUTTON_Y)])
	_ensure_action(ULT, 0.5, [_key(KEY_U), _joy_btn(JOY_BUTTON_RIGHT_SHOULDER)])
	## Prep layout rotate — same physical defaults as dash (contexts do not overlap).
	_ensure_action(ROTATE, 0.5, [_key(KEY_K), _key(KEY_X), _joy_btn(JOY_BUTTON_X)])
	_ensure_action(RESTOCK_PREV, 0.5, [_key(KEY_Q)])
	_ensure_action(RESTOCK_NEXT, 0.5, [_key(KEY_E)])
	_ensure_action(RESTOCK_SLOT_1, 0.5, [_key(KEY_1)])
	_ensure_action(RESTOCK_SLOT_2, 0.5, [_key(KEY_2)])
	_ensure_action(RESTOCK_SLOT_3, 0.5, [_key(KEY_3)])


func move_vector() -> Vector2:
	return Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN, MOVE_DEADZONE)


## Checkout / skill-menu cardinal: 0 up, 1 down, 2 left, 3 right. -1 if none.
func dir_just_pressed() -> int:
	if Input.is_action_just_pressed(MOVE_UP):
		return 0
	if Input.is_action_just_pressed(MOVE_DOWN):
		return 1
	if Input.is_action_just_pressed(MOVE_LEFT):
		return 2
	if Input.is_action_just_pressed(MOVE_RIGHT):
		return 3
	return -1


func dir_from_event(event: InputEvent) -> int:
	if event.is_action_pressed(MOVE_UP):
		return 0
	if event.is_action_pressed(MOVE_DOWN):
		return 1
	if event.is_action_pressed(MOVE_LEFT):
		return 2
	if event.is_action_pressed(MOVE_RIGHT):
		return 3
	return -1


func _ensure_action(action: String, deadzone: float, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	elif not is_zero_approx(InputMap.action_get_deadzone(action) - deadzone):
		InputMap.action_set_deadzone(action, deadzone)
	if not InputMap.action_get_events(action).is_empty():
		return
	for ev in events:
		InputMap.action_add_event(action, ev)


func _key(physical: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical
	return ev


func _joy_btn(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev
