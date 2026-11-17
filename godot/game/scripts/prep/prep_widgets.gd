extends RefCounted
## Shared prep-menu chrome helpers (fonts, buttons, panels).

const UiFont = preload("res://scripts/ui_font.gd")
const PrepIcons = preload("res://scripts/prep/prep_icons.gd")
const PREP_TITLE := 40
const PREP_INFO := 28
const PREP_LIST := 34
const PREP_HINT := 24
const PREP_BTN := 32
const PREP_NUM := 44
## Icon-on-top tile: keep ≥ icon + label + style margins (see hub_tile fonts).
const HUB_TILE_H := 122.0
## Subdirectory option rows (角色整備／貨品管理…).
const HUB_ROW_H := 80.0
const OPEN_MAIN_H := 64.0
const OPEN_ELITE_H := 64.0
const DIFF_H := 52.0
## ItemList leaf pages — touch-friendly row height via spacer icon.
const LIST_ROW_H := 72
const LIST_V_SEP := 14
const STEP_BTN_H := 84.0
const STEP_BTN_W := 96.0
## Page grid. Info stays left of the back button. Content starts under that band.
## INFO_H fits prep.header (2 lines) + page blurb (1 line).
const MARGIN := 24.0
const INFO_TOP := 80.0
const INFO_H := 120.0
const INFO_W := 1000.0
const CONTENT_TOP := 212.0
const CONTENT_BOTTOM := 700.0
const CONTENT_W := 1232.0
const COL_BG := Color("121816")
const COL_CARD := Color("1c2822")
const COL_CARD_ON := Color("24362c")
const COL_INK := Color("f4f1ea")
const COL_GOLD := Color("f4d35e")
const COL_GOLD_HOT := Color("ffe08a")
const COL_LINE := Color("3d5246")
const COL_INK_DIM := Color("1c241f")

static var _list_spacer: ImageTexture


static func clear(node: Node) -> void:
	## Detach now so layout/get_child_count see an empty parent this frame.
	## queue_free (not free): hub tiles often call refresh from pressed, and
	## free()-ing the emitter mid-signal errors with "Object is locked".
	while node.get_child_count() > 0:
		var c := node.get_child(0)
		node.remove_child(c)
		c.queue_free()


static func paint_list(list: ItemList) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = COL_CARD
	panel.border_color = COL_LINE
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(8)
	var selected := StyleBoxFlat.new()
	selected.bg_color = COL_GOLD
	selected.set_corner_radius_all(8)
	selected.set_content_margin_all(4)
	var hovered := StyleBoxFlat.new()
	hovered.bg_color = COL_CARD_ON
	hovered.border_color = COL_GOLD
	hovered.set_border_width_all(1)
	hovered.set_corner_radius_all(8)
	list.add_theme_stylebox_override("panel", panel)
	list.add_theme_stylebox_override("selected", selected)
	list.add_theme_stylebox_override("hovered", hovered)
	list.add_theme_stylebox_override("focus", selected)
	list.add_theme_color_override("font_color", COL_INK)
	list.add_theme_color_override("font_selected_color", COL_INK_DIM)
	list.add_theme_color_override("font_hovered_color", COL_GOLD)


static func list_row_spacer() -> Texture2D:
	## Transparent strip so ItemList rows keep a minimum touch height.
	if _list_spacer != null:
		return _list_spacer
	var img := Image.create(8, LIST_ROW_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_list_spacer = ImageTexture.create_from_image(img)
	return _list_spacer


static func name_label(text: String, width: float, tall: float = 84.0) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.custom_minimum_size = Vector2(width, tall)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFont.apply_label(lab, PREP_BTN)
	lab.add_theme_color_override("font_color", COL_INK)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


static func bare_button(text: String, wide: float, tall: float) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(wide, tall)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFont.apply_button(btn, PREP_BTN)
	return btn


static func paint_btn(btn: Button, on: bool) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_GOLD if on else COL_CARD
	bg.set_corner_radius_all(10)
	bg.border_color = COL_GOLD if on else COL_LINE
	bg.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)
	var col := COL_INK_DIM if on else COL_INK
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", COL_INK_DIM if on else COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_INK_DIM)


