extends GutTest

## Break: the four defined terms, the clauses, and landing (plan §1.6, GDD §5.5 as of 1.9).
## Every geometry asserts its own preconditions, so a mis-placed tile fails loudly here instead of
## letting a test pass for the wrong reason.

const PLAYER := Taxonomy.Faction.PLAYER
const DRIFTER := Taxonomy.Faction.DRIFTER
const PISTOL := Taxonomy.WeaponClass.PISTOL
const RIFLE := Taxonomy.WeaponClass.RIFLE


func _map(step: Taxonomy.WaterStep = Taxonomy.WaterStep.DRY, x0 := -2, x1 := 8, y0 := -2, y1 := 6) -> BowlMap:
	var map := BowlMap.new()
	map.water_step = step
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	return map


func _u(id: int, cell: Vector3i, faction: Taxonomy.Faction, weapon: Taxonomy.WeaponClass = PISTOL) -> Unit:
	return Unit.new(id, cell, faction, weapon)


## Phases have started: break is a combat state.
func _fight(map: BowlMap, units: Array) -> CombatState:
	var state := CombatState.new()
	state.map = map
	state.in_contact = true
	for u in units:
		state.add_unit(u)
	return state


func _check(state: CombatState, unit: Unit) -> BreakRule.Result:
	return BreakRule.check(state.map, state, unit)


## --- friends ---


func test_who_is_a_friend() -> void:
	## Friends: the same faction, or any two non-player, non-neutral factions. Neutrals are nobody's.
	var F := Taxonomy.Faction
	assert_true(CombatState.is_friend(F.PLAYER, F.PLAYER))
	assert_false(CombatState.is_friend(F.PLAYER, F.DRIFTER))
	assert_false(CombatState.is_friend(F.PLAYER, F.NEUTRAL))
	assert_true(CombatState.is_friend(F.DRIFTER, F.DRIFTER))
	assert_true(CombatState.is_friend(F.DRIFTER, F.WAKE_RIDER), "the enemy fights as one side")
	assert_true(CombatState.is_friend(F.VANGUARD, F.PURIFIER))
	assert_false(CombatState.is_friend(F.DRIFTER, F.NEUTRAL), "a stranger on a roof is not on the Drifters' side")
	assert_false(CombatState.is_friend(F.NEUTRAL, F.DRIFTER))
	assert_false(CombatState.is_friend(F.NEUTRAL, F.NEUTRAL), "neutrals are not each other's friends either")


func test_a_neutral_beside_an_enemy_does_not_protect_it() -> void:
	var map := _map()
	var d := _u(10, Vector3i(0, 0, 0), DRIFTER)
	var stranger := _u(11, Vector3i(1, 0, 0), Taxonomy.Faction.NEUTRAL)
	var state := _fight(map, [d, stranger, _u(1, Vector3i(5, 0, 0), PLAYER), _u(2, Vector3i(0, 5, 0), PLAYER)])
	assert_eq(state.attackers_of(map, d).size(), 2, "precondition: two guns on the Drifter")
	assert_eq(BreakRule.friends_near(state, d), 1, "only itself: the stranger is nobody's friend")
	assert_true(BreakRule.outnumbered(map, state, d))


## --- outnumbered ---


func test_two_guns_against_one_friend_beside_you_is_not_outnumbered() -> void:
	var map := _map()
	var b := _u(1, Vector3i(0, 0, 0), PLAYER)
	var friend := _u(2, Vector3i(1, 0, 0), PLAYER)
	var state := _fight(map, [b, friend, _u(10, Vector3i(5, 0, 0), DRIFTER), _u(11, Vector3i(0, 5, 0), DRIFTER)])
	assert_eq(state.attackers_of(map, b).size(), 2, "precondition: two guns on B")
	assert_eq(BreakRule.friends_near(state, b), 2, "B and the friend beside it")
	assert_false(BreakRule.outnumbered(map, state, b))


