extends CanvasLayer

signal exited

const UiFont = preload("res://scripts/ui_font.gd")
const COPY := "prep.swiss_lung."
const SPEAKERS := ["a", "player", "a", "player", "a", "a", "player", "a", "player", "a", "a", "b", "a", "c", "player"]
const WITNESSES := [["b", "c"], ["a", "b"], ["c", "a"]]
const INTERRUPTERS := ["a", "c", "b"]

enum Phase { INTRO, OFFERS, ASK, INTERRUPTED, REPLY, CARDS, FEEDBACK, PRICE, BAG, RESULT }

class CounterArt extends Control:
	var lit := -1
	var actors := 4
	var show_sample := true
	var flipped_sign := false
	var bagged := false

	func _draw() -> void:
		var scale_px := size / Vector2(320, 64)
		draw_set_transform(Vector2.ZERO, 0.0, scale_px)
		draw_rect(Rect2(0, 0, 320, 64), Color("354f54"))
		for i in 12:
			draw_rect(Rect2(i * 28, 6, 24, 13), Color("6b8880"))
			draw_rect(Rect2(i * 28, 20, 24, 2), Color("deb584"))
		for i in actors:
			var x := 40 + i * 80
			var coat: Color = [Color("e1a85e"), Color("b16963"), Color("7b92bc"), Color("8d75a6")][i]
			if lit == i:
				draw_rect(Rect2(x - 23, 23, 46, 34), Color("dfc984"))
			draw_rect(Rect2(x - 14, 42, 28, 16), coat)
			draw_rect(Rect2(x - 9, 29, 18, 15), Color("efd1a2"))
			draw_rect(Rect2(x - 10, 27, 20, 4 + i % 3), coat.darkened(0.35))
			draw_rect(Rect2(x - 5, 35, 2, 2), Color("443c49"))
			draw_rect(Rect2(x + 3, 35, 2, 2), Color("443c49"))
			if i == 0:
				draw_rect(Rect2(x - 5, 43, 10, 8), Color("f6e4b6"))
			elif i == 2:
				draw_rect(Rect2(x - 10, 35, 20, 2), Color("514464"))
			elif i == 3:
				draw_rect(Rect2(x + 8, 31, 4, 13), Color("584562"))
		draw_rect(Rect2(0, 55, 320, 9), Color("ad7455"))
		draw_rect(Rect2(0, 55, 320, 2), Color("f2c18c"))
		if flipped_sign:
			draw_rect(Rect2(188, 41, 20, 15), Color("97684c"))
			draw_rect(Rect2(189, 42, 18, 12), Color("ffd43b"))
			draw_rect(Rect2(193, 47, 10, 2), Color("5c4938"))
		if bagged:
			draw_rect(Rect2(146, 43, 18, 13), Color("d4ac76"))
			draw_rect(Rect2(151, 39, 8, 5), Color("d4ac76"), false, 1)
		elif show_sample:
			draw_rect(Rect2(143, 53, 24, 3), Color("584652"))
			draw_rect(Rect2(147, 45, 8, 8), Color("e7a0a1"))
			draw_rect(Rect2(157, 45, 8, 8), Color("e7a0a1"))
			draw_rect(Rect2(154, 42, 4, 6), Color("edc7a8"))

var phase := Phase.INTRO
var line := 0
var offer := 0
var started_before := false
var interruption := 0
var interrupted := false
var pending_card := -1
var solved := {}
var collected: Array[int] = []
var selected: Array[int] = []
var feedback := ""
var price_set := false
var heading: Label
var narrative: Label
var board: Label
var rows: VBoxContainer
var scroll: ScrollContainer
var art: CounterArt
var buttons: Array[Button] = []
var cursor := 0


func _ready() -> void:
	var backplate := ColorRect.new()
	backplate.color = Color("354f54")
	add_child(backplate)
	backplate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	backplate.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	heading = _label(layout, UiFont.SIZE_HEADING)
	art = CounterArt.new()
	art.custom_minimum_size.y = 120
	layout.add_child(art)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style("F7EED6", 20))
	layout.add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	narrative = _label(body, UiFont.SIZE_BODY_SM)
	board = _label(body, UiFont.SIZE_CAPTION)
	rows = VBoxContainer.new()
	body.add_child(rows)
	Loc.locale_changed.connect(_locale_changed)
	restart()


