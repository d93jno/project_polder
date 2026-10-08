extends GutTest

## The basin as data and the knowability read (plan 07 §7.0).

const Ring := preload("res://rules/fixtures/basin_ring.gd")


func test_the_fixture_is_seven_bowls_in_three_rings() -> void:
	var basin := Ring.opening()
	assert_eq(basin.ids().size(), 7)
	var count := {BasinBowl.Grade.RIM: 0, BasinBowl.Grade.FLOOR: 0, BasinBowl.Grade.SUMP: 0}
	for id in basin.ids():
		count[basin.bowl(id).grade] += 1
	assert_eq(count[BasinBowl.Grade.RIM], 3)
	assert_eq(count[BasinBowl.Grade.FLOOR], 3)
	assert_eq(count[BasinBowl.Grade.SUMP], 1)
	assert_eq(basin.bowl(Ring.SUMP).feeders.size(), 3, "the sump has three feeders, so a majority means something")


func test_every_feeder_is_a_bowl_in_the_basin() -> void:
	for basin in [Ring.opening(), Ring.late_ring()]:
		for id in basin.ids():
			for feeder_id in basin.bowl(id).feeders:
				assert_true(basin.has_bowl(feeder_id), "%s is fed by %s" % [id, feeder_id])


func test_a_duplicated_basin_is_independent() -> void:
	var basin := Ring.opening()
	var copy := basin.duplicate_basin()
	copy.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.DRY
	copy.bowl(Ring.TERRACE).pump = BasinBowl.Pump.DEAD
	copy.bowl(Ring.TERRACE).feeders.append("elsewhere")
	assert_eq(basin.bowl(Ring.TERRACE).step, Taxonomy.WaterStep.FLOODED)
	assert_eq(basin.bowl(Ring.TERRACE).pump, BasinBowl.Pump.ON)
	assert_eq(basin.bowl(Ring.TERRACE).feeders.size(), 2)
	assert_eq(copy.ids(), basin.ids(), "the same authored order")


func test_a_bowl_nobody_has_visited_reads_unknown_not_dry() -> void:
	var read := WaterGraph.read(Ring.opening(), Ring.SUMP)
	assert_false(read["known"])
	assert_false(read.has("step"), "no step is invented for it")
	assert_false(WaterGraph.read(Ring.opening(), "nowhere")["known"])


func test_a_plate_reads_its_own_bowl_and_never_the_ring() -> void:
	var read := WaterGraph.read(Ring.opening(), Ring.RIDGE_W)
	assert_true(read["known"])
	assert_false(read["instrumented"])
	for field in ["grade", "step", "pump", "upkeep", "walking"]:
		assert_true(read.has(field), field)
	assert_false(read.has("feeders"), "which feeders pour is the instruments' to say")


func test_instruments_read_the_feeders_and_which_still_pour() -> void:
	var basin := Ring.opening()
	var read := WaterGraph.read(basin, Ring.TERRACE)
	assert_true(read["instrumented"])
	var feeders: Array = read["feeders"]
	assert_eq(feeders.size(), 2)
	## The terrace is Flooded and the ridges are Falling: drier than it, so they are not pouring.
	for feeder in feeders:
		assert_false(feeder["pouring"], "%s is drier than the terrace" % feeder["id"])
	basin.bowl(Ring.RIDGE_W).step = Taxonomy.WaterStep.FLOODED
	var after: Array = WaterGraph.read(basin, Ring.TERRACE)["feeders"]
	var pouring := {}
	for feeder in after:
		pouring[feeder["id"]] = feeder["pouring"]
	assert_true(pouring[Ring.RIDGE_W], "as wet as the terrace, so it pours in")
	assert_false(pouring[Ring.RIDGE_N])


func test_a_walking_step_reads_as_walking_with_its_days() -> void:
	var basin := Ring.late_ring()
	var bowl := basin.bowl(Ring.TERRACE)
	assert_eq(WaterGraph.read(basin, Ring.TERRACE)["walking"], BasinBowl.Walk.NONE)
	assert_eq(WaterGraph.read(basin, Ring.TERRACE)["eta_days"], 0)
	bowl.walk = BasinBowl.Walk.WETTER
	bowl.walk_days_left = 2
	var read := WaterGraph.read(basin, Ring.TERRACE)
	assert_eq(read["walking"], BasinBowl.Walk.WETTER)
	assert_eq(read["eta_days"], 2)


func test_upkeep_is_derived_from_the_wear_counter() -> void:
	var bowl := BasinBowl.new("p")
	assert_eq(bowl.upkeep(), BasinBowl.Upkeep.KEPT)
	bowl.neglect = BasinRules.THIN_AFTER_DAYS - 1
	assert_eq(bowl.upkeep(), BasinBowl.Upkeep.KEPT)
	bowl.neglect = BasinRules.THIN_AFTER_DAYS
	assert_eq(bowl.upkeep(), BasinBowl.Upkeep.THIN)
	bowl.neglect = BasinRules.FAILING_AFTER_DAYS
	assert_eq(bowl.upkeep(), BasinBowl.Upkeep.FAILING)
	bowl.neglect = 0
	bowl.pump = BasinBowl.Pump.DEAD
	assert_eq(bowl.upkeep(), BasinBowl.Upkeep.FAILING, "a dead pump is not kept")


func test_wetter_and_drier_stop_at_the_ends() -> void:
	assert_eq(BasinRules.wetter(Taxonomy.WaterStep.FLOODED), Taxonomy.WaterStep.FLOODED)
	assert_eq(BasinRules.wetter(Taxonomy.WaterStep.DRY), Taxonomy.WaterStep.MUD)
	assert_eq(BasinRules.drier(Taxonomy.WaterStep.DRY), Taxonomy.WaterStep.DRY)
	assert_eq(BasinRules.drier(Taxonomy.WaterStep.FLOODED), Taxonomy.WaterStep.FALLING)
