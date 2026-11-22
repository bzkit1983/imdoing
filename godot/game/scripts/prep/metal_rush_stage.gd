extends Control

const LANE_COLORS := [Color("78dcb1"), Color("ffd077"), Color("87caff"), Color("f1a5ce")]
const TRAVEL_TIME := 1.6
const KEY_HINTS := ["D / X", "F / Y", "J / A", "K / B"]
var chart: RefCounted
var song_time := -3.0
var flashes := [0.0, 0.0, 0.0, 0.0]


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(320, 144))
	draw_rect(Rect2(0, 0, 320, 144), Color("1b2138"))
	for x in [6, 38, 256, 288]:
		draw_rect(Rect2(x, 24, 26, 95), Color("322d4b"))
		for row in 4:
			var y := 31 + row * 21
			draw_rect(Rect2(x + 2, y + 12, 22, 2), Color("806078"))
			for item in 4:
				var shade: Color = LANE_COLORS[(row + item) % 4]
				draw_rect(Rect2(x + 3 + item * 5, y + 4, 4, 8), shade.darkened(0.5))
	draw_rect(Rect2(0, 4, 320, 5), Color("5b4764"))
	for x in [20, 58, 256, 294]:
		draw_rect(Rect2(x, 9, 12, 4), Color("ffdd98"))
		draw_rect(Rect2(x - 3, 13, 18, 2), Color("80596c"))
	for lane in 4:
		var x := 72 + 44 * lane
		var shade: Color = LANE_COLORS[lane]
		draw_rect(Rect2(x, 0, 42, 144), shade.darkened(0.85))
		draw_rect(Rect2(x, 0, 1, 144), shade.darkened(0.55))
		draw_rect(Rect2(x + 2, 126, 38, 3), shade)
		if flashes[lane] > 0.0:
			draw_rect(Rect2(x + 2, 113, 38, 22), Color(shade, 0.45))
		draw_string(ThemeDB.fallback_font, Vector2(x + 7, 141), KEY_HINTS[lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, shade)
	if chart == null:
		return
	for i in range(chart.next_miss, chart.notes.size()):
		if chart.resolved.has(i):
			continue
		var note: Vector2 = chart.notes[i]
		var until := note.x - song_time
		if until > TRAVEL_TIME:
			break
		var y := roundf(126.0 - until * 126.0 / TRAVEL_TIME)
		var x := 76 + 44 * int(note.y)
		var shade: Color = LANE_COLORS[int(note.y)]
		draw_rect(Rect2(x, y - 4, 34, 7), shade)
		draw_rect(Rect2(x + 2, y - 3, 30, 2), shade.lightened(0.45))
