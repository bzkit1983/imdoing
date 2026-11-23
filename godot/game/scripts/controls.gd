extends Node
## Registers and documents InputMap actions for the living game line.
## Xbox ↔ keyboard (ops): A/H, B/J, X/Space, Y/U, LB/Y-key, RB/I, LT+RT/K.
## If an action already has events, migrations rewrite to the current defaults.

const MOVE_DEADZONE := 0.25
## InputMap: -1 matches every connected pad. Windows Xbox often is not device 0
## (XInput + DirectInput / a ghost pad at 0); macOS usually is 0.
const JOY_ALL_DEVICES := -1

## Logical actions used by gameplay + prep UI.
const MOVE_UP := "move_up"
const MOVE_DOWN := "move_down"
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const INTERACT := "interact"
const CANCEL := "cancel"
const DASH := "dash"
const SKILL := "skill"
## Short-press opens ops bag radial (Xbox RB / keyboard I).
const BAG_MENU := "bag_menu"
## Short-press opens carry radial (Xbox face Y / keyboard U).
const CARRY_MENU := "carry_menu"
const ULT := "ult"
## Legacy action names kept for menu/touch; no default binds.
const SKILL_2 := "skill_2"
const SKILL_3 := "skill_3"
## Carry ±1 removed from defaults (select via carry radial). Actions kept for API.
const CARRY_PREV := "carry_prev"
const CARRY_NEXT := "carry_next"
const ROTATE := "rotate"
const RESTOCK_PREV := "restock_prev"
const RESTOCK_NEXT := "restock_next"
const RESTOCK_SLOT_1 := "restock_slot_1"
const RESTOCK_SLOT_2 := "restock_slot_2"
const RESTOCK_SLOT_3 := "restock_slot_3"
## Ops item bag slots — keyboard 1–4 only; no D-Pad (main path = bag radial).
const BAG_SLOT_UP := "bag_slot_up"
const BAG_SLOT_RIGHT := "bag_slot_right"
const BAG_SLOT_DOWN := "bag_slot_down"
const BAG_SLOT_LEFT := "bag_slot_left"
## Cycle shop camera framing (normal / far / overview). Xbox View = JOY_BUTTON_BACK.
const CAMERA_VIEW := "camera_view"

const BAG_SLOT_ACTIONS: Array[String] = [
	BAG_SLOT_UP, BAG_SLOT_RIGHT, BAG_SLOT_DOWN, BAG_SLOT_LEFT,
]

## Analog trigger press threshold (Xbox LT/RT), after normalize to 0..1.
const TRIGGER_PRESS := 0.20
## Release hysteresis: stay down until below this (avoids chatter near press).
const TRIGGER_RELEASE := 0.08
## Must stay below RELEASE this long before a press cycle ends (kills 1-frame axis dips).
const TRIGGER_RELEASE_CONFIRM_SEC := 0.05
## Alias for older call sites; prefer TRIGGER_PRESS + trigger_latched().
const TRIGGER_DEADZONE := TRIGGER_PRESS
## Solo LT/RT waits this long before casting so LT+RT can form an ult chord.
const TRIGGER_SKILL_GRACE := 0.1
## HTML5 Standard Gamepad: buttons[6]/[7] are LT/RT (Godot uses the same indices on Web).
const WEB_BTN_LT := 6
const WEB_BTN_RT := 7
## Stick vs trigger alias epsilon (Web often exposes only 4 axes; axis 4/5 can mirror stick).
const TRIGGER_ALIAS_EPS := 0.15
const TRIGGER_ALIAS_STICK_MIN := 0.35
## Web: while left stick is this far out, never trust axis LT/RT (deep diagonal → false ult).
const WEB_STICK_SUPPRESS_AXIS_TRIGGERS := 0.45

## device_id → once true, axis LT/RT stay ignored (buttons 6/7 only on Web).
var _web_axis_triggers_untrusted: Dictionary = {}

const HOLD_ACTIONS: Array[String] = [INTERACT, CANCEL, DASH, SKILL, BAG_MENU, CARRY_MENU, ULT]
const MOVE_ACTIONS: Array[String] = [MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT]
const SKILL_SLOT_ACTIONS: Array[String] = [SKILL_2, SKILL_3]


func _enter_tree() -> void:
	ensure_actions()


