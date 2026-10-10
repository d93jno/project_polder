extends GutTest

## The day economy (plan 09 §9.0): the meal, and a forecast that is the rule run on a copy.

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Queries := preload("res://presentation/table_queries.gd")


func test_a_ration_feeds_four_and_a_part_fed_group_eats_a_whole_one() -> void:
	assert_eq(BasinRules.food_for(0), 0)
	assert_eq(BasinRules.food_for(1), 1)
	assert_eq(BasinRules.food_for(4), 1)
	assert_eq(BasinRules.food_for(5), 2)
	assert_eq(BasinRules.food_for(10), 3)


func test_a_day_ends_with_food_lower_by_the_mouths() -> void:
	var c := Opening.opening()
	var before := c.food
	c.close_day()
	assert_eq(c.food, before - BasinRules.food_for(c.people()))
	assert_eq(c.morning.meal, {"ate": 3, "short": 0})


func test_a_shortfall_is_recorded_and_food_stops_at_zero() -> void:
	var c := Opening.opening()
	c.food = 1
	c.close_day()
	assert_eq(c.food, 0)
	assert_eq(c.morning.meal, {"ate": 1, "short": 2})
	c.close_day()
	assert_eq(c.food, 0, "food never goes below zero")
	assert_eq(c.morning.meal, {"ate": 0, "short": 2}, "and the two who left no longer eat")


func test_eating_does_not_touch_the_people_or_the_labor() -> void:
	var c := Opening.opening()
	var labor := c.labor.duplicate()
	c.close_day()
	assert_eq(c.labor, labor)


func test_the_forecast_equals_the_days_the_real_tick_feeds_the_camp() -> void:
	for food in [0, 2, 3, 5, 12, 40, 200]:
		var c := Opening.opening()
		c.food = food
		var forecast := EconomyForecast.days_of_food(c)
		var fed := 0
		for i in BasinRules.FORECAST_DAYS:
			c.close_day()
			if int(c.morning.meal["short"]) > 0:
				break
			fed += 1
		if fed >= BasinRules.FORECAST_DAYS:
			fed = -1
		assert_eq(forecast, fed, "food %d" % food)


func test_the_forecast_changes_nothing() -> void:
	var c := Opening.opening()
	var day := c.day
	var food := c.food
	EconomyForecast.days_of_food(c)
	assert_eq([c.day, c.food], [day, food])


func test_the_opening_food_lasts_four_days() -> void:
	assert_eq(EconomyForecast.days_of_food(Opening.opening()), 4)


func test_the_table_says_how_long_food_lasts_in_words() -> void:
	assert_eq(Queries.food_lasts_line(4), "food lasts 4 days")
	assert_eq(Queries.food_lasts_line(1), "food lasts 1 day")
	assert_eq(Queries.food_lasts_line(0), "food does not feed the camp tomorrow")
	assert_true(Queries.food_lasts_line(-1).begins_with("food lasts more than"))


func test_the_morning_names_the_meal() -> void:
	var c := Opening.opening()
	c.close_day()
	var q = Queries.compute(c, "", [] as Array[int])
	assert_true(q.morning.has("the camp ate 3 food"))
	c.food = 1
	c.close_day()
	q = Queries.compute(c, "", [] as Array[int])
	assert_true(q.morning.has("the camp ate 0 food and was short by 3") or q.morning.has("the camp ate 1 food and was short by 2"))


## --- Fields feed (plan 09 §9.1) ---

const Ring := preload("res://rules/fixtures/basin_ring.gd")


func _late() -> Campaign:
	var c := Opening.opening()
	c.basin = Ring.late_ring()
	c.labor[Campaign.Bucket.FIELDS] = 0
	return c


## A late ring whose pumps are kept for good, so the water holds while the days run.
func _held() -> Campaign:
	var c := _late()
	c.scrap = 10000
	c.labor[Campaign.Bucket.PUMPS] = 7
	return c


func test_dry_fields_raise_food_each_day() -> void:
	var c := _late()
	var before := c.food
	var mouths := c.people()
	c.close_day()
	assert_eq(c.morning.harvest["fields"], 7)
	assert_eq(c.morning.harvest["food"], 7 * BasinRules.FIELD_YIELD)
	assert_eq(c.food, before + 7 - BasinRules.food_for(mouths))


