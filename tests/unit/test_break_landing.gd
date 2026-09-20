extends GutTest

## How a break lands, is served and clears, and what a broken unit may do (plan §1.6, §7.3).

const PLAYER := Taxonomy.Faction.PLAYER
const DRIFTER := Taxonomy.Faction.DRIFTER
const PISTOL := Taxonomy.WeaponClass.PISTOL
const RIFLE := Taxonomy.WeaponClass.RIFLE


func _map(x1 := 8, y1 := 6, y0 := -2) -> BowlMap:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	for x in range(-2, x1 + 1):
		for y in range(y0, y1 + 1):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	return map


func _u(id: int, cell: Vector3i, faction: Taxonomy.Faction, weapon: Taxonomy.WeaponClass = PISTOL) -> Unit:
	return Unit.new(id, cell, faction, weapon)


func _fight(map: BowlMap, units: Array, side: CombatState.PhaseSide = CombatState.PhaseSide.PLAYER) -> CombatState:
	var state := CombatState.new()
	state.map = map
	state.in_contact = true
	state.active_side = side
	for u in units:
		state.add_unit(u)
	return state


## B alone in an open field. E1 holds a loaded pistol Watch facing west from (6,0); E2 covers from the
## north. B walking two tiles east enters E1's cone, is hit (a pistol does not drop), and is then
## pinned, outnumbered (two guns, no friend) and in the open.
func _walk_into_the_crossfire() -> CombatState:
	var map := _map()
	var b := _u(1, Vector3i(0, 0, 0), PLAYER)
	var e1 := _u(10, Vector3i(6, 0, 0), DRIFTER)
	var e2 := _u(11, Vector3i(2, 5, 0), DRIFTER)
	var state := _fight(map, [b, e1, e2])
	state.add_watch(LiveWatch.new(10, Vector3i(-1, 0, 0)))
	return state


func test_a_break_caused_by_an_action_lands_in_that_same_command() -> void:
	var state := _walk_into_the_crossfire()
	var next := MoveCommand.new(1, Vector3i(2, 0, 0)).apply(state)
	var b := next.get_unit(1)
	assert_eq(b.hp, RulesConstants.HP_PIPS - 1, "precondition: the reaction shot hit and did not drop")
	assert_true(b.broken, "pinned, outnumbered and in the open: broken before the command returns")
	assert_false(state.get_unit(1).broken, "the state it was applied to is untouched")


func test_a_break_in_the_units_own_phase_forfeits_it_and_constrains_the_next() -> void:
	var b := MoveCommand.new(1, Vector3i(2, 0, 0)).apply(_walk_into_the_crossfire()).get_unit(1)
	assert_eq(b.ap, 0, "loses the rest of the current phase")
	assert_eq(b.break_phases_left, 2, "and serves the next one")


func test_a_break_found_at_the_start_of_its_own_phase_costs_that_phase() -> void:
	## No pin is involved, so nothing else zeroes the AP: the forfeit has to come from the break itself.
	## An unadapted pistol on Dry stands under a loaded rifle Watch, but nothing has resolved it yet
	## (the enemy phase ended first). Its phase begins and the break lands in it.
	var map := _map()
	var recruit := _u(1, Vector3i(3, 0, 0), PLAYER)
	var rifle := _u(10, Vector3i(0, 0, 0), DRIFTER, RIFLE)
	var state := _fight(map, [recruit, rifle], CombatState.PhaseSide.ENEMY)
	state.add_watch(LiveWatch.new(10, Vector3i(1, 0, 0)))
	assert_false(state.get_unit(1).broken, "precondition: not yet resolved")
	assert_eq(BreakRule.check(map, state, recruit), BreakRule.Result.BREAKS, "precondition: it should break")
	var next := state.end_phase()
	var b := next.get_unit(1)
	assert_eq(next.active_side, CombatState.PhaseSide.PLAYER)
	assert_true(b.broken)
	assert_eq(b.ap, 0, "the phase that just began is lost")
	assert_eq(b.break_phases_left, 2, "and the next one is the constrained move")


func test_broken_wins_over_pinned_so_the_duck_is_dropped() -> void:
	var b := MoveCommand.new(1, Vector3i(2, 0, 0)).apply(_walk_into_the_crossfire()).get_unit(1)
	assert_eq(b.pin, Unit.PinState.NONE, "it takes its broken move instead of ducking (GDD §5.5)")


