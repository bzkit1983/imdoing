extends Node2D
## Full-view Prep aquarium — fish swim from fish_stock; counts sit top-right.

const Tuning = preload("res://scripts/tuning.gd")
const UiFont = preload("res://scripts/ui_font.gd")

## Near-fullscreen tank (Prep ~1280×720; leave strip for bottom actions).
const W := 1120
const H := 500
const MAX_PER_SPECIES := 4
const MAX_TOTAL := 16

## Soft body colors per fish_id (tank water is cool teal).
const FISH_FILL := {
	"saba": "9eb8c8",
	"tai": "e8a090",
	"sanma": "4a6a88",
	"aji": "c8c070",
	"ayu": "a8c890",
}
const FISH_EDGE := {
	"saba": "6a8494",
	"tai": "b07068",
	"sanma": "2a4060",
	"aji": "908848",
	"ayu": "688858",
}

## Cozy stock plate — warm paper／cocoa so copy never sits on teal water.
const STOCK_PLATE := Color("F4F1EA")
const STOCK_PLATE_EDGE := Color("C9A66B")
const STOCK_INK := Color("5C4938")
const STOCK_MUTED := Color("9C8B7A")

## Each entry: {id, x, y, vx, amp, phase}
var school: Array = []
var _t: float = 0.0
var _counts: Dictionary = {}
var _stock_root: Control = null
var _stock_labels: Dictionary = {}


func setup_from_state(state: RefCounted) -> void:
	school.clear()
	_counts.clear()
	_t = 0.0
	_ensure_stock_ui()
	if state == null:
		_refresh_stock_labels()
		queue_redraw()
		return
	var total := 0
	for fid in Tuning.FISH_IDS:
		var have := int(state.fish_count(fid))
		_counts[fid] = have
		var n := mini(have, MAX_PER_SPECIES)
		for i in n:
			if total >= MAX_TOTAL:
				break
			school.append({
				"id": fid,
				"x": randf_range(48.0, float(W - 48)),
				"y": randf_range(56.0, float(H - 64)),
				"vx": randf_range(22.0, 42.0) * (1.0 if randf() > 0.5 else -1.0),
				"amp": randf_range(2.5, 6.0),
				"phase": randf() * TAU,
			})
			total += 1
		if total >= MAX_TOTAL:
			break
	_refresh_stock_labels()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for row in school:
		if not (row is Dictionary):
			continue
		var vx := float(row.get("vx", 20.0))
		var x := float(row.get("x", 40.0)) + vx * delta
		if x < 36.0 or x > float(W - 36):
			vx *= -1.0
			x = clampf(x, 36.0, float(W - 36))
			row["vx"] = vx
		row["x"] = x
	queue_redraw()


func _box(x: float, y: float, w: float, h: float, shade: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(shade))


func _draw() -> void:
	## Wooden rim (Cozy warm).
	_box(0, 0, W, H, "C9A66B")
	_box(6, 6, W - 12, H - 12, "8B6914")
	## Glass / water.
	_box(16, 16, W - 32, H - 40, "2a6a78")
	_box(20, 20, W - 40, H - 48, "3a8a9a")
	## Light shaft.
	_box(48, 24, 72, H - 64, "5ab0c0")
	## Bubbles.
	for b in 8:
		var bx := 60.0 + b * 120.0 + sin(_t * 1.2 + b) * 6.0
		var by := fmod(_t * 26.0 + b * 36.0, float(H - 72)) + 28.0
		_box(bx, by, 4, 4, "c8e8f0")
	## Gravel.
	_box(16, H - 32, W - 32, 16, "6b5a3e")
	for g in 28:
		_box(22 + g * 38, H - 28, 14, 6, "7a6848" if g % 2 == 0 else "5c4c34")
	## Plants.
	_draw_plant(40, H - 32)
	_draw_plant(W * 0.35, H - 32)
	_draw_plant(W * 0.65, H - 32)
	_draw_plant(W - 56, H - 32)
	## Fish.
	if school.is_empty():
		_box(W * 0.5 - 16, H * 0.45, 32, 10, "2a5a68")
	else:
		for row in school:
			if row is Dictionary:
				_draw_fish(row)


func _draw_plant(base_x: float, base_y: float) -> void:
	for leaf in 4:
		var lx := base_x + leaf * 4.0 - 6.0
		var ly := base_y - 14.0 - leaf * 10.0 + sin(_t * 2.0 + leaf) * 2.0
		_box(lx, ly, 6, 16, "3f7a48" if leaf % 2 == 0 else "4f8a58")


func _draw_fish(row: Dictionary) -> void:
	var fid := String(row.get("id", "saba"))
	var x := float(row.get("x", 40.0))
	var y := float(row.get("y", 60.0)) + sin(_t * 2.2 + float(row.get("phase", 0.0))) * float(row.get("amp", 3.0))
	var facing := 1.0 if float(row.get("vx", 1.0)) >= 0.0 else -1.0
	var fill := String(FISH_FILL.get(fid, "9eb8c8"))
	var edge := String(FISH_EDGE.get(fid, "6a8494"))
	## Body (slightly larger for fullscreen tank).
	_box(x - 12, y - 4, 24, 10, edge)
	_box(x - 10, y - 3, 20, 8, fill)
	_box(x + facing * 9, y - 3, 7, 7, fill)
	_box(x - facing * 14, y - 5, 5, 4, edge)
	_box(x - facing * 14, y + 1, 5, 4, edge)
	_box(x + facing * 7, y - 1, 3, 3, "2a2030")
	_box(x - facing * 1, y - 7, 6, 3, edge)


func _ensure_stock_ui() -> void:
	if _stock_root != null and is_instance_valid(_stock_root):
		return
	_stock_root = Control.new()
	_stock_root.name = "StockPanel"
	## Top-right of tank, inset from wood rim.
	_stock_root.position = Vector2(W - 248, 24)
	_stock_root.size = Vector2(220, 28 + Tuning.FISH_IDS.size() * 28)
	_stock_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stock_root)
	var plate := ColorRect.new()
	plate.color = STOCK_PLATE
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_root.add_child(plate)
	var edge := ColorRect.new()
	edge.color = STOCK_PLATE_EDGE
	edge.position = Vector2.ZERO
	edge.size = Vector2(_stock_root.size.x, 4)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_root.add_child(edge)
	var y := 10.0
	for fid in Tuning.FISH_IDS:
		var lab := Label.new()
		lab.position = Vector2(12, y)
		lab.size = Vector2(196, 26)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiFont.apply_label(lab, UiFont.SIZE_CAPTION, UiFont.WEIGHT_BOLD, 2, Color(1, 1, 1, 0.92))
		lab.add_theme_color_override("font_color", STOCK_INK)
		_stock_root.add_child(lab)
		_stock_labels[fid] = lab
		y += 28.0


func _refresh_stock_labels() -> void:
	if _stock_root == null:
		return
	var any := false
	for fid in Tuning.FISH_IDS:
		var n := int(_counts.get(fid, 0))
		if n > 0:
			any = true
		var lab: Label = _stock_labels.get(fid) as Label
		if lab == null:
			continue
		lab.text = Loc.t("prep.fish_tank_gallery.row", [Tuning.fish_name(fid), n])
		lab.add_theme_color_override("font_color", STOCK_INK if n > 0 else STOCK_MUTED)
	_stock_root.visible = true
	## Empty hint uses muted ink on the same plate (still readable).
	if not any and _stock_labels.has(Tuning.FISH_IDS[0]):
		pass
