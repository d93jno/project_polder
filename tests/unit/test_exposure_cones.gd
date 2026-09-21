extends GutTest

## Exposure and cone unit cases (plan §1.3).


func _state_with(units: Array) -> CombatState:
	var state := CombatState.new()
	for unit in units:
		state.add_unit(unit)
	return state


func test_hidden_when_no_hostile_line() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.FLOODED
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var enemy := Unit.new(2, Vector3i(5, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var exp := ExposureQuery.exposure(map, _state_with([player, enemy]), player)
	assert_eq(exp.state, Exposure.State.HIDDEN)
	assert_eq(exp.count, 0)
	assert_eq(exp.sources.size(), 0)


func test_exposed_count_and_sources() -> void:
	var map := BowlMap.new()
	for x in range(0, 5):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.RIFLE)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	var state := _state_with([player, enemy])
	state.map = map
	state.knowledge.peel(map, state)
	var exp := ExposureQuery.exposure(map, state, player)
	assert_eq(exp.state, Exposure.State.EXPOSED)
	assert_eq(exp.count, 1)
	assert_eq(exp.sources.size(), 1)
	assert_eq(exp.sources[0], enemy.cell)


func test_hidden_watcher_gap_count_exceeds_sources() -> void:
	## Earshot gap (plan 04 §4.3): scout peels the shooter Live; near locates; far does not.
	var map := BowlMap.new()
	for x in range(0, 11):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(4, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var near := Unit.new(1, Vector3i(2, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var scout := Unit.new(2, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var far := Unit.new(3, Vector3i(8, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var enemy := Unit.new(10, Vector3i(1, 0, 0), Taxonomy.Faction.VANGUARD, Taxonomy.WeaponClass.RIFLE)
	var state := _state_with([near, scout, far, enemy])
	state.map = map
	state.knowledge.peel(map, state)
	assert_eq(state.knowledge.own_sight(2, enemy.cell), Knowledge.CellSight.LIVE)
	assert_eq(state.knowledge.own_sight(3, enemy.cell), Knowledge.CellSight.UNKNOWN)
	assert_true(Comms.shares(state, near, scout))
	assert_false(Comms.shares(state, far, scout))
	## Near is under the rifle and locates via own/earshot Live.
	var exp_near := ExposureQuery.exposure(map, state, near)
	assert_eq(exp_near.count, 1)
	assert_eq(exp_near.sources.size(), 1)
	## Far is not under that gun (wall); merged knowledge still lacks the scout's peel.
	var exp_far := ExposureQuery.exposure(map, state, far)
	assert_eq(exp_far.count, 0)
	assert_eq(state.knowledge.merged_sight(state, far, enemy.cell), Knowledge.CellSight.UNKNOWN)
	assert_eq(state.knowledge.merged_sight(state, near, enemy.cell), Knowledge.CellSight.LIVE)


func test_plank_no_longer_hides_a_located_source() -> void:
	## The 4.1 plank shift: eyes see over soft cover, so locate follows sight after peel.
	var map := BowlMap.new()
	for x in range(0, 5):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.PLANK))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.VANGUARD, Taxonomy.WeaponClass.RIFLE)
	var state := _state_with([player, enemy])
	state.map = map
	state.knowledge.peel(map, state)
	var exp := ExposureQuery.exposure(map, state, player)
	assert_eq(exp.count, 1)
	assert_eq(exp.sources.size(), 1, "plank does not hide a shooter the squad can see over")
	assert_eq(exp.sources[0], enemy.cell)


func test_no_hide_on_falling() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.FALLING
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var exp := ExposureQuery.exposure(map, _state_with([player]), player)
	assert_eq(exp.state, Exposure.State.NO_HIDE)
	assert_eq(exp.count, 0)


func test_no_hide_on_open_dry() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var exp := ExposureQuery.exposure(map, _state_with([player]), player)
	assert_eq(exp.state, Exposure.State.NO_HIDE)


func test_shelter_on_dry_can_hide() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.SHELTER))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var exp := ExposureQuery.exposure(map, _state_with([player]), player)
	assert_eq(exp.state, Exposure.State.HIDDEN)


func test_cone_forward_wedge_and_los() -> void:
	var map := BowlMap.new()
	var cells := Cones.cone(map, Vector3i(0, 0, 0), Vector3i(1, 0, 0), Taxonomy.WeaponClass.PISTOL)
	assert_true(Vector3i(1, 0, 0) in cells)
	assert_true(Vector3i(2, 0, 0) in cells)
	assert_true(Vector3i(2, 1, 0) in cells, "45° edge of 90° wedge")
	assert_false(Vector3i(-1, 0, 0) in cells, "behind watcher")
	assert_false(Vector3i(0, 2, 0) in cells, "pure lateral not in forward wedge")


func test_cone_blocked_by_masonry() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var cells := Cones.cone(map, Vector3i(0, 0, 0), Vector3i(1, 0, 0), Taxonomy.WeaponClass.PISTOL)
	assert_true(Vector3i(1, 0, 0) in cells)
	assert_false(Vector3i(3, 0, 0) in cells, "cells behind masonry are not in the cone")


func test_cone_from_smoke_still_has_volume() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.SMOKE))
	var cells := Cones.cone(map, Vector3i(0, 0, 0), Vector3i(1, 0, 0), Taxonomy.WeaponClass.RIFLE)
	assert_gt(cells.size(), 0, "hidden watcher still throws a cone (UI §4.4)")


