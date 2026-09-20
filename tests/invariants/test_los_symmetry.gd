extends GutTest

## Property: los(a,b,w).clean == los(b,a,w).clean for all a, b, w.


func test_los_clean_is_symmetric_on_random_bowls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260920

	var materials: Array = Taxonomy.CoverMaterial.values()
	var weapons: Array = Taxonomy.WeaponClass.values()
	var checks := 0

	for _bowl_i in range(24):
		var bowl := BowlMap.new()
		bowl.water_step = rng.randi_range(0, Taxonomy.WaterStep.values().size() - 1) as Taxonomy.WaterStep
		bowl.water_z = rng.randi_range(-1, 1)

		## Sparse random volume in a 5x5x3 box.
		for _cell_i in range(18):
			var coord := Vector3i(
				rng.randi_range(-2, 2),
				rng.randi_range(-2, 2),
				rng.randi_range(-1, 1)
			)
			var material: Taxonomy.CoverMaterial = materials[rng.randi_range(0, materials.size() - 1)]
			bowl.set_cell(coord, Cell.new(material))

		for _pair_i in range(20):
			var a := Vector3i(
				rng.randi_range(-2, 2),
				rng.randi_range(-2, 2),
				rng.randi_range(-1, 1)
			)
			var b := Vector3i(
				rng.randi_range(-2, 2),
				rng.randi_range(-2, 2),
				rng.randi_range(-1, 1)
			)
			var weapon: Taxonomy.WeaponClass = weapons[rng.randi_range(0, weapons.size() - 1)]
			var ab := Los.line_of_sight(bowl, a, b, weapon)
			var ba := Los.line_of_sight(bowl, b, a, weapon)
			assert_eq(
				ab.clean,
				ba.clean,
				"symmetry broken a=%s b=%s w=%s ab_blocker=%s@%s ba_blocker=%s@%s"
				% [
					a,
					b,
					Taxonomy.weapon_class_name(weapon),
					Taxonomy.material_name(ab.blocker),
					ab.blocker_cell,
					Taxonomy.material_name(ba.blocker),
					ba.blocker_cell,
				]
			)
			checks += 1

	assert_gt(checks, 400, "property suite should exercise hundreds of pairs")
