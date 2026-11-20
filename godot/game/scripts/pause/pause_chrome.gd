extends RefCounted
## Pause menu presentation — layout constants, pill styling, volume row geometry.

const UiFont = preload("res://scripts/ui_font.gd")

## pause-ui-chrome + docs/systemdesign/uitypography.md
const COL_COCOA := Color("5C4938")
const COL_TAUPE := Color("9C8B7A")
const SIZE_CAPTION := 16
const SIZE_BODY_SM := 22
const SIZE_BODY := 29
const SIZE_HEADING_SM := 43
const SPACE_12 := 12.0
const SPACE_24 := 24.0
const SPACE_30 := 30.0
## Editor-tuned (pause_menu.tscn bake) — left title／body, right pill column.
const ROW_H_MAX := 84.0
const ROW_H_MIN := 56.0
const ROW_LEFT := 345.0
const ROW_RIGHT := 681.0
const VOL_ROW_LEFT := 223.0
const VOL_ROW_RIGHT := 803.0
const ROW_GAP := 2.0
const ROWS_TOP_MAIN := 58.0
const ROWS_TOP_SETTINGS := 58.0
const TITLE_LEFT := 66.0
const TITLE_RIGHT := 245.0
const TITLE_TOP := 57.0
const TITLE_BOTTOM := 120.0
const BODY_LEFT := 69.0
const BODY_RIGHT := 299.0
const BODY_TOP := 125.0
const BODY_BOTTOM := 292.0
const VOL_MINI := 60.0
const VOL_SIDE_NEST := 14.0
const GAP_MIN := -4.0


static func layout_header_block(menu: CanvasLayer, settings: bool) -> float:
	if menu._title:
		menu._title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		menu._title.offset_left = TITLE_LEFT
		menu._title.offset_right = TITLE_RIGHT
		menu._title.offset_top = TITLE_TOP
		menu._title.offset_bottom = TITLE_BOTTOM
	if menu._body != null and menu._body.visible:
		menu._body.offset_left = BODY_LEFT
		menu._body.offset_right = BODY_RIGHT
		menu._body.offset_top = BODY_TOP
		menu._body.offset_bottom = BODY_BOTTOM
	return ROWS_TOP_SETTINGS if settings else ROWS_TOP_MAIN


static func layout_volume_row(menu: CanvasLayer, row: Control, row_h: float, font_px: int) -> void:
	row.clip_contents = false
	var row_w := row.offset_right - row.offset_left
	var side_w := VOL_MINI
	var mid_w := ROW_RIGHT - ROW_LEFT
	var mid_left := (row_w - mid_w) * 0.5
	var mid_right := mid_left + mid_w
	var mini_top := maxf(0.0, (row_h - side_w) * 0.5)
	for child in row.get_children():
		if not child is Button:
			continue
		var b := child as Button
		UiFont.apply_button_literal(b, font_px)
		if b == menu._vol_down or b == menu._bgm_vol_down:
			b.offset_left = mid_left - side_w + VOL_SIDE_NEST
			b.offset_right = b.offset_left + side_w
			b.offset_top = mini_top
			b.offset_bottom = mini_top + side_w
		elif b == menu._vol_up or b == menu._bgm_vol_up:
			b.offset_right = mid_right + side_w - VOL_SIDE_NEST
			b.offset_left = b.offset_right - side_w
			b.offset_top = mini_top
			b.offset_bottom = mini_top + side_w
		else:
			b.offset_left = mid_left
			b.offset_right = mid_right
			b.offset_top = 0.0
			b.offset_bottom = row_h
			b.clip_text = true


static func mark_mini_btn(btn: Button) -> void:
	if btn == null:
		return
	btn.set_meta("_pause_kind", "mini")


static func is_mini_btn(btn: Button) -> bool:
	return btn != null and str(btn.get_meta("_pause_kind", "")) == "mini"


static func style_btn(menu: CanvasLayer, btn: Button, on: bool) -> void:
	if btn == null:
		return
	ensure_pause_btn_skin(menu, btn)
	var focus_sb: StyleBox = btn.get_meta("_pause_focus") as StyleBox
	var normal_sb: StyleBox = btn.get_meta("_pause_normal") as StyleBox
	var hover_sb: StyleBox = btn.get_meta("_pause_hover") as StyleBox
	if on and focus_sb != null:
		btn.add_theme_stylebox_override("normal", focus_sb)
		btn.add_theme_stylebox_override("hover", focus_sb)
	else:
		if normal_sb != null:
			btn.add_theme_stylebox_override("normal", normal_sb)
		if hover_sb != null:
			btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_color_override("font_color", COL_COCOA)
	btn.add_theme_color_override("font_hover_color", COL_COCOA)
	btn.add_theme_color_override("font_pressed_color", COL_COCOA)
	btn.add_theme_color_override("font_focus_color", COL_COCOA)


