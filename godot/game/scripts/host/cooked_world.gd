extends RefCounted
## Cooked-stall world helpers peeled from demo.gd (theme_historic guest queue).

var host: Node


func bind(day_host: Node) -> void:
	host = day_host


## Prefer a stall with face stock for `sku`, else nearest placed cooked_stall.
func find_cooked_stall(sku: String, from: Vector2 = Vector2.ZERO) -> Node2D:
	var best_stocked: Node2D = null
	var best_stocked_d := 1.0e12
	var best_any: Node2D = null
	var best_any_d := 1.0e12
	var origin := from
	if origin == Vector2.ZERO and host.get("_player") != null and is_instance_valid(host._player):
		origin = host._player.global_position
	var stalls: Array = host.cooked_stalls if host.get("cooked_stalls") != null else []
	for stall in stalls:
		if stall == null or not is_instance_valid(stall):
			continue
		var d := origin.distance_squared_to(stall.global_position)
		if d < best_any_d:
			best_any_d = d
			best_any = stall
		if stall_has(stall, sku) and d < best_stocked_d:
			best_stocked_d = d
			best_stocked = stall
	return best_stocked if best_stocked != null else best_any


func stall_has(stall: Node2D, sku: String) -> bool:
	if stall == null or not is_instance_valid(stall):
		return false
	if stall.has_method("face_count_of"):
		return int(stall.call("face_count_of", sku)) > 0
	return false
