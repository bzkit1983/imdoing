extends CanvasLayer
## In-day pause overlay. process_mode ALWAYS so it works while the tree is paused.
## Opened by Esc / Start / HUD pause button or PlatformServices.pause_menu_requested (suspend).

const UiFont = preload("res://scripts/ui_font.gd")

signal resume_requested
signal end_day_requested

const FOCUS_RESUME := 0
const FOCUS_SFX := 1
const FOCUS_VOL := 2
const FOCUS_END := 3
const FOCUS_COUNT := 4

var game: Node
var _open: bool = false
var _focus: int = 0
var _from_suspend: bool = false

@onready var _shade: ColorRect = %Shade
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _hint: Label = %Hint
@onready var _resume_btn: Button = %ResumeBtn
@onready var _sfx_btn: Button = %SfxBtn
@onready var _vol_btn: Button = %VolBtn
@onready var _vol_down: Button = %VolDownBtn
@onready var _vol_up: Button = %VolUpBtn
@onready var _end_btn: Button = %EndDayBtn


func setup(host: Node) -> void:
	game = host
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_open = false
	UiFont.apply_label(_title, 40)
	_title.add_theme_color_override("font_color", Color("f4d35e"))
	UiFont.apply_label(_body, 24)
	_body.add_theme_color_override("font_color", Color("f4f1ea"))
	UiFont.apply_label(_hint, 20)
	_hint.add_theme_color_override("font_color", Color("c8c2b4"))
	for b in [_resume_btn, _sfx_btn, _vol_btn, _vol_down, _vol_up, _end_btn]:
		UiFont.apply_button(b, 22)
		b.focus_mode = Control.FOCUS_NONE
	_resume_btn.pressed.connect(_on_resume)
	_sfx_btn.pressed.connect(_on_sfx_toggle)
	_vol_btn.pressed.connect(_on_vol_preview)
	_vol_down.pressed.connect(_on_vol_nudge.bind(-1))
	_vol_up.pressed.connect(_on_vol_nudge.bind(1))
	_end_btn.pressed.connect(_on_end_day)
	_paint_focus()
	_refresh_audio_labels()
	if not PlatformServices.pause_menu_requested.is_connected(_on_platform_pause_requested):
		PlatformServices.pause_menu_requested.connect(_on_platform_pause_requested)
	if not PlatformServices.suspended.is_connected(_on_platform_suspended):
		PlatformServices.suspended.connect(_on_platform_suspended)
	if not PlatformServices.resumed.is_connected(_on_platform_resumed):
		PlatformServices.resumed.connect(_on_platform_resumed)


func is_open() -> bool:
	return _open


func can_open() -> bool:
	if game == null:
		return false
	if game.has_method("can_open_pause"):
		return bool(game.call("can_open_pause"))
	var phase := String(game.get("phase"))
	return phase == "restock" or phase == "open"


func open_menu(from_suspend: bool = false) -> void:
	if _open:
		if from_suspend:
			_from_suspend = true
			_refresh_copy()
		return
	if not can_open():
		return
	_open = true
	_from_suspend = from_suspend
	_focus = FOCUS_RESUME
	visible = true
	_refresh_copy()
	_paint_focus()
	PlatformServices.checkpoint()
	SfxBus.play("sfx_ui_pause_open")
	if game and game.has_method("on_pause_opened"):
		game.call("on_pause_opened")
	get_tree().paused = true


func close_menu() -> void:
	if not _open:
		return
	_open = false
	_from_suspend = false
	visible = false
	get_tree().paused = false
	SfxBus.play("sfx_ui_pause_close")
	if game and game.has_method("on_pause_closed"):
		game.call("on_pause_closed")


func _refresh_copy() -> void:
	_title.text = Loc.t("pause.title")
	if _from_suspend:
		_body.text = Loc.t("pause.body_suspend")
	else:
		_body.text = Loc.t("pause.body")
	if PlatformServices.wants_touch_pad():
		_hint.text = Loc.t("pause.hint_touch")
	else:
		_hint.text = Loc.t("pause.hint")
	_resume_btn.text = Loc.t("pause.resume")
	_end_btn.text = Loc.t("pause.end_day")
	_refresh_audio_labels()


func _refresh_audio_labels() -> void:
	if _sfx_btn:
		_sfx_btn.text = Loc.t("pause.sfx_off") if SfxBus.is_muted() else Loc.t("pause.sfx_on")
	if _vol_btn:
		_vol_btn.text = Loc.t("pause.sfx_volume", [SfxBus.volume_percent()])


func _on_platform_pause_requested() -> void:
	open_menu(true)


func _on_platform_suspended() -> void:
	PlatformServices.checkpoint()


