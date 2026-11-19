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
const FOCUS_SETTINGS := 3
const FOCUS_LANG := 4
const FOCUS_END := 5
const FOCUS_COUNT := 6
## Settings submenu focus (when _settings).
const SET_SFX := 0
const SET_VOL := 1
const SET_BGM := 2
const SET_BGM_VOL := 3
const SET_STICK := 4
const SET_CAMERA := 5
const SET_BACK := 6
const SET_COUNT := 7

const TutorialCatalog = preload("res://scripts/tutorial/tutorial_catalog.gd")

## pause-ui-chrome + docs/systemdesign/uitypography.md
const COL_COCOA := Color("5C4938")
const COL_TAUPE := Color("9C8B7A")
const SIZE_CAPTION := 16
const SIZE_BODY_SM := 22
const SIZE_BODY := 29
const SIZE_HEADING_SM := 43
const SPACE_12 := 12.0
const SPACE_24 := 24.0
const SPACE_30 := 30.0
## Editor-tuned (pause_menu.tscn bake) — left title／body, right pill column.
const ROW_H_MAX := 84.0
const ROW_H_MIN := 56.0
const ROW_LEFT := 345.0
const ROW_RIGHT := 681.0
const VOL_ROW_LEFT := 223.0
const VOL_ROW_RIGHT := 803.0
const ROW_GAP := 2.0
const ROWS_TOP_MAIN := 58.0
const ROWS_TOP_SETTINGS := 58.0
const TITLE_LEFT := 66.0
const TITLE_RIGHT := 245.0
const TITLE_TOP := 57.0
const TITLE_BOTTOM := 120.0
const BODY_LEFT := 69.0
const BODY_RIGHT := 299.0
const BODY_TOP := 125.0
const BODY_BOTTOM := 292.0
const VOL_MINI := 60.0
## Mid pill vs ± nest (editor: ± ends past mid start by ~14px).
const VOL_SIDE_NEST := 14.0
const GAP_MIN := -4.0

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
## Settings submenu (SFX／BGM／stick／camera／back). Language stays on main list.
var _settings: bool = false
var _settings_focus: int = 0
## Brief yellow flash on ± while nudging volume (mid pill stays focus yellow).
var _vol_flash_btn: Button = null
var _vol_flash_gen: int = 0

@onready var _shade: ColorRect = %Shade
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _hint: Label = %Hint
@onready var _resume_btn: Button = %ResumeBtn
@onready var _tasks_btn: Button = %TasksBtn
@onready var _tutorial_btn: Button = %TutorialBtn
@onready var _settings_btn: Button = %SettingsBtn
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
## Scene node (editor-tuned); was runtime Button.new().
@onready var _settings_back: Button = %SettingbackBtn


