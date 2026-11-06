extends Node
## Registers and documents InputMap actions for the living game line.
## Defaults match the previous hardcoded WASD / J K L U / Xbox layout.
## If an action already has events (e.g. edited in Project Settings), defaults are left alone.

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
const ULT := "ult"
## Xbox shoulder hotkeys: LB=skill2, RB=skill3 (slots 1/2). LT/RT polled in player.
const SKILL_2 := "skill_2"
const SKILL_3 := "skill_3"
const ROTATE := "rotate"
const RESTOCK_PREV := "restock_prev"
const RESTOCK_NEXT := "restock_next"
const RESTOCK_SLOT_1 := "restock_slot_1"
const RESTOCK_SLOT_2 := "restock_slot_2"
const RESTOCK_SLOT_3 := "restock_slot_3"
## Cycle shop camera framing (normal / far / overview). Xbox View = JOY_BUTTON_BACK.
const CAMERA_VIEW := "camera_view"

## Analog trigger "pressed" threshold (Xbox LT/RT), after normalize to 0..1.
const TRIGGER_DEADZONE := 0.5
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

const HOLD_ACTIONS: Array[String] = [INTERACT, CANCEL, DASH, SKILL, ULT]
const MOVE_ACTIONS: Array[String] = [MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT]
const SKILL_SLOT_ACTIONS: Array[String] = [SKILL_2, SKILL_3]


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
	## Keyboard U only — Xbox ult is LT+RT long-press (polled). Touch still set_hold("ult").
	_ensure_action(ULT, 0.5, [_key(KEY_U)])
	_ensure_action(SKILL_2, 0.5, [_joy_btn(JOY_BUTTON_LEFT_SHOULDER)])
	_ensure_action(SKILL_3, 0.5, [_joy_btn(JOY_BUTTON_RIGHT_SHOULDER)])
	_migrate_xbox_skill_bindings()
	## Prep layout rotate — same physical defaults as dash (contexts do not overlap).
	_ensure_action(ROTATE, 0.5, [_key(KEY_K), _key(KEY_X), _joy_btn(JOY_BUTTON_X)])
	_ensure_action(RESTOCK_PREV, 0.5, [_key(KEY_Q)])
	_ensure_action(RESTOCK_NEXT, 0.5, [_key(KEY_E)])
	_ensure_action(RESTOCK_SLOT_1, 0.5, [_key(KEY_1)])
	_ensure_action(RESTOCK_SLOT_2, 0.5, [_key(KEY_2)])
	_ensure_action(RESTOCK_SLOT_3, 0.5, [_key(KEY_3)])
	_ensure_action(CAMERA_VIEW, 0.5, [_key(KEY_V), _joy_btn(JOY_BUTTON_BACK)])


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
		v += _dpad_on_device(joy)
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
	## Poll discrete edges per device / keyboard.
	if SeatTable.keyboard_owns_seat(seat):
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			## just_pressed needs edge; use InputMap only when keyboard owns seat — but
			## global just_pressed fires for everyone. Use raw echo-free via Input.
			pass
	## Fall back: use event path in player._input with event_for_seat filter.
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


## RB used to be ult; now RB=skill3 and Xbox ult is LT+RT. Fix saved Project Settings.
func _migrate_xbox_skill_bindings() -> void:
	if InputMap.has_action(ULT):
		var drop: Array[InputEvent] = []
		var has_u := false
		for ev in InputMap.action_get_events(ULT):
			if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				drop.append(ev)
			elif ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_U:
				has_u = true
		for ev2 in drop:
			InputMap.action_erase_event(ULT, ev2)
		if not has_u:
			InputMap.action_add_event(ULT, _key(KEY_U))
	_ensure_joy_btn(SKILL_2, JOY_BUTTON_LEFT_SHOULDER)
	_ensure_joy_btn(SKILL_3, JOY_BUTTON_RIGHT_SHOULDER)


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
