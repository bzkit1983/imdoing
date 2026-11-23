extends CanvasLayer

signal exited

const UiFont = preload("res://scripts/ui_font.gd")
const QUESTION_COUNT := 5
const QUESTION_SECONDS := 15.0
const MIN_PRICE_TENTHS := 50
const MAX_PRICE_TENTHS := 499
const PAYMENT_STEP_TENTHS := 50

var _view: Control
var _question_count: Label
var _timer_label: Label
var _prompt: Label
var _answer: Label
var _keypad: GridContainer
var _cover: CenterContainer
var _heading: Label
var _details: Label
var _start: Button
var _back_button: Button
var _reward_dialog: AcceptDialog
var _answer_text := ""
var _prices: Array[int] = []
var _tender_tenths := 0
var _correct_tenths := 0
var _score := 0
var _time_left := 0.0
var _running := false
var _finished := false
var _won := false
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("161629")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	background.add_child(aspect)
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view = Control.new()
	aspect.add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var backdrop := get_node("Backdrop")
	remove_child(backdrop)
	viewport.add_child(backdrop)
	var screen := TextureRect.new()
	screen.texture = viewport.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_random.randomize()
	Loc.locale_changed.connect(_localize)
	get_window().focus_exited.connect(_clear_focus)
	_localize()
	_set_running(false)


func _build_ui() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_view.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24
	column.offset_right = -24
	column.offset_top = 24
	column.offset_bottom = -24

	var top := HBoxContainer.new()
	column.add_child(top)
	_question_count = _label(top, UiFont.SIZE_BODY_SM)
	_question_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_label = _label(top, UiFont.SIZE_BODY_SM)
	_back_button = _button(top, _exit, UiFont.SIZE_CAPTION)
	_back_button.custom_minimum_size.x = 110

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var prompt_panel := PanelContainer.new()
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color("fff5dd")
	prompt_style.border_color = Color("1b1c2e")
	prompt_style.set_border_width_all(3)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		prompt_style.set_content_margin(side, 12)
	prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(prompt_panel)
	_prompt = _label(prompt_panel, UiFont.SIZE_BODY)
	_prompt.add_theme_color_override("font_color", Color("20202d"))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size.x = 550

	var answer_row := HBoxContainer.new()
	answer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(answer_row)
	var answer_panel := PanelContainer.new()
	var answer_style := StyleBoxFlat.new()
	answer_style.bg_color = Color("fffdf5")
	answer_style.border_color = Color("2b2b39")
	answer_style.set_border_width_all(2)
	answer_style.set_content_margin(SIDE_LEFT, 12)
	answer_style.set_content_margin(SIDE_RIGHT, 12)
	answer_style.set_content_margin(SIDE_TOP, 4)
	answer_style.set_content_margin(SIDE_BOTTOM, 4)
	answer_panel.add_theme_stylebox_override("panel", answer_style)
	answer_row.add_child(answer_panel)
	_answer = _label(answer_panel, UiFont.SIZE_BODY)
	_answer.add_theme_color_override("font_color", Color("20202d"))
	_answer.custom_minimum_size.x = 300
	_answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_keypad = GridContainer.new()
	_keypad.columns = 3
	_keypad.add_theme_constant_override("h_separation", 6)
	_keypad.add_theme_constant_override("v_separation", 6)
	_keypad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_keypad)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "prep.cashier_duel.delete", "0", "prep.cashier_duel.decimal"]:
		var key_label: String = Loc.t(key) if key == "prep.cashier_duel.delete" else "." if key == "prep.cashier_duel.decimal" else key
		var key_value: String = "backspace" if key == "prep.cashier_duel.delete" else "decimal" if key == "prep.cashier_duel.decimal" else key
		var button := _button(_keypad, _press_key.bind(key_value), UiFont.SIZE_BODY_SM)
		button.text = key_label
		if key == "prep.cashier_duel.decimal":
			button.tooltip_text = Loc.t(key)
		button.custom_minimum_size = Vector2(72, 48)

	var submit := _button(column, _submit_answer, UiFont.SIZE_BODY_SM)
	submit.custom_minimum_size = Vector2(220, 48)
	submit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	submit.name = "SubmitButton"

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bottom_spacer)

	_cover = CenterContainer.new()
	_view.add_child(_cover)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff4d9")
	style.border_color = Color("29263d")
	style.set_border_width_all(4)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 24)
	panel.add_theme_stylebox_override("panel", style)
	_cover.add_child(panel)
	var cover_column := VBoxContainer.new()
	cover_column.add_theme_constant_override("separation", 12)
	panel.add_child(cover_column)
	_heading = _label(cover_column, UiFont.SIZE_HEADING)
	_heading.add_theme_color_override("font_color", Color("20202d"))
	_details = _label(cover_column, UiFont.SIZE_BODY_SM)
	_details.add_theme_color_override("font_color", Color("20202d"))
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size.x = 460
	_start = _button(cover_column, _start_or_restart, UiFont.SIZE_BODY_SM)
	_start.custom_minimum_size = Vector2(240, 48)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_reward_dialog = AcceptDialog.new()
	_reward_dialog.dialog_autowrap = true
	var dialog_theme := Theme.new()
	dialog_theme.default_font = UiFont.font()
	dialog_theme.default_font_size = UiFont.SIZE_BODY_SM
	_reward_dialog.theme = dialog_theme
	add_child(_reward_dialog)
	_reward_dialog.confirmed.connect(_focus_restart_button)
	_reward_dialog.canceled.connect(_focus_restart_button)
	_cover.show()