func setup(host: Node) -> void:
	game = host
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_open = false
	UiFont.apply_title_bold(_title, SIZE_HEADING_SM)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_color_override("font_color", COL_COCOA)
	UiFont.apply_label(_body, SIZE_BODY)
	_body.add_theme_color_override("font_color", COL_TAUPE)
	UiFont.apply_label(_hint, SIZE_CAPTION)
	_hint.add_theme_color_override("font_color", COL_TAUPE)
	for b in [
		_resume_btn, _tasks_btn, _tutorial_btn, _settings_btn, _sfx_btn, _vol_btn, _vol_down, _vol_up,
		_bgm_btn, _bgm_vol_btn, _bgm_vol_down, _bgm_vol_up,
		_stick_btn, _camera_btn, _lang_btn, _end_btn, _settings_back,
	]:
		if b == null:
			continue
		UiFont.apply_button_literal(b, SIZE_BODY_SM)
		b.focus_mode = Control.FOCUS_NONE
	_mark_mini_btn(_vol_down)
	_mark_mini_btn(_vol_up)
	_mark_mini_btn(_bgm_vol_down)
	_mark_mini_btn(_bgm_vol_up)
	## Do not clip VolRow — short rows used to crop cream mini ± into gray stubs.
	if _vol_btn != null and _vol_btn.get_parent() is Control:
		(_vol_btn.get_parent() as Control).clip_contents = false
	if _bgm_vol_btn != null and _bgm_vol_btn.get_parent() is Control:
		(_bgm_vol_btn.get_parent() as Control).clip_contents = false
	_resume_btn.pressed.connect(_on_resume)
	if _tasks_btn:
		_tasks_btn.pressed.connect(_enter_tasks_detail)
	if _tutorial_btn:
		_tutorial_btn.pressed.connect(_enter_tut_review)
	if _settings_btn:
		_settings_btn.pressed.connect(_enter_settings)
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
	_wire_settings_back()
	## Editor default: main page visible, settings chrome hidden.
	_set_main_options_visible(true)
	_set_settings_options_visible(false)
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
	_exit_settings(false)
	visible = true
	_set_settings_options_visible(false)
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
	_exit_settings(false)
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
		if _settings and not _lang_pick and not _tasks_detail:
			if _settings_focus == SET_SFX or _settings_focus == SET_VOL:
				_on_vol_nudge(1 if v.x > 0.0 else -1)
			elif _settings_focus == SET_BGM or _settings_focus == SET_BGM_VOL:
				_on_bgm_vol_nudge(1 if v.x > 0.0 else -1)
	else:
		if _lang_pick:
			_move_lang_pick_focus(1 if v.y > 0.0 else -1)
		elif _tasks_detail:
			_scroll_tasks_detail(1 if v.y > 0.0 else -1)
		elif _settings:
			_move_settings_focus(1 if v.y > 0.0 else -1)
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
	if _settings:
		_title.text = Loc.t("pause.settings.title")
		if _from_suspend:
			_body.text = Loc.t("pause.body_suspend")
		else:
			_body.text = Loc.t("pause.body")
		if InputMode.show_vj():
			_hint.text = Loc.t("pause.hint_touch")
		else:
			_hint.text = Loc.t("pause.hint")
		if _settings_back:
			_settings_back.text = Loc.t("pause.settings.back")
		_refresh_audio_labels()
		_refresh_stick_row()
		_refresh_camera_row()
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
	if _settings_btn:
		_settings_btn.text = Loc.t("pause.settings")
	_refresh_lang_row()
	_end_btn.text = Loc.t("pause.end_day")
	## Do not refresh settings-only rows here — that would re-show them on the main list.
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
	## Labels only; visibility is owned by settings／main shells.


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
	## Body＋control-hint chrome are for developers on main／settings; subpages may show context.
	var show := PlatformServices.is_show_dev_hud()
	if _hint:
		_hint.visible = show and not _settings
	if _body:
		## Language／tasks／tutorial reuse body for context; settings keeps title-only chrome.
		if _lang_pick or _tasks_detail or _tut_review:
			_body.visible = true
		elif _settings:
			_body.visible = false
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
	if _settings:
		_settings_input(event)
		return
	var dir := _dir_of(event)
	if dir == 0:
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif dir == 1:
		_move_focus(1)
		get_viewport().set_input_as_handled()
	elif dir == 2 or dir == 3:
		get_viewport().set_input_as_handled()
	elif _is_confirm(event):
		get_viewport().set_input_as_handled()
		_activate_focus()
	elif _is_cancel(event):
		get_viewport().set_input_as_handled()
		SfxBus.play("sfx_ui_cancel")
		_on_resume()


func _settings_input(event: InputEvent) -> void:
	var dir := _dir_of(event)
	if dir == 0:
		_move_settings_focus(-1)
		get_viewport().set_input_as_handled()
	elif dir == 1:
		_move_settings_focus(1)
		get_viewport().set_input_as_handled()
	elif dir == 2:
		## Mute row or volume row: A／D still nudges that bus's volume.
		if _settings_focus == SET_SFX or _settings_focus == SET_VOL:
			_on_vol_nudge(-1)
		elif _settings_focus == SET_BGM or _settings_focus == SET_BGM_VOL:
			_on_bgm_vol_nudge(-1)
		get_viewport().set_input_as_handled()
	elif dir == 3:
		if _settings_focus == SET_SFX or _settings_focus == SET_VOL:
			_on_vol_nudge(1)
		elif _settings_focus == SET_BGM or _settings_focus == SET_BGM_VOL:
			_on_bgm_vol_nudge(1)
		get_viewport().set_input_as_handled()
	elif _is_confirm(event):
		get_viewport().set_input_as_handled()
		_activate_settings_focus()
	elif _is_cancel(event):
		get_viewport().set_input_as_handled()
		SfxBus.play("sfx_ui_cancel")
		_exit_settings(true)


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
	var show_row := _settings and _stick_row_visible()
	_stick_btn.visible = show_row
	if show_row:
		_stick_btn.text = Loc.t(
			"pause.virtual_stick_on" if PlatformServices.is_virtual_stick_enabled() else "pause.virtual_stick_off"
		)
	if _settings:
		_layout_option_rows()
	if not show_row and _settings and _settings_focus == SET_STICK:
		_settings_focus = SET_CAMERA
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
	if _settings:
		_layout_option_rows()


