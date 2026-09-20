extends GutTest

## Free movement until contact, phases after (plan §1.6, GDD §3.1, UI §7). The four degenerate reads
## from UI §7 are the rule's real specification, so they are tested directly.

const PLAYER := Taxonomy.Faction.PLAYER
const DRIFTER := Taxonomy.Faction.DRIFTER
const NEUTRAL := Taxonomy.Faction.NEUTRAL
const PISTOL := Taxonomy.WeaponClass.PISTOL
const RIFLE := Taxonomy.WeaponClass.RIFLE


func _map(x1 := 9, y1 := 4) -> BowlMap:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	for x in range(0, x1 + 1):
		for y in range(0, y1 + 1):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	return map


func _u(id: int, cell: Vector3i, faction: Taxonomy.Faction, weapon: Taxonomy.WeaponClass = PISTOL) -> Unit:
	return Unit.new(id, cell, faction, weapon)


## Squad mode: not in contact.
func _walk(map: BowlMap, units: Array) -> CombatState:
	var state := CombatState.new()
	state.map = map
	for u in units:
		state.add_unit(u)
	return state


## --- Seeing is never contact, and the squad's own line never starts a fight ---


func test_the_squads_own_line_never_starts_a_fight() -> void:
	## P (rifle) can see H through the plank; H (pistol) cannot see P. One-sided on purpose.
	var map := _map()
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.PLANK))
	var p := _u(1, Vector3i(0, 0, 0), PLAYER, RIFLE)
	var h := _u(10, Vector3i(5, 0, 0), DRIFTER, PISTOL)
	var state := _walk(map, [p, h])
	assert_true(Contact.is_live(map, state, h), "precondition: the squad can see it")
	assert_eq(state.attackers_of(map, p).size(), 0, "precondition: it cannot see the squad")
	assert_false(Contact.check(map, state).contact, "seeing is never contact")


func test_a_hostile_getting_a_clean_line_is_contact() -> void:
	var map := _map()
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.PLANK))
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), _u(10, Vector3i(5, 0, 0), DRIFTER, RIFLE)])
	var result := Contact.check(map, state)
	assert_true(result.contact, "a rifle punches the plank")
	assert_eq(result.reason, ContactResult.Reason.HOSTILE_LINE)
	assert_eq(result.seer_id, 10)
	assert_eq(result.target_id, 1)


func test_a_downed_hostile_with_a_line_starts_nothing() -> void:
	var map := _map()
	var h := _u(10, Vector3i(5, 0, 0), DRIFTER, RIFLE)
	h.bleeding = true
	assert_false(Contact.check(map, _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), h])).contact)


func test_a_friendly_roof_meeting_is_never_contact() -> void:
	var map := _map()
	var stranger := _u(10, Vector3i(3, 0, 0), NEUTRAL, RIFLE)
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), stranger])
	assert_eq(state.attackers_of(map, state.get_unit(1)).size(), 0, "neutrals are nobody's hostile")
	assert_false(Contact.check(map, state).contact)
	var knock := InteractCommand.new(1, Vector3i(3, 0, 0), InteractCommand.Kind.KNOCK)
	assert_false(knock.apply(state).in_contact, "knocking a friendly roof is a meeting")


func test_contact_check_only_reports() -> void:
	var map := _map()
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), _u(10, Vector3i(5, 0, 0), DRIFTER)])
	assert_true(Contact.check(map, state).contact)
	assert_false(state.in_contact, "check does not start phases; begin does")


func test_phases_begin_with_the_players_side() -> void:
	var state := _walk(_map(), [_u(1, Vector3i(0, 0, 0), PLAYER)])
	state.active_side = CombatState.PhaseSide.ENEMY
	Contact.begin(state)
	assert_true(state.in_contact)
	assert_eq(state.active_side, CombatState.PhaseSide.PLAYER)
	assert_eq(Contact.check(_map(), state).reason, ContactResult.Reason.ALREADY)


## --- Deck versus interior (GDD §3.1, UI §7) ---


func _shelter_scene(flag: int) -> CombatState:
	var map := _map()
	map.set_cell(Vector3i(5, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR, flag))
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), _u(10, Vector3i(5, 0, 0), DRIFTER)])
	assert_eq(state.attackers_of(map, state.get_unit(1)).size(), 1, "precondition: geometrically a clean line")
	return state


func test_circling_a_roof_deck_in_its_occupants_line_is_contact_before_any_knock() -> void:
	var state := _shelter_scene(Taxonomy.CellFlags.DECK)
	assert_true(Contact.sees_out(state.map, state.get_unit(10)))
	assert_true(Contact.check(state.map, state).contact)


