extends Node2D

var bites := [0, 0]
var chomp := [0.0, 0.0]


func reset() -> void:
	bites = [0, 0]
	chomp = [0.0, 0.0]
	queue_redraw()


func bite(side: int, count: int) -> void:
	bites[side] = count
	chomp[side] = 0.13
	queue_redraw()


func _process(delta: float) -> void:
	for side in 2:
		if chomp[side] > 0.0:
			chomp[side] = maxf(0.0, chomp[side] - delta)
			queue_redraw()


func _box(x: int, y: int, w: int, h: int, shade: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(shade))


func _draw() -> void:
	_box(0, 0, 320, 180, "17273b")
	_box(0, 36, 320, 92, "36585b")
	for bay in 6:
		var x := bay * 55
		_box(x, 43, 51, 51, "273e49")
		for row in 2:
			for slot in 6:
				var colors := ["ba6a68", "ddb878", "78a38f", "8d82a2"]
				_box(x + 3 + slot * 8, 47 + row * 21, 5, 11, colors[(bay + slot + row) % 4])
			_box(x, 59 + row * 21, 51, 3, "537675")
	for tile in 20:
		for row in 3:
			_box(tile * 16, 109 + row * 16, 16, 16, "455a65" if (tile + row) % 2 == 0 else "3b4e60")
	_box(0, 141, 320, 39, "17273b")
	_box(71, 116, 178, 16, "49354b")
	_box(67, 108, 186, 12, "e2ad78")
	_box(67, 117, 186, 5, "a96b61")
	_box(80, 122, 7, 14, "684a55")
	_box(233, 122, 7, 14, "684a55")
	_fighter(0, 73, 1)
	_fighter(1, 247, -1)
	for side in 2:
		var stack_x := 116 if side == 0 else 192
		_box(stack_x - 3, 106, 23, 3, "f3dbb2")
		for bun in 4 - floori(float(bites[side]) / 5.0) % 4:
			_bun(stack_x, 100 - bun * 5, 16)


func _fighter(side: int, x: int, facing: int) -> void:
	var biting: bool = chomp[side] > 0.0
	var shift := facing * (3 if biting else 0)
	var shirt := "efb94e" if side == 0 else "638ec0"
	var shadow := "a16b46" if side == 0 else "415582"
	_box(x - 16, 92, 32, 24, "273048")
	_box(x - 14, 93, 28, 19, shirt)
	_box(x - 8, 97, 16, 18, shadow)
	_box(x - 5, 99, 10, 13, shirt)
	_box(x - 13 + shift, 67, 26, 24, "453247")
	_box(x - 11 + shift, 72, 22, 18, "f1ba87")
	_box(x - 12 + shift, 66, 23, 7, shadow)
	_box(x - 9 + shift, 63, 17, 5, shirt)
	_box(x + facing * 5 + shift, 76, 3, 3, "473341")
	_box(x + facing * 7 + shift, 83, 5, 3 if biting else 1, "814b50")
	var hand_x := x + facing * 20
	var hand_y := 86 if biting else 96
	_box(hand_x - 7, hand_y + 3, 14, 5, shadow)
	_box(hand_x - 4, hand_y, 8, 6, "f1ba87")
	_bun(hand_x - 7, hand_y - 5, 15 - (bites[side] % 5) * 2)


func _bun(x: int, y: int, w: int) -> void:
	_box(x, y + 2, w, 5, "ad6644")
	_box(x + 1, y + 1, w - 2, 4, "e6a251")
	_box(x + 2, y, w - 4, 2, "f9cc71")