func test_the_same_fight_with_the_friend_five_tiles_away_is_outnumbered() -> void:
	var map := _map(Taxonomy.WaterStep.DRY, -6, 8, -6, 6)
	var b := _u(1, Vector3i(0, 0, 0), PLAYER)
	var friend := _u(2, Vector3i(0, -5, 0), PLAYER)
	var state := _fight(map, [b, friend, _u(10, Vector3i(5, 0, 0), DRIFTER), _u(11, Vector3i(0, 5, 0), DRIFTER)])
	assert_eq(state.attackers_of(map, b).size(), 2)
	assert_eq(BreakRule.friends_near(state, b), 1, "the friend is outside the radius")
	assert_true(BreakRule.outnumbered(map, state, b))


func test_the_friend_radius_is_measured_in_tiles_diagonals_included() -> void:
	## Chebyshev: a friend three tiles away on a diagonal is within 3 (Manhattan would say 6). At the
	## edge of the radius counts, one tile past it does not.
	var map := _map(Taxonomy.WaterStep.DRY, -6, 8, -6, 6)
	var b := _u(1, Vector3i(0, 0, 0), PLAYER)
	var diagonal := _u(2, Vector3i(3, 3, 0), PLAYER)
	var just_out := _u(3, Vector3i(4, 0, 0), PLAYER)
	var state := _fight(map, [b, diagonal, just_out])
	assert_eq(BreakRule.chebyshev(b.cell, diagonal.cell), 3, "precondition")
	assert_eq(BreakRule.friends_near(state, b), 2, "B and the diagonal friend; the tile-four friend is out")


func test_the_calls_radius_is_measured_the_same_way() -> void:
	var founder := _u(2, Vector3i(2, 2, 0), PLAYER)
	founder.is_founder = true
	var state := _fight(_map(), [_u(1, Vector3i(0, 0, 0), PLAYER), founder])
	assert_eq(BreakRule.chebyshev(Vector3i(0, 0, 0), founder.cell), RulesConstants.CALL_RADIUS, "precondition: exactly on the edge")
	assert_true(BreakRule.in_the_call(state, state.get_unit(1)), "a diagonal edge counts")
	founder.cell = Vector3i(3, 0, 0)
	assert_false(BreakRule.in_the_call(state, state.get_unit(1)), "one past the edge does not")


func test_a_downed_friend_adds_nothing() -> void:
	var map := _map()
	var b := _u(1, Vector3i(0, 0, 0), PLAYER)
	var friend := _u(2, Vector3i(1, 0, 0), PLAYER)
	var state := _fight(map, [b, friend, _u(10, Vector3i(5, 0, 0), DRIFTER), _u(11, Vector3i(0, 5, 0), DRIFTER)])
	friend.bleeding = true
	assert_eq(BreakRule.friends_near(state, b), 1)
	assert_true(BreakRule.outnumbered(map, state, b))


func test_a_downed_hostile_is_not_a_gun() -> void:
	var map := _map()
	var b := _u(1, Vector3i(0, 0, 0), PLAYER)
	var state := _fight(map, [b, _u(10, Vector3i(5, 0, 0), DRIFTER), _u(11, Vector3i(0, 5, 0), DRIFTER)])
	state.get_unit(11).bleeding = true
	assert_eq(state.attackers_of(map, b).size(), 1)
	assert_false(BreakRule.outnumbered(map, state, b), "one gun against B itself")


## --- in the open ---


## H at (6,0), a plank at (4,0), B at (2,3). The plank shadows a wedge of tiles behind it, diagonals
## included; the nearest hidden tile for B is (2,1), two steps away.
func _plank_scene(hostile_weapon: Taxonomy.WeaponClass, b_ap: int) -> CombatState:
	var map := _map()
	map.set_cell(Vector3i(4, 0, 0), Cell.new(Taxonomy.CoverMaterial.PLANK))
	var b := Unit.new(1, Vector3i(2, 3, 0), PLAYER, PISTOL, Vector3i(1, 0, 0), b_ap)
	return _fight(map, [b, _u(10, Vector3i(6, 0, 0), DRIFTER, hostile_weapon)])


func test_a_plank_does_not_help_against_a_rifle_so_the_unit_is_in_the_open() -> void:
	var state := _plank_scene(RIFLE, 6)
	var b := state.get_unit(1)
	assert_eq(state.attackers_of(state.map, b).size(), 1, "precondition: the rifle has a line")
	assert_true(BreakRule.in_the_open(state.map, state, b))