func test_a_broken_unit_cannot_be_pinned_again() -> void:
	var state := _walk_into_the_crossfire()
	var b := MoveCommand.new(1, Vector3i(2, 0, 0)).apply(state).get_unit(1)
	var next := MoveCommand.new(1, Vector3i(2, 0, 0)).apply(state)
	next.apply_pin(next.get_unit(1))
	assert_eq(next.get_unit(1).pin, Unit.PinState.NONE, "broken wins, still")
	assert_eq(b.pin, Unit.PinState.NONE)


func test_a_break_in_the_opponents_phase_leaves_the_current_phase_alone() -> void:
	var map := _map()
	var b := _u(1, Vector3i(0, 0, 0), PLAYER)
	var state := _fight(map, [b, _u(10, Vector3i(6, 0, 0), DRIFTER), _u(11, Vector3i(2, 5, 0), DRIFTER)], CombatState.PhaseSide.ENEMY)
	var next := ShootCommand.new(10, 1).apply(state)
	var hit := next.get_unit(1)
	assert_eq(hit.hp, RulesConstants.HP_PIPS - 1, "precondition: a pistol hit that did not drop")
	assert_true(hit.broken)
	assert_eq(hit.ap, RulesConstants.AP_POOL, "it is not its phase, so nothing is forfeited")
	assert_eq(hit.break_phases_left, 1, "only its next own phase is constrained")
	assert_eq(hit.pin, Unit.PinState.NONE, "and it will not spend that phase ducked")


func test_the_broken_unit_gets_a_full_phase_of_ap_to_take_its_move() -> void:
	var map := _map()
	var b := _u(1, Vector3i(0, 0, 0), PLAYER)
	var state := _fight(map, [b, _u(10, Vector3i(6, 0, 0), DRIFTER), _u(11, Vector3i(2, 5, 0), DRIFTER)], CombatState.PhaseSide.ENEMY)
	var mid := ShootCommand.new(10, 1).apply(state)
	var next := mid.end_phase()
	assert_eq(next.active_side, CombatState.PhaseSide.PLAYER)
	assert_true(next.get_unit(1).broken, "still broken in its next phase")
	assert_eq(next.get_unit(1).ap, RulesConstants.AP_POOL, "and not ducked: it can act")


func test_a_break_is_served_and_then_clears() -> void:
	var map := _map()
	var b := _u(1, Vector3i(0, 0, 0), PLAYER)
	var state := _fight(map, [b, _u(10, Vector3i(6, 0, 0), DRIFTER), _u(11, Vector3i(2, 5, 0), DRIFTER)], CombatState.PhaseSide.ENEMY)
	state = ShootCommand.new(10, 1).apply(state)
	state = state.end_phase() ## player phase: the constrained one
	assert_true(state.get_unit(1).broken)
	state = state.end_phase() ## its phase is over
	assert_false(state.get_unit(1).broken, "cleared at the end of the phase it served")
	assert_eq(state.get_unit(1).break_phases_left, 0)


func test_a_unit_that_broke_in_its_own_phase_serves_the_next_one_too() -> void:
	var state := MoveCommand.new(1, Vector3i(2, 0, 0)).apply(_walk_into_the_crossfire())
	assert_true(state.get_unit(1).broken)
	state = state.end_phase() ## enemy phase
	assert_true(state.get_unit(1).broken, "still broken across the opponent's phase")
	state = state.end_phase() ## its own next phase begins
	assert_true(state.get_unit(1).broken)
	assert_eq(state.get_unit(1).ap, RulesConstants.AP_POOL)
	state = state.end_phase() ## that phase ends
	assert_false(state.get_unit(1).broken)


func test_a_unit_still_in_trouble_simply_breaks_again() -> void:
	## Clause 3 holds for as long as a rifle keeps its Watch on an unadapted pistol on Dry, so the
	## break re-lands at the next phase start (GDD §5.5, plan §7.3).
	var map := _map()
	var p := _u(1, Vector3i(0, 0, 0), PLAYER, RIFLE)
	var d := _u(10, Vector3i(3, 0, 0), DRIFTER)
	var state := _fight(map, [p, d])
	state = WatchCommand.new(1, Vector3i(1, 0, 0)).apply(state)
	assert_true(state.get_unit(10).broken, "the cone breaks it the moment the Watch is loaded")
	state = state.end_phase() ## enemy phase: D is served, D acts constrained
	assert_true(state.get_unit(10).broken)
	state = state.end_phase() ## D's phase ends: cleared, then the phase-start check
	assert_true(state.get_unit(10).broken, "the Watch is still loaded, so it breaks again")
	assert_eq(state.get_unit(10).break_phases_left, 1, "a fresh break, landed in the opponent's phase")


