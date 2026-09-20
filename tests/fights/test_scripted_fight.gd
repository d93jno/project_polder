extends GutTest

## The proof (plan §1.6 / 2.6). One bowl, four bodies: walk until contact, exchange fire, one unit pinned,
## one broken, one bleeding out, extract. Driven entirely through commands and asserted end to end,
## headless. It reads as a description of the fight.
##
## Opening state comes from `ScriptedFight` — the same module `fight_view` loads (plan 2.6).
## The bowl is a street with a wall across its south half. The squad starts hidden behind the wall.
## The Drifters are in the lane to the east: one close enough to fall inside a rifle's cone, two more
## than a rifle cone's length away, so they can shoot down the lane but are never frightened by it.

const ScriptedFight := preload("res://rules/fixtures/scripted_fight.gd")

const P1 := ScriptedFight.P1
const P2 := ScriptedFight.P2
const P3 := ScriptedFight.P3
const P4 := ScriptedFight.P4
const D_NEAR := ScriptedFight.D_NEAR
const D_FAR_A := ScriptedFight.D_FAR_A
const D_FAR_B := ScriptedFight.D_FAR_B
const CONTACT_TILE := ScriptedFight.CONTACT_TILE


## Apply a command, failing loudly with the rules' own reason if it is not legal.
func _do(state: CombatState, cmd: Command) -> CombatState:
	var check := cmd.validate(state)
	assert_true(check.ok, "illegal command: %s" % check.reason)
	return cmd.apply(state)


func _snapshot(state: CombatState) -> String:
	var lines: Array[String] = []
	var ids: Array = state.units.keys()
	ids.sort()
	for id in ids:
		var u: Unit = state.units[id]
		lines.append("%d@%s hp%d ap%d pin%d brk%s/%d bl%s/%s/%d x%s dead%s" % [
			id, u.cell, u.hp, u.ap, u.pin, u.broken, u.break_phases_left,
			u.bleeding, u.bleed_stabilized, u.bleed_rounds_left, u.extracted, u.dead,
		])
	return "%s contact%s side%d round%d" % ["\n".join(lines), state.in_contact, state.active_side, state.round_index]


