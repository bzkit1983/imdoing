extends CanvasLayer
## In-day pause overlay. process_mode ALWAYS so it works while the tree is paused.
## Opened by Esc / Start / HUD pause button or PlatformServices.pause_menu_requested (suspend).

const UiFont = preload("res://scripts/ui_font.gd")

signal resume_requested
signal end_day_requested

const FOCUS_RESUME := 0
const FOCUS_SFX := 1
const FOCUS_VOL := 2
const FOCUS_STICK := 3
const FOCUS_CAMERA := 4
const FOCUS_LANG := 5
const FOCUS_END := 6
const FOCUS_COUNT := 7

var game: Node
var _open: bool = false
var _focus: int = 0
var _from_suspend: bool = false
## Stick UI: one step on deflect, then must recenter (same as prep dialogs).
var _stick_armed: bool = true
const STICK_UI_DEAD := 0.55
## Language list sub-mode (replaces cycle toggle).
var _lang_pick: bool = false
var _lang_pick_focus: int = 0
var _lang_pick_codes: Array[String] = []
var _lang_pick_btns: Array[Button] = []
var _lang_pick_back: Button = null
var _lang_pick_root: Control = null

@onready var _shade: ColorRect = %Shade
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _hint: Label = %Hint
@onready var _resume_btn: Button = %ResumeBtn
@onready var _sfx_btn: Button = %SfxBtn
@onready var _vol_btn: Button = %VolBtn
@onready var _vol_down: Button = %VolDownBtn
@onready var _vol_up: Button = %VolUpBtn
@onready var _stick_btn: Button = %StickBtn
@onready var _camera_btn: Button = %CameraBtn
@onready var _lang_btn: Button = %LangBtn
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
	for b in [_resume_btn, _sfx_btn, _vol_btn, _vol_down, _vol_up, _stick_btn, _camera_btn, _lang_btn, _end_btn]:
		UiFont.apply_button(b, 22)
		b.focus_mode = Control.FOCUS_NONE
	_resume_btn.pressed.connect(_on_resume)
	_sfx_btn.pressed.connect(_on_sfx_toggle)
	_vol_btn.pressed.connect(_on_vol_preview)
	_vol_down.pressed.connect(_on_vol_nudge.bind(-1))
	_vol_up.pressed.connect(_on_vol_nudge.bind(1))
	_stick_btn.pressed.connect(_on_stick_toggle)
	_camera_btn.pressed.connect(_on_camera_cycle)
	_lang_btn.pressed.connect(_enter_lang_pick)
	_end_btn.pressed.connect(_on_end_day)
	_paint_focus()
	_refresh_audio_labels()
	_refresh_stick_row()
	_refresh_camera_row()
	_refresh_lang_row()
	if not PlatformServices.pause_menu_requested.is_connected(_on_platform_pause_requested):
		PlatformServices.pause_menu_requested.connect(_on_platform_pause_requested)
	if not PlatformServices.suspended.is_connected(_on_platform_suspended):
		PlatformServices.suspended.connect(_on_platform_suspended)
	if not PlatformServices.resumed.is_connected(_on_platform_resumed):
		PlatformServices.resumed.connect(_on_platform_resumed)
	if not Loc.locale_changed.is_connected(_on_locale_changed):
		Loc.locale_changed.connect(_on_locale_changed)


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
	_stick_armed = true
	_exit_lang_pick(false)
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
	_exit_lang_pick(false)
	_open = false
	_from_suspend = false
	_stick_armed = true
	visible = false
	get_tree().paused = false
	SfxBus.play("sfx_ui_pause_close")
	if game and game.has_method("on_pause_closed"):
		game.call("on_pause_closed")


