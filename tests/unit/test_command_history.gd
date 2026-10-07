extends GutTest

## CommandHistory — undo as "hold the previous state" (plan 05 §5.1).


func _phase_state() -> CombatState:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	for x in range(0, 6):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var state := CombatState.new()
	state.map = map
	state.in_contact = true
	state.active_side = CombatState.PhaseSide.PLAYER
	state.add_unit(Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL))
	state.add_unit(Unit.new(2, Vector3i(5, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL))
	state.knowledge.peel(map, state)
	return state


## Apply a command through the history, as the view will. Returns the new state.
func _do(history: CommandHistory, state: CombatState, command: Command) -> CombatState:
	var outcome := command.apply_outcome(state)
	history.record(command, state, outcome)
	return outcome.state


func _same(a: CombatState, b: CombatState) -> bool:
	if a.in_contact != b.in_contact or a.active_side != b.active_side or a.round_index != b.round_index:
		return false
	if a.units.size() != b.units.size() or a.watches.size() != b.watches.size():
		return false
	for id in a.units:
		var x: Unit = a.units[id]
		var y: Unit = b.units[id]
		if x.cell != y.cell or x.ap != y.ap or x.hp != y.hp or x.pin != y.pin:
			return false
	return a.knowledge.known_cells(a).size() == b.knowledge.known_cells(b).size()


func test_a_fresh_history_has_nothing_to_undo() -> void:
	var history := CommandHistory.new()
	assert_false(history.can_undo())
	assert_null(history.undo())


func test_undo_returns_the_exact_state_before_a_reversible_move() -> void:
	var history := CommandHistory.new()
	var start := _phase_state()
	var moved := _do(history, start, MoveCommand.new(1, Vector3i(2, 0, 0)))
	assert_eq(moved.get_unit(1).cell, Vector3i(2, 0, 0))
	assert_true(history.can_undo())
	var back := history.undo()
	assert_true(_same(back, start), "position, AP and knowledge all return")
	assert_eq(back.get_unit(1).ap, start.get_unit(1).ap, "undo refunds the AP (plan 05 §7.2)")
	assert_false(history.can_undo())


func test_two_reversible_moves_undo_in_order() -> void:
	var history := CommandHistory.new()
	var s0 := _phase_state()
	var s1 := _do(history, s0, MoveCommand.new(1, Vector3i(1, 0, 0)))
	var s2 := _do(history, s1, MoveCommand.new(1, Vector3i(3, 0, 0)))
	assert_eq(s2.get_unit(1).cell, Vector3i(3, 0, 0))
	assert_eq(history.depth(), 2)
	assert_eq(history.undo().get_unit(1).cell, Vector3i(1, 0, 0), "last move first")
	assert_eq(history.undo().get_unit(1).cell, Vector3i(0, 0, 0))
	assert_false(history.can_undo())


func test_a_shot_stands_and_clears_what_is_behind_it() -> void:
	var history := CommandHistory.new()
	var s0 := _phase_state()
	var s1 := _do(history, s0, MoveCommand.new(1, Vector3i(1, 0, 0)))
	assert_true(history.can_undo())
	_do(history, s1, ShootCommand.new(1, 2))
	assert_false(history.can_undo(), "an act stands, and so does everything before it")


func test_a_confirmed_action_clears_the_history() -> void:
	var history := CommandHistory.new()
	var s0 := _phase_state()
	s0.get_unit(2).hp = 0
	s0.get_unit(2).bleeding = true
	var s1 := _do(history, s0, MoveCommand.new(1, Vector3i(1, 0, 0)))
	assert_true(history.can_undo())
	var tier := history.record(
		ShootCommand.new(1, 2), s1, ShootCommand.new(1, 2).apply_outcome(s1)
	)
	assert_eq(tier, CommitPolicy.Tier.CONFIRMED)
	assert_false(history.can_undo())


func test_a_move_that_peels_stands() -> void:
	var history := CommandHistory.new()
	var state := CombatState.new()
	state.map = _phase_state().map
	state.add_unit(Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER))
	var tier := history.record(
		FreeMoveCommand.new(1, Vector3i(2, 0, 0)),
		state,
		FreeMoveCommand.new(1, Vector3i(2, 0, 0)).apply_outcome(state),
	)
	assert_eq(tier, CommitPolicy.Tier.COMMITTED)
	assert_false(history.can_undo(), "the first walk peels fog, so it cannot be taken back")


func test_ending_a_phase_clears_the_history() -> void:
	var history := CommandHistory.new()
	_do(history, _phase_state(), MoveCommand.new(1, Vector3i(2, 0, 0)))
	assert_true(history.can_undo())
	history.clear()
	assert_false(history.can_undo())


func test_the_history_holds_its_own_copy_of_the_state() -> void:
	var history := CommandHistory.new()
	var start := _phase_state()
	_do(history, start, MoveCommand.new(1, Vector3i(2, 0, 0)))
	## The caller keeps playing with its own state; the history must not see it.
	start.get_unit(1).cell = Vector3i(4, 0, 0)
	start.get_unit(1).ap = 0
	var back := history.undo()
	assert_eq(back.get_unit(1).cell, Vector3i(0, 0, 0))
	assert_gt(back.get_unit(1).ap, 0)


func test_undo_and_replay_branch_independently() -> void:
	var history := CommandHistory.new()
	var start := _phase_state()
	var first := _do(history, start, MoveCommand.new(1, Vector3i(2, 0, 0)))
	var back := history.undo()
	var other := _do(history, back, MoveCommand.new(1, Vector3i(1, 0, 0)))
	assert_eq(first.get_unit(1).cell, Vector3i(2, 0, 0), "the undone branch is untouched")
	assert_eq(other.get_unit(1).cell, Vector3i(1, 0, 0))
	assert_eq(back.get_unit(1).cell, Vector3i(0, 0, 0), "so is the state we branched from")