func _refresh_lang_row() -> void:
	if _lang_btn == null:
		return
	var code := Loc.get_locale()
	var endonym := Loc.t("locale.name.%s" % code)
	_lang_btn.text = Loc.t("pause.language", [endonym])
	if _open and not _settings and not _lang_pick and not _tasks_detail and not _tut_review:
		_layout_option_rows()


func _layout_option_rows() -> void:
	## Editor-tuned narrow pills; volume rows stay wider.
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
	if _settings:
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
		if _settings_back != null and _settings_back.visible:
			rows.append(_settings_back)
	else:
		rows.append(_resume_btn)
		if _tasks_btn != null and _tasks_btn.visible:
			rows.append(_tasks_btn)
		if _tutorial_btn != null and _tutorial_btn.visible:
			rows.append(_tutorial_btn)
		if _settings_btn != null and _settings_btn.visible:
			rows.append(_settings_btn)
		if _lang_btn != null and _lang_btn.visible:
			rows.append(_lang_btn)
		if _end_btn != null and _end_btn.visible:
			rows.append(_end_btn)
	var n := rows.size()
	if n <= 0:
		return
	var gap := ROW_GAP
	var bottom_pad := SPACE_24
	var y0 := header_h
	var avail := maxf(80.0, inner_h - y0 - bottom_pad)
	var row_h := ROW_H_MAX
	var need := row_h * float(n) + gap * float(n - 1)
	if need > avail:
		## Prefer keeping plump height; allow slightly tighter (more negative) gap first.
		var gap_need := (avail - row_h * float(n)) / float(maxi(n - 1, 1))
		if gap_need >= GAP_MIN:
			gap = gap_need
		else:
			gap = GAP_MIN
			bottom_pad = maxf(8.0, bottom_pad - 8.0)
			avail = maxf(80.0, inner_h - y0 - bottom_pad)
			row_h = (avail - gap * float(n - 1)) / float(n)
			row_h = clampf(row_h, ROW_H_MIN, ROW_H_MAX)
	var font_px := SIZE_BODY_SM if row_h >= 56.0 else (18 if row_h >= 48.0 else SIZE_CAPTION)
	var y := y0
	var vol_parent := _vol_btn.get_parent() if _vol_btn else null
	var bgm_vol_parent := _bgm_vol_btn.get_parent() if _bgm_vol_btn else null
	for row in rows:
		var is_vol := row == vol_parent or row == bgm_vol_parent
		if is_vol:
			row.offset_left = VOL_ROW_LEFT
			row.offset_right = VOL_ROW_RIGHT
		else:
			row.offset_left = ROW_LEFT
			row.offset_right = ROW_RIGHT
		row.offset_top = y
		row.offset_bottom = y + row_h
		if row is Button:
			UiFont.apply_button_literal(row as Button, font_px)
		if is_vol:
			_layout_volume_row(row, row_h, font_px)
		y += row_h + gap


## Left-column title／body; right-column rows start at ROWS_TOP_* (body does not push Y).
func _layout_header_block() -> float:
	if _title:
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_title.offset_left = TITLE_LEFT
		_title.offset_right = TITLE_RIGHT
		_title.offset_top = TITLE_TOP
		_title.offset_bottom = TITLE_BOTTOM
	if _body != null and _body.visible:
		_body.offset_left = BODY_LEFT
		_body.offset_right = BODY_RIGHT
		_body.offset_top = BODY_TOP
		_body.offset_bottom = BODY_BOTTOM
	## Hint stays editor-placed; do not pull into header stack.
	return ROWS_TOP_SETTINGS if _settings else ROWS_TOP_MAIN


