extends GutTest

## The interact preview is the rule, run and diffed (plan 06 §6.3, UI §1): what it lists is what the
## command then does, and nothing in `presentation/` computes water, AP or contact on its own.

const Queries := preload("res://presentation/overlay_queries.gd")
const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")

const SLUICE := Vector3i(3, 3, 0)


func _terrace(step: Taxonomy.WaterStep = Taxonomy.WaterStep.FALLING) -> CombatState:
	var state := FloodedTerrace.opening(step)
	state.in_contact = true
	state.active_side = CombatState.PhaseSide.PLAYER
	state.add_machine(Machine.new(SLUICE, Machine.Kind.SLUICE))
	state.knowledge.peel(state.map, state)
	return state


func _preview(state: CombatState, unit_id := FloodedTerrace.P1) -> Dictionary:
	return Queries.interact_preview(state.map, state, state.get_unit(unit_id), SLUICE)


func test_the_sluice_preview_lists_exactly_the_cells_the_command_changes() -> void:
	var state := _terrace()
	var preview := _preview(state)
	var after := MachineCommand.new(FloodedTerrace.P1, SLUICE).apply(state)
	var actually_changed: Array[Vector3i] = []
	for coord in state.map.cells.keys():
		if state.map.step_at(coord) != after.map.step_at(coord):
			actually_changed.append(coord)
	var listed: Array = preview["changed_cells"]
	assert_gt(listed.size(), 0)
	assert_eq(listed.size(), actually_changed.size())
	for coord in actually_changed:
		assert_true(coord in listed, "%s changes, so it is listed" % coord)


func test_the_cells_it_lists_are_the_wet_ones_and_never_dry_ground() -> void:
	## From GDD 5.8 alone, not from the code under test: when the step changes, the cells that change
	## are the wet cells, and a roof or a dock deck is dry at every step.
	var state := _terrace()
	var listed: Array = _preview(state)["changed_cells"]
	for coord in state.map.cells.keys():
		assert_eq(coord in listed, state.map.is_wet(coord), "%s" % coord)
	assert_false(FloodedTerrace.ROOF_A in listed, "a roof stays dry")


func test_it_names_the_squad_bodies_standing_in_the_water() -> void:
	var state := _terrace()
	var bodies: Array = _preview(state)["bodies_in_it"]
	assert_true(FloodedTerrace.P1 in bodies, "the rifleman on the canal")
	assert_false(FloodedTerrace.P4 in bodies, "the man on the roof is dry")


func test_a_preview_changes_nothing() -> void:
	var state := _terrace()
	var step := state.map.water_step
	var ap := state.get_unit(FloodedTerrace.P1).ap
	_preview(state)
	assert_eq(state.map.water_step, step)
	assert_eq(state.get_unit(FloodedTerrace.P1).ap, ap)
	assert_false(state.machine_at(SLUICE).on)


func test_an_unaffordable_interact_shows_its_cost_and_is_not_hidden() -> void:
	var state := _terrace()
	state.get_unit(FloodedTerrace.P1).ap = 0
	var preview := _preview(state)
	assert_false(preview["affordable"])
	assert_false(preview["ok"])
	var label := Queries.format_interact(preview)
	assert_true(label.contains("%d AP" % RulesConstants.INTERACT_COST), label)
	assert_true(label.contains("can't afford"), label)


func test_the_label_says_what_it_costs_what_it_does_and_that_it_confirms() -> void:
	var label := Queries.format_interact(_preview(_terrace()))
	assert_true(label.begins_with("open sluice · %d AP" % RulesConstants.INTERACT_COST), label)
	assert_true(label.contains("water falling to flooded"), label)
	assert_true(label.contains("stand in it"), label)
	assert_true(label.contains("click again to confirm"), label)
	assert_false(label.contains("%"), "no probability (UI §1)")


func test_a_flooded_bowl_says_why_it_cannot_be_opened() -> void:
	var preview := _preview(_terrace(Taxonomy.WaterStep.FLOODED))
	assert_false(preview["ok"])
	assert_eq(preview["reason"], "the water is already as deep as it goes")
	assert_true((preview["changed_cells"] as Array).is_empty())
	assert_true(Queries.format_interact(preview).contains("as deep as it goes"))


func test_a_contested_machine_says_so() -> void:
	var state := _terrace()
	state.add_unit(Unit.new(30, SLUICE, Taxonomy.Faction.DRIFTER))
	state.knowledge.peel(state.map, state)
	var preview := _preview(state)
	assert_eq(preview["contested"], Contact.machine_starts_contact(state.map, state, state.get_unit(FloodedTerrace.P1), SLUICE))
	assert_true(preview["contested"], "the squad can see a hostile standing on it")
	assert_true(Queries.format_interact(preview).contains("contested"))


func test_a_pump_preview_has_no_water_diff() -> void:
	var state := _terrace()
	state.add_machine(Machine.new(Vector3i(3, 2, 0), Machine.Kind.PUMP))
	var preview := Queries.interact_preview(state.map, state, state.get_unit(FloodedTerrace.P1), Vector3i(3, 2, 0))
	assert_true((preview["changed_cells"] as Array).is_empty())
	assert_false(preview["confirms"], "a pump is committed, not confirmed")
	assert_true(Queries.format_interact(preview).begins_with("start pump"))


func test_compute_fills_the_preview_only_over_a_machine() -> void:
	var state := _terrace()
	var over = Queries.compute(state.map, state, FloodedTerrace.P1, SLUICE)
	assert_false(over.interact.is_empty())
	assert_ne(over.interact_label, "")
	var away = Queries.compute(state.map, state, FloodedTerrace.P1, Vector3i(5, 5, 0))
	assert_true(away.interact.is_empty())
	assert_eq(away.interact_label, "")