static func paint_open_main(btn: Button, on: bool) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_GOLD_HOT if on else COL_GOLD
	bg.set_corner_radius_all(16)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)
	btn.add_theme_color_override("font_color", Color("1c241f"))
	btn.add_theme_color_override("font_hover_color", Color("1c241f"))
	btn.add_theme_color_override("font_pressed_color", Color("1c241f"))


static func paint_choice(btn: Button, selected: bool, focused: bool) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_GOLD if selected else COL_CARD
	bg.set_corner_radius_all(10)
	bg.border_color = COL_INK_DIM if selected else COL_LINE
	bg.set_border_width_all(3 if focused else 1)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)
	var col := COL_INK_DIM if selected else COL_INK
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", COL_INK_DIM if selected else COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_INK_DIM)


static func paint_open_elite(btn: Button, on: bool) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("5a3a52") if on else Color("3a2a38")
	bg.set_corner_radius_all(16)
	bg.border_color = Color("8a5a82")
	bg.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)
	btn.add_theme_color_override("font_color", Color("f3d6ef"))
	btn.add_theme_color_override("font_hover_color", Color("ffffff"))
	btn.add_theme_color_override("font_pressed_color", Color("f3d6ef"))


static func paint_open_random(btn: Button, on: bool) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("2a4a52") if on else Color("1e343a")
	bg.set_corner_radius_all(16)
	bg.border_color = Color("4a7a82")
	bg.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)
	btn.add_theme_color_override("font_color", Color("d6eef3"))
	btn.add_theme_color_override("font_hover_color", Color("ffffff"))
	btn.add_theme_color_override("font_pressed_color", Color("d6eef3"))


static func step_button(text: String, on: bool, cb: Callable, tall: float = STEP_BTN_H, wide: float = STEP_BTN_W) -> Button:
	var btn := bare_button(text, wide, tall)
	paint_btn(btn, on)
	btn.pressed.connect(cb)
	return btn


static func hub_tile(label: String, icon_id: String, on: bool, locked: bool, cb: Callable) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	## Fixed height — do not let GridContainer stretch the hit box.
	btn.custom_minimum_size = Vector2(0, HUB_TILE_H)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn.clip_text = true
	btn.expand_icon = false
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.text = label
	btn.icon = PrepIcons.icon_tex(icon_id)
	btn.disabled = locked
	## px_btn doubles size and blows past HUB_TILE_H; hub chrome uses px().
	_apply_hub_button_font(btn, 22)
	paint_hub_surface(btn, on, locked, false)
	if not locked:
		btn.pressed.connect(cb)
	return btn


static func hub_row(label: String, icon_id: String, on: bool, locked: bool, tag: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, HUB_ROW_H)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.expand_icon = false
	btn.text = label if tag == "" else "%s　　%s" % [label, tag]
	btn.icon = PrepIcons.icon_tex(icon_id)
	btn.disabled = locked
	_apply_hub_button_font(btn, 24)
	paint_hub_surface(btn, on, locked, true)
	if not locked:
		btn.pressed.connect(cb)
	return btn


static func _apply_hub_button_font(btn: Button, size: int) -> void:
	UiFont.apply_button(btn, size)
	btn.add_theme_font_size_override("font_size", UiFont.px(size))


static func paint_hub_surface(btn: Button, on: bool, locked: bool, row: bool) -> void:
	var bg := StyleBoxFlat.new()
	if locked:
		bg.bg_color = Color("1a221e")
		bg.border_color = Color("2a3830")
		bg.set_border_width_all(1)
	elif on:
		bg.bg_color = COL_CARD_ON
		bg.border_color = COL_GOLD
		bg.set_border_width_all(3)
	else:
		bg.bg_color = COL_CARD
		bg.border_color = COL_LINE
		bg.set_border_width_all(1)
	bg.set_corner_radius_all(12 if not row else 10)
	bg.content_margin_left = 12
	bg.content_margin_right = 12
	bg.content_margin_top = 6
	bg.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)
	btn.add_theme_stylebox_override("disabled", bg)
	var col := Color("5a655e") if locked else (Color("f4d35e") if on else Color("f4f1ea"))
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", Color("f4d35e") if not locked else col)
	btn.add_theme_color_override("font_pressed_color", col)
	btn.add_theme_color_override("font_disabled_color", Color("5a655e"))