func _layout_volume_row(row: Control, row_h: float, font_px: int) -> void:
	## Wider row; mid pill same width as main pills; ± nest slightly into mid (editor).
	row.clip_contents = false
	var row_w := row.offset_right - row.offset_left
	var side_w := VOL_MINI
	var mid_w := ROW_RIGHT - ROW_LEFT
	var mid_left := (row_w - mid_w) * 0.5
	var mid_right := mid_left + mid_w
	var mini_top := maxf(0.0, (row_h - side_w) * 0.5)
	for child in row.get_children():
		if not child is Button:
			continue
		var b := child as Button
		UiFont.apply_button_literal(b, font_px)
		if b == _vol_down or b == _bgm_vol_down:
			b.offset_left = mid_left - side_w + VOL_SIDE_NEST
			b.offset_right = b.offset_left + side_w
			b.offset_top = mini_top
			b.offset_bottom = mini_top + side_w
		elif b == _vol_up or b == _bgm_vol_up:
			b.offset_right = mid_right + side_w - VOL_SIDE_NEST
			b.offset_left = b.offset_right - side_w
			b.offset_top = mini_top
			b.offset_bottom = mini_top + side_w
		else:
			b.offset_left = mid_left
			b.offset_right = mid_right
			b.offset_top = 0.0
			b.offset_bottom = row_h
			b.clip_text = true


func _move_focus(delta: int) -> void:
	var next := _focus
	for _i in FOCUS_COUNT:
		next = posmod(next + delta, FOCUS_COUNT)
		if next == FOCUS_END and _end_btn != null and not _end_btn.visible:
			continue
		break
	if next == _focus:
		return
	SfxBus.play("sfx_ui_move")
	_focus = next
	_paint_focus()


func _move_settings_focus(delta: int) -> void:
	var next := _settings_focus
	for _i in SET_COUNT:
		next = posmod(next + delta, SET_COUNT)
		if next == SET_STICK and not _stick_row_visible():
			continue
		break
	if next == _settings_focus:
		return
	SfxBus.play("sfx_ui_move")
	_settings_focus = next
	_paint_focus()


func _activate_focus() -> void:
	if _settings:
		_activate_settings_focus()
		return
	match _focus:
		FOCUS_RESUME:
			SfxBus.play("sfx_ui_confirm")
			_on_resume()
		FOCUS_TASKS:
			_enter_tasks_detail()
		FOCUS_TUTORIAL:
			_enter_tut_review()
		FOCUS_SETTINGS:
			_enter_settings()
		FOCUS_LANG:
			_enter_lang_pick()
		FOCUS_END:
			SfxBus.play("sfx_ui_confirm")
			_on_end_day()


func _activate_settings_focus() -> void:
	match _settings_focus:
		SET_SFX:
			_on_sfx_toggle()
		SET_VOL:
			_on_vol_preview()
		SET_BGM:
			_on_bgm_toggle()
		SET_BGM_VOL:
			_on_bgm_vol_preview()
		SET_STICK:
			_on_stick_toggle()
		SET_CAMERA:
			_on_camera_cycle()
		SET_BACK:
			SfxBus.play("sfx_ui_cancel")
			_exit_settings(true)


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
	_settings_focus = SET_VOL
	_paint_focus()
	var mini: Button = _vol_up if steps > 0 else _vol_down
	_flash_vol_mini(mini)


func _on_vol_preview() -> void:
	## J / tap center: sample current level (audible even if muted).
	SfxBus.play("sfx_ui_confirm", 1.0, NAN, true)
	_settings_focus = SET_VOL
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
	_settings_focus = SET_BGM_VOL
	_paint_focus()
	var mini: Button = _bgm_vol_up if steps > 0 else _bgm_vol_down
	_flash_vol_mini(mini)


func _on_bgm_vol_preview() -> void:
	var bgm := BgmBusScript.bus()
	if bgm:
		bgm.preview_volume()
	SfxBus.play("sfx_ui_confirm", 1.0, NAN, true)
	_settings_focus = SET_BGM_VOL
	_paint_focus()


func _on_stick_toggle() -> void:
	if not _stick_row_visible():
		return
	PlatformServices.toggle_virtual_stick()
	SfxBus.play("sfx_ui_confirm")
	_refresh_stick_row()
	_settings_focus = SET_STICK
	_paint_focus()


func _on_camera_cycle() -> void:
	PlatformServices.cycle_camera_view()
	SfxBus.play("sfx_ui_confirm")
	_refresh_camera_row()
	_settings_focus = SET_CAMERA
	_paint_focus()


func _enter_lang_pick() -> void:
	if _lang_pick:
		return
	_exit_tasks_detail(false)
	_exit_tut_review(false)
	_exit_settings(false)
	SfxBus.play("sfx_ui_confirm")
	_lang_pick = true
	_lang_pick_focus = 0
	_set_main_options_visible(false)
	_set_settings_options_visible(false)
	_build_lang_pick()
	_refresh_copy()
	_paint_focus()


