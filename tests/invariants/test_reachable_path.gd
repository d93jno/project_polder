extends GutTest

## reachable() and path() run one flood, so they must agree on every tile (plan §1.5.1):
##   tile in reachable(budget)  <=>  path(tile).reachable and path(tile).total_cost <= budget
## Also: exposure and attackers_of agree once bleeders are filtered out.

const FIELD := 3 ## tiles run -FIELD..FIELD on x and y


func _random_bowl(rng: RandomNumberGenerator) -> BowlMap:
	var map := BowlMap.new()
	map.water_step = (
		[
			Taxonomy.WaterStep.FLOODED,
			Taxonomy.WaterStep.MUD,
			Taxonomy.WaterStep.DRY,
		][rng.randi_range(0, 2)]
	)
	var solids: Array = [
		Taxonomy.CoverMaterial.AIR,
		Taxonomy.CoverMaterial.AIR,
		Taxonomy.CoverMaterial.AIR,
		Taxonomy.CoverMaterial.PLANK,
		Taxonomy.CoverMaterial.MASONRY,
	]
	for x in range(-FIELD, FIELD + 1):
		for y in range(-FIELD, FIELD + 1):
			map.set_cell(Vector3i(x, y, 0), Cell.new(solids[rng.randi_range(0, solids.size() - 1)]))
	return map


func _random_cell(rng: RandomNumberGenerator) -> Vector3i:
	return Vector3i(rng.randi_range(-FIELD, FIELD), rng.randi_range(-FIELD, FIELD), 0)


func test_reachable_agrees_with_path_on_random_bowls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260921
	var checked_tiles := 0

	for _i in range(25):
		var map := _random_bowl(rng)
		var state := CombatState.new()
		var start := _random_cell(rng)
		map.set_cell(start, Cell.new(Taxonomy.CoverMaterial.AIR))
		var mover := Unit.new(1, start, Taxonomy.Faction.PLAYER)
		state.add_unit(mover)
		for b in range(rng.randi_range(0, 4)):
			var body := Unit.new(10 + b, _random_cell(rng), Taxonomy.Faction.DRIFTER)
			if body.cell == start:
				continue
			body.bleeding = rng.randf() < 0.3 ## downed bodies must not block
			state.add_unit(body)

		var budget := rng.randi_range(0, 8)
		var reach := Movement.reachable(map, state, mover, budget)
		for x in range(-FIELD, FIELD + 1):
			for y in range(-FIELD, FIELD + 1):
				var tile := Vector3i(x, y, 0)
				var p := Movement.path(map, state, mover, tile)
				var by_path := p.reachable and p.total_cost <= budget
				assert_eq(
					tile in reach,
					by_path,
					"reachable vs path at %s (start %s, budget %d)" % [tile, start, budget]
				)
				checked_tiles += 1
		assert_true(start in reach, "the start is always reachable")

	assert_gt(checked_tiles, 1000)


func test_attackers_agree_with_exposure_and_are_all_standing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260922
	var weapons: Array = Taxonomy.WeaponClass.values()
	var saw_a_downed_hostile := false

	for _i in range(30):
		var map := _random_bowl(rng)
		var state := CombatState.new()
		var player := Unit.new(1, _random_cell(rng), Taxonomy.Faction.PLAYER, weapons[rng.randi_range(0, weapons.size() - 1)])
		state.add_unit(player)
		for h in range(rng.randi_range(1, 5)):
			var hostile := Unit.new(10 + h, _random_cell(rng), Taxonomy.Faction.DRIFTER, weapons[rng.randi_range(0, weapons.size() - 1)])
			var roll := rng.randf()
			hostile.bleeding = roll < 0.25
			hostile.dead = roll >= 0.25 and roll < 0.4
			saw_a_downed_hostile = saw_a_downed_hostile or hostile.bleeding or hostile.dead
			state.add_unit(hostile)

		var attackers := state.attackers_of(map, player)
		var exp := ExposureQuery.exposure(map, state, player)
		assert_eq(attackers.size(), exp.count, "attackers_of and exposure.count are one number")

		var by_hand := 0
		for other in state.all_units():
			if other.faction == Taxonomy.Faction.DRIFTER and other.is_active():
				if Los.line_of_sight(map, other.cell, player.cell, other.weapon).clean:
					by_hand += 1
		assert_eq(attackers.size(), by_hand, "counted by hand over standing hostiles only")
		for a in attackers:
			assert_true(a.is_active(), "no attacker is downed")

	assert_true(saw_a_downed_hostile, "the generator did exercise bleeders and the dead")
