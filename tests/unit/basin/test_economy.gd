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
	assert_eq(c.morning.meal, {"ate": 0, "short": 3})


func test_eating_does_not_touch_the_people_or_the_labor() -> void:
	var c := Opening.opening()
	var labor := c.labor.duplicate()
	c.food = 0
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
