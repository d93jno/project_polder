extends GutTest

## Mail (plan 10 §10.3): what a band's eyes heard, arriving late, naming a bowl it never makes known.

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")
const Queries := preload("res://presentation/table_queries.gd")


## The Wake-Riders met, on EYES, standing at polder_a: a bowl the player has not walked.
func _watching() -> Campaign:
	var c := Opening.opening()
	Bands.meet_at(c, Ring.TERRACE)
	var b := Bands.band(c, "wake_riders")
	b.route = [Ring.POLDER_A] as Array[String]
	b.at = 0
	return c


func _day_with_pump_broken(bowl: String) -> DayResult:
	var r := DayResult.new()
	r.pumps_broke = [bowl] as Array[String]
	return r


func test_a_report_arrives_exactly_the_lag_after_the_morning_the_event_shows() -> void:
	var c := _watching()
	var reports := Mail.read(c, _day_with_pump_broken(Ring.POLDER_A), 5)
	assert_eq(reports.size(), 1)
	assert_eq(reports[0].happened_day, 5)
	assert_eq(reports[0].arrives_day, 5 + BasinRules.MAIL_LAG_DAYS)
	c.inbox = reports
	assert_eq(Mail.deliver(c, 5 + BasinRules.MAIL_LAG_DAYS - 1).size(), 0, "never early")
	assert_eq(Mail.deliver(c, 5 + BasinRules.MAIL_LAG_DAYS).size(), 1)
	assert_eq(c.inbox.size(), 0, "and it is delivered once")


func test_radio_takes_the_lag_away() -> void:
	var c := _watching()
	c.radio = true
	var reports := Mail.read(c, _day_with_pump_broken(Ring.POLDER_A), 5)
	assert_eq(reports[0].arrives_day, 5)


func test_each_event_is_reported_where_the_band_stands_and_nowhere_else() -> void:
	var c := _watching()
	var r := DayResult.new()
	r.moved = [{"id": Ring.POLDER_A, "from": Taxonomy.WaterStep.DRY, "to": Taxonomy.WaterStep.MUD}, {"id": Ring.SUMP, "from": 3, "to": 2}]
	r.walks_started = [{"id": Ring.POLDER_A, "dir": BasinBowl.Walk.WETTER, "in_days": 2}, {"id": Ring.RIDGE_E, "dir": BasinBowl.Walk.DRIER, "in_days": 2}]
	r.pumps_broke = [Ring.POLDER_A, Ring.POLDER_B] as Array[String]
	var reports := Mail.read(c, r, 7)
	assert_eq(reports.size(), 3)
	for e in reports:
		assert_eq(e.bowl_id, Ring.POLDER_A)


func test_only_a_warm_met_band_on_eyes_reports() -> void:
	var r := _day_with_pump_broken(Ring.POLDER_A)
	var c := Opening.opening()
	Bands.band(c, "wake_riders").route = [Ring.POLDER_A] as Array[String]
	assert_eq(Mail.read(c, r, 3).size(), 0, "an unmet band")
	c = _watching()
	Bands.band(c, "wake_riders").warm = false
	assert_eq(Mail.read(c, r, 3).size(), 0, "a cold band")
	c = _watching()
	Bands.band(c, "wake_riders").job = Band.Job.FOOD
	assert_eq(Mail.read(c, r, 3).size(), 0, "a band on another job")


func test_a_heard_bowl_is_still_unknown_to_every_table_read() -> void:
	var c := _watching()
	c.inbox = Mail.read(c, _day_with_pump_broken(Ring.POLDER_A), 1)
	c.day = 1 + BasinRules.MAIL_LAG_DAYS
	c.morning = DayResult.new()
	c.morning.heard = Mail.deliver(c, c.day)
	assert_false(c.basin.bowl(Ring.POLDER_A).known)
	var q = Queries.compute(c, Ring.POLDER_A, [] as Array[int])
	assert_true(q.morning.has("heard: polder_a, the pump broke, 2 days ago"))
	assert_false(WaterGraph.read(c.basin, Ring.POLDER_A).get("known", false), "hearing is not walking")
	assert_false(q.dispatch.has("bowl_lines"), "the dispatch still has nothing to say about it")


