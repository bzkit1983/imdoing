extends StaticBody2D

const Tuning = preload("res://scripts/tuning.gd")

var kind: String = "cashier"
var queue: Array = []
var label: Label
var front_offset := Vector2(0, -78)
var slot_gap := 34.0
var facing := Vector2.UP
var register_index: int = 0
var _label_n: int = -1


func set_facing(dir: Vector2) -> void:
	facing = dir.normalized() if dir.length_squared() > 0.01 else Vector2.UP
	front_offset = facing * 78.0


func front_customer():
	if queue.is_empty():
		return null
	return queue[0]


func ready_customer():
	var cust = front_customer()
	if cust == null:
		return null
	if cust.has_method("is_at_register") and bool(cust.call("is_at_register")):
		return cust
	return null


func enqueue(customer) -> void:
	if customer in queue:
		return
	queue.append(customer)
	_refresh_label()


func dequeue(customer) -> void:
	queue.erase(customer)
	_refresh_label()


func queue_index_of(customer) -> int:
	return int(queue.find(customer))


func slot_position(index: int) -> Vector2:
	return global_position + front_offset + facing * slot_gap * float(index)


func back_position() -> Vector2:
	return global_position - facing * 52.0


func _refresh_label() -> void:
	if label == null:
		return
	var n: int = queue.size()
	if n == _label_n:
		return
	_label_n = n
	label.text = "收銀機 %d\n排隊 %d 人\n後方長按 行動" % [register_index + 1, n]
