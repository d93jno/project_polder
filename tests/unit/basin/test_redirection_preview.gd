extends GutTest

## The redirection preview (plan 08 §8.3): the rule run on a copy and diffed, so it cannot disagree.

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")
const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")

const TERRACE := Ring.TERRACE
const HORIZON := 14


## A late dry ring with the terrace in Mud: a sluice there leaves it Falling, two steps wetter than the
## Dry polders it feeds, which is what pushes them. (From Falling the world already pushes them.)
func _campaign() -> Campaign:
	var c := Opening.opening()
	c.basin = Ring.late_ring()
	c.basin.bowl(TERRACE).step = Taxonomy.WaterStep.MUD
	## Every pump posted, with the scrap to keep them: the water then moves only for the reasons under test.
	c.scrap = 99
	c.labor[Campaign.Bucket.PUMPS] = 7
	c.labor[Campaign.Bucket.IDLE] = 0
	return c


func _ids(preview: Dictionary) -> Array:
	return preview["bowls"].map(func(b): return b["id"])


func _entry(preview: Dictionary, id: String) -> Dictionary:
	for b in preview["bowls"]:
		if b["id"] == id:
			return b
	return {}


func _snapshot(c: Campaign) -> Array:
	var out: Array = [c.day, c.scrap, c.redirections.size(), c.cards_spent.size()]
	for id in c.basin.ids():
		var b := c.basin.bowl(id)
		out.append([id, b.step, b.pump, b.neglect, b.walk, b.walk_days_left, b.hang_days, b.fields, b.ruined])
	return out


func test_a_flooded_bowl_cannot_be_redirected_and_says_why() -> void:
	var c := _campaign()
	c.basin.bowl(TERRACE).step = Taxonomy.WaterStep.FLOODED
	var p := RedirectionPreview.read(c, TERRACE)
	assert_false(p["ok"])
	assert_eq(p["reason"], "the water is already as deep as it goes")


func test_it_names_the_step_the_sluice_leaves_and_how_long_the_target_hangs_wet() -> void:
	var p := RedirectionPreview.read(_campaign(), TERRACE)
	assert_true(p["ok"])
	assert_eq(p["from"], Taxonomy.WaterStep.MUD)
	assert_eq(p["to"], Taxonomy.WaterStep.FALLING)
	var terrace := _entry(p, TERRACE)
	assert_eq(terrace["distance"], 0)
	assert_eq(terrace["steps_wetter"], 1)
	assert_eq(terrace["peak"], Taxonomy.WaterStep.FALLING)
	assert_gte(terrace["set_back"], 1, "and it is held from drying as it would have")
	assert_gte(terrace["hang_days"], BasinRules.REDIRECTION_HANG_DAYS, "at least the hold")
	assert_false(terrace["beyond_horizon"])


func test_it_says_whether_the_creep_reaches_the_next_bowl_and_which() -> void:
	var p := RedirectionPreview.read(_campaign(), TERRACE)
	assert_true(p["creeps"])
	assert_true(Ring.POLDER_B in _ids(p), "the polder the terrace feeds is pushed")
	assert_false(Ring.POLDER_A in _ids(p), "the polder it does not feed is not")
	assert_false(Ring.RIDGE_W in _ids(p), "and the bowls that feed it never are")
	assert_eq(_entry(p, Ring.POLDER_B)["distance"], 1)


func test_it_says_what_of_the_players_stands_in_each_affected_bowl() -> void:
	var p := RedirectionPreview.read(_campaign(), TERRACE)
	var polder := _entry(p, Ring.POLDER_B)
	assert_eq(polder["stands"]["fields"], 2)
	assert_eq(polder["stands"]["posts"], 1)
	assert_eq(polder["stands"]["fields_lost"], 2, "the redirection is what ruins them")
	assert_eq(_entry(p, TERRACE)["stands"]["fields_lost"], 0, "the terrace was in Mud already: Mud ruined those fields anyway")


func test_it_changes_nothing() -> void:
	var c := _campaign()
	var before := _snapshot(c)
	RedirectionPreview.read(c, TERRACE)
	assert_eq(_snapshot(c), before, "campaign, basin, ledger and scrap are untouched")


func test_it_never_names_a_bowl_the_player_has_not_walked() -> void:
	var c := _campaign()
	c.basin.bowl(Ring.POLDER_B).known = false
	var p := RedirectionPreview.read(c, TERRACE)
	assert_false(Ring.POLDER_B in _ids(p))
	assert_gte(p["unknown_reached"], 1, "but it says the creep reaches ground not yet walked")
	assert_true(p["creeps"], "and that it spreads")


func test_a_fully_instrumented_ring_previews_exactly() -> void:
	var p := RedirectionPreview.read(_campaign(), TERRACE)
	assert_false(p["is_range"])
	for b in p["bowls"]:
		assert_eq(b["hang_days_min"], b["hang_days_max"], b["id"])


