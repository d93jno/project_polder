class_name CutawayBowl
extends Object
## Small street + roof deck for cutaway / water / Falling NO_HIDE (plan 2.2).
## Not the scripted fight. 2.6 restores the shared fight opening.

const ROOF := Vector3i(3, 1, 1)
const STREET := Vector3i(1, 1, 0)


static func map(step: Taxonomy.WaterStep = Taxonomy.WaterStep.FLOODED, water_z: int = 1) -> BowlMap:
	var map := BowlMap.new()
	map.water_step = step
	map.water_z = water_z
	for x in range(0, 8):
		for y in range(0, 4):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	## One roof deck above the street — cutaway and roof pick target.
	map.set_cell(ROOF, Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	map.set_cell(Vector3i(4, 1, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	return map


static func opening(step: Taxonomy.WaterStep = Taxonomy.WaterStep.FLOODED) -> CombatState:
	var state := CombatState.new()
	state.map = map(step, 1 if step != Taxonomy.WaterStep.DRY else 0)
	state.extract_cells = [Vector3i(0, 0, 0), Vector3i(0, 1, 0)] as Array[Vector3i]
	var street := Unit.new(1, STREET, Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	street.adapted = true
	var roof := Unit.new(2, ROOF, Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	state.add_unit(street)
	state.add_unit(roof)
	state.add_unit(Unit.new(10, Vector3i(6, 1, 0), Taxonomy.Faction.DRIFTER))
	return state


static func falling_opening() -> CombatState:
	return opening(Taxonomy.WaterStep.FALLING)