func test_the_mail_for_a_bowl_the_player_knows_adds_nothing_to_the_dome() -> void:
	var c := Opening.opening()
	var e := MailEntry.new("wake_riders", Ring.TERRACE, MailEntry.Event.PUMP_BROKE, 1, 3)
	c.day = 3
	assert_eq(Queries.heard_line(c, e), "")


func test_a_report_never_names_what_stands_in_the_bowl() -> void:
	var c := _watching()
	c.basin.bowl(Ring.POLDER_A).fields = 3
	c.basin.bowl(Ring.POLDER_A).camps = 2
	c.day = 3
	for event in MailEntry.Event.values():
		var line := Queries.heard_line(c, MailEntry.new("wake_riders", Ring.POLDER_A, event, 1, 3, 3, 2))
		for banned in ["field", "camp", "post", "road", "%"]:
			assert_false(line.contains(banned), "'%s' in '%s'" % [banned, line])


func test_the_whole_day_tick_carries_a_pump_break_to_the_morning_two_days_late() -> void:
	var c := _watching()
	var broke_on := -1
	var heard_on := -1
	for i in 14:
		c.close_day()
		if broke_on < 0 and c.morning.pumps_broke.has(Ring.POLDER_A):
			broke_on = c.day
		for e in c.morning.heard:
			if e.event == MailEntry.Event.PUMP_BROKE and e.bowl_id == Ring.POLDER_A and heard_on < 0:
				heard_on = c.day
	assert_true(broke_on > 0, "the unposted pump broke")
	assert_eq(heard_on, broke_on + BasinRules.MAIL_LAG_DAYS)


func test_the_inbox_and_the_morning_are_saved() -> void:
	var c := _watching()
	c.inbox = Mail.read(c, _day_with_pump_broken(Ring.POLDER_A), 4)
	c.morning = DayResult.new()
	c.morning.heard = [MailEntry.new("wake_riders", Ring.POLDER_A, MailEntry.Event.STEP_LANDED, 2, 4, 3, 2)]
	var path := "user://mail_test_save.json"
	CampaignSave.save_campaign(c, path)
	var loaded = CampaignSave.load_campaign(path)
	DirAccess.remove_absolute(path)
	assert_eq(loaded.inbox.size(), 1)
	assert_eq(loaded.inbox[0].arrives_day, 4 + BasinRules.MAIL_LAG_DAYS)
	assert_eq(loaded.morning.heard.size(), 1)
	assert_eq([loaded.morning.heard[0].from, loaded.morning.heard[0].to], [3, 2])


func test_a_branch_leaves_the_inbox_it_came_from_alone() -> void:
	var c := _watching()
	c.inbox = Mail.read(c, _day_with_pump_broken(Ring.POLDER_A), 4)
	var branch := c.duplicate_campaign()
	branch.inbox.clear()
	assert_eq(c.inbox.size(), 1)


func test_a_band_follows_its_route_every_few_days_and_a_one_bowl_band_stays() -> void:
	var c := Opening.opening()
	var riders := Bands.band(c, "wake_riders")
	assert_eq(riders.bowl_id(), Ring.TERRACE)
	for i in 6:
		c.close_day()
	assert_eq(riders.bowl_id(), Ring.TERRACE, "the campaign it came from is untouched")
	var moved := Bands.band(c, "wake_riders")
	assert_eq(c.day, 7)
	assert_eq(moved.bowl_id(), Ring.TERRACE, "two steps on a two-bowl route is home again")
	assert_eq(Bands.band(c, "roof_clan").bowl_id(), Ring.RIDGE_W)
	c = Opening.opening()
	for i in BasinRules.BAND_MOVE_DAYS - 1:
		c.close_day()
	assert_eq(Bands.band(c, "wake_riders").bowl_id(), Ring.POLDER_A)
