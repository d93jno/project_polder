extends GutTest

## Coming home is the switch (plan 07 §7.5): table, dispatch, fight, home, with one save.

const Game := preload("res://presentation/game.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")

const PATH := "user://test_game_flow.json"


func before_each() -> void:
	_remove()


func after_each() -> void:
	_remove()


func _remove() -> void:
	for p in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _game() -> Node:
	var game = Game.new()
	game.save_path = PATH
	add_child_autofree(game)
	return game


func _mode(game: Node) -> String:
	for child in game.get_children():
		if child.has_method("all_text"):
			return "table"
		if child.has_signal("fight_ended"):
			return "fight"
	return "none"


func _table(game: Node) -> Node:
	for child in game.get_children():
		if child.has_method("all_text"):
			return child
	return null


func _fight(game: Node) -> Node:
	for child in game.get_children():
		if child.has_signal("fight_ended"):
			return child
	return null


func _dispatch(game: Node, ids: Array) -> void:
	var table := _table(game)
	table._on_bowl(Ring.TERRACE)
	for id in ids:
		table._on_body(true, id)
	table._on_dispatch()
	await get_tree().process_frame
	await get_tree().process_frame


func test_the_game_starts_on_the_table_with_a_new_campaign() -> void:
	var game := _game()
	assert_eq(_mode(game), "table")
	assert_eq(game.campaign.day, 1)


func test_a_dispatch_leaves_the_table_for_the_fight() -> void:
	var game := _game()
	await _dispatch(game, [1, 2, 3, 4])
	assert_eq(_mode(game), "fight")
	var fight := _fight(game)
	assert_eq(fight._state.units_of_faction(Taxonomy.Faction.PLAYER).size(), 4)
	assert_eq(fight._state.map.water_step, game.campaign.basin.bowl(Ring.TERRACE).step, "the basin's water")
	assert_false(game.campaign.deployment.is_empty(), "the fireteam is out")


func test_the_fight_ending_brings_the_squad_home_to_the_table() -> void:
	var game := _game()
	await _dispatch(game, [1, 2, 3, 4])
	var fight := _fight(game)
	for unit in fight._state.units_of_faction(Taxonomy.Faction.PLAYER):
		unit.extracted = true
	fight._check_fight_end()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_mode(game), "table", "coming home is the switch")
	assert_true(game.campaign.deployment.is_empty())
	assert_eq(game.campaign.day, 2, "a dispatch spends the day")
	assert_eq(game.campaign.bench.size(), 4)
	assert_not_null(game.campaign.morning)


func test_a_lost_squad_member_is_gone_when_the_table_opens() -> void:
	var game := _game()
	await _dispatch(game, [1, 2, 3, 4])
	var fight := _fight(game)
	for unit in fight._state.units_of_faction(Taxonomy.Faction.PLAYER):
		unit.extracted = unit.id != 4
	fight._state.get_unit(4).dead = true
	fight._state.get_unit(4).hp = 0
	fight._check_fight_end()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.campaign.bench, [1, 2, 3] as Array[int])
	assert_eq(game.campaign.people(), 9)


func test_the_fight_is_over_once_and_the_store_is_written_once() -> void:
	var game := _game()
	await _dispatch(game, [1, 2, 3, 4])
	var fight := _fight(game)
	var ended := []
	fight.fight_ended.connect(func(state): ended.append(state))
	for unit in fight._state.units_of_faction(Taxonomy.Faction.PLAYER):
		unit.extracted = true
	fight._check_fight_end()
	fight._check_fight_end()
	assert_eq(ended.size(), 1)


func test_an_ongoing_fight_does_not_end() -> void:
	var game := _game()
	await _dispatch(game, [1, 2, 3, 4])
	var fight := _fight(game)
	fight._check_fight_end()
	assert_eq(_mode(game), "fight")


## --- The save ---


func test_day_end_saves_and_a_new_game_reloads_it() -> void:
	var game := _game()
	var table := _table(game)
	table._on_day_end()
	table._on_day_end()
	assert_true(FileAccess.file_exists(PATH), "written at Day end")
	var again := _game()
	assert_eq(again.campaign.day, 2, "the same day, from the save")


func test_assigning_labor_and_dispatching_do_not_write_the_save() -> void:
	var game := _game()
	var table := _table(game)
	table._assign(Campaign.Bucket.IDLE, Campaign.Bucket.FIELDS)
	assert_false(FileAccess.file_exists(PATH), "nothing is written until a day ends")
	await _dispatch(game, [1, 2])
	assert_false(FileAccess.file_exists(PATH), "and an abandoned fight keeps nothing")


func test_an_abandoned_fight_leaves_the_save_as_it_was() -> void:
	var first := _game()
	_table(first)._on_day_end()
	_table(first)._on_day_end()
	var before := FileAccess.get_file_as_bytes(PATH)
	var game := _game()
	await _dispatch(game, [1, 2, 3, 4])
	game.free() ## quit in the middle of the fight
	assert_eq(FileAccess.get_file_as_bytes(PATH), before)
	assert_eq(_game().campaign.day, 2, "the next start finds the table as it was before the dispatch")


func test_coming_home_saves() -> void:
	var game := _game()
	await _dispatch(game, [1, 2, 3, 4])
	var fight := _fight(game)
	for unit in fight._state.units_of_faction(Taxonomy.Faction.PLAYER):
		unit.extracted = true
	fight._check_fight_end()
	await get_tree().process_frame
	await get_tree().process_frame
	var back := CampaignSave.load_campaign(PATH)
	assert_not_null(back)
	assert_eq(back.day, 2)


func test_the_opening_still_plays_without_a_table() -> void:
	## Squad mode needs no campaign: the shared opening is `fight_view` with no injected state.
	var view = load("res://presentation/fight_view.gd").new()
	assert_null(view.fight_state)
	view.free()
