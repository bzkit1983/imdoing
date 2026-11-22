extends CanvasLayer

signal exited

const Course = preload("res://scripts/prep/dasher_course.gd")
const UiFont = preload("res://scripts/ui_font.gd")

var course: Course
var _held := {}
var _sticks := {}
var _jump := false
var _dash := false
var _view: Control
var _lives: Label
var _status: Label
var _notice: Label
var _cover: CenterContainer
var _heading: Label
var _details: Label
var _start: Button
var _restart: Button
var _back: Button
var _started := false


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("141421")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	background.add_child(aspect)
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view = Control.new()
	aspect.add_child(_view)
	var screen := TextureRect.new()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	course = Course.new()
	viewport.add_child(course)
	screen.texture = viewport.get_texture()
	_build_ui()
	Loc.locale_changed.connect(_localize)
	get_window().focus_exited.connect(_clear_input)
	_localize()


func _build_ui() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	_view.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_top = 12
	_lives = _label(bar, UiFont.SIZE_BODY)
	_lives.add_theme_stylebox_override("normal", _warm_panel("FFFDF2", 14, 8))
	_status = _label(bar, UiFont.SIZE_BODY)
	_status.add_theme_stylebox_override("normal", _warm_panel("FFFDF2", 14, 8))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_restart = _button(bar, _reset)
	_back = _button(bar, _exit)
	_notice = _label(_view, UiFont.SIZE_BODY)
	_notice.add_theme_color_override("font_color", Color("fff1c4"))
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_notice.offset_top = 65
	_notice.offset_bottom = 106
	_cover = CenterContainer.new()
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_cover)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _warm_panel("FFFDF2", 28, 10))
	_cover.add_child(panel)
	var inset := PanelContainer.new()
	inset.add_theme_stylebox_override("panel", _warm_panel("F7EED6", 20, 18))
	panel.add_child(inset)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	inset.add_child(column)
	_heading = _label(column, UiFont.SIZE_HEADING)
	_details = _label(column, UiFont.SIZE_BODY_SM)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size.x = 410
	_start = _button(column, _reset)


func _label(parent: Control, size_px: int) -> Label:
	var label := Label.new()
	UiFont.apply_label(label, size_px, UiFont.WEIGHT_REGULAR, 0)
	label.add_theme_color_override("font_color", Color("5C4938"))
	parent.add_child(label)
	return label


func _button(parent: Control, action: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 44
	UiFont.apply_button_literal(button, UiFont.SIZE_BODY_SM)
	button.add_theme_stylebox_override("normal", _warm_panel("FFFDF2", 24, 8))
	button.add_theme_stylebox_override("hover", _warm_panel("FFD43B", 24, 8))
	button.add_theme_stylebox_override("pressed", _warm_panel("FFD43B", 24, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("5C4938"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _warm_panel(fill: String, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color("E0AC16" if fill == "FFD43B" else "DFD3B8")
	style.set_border_width_all(2)
	style.border_width_bottom = 4
	style.set_corner_radius_all(radius)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style


func _localize(_locale: String = "") -> void:
	_back.text = Loc.t("prep.back")
	_restart.text = Loc.t("prep.dasher.restart")
	_start.text = Loc.t("prep.dasher.start" if not _started else "prep.dasher.restart")
	if not _started:
		_heading.text = Loc.t("skill.dasher.name")
		_details.text = Loc.t("prep.dasher.rules", [Course.LIFE_LIMIT, Course.DASH_LIMIT])
	elif not course.running:
		_heading.text = Loc.t("prep.dasher.win" if course.won else "prep.dasher.game_over")
		_details.text = Loc.t("prep.dasher.result", [course.elapsed, course.dashes, Course.DASH_LIMIT])
	_update_hud()


func _reset() -> void:
	_started = true
	_jump = false
	_dash = false
	_cover.hide()
	course.reset()
	_localize()


func _exit() -> void:
	course.running = false
	set_process_input(false)
	hide()
	exited.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	if not course.running:
		return
	var direction := 0.0
	for value in _held.values():
		direction += float(value)
	for value in _sticks.values():
		direction += float(value)
	course.step(delta, signf(direction), _jump, _dash)
	_jump = false
	_dash = false
	_update_hud()
	if not course.running:
		_cover.show()
		_localize()


func _update_hud() -> void:
	_lives.text = Loc.t("prep.dasher.lives", [course.lives, Course.LIFE_LIMIT])
	_status.text = Loc.t("prep.dasher.dashes", [course.dashes, Course.DASH_LIMIT])
	var notice_key := "prep.dasher.enemy_hit" if course.hit_enemy else "prep.dasher.fall"
	_notice.text = Loc.t(notice_key) if course.life_loss_notice > 0 else ""


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X:
			_sticks[event.device] = signf(event.axis_value) if absf(event.axis_value) >= 0.25 else 0.0
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_LEFT, KEY_A:
				_move_input("key:%d" % key, event.pressed, -1.0)
			KEY_RIGHT, KEY_D:
				_move_input("key:%d" % key, event.pressed, 1.0)
			KEY_SPACE:
				if event.pressed and not event.echo:
					_jump_or_start()
			KEY_SHIFT:
				if event.pressed and not event.echo:
					_dash = course.running
			KEY_R:
				if event.pressed and not event.echo:
					_reset()
			KEY_ESCAPE:
				if event.pressed and not event.echo:
					_exit()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
				var direction := -1.0 if event.button_index == JOY_BUTTON_DPAD_LEFT else 1.0
				_move_input("pad:%d:%d" % [event.device, event.button_index], event.pressed, direction)
			JOY_BUTTON_A:
				if event.pressed:
					_jump_or_start()
			JOY_BUTTON_X:
				if event.pressed:
					_dash = course.running
			JOY_BUTTON_Y:
				if event.pressed:
					_reset()
			JOY_BUTTON_B:
				if event.pressed:
					_exit()
		get_viewport().set_input_as_handled()


func _clear_input() -> void:
	_held.clear()
	_sticks.clear()
	_jump = false
	_dash = false


func _move_input(source: String, pressed: bool, direction: float) -> void:
	if pressed:
		_held[source] = direction
	else:
		_held.erase(source)


func _jump_or_start() -> void:
	if course.running:
		_jump = true
	else:
		_reset()