static func ensure_pause_btn_skin(menu: CanvasLayer, btn: Button) -> void:
	if btn == null or btn.has_meta("_pause_skin_saved"):
		return
	if is_mini_btn(btn):
		ensure_mini_btn_styles(menu, btn)
	elif btn != menu._resume_btn and menu._resume_btn != null and menu._resume_btn.has_meta("_pause_skin_saved"):
		var rn: StyleBox = menu._resume_btn.get_meta("_pause_normal") as StyleBox
		var rh: StyleBox = menu._resume_btn.get_meta("_pause_hover") as StyleBox
		var rf: StyleBox = menu._resume_btn.get_meta("_pause_focus") as StyleBox
		if rn != null:
			btn.add_theme_stylebox_override("normal", rn)
		if rh != null:
			btn.add_theme_stylebox_override("hover", rh)
		if rf != null:
			btn.add_theme_stylebox_override("focus", rf)
		for state_name in ["pressed", "hover_pressed", "disabled"]:
			var sb := menu._resume_btn.get_theme_stylebox(state_name)
			if sb != null:
				btn.add_theme_stylebox_override(state_name, sb)
	else:
		var normal_sb := btn.get_theme_stylebox("normal")
		if normal_sb == null or not (normal_sb is StyleBoxTexture):
			if menu._resume_btn != null and btn != menu._resume_btn:
				copy_pause_btn_styles(menu, menu._resume_btn, btn)
	btn.set_meta("_pause_normal", btn.get_theme_stylebox("normal"))
	var hover_sb := btn.get_theme_stylebox("hover")
	if hover_sb == null:
		hover_sb = btn.get_theme_stylebox("normal")
	btn.set_meta("_pause_hover", hover_sb)
	var focus_sb := btn.get_theme_stylebox("focus")
	if focus_sb == null:
		focus_sb = btn.get_theme_stylebox("pressed")
		if focus_sb == null:
			focus_sb = btn.get_theme_stylebox("normal")
	if not is_mini_btn(btn) and focus_sb != null and focus_sb == btn.get_meta("_pause_normal"):
		if menu._resume_btn != null and menu._resume_btn.has_meta("_pause_focus"):
			focus_sb = menu._resume_btn.get_meta("_pause_focus") as StyleBox
	btn.set_meta("_pause_focus", focus_sb)
	btn.set_meta("_pause_skin_saved", true)


static func ensure_mini_btn_styles(menu: CanvasLayer, btn: Button) -> void:
	var n := btn.get_theme_stylebox("normal")
	var f := btn.get_theme_stylebox("pressed")
	if n == null and menu._vol_down != null and btn != menu._vol_down:
		n = menu._vol_down.get_theme_stylebox("normal")
		f = menu._vol_down.get_theme_stylebox("pressed")
	if n != null:
		btn.add_theme_stylebox_override("normal", n)
		btn.add_theme_stylebox_override("hover", n)
	if f != null:
		btn.add_theme_stylebox_override("pressed", f)
		btn.add_theme_stylebox_override("focus", f)
		btn.add_theme_stylebox_override("hover_pressed", f)


static func copy_pause_btn_styles(menu: CanvasLayer, from_btn: Button, to_btn: Button) -> void:
	if from_btn == null or to_btn == null:
		return
	ensure_pause_btn_skin(menu, from_btn)
	if from_btn.has_meta("_pause_normal"):
		var n: StyleBox = from_btn.get_meta("_pause_normal") as StyleBox
		var h: StyleBox = from_btn.get_meta("_pause_hover") as StyleBox
		var f: StyleBox = from_btn.get_meta("_pause_focus") as StyleBox
		if n != null:
			to_btn.add_theme_stylebox_override("normal", n)
		if h != null:
			to_btn.add_theme_stylebox_override("hover", h)
		else:
			to_btn.add_theme_stylebox_override("hover", n)
		for state_name in ["pressed", "hover_pressed", "disabled"]:
			var sb := from_btn.get_theme_stylebox(state_name)
			if sb != null:
				to_btn.add_theme_stylebox_override(state_name, sb)
		if f != null:
			to_btn.add_theme_stylebox_override("focus", f)
		if to_btn.has_meta("_pause_skin_saved"):
			to_btn.remove_meta("_pause_skin_saved")
		return
	for state_name in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
		var sb2 := from_btn.get_theme_stylebox(state_name)
		if sb2 != null:
			to_btn.add_theme_stylebox_override(state_name, sb2)

