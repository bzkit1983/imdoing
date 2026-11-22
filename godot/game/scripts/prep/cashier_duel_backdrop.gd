extends Node2D


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color("f3e4bd"))
	for i in range(-160, 420, 18):
		draw_line(Vector2(i, 0), Vector2(i + 120, 180), Color("d8c8a0"), 2.0)
		if i % 36 == 0:
			draw_line(Vector2(i + 4, 0), Vector2(i + 108, 180), Color("fff5d8"), 1.0)
	_draw_burst(Vector2(82, 87), Color("ffd438"), Color("f17b22"))
	_draw_burst(Vector2(238, 84), Color("40d6ee"), Color("4267da"))
	_draw_floor()
	_draw_player()
	_draw_master()
	_draw_abacus(Vector2(127, 107), Color("ffd743"))
	_draw_abacus(Vector2(193, 104), Color("64dcf2"))
	draw_rect(Rect2(0, 0, 320, 180), Color("1a1825"), false, 4.0)


func _draw_burst(center: Vector2, main: Color, shade: Color) -> void:
	for i in range(14):
		var a := TAU * float(i) / 14.0 - 0.12
		var b := TAU * float(i + 1) / 14.0 + 0.12
		var radius := 118.0 if i % 2 == 0 else 92.0
		var points := PackedVector2Array([center, center + Vector2.from_angle(a) * radius, center + Vector2.from_angle(b) * radius])
		draw_colored_polygon(points, shade if i % 3 == 0 else main)
	for i in range(11):
		var x := float(i) * 35.0 - 20.0
		draw_line(Vector2(x, 0), Vector2(x + 42.0, 180), Color(1, 1, 1, 0.58), 2.0)


func _draw_floor() -> void:
	draw_rect(Rect2(0, 144, 320, 36), Color("312846"))
	draw_rect(Rect2(0, 144, 320, 5), Color("1c1a2d"))
	for x in range(0, 320, 24):
		draw_line(Vector2(x, 149), Vector2(x + 14, 180), Color("584660"), 2.0)


func _draw_player() -> void:
	# Original supermarket clerk: short sleeves, apron, name badge and plain cap.
	draw_rect(Rect2(51, 121, 26, 24), Color("25233a"))
	draw_rect(Rect2(78, 120, 24, 25), Color("25233a"))
	draw_rect(Rect2(48, 143, 34, 7), Color("191827"))
	draw_rect(Rect2(77, 143, 34, 7), Color("191827"))
	draw_rect(Rect2(52, 66, 51, 57), Color("f4bf24"))
	draw_rect(Rect2(57, 75, 44, 50), Color("f8db83"))
	draw_rect(Rect2(62, 83, 30, 37), Color("fff0bc"))
	draw_rect(Rect2(91, 80, 11, 17), Color("e1a52c"))
	draw_rect(Rect2(67, 55, 33, 32), Color("f2b47c"))
	draw_rect(Rect2(62, 49, 41, 11), Color("e8ad21"))
	draw_rect(Rect2(68, 45, 31, 7), Color("29243b"))
	draw_rect(Rect2(72, 68, 5, 5), Color("20202d"))
	draw_rect(Rect2(89, 70, 5, 5), Color("20202d"))
	draw_rect(Rect2(77, 80, 16, 3), Color("7e4c32"))
	draw_rect(Rect2(87, 96, 13, 8), Color("b72e4b"))
	draw_line(Vector2(95, 82), Vector2(123, 98), Color("f2b47c"), 10.0)
	draw_rect(Rect2(116, 94, 11, 10), Color("f2b47c"))


func _draw_master() -> void:
	# Pixel portrait of Master Asia with long hair, moustache, headband and sash.
	draw_colored_polygon(PackedVector2Array([Vector2(258, 42), Vector2(276, 36), Vector2(305, 48), Vector2(315, 67), Vector2(308, 72), Vector2(282, 57), Vector2(266, 60)]), Color("151624"))
	draw_colored_polygon(PackedVector2Array([Vector2(264, 76), Vector2(286, 71), Vector2(312, 83), Vector2(315, 91), Vector2(287, 87), Vector2(270, 86)]), Color("b72e4b"))
	draw_rect(Rect2(244, 120, 24, 25), Color("272039"))
	draw_rect(Rect2(269, 118, 20, 27), Color("272039"))
	draw_rect(Rect2(239, 143, 34, 7), Color("151624"))
	draw_rect(Rect2(267, 143, 32, 7), Color("151624"))
	draw_colored_polygon(PackedVector2Array([Vector2(231, 67), Vector2(276, 59), Vector2(287, 124), Vector2(242, 127)]), Color("17234d"))
	draw_colored_polygon(PackedVector2Array([Vector2(236, 71), Vector2(264, 80), Vector2(262, 124), Vector2(230, 116)]), Color("3154b2"))
	draw_rect(Rect2(274, 76, 11, 36), Color("1c2f78"))
	draw_colored_polygon(PackedVector2Array([Vector2(247, 78), Vector2(258, 81), Vector2(269, 119), Vector2(255, 116)]), Color("b72e4b"))
	draw_line(Vector2(237, 94), Vector2(269, 102), Color("f0cd4b"), 5.0)
	draw_line(Vector2(239, 98), Vector2(267, 106), Color("f5dc79"), 2.0)
	draw_line(Vector2(239, 82), Vector2(202, 96), Color("edbc94"), 9.0)
	draw_rect(Rect2(192, 92, 12, 9), Color("edbc94"))
	draw_rect(Rect2(236, 52, 35, 32), Color("edbc94"))
	draw_colored_polygon(PackedVector2Array([Vector2(231, 50), Vector2(246, 44), Vector2(267, 49), Vector2(273, 58), Vector2(270, 79), Vector2(263, 88), Vector2(239, 84), Vector2(232, 69)]), Color("151624"))
	draw_rect(Rect2(231, 48, 42, 7), Color("b72e4b"))
	draw_rect(Rect2(235, 55, 7, 27), Color("151624"))
	draw_rect(Rect2(257, 39, 12, 10), Color("151624"))
	draw_rect(Rect2(264, 34, 9, 8), Color("151624"))
	draw_rect(Rect2(238, 62, 5, 4), Color("161a31"))
	draw_rect(Rect2(253, 61, 5, 4), Color("161a31"))
	draw_line(Vector2(239, 69), Vector2(258, 72), Color("e9dfcf"), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(239, 69), Vector2(250, 70), Vector2(260, 67), Vector2(256, 74), Vector2(246, 76)]), Color("f2eee1"))
	draw_colored_polygon(PackedVector2Array([Vector2(245, 75), Vector2(258, 74), Vector2(255, 85), Vector2(249, 90), Vector2(245, 83)]), Color("e9dfcf"))
	draw_colored_polygon(PackedVector2Array([Vector2(274, 61), Vector2(286, 64), Vector2(304, 81), Vector2(299, 91), Vector2(282, 79)]), Color("342764"))


func _draw_abacus(center: Vector2, color: Color) -> void:
	var frame := Rect2(center - Vector2(11, 9), Vector2(22, 18))
	draw_rect(frame, Color("211b2b"))
	draw_rect(frame.grow(-2), Color("7f4a2c"))
	for row in range(3):
		var y := frame.position.y + 5.0 + row * 5.0
		draw_line(Vector2(frame.position.x + 2, y), Vector2(frame.end.x - 2, y), Color("f7dfaa"), 1.0)
		for bead in range(3):
			var x := frame.position.x + 5.0 + bead * 6.0 + (row % 2) * 2.0
			draw_rect(Rect2(Vector2(x, y - 2), Vector2(3, 4)), color)
