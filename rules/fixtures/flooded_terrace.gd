extends Object
## Flooded terrace opening (plan 3.3). Cells and units only — stamps live in
## `presentation/fixtures/flooded_terrace_stamps.gd`. Preload (no class_name).

const PLAYER := Taxonomy.Faction.PLAYER
const DRIFTER := Taxonomy.Faction.DRIFTER

const P1 := 1 ## rifleman on the canal
const P2 := 2 ## recruit
const P3 := 3 ## medic
const P4 := 4 ## starts on the roof
const D_RIFLE := 10 ## levee crest Watch down the canal
const D_PISTOL := 11 ## upstairs window (INTERIOR)
## Authored interior occupant — seated at load; fog decides whether they are drawn (§7.6).
const ROOF_CLAN := 20

## House A origin (stair + ladder column). House B beside it.
const HOUSE_A := Vector3i(4, 5, 0)
const HOUSE_B := Vector3i(6, 5, 0)
const ROOF_A := Vector3i(4, 5, 2)
const ROOF_B := Vector3i(7, 5, 2) ## shanty deck cell on house B
const CLAN_CELL := Vector3i(7, 5, 0) ## authored occupant inside house B
const STAIR := Vector3i(4, 5, 0)
const LADDER := Vector3i(4, 5, 1)
const INSIDE_A := Vector3i(4, 5, 0) ## stair-column ground room
const UPSTAIRS_B := Vector3i(6, 5, 1)
const CANAL := Vector3i(3, 3, 0)
const CREST := Vector3i(8, 9, 0)
const PIER_ORIGIN := Vector3i(1, 0, 0)


static func map(step: Taxonomy.WaterStep = Taxonomy.WaterStep.FLOODED) -> BowlMap:
	var map := BowlMap.new()
	map.water_step = step
	## Street-level plane; Dry hides it in the view. Geometry is identical at every step.
	map.water_z = 0
	## 16×10 footprint: near pier, canal street, terrace houses, levee crest.
	for x in range(0, 16):
		for y in range(0, 10):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	## Pier extract (crate cover matches env_pier).
	for x in range(1, 4):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.CRATE))
	## Far-bank levee flanks — masonry cover with a sight corridor down the canal so the
	## crest rifle can see the roof decks (plan 3.3).
	for x in range(0, 16):
		if x >= 4 and x <= 11:
			continue
		map.set_cell(Vector3i(x, 8, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	_house_volume(map, HOUSE_A)
	_house_volume(map, HOUSE_B)
	return map


static func _house_volume(map: BowlMap, origin: Vector3i) -> void:
	## Ground shell is masonry (house stamp is 2×2×1). Upper storey and roof are
	## sparse so a crest→deck line can clear over the back wall.
	var room := Taxonomy.CellFlags.INTERIOR | Taxonomy.CellFlags.SHELTER
	var is_a := origin == HOUSE_A
	for dx in 2:
		for dy in 2:
			var ground := Vector3i(origin.x + dx, origin.y + dy, 0)
			if dy != 0:
				map.set_cell(ground, Cell.new(Taxonomy.CoverMaterial.MASONRY))
			elif is_a and dx == 0:
				map.set_cell(ground, Cell.new(Taxonomy.CoverMaterial.MASONRY, room))
			elif is_a and dx == 1:
				map.set_cell(ground, Cell.new(Taxonomy.CoverMaterial.MASONRY))
			elif (not is_a) and dx == 0:
				map.set_cell(ground, Cell.new(Taxonomy.CoverMaterial.MASONRY))
			else:
				map.set_cell(ground, Cell.new(Taxonomy.CoverMaterial.MASONRY, room))
	if is_a:
		map.set_cell(Vector3i(origin.x, origin.y, 1), Cell.new(Taxonomy.CoverMaterial.MASONRY, room))
		map.set_cell(Vector3i(origin.x + 1, origin.y, 1), Cell.new(Taxonomy.CoverMaterial.MASONRY, room))
		map.set_cell(Vector3i(origin.x, origin.y, 2), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	else:
		map.set_cell(Vector3i(origin.x, origin.y, 1), Cell.new(Taxonomy.CoverMaterial.MASONRY, room))
		map.set_cell(Vector3i(origin.x + 1, origin.y, 2), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
		## Ground interior of house B: authored occupant, unseen until a line in.
		map.set_cell(
			Vector3i(origin.x + 1, origin.y, 0),
			Cell.new(Taxonomy.CoverMaterial.MASONRY, room, ROOF_CLAN)
		)


static func occupant_roster() -> Dictionary:
	## id → { faction, weapon }. Smallest roster that seats authored Cell.occupant ids.
	return {
		ROOF_CLAN: {
			"faction": Taxonomy.Faction.NEUTRAL,
			"weapon": Taxonomy.WeaponClass.PISTOL,
		},
	}


static func opening(step: Taxonomy.WaterStep = Taxonomy.WaterStep.FLOODED) -> CombatState:
	var state := CombatState.new()
	state.map = map(step)
	state.extract_cells = [
		Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0),
	] as Array[Vector3i]
	var p1 := Unit.new(P1, Vector3i(2, 3, 0), PLAYER, Taxonomy.WeaponClass.RIFLE)
	p1.adapted = true
	var p3 := Unit.new(P3, Vector3i(1, 3, 0), PLAYER)
	p3.has_trauma_kit = true
	state.add_unit(p1)
	state.add_unit(Unit.new(P2, Vector3i(2, 2, 0), PLAYER))
	state.add_unit(p3)
	state.add_unit(Unit.new(P4, ROOF_A, PLAYER)) ## starts on the roof
	var rifle := Unit.new(D_RIFLE, CREST, DRIFTER, Taxonomy.WeaponClass.RIFLE)
	state.add_unit(rifle)
	state.add_watch(LiveWatch.new(D_RIFLE, Vector3i(0, -1, 0)))
	state.add_unit(Unit.new(D_PISTOL, UPSTAIRS_B, DRIFTER, Taxonomy.WeaponClass.PISTOL))
	Occupants.seat(state, occupant_roster())
	return state
