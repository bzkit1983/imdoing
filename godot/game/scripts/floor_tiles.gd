extends Node2D
## Draws a tiled floor in one canvas item (no per-cell Sprite2D).

const Vox = preload("res://scripts/voxel_sprite.gd")
## Fallback when anchors.json lacks floor_tile_0 (legacy bake).
const _FALLBACK_AX := 32.0
const _FALLBACK_AY := 36.0

var _origin := Vector2.ZERO
var _size := Vector2.ZERO
var _step := 64.0
var _tex: Texture2D
var _tile_ax := _FALLBACK_AX
var _tile_ay := _FALLBACK_AY


func setup(origin: Vector2, size: Vector2, step: float, floor_id: String = "floor_tile") -> void:
	_origin = origin
	_size = size
	_step = maxf(1.0, step)
	var id := floor_id if floor_id != "" else "floor_tile"
	_tex = Vox.texture(id, 0)
	if _tex == null and id != "floor_tile":
		id = "floor_tile"
		_tex = Vox.texture(id, 0)
	var info := Vox.anchor_info(id, 0)
	_tile_ax = float(info.get("ax", _FALLBACK_AX))
	_tile_ay = float(info.get("ay", _FALLBACK_AY))
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var x := 0.0
	while x < _size.x - 0.5:
		var y := 0.0
		while y < _size.y - 0.5:
			## Same placement as old Sprite2D at cell center with centered=false + offset.
			var cell_center := _origin + Vector2(x + _step * 0.5, y + _step * 0.5)
			draw_texture(_tex, cell_center - Vector2(_tile_ax, _tile_ay))
			y += _step
		x += _step