func test_the_same_plank_against_a_pistol_is_cover_within_reach() -> void:
	var state := _plank_scene(PISTOL, 6)
	var b := state.get_unit(1)
	assert_eq(state.attackers_of(state.map, b).size(), 1, "precondition: the pistol has a line")
	var cover := Vector3i(3, 0, 0)
	assert_false(Los.line_of_sight(state.map, Vector3i(6, 0, 0), cover, PISTOL).clean, "precondition: plank hides (3,0)")
	assert_true(cover in Movement.reachable(state.map, state, b, 6), "precondition: reachable with 6 AP")
	assert_false(BreakRule.in_the_open(state.map, state, b))


func test_spending_ap_until_cover_is_out_of_reach_flips_the_answer() -> void:
	## The nearest cover, (2,1), is 2 steps from B: 1 AP cannot reach it, 2 can.
	var cover := Vector3i(2, 1, 0)
	var short := _plank_scene(PISTOL, 1)
	assert_false(Los.line_of_sight(short.map, Vector3i(6, 0, 0), cover, PISTOL).clean, "precondition: (2,1) is hidden")
	assert_false(cover in Movement.reachable(short.map, short, short.get_unit(1)), "precondition")
	assert_true(BreakRule.in_the_open(short.map, short, short.get_unit(1)), "1 AP: cover is out of reach")
	var enough := _plank_scene(PISTOL, 2)
	assert_true(cover in Movement.reachable(enough.map, enough, enough.get_unit(1)), "precondition")
	assert_false(BreakRule.in_the_open(enough.map, enough, enough.get_unit(1)), "2 AP: cover is in reach")


func test_not_being_shot_at_is_not_being_in_the_open() -> void:
	var map := _map()
	var state := _fight(map, [_u(1, Vector3i(0, 0, 0), PLAYER)])
	assert_false(BreakRule.in_the_open(map, state, state.get_unit(1)), "nobody to be open to")


func test_pinned_does_not_zero_the_ap_for_the_open_test() -> void:
	## apply_pin forfeits the unit's AP, but GDD §5.5 says Pinned must not zero it here (plan §7.4).
	var state := _plank_scene(PISTOL, 6)
	var b := state.get_unit(1)
	state.apply_pin(b)
	assert_eq(b.pin, Unit.PinState.DUCKED)
	assert_eq(b.ap, 0, "precondition: the state machine forfeited the AP")
	assert_false(BreakRule.in_the_open(state.map, state, b), "cover is still within a full phase's reach")
	## Control: the same unit unpinned with no AP left really is in the open.
	var unpinned := _plank_scene(PISTOL, 0)
	assert_true(BreakRule.in_the_open(unpinned.map, unpinned, unpinned.get_unit(1)))


## --- long cone and CQB kit ---


## A rifle Watch at (0,0) facing east; a Drifter (unadapted, pistol) three tiles down the line.
func _cone_scene(step: Taxonomy.WaterStep = Taxonomy.WaterStep.DRY) -> CombatState:
	var map := _map(step)
	var watcher := _u(1, Vector3i(0, 0, 0), PLAYER, RIFLE)
	var drifter := _u(10, Vector3i(3, 0, 0), DRIFTER, PISTOL)
	var state := _fight(map, [watcher, drifter])
	state.add_watch(LiveWatch.new(1, Vector3i(1, 0, 0)))
	return state


func test_a_loaded_long_watch_breaks_an_unadapted_cqb_unit_on_dry() -> void:
	var state := _cone_scene()
	var d := state.get_unit(10)
	assert_true(BreakRule.under_long_cone(state.map, state, d), "precondition")
	assert_true(BreakRule.has_cqb_kit(d))
	assert_eq(_check(state, d), BreakRule.Result.BREAKS)


func test_the_same_rifle_with_no_watch_breaks_no_one() -> void:
	var state := _cone_scene()
	state.watches.clear()
	assert_eq(state.attackers_of(state.map, state.get_unit(10)).size(), 1, "precondition: it still has a line")
	assert_eq(_check(state, state.get_unit(10)), BreakRule.Result.SAFE)