func test_hands_in_fields_add_one_to_a_field_and_no_more() -> void:
	var c := _late()
	c.labor[Campaign.Bucket.FIELDS] = 3
	c.close_day()
	assert_eq(c.morning.harvest["food"], 7 + 3)
	c = _late()
	c.labor[Campaign.Bucket.FIELDS] = 20
	c.close_day()
	assert_eq(c.morning.harvest["food"], 7 + 7, "one hand to a field, the rest add nothing")


func test_falling_and_mud_yield_nothing() -> void:
	for step in [Taxonomy.WaterStep.FALLING, Taxonomy.WaterStep.MUD, Taxonomy.WaterStep.FLOODED]:
		var c := _late()
		c.labor[Campaign.Bucket.FIELDS] = 3
		for id in c.basin.ids():
			c.basin.bowl(id).step = step
		var r := DayResult.new()
		Economy.harvest(c, r)
		assert_eq(r.harvest["food"], 0)


func test_a_ruined_field_yields_nothing_for_good() -> void:
	var c := _late()
	c.basin.bowl(Ring.POLDER_A).ruined = 3
	c.basin.bowl(Ring.POLDER_A).fields = 0
	c.close_day()
	assert_eq(c.morning.harvest["fields"], 4)


func test_unwalked_ground_is_counted_apart() -> void:
	var c := _late()
	c.basin.bowl(Ring.POLDER_A).known = false
	c.close_day()
	assert_eq(c.morning.harvest["unwalked"], 3)
	assert_eq(c.morning.harvest["food"], 4)
	var q = Queries.compute(c, "", [] as Array[int])
	assert_true(q.morning.has("the fields brought in 4 food"))
	assert_true(q.morning.has("and more from ground you have not walked"))
	for line in q.morning:
		assert_false(line.contains("7 food"), "the unwalked number is never stated")


func test_the_forecast_counts_the_harvest() -> void:
	var c := _held()
	c.food = 0
	assert_eq(EconomyForecast.days_of_food(c), -1, "seven fields outfeed ten mouths")


func test_a_redirection_says_the_food_it_will_cost() -> void:
	var c := _late()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.MUD
	c.basin.bowl(Ring.TERRACE).fields = 2
	var p := RedirectionPreview.read(c, Ring.TERRACE)
	assert_true(p["ok"])
	var lost := 0
	var without := c.duplicate_campaign()
	var with := c.duplicate_campaign()
	Redirection.record(with, Ring.TERRACE, BasinRules.wetter(Taxonomy.WaterStep.MUD))
	for i in RedirectionPreview.DEFAULT_HORIZON_DAYS:
		with.close_day()
		without.close_day()
		lost += int(without.morning.harvest["food"]) - int(with.morning.harvest["food"])
	assert_eq(p["food_lost"], lost)


## --- Scrap in and out (plan 09 §9.3) ---

const Bowls := preload("res://rules/fixtures/bowl_openings.gd")


func test_workshop_hands_make_scrap_after_the_pumps_are_kept() -> void:
	var c := Opening.opening()
	c.labor[Campaign.Bucket.WORKSHOP] = 3
	var posted := c.posted_pumps().size()
	var before := c.scrap
	c.close_day()
	assert_eq(c.scrap, before - posted * Campaign.SCRAP_PER_POST + 3 * BasinRules.SCRAP_PER_WORKSHOP_HAND)
	assert_eq(c.morning.scrap_made, 3)


func test_no_workshop_hands_make_none() -> void:
	var c := Opening.opening()
	c.close_day()
	assert_eq(c.morning.scrap_made, 0)


func test_the_cache_comes_home_once_and_only_with_someone() -> void:
	var c := Opening.opening()
	var fuel := c.fuel
	var scrap := c.scrap
	assert_eq(Economy.salvage(c, Ring.TERRACE, 0), {}, "nobody got out")
	var got := Economy.salvage(c, Ring.TERRACE, 1)
	assert_eq(got, {"scrap": 2, "fuel": 2})
	assert_eq([c.fuel, c.scrap], [fuel + 2, scrap + 2])
	assert_eq(Economy.salvage(c, Ring.TERRACE, 3), {}, "no infinite well")
	assert_eq(Economy.salvage(c, Ring.RIDGE_W, 3), {}, "a bowl with no cache")


