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
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.RIFLE)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL)
	var exp := ExposureQuery.exposure(map, _state_with([player, enemy]), player)
	assert_eq(exp.state, Exposure.State.EXPOSED)
	assert_eq(exp.count, 1)
	assert_eq(exp.sources.size(), 1)
	assert_eq(exp.sources[0], enemy.cell)


func test_hidden_watcher_gap_count_exceeds_sources() -> void:
	## Hostile rifle punches plank; player pistol cannot locate them through it.
	var map := BowlMap.new()
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.PLANK))
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.VANGUARD, Taxonomy.WeaponClass.RIFLE)
	var exp := ExposureQuery.exposure(map, _state_with([player, enemy]), player)
	assert_eq(exp.count, 1, "rifle hostile has a clean line")
	assert_eq(exp.sources.size(), 0, "pistol cannot locate through plank")
	assert_eq(exp.state, Exposure.State.EXPOSED)


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