func _process(_delta: float) -> void:
	if not _open:
		return
	## Left + right sticks (right is not on move_*). PROCESS_MODE_ALWAYS while tree paused.
	var v := Controls.menu_stick_vector()
	if v.length() < STICK_UI_DEAD:
		_stick_armed = true
		return
	if not _stick_armed:
		return
	_stick_armed = false
	if absf(v.x) > absf(v.y):
		if not _lang_pick and _focus == FOCUS_VOL:
			_on_vol_nudge(1 if v.x > 0.0 else -1)
	else:
		if _lang_pick:
			_move_lang_pick_focus(1 if v.y > 0.0 else -1)
		else:
			_move_focus(1 if v.y > 0.0 else -1)


func _refresh_copy() -> void:
	if _lang_pick:
		_title.text = Loc.t("pause.language_pick.title")
		_body.text = Loc.t("pause.language", [Loc.t("locale.name.%s" % Loc.get_locale())])
		if InputMode.show_vj():
			_hint.text = Loc.t("pause.hint_touch")
		else:
			_hint.text = Loc.t("pause.hint")
		_refresh_lang_pick_labels()
		return
	_title.text = Loc.t("pause.title")
	if _from_suspend:
		_body.text = Loc.t("pause.body_suspend")
	else:
		_body.text = Loc.t("pause.body")
	if InputMode.show_vj():
		_hint.text = Loc.t("pause.hint_touch")
	else:
		_hint.text = Loc.t("pause.hint")
	_resume_btn.text = Loc.t("pause.resume")
	_end_btn.text = Loc.t("pause.end_day")
	_refresh_audio_labels()
	_refresh_stick_row()
	_refresh_camera_row()
	_refresh_lang_row()


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


func _on_locale_changed(_code: String) -> void:
	if _open:
		_refresh_copy()
		_paint_focus()


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
	if _lang_pick:
		_lang_pick_input(event)
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


func _lang_pick_input(event: InputEvent) -> void:
	var dir := _dir_of(event)
	if dir == 0:
		_move_lang_pick_focus(-1)
		get_viewport().set_input_as_handled()
	elif dir == 1:
		_move_lang_pick_focus(1)
		get_viewport().set_input_as_handled()
	elif dir == 2 or dir == 3:
		get_viewport().set_input_as_handled()
	elif _is_confirm(event):
		get_viewport().set_input_as_handled()
		_activate_lang_pick()
	elif _is_cancel(event):
		get_viewport().set_input_as_handled()
		SfxBus.play("sfx_ui_cancel")
		_exit_lang_pick(true)


func _stick_row_visible() -> bool:
	## Always offer the toggle (Desktop editor included). VJ still only draws when
	## pref is on and InputMode is TOUCH.
	return true


func _refresh_stick_row() -> void:
	if _stick_btn == null:
		return
	var show_row := _stick_row_visible()
	_stick_btn.visible = show_row
	if show_row:
		_stick_btn.text = Loc.t(
			"pause.virtual_stick_on" if PlatformServices.is_virtual_stick_enabled() else "pause.virtual_stick_off"
		)
	_layout_option_rows()
	if not show_row and _focus == FOCUS_STICK:
		_focus = FOCUS_CAMERA
		_paint_focus()


func _refresh_camera_row() -> void:
	if _camera_btn == null:
		return
	match PlatformServices.get_camera_view():
		PlatformServices.CAMERA_VIEW_FAR:
			_camera_btn.text = Loc.t("pause.camera_far")
		PlatformServices.CAMERA_VIEW_OVERVIEW:
			_camera_btn.text = Loc.t("pause.camera_overview")
		_:
			_camera_btn.text = Loc.t("pause.camera_normal")
	_layout_option_rows()


func _refresh_lang_row() -> void:
	if _lang_btn == null:
		return
	var code := Loc.get_locale()
	var endonym := Loc.t("locale.name.%s" % code)
	_lang_btn.text = Loc.t("pause.language", [endonym])
	_layout_option_rows()


