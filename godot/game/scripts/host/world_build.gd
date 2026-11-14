extends RefCounted
## Furniture / shell world construction peeled out of demo.gd (tech-review F1).
## Instance bound to the day host; mutates host arrays and `_world`.

const Tuning = preload("res://scripts/tuning.gd")
const StateScript = preload("res://scripts/game_state.gd")
const RestockScript = preload("res://scripts/restock_point.gd")
const ShelfScript = preload("res://scripts/shelf.gd")
const CashierScript = preload("res://scripts/cashier.gd")
const ClerkScript = preload("res://scripts/clerk.gd")
const FloorTilesScript = preload("res://scripts/floor_tiles.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

var host: Node


func bind(day_host: Node) -> void:
	host = day_host

func facing(rot: int) -> Vector2:
	match posmod(rot, 4):
		1:
			return Vector2.RIGHT
		2:
			return Vector2.DOWN
		3:
			return Vector2.LEFT
		_:
			return Vector2.UP

func caption(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.z_index = 3
	UiFont.apply_label(l, UiFont.WORLD)
	l.add_theme_color_override("font_color", Color("fff4c2"))
	l.add_theme_color_override("font_outline_color", Color("121212"))
	l.add_theme_constant_override("outline_size", 5)
	host._world.add_child(l)
	return l

func solid(r: Rect2) -> void:
	host._obstacles.append(r)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	col.shape = shape
	body.add_child(col)
	host._world.add_child(body)

func fit_body(body: StaticBody2D, r: Rect2, model_id: String, rot: int, layer: int = 1) -> void:
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var spr := Vox.sprite(model_id, Vox.k_from_rot(rot))
	spr.name = "Body"
	Vox.fit(spr, r.size)
	body.add_child(spr)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	col.shape = shape
	body.add_child(col)

func run_wall(a: Vector2, b: Vector2, k: int) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 8.0:
		return
	var dir := delta / length
	var count := maxi(1, int(round(length / 64.0)))
	var each := length / float(count)
	for i in count:
		var spr := Vox.sprite("wall", k)
		spr.z_index = -5
		spr.position = a + dir * (each * (float(i) + 0.5))
		host._world.add_child(spr)

func build_floor() -> void:
	## One canvas item that draws tiled floor (avoids 100–400 Sprite2D nodes).
	var floor: Node2D = FloorTilesScript.new()
	floor.name = "Floor"
	floor.z_index = -8
	host._world.add_child(floor)
	floor.call("setup", host.FLOOR_ORIGIN, host.FLOOR_SIZE, StateScript.CELL)

func walls_and_door() -> void:
	var t := 18.0
	var o := host.FLOOR_ORIGIN
	var s := host.FLOOR_SIZE
	var door_w := 90.0
	var mid := o.x + s.x * 0.5
	solid(Rect2(o.x - t, o.y - t, mid - door_w * 0.5 - (o.x - t), t))
	solid(Rect2(mid + door_w * 0.5, o.y - t, (o.x + s.x + t) - (mid + door_w * 0.5), t))
	solid(Rect2(o.x - t, o.y + s.y, s.x + t * 2.0, t))
	solid(Rect2(o.x - t, o.y, t, s.y))
	solid(Rect2(o.x + s.x, o.y, t, s.y))
	var north_y := o.y - t * 0.5
	var south_y := o.y + s.y + t * 0.5
	var west_x := o.x - t * 0.5
	var east_x := o.x + s.x + t * 0.5
	run_wall(Vector2(o.x, north_y), Vector2(mid - door_w * 0.5, north_y), 0)
	run_wall(Vector2(mid + door_w * 0.5, north_y), Vector2(o.x + s.x, north_y), 0)
	run_wall(Vector2(o.x, south_y), Vector2(o.x + s.x, south_y), 2)
	run_wall(Vector2(west_x, o.y), Vector2(west_x, o.y + s.y), 1)
	run_wall(Vector2(east_x, o.y), Vector2(east_x, o.y + s.y), 3)
	var door := Vox.sprite("door", 0)
	door.z_index = -4
	door.position = Vector2(mid, north_y)
	host._world.add_child(door)
	caption(Vector2(mid - 28, o.y + 6), Loc.t("world.door"))

func restock(r: Rect2, cat: String, default_sku: String = "") -> Node2D:
	host._obstacles.append(r)
	var node: StaticBody2D = RestockScript.new()
	fit_body(node, r, "restock_" + cat, 0, 2)
	node.body = node.get_node("Body")
	node.label = caption(r.position + Vector2(4, 18), "")
	node.setup(cat)
	## Must be in-tree before apply_default_sku — skus() reads game host.state via the tree.
	host._world.add_child(node)
	node.apply_default_sku(default_sku)
	node.pull_stock()
	return node

func make_shelf(r: Rect2, cat: String, index: int, rot: int, cap: int = Tuning.SHELF_CAP) -> Node2D:
	host._obstacles.append(r)
	var node: StaticBody2D = ShelfScript.new()
	node.category = cat
	node.capacity = cap
	node.shelf_index = index
	node.net_shelf_id = host._next_net_shelf_id
	host._next_net_shelf_id += 1
	node.facing = facing(rot)
	fit_body(node, r, "shelf_" + cat, rot, 2)
	node.body = node.get_node("Body")
	var lab := Label.new()
	lab.position = Vector2(-58, -18)
	UiFont.apply_label(lab, UiFont.WORLD)
	lab.add_theme_color_override("font_color", Color("fff4c2"))
	lab.add_theme_color_override("font_outline_color", Color("121212"))
	lab.add_theme_constant_override("outline_size", 5)
	node.add_child(lab)
	node.label = lab
	host._world.add_child(node)
	node._refresh()
	register_shelf(node)
	return node

func make_cashier(r: Rect2, rot: int, index: int) -> Node2D:
	host._obstacles.append(r)
	var node: StaticBody2D = CashierScript.new()
	fit_body(node, r, "register", rot, 2)
	node.register_index = index
	node.set_facing(facing(rot))
	node.label = caption(r.position + Vector2(8, 4), "")
	host._world.add_child(node)
	host.cashiers.append(node)
	return node

func build_furniture(nodes: Array[Node2D]) -> void:
	var shelf_i := 1
	var reg_i := 0
	for it in host.state.placed:
		var cell := StateScript.CELL
		var r := Rect2(host.FLOOR_ORIGIN + Vector2(int(it["x"]), int(it["y"])) * cell, Vector2(int(it["w"]), int(it["h"])) * cell)
		var t := String(it["type"])
		var rot := int(it["rot"])
		if t.begins_with("restock"):
			var cat := Tuning.CAT_DRY
			if t.ends_with("frozen"):
				cat = Tuning.CAT_FROZEN
			elif t.ends_with("ice"):
				cat = Tuning.CAT_ICE
			nodes.append(restock(r, cat, String(it.get("default_sku", ""))))
		elif t.begins_with("shelf"):
			var cat := Tuning.CAT_DRY
			if t.contains("frozen"):
				cat = Tuning.CAT_FROZEN
			elif t.contains("ice"):
				cat = Tuning.CAT_ICE
			nodes.append(make_shelf(r, cat, shelf_i, rot, host.state.shelf_capacity(t)))
			shelf_i += 1
		elif t == "cashier":
			var node := make_cashier(r, rot, reg_i)
			nodes.append(node)
			reg_i += 1
	if not host.cashiers.is_empty():
		host.cashier = host.cashiers[0]

func spawn_clerks() -> void:
	var i := 0
	for c in host.state.clerks:
		var clerk: CharacterBody2D = ClerkScript.new()
		var reg: Node2D = null
		if String(c["role"]) == "cashier" and not host.cashiers.is_empty():
			reg = host.cashiers[mini(int(c["register"]), host.cashiers.size() - 1)]
		host._world.add_child(clerk)
		clerk.setup(host, host.FLOOR_ORIGIN + Vector2(80 + i * 36, host.FLOOR_SIZE.y - 120), String(c["role"]), reg)
		host._clerks.append(clerk)
		host._register_net_agent(clerk, "clerk", {
			"role": String(c["role"]),
		})
		i += 1

func index_shelf_sku(sku: String, shelf: Node) -> void:
	if sku == "" or shelf == null:
		return
	var list: Array = host._shelves_by_sku.get(sku, [])
	if not list.has(shelf):
		list.append(shelf)
	host._shelves_by_sku[sku] = list

func unindex_shelf_sku(sku: String, shelf: Node) -> void:
	if sku == "" or not host._shelves_by_sku.has(sku):
		return
	var list: Array = host._shelves_by_sku[sku]
	list.erase(shelf)
	if list.is_empty():
		host._shelves_by_sku.erase(sku)
	else:
		host._shelves_by_sku[sku] = list

func index_empty_shelf(shelf: Node) -> void:
	if shelf == null:
		return
	var cat := String(shelf.get("category"))
	var list: Array = host._empty_by_cat.get(cat, [])
	if not list.has(shelf):
		list.append(shelf)
	host._empty_by_cat[cat] = list

func unindex_empty_shelf(shelf: Node) -> void:
	if shelf == null:
		return
	var cat := String(shelf.get("category"))
	if not host._empty_by_cat.has(cat):
		return
	var list: Array = host._empty_by_cat[cat]
	list.erase(shelf)
	if list.is_empty():
		host._empty_by_cat.erase(cat)
	else:
		host._empty_by_cat[cat] = list

func on_shelf_stock_sku_changed(shelf: Node, old_sku: String, new_sku: String) -> void:
	if old_sku != "":
		unindex_shelf_sku(old_sku, shelf)
	if new_sku != "":
		index_shelf_sku(new_sku, shelf)
		unindex_empty_shelf(shelf)
	else:
		index_empty_shelf(shelf)

func register_shelf(node: Node2D) -> void:
	host.shelves.append(node)
	var nid := int(node.get("net_shelf_id")) if node.get("net_shelf_id") != null else -1
	if nid >= 0:
		host._shelves_by_net_id[nid] = node
	if node.has_signal("stock_sku_changed"):
		node.connect("stock_sku_changed", on_shelf_stock_sku_changed)
	if node.has_signal("stock_changed"):
		node.connect("stock_changed", host._on_shelf_stock_changed)
	var sku := ""
	if node.has_method("occupied_sku"):
		sku = String(node.call("occupied_sku"))
	elif int(node.get("count")) > 0:
		sku = String(node.get("sku"))
	if sku != "":
		index_shelf_sku(sku, node)
	else:
		index_empty_shelf(node)

