extends GutTest

## Plan 3.2 — stamps vs cells authoring lint.

const BowlDraw = preload("res://presentation/bowl_draw.gd")
const ScriptedFight = preload("res://rules/fixtures/scripted_fight.gd")


func test_scripted_street_passes_lint() -> void:
	var failures := BowlAuthoring.lint(ScriptedFight.street(), ScriptedFight.stamps())
	assert_eq(failures, PackedStringArray(), "\n".join(failures))


func test_cutaway_passes_lint() -> void:
	var failures := BowlAuthoring.lint(CutawayBowl.map(), CutawayBowl.stamps())
	assert_eq(failures, PackedStringArray(), "\n".join(failures))


func test_cutaway_without_ladders_fails_invisible_climb() -> void:
	## The expected first failure before the fixture gained connector stamps.
	var stamps: Array = [Stamp.new("env_roof_deck_a", CutawayBowl.ROOF, 0.0)]
	var failures := BowlAuthoring.lint(CutawayBowl.map(), stamps)
	assert_gt(failures.size(), 0)
	var climb := false
	for f in failures:
		if str(f).begins_with("invisible climb:"):
			climb = true
	assert_true(climb, "roof over street without a ladder must fail lint 4")


func test_cover_honesty_fails_when_house_over_air() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(1, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(0, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(1, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var stamps: Array = [Stamp.new("env_house_2storey_a", Vector3i(0, 0, 0), 0.0)]
	var failures := BowlAuthoring.lint(map, stamps)
	var hit := false
	for f in failures:
		if str(f).begins_with("cover honesty:"):
			hit = true
	assert_true(hit, "masonry house over AIR must fail cover honesty")


func test_orphan_deck_without_stamp_fails() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(2, 2, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	var failures := BowlAuthoring.lint(map, [])
	var hit := false
	for f in failures:
		if str(f).begins_with("orphan cell:"):
			hit = true
	assert_true(hit, "deck cell with multi-cell mesh must be stamped")


func test_overlapping_stamps_fail() -> void:
	var map := BowlMap.new()
	for x in 2:
		for y in 2:
			map.set_cell(Vector3i(x, y, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	var stamps: Array = [
		Stamp.new("env_roof_deck_a", Vector3i(0, 0, 1), 0.0),
		Stamp.new("env_roof_deck_b", Vector3i(0, 0, 1), 0.0),
	]
	var failures := BowlAuthoring.lint(map, stamps)
	var hit := false
	for f in failures:
		if str(f).begins_with("overlap:"):
			hit = true
	assert_true(hit, "two decks on the same cells must fail overlap lint")


func test_invisible_climb_fails_without_connector() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(1, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(1, 1, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	var failures := BowlAuthoring.lint(map, [])
	var hit := false
	for f in failures:
		if str(f).begins_with("invisible climb:"):
			hit = true
	assert_true(hit)


func test_swim_column_exempts_vertical_stack() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(1, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(1, 1, 1), Cell.new(Taxonomy.CoverMaterial.AIR))
	var failures := BowlAuthoring.lint(map, [], [Vector2i(1, 1)])
	assert_eq(failures, PackedStringArray())


func test_footprint_yaw_swaps_axes() -> void:
	assert_eq(PresentationCatalog.footprint_size("env_pier", 0.0), Vector3i(1, 3, 1))
	assert_eq(PresentationCatalog.footprint_size("env_pier", 90.0), Vector3i(3, 1, 1))


func test_draw_stamps_instances_once_per_stamp() -> void:
	var bowl = BowlDraw.new()
	add_child_autofree(bowl)
	bowl.draw_map(CutawayBowl.map(), CutawayBowl.stamps())
	var decks := 0
	var ladders := 0
	for n in bowl.get_children():
		var id: String = str(n.get_meta("polder_piece", ""))
		if id == "env_roof_deck_a":
			decks += 1
		elif id == "env_ladder":
			ladders += 1
	assert_eq(decks, 1, "2×2 deck is one stamp, not one mesh per cell")
	assert_eq(ladders, 2)
	assert_eq(bowl.pieces[CutawayBowl.ROOF], "env_roof_deck_a")
	assert_eq(bowl.cover_tag_at(CutawayBowl.ROOF), -1)
