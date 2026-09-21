extends Node3D
## Known-quiet ageing veil. Unknown draws nothing; Live is staleness 0 (shader discards).
## Loads PresentationCatalog.FOG_MAT — the unplugged half of the fog data model (plan 04 §4.4).

var reduced_motion: bool = false


func redraw(map: BowlMap, state: CombatState) -> void:
	for c in get_children():
		c.queue_free()
	if map == null or state == null or state.knowledge == null:
		return
	var mat_src := load(PresentationCatalog.FOG_MAT) as ShaderMaterial
	if mat_src == null:
		push_warning("fog_view: missing %s" % PresentationCatalog.FOG_MAT)
		return
	for coord in map.cells.keys():
		var cell: Vector3i = coord
		if state.knowledge.squad_sight(state, cell) != Knowledge.CellSight.KNOWN_QUIET:
			continue
		var stale := state.knowledge.staleness_of(state, cell)
		if stale <= 0.001:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Fog_%s" % cell
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(PresentationCoords.CELL_M, PresentationCoords.CELL_M)
		mi.mesh = mesh
		var mat := mat_src.duplicate() as ShaderMaterial
		mat.set_shader_parameter("staleness", stale)
		mat.set_shader_parameter("reduced_motion", reduced_motion)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		## Sit just above the slab so the veil reads on Known-quiet terrain.
		mi.position = PresentationCoords.world_ground(cell) + Vector3(0.0, 0.05, 0.0)
		add_child(mi)
