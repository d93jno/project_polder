extends GutTest

## The table surface (plan 07 §7.4, UI §8): it draws what the rules say, and never what UI §8 forbids.

const TableView := preload("res://presentation/table_view.gd")
const Queries := preload("res://presentation/table_queries.gd")
const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")

const B := Campaign.Bucket


func _view() -> Control:
	var view = TableView.new()
	add_child_autofree(view)
	return view


func _text(view: Control) -> String:
	return "\n".join(view.all_text())


func _has_node_of(root: Node, cls: String) -> bool:
	if root.is_class(cls):
		return true
	for child in root.get_children():
		if _has_node_of(child, cls):
			return true
	return false


## --- What it never shows ---


func test_the_table_has_no_bar_percentage_target_or_progress_pip() -> void:
	var view := _view()
	for step in 3:
		view._on_day_end()
		view._on_day_end()
	var text := _text(view)
	for banned in ["%", "goal", "target", "progress", "health", "happy"]:
		assert_false(text.to_lower().contains(banned), "UI 8 never shows '%s'" % banned)
	assert_false(_has_node_of(view, "ProgressBar"), "no bar")
	assert_false(_has_node_of(view, "TextureProgressBar"), "no pip")
	assert_false(_has_node_of(view, "Slider"), "no slider")


func test_the_currencies_are_plain_counts_and_the_people_are_one_number() -> void:
	var view := _view()
	assert_true(_text(view).contains("food 12 · fuel 4 · scrap 6"))
	assert_true(_text(view).contains("10 people"))


func test_labor_is_a_short_board_of_buckets_and_never_individuals() -> void:
	var q = Queries.compute(Opening.opening(), "", [] as Array[int])
	assert_eq(q.labor.size(), 7)
	var names: Array = q.labor.map(func(row): return row["name"])
	assert_true("pumps and ring watch" in names)
	assert_true("roster" in names)


## --- What it shows of the water ---


func test_a_bowl_nobody_has_walked_is_unknown_and_shows_no_data() -> void:
	var q = Queries.compute(Opening.opening(), "", [] as Array[int])
	for card in q.cards:
		if card["id"] in [Ring.SUMP, Ring.POLDER_A, Ring.POLDER_B, Ring.RIDGE_E]:
			assert_false(card["known"], card["id"])
			assert_eq(card["lines"], ["unknown"], "a word and nothing else")
			assert_false(card.has("step"), "no step is invented")


func test_a_known_bowl_reads_its_step_pump_and_upkeep_in_words() -> void:
	var q = Queries.compute(Opening.opening(), "", [] as Array[int])
	var terrace := _card(q, Ring.TERRACE)
	assert_true(terrace["lines"][0].begins_with("flooded"))
	assert_true("pump on, kept" in terrace["lines"])


func test_only_the_instrumented_bowl_shows_its_ring() -> void:
	var q = Queries.compute(Opening.opening(), "", [] as Array[int])
	assert_gt(q.edges.size(), 0)
	for edge in q.edges:
		assert_eq(edge["to"], Ring.TERRACE, "the plate on a ridge reports its own bowl, never the ring")
	var ridge := _card(q, Ring.RIDGE_W)
	for line in ridge["lines"]:
		assert_false(str(line).contains("pours"), "no feeder line on an uninstrumented bowl")


func test_a_walking_step_and_a_held_bowl_are_said_in_days() -> void:
	var c := Opening.opening()
	c.basin.bowl(Ring.TERRACE).walk = BasinBowl.Walk.DRIER
	c.basin.bowl(Ring.TERRACE).walk_days_left = 2
	c.basin.bowl(Ring.RIDGE_W).hang_days = 1
	var q = Queries.compute(c, "", [] as Array[int])
	assert_true("walking drier in 2 days" in _card(q, Ring.TERRACE)["lines"])
	assert_true("held wet, 1 day" in _card(q, Ring.RIDGE_W)["lines"])


func _card(q, id: String) -> Dictionary:
	for card in q.cards:
		if card["id"] == id:
			return card
	return {}


