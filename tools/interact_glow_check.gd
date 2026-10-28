extends Node
## Headless: interact halo only while the aimed object can really be used.
## Launched as its own scene so project autoloads exist.

const PlayerScript = preload("res://scripts/player.gd")
const ShelfScript = preload("res://scripts/shelf.gd")
const CashierScript = preload("res://scripts/cashier.gd")
const RestockScript = preload("res://scripts/restock_point.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")


func _ready() -> void:
	print("interact glow check start")
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	var root := get_tree().root
	var host := Node.new()
	host.name = "Game"
	host.set_script(_host_script())
	host.add_to_group("game")
	root.add_child(host)
	var custs := Node2D.new()
	custs.name = "Customers"
	host.set("_customers", custs)
	host.add_child(custs)
	var state := RefCounted.new()
	state.set_script(_state_script())
	host.set("state", state)

	var player: CharacterBody2D = PlayerScript.new()
	player.game = host
	root.add_child(player)
	player.global_position = Vector2.ZERO
	player.facing = Vector2.RIGHT

	var shelf: StaticBody2D = ShelfScript.new()
	root.add_child(shelf)
	shelf.global_position = Vector2(72, 0)
	shelf.sku = "can"
	shelf.count = 4
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(128, 64)
	col.shape = rect
	shelf.add_child(col)
	_set_targets(player, [shelf])
	_aim(player)
	_need(errors, _has_glow(shelf), "stocked shelf in front glows")
	_need(errors, not _has_glow(player), "player does not wear the halo")
	var span: Vector2 = player._glow_span(shelf)
	_need(errors, is_equal_approx(span.x, 128.0 * 1.85 * player.GLOW_SPAN_SCALE), "shelf halo width %s" % span)
	_need(errors, is_equal_approx(span.y, 64.0 * 2.15 * player.GLOW_SPAN_SCALE), "shelf halo height %s" % span)
	_need(errors, span.x < 128.0 * 1.85 and span.y < 64.0 * 2.15, "halo is tighter than the first fit")

	player.facing = Vector2.UP
	_aim(player)
	_need(errors, not _has_glow(shelf), "looking away clears the halo")

	player.facing = Vector2.RIGHT
	host.set("phase", "prep")
	_aim(player)
	_need(errors, not _has_glow(shelf), "prep does not glow")
	host.set("phase", "open")

	shelf.count = 0
	shelf.sku = ""
	player.inventory.clear()
	_aim(player)
	_need(errors, not _has_glow(shelf), "empty shelf with empty hands does not glow")

	player.inventory.add_one("drink")
	_aim(player)
	_need(errors, not _has_glow(shelf), "wrong category does not glow")

	player.inventory.clear()
	player.inventory.add_one("can")
	_aim(player)
	_need(errors, _has_glow(shelf), "empty shelf accepts carried dry goods")

	player.skill_menu_open = true
	player._sync_interact_glow()
	_need(errors, not _has_glow(shelf), "skill menu hides the halo")
	player.skill_menu_open = false
	player._sync_interact_glow()
	_need(errors, _has_glow(shelf), "closing the skill menu restores the halo")

	player._cancel_drop_ready = true
	player._sync_interact_glow()
	_need(errors, not _has_glow(shelf), "drop aim hides the halo")
	player._cancel_drop_ready = false
	player.inventory.clear()

	var restock: StaticBody2D = RestockScript.new()
	root.add_child(restock)
	restock.global_position = Vector2(80, 0)
	_set_targets(player, [restock])
	_aim(player)
	_need(errors, _has_glow(restock), "restock point with a SKU list glows")
	_need(errors, not _has_glow(shelf), "previous shelf lost the halo")
	state.call("set_skus", [])
	_aim(player)
	_need(errors, not _has_glow(restock), "restock point with no SKUs does not glow")
	state.call("set_skus", ["can"])

	var cashier: StaticBody2D = CashierScript.new()
	root.add_child(cashier)
	cashier.global_position = Vector2(70, 0)
	_set_targets(player, [cashier])
	_aim(player)
	_need(errors, not _has_glow(cashier), "cashier with nobody waiting does not glow")
	var payer := Node2D.new()
	payer.set_script(_payer_script())
	cashier.enqueue(payer)
	_aim(player)
	_need(errors, _has_glow(cashier), "cashier with a guest at the counter glows")

	var thief := Node2D.new()
	thief.set_script(_thief_script())
	root.add_child(thief)
	thief.global_position = Vector2(60, 0)
	_set_targets(player, [thief, shelf])
	shelf.sku = "can"
	shelf.count = 4
	player.inventory.add_one("can")
	_aim(player)
	_need(errors, not _has_glow(thief), "thief does not glow while hands are full")
	_need(errors, not _has_glow(shelf), "full-hands thief still blocks the shelf halo")
	player.inventory.clear()
	_aim(player)
	_need(errors, _has_glow(thief), "empty-hands thief glows")
	_need(errors, not _has_glow(shelf), "thief wins over a stocked shelf")

	_set_targets(player, [])
	var guest := Node2D.new()
	guest.set_script(_guest_script())
	custs.add_child(guest)
	guest.global_position = Vector2(68, 0)
	player.inventory.add_one("can")
	_aim(player)
	_need(errors, _has_glow(guest), "guest who can take goods glows")
	host.set("phase", "restock")
	_aim(player)
	_need(errors, not _has_glow(guest), "restock hour does not glow a guest")
	host.set("phase", "open")
	guest.set("_ok", false)
	_aim(player)
	_need(errors, not _has_glow(guest), "guest who cannot receive does not glow")

	var drop := Node2D.new()
	drop.set_script(_drop_script())
	root.add_child(drop)
	drop.global_position = Vector2(64, 0)
	_set_targets(player, [drop])
	player.inventory.clear()
	_aim(player)
	_need(errors, _has_glow(drop), "floor box that fits glows")
	for _i in player.carry_cap():
		player.inventory.add_one("can")
	_aim(player)
	_need(errors, not _has_glow(drop), "floor box does not glow when carry is full")

	var shot := OS.get_environment("GLOW_SHOT")
	if shot != "" and errors.is_empty():
		if shelf.get_node_or_null("Body") == null:
			var body := Vox.sprite("shelf_dry", 0)
			body.name = "Body"
			shelf.add_child(body)
		shelf.global_position = Vector2(640, 360)
		player.global_position = Vector2(540, 360)
		player.facing = Vector2.RIGHT
		player.inventory.clear()
		host.set("phase", "open")
		player.skill_menu_open = false
		player._cancel_drop_ready = false
		shelf.sku = "can"
		shelf.count = 4
		_set_targets(player, [shelf])
		_aim(player)
		await _shot(shot)
		player.facing = Vector2.UP
		_aim(player)
		var off := shot.get_basename() + "_off.png"
		await _shot(off)
	if errors.is_empty():
		print("OK interact glow")
		get_tree().quit(0)
		return
	print("FAIL interact glow")
	for err in errors:
		print(" ", err)
	get_tree().quit(1)