func test_break_only_lands_once_phases_have_started() -> void:
	var state := _walk_into_the_crossfire()
	state.in_contact = false
	state.get_unit(1).pin = Unit.PinState.DUCKED
	assert_eq(BreakRule.resolve(state), [] as Array[int], "free movement has no break")
	assert_false(state.get_unit(1).broken)


func test_the_call_stops_a_break_landing() -> void:
	var state := _walk_into_the_crossfire()
	var founder := _u(2, Vector3i(1, 0, 0), PLAYER)
	founder.is_founder = true
	state.add_unit(founder)
	var next := MoveCommand.new(1, Vector3i(2, 0, 0)).apply(state)
	assert_true(next.get_unit(1).pin != Unit.PinState.NONE, "precondition: hit and pinned")
	assert_false(next.get_unit(1).broken, "but the founder stands within the Call")


func test_a_broken_unit_loses_its_watch() -> void:
	var state := _walk_into_the_crossfire()
	state = state.duplicate_state()
	state.get_unit(1).weapon = RIFLE
	state = WatchCommand.new(1, Vector3i(1, 0, 0)).apply(state)
	assert_not_null(state.live_watch_for(1), "precondition: it holds a Watch")
	state.get_unit(1).pin = Unit.PinState.DUCKED
	BreakRule.resolve(state)
	assert_true(state.get_unit(1).broken)
	assert_null(state.live_watch_for(1), "a fleeing unit is not holding a Watch")


## --- The broken move: closer to cover or extraction (GDD §5.5) ---


## A three-row street (y 0..2). A wall across rows 0-1 at x=4 with a gap on row 2; H at (7,1) has a
## pistol. West of the wall is hidden from H. B is broken, east of it, and the only way to cover is
## through the gap.
func _wall_scene(b_cell: Vector3i) -> CombatState:
	var map := _map(7, 2, 0)
	map.set_cell(Vector3i(4, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	map.set_cell(Vector3i(4, 1, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var b := _u(1, b_cell, PLAYER)
	b.broken = true
	b.break_phases_left = 1
	return _fight(map, [b, _u(10, Vector3i(7, 1, 0), DRIFTER)])


func _move_result(state: CombatState, to: Vector3i) -> CommandResult:
	return MoveCommand.new(1, to).validate(state)


func test_a_broken_unit_may_move_toward_cover() -> void:
	var state := _wall_scene(Vector3i(5, 0, 0))
	assert_true(_move_result(state, Vector3i(5, 1, 0)).ok, "one step nearer the gap")


func test_a_broken_unit_may_not_move_away_from_cover() -> void:
	var state := _wall_scene(Vector3i(5, 0, 0))
	var result := _move_result(state, Vector3i(6, 0, 0))
	assert_false(result.ok)
	assert_string_contains(result.reason, "broken")


func test_an_unbroken_unit_is_not_held_to_it() -> void:
	var state := _wall_scene(Vector3i(5, 0, 0))
	state.get_unit(1).broken = false
	assert_true(_move_result(state, Vector3i(6, 0, 0)).ok)


func test_an_extract_tile_is_somewhere_to_go() -> void:
	var state := _wall_scene(Vector3i(5, 0, 0))
	assert_false(_move_result(state, Vector3i(6, 0, 0)).ok, "precondition: away from cover is illegal")
	state.extract_cells = [Vector3i(6, 0, 0)] as Array[Vector3i]
	assert_true(_move_result(state, Vector3i(6, 0, 0)).ok, "the boat is a place to run to")


func test_a_broken_unit_already_in_cover_may_only_move_to_more_cover() -> void:
	var state := _wall_scene(Vector3i(3, 0, 0))
	var attackers := state.attackers_of(state.map, state.get_unit(1))
	assert_eq(attackers.size(), 0, "precondition: hidden behind the wall")
	assert_true(_move_result(state, Vector3i(2, 0, 0)).ok, "further behind the wall")
	assert_false(_move_result(state, Vector3i(3, 2, 0)).ok, "out through the gap and into the line")


func test_with_nowhere_safe_to_go_nothing_is_forbidden() -> void:
	var map := _map(7, 2)
	var b := _u(1, Vector3i(3, 1, 0), PLAYER)
	b.broken = true
	var state := _fight(map, [b, _u(10, Vector3i(7, 1, 0), DRIFTER)])
	assert_true(_move_result(state, Vector3i(2, 1, 0)).ok)
	assert_true(_move_result(state, Vector3i(5, 1, 0)).ok)