func _on_platform_resumed() -> void:
	if _open:
		_from_suspend = true
		_refresh_copy()


func _unhandled_input(event: InputEvent) -> void:
	if _is_toggle(event):
		if _open:
			close_menu()
			resume_requested.emit()
		elif can_open():
			open_menu(false)
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if not event.is_pressed() or event.is_echo():
		return
	var dir := _dir_of(event)
	if dir == 0:
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif dir == 1:
		_move_focus(1)
		get_viewport().set_input_as_handled()
	elif dir == 2:
		if _focus == FOCUS_VOL:
			_on_vol_nudge(-1)
		get_viewport().set_input_as_handled()
	elif dir == 3:
		if _focus == FOCUS_VOL:
			_on_vol_nudge(1)
		get_viewport().set_input_as_handled()
	elif _is_confirm(event):
		get_viewport().set_input_as_handled()
		_activate_focus()
	elif _is_cancel(event):
		get_viewport().set_input_as_handled()
		SfxBus.play("sfx_ui_cancel")
		_on_resume()


func _move_focus(delta: int) -> void:
	var next := posmod(_focus + delta, FOCUS_COUNT)
	if next == _focus:
		return
	SfxBus.play("sfx_ui_move")
	_focus = next
	_paint_focus()


func _activate_focus() -> void:
	match _focus:
		FOCUS_RESUME:
			SfxBus.play("sfx_ui_confirm")
			_on_resume()
		FOCUS_SFX:
			_on_sfx_toggle()
		FOCUS_VOL:
			_on_vol_preview()
		FOCUS_END:
			SfxBus.play("sfx_ui_confirm")
			_on_end_day()


func _on_resume() -> void:
	close_menu()
	resume_requested.emit()


func _on_sfx_toggle() -> void:
	if SfxBus.is_muted():
		SfxBus.set_muted(false)
		SfxBus.play("sfx_ui_confirm")
	else:
		SfxBus.play("sfx_ui_confirm")
		SfxBus.set_muted(true)
	_refresh_audio_labels()
	_paint_focus()


func _on_vol_nudge(steps: int) -> void:
	SfxBus.nudge_volume(steps)
	SfxBus.play("sfx_ui_move", 1.0, NAN, true)
	_refresh_audio_labels()
	_focus = FOCUS_VOL
	_paint_focus()


func _on_vol_preview() -> void:
	## J / tap center: sample current level (audible even if muted).
	SfxBus.play("sfx_ui_confirm", 1.0, NAN, true)
	_focus = FOCUS_VOL
	_paint_focus()


func _on_end_day() -> void:
	close_menu()
	end_day_requested.emit()


func _paint_focus() -> void:
	_style_btn(_resume_btn, _focus == FOCUS_RESUME)
	_style_btn(_sfx_btn, _focus == FOCUS_SFX)
	var vol_on := _focus == FOCUS_VOL
	_style_btn(_vol_btn, vol_on)
	_style_btn(_vol_down, vol_on)
	_style_btn(_vol_up, vol_on)
	_style_btn(_end_btn, _focus == FOCUS_END)


func _style_btn(btn: Button, on: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f4d35e") if on else Color("24302a")
	box.set_corner_radius_all(10)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state_name, box)
	btn.add_theme_color_override("font_color", Color("1c241f") if on else Color("f4f1ea"))


func _is_toggle(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventKey:
		return (event as InputEventKey).physical_keycode == KEY_ESCAPE
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	return false


func _is_confirm(event: InputEvent) -> bool:
	if event is InputEventKey:
		var k := (event as InputEventKey).physical_keycode
		return k == KEY_J or k == KEY_ENTER
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
	return false


func _is_cancel(event: InputEvent) -> bool:
	if event is InputEventKey:
		var k := (event as InputEventKey).physical_keycode
		return k == KEY_SEMICOLON or k == KEY_BACKSPACE
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	return false


## 0 up, 1 down, 2 left, 3 right, -1 none
func _dir_of(event: InputEvent) -> int:
	if event is InputEventKey:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_W or k == KEY_UP:
			return 0
		if k == KEY_S or k == KEY_DOWN:
			return 1
		if k == KEY_A or k == KEY_LEFT:
			return 2
		if k == KEY_D or k == KEY_RIGHT:
			return 3
	if event is InputEventJoypadButton:
		var b := (event as InputEventJoypadButton).button_index
		if b == JOY_BUTTON_DPAD_UP:
			return 0
		if b == JOY_BUTTON_DPAD_DOWN:
			return 1
		if b == JOY_BUTTON_DPAD_LEFT:
			return 2
		if b == JOY_BUTTON_DPAD_RIGHT:
			return 3
	return -1