## The whole fight. Returns the final state; `check` turns the assertions on so a second run can be
## compared for determinism without asserting everything twice.
func _play(check: bool) -> CombatState:
	var opening := ScriptedFight.opening()
	var s := opening
	var map := s.map

	## --- Walk until contact ---
	if check:
		assert_false(Contact.check(map, s).contact, "the squad starts hidden behind the wall")
		assert_false(s.in_contact)
	s = _do(s, FreeMoveCommand.new(P1, Vector3i(5, 5, 0)))
	if check:
		assert_true(s.in_contact, "phases have started")
		assert_eq(s.get_unit(P1).cell, CONTACT_TILE, "stopped on the first tile a Drifter could see, not at the destination")
		assert_eq(s.get_unit(P1).ap, RulesConstants.AP_POOL, "walking was free")
		assert_eq(s.active_side, CombatState.PhaseSide.PLAYER)
		assert_eq(opening.get_unit(P1).cell, Vector3i(5, 3, 0), "the opening state is untouched")
		assert_false(opening.in_contact)

	## --- Player phase 1: a rifle Watch routs the near Drifter; the recruits come out ---
	s = _do(s, WatchCommand.new(P1, Vector3i(1, 0, 0)))
	if check:
		assert_true(BreakRule.under_long_cone(map, s, s.get_unit(D_NEAR)))
		assert_true(s.get_unit(D_NEAR).broken, "unadapted, CQB kit, on Dry, under a loaded rifle Watch (broken, one)")
		assert_false(s.get_unit(D_FAR_A).broken, "more than a cone's length away: it can shoot but is not frightened")
		assert_false(s.get_unit(D_FAR_B).broken)
		assert_eq(s.get_unit(D_NEAR).break_phases_left, 1, "landed in the opponent's phase")
	s = _do(s, MoveCommand.new(P2, Vector3i(3, 4, 0)))
	s = _do(s, MoveCommand.new(P4, Vector3i(2, 4, 0)))
	if check:
		for id in [P2, P4]:
			assert_gt(s.attackers_of(map, s.get_unit(id)).size(), 0, "unit %d is now in the lane" % id)
		assert_eq(s.attackers_of(map, s.get_unit(P3)).size(), 0, "the medic is still behind the wall")

	## --- Enemy phase 1: one recruit pinned, the other goes down ---
	s = s.end_phase()
	s = _do(s, ShootCommand.new(D_FAR_A, P2))
	if check:
		assert_eq(s.get_unit(P2).hp, RulesConstants.HP_PIPS - 1, "a pistol hit does not drop")
		assert_eq(s.get_unit(P2).pin, Unit.PinState.DUCKING_NEXT, "pinned (one)")
		assert_false(s.get_unit(P2).broken, "pinned, but friends stand near: not outnumbered")
	s = _do(s, ShootCommand.new(D_FAR_B, P4))
	s = _do(s, ShootCommand.new(D_FAR_B, P4))
	if check:
		assert_true(s.get_unit(P4).bleeding, "two clean pistol hits drop a unit to Bleeding Out (bleeding, one)")
		assert_eq(s.get_unit(P4).bleed_rounds_left, RulesConstants.BLEED_ROUNDS)
		assert_false(s.get_unit(P4).broken, "downed units do not break")

	## --- Player phase 2: the medic stabilises, the rifleman clears the lane ---
	s = s.end_phase()
	if check:
		assert_eq(s.get_unit(P2).pin, Unit.PinState.DUCKED, "the pinned recruit spends this phase ducked")
		assert_eq(s.get_unit(P2).ap, 0)
		assert_eq(s.get_unit(P4).bleed_rounds_left, RulesConstants.BLEED_ROUNDS - 1, "a round has passed")
		assert_true(s.get_unit(D_NEAR).broken, "the Watch is still loaded, so it simply breaks again")
		assert_eq(s.get_unit(D_NEAR).break_phases_left, 1, "a fresh break, not the old one")
		assert_false(_do_would_pass(s, MoveCommand.new(P2, Vector3i(3, 5, 0))), "and a ducked unit cannot act")
	s = _do(s, MoveCommand.new(P3, Vector3i(3, 3, 0)))
	s = _do(s, InteractCommand.new(P3, Vector3i(2, 4, 0), InteractCommand.Kind.TRAUMA_KIT))
	if check:
		assert_true(s.get_unit(P4).bleed_stabilized, "the clock has stopped")
	var clock := s.get_unit(P4).bleed_rounds_left
	s = _do(s, ShootCommand.new(P1, D_FAR_A))
	s = _do(s, ShootCommand.new(P1, D_FAR_B))
	if check:
		assert_true(s.get_unit(D_FAR_A).bleeding and s.get_unit(D_FAR_B).bleeding, "a rifle drops in one hit")
		assert_true(s.get_unit(D_NEAR).is_active() and s.get_unit(D_NEAR).broken, "nobody holds the street: one is down, one is broken")

	## --- A quiet enemy phase, then the way out ---
	s = s.end_phase()
	s = s.end_phase()
	if check:
		assert_eq(s.get_unit(P2).pin, Unit.PinState.NONE, "the duck has cleared")
		assert_eq(s.get_unit(P4).bleed_rounds_left, clock, "stabilised: the clock did not move across two more rounds")
	s = _do(s, MoveCommand.new(P2, Vector3i(1, 4, 0)))
	s = _do(s, MoveCommand.new(P3, Vector3i(1, 3, 0)))
	s = _do(s, MoveCommand.new(P1, Vector3i(1, 5, 0)))
	for id in [P1, P2, P3]:
		s = _do(s, ExtractCommand.new(id))

	if check:
		for id in [P1, P2, P3]:
			assert_true(s.get_unit(id).extracted, "unit %d is off the map" % id)
		var wounded := s.get_unit(P4)
		assert_false(wounded.extracted, "walking does not extract the wounded (MEDEVAC, GDD §8.5)")
		assert_false(_do_would_pass(s, ExtractCommand.new(P4)))
		assert_true(wounded.bleeding and wounded.bleed_stabilized and not wounded.dead, "alive, down, clock stopped, awaiting MEDEVAC")
		assert_eq(wounded.bleed_rounds_left, clock)
	return s


func _do_would_pass(state: CombatState, cmd: Command) -> bool:
	return cmd.validate(state).ok


func test_the_scripted_fight() -> void:
	_play(true)


func test_the_scripted_fight_is_deterministic() -> void:
	assert_eq(_snapshot(_play(false)), _snapshot(_play(false)), "same commands, same fight, twice")


func test_opening_is_the_shared_fixture() -> void:
	## Plan 2.6: view and test must not rebuild the street by hand.
	var s := ScriptedFight.opening()
	assert_eq(s.map.water_step, Taxonomy.WaterStep.DRY)
	assert_eq(s.get_unit(P1).cell, Vector3i(5, 3, 0))
	assert_eq(s.get_unit(P1).weapon, Taxonomy.WeaponClass.RIFLE)
	assert_true(s.get_unit(P1).adapted)
	assert_true(s.get_unit(P3).has_trauma_kit)
	assert_eq(s.get_unit(D_NEAR).cell, Vector3i(9, 4, 0))
	assert_eq(s.extract_cells.size(), 3)
	assert_false(s.in_contact)
