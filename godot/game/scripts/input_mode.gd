extends Node
## Active input device + whether the on-screen TouchPad should show.
## Modes: touch (VJ) / physical gamepad / keyboard. Pref + platform gate VJ.

enum Mode { TOUCH, GAMEPAD, KEYBOARD }

signal mode_changed(mode: int)
signal show_vj_changed(visible: bool)
## Demo / player should release all virtual holds when VJ hides mid-press.
signal clear_virtual_holds

var _mode: int = Mode.TOUCH
var _show_vj: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if PlatformServices.wants_touch_pad():
		_mode = Mode.TOUCH
	else:
		_mode = Mode.KEYBOARD
	if not PlatformServices.virtual_stick_changed.is_connected(_on_pref_changed):
		PlatformServices.virtual_stick_changed.connect(_on_pref_changed)
	_recompute_show(false)


func get_mode() -> int:
	return _mode


func is_touch() -> bool:
	return _mode == Mode.TOUCH


func is_gamepad() -> bool:
	return _mode == Mode.GAMEPAD


func is_keyboard() -> bool:
	return _mode == Mode.KEYBOARD


## Prefer this over PlatformServices.show_touch_pad() for live visibility.
func show_vj() -> bool:
	return _show_vj


func note_touch() -> void:
	_set_mode(Mode.TOUCH)


func note_gamepad() -> void:
	_set_mode(Mode.GAMEPAD)


func note_keyboard() -> void:
	_set_mode(Mode.KEYBOARD)


## Player turned VJ on in Prep/Pause — treat as touch so chrome can appear now.
func prefer_touch_for_vj() -> void:
	if PlatformServices.is_virtual_stick_enabled():
		_set_mode(Mode.TOUCH)


func _on_pref_changed(enabled: bool) -> void:
	if enabled:
		prefer_touch_for_vj()
	_recompute_show(true)


func _set_mode(next: int) -> void:
	if next == _mode:
		_recompute_show(false)
		return
	_mode = next
	mode_changed.emit(_mode)
	_recompute_show(true)


func _recompute_show(emit_holds_if_hide: bool) -> void:
	## Pref + active touch mode. No platform gate so Desktop editor can preview VJ
	## after the player opts in (default pref remains off).
	var next := PlatformServices.is_virtual_stick_enabled() and _mode == Mode.TOUCH
	if next == _show_vj:
		return
	var was := _show_vj
	_show_vj = next
	show_vj_changed.emit(_show_vj)
	if was and not _show_vj and emit_holds_if_hide:
		clear_virtual_holds.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			note_touch()
		return
	if event is InputEventScreenDrag:
		note_touch()
		return
	## Mouse / emulated touch counts as touch so Desktop can preview VJ after opt-in.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		note_touch()
		return
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			note_gamepad()
		return
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if absf(jm.axis_value) >= 0.55:
			note_gamepad()
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and _is_gameplay_key(k.physical_keycode):
			note_keyboard()


func _is_gameplay_key(code: Key) -> bool:
	match code:
		KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			return true
		KEY_J, KEY_K, KEY_L, KEY_U, KEY_ENTER, KEY_SEMICOLON, KEY_BACKSPACE, KEY_ESCAPE:
			return true
		KEY_Q, KEY_E, KEY_X, KEY_1, KEY_2, KEY_3:
			return true
		_:
			return false
