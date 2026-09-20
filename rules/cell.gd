class_name Cell
extends Resource
## One sparse-grid cell. CoverMaterial is what stops a line; flags are tile properties.

@export var material: Taxonomy.CoverMaterial = Taxonomy.CoverMaterial.AIR
@export var flags: int = 0
## Unit id occupying this cell, or -1 for none.
@export var occupant: int = -1


func _init(
	p_material: Taxonomy.CoverMaterial = Taxonomy.CoverMaterial.AIR,
	p_flags: int = 0,
	p_occupant: int = -1,
) -> void:
	material = p_material
	flags = p_flags
	occupant = p_occupant


func has_flag(flag: int) -> bool:
	return (flags & flag) != 0


func duplicate_cell() -> Cell:
	return Cell.new(material, flags, occupant)


func equals(other: Cell) -> bool:
	if other == null:
		return false
	return (
		material == other.material
		and flags == other.flags
		and occupant == other.occupant
	)
