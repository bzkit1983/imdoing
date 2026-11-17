extends CanvasLayer
## In-day pause overlay. process_mode ALWAYS so it works while the tree is paused.
## Opened by Esc / Start / HUD pause button or PlatformServices.pause_menu_requested (suspend).

const UiFont = preload("res://scripts/ui_font.gd")
const TaskTracker = preload("res://scripts/session/task_tracker.gd")
const BgmBusScript = preload("res://scripts/bgm_bus.gd")

signal resume_requested
signal end_day_requested

const FOCUS_RESUME := 0
const FOCUS_TASKS := 1
const FOCUS_TUTORIAL := 2
const FOCUS_SFX := 3
const FOCUS_VOL := 4
const FOCUS_BGM := 5
const FOCUS_BGM_VOL := 6
const FOCUS_STICK := 7
const FOCUS_CAMERA := 8
const FOCUS_LANG := 9
const FOCUS_END := 10
const FOCUS_COUNT := 11

const TutorialCatalog = preload("res://scripts/tutorial/tutorial_catalog.gd")

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
## Task details sub-mode (below Continue on main list).
var _tasks_detail: bool = false
var _tasks_detail_root: Control = null
var _tasks_detail_back: Button = null
var _tasks_detail_scroll: ScrollContainer = null
## Tutorial review list sub-mode.
var _tut_review: bool = false
var _tut_review_root: Control = null
var _tut_review_back: Button = null
var _tut_review_btns: Array[Button] = []
var _tut_review_ids: Array[String] = []
var _tut_review_focus: int = 0
var _tut_review_scroll: ScrollContainer = null

@onready var _shade: ColorRect = %Shade
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _hint: Label = %Hint
@onready var _resume_btn: Button = %ResumeBtn
@onready var _tasks_btn: Button = %TasksBtn
@onready var _tutorial_btn: Button = %TutorialBtn
@onready var _sfx_btn: Button = %SfxBtn
@onready var _vol_btn: Button = %VolBtn
@onready var _vol_down: Button = %VolDownBtn
@onready var _vol_up: Button = %VolUpBtn
@onready var _bgm_btn: Button = %BgmBtn
@onready var _bgm_vol_btn: Button = %BgmVolBtn
@onready var _bgm_vol_down: Button = %BgmVolDownBtn
@onready var _bgm_vol_up: Button = %BgmVolUpBtn
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
	for b in [
		_resume_btn, _tasks_btn, _tutorial_btn, _sfx_btn, _vol_btn, _vol_down, _vol_up,
		_bgm_btn, _bgm_vol_btn, _bgm_vol_down, _bgm_vol_up,
		_stick_btn, _camera_btn, _lang_btn, _end_btn,
	]:
		if b == null:
			continue
		UiFont.apply_button(b, 22)
		b.focus_mode = Control.FOCUS_NONE
	_resume_btn.pressed.connect(_on_resume)
	if _tasks_btn:
		_tasks_btn.pressed.connect(_enter_tasks_detail)
	if _tutorial_btn:
		_tutorial_btn.pressed.connect(_enter_tut_review)
	_sfx_btn.pressed.connect(_on_sfx_toggle)
	_vol_btn.pressed.connect(_on_vol_preview)
	_vol_down.pressed.connect(_on_vol_nudge.bind(-1))
	_vol_up.pressed.connect(_on_vol_nudge.bind(1))
	if _bgm_btn:
		_bgm_btn.pressed.connect(_on_bgm_toggle)
	if _bgm_vol_btn:
		_bgm_vol_btn.pressed.connect(_on_bgm_vol_preview)
	if _bgm_vol_down:
		_bgm_vol_down.pressed.connect(_on_bgm_vol_nudge.bind(-1))
	if _bgm_vol_up:
		_bgm_vol_up.pressed.connect(_on_bgm_vol_nudge.bind(1))
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
	if not PlatformServices.show_dev_hud_changed.is_connected(_on_show_dev_hud_changed):
		PlatformServices.show_dev_hud_changed.connect(_on_show_dev_hud_changed)
	_refresh_hint_visibility()


func is_open() -> bool:
	return _open


func can_open() -> bool:
	if game == null:
		return false
	if game.has_method("can_open_pause"):
		return bool(game.call("can_open_pause"))
	var phase := String(game.get("phase"))
	return phase == "restock" or phase == "open"


