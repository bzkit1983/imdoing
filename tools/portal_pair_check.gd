extends Node
## Headless (#149): portal pair linking + busy lock + freed partner guard.


const PortalScript = preload("res://scripts/portal.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []

	var a: StaticBody2D = PortalScript.new()
	var b: StaticBody2D = PortalScript.new()
	var orphan: StaticBody2D = PortalScript.new()
	add_child(a)
	add_child(b)
	add_child(orphan)
	a.pair_id = "p1"
	b.pair_id = "p1"
	orphan.pair_id = "lonely"
	a.global_position = Vector2(0, 0)
	b.global_position = Vector2(200, 0)
	orphan.global_position = Vector2(400, 0)

	_link([a, b, orphan])
	_need(errors, a.is_paired() and b.is_paired(), "pair of two links")
	_need(errors, a.partner == b and b.partner == a, "partners reciprocal")
	_need(errors, not orphan.is_paired(), "singleton pair_id stays unpaired")
	_need(errors, a.can_use() and b.can_use(), "paired idle portals usable")

	_need(errors, a.try_begin_use(), "begin use locks both ends")
	_need(errors, not a.can_use() and not b.can_use(), "busy blocks can_use")
	_need(errors, not b.try_begin_use(), "second begin fails while busy")
	a.end_use()
	_need(errors, a.can_use() and b.can_use(), "end_use clears both busy flags")

	## Freed partner must not crash is_paired / can_use.
	var ghost: StaticBody2D = PortalScript.new()
	add_child(ghost)
	ghost.pair_id = "gone"
	a.pair_id = "gone"
	a.partner = ghost
	ghost.partner = a
	_need(errors, a.is_paired(), "paired before free")
	ghost.queue_free()
	await get_tree().process_frame
	_need(errors, not a.is_paired(), "freed partner → not paired")
	_need(errors, not a.can_use(), "freed partner → cannot use")
	_need(errors, not a.try_begin_use(), "freed partner → begin fails")

	if errors.is_empty():
		print("OK portal pair")
		get_tree().quit(0)
		return
	for e in errors:
		print("FAIL ", e)
	get_tree().quit(1)


func _link(portals: Array) -> void:
	var by_pair: Dictionary = {}
	for p in portals:
		if p == null or not is_instance_valid(p):
			continue
		var pid := String(p.get("pair_id"))
		if pid == "":
			p.partner = null
			continue
		if not by_pair.has(pid):
			by_pair[pid] = []
		(by_pair[pid] as Array).append(p)
	for pid in by_pair.keys():
		var group: Array = by_pair[pid]
		if group.size() == 2:
			group[0].partner = group[1]
			group[1].partner = group[0]
		else:
			for p in group:
				p.partner = null


func _need(errors: PackedStringArray, ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
