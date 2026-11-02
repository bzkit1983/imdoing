extends Node
## Headless: Xbox bindings match every pad id, including Windows device 1+.


func _ready() -> void:
	print("xbox pad check start")
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	Controls.ensure_actions()

	var joy_actions: Array[String] = [
		Controls.MOVE_UP, Controls.MOVE_DOWN, Controls.MOVE_LEFT, Controls.MOVE_RIGHT,
		Controls.INTERACT, Controls.CANCEL, Controls.DASH, Controls.SKILL, Controls.ULT,
		Controls.ROTATE,
	]
	for action in joy_actions:
		var saw_joy := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				saw_joy = true
				if ev.device != Controls.JOY_ALL_DEVICES:
					errors.append("%s joy device is %s, want -1" % [action, ev.device])
		if not saw_joy:
			errors.append("%s missing joy binding" % action)

	_feed_btn(1, JOY_BUTTON_A, true)
	_need(errors, Input.is_action_pressed(Controls.INTERACT), "pad 1 A matches interact")
	_feed_btn(1, JOY_BUTTON_A, false)
	_need(errors, not Input.is_action_pressed(Controls.INTERACT), "pad 1 A release clears interact")

	_feed_btn(0, JOY_BUTTON_X, true)
	_need(errors, Input.is_action_pressed(Controls.DASH), "pad 0 X matches dash")
	_feed_btn(0, JOY_BUTTON_X, false)

	_feed_btn(2, JOY_BUTTON_Y, true)
	_need(errors, Input.is_action_pressed(Controls.SKILL), "pad 2 Y matches skill")
	_feed_btn(2, JOY_BUTTON_Y, false)

	_feed_btn(1, JOY_BUTTON_RIGHT_SHOULDER, true)
	_need(errors, Input.is_action_pressed(Controls.ULT), "pad 1 RB matches ult")
	_feed_btn(1, JOY_BUTTON_RIGHT_SHOULDER, false)

	_feed_axis(1, JOY_AXIS_LEFT_X, 1.0)
	_need(errors, Input.is_action_pressed(Controls.MOVE_RIGHT), "pad 1 stick right matches move_right")
	_feed_axis(1, JOY_AXIS_LEFT_X, 0.0)
	_need(errors, not Input.is_action_pressed(Controls.MOVE_RIGHT), "pad 1 stick release clears move_right")

	_feed_axis(3, JOY_AXIS_LEFT_Y, -1.0)
	_need(errors, Input.is_action_pressed(Controls.MOVE_UP), "pad 3 stick up matches move_up")
	_feed_axis(3, JOY_AXIS_LEFT_Y, 0.0)

	## Stale Project Settings bind locked to device 0 (the old Windows miss).
	InputMap.action_erase_events(Controls.INTERACT)
	var stale := InputEventJoypadButton.new()
	stale.device = 0
	stale.button_index = JOY_BUTTON_A
	InputMap.action_add_event(Controls.INTERACT, stale)
	Controls.ensure_actions()
	for ev in InputMap.action_get_events(Controls.INTERACT):
		if ev is InputEventJoypadButton:
			_need(errors, ev.device == Controls.JOY_ALL_DEVICES, "stale device 0 A rewritten to -1")
	_feed_btn(1, JOY_BUTTON_A, true)
	_need(errors, Input.is_action_pressed(Controls.INTERACT), "rewritten bind still matches pad 1 A")
	_feed_btn(1, JOY_BUTTON_A, false)

	if errors.is_empty():
		print("joy InputMap device=-1 for move/interact/cancel/dash/skill/ult/rotate")
		print("pad 1 A -> interact; pad 0 X -> dash; pad 2 Y -> skill; pad 1 RB -> ult")
		print("pad 1 stick right -> move_right; pad 3 stick up -> move_up")
		print("stale device-0 A rewritten to -1 and still matches pad 1")
		print("OK xbox pad")
	else:
		for line in errors:
			print("FAIL xbox pad: ", line)
	get_tree().quit(0 if errors.is_empty() else 1)


func _need(errors: PackedStringArray, ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)


func _feed_btn(device: int, button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _feed_axis(device: int, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
