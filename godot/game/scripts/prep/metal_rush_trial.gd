extends CanvasLayer

signal exited

const Chart = preload("res://scripts/prep/metal_rush_chart.gd")
const Track = preload(Chart.AUDIO_PATH)
const Stage = preload("res://scripts/prep/metal_rush_stage.gd")
const FontStyle = preload("res://scripts/ui_font.gd")
const COPY := "prep.metal_trial."
const KEYS := [KEY_D, KEY_F, KEY_J, KEY_K]
const PAD := [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_A, JOY_BUTTON_B]

var chart: Chart
var stage: Stage
var music: AudioStreamPlayer
var status: Label
var summary: Label
var retry: Button
var back: Button
var controls: Label
var title: Label
var reward: AcceptDialog
var countdown := 3.0
var song_time := -3.0
var finished := false
var held := {}
var judgment := ""
var judgment_time := 0.0
var _background_suspended := false


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("211d33")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	background.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var column := VBoxContainer.new()
	margin.add_child(column)
	title = _label(column, FontStyle.SIZE_HEADING)
	status = _label(column, FontStyle.SIZE_BODY)
	stage = Stage.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stage)
	controls = _label(column, FontStyle.SIZE_CAPTION)
	summary = _label(column, FontStyle.SIZE_BODY_SM)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	retry = _button(buttons, restart)
	back = _button(buttons, _exit)
	reward = AcceptDialog.new()
	add_child(reward)
	music = AudioStreamPlayer.new()
	music.stream = Track
	add_child(music)
	music.finished.connect(_finish)
	Loc.locale_changed.connect(_refresh)
	restart()


func _panel(fill: String, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color("E0AC16" if fill == "FFD43B" else "DFD3B8")
	style.set_border_width_all(2)
	style.border_width_bottom = 4
	style.set_corner_radius_all(radius)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 8)
	return style


func _label(parent: Control, size_px: int) -> Label:
	var label := Label.new()
	FontStyle.apply_label(label, size_px)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("5C4938"))
	label.add_theme_stylebox_override("normal", _panel("FFFDF2", 14))
	parent.add_child(label)
	return label


func _button(parent: Control, action: Callable) -> Button:
	var button := Button.new()
	FontStyle.apply_button_literal(button, FontStyle.SIZE_BODY_SM)
	button.add_theme_stylebox_override("normal", _panel("FFFDF2", 24))
	button.add_theme_stylebox_override("hover", _panel("FFD43B", 24))
	button.add_theme_stylebox_override("pressed", _panel("FFD43B", 24))
	button.add_theme_stylebox_override("focus", _panel("FFD43B", 24))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("5C4938"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func restart() -> void:
	music.stop()
	_set_background_suspended(music.stream != null)
	reward.hide()
	chart = Chart.new()
	stage.chart = chart
	countdown = 3.0
	song_time = -3.0
	stage.song_time = song_time
	stage.flashes = [0.0, 0.0, 0.0, 0.0]
	held.clear()
	finished = false
	judgment = ""
	judgment_time = 0.0
	_refresh()


func _audio_time() -> float:
	return music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


func _process(delta: float) -> void:
	if finished or music.stream == null:
		return
	if countdown > 0.0:
		countdown = maxf(0.0, countdown - delta)
		song_time = -countdown
		if countdown == 0.0:
			music.play()
	else:
		song_time = maxf(song_time, _audio_time())
		chart.expire(song_time)
	judgment_time = maxf(0.0, judgment_time - delta)
	stage.song_time = song_time
	for lane in 4:
		stage.flashes[lane] = maxf(0.0, stage.flashes[lane] - delta)
	stage.queue_redraw()
	_refresh()


func _finish() -> void:
	if finished:
		return
	chart.expire(Chart.DURATION)
	finished = true
	_set_background_suspended(false)
	stage.queue_redraw()
	_refresh()
	if chart.passed():
		reward.popup_centered()


func _refresh(_locale: String = "") -> void:
	title.text = Loc.t(COPY + "title")
	controls.text = Loc.t(COPY + "controls")
	back.text = Loc.t("prep.back")
	retry.text = Loc.t(COPY + "retry")
	retry.visible = finished
	summary.visible = finished
	if music.stream == null:
		status.text = Loc.t(COPY + "audio_error")
	elif finished:
		status.text = Loc.t(COPY + ("pass" if chart.passed() else "fail"))
		summary.text = Loc.t(COPY + "summary", [100.0 * chart.score() / (chart.notes.size() * 100), chart.best, chart.perfect, chart.good, chart.miss])
	elif countdown > 0.0:
		status.text = Loc.t(COPY + "ready", [ceili(countdown)])
	else:
		status.text = Loc.t(COPY + "live", [chart.score(), chart.combo])
		if judgment_time > 0.0:
			status.text += "   " + Loc.t(COPY + judgment)
	reward.title = Loc.t(COPY + "pass")
	reward.dialog_text = Loc.t(COPY + "reward", [Loc.t("skill.metal_rush.name")])
	reward.ok_button_text = Loc.t("prep.bun_duel.ok")


func _input(event: InputEvent) -> void:
	var lane := -1
	var source := ""
	var pressed := false
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_exit()
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not event.echo and event.keycode == KEY_R and finished and not reward.visible:
			restart()
			get_viewport().set_input_as_handled()
			return
		lane = KEYS.find(event.physical_keycode if event.physical_keycode else event.keycode)
		source = "key:%d" % lane
		pressed = event.pressed and not event.echo
		if event.echo and lane >= 0:
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_BACK and event.pressed:
			_exit()
			get_viewport().set_input_as_handled()
			return
		if finished and event.button_index == JOY_BUTTON_START and event.pressed and not reward.visible:
			restart()
			get_viewport().set_input_as_handled()
			return
		lane = PAD.find(event.button_index)
		source = "pad:%d:%d" % [event.device, lane]
		pressed = event.pressed
	if lane < 0:
		return
	if not pressed:
		held.erase(source)
	elif not held.has(source):
		held[source] = true
		if countdown == 0.0 and not finished and music.playing:
			judgment = chart.hit(lane, maxf(song_time, _audio_time()))
			judgment_time = 0.25
			if judgment != "empty":
				stage.flashes[lane] = 0.12
	get_viewport().set_input_as_handled()


func _exit() -> void:
	music.stop()
	_set_background_suspended(false)
	set_process(false)
	set_process_input(false)
	hide()
	exited.emit()
	queue_free()


func _exit_tree() -> void:
	_set_background_suspended(false)


func _set_background_suspended(suspended: bool) -> void:
	if _background_suspended == suspended:
		return
	_background_suspended = suspended
	var bgm := get_node_or_null("/root/BgmBus")
	if bgm != null:
		bgm.set_suspended(suspended)
