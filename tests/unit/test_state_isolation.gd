extends GutTest

## A fight never writes to the map, and a command never changes the state it was applied to.
## CombatState.duplicate_state() shares the BowlMap between a state and its copies, so anything a
## fight wrote into a Cell would leak backwards into the state a command promised not to touch
## (plan §7.5). Cell.occupant is the *authored* occupant of a roof or deck (UI §17: "occupants are
## data from the start… nothing spawns at the knock"), not where a live unit currently stands.


func _corridor(x1: int) -> BowlMap:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	for x in range(0, x1 + 1):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	return map


func _snapshot(map: BowlMap) -> Dictionary:
	var snap: Dictionary = {}
	for coord in map.cells:
		snap[coord] = (map.cells[coord] as Cell).duplicate_cell()
	return snap


func _map_matches(map: BowlMap, snap: Dictionary) -> bool:
	if map.cells.size() != snap.size():
		return false
	for coord in snap:
		if not map.has_cell(coord) or not map.get_cell(coord).equals(snap[coord]):
			return false
	return true


func _fight(map: BowlMap) -> CombatState:
	var state := CombatState.new()
	state.map = map
	state.add_unit(Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER))
	state.add_unit(Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER))
	return state


func test_adding_a_unit_does_not_write_the_map() -> void:
	var map := _corridor(4)
	var snap := _snapshot(map)
	_fight(map)
	assert_true(_map_matches(map, snap), "units live in the state, not in the cells")


func test_applying_a_move_leaves_the_original_state_and_the_map_untouched() -> void:
	var map := _corridor(4)
	var state := _fight(map)
	var snap := _snapshot(map)
	var cell_before: Vector3i = state.get_unit(1).cell
	var ap_before: int = state.get_unit(1).ap

	var next := MoveCommand.new(1, Vector3i(2, 0, 0)).apply(state)

	assert_eq(next.get_unit(1).cell, Vector3i(2, 0, 0), "the new state moved")
	assert_eq(state.get_unit(1).cell, cell_before, "the original did not")
	assert_eq(state.get_unit(1).ap, ap_before)
	assert_true(_map_matches(map, snap), "and the shared map was not written to")


func test_downing_a_unit_does_not_write_the_map() -> void:
	var map := _corridor(4)
	var state := _fight(map)
	var snap := _snapshot(map)
	state.apply_damage(state.get_unit(2), RulesConstants.HP_PIPS)
	assert_true(state.get_unit(2).bleeding)
	assert_true(_map_matches(map, snap))


func test_authored_occupants_survive_a_fight() -> void:
	## A roof occupant placed by data stays put whatever walks over the tile.
	var map := _corridor(4)
	map.get_cell(Vector3i(2, 0, 0)).occupant = 7
	var state := _fight(map)
	var there := MoveCommand.new(1, Vector3i(2, 0, 0)).apply(state)
	assert_eq(map.get_cell(Vector3i(2, 0, 0)).occupant, 7, "standing on it does not overwrite it")
	var away := MoveCommand.new(1, Vector3i(3, 0, 0)).apply(there)
	assert_eq(map.get_cell(Vector3i(2, 0, 0)).occupant, 7, "and leaving it does not clear it")
	assert_eq(away.get_unit(1).cell, Vector3i(3, 0, 0))


func test_sibling_states_diverge_without_touching_each_other() -> void:
	var map := _corridor(4)
	var root := _fight(map)
	var a := MoveCommand.new(1, Vector3i(1, 0, 0)).apply(root)
	var b := MoveCommand.new(1, Vector3i(3, 0, 0)).apply(root)
	assert_eq(a.get_unit(1).cell, Vector3i(1, 0, 0))
	assert_eq(b.get_unit(1).cell, Vector3i(3, 0, 0))
	assert_eq(root.get_unit(1).cell, Vector3i(0, 0, 0), "the root is where it started")
	## Occupancy is per state: a's move must not have cleared or claimed anything for b.
	assert_true(Movement.is_free(map, a, Vector3i(3, 0, 0), a.get_unit(1)), "a never went to 3")
	assert_false(Movement.is_free(map, b, Vector3i(3, 0, 0), b.get_unit(2)), "b's unit stands on 3")


func test_a_peeled_copy_leaves_its_parent_untouched() -> void:
	## Knowledge is copied like units, not shared like the map (plan 04 §4.2).
	var map := _corridor(4)
	var root := _fight(map)
	assert_eq(root.knowledge.own_sight(1, Vector3i(0, 0, 0)), Knowledge.CellSight.UNKNOWN)
	var next := MoveCommand.new(1, Vector3i(2, 0, 0)).apply(root)
	assert_eq(next.knowledge.own_sight(1, Vector3i(2, 0, 0)), Knowledge.CellSight.LIVE)
	assert_eq(
		root.knowledge.own_sight(1, Vector3i(2, 0, 0)),
		Knowledge.CellSight.UNKNOWN,
		"peel must not leak into the state the command promised not to touch"
	)
	assert_eq(root.knowledge.known_cells(root).size(), 0)
