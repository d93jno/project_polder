extends GutTest

## Going cold, and the warning before it (plan 10 §10.4).

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")
const Queries := preload("res://presentation/table_queries.gd")


func _met() -> Campaign:
	var c := Opening.opening()
	c.day = 2
	Bands.meet_at(c, Ring.TERRACE)
	Bands.meet_at(c, Ring.RIDGE_W)
	return c


func _flood(c: Campaign, bowl: String) -> void:
	c.basin.bowl(bowl).step = Taxonomy.WaterStep.FALLING
	Redirection.record(c, bowl, Taxonomy.WaterStep.FLOODED)


func test_a_redirection_that_still_hangs_cools_the_band_standing_there() -> void:
	var c := _met()
	_flood(c, Ring.TERRACE)
	c.close_day()
	var riders := Bands.band(c, "wake_riders")
	assert_false(riders.warm)
	assert_eq([riders.cold_cause, riders.cold_at], ["flood", Ring.TERRACE])
	assert_eq(c.morning.went_cold, [{"band": "wake_riders", "bowl": Ring.TERRACE, "cause": "flood"}])
	assert_true(Bands.band(c, "roof_clan").warm, "no other band")


func test_a_redirection_elsewhere_cools_nobody() -> void:
	var c := _met()
	_flood(c, Ring.SUMP)
	c.close_day()
	assert_eq(Bands.warm_count(c), 2)


func test_a_redirection_the_bowl_has_dried_back_from_cools_nobody() -> void:
	var c := _met()
	_flood(c, Ring.TERRACE)
	c.redirections[0].from_step = Taxonomy.WaterStep.FLOODED ## it no longer stands wetter than before
	c.close_day()
	assert_true(Bands.band(c, "wake_riders").warm)


func test_an_unmet_band_is_not_cooled() -> void:
	var c := Opening.opening()
	_flood(c, Ring.TERRACE)
	c.close_day()
	assert_false(Bands.band(c, "wake_riders").warm == false and Bands.band(c, "wake_riders").met())
	assert_eq(c.morning.went_cold, [] as Array[Dictionary])


func test_going_cold_is_permanent_and_stops_the_mail_and_the_jobs() -> void:
	var c := _met()
	_flood(c, Ring.TERRACE)
	c.close_day()
	for i in 20:
		c.close_day()
	assert_false(Bands.band(c, "wake_riders").warm)
	assert_eq(SetJobCommand.new("wake_riders", Band.Job.FOOD).validate(c).reason, "they have gone cold and take no work")
	assert_eq(Bands.with_job(c, Band.Job.EYES).size(), 0)
	assert_false(Ending.has_warm_band(c) and Bands.band(c, "roof_clan").warm == false)


func test_taking_the_cache_cools_a_band_met_before_the_fireteam_came() -> void:
	var c := _met()
	var cooled := Bands.cool_for_cache(c, Ring.TERRACE)
	assert_eq(cooled.size(), 1)
	assert_eq(Bands.band(c, "wake_riders").cold_cause, "cache")


func test_the_trip_that_meets_a_band_does_not_cool_it_for_the_cache_it_takes() -> void:
	var c := Opening.opening()
	var ids: Array[int] = [1, 2, 3, 4]
	c = DispatchCommand.new(Ring.TERRACE, ids).apply(c)
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, ids)
	for id in ids:
		fight.get_unit(id).extracted = true
	c = HomeCommand.new(fight).apply(c)
	assert_true(Bands.band(c, "wake_riders").warm)
	assert_eq(c.morning.went_cold, [] as Array[Dictionary])


func test_the_dispatch_slot_names_the_band_the_cache_would_cool() -> void:
	var c := _met()
	var q = Queries.compute(c, Ring.TERRACE, [] as Array[int])
	assert_eq(q.dispatch["cache_warning"], "the wake riders stand where the cache is: taking it would turn them cold")
	c.salvaged[Ring.TERRACE] = true
	q = Queries.compute(c, Ring.TERRACE, [] as Array[int])
	assert_false(q.dispatch.has("cache_warning"), "nothing left to take")
	var q2 = Queries.compute(Opening.opening(), Ring.TERRACE, [] as Array[int])
	assert_false(q2.dispatch.has("cache_warning"), "a band not yet met is nobody's to wrong")


## --- The card ---


func test_the_card_names_a_band_it_will_cool_if_and_only_if_the_rule_does() -> void:
	for met_there in [true, false]:
		var c := Opening.opening()
		c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.MUD
		if met_there:
			c.day = 2
			Bands.meet_at(c, Ring.TERRACE)
		var preview := RedirectionPreview.read(c, Ring.TERRACE)
		var lines := Queries.redirection_card(preview, Ring.TERRACE)
		var named := false
		for line in lines:
			if line.contains("would go cold"):
				named = true
		## The same redirection, played for real.
		var played := c.duplicate_campaign()
		Redirection.record(played, Ring.TERRACE, BasinRules.wetter(Taxonomy.WaterStep.MUD))
		for i in RedirectionPreview.DEFAULT_HORIZON_DAYS:
			played.close_day()
		var cooled := not Bands.band(played, "wake_riders").warm and Bands.band(played, "wake_riders").met()
		assert_eq(named, cooled, "met there: %s" % met_there)


func test_the_card_does_not_name_an_unwalked_bowl_unless_the_band_warns() -> void:
	var entry := {"id": "wake_riders", "bowl": Ring.POLDER_A, "cause": "flood", "warn": false, "known": false}
	var preview := {
		"ok": true, "is_range": false, "bowls": [], "beyond_first": false, "creeps": false, "unknown_reached": 0,
		"bands_cooled": [entry], "horizon_days": 14,
	}
	var quiet := Queries.redirection_card(preview, Ring.TERRACE)
	assert_true(quiet.has("a band you have met would go cold"))
	for line in quiet:
		assert_false(line.contains(Ring.POLDER_A))
	entry["warn"] = true
	assert_true(Queries.redirection_card(preview, Ring.TERRACE).has("the wake riders would go cold at polder_a"))


func test_the_morning_says_a_band_went_quiet_in_words_with_no_meter() -> void:
	var c := _met()
	_flood(c, Ring.TERRACE)
	c.close_day()
	var q = Queries.compute(c, "", [] as Array[int])
	assert_true(q.morning.has("the wake riders went quiet: their ground is under water"))
	for line in q.morning:
		for banned in ["warm", "cold", "trust", "reputation", "loyal", "%"]:
			assert_false(line.to_lower().contains(banned), "UI 8: '%s' in '%s'" % [banned, line])


func test_a_cold_band_is_saved() -> void:
	var c := _met()
	_flood(c, Ring.TERRACE)
	c.close_day()
	var path := "user://cold_test_save.json"
	CampaignSave.save_campaign(c, path)
	var loaded = CampaignSave.load_campaign(path)
	DirAccess.remove_absolute(path)
	var riders: Band = Bands.band(loaded, "wake_riders")
	assert_eq([riders.warm, riders.cold_cause, riders.cold_at], [false, "flood", Ring.TERRACE])
	assert_eq(loaded.morning.went_cold.size(), 1)
