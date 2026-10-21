extends RefCounted
## Shared prep-menu chrome helpers (fonts, buttons, panels).

const UiFont = preload("res://scripts/ui_font.gd")

const PREP_TITLE := 40
const PREP_INFO := 28
const PREP_LIST := 32
const PREP_HINT := 24
const PREP_BTN := 32
const PREP_NUM := 44


static func clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


static func name_label(text: String, width: float, tall: float = 72.0) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.custom_minimum_size = Vector2(width, tall)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFont.apply_label(lab, PREP_BTN)
	lab.add_theme_color_override("font_color", Color("f4f1ea"))
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
	bg.bg_color = Color("f4d35e") if on else Color("24302a")
	bg.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)
	var col := Color("1c241f") if on else Color("f4f1ea")
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", Color("1c241f") if on else Color("f4d35e"))
	btn.add_theme_color_override("font_pressed_color", Color("1c241f"))


static func step_button(text: String, on: bool, cb: Callable, tall: float = 72.0, wide: float = 84.0) -> Button:
	var btn := bare_button(text, wide, tall)
	paint_btn(btn, on)
	btn.pressed.connect(cb)
	return btn