func test_a_step_is_a_pattern_and_a_word_not_a_hue() -> void:
	## The board draws the glyph from the step alone, one pattern per step, and the word beside it.
	var source := FileAccess.get_file_as_string("res://presentation/table_board.gd")
	for step in ["FLOODED", "FALLING", "MUD"]:
		assert_true(source.contains("WaterStep.%s" % step), "a pattern for %s" % step)
	var q = Queries.compute(Opening.opening(), "", [] as Array[int])
	assert_true(str(_card(q, Ring.RIDGE_W)["lines"][0]).begins_with("falling"))


## --- The morning read ---


func test_the_morning_says_what_moved_on_bowls_you_know_and_nothing_about_the_rest() -> void:
	var c := Opening.opening()
	var result := DayResult.new()
	result.basin = c.basin
	result.moved = [
		{"id": Ring.RIDGE_W, "from": Taxonomy.WaterStep.FALLING, "to": Taxonomy.WaterStep.MUD},
		{"id": Ring.SUMP, "from": Taxonomy.WaterStep.FLOODED, "to": Taxonomy.WaterStep.FALLING},
	] as Array[Dictionary]
	result.pumps_broke = [Ring.POLDER_A] as Array[String]
	c.morning = result
	var lines: Array[String] = Queries.compute(c, "", [] as Array[int]).morning
	assert_eq(lines, ["ridge_w: falling to mud"] as Array[String], "the sump and polder_a are not known, so they say nothing")


func test_the_morning_after_a_week_of_left_pumps_names_the_pumps() -> void:
	var view := _view()
	view._assign(B.PUMPS, B.IDLE)
	view._assign(B.PUMPS, B.IDLE)
	for _day in BasinRules.BREAKS_AFTER_DAYS:
		view._on_day_end()
		view._on_day_end()
	assert_true(_text(view).contains("the pump broke"))


## --- Acting ---


func test_moving_a_hand_goes_through_the_command_and_updates_the_board() -> void:
	var view := _view()
	view._assign(B.IDLE, B.FIELDS)
	assert_eq(view.campaign.hands(B.FIELDS), 3)
	assert_eq(view.campaign.hands(B.IDLE), 3)
	assert_eq(view.campaign.assignments_today, 1)
	assert_true(_text(view).contains("2 assignments left today"))


func test_a_refused_assignment_says_why_and_changes_nothing() -> void:
	var view := _view()
	view._assign(B.RESEARCH, B.FIELDS)
	assert_eq(view._note.text, "not enough hands in research")
	assert_eq(view.campaign.hands(B.FIELDS), 2)


func test_day_end_is_one_confirmed_action_and_not_an_end_turn() -> void:
	var view := _view()
	view._on_day_end()
	assert_eq(view.campaign.day, 1, "the first press only arms it")
	assert_true(view._note.text.begins_with("confirm: end day 1"), view._note.text)
	assert_true(view._note.text.contains("2 pumps posted"))
	view._on_day_end()
	assert_eq(view.campaign.day, 2)
	assert_eq(view._note.text, "")


func test_escape_disarms_the_day_end() -> void:
	var view := _view()
	view._on_day_end()
	view._confirm.cancel()
	view._on_day_end()
	assert_eq(view.campaign.day, 1, "after a cancel it must be armed again")


func test_choosing_a_bowl_leads_the_dispatch_with_the_bowl_then_the_bodies() -> void:
	var view := _view()
	view._on_bowl(Ring.TERRACE)
	var d: Dictionary = view._queries.dispatch
	assert_eq(d["bowl"], Ring.TERRACE)
	assert_true(d.has("bowl_lines"), "the bowl's water and pump come first")
	assert_eq(d["reason"], "send at least one")
	view._on_body(true, 1)
	view._on_body(true, 2)
	assert_true(view._queries.dispatch["ok"])
	view._on_dispatch()
	assert_eq(view.campaign.deployment["bowl"], Ring.TERRACE)
	assert_true(view._queries.dispatch.has("out"))


func test_a_bowl_with_no_map_says_so_instead_of_sending_anyone() -> void:
	var view := _view()
	view._on_bowl(Ring.RIDGE_W)
	view._on_body(true, 1)
	assert_false(view._queries.dispatch["ok"])
	assert_eq(view._queries.dispatch["reason"], "no known map")