func _set_targets(player: Node, nodes: Array) -> void:
	var typed: Array[Node2D] = []
	for node in nodes:
		typed.append(node)
	player.interactables = typed


func _shot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)


func _aim(player: Node) -> void:
	player._update_target()
	player._sync_interact_glow()


func _has_glow(node: Node) -> bool:
	return node.get_node_or_null("InteractGlow") != null


func _need(errors: PackedStringArray, ok: bool, msg: String) -> void:
	if not ok:
		errors.append(msg)


func _host_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = "extends Node\nvar phase: String = \"open\"\nvar _customers: Node2D\nvar state\nfunc asking_early_close() -> bool:\n\treturn false\n"
	scr.reload()
	return scr


func _state_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = "extends RefCounted\nvar _skus: Array[String] = [\"can\"]\nfunc developed_of(_cat: String) -> Array[String]:\n\treturn _skus\nfunc set_skus(ids: Array) -> void:\n\t_skus.clear()\n\tfor id in ids:\n\t\t_skus.append(String(id))\n"
	scr.reload()
	return scr


func _payer_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = "extends Node2D\nfunc is_at_register() -> bool:\n\treturn true\nfunc cancel_pay() -> void:\n\tpass\n"
	scr.reload()
	return scr


func _thief_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = "extends Node2D\nvar kind: String = \"thief\"\nfunc is_active_thief() -> bool:\n\treturn true\n"
	scr.reload()
	return scr


func _guest_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = "extends Node2D\nvar kind: String = \"\"\nvar _ok: bool = true\nfunc can_receive_delivery() -> bool:\n\treturn _ok\n"
	scr.reload()
	return scr


func _drop_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = "extends Node2D\nvar kind: String = \"drop\"\nvar sku: String = \"can\"\nvar count: int = 4\n"
	scr.reload()
	return scr
