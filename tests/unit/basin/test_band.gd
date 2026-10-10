extends GutTest

## A band is a person in a place (plan 10 §10.0).

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")


func test_the_opening_authors_unmet_bands_at_the_start_of_their_routes() -> void:
	var c := Opening.opening()
	assert_eq(c.bands.size(), 2)
	var riders := Bands.band(c, "wake_riders")
	assert_false(riders.met())
	assert_eq(riders.bowl_id(), Ring.TERRACE)
	assert_eq(riders.job, Band.Job.EYES)
	assert_eq(Bands.band(c, "roof_clan").bowl_id(), Ring.RIDGE_W)
	assert_null(Bands.band(c, "nobody"))


func test_an_unmet_band_is_not_warm_for_the_ending() -> void:
	var c := Opening.opening()
	assert_eq(Bands.warm_count(c), 0, "an unmet band is nobody's friend yet")
	assert_false(Ending.has_warm_band(c))


func test_meeting_a_band_makes_it_warm_and_keeps_its_job() -> void:
	var c := Opening.opening()
	c.day = 3
	var met := Bands.meet_at(c, Ring.TERRACE)
	assert_eq(met, ["wake_riders"] as Array[String])
	var b := Bands.band(c, "wake_riders")
	assert_true(b.met() and b.warm)
	assert_eq(b.met_day, 3)
	assert_eq(b.job, Band.Job.EYES)
	assert_true(Ending.has_warm_band(c))


func test_a_band_is_met_only_where_it_stands_and_only_once() -> void:
	var c := Opening.opening()
	assert_eq(Bands.meet_at(c, Ring.SUMP), [] as Array[String])
	assert_eq(Bands.why_not_met(c, Bands.band(c, "wake_riders"), Ring.RIDGE_W), "not there")
	Bands.meet_at(c, Ring.TERRACE)
	assert_eq(Bands.meet_at(c, Ring.TERRACE), [] as Array[String], "once")
	assert_eq(Bands.why_not_met(c, Bands.band(c, "wake_riders"), Ring.TERRACE), "already met")


func test_a_ring_holds_only_so_many_bands() -> void:
	var c := Opening.opening()
	c.bands.clear()
	for i in BasinRules.BANDS_PER_RING + 1:
		var route: Array[String] = [Ring.TERRACE]
		c.bands.append(Band.new("b%d" % i, Band.Job.EYES, route))
	var met := Bands.meet_at(c, Ring.TERRACE)
	assert_eq(met.size(), BasinRules.BANDS_PER_RING)
	var last := Bands.band(c, "b%d" % BasinRules.BANDS_PER_RING)
	assert_false(last.met())
	assert_eq(Bands.why_not_met(c, last, Ring.TERRACE), "the ring holds no more bands")
	assert_eq(Bands.met_in_ring(c, Ring.POLDER_A), BasinRules.BANDS_PER_RING, "the ring is the grade, not the bowl")


func test_another_ring_has_its_own_room() -> void:
	var c := Opening.opening()
	assert_eq(Bands.meet_at(c, Ring.RIDGE_W).size(), 1)
	assert_eq(Bands.meet_at(c, Ring.TERRACE).size(), 1)


func test_a_branch_leaves_the_campaign_it_came_from_untouched() -> void:
	var c := Opening.opening()
	var branch := c.duplicate_campaign()
	Bands.meet_at(branch, Ring.TERRACE)
	assert_false(Bands.band(c, "wake_riders").met())
	assert_true(Bands.band(branch, "wake_riders").met())


func test_bands_survive_a_save() -> void:
	var c := Opening.opening()
	c.day = 4
	Bands.meet_at(c, Ring.TERRACE)
	Bands.band(c, "roof_clan").warm = false
	Bands.band(c, "roof_clan").cold_cause = "flood"
	var path := "user://band_test_save.json"
	CampaignSave.save_campaign(c, path)
	var loaded = CampaignSave.load_campaign(path)
	DirAccess.remove_absolute(path)
	var riders: Band = Bands.band(loaded, "wake_riders")
	assert_eq([riders.met_day, riders.warm, riders.job], [4, true, Band.Job.EYES])
	var clan: Band = Bands.band(loaded, "roof_clan")
	assert_eq([clan.met(), clan.warm, clan.cold_cause], [false, false, "flood"])
	assert_eq(riders.route, [Ring.TERRACE, Ring.POLDER_A] as Array[String])


func test_a_save_from_before_bands_opens_with_the_authored_ones() -> void:
	var c := Opening.opening()
	var data := CampaignCodec.to_dict(c)
	data.erase("bands")
	assert_eq(CampaignCodec.from_dict(data).bands.size(), 2)


func test_a_cold_band_is_not_warm() -> void:
	var c := Opening.opening()
	Bands.meet_at(c, Ring.TERRACE)
	Bands.band(c, "wake_riders").warm = false
	assert_eq(Bands.warm_count(c), 0)
	assert_false(Ending.has_warm_band(c))


func test_only_the_band_rules_change_a_band() -> void:
	var pattern := RegEx.create_from_string("\\b(warm|job|met_day|cold_cause|name_given)\\s*=(?!=)")
	var offenders: Array[String] = []
	for root in ["res://rules", "res://presentation"]:
		_scan(root, pattern, offenders)
	assert_eq(offenders, [], "plan 10: one place changes a band")


func _scan(dir_path: String, pattern: RegEx, offenders: Array[String]) -> void:
	for name in DirAccess.get_files_at(dir_path):
		if not name.ends_with(".gd") or name in ["band.gd", "bands.gd", "campaign_codec.gd"]:
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