var _applying_net_pause: bool = false


func open_menu(from_suspend: bool = false) -> void:
	## Client system suspend during LAN day = disconnect (§12.6).
	if from_suspend and SessionService.is_networked() and SessionService.is_client() and SessionService.day_started:
		SessionService.close()
		return
	if SessionService.is_networked() and not _applying_net_pause:
		SessionService.request_pause(true)
		## Host suspend still requests room pause; UI opens via room_paused_changed.
		if not from_suspend:
			return
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
	_exit_tasks_detail(false)
	_exit_tut_review(false)
	visible = true
	_refresh_end_day_row()
	_refresh_copy()
	_layout_option_rows()
	_paint_focus()
	PlatformServices.checkpoint()
	SfxBus.play("sfx_ui_pause_open")
	if game and game.has_method("on_pause_opened"):
		game.call("on_pause_opened")
	get_tree().paused = true


func close_menu() -> void:
	if SessionService.is_networked() and not _applying_net_pause and _open:
		SessionService.request_pause(false)
		return
	if not _open:
		return
	_exit_lang_pick(false)
	_exit_tasks_detail(false)
	_exit_tut_review(false)
	_open = false
	_from_suspend = false
	_stick_armed = true
	visible = false
	get_tree().paused = false
	SfxBus.play("sfx_ui_pause_close")
	if game and game.has_method("on_pause_closed"):
		game.call("on_pause_closed")


func apply_net_pause(paused: bool) -> void:
	_applying_net_pause = true
	if paused:
		open_menu(false)
	else:
		close_menu()
	_applying_net_pause = false


func _refresh_end_day_row() -> void:
	if _end_btn == null:
		return
	var host_ok := (not SessionService.is_networked()) or SessionService.is_server()
	_end_btn.visible = host_ok
	_end_btn.disabled = not host_ok
	_layout_option_rows()


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
		if not _lang_pick and not _tasks_detail:
			if _focus == FOCUS_VOL:
				_on_vol_nudge(1 if v.x > 0.0 else -1)
			elif _focus == FOCUS_BGM_VOL:
				_on_bgm_vol_nudge(1 if v.x > 0.0 else -1)
	else:
		if _lang_pick:
			_move_lang_pick_focus(1 if v.y > 0.0 else -1)
		elif _tasks_detail:
			_scroll_tasks_detail(1 if v.y > 0.0 else -1)
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
		_refresh_hint_visibility()
		return
	if _tasks_detail:
		_title.text = Loc.t("pause.tasks.title")
		_body.text = Loc.t("pause.tasks")
		if InputMode.show_vj():
			_hint.text = Loc.t("pause.hint_touch")
		else:
			_hint.text = Loc.t("pause.hint")
		if _tasks_detail_back:
			_tasks_detail_back.text = Loc.t("pause.tasks.back")
		_refresh_hint_visibility()
		return
	if _tut_review:
		_title.text = Loc.t("pause.tutorial.title")
		_body.text = Loc.t("pause.tutorial")
		if InputMode.show_vj():
			_hint.text = Loc.t("pause.hint_touch")
		else:
			_hint.text = Loc.t("pause.hint")
		if _tut_review_back:
			_tut_review_back.text = Loc.t("pause.tutorial.back")
		_refresh_hint_visibility()
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
	if _tasks_btn:
		_tasks_btn.text = Loc.t("pause.tasks")
	if _tutorial_btn:
		_tutorial_btn.text = Loc.t("pause.tutorial")
	_end_btn.text = Loc.t("pause.end_day")
	_refresh_audio_labels()
	_refresh_stick_row()
	_refresh_camera_row()
	_refresh_lang_row()
	_refresh_hint_visibility()


func _refresh_audio_labels() -> void:
	if _sfx_btn:
		_sfx_btn.text = Loc.t("pause.sfx_off") if SfxBus.is_muted() else Loc.t("pause.sfx_on")
	if _vol_btn:
		_vol_btn.text = Loc.t("pause.sfx_volume", [SfxBus.volume_percent()])
	var bgm := BgmBusScript.bus()
	if _bgm_btn and bgm:
		_bgm_btn.text = Loc.t("pause.bgm_off") if bgm.is_muted() else Loc.t("pause.bgm_on")
	if _bgm_vol_btn and bgm:
		_bgm_vol_btn.text = Loc.t("pause.bgm_volume", [bgm.volume_percent()])


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