func _layout_option_rows() -> void:
	if _end_btn == null or _camera_btn == null or _lang_btn == null:
		return
	var stick_on := _stick_btn != null and _stick_btn.visible
	## Rows: stick (optional) → camera → language → end day.
	if stick_on:
		_stick_btn.offset_top = 472.0
		_stick_btn.offset_bottom = 544.0
		_camera_btn.offset_top = 558.0
		_camera_btn.offset_bottom = 630.0
		_lang_btn.offset_top = 644.0
		_lang_btn.offset_bottom = 716.0
		_end_btn.offset_top = 730.0
		_end_btn.offset_bottom = 802.0
	else:
		_camera_btn.offset_top = 472.0
		_camera_btn.offset_bottom = 544.0
		_lang_btn.offset_top = 558.0
		_lang_btn.offset_bottom = 630.0
		_end_btn.offset_top = 644.0
		_end_btn.offset_bottom = 716.0


func _move_focus(delta: int) -> void:
	var next := _focus
	for _i in FOCUS_COUNT:
		next = posmod(next + delta, FOCUS_COUNT)
		if next == FOCUS_STICK and not _stick_row_visible():
			continue
		break
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
		FOCUS_STICK:
			_on_stick_toggle()
		FOCUS_CAMERA:
			_on_camera_cycle()
		FOCUS_LANG:
			_enter_lang_pick()
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


func _on_stick_toggle() -> void:
	if not _stick_row_visible():
		return
	PlatformServices.toggle_virtual_stick()
	SfxBus.play("sfx_ui_confirm")
	_refresh_stick_row()
	_focus = FOCUS_STICK
	_paint_focus()


func _on_camera_cycle() -> void:
	PlatformServices.cycle_camera_view()
	SfxBus.play("sfx_ui_confirm")
	_refresh_camera_row()
	_focus = FOCUS_CAMERA
	_paint_focus()


func _enter_lang_pick() -> void:
	if _lang_pick:
		return
	SfxBus.play("sfx_ui_confirm")
	_lang_pick = true
	_lang_pick_focus = 0
	_set_main_options_visible(false)
	_build_lang_pick()
	_refresh_copy()
	_paint_focus()


func _exit_lang_pick(play_focus: bool) -> void:
	if not _lang_pick and _lang_pick_root == null:
		return
	_lang_pick = false
	_clear_lang_pick()
	_set_main_options_visible(true)
	_refresh_copy()
	_focus = FOCUS_LANG
	if play_focus:
		_paint_focus()


func _set_main_options_visible(on: bool) -> void:
	_resume_btn.visible = on
	_sfx_btn.visible = on
	if _vol_btn.get_parent() is Control:
		(_vol_btn.get_parent() as Control).visible = on
	if _stick_btn:
		_stick_btn.visible = on and _stick_row_visible()
	if _camera_btn:
		_camera_btn.visible = on
	if _lang_btn:
		_lang_btn.visible = on
	_end_btn.visible = on


func _build_lang_pick() -> void:
	_clear_lang_pick()
	var card := _lang_btn.get_parent()
	if card == null:
		return
	_lang_pick_root = Control.new()
	_lang_pick_root.name = "LangPickRoot"
	_lang_pick_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lang_pick_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_lang_pick_root)
	_lang_pick_codes.clear()
	_lang_pick_btns.clear()
	var current := Loc.get_locale()
	var y := 214.0
	var i := 0
	for code in Loc.locales():
		var c := String(code)
		_lang_pick_codes.append(c)
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.offset_left = 36.0
		btn.offset_right = 764.0
		btn.offset_top = y
		btn.offset_bottom = y + 72.0
		UiFont.apply_button(btn, 22)
		var endonym := Loc.t("locale.name.%s" % c)
		btn.text = Loc.t("pause.language_pick.current", [endonym]) if c == current else endonym
		var idx := i
		btn.pressed.connect(func() -> void:
			_lang_pick_focus = idx
			_activate_lang_pick()
		)
		_lang_pick_root.add_child(btn)
		_lang_pick_btns.append(btn)
		y += 86.0
		i += 1
	_lang_pick_back = Button.new()
	_lang_pick_back.focus_mode = Control.FOCUS_NONE
	_lang_pick_back.offset_left = 36.0
	_lang_pick_back.offset_right = 764.0
	_lang_pick_back.offset_top = y
	_lang_pick_back.offset_bottom = y + 72.0
	UiFont.apply_button(_lang_pick_back, 22)
	_lang_pick_back.text = Loc.t("pause.language_pick.back")
	_lang_pick_back.pressed.connect(func() -> void:
		SfxBus.play("sfx_ui_cancel")
		_exit_lang_pick(true)
	)
	_lang_pick_root.add_child(_lang_pick_back)
	## Prefer focusing the current locale row.
	var cur_i := _lang_pick_codes.find(current)
	_lang_pick_focus = cur_i if cur_i >= 0 else 0


