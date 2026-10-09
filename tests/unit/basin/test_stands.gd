extends GutTest

## What stands in a bowl (plan 08 §7.2, §8.1): counts a redirection can drown, and Mud ruining a field.

const Ring := preload("res://rules/fixtures/basin_ring.gd")


func _all_posted(basin: Basin) -> Dictionary:
	var posted := {}
	for id in basin.ids():
		posted[id] = true
	return posted


func test_a_known_bowl_reads_what_the_player_has_there() -> void:
	var read := WaterGraph.read(Ring.late_ring(), Ring.POLDER_A)
	assert_eq(read["stands"], {"fields": 3, "camps": 0, "posts": 0, "ruined": 0, "road": true})


func test_a_bowl_nobody_has_walked_does_not_read_its_stands() -> void:
	var basin := Ring.opening()
	basin.bowl(Ring.SUMP).fields = 5
	var read := WaterGraph.read(basin, Ring.SUMP)
	assert_false(read.has("stands"), "unknown is unknown, whatever is on the bowl")


func test_the_opening_has_a_camp_and_a_post_on_the_walked_wet_bowls_and_no_fields() -> void:
	var basin := Ring.opening()
	assert_eq(basin.bowl(Ring.TERRACE).camps, 1)
	assert_eq(basin.bowl(Ring.TERRACE).posts, 1)
	for id in basin.ids():
		assert_eq(basin.bowl(id).fields, 0, "no fields on wet ground")


func test_a_field_in_a_bowl_that_goes_to_mud_is_ruined_once() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.POLDER_B).step = Taxonomy.WaterStep.MUD
	var result := BasinDay.end(basin, _all_posted(basin))
	var bowl := result.basin.bowl(Ring.POLDER_B)
	assert_eq(bowl.fields, 0)
	assert_eq(bowl.ruined, 2)
	assert_eq(result.fields_ruined, [{"id": Ring.POLDER_B, "count": 2}] as Array[Dictionary])
	var again := BasinDay.end(result.basin, _all_posted(result.basin))
	assert_eq(again.basin.bowl(Ring.POLDER_B).ruined, 2, "ruined once, not again")
	assert_true(again.fields_ruined.is_empty())


func test_a_ruined_field_stays_ruined_when_the_water_recedes() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.POLDER_B).step = Taxonomy.WaterStep.FLOODED
	var posted := _all_posted(basin)
	basin = BasinDay.end(basin, posted).basin
	assert_eq(basin.bowl(Ring.POLDER_B).ruined, 2)
	basin.bowl(Ring.POLDER_B).step = Taxonomy.WaterStep.DRY
	for _day in 5:
		basin = BasinDay.end(basin, posted).basin
	assert_eq(basin.bowl(Ring.POLDER_B).fields, 0, "a dry bowl does not grow them back")
	assert_eq(basin.bowl(Ring.POLDER_B).ruined, 2)


func test_posts_camps_and_the_road_are_listed_in_a_wet_bowl_not_destroyed() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.POLDER_A).step = Taxonomy.WaterStep.FLOODED
	basin.bowl(Ring.POLDER_A).camps = 2
	basin.bowl(Ring.POLDER_A).posts = 1
	basin = BasinDay.end(basin, _all_posted(basin)).basin
	var bowl := basin.bowl(Ring.POLDER_A)
	assert_eq([bowl.camps, bowl.posts, bowl.road], [2, 1, true])
	assert_eq(bowl.ruined, 3, "only the fields went")


func test_a_dry_or_falling_bowl_keeps_its_fields() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.POLDER_A).step = Taxonomy.WaterStep.FALLING ## Falling is not Mud: nothing grows, but nothing ruined by it either here
	var result := BasinDay.end(basin, _all_posted(basin))
	## Falling is wetter than Mud, so a field there is ruined: the rule is "Mud or wetter".
	assert_eq(result.basin.bowl(Ring.POLDER_A).ruined, 3)
	var dry := BasinDay.end(Ring.late_ring(), _all_posted(Ring.late_ring()))
	assert_true(dry.fields_ruined.is_empty(), "dry ground ruins nothing")
	assert_eq(dry.basin.bowl(Ring.POLDER_A).fields, 3)


func test_a_redirection_drowns_the_fields_it_reaches() -> void:
	## The terrace redirected to Flooded loses its fields; the polder it pushes toward Mud loses its.
	var basin := Ring.late_ring()
	basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.FLOODED
	basin.bowl(Ring.TERRACE).hang_days = BasinRules.REDIRECTION_HANG_DAYS
	var posted := _all_posted(basin)
	for _day in 6:
		basin = BasinDay.end(basin, posted).basin
	assert_eq(basin.bowl(Ring.TERRACE).ruined, 2)
	assert_eq(basin.bowl(Ring.POLDER_B).ruined, 2)
	assert_eq(basin.bowl(Ring.POLDER_A).fields, 3, "the other polder is untouched")


func test_the_day_result_counts_a_ruin_as_something_that_moved() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.POLDER_B).step = Taxonomy.WaterStep.MUD
	assert_true(BasinDay.end(basin, _all_posted(basin)).anything_moved())


func test_stands_survive_the_save() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.POLDER_B).ruined = 4
	var campaign := Campaign.new()
	campaign.basin = basin
	var back := CampaignCodec.from_dict(JSON.parse_string(JSON.stringify(CampaignCodec.to_dict(campaign))))
	for id in basin.ids():
		var x := basin.bowl(id)
		var y := back.basin.bowl(id)
		assert_eq([x.fields, x.camps, x.posts, x.ruined, x.road], [y.fields, y.camps, y.posts, y.ruined, y.road], id)


func test_a_ruin_in_the_morning_survives_the_save() -> void:
	var basin := Ring.late_ring()
	basin.bowl(Ring.POLDER_B).step = Taxonomy.WaterStep.MUD
	var campaign := Campaign.new()
	campaign.basin = BasinDay.end(basin, _all_posted(basin)).basin
	campaign.morning = BasinDay.end(basin, _all_posted(basin))
	var back := CampaignCodec.from_dict(JSON.parse_string(JSON.stringify(CampaignCodec.to_dict(campaign))))
	assert_eq(back.morning.fields_ruined, [{"id": Ring.POLDER_B, "count": 2}] as Array[Dictionary])
