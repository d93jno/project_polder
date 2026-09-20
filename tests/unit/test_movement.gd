extends GutTest

## Movement costs, path annotation, reserve marks (plan §1.4).


func _corridor(map: BowlMap, from_x: int, to_x: int, y: int = 0, z: int = 0) -> void:
	for x in range(mini(from_x, to_x), maxi(from_x, to_x) + 1):
		map.set_cell(Vector3i(x, y, z), Cell.new(Taxonomy.CoverMaterial.AIR))


func test_mud_doubles_move_cost() -> void:
	var dry := BowlMap.new()
	dry.water_step = Taxonomy.WaterStep.DRY
	var mud := BowlMap.new()
	mud.water_step = Taxonomy.WaterStep.MUD
	var unit := Unit.new()
	var cell := Vector3i(1, 0, 0)
	assert_eq(Movement.move_cost(dry, cell, unit), RulesConstants.MOVE_COST_DRY)
	assert_eq(Movement.move_cost(mud, cell, unit), RulesConstants.MOVE_COST_MUD)
	assert_eq(RulesConstants.MOVE_COST_MUD, RulesConstants.MOVE_COST_DRY * 2)


func test_swim_cost_in_flooded() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.FLOODED
	assert_eq(
		Movement.move_cost(map, Vector3i(0, 0, 0), Unit.new()),
		RulesConstants.MOVE_COST_SWIM
	)


func test_climb_and_dive_add_vertical_surcharge() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	var unit := Unit.new()
	var street := Vector3i(0, 0, 0)
	var roof := Vector3i(0, 0, 1)
	assert_eq(
		Movement.move_cost(map, roof, unit, street),
		RulesConstants.MOVE_COST_DRY + RulesConstants.MOVE_COST_VERTICAL_SURCHARGE
	)
	assert_eq(
		Movement.move_cost(map, street, unit, roof),
		RulesConstants.MOVE_COST_DRY + RulesConstants.MOVE_COST_VERTICAL_SURCHARGE
	)


func test_path_climb_is_reachable() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(0, 0, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	var unit := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.add_unit(unit)
	var path := Movement.path(map, state, unit, Vector3i(0, 0, 1))
	assert_true(path.reachable)
	assert_eq(path.cells, [Vector3i(0, 0, 0), Vector3i(0, 0, 1)] as Array[Vector3i])
	assert_eq(path.cost_per_cell[1], RulesConstants.MOVE_COST_DRY + RulesConstants.MOVE_COST_VERTICAL_SURCHARGE)


func test_shot_reserve_moves_when_ap_changes() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 5)
	var unit := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	unit.ap = 6
	var state := CombatState.new()
	state.add_unit(unit)
	var rich := Movement.path(map, state, unit, Vector3i(5, 0, 0))
	unit.ap = 3
	var poor := Movement.path(map, state, unit, Vector3i(5, 0, 0))
	assert_gt(rich.shot_reserve_at, poor.shot_reserve_at, "less AP shortens the shot reserve")
	assert_true(rich.shot_reserve_at >= 0)
	## After the reserve mark, remaining AP cannot afford a shot.
	var spent_past := 0
	for i in range(poor.shot_reserve_at + 1):
		spent_past += poor.cost_per_cell[i]
	if poor.shot_reserve_at + 1 < poor.cells.size():
		var spent_next := spent_past + poor.cost_per_cell[poor.shot_reserve_at + 1]
		assert_lt(3 - spent_next, RulesConstants.shot_cost(unit.weapon))


func test_shot_reserve_moves_when_weapon_changes() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 5)
	var unit := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	unit.ap = 6
	var state := CombatState.new()
	state.add_unit(unit)
	var pistol_path := Movement.path(map, state, unit, Vector3i(5, 0, 0))
	unit.weapon = Taxonomy.WeaponClass.RIFLE
	var rifle_path := Movement.path(map, state, unit, Vector3i(5, 0, 0))
	assert_gt(
		RulesConstants.shot_cost(Taxonomy.WeaponClass.RIFLE),
		RulesConstants.shot_cost(Taxonomy.WeaponClass.PISTOL)
	)
	assert_gt(
		pistol_path.shot_reserve_at,
		rifle_path.shot_reserve_at,
		"heavier shot cost shortens the reserve"
	)


func test_watch_reserve_differs_from_shot_reserve() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 5)
	var unit := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	unit.ap = 6
	var state := CombatState.new()
	state.add_unit(unit)
	var path := Movement.path(map, state, unit, Vector3i(5, 0, 0))
	assert_ne(RulesConstants.WATCH_COST, RulesConstants.shot_cost(unit.weapon))
	assert_ne(path.shot_reserve_at, path.watch_reserve_at)


func test_path_crosses_two_watches() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 8)
	## Watchers one row north; short cones so the path enters each separately.
	var w1 := Unit.new(
		10, Vector3i(2, 1, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.SHOTGUN, Vector3i(0, -1, 0)
	)
	var w2 := Unit.new(
		11, Vector3i(6, 1, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.SHOTGUN, Vector3i(0, -1, 0)
	)
	map.set_cell(w1.cell, Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(w2.cell, Cell.new(Taxonomy.CoverMaterial.AIR))

	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.add_unit(player)
	state.add_unit(w1)
	state.add_unit(w2)
	state.add_watch(LiveWatch.new(10, Vector3i(0, -1, 0)))
	state.add_watch(LiveWatch.new(11, Vector3i(0, -1, 0)))

	## Sanity: start outside both; mid cells inside each.
	var vol1 := Cones.cone(map, w1.cell, Vector3i(0, -1, 0), w1.weapon)
	var vol2 := Cones.cone(map, w2.cell, Vector3i(0, -1, 0), w2.weapon)
	assert_false(Vector3i(0, 0, 0) in vol1)
	assert_true(Vector3i(2, 0, 0) in vol1)
	assert_false(Vector3i(0, 0, 0) in vol2)
	assert_true(Vector3i(6, 0, 0) in vol2)

	var path := Movement.path(map, state, player, Vector3i(8, 0, 0))
	assert_true(path.reachable)
	assert_eq(path.watches_crossed.size(), 2, "both watches report a crossing")
	var ids: Array = []
	for crossing in path.watches_crossed:
		ids.append(crossing.watcher_id)
	assert_true(10 in ids)
	assert_true(11 in ids)


func test_exposure_per_cell_along_path() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.FLOODED
	_corridor(map, 0, 3)
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.SHELTER))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.add_unit(player)
	var path := Movement.path(map, state, player, Vector3i(3, 0, 0))
	assert_eq(path.exposure_per_cell.size(), path.cells.size())
	assert_eq(path.exposure_per_cell[0].state, Exposure.State.HIDDEN)


func test_mud_path_costs_double_per_tile() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.MUD
	_corridor(map, 0, 3)
	var unit := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.add_unit(unit)
	var path := Movement.path(map, state, unit, Vector3i(3, 0, 0))
	assert_eq(path.total_cost, 3 * RulesConstants.MOVE_COST_MUD)
	for i in range(1, path.cost_per_cell.size()):
		assert_eq(path.cost_per_cell[i], RulesConstants.MOVE_COST_MUD)


func test_masonry_not_walkable() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(1, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	assert_false(Movement.is_walkable(map, Vector3i(1, 0, 0)))
