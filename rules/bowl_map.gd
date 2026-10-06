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


## GDD 5.8: water stands at a level, `water_z`. A cell is wet when its floor is at or below that
## level and it is not a deck. Everything above is dry ground, whatever the step: a roof, an upstairs
## floor, and the deck of a floating dock, which rides the water on its guide piles.
func is_wet(coord: Vector3i) -> bool:
	if coord.z > water_z:
		return false
	var cell: Cell = get_cell(coord)
	return cell == null or not cell.has_flag(Taxonomy.CellFlags.DECK)


## GDD 5.3: a vertical step needs a connector. It is legal between two vertically adjacent cells
## when either carries the LINK flag; a step on the same level needs no link.
func can_step(from_cell: Vector3i, to_cell: Vector3i) -> bool:
	if from_cell.z == to_cell.z:
		return true
	if from_cell.x != to_cell.x or from_cell.y != to_cell.y:
		return false
	for coord in [from_cell, to_cell]:
		var cell: Cell = get_cell(coord)
		if cell != null and cell.has_flag(Taxonomy.CellFlags.LINK):
			return true
	return false


## The step that governs this cell. The step's move cost, its hiding and the Dry clause of break
## are read through here, so they apply to wet cells alone; dry ground is Dry (GDD 5.8).
func step_at(coord: Vector3i) -> Taxonomy.WaterStep:
	return water_step if is_wet(coord) else Taxonomy.WaterStep.DRY


func remove_cell(coord: Vector3i) -> void:
	cells.erase(coord)


func cell_count() -> int:
	return cells.size()
