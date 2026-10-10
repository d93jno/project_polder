extends GutTest

## Day end (plan 07 §7.2): one commit that posts, spends, ticks and opens the morning.

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")

const B := Campaign.Bucket


func _days(campaign: Campaign, n: int) -> Campaign:
	var c := campaign
	for _i in n:
		c = EndDayCommand.new().apply(c)
	return c


func _with_pumps(hands: int, scrap: int = 99) -> Campaign:
	var c := Opening.opening()
	c.labor[B.IDLE] = c.hands(B.IDLE) + c.hands(B.PUMPS) - hands
	c.labor[B.PUMPS] = hands
	c.scrap = scrap
	c.food = 10000 ## these tests are about the water; a hungry camp sends its hands away (plan 09)
	return c


func test_day_end_is_a_confirmed_action() -> void:
	assert_true(EndDayCommand.new().needs_confirm(Opening.opening()))
	assert_false(AssignLaborCommand.new(B.IDLE, B.FIELDS).needs_confirm(Opening.opening()))


func test_a_day_ends_into_the_next_morning() -> void:
	var c := Opening.opening()
	c = AssignLaborCommand.new(B.IDLE, B.FIELDS).apply(c)
	var next := EndDayCommand.new().apply(c)
	assert_eq(next.day, 2)
	assert_eq(next.assignments_today, 0, "a new day has its assignments back")
	assert_false(next.dispatched_today)
	assert_not_null(next.morning, "what moved overnight is kept as data for the morning read")
	assert_same(next.morning.basin, next.basin)
	assert_eq(next.people(), 10)


func test_day_end_spends_the_scrap_it_posted() -> void:
	var c := Opening.opening() ## two hands, six scrap
	var next := EndDayCommand.new().apply(c)
	assert_eq(next.scrap, 6 - 2 * Campaign.SCRAP_PER_POST)


func test_day_end_leaves_the_campaign_it_came_from_alone() -> void:
	var c := Opening.opening()
	EndDayCommand.new().apply(c)
	assert_eq(c.day, 1)
	assert_eq(c.scrap, 6)
	assert_null(c.morning)
	assert_eq(c.basin.bowl(Ring.TERRACE).neglect, 0)


func test_a_day_is_deterministic() -> void:
	var a := _days(Opening.opening(), 12)
	var b := _days(Opening.opening(), 12)
	assert_eq(a.day, b.day)
	assert_eq(a.scrap, b.scrap)
	for id in a.basin.ids():
		assert_eq(a.basin.bowl(id).step, b.basin.bowl(id).step, id)
		assert_eq(a.basin.bowl(id).neglect, b.basin.bowl(id).neglect, id)


func test_the_hands_on_the_pumps_decide_whether_the_pumps_hold() -> void:
	var worst := {}
	for hands in [0, 1, 2, 3]:
		var c := _with_pumps(hands)
		var thinnest := 0
		var broke := false
		for _day in 20:
			c = EndDayCommand.new().apply(c)
			for id in [Ring.RIDGE_W, Ring.RIDGE_N, Ring.TERRACE]:
				thinnest = maxi(thinnest, c.basin.bowl(id).neglect)
				if c.basin.bowl(id).pump == BasinBowl.Pump.DEAD:
					broke = true
		worst[hands] = {"neglect": thinnest, "broke": broke}
	assert_true(worst[0]["broke"], "no hands, and the pumps break")
	assert_false(worst[1]["broke"], "one hand, rotated over three pumps, keeps them from breaking")
	assert_eq(worst[1]["neglect"], BasinRules.THIN_AFTER_DAYS, "but they all run thin, the read that tells a wrench where to go")
	assert_false(worst[3]["broke"], "a hand for each pump holds them all")
	assert_lt(worst[2]["neglect"], BasinRules.THIN_AFTER_DAYS, "two hands rotated over three pumps keep them all kept")
	assert_lt(worst[3]["neglect"], worst[1]["neglect"])


func test_moving_hands_off_the_pumps_measurably_thins_them_over_the_following_days() -> void:
	var kept := _days(_with_pumps(3), 4)
	var left := _days(_with_pumps(0), 4)
	for id in [Ring.RIDGE_W, Ring.RIDGE_N, Ring.TERRACE]:
		assert_eq(kept.basin.bowl(id).upkeep(), BasinBowl.Upkeep.KEPT, id)
		assert_eq(left.basin.bowl(id).upkeep(), BasinBowl.Upkeep.FAILING, id)


func test_running_out_of_scrap_is_what_ends_the_keeping() -> void:
	var c := _with_pumps(3, 3) ## three scrap buys one day of three posts, then nothing
	c = _days(c, 1)
	assert_eq(c.scrap, 0)
	var after := _days(c, 3)
	for id in [Ring.RIDGE_W, Ring.RIDGE_N, Ring.TERRACE]:
		assert_eq(after.basin.bowl(id).neglect, 3, "hands with no scrap keep nothing")


func test_a_table_day_decides_tomorrows_map() -> void:
	## The same basin, two labor plans: the water ends up in different places (UI filter 10).
	var posted := _days(_with_pumps(3), 25)
	var unposted := _days(_with_pumps(0), 25)
	assert_gt(
		int(posted.basin.bowl(Ring.RIDGE_W).step),
		int(unposted.basin.bowl(Ring.RIDGE_W).step),
		"a kept rim pump has dried its bowl further than one left to break"
	)
	assert_eq(unposted.basin.bowl(Ring.RIDGE_W).pump, BasinBowl.Pump.DEAD)
	assert_eq(posted.basin.bowl(Ring.RIDGE_W).pump, BasinBowl.Pump.ON)
