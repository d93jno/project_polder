extends GutTest

## Knowledge peel, monotonicity, earshot merge (plan 04 §4.2).


const LIVE := Knowledge.CellSight.LIVE
const QUIET := Knowledge.CellSight.KNOWN_QUIET
const UNKNOWN := Knowledge.CellSight.UNKNOWN


func _street(length := 8) -> BowlMap:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	for x in range(0, length + 1):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	return map


func _room_off_street() -> BowlMap:
	## Street on y=0; a room at (4,2) behind a masonry wall on y=1. Door at (4,1).
	var map := _street(6)
	for x in range(3, 6):
		map.set_cell(Vector3i(x, 1, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
		map.set_cell(Vector3i(x, 2, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(4, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	return map


func _state(map: BowlMap, units: Array) -> CombatState:
	var state := CombatState.new()
	state.map = map
	for u in units:
		state.add_unit(u)
	return state


func test_opening_knowledge_is_empty() -> void:
	var state := _state(_street(), [Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)])
	assert_eq(state.knowledge.own_sight(1, Vector3i(0, 0, 0)), UNKNOWN)
	assert_eq(state.knowledge.known_cells(state).size(), 0)


func test_walk_peels_live_then_known_quiet() -> void:
	var map := _street()
	var state := _state(map, [Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)])
	var at_far := FreeMoveCommand.new(1, Vector3i(6, 0, 0)).apply(state)
	assert_eq(at_far.knowledge.own_sight(1, Vector3i(6, 0, 0)), LIVE, "standing tile is Live")
	assert_eq(at_far.knowledge.own_sight(1, Vector3i(0, 0, 0)), LIVE, "start still in sight along the street")

	## Walk away so the far end drops out of vision — use a short street segment behind a wall.
	var walled := _street(10)
	walled.set_cell(Vector3i(5, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var start := _state(walled, [Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)])
	var near_wall := FreeMoveCommand.new(1, Vector3i(4, 0, 0)).apply(start)
	assert_eq(near_wall.knowledge.own_sight(1, Vector3i(4, 0, 0)), LIVE)
	assert_eq(near_wall.knowledge.own_sight(1, Vector3i(0, 0, 0)), LIVE)
	## Behind the wall stays Unknown — never seen.
	assert_eq(near_wall.knowledge.own_sight(1, Vector3i(8, 0, 0)), UNKNOWN)

	## Peel from west of wall, then move east of wall so west cells leave Live.
	var east_map := _street(10)
	east_map.set_cell(Vector3i(5, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	## Gap north so the unit can walk around.
	east_map.set_cell(Vector3i(5, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	for x in range(0, 11):
		east_map.set_cell(Vector3i(x, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var s2 := _state(east_map, [Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)])
	var saw_west := FreeMoveCommand.new(1, Vector3i(3, 0, 0)).apply(s2)
	assert_eq(saw_west.knowledge.own_sight(1, Vector3i(0, 0, 0)), LIVE)
	var around := FreeMoveCommand.new(1, Vector3i(8, 0, 0)).apply(saw_west)
	assert_eq(around.knowledge.own_sight(1, Vector3i(8, 0, 0)), LIVE)
	assert_eq(
		around.knowledge.own_sight(1, Vector3i(0, 0, 0)),
		QUIET,
		"left vision freezes the tile — Known-quiet, not Unknown"
	)


func test_room_stays_unknown_until_a_line_in() -> void:
	var map := _room_off_street()
	var state := _state(map, [Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)])
	## West of the door: the room is walled off. Standing on (4,0) would look straight in.
	var on_street := FreeMoveCommand.new(1, Vector3i(2, 0, 0)).apply(state)
	assert_eq(on_street.knowledge.own_sight(1, Vector3i(4, 2, 0)), UNKNOWN, "walled room")
	var at_door := FreeMoveCommand.new(1, Vector3i(4, 1, 0)).apply(on_street)
	assert_eq(at_door.knowledge.own_sight(1, Vector3i(4, 2, 0)), LIVE, "line through the door")


func test_earshot_merge_not_map() -> void:
	## Scout peels west of a wall; near teammate merges it; far teammate behind the wall does not.
	## Squad picture still includes the scout's peel (earshot does not gate the map).
	var map := _street(10)
	map.set_cell(Vector3i(4, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var scout := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var near := Unit.new(2, Vector3i(2, 0, 0), Taxonomy.Faction.PLAYER)
	var far := Unit.new(3, Vector3i(8, 0, 0), Taxonomy.Faction.PLAYER)
	var state := _state(map, [scout, near, far])
	state.knowledge.peel(map, state)

	assert_eq(state.knowledge.own_sight(1, Vector3i(0, 0, 0)), LIVE)
	assert_eq(state.knowledge.own_sight(3, Vector3i(0, 0, 0)), UNKNOWN, "wall hides west from far")
	assert_eq(state.knowledge.merged_sight(state, near, Vector3i(0, 0, 0)), LIVE, "in earshot")
	assert_eq(state.knowledge.merged_sight(state, far, Vector3i(0, 0, 0)), UNKNOWN, "out of earshot")
	assert_eq(
		state.knowledge.squad_sight(state, Vector3i(0, 0, 0)),
		LIVE,
		"squad picture is the union"
	)
	assert_true(state.knowledge.known_cells(state).has(Vector3i(0, 0, 0)))


func test_never_returns_to_unknown() -> void:
	var map := _street(10)
	map.set_cell(Vector3i(5, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	for x in range(0, 11):
		map.set_cell(Vector3i(x, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var state := _state(map, [Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)])
	var west := FreeMoveCommand.new(1, Vector3i(3, 0, 0)).apply(state)
	assert_ne(west.knowledge.own_sight(1, Vector3i(0, 0, 0)), UNKNOWN)
	var east := FreeMoveCommand.new(1, Vector3i(8, 0, 0)).apply(west)
	assert_eq(east.knowledge.own_sight(1, Vector3i(0, 0, 0)), QUIET)
	assert_ne(east.knowledge.own_sight(1, Vector3i(0, 0, 0)), UNKNOWN)


func test_to_dict_round_trip() -> void:
	var map := _street()
	var state := _state(map, [Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)])
	state.knowledge.peel(map, state)
	var again := Knowledge.from_dict(state.knowledge.to_dict())
	assert_eq(again.own_sight(1, Vector3i(0, 0, 0)), LIVE)
	assert_eq(again.visit_index, state.knowledge.visit_index)


func test_enemy_does_not_peel() -> void:
	var map := _street()
	var state := _state(map, [
		Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER),
		Unit.new(10, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER),
	])
	state.knowledge.peel(map, state)
	assert_eq(state.knowledge.own_sight(10, Vector3i(4, 0, 0)), UNKNOWN)
	assert_eq(state.knowledge.own_sight(1, Vector3i(0, 0, 0)), LIVE)
