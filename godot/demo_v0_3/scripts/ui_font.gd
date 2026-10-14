extends RefCounted
## Bundled Traditional Chinese font so Web / iPhone Safari can render 中文.
## Sizes are at least 2× the previous design, and grow further if the
## 1280×720 viewport is scaled down (iPhone 12 portrait especially).

const FACE := preload("res://fonts/NotoSansTC-Regular.otf")

const BODY := 28
const TITLE := 36
const WORLD := 26
const BUTTON := 24
const HUGE := 56


static func font() -> Font:
	return FACE


static func fit() -> float:
	var win := DisplayServer.window_get_size()
	if win.x < 8 or win.y < 8:
		return 1.0
	return minf(float(win.x) / 1280.0, float(win.y) / 720.0)


static func px(size: int) -> int:
	var doubled := size * 2
	# Keep ~22 CSS pixels even when the canvas is shrunk on a phone.
	var min_game := int(ceil(22.0 / maxf(fit(), 0.25)))
	return maxi(doubled, min_game)


static func apply_label(lab: Label, size: int = BODY) -> void:
	lab.add_theme_font_override("font", FACE)
	lab.add_theme_font_size_override("font_size", px(size))


static func apply_button(btn: Button, size: int = BUTTON) -> void:
	btn.add_theme_font_override("font", FACE)
	btn.add_theme_font_size_override("font_size", px(size))
