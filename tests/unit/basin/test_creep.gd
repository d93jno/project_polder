extends GutTest

## Creep across bowls (plan 08 §7.1, GDD §6.4: "creep can overshoot into the next bowl if ignored").

const Ring := preload("res://rules/fixtures/basin_ring.gd")


func _all_posted(basin: Basin) -> Dictionary:
	var posted := {}
	for id in basin.ids():
		posted[id] = true
	return posted


## A late, dry ring with the terrace redirected: Flooded and held, as a sluice leaves it.
func _redirected() -> Basin:
	var basin := Ring.late_ring()
	basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.FLOODED
	basin.bowl(Ring.TERRACE).hang_days = BasinRules.REDIRECTION_HANG_DAYS
	return basin


func _run(basin: Basin, days: int) -> Basin:
	var now := basin
	for _day in days:
		now = BasinDay.end(now, _all_posted(now)).basin
	return now


func test_a_flooded_bowl_pushes_the_dry_bowl_it_feeds_toward_mud() -> void:
	var basin := _redirected()
	var steps: Array = []
	for _day in 6:
		basin = BasinDay.end(basin, _all_posted(basin)).basin
		steps.append(basin.bowl(Ring.POLDER_B).step)
	assert_eq(steps[0], Taxonomy.WaterStep.DRY, "it begins walking, it does not land the same day")
	assert_eq(steps[-1], Taxonomy.WaterStep.MUD, "the neighbour has been pushed to Mud")


func _wettest(basin: Basin, id: String, days: int) -> int:
	## The wettest step the bowl reached over the run (lower is wetter).
	var low := int(basin.bowl(id).step)
	var now := basin
	for _day in days:
		now = BasinDay.end(now, _all_posted(now)).basin
		low = mini(low, int(now.bowl(id).step))
	return low


func test_it_stops_at_mud_while_the_bowls_own_ring_holds() -> void:
	assert_eq(_wettest(_redirected(), Ring.POLDER_B, 30), int(Taxonomy.WaterStep.MUD), "Mud, and never wetter")


func test_it_runs_on_when_the_ring_does_not_hold() -> void:
	var basin := _redirected()
	## The polder's two feeders are the redirected terrace and the east ridge: kill both pumps.
	basin.bowl(Ring.TERRACE).pump = BasinBowl.Pump.DEAD
	basin.bowl(Ring.RIDGE_E).pump = BasinBowl.Pump.DEAD
	assert_eq(
		_wettest(basin, Ring.POLDER_B, 30), int(Taxonomy.WaterStep.FALLING),
		"past Mud, because nothing held, and then it is only one step behind the water that pushes it"
	)


func test_the_spread_follows_its_source_back_down_once_the_hang_ends() -> void:
	var basin := _run(_redirected(), 20)
	assert_eq(basin.bowl(Ring.TERRACE).step, Taxonomy.WaterStep.DRY, "the terrace dries again after its hold")
	assert_eq(basin.bowl(Ring.POLDER_B).step, Taxonomy.WaterStep.DRY, "and the polder it pushed follows it")


func test_a_bowl_never_pushes_the_bowls_that_feed_it() -> void:
	## Uphill only: the polder is Flooded, but the terrace feeds it and is not fed by it.
	var basin := Ring.late_ring()
	basin.bowl(Ring.POLDER_B).step = Taxonomy.WaterStep.FLOODED
	basin.bowl(Ring.POLDER_B).hang_days = 99
	basin = _run(basin, 20)
	assert_eq(basin.bowl(Ring.TERRACE).step, Taxonomy.WaterStep.DRY)
	assert_eq(basin.bowl(Ring.RIDGE_E).step, Taxonomy.WaterStep.DRY)


func test_a_bowl_with_most_of_its_feeders_as_dry_as_it_is_is_not_pushed() -> void:
	## The sump has three feeders. With the terrace Flooded and the two polders Dry, two of three are
	## as dry as it is, so it holds, even though one feeder is far wetter.
	var basin := _redirected()
	basin.bowl(Ring.POLDER_B).hang_days = 99 ## keep the polder from walking, so only the terrace pushes
	var pushed := BasinDay.end(basin, _all_posted(basin))
	assert_eq(pushed.basin.bowl(Ring.SUMP).walk, BasinBowl.Walk.NONE)
	assert_eq(pushed.basin.bowl(Ring.POLDER_B).walk, BasinBowl.Walk.WETTER, "while the polder, with one dry feeder of two, is")


func test_the_creep_goes_on_one_bowl_at_a_time() -> void:
	## A step crosses one bowl a day: the sump is not pushed until the polder has actually walked.
	var basin := _redirected()
	var day_polder := -1
	var day_sump := -1
	for day in range(1, 20):
		var result := BasinDay.end(basin, _all_posted(basin))
		basin = result.basin
		for move in result.moved:
			if move["id"] == Ring.POLDER_B and day_polder < 0:
				day_polder = day
			if move["id"] == Ring.SUMP and day_sump < 0:
				day_sump = day
	assert_gt(day_polder, 0)
	if day_sump > 0:
		assert_gt(day_sump, day_polder, "the sump only walks after the polder has")


func test_a_redirected_bowl_still_holds_wet_through_the_spread() -> void:
	var basin := _run(_redirected(), BasinRules.REDIRECTION_HANG_DAYS - 1)
	assert_eq(basin.bowl(Ring.TERRACE).step, Taxonomy.WaterStep.FLOODED)
	assert_gt(basin.bowl(Ring.TERRACE).hang_days, 0)


func test_a_wet_bowl_beside_a_wet_neighbour_is_not_pushed() -> void:
	## Two steps is the threshold: a feeder one step wetter does not push.
	var basin := Ring.late_ring()
	basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.FALLING
	basin.bowl(Ring.TERRACE).hang_days = 99
	basin.bowl(Ring.POLDER_B).step = Taxonomy.WaterStep.MUD
	var result := BasinDay.end(basin, _all_posted(basin))
	assert_eq(result.basin.bowl(Ring.POLDER_B).walk, BasinBowl.Walk.NONE, "Falling beside Mud is one step")
