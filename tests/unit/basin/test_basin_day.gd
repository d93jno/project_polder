extends GutTest

## The day tick (plan 07 §7.1, GDD §6.1, §6.2).

const Ring := preload("res://rules/fixtures/basin_ring.gd")


func _all_posted(basin: Basin) -> Dictionary:
	var posted := {}
	for id in basin.ids():
		posted[id] = true
	return posted


func _run(basin: Basin, days: int, posted: Dictionary = {}) -> Basin:
	var now := basin
	for _day in days:
		now = BasinDay.end(now, posted).basin
	return now


func _snapshot(basin: Basin) -> Array:
	var out: Array = []
	for id in basin.ids():
		var b := basin.bowl(id)
		out.append([id, b.step, b.pump, b.neglect, b.walk, b.walk_days_left])
	return out


## --- Wear ---


func test_an_unposted_pump_wears_thin_then_failing_then_breaks() -> void:
	var basin := Ring.late_ring()
	var seen: Array = []
	for day in BasinRules.BREAKS_AFTER_DAYS:
		var result := BasinDay.end(basin, {})
		basin = result.basin
		seen.append(basin.bowl(Ring.TERRACE).upkeep())
		if day + 1 == BasinRules.BREAKS_AFTER_DAYS:
			assert_true(Ring.TERRACE in result.pumps_broke)
	assert_eq(seen[0], BasinBowl.Upkeep.KEPT)
	assert_eq(seen[BasinRules.THIN_AFTER_DAYS - 1], BasinBowl.Upkeep.THIN)
	assert_eq(seen[BasinRules.FAILING_AFTER_DAYS - 1], BasinBowl.Upkeep.FAILING)
	assert_eq(basin.bowl(Ring.TERRACE).pump, BasinBowl.Pump.DEAD)


func test_posting_a_pump_holds_it_kept_and_resets_the_clock() -> void:
	var basin := _run(Ring.late_ring(), 3, {})
	assert_eq(basin.bowl(Ring.TERRACE).upkeep(), BasinBowl.Upkeep.THIN)
	basin = _run(basin, 1, _all_posted(basin))
	assert_eq(basin.bowl(Ring.TERRACE).neglect, 0)
	assert_eq(basin.bowl(Ring.TERRACE).upkeep(), BasinBowl.Upkeep.KEPT)
	basin = _run(basin, 20, _all_posted(basin))
	assert_eq(basin.bowl(Ring.TERRACE).pump, BasinBowl.Pump.ON, "a posted pump never breaks")


func test_the_day_reports_when_upkeep_changes() -> void:
	var basin := _run(Ring.late_ring(), BasinRules.THIN_AFTER_DAYS - 1, {})
	var result := BasinDay.end(basin, {})
	var terrace_change := false
	for change in result.upkeep_changed:
		if change["id"] == Ring.TERRACE:
			terrace_change = true
			assert_eq(change["from"], BasinBowl.Upkeep.KEPT)
			assert_eq(change["to"], BasinBowl.Upkeep.THIN)
	assert_true(terrace_change)


## --- Creep ---


func test_a_stopped_late_pump_walks_dry_to_mud_and_stops() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.TERRACE).pump = BasinBowl.Pump.DEAD
	var posted := _all_posted(basin)
	var steps: Array = []
	for _day in 10:
		basin = BasinDay.end(basin, posted).basin
		steps.append(basin.bowl(Ring.TERRACE).step)
	assert_eq(steps[0], Taxonomy.WaterStep.DRY, "it begins walking, it does not land")
	assert_eq(steps[-1], Taxonomy.WaterStep.MUD, "Dry walks to Mud")
	assert_false(Taxonomy.WaterStep.FALLING in steps, "and stops there while the ring holds")
	assert_false(Taxonomy.WaterStep.FLOODED in steps)


func test_the_walk_takes_the_bowls_own_leak_days() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.RIDGE_W).pump = BasinBowl.Pump.DEAD ## leaks in a day
	basin.bowl(Ring.SUMP).pump = BasinBowl.Pump.DEAD ## leaks in three
	var posted := _all_posted(basin)
	var day_landed := {}
	for day in range(1, 8):
		var result := BasinDay.end(basin, posted)
		basin = result.basin
		for move in result.moved:
			day_landed[move["id"]] = day
	assert_lt(day_landed[Ring.RIDGE_W], day_landed[Ring.SUMP], "outer leaks faster than inner (GDD 6.2)")
	assert_eq(day_landed[Ring.RIDGE_W], 2, "one day of leak, landing the tick after it began")
	assert_eq(day_landed[Ring.SUMP], 4)


func test_with_the_ring_failing_there_is_no_cap() -> void:
	## A sump whose feeders have mostly died can keep walking: the sea can still win a low bowl.
	var basin := Ring.late_ring()
	basin.bowl(Ring.SUMP).pump = BasinBowl.Pump.DEAD
	basin.bowl(Ring.TERRACE).pump = BasinBowl.Pump.DEAD
	basin.bowl(Ring.POLDER_A).pump = BasinBowl.Pump.DEAD
	var posted := _all_posted(basin)
	basin = _run(basin, 24, posted)
	assert_eq(basin.bowl(Ring.SUMP).step, Taxonomy.WaterStep.FLOODED, "past Mud, because the ring did not hold")


