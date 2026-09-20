extends GutTest

## exposure.count > 0  <=>  exists hostile with clean los onto the unit.


func test_exposure_count_agrees_with_los_on_random_bowls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260920

	var materials: Array = Taxonomy.CoverMaterial.values()
	var weapons: Array = Taxonomy.WeaponClass.values()
	var checks := 0

	for _i in range(30):
		var map := BowlMap.new()
		map.water_step = (
			[
				Taxonomy.WaterStep.FLOODED,
				Taxonomy.WaterStep.FALLING,
				Taxonomy.WaterStep.MUD,
				Taxonomy.WaterStep.DRY,
			][rng.randi_range(0, 3)]
		)

		for _c in range(14):
			var coord := Vector3i(
				rng.randi_range(-2, 2),
				rng.randi_range(-2, 2),
				rng.randi_range(-1, 1)
			)
			var material: Taxonomy.CoverMaterial = materials[rng.randi_range(0, materials.size() - 1)]
			var flags := 0
			if rng.randf() < 0.15:
				flags = Taxonomy.CellFlags.SHELTER
			map.set_cell(coord, Cell.new(material, flags))

		var state := CombatState.new()
		var player := Unit.new(
			1,
			Vector3i(rng.randi_range(-2, 2), rng.randi_range(-2, 2), rng.randi_range(-1, 1)),
			Taxonomy.Faction.PLAYER,
			weapons[rng.randi_range(0, weapons.size() - 1)]
		)
		state.add_unit(player)

		var hostile_n := rng.randi_range(1, 4)
		for h in range(hostile_n):
			state.add_unit(
				Unit.new(
					10 + h,
					Vector3i(rng.randi_range(-2, 2), rng.randi_range(-2, 2), rng.randi_range(-1, 1)),
					Taxonomy.Faction.DRIFTER,
					weapons[rng.randi_range(0, weapons.size() - 1)]
				)
			)

		var exp := ExposureQuery.exposure(map, state, player)
		var los_count := 0
		for hostile in state.hostiles_of(player):
			if Los.line_of_sight(map, hostile.cell, player.cell, hostile.weapon).clean:
				los_count += 1

		assert_eq(
			exp.count,
			los_count,
			"exposure.count must equal hostile los count (player@%s)" % player.cell
		)
		assert_eq(
			exp.count > 0,
			los_count > 0,
			"exposure.count > 0 <=> exists hostile clean los"
		)
		assert_lte(exp.sources.size(), exp.count, "sources are a subset of count")
		checks += 1

	assert_gt(checks, 20)