func _clear_lang_pick() -> void:
	_lang_pick_btns.clear()
	_lang_pick_back = null
	_lang_pick_codes.clear()
	if _lang_pick_root != null and is_instance_valid(_lang_pick_root):
		_lang_pick_root.queue_free()
	_lang_pick_root = null


func _refresh_lang_pick_labels() -> void:
	if _lang_pick_back:
		_lang_pick_back.text = Loc.t("pause.language_pick.back")
	var current := Loc.get_locale()
	for i in _lang_pick_btns.size():
		var c := _lang_pick_codes[i] if i < _lang_pick_codes.size() else ""
		var endonym := Loc.t("locale.name.%s" % c)
		_lang_pick_btns[i].text = Loc.t("pause.language_pick.current", [endonym]) if c == current else endonym


func _lang_pick_count() -> int:
	## Locale rows + back.
	return _lang_pick_btns.size() + (1 if _lang_pick_back != null else 0)


func _move_lang_pick_focus(delta: int) -> void:
	var n := _lang_pick_count()
	if n <= 0:
		return
	_lang_pick_focus = posmod(_lang_pick_focus + delta, n)
	SfxBus.play("sfx_ui_move")
	_paint_focus()


func _activate_lang_pick() -> void:
	var n_locales := _lang_pick_btns.size()
	if _lang_pick_focus >= 0 and _lang_pick_focus < n_locales:
		var code := _lang_pick_codes[_lang_pick_focus]
		PlatformServices.set_locale(code)
		SfxBus.play("sfx_ui_confirm")
		_exit_lang_pick(true)
		return
	## Back row.
	SfxBus.play("sfx_ui_cancel")
	_exit_lang_pick(true)


func _on_end_day() -> void:
	close_menu()
	end_day_requested.emit()


func _paint_focus() -> void:
	if _lang_pick:
		for i in _lang_pick_btns.size():
			_style_btn(_lang_pick_btns[i], _lang_pick_focus == i)
		if _lang_pick_back:
			_style_btn(_lang_pick_back, _lang_pick_focus == _lang_pick_btns.size())
		return
	_style_btn(_resume_btn, _focus == FOCUS_RESUME)
	_style_btn(_sfx_btn, _focus == FOCUS_SFX)
	var vol_on := _focus == FOCUS_VOL
	_style_btn(_vol_btn, vol_on)
	_style_btn(_vol_down, vol_on)
	_style_btn(_vol_up, vol_on)
	if _stick_btn and _stick_btn.visible:
		_style_btn(_stick_btn, _focus == FOCUS_STICK)
	if _camera_btn:
		_style_btn(_camera_btn, _focus == FOCUS_CAMERA)
	if _lang_btn:
		_style_btn(_lang_btn, _focus == FOCUS_LANG)
	_style_btn(_end_btn, _focus == FOCUS_END)


func _style_btn(btn: Button, on: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f4d35e") if on else Color("24302a")
	box.set_corner_radius_all(10)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state_name, box)
	btn.add_theme_color_override("font_color", Color("1c241f") if on else Color("f4f1ea"))


func _is_toggle(event: InputEvent) -> bool:
	## M1: any seat may open/close — Esc or any pad's Start (no device filter).
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
