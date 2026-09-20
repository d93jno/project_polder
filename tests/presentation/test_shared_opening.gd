extends GutTest

## Plan 2.6 / 3.3 — fight view must load the shared opening, not a forked map.

const FightView := preload("res://presentation/fight_view.gd")
const ScriptedFight := preload("res://rules/fixtures/scripted_fight.gd")
const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")


func test_fight_view_opening_matches_scripted_fight() -> void:
	var view = FightView.new()
	var from_view: CombatState = view._opening()
	var from_fixture: CombatState = ScriptedFight.opening()
	assert_eq(from_view.get_unit(ScriptedFight.P1).cell, from_fixture.get_unit(ScriptedFight.P1).cell)
	assert_eq(from_view.get_unit(ScriptedFight.P1).weapon, Taxonomy.WeaponClass.RIFLE)
	assert_eq(from_view.get_unit(ScriptedFight.D_NEAR).cell, from_fixture.get_unit(ScriptedFight.D_NEAR).cell)
	assert_eq(from_view.map.water_step, Taxonomy.WaterStep.DRY)
	assert_eq(from_view.extract_cells, from_fixture.extract_cells)
	assert_eq(from_view.units.size(), from_fixture.units.size())
	view.free()


func test_fight_view_opening_matches_flooded_terrace() -> void:
	var view = FightView.new()
	view._bowl_id = "terrace"
	var from_view: CombatState = view._opening()
	var from_fixture: CombatState = FloodedTerrace.opening()
	assert_eq(from_view.get_unit(FloodedTerrace.P1).cell, from_fixture.get_unit(FloodedTerrace.P1).cell)
	assert_eq(from_view.get_unit(FloodedTerrace.P4).cell, FloodedTerrace.ROOF_A)
	assert_eq(from_view.get_unit(FloodedTerrace.D_RIFLE).cell, FloodedTerrace.CREST)
	assert_eq(from_view.map.water_step, Taxonomy.WaterStep.FLOODED)
	assert_eq(from_view.extract_cells, from_fixture.extract_cells)
	assert_eq(from_view.units.size(), from_fixture.units.size())
	view.free()
