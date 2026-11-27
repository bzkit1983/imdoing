extends RefCounted
## Early-close dialog / input peeled out of demo.gd (#148).

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")

var host: Node


func bind(day_host: Node) -> void:
	host = day_host


func consider_early_close() -> bool:
	## §8.1: only Host evaluates early-close (Client clock is presentation-only).
	if SessionService.is_networked() and SessionService.is_client():
		return false
	if not _restocks_cleared() or not _registers_idle():
		host._early_latched = false
		return false
	if host._early_latched:
		return false
	host._show_early_dialog()
	host._day_chrome.broadcast_day_clock_state(true)
	return true


func _restocks_cleared() -> bool:
	if host._player == null or host.state == null:
		return false
	var saw := false
	for n in host._player.interactables:
		if n == null or not is_instance_valid(n):
			continue
		if str(n.get("kind")) != "restock":
			continue
		saw = true
		if not n.has_method("skus"):
			return false
		for sku in n.skus():
			if int(host.state.stock.get(sku, 0)) > 0:
				return false
	return saw


func _registers_idle() -> bool:
	for c in host.all_registers():
		if c != null and is_instance_valid(c) and c.queue.size() > 0:
			return false
	return true


func show_early_dialog() -> void:
	host._early_open = true
	host._early_focus = 0
	SfxBus.play("sfx_early_close_ask")
	if host._player and host._player.has_method("set_hold"):
		host._player.set_hold("interact", false)
		host._player.set_hold("cancel", false)
		host._player.set_hold("dash", false)
		host._player.set_hold("skill", false)
		host._player.set_hold("bag_menu", false)
		host._player.set_hold("ult", false)
	if host._early_layer != null and is_instance_valid(host._early_layer):
		host._early_layer.visible = true
		_paint_early_focus()
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	host.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := ColorRect.new()
	card.color = Color("1c241f")
	card.position = Vector2(240, 150)
	card.size = Vector2(800, 420)
	layer.add_child(card)
	var title := Label.new()
	title.text = Loc.t("early.title")
	title.position = Vector2(36, 28)
	title.size = Vector2(720, 56)
	UiFont.apply_label(title, 36)
	title.add_theme_color_override("font_color", Color("f4d35e"))
	card.add_child(title)
	var body := Label.new()
	body.text = Loc.t("early.body")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(36, 108)
	body.size = Vector2(720, 110)
	UiFont.apply_label(body, 26)
	body.add_theme_color_override("font_color", Color("f4f1ea"))
	card.add_child(body)
	var hint := Label.new()
	hint.text = Loc.t("early.hint")
	hint.position = Vector2(36, 228)
	hint.size = Vector2(720, 40)
	UiFont.apply_label(hint, 22)
	hint.add_theme_color_override("font_color", Color("c8c2b4"))
	card.add_child(hint)
	host._early_yes = _early_choice(Loc.t("early.yes"), Vector2(36, 290), Callable(host, "_confirm_early_close"))
	host._early_no = _early_choice(Loc.t("early.no"), Vector2(400, 290), Callable(host, "_decline_early_close"))
	card.add_child(host._early_yes)
	card.add_child(host._early_no)
	host._early_layer = layer
	_paint_early_focus()


func _early_choice(text: String, at: Vector2, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = at
	btn.size = Vector2(360, 88)
	btn.focus_mode = Control.FOCUS_NONE
	UiFont.apply_button(btn, 22)
	btn.pressed.connect(cb)
	return btn


func _paint_early_focus() -> void:
	_style_early_btn(host._early_yes, host._early_focus == 0)
	_style_early_btn(host._early_no, host._early_focus == 1)


func _style_early_btn(btn: Button, on: bool) -> void:
	if btn == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f4d35e") if on else Color("24302a")
	box.set_corner_radius_all(10)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state_name, box)
	btn.add_theme_color_override("font_color", Color("1c241f") if on else Color("f4f1ea"))


func early_input(event: InputEvent) -> void:
	if event.is_echo():
		host.get_viewport().set_input_as_handled()
		return
	var early_dir := Controls.dir_from_event(event)
	if not (
		early_dir == 2
		or early_dir == 3
		or event.is_action(Controls.INTERACT)
		or event.is_action(Controls.CANCEL)
	):
		return
	var press := event.is_pressed()
	host.get_viewport().set_input_as_handled()
	if not press:
		return
	if early_dir == 2:
		host._early_focus = 0
		_paint_early_focus()
	elif early_dir == 3:
		host._early_focus = 1
		_paint_early_focus()
	elif event.is_action_pressed(Controls.INTERACT):
		if host._early_focus == 0:
			host._confirm_early_close()
		else:
			host._decline_early_close()
	elif event.is_action_pressed(Controls.CANCEL):
		host._decline_early_close()


func confirm_early_close() -> void:
	## Same Host-only gate as skip_operate / pause end-day.
	if SessionService.is_networked() and not SessionService.request_end_day():
		return
	if host._tutorial != null and host._tutorial.blocks_settle():
		host._decline_early_close()
		return

	if not host._early_open:
		return
	host._hide_early_dialog()
	host._early_closed = true
	host.clear_guest_dusk()
	host.phase = "closed"
	host.game_hours = Tuning.CLOSE_HOUR
	host._day_chrome.broadcast_day_clock_state(true)
	host._finish_day()


func decline_early_close() -> void:
	if SessionService.is_networked() and SessionService.is_client():
		## Client mirrors Host chrome only — cannot dismiss Host prompt.
		return
	if not host._early_open:
		return
	host._early_latched = true
	host._hide_early_dialog()
	host._day_chrome.broadcast_day_clock_state(true)


func hide_early_dialog() -> void:
	host._early_open = false
	if host._early_layer != null and is_instance_valid(host._early_layer):
		host._early_layer.visible = false
