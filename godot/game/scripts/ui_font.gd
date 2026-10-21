extends RefCounted
## Bundled Traditional Chinese font so Web / iPhone Safari can render 中文.
## Game-scoped subset — rebuild via tools/fonts/subset_notosans_tc.py
## (docs/alpha/fonts-subset.md). Interface type stays modest; virtual-button
## captions keep a larger size.

const FACE := preload("res://fonts/NotoSansTC-Game.otf")

const BODY := 24
const TITLE := 28
const WORLD := 22
const BUTTON := 24
const HUGE := 44


static func font() -> Font:
	return FACE


static func fit() -> float:
	var win := DisplayServer.window_get_size()
	if win.x < 8 or win.y < 8:
		return 1.0
	return minf(float(win.x) / 1280.0, float(win.y) / 720.0)


static func px(size: int) -> int:
	var f := maxf(fit(), 0.25)
	if float(size) * f >= 13.0:
		return size
	return int(ceil(13.0 / f))


static func px_btn(size: int) -> int:
	var f := maxf(fit(), 0.25)
	return maxi(int(round(float(size) * 2.0)), int(ceil(15.0 / f)))


static func apply_label(lab: Label, size: int = BODY) -> void:
	lab.add_theme_font_override("font", FACE)
	lab.add_theme_font_size_override("font_size", px(size))


static func apply_button(btn: Button, size: int = BUTTON) -> void:
	btn.add_theme_font_override("font", FACE)
	btn.add_theme_font_size_override("font_size", px_btn(size))