func test_the_view_computes_no_rule_of_its_own() -> void:
	## CLAUDE.md: presentation draws state and applies already-validated commands; it decides nothing.
	for path in ["res://presentation/table_view.gd", "res://presentation/table_board.gd"]:
		var text := FileAccess.get_file_as_string(path)
		for forbidden in ["BasinDay", "posted_pumps", "WaterGraph", "hang_days", "REDIRECTION", "step_move_cost", "BREAKS_AFTER"]:
			assert_false(text.contains(forbidden), "%s must not know %s" % [path, forbidden])


## --- The redirection card (plan 08 §8.4) ---


func _card_campaign() -> Campaign:
	## A dry late ring with the terrace in Mud and every pump kept, so a sluice there crosses the threshold.
	var c := Opening.opening()
	c.basin = Ring.late_ring()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.MUD
	c.scrap = 99
	c.labor[B.PUMPS] = 7
	c.labor[B.IDLE] = 0
	return c


func _card_view() -> Control:
	var view = TableView.new()
	view.campaign = _card_campaign()
	add_child_autofree(view)
	return view


func test_the_card_appears_on_the_dispatch_slot_for_a_bowl_with_a_sluice_before_anyone_is_sent() -> void:
	var view := _card_view()
	assert_true(view._queries.dispatch.get("card", []).is_empty(), "nothing is chosen yet")
	view._on_bowl(Ring.TERRACE)
	var card: Array = view._queries.dispatch["card"]
	assert_eq(card[0], "if the sluice at terrace is opened:")
	assert_true(view._card.text.contains("terrace mud to falling"))
	assert_eq(view.campaign.deployment.size(), 0, "and nobody has been sent")


func test_a_bowl_without_a_sluice_offers_no_card() -> void:
	var view := _card_view()
	view._on_bowl(Ring.RIDGE_W)
	assert_false(view._queries.dispatch.has("card"))
	assert_eq(view._card.text, "")


func test_the_card_names_what_the_preview_names_and_nothing_else() -> void:
	var c := _card_campaign()
	var preview := RedirectionPreview.read(c, Ring.TERRACE)
	var lines := Queries.redirection_card(preview, Ring.TERRACE)
	var text := "\n".join(lines)
	for entry in preview["bowls"]:
		assert_true(text.contains(str(entry["id"])), "%s is on the card" % entry["id"])
	assert_false(text.contains(Ring.POLDER_A), "and a bowl the preview does not name is not")
	assert_true(text.contains("2 fields drowned"), "what stands in the water, in counts")
	assert_true(text.contains("the creep reaches the next bowl"))


func test_a_fully_instrumented_ring_reads_exactly_and_a_half_fixed_one_says_range() -> void:
	var c := _card_campaign()
	var exact := "\n".join(Queries.redirection_card(RedirectionPreview.read(c, Ring.TERRACE), Ring.TERRACE))
	assert_false(exact.contains("a range"))
	assert_false(exact.contains("about"))
	c.basin.bowl(Ring.POLDER_B).instrumented = false
	var ranged := "\n".join(Queries.redirection_card(RedirectionPreview.read(c, Ring.TERRACE), Ring.TERRACE))
	assert_true(ranged.contains("a range: not every bowl here has instruments"))
	assert_true(ranged.contains("about"))


func test_the_card_never_names_a_bowl_the_player_has_not_walked() -> void:
	var c := _card_campaign()
	c.basin.bowl(Ring.POLDER_B).known = false
	var text := "\n".join(Queries.redirection_card(RedirectionPreview.read(c, Ring.TERRACE), Ring.TERRACE))
	assert_false(text.contains(Ring.POLDER_B))
	assert_true(text.contains("and reaches ground you have not walked"))


func test_a_flooded_bowl_says_its_sluice_can_do_no_more() -> void:
	var c := _card_campaign()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.FLOODED
	var lines := Queries.redirection_card(RedirectionPreview.read(c, Ring.TERRACE), Ring.TERRACE)
	assert_eq(lines, ["a sluice at terrace can do no more: the water is already as deep as it goes"] as Array[String])