func test_a_half_fixed_ring_previews_as_a_range_one_day_wider_per_bowl_without_instruments() -> void:
	var c := _campaign()
	c.basin.bowl(Ring.POLDER_B).instrumented = false
	var p := RedirectionPreview.read(c, TERRACE)
	assert_true(p["is_range"])
	var polder := _entry(p, Ring.POLDER_B)
	assert_eq(polder["hang_days_max"], polder["hang_days_min"] + 1, "its own bowl lacks instruments")
	var terrace := _entry(p, TERRACE)
	assert_eq(terrace["hang_days_max"], terrace["hang_days_min"] + 1, "and the target is wider by that one")
	c.basin.bowl(TERRACE).instrumented = false
	var wider := _entry(RedirectionPreview.read(c, TERRACE), TERRACE)
	assert_eq(wider["hang_days_max"], wider["hang_days_min"] + 2, "two affected bowls lack instruments")


func test_the_horizon_is_what_it_says_and_a_hang_past_it_is_flagged() -> void:
	var p := RedirectionPreview.read(_campaign(), TERRACE, 3)
	assert_eq(p["horizon_days"], 3)
	assert_true(_entry(p, TERRACE)["beyond_horizon"], "still wet when the preview stops")


func test_the_bowls_come_nearest_first_in_the_basins_order() -> void:
	var p := RedirectionPreview.read(_campaign(), TERRACE)
	var distances: Array = p["bowls"].map(func(b): return b["distance"])
	var sorted := distances.duplicate()
	sorted.sort()
	assert_eq(distances, sorted)
	assert_eq(_ids(p)[0], TERRACE)


func test_the_labor_plan_it_reads_is_the_current_one() -> void:
	var held := _campaign()
	var left := _campaign()
	left.labor[Campaign.Bucket.IDLE] += left.labor[Campaign.Bucket.PUMPS]
	left.labor[Campaign.Bucket.PUMPS] = 0
	left.scrap = 0
	var a := RedirectionPreview.read(held, TERRACE)
	var b := RedirectionPreview.read(left, TERRACE)
	assert_ne(
		[_entry(a, TERRACE)["hang_days"], a["bowls"].size()],
		[_entry(b, TERRACE)["hang_days"], b["bowls"].size()],
		"pumps left to break change how the water recovers",
	)


## --- The preview is the rule ---


func _real(with_sluice: bool, days: int) -> Campaign:
	## The real way: dispatch, a fight that does or does not open the sluice, home, then more days.
	var c := _campaign()
	c.bench = [1, 2, 3, 4] as Array[int]
	c = DispatchCommand.new(TERRACE, [1, 2, 3, 4] as Array[int]).apply(c)
	var fight := TableDispatch.build_fight(c, TERRACE, [1, 2, 3, 4] as Array[int])
	fight.in_contact = true
	fight.active_side = CombatState.PhaseSide.PLAYER
	if with_sluice:
		fight.get_unit(FloodedTerrace.P2).cell = FloodedTerrace.SLUICE + Vector3i(-1, 0, 0)
		fight = MachineCommand.new(FloodedTerrace.P2, FloodedTerrace.SLUICE).apply(fight)
	for unit in fight.units_of_faction(Taxonomy.Faction.PLAYER):
		unit.extracted = true
	c = HomeCommand.new(fight).apply(c)
	for _day in days - 1:
		c = EndDayCommand.new().apply(c)
	return c


func test_the_bowls_it_lists_are_the_bowls_that_differ_after_the_real_command_and_the_same_days() -> void:
	var preview := RedirectionPreview.read(_campaign(), TERRACE, 1)
	var real := _real(true, 1)
	var plain := _real(false, 1)
	var differ: Array = []
	for id in real.basin.ids():
		if real.basin.bowl(id).step != plain.basin.bowl(id).step:
			differ.append(id)
	var listed := _ids(preview).filter(func(id): return _entry(preview, id)["steps_wetter"] > 0)
	## After one day only the target has been redirected: nothing has had time to spread.
	assert_eq(listed, differ)
	assert_eq(real.basin.bowl(TERRACE).step, Taxonomy.WaterStep.FALLING)


func test_the_water_after_the_horizon_is_the_water_the_real_run_reaches() -> void:
	var days := 9
	var preview := RedirectionPreview.read(_campaign(), TERRACE, days)
	var real := _real(true, days)
	var plain := _real(false, days)
	for entry in preview["bowls"]:
		var id: String = entry["id"]
		assert_gte(
			int(plain.basin.bowl(id).step) - int(real.basin.bowl(id).step), 0,
			"%s is never drier for the redirection" % id
		)
	var wetter_in_real: Array = []
	for id in real.basin.ids():
		if int(real.basin.bowl(id).step) < int(plain.basin.bowl(id).step):
			wetter_in_real.append(id)
	for id in wetter_in_real:
		assert_true(id in _ids(preview), "%s differs in the real run, so the preview names it" % id)
	for id in real.basin.ids():
		assert_eq(
			real.basin.bowl(id).ruined - plain.basin.bowl(id).ruined,
			_entry(preview, id).get("stands", {}).get("fields_lost", 0),
			"fields lost in %s" % id,
		)
