extends CanvasLayer

signal exited

const Board = preload("res://scripts/prep/hoop_ace_board.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const COPY := "prep.hoop_trial."
const SKUS := ["can", "drink", "snack"]

var board: Board
var status: Label
var controls: Label
var choice: Button
var extra: Button
var next: Button
var sku := 0
var second := 1
var side := 0
var angle := 0.45
var power := 0.0
var charging := false
var dragging := false
var stick := 0.0
var arrows := {}
var completed_best := 0


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("f7eed6")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	background.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	var column := VBoxContainer.new()
	margin.add_child(column)
	status = _label(column, UiFont.SIZE_HEADING)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = Board.SIZE.aspect()
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(aspect)
	board = Board.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.add_child(board)
	controls = _label(column, UiFont.SIZE_CAPTION)
	var row := HBoxContainer.new()
	column.add_child(row)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	choice = _button(row, _cycle)
	extra = _button(row, _cycle_second)
	next = _button(row, _next)
	_button(row, _retry).text = Loc.t(COPY + "retry")
	_button(row, _exit).text = Loc.t("prep.back")
	board.changed.connect(_refresh)
	get_window().focus_exited.connect(_cancel)
	Loc.locale_changed.connect(_refresh)
	side = randi_range(0, 1)
	board.reset_board(0, side)


func _label(parent: Control, size_px: int) -> Label:
	var result := Label.new()
	UiFont.apply_label(result, size_px)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_color_override("font_color", Color("5c4938"))
	parent.add_child(result)
	return result


func _button(parent: Control, callback: Callable) -> Button:
	var button := Button.new()
	UiFont.apply_button_literal(button, UiFont.SIZE_BODY_SM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("fffdf2" if state == "normal" else "ffd43b")
		style.border_color = Color("dfd3b8")
		style.set_border_width_all(2)
		style.border_width_bottom = 4
		style.set_corner_radius_all(24)
		for edge in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_content_margin(edge, 10)
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("5c4938"))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _double() -> bool:
	return board.level == 2 and board.shots == 1


func _refresh(_locale: String = "") -> void:
	var level_name := Loc.t(COPY + "level_%d" % board.level)
	status.text = Loc.t(COPY + "status", [level_name, board.shots, board.best])
	controls.text = Loc.t(COPY + "goal_%d" % board.level) + "\n" + Loc.t(COPY + "controls")
	choice.text = Loc.t(COPY + "ammo", [Loc.t("sku." + SKUS[sku])])
	board.preview_sku = sku
	board.queue_redraw()
	extra.text = Loc.t(COPY + "second", [Loc.t("sku." + SKUS[second])])
	extra.visible = _double() and not board.won
	next.visible = board.won
	next.text = Loc.t(COPY + ("new" if board.level == 2 else "next"))
	if board.won and board.level == 2:
		controls.text = Loc.t(COPY + "win", [board.shots, board.best])
	elif board.settled and board.shots == 0 and not board.won:
		controls.text = Loc.t(COPY + "failed")
	elif board.reveals:
		controls.text += "\n" + Loc.t(COPY + "reveal")


func _cycle() -> void:
	if board.settled and not board.won:
		sku = (sku + 1) % SKUS.size()
		if second == sku:
			second = (second + 1) % SKUS.size()
		_refresh()


func _cycle_second() -> void:
	if not _double():
		return
	second = (second + 1) % SKUS.size()
	if second == sku:
		second = (second + 1) % SKUS.size()
	_refresh()


func _cancel() -> void:
	charging = false
	dragging = false
	arrows.clear()
	stick = 0.0
	board.aiming = false
	board.queue_redraw()


func _retry() -> void:
	_cancel()
	board.best = completed_best
	board.reset_board(board.level, side)


func _next() -> void:
	if not board.won:
		return
	_cancel()
	if board.level == 2:
		side = randi_range(0, 1)
		completed_best = 0
		board.best = 0
		board.reset_board(0, side)
	else:
		completed_best = board.best
		board.reset_board(board.level + 1, side)


func _process(delta: float) -> void:
	if not board.settled or board.won or board.shots == 0:
		return
	var direction := stick + float(arrows.has(KEY_UP)) - float(arrows.has(KEY_DOWN))
	angle = clampf(angle + direction * delta * 1.3, -0.05, 1.38)
	if charging:
		power = minf(1.0, power + delta * 0.8)
	if not dragging:
		board.aim = Vector2.from_angle(-angle) * lerpf(155.0, 570.0, power if charging else 0.55)
		board.aiming = true
	board.queue_redraw()


func _shoot() -> void:
	if board.settled and not board.won and board.shots > 0:
		board.launch(board.aim, sku, second if _double() else -1)
	board.aiming = false


func _charge(pressed: bool) -> void:
	if pressed and board.settled and not board.won and board.shots > 0 and not dragging:
		charging = true
		power = 0.0
	elif not pressed and charging:
		charging = false
		_shoot()


func _board_point(point: Vector2) -> Vector2:
	return (board.get_global_transform_with_canvas().affine_inverse() * point) * Board.SIZE / board.size


func _drag_to(point: Vector2) -> void:
	var pull := Board.ORIGIN - _board_point(point)
	board.aim = Vector2(maxf(0.0, pull.x), pull.y).limit_length(95.0) * 6.0
	board.aiming = true
	board.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and dragging:
		_drag_to(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and board.settled and not board.won and board.shots > 0 and _board_point(event.position).distance_to(Board.ORIGIN) < 28.0:
			dragging = true
			_drag_to(event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
			_drag_to(event.position)
			dragging = false
			if board.aim.length() >= 85.0:
				_shoot()
		else:
			return
	elif event is InputEventKey and not event.echo:
		match event.keycode:
			KEY_UP, KEY_DOWN:
				if event.pressed:
					arrows[event.keycode] = true
				else:
					arrows.erase(event.keycode)
			KEY_SPACE: _charge(event.pressed)
			KEY_TAB:
				if event.pressed: _cycle()
			KEY_Q:
				if event.pressed: _cycle_second()
			KEY_C:
				if event.pressed: _cancel()
			KEY_R:
				if event.pressed: _retry()
			KEY_ENTER:
				if event.pressed: _next()
			KEY_ESCAPE:
				if event.pressed: _exit()
			_: return
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		stick = -event.axis_value if absf(event.axis_value) > 0.24 else 0.0
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_A:
			if board.won:
				if event.pressed: _next()
			else:
				_charge(event.pressed)
		elif event.pressed:
			match event.button_index:
				JOY_BUTTON_B:
					if charging or dragging:
						_cancel()
					else:
						_exit()
				JOY_BUTTON_X: _cycle()
				JOY_BUTTON_Y: _retry()
				JOY_BUTTON_RIGHT_SHOULDER: _cycle_second()
				_: return
	else:
		return
	get_viewport().set_input_as_handled()


func _exit() -> void:
	set_process_input(false)
	hide()
	exited.emit()
	queue_free()
