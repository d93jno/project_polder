extends GutTest

## CommitPolicy — the four tiers of UI §5 as a value (plan 05 §5.0).

const Tier := CommitPolicy.Tier


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


func _tier(command: Command, state: CombatState) -> Tier:
	return CommitPolicy.tier_of(command, state, command.apply_outcome(state))


func _dry_map(x1 := 4) -> BowlMap:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_corridor(map, 0, x1)
	return map


func test_a_walk_through_known_empty_ground_is_reversible() -> void:
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := _phase_state(_dry_map(), [player])
	state.knowledge.peel(state.map, state)
	assert_eq(_tier(MoveCommand.new(1, Vector3i(2, 0, 0)), state), Tier.REVERSIBLE)


func test_a_walk_that_peels_a_cell_is_committed() -> void:
	var state := CombatState.new()
	state.map = _dry_map()
	state.add_unit(Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER))
	assert_eq(_tier(FreeMoveCommand.new(1, Vector3i(2, 0, 0)), state), Tier.COMMITTED)


func test_a_walk_that_triggers_a_watch_by_entry_is_committed() -> void:
	var map := _dry_map()
	map.set_cell(Vector3i(4, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var watcher := Unit.new(
		2, Vector3i(4, 1, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL, Vector3i(0, -1, 0)
	)
	var state := _phase_state(map, [player, watcher])
	state.add_watch(LiveWatch.new(2, Vector3i(0, -1, 0)))
	state.knowledge.peel(map, state)
	var outcome := MoveCommand.new(1, Vector3i(4, 0, 0)).apply_outcome(state)
	assert_false(outcome.reveal.watches_triggered.is_empty())
	assert_true(outcome.reveal.cells_peeled.is_empty(), "the Watch alone is what commits it")
	assert_true(outcome.reveal.enemy_lines_entered.is_empty())
	assert_eq(CommitPolicy.tier_of(MoveCommand.new(1, Vector3i(4, 0, 0)), state, outcome), Tier.COMMITTED)


func test_a_walk_into_an_enemy_line_is_committed() -> void:
	var map := _dry_map(5)
	map.set_cell(Vector3i(0, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(1, 1, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var player := Unit.new(1, Vector3i(0, 1, 0), Taxonomy.Faction.PLAYER)
	var hostile := Unit.new(
		2, Vector3i(5, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE, Vector3i(-1, 0, 0)
	)
	var state := _phase_state(map, [player, hostile])
	state.knowledge.peel(map, state)
	var command := MoveCommand.new(1, Vector3i(0, 0, 0))
	var outcome := command.apply_outcome(state)
	assert_false(outcome.reveal.enemy_lines_entered.is_empty())
	assert_eq(CommitPolicy.tier_of(command, state, outcome), Tier.COMMITTED)


func test_a_shot_is_committed_even_with_nothing_else_revealed() -> void:
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var target := Unit.new(2, Vector3i(2, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	var state := _phase_state(_dry_map(), [player, target])
	state.knowledge.peel(state.map, state)
	var command := ShootCommand.new(1, 2)
	var outcome := command.apply_outcome(state)
	assert_true(outcome.reveal.cells_peeled.is_empty())
	assert_eq(CommitPolicy.tier_of(command, state, outcome), Tier.COMMITTED)


func test_an_interact_is_committed() -> void:
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := _phase_state(_dry_map(), [player])
	state.knowledge.peel(state.map, state)
	assert_eq(_tier(InteractCommand.new(1, Vector3i(1, 0, 0)), state), Tier.COMMITTED)


func test_a_throw_is_committed() -> void:
	var command := ThrowCommand.new()
	assert_true(command._is_act(), "a throw is an act (UI §5)")
	var state := _phase_state(_dry_map(), [Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)])
	assert_false(command.needs_confirm(state))
	assert_eq(
		CommitPolicy.tier_of(command, state, CommandOutcome.of(state, _act_reveal())),
		Tier.COMMITTED,
	)


func test_setting_a_watch_is_committed() -> void:
	var command := WatchCommand.new()
	assert_true(command._is_act(), "plan 05 §7.4: a Watch is an act, not a reversible move")
	var state := _phase_state(_dry_map(), [Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)])
	assert_eq(
		CommitPolicy.tier_of(command, state, CommandOutcome.of(state, _act_reveal())),
		Tier.COMMITTED,
	)


func test_shooting_a_bleeder_is_confirmed_and_shooting_a_standing_foe_is_not() -> void:
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var standing := Unit.new(2, Vector3i(2, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	var bleeder := Unit.new(3, Vector3i(3, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	bleeder.hp = 0
	bleeder.bleeding = true
	var state := _phase_state(_dry_map(), [player, standing, bleeder])
	state.knowledge.peel(state.map, state)
	assert_false(ShootCommand.new(1, 2).needs_confirm(state))
	assert_true(ShootCommand.new(1, 3).needs_confirm(state))
	assert_eq(_tier(ShootCommand.new(1, 3), state), Tier.CONFIRMED)
	assert_eq(_tier(ShootCommand.new(1, 2), state), Tier.COMMITTED)


func test_a_trauma_kit_is_confirmed() -> void:
	var medic := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	medic.has_trauma_kit = true
	var patient := Unit.new(2, Vector3i(1, 0, 0), Taxonomy.Faction.PLAYER)
	patient.hp = 0
	patient.bleeding = true
	var state := _phase_state(_dry_map(), [medic, patient])
	state.knowledge.peel(state.map, state)
	var kit := InteractCommand.new(1, Vector3i(1, 0, 0), InteractCommand.Kind.TRAUMA_KIT)
	assert_true(kit.needs_confirm(state))
	assert_eq(_tier(kit, state), Tier.CONFIRMED)


func test_only_a_reversible_tier_can_be_undone() -> void:
	assert_true(CommitPolicy.is_undoable(Tier.REVERSIBLE))
	assert_false(CommitPolicy.is_undoable(Tier.COMMITTED))
	assert_false(CommitPolicy.is_undoable(Tier.CONFIRMED))
	assert_false(CommitPolicy.is_undoable(Tier.FREE))


func test_tiering_does_not_mutate_the_state() -> void:
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := _phase_state(_dry_map(), [player])
	state.knowledge.peel(state.map, state)
	var command := MoveCommand.new(1, Vector3i(2, 0, 0))
	var outcome := command.apply_outcome(state)
	CommitPolicy.tier_of(command, state, outcome)
	assert_eq(state.get_unit(1).cell, Vector3i(0, 0, 0))


func _act_reveal() -> RevealResult:
	var reveal := RevealResult.new()
	reveal.was_act = true
	return reveal
