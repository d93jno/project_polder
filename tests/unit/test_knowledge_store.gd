extends GutTest

## KnowledgeStore across fights (plan 04 §4.6).


const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")
const LIVE := Knowledge.CellSight.LIVE
const QUIET := Knowledge.CellSight.KNOWN_QUIET
const UNKNOWN := Knowledge.CellSight.UNKNOWN


func _tmp_path() -> String:
	return "user://test_knowledge_store_%d.json" % Time.get_ticks_usec()


func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(path + ".tmp")


func _corridor_state() -> CombatState:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	for x in range(0, 6):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var state := CombatState.new()
	state.map = map
	state.extract_cells = [Vector3i(0, 0, 0)] as Array[Vector3i]
	state.add_unit(Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER))
	return state


func _end_extracted(state: CombatState) -> CombatState:
	## All player bodies leave (or are already inactive) with at least one extracted.
	var next := state.duplicate_state()
	for unit in next.units_of_faction(Taxonomy.Faction.PLAYER):
		if unit.is_active():
			unit.extracted = true
	return next


func _end_wiped(state: CombatState) -> CombatState:
	var next := state.duplicate_state()
	for unit in next.units_of_faction(Taxonomy.Faction.PLAYER):
		unit.dead = true
		next.last_player_down_cell = unit.cell
		next.has_last_player_down = true
	return next


func test_outcome_ongoing_wiped_extracted() -> void:
	var state := _corridor_state()
	assert_eq(state.outcome(), CombatState.FightOutcome.ONGOING)

	var wiped := state.duplicate_state()
	wiped.get_unit(1).dead = true
	assert_eq(wiped.outcome(), CombatState.FightOutcome.WIPED)

	var extracted := state.duplicate_state()
	extracted.get_unit(1).extracted = true
	assert_eq(extracted.outcome(), CombatState.FightOutcome.EXTRACTED)

	## Mixed: one extracted, one dead → EXTRACTED (not a wipe).
	var mixed := state.duplicate_state()
	mixed.add_unit(Unit.new(2, Vector3i(1, 0, 0), Taxonomy.Faction.PLAYER))
	mixed.get_unit(1).extracted = true
	mixed.get_unit(2).dead = true
	assert_eq(mixed.outcome(), CombatState.FightOutcome.EXTRACTED)


func test_round_trip_to_dict_from_dict() -> void:
	var store := KnowledgeStore.fresh(_tmp_path())
	store.bowls["street"] = {
		"visit_index": 2,
		"cells": {"1,0,0": {"last_seen_visit": 1, "water_step": int(Taxonomy.WaterStep.DRY)}},
		"unrecovered": [{
			"visit": 0,
			"anchor": "3,0,0",
			"cells": {"2,0,0": {"last_seen_visit": 0, "water_step": 0}},
		}],
	}
	var again := KnowledgeStore.from_dict(store.to_dict())
	assert_eq(int(again.bowls["street"]["visit_index"]), 2)
	assert_true(again.bowls["street"]["cells"].has("1,0,0"))
	assert_eq(again.bowls["street"]["unrecovered"].size(), 1)


func test_completed_fight_bumps_visit_and_stamps_cells() -> void:
	var path := _tmp_path()
	var store := KnowledgeStore.fresh(path)
	var state := _corridor_state()
	store.begin_fight(state, "street")
	state.knowledge.peel(state.map, state)
	assert_eq(state.knowledge.own_sight(1, Vector3i(0, 0, 0)), LIVE)

	state = _end_extracted(state)
	store.commit_fight(state)

	assert_eq(int(store.bowls["street"]["visit_index"]), 1)
	assert_true(store.bowls["street"]["cells"].has("0,0,0"))
	assert_eq(int(store.bowls["street"]["cells"]["0,0,0"]["last_seen_visit"]), 0)
	_cleanup(path)


func test_abandoned_fight_leaves_store_byte_identical() -> void:
	var path := _tmp_path()
	var store := KnowledgeStore.fresh(path)
	var state := _corridor_state()
	store.begin_fight(state, "street")
	state = _end_extracted(state)
	store.commit_fight(state)
	var before := store.file_bytes()

	var mid := _corridor_state()
	store.begin_fight(mid, "street")
	mid.knowledge.peel(mid.map, mid)
	mid = FreeMoveCommand.new(1, Vector3i(3, 0, 0)).apply(mid)
	## Abandon: no commit.
	var after := KnowledgeStore.load_from(path).file_bytes()
	assert_eq(before, after, "abandoned fight writes nothing")
	_cleanup(path)


func test_wipe_seals_intel_without_applying_cells() -> void:
	var path := _tmp_path()
	var store := KnowledgeStore.fresh(path)
	var state := _corridor_state()
	store.begin_fight(state, "street")
	state.knowledge.peel(state.map, state)
	state = FreeMoveCommand.new(1, Vector3i(2, 0, 0)).apply(state)
	var down_cell := state.get_unit(1).cell
	state = _end_wiped(state)
	assert_eq(state.wipe_anchor(), down_cell)
	store.commit_fight(state)

	assert_eq(int(store.bowls["street"]["visit_index"]), 1)
	assert_true(store.bowls["street"]["cells"].is_empty(), "wipe does not apply peeled cells")
	assert_eq(store.bowls["street"]["unrecovered"].size(), 1)
	var rec: Dictionary = store.bowls["street"]["unrecovered"][0]
	assert_eq(str(rec["anchor"]), Knowledge._cell_key(down_cell))
	assert_false((rec["cells"] as Dictionary).is_empty())
	_cleanup(path)


