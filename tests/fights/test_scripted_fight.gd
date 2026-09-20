extends GutTest

## The proof (plan §1.6). One bowl, four bodies: walk until contact, exchange fire, one unit pinned,
## one broken, one bleeding out, extract. Driven entirely through commands and asserted end to end,
## headless. It reads as a description of the fight.
##
## The bowl is a street with a wall across its south half. The squad starts hidden behind the wall.
## The Drifters are in the lane to the east: one close enough to fall inside a rifle's cone, two more
## than a rifle cone's length away, so they can shoot down the lane but are never frightened by it.

const PLAYER := Taxonomy.Faction.PLAYER
const DRIFTER := Taxonomy.Faction.DRIFTER

const P1 := 1 ## trained rifleman, sets the Watch
const P2 := 2 ## raw recruit, gets pinned
const P3 := 3 ## medic with a trauma kit
const P4 := 4 ## raw recruit, goes down
const D_NEAR := 10 ## in the rifle's cone: routs
const D_FAR_A := 11 ## out of the cone: shoots P2
const D_FAR_B := 12 ## out of the cone: shoots P4 twice

const CONTACT_TILE := Vector3i(5, 4, 0)


func _street() -> BowlMap:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	for x in range(0, 17):
		for y in range(0, 6):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	for y in range(0, 4):
		map.set_cell(Vector3i(6, y, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	return map


func _opening() -> CombatState:
	var state := CombatState.new()
	state.map = _street()
	state.extract_cells = [Vector3i(1, 3, 0), Vector3i(1, 4, 0), Vector3i(1, 5, 0)] as Array[Vector3i]
	var p1 := Unit.new(P1, Vector3i(5, 3, 0), PLAYER, Taxonomy.WeaponClass.RIFLE)
	p1.adapted = true
	var p3 := Unit.new(P3, Vector3i(4, 3, 0), PLAYER)
	p3.has_trauma_kit = true
	state.add_unit(p1)
	state.add_unit(Unit.new(P2, Vector3i(3, 3, 0), PLAYER))
	state.add_unit(p3)
	state.add_unit(Unit.new(P4, Vector3i(3, 2, 0), PLAYER))
	state.add_unit(Unit.new(D_NEAR, Vector3i(9, 4, 0), DRIFTER))
	state.add_unit(Unit.new(D_FAR_A, Vector3i(15, 4, 0), DRIFTER))
	state.add_unit(Unit.new(D_FAR_B, Vector3i(15, 5, 0), DRIFTER))
	return state


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
	var opening := _opening()
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
