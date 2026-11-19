extends RefCounted
## UiFont — shared DynamicFont for HUD / menus (Noto Sans TC Game subset).
## Prefer Loc.t for copy; this only styles Control fonts.
## Type Scale tokens: docs/systemdesign/uitypography.md
## Rebuild faces: tools/fonts/subset_notosans_tc.py

const FACE := preload("res://fonts/NotoSansTC-Game.ttf")
const FACE_BOLD := preload("res://fonts/NotoSansTC-Game-Bold.ttf")
const FACE_BLACK := preload("res://fonts/NotoSansTC-Game-Black.ttf")

const WEIGHT_REGULAR := 0
const WEIGHT_BOLD := 1
const WEIGHT_BLACK := 2

## Type Scale (design tokens → px() / px_btn()).
const SIZE_DISPLAY := 36
const SIZE_HEADING := 28
const SIZE_HEADING_SM := 24
const SIZE_BODY := 24
const SIZE_BODY_SM := 22
const SIZE_CAPTION := 18
const SIZE_MICRO := 16
## Alias: Prep/shop body at body-sm.
const SIZE_UI := SIZE_BODY_SM
## Alias: Prep/shop titles at heading.
const SIZE_TITLE := SIZE_HEADING
## Compact labels (Dev HUD, chips) — micro.
const SIZE_COMPACT := SIZE_MICRO

## Button face / HUD callouts — larger than body for tap targets.
const SIZE_BUTTON := 28
## Alias kept for older call sites.
const SIZE_BTN := SIZE_BUTTON
## Dense tables / skill strips.
const SIZE_DENSE := 20
## Splash / wordmark — display.
const SIZE_HERO := SIZE_DISPLAY

## Legacy aliases (prep / older call sites).
const BODY := SIZE_BODY
const TITLE := SIZE_HEADING
const WORLD := SIZE_BODY_SM
const BUTTON := SIZE_BODY
const HUGE := 44

## Outline defaults (black, semi-opaque).
const OUTLINE_UI := 2
const OUTLINE_COMPACT := 1
const OUTLINE_BUTTON := 3


static func font() -> Font:
	return FACE


static func font_bold() -> Font:
	return FACE_BOLD


static func font_black() -> Font:
	return FACE_BLACK


static func _face_for_weight(weight: int) -> FontFile:
	match weight:
		WEIGHT_BOLD:
			return FACE_BOLD
		WEIGHT_BLACK:
			return FACE_BLACK
		_:
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


## Buttons / titles: ~2× design so labels stay readable on 9-slice faces (Prep etc.).
static func px_btn(size: int) -> int:
	var f := maxf(fit(), 0.25)
	return maxi(int(round(float(size) * 2.0)), int(ceil(15.0 / f)))


static func apply_label(
	label: Label,
	design_size: int = SIZE_UI,
	weight: int = WEIGHT_REGULAR,
	outline: int = 0,
	outline_color: Color = Color(0, 0, 0, 0.85)
) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", _face_for_weight(weight))
	label.add_theme_font_size_override("font_size", px(design_size))
	if outline > 0:
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_outline_color", outline_color)


static func apply_title_bold(
	label: Label,
	design_size: int = SIZE_HEADING_SM,
	outline: int = 0,
	outline_color: Color = Color(0, 0, 0, 0.85)
) -> void:
	apply_label(label, design_size, WEIGHT_BOLD, outline, outline_color)


## Prep / legacy: font size via px_btn (≈2×). Prefer apply_button_literal for pause chrome.
static func apply_button(
	btn: Button,
	design_size: int = SIZE_BUTTON,
	outline: int = 0,
	outline_color: Color = Color(0, 0, 0, 0.9)
) -> void:
	if btn == null:
		return
	btn.add_theme_font_override("font", FACE)
	btn.add_theme_font_size_override("font_size", px_btn(design_size))
	if outline > 0:
		btn.add_theme_constant_override("outline_size", outline)
		btn.add_theme_color_override("font_outline_color", outline_color)


## Literal design size via px() — no ×2. Use for pause / cozy chrome pills.
static func apply_button_literal(
	btn: Button,
	design_size: int = SIZE_BODY_SM,
	weight: int = WEIGHT_REGULAR,
	outline: int = 0,
	outline_color: Color = Color(0, 0, 0, 0.85)
) -> void:
	if btn == null:
		return
	btn.add_theme_font_override("font", _face_for_weight(weight))
	btn.add_theme_font_size_override("font_size", px(design_size))
	if outline > 0:
		btn.add_theme_constant_override("outline_size", outline)
		btn.add_theme_color_override("font_outline_color", outline_color)


static func apply_richtext(
	rtl: RichTextLabel,
	design_size: int = SIZE_UI,
	weight: int = WEIGHT_REGULAR,
	outline: int = 0,
	outline_color: Color = Color(0, 0, 0, 0.85)
) -> void:
	if rtl == null:
		return
	rtl.add_theme_font_override("normal_font", _face_for_weight(weight))
	rtl.add_theme_font_size_override("normal_font_size", px(design_size))
	if outline > 0:
		rtl.add_theme_constant_override("outline_size", outline)
		rtl.add_theme_color_override("font_outline_color", outline_color)
