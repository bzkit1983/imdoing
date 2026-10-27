extends StaticBody2D
## Floor shelf. Emits stock_sku_changed when occupied SKU identity changes
## (empty↔stocked) so the game host can keep an O(1) SKU→shelf index.

const Tuning = preload("res://scripts/tuning.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")

## old_sku / new_sku are "" when the shelf is empty.
signal stock_sku_changed(shelf: Node, old_sku: String, new_sku: String)

var kind: String = "shelf"
var category: String = Tuning.CAT_DRY
var sku: String = ""
var count: int = 0
var capacity: int = Tuning.SHELF_CAP
var shelf_index: int = 1
var label: Label
var body: CanvasItem
var _goods: Sprite2D
var facing: Vector2 = Vector2.UP
var _fill_level: int = -1


func can_accept(item_sku: String) -> bool:
	if Tuning.category_of(item_sku) != category:
		return false
	if count >= capacity:
		return false
	return sku == "" or sku == item_sku


func occupied_sku() -> String:
	return sku if count > 0 and sku != "" else ""


func add_items(item_sku: String, n: int) -> int:
	if not can_accept(item_sku):
		return 0
	var old_sku := occupied_sku()
	var space := capacity - count
	var placed := mini(n, space)
	sku = item_sku
	count += placed
	_refresh()
	_emit_sku_change(old_sku)
	return placed


func take_all() -> Array[String]:
	var out: Array[String] = []
	if sku == "" or count <= 0:
		return out
	var old_sku := occupied_sku()
	for _i in count:
		out.append(sku)
	sku = ""
	count = 0
	_refresh()
	_emit_sku_change(old_sku)
	return out


func take_one(want: String) -> bool:
	if not has_sku(want):
		return false
	var old_sku := occupied_sku()
	count -= 1
	if count <= 0:
		sku = ""
		count = 0
	_refresh()
	_emit_sku_change(old_sku)
	return true


## Remove up to `n` of the occupied SKU (any). Returns how many were taken.
func take_n(n: int) -> int:
	if sku == "" or count <= 0 or n <= 0:
		return 0
	var old_sku := occupied_sku()
	var taken := mini(n, count)
	count -= taken
	if count <= 0:
		sku = ""
		count = 0
	_refresh()
	_emit_sku_change(old_sku)
	return taken


## Drop a fraction of current stock (LV6 / frac≥1 → all). Returns {sku, n}.
func smash_fraction(frac: float) -> Dictionary:
	if sku == "" or count <= 0:
		return {}
	var n: int
	if frac >= 0.999:
		n = count
	else:
		n = int(floor(float(count) * frac))
		if count >= 1:
			n = maxi(1, n)
		n = mini(n, count)
	if n <= 0:
		return {}
	var item := sku
	var taken := take_n(n)
	if taken <= 0:
		return {}
	return {"sku": item, "n": taken}


func has_sku(want: String) -> bool:
	return sku == want and count > 0


func _emit_sku_change(old_sku: String) -> void:
	var new_sku := occupied_sku()
	if old_sku == new_sku:
		return
	stock_sku_changed.emit(self, old_sku, new_sku)


func stand_position() -> Vector2:
	return global_position + facing * 58.0


func fill_level() -> int:
	## 0 empty · 1 low · 2 mid · 3 full (Alpha shelf fill_* art).
	if count <= 0 or capacity <= 0:
		return 0
	var ratio := float(count) / float(capacity)
	if ratio < 0.34:
		return 1
	if ratio < 0.67:
		return 2
	return 3


func _shelf_model_base() -> String:
	if category == Tuning.CAT_FROZEN:
		return "shelf_frozen"
	if category == Tuning.CAT_ICE:
		return "shelf_ice"
	return "shelf_dry"


func _refresh() -> void:
	var level := fill_level()
	if body is Sprite2D and level != _fill_level:
		_fill_level = level
		var k := Vox.k_from_facing(facing)
		var fill_id := "%s_fill_%d" % [_shelf_model_base(), level]
		var path := "res://art/sprites/%s_%d.png" % [fill_id, k]
		if ResourceLoader.exists(path):
			Vox.apply(body as Sprite2D, fill_id, k)
		else:
			Vox.apply(body as Sprite2D, _shelf_model_base(), k)
	if _goods == null:
		_goods = Sprite2D.new()
		_goods.centered = true
		_goods.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_goods.z_index = 1
		add_child(_goods)
	if sku == "":
		_goods.visible = false
	else:
		_goods.visible = true
		_goods.texture = SkuIcons.texture(sku)
		## ~30px logical icon on shelf face.
		var s := 30.0 / float(SkuIcons.SIZE)
		_goods.scale = Vector2(s, s)
		_goods.position = facing * -8.0 + Vector2(0, -34)
	var kind_name := "乾貨架"
	if category == Tuning.CAT_FROZEN:
		kind_name = "凍櫃貨架"
	elif category == Tuning.CAT_ICE:
		kind_name = "冰櫃貨架"
	if label:
		## Name dropped — icon carries SKU identity; keep index + fill.
		if sku == "":
			label.text = "%s %d\n空　%d" % [kind_name, shelf_index, capacity]
		else:
			label.text = "%s %d\n%d/%d" % [kind_name, shelf_index, count, capacity]