func test_one_dead_pump_does_not_refill_the_basin() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.TERRACE).pump = BasinBowl.Pump.DEAD
	basin = _run(basin, 30, _all_posted(basin))
	for id in basin.ids():
		if id != Ring.TERRACE:
			assert_eq(basin.bowl(id).step, Taxonomy.WaterStep.DRY, "%s is untouched by one wrench" % id)


## --- Drying ---


func test_a_bowl_cannot_be_drier_than_the_water_pouring_into_it() -> void:
	## One hero pump in a hole in the ring: its feeders are still wet, so it stays wet.
	var basin := Ring.opening()
	for id in [Ring.RIDGE_W, Ring.RIDGE_N, Ring.RIDGE_E]:
		basin.bowl(id).step = Taxonomy.WaterStep.FLOODED
		basin.bowl(id).pump = BasinBowl.Pump.DAMAGED ## the rim is not draining
	var posted := _all_posted(basin)
	basin = _run(basin, 20, posted)
	assert_eq(basin.bowl(Ring.TERRACE).step, Taxonomy.WaterStep.FLOODED, "a whirlpool, not a dry street")
	assert_eq(basin.bowl(Ring.TERRACE).walk, BasinBowl.Walk.NONE)


func test_a_bowl_dries_once_enough_of_its_feeders_have() -> void:
	var basin := Ring.opening() ## the ridges are Falling, the terrace Flooded: its two feeders are dry enough
	var terrace := basin.bowl(Ring.TERRACE)
	basin = BasinDay.end(basin, _all_posted(basin)).basin
	assert_eq(basin.bowl(Ring.TERRACE).walk, BasinBowl.Walk.DRIER, "it starts walking drier")
	assert_eq(basin.bowl(Ring.TERRACE).step, terrace.step, "and does not land the same day")


func test_one_dry_feeder_is_not_enough_for_a_bowl_with_two() -> void:
	var basin := Ring.opening()
	basin.bowl(Ring.RIDGE_N).step = Taxonomy.WaterStep.FLOODED
	basin.bowl(Ring.RIDGE_N).pump = BasinBowl.Pump.DAMAGED
	basin = BasinDay.end(basin, _all_posted(basin)).basin
	assert_eq(basin.bowl(Ring.TERRACE).walk, BasinBowl.Walk.NONE, "only one of its two feeders is dry")


func test_the_basin_dries_from_the_rim_inward() -> void:
	var basin := Ring.opening()
	var posted := _all_posted(basin)
	var first_dry := {}
	for day in range(1, 60):
		basin = BasinDay.end(basin, posted).basin
		for id in basin.ids():
			if basin.bowl(id).step == Taxonomy.WaterStep.DRY and not first_dry.has(id):
				first_dry[id] = day
	for id in basin.ids():
		assert_true(first_dry.has(id), "%s dries in the end" % id)
	assert_lt(first_dry[Ring.RIDGE_N], first_dry[Ring.TERRACE], "the rim before the floor ring")
	assert_lt(first_dry[Ring.TERRACE], first_dry[Ring.SUMP], "the floor ring before the sump")
	assert_lt(first_dry[Ring.POLDER_A], first_dry[Ring.SUMP])


## --- The tick itself ---


func test_a_step_never_lands_the_day_it_starts() -> void:
	var basin := Ring.opening()
	for _day in 30:
		var result := BasinDay.end(basin, _all_posted(basin))
		for started in result.walks_started:
			for move in result.moved:
				assert_ne(started["id"], move["id"], "a bowl that began walking did not also land")
		basin = result.basin


func test_the_tick_is_deterministic() -> void:
	var a := _run(Ring.opening(), 15, {Ring.TERRACE: true})
	var b := _run(Ring.opening(), 15, {Ring.TERRACE: true})
	assert_eq(_snapshot(a), _snapshot(b))


func test_the_tick_leaves_its_input_untouched() -> void:
	var basin := Ring.opening()
	var before := _snapshot(basin)
	BasinDay.end(basin, _all_posted(basin))
	assert_eq(_snapshot(basin), before)


func test_the_result_names_what_moved_overnight() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.RIDGE_W).pump = BasinBowl.Pump.DEAD
	var posted := _all_posted(basin)
	var r1 := BasinDay.end(basin, posted)
	assert_eq(r1.walks_started.size(), 1)
	assert_eq(r1.walks_started[0]["id"], Ring.RIDGE_W)
	assert_eq(r1.walks_started[0]["dir"], BasinBowl.Walk.WETTER)
	assert_true(r1.anything_moved())
	var r2 := BasinDay.end(r1.basin, posted)
	assert_eq(r2.moved.size(), 1)
	assert_eq(r2.moved[0]["from"], Taxonomy.WaterStep.DRY)
	assert_eq(r2.moved[0]["to"], Taxonomy.WaterStep.MUD)
