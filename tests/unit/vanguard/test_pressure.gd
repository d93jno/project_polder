extends GutTest

## The highland's pressure (plan 11 §11.0): hidden, stage by stage, never backwards.

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")


## A late ring, held: scrap and hands to keep every pump, so the water stands while the days run.
func _held() -> Campaign:
	var c := Opening.opening()
	c.basin = Ring.late_ring()
	c.scrap = 10000
	c.labor[Campaign.Bucket.FIELDS] = 0
	c.labor[Campaign.Bucket.PUMPS] = 7
	return c


func test_a_quiet_town_never_leaves_none() -> void:
	var c := Opening.opening()
	c.food = 10000
	for i in 60:
		c.close_day()
	assert_eq(c.pressure.stage, Pressure.Stage.NONE)


func test_a_loud_town_goes_watching_then_surveying_then_building_in_order() -> void:
	var c := _held()
	var seen: Array[int] = [0]
	var days: Array[int] = [c.day]
	for i in 80:
		c.close_day()
		if int(c.pressure.stage) != seen[-1]:
			seen.append(int(c.pressure.stage))
			days.append(c.day)
	assert_eq(seen, [0, 1, 2, 3], "one stage at a time, none skipped")
	for i in range(2, days.size()):
		assert_true(days[i] - days[i - 1] >= BasinRules.PRESSURE_STAGE_DAYS, "no sooner than the minimum days")


func test_the_stage_cannot_go_backwards() -> void:
	var c := _held()
	for i in 80:
		c.close_day()
	assert_eq(c.pressure.stage, Pressure.Stage.BUILDING)
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.FLOODED
	for i in 20:
		c.close_day()
	assert_eq(c.pressure.stage, Pressure.Stage.BUILDING)


func test_watching_and_surveying_advance_over_a_wet_floor_but_building_waits() -> void:
	var c := _held()
	c.basin.bowl(Ring.POLDER_B).step = Taxonomy.WaterStep.MUD
	c.basin.bowl(Ring.POLDER_B).fields = 0
	assert_false(Pressure.inner_ring_dry(c))
	c.pressure.stage = Pressure.Stage.SURVEYING
	c.pressure.last_change_day = 1
	c.day = 30
	assert_false(Pressure.ready_for(c, Pressure.Stage.BUILDING), "the inner ring is wet")
	c.pressure.tick(c)
	assert_eq(c.pressure.stage, Pressure.Stage.SURVEYING)
	c.basin.bowl(Ring.POLDER_B).step = Taxonomy.WaterStep.DRY
	assert_true(Pressure.inner_ring_dry(c))
	c.labor[Campaign.Bucket.IDLE] = 40 ## loud enough
	assert_true(c.pressure.tick(c))
	assert_eq(c.pressure.stage, Pressure.Stage.BUILDING)


func test_surveying_asks_for_a_field_as_well_as_noise() -> void:
	var c := Opening.opening()
	c.labor[Campaign.Bucket.IDLE] = 60 ## very loud, and no Dry field
	assert_true(Pressure.ready_for(c, Pressure.Stage.WATCHING))
	assert_false(Pressure.ready_for(c, Pressure.Stage.SURVEYING))


func test_the_minimum_days_between_stages_holds() -> void:
	var c := _held()
	c.labor[Campaign.Bucket.IDLE] = 60
	c.day = 10
	assert_true(c.pressure.tick(c))
	c.day = 10 + BasinRules.PRESSURE_STAGE_DAYS - 1
	assert_false(c.pressure.tick(c), "too soon")
	c.day = 10 + BasinRules.PRESSURE_STAGE_DAYS
	assert_true(c.pressure.tick(c))


func test_the_act_is_read_from_the_state() -> void:
	var c := Opening.opening()
	assert_eq(Ending.act(c), Ending.Act.I)
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.DRY
	assert_eq(Ending.act(c), Ending.Act.II)
	c.pressure.stage = Pressure.Stage.SURVEYING
	assert_eq(Ending.act(c), Ending.Act.II, "surveying alone is not Act III")
	c.pressure.stage = Pressure.Stage.BUILDING
	assert_eq(Ending.act(c), Ending.Act.III)
	assert_eq(c.pressure.stage, Pressure.Stage.BUILDING, "reading the act changes nothing")


func test_the_pressure_is_saved_and_a_branch_leaves_the_original_alone() -> void:
	var c := _held()
	c.pressure.stage = Pressure.Stage.SURVEYING
	c.pressure.last_change_day = 9
	var branch := c.duplicate_campaign()
	branch.pressure.stage = Pressure.Stage.BUILDING
	assert_eq(c.pressure.stage, Pressure.Stage.SURVEYING)
	var path := "user://pressure_test_save.json"
	CampaignSave.save_campaign(c, path)
	var loaded = CampaignSave.load_campaign(path)
	DirAccess.remove_absolute(path)
	assert_eq([loaded.pressure.stage, loaded.pressure.last_change_day], [Pressure.Stage.SURVEYING, 9])


func test_nothing_the_table_reads_names_the_pressure_or_its_loudness() -> void:
	for path in ["res://presentation/table_queries.gd", "res://presentation/table_view.gd", "res://presentation/table_board.gd"]:
		var text := FileAccess.get_file_as_string(path).to_lower()
		for banned in ["loudness", "pressure", "threshold"]:
			assert_false(text.contains(banned), "%s names '%s'" % [path, banned])


func test_only_the_pressure_rule_changes_the_stage() -> void:
	var pattern := RegEx.create_from_string("\\b(stage|last_change_day)\\s*=(?!=)")
	var offenders: Array[String] = []
	for root in ["res://rules", "res://presentation"]:
		_scan(root, pattern, offenders)
	assert_eq(offenders, [], "plan 11: one place changes the stage")


func _scan(dir_path: String, pattern: RegEx, offenders: Array[String]) -> void:
	for name in DirAccess.get_files_at(dir_path):
		if not name.ends_with(".gd") or name in ["pressure.gd", "campaign_codec.gd"]:
			continue
		var n := 0
		for line in FileAccess.get_file_as_string(dir_path.path_join(name)).split("\n"):
			n += 1
			var t := line.strip_edges()
			if t.begins_with("#") or t.begins_with("var ") or t.begins_with("copy."):
				continue
			if pattern.search(t) != null:
				offenders.append("%s/%s:%d %s" % [dir_path, name, n, t])
	for sub in DirAccess.get_directories_at(dir_path):
		if sub != "fixtures":
			_scan(dir_path.path_join(sub), pattern, offenders)