func _on_show_dev_hud_changed(_enabled: bool) -> void:
	_refresh_hint_visibility()


func _refresh_hint_visibility() -> void:
	## Body＋control-hint chrome are for developers; players use the option buttons.
	var show := PlatformServices.is_show_dev_hud()
	if _hint:
		_hint.visible = show
	if _body:
		## Keep body visible in language／tasks／tutorial subpages (they reuse it for context).
		if _lang_pick or _tasks_detail or _tut_review:
			_body.visible = true
		else:
			_body.visible = show
	if _open and not _lang_pick and not _tasks_detail and not _tut_review:
		_layout_option_rows()


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
	if _tasks_detail:
		_tasks_detail_input(event)
		return
	if _tut_review:
		_tut_review_input(event)
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
		elif _focus == FOCUS_BGM_VOL:
			_on_bgm_vol_nudge(-1)
		get_viewport().set_input_as_handled()
	elif dir == 3:
		if _focus == FOCUS_VOL:
			_on_vol_nudge(1)
		elif _focus == FOCUS_BGM_VOL:
			_on_bgm_vol_nudge(1)
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
	## Fit all main options inside the 720p card without overlapping the header.
	if _resume_btn == null or _end_btn == null:
		return
	var card := _resume_btn.get_parent() as Control
	if card == null:
		return
	var vp_h := get_viewport().get_visible_rect().size.y
	var card_top := 8.0
	var card_bottom := mini(712.0, vp_h - 8.0)
	card.offset_top = card_top
	card.offset_bottom = card_bottom
	var inner_h := card_bottom - card_top
	var header_h := _layout_header_block()
	var rows: Array[Control] = []
	rows.append(_resume_btn)
	if _tasks_btn != null and _tasks_btn.visible:
		rows.append(_tasks_btn)
	if _tutorial_btn != null and _tutorial_btn.visible:
		rows.append(_tutorial_btn)
	rows.append(_sfx_btn)
	if _vol_btn != null and _vol_btn.get_parent() is Control:
		rows.append(_vol_btn.get_parent() as Control)
	if _bgm_btn != null and _bgm_btn.visible:
		rows.append(_bgm_btn)
	if _bgm_vol_btn != null and _bgm_vol_btn.get_parent() is Control:
		rows.append(_bgm_vol_btn.get_parent() as Control)
	if _stick_btn != null and _stick_btn.visible:
		rows.append(_stick_btn)
	if _camera_btn != null and _camera_btn.visible:
		rows.append(_camera_btn)
	if _lang_btn != null and _lang_btn.visible:
		rows.append(_lang_btn)
	if _end_btn != null and _end_btn.visible:
		rows.append(_end_btn)
	var n := rows.size()
	if n <= 0:
		return
	var gap := 4.0
	var bottom_pad := 8.0
	var y0 := header_h
	var avail := maxf(80.0, inner_h - y0 - bottom_pad)
	var row_h := (avail - gap * float(n - 1)) / float(n)
	row_h = clampf(row_h, 28.0, 52.0)
	## If clamped min still overflows, pull start up under the title only.
	var need := row_h * float(n) + gap * float(n - 1)
	if y0 + need > inner_h - bottom_pad:
		y0 = maxf(64.0, inner_h - bottom_pad - need)
		avail = maxf(80.0, inner_h - y0 - bottom_pad)
		row_h = clampf((avail - gap * float(n - 1)) / float(n), 26.0, 52.0)
	var font_px := 22 if row_h >= 40.0 else (18 if row_h >= 32.0 else 16)
	var y := y0
	var vol_parent := _vol_btn.get_parent() if _vol_btn else null
	var bgm_vol_parent := _bgm_vol_btn.get_parent() if _bgm_vol_btn else null
	for row in rows:
		row.offset_left = 36.0
		row.offset_right = 764.0
		row.offset_top = y
		row.offset_bottom = y + row_h
		if row is Button:
			UiFont.apply_button(row as Button, font_px)
		if row == vol_parent or row == bgm_vol_parent:
			_layout_volume_row(row, row_h, font_px)
		y += row_h + gap


