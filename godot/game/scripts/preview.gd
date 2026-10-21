extends Node3D
## Lays out every blockout in art/catalog.json. Drag to turn, scroll to zoom.

const Vox = preload("res://scripts/vox_mesh.gd")

var _focus := Vector3.ZERO
var _yaw := 0.7
var _pitch := 0.42
var _dist := 14.0
var _drag := false


func _ready() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://art/catalog.json"))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang TC", "PingFang HK", "Hiragino Sans CNS", "Noto Sans CJK TC"])
	var cursor_x := 0.0
	var cursor_z := 0.0
	var min_x := 0.0
	var max_x := 0.0
	var min_z := 0.0
	var count := 0
	for group in catalog["groups"]:
		cursor_x = 0.0
		var row_depth := 0.0
		for spec in group["models"]:
			var mesh := Vox.load_mesh("res://art/src/%s" % String(spec["file"]))
			var body := MeshInstance3D.new()
			body.mesh = mesh
			body.position = Vector3(cursor_x, 0.0, cursor_z)
			body.name = String(spec["id"])
			add_child(body)
			var bounds := mesh.get_aabb()
			var label := Label3D.new()
			label.text = String(spec["name"])
			label.font = font
			label.font_size = 48
			label.pixel_size = 0.0035
			label.modulate = Color("f4f1ea")
			label.outline_modulate = Color("121212")
			label.outline_size = 8
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = body.position + Vector3(bounds.size.x * 0.5, bounds.size.y + 0.2, -bounds.size.z * 0.5)
			add_child(label)
			cursor_x += bounds.size.x + 0.7
			row_depth = maxf(row_depth, bounds.size.z)
			max_x = maxf(max_x, body.position.x + bounds.size.x)
			min_z = minf(min_z, body.position.z - bounds.size.z)
			count += 1
		cursor_z -= row_depth + 1.4
	_focus = Vector3(max_x * 0.5, 0.6, min_z * 0.5)
	_dist = maxf(max_x, -min_z) * 0.85
	_add_stage(min_x, max_x, min_z, cursor_z)
	_add_camera()
	print("ALPHA_VOX %d" % count)


func _add_stage(min_x: float, max_x: float, min_z: float, max_span_z: float) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141c18")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8d4c5")
	env.ambient_light_energy = 0.65
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -36, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(maxf(4.0, max_x - min_x + 6.0), maxf(4.0, absf(max_span_z - min_z) + 6.0))
	var floor_body := MeshInstance3D.new()
	floor_body.mesh = floor_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("1c241f")
	floor_body.material_override = mat
	floor_body.position = Vector3((min_x + max_x) * 0.5, -0.01, (min_z + max_span_z) * 0.5)
	add_child(floor_body)


func _add_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	add_child(cam)
	_place_camera()


func _process(_delta: float) -> void:
	_place_camera()


func _place_camera() -> void:
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var offset := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _dist
	cam.position = _focus + offset
	cam.look_at(_focus)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_drag = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(2.0, _dist * 0.9)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(80.0, _dist * 1.1)
	elif event is InputEventMouseMotion and _drag:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.01
		_pitch = clampf(_pitch - motion.relative.y * 0.01, -0.15, 1.15)
