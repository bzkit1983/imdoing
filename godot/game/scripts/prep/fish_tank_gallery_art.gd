extends Node2D
## 8-bit aquarium for Prep fish_tank_gallery — fish swim from fish_stock counts.

const Tuning = preload("res://scripts/tuning.gd")

const W := 240
const H := 148
const MAX_PER_SPECIES := 3
const MAX_TOTAL := 12

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

## Each entry: {id, x, y, vx, amp, phase}
var school: Array = []
var _t: float = 0.0


func setup_from_state(state: RefCounted) -> void:
	school.clear()
	_t = 0.0
	if state == null:
		queue_redraw()
		return
	var total := 0
	for fid in Tuning.FISH_IDS:
		var n := mini(int(state.fish_count(fid)), MAX_PER_SPECIES)
		for i in n:
			if total >= MAX_TOTAL:
				break
			school.append({
				"id": fid,
				"x": randf_range(28.0, float(W - 28)),
				"y": randf_range(36.0, float(H - 36)),
				"vx": randf_range(18.0, 34.0) * (1.0 if randf() > 0.5 else -1.0),
				"amp": randf_range(2.0, 5.0),
				"phase": randf() * TAU,
			})
			total += 1
		if total >= MAX_TOTAL:
			break
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for row in school:
		if not (row is Dictionary):
			continue
		var vx := float(row.get("vx", 20.0))
		var x := float(row.get("x", 40.0)) + vx * delta
		if x < 22.0 or x > float(W - 22):
			vx *= -1.0
			x = clampf(x, 22.0, float(W - 22))
			row["vx"] = vx
		row["x"] = x
	queue_redraw()


func _box(x: float, y: float, w: float, h: float, shade: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(shade))


func _draw() -> void:
	## Wooden rim (Cozy warm).
	_box(0, 0, W, H, "C9A66B")
	_box(4, 4, W - 8, H - 8, "8B6914")
	## Glass / water.
	_box(10, 10, W - 20, H - 28, "2a6a78")
	_box(12, 12, W - 24, H - 34, "3a8a9a")
	## Light shaft.
	_box(28, 14, 36, H - 44, "5ab0c0")
	## Bubbles.
	for b in 5:
		var bx := 40.0 + b * 36.0 + sin(_t * 1.2 + b) * 4.0
		var by := fmod(_t * 22.0 + b * 28.0, float(H - 48)) + 18.0
		_box(bx, by, 3, 3, "c8e8f0")
	## Gravel.
	_box(10, H - 22, W - 20, 12, "6b5a3e")
	for g in 14:
		_box(14 + g * 15, H - 20, 8, 4, "7a6848" if g % 2 == 0 else "5c4c34")
	## Plants.
	_draw_plant(24, H - 22)
	_draw_plant(W - 36, H - 22)
	## Fish.
	if school.is_empty():
		## Empty tank hint glyph — quiet.
		_box(W * 0.5 - 10, H * 0.45, 20, 8, "2a5a68")
	else:
		for row in school:
			if row is Dictionary:
				_draw_fish(row)


func _draw_plant(base_x: float, base_y: float) -> void:
	for leaf in 3:
		var lx := base_x + leaf * 3.0 - 3.0
		var ly := base_y - 10.0 - leaf * 8.0 + sin(_t * 2.0 + leaf) * 1.5
		_box(lx, ly, 5, 12, "3f7a48" if leaf % 2 == 0 else "4f8a58")


func _draw_fish(row: Dictionary) -> void:
	var fid := String(row.get("id", "saba"))
	var x := float(row.get("x", 40.0))
	var y := float(row.get("y", 60.0)) + sin(_t * 2.2 + float(row.get("phase", 0.0))) * float(row.get("amp", 3.0))
	var facing := 1.0 if float(row.get("vx", 1.0)) >= 0.0 else -1.0
	var fill := String(FISH_FILL.get(fid, "9eb8c8"))
	var edge := String(FISH_EDGE.get(fid, "6a8494"))
	## Body.
	_box(x - 8, y - 3, 16, 7, edge)
	_box(x - 7, y - 2, 14, 5, fill)
	## Head bump.
	_box(x + facing * 6, y - 2, 5, 5, fill)
	## Tail.
	_box(x - facing * 10, y - 4, 4, 3, edge)
	_box(x - facing * 10, y + 1, 4, 3, edge)
	## Eye.
	_box(x + facing * 5, y - 1, 2, 2, "2a2030")
	## Fin.
	_box(x - facing * 1, y - 5, 4, 2, edge)
