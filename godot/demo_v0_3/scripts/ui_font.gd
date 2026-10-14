extends RefCounted
## Bundled Traditional Chinese font so Web / iPhone Safari can render 中文.
## Sizes are for a 1280×720 viewport so iPhone 12 landscape (~844×390) stays readable.

const FACE := preload("res://fonts/NotoSansTC-Regular.otf")

const BODY := 28
const TITLE := 36
const WORLD := 26
const BUTTON := 24
const HUGE := 56


static func font() -> Font:
	return FACE


static func apply_label(lab: Label, size: int = BODY) -> void:
	lab.add_theme_font_override("font", FACE)
	lab.add_theme_font_size_override("font_size", size)


static func apply_button(btn: Button, size: int = BUTTON) -> void:
	btn.add_theme_font_override("font", FACE)
	btn.add_theme_font_size_override("font_size", size)