func ensure_actions() -> void:
	## Ops loco: keyboard + left stick only. No D-Pad.
	_ensure_action(MOVE_UP, MOVE_DEADZONE, [
		_key(KEY_W), _key(KEY_UP),
		_joy_axis(JOY_AXIS_LEFT_Y, -1.0),
	])
	_ensure_action(MOVE_DOWN, MOVE_DEADZONE, [
		_key(KEY_S), _key(KEY_DOWN),
		_joy_axis(JOY_AXIS_LEFT_Y, 1.0),
	])
	_ensure_action(MOVE_LEFT, MOVE_DEADZONE, [
		_key(KEY_A), _key(KEY_LEFT),
		_joy_axis(JOY_AXIS_LEFT_X, -1.0),
	])
	_ensure_action(MOVE_RIGHT, MOVE_DEADZONE, [
		_key(KEY_D), _key(KEY_RIGHT),
		_joy_axis(JOY_AXIS_LEFT_X, 1.0),
	])
	_ensure_action(INTERACT, 0.5, [_key(KEY_H), _key(KEY_ENTER), _joy_btn(JOY_BUTTON_A)])
	_ensure_action(CANCEL, 0.5, [
		_key(KEY_J), _key(KEY_BACKSPACE),
		_joy_btn(JOY_BUTTON_B),
	])
	## Esc opens pause (pause_menu); must not be cancel or player _input eats it first.
	_erase_key(CANCEL, KEY_ESCAPE)
	_ensure_action(DASH, 0.5, [_key(KEY_SPACE), _joy_btn(JOY_BUTTON_X)])
	_ensure_action(SKILL, 0.5, [_key(KEY_Y), _joy_btn(JOY_BUTTON_LEFT_SHOULDER)])
	_ensure_action(BAG_MENU, 0.5, [_key(KEY_I), _joy_btn(JOY_BUTTON_RIGHT_SHOULDER)])
	_ensure_action(CARRY_MENU, 0.5, [_key(KEY_U), _joy_btn(JOY_BUTTON_Y)])
	## Keyboard K — Xbox ult is LT+RT long-press (polled). Touch still set_hold("ult").
	_ensure_action(ULT, 0.5, [_key(KEY_K)])
	_ensure_action(SKILL_2, 0.5, [])
	_ensure_action(SKILL_3, 0.5, [])
	## Carry ±1 unbound by default.
	_ensure_action(CARRY_PREV, 0.5, [])
	_ensure_action(CARRY_NEXT, 0.5, [])
	## Prep rotate: keyboard R; face Y in prep only (ops face Y = carry_menu).
	_ensure_action(ROTATE, 0.5, [_key(KEY_R), _joy_btn(JOY_BUTTON_Y)])
	_ensure_action(RESTOCK_PREV, 0.5, [_key(KEY_Q)])
	_ensure_action(RESTOCK_NEXT, 0.5, [_key(KEY_E)])
	_ensure_action(RESTOCK_SLOT_1, 0.5, [_key(KEY_1)])
	_ensure_action(RESTOCK_SLOT_2, 0.5, [_key(KEY_2)])
	_ensure_action(RESTOCK_SLOT_3, 0.5, [_key(KEY_3)])
	## Keyboard digits only — no D-Pad.
	_ensure_action(BAG_SLOT_UP, 0.5, [_key(KEY_1)])
	_ensure_action(BAG_SLOT_RIGHT, 0.5, [_key(KEY_2)])
	_ensure_action(BAG_SLOT_DOWN, 0.5, [_key(KEY_3)])
	_ensure_action(BAG_SLOT_LEFT, 0.5, [_key(KEY_4)])
	_ensure_action(CAMERA_VIEW, 0.5, [_key(KEY_V), _joy_btn(JOY_BUTTON_BACK)])
	_migrate_ops_remap_v2()


func move_vector() -> Vector2:
	return Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN, MOVE_DEADZONE)


