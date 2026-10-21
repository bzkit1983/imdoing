extends RefCounted
## Reads a MagicaVoxel .vox (version 150, one model) into a mesh.
## Vox X right, Y forward, Z up becomes Godot X right, Y up, Z toward the camera when the model faces +Y.

const VOXEL_METERS := 0.1

const _FACE_SHADE := {
	"px": 0.82,
	"nx": 0.7,
	"py": 1.0,
	"ny": 0.55,
	"pz": 0.76,
	"nz": 0.64,
}


static func load_mesh(path: String) -> ArrayMesh:
	var data := FileAccess.get_file_as_bytes(path)
	if data.is_empty() or data.slice(0, 4).get_string_from_ascii() != "VOX ":
		push_error("打不開 Voxel 檔：%s" % path)
		return ArrayMesh.new()
	var cursor := 8
	var main := _chunk(data, cursor)
	cursor = main["content"] + int(main["content_size"])
	var end := cursor + int(main["children"])
	var voxels: Array[Vector4i] = []
	var palette := PackedColorArray()
	palette.resize(256)
	while cursor < end:
		var chunk: Dictionary = _chunk(data, cursor)
		var tag := String(chunk["tag"])
		var at := int(chunk["content"])
		if tag == "XYZI":
			var count := data.decode_s32(at)
			for i in count:
				var p := at + 4 + i * 4
				voxels.append(Vector4i(data[p], data[p + 1], data[p + 2], data[p + 3]))
		elif tag == "RGBA":
			for i in 256:
				var p := at + i * 4
				palette[i] = Color8(data[p], data[p + 1], data[p + 2], 255)
		cursor = at + int(chunk["content_size"]) + int(chunk["children"])
	return _build(voxels, palette)


static func _chunk(data: PackedByteArray, pos: int) -> Dictionary:
	return {
		"tag": data.slice(pos, pos + 4).get_string_from_ascii(),
		"content_size": data.decode_s32(pos + 4),
		"children": data.decode_s32(pos + 8),
		"content": pos + 12,
	}


static func _build(voxels: Array[Vector4i], palette: PackedColorArray) -> ArrayMesh:
	var filled := {}
	for voxel in voxels:
		filled[Vector3i(voxel.x, voxel.y, voxel.z)] = voxel.w
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := VOXEL_METERS
	for cell in filled:
		var index := int(filled[cell])
		if index <= 0:
			continue
		var color: Color = palette[index - 1]
		var origin := Vector3(cell.x, cell.z, -(cell.y + 1)) * s
		if not filled.has(cell + Vector3i(1, 0, 0)):
			_quad(st, origin, s, color * _FACE_SHADE["px"], Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0))
		if not filled.has(cell + Vector3i(-1, 0, 0)):
			_quad(st, origin, s, color * _FACE_SHADE["nx"], Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1))
		if not filled.has(cell + Vector3i(0, 0, 1)):
			_quad(st, origin, s, color * _FACE_SHADE["py"], Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0))
		if not filled.has(cell + Vector3i(0, 0, -1)):
			_quad(st, origin, s, color * _FACE_SHADE["ny"], Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1))
		if not filled.has(cell + Vector3i(0, -1, 0)):
			_quad(st, origin, s, color * _FACE_SHADE["pz"], Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1))
		if not filled.has(cell + Vector3i(0, 1, 0)):
			_quad(st, origin, s, color * _FACE_SHADE["nz"], Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	st.set_material(mat)
	return st.commit()


static func _quad(st: SurfaceTool, origin: Vector3, scale: float, color: Color, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var verts: Array[Vector3] = [a, b, c, a, c, d]
	for corner in verts:
		st.set_color(color)
		st.add_vertex(origin + corner * scale)