## Pack title／optional body／hint; returns Y where option rows may start.
func _layout_header_block() -> float:
	var y := 12.0
	if _title:
		_title.offset_left = 36.0
		_title.offset_right = 764.0
		_title.offset_top = y
		_title.offset_bottom = y + 44.0
		y = _title.offset_bottom + 6.0
	if _body != null and _body.visible:
		_body.offset_left = 36.0
		_body.offset_right = 764.0
		_body.offset_top = y
		_body.offset_bottom = y + 56.0
		y = _body.offset_bottom + 4.0
	if _hint != null and _hint.visible:
		_hint.offset_left = 36.0
		_hint.offset_right = 764.0
		_hint.offset_top = y
		_hint.offset_bottom = y + 28.0
		y = _hint.offset_bottom + 8.0
	else:
		y += 4.0
	return y


func _layout_volume_row(row: Control, row_h: float, font_px: int) -> void:
	var row_w := 728.0
	var side_w := minf(88.0, row_h + 20.0)
	var gap_x := 12.0
	var mid_left := side_w + gap_x
	var mid_right := row_w - side_w - gap_x
	for child in row.get_children():
		if not child is Button:
			continue
		var b := child as Button
		UiFont.apply_button(b, font_px)
		b.offset_top = 0.0
		b.offset_bottom = row_h
		if b == _vol_down or b == _bgm_vol_down:
			b.offset_left = 0.0
			b.offset_right = side_w
		elif b == _vol_up or b == _bgm_vol_up:
			b.offset_left = row_w - side_w
			b.offset_right = row_w
		else:
			b.offset_left = mid_left
			b.offset_right = mid_right


func _move_focus(delta: int) -> void:
	var next := _focus
	for _i in FOCUS_COUNT:
		next = posmod(next + delta, FOCUS_COUNT)
		if next == FOCUS_STICK and not _stick_row_visible():
			continue
		if next == FOCUS_END and _end_btn != null and not _end_btn.visible:
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
		FOCUS_TASKS:
			_enter_tasks_detail()
		FOCUS_TUTORIAL:
			_enter_tut_review()
		FOCUS_SFX:
			_on_sfx_toggle()
		FOCUS_VOL:
			_on_vol_preview()
		FOCUS_BGM:
			_on_bgm_toggle()
		FOCUS_BGM_VOL:
			_on_bgm_vol_preview()
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


func _on_bgm_toggle() -> void:
	var bgm := BgmBusScript.bus()
	if bgm == null:
		return
	if bgm.is_muted():
		bgm.set_muted(false)
		SfxBus.play("sfx_ui_confirm")
	else:
		SfxBus.play("sfx_ui_confirm")
		bgm.set_muted(true)
	_refresh_audio_labels()
	_paint_focus()


func _on_bgm_vol_nudge(steps: int) -> void:
	var bgm := BgmBusScript.bus()
	if bgm == null:
		return
	bgm.nudge_volume(steps)
	bgm.preview_volume()
	SfxBus.play("sfx_ui_move", 1.0, NAN, true)
	_refresh_audio_labels()
	_focus = FOCUS_BGM_VOL
	_paint_focus()


func _on_bgm_vol_preview() -> void:
	var bgm := BgmBusScript.bus()
	if bgm:
		bgm.preview_volume()
	SfxBus.play("sfx_ui_confirm", 1.0, NAN, true)
	_focus = FOCUS_BGM_VOL
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
	_exit_tasks_detail(false)
	_exit_tut_review(false)
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
	if not _tasks_detail and not _tut_review:
		_set_main_options_visible(true)
	_refresh_copy()
	_focus = FOCUS_LANG
	if play_focus:
		_paint_focus()


func _enter_tasks_detail() -> void:
	if _tasks_detail:
		return
	_exit_lang_pick(false)
	_exit_tut_review(false)
	SfxBus.play("sfx_ui_confirm")
	_tasks_detail = true
	_set_main_options_visible(false)
	_build_tasks_detail()
	_refresh_copy()
	_paint_focus()


func _exit_tasks_detail(play_focus: bool) -> void:
	if not _tasks_detail and _tasks_detail_root == null:
		return
	_tasks_detail = false
	_clear_tasks_detail()
	if not _lang_pick and not _tut_review:
		_set_main_options_visible(true)
	_refresh_copy()
	_focus = FOCUS_TASKS
	if play_focus:
		_paint_focus()


func _enter_tut_review() -> void:
	if _tut_review:
		return
	_exit_lang_pick(false)
	_exit_tasks_detail(false)
	SfxBus.play("sfx_ui_confirm")
	_tut_review = true
	_tut_review_focus = 0
	_set_main_options_visible(false)
	_build_tut_review()
	_refresh_copy()
	_paint_focus()


