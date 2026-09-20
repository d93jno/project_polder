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
