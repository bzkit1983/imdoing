extends Node2D
## World-space repair timing bar drawn above a broken self-checkout.

var machine: Node2D

const BAR_W := 112.0
const BAR_H := 14.0
const ZONE_COLORS := [
	Color("f4f1ea"),  ## blank
	Color("e74c3c"),  ## red
	Color("f1c40f"),  ## yellow
	Color("2ecc71"),  ## green
	Color("f1c40f"),  ## yellow
	Color("e74c3c"),  ## red
	Color("ffffff"),  ## white
]


func _draw() -> void:
	if machine == null or not bool(machine.get("_repairing")):
		return
	var x0 := -BAR_W * 0.5
	var y0 := -BAR_H * 0.5
	draw_rect(Rect2(x0 - 2, y0 - 2, BAR_W + 4, BAR_H + 4), Color(0.1, 0.1, 0.1, 0.85), true)
	var zw := BAR_W / 7.0
	for i in 7:
		draw_rect(Rect2(x0 + zw * float(i), y0, zw - 1.0, BAR_H), ZONE_COLORS[i], true)
	## Cursor: same ping-pong as machine._cursor_zone.
	var t := float(machine.get("_repair_t"))
	var hz := 1.5
	if Engine.get_main_loop() != null:
		var Tun = load("res://scripts/tuning.gd")
		hz = float(Tun.SELF_CASHIER_REPAIR_HZ)
	var trip := absf(fposmod(t * hz * 2.0, 2.0) - 1.0)
	var cx := x0 + trip * BAR_W
	draw_line(Vector2(cx, y0 - 4), Vector2(cx, y0 + BAR_H + 4), Color("121212"), 3.0)
	draw_line(Vector2(cx, y0 - 4), Vector2(cx, y0 + BAR_H + 4), Color("fff4c2"), 1.5)
