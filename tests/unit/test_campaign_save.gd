extends GutTest

## The campaign in the plan 4.6 store (plan 07 §7.5): one save, written at Day end and when home.

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")

const PATH := "user://test_campaign_save.json"


func before_each() -> void:
	_remove()


func after_each() -> void:
	_remove()


func _remove() -> void:
	for p in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _week() -> Campaign:
	var c := Opening.opening()
	c = AssignLaborCommand.new(Campaign.Bucket.IDLE, Campaign.Bucket.FIELDS).apply(c)
	for _day in 4:
		c = EndDayCommand.new().apply(c)
	c.basin.bowl(Ring.RIDGE_W).hang_days = 3
	return c


func _same(a: Campaign, b: Campaign) -> void:
	assert_eq([a.day, a.food, a.fuel, a.scrap], [b.day, b.food, b.fuel, b.scrap])
	assert_eq(a.bench, b.bench)
	assert_eq(a.assignments_today, b.assignments_today)
	for bucket in Campaign.Bucket.values():
		assert_eq(a.hands(bucket), b.hands(bucket), "labor %d" % bucket)
	assert_eq(a.basin.ids(), b.basin.ids())
	for id in a.basin.ids():
		var x := a.basin.bowl(id)
		var y := b.basin.bowl(id)
		assert_eq(
			[x.grade, x.step, x.pump, x.neglect, x.feeders, x.leak_days, x.walk, x.walk_days_left, x.hang_days, x.known, x.instrumented],
			[y.grade, y.step, y.pump, y.neglect, y.feeders, y.leak_days, y.walk, y.walk_days_left, y.hang_days, y.known, y.instrumented],
			id,
		)


func test_a_campaign_survives_a_round_trip_through_json() -> void:
	var c := _week()
	var json := JSON.stringify(CampaignCodec.to_dict(c))
	var parsed: Variant = JSON.parse_string(json)
	var back := CampaignCodec.from_dict(parsed)
	assert_not_null(back)
	_same(c, back)


func test_the_morning_read_survives_the_round_trip() -> void:
	var c := Opening.opening()
	c = AssignLaborCommand.new(Campaign.Bucket.PUMPS, Campaign.Bucket.IDLE, 2).apply(c)
	for _day in BasinRules.BREAKS_AFTER_DAYS:
		c = EndDayCommand.new().apply(c)
	assert_false(c.morning.pumps_broke.is_empty(), "precondition: something to read")
	var back := CampaignCodec.from_dict(JSON.parse_string(JSON.stringify(CampaignCodec.to_dict(c))))
	assert_eq(back.morning.pumps_broke, c.morning.pumps_broke)
	assert_eq(back.morning.moved.size(), c.morning.moved.size())
	assert_eq(back.morning.upkeep_changed.size(), c.morning.upkeep_changed.size())


func test_a_saved_campaign_reloads_to_the_same_day_basin_and_bench() -> void:
	var c := _week()
	CampaignSave.save_campaign(c, PATH)
	var back := CampaignSave.load_campaign(PATH)
	assert_not_null(back)
	_same(c, back)
	assert_gt(c.day, 1)


func test_no_save_means_no_campaign() -> void:
	assert_null(CampaignSave.load_campaign(PATH))


func test_a_damaged_campaign_starts_fresh_and_never_crashes() -> void:
	var store := KnowledgeStore.fresh(PATH)
	store.campaign_data = {"day": "x", "food": 1}
	store.save()
	assert_null(CampaignSave.load_campaign(PATH), "missing fields")
	store.campaign_data = {"day": 2, "food": 1, "fuel": 1, "scrap": 1, "labor": {"99": 1}, "bench": [], "basin": []}
	store.save()
	assert_null(CampaignSave.load_campaign(PATH), "a bucket that does not exist")
	store.campaign_data = {"day": 2, "food": 1, "fuel": 1, "scrap": 1, "labor": {}, "bench": [], "basin": [7]}
	store.save()
	assert_null(CampaignSave.load_campaign(PATH), "a bowl that is not a record")


func test_the_campaign_rides_beside_the_knowledge_and_neither_loses_the_other() -> void:
	var store := KnowledgeStore.fresh(PATH)
	store.bowls["terrace"] = {"visit_index": 3, "cells": {}, "unrecovered": []}
	store.save()
	CampaignSave.save_campaign(_week(), PATH)
	var reloaded := KnowledgeStore.load_from(PATH)
	assert_eq(int(reloaded.bowls["terrace"]["visit_index"]), 3, "the fog memory is still there")
	assert_false(reloaded.campaign_data.is_empty())
	## A fight ending writes the store: the campaign must come through it.
	reloaded.save()
	assert_not_null(CampaignSave.load_campaign(PATH), "a fight's write did not lose the campaign")
	assert_eq(int(KnowledgeStore.load_from(PATH).bowls["terrace"]["visit_index"]), 3)


func test_an_old_store_with_no_campaign_still_loads() -> void:
	var store := KnowledgeStore.fresh(PATH)
	store.bowls["street"] = {"visit_index": 1, "cells": {}, "unrecovered": []}
	store.save()
	var text := FileAccess.get_file_as_string(PATH)
	assert_false(text.contains("campaign"), "nothing written for a campaign that does not exist")
	assert_null(CampaignSave.load_campaign(PATH))
	assert_eq(int(KnowledgeStore.load_from(PATH).bowls["street"]["visit_index"]), 1)


func test_a_save_is_never_resumed_with_the_fireteam_out() -> void:
	var c := Opening.opening()
	c = DispatchCommand.new(Ring.TERRACE, [1, 2] as Array[int]).apply(c)
	assert_false(c.deployment.is_empty())
	CampaignSave.save_campaign(c, PATH)
	var back := CampaignSave.load_campaign(PATH)
	assert_true(back.deployment.is_empty(), "an abandoned fight keeps nothing: everyone is home")
	assert_false(back.dispatched_today)
