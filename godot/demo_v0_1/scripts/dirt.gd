extends Area2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node2D) -> void:
	if body.has_method("add_dirt"):
		body.add_dirt(1)


func _on_exit(body: Node2D) -> void:
	if body.has_method("add_dirt"):
		body.add_dirt(-1)