func _label(parent: Control, size_px: int) -> Label:
	var label := Label.new()
	UiFont.apply_label(label, size_px, UiFont.WEIGHT_BOLD, 2)
	label.add_theme_color_override("font_color", Color("fff8df"))
	parent.add_child(label)
	return label


func _button(parent: Control, action: Callable, size_px: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 40
	UiFont.apply_button_literal(button, size_px)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _localize(_locale: String = "") -> void:
	if not is_instance_valid(_cover):
		return
	_start.text = Loc.t("prep.cashier_duel.start" if not _finished else "prep.cashier_duel.retry")
	_back_button.text = Loc.t("prep.back")
	_question_count.text = Loc.t("prep.cashier_duel.progress", [_score, QUESTION_COUNT])
	_timer_label.text = Loc.t("prep.cashier_duel.timer", [maxf(_time_left, 0.0)])
	if _prices.size() == 2:
		_prompt.text = Loc.t("prep.cashier_duel.prompt", [
			_format_money(_prices[0]), _format_money(_prices[1]), _format_money(_tender_tenths)
		])
	else:
		_prompt.text = ""
	_update_answer_display()
	if _finished:
		_heading.text = Loc.t("prep.cashier_duel.success" if _won else "prep.cashier_duel.failed")
		_details.text = Loc.t("prep.cashier_duel.result", [_score, QUESTION_COUNT])
	else:
		_heading.text = Loc.t("skill.checkout_rush.name")
		_details.text = Loc.t("prep.cashier_duel.rules") + "\n" + Loc.t("prep.cashier_duel.pad_controls")
	var submit := _view.find_child("SubmitButton", true, false) as Button
	if submit != null:
		submit.text = Loc.t("prep.cashier_duel.submit")
	if _keypad != null and _keypad.get_child_count() == 12:
		(_keypad.get_child(9) as Button).text = Loc.t("prep.cashier_duel.delete")
		(_keypad.get_child(11) as Button).tooltip_text = Loc.t("prep.cashier_duel.decimal")
	if _reward_dialog != null:
		_reward_dialog.title = Loc.t("prep.cashier_duel.reward_title")
		_reward_dialog.dialog_text = Loc.t("prep.cashier_duel.reward", [Loc.t("skill.checkout_rush.name")])
		_reward_dialog.ok_button_text = Loc.t("prep.cashier_duel.submit")


func _process(delta: float) -> void:
	if not _running:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_timer_label.text = Loc.t("prep.cashier_duel.timer", [_time_left])
	if _time_left <= 0.0:
		_end_run(false)
		return


func _start_or_restart() -> void:
	_score = 0
	_finished = false
	_won = false
	_answer_text = ""
	_cover.hide()
	_randomize_question()
	_set_running(true)
	_localize()
	_focus_first_key()


func _randomize_question() -> void:
	_prices.clear()
	var total_tenths := 0
	for _i in range(2):
		var price := _random.randi_range(MIN_PRICE_TENTHS, MAX_PRICE_TENTHS)
		_prices.append(price)
		total_tenths += price
	_tender_tenths = (floori(float(total_tenths) / PAYMENT_STEP_TENTHS) + 1) * PAYMENT_STEP_TENTHS
	_correct_tenths = _tender_tenths - total_tenths
	_answer_text = ""
	_time_left = QUESTION_SECONDS


func _press_key(value: String) -> void:
	if not _running:
		return
	match value:
		"backspace":
			if not _answer_text.is_empty():
				_answer_text = _answer_text.substr(0, _answer_text.length() - 1)
		"decimal":
			if not _answer_text.contains("."):
				_answer_text += "."
		_:
			if _answer_text.length() < 6:
				_answer_text += value
	_update_answer_display()


func _update_answer_display() -> void:
	if _answer == null:
		return
	var amount := "$" + _answer_text if not _answer_text.is_empty() else "$ —"
	_answer.text = "%s: %s" % [Loc.t("prep.cashier_duel.answer"), amount]


func _submit_answer() -> void:
	if not _running:
		return
	var entered_tenths := _parse_tenths(_answer_text)
	if entered_tenths < 0:
		return
	_set_running(false)
	if entered_tenths != _correct_tenths:
		_end_run(false)
		return
	_score += 1
	if _score >= QUESTION_COUNT:
		_end_run(true)
	else:
		_randomize_question()
		_set_running(true)
		_localize()
		_focus_first_key()


func _parse_tenths(text: String) -> int:
	var parts := text.strip_edges().split(".", true)
	if parts.is_empty() or parts.size() > 2 or not parts[0].is_valid_int():
		return -1
	var whole := parts[0].to_int()
	var decimal := 0
	if parts.size() == 2 and not parts[1].is_empty():
		if parts[1].length() != 1 or not parts[1].is_valid_int():
			return -1
		decimal = parts[1].to_int()
	return whole * 10 + decimal


func _end_run(success: bool) -> void:
	_set_running(false)
	_finished = true
	_won = success
	_cover.show()
	_localize()
	if success:
		_reward_dialog.popup_centered()
	else:
		_start.grab_focus()


func _set_running(value: bool) -> void:
	_running = value
	if _keypad != null:
		_keypad.visible = value
	var submit: Button = null
	if _view != null:
		submit = _view.find_child("SubmitButton", true, false) as Button
	if submit != null:
		submit.visible = value
	if _answer != null:
		_answer.visible = value
	if _timer_label != null:
		_timer_label.visible = value
	if _question_count != null:
		_question_count.visible = value
	if _prompt != null:
		_prompt.visible = value


func _format_money(tenths: int) -> String:
	return "%d.%d" % [floori(float(tenths) / 10.0), tenths % 10]


var _pad_cell := 0
var _pad_axes := Vector2i.ZERO


func _move_pad_cursor(direction: Vector2i) -> void:
	var cell := Vector2i(_pad_cell % 3, floori(_pad_cell / 3.0))
	cell = (cell + direction).clamp(Vector2i.ZERO, Vector2i(2, 3))
	_pad_cell = cell.y * 3 + cell.x
	(_keypad.get_child(_pad_cell) as Button).grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_ESCAPE:
			_exit()
			get_viewport().set_input_as_handled()
			return
		if not _running:
			return
		if key >= KEY_0 and key <= KEY_9:
			_press_key(str(key - KEY_0))
		elif key >= KEY_KP_0 and key <= KEY_KP_9:
			_press_key(str(key - KEY_KP_0))
		elif key == KEY_PERIOD or key == KEY_KP_PERIOD or key == KEY_COMMA:
			_press_key("decimal")
		elif key == KEY_BACKSPACE or key == KEY_DELETE:
			_press_key("backspace")
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			_submit_answer()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		if not pad.pressed or _reward_dialog.visible:
			return
		match pad.button_index:
			JOY_BUTTON_B: _exit()
			JOY_BUTTON_A:
				if _running:
					(_keypad.get_child(_pad_cell) as Button).pressed.emit()
				else:
					_start_or_restart()
			JOY_BUTTON_X:
				if _running: _press_key("backspace")
			JOY_BUTTON_Y, JOY_BUTTON_START:
				if _running: _submit_answer()
			JOY_BUTTON_DPAD_LEFT:
				if _running: _move_pad_cursor(Vector2i.LEFT)
			JOY_BUTTON_DPAD_RIGHT:
				if _running: _move_pad_cursor(Vector2i.RIGHT)
			JOY_BUTTON_DPAD_UP:
				if _running: _move_pad_cursor(Vector2i.UP)
			JOY_BUTTON_DPAD_DOWN:
				if _running: _move_pad_cursor(Vector2i.DOWN)
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and _running:
		var motion := event as InputEventJoypadMotion
		var axis := motion.axis
		if axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			return
		var horizontal := axis == JOY_AXIS_LEFT_X
		var previous := _pad_axes.x if horizontal else _pad_axes.y
		var threshold := 0.55 if previous == 0 else 0.35
		var direction := int(signf(motion.axis_value)) if absf(motion.axis_value) >= threshold else 0
		if horizontal:
			_pad_axes.x = direction
		else:
			_pad_axes.y = direction
		if direction != 0 and direction != previous:
			_move_pad_cursor(Vector2i(direction, 0) if horizontal else Vector2i(0, direction))
		get_viewport().set_input_as_handled()


func _clear_focus() -> void:
	_pad_axes = Vector2i.ZERO
	if _view == null:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and _view.is_ancestor_of(focus):
		focus.release_focus()


func _focus_restart_button() -> void:
	if is_instance_valid(_start):
		_start.grab_focus()


func _focus_first_key() -> void:
	if _keypad != null and _keypad.get_child_count() > 0:
		_pad_cell = 0
		(_keypad.get_child(0) as Button).grab_focus()


func _exit() -> void:
	_running = false
	set_process_input(false)
	if _reward_dialog != null and _reward_dialog.visible:
		_reward_dialog.hide()
	hide()
	exited.emit()
	queue_free()