func test_a_cache_that_came_home_is_saved() -> void:
	var c := Opening.opening()
	Economy.salvage(c, Ring.TERRACE, 1)
	var path := "user://salvage_test_save.json"
	CampaignSave.save_campaign(c, path)
	var loaded = CampaignSave.load_campaign(path)
	DirAccess.remove_absolute(path)
	assert_true(loaded.salvaged.has(Ring.TERRACE))
	assert_eq(Economy.salvage(loaded, Ring.TERRACE, 1), {})


func test_the_table_says_ahead_when_scrap_will_not_keep_a_pump() -> void:
	var c := Opening.opening()
	c.scrap = 0
	c.basin.bowl(Ring.RIDGE_W).pump = BasinBowl.Pump.ON
	assert_true(c.pumps_scrap_cannot_keep() > 0)
	assert_true(Queries.scrap_short_line(c.pumps_scrap_cannot_keep()).begins_with("scrap will not keep"))
	c.scrap = 20
	assert_eq(c.pumps_scrap_cannot_keep(), 0)
	assert_eq(Queries.scrap_short_line(0), "")


func test_the_morning_names_the_workshop_and_the_cache() -> void:
	var c := Opening.opening()
	c.labor[Campaign.Bucket.WORKSHOP] = 2
	c.close_day()
	c.morning.salvage = {"scrap": 2, "fuel": 2}
	var q = Queries.compute(c, "", [] as Array[int])
	assert_true(q.morning.has("the workshop made 2 scrap"))
	assert_true(q.morning.has("the fireteam brought back 2 scrap and 2 fuel"))


func test_only_the_economy_changes_food_fuel_or_scrap() -> void:
	var pattern := RegEx.create_from_string("\\b(food|fuel|scrap)\\s*[-+]?=(?!=)")
	var offenders: Array[String] = []
	for root in ["res://rules", "res://presentation"]:
		_scan(root, pattern, offenders)
	assert_eq(offenders, [], "plan 09: one place changes a count")


func _scan(dir_path: String, pattern: RegEx, offenders: Array[String]) -> void:
	for name in DirAccess.get_files_at(dir_path):
		if not name.ends_with(".gd") or name in ["economy.gd", "campaign_codec.gd"]:
			continue
		var text := FileAccess.get_file_as_string(dir_path.path_join(name))
		var n := 0
		for line in text.split("\n"):
			n += 1
			var t := line.strip_edges()
			if t.begins_with("#") or t.begins_with("var ") or t.begins_with("copy."):
				continue
			if pattern.search(t) != null:
				offenders.append("%s/%s:%d %s" % [dir_path, name, n, t])
	for sub in DirAccess.get_directories_at(dir_path):
		if sub == "fixtures":
			continue
		_scan(dir_path.path_join(sub), pattern, offenders)


## --- People follow the water (plan 09 §9.4) ---


func test_capacity_is_what_the_dry_fields_can_feed() -> void:
	assert_eq(Economy.capacity(_late()), 7 * BasinRules.FIELD_YIELD * BasinRules.MOUTHS_PER_FOOD)
	assert_eq(Economy.capacity(Opening.opening()), 0, "promises feed nobody")


func test_a_fed_camp_under_capacity_takes_in_one_idle_hand_a_day() -> void:
	var c := _late()
	var idle := c.hands(Campaign.Bucket.IDLE)
	var people := c.people()
	c.close_day()
	assert_eq(c.people(), people + 1)
	assert_eq(c.hands(Campaign.Bucket.IDLE), idle + 1)
	assert_eq(c.morning.arrived, 1)


func test_the_camp_never_grows_past_what_the_fields_feed() -> void:
	var c := _held()
	for i in 40:
		c.close_day()
	assert_eq(c.people(), Economy.capacity(c))


