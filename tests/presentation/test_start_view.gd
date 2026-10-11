extends GutTest

## The start screen: continue, new game, quit. It decides nothing and says what a new game costs.

const Start := preload("res://presentation/start_view.gd")
const Game := preload("res://presentation/game.gd")

const PATH := "user://test_start_flow.json"


func before_each() -> void:
	CampaignSave.erase(PATH)


func after_each() -> void:
	CampaignSave.erase(PATH)


func _start(has_save: bool) -> Control:
	var view = Start.new()
	view.has_save = has_save
	add_child_autofree(view)
	return view


func _buttons(root: Node) -> Dictionary:
	var out := {}
	for child in root.get_children():
		if child is Button and not child.is_queued_for_deletion():
			out[child.text] = child
		out.merge(_buttons(child))
	return out


func _game(save: bool) -> Node:
	if save:
		var c := preload("res://rules/fixtures/table_opening.gd").opening()
		c.day = 7
		CampaignSave.save_campaign(c, PATH)
	var game = Game.new()
	game.save_path = PATH
	game.start_screen = true
	add_child_autofree(game)
	return game


func _current(game: Node) -> Node:
	for child in game.get_children():
		return child
	return null


func test_without_a_save_there_is_no_continue() -> void:
	var buttons := _buttons(_start(false))
	assert_false(buttons["continue"].visible)
	assert_true(buttons["new game"].visible)
	assert_true(buttons.has("quit"))


func test_with_a_save_continue_is_offered() -> void:
	assert_true(_buttons(_start(true))["continue"].visible)


func test_a_new_game_without_a_save_starts_at_once() -> void:
	var view := _start(false)
	watch_signals(view)
	view._on_new()
	assert_signal_emitted(view, "new_game_pressed")


func test_a_new_game_over_a_save_asks_twice_and_says_what_it_replaces() -> void:
	var view := _start(true)
	watch_signals(view)
	view._on_new()
	assert_signal_not_emitted(view, "new_game_pressed")
	assert_true(" ".join(view.all_text()).contains("replaces your saved campaign"))
	view._on_new()
	assert_signal_emitted(view, "new_game_pressed")


func test_continue_and_quit_say_what_was_chosen() -> void:
	var view := _start(true)
	watch_signals(view)
	view._on_continue()
	assert_signal_emitted(view, "continue_pressed")
	_buttons(view)["quit"].pressed.emit()
	assert_signal_emitted(view, "quit_pressed")


func test_the_start_screen_shows_no_meter_or_number() -> void:
	var text := " ".join(_start(true).all_text()).to_lower()
	for banned in ["%", "score", "level", "progress"]:
		assert_false(text.contains(banned))


## --- The game flow ---


func test_the_game_opens_on_the_start_screen() -> void:
	var game := _game(false)
	assert_true(_current(game).has_signal("new_game_pressed"))


func test_continue_opens_the_saved_campaign() -> void:
	var game := _game(true)
	game._on_continue()
	assert_true(_current(game).has_method("all_text"))
	assert_eq(game.campaign.day, 7)


func test_new_game_forgets_the_save_and_opens_the_first_day() -> void:
	var game := _game(true)
	game._on_new_game()
	assert_eq(game.campaign.day, 1)
	assert_false(CampaignSave.has_save(PATH), "the old campaign is gone")
	assert_true(_current(game).has_method("all_text"))


func test_the_menu_returns_to_the_start_screen_and_a_save_still_continues() -> void:
	var game := _game(true)
	game._on_continue()
	_current(game).menu_requested.emit()
	assert_true(_current(game).has_signal("new_game_pressed"))
	assert_true(_current(game).has_save)
	game._on_continue()
	assert_eq(game.campaign.day, 7)


func test_a_game_without_the_start_screen_still_opens_on_the_table() -> void:
	var game = Game.new()
	game.save_path = PATH
	add_child_autofree(game)
	assert_true(_current(game).has_method("all_text"))
