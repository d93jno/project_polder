extends GutTest

## Vision is the only "can this faction see that cell" (plan 04 §4.1).


func _air_map(x1 := 4, y1 := 0) -> BowlMap:
	var map := BowlMap.new()
	for x in range(0, x1 + 1):
		for y in range(0, y1 + 1):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	return map


func _state(map: BowlMap, units: Array) -> CombatState:
	var state := CombatState.new()
	state.map = map
	for u in units:
		state.add_unit(u)
	return state


func test_sees_clean_air() -> void:
	var map := _air_map()
	var state := _state(map, [
		Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER),
	])
	assert_true(Vision.sees(map, state, Taxonomy.Faction.PLAYER, Vector3i(4, 0, 0)))


func test_masonry_blocks_sees() -> void:
	var map := _air_map()
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var state := _state(map, [
		Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER),
	])
	assert_false(Vision.sees(map, state, Taxonomy.Faction.PLAYER, Vector3i(4, 0, 0)))


func test_plank_does_not_block_sees() -> void:
	## Sight, not shot: a pistol unit still sees past a plank.
	var map := _air_map()
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.PLANK))
	var state := _state(map, [
		Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL),
	])
	assert_true(Vision.sees(map, state, Taxonomy.Faction.PLAYER, Vector3i(4, 0, 0)))


func test_inactive_unit_does_not_see() -> void:
	var map := _air_map()
	var downed := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	downed.bleeding = true
	var state := _state(map, [downed])
	assert_false(Vision.sees(map, state, Taxonomy.Faction.PLAYER, Vector3i(4, 0, 0)))


func test_other_faction_does_not_count() -> void:
	var map := _air_map()
	var state := _state(map, [
		Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.DRIFTER),
	])
	assert_false(Vision.sees(map, state, Taxonomy.Faction.PLAYER, Vector3i(4, 0, 0)))


func test_seers_of_names_who() -> void:
	## Wall on the street; a second squad body stands beside the far end and sees it.
	var map := _air_map(4, 1)
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var a := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var b := Unit.new(2, Vector3i(4, 1, 0), Taxonomy.Faction.PLAYER)
	var state := _state(map, [a, b])
	var seers := Vision.seers_of(map, state, Taxonomy.Faction.PLAYER, Vector3i(4, 0, 0))
	assert_eq(seers.size(), 1)
	assert_eq(seers[0].id, 2)


func test_live_cells_include_own_exclude_walled() -> void:
	var map := _air_map()
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var unit := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := _state(map, [unit])
	var live := Vision.live_cells(map, state, unit)
	assert_true(live.has(Vector3i(0, 0, 0)), "own cell is live")
	assert_true(live.has(Vector3i(1, 0, 0)))
	assert_true(live.has(Vector3i(2, 0, 0)), "the wall tile itself is visible")
	assert_false(live.has(Vector3i(4, 0, 0)), "behind masonry")


func test_live_cells_empty_when_inactive() -> void:
	var map := _air_map()
	var unit := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	unit.dead = true
	var state := _state(map, [unit])
	assert_eq(Vision.live_cells(map, state, unit).size(), 0)


func test_contact_is_live_and_apex_are_vision() -> void:
	## The two call sites are one-liners over Vision; behaviour matches sees().
	var map := _air_map()
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var hostile := Unit.new(10, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER)
	var state := _state(map, [player, hostile])
	assert_eq(
		Contact.is_live(map, state, hostile),
		Vision.sees(map, state, Taxonomy.Faction.PLAYER, hostile.cell)
	)
	assert_eq(
		Cones.apex_known(map, state, hostile.cell, Taxonomy.Faction.PLAYER),
		Vision.sees(map, state, Taxonomy.Faction.PLAYER, hostile.cell)
	)
	assert_false(Contact.is_live(map, state, hostile))