func test_the_card_has_no_bar_percentage_or_target() -> void:
	var view := _card_view()
	view._on_bowl(Ring.TERRACE)
	var text: String = view._card.text.to_lower()
	for banned in ["%", "goal", "target", "progress"]:
		assert_false(text.contains(banned), banned)


func test_the_morning_says_a_redirected_bowl_is_held_wet_and_how_long() -> void:
	var c := _card_campaign()
	Redirection.record(c, Ring.TERRACE, Taxonomy.WaterStep.FALLING)
	var lines: Array[String] = Queries.compute(c, "", [] as Array[int]).morning
	assert_true("terrace: held wet, %d days" % BasinRules.REDIRECTION_HANG_DAYS in lines, str(lines))


func test_the_morning_says_when_a_hold_has_run_out_but_the_water_is_still_wetter() -> void:
	var c := _card_campaign()
	Redirection.record(c, Ring.TERRACE, Taxonomy.WaterStep.FALLING)
	c.basin.bowl(Ring.TERRACE).hang_days = 0
	var lines: Array[String] = Queries.compute(c, "", [] as Array[int]).morning
	assert_true("terrace: still wetter than before the sluice" in lines, str(lines))
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.DRY
	assert_false(_has_line(Queries.compute(c, "", [] as Array[int]).morning, "terrace"), "a bowl that dried back says nothing")


func _has_line(lines: Array, prefix: String) -> bool:
	for line in lines:
		if str(line).begins_with(prefix):
			return true
	return false


func test_the_morning_names_the_fields_a_flood_ruined_on_known_bowls_only() -> void:
	var c := _card_campaign()
	var result := DayResult.new()
	result.basin = c.basin
	result.fields_ruined = [
		{"id": Ring.POLDER_B, "count": 2}, {"id": Ring.SUMP, "count": 1},
	] as Array[Dictionary]
	c.basin.bowl(Ring.SUMP).known = false
	c.morning = result
	var lines: Array[String] = Queries.compute(c, "", [] as Array[int]).morning
	assert_true("polder_b: 2 fields ruined" in lines)
	assert_false(_has_line(lines, "sump"))


func test_the_view_still_decides_nothing_about_redirection() -> void:
	for path in ["res://presentation/table_view.gd", "res://presentation/table_board.gd"]:
		var text := FileAccess.get_file_as_string(path)
		for forbidden in ["RedirectionPreview", "Redirection.", "Ending", "hang_days_min", "steps_wetter"]:
			assert_false(text.contains(forbidden), "%s must not know %s" % [path, forbidden])


## --- Refusing the sluice (plan 08 §8.5) ---


func test_holding_the_sluice_changes_the_card_to_say_nothing_is_redirected() -> void:
	var view := _card_view()
	view._on_bowl(Ring.TERRACE)
	assert_true(view._queries.dispatch.get("has_sluice", false))
	view._on_hold(true)
	var card: Array = view._queries.dispatch["card"]
	assert_eq(card.size(), 1)
	assert_true(card[0].contains("held shut"))
	assert_true(card[0].contains("nothing is redirected"))


func test_only_a_bowl_with_a_sluice_offers_the_hold_and_it_resets_on_a_new_bowl() -> void:
	var view := _card_view()
	view._on_bowl(Ring.RIDGE_W)
	assert_false(view._queries.dispatch.get("has_sluice", false))
	view._on_bowl(Ring.TERRACE)
	view._on_hold(true)
	view._on_bowl(Ring.RIDGE_W)
	view._on_bowl(Ring.TERRACE)
	assert_false(view._hold_sluice, "the choice belongs to one dispatch")


func test_the_hold_is_not_saved() -> void:
	var c := _card_campaign()
	c = DispatchCommand.new(Ring.TERRACE, [1, 2, 3, 4] as Array[int], true).apply(c)
	var path := "user://hold_test_save.json"
	CampaignSave.save_campaign(c, path)
	var loaded = CampaignSave.load_campaign(path)
	DirAccess.remove_absolute(path)
	assert_eq(loaded.deployment.size(), 0, "a dispatch is not saved, so neither is its hold")
