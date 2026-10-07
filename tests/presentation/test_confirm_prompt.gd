extends GutTest

## ConfirmPrompt — one confirm for every Confirmed-tier action (plan 05 §5.3).

const ConfirmPrompt := preload("res://presentation/confirm_prompt.gd")

const HERE := Vector3i(3, 0, 0)
const ELSEWHERE := Vector3i(4, 0, 0)


func _state() -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL))
	var bleeder := Unit.new(2, HERE, Taxonomy.Faction.DRIFTER)
	bleeder.hp = 0
	bleeder.bleeding = true
	state.add_unit(bleeder)
	return state


func test_the_first_press_arms_and_the_second_commits() -> void:
	var prompt = ConfirmPrompt.new()
	var shot := ShootCommand.new(1, 2)
	assert_false(prompt.is_armed())
	assert_false(prompt.press(shot, HERE), "the first press only arms it")
	assert_true(prompt.is_armed())
	assert_true(prompt.press(ShootCommand.new(1, 2), HERE), "the same action again commits")
	assert_false(prompt.is_armed(), "and disarms")


func test_a_different_action_arms_instead_of_committing() -> void:
	var prompt = ConfirmPrompt.new()
	prompt.press(ShootCommand.new(1, 2), HERE)
	assert_false(prompt.press(ShootCommand.new(1, 3), ELSEWHERE), "another target is a new arming")


func test_escape_disarms() -> void:
	var prompt = ConfirmPrompt.new()
	prompt.press(ShootCommand.new(1, 2), HERE)
	prompt.cancel()
	assert_false(prompt.is_armed())
	assert_false(prompt.press(ShootCommand.new(1, 2), HERE), "after Esc it must be armed again")


func test_moving_the_hover_off_the_target_disarms() -> void:
	var prompt = ConfirmPrompt.new()
	prompt.press(ShootCommand.new(1, 2), HERE)
	prompt.hover_moved(HERE)
	assert_true(prompt.is_armed(), "still pointing at it")
	prompt.hover_moved(ELSEWHERE)
	assert_false(prompt.is_armed())


func test_the_text_names_the_action_and_its_cost_and_no_probability() -> void:
	var state := _state()
	var text: String = ConfirmPrompt.text_for(ShootCommand.new(1, 2), state)
	assert_true(text.contains("kills a bleeder"))
	assert_true(text.contains("%d AP" % RulesConstants.shot_cost(Taxonomy.WeaponClass.PISTOL)))
	assert_false(text.contains("%"), "a cost and an outcome, never a chance (UI §1)")
	var kit := InteractCommand.new(1, HERE, InteractCommand.Kind.TRAUMA_KIT)
	var kit_text: String = ConfirmPrompt.text_for(kit, state)
	assert_true(kit_text.contains("Trauma Kit"))
	assert_true(kit_text.contains("%d AP" % RulesConstants.INTERACT_COST))


func test_a_trauma_kit_and_a_shot_have_distinct_keys() -> void:
	var shot_key: String = ConfirmPrompt.key_of(ShootCommand.new(1, 2))
	var kit_key: String = ConfirmPrompt.key_of(InteractCommand.new(1, HERE, InteractCommand.Kind.TRAUMA_KIT))
	assert_ne(shot_key, kit_key)
