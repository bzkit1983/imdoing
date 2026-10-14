extends RefCounted
## Bundled Traditional Chinese font so Web / iPhone Safari can render 中文.

const FACE := preload("res://fonts/NotoSansTC-Regular.otf")


static func font() -> Font:
	return FACE


static func apply_label(lab: Label, size: int = 13) -> void:
	lab.add_theme_font_override("font", FACE)
	lab.add_theme_font_size_override("font_size", size)


static func apply_button(btn: Button, size: int = 16) -> void:
	btn.add_theme_font_override("font", FACE)
	btn.add_theme_font_size_override("font_size", size)
