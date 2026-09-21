extends GutTest

## RevealResult / CommandOutcome — the information boundary (plan 04 §4.5).


func _corridor(map: BowlMap, x0: int, x1: int, y := 0) -> void:
	for x in range(x0, x1 + 1):
		map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))


func _phase_state(map: BowlMap, units: Array) -> CombatState:
	var state := CombatState.new()
	state.map = map
	state.in_contact = true
	state.active_side = CombatState.PhaseSide.PLAYER
	for u in units:
		state.add_unit(u)
	return state


func test_move_on_known_ground_reveals_nothing() -> void:
	## Peel the corridor first, then step along it — no peel, Watch, line, or act.
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 4)
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := _phase_state(map, [player])
	state.knowledge.peel(map, state)
	assert_true(state.knowledge.known_cells(state).has(Vector3i(2, 0, 0)))

	var outcome := MoveCommand.new(1, Vector3i(2, 0, 0)).apply_outcome(state)
	assert_false(outcome.reveal.anything_revealed(), "known empty ground is reversible")
	assert_true(outcome.reveal.cells_peeled.is_empty())
	assert_true(outcome.reveal.watches_triggered.is_empty())
	assert_true(outcome.reveal.enemy_lines_entered.is_empty())
	assert_false(outcome.reveal.was_act)


func test_move_that_peels_reports_cells() -> void:
	## Opening knowledge is empty; one free-move step peels Live cells.
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 4)
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.map = map
	state.add_unit(player)
	assert_eq(state.knowledge.known_cells(state).size(), 0)

	var outcome := FreeMoveCommand.new(1, Vector3i(2, 0, 0)).apply_outcome(state)
	assert_false(outcome.reveal.cells_peeled.is_empty(), "first walk peels fog")
	assert_true(Vector3i(2, 0, 0) in outcome.reveal.cells_peeled)
	assert_true(outcome.reveal.anything_revealed())
	assert_false(outcome.reveal.was_act)


func test_watch_entry_reports_triggered() -> void:
	## Watcher north of corridor faces south; player walks into the cone.
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 4)
	map.set_cell(Vector3i(4, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var watcher := Unit.new(
		2, Vector3i(4, 1, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL, Vector3i(0, -1, 0)
	)
	var state := _phase_state(map, [player, watcher])
	state.add_watch(LiveWatch.new(2, Vector3i(0, -1, 0)))
	state.knowledge.peel(map, state)

	var vol := Cones.cone(map, watcher.cell, Vector3i(0, -1, 0), watcher.weapon)
	assert_false(Vector3i(0, 0, 0) in vol)
	assert_true(Vector3i(4, 0, 0) in vol)

	var outcome := MoveCommand.new(1, Vector3i(4, 0, 0)).apply_outcome(state)
	assert_true(2 in outcome.reveal.watches_triggered, "entry into the cone triggers Watch")
	assert_true(outcome.reveal.anything_revealed())


func test_step_wholly_inside_cone_reports_no_watch() -> void:
	## Start already inside the cone; one step that stays inside triggers nothing.
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 4)
	map.set_cell(Vector3i(2, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var player := Unit.new(1, Vector3i(2, 0, 0), Taxonomy.Faction.PLAYER)
	var watcher := Unit.new(
		2, Vector3i(2, 1, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.SHOTGUN, Vector3i(0, -1, 0)
	)
	var state := _phase_state(map, [player, watcher])
	state.add_watch(LiveWatch.new(2, Vector3i(0, -1, 0)))
	state.knowledge.peel(map, state)

	var vol := Cones.cone(map, watcher.cell, Vector3i(0, -1, 0), watcher.weapon)
	assert_true(Vector3i(2, 0, 0) in vol)
	assert_true(Vector3i(3, 0, 0) in vol)

	var outcome := MoveCommand.new(1, Vector3i(3, 0, 0)).apply_outcome(state)
	assert_true(outcome.reveal.watches_triggered.is_empty(), "moving wholly inside does not trigger")
	assert_false(outcome.reveal.was_act)


func test_enemy_line_entry_reports_seer() -> void:
	## Hostile on the street; player steps out from behind a masonry corner into their line.
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 5)
	## Blind alley north of x=0, sealed east by masonry so the rifle cannot see in.
	map.set_cell(Vector3i(0, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(1, 1, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var player := Unit.new(1, Vector3i(0, 1, 0), Taxonomy.Faction.PLAYER)
	var hostile := Unit.new(
		2, Vector3i(5, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE, Vector3i(-1, 0, 0)
	)
	var state := _phase_state(map, [player, hostile])
	state.knowledge.peel(map, state)
	assert_true(Command.enemy_line_seers(map, state, player).is_empty(), "alcove starts clear of line")

	var outcome := MoveCommand.new(1, Vector3i(0, 0, 0)).apply_outcome(state)
	assert_true(2 in outcome.reveal.enemy_lines_entered, "stepping onto the street enters the line")
	assert_true(outcome.reveal.anything_revealed())


func test_in_cone_shot_reports_triggered_watch() -> void:
	## Player already inside a hostile Watch cone fires — GDD 1.13 act trigger.
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 4)
	map.set_cell(Vector3i(2, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var player := Unit.new(1, Vector3i(2, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var watcher := Unit.new(
		2, Vector3i(2, 1, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL, Vector3i(0, -1, 0)
	)
	## Second hostile further east as the shot target (watcher is the Watch apex).
	var target := Unit.new(3, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	var state := _phase_state(map, [player, watcher, target])
	state.add_watch(LiveWatch.new(2, Vector3i(0, -1, 0)))
	state.knowledge.peel(map, state)

	var vol := Cones.cone(map, watcher.cell, Vector3i(0, -1, 0), watcher.weapon)
	assert_true(Vector3i(2, 0, 0) in vol, "shooter stands in the cone")

	var outcome := ShootCommand.new(1, 3).apply_outcome(state)
	assert_true(outcome.reveal.was_act)
	assert_true(2 in outcome.reveal.watches_triggered, "in-cone shot reports the Watch")
	## Resolution of that reaction is a later slice — Watch stays unspent.
	assert_false(state.watches[0].spent)
	assert_false(outcome.state.watches[0].spent)


func test_apply_still_returns_combat_state() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, 2)
	var state := _phase_state(map, [Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)])
	var next = MoveCommand.new(1, Vector3i(2, 0, 0)).apply(state)
	assert_true(next is CombatState)
	assert_eq(next.get_unit(1).cell, Vector3i(2, 0, 0))