func _exit_lang_pick(play_focus: bool) -> void:
	if not _lang_pick and _lang_pick_root == null:
		return
	_lang_pick = false
	_clear_lang_pick()
	if not _tasks_detail and not _tut_review and not _settings:
		_set_main_options_visible(true)
		_focus = FOCUS_LANG
	_refresh_copy()
	if play_focus:
		_paint_focus()


func _enter_tasks_detail() -> void:
	if _tasks_detail:
		return
	_exit_lang_pick(false)
	_exit_tut_review(false)
	_exit_settings(false)
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
	if not _lang_pick and not _tut_review and not _settings:
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
	_exit_settings(false)
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
	if not _lang_pick and not _tasks_detail and not _settings:
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
	if _settings_btn:
		_settings_btn.visible = on
	if _lang_btn:
		_lang_btn.visible = on
	## Host-only end-day; keep prior host_ok rule from _refresh_end_day_row.
	if on:
		_refresh_end_day_row()
	else:
		_end_btn.visible = false
	if on:
		_set_settings_options_visible(false)


func _set_settings_options_visible(on: bool) -> void:
	if _sfx_btn:
		_sfx_btn.visible = on
	if _vol_btn and _vol_btn.get_parent() is Control:
		(_vol_btn.get_parent() as Control).visible = on
	if _bgm_btn:
		_bgm_btn.visible = on
	if _bgm_vol_btn and _bgm_vol_btn.get_parent() is Control:
		(_bgm_vol_btn.get_parent() as Control).visible = on
	if _stick_btn:
		_stick_btn.visible = on and _stick_row_visible()
	if _camera_btn:
		_camera_btn.visible = on
	if _settings_back:
		_settings_back.visible = on
	if on:
		_layout_option_rows()


func _enter_settings() -> void:
	if _settings:
		return
	_exit_lang_pick(false)
	_exit_tasks_detail(false)
	_exit_tut_review(false)
	SfxBus.play("sfx_ui_confirm")
	_settings = true
	_settings_focus = SET_SFX
	_set_main_options_visible(false)
	_set_settings_options_visible(true)
	## Keep volume ± rows／back above other chrome so clicks hit −／＋／返回.
	_raise_volume_rows()
	_refresh_copy()
	_paint_focus()


func _raise_volume_rows() -> void:
	var card := _resume_btn.get_parent() if _resume_btn else null
	if card == null:
		return
	var vol_row := _vol_btn.get_parent() if _vol_btn else null
	var bgm_row := _bgm_vol_btn.get_parent() if _bgm_vol_btn else null
	if vol_row is Control:
		card.move_child(vol_row, card.get_child_count() - 1)
	if bgm_row is Control:
		card.move_child(bgm_row, card.get_child_count() - 1)
	if _settings_back != null and is_instance_valid(_settings_back):
		card.move_child(_settings_back, card.get_child_count() - 1)


func _exit_settings(play_focus: bool) -> void:
	if not _settings:
		return
	_settings = false
	_set_settings_options_visible(false)
	if not _lang_pick and not _tasks_detail and not _tut_review:
		_set_main_options_visible(true)
	_refresh_copy()
	_focus = FOCUS_SETTINGS
	if play_focus:
		_paint_focus()


func _wire_settings_back() -> void:
	## Scene %SettingbackBtn — do not Button.new()／queue_free.
	if _settings_back == null:
		return
	_settings_back.focus_mode = Control.FOCUS_NONE
	UiFont.apply_button_literal(_settings_back, SIZE_BODY_SM)
	_settings_back.text = Loc.t("pause.settings.back")
	if not _settings_back.pressed.is_connected(_on_settings_back_pressed):
		_settings_back.pressed.connect(_on_settings_back_pressed)


func _on_settings_back_pressed() -> void:
	SfxBus.play("sfx_ui_cancel")
	_exit_settings(true)


