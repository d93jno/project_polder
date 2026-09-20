extends Node3D
## Instances kit meshes for every BowlMap cell. The map is the source of truth.

const _SLABS := [
	"res://assets/env/kits/terrace/env_street_slab_a.glb",
	"res://assets/env/kits/terrace/env_street_slab_b.glb",
	"res://assets/env/kits/terrace/env_street_slab_c.glb",
]


func draw_map(map: BowlMap) -> void:
	_clear()
	for coord in map.cells.keys():
		var cell: Cell = map.cells[coord]
		var origin := PresentationCoords.world(coord)
		match cell.material:
			Taxonomy.CoverMaterial.MASONRY:
				_inst("res://assets/props/prop_cover_masonry_corner.glb", origin, "M_%s" % coord)
			Taxonomy.CoverMaterial.PLANK:
				_inst("res://assets/props/prop_plank_wood.glb", origin, "P_%s" % coord)
			Taxonomy.CoverMaterial.CRATE:
				_inst("res://assets/props/prop_crate_wood.glb", origin, "C_%s" % coord)
			Taxonomy.CoverMaterial.METAL:
				_inst("res://assets/env/kits/terrace/env_shanty_water_tank.glb", origin, "T_%s" % coord)
			_:
				var slab: String = _SLABS[absi(coord.x + coord.y * 3) % _SLABS.size()]
				_inst(slab, origin, "S_%s" % coord)


func _inst(path: String, origin: Vector3, node_name: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var n := packed.instantiate() as Node3D
	n.name = node_name
	n.position = origin
	add_child(n)


func _clear() -> void:
	for c in get_children():
		c.queue_free()
