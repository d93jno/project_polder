extends GutTest

## What the rules call wet and what the picture draws as water must be the same cells, at every
## step (UI Principle 1: a preview that disagrees with the rule is the bug). Presentation decides it
## from floors and the surface height; the rules decide it from `water_z` and the deck flag.

const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")
const TerraceStamps := preload("res://presentation/fixtures/flooded_terrace_stamps.gd")


func test_terrace_water_is_drawn_where_the_rules_say_it_is() -> void:
	for step in [Taxonomy.WaterStep.FLOODED, Taxonomy.WaterStep.FALLING]:
		var map := FloodedTerrace.map(step)
		for coord in map.cells.keys():
			var cell: Cell = map.get_cell(coord)
			if cell.has_flag(Taxonomy.CellFlags.DECK):
				continue ## drawn on its own plane; the rules call it dry (below)
			assert_eq(
				PresentationCoords.in_water(coord, step, map.water_z), map.is_wet(coord),
				"%s at %s" % [coord, Taxonomy.WaterStep.keys()[step]]
			)


func test_every_cell_under_a_dock_is_a_deck_in_the_rules() -> void:
	## The picture stands a body on the dock's deck. The rules must agree that it is dry there.
	var map := FloodedTerrace.map(Taxonomy.WaterStep.FLOODED)
	var docks := PresentationCatalog.dock_cells(TerraceStamps.stamps())
	assert_gt(docks.size(), 0)
	for coord in docks.keys():
		var cell: Cell = map.get_cell(coord)
		assert_not_null(cell, "the dock stands on authored cells: %s" % coord)
		assert_true(cell.has_flag(Taxonomy.CellFlags.DECK), "dock cell %s is a deck" % coord)
		assert_false(map.is_wet(coord), "dock cell %s is dry ground" % coord)
