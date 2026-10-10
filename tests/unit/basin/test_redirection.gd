extends GutTest

## The redirection ledger and Bitter (plan 08 §8.2, GDD §6.4, §6.6).

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")
const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")

const TERRACE := Ring.TERRACE


func _late() -> Campaign:
	var c := Opening.opening()
	c.basin = Ring.late_ring()
	return c


func _step(c: Campaign) -> Taxonomy.WaterStep:
	return c.basin.bowl(TERRACE).step


func _dry_back(c: Campaign, step: Taxonomy.WaterStep) -> void:
	c.basin.bowl(TERRACE).step = step


## --- The ledger ---


func test_a_redirection_is_recorded_with_the_step_it_left_and_the_day() -> void:
	var c := _late()
	c.day = 4
	c.basin.bowl(TERRACE).step = Taxonomy.WaterStep.FALLING
	var entry := Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	assert_eq(c.redirections.size(), 1)
	assert_eq([entry.bowl_id, entry.day, entry.from_step, entry.to_step], [TERRACE, 4, Taxonomy.WaterStep.FALLING, Taxonomy.WaterStep.FLOODED])
	assert_eq(_step(c), Taxonomy.WaterStep.FLOODED)
	assert_eq(c.basin.bowl(TERRACE).hang_days, BasinRules.REDIRECTION_HANG_DAYS, "held wet")
	assert_eq(c.basin.bowl(TERRACE).walk, BasinBowl.Walk.NONE)


func test_recording_a_redirection_drops_a_walk_in_progress() -> void:
	var c := _late()
	c.basin.bowl(TERRACE).walk = BasinBowl.Walk.DRIER
	c.basin.bowl(TERRACE).walk_days_left = 2
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	assert_eq(c.basin.bowl(TERRACE).walk, BasinBowl.Walk.NONE)
	assert_eq(c.basin.bowl(TERRACE).walk_days_left, 0)


func test_the_first_redirection_at_the_terrace_is_the_first_contact_card() -> void:
	var c := _late()
	var first := Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	assert_true(first.first_contact)
	assert_true(c.cards_spent.has(TERRACE))


func test_the_next_redirection_at_that_bowl_is_not() -> void:
	var c := _late()
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.MUD)
	_dry_back(c, Taxonomy.WaterStep.DRY)
	var second := Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	assert_false(second.first_contact, "the card is spent")


func test_a_bowl_with_no_authored_card_has_no_first_contact_redirection() -> void:
	var c := _late()
	var entry := Redirection.record(c, Ring.POLDER_A, Taxonomy.WaterStep.FLOODED)
	assert_false(entry.first_contact, "only the bowl whose map carries the sluice offers the card")


func test_two_redirections_of_one_bowl_count_once_judged_against_the_step_the_first_left() -> void:
	var c := _late() ## the terrace is Dry
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.MUD)
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	assert_eq(c.redirections.size(), 1, "while the first still hangs, there is one redirection")
	assert_eq(c.redirections[0].from_step, Taxonomy.WaterStep.DRY, "judged against the step before the first")
	assert_eq(c.redirections[0].to_step, Taxonomy.WaterStep.FLOODED)


func test_a_redirection_after_the_first_has_dried_back_is_a_new_entry() -> void:
	var c := _late()
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	_dry_back(c, Taxonomy.WaterStep.DRY)
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	assert_eq(c.redirections.size(), 2)


func test_the_ledger_is_copied_with_the_campaign() -> void:
	var c := _late()
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	var copy := c.duplicate_campaign()
	copy.redirections[0].from_step = Taxonomy.WaterStep.FLOODED
	copy.cards_spent.clear()
	assert_eq(c.redirections[0].from_step, Taxonomy.WaterStep.DRY)
	assert_true(c.cards_spent.has(TERRACE))
	assert_not_same(copy.redirections[0], c.redirections[0])


func test_the_ledger_and_the_spent_card_survive_the_save() -> void:
	var c := _late()
	c.day = 3
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	var back := CampaignCodec.from_dict(JSON.parse_string(JSON.stringify(CampaignCodec.to_dict(c))))
	assert_eq(back.redirections.size(), 1)
	var r := back.redirections[0]
	assert_eq([r.bowl_id, r.day, r.from_step, r.to_step, r.first_contact], [TERRACE, 3, Taxonomy.WaterStep.DRY, Taxonomy.WaterStep.FLOODED, true])
	assert_true(back.cards_spent.has(TERRACE))
	assert_true(Ending.is_bitter(back) == Ending.is_bitter(c))


## --- Bitter ---


func test_a_campaign_with_no_redirection_is_not_bitter() -> void:
	assert_false(Ending.is_bitter(_late()))