## Per-seat move (M1 coop). Solo falls back to global move_vector().
func move_vector_for(seat: int) -> Vector2:
	if not _coop():
		return move_vector()
	var v := Vector2.ZERO
	var joy := SeatTable.joy_device_for_seat(seat)
	if joy >= 0:
		v += _stick_on_device(joy, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if SeatTable.keyboard_owns_seat(seat):
		v += _keyboard_move_vector()
	## Same deadzone as Input.get_vector / solo path — raw axes drift otherwise.
	if v.length() < MOVE_DEADZONE:
		return Vector2.ZERO
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


## Left stick only — excludes keyboard / d-pad so menu `_process` polling
## does not double-fire with `_unhandled_input` action presses (esp. Web).
## Uses the strongest deflection among connected pads so a Windows ghost
## device at index 0 cannot hide the real Xbox stick.
func stick_vector() -> Vector2:
	return _best_stick_vector(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)


func stick_vector_for(seat: int) -> Vector2:
	if not _coop():
		return stick_vector()
	var joy := SeatTable.joy_device_for_seat(seat)
	if joy < 0:
		return Vector2.ZERO
	var v := _stick_on_device(joy, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if v.length() < MOVE_DEADZONE:
		return Vector2.ZERO
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func trigger_values_for(seat: int) -> Vector2:
	if not _coop():
		return trigger_values()
	var joy := SeatTable.joy_device_for_seat(seat)
	if joy < 0:
		return Vector2.ZERO
	return _trigger_values_on_device(joy)


## Digitalize analog LT/RT with press/release hysteresis.
func trigger_latched(value: float, was_down: bool) -> bool:
	if was_down:
		return value >= TRIGGER_RELEASE
	return value >= TRIGGER_PRESS


## True if this event should drive the given seat (coop) or any seat (solo).
func event_for_seat(event: InputEvent, seat: int) -> bool:
	if not _coop():
		return true
	if event is InputEventKey:
		return SeatTable.keyboard_owns_seat(seat)
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var joy := SeatTable.joy_device_for_seat(seat)
		if joy < 0:
			return false
		return int(event.device) == joy
	return false


func dir_just_pressed_for(seat: int) -> int:
	if not _coop():
		return dir_just_pressed()
	return -1


func _coop() -> bool:
	var st := get_node_or_null("/root/SeatTable")
	return st != null and bool(st.call("is_coop"))


func _keyboard_move_vector() -> Vector2:
	var x := 0.0
	var y := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		y += 1.0
	return Vector2(x, y)


func _stick_on_device(device: int, axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	return Vector2(
		Input.get_joy_axis(device, axis_x),
		Input.get_joy_axis(device, axis_y)
	)


func _dpad_on_device(device: int) -> Vector2:
	## Kept for rare debug callers; ops InputMap does not bind D-Pad.
	var x := 0.0
	var y := 0.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		x -= 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		x += 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
		y -= 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
		y += 1.0
	return Vector2(x, y)


func _trigger_values_on_device(device: int) -> Vector2:
	var on_web := OS.has_feature("web")
	var lx := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var ly := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	var stick_len := Vector2(lx, ly).length()
	var raw_lt := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
	var raw_rt := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)
	var lt := _normalize_trigger_axis(raw_lt)
	var rt := _normalize_trigger_axis(raw_rt)
	var aliased := _triggers_alias_left_stick(raw_lt, raw_rt, lx, ly)
	if aliased:
		_web_axis_triggers_untrusted[device] = true
	var untrusted := bool(_web_axis_triggers_untrusted.get(device, false))
	if on_web and (untrusted or stick_len >= WEB_STICK_SUPPRESS_AXIS_TRIGGERS):
		lt = 0.0
		rt = 0.0
	elif aliased:
		lt = 0.0
		rt = 0.0
	if on_web:
		lt = maxf(lt, _web_trigger_button(device, true))
		rt = maxf(rt, _web_trigger_button(device, false))
	return Vector2(lt, rt)


## Right stick — not on move_* InputMap; menus (pause) poll this explicitly.
func right_stick_vector() -> Vector2:
	return _best_stick_vector(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)


## Stronger of left / right sticks for UI navigation.
func menu_stick_vector() -> Vector2:
	var left := stick_vector()
	var right := right_stick_vector()
	return right if right.length_squared() > left.length_squared() else left


func _best_stick_vector(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	var best := Vector2.ZERO
	var best_len_sq := 0.0
	for device in Input.get_connected_joypads():
		var v := Vector2(
			Input.get_joy_axis(device, axis_x),
			Input.get_joy_axis(device, axis_y)
		)
		var len_sq := v.length_squared()
		if len_sq > best_len_sq:
			best = v
			best_len_sq = len_sq
	return best


## Checkout / skill-menu / prep cardinal: 0 up, 1 down, 2 left, 3 right. -1 if none.
## Stick + keyboard / arrows only — no D-Pad InputMap.
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


## Bag cross index: 0 up, 1 right, 2 down, 3 left. -1 if none.
func bag_slot_from_event(event: InputEvent) -> int:
	if event.is_action_pressed(BAG_SLOT_UP):
		return 0
	if event.is_action_pressed(BAG_SLOT_RIGHT):
		return 1
	if event.is_action_pressed(BAG_SLOT_DOWN):
		return 2
	if event.is_action_pressed(BAG_SLOT_LEFT):
		return 3
	return -1


func _ensure_action(action: String, deadzone: float, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	elif not is_zero_approx(InputMap.action_get_deadzone(action) - deadzone):
		InputMap.action_set_deadzone(action, deadzone)
	var existing := InputMap.action_get_events(action)
	if existing.is_empty():
		for ev in events:
			InputMap.action_add_event(action, ev)
		return
	## Project Settings may keep which buttons are bound, but a saved
	## device 0 filter still drops Windows Xbox pads that are not index 0.
	for ev in existing:
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			if ev.device != JOY_ALL_DEVICES:
				ev.device = JOY_ALL_DEVICES


## Full ops remap: Xbox face/shoulders + aligned keyboard; strip D-Pad everywhere.
func _migrate_ops_remap_v2() -> void:
	_strip_all_dpad_binds()
	## Interact: A / H / Enter (was J).
	_erase_key(INTERACT, KEY_J)
	_ensure_key(INTERACT, KEY_H)
	_ensure_key(INTERACT, KEY_ENTER)
	_ensure_joy_btn(INTERACT, JOY_BUTTON_A)
	## Cancel: B / J / Backspace (was ;).
	_erase_key(CANCEL, KEY_SEMICOLON)
	_ensure_key(CANCEL, KEY_J)
	_ensure_key(CANCEL, KEY_BACKSPACE)
	_ensure_joy_btn(CANCEL, JOY_BUTTON_B)
	_erase_key(CANCEL, KEY_ESCAPE)
	## Dash: X / Space (was K; pad was RT poll).
	_erase_key(DASH, KEY_K)
	_ensure_key(DASH, KEY_SPACE)
	_ensure_joy_btn(DASH, JOY_BUTTON_X)
	## Skill: LB / letter Y (was face Y / L).
	_erase_joy_btn(SKILL, JOY_BUTTON_Y)
	_erase_key(SKILL, KEY_L)
	_ensure_key(SKILL, KEY_Y)
	_ensure_joy_btn(SKILL, JOY_BUTTON_LEFT_SHOULDER)
	## Bag: RB / I (was face X).
	_erase_joy_btn(BAG_MENU, JOY_BUTTON_X)
	_ensure_key(BAG_MENU, KEY_I)
	_ensure_joy_btn(BAG_MENU, JOY_BUTTON_RIGHT_SHOULDER)
	## Carry radial: face Y / U.
	_ensure_key(CARRY_MENU, KEY_U)
	_ensure_joy_btn(CARRY_MENU, JOY_BUTTON_Y)
	## Ult: K only on keyboard (was U); pad stays LT+RT poll.
	_erase_key(ULT, KEY_U)
	_erase_joy_btn(ULT, JOY_BUTTON_RIGHT_SHOULDER)
	_ensure_key(ULT, KEY_K)
	## Clear carry ±1 and shoulder leftovers.
	_clear_action_events(CARRY_PREV)
	_clear_action_events(CARRY_NEXT)
	_erase_joy_btn(SKILL_2, JOY_BUTTON_LEFT_SHOULDER)
	_erase_joy_btn(SKILL_3, JOY_BUTTON_RIGHT_SHOULDER)
	## Rotate: R + face Y (prep); drop old K / face X.
	_erase_key(ROTATE, KEY_K)
	_erase_key(ROTATE, KEY_X)
	_erase_joy_btn(ROTATE, JOY_BUTTON_X)
	_ensure_key(ROTATE, KEY_R)
	_ensure_joy_btn(ROTATE, JOY_BUTTON_Y)


func _strip_all_dpad_binds() -> void:
	var dpad_btns: Array[int] = [
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	]
	var actions: Array[String] = []
	actions.append_array(MOVE_ACTIONS)
	actions.append_array(BAG_SLOT_ACTIONS)
	actions.append_array([CARRY_PREV, CARRY_NEXT, SKILL, BAG_MENU, CARRY_MENU, DASH, INTERACT, CANCEL, ULT, ROTATE])
	for action in actions:
		if not InputMap.has_action(action):
			continue
		var drop: Array[InputEvent] = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton and int(ev.button_index) in dpad_btns:
				drop.append(ev)
		for ev2 in drop:
			InputMap.action_erase_event(action, ev2)


func _clear_action_events(action: String) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, ev)


func _erase_joy_btn(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	var drop: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			drop.append(ev)
	for ev2 in drop:
		InputMap.action_erase_event(action, ev2)


func _erase_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		return
	var drop: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == keycode:
			drop.append(ev)
	for ev2 in drop:
		InputMap.action_erase_event(action, ev2)


func _ensure_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == keycode:
			return
	InputMap.action_add_event(action, _key(keycode))


func _ensure_joy_btn(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			if ev.device != JOY_ALL_DEVICES:
				ev.device = JOY_ALL_DEVICES
			return
	InputMap.action_add_event(action, _joy_btn(button))


## Strongest LT/RT deflection across connected pads, normalized to 0..1.
## Web safety: axis 4/5 often alias the left stick (4-axis pads). Deep stick
## (especially diagonal) then reads as LT+RT and false-starts ult. Ignore bad
## axes and use Standard Gamepad buttons 6/7 instead.
func trigger_values() -> Vector2:
	var best_lt := 0.0
	var best_rt := 0.0
	var on_web := OS.has_feature("web")
	for device in Input.get_connected_joypads():
		var lx := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		var ly := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		var stick_len := Vector2(lx, ly).length()
		var raw_lt := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
		var raw_rt := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)
		var lt := _normalize_trigger_axis(raw_lt)
		var rt := _normalize_trigger_axis(raw_rt)
		var aliased := _triggers_alias_left_stick(raw_lt, raw_rt, lx, ly)
		if aliased:
			_web_axis_triggers_untrusted[device] = true
		var untrusted := bool(_web_axis_triggers_untrusted.get(device, false))
		## Web: suppress axis triggers while stick is deflected, or forever once aliased.
		## Real LT/RT still come from buttons 6/7 below.
		if on_web and (untrusted or stick_len >= WEB_STICK_SUPPRESS_AXIS_TRIGGERS):
			lt = 0.0
			rt = 0.0
		elif aliased:
			lt = 0.0
			rt = 0.0
		if on_web:
			lt = maxf(lt, _web_trigger_button(device, true))
			rt = maxf(rt, _web_trigger_button(device, false))
		best_lt = maxf(best_lt, lt)
		best_rt = maxf(best_rt, rt)
	return Vector2(best_lt, best_rt)


## Map raw axis to 0..1. Handles rest-at-0 and rest-at--1 (SDL / some pads).
func _normalize_trigger_axis(raw: float) -> float:
	if raw < -0.01:
		return clampf((raw + 1.0) * 0.5, 0.0, 1.0)
	return clampf(raw, 0.0, 1.0)


## True when LT/RT axis pair is clearly the left stick (Web 4-axis alias bug).
func _triggers_alias_left_stick(raw_lt: float, raw_rt: float, lx: float, ly: float) -> bool:
	if Vector2(lx, ly).length() < TRIGGER_ALIAS_STICK_MIN:
		return false
	var match_xy := (
		absf(raw_lt - lx) <= TRIGGER_ALIAS_EPS and absf(raw_rt - ly) <= TRIGGER_ALIAS_EPS
	)
	var match_yx := (
		absf(raw_lt - ly) <= TRIGGER_ALIAS_EPS and absf(raw_rt - lx) <= TRIGGER_ALIAS_EPS
	)
	## Also catch near-match on magnitude (browser axis noise at full deflection).
	var as_stick := Vector2(raw_lt, raw_rt)
	var stick := Vector2(lx, ly)
	var near := as_stick.distance_to(stick) <= TRIGGER_ALIAS_EPS * 2.0
	var near_swap := as_stick.distance_to(Vector2(ly, lx)) <= TRIGGER_ALIAS_EPS * 2.0
	return match_xy or match_yx or near or near_swap


func _web_trigger_button(device: int, left: bool) -> float:
	var btn := WEB_BTN_LT if left else WEB_BTN_RT
	if Input.is_joy_button_pressed(device, btn):
		return 1.0
	return 0.0


func _key(physical: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical
	return ev


func _joy_btn(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = JOY_ALL_DEVICES
	ev.button_index = button
	return ev


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.device = JOY_ALL_DEVICES
	ev.axis = axis
	ev.axis_value = value
	return ev
