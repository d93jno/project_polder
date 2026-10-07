extends GutTest

## Machines as fight state (plan 06 §6.0): hatch, pump, sluice.

const GROUND := Vector3i(0, 0, 0)
const UPSTAIRS := Vector3i(0, 0, 1)
const NEXT_TO := Vector3i(1, 0, 0)


func _bowl() -> BowlMap:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	for x in range(0, 4):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(UPSTAIRS, Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	return map


func _state(machine: Machine = null, unit_cell := NEXT_TO) -> CombatState:
	var state := CombatState.new()
	state.map = _bowl()
	state.in_contact = true
	state.active_side = CombatState.PhaseSide.PLAYER
	state.add_unit(Unit.new(1, unit_cell, Taxonomy.Faction.PLAYER))
	if machine != null:
		state.add_machine(machine)
	return state


func _can_climb(state: CombatState) -> bool:
	var unit: Unit = state.get_unit(1)
	unit.cell = GROUND
	return Movement.path(state.map, state, unit, UPSTAIRS).reachable


func test_a_closed_hatch_blocks_the_climb_and_an_open_one_carries_it() -> void:
	var state := _state(Machine.new(GROUND, Machine.Kind.HATCH, false))
	assert_false(_can_climb(state), "closed")
	state.machine_at(GROUND).on = true
	assert_true(_can_climb(state), "open, with no LINK flag on the map")


func test_the_hatch_alone_decides_even_over_a_link_flag() -> void:
	var state := _state(Machine.new(GROUND, Machine.Kind.HATCH, false))
	state.map.get_cell(GROUND).flags |= Taxonomy.CellFlags.LINK
	assert_false(_can_climb(state), "a closed hatch beats the map's LINK")


func test_a_pump_at_the_lower_cell_does_not_gate_a_climb() -> void:
	var state := _state(Machine.new(GROUND, Machine.Kind.PUMP, true))
	state.map.get_cell(GROUND).flags |= Taxonomy.CellFlags.LINK
	assert_true(_can_climb(state), "only a hatch is a connector")


func test_unit_opens_a_closed_hatch_then_climbs_through_it() -> void:
	var state := _state(Machine.new(GROUND, Machine.Kind.HATCH, false))
	var unit: Unit = state.get_unit(1)
	assert_false(Movement.path(state.map, state, unit, UPSTAIRS).reachable)
	var open := MachineCommand.new(1, GROUND, true)
	assert_true(open.validate(state).ok)
	var next := open.apply(state)
	assert_true(next.machine_at(GROUND).on)
	assert_eq(next.get_unit(1).ap, state.get_unit(1).ap - RulesConstants.INTERACT_COST)
	var climber: Unit = next.get_unit(1)
	var path := Movement.path(next.map, next, climber, UPSTAIRS)
	assert_true(path.reachable)
	assert_false(state.machine_at(GROUND).on, "the state it was applied to is untouched")


func test_a_machine_command_says_why_it_fails() -> void:
	var state := _state(Machine.new(GROUND, Machine.Kind.HATCH, false))
	assert_eq(MachineCommand.new(1, Vector3i(3, 0, 0)).validate(state).reason, "no machine there")
	assert_eq(MachineCommand.new(9, GROUND).validate(state).reason, "unknown unit")
	assert_eq(MachineCommand.new(1, GROUND, false).validate(state).reason, "already closed")
	var far := _state(Machine.new(GROUND, Machine.Kind.HATCH, false), Vector3i(3, 0, 0))
	assert_eq(MachineCommand.new(1, GROUND).validate(far).reason, "too far from the machine")
	var broke := _state(Machine.new(GROUND, Machine.Kind.HATCH, false))
	broke.get_unit(1).ap = 0
	assert_eq(MachineCommand.new(1, GROUND).validate(broke).reason, "not enough AP")


func test_a_pump_starts_and_stops() -> void:
	var state := _state(Machine.new(GROUND, Machine.Kind.PUMP, false))
	var running := MachineCommand.new(1, GROUND, true).apply(state)
	assert_true(running.machine_at(GROUND).on)
	assert_eq(MachineCommand.new(1, GROUND, true).validate(running).reason, "already running")
	var stopped := MachineCommand.new(1, GROUND, false).apply(running)
	assert_false(stopped.machine_at(GROUND).on)
	assert_eq(MachineCommand.new(1, GROUND, false).validate(stopped).reason, "already stopped")


func test_a_sluice_opens_and_cannot_be_closed() -> void:
	var state := _state(Machine.new(GROUND, Machine.Kind.SLUICE, false))
	var open := MachineCommand.new(1, GROUND, true).apply(state)
	assert_true(open.machine_at(GROUND).on)
	assert_eq(MachineCommand.new(1, GROUND, false).validate(open).reason, "a sluice cannot be closed again")


func test_a_machine_command_is_an_act_so_it_is_committed() -> void:
	var state := _state(Machine.new(GROUND, Machine.Kind.PUMP, false))
	var command := MachineCommand.new(1, GROUND)
	var outcome := command.apply_outcome(state)
	assert_true(outcome.reveal.was_act)
	assert_eq(CommitPolicy.tier_of(command, state, outcome), CommitPolicy.Tier.COMMITTED)


func test_machine_state_is_copied_not_shared() -> void:
	var state := _state(Machine.new(GROUND, Machine.Kind.HATCH, false))
	var copy := state.duplicate_state()
	copy.machine_at(GROUND).on = true
	assert_false(state.machine_at(GROUND).on, "a copy's machine is its own")
	assert_not_same(copy.machine_at(GROUND), state.machine_at(GROUND))
	assert_eq(copy.machines.size(), 1)


func test_the_machine_command_never_writes_the_map() -> void:
	var state := _state(Machine.new(GROUND, Machine.Kind.HATCH, false))
	var before := (state.map.get_cell(GROUND) as Cell).duplicate_cell()
	MachineCommand.new(1, GROUND).apply(state)
	assert_true(state.map.get_cell(GROUND).equals(before))