func _exit_tut_review(play_focus: bool) -> void:
	if not _tut_review and _tut_review_root == null:
		return
	_tut_review = false
	_clear_tut_review()
	if not _lang_pick and not _tasks_detail:
		_set_main_options_visible(true)
	_refresh_copy()
	_focus = FOCUS_TUTORIAL
	if play_focus:
		_paint_focus()


func _set_main_options_visible(on: bool) -> void:
	_resume_btn.visible = on
	if _tasks_btn:
		_tasks_btn.visible = on
	if _tutorial_btn:
		_tutorial_btn.visible = on
	_sfx_btn.visible = on
	if _vol_btn.get_parent() is Control:
		(_vol_btn.get_parent() as Control).visible = on
	if _bgm_btn:
		_bgm_btn.visible = on
	if _bgm_vol_btn and _bgm_vol_btn.get_parent() is Control:
		(_bgm_vol_btn.get_parent() as Control).visible = on
	if _stick_btn:
		_stick_btn.visible = on and _stick_row_visible()
	if _camera_btn:
		_camera_btn.visible = on
	if _lang_btn:
		_lang_btn.visible = on
	## Host-only end-day; keep prior host_ok rule from _refresh_end_day_row.
	if on:
		_refresh_end_day_row()
	else:
		_end_btn.visible = false


func _local_task_seat() -> int:
	if game == null:
		return 0
	var p = game.get("player")
	if p != null and is_instance_valid(p) and "seat_id" in p:
		return int(p.seat_id)
	return 0


func _format_pause_task_row(row: Dictionary) -> String:
	var st := String(row.get("status", "active"))
	var unwired := bool(row.get("unwired", false))
	var mark := TaskTracker.status_mark(st, unwired)
	var name := String(row.get("name", ""))
	if name == "":
		name = String(row.get("id", "?"))
	var desc := String(row.get("desc", ""))
	var prog := TaskTracker.progress_text(
		String(row.get("op", ">=")),
		int(row.get("current", 0)),
		int(row.get("target", 0)),
		st
	)
	if unwired:
		return Loc.t("prep.tasks.row_unwired", [mark, name])
	if desc == "":
		if st == "done":
			return Loc.t("prep.tasks.row_done_nodesc", [mark, name, prog])
		return Loc.t("prep.tasks.row_nodesc", [mark, name, prog])
	if st == "done":
		return Loc.t("prep.tasks.row_done", [mark, name, desc, prog])
	return Loc.t("prep.tasks.row", [mark, name, desc, prog])


func _build_tasks_detail() -> void:
	_clear_tasks_detail()
	var card := _resume_btn.get_parent()
	if card == null:
		return
	_tasks_detail_root = Control.new()
	_tasks_detail_root.name = "TasksDetailRoot"
	_tasks_detail_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tasks_detail_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_tasks_detail_root)
	_tasks_detail_scroll = ScrollContainer.new()
	_tasks_detail_scroll.offset_left = 36.0
	_tasks_detail_scroll.offset_right = 764.0
	_tasks_detail_scroll.offset_top = 214.0
	_tasks_detail_scroll.offset_bottom = 600.0
	_tasks_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tasks_detail_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_tasks_detail_root.add_child(_tasks_detail_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(720, 0)
	_tasks_detail_scroll.add_child(box)
	var rows: Array = []
	if game != null and game.has_method("task_hud_lines"):
		rows = game.task_hud_lines(_local_task_seat())
	if rows.is_empty():
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.text = Loc.t("pause.tasks.empty")
		UiFont.apply_label(empty, 22)
		empty.add_theme_color_override("font_color", Color("f4f1ea"))
		box.add_child(empty)
	else:
		for row in rows:
			if not (row is Dictionary):
				continue
			var lab := Label.new()
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lab.text = _format_pause_task_row(row as Dictionary)
			UiFont.apply_label(lab, 22)
			lab.add_theme_color_override("font_color", Color("f4f1ea"))
			lab.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.06, 1))
			lab.add_theme_constant_override("outline_size", 3)
			box.add_child(lab)
	_tasks_detail_back = Button.new()
	_tasks_detail_back.focus_mode = Control.FOCUS_NONE
	_tasks_detail_back.offset_left = 36.0
	_tasks_detail_back.offset_right = 764.0
	_tasks_detail_back.offset_top = 612.0
	_tasks_detail_back.offset_bottom = 684.0
	UiFont.apply_button(_tasks_detail_back, 22)
	_tasks_detail_back.text = Loc.t("pause.tasks.back")
	_tasks_detail_back.pressed.connect(func() -> void:
		SfxBus.play("sfx_ui_cancel")
		_exit_tasks_detail(true)
	)
	_tasks_detail_root.add_child(_tasks_detail_back)