func test_a_spent_watch_does_not_break_anyone() -> void:
	var state := _cone_scene()
	state.spend_watch(1)
	assert_eq(_check(state, state.get_unit(10)), BreakRule.Result.SAFE)


func test_a_short_weapons_watch_does_not_break_anyone() -> void:
	var state := _cone_scene()
	state.get_unit(1).weapon = PISTOL
	assert_eq(_check(state, state.get_unit(10)), BreakRule.Result.SAFE)


func test_clause_three_needs_dry_ground() -> void:
	var state := _cone_scene(Taxonomy.WaterStep.MUD)
	assert_true(BreakRule.under_long_cone(state.map, state, state.get_unit(10)), "precondition")
	assert_eq(_check(state, state.get_unit(10)), BreakRule.Result.SAFE)


func test_an_adapted_unit_does_not_dump_the_street_because_it_is_dry() -> void:
	## A trained Muckraker does not (GDD §5.5).
	var state := _cone_scene()
	state.get_unit(10).adapted = true
	assert_eq(_check(state, state.get_unit(10)), BreakRule.Result.SAFE)


func test_carrying_a_long_gun_is_not_cqb_kit() -> void:
	var state := _cone_scene()
	state.get_unit(10).weapon = RIFLE
	assert_false(BreakRule.has_cqb_kit(state.get_unit(10)))
	assert_eq(_check(state, state.get_unit(10)), BreakRule.Result.SAFE)


func test_a_friendly_long_watch_does_not_frighten_its_own_side() -> void:
	var state := _cone_scene()
	state.get_unit(10).faction = PLAYER
	assert_false(BreakRule.under_long_cone(state.map, state, state.get_unit(10)))


## --- clause 2: pinned and outnumbered in the open ---


func _outnumbered_in_the_open() -> CombatState:
	var map := _map()
	var b := _u(1, Vector3i(0, 0, 0), PLAYER)
	return _fight(map, [b, _u(10, Vector3i(5, 0, 0), DRIFTER), _u(11, Vector3i(0, 5, 0), DRIFTER)])


func test_clause_two_is_a_condition_until_the_unit_is_pinned() -> void:
	var state := _outnumbered_in_the_open()
	var b := state.get_unit(1)
	assert_true(BreakRule.outnumbered(state.map, state, b), "precondition")
	assert_true(BreakRule.in_the_open(state.map, state, b), "precondition")
	assert_eq(_check(state, b), BreakRule.Result.WOULD_BREAK_IF_PINNED, "if hit here, breaks")
	b.pin = Unit.PinState.DUCKED
	assert_eq(_check(state, b), BreakRule.Result.BREAKS)
	b.pin = Unit.PinState.DUCKING_NEXT
	assert_eq(_check(state, b), BreakRule.Result.BREAKS, "either kind of pinned counts")


func test_outnumbered_but_with_cover_in_reach_is_not_a_break() -> void:
	## The plank scene plus a second pistol: two guns on B, B alone, but (2,0) is hidden from both.
	var state := _plank_scene(PISTOL, 6)
	var b := state.get_unit(1)
	state.add_unit(_u(11, Vector3i(6, 1, 0), DRIFTER, PISTOL))
	assert_eq(state.attackers_of(state.map, b).size(), 2, "precondition: both have a line on B")
	assert_true(BreakRule.outnumbered(state.map, state, b), "precondition")
	var cover := Vector3i(2, 0, 0)
	for hostile in state.attackers_of(state.map, b):
		assert_false(Los.line_of_sight(state.map, hostile.cell, cover, PISTOL).clean, "precondition: (2,0) is hidden from %d" % hostile.id)
	assert_false(BreakRule.in_the_open(state.map, state, b))
	b.pin = Unit.PinState.DUCKED
	assert_eq(_check(state, b), BreakRule.Result.SAFE, "pinned and outnumbered, but not in the open")


## --- clause 1: the last friend has dropped ---


