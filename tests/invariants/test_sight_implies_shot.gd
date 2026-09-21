extends GutTest

## Anything you can shoot, you can see (plan 04 §4.0).
## Across every CoverMaterial × WeaponClass: blocks_sight ⇒ stops.
## Fog can never hide a legal target; commands stay unchanged.


func test_sight_blocked_implies_shot_blocked() -> void:
	var materials: Array = Taxonomy.CoverMaterial.values()
	var weapons: Array = Taxonomy.WeaponClass.values()
	assert_eq(materials.size(), 10, "P0 material set size")
	assert_eq(weapons.size(), 7, "weapon class set size")
	var cases := 0
	for material in materials:
		for weapon in weapons:
			if Taxonomy.blocks_sight(material):
				assert_true(
					Taxonomy.stops(material, weapon),
					"sight blocked by %s but %s shot is clean — fog would hide a legal target"
					% [Taxonomy.material_name(material), Taxonomy.weapon_class_name(weapon)]
				)
			cases += 1
	assert_eq(cases, 70, "full product: 10 materials × 7 weapons")
