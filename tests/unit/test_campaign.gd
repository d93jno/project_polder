extends GutTest

## The campaign and the labor board (plan 07 §7.2).

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")

const B := Campaign.Bucket


func _assign(from: Campaign.Bucket, to: Campaign.Bucket, hands: int = 1) -> AssignLaborCommand:
	return AssignLaborCommand.new(from, to, hands)


func test_the_opening_has_ten_people_and_the_four_currencies_as_plain_counts() -> void:
	var c := Opening.opening()
	assert_eq(c.people(), 10, "GDD 4.2's working default is 8 to 12")
	assert_eq([c.food, c.fuel, c.scrap], [12, 4, 6])
	assert_eq(c.bench.size(), 4)
	assert_eq(c.day, 1)
	assert_eq(c.labor.size(), Campaign.Bucket.values().size(), "a short board of buckets, not people")


func test_moving_hands_conserves_people() -> void:
	var c := Opening.opening()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var buckets := Campaign.Bucket.values()
	for _i in 200:
		var cmd := _assign(
			buckets[rng.randi_range(0, buckets.size() - 1)],
			buckets[rng.randi_range(0, buckets.size() - 1)],
			rng.randi_range(1, 3),
		)
		c.assignments_today = 0 ## the budget has its own test
		if cmd.validate(c).ok:
			c = cmd.apply(c)
		assert_eq(c.people(), 10, "no assignment makes or loses a person")
		for bucket in buckets:
			assert_gte(c.hands(bucket), 0)


func test_an_assignment_that_would_go_below_zero_fails_with_a_reason() -> void:
	var c := Opening.opening()
	var cmd := _assign(B.RESEARCH, B.PUMPS, 1)
	assert_false(cmd.validate(c).ok)
	assert_eq(cmd.validate(c).reason, "not enough hands in research")
	assert_eq(_assign(B.IDLE, B.PUMPS, 5).validate(c).reason, "not enough hands in idle")


func test_a_pointless_assignment_says_so() -> void:
	var c := Opening.opening()
	assert_eq(_assign(B.IDLE, B.IDLE).validate(c).reason, "they are already there")
	assert_eq(_assign(B.IDLE, B.PUMPS, 0).validate(c).reason, "move at least one hand")
	assert_eq(_assign(B.IDLE, B.PUMPS, -2).validate(c).reason, "move at least one hand")


func test_a_table_day_has_a_handful_of_assignments() -> void:
	var c := Opening.opening()
	for i in Campaign.ASSIGNMENTS_PER_DAY:
		assert_true(_assign(B.IDLE, B.FIELDS).validate(c).ok, "assignment %d" % (i + 1))
		c = _assign(B.IDLE, B.FIELDS).apply(c)
	var over := _assign(B.IDLE, B.FIELDS)
	assert_false(over.validate(c).ok)
	assert_eq(over.validate(c).reason, "a day has only %d assignments" % Campaign.ASSIGNMENTS_PER_DAY)


func test_an_assignment_changes_a_copy_and_leaves_the_campaign_alone() -> void:
	var c := Opening.opening()
	var after := _assign(B.IDLE, B.PUMPS, 2).apply(c)
	assert_eq(after.hands(B.PUMPS), 4)
	assert_eq(c.hands(B.PUMPS), 2, "the campaign it came from still reads its own board")
	assert_eq(c.assignments_today, 0)
	assert_eq(after.assignments_today, 1)
	assert_not_same(after.basin, c.basin)


func test_a_duplicated_campaign_is_independent() -> void:
	var c := Opening.opening()
	var copy := c.duplicate_campaign()
	copy.labor[B.FIELDS] = 99
	copy.bench.append(9)
	copy.basin.bowl(Ring.TERRACE).neglect = 5
	copy.scrap = 0
	assert_eq(c.hands(B.FIELDS), 2)
	assert_eq(c.bench.size(), 4)
	assert_eq(c.basin.bowl(Ring.TERRACE).neglect, 0)
	assert_eq(c.scrap, 6)


## --- Posting pumps ---


func test_hands_post_the_most_neglected_pumps_first() -> void:
	var c := Opening.opening() ## two hands on pumps; three known pumps
	c.basin.bowl(Ring.TERRACE).neglect = 3
	c.basin.bowl(Ring.RIDGE_N).neglect = 1
	var posted := c.posted_pumps()
	assert_eq(posted.size(), 2)
	assert_true(posted.has(Ring.TERRACE), "the one that is wearing most")
	assert_true(posted.has(Ring.RIDGE_N))
	assert_false(posted.has(Ring.RIDGE_W))


func test_ties_post_in_the_basins_authored_order() -> void:
	var c := Opening.opening()
	var posted := c.posted_pumps()
	assert_true(posted.has(Ring.RIDGE_W) and posted.has(Ring.RIDGE_N))
	assert_false(posted.has(Ring.TERRACE))


func test_scrap_short_means_fewer_posts() -> void:
	var c := Opening.opening()
	c.scrap = 1
	assert_eq(c.posted_pumps().size(), 1)
	c.scrap = 0
	assert_eq(c.posted_pumps().size(), 0, "hands with no scrap keep nothing")


func test_hands_short_means_fewer_posts() -> void:
	var c := Opening.opening()
	c.labor[B.PUMPS] = 0
	c.labor[B.IDLE] = 6
	assert_eq(c.posted_pumps().size(), 0)
	c.labor[B.PUMPS] = 1
	c.labor[B.IDLE] = 5
	assert_eq(c.posted_pumps().size(), 1)


func test_hands_cannot_reach_a_bowl_nobody_has_walked_or_a_dead_pump() -> void:
	var c := Opening.opening()
	c.labor[B.PUMPS] = 9
	c.labor[B.IDLE] = 0
	c.scrap = 99
	var posted := c.posted_pumps()
	assert_eq(posted.size(), 3, "only the three bowls that have been walked")
	assert_false(posted.has(Ring.SUMP))
	c.basin.bowl(Ring.TERRACE).pump = BasinBowl.Pump.DEAD
	assert_false(c.posted_pumps().has(Ring.TERRACE), "a dead pump is not kept, it is a repair")