func test_the_last_standing_member_of_a_squad_that_has_lost_someone_breaks() -> void:
	var map := _map()
	var a := _u(1, Vector3i(0, 0, 0), PLAYER)
	var b := _u(2, Vector3i(1, 0, 0), PLAYER)
	var state := _fight(map, [a, b])
	assert_eq(_check(state, b), BreakRule.Result.SAFE, "two standing: safe")
	a.bleeding = true
	assert_eq(_check(state, b), BreakRule.Result.BREAKS)
	a.bleeding = false
	a.dead = true
	assert_eq(_check(state, b), BreakRule.Result.BREAKS, "dead counts as dropped")


func test_a_lone_unit_that_never_had_a_squad_has_not_lost_one() -> void:
	var state := _fight(_map(), [_u(1, Vector3i(0, 0, 0), PLAYER)])
	assert_eq(_check(state, state.get_unit(1)), BreakRule.Result.SAFE)


func test_an_extracted_friend_has_not_dropped() -> void:
	var a := _u(1, Vector3i(0, 0, 0), PLAYER)
	var b := _u(2, Vector3i(1, 0, 0), PLAYER)
	var state := _fight(_map(), [a, b])
	a.extracted = true
	assert_eq(_check(state, b), BreakRule.Result.SAFE, "left safely, not dropped")


func test_the_last_unit_out_breaks_when_a_squadmate_was_left_wounded() -> void:
	## Documents a consequence, not an endorsement (plan §7.7): once the others have extracted, the last
	## standing member of a squad that lost someone is "the last friend", so clause 1 applies to it on
	## the way out. Extracting is not a break, but the rule as written does not exempt the boat.
	var a := _u(1, Vector3i(0, 0, 0), PLAYER)
	var b := _u(2, Vector3i(1, 0, 0), PLAYER)
	var c := _u(3, Vector3i(2, 0, 0), PLAYER)
	var state := _fight(_map(), [a, b, c])
	a.bleeding = true
	b.extracted = true
	assert_eq(_check(state, c), BreakRule.Result.BREAKS)


func test_a_standing_friend_anywhere_keeps_the_squad_alive() -> void:
	var a := _u(1, Vector3i(0, 0, 0), PLAYER)
	var b := _u(2, Vector3i(1, 0, 0), PLAYER)
	var c := _u(3, Vector3i(6, 5, 0), PLAYER)
	var state := _fight(_map(), [a, b, c])
	a.bleeding = true
	assert_eq(_check(state, b), BreakRule.Result.SAFE)


func test_the_enemy_side_breaks_the_same_way() -> void:
	var a := _u(10, Vector3i(0, 0, 0), DRIFTER)
	var b := _u(11, Vector3i(1, 0, 0), Taxonomy.Faction.WAKE_RIDER)
	var state := _fight(_map(), [a, b])
	a.bleeding = true
	assert_eq(_check(state, b), BreakRule.Result.BREAKS, "non-player factions fight as one side")


func test_a_downed_unit_does_not_break() -> void:
	var state := _fight(_map(), [_u(1, Vector3i(0, 0, 0), PLAYER), _u(2, Vector3i(1, 0, 0), PLAYER)])
	state.get_unit(1).bleeding = true
	state.get_unit(2).bleeding = true
	assert_eq(_check(state, state.get_unit(2)), BreakRule.Result.SAFE)


## --- Agoraphobia ---


## A trained rifleman with the scar, in the open on Mud, under an enemy rifle's loaded Watch.
func _agoraphobe() -> CombatState:
	var map := _map(Taxonomy.WaterStep.MUD)
	var b := _u(1, Vector3i(3, 0, 0), PLAYER, RIFLE)
	b.adapted = true
	b.give_scar(Taxonomy.Scar.AGORAPHOBIA)
	var sniper := _u(10, Vector3i(0, 0, 0), DRIFTER, RIFLE)
	var state := _fight(map, [b, sniper])
	state.add_watch(LiveWatch.new(10, Vector3i(1, 0, 0)))
	return state


