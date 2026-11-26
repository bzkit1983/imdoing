extends CanvasLayer
## Prep minigame: Fishing Taro — ACNH-style cast loop (theme_historic).
## Move on shore → cast on shadow → wait → bite window → catch into fish_stock.
## First exit grants fish_tank.

signal exited

const Art = preload("res://scripts/prep/fishing_taro_art.gd")
const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")
const BgmBusScript = preload("res://scripts/bgm_bus.gd")
## Preload like metal_rush — runtime load + mutate import can fail silently.
const BGM_STREAM: AudioStream = preload("res://audio/bgm/fishing_taro.wav")

const MAX_CASTS := 20
const CAST_RANGE := 42.0
const BITE_MIN := 0.45
const BITE_MAX := 0.70
const WAIT_MIN := 1.1
const WAIT_MAX := 2.6
const CAST_FLIGHT := 0.32
const SHOW_SEC := 1.35
const SHOW_CATCH_SEC := 1.85
const CATCH_ICON_PX := 96
const SHADOW_SPAWN_MIN := 1.4
const SHADOW_SPAWN_MAX := 3.2

enum Phase { INTRO, IDLE, CASTING, WAITING, BITE, SHOW }

var state: RefCounted
var phase: Phase = Phase.INTRO
var art: Node2D

## Polled each physics tick from Controls InputMap (pad-safe; parent Prep may eat _input).
var _move_x: float = 0.0
var _casts_left: int = MAX_CASTS
var _caught_total: int = 0
var _last_catch: String = ""
var _show_ok: bool = false
var _phase_t: float = 0.0
var _bite_window: float = 0.55
var _wait_total: float = 1.5
var _cast_from: Vector2 = Vector2.ZERO
var _cast_to: Vector2 = Vector2.ZERO
var _cast_on_shadow: bool = false
var _shadow_spawn_cd: float = 0.8
var _shadow_vx: float = 18.0
var _exiting: bool = false

var _hud_casts: Label
var _hud_stock: Label
var _hud_hint: Label
var _notice: Label
var _catch_card: PanelContainer
var _catch_icon: TextureRect
var _catch_name: Label
var _cover: CenterContainer
var _heading: Label
var _details: Label
var _start: Button
var _back: Button
var _exit_btn: Button
var _bgm_override: bool = false


func setup(game_state: RefCounted) -> void:
	state = game_state
	layer = 80