func _copy_pause_btn_styles(from_btn: Button, to_btn: Button) -> void:
	## Prefer canonical saved skins — painted focus may sit on "normal" override.
	if from_btn == null or to_btn == null:
		return
	_ensure_pause_btn_skin(from_btn)
	if from_btn.has_meta("_pause_normal"):
		var n: StyleBox = from_btn.get_meta("_pause_normal") as StyleBox
		var h: StyleBox = from_btn.get_meta("_pause_hover") as StyleBox
		var f: StyleBox = from_btn.get_meta("_pause_focus") as StyleBox
		if n != null:
			to_btn.add_theme_stylebox_override("normal", n)
		if h != null:
			to_btn.add_theme_stylebox_override("hover", h)
		else:
			to_btn.add_theme_stylebox_override("hover", n)
		for state_name in ["pressed", "hover_pressed", "disabled"]:
			var sb := from_btn.get_theme_stylebox(state_name)
			if sb != null:
				to_btn.add_theme_stylebox_override(state_name, sb)
		if f != null:
			to_btn.add_theme_stylebox_override("focus", f)
		## Force destination to re-cache cream normal (not a painted yellow).
		if to_btn.has_meta("_pause_skin_saved"):
			to_btn.remove_meta("_pause_skin_saved")
		return
	for state_name in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
		var sb2 := from_btn.get_theme_stylebox(state_name)
		if sb2 != null:
			to_btn.add_theme_stylebox_override(state_name, sb2)


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
	UiFont.apply_button_literal(_tasks_detail_back, SIZE_BODY_SM)
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
		UiFont.apply_button_literal(btn, SIZE_BODY_SM)
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
	UiFont.apply_button_literal(_lang_pick_back, SIZE_BODY_SM)
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
			UiFont.apply_button_literal(btn, SIZE_BODY_SM)
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
	UiFont.apply_button_literal(_tut_review_back, SIZE_BODY_SM)
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


func _flash_vol_mini(btn: Button) -> void:
	## Brief yellow on ± after nudge; mid pill focus unchanged.
	if btn == null:
		return
	_vol_flash_gen += 1
	var gen := _vol_flash_gen
	_vol_flash_btn = btn
	_style_btn(btn, true)
	await get_tree().create_timer(0.12).timeout
	if gen != _vol_flash_gen:
		return
	if _vol_flash_btn == btn:
		_vol_flash_btn = null
	_style_btn(btn, false)


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
	if _settings:
		_style_btn(_sfx_btn, _settings_focus == SET_SFX)
		var vol_on := _settings_focus == SET_VOL
		## Focus = mid pill only；± stay cream unless _flash_vol_mini.
		_style_btn(_vol_btn, vol_on)
		_style_btn(_vol_down, _vol_flash_btn == _vol_down)
		_style_btn(_vol_up, _vol_flash_btn == _vol_up)
		if _bgm_btn:
			_style_btn(_bgm_btn, _settings_focus == SET_BGM)
		var bgm_vol_on := _settings_focus == SET_BGM_VOL
		if _bgm_vol_btn:
			_style_btn(_bgm_vol_btn, bgm_vol_on)
		if _bgm_vol_down:
			_style_btn(_bgm_vol_down, _vol_flash_btn == _bgm_vol_down)
		if _bgm_vol_up:
			_style_btn(_bgm_vol_up, _vol_flash_btn == _bgm_vol_up)
		if _stick_btn and _stick_btn.visible:
			_style_btn(_stick_btn, _settings_focus == SET_STICK)
		if _camera_btn:
			_style_btn(_camera_btn, _settings_focus == SET_CAMERA)
		if _settings_back:
			_style_btn(_settings_back, _settings_focus == SET_BACK)
		return
	_style_btn(_resume_btn, _focus == FOCUS_RESUME)
	if _tasks_btn:
		_style_btn(_tasks_btn, _focus == FOCUS_TASKS)
	if _tutorial_btn:
		_style_btn(_tutorial_btn, _focus == FOCUS_TUTORIAL)
	if _settings_btn:
		_style_btn(_settings_btn, _focus == FOCUS_SETTINGS)
	if _lang_btn:
		_style_btn(_lang_btn, _focus == FOCUS_LANG)
	_style_btn(_end_btn, _focus == FOCUS_END)


func _mark_mini_btn(btn: Button) -> void:
	if btn == null:
		return
	btn.set_meta("_pause_kind", "mini")


func _is_mini_btn(btn: Button) -> bool:
	return btn != null and str(btn.get_meta("_pause_kind", "")) == "mini"


