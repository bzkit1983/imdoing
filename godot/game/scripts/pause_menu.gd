extends CanvasLayer
## In-day pause overlay. process_mode ALWAYS so it works while the tree is paused.
## Opened by Esc / Start or PlatformServices.pause_menu_requested (suspend).

const UiFont = preload("res://scripts/ui_font.gd")

signal resume_requested
signal end_day_requested

var game: Node
var _open: bool = false
var _focus: int = 0
var _from_suspend: bool = false

@onready var _shade: ColorRect = %Shade
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _hint: Label = %Hint
@onready var _resume_btn: Button = %ResumeBtn
@onready var _end_btn: Button = %EndDayBtn


func setup(host: Node) -> void:
	game = host
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_open = false
	UiFont.apply_label(_title, 40)
	_title.add_theme_color_override("font_color", Color("f4d35e"))
	UiFont.apply_label(_body, 26)
	_body.add_theme_color_override("font_color", Color("f4f1ea"))
	UiFont.apply_label(_hint, 22)
	_hint.add_theme_color_override("font_color", Color("c8c2b4"))
	UiFont.apply_button(_resume_btn, 22)
	UiFont.apply_button(_end_btn, 22)
	_resume_btn.focus_mode = Control.FOCUS_NONE
	_end_btn.focus_mode = Control.FOCUS_NONE
	_resume_btn.text = Loc.t("pause.resume")
	_end_btn.text = Loc.t("pause.end_day")
	_resume_btn.pressed.connect(_on_resume)
	_end_btn.pressed.connect(_on_end_day)
	_paint_focus()
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
	_focus = 0
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
	_hint.text = Loc.t("pause.hint")
	_resume_btn.text = Loc.t("pause.resume")
	_end_btn.text = Loc.t("pause.end_day")


func _on_platform_pause_requested() -> void:
	open_menu(true)


func _on_platform_suspended() -> void:
	# pause_menu_requested already opens; ensure checkpoint even if menu blocked.
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
		if _focus != 0:
			SfxBus.play("sfx_ui_move")
		_focus = 0
		_paint_focus()
		get_viewport().set_input_as_handled()
	elif dir == 1:
		if _focus != 1:
			SfxBus.play("sfx_ui_move")
		_focus = 1
		_paint_focus()
		get_viewport().set_input_as_handled()
	elif _is_confirm(event):
		get_viewport().set_input_as_handled()
		SfxBus.play("sfx_ui_confirm")
		if _focus == 0:
			_on_resume()
		else:
			_on_end_day()
	elif _is_cancel(event):
		get_viewport().set_input_as_handled()
		SfxBus.play("sfx_ui_cancel")
		_on_resume()


func _on_resume() -> void:
	close_menu()
	resume_requested.emit()


func _on_end_day() -> void:
	close_menu()
	end_day_requested.emit()


func _paint_focus() -> void:
	_style_btn(_resume_btn, _focus == 0)
	_style_btn(_end_btn, _focus == 1)


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


## 0 up, 1 down, -1 none
func _dir_of(event: InputEvent) -> int:
	if event is InputEventKey:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_W or k == KEY_UP:
			return 0
		if k == KEY_S or k == KEY_DOWN:
			return 1
	if event is InputEventJoypadButton:
		var b := (event as InputEventJoypadButton).button_index
		if b == JOY_BUTTON_DPAD_UP:
			return 0
		if b == JOY_BUTTON_DPAD_DOWN:
			return 1
	return -1
