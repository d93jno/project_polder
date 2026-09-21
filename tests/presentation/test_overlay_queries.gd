extends GutTest

## OverlayQueries must agree with rules/ — the view draws queries only (plan 2.3).

const Queries := preload("res://presentation/overlay_queries.gd")


func test_exposure_count_matches_attackers_of() -> void:
	var map := BowlMap.new()
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE)
	var state := CombatState.new()
	state.add_unit(player)
	state.add_unit(enemy)
	var q = Queries.compute(map, state, 1, Vector3i(1, 0, 0))
	assert_eq(q.exposure.count, state.attackers_of(map, player).size())
	assert_eq(q.exposure.count, 1)


func test_path_shot_reserve_matches_movement() -> void:
	var map := BowlMap.new()
	for x in range(0, 6):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var state := CombatState.new()
	state.add_unit(player)
	state.in_contact = true
	var hover := Vector3i(4, 0, 0)
	var q = Queries.compute(map, state, 1, hover)
	var path := Movement.path(map, state, player, hover)
	assert_true(q.path.reachable)
	assert_eq(q.path.shot_reserve_at, path.shot_reserve_at)
	assert_eq(q.path.watch_reserve_at, path.watch_reserve_at)
	assert_eq(q.path.cells.size(), path.cells.size())