func _clear_tasks_detail() -> void:
	_tasks_detail_back = null
	_tasks_detail_scroll = null
	if _tasks_detail_root != null and is_instance_valid(_tasks_detail_root):
		_tasks_detail_root.queue_free()
	_tasks_detail_root = null


func _scroll_tasks_detail(dir: int) -> void:
	if _tasks_detail_scroll == null:
		return
	var step := 56.0 * float(dir)
	_tasks_detail_scroll.scroll_vertical = maxi(
		0,
		_tasks_detail_scroll.scroll_vertical + int(step)
	)
	SfxBus.play("sfx_ui_move")


func _tasks_detail_input(event: InputEvent) -> void:
	var dir := _dir_of(event)
	if dir == 0:
		_scroll_tasks_detail(-1)
		get_viewport().set_input_as_handled()
	elif dir == 1:
		_scroll_tasks_detail(1)
		get_viewport().set_input_as_handled()
	elif dir == 2 or dir == 3:
		get_viewport().set_input_as_handled()
	elif _is_confirm(event) or _is_cancel(event):
		get_viewport().set_input_as_handled()
		SfxBus.play("sfx_ui_cancel")
		_exit_tasks_detail(true)


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
	if game != null and game.has_method("tutorial_blocks_settle") and bool(game.call("tutorial_blocks_settle")):
		SfxBus.play("sfx_ui_cancel")
		if game.has_method("play_skill_banner"):
			game.call("play_skill_banner", Loc.t("tut.gate.ops"))
		return
	if SessionService.is_networked() and not SessionService.request_end_day():
		return
	close_menu()
	end_day_requested.emit()


func _game_state():
	if game == null:
		return null
	return game.get("state")


func _tutorial_director() -> Node:
	if game != null and game.has_method("tutorial"):
		return game.tutorial()
	return null


func _lesson_review_title(lesson_id: String) -> String:
	var lesson := TutorialCatalog.lesson_by_id(lesson_id)
	var pages = lesson.get("pages", [])
	if pages is Array and not pages.is_empty() and pages[0] is Dictionary:
		var key := String((pages[0] as Dictionary).get("title_key", ""))
		if key != "":
			return Loc.t(key)
	return lesson_id


func _build_tut_review() -> void:
	_clear_tut_review()
	var card := _resume_btn.get_parent()
	if card == null:
		return
	_tut_review_root = Control.new()
	_tut_review_root.name = "TutorialReviewRoot"
	_tut_review_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tut_review_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_tut_review_root)
	_tut_review_scroll = ScrollContainer.new()
	_tut_review_scroll.offset_left = 36.0
	_tut_review_scroll.offset_right = 764.0
	_tut_review_scroll.offset_top = 214.0
	_tut_review_scroll.offset_bottom = 600.0
	_tut_review_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tut_review_root.add_child(_tut_review_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(720, 0)
	_tut_review_scroll.add_child(box)
	_tut_review_ids.clear()
	_tut_review_btns.clear()
	var st = _game_state()
	var done_ids: Array[String] = []
	if st != null and st.has_method("list_tutorial_done_ids"):
		done_ids = st.list_tutorial_done_ids()
	if done_ids.is_empty():
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.text = Loc.t("pause.tutorial.empty")
		UiFont.apply_label(empty, 22)
		empty.add_theme_color_override("font_color", Color("f4f1ea"))
		box.add_child(empty)
	else:
		for i in done_ids.size():
			var lid := done_ids[i]
			_tut_review_ids.append(lid)
			var btn := Button.new()
			btn.focus_mode = Control.FOCUS_NONE
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 56)
			UiFont.apply_button(btn, 22)
			btn.text = _lesson_review_title(lid)
			var idx := i
			btn.pressed.connect(func() -> void:
				_tut_review_focus = idx
				_activate_tut_review()
			)
			box.add_child(btn)
			_tut_review_btns.append(btn)
	_tut_review_back = Button.new()
	_tut_review_back.focus_mode = Control.FOCUS_NONE
	_tut_review_back.offset_left = 36.0
	_tut_review_back.offset_right = 764.0
	_tut_review_back.offset_top = 612.0
	_tut_review_back.offset_bottom = 684.0
	UiFont.apply_button(_tut_review_back, 22)
	_tut_review_back.text = Loc.t("pause.tutorial.back")
	_tut_review_back.pressed.connect(func() -> void:
		SfxBus.play("sfx_ui_cancel")
		_exit_tut_review(true)
	)
	_tut_review_root.add_child(_tut_review_back)