func test_the_first_contact_sluice_never_makes_a_campaign_bitter() -> void:
	var c := _late()
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	assert_true(c.redirections[0].hangs(c.basin), "the ditch is on the map")
	assert_false(Ending.is_bitter(c), "and it is still not Bitter: it was authored panic")


func test_a_later_redirection_makes_it_bitter_until_the_bowl_has_dried_back() -> void:
	var c := _late()
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.MUD) ## the card, spent
	_dry_back(c, Taxonomy.WaterStep.DRY)
	Redirection.record(c, TERRACE, Taxonomy.WaterStep.FLOODED)
	assert_true(Ending.is_bitter(c))
	assert_eq(Ending.hanging_redirections(c).size(), 1)
	_dry_back(c, Taxonomy.WaterStep.MUD)
	assert_true(Ending.is_bitter(c), "wetter than before is still a hanging tile")
	_dry_back(c, Taxonomy.WaterStep.DRY)
	assert_false(Ending.is_bitter(c), "dried back to the step it left: the neighbours have their land again")
	_dry_back(c, Taxonomy.WaterStep.DRY)
	assert_false(Ending.is_bitter(c))


func test_a_redirection_stops_counting_when_it_walks_back_past_the_step_it_left() -> void:
	var c := _late()
	c.basin.bowl(TERRACE).step = Taxonomy.WaterStep.FALLING
	Redirection.record(c, Ring.POLDER_A, Taxonomy.WaterStep.FALLING) ## not the card: another bowl
	assert_true(Ending.is_bitter(c))
	c.basin.bowl(Ring.POLDER_A).step = Taxonomy.WaterStep.DRY
	assert_false(Ending.is_bitter(c))


func test_bitter_reads_only_the_ledger_and_the_basin() -> void:
	## A wet bowl nobody redirected is the world's doing, not the player's.
	var c := _late()
	c.basin.bowl(Ring.POLDER_B).step = Taxonomy.WaterStep.FLOODED
	assert_false(Ending.is_bitter(c))


func test_bitter_and_the_first_contact_card_through_the_real_way_home() -> void:
	## A fight that opens the sluice, sent home through HomeCommand: the first is the card.
	var c := Opening.opening()
	c.basin.bowl(TERRACE).step = Taxonomy.WaterStep.FALLING
	c = DispatchCommand.new(TERRACE, [1, 2, 3, 4] as Array[int]).apply(c)
	var fight := TableDispatch.build_fight(c, TERRACE, [1, 2, 3, 4] as Array[int])
	fight.in_contact = true
	fight.active_side = CombatState.PhaseSide.PLAYER
	fight.get_unit(FloodedTerrace.P2).cell = FloodedTerrace.SLUICE + Vector3i(-1, 0, 0)
	fight = MachineCommand.new(FloodedTerrace.P2, FloodedTerrace.SLUICE).apply(fight)
	for unit in fight.units_of_faction(Taxonomy.Faction.PLAYER):
		unit.extracted = true
	var home := HomeCommand.new(fight).apply(c)
	assert_eq(home.redirections.size(), 1)
	assert_true(home.redirections[0].first_contact)
	assert_eq(home.redirections[0].from_step, Taxonomy.WaterStep.FALLING)
	assert_false(Ending.is_bitter(home), "the first-contact sluice is not Bitter")


## --- One place redirects ---


func test_no_code_outside_the_tick_and_the_ledger_sets_a_bowls_step_or_hold() -> void:
	var allowed := [
		"res://rules/basin/basin_day.gd", "res://rules/basin/redirection.gd",
		"res://rules/basin/basin_bowl.gd", "res://rules/campaign_codec.gd",
	]
	var offenders: Array[String] = []
	for dir in ["res://rules", "res://rules/basin", "res://rules/commands", "res://rules/commands/table", "res://presentation"]:
		for file in DirAccess.get_files_at(dir):
			var path: String = dir.path_join(file)
			if not path.ends_with(".gd") or path in allowed:
				continue
			for line in FileAccess.get_file_as_string(path).split("\n"):
				if _assigns(line.split("#")[0]):
					offenders.append(path)
					break
	assert_eq(offenders, [] as Array[String], "assignments to a bowl's step or hold outside the tick and the ledger: %s" % [offenders])


## `x.hang_days = ...` or `bowl.step = ...`, but not a comparison (`==`).
func _assigns(code: String) -> bool:
	for field in [".hang_days", "bowl.step", ".step"]:
		var at := code.find(field + " =")
		if at == -1:
			continue
		var rest := code.substr(at + field.length()).strip_edges()
		if rest.begins_with("=") and not rest.begins_with("=="):
			if field == ".step" and not code.contains("bowl"):
				continue
			return true
	return false