func _style(fill: String, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color("E0AC16" if fill == "FFD43B" else "DFD3B8")
	style.set_corner_radius_all(radius)
	style.set_border_width_all(2)
	style.border_width_bottom = 4
	for side in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		style.set_content_margin(side, 8)
	return style


func _label(parent: Control, size_px: int) -> Label:
	var label := Label.new()
	UiFont.apply_label(label, size_px)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("5C4938"))
	label.add_theme_stylebox_override("normal", _style("FFFDF2", 14))
	parent.add_child(label)
	return label


func _choice(label: String, callback: Callable) -> void:
	var button := Button.new()
	UiFont.apply_button_literal(button, UiFont.SIZE_BODY_SM)
	button.text = label
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 42
	button.add_theme_stylebox_override("normal", _style("FFFDF2", 24))
	for state in ["hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, _style("FFD43B", 24))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("5C4938"))
	button.pressed.connect(callback)
	rows.add_child(button)
	buttons.append(button)


func restart() -> void:
	phase = Phase.OFFERS if started_before else Phase.INTRO
	line = 0
	offer = 0
	interruption = randi_range(0, 2)
	interrupted = false
	pending_card = -1
	solved.clear()
	collected.clear()
	selected.clear()
	price_set = false
	feedback = ""
	_refresh()


func _text(key: String, args: Array = []) -> String:
	return Loc.t(COPY + key, args)


func _speaker(speaker: String, key: String) -> String:
	art.lit = ["player", "a", "b", "c"].find(speaker)
	return _text("speaker_" + speaker) + "  " + _text(key)


func _locale_changed(_locale: String) -> void:
	_refresh()


func _refresh() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	buttons.clear()
	art.lit = -1
	art.actors = 2 if phase == Phase.INTRO and line < 11 else 3 if phase == Phase.INTRO and line < 13 else 4
	art.show_sample = phase != Phase.INTRO or line >= 4
	art.flipped_sign = price_set or (phase == Phase.FEEDBACK and feedback == "reveal_2")
	art.bagged = phase == Phase.RESULT
	heading.text = _text("title")
	board.visible = phase >= Phase.ASK
	board.text = _text("progress", [solved.size(), collected.size()])
	match phase:
		Phase.INTRO:
			narrative.text = _speaker(SPEAKERS[line], "intro_%d" % line)
			_choice(_text("continue"), _advance_intro)
		Phase.OFFERS:
			narrative.text = _speaker(["a", "b", "c"][offer], "offer_%d" % offer)
			_choice(_text("continue"), _advance_offer)
		Phase.ASK:
			narrative.text = _text("ask")
			for topic in 3:
				if solved.has(topic):
					continue
				for side in 2:
					var card := topic * 2 + side
					if not collected.has(card):
						var name_key: String = WITNESSES[topic][side]
						_choice(_text("question", [_text("speaker_" + name_key), _text("topic_%d" % topic)]), _ask.bind(card))
			if collected.size() >= 2:
				_choice(_text("cards"), _show_cards)
		Phase.INTERRUPTED:
			narrative.text = _speaker(INTERRUPTERS[interruption], "aside_%d" % interruption)
			_choice(_text("original"), _answer_pending)
		Phase.REPLY:
			narrative.text = _speaker(WITNESSES[floori(pending_card / 2.0)][pending_card % 2], "card_%d" % pending_card)
			board.text += "\n" + _text("added")
			_choice(_text("continue"), _show_ask)
			if collected.size() >= 2:
				_choice(_text("cards"), _show_cards)
		Phase.CARDS:
			narrative.text = _text("pair")
			for card in collected:
				var speaker: String = WITNESSES[floori(card / 2.0)][card % 2] if card < 6 else INTERRUPTERS[card - 6]
				var key := "card_%d" % card if card < 6 else "aside_%d" % (card - 6)
				_choice(("✓  " if selected.has(card) else "") + _text("speaker_" + speaker) + "  " + _text(key), _toggle_card.bind(card))
			if selected.size() == 2:
				_choice(_text("challenge"), _challenge)
			_choice(_text("more"), _show_ask)
		Phase.FEEDBACK:
			narrative.text = _text(feedback)
			if feedback == "wrong":
				board.text += "\n" + _text("hint")
				_choice(_text("cards"), _show_cards)
				_choice(_text("more"), _show_ask)
			elif solved.size() == 2:
				_choice(_text("offer_item"), _show_price)
			else:
				_choice(_text("continue"), _show_ask)
		Phase.PRICE:
			narrative.text = _speaker("player", "sale" if price_set else "price")
			_choice(_text("give_offer" if price_set else "set_price"), _advance_price)
		Phase.BAG:
			narrative.text = _speaker("a", "bag_line")
			_choice(_text("bag"), _finish)
		Phase.RESULT:
			narrative.text = _speaker("player", "punchline")
			board.text = _text("reward", [Loc.t("skill.force_sell.name")])
			_choice(_text("retry"), restart)
	_choice(Loc.t("prep.back"), _exit)
	art.queue_redraw()
	cursor = 0
	scroll.scroll_vertical = 0
	_restore_focus.call_deferred()


func _advance_intro() -> void:
	line += 1
	if line == SPEAKERS.size():
		started_before = true
		phase = Phase.OFFERS
	_refresh()


func _advance_offer() -> void:
	offer += 1
	if offer == 3:
		phase = Phase.ASK
	_refresh()


func _ask(card: int) -> void:
	pending_card = card
	if not interrupted and floori(card / 2.0) == interruption:
		interrupted = true
		collected.append(6 + interruption)
		phase = Phase.INTERRUPTED
		_refresh()
	else:
		_answer_pending()


func _answer_pending() -> void:
	if not collected.has(pending_card):
		collected.append(pending_card)
	phase = Phase.REPLY
	_refresh()


func _show_cards() -> void:
	phase = Phase.CARDS
	_refresh()


func _show_ask() -> void:
	phase = Phase.ASK
	_refresh()


func _toggle_card(card: int) -> void:
	var old_cursor := cursor
	if selected.has(card):
		selected.erase(card)
	else:
		if selected.size() == 2:
			selected.pop_front()
		selected.append(card)
	_refresh()
	_focus(old_cursor)


func _challenge() -> void:
	if selected.size() != 2:
		return
	var first := mini(selected[0], selected[1])
	var second := maxi(selected[0], selected[1])
	var topic := floori(first / 2.0)
	if first < 6 and first % 2 == 0 and second == first + 1 and not solved.has(topic):
		solved[topic] = true
		selected.clear()
		feedback = "reveal_%d" % topic
	else:
		feedback = "wrong"
	phase = Phase.FEEDBACK
	_refresh()


func _show_price() -> void:
	phase = Phase.PRICE
	_refresh()


func _advance_price() -> void:
	if price_set:
		phase = Phase.BAG
	else:
		price_set = true
	_refresh()


func _finish() -> void:
	phase = Phase.RESULT
	_refresh()


func _restore_focus() -> void:
	if not buttons.is_empty():
		_focus(cursor)


func _focus(index: int) -> void:
	cursor = clampi(index, 0, buttons.size() - 1)
	var button := buttons[cursor]
	button.grab_focus()
	scroll.ensure_control_visible(button)


func _input(event: InputEvent) -> void:
	var command := 0
	if event is InputEventKey and event.pressed:
		var key: int = event.keycode
		match key:
			KEY_UP: command = 1
			KEY_DOWN: command = 2
			KEY_ENTER, KEY_KP_ENTER: command = 3
			KEY_ESCAPE: command = 4
		if command != 0 and event.echo:
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: command = 1
			JOY_BUTTON_DPAD_DOWN: command = 2
			JOY_BUTTON_A: command = 3
			JOY_BUTTON_B: command = 4
	if command == 0:
		return
	get_viewport().set_input_as_handled()
	match command:
		1: _focus(cursor - 1)
		2: _focus(cursor + 1)
		3: buttons[cursor].pressed.emit()
		4: _exit()


func _exit() -> void:
	set_process_input(false)
	hide()
	exited.emit()
	queue_free()
