extends Node3D
## Instances kit meshes for every BowlMap cell via PresentationCatalog.
## The map is the source of truth; the catalog is the only mesh table.

## Cell → piece id last drawn (empty string = magenta marker).
var pieces: Dictionary = {}
## Highest visible level (inclusive). Floors above this are hidden.
var cutaway_z: int = 99

var _nodes_by_level: Dictionary = {} ## int → Array[Node3D]


func draw_map(map: BowlMap) -> void:
	_clear()
	pieces.clear()
	_nodes_by_level.clear()
	var max_z := 0
	for coord in map.cells.keys():
		max_z = maxi(max_z, coord.z)
		var choice: Dictionary = PresentationCatalog.piece_for_cell(map, coord)
		var piece_id: String = choice.get("id", "")
		var yaw: float = choice.get("yaw", 0.0)
		pieces[coord] = piece_id
		var origin := PresentationCoords.world(coord)
		var n: Node3D
		if piece_id.is_empty():
			n = _missing_marker(origin, "X_%s" % coord)
		else:
			var packed := PresentationCatalog.scene_for_piece(piece_id)
			if packed == null:
				push_warning("bowl_draw: missing scene for %s at %s" % [piece_id, coord])
				n = _missing_marker(origin, "X_%s" % coord)
			else:
				n = packed.instantiate() as Node3D
				n.name = "%s_%s" % [piece_id, coord]
				n.position = origin
				n.rotation_degrees.y = yaw
				n.set_meta("polder_piece", piece_id)
				add_child(n)
		n.set_meta("polder_z", coord.z)
		if not _nodes_by_level.has(coord.z):
			_nodes_by_level[coord.z] = []
		_nodes_by_level[coord.z].append(n)
	cutaway_z = max_z
	apply_cutaway()


func set_cutaway_z(level: int) -> void:
	cutaway_z = level
	apply_cutaway()


func apply_cutaway() -> void:
	for z in _nodes_by_level.keys():
		var show := int(z) <= cutaway_z
		for n in _nodes_by_level[z]:
			(n as Node3D).visible = show


## CoverMaterial the catalog tagged on the mesh at this cell, or -1 if none / missing.
func cover_tag_at(coord: Vector3i) -> int:
	if not pieces.has(coord):
		return -1
	var piece_id: String = pieces[coord]
	if piece_id.is_empty():
		return -1
	return PresentationCatalog.cover_of(piece_id)


func _missing_marker(origin: Vector3, node_name: String) -> MeshInstance3D:
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
	return mi


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_nodes_by_level.clear()