func test_cone_cells_match_cones_cone() -> void:
	var map := BowlMap.new()
	var enemy := Unit.new(2, Vector3i(0, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE)
	var player := Unit.new(1, Vector3i(5, 0, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.add_unit(player)
	state.add_unit(enemy)
	state.add_watch(LiveWatch.new(2, Vector3i(1, 0, 0)))
	var q = Queries.compute(map, state, 1, Vector3i(2, 0, 0))
	assert_eq(q.watches.size(), 1)
	var expected: Array[Vector3i] = Cones.cone(map, enemy.cell, Vector3i(1, 0, 0), enemy.weapon)
	assert_eq(q.watches[0]["cells"], expected)


func test_stack_label_names_count_and_long() -> void:
	var map := BowlMap.new()
	var a := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE)
	var b := Unit.new(2, Vector3i(0, 2, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	var player := Unit.new(9, Vector3i(8, 0, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.add_unit(a)
	state.add_unit(b)
	state.add_unit(player)
	state.add_watch(LiveWatch.new(1, Vector3i(1, 0, 0)))
	state.add_watch(LiveWatch.new(2, Vector3i(1, 0, 0)))
	var target := Vector3i(3, 1, 0)
	var q = Queries.compute(map, state, 9, target)
	var raw := Cones.cone_stack(map, state, target)
	assert_eq(q.stack.count, raw.count)
	assert_eq(q.stack_label, Queries.format_stack(raw))
	assert_true(q.stack_label.contains("2 watches"))
	assert_true(q.stack_label.contains("rifle, long"))
	assert_true(q.stack_label.contains("pistol"))


func test_friendly_cone_full_when_path_crosses() -> void:
	var map := BowlMap.new()
	for x in range(0, 8):
		for y in range(0, 3):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var watcher := Unit.new(1, Vector3i(0, 1, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var mover := Unit.new(2, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var state := CombatState.new()
	state.add_unit(watcher)
	state.add_unit(mover)
	state.in_contact = true
	state.add_watch(LiveWatch.new(1, Vector3i(1, 0, 0)))
	var q = Queries.compute(map, state, 2, Vector3i(5, 0, 0))
	assert_eq(q.watches.size(), 1)
	assert_true(q.path.reachable)
	assert_true(q.watches[0]["full_volume"], "move preview crossing a friendly cone opens the volume")


func test_friendly_cone_outline_when_idle() -> void:
	var map := BowlMap.new()
	var watcher := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var other := Unit.new(2, Vector3i(3, 3, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.add_unit(watcher)
	state.add_unit(other)
	state.add_watch(LiveWatch.new(1, Vector3i(1, 0, 0)))
	var q = Queries.compute(map, state, 2, Vector3i(3, 3, 0))
	assert_eq(q.watches.size(), 1)
	assert_false(q.watches[0]["full_volume"], "unselected friendly watch stays outline")


func test_falling_exposure_word_is_no_hide() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.FALLING
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.add_unit(player)
	var q = Queries.compute(map, state, 1, Vector3i(0, 0, 0))
	assert_eq(Queries.exposure_word(q.exposure), "no hide")
	assert_eq(q.exposure.state, Exposure.State.NO_HIDE)


## --- plan 2.4: path chrome / line / cover stops / shot afford ---


func test_path_cost_and_crossings_match_movement() -> void:
	var map := BowlMap.new()
	for x in range(0, 9):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
		map.set_cell(Vector3i(x, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var w1 := Unit.new(
		10, Vector3i(2, 1, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.SHOTGUN, Vector3i(0, -1, 0)
	)
	var w2 := Unit.new(
		11, Vector3i(6, 1, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.SHOTGUN, Vector3i(0, -1, 0)
	)
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.add_unit(player)
	state.add_unit(w1)
	state.add_unit(w2)
	state.in_contact = true
	state.add_watch(LiveWatch.new(10, Vector3i(0, -1, 0)))
	state.add_watch(LiveWatch.new(11, Vector3i(0, -1, 0)))
	var hover := Vector3i(8, 0, 0)
	var q = Queries.compute(map, state, 1, hover)
	var path := Movement.path(map, state, player, hover)
	assert_true(q.path.reachable)
	assert_eq(q.path.cost_per_cell, path.cost_per_cell)
	assert_eq(q.path.watches_crossed.size(), path.watches_crossed.size())
	assert_eq(q.path.watches_crossed.size(), 2)
	assert_eq(Queries.crossing_label(q.path.watches_crossed[0]), "crosses shotgun")


func test_cover_hover_names_stops() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(1, 0, 0), Cell.new(Taxonomy.CoverMaterial.PLANK))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var state := CombatState.new()
	state.add_unit(player)
	var q = Queries.compute(map, state, 1, Vector3i(1, 0, 0))
	assert_true(q.hover_cover)
	assert_eq(q.cover_stops_label, Queries.format_cover_stops(Taxonomy.CoverMaterial.PLANK))
	assert_true(q.cover_stops_label.contains("pistol"))
	assert_true(q.cover_stops_label.contains("shotgun"))
	assert_false(q.cover_stops_label.contains("rifle"), "soft cover does not stop long")


func test_shot_outcome_pins_and_blocker() -> void:
	var map := BowlMap.new()
	for x in range(0, 5):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER)
	var state := CombatState.new()
	state.add_unit(player)
	state.add_unit(enemy)
	state.knowledge.peel(map, state)
	var clean = Queries.compute(map, state, 1, enemy.cell)
	assert_true(clean.hover_hostile)
	assert_eq(clean.shot_outcome, "pins")
	assert_eq(clean.shot_cost, RulesConstants.shot_cost(Taxonomy.WeaponClass.PISTOL))
	assert_true(clean.shot_affordable)
	assert_false(clean.kills_bleeder)

	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	## Knowledge still Live from the open peel — fog offers the body; the weapon line names the wall.
	var blocked = Queries.compute(map, state, 1, enemy.cell)
	assert_true(blocked.hover_hostile, "still offered while Live in knowledge")
	assert_true(blocked.shot_outcome.begins_with("blocked:"))
	assert_true(blocked.shot_outcome.contains("MASONRY") or blocked.shot_outcome.contains("masonry"))


func test_shot_outcome_kills_bleeder_and_unaffordable() -> void:
	var map := BowlMap.new()
	for x in range(0, 5):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.RIFLE)
	player.ap = 0
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER)
	enemy.bleeding = true
	var state := CombatState.new()
	state.add_unit(player)
	state.add_unit(enemy)
	state.knowledge.peel(map, state)
	var q = Queries.compute(map, state, 1, enemy.cell)
	assert_eq(q.shot_outcome, "kills a bleeder")
	assert_true(q.kills_bleeder)
	assert_eq(q.shot_cost, RulesConstants.shot_cost(Taxonomy.WeaponClass.RIFLE))
	assert_false(q.shot_affordable, "cost stays visible when AP is short")


func test_shot_outcome_drops_to_bleeding() -> void:
	var map := BowlMap.new()
	for x in range(0, 5):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.RIFLE)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER)
	enemy.hp = RulesConstants.HP_PIPS
	var state := CombatState.new()
	state.add_unit(player)
	state.add_unit(enemy)
	state.knowledge.peel(map, state)
	var q = Queries.compute(map, state, 1, enemy.cell)
	assert_eq(q.shot_outcome, "drops to Bleeding Out")


func test_terrace_climb_path_matches_movement() -> void:
	## Plan 3 verification: overlay path cost for a climb equals Movement.path.
	const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")
	var state := FloodedTerrace.opening(Taxonomy.WaterStep.FLOODED)
	state.units.erase(FloodedTerrace.P4)
	var u: Unit = state.get_unit(FloodedTerrace.P1)
	u.cell = Vector3i(4, 4, 0)
	state.in_contact = true
	var dest := FloodedTerrace.ROOF_A
	var q = Queries.compute(state.map, state, FloodedTerrace.P1, dest)
	var path := Movement.path(state.map, state, u, dest)
	assert_true(path.reachable)
	assert_true(q.path.reachable)
	assert_eq(q.path.total_cost, path.total_cost)
	assert_eq(q.path.cells, path.cells)
	assert_eq(
		path.total_cost,
		RulesConstants.MOVE_COST_SWIM
		+ 2 * (RulesConstants.MOVE_COST_SWIM + RulesConstants.MOVE_COST_VERTICAL_SURCHARGE)
	)
