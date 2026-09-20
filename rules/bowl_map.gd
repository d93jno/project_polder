class_name BowlMap
extends Resource
## Sparse 3D fight grid. A cell's z is its level (UI §17).
##
## TODO(levee): UI §3 allows two water surfaces on one map (one per bowl across a
## levee). This type currently carries a single water_step / water_z plane.
## Promote to a per-region list before Act II levee maps ship — do not discover
## this in phase 4. See tests/unit/test_bowl_map.gd::test_levee_two_surfaces_not_yet_supported.

@export var cells: Dictionary = {} ## Vector3i -> Cell
@export var water_step: Taxonomy.WaterStep = Taxonomy.WaterStep.DRY
@export var water_z: int = 0


func set_cell(coord: Vector3i, cell: Cell) -> void:
	cells[coord] = cell


func get_cell(coord: Vector3i) -> Cell:
	return cells.get(coord) as Cell


func has_cell(coord: Vector3i) -> bool:
	return cells.has(coord)


func remove_cell(coord: Vector3i) -> void:
	cells.erase(coord)


func cell_count() -> int:
	return cells.size()
