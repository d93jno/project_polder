extends GutTest

## GDD 6.1: "A bowl that changes with no way to have seen it coming is a design bug." Over many days
## and many labor plans, a step may only land if the day before already read as walking that way,
## with a day to go (plan 07 §7.1). Written before any table surface, so the surface is held to it.

const Ring := preload("res://rules/fixtures/basin_ring.gd")


func _plan(rng: RandomNumberGenerator, basin: Basin) -> Dictionary:
	var posted := {}
	for id in basin.ids():
		posted[id] = rng.randf() < 0.6
	return posted


func _step_dir(from: Taxonomy.WaterStep, to: Taxonomy.WaterStep) -> BasinBowl.Walk:
	return BasinBowl.Walk.WETTER if int(to) < int(from) else BasinBowl.Walk.DRIER


func _drive(start: Basin, seed_value: int, days: int, kill_pumps: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var basin := start
	var landed := 0
	for day in days:
		if kill_pumps and rng.randf() < 0.08:
			var victim: String = basin.ids()[rng.randi_range(0, basin.ids().size() - 1)]
			basin.bowl(victim).pump = BasinBowl.Pump.DEAD
		var result := BasinDay.end(basin, _plan(rng, basin))
		for move in result.moved:
			landed += 1
			var before: BasinBowl = basin.bowl(move["id"])
			var dir := _step_dir(move["from"], move["to"])
			assert_eq(before.walk, dir, "seed %d day %d: %s landed %s with no walk to read" % [seed_value, day, move["id"], dir])
			assert_eq(before.walk_days_left, 1, "and it was one day away the day before")
			var read := WaterGraph.read(basin, move["id"])
			if read["known"]:
				assert_eq(read["walking"], dir, "the read said so, too")
				assert_eq(read["eta_days"], 1)
		basin = result.basin
	assert_gte(landed, 0)


func test_no_step_lands_unannounced_from_the_opening() -> void:
	for seed_value in range(1, 13):
		_drive(Ring.opening(), seed_value, 60, false)


func test_no_step_lands_unannounced_in_a_late_ring_with_pumps_dying() -> void:
	for seed_value in range(1, 13):
		_drive(Ring.late_ring(), seed_value, 60, true)


func test_the_runs_are_not_vacuous() -> void:
	## The invariant above is meaningless if nothing ever lands. Count them.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var basin := Ring.opening()
	var landed := 0
	for _day in 60:
		var result := BasinDay.end(basin, _plan(rng, basin))
		landed += result.moved.size()
		basin = result.basin
	assert_gt(landed, 5, "water walked during the run")
