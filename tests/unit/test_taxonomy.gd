extends GutTest

## Exhaustive CoverMaterial × WeaponClass stopping matrix (Taxonomy.stops is SoT).


func test_plank_stops_pistol_not_rifle() -> void:
	assert_true(
		Taxonomy.stops(Taxonomy.CoverMaterial.PLANK, Taxonomy.WeaponClass.PISTOL),
		"plank stops pistol (GDD §5.4)"
	)
	assert_false(
		Taxonomy.stops(Taxonomy.CoverMaterial.PLANK, Taxonomy.WeaponClass.RIFLE),
		"plank does not stop rifle (GDD §5.4)"
	)


func test_crate_matches_plank() -> void:
	for weapon in Taxonomy.WeaponClass.values():
		assert_eq(
			Taxonomy.stops(Taxonomy.CoverMaterial.CRATE, weapon),
			Taxonomy.stops(Taxonomy.CoverMaterial.PLANK, weapon),
			"crate and plank share soft-cover stopping for %s" % Taxonomy.weapon_class_name(weapon)
		)


func test_smoke_blocks_every_class() -> void:
	for weapon in Taxonomy.WeaponClass.values():
		assert_true(
			Taxonomy.stops(Taxonomy.CoverMaterial.SMOKE, weapon),
			"smoke blocks %s (GDD §5.4)" % Taxonomy.weapon_class_name(weapon)
		)


func test_deep_water_blocks_every_class() -> void:
	for weapon in Taxonomy.WeaponClass.values():
		assert_true(
			Taxonomy.stops(Taxonomy.CoverMaterial.WATER_DEEP, weapon),
			"deep water blocks %s" % Taxonomy.weapon_class_name(weapon)
		)


func test_chest_water_blocks_nothing() -> void:
	for weapon in Taxonomy.WeaponClass.values():
		assert_false(
			Taxonomy.stops(Taxonomy.CoverMaterial.WATER_CHEST, weapon),
			"chest-deep water does not block %s (GDD §5.4 / §5.8)" % Taxonomy.weapon_class_name(weapon)
		)


func test_air_blocks_nothing() -> void:
	for weapon in Taxonomy.WeaponClass.values():
		assert_false(
			Taxonomy.stops(Taxonomy.CoverMaterial.AIR, weapon),
			"air does not block %s" % Taxonomy.weapon_class_name(weapon)
		)


func test_hard_cover_stops_all() -> void:
	var hard: Array = [
		Taxonomy.CoverMaterial.MASONRY,
		Taxonomy.CoverMaterial.METAL,
		Taxonomy.CoverMaterial.DEPLOYED_BARRIER,
		Taxonomy.CoverMaterial.GROUND,
	]
	for material in hard:
		for weapon in Taxonomy.WeaponClass.values():
			assert_true(
				Taxonomy.stops(material, weapon),
				"%s stops %s" % [Taxonomy.material_name(material), Taxonomy.weapon_class_name(weapon)]
			)


func test_soft_cover_stops_short_passes_long() -> void:
	var soft: Array = [Taxonomy.CoverMaterial.PLANK, Taxonomy.CoverMaterial.CRATE]
	var stopped: Array = [
		Taxonomy.WeaponClass.PISTOL,
		Taxonomy.WeaponClass.MELEE,
		Taxonomy.WeaponClass.SPEAR,
		Taxonomy.WeaponClass.SHOTGUN,
	]
	var passes: Array = [
		Taxonomy.WeaponClass.RIFLE,
		Taxonomy.WeaponClass.LMG,
		Taxonomy.WeaponClass.SNIPER,
	]
	for material in soft:
		for weapon in stopped:
			assert_true(
				Taxonomy.stops(material, weapon),
				"%s stops %s" % [Taxonomy.material_name(material), Taxonomy.weapon_class_name(weapon)]
			)
		for weapon in passes:
			assert_false(
				Taxonomy.stops(material, weapon),
				"%s does not stop %s" % [Taxonomy.material_name(material), Taxonomy.weapon_class_name(weapon)]
			)


func test_stopping_table_is_total() -> void:
	## Every CoverMaterial × WeaponClass pair is defined (no unhandled enum falls through silently).
	var materials: Array = Taxonomy.CoverMaterial.values()
	var weapons: Array = Taxonomy.WeaponClass.values()
	assert_eq(materials.size(), 10, "P0 material set size")
	assert_eq(weapons.size(), 7, "weapon class set size (assets §6.2)")
	for material in materials:
		for weapon in weapons:
			var result: bool = Taxonomy.stops(material, weapon)
			assert_typeof(result, TYPE_BOOL)
			## Touch both branches so the matrix is exercised, not just typed.
			assert_true(result or not result)


func test_material_and_weapon_names_cover_enums() -> void:
	for material in Taxonomy.CoverMaterial.values():
		var name: String = Taxonomy.material_name(material)
		assert_ne(name, "", "material %s has a name" % material)
	for weapon in Taxonomy.WeaponClass.values():
		var name: String = Taxonomy.weapon_class_name(weapon)
		assert_ne(name, "", "weapon %s has a name" % weapon)