func test_apex_unknown_when_watcher_in_smoke() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(4, 0, 0), Cell.new(Taxonomy.CoverMaterial.SMOKE))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.RIFLE)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE)
	var state := _state_with([player, enemy])
	var volume := Cones.watch_cone(map, state, enemy, Vector3i(-1, 0, 0), Taxonomy.Faction.PLAYER)
	assert_gt(volume.cells.size(), 0)
	assert_false(volume.apex_known, "smoke hides the apex")


func test_cone_stack_names_count_and_classes() -> void:
	var map := BowlMap.new()
	var a := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE, Vector3i(1, 0, 0))
	var b := Unit.new(2, Vector3i(0, 2, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL, Vector3i(1, 0, 0))
	var state := _state_with([a, b])
	state.add_watch(LiveWatch.new(1, Vector3i(1, 0, 0)))
	state.add_watch(LiveWatch.new(2, Vector3i(1, 0, 0)))
	var target := Vector3i(3, 1, 0)
	## Ensure target sits in both wedges with clean air.
	var stack := Cones.cone_stack(map, state, target)
	assert_eq(stack.count, 2)
	assert_eq(stack.classes.size(), 2)
	assert_true(Taxonomy.WeaponClass.RIFLE in stack.classes)
	assert_true(Taxonomy.WeaponClass.PISTOL in stack.classes)


func test_spent_watch_excluded_from_stack() -> void:
	var map := BowlMap.new()
	var enemy := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE)
	var state := _state_with([enemy])
	state.add_watch(LiveWatch.new(1, Vector3i(1, 0, 0), true))
	var stack := Cones.cone_stack(map, state, Vector3i(2, 0, 0))
	assert_eq(stack.count, 0)


## --- Bleeders are filtered everywhere (plan §1.5.1) ---


func _duel() -> Array:
	## Player pistol at the origin, Drifter rifle 4 tiles east, open air between.
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE)
	return [player, enemy, _state_with([player, enemy])]


func test_downed_hostile_is_not_a_gun_on_you() -> void:
	var map := BowlMap.new()
	var duel := _duel()
	var player: Unit = duel[0]
	var enemy: Unit = duel[1]
	var state: CombatState = duel[2]
	assert_eq(ExposureQuery.exposure(map, state, player).count, 1, "standing rifleman is a gun")

	state.apply_damage(enemy, RulesConstants.HP_PIPS) ## rifle-class drop: Bleeding Out
	assert_true(enemy.bleeding)
	var exp := ExposureQuery.exposure(map, state, player)
	assert_eq(exp.count, 0, "a bleeder cannot fire, so exposure falls by one")
	assert_eq(exp.sources.size(), 0)
	assert_ne(exp.state, Exposure.State.EXPOSED)
	assert_eq(state.attackers_of(map, player).size(), 0)
	assert_false(enemy in state.hostiles_of(player), "hostiles_of returns standing units only")


func test_stabilising_does_not_bring_the_gun_back() -> void:
	## A stabilised unit is still down (GDD §5.5).
	var map := BowlMap.new()
	var duel := _duel()
	var player: Unit = duel[0]
	var enemy: Unit = duel[1]
	var state: CombatState = duel[2]
	state.apply_damage(enemy, RulesConstants.HP_PIPS)
	enemy.bleed_stabilized = true
	assert_eq(ExposureQuery.exposure(map, state, player).count, 0)


func test_dead_hostile_is_not_a_gun_either() -> void:
	var map := BowlMap.new()
	var duel := _duel()
	var player: Unit = duel[0]
	var state: CombatState = duel[2]
	(duel[1] as Unit).dead = true
	assert_eq(ExposureQuery.exposure(map, state, player).count, 0)


