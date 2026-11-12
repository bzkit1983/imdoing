extends Node
## Headless: canvas outline API defaults OFF; toggle attaches shader.


const Vox = preload("res://scripts/voxel_sprite.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	## Force off first (compile default or VOXEL_CANVAS_OUTLINE may be on during QA).
	Vox.set_canvas_outline_enabled(false)
	if Vox.is_canvas_outline_enabled():
		errors.append("outline should be OFF after set_canvas_outline_enabled(false)")
	var spr: Sprite2D = Vox.sprite("player", 0)
	if spr.material != null:
		errors.append("sprite with outline OFF must not carry outline material")
	Vox.set_canvas_outline_enabled(true)
	if not Vox.is_canvas_outline_enabled():
		errors.append("set_canvas_outline_enabled(true) failed")
	Vox.apply_canvas_outline(spr)
	if spr.material == null or not (spr.material is ShaderMaterial):
		errors.append("apply_canvas_outline did not attach ShaderMaterial")
	else:
		var sm := spr.material as ShaderMaterial
		if sm.shader == null or not String(sm.shader.resource_path).ends_with("sprite_outline.gdshader"):
			errors.append("unexpected shader path")
	var spr2: Sprite2D = Vox.sprite("shelf_dry", 0)
	if spr2.material == null:
		errors.append("new sprite after enable should auto-attach")
	## Skin tint still assignable with outline material present.
	spr.modulate = Color(1.15, 0.85, 0.85, 1.0)
	if spr.modulate != Color(1.15, 0.85, 0.85, 1.0):
		errors.append("modulate tint blocked by outline material")
	Vox.set_canvas_outline_enabled(false)
	Vox.apply_canvas_outline(spr)
	if spr.material != null:
		errors.append("disable should clear outline material")
	spr.queue_free()
	spr2.queue_free()
	if errors.is_empty():
		print("OK voxel canvas outline")
		get_tree().quit(0)
	else:
		for e in errors:
			push_error(e)
			print("FAIL ", e)
		get_tree().quit(1)