func test_people_inside_see_nothing_until_the_knock() -> void:
	var state := _shelter_scene(Taxonomy.CellFlags.INTERIOR)
	assert_false(Contact.sees_out(state.map, state.get_unit(10)))
	assert_false(Contact.check(state.map, state).contact, "a clean line is not a line when you are indoors")
	var knocked := InteractCommand.new(1, Vector3i(5, 0, 0), InteractCommand.Kind.KNOCK).apply(state)
	assert_true(knocked.in_contact, "and then the knock starts it")


func test_surrounding_an_interior_is_legal() -> void:
	var map := _map()
	map.set_cell(Vector3i(5, 2, 0), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.INTERIOR))
	var state := _walk(map, [
		_u(1, Vector3i(0, 0, 0), PLAYER),
		_u(2, Vector3i(0, 1, 0), PLAYER),
		_u(3, Vector3i(0, 3, 0), PLAYER),
		_u(4, Vector3i(0, 4, 0), PLAYER),
		_u(10, Vector3i(5, 2, 0), DRIFTER),
	])
	var ring := {1: Vector3i(4, 2, 0), 2: Vector3i(6, 2, 0), 3: Vector3i(5, 1, 0), 4: Vector3i(5, 3, 0)}
	for id in ring:
		state = FreeMoveCommand.new(id, ring[id]).apply(state)
		assert_eq(state.get_unit(id).cell, ring[id], "unit %d reached its side of the building" % id)
	assert_false(state.in_contact, "the whole squad stands around it and nothing has started")
	for id in ring:
		assert_eq(state.attackers_of(map, state.get_unit(id)).size(), 1, "precondition: each has a geometric line")


## --- Acting starts contact ---


func test_knocking_a_shelter_with_a_hostile_in_it_starts_contact() -> void:
	var map := _map()
	map.set_cell(Vector3i(3, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.INTERIOR))
	var state := _walk(map, [_u(1, Vector3i(2, 0, 0), PLAYER), _u(10, Vector3i(3, 0, 0), DRIFTER)])
	var next := InteractCommand.new(1, Vector3i(3, 0, 0), InteractCommand.Kind.KNOCK).apply(state)
	assert_true(next.in_contact)
	assert_eq(next.active_side, CombatState.PhaseSide.PLAYER)
	assert_false(state.in_contact, "the state it was applied to is untouched")


func test_knocking_an_empty_shelter_is_a_quiet_night() -> void:
	var map := _map()
	map.set_cell(Vector3i(3, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.SHELTER))
	var state := _walk(map, [_u(1, Vector3i(2, 0, 0), PLAYER)])
	assert_false(InteractCommand.new(1, Vector3i(3, 0, 0), InteractCommand.Kind.KNOCK).apply(state).in_contact)


func test_the_player_firing_starts_contact() -> void:
	var map := _map()
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), _u(10, Vector3i(4, 0, 0), DRIFTER)])
	var next := ShootCommand.new(1, 10).apply(state)
	assert_true(next.in_contact)
	assert_false(state.in_contact)


func test_starting_a_machine_on_a_tile_with_a_live_hostile_is_contact() -> void:
	var map := _map()
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), _u(10, Vector3i(4, 0, 0), DRIFTER)])
	var start := InteractCommand.new(1, Vector3i(4, 0, 0), InteractCommand.Kind.MACHINE)
	assert_true(Contact.is_live(map, state, state.get_unit(10)), "precondition: the squad can see it")
	assert_true(start.apply(state).in_contact)


func test_starting_a_machine_nobody_is_standing_at_is_not() -> void:
	var map := _map()
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), _u(10, Vector3i(8, 4, 0), DRIFTER)])
	assert_false(InteractCommand.new(1, Vector3i(4, 0, 0), InteractCommand.Kind.MACHINE).apply(state).in_contact)


func test_a_hostile_the_squad_cannot_see_does_not_make_a_machine_contested() -> void:
	var map := _map()
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), _u(10, Vector3i(4, 0, 0), DRIFTER)])
	assert_false(Contact.is_live(map, state, state.get_unit(10)), "precondition: walled off")
	assert_false(InteractCommand.new(1, Vector3i(4, 0, 0), InteractCommand.Kind.MACHINE).apply(state).in_contact)


## --- Walking ---