func test_a_bleeder_does_not_hide_the_standing_gun_beside_it() -> void:
	var map := BowlMap.new()
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var downed := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE)
	var standing := Unit.new(3, Vector3i(0, 4, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	var state := _state_with([player, downed, standing])
	state.apply_damage(downed, RulesConstants.HP_PIPS)
	var attackers := state.attackers_of(map, player)
	assert_eq(attackers.size(), 1)
	assert_eq(attackers[0].id, 3)
	assert_eq(ExposureQuery.exposure(map, state, player).count, 1)


## --- attackers_of returns the bodies ---


func test_attackers_are_the_hostiles_with_a_clean_line_only() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(0, 6, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var open := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	var walled := Unit.new(3, Vector3i(0, 8, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	var friend := Unit.new(4, Vector3i(0, 2, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.RIFLE)
	var state := _state_with([player, open, walled, friend])
	var ids: Array = []
	for a in state.attackers_of(map, player):
		ids.append(a.id)
	assert_eq(ids, [2], "masonry blocks one hostile; a friend is never an attacker")


func test_attackers_count_equals_exposure_count() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.PLANK))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var rifle := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.VANGUARD, Taxonomy.WeaponClass.RIFLE)
	var pistol := Unit.new(3, Vector3i(0, 3, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	var state := _state_with([player, rifle, pistol])
	assert_eq(state.attackers_of(map, player).size(), ExposureQuery.exposure(map, state, player).count)
	assert_eq(state.attackers_of(map, player).size(), 2, "rifle punches the plank; pistol has open air")


## --- cone_stack faction filter ---


func _crossfire() -> Array:
	## Drifter rifle Watch and player rifle Watch, both covering the same target tile.
	var map := BowlMap.new()
	var hostile := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE, Vector3i(1, 0, 0))
	var friendly := Unit.new(2, Vector3i(0, 2, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL, Vector3i(1, 0, 0))
	var state := _state_with([hostile, friendly])
	state.add_watch(LiveWatch.new(1, Vector3i(1, 0, 0)))
	state.add_watch(LiveWatch.new(2, Vector3i(1, 0, 0)))
	return [map, state, Vector3i(3, 1, 0)]


func test_cone_stack_unfiltered_counts_every_live_watch() -> void:
	var c := _crossfire()
	var stack := Cones.cone_stack(c[0], c[1], c[2])
	assert_eq(stack.count, 2, "the overlay read (UI §4.4) still shows every cone")


func test_cone_stack_filtered_counts_only_watches_hostile_to_that_faction() -> void:
	var c := _crossfire()
	var against_player := Cones.cone_stack(c[0], c[1], c[2], Taxonomy.Faction.PLAYER)
	assert_eq(against_player.count, 1, "only the Drifter's Watch is hostile to the player")
	assert_eq(against_player.classes, [Taxonomy.WeaponClass.RIFLE])

	var against_drifter := Cones.cone_stack(c[0], c[1], c[2], Taxonomy.Faction.DRIFTER)
	assert_eq(against_drifter.count, 1, "and only the player's is hostile to a Drifter")
	assert_eq(against_drifter.classes, [Taxonomy.WeaponClass.PISTOL])

	var against_neutral := Cones.cone_stack(c[0], c[1], c[2], Taxonomy.Faction.NEUTRAL)
	assert_eq(against_neutral.count, 0, "nobody is hostile to a neutral")


func test_cone_stack_filter_still_skips_spent_watches() -> void:
	var c := _crossfire()
	(c[1] as CombatState).spend_watch(1)
	assert_eq(Cones.cone_stack(c[0], c[1], c[2], Taxonomy.Faction.PLAYER).count, 0)


## GDD 5.8: above the water is dry ground. There is no dive there, so hiding is as on Dry: only
## shelter or an interior hides a unit.
func test_a_roof_over_a_flooded_street_has_no_hide_unless_sheltered() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.FLOODED
	map.water_z = 0
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(0, 0, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	map.set_cell(Vector3i(1, 0, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.SHELTER))
	var swimmer := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var on_roof := Unit.new(2, Vector3i(0, 0, 1), Taxonomy.Faction.PLAYER)
	var under_cover := Unit.new(3, Vector3i(1, 0, 1), Taxonomy.Faction.PLAYER)
	var state := _state_with([swimmer, on_roof, under_cover])
	assert_eq(ExposureQuery.exposure(map, state, swimmer).state, Exposure.State.HIDDEN, "the swimmer can dive")
	assert_eq(ExposureQuery.exposure(map, state, on_roof).state, Exposure.State.NO_HIDE, "an open roof is open")
	assert_eq(ExposureQuery.exposure(map, state, under_cover).state, Exposure.State.HIDDEN, "shelter hides, as on Dry")


func test_a_roof_over_falling_water_reads_the_same_as_over_flooded() -> void:
	## The step changes nothing above the water.
	for step in [Taxonomy.WaterStep.FLOODED, Taxonomy.WaterStep.FALLING, Taxonomy.WaterStep.MUD]:
		var map := BowlMap.new()
		map.water_step = step
		map.water_z = 0
		map.set_cell(Vector3i(0, 0, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
		var on_roof := Unit.new(1, Vector3i(0, 0, 1), Taxonomy.Faction.PLAYER)
		assert_eq(
			ExposureQuery.exposure(map, _state_with([on_roof]), on_roof).state, Exposure.State.NO_HIDE,
			"open roof at %s" % Taxonomy.WaterStep.keys()[step]
		)