func test_a_camp_with_no_dry_fields_does_not_grow_or_shrink() -> void:
	var c := Opening.opening()
	var people := c.people()
	c.close_day()
	assert_eq(c.people(), people)
	assert_eq([c.morning.arrived, c.morning.left], [0, 0])


func test_a_short_meal_sends_one_person_away_per_ration_and_nobody_arrives() -> void:
	var c := _late()
	c.basin.bowl(Ring.POLDER_A).fields = 0
	c.basin.bowl(Ring.POLDER_B).fields = 0
	c.basin.bowl(Ring.TERRACE).fields = 0
	c.food = 0
	var people := c.people()
	c.close_day()
	var short: int = c.morning.meal["short"]
	assert_true(short > 0)
	assert_eq(c.morning.left, short)
	assert_eq(c.people(), people - short)
	assert_eq(c.morning.arrived, 0)


func test_a_ruined_field_sends_a_person_away() -> void:
	var c := Opening.opening()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.MUD
	c.basin.bowl(Ring.TERRACE).fields = 2
	var people := c.people()
	c.close_day()
	assert_eq(c.morning.fields_ruined.size(), 1)
	assert_eq(c.morning.left, 2)
	assert_eq(c.people(), people - 2)


func test_leavers_are_idle_first_and_never_the_roster() -> void:
	var c := Opening.opening()
	var roster := c.hands(Campaign.Bucket.ROSTER)
	for i in 30:
		c.lose_leaver()
	assert_eq(c.hands(Campaign.Bucket.IDLE), 0)
	assert_eq(c.hands(Campaign.Bucket.ROSTER), roster)
	assert_false(c.lose_leaver())
	assert_eq(c.people(), roster)


func test_the_pool_never_goes_negative_or_invents_hands() -> void:
	var c := _late()
	for i in 60:
		c.close_day()
		for bucket in Campaign.Bucket.values():
			assert_true(c.hands(bucket) >= 0)


func test_the_morning_says_who_came_and_who_left_in_words() -> void:
	var c := _late()
	c.close_day()
	var q = Queries.compute(c, "", [] as Array[int])
	assert_true(q.morning.has("1 came to the camp"))
	c.morning.left = 2
	q = Queries.compute(c, "", [] as Array[int])
	assert_true(q.morning.has("2 left the camp"))


## --- Starved, and the card's food line (plan 09 §9.5) ---


func test_starved_is_no_food_and_no_dry_field() -> void:
	var c := Opening.opening()
	assert_false(Ending.is_starved(c), "there is food")
	c.food = 0
	assert_true(Ending.is_starved(c), "no food, and the fields are promises")
	c = _late()
	c.food = 0
	assert_false(Ending.is_starved(c), "dry fields stand to bring more")
	for id in c.basin.ids():
		c.basin.bowl(id).fields = 0
	assert_true(Ending.is_starved(c))


func test_the_card_names_the_food_a_redirection_costs_in_counts() -> void:
	var c := _held()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.FALLING
	c.basin.bowl(Ring.TERRACE).fields = 2
	var p := RedirectionPreview.read(c, Ring.TERRACE)
	var lines := Queries.redirection_card(p, Ring.TERRACE)
	if int(p["food_lost"]) > 0:
		assert_true(lines.has("it costs %d food over the next %d days" % [p["food_lost"], p["horizon_days"]]))
	else:
		for line in lines:
			assert_false(line.contains("it costs"))
	p["food_lost"] = 5
	assert_true(Queries.redirection_card(p, Ring.TERRACE).has("it costs 5 food over the next %d days" % p["horizon_days"]))


func test_nothing_the_table_says_about_the_economy_is_a_bar_or_a_rate() -> void:
	var c := _late()
	c.close_day()
	var q = Queries.compute(c, Ring.TERRACE, [] as Array[int])
	var all = [q.food_lasts, q.scrap_line, q.currencies, q.people] + q.morning + q.dispatch.get("bowl_lines", []) + [q.dispatch.get("fuel_line", "")]
	for line in all:
		for banned in ["%", "goal", "target", "progress", "per day", "/day"]:
			assert_false(str(line).to_lower().contains(banned), "UI 8: '%s' in '%s'" % [banned, line])
