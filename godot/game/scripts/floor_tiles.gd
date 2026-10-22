extends Node2D
## Draws a tiled floor in one canvas item (no per-cell Sprite2D).

const Vox = preload("res://scripts/voxel_sprite.gd")
## Matches art/sprites/anchors.json floor_tile_0 (ax/ay).
const TILE_AX := 32.0
const TILE_AY := 36.0

var _origin := Vector2.ZERO
var _size := Vector2.ZERO
var _step := 64.0
var _tex: Texture2D


func setup(origin: Vector2, size: Vector2, step: float) -> void:
	_origin = origin
	_size = size
	_step = maxf(1.0, step)
	_tex = Vox.texture("floor_tile", 0)
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
			draw_texture(_tex, cell_center - Vector2(TILE_AX, TILE_AY))
			y += _step
		x += _step