func _ready() -> void:
	## Keep ticking／polling even while parent Prep CanvasLayer is hidden.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_start_minigame_bgm()
	Loc.locale_changed.connect(_localize)
	get_window().focus_exited.connect(_clear_input)
	## Drop Prep list focus so pad A is not eaten by ui_accept on a hidden button.
	var vp := get_viewport()
	if vp != null:
		vp.gui_release_focus()
	_localize()
	_show_intro()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("1a2834")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	background.add_child(aspect)
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var view := Control.new()
	aspect.add_child(view)

	var screen := TextureRect.new()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(Art.W, Art.H)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	art = Art.new()
	viewport.add_child(art)
	screen.texture = viewport.get_texture()

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	view.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 20
	bar.offset_right = -20
	bar.offset_top = 10
	_hud_casts = _label(bar, UiFont.SIZE_BODY)
	_hud_casts.add_theme_stylebox_override("normal", _panel("FFFDF2", 12, 6))
	_hud_stock = _label(bar, UiFont.SIZE_CAPTION)
	_hud_stock.add_theme_stylebox_override("normal", _panel("FFFDF2", 12, 6))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_exit_btn = _button(bar, _request_exit)

	_hud_hint = _label(view, UiFont.SIZE_CAPTION)
	_hud_hint.add_theme_color_override("font_color", Color("fff1c4"))
	_hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hud_hint.offset_bottom = -16
	_hud_hint.offset_top = -48

	_notice = _label(view, UiFont.SIZE_HEADING)
	_notice.add_theme_color_override("font_color", Color("fff1c4"))
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_notice.offset_top = -40
	_notice.offset_bottom = 40

	## Catch reveal card (fishingtaro.md §3.2 成功：出示魚種卡片).
	_catch_card = PanelContainer.new()
	_catch_card.visible = false
	_catch_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catch_card.add_theme_stylebox_override("panel", _panel("FFFDF2", 18, 14))
	view.add_child(_catch_card)
	_catch_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_catch_card.offset_left = -90
	_catch_card.offset_right = 90
	_catch_card.offset_top = -110
	_catch_card.offset_bottom = 70
	var catch_col := VBoxContainer.new()
	catch_col.add_theme_constant_override("separation", 10)
	catch_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_catch_card.add_child(catch_col)
	_catch_icon = TextureRect.new()
	_catch_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_catch_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_catch_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_catch_icon.custom_minimum_size = Vector2(CATCH_ICON_PX, CATCH_ICON_PX)
	_catch_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	catch_col.add_child(_catch_icon)
	_catch_name = _label(catch_col, UiFont.SIZE_BODY)
	_catch_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_cover = CenterContainer.new()
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_cover)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel("FFFDF2", 24, 10))
	_cover.add_child(panel)
	var inset := PanelContainer.new()
	inset.add_theme_stylebox_override("panel", _panel("F7EED6", 18, 16))
	panel.add_child(inset)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	inset.add_child(column)
	_heading = _label(column, UiFont.SIZE_HEADING)
	_details = _label(column, UiFont.SIZE_BODY_SM)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size.x = 420
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	_start = _button(row, _begin_play)
	_back = _button(row, _request_exit)


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
	button.add_theme_stylebox_override("normal", _panel("FFFDF2", 20, 8))
	button.add_theme_stylebox_override("hover", _panel("FFD43B", 20, 8))
	button.add_theme_stylebox_override("pressed", _panel("FFD43B", 20, 8))
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, Color("5C4938"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _panel(fill: String, radius: int, padding: int) -> StyleBoxFlat:
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
	_back.text = Loc.t("prep.fishing_taro.exit")
	_exit_btn.text = Loc.t("prep.fishing_taro.exit")
	_start.text = Loc.t("prep.fishing_taro.start")
	_heading.text = Loc.t("prep.fishing_taro.title")
	_details.text = Loc.t("prep.fishing_taro.rules", [MAX_CASTS])
	_refresh_hud()


func _show_intro() -> void:
	phase = Phase.INTRO
	_cover.show()
	art.reset_scene()
	_refresh_hud()


func _begin_play() -> void:
	_casts_left = MAX_CASTS
	_caught_total = 0
	_last_catch = ""
	_cover.hide()
	art.reset_scene()
	_enter_idle(true)
	_refresh_hud()


func _enter_idle(respawn_shadow: bool) -> void:
	phase = Phase.IDLE
	_phase_t = 0.0
	art.rod_cast = false
	art.bobber_visible = false
	art.bobber_nibble = false
	art.bite_flash = 0.0
	if respawn_shadow or not art.shadow_visible:
		_shadow_spawn_cd = randf_range(0.35, 1.0)
		art.shadow_visible = false
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if _exiting:
		return
	_poll_controls()
	if phase == Phase.INTRO:
		return
	match phase:
		Phase.IDLE:
			_tick_idle(delta)
		Phase.CASTING:
			_tick_casting(delta)
		Phase.WAITING:
			_tick_waiting(delta)
		Phase.BITE:
			_tick_bite(delta)
		Phase.SHOW:
			_tick_show(delta)
	_refresh_hud()


func _poll_controls() -> void:
	## Prefer InputMap so Xbox A／stick work on every device (Controls.JOY_ALL_DEVICES).
	var move := Input.get_axis(Controls.MOVE_LEFT, Controls.MOVE_RIGHT)
	var stick := Controls.stick_vector()
	if absf(stick.x) > absf(move):
		move = stick.x
	if absf(move) < Controls.MOVE_DEADZONE:
		move = 0.0
	_move_x = clampf(move, -1.0, 1.0)
	## Action = Interact (A／H／Enter) or Dash/Space — same cast／reel button feel.
	if Input.is_action_just_pressed(Controls.INTERACT) or Input.is_action_just_pressed(Controls.DASH):
		_try_action()
	elif Input.is_action_just_pressed(Controls.CANCEL):
		_request_exit()


func _tick_idle(delta: float) -> void:
	if absf(_move_x) > 0.01:
		art.facing = signf(_move_x)
		art.player_x = clampf(art.player_x + _move_x * 78.0 * delta, 28.0, float(Art.W - 28))
	_tick_shadow(delta)


func _tick_shadow(delta: float) -> void:
	if art.shadow_visible:
		art.shadow_x += _shadow_vx * delta
		if art.shadow_x < 36.0 or art.shadow_x > float(Art.W - 36):
			_shadow_vx *= -1.0
			art.shadow_x = clampf(art.shadow_x, 36.0, float(Art.W - 36))
		return
	_shadow_spawn_cd -= delta
	if _shadow_spawn_cd > 0.0:
		return
	art.shadow_x = randf_range(48.0, float(Art.W - 48))
	art.shadow_y = randf_range(66.0, 92.0)
	art.shadow_visible = true
	_shadow_vx = randf_range(14.0, 26.0) * (1.0 if randf() > 0.5 else -1.0)
	_shadow_spawn_cd = randf_range(SHADOW_SPAWN_MIN, SHADOW_SPAWN_MAX)


func _tick_casting(delta: float) -> void:
	_phase_t += delta
	var u := clampf(_phase_t / CAST_FLIGHT, 0.0, 1.0)
	## Arc: ease out then splash.
	var pos := _cast_from.lerp(_cast_to, u)
	pos.y -= sin(u * PI) * 28.0
	art.bobber_x = pos.x
	art.bobber_y = pos.y
	art.bobber_visible = true
	art.rod_cast = true
	if u < 1.0:
		return
	art.splash = 0.35
	art.bobber_x = _cast_to.x
	art.bobber_y = _cast_to.y
	if _cast_on_shadow:
		phase = Phase.WAITING
		_phase_t = 0.0
		_wait_total = randf_range(WAIT_MIN, WAIT_MAX)
		art.bobber_nibble = false
	else:
		## Empty cast — short wait then fail.
		phase = Phase.WAITING
		_phase_t = 0.0
		_wait_total = 0.55
		_cast_on_shadow = false


func _tick_waiting(delta: float) -> void:
	_phase_t += delta
	## Nibble telegraph in the last 0.45s when on shadow.
	if _cast_on_shadow and _phase_t >= _wait_total - 0.45:
		art.bobber_nibble = true
	if _phase_t < _wait_total:
		return
	if not _cast_on_shadow:
		_fail(Loc.t("prep.fishing_taro.fail_miss"))
		return
	phase = Phase.BITE
	_phase_t = 0.0
	_bite_window = randf_range(BITE_MIN, BITE_MAX)
	art.bobber_nibble = false
	art.bite_flash = 0.25
	art.splash = 0.4


func _tick_bite(delta: float) -> void:
	_phase_t += delta
	if _phase_t <= _bite_window:
		return
	_fail(Loc.t("prep.fishing_taro.fail_late"))


func _tick_show(delta: float) -> void:
	_phase_t += delta
	var hold := SHOW_CATCH_SEC if _show_ok else SHOW_SEC
	if _phase_t < hold:
		return
	_hide_catch_card()
	if _casts_left <= 0:
		_end_session_cover()
		return
	_enter_idle(true)


func _try_action() -> void:
	if _exiting:
		return
	match phase:
		Phase.INTRO:
			_begin_play()
		Phase.IDLE:
			_start_cast()
		Phase.WAITING:
			_fail(Loc.t("prep.fishing_taro.fail_early"))
		Phase.BITE:
			_succeed()
		Phase.SHOW:
			_phase_t = SHOW_CATCH_SEC if _show_ok else SHOW_SEC
		Phase.CASTING:
			pass


func _start_cast() -> void:
	if _casts_left <= 0:
		_end_session_cover()
		return
	_casts_left -= 1
	var near: bool = bool(art.shadow_visible) and absf(art.player_x - art.shadow_x) <= CAST_RANGE
	_cast_on_shadow = near
	_cast_from = Vector2(art.player_x + art.facing * 18.0, float(Art.SHORE_Y) + 4.0)
	if near:
		_cast_to = Vector2(art.shadow_x, art.shadow_y)
	else:
		## Land somewhere in front — empty water.
		_cast_to = Vector2(
			clampf(art.player_x + art.facing * randf_range(36.0, 70.0), 24.0, float(Art.W - 24)),
			randf_range(70.0, 96.0),
		)
	phase = Phase.CASTING
	_phase_t = 0.0
	art.rod_cast = true
	art.bobber_visible = true
	art.bobber_x = _cast_from.x
	art.bobber_y = _cast_from.y
	_refresh_hud()


func _succeed() -> void:
	var fid := Tuning.roll_fish_id()
	if state != null:
		state.add_fish(fid, 1)
	_last_catch = fid
	_caught_total += 1
	_show_ok = true
	art.shadow_visible = false
	art.bobber_visible = false
	art.rod_cast = false
	art.bite_flash = 0.0
	art.splash = 0.55
	phase = Phase.SHOW
	_phase_t = 0.0
	_notice.text = ""
	_show_catch_card(fid)
	_refresh_hud()


func _fail(msg: String) -> void:
	_show_ok = false
	_last_catch = ""
	art.shadow_visible = false
	art.bobber_visible = false
	art.bobber_nibble = false
	art.rod_cast = false
	art.bite_flash = 0.0
	phase = Phase.SHOW
	_phase_t = 0.0
	_hide_catch_card()
	_notice.text = msg
	_refresh_hud()


func _show_catch_card(fid: String) -> void:
	if _catch_card == null:
		return
	_catch_icon.texture = _fish_catch_texture(fid)
	_catch_name.text = Loc.t("prep.fishing_taro.caught", [Tuning.fish_name(fid)])
	_catch_card.visible = true


func _hide_catch_card() -> void:
	if _catch_card != null:
		_catch_card.visible = false
	if _catch_icon != null:
		_catch_icon.texture = null


## Prefer full 64² sku art; fall back to SkuIcons procedural／cached 32².
func _fish_catch_texture(fid: String) -> Texture2D:
	var path := "res://art/ui/sku/%s.png" % fid
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return SkuIcons.texture(fid)


func _end_session_cover() -> void:
	phase = Phase.INTRO
	_cover.show()
	_heading.text = Loc.t("prep.fishing_taro.session_done")
	_details.text = Loc.t("prep.fishing_taro.session_summary", [_caught_total, MAX_CASTS])
	_start.text = Loc.t("prep.fishing_taro.start_again")
	art.reset_scene()
	_refresh_hud()


func _refresh_hud() -> void:
	if _hud_casts == null:
		return
	_hud_casts.text = Loc.t("prep.fishing_taro.casts", [_casts_left, MAX_CASTS])
	_hud_stock.text = _stock_line()
	match phase:
		Phase.IDLE:
			_hide_catch_card()
			var near: bool = bool(art.shadow_visible) and absf(art.player_x - art.shadow_x) <= CAST_RANGE
			_hud_hint.text = (
				Loc.t("prep.fishing_taro.hint_cast")
				if near
				else Loc.t("prep.fishing_taro.hint_move")
			)
			_notice.text = ""
		Phase.CASTING:
			_hide_catch_card()
			_hud_hint.text = Loc.t("prep.fishing_taro.hint_wait")
			_notice.text = ""
		Phase.WAITING:
			_hide_catch_card()
			_hud_hint.text = Loc.t("prep.fishing_taro.hint_wait")
			_notice.text = ""
		Phase.BITE:
			_hide_catch_card()
			_hud_hint.text = Loc.t("prep.fishing_taro.hint_bite")
			_notice.text = Loc.t("prep.fishing_taro.bite")
		Phase.SHOW:
			_hud_hint.text = Loc.t("prep.fishing_taro.hint_continue")
			if not _show_ok:
				_hide_catch_card()
		Phase.INTRO:
			_hide_catch_card()
			_hud_hint.text = ""
			_notice.text = ""


func _stock_line() -> String:
	if state == null:
		return ""
	var parts: PackedStringArray = []
	for fid in Tuning.FISH_IDS:
		parts.append("%s %d" % [Tuning.fish_name(fid), int(state.fish_count(fid))])
	return Loc.t("prep.fishing_taro.stock", [" · ".join(parts)])


func _clear_input() -> void:
	_move_x = 0.0


func _request_exit() -> void:
	if _exiting:
		return
	_exiting = true
	_stop_minigame_bgm()
	if state != null:
		var first: bool = bool(state.mark_fishing_taro_played())
		if first:
			_notice.text = Loc.t("prep.fishing_taro.reward_tank")
			_notice.visible = true
			await get_tree().create_timer(0.9).timeout
	exited.emit()
	queue_free()


func _start_minigame_bgm() -> void:
	## Drive Music bus via BgmBus (same player as PrepareShop) so mute/volume apply.
	if BGM_STREAM == null:
		push_warning("fishing_taro: missing BGM stream")
		return
	var bgm := BgmBusScript.bus()
	if bgm == null or not bgm.has_method("play_override"):
		push_warning("fishing_taro: BgmBus.play_override missing")
		return
	bgm.play_override(BGM_STREAM)
	_bgm_override = true


func _stop_minigame_bgm() -> void:
	if not _bgm_override:
		return
	_bgm_override = false
	var bgm := BgmBusScript.bus()
	if bgm != null and bgm.has_method("clear_override"):
		bgm.clear_override()


func _exit_tree() -> void:
	_stop_minigame_bgm()
