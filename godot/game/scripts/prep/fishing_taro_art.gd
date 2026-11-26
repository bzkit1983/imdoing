extends Node2D
## 8-bit riverside art for Fishing Taro (320×180). Host drives positions／phase.

const W := 320
const H := 180
const SHORE_Y := 112

var player_x: float = 160.0
var facing: float = 1.0
var shadow_x: float = -999.0
var shadow_y: float = 64.0
var shadow_visible: bool = false
var bobber_x: float = 0.0
var bobber_y: float = 0.0
var bobber_visible: bool = false
var bobber_nibble: bool = false
var bite_flash: float = 0.0
var splash: float = 0.0
var rod_cast: bool = false
var t: float = 0.0


func reset_scene() -> void:
	player_x = 160.0
	facing = 1.0
	shadow_visible = false
	bobber_visible = false
	bobber_nibble = false
	bite_flash = 0.0
	splash = 0.0
	rod_cast = false
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	if bite_flash > 0.0:
		bite_flash = maxf(0.0, bite_flash - delta)
	if splash > 0.0:
		splash = maxf(0.0, splash - delta)
	queue_redraw()


func _box(x: float, y: float, w: float, h: float, shade: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(shade))


func _draw() -> void:
	## Sky + far hills.
	_box(0, 0, W, 48, "6ea0b8")
	_box(0, 40, W, 20, "5b8fa8")
	for hill in 5:
		var hx := hill * 70 - 10
		_box(hx, 52, 64, 18, "3f6d5e")
		_box(hx + 8, 46, 40, 12, "4a7d6a")
	## Water.
	_box(0, 58, W, SHORE_Y - 58, "2a5f78")
	_box(0, 70, W, 10, "34708a")
	for ripple in 8:
		var rx := fmod(t * 18.0 + ripple * 42.0, float(W + 40)) - 20.0
		_box(rx, 78 + (ripple % 3) * 8, 18, 2, "3d7c96")
	## Fish shadow.
	if shadow_visible:
		var sway := sin(t * 2.4 + shadow_x * 0.05) * 3.0
		_box(shadow_x - 14, shadow_y - 4 + sway, 28, 8, "1a3340")
		_box(shadow_x - 10, shadow_y - 2 + sway, 20, 4, "152830")
	## Bobber.
	if bobber_visible:
		var by := bobber_y + (sin(t * 10.0) * 1.5 if bobber_nibble else sin(t * 3.0) * 1.0)
		_box(bobber_x - 3, by - 3, 6, 6, "e8e8e8")
		_box(bobber_x - 3, by, 6, 3, "c43c3c")
		_box(bobber_x - 1, by - 6, 2, 4, "d8d0c0")
	if splash > 0.0:
		var s := 1.0 - splash
		_box(bobber_x - 6 - s * 4, bobber_y - 2, 4, 2, "9ad0e8")
		_box(bobber_x + 2 + s * 4, bobber_y - 2, 4, 2, "9ad0e8")
	if bite_flash > 0.0:
		_box(bobber_x - 10, bobber_y - 10, 20, 20, "f4d35e")
		_box(bobber_x - 6, bobber_y - 6, 12, 12, "2a5f78")
	## Shore.
	_box(0, SHORE_Y, W, H - SHORE_Y, "6b5a3e")
	for tile in 20:
		_box(tile * 16, SHORE_Y, 16, 8, "7a6848" if tile % 2 == 0 else "6b5a3e")
		_box(tile * 16, SHORE_Y + 8, 16, H - SHORE_Y - 8, "5c4c34" if tile % 2 == 0 else "53442e")
	## Grass fringe.
	for g in 16:
		_box(g * 20 + 4, SHORE_Y - 4, 3, 5, "4f7a48")
	_draw_player()


func _draw_player() -> void:
	var px := int(player_x)
	var py := SHORE_Y + 18
	var f := int(facing)
	## Shadow under feet.
	_box(px - 10, py + 20, 20, 4, "3a3224")
	## Legs.
	_box(px - 6, py + 10, 5, 12, "3d4a6a")
	_box(px + 1, py + 10, 5, 12, "3d4a6a")
	## Body.
	_box(px - 8, py - 2, 16, 14, "c4783a")
	_box(px - 6, py, 12, 10, "e8a838")
	## Head.
	_box(px - 7, py - 16, 14, 14, "f1ba87")
	_box(px - 6, py - 18, 12, 4, "5c4030")
	_box(px + f * 3, py - 10, 3, 3, "473341")
	## Rod.
	var rod_tip_x := px + f * (28 if rod_cast else 18)
	var rod_tip_y := py - (22 if rod_cast else 8)
	draw_line(Vector2(px + f * 6, py + 2), Vector2(rod_tip_x, rod_tip_y), Color("d8c8a0"), 2.0)
	if bobber_visible and rod_cast:
		draw_line(Vector2(rod_tip_x, rod_tip_y), Vector2(bobber_x, bobber_y), Color("c8c0b0", 0.7), 1.0)