func test_later_fight_recovers_sealed_intel_aged() -> void:
	var path := _tmp_path()
	var store := KnowledgeStore.fresh(path)
	## Visit 0: wipe after peeling the street.
	var wiped := _corridor_state()
	store.begin_fight(wiped, "street")
	wiped.knowledge.peel(wiped.map, wiped)
	wiped = FreeMoveCommand.new(1, Vector3i(4, 0, 0)).apply(wiped)
	var anchor := wiped.get_unit(1).cell
	wiped = _end_wiped(wiped)
	store.commit_fight(wiped)
	assert_eq(store.bowls["street"]["unrecovered"].size(), 1)

	## Visit 1: open without reaching the anchor — seal stays.
	var miss := _corridor_state()
	## Wall so west cells are not Live when standing on the anchor.
	miss.map.set_cell(Vector3i(3, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	for x in range(0, 6):
		miss.map.set_cell(Vector3i(x, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	miss.get_unit(1).cell = Vector3i(0, 0, 0)
	store.begin_fight(miss, "street")
	miss.knowledge.peel(miss.map, miss)
	assert_eq(store.bowls["street"]["unrecovered"].size(), 1, "never saw the anchor")
	assert_eq(miss.knowledge.own_sight(1, Vector3i(4, 0, 0)), UNKNOWN)

	## Walk around the wall onto the anchor — seal recovers as Known-quiet, aged.
	miss = FreeMoveCommand.new(1, Vector3i(4, 1, 0)).apply(miss)
	miss = FreeMoveCommand.new(1, anchor).apply(miss)
	assert_eq(miss.knowledge.own_sight(1, Vector3i(1, 0, 0)), QUIET, "recovered behind the wall")
	assert_gt(miss.knowledge.staleness_of(miss, Vector3i(1, 0, 0)), 0.0)

	## End normally: seal removed, cells written.
	miss = _end_extracted(miss)
	store.commit_fight(miss)
	assert_true(store.bowls["street"]["unrecovered"].is_empty())
	assert_true(store.bowls["street"]["cells"].has("1,0,0"))
	_cleanup(path)


func test_missing_corrupt_future_version_degrade_to_fresh() -> void:
	var missing_path := _tmp_path()
	var missing := KnowledgeStore.load_from(missing_path)
	assert_true(missing.bowls.is_empty())

	var corrupt_path := _tmp_path()
	var f := FileAccess.open(corrupt_path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var corrupt := KnowledgeStore.load_from(corrupt_path)
	assert_true(corrupt.bowls.is_empty())
	_cleanup(corrupt_path)

	var future_path := _tmp_path()
	f = FileAccess.open(future_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 99, "bowls": {"x": {}}}))
	f.close()
	var future := KnowledgeStore.load_from(future_path)
	assert_true(future.bowls.is_empty())
	_cleanup(future_path)


func test_staleness_rises_with_visits_and_clamps() -> void:
	var path := _tmp_path()
	var store := KnowledgeStore.fresh(path)
	var state := _corridor_state()
	store.begin_fight(state, "street")
	state.knowledge.peel(state.map, state)
	## Freeze: Live → Known-quiet by leaving, then age visit_index.
	state.knowledge._by_unit[1][Vector3i(0, 0, 0)]["sight"] = QUIET
	state.knowledge._by_unit[1][Vector3i(0, 0, 0)]["last_seen_visit"] = 0
	state.knowledge.visit_index = 0
	var s0 := state.knowledge.staleness_of(state, Vector3i(0, 0, 0))
	state.knowledge.visit_index = 2
	var s1 := state.knowledge.staleness_of(state, Vector3i(0, 0, 0))
	assert_gt(s1, s0)
	state.knowledge.visit_index = RulesConstants.STALE_FULL_AFTER_VISITS + 10
	assert_eq(state.knowledge.staleness_of(state, Vector3i(0, 0, 0)), 1.0)
	_cleanup(path)


func test_second_terrace_visit_opens_known_quiet_and_aged() -> void:
	## Done-when: first visit peels a room; second visit opens that room Known-quiet and aged.
	var path := _tmp_path()
	var store := KnowledgeStore.fresh(path)

	var first := FloodedTerrace.opening(Taxonomy.WaterStep.DRY)
	first.units.erase(FloodedTerrace.D_RIFLE)
	first.units.erase(FloodedTerrace.D_PISTOL)
	first.watches.clear()
	store.begin_fight(first, "terrace")
	first.knowledge.peel(first.map, first)
	assert_eq(first.knowledge.squad_sight(first, FloodedTerrace.CLAN_CELL), UNKNOWN)

	## Stand in the interior so Vision peels it (same seam as terrace_fog_peeled).
	first.get_unit(FloodedTerrace.P1).cell = FloodedTerrace.CLAN_CELL
	first.knowledge.peel(first.map, first)
	assert_eq(first.knowledge.squad_sight(first, FloodedTerrace.CLAN_CELL), LIVE)

	first = _end_extracted(first)
	store.commit_fight(first)
	assert_eq(int(store.bowls["terrace"]["visit_index"]), 1)
	assert_true(store.bowls["terrace"]["cells"].has(Knowledge._cell_key(FloodedTerrace.CLAN_CELL)))

	var second := FloodedTerrace.opening(Taxonomy.WaterStep.DRY)
	second.units.erase(FloodedTerrace.D_RIFLE)
	second.units.erase(FloodedTerrace.D_PISTOL)
	second.watches.clear()
	store.begin_fight(second, "terrace")
	assert_eq(second.knowledge.visit_index, 1)
	assert_eq(
		second.knowledge.squad_sight(second, FloodedTerrace.CLAN_CELL),
		QUIET,
		"second visit opens with prior rooms Known-quiet"
	)
	assert_gt(
		second.knowledge.staleness_of(second, FloodedTerrace.CLAN_CELL),
		0.0,
		"prior visit is already aged"
	)
	_cleanup(path)
