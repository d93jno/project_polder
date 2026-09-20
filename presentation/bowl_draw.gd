extends Node3D
## Instances kit meshes for every BowlMap cell via PresentationCatalog.
## The map is the source of truth; the catalog is the only mesh table.

## Cell → piece id last drawn (empty string = magenta marker).
var pieces: Dictionary = {}


func draw_map(map: BowlMap) -> void:
	_clear()
	pieces.clear()
	for coord in map.cells.keys():
		var choice: Dictionary = PresentationCatalog.piece_for_cell(map, coord)
		var piece_id: String = choice.get("id", "")
		var yaw: float = choice.get("yaw", 0.0)
		pieces[coord] = piece_id
		var origin := PresentationCoords.world(coord)
		if piece_id.is_empty():
			_missing_marker(origin, "X_%s" % coord)
			continue
		var packed := PresentationCatalog.scene_for_piece(piece_id)
		if packed == null:
			push_warning("bowl_draw: missing scene for %s at %s" % [piece_id, coord])
			_missing_marker(origin, "X_%s" % coord)
			continue
		var n := packed.instantiate() as Node3D
		n.name = "%s_%s" % [piece_id, coord]
		n.position = origin
		n.rotation_degrees.y = yaw
		n.set_meta("polder_piece", piece_id)
		add_child(n)


## CoverMaterial the catalog tagged on the mesh at this cell, or -1 if none / missing.
func cover_tag_at(coord: Vector3i) -> int:
	if not pieces.has(coord):
		return -1
	var piece_id: String = pieces[coord]
	if piece_id.is_empty():
		return -1
	return PresentationCatalog.cover_of(piece_id)


func _missing_marker(origin: Vector3, node_name: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 1.2, 0.6)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = origin + Vector3(0.0, 0.6, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _clear() -> void:
	for c in get_children():
		c.queue_free()
