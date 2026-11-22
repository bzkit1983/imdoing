extends CanvasLayer

signal exited

const Art = preload("res://scripts/prep/bun_duel_art.gd")
const FontStyle = preload("res://scripts/ui_font.gd")
const READY_TIME := 3.0
const ROUND_TIME := 15.0
const BITES_PER_BUN := 5
const CPU_BITES := 25 * BITES_PER_BUN
const COPY := "prep.bun_duel."

enum Phase { READY, EATING, RESULT }
var phase := Phase.READY
var elapsed := 0.0
var player_bites := 0
var cpu_bites := 0
var held := {}
var art: Node2D
var clock: Label
var player_score: Label
var cpu_score: Label
var result: Label
var retry: Button
var back: Button
var instructions: Label
var reward: AcceptDialog


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("17273b")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := AspectRatioContainer.new()
	layout.ratio = 16.0 / 9.0
	background.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := Control.new()
	layout.add_child(frame)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	art = Art.new()
	viewport.add_child(art)
	var picture := TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var chrome := VBoxContainer.new()
	frame.add_child(chrome)
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.offset_left = 24
	chrome.offset_right = -24
	chrome.offset_top = 12
	chrome.offset_bottom = -12
	clock = _label(chrome, FontStyle.SIZE_DISPLAY)
	var scores := HBoxContainer.new()
	chrome.add_child(scores)
	player_score = _label(scores, FontStyle.SIZE_BODY)
	cpu_score = _label(scores, FontStyle.SIZE_BODY)
	player_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cpu_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chrome.add_child(space)
	result = _label(chrome, FontStyle.SIZE_HEADING)
	instructions = _label(chrome, FontStyle.SIZE_CAPTION)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	chrome.add_child(buttons)
	retry = _button(buttons, reset_round)
	back = _button(buttons, _exit)
	reward = AcceptDialog.new()
	add_child(reward)
	Loc.locale_changed.connect(_refresh)
	get_window().focus_exited.connect(func(): held.clear())
	reset_round()


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FontStyle.apply_label(label, font_size)
	label.add_theme_color_override("font_color", Color("fff0c9"))
	parent.add_child(label)
	return label


func _button(parent: Control, action: Callable) -> Button:
	var button := Button.new()
	FontStyle.apply_button(button, FontStyle.SIZE_BODY_SM)
	parent.add_child(button)
	button.pressed.connect(action)
	return button


func reset_round() -> void:
	phase = Phase.READY
	elapsed = 0.0
	player_bites = 0
	cpu_bites = 0
	art.reset()
	reward.hide()
	_refresh()


func advance(delta: float) -> void:
	if phase == Phase.RESULT:
		return
	elapsed = minf(elapsed + delta, READY_TIME + ROUND_TIME)
	if elapsed >= READY_TIME:
		phase = Phase.EATING
		var next_bites := floori((elapsed - READY_TIME) * CPU_BITES / ROUND_TIME)
		if next_bites != cpu_bites:
			cpu_bites = next_bites
			art.bite(1, cpu_bites)
	if elapsed >= READY_TIME + ROUND_TIME:
		phase = Phase.RESULT
		_refresh()
		if _buns(player_bites) > _buns(cpu_bites):
			reward.popup_centered()


func _process(delta: float) -> void:
	if phase != Phase.RESULT:
		advance(delta)
		_refresh()


@warning_ignore("integer_division")
func _buns(bites: int) -> int:
	return bites / BITES_PER_BUN


func _refresh(_locale: String = "") -> void:
	var remaining := READY_TIME - elapsed if phase == Phase.READY else READY_TIME + ROUND_TIME - elapsed
	clock.text = Loc.t(COPY + ("ready" if phase == Phase.READY else "time"), [ceili(remaining)])
	player_score.text = Loc.t(COPY + "player", [_buns(player_bites), player_bites % BITES_PER_BUN])
	cpu_score.text = Loc.t(COPY + "cpu", [_buns(cpu_bites), cpu_bites % BITES_PER_BUN])
	instructions.text = Loc.t(COPY + "controls")
	retry.text = Loc.t(COPY + "retry")
	retry.visible = phase == Phase.RESULT
	back.text = Loc.t("prep.back")
	result.visible = phase == Phase.RESULT
	var difference := _buns(player_bites) - _buns(cpu_bites)
	result.text = Loc.t(COPY + ("win" if difference > 0 else "tie" if difference == 0 else "loss"))
	reward.title = Loc.t(COPY + "win")
	reward.dialog_text = Loc.t(COPY + "reward", [Loc.t("skill.quick_swallow.name")])
	reward.ok_button_text = Loc.t(COPY + "ok")


func _press_bite(source: String, pressed: bool) -> void:
	if not pressed:
		held.erase(source)
	elif not held.has(source):
		held[source] = true
		if phase == Phase.EATING:
			player_bites += 1
			art.bite(0, player_bites)
			_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.physical_keycode == KEY_A or event.keycode == KEY_A:
			if not event.echo:
				_press_bite("keyboard", event.pressed)
		elif event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_exit()
		elif event.pressed and not event.echo and event.keycode == KEY_R and phase == Phase.RESULT and not reward.visible:
			reset_round()
		else:
			return
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_A:
			_press_bite("pad:%d" % event.device, event.pressed)
		elif event.pressed and event.button_index == JOY_BUTTON_B:
			_exit()
		elif event.pressed and event.button_index == JOY_BUTTON_Y and phase == Phase.RESULT and not reward.visible:
			reset_round()
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _exit() -> void:
	set_process(false)
	set_process_input(false)
	hide()
	exited.emit()
	queue_free()