func test_free_movement_costs_no_ap_and_triggers_no_watch() -> void:
	var map := _map()
	var h := _u(10, Vector3i(9, 4, 0), NEUTRAL)
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), h])
	var watcher := _u(11, Vector3i(3, 0, 0), NEUTRAL, RIFLE)
	state.add_unit(watcher)
	state.add_watch(LiveWatch.new(11, Vector3i(-1, 0, 0)))
	var next := FreeMoveCommand.new(1, Vector3i(4, 0, 0)).apply(state)
	assert_eq(next.get_unit(1).cell, Vector3i(4, 0, 0))
	assert_eq(next.get_unit(1).ap, RulesConstants.AP_POOL, "walking is free")
	assert_eq(next.get_unit(1).hp, RulesConstants.HP_PIPS)


func test_the_squad_stops_on_the_tile_where_a_hostile_first_gets_a_line() -> void:
	## A wall across rows 0-1 hides H from the west. Walk the long way round and phases begin on the first
	## tile H can see, not at the destination.
	var map := _map()
	map.set_cell(Vector3i(3, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	map.set_cell(Vector3i(3, 1, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var p := _u(1, Vector3i(0, 0, 0), PLAYER)
	var h := _u(10, Vector3i(6, 0, 0), DRIFTER)
	var state := _walk(map, [p, h])
	var dest := Vector3i(8, 3, 0)
	var route := Movement.path(map, state, p, dest).cells
	var first_line := -1
	for i in range(1, route.size()):
		if Los.line_of_sight(map, h.cell, route[i], h.weapon).clean:
			first_line = i
			break
	assert_gt(first_line, 1, "precondition: the walk starts hidden")
	assert_lt(first_line, route.size() - 1, "precondition: and is caught before it arrives")

	var next := FreeMoveCommand.new(1, dest).apply(state)
	assert_true(next.in_contact)
	assert_eq(next.get_unit(1).cell, route[first_line], "stopped on the first tile with a line")
	assert_ne(next.get_unit(1).cell, dest)
	assert_eq(next.active_side, CombatState.PhaseSide.PLAYER)


func test_walking_stops_being_free_once_phases_have_started() -> void:
	var state := _walk(_map(), [_u(1, Vector3i(0, 0, 0), PLAYER)])
	state.in_contact = true
	assert_false(FreeMoveCommand.new(1, Vector3i(2, 0, 0)).validate(state).ok)


func test_only_the_squad_walks_freely() -> void:
	var state := _walk(_map(), [_u(10, Vector3i(0, 0, 0), DRIFTER)])
	assert_false(FreeMoveCommand.new(10, Vector3i(2, 0, 0)).validate(state).ok)


func test_walking_cannot_pass_through_a_standing_body() -> void:
	var map := _map(4, 0)
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), _u(2, Vector3i(2, 0, 0), PLAYER)])
	assert_false(FreeMoveCommand.new(1, Vector3i(4, 0, 0)).validate(state).ok)


## --- Extract ---


func _boat_scene() -> CombatState:
	var map := _map()
	var state := _walk(map, [_u(1, Vector3i(0, 0, 0), PLAYER), _u(2, Vector3i(1, 0, 0), PLAYER)])
	state.in_contact = true
	state.extract_cells = [Vector3i(0, 0, 0)] as Array[Vector3i]
	return state


func test_a_unit_on_an_extract_tile_leaves_the_map() -> void:
	var state := _boat_scene()
	var next := ExtractCommand.new(1).apply(state)
	assert_true(next.get_unit(1).extracted)
	assert_false(next.get_unit(1).is_active())
	assert_false(state.get_unit(1).extracted, "the original is untouched")


func test_extracting_needs_an_extract_tile() -> void:
	assert_false(ExtractCommand.new(2).validate(_boat_scene()).ok)


func test_a_downed_unit_is_not_extracted_by_walking() -> void:
	## Getting the wounded off the map is MEDEVAC (GDD §8.5), a table-scale matter.
	var state := _boat_scene()
	state.get_unit(1).bleeding = true
	assert_false(ExtractCommand.new(1).validate(state).ok)


func test_an_extracted_unit_is_nobodys_gun_friend_or_obstacle() -> void:
	var map := _map()
	var state := _boat_scene()
	state.add_unit(_u(10, Vector3i(5, 0, 0), DRIFTER))
	var next := ExtractCommand.new(1).apply(state)
	var gone := next.get_unit(1)
	assert_false(gone in next.hostiles_of(next.get_unit(10)), "not a target")
	var ids: Array = []
	for a in next.attackers_of(map, next.get_unit(10)):
		ids.append(a.id)
	assert_eq(ids, [2], "only the unit still on the map has a line on it")
	assert_eq(BreakRule.friends_near(next, next.get_unit(2)), 1, "not a friend in the count")
	assert_true(Movement.is_free(map, next, Vector3i(0, 0, 0), next.get_unit(2)), "and the tile is clear")