func _style_btn(btn: Button, on: bool) -> void:
	## Keep scene StyleBoxTexture skins. Selection = focus skin (no Flat wipe).
	if btn == null:
		return
	_ensure_pause_btn_skin(btn)
	var focus_sb: StyleBox = btn.get_meta("_pause_focus") as StyleBox
	var normal_sb: StyleBox = btn.get_meta("_pause_normal") as StyleBox
	var hover_sb: StyleBox = btn.get_meta("_pause_hover") as StyleBox
	if on and focus_sb != null:
		btn.add_theme_stylebox_override("normal", focus_sb)
		btn.add_theme_stylebox_override("hover", focus_sb)
	else:
		if normal_sb != null:
			btn.add_theme_stylebox_override("normal", normal_sb)
		if hover_sb != null:
			btn.add_theme_stylebox_override("hover", hover_sb)
	## Cream／gold pill art: Cocoa Ink (uitypography + pause-ui-chrome).
	btn.add_theme_color_override("font_color", COL_COCOA)
	btn.add_theme_color_override("font_hover_color", COL_COCOA)
	btn.add_theme_color_override("font_pressed_color", COL_COCOA)
	btn.add_theme_color_override("font_focus_color", COL_COCOA)


func _ensure_pause_btn_skin(btn: Button) -> void:
	if btn == null or btn.has_meta("_pause_skin_saved"):
		return
	## Mini ± must never inherit main-pill focus (yellow block over mid label).
	if _is_mini_btn(btn):
		_ensure_mini_btn_styles(btn)
	elif btn != _resume_btn and _resume_btn != null and _resume_btn.has_meta("_pause_skin_saved"):
		## New pills (SettingsBack etc.): clone Resume meta, not painted overrides.
		var rn: StyleBox = _resume_btn.get_meta("_pause_normal") as StyleBox
		var rh: StyleBox = _resume_btn.get_meta("_pause_hover") as StyleBox
		var rf: StyleBox = _resume_btn.get_meta("_pause_focus") as StyleBox
		if rn != null:
			btn.add_theme_stylebox_override("normal", rn)
		if rh != null:
			btn.add_theme_stylebox_override("hover", rh)
		if rf != null:
			btn.add_theme_stylebox_override("focus", rf)
		for state_name in ["pressed", "hover_pressed", "disabled"]:
			var sb := _resume_btn.get_theme_stylebox(state_name)
			if sb != null:
				btn.add_theme_stylebox_override(state_name, sb)
	else:
		var normal_sb := btn.get_theme_stylebox("normal")
		if normal_sb == null or not (normal_sb is StyleBoxTexture):
			if _resume_btn != null and btn != _resume_btn:
				_copy_pause_btn_styles(_resume_btn, btn)
	btn.set_meta("_pause_normal", btn.get_theme_stylebox("normal"))
	var hover_sb := btn.get_theme_stylebox("hover")
	if hover_sb == null:
		hover_sb = btn.get_theme_stylebox("normal")
	btn.set_meta("_pause_hover", hover_sb)
	var focus_sb := btn.get_theme_stylebox("focus")
	if focus_sb == null:
		## Prefer pressed for mini (mini_focus art); else normal.
		focus_sb = btn.get_theme_stylebox("pressed")
		if focus_sb == null:
			focus_sb = btn.get_theme_stylebox("normal")
	## Guard: never store the same box as both normal and focus for main pills.
	if not _is_mini_btn(btn) and focus_sb != null and focus_sb == btn.get_meta("_pause_normal"):
		if _resume_btn != null and _resume_btn.has_meta("_pause_focus"):
			focus_sb = _resume_btn.get_meta("_pause_focus") as StyleBox
	btn.set_meta("_pause_focus", focus_sb)
	btn.set_meta("_pause_skin_saved", true)


func _ensure_mini_btn_styles(btn: Button) -> void:
	## Keep mini normal／focus only — never copy Resume main-pill StyleBoxes.
	var n := btn.get_theme_stylebox("normal")
	var f := btn.get_theme_stylebox("pressed")
	if n == null and _vol_down != null and btn != _vol_down:
		n = _vol_down.get_theme_stylebox("normal")
		f = _vol_down.get_theme_stylebox("pressed")
	if n != null:
		btn.add_theme_stylebox_override("normal", n)
		btn.add_theme_stylebox_override("hover", n)
	if f != null:
		btn.add_theme_stylebox_override("pressed", f)
		btn.add_theme_stylebox_override("focus", f)
		btn.add_theme_stylebox_override("hover_pressed", f)


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
