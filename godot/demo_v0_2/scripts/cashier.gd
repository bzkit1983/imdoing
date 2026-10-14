extends StaticBody2D

const Tuning = preload("res://scripts/tuning.gd")

var kind: String = "cashier"
var queue: Array = []
var label: Label
var front_offset := Vector2(0, -78)
var slot_gap := 34.0


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


func dequeue(customer) -> void:
	queue.erase(customer)


func slot_position(index: int) -> Vector2:
	return global_position + front_offset + Vector2(0, -slot_gap * float(index))


func back_position() -> Vector2:
	return global_position + Vector2(0, 48)


func _process(_delta: float) -> void:
	if label:
		var n: int = queue.size()
		label.text = "收銀機\n排隊 %d 人\n角色在後方長按 J" % n
