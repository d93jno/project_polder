extends Object
## Shared opening for the headless scripted fight and `fight_view` (plan 2.6).
## One street, one wall, four players, three Drifters. Tests own the command list;
## this module owns only the starting `BowlMap` / `CombatState` so the view cannot drift.
## Preload this script (no class_name) so headless tests do not need a global-class refresh.

const PLAYER := Taxonomy.Faction.PLAYER
const DRIFTER := Taxonomy.Faction.DRIFTER

const P1 := 1 ## trained rifleman, sets the Watch
const P2 := 2 ## raw recruit, gets pinned
const P3 := 3 ## medic with a trauma kit
const P4 := 4 ## raw recruit, goes down
const D_NEAR := 10 ## in the rifle's cone: routs
const D_FAR_A := 11 ## out of the cone: shoots P2
const D_FAR_B := 12 ## out of the cone: shoots P4 twice

const CONTACT_TILE := Vector3i(5, 4, 0)


static func street() -> BowlMap:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	map.water_z = 0
	for x in range(0, 17):
		for y in range(0, 6):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	for y in range(0, 4):
		map.set_cell(Vector3i(6, y, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	return map


static func opening() -> CombatState:
	var state := CombatState.new()
	state.map = street()
	state.extract_cells = [Vector3i(1, 3, 0), Vector3i(1, 4, 0), Vector3i(1, 5, 0)] as Array[Vector3i]
	var p1 := Unit.new(P1, Vector3i(5, 3, 0), PLAYER, Taxonomy.WeaponClass.RIFLE)
	p1.adapted = true
	var p3 := Unit.new(P3, Vector3i(4, 3, 0), PLAYER)
	p3.has_trauma_kit = true
	state.add_unit(p1)
	state.add_unit(Unit.new(P2, Vector3i(3, 3, 0), PLAYER))
	state.add_unit(p3)
	state.add_unit(Unit.new(P4, Vector3i(3, 2, 0), PLAYER))
	state.add_unit(Unit.new(D_NEAR, Vector3i(9, 4, 0), DRIFTER))
	state.add_unit(Unit.new(D_FAR_A, Vector3i(15, 4, 0), DRIFTER))
	state.add_unit(Unit.new(D_FAR_B, Vector3i(15, 5, 0), DRIFTER))
	return state
