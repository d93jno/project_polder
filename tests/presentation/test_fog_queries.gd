extends GutTest

## Fog filters live in overlay_queries — not in the view (plan 04 §4.3).

const Queries := preload("res://presentation/overlay_queries.gd")


func _street(length := 8) -> BowlMap:
	var map := BowlMap.new()
	for x in range(0, length + 1):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	return map


func _room_bowl() -> BowlMap:
	## Street y=0; masonry wall y=1 with door at (4,1); room y=2.
	var map := _street(6)
	for x in range(3, 6):
		map.set_cell(Vector3i(x, 1, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
		map.set_cell(Vector3i(x, 2, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(4, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	return map


func _ids(hostiles: Array) -> Array:
	var out: Array = []
	for h in hostiles:
		out.append(h.id)
	return out


func test_hostile_in_room_absent_until_sight_line() -> void:
	var map := _room_bowl()
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var enemy := Unit.new(10, Vector3i(4, 2, 0), Taxonomy.Faction.DRIFTER)
	var state := CombatState.new()
	state.map = map
	state.add_unit(player)
	state.add_unit(enemy)

	state.knowledge.peel(map, state)
	var before = Queries.compute(map, state, 1, enemy.cell)
	assert_false(_ids(before.hostiles).has(10), "room hostile not offered")
	assert_false(before.hover_hostile, "shot preview must not name an unoffered target")
	assert_eq(before.shot_outcome, "")

	player.cell = Vector3i(4, 1, 0)
	state.knowledge.peel(map, state)
	var after = Queries.compute(map, state, 1, enemy.cell)
	assert_true(_ids(after.hostiles).has(10), "Live after a line through the door")
	assert_true(after.hover_hostile)
	assert_ne(after.shot_outcome, "")


func test_earshot_locates_out_of_earshot_does_not() -> void:
	var map := _street(10)
	map.set_cell(Vector3i(4, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var scout := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var near := Unit.new(2, Vector3i(2, 0, 0), Taxonomy.Faction.PLAYER)
	var far := Unit.new(3, Vector3i(8, 0, 0), Taxonomy.Faction.PLAYER)
	var enemy := Unit.new(10, Vector3i(1, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE)
	var state := CombatState.new()
	state.map = map
	state.add_unit(scout)
	state.add_unit(near)
	state.add_unit(far)
	state.add_unit(enemy)
	state.knowledge.peel(map, state)

	assert_true(_ids(Queries.compute(map, state, 1, enemy.cell).hostiles).has(10), "squad picture")
	var near_q = Queries.compute(map, state, 2, enemy.cell)
	assert_eq(near_q.exposure.count, 1)
	assert_eq(near_q.exposure.sources.size(), 1, "in earshot of the seer — located")
	var far_q = Queries.compute(map, state, 3, enemy.cell)
	assert_eq(far_q.exposure.sources.size(), 0, "out of earshot — not located")
	assert_eq(state.knowledge.merged_sight(state, far, enemy.cell), Knowledge.CellSight.UNKNOWN)


func test_shot_preview_never_names_unoffered_target() -> void:
	var map := _street()
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.PISTOL)
	var enemy := Unit.new(10, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER)
	var state := CombatState.new()
	state.map = map
	state.add_unit(player)
	state.add_unit(enemy)
	## No peel — squad picture is Unknown.
	var q = Queries.compute(map, state, 1, enemy.cell)
	assert_eq(q.hostiles.size(), 0)
	assert_false(q.hover_hostile)
	assert_eq(q.shot_outcome, "")
	assert_eq(q.exposure.count, 1, "count stays truthful")
	assert_eq(q.exposure.sources.size(), 0, "unpeeled — counted, not located")


func test_cone_apex_follows_squad_live() -> void:
	var map := _street()
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.RIFLE)
	var state := CombatState.new()
	state.map = map
	state.add_unit(player)
	state.add_unit(enemy)
	state.add_watch(LiveWatch.new(2, Vector3i(-1, 0, 0)))

	var fogged = Queries.compute(map, state, 1, Vector3i(2, 0, 0))
	assert_eq(fogged.watches.size(), 1)
	assert_gt(fogged.watches[0]["cells"].size(), 0, "volume remains")
	assert_false(fogged.watches[0]["apex_known"], "apex waits on Live")

	state.knowledge.peel(map, state)
	var live = Queries.compute(map, state, 1, Vector3i(2, 0, 0))
	assert_true(live.watches[0]["apex_known"], "Live in the squad picture names the apex")