func _clear_tut_review() -> void:
	_tut_review_btns.clear()
	_tut_review_ids.clear()
	_tut_review_back = null
	_tut_review_scroll = null
	if _tut_review_root != null and is_instance_valid(_tut_review_root):
		_tut_review_root.queue_free()
	_tut_review_root = null


func _tut_review_count() -> int:
	return _tut_review_btns.size() + (1 if _tut_review_back != null else 0)


func _move_tut_review_focus(delta: int) -> void:
	var n := _tut_review_count()
	if n <= 0:
		return
	_tut_review_focus = posmod(_tut_review_focus + delta, n)
	SfxBus.play("sfx_ui_move")
	_paint_focus()


func _activate_tut_review() -> void:
	if _tut_review_focus >= 0 and _tut_review_focus < _tut_review_btns.size():
		var lid := _tut_review_ids[_tut_review_focus] if _tut_review_focus < _tut_review_ids.size() else ""
		var dir := _tutorial_director()
		if lid != "" and dir != null:
			SfxBus.play("sfx_ui_confirm")
			## Close pause so tutorial modal can own tree pause cleanly.
			close_menu()
			resume_requested.emit()
			dir.open_review(lid)
		return
	SfxBus.play("sfx_ui_cancel")
	_exit_tut_review(true)


func _tut_review_input(event: InputEvent) -> void:
	var dir := _dir_of(event)
	if dir == 0:
		_move_tut_review_focus(-1)
		get_viewport().set_input_as_handled()
	elif dir == 1:
		_move_tut_review_focus(1)
		get_viewport().set_input_as_handled()
	elif _is_confirm(event):
		get_viewport().set_input_as_handled()
		_activate_tut_review()
	elif _is_cancel(event):
		get_viewport().set_input_as_handled()
		SfxBus.play("sfx_ui_cancel")
		_exit_tut_review(true)


func _paint_focus() -> void:
	if _lang_pick:
		for i in _lang_pick_btns.size():
			_style_btn(_lang_pick_btns[i], _lang_pick_focus == i)
		if _lang_pick_back:
			_style_btn(_lang_pick_back, _lang_pick_focus == _lang_pick_btns.size())
		return
	if _tasks_detail:
		if _tasks_detail_back:
			_style_btn(_tasks_detail_back, true)
		return
	if _tut_review:
		for i in _tut_review_btns.size():
			_style_btn(_tut_review_btns[i], _tut_review_focus == i)
		if _tut_review_back:
			_style_btn(_tut_review_back, _tut_review_focus == _tut_review_btns.size())
		return
	_style_btn(_resume_btn, _focus == FOCUS_RESUME)
	if _tasks_btn:
		_style_btn(_tasks_btn, _focus == FOCUS_TASKS)
	if _tutorial_btn:
		_style_btn(_tutorial_btn, _focus == FOCUS_TUTORIAL)
	_style_btn(_sfx_btn, _focus == FOCUS_SFX)
	var vol_on := _focus == FOCUS_VOL
	_style_btn(_vol_btn, vol_on)
	_style_btn(_vol_down, vol_on)
	_style_btn(_vol_up, vol_on)
	if _bgm_btn:
		_style_btn(_bgm_btn, _focus == FOCUS_BGM)
	var bgm_vol_on := _focus == FOCUS_BGM_VOL
	if _bgm_vol_btn:
		_style_btn(_bgm_vol_btn, bgm_vol_on)
	if _bgm_vol_down:
		_style_btn(_bgm_vol_down, bgm_vol_on)
	if _bgm_vol_up:
		_style_btn(_bgm_vol_up, bgm_vol_on)
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
