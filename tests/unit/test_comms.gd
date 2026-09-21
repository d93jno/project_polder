extends GutTest

## Comms.shares: one earshot predicate (plan 04 §4.2 / §7.3).


func _pair(
	a_cell: Vector3i,
	b_cell: Vector3i,
	a_faction := Taxonomy.Faction.PLAYER,
	b_faction := Taxonomy.Faction.PLAYER,
) -> Array:
	var a := Unit.new(1, a_cell, a_faction)
	var b := Unit.new(2, b_cell, b_faction)
	var state := CombatState.new()
	state.add_unit(a)
	state.add_unit(b)
	return [state, a, b]


func test_shares_is_symmetric() -> void:
	var pair := _pair(Vector3i(0, 0, 0), Vector3i(2, 0, 0))
	var state: CombatState = pair[0]
	var a: Unit = pair[1]
	var b: Unit = pair[2]
	assert_eq(Comms.shares(state, a, b), Comms.shares(state, b, a))
	assert_true(Comms.shares(state, a, b))


func test_shares_at_radius_edge() -> void:
	var r := RulesConstants.EARSHOT_RADIUS
	var inside := _pair(Vector3i(0, 0, 0), Vector3i(r, 0, 0))
	assert_true(Comms.shares(inside[0], inside[1], inside[2]), "distance %d shares" % r)
	var outside := _pair(Vector3i(0, 0, 0), Vector3i(r + 1, 0, 0))
	assert_false(Comms.shares(outside[0], outside[1], outside[2]), "distance %d does not" % (r + 1))


func test_shares_uses_chebyshev_including_diagonal() -> void:
	var r := RulesConstants.EARSHOT_RADIUS
	var pair := _pair(Vector3i(0, 0, 0), Vector3i(r, r, 0))
	assert_true(Comms.shares(pair[0], pair[1], pair[2]), "diagonal chebyshev %d shares" % r)


func test_shares_ignores_walls() -> void:
	var pair := _pair(Vector3i(0, 0, 0), Vector3i(2, 0, 0))
	var state: CombatState = pair[0]
	state.map = BowlMap.new()
	state.map.set_cell(Vector3i(1, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	assert_true(Comms.shares(state, pair[1], pair[2]), "sound is not sight")


func test_different_faction_does_not_share() -> void:
	var pair := _pair(
		Vector3i(0, 0, 0), Vector3i(1, 0, 0),
		Taxonomy.Faction.PLAYER, Taxonomy.Faction.DRIFTER
	)
	assert_false(Comms.shares(pair[0], pair[1], pair[2]))


func test_inactive_does_not_share() -> void:
	var pair := _pair(Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	var state: CombatState = pair[0]
	var a: Unit = pair[1]
	var b: Unit = pair[2]
	b.bleeding = true
	assert_false(Comms.shares(state, a, b))
	assert_false(Comms.shares(state, b, a))


func test_self_does_not_share() -> void:
	var pair := _pair(Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	var a: Unit = pair[1]
	assert_false(Comms.shares(pair[0], a, a))
