extends GutTest

## Sight line vs weapon line (plan 04 §4.0). Eyes are not a weapon.


func _air_bowl() -> BowlMap:
	return BowlMap.new()


func test_blocks_sight_table() -> void:
	## Written out — do not silently inherit from stops().
	var blocks: Array = [
		Taxonomy.CoverMaterial.MASONRY,
		Taxonomy.CoverMaterial.METAL,
		Taxonomy.CoverMaterial.GROUND,
		Taxonomy.CoverMaterial.SMOKE,
		Taxonomy.CoverMaterial.WATER_DEEP,
	]
	var clear: Array = [
		Taxonomy.CoverMaterial.AIR,
		Taxonomy.CoverMaterial.WATER_CHEST,
		Taxonomy.CoverMaterial.PLANK,
		Taxonomy.CoverMaterial.CRATE,
		Taxonomy.CoverMaterial.DEPLOYED_BARRIER,
	]
	assert_eq(blocks.size() + clear.size(), Taxonomy.material_count(), "every material classified")
	for material in blocks:
		assert_true(
			Taxonomy.blocks_sight(material),
			"%s blocks sight" % Taxonomy.material_name(material)
		)
	for material in clear:
		assert_false(
			Taxonomy.blocks_sight(material),
			"%s does not block sight" % Taxonomy.material_name(material)
		)


func test_plank_stops_pistol_not_sight() -> void:
	## The bug that made sight its own line: soft cover stops short shots, not eyes.
	var bowl := _air_bowl()
	bowl.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.PLANK))
	var pistol := Los.line_of_sight(
		bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0), Taxonomy.WeaponClass.PISTOL
	)
	assert_false(pistol.clean, "plank stops pistol")
	var sight := Los.sight_line(bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0))
	assert_true(sight.clean, "plank does not block sight")


func test_crate_and_barrier_do_not_block_sight() -> void:
	for material in [Taxonomy.CoverMaterial.CRATE, Taxonomy.CoverMaterial.DEPLOYED_BARRIER]:
		var bowl := _air_bowl()
		bowl.set_cell(Vector3i(2, 0, 0), Cell.new(material))
		var sight := Los.sight_line(bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0))
		assert_true(
			sight.clean,
			"%s does not block sight (§7.1)" % Taxonomy.material_name(material)
		)


func test_masonry_blocks_sight() -> void:
	var bowl := _air_bowl()
	bowl.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var sight := Los.sight_line(bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0))
	assert_false(sight.clean)
	assert_eq(sight.blocker, Taxonomy.CoverMaterial.MASONRY)
	assert_eq(sight.blocker_cell, Vector3i(2, 0, 0))


func test_body_in_deep_water_has_no_sight_to_or_from() -> void:
	var bowl := _air_bowl()
	bowl.water_step = Taxonomy.WaterStep.FLOODED
	bowl.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.WATER_DEEP))
	bowl.set_cell(Vector3i(4, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))

	var from_deep := Los.sight_line(bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0))
	assert_false(from_deep.clean)
	assert_eq(from_deep.blocker, Taxonomy.CoverMaterial.WATER_DEEP)
	assert_eq(from_deep.blocker_cell, Vector3i(0, 0, 0))

	var to_deep := Los.sight_line(bowl, Vector3i(4, 0, 0), Vector3i(0, 0, 0))
	assert_false(to_deep.clean)
	assert_eq(to_deep.blocker, Taxonomy.CoverMaterial.WATER_DEEP)
	assert_eq(to_deep.blocker_cell, Vector3i(0, 0, 0))


func test_chest_deep_water_does_not_hide_or_block_sight() -> void:
	var bowl := _air_bowl()
	bowl.water_step = Taxonomy.WaterStep.FALLING
	for x in range(0, 5):
		bowl.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.WATER_CHEST))
	var sight := Los.sight_line(bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0))
	assert_true(sight.clean, "chest-deep water does not hide or block sight")


func test_sight_line_same_cell_is_clean() -> void:
	var sight := Los.sight_line(_air_bowl(), Vector3i(1, 2, 3), Vector3i(1, 2, 3))
	assert_true(sight.clean)