func test_agoraphobia_breaks_a_trained_rifleman_in_the_open_on_mud() -> void:
	var state := _agoraphobe()
	var b := state.get_unit(1)
	assert_true(b.adapted and not BreakRule.has_cqb_kit(b), "precondition: clause 3 alone would not touch them")
	assert_true(BreakRule.under_long_cone(state.map, state, b))
	assert_true(BreakRule.in_the_open(state.map, state, b))
	assert_eq(_check(state, b), BreakRule.Result.BREAKS)


func test_the_same_spot_without_the_scar_is_safe() -> void:
	var state := _agoraphobe()
	state.get_unit(1).scars = 0
	assert_eq(_check(state, state.get_unit(1)), BreakRule.Result.SAFE)


func test_an_agoraphobe_with_cover_in_reach_is_not_in_the_open() -> void:
	var state := _agoraphobe()
	## Masonry stops rifles. It leaves B in the sniper's cone but hides (3,1), one mud step away.
	state.map.set_cell(Vector3i(2, 1, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var b := state.get_unit(1)
	assert_true(BreakRule.under_long_cone(state.map, state, b), "precondition: still under the cone")
	var cover := Vector3i(3, 1, 0)
	assert_false(Los.line_of_sight(state.map, Vector3i(0, 0, 0), cover, RIFLE).clean, "precondition: (3,1) is hidden")
	assert_true(cover in Movement.reachable(state.map, state, b), "precondition: and reachable")
	assert_false(BreakRule.in_the_open(state.map, state, b))
	assert_eq(_check(state, b), BreakRule.Result.SAFE, "the scar needs the open as well as the cone")


func test_agoraphobia_does_not_switch_off_the_plain_clause() -> void:
	## An Agoraphobic *unadapted* CQB unit under a long cone on Dry breaks by clause 3 even if it is
	## not in the open by the scar's route.
	var state := _cone_scene()
	var d := state.get_unit(10)
	d.give_scar(Taxonomy.Scar.AGORAPHOBIA)
	assert_eq(_check(state, d), BreakRule.Result.BREAKS)


## --- The Call ---


func test_the_call_overrides_every_clause_agoraphobia_included() -> void:
	var state := _agoraphobe()
	var b := state.get_unit(1)
	assert_eq(_check(state, b), BreakRule.Result.BREAKS, "precondition")
	var founder := _u(2, Vector3i(4, 0, 0), PLAYER)
	founder.is_founder = true
	state.add_unit(founder)
	assert_true(BreakRule.in_the_call(state, b))
	assert_eq(_check(state, b), BreakRule.Result.SAFE)


func test_a_founder_out_of_range_does_not_help() -> void:
	var state := _agoraphobe()
	var founder := _u(2, Vector3i(3, 5, 0), PLAYER)
	founder.is_founder = true
	state.add_unit(founder)
	assert_false(BreakRule.in_the_call(state, state.get_unit(1)))
	assert_eq(_check(state, state.get_unit(1)), BreakRule.Result.BREAKS)


func test_a_downed_founder_is_no_presence() -> void:
	var state := _agoraphobe()
	var founder := _u(2, Vector3i(4, 0, 0), PLAYER)
	founder.is_founder = true
	founder.bleeding = true
	state.add_unit(founder)
	assert_false(BreakRule.in_the_call(state, state.get_unit(1)))


func test_an_enemy_founder_does_not_protect_the_player() -> void:
	var state := _agoraphobe()
	var other := _u(2, Vector3i(4, 0, 0), DRIFTER)
	other.is_founder = true
	state.add_unit(other)
	assert_false(BreakRule.in_the_call(state, state.get_unit(1)))


func test_the_founder_stands_inside_their_own_call() -> void:
	var state := _agoraphobe()
	var b := state.get_unit(1)
	b.is_founder = true
	assert_true(BreakRule.in_the_call(state, b))


## --- purity ---


func test_check_does_not_mutate_anything() -> void:
	var state := _outnumbered_in_the_open()
	var b := state.get_unit(1)
	b.pin = Unit.PinState.DUCKED
	var before := b.duplicate_unit()
	_check(state, b)
	for prop in b.get_property_list():
		if (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			assert_eq(b.get(prop["name"]), before.get(prop["name"]), "check changed '%s'" % prop["name"])
	assert_false(b.broken, "check reports; only resolve lands a break")
