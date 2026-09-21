extends GutTest

## Clicking a body must pick the body. The ground-plane-only pick sent a click on an enemy's torso
## to the tile behind their feet, so aiming became a move.

const Picking := preload("res://presentation/picking.gd")
const ScriptedFight := preload("res://rules/fixtures/scripted_fight.gd")


func _rest_eye() -> Vector3:
	## Same pose as PresentationCameraRig at rest, looking at the fight view's look point.
	var look := PresentationCoords.world(Vector3i(8, 3, 0)) + Vector3(0.0, 1.5, 0.0)
	var arm: float = PresentationCameraRig.ZOOM_DISTANCES[PresentationCameraRig.REST_ZOOM_INDEX]
	return look + PresentationCameraRig.eye_offset(arm, PresentationCameraRig.PITCH_DEG, 0.0)


func _ray_at(target: Vector3) -> Array:
	var eye := _rest_eye()
	return [eye, (target - eye).normalized()]


func test_cylinder_side_top_and_misses() -> void:
	var foot := Vector3(0.0, 0.0, 0.0)
	## Horizontal ray at chest height, from 5 m out along -X: hits the near wall at x = -0.6.
	var t := Picking.ray_vs_cylinder(Vector3(-5.0, 1.0, 0.0), Vector3.RIGHT, foot, 0.6, 1.9)
	assert_almost_eq(t, 4.4, 0.001)
	## Straight down onto the top cap.
	t = Picking.ray_vs_cylinder(Vector3(0.1, 5.0, 0.1), Vector3.DOWN, foot, 0.6, 1.9)
	assert_almost_eq(t, 3.1, 0.001)
	## Above the head, beside the body, and pointing away are all misses.
	assert_eq(Picking.ray_vs_cylinder(Vector3(-5.0, 2.5, 0.0), Vector3.RIGHT, foot, 0.6, 1.9), -1.0)
	assert_eq(Picking.ray_vs_cylinder(Vector3(-5.0, 1.0, 1.0), Vector3.RIGHT, foot, 0.6, 1.9), -1.0)
	assert_eq(Picking.ray_vs_cylinder(Vector3(-5.0, 1.0, 0.0), Vector3.LEFT, foot, 0.6, 1.9), -1.0)


func test_torso_and_head_pick_the_enemy_but_the_ground_plane_alone_would_not() -> void:
	var state: CombatState = ScriptedFight.opening()
	for id in [ScriptedFight.D_NEAR, ScriptedFight.D_FAR_A, ScriptedFight.D_FAR_B]:
		var unit: Unit = state.get_unit(id)
		var foot := PresentationCoords.world_ground(unit.cell)
		for height in [0.0, 1.0, 1.7]:
			var ray := _ray_at(foot + Vector3(0.0, height, 0.0))
			var body: Dictionary = Picking.body_under_ray(state, 0, ray[0], ray[1])
			assert_false(body.is_empty(), "unit %d at height %.1f must be under the ray" % [id, height])
			assert_eq((body["unit"] as Unit).id, id)
			if height > 0.5:
				## The bug: the ray meets the floor beyond the feet, in the next cell.
				var t: float = (0.0 - (ray[0] as Vector3).y) / (ray[1] as Vector3).y
				var hit: Vector3 = (ray[0] as Vector3) + (ray[1] as Vector3) * t
				var xy := PresentationCoords.cell_on_ground(hit)
				assert_ne(Vector2i(xy.x, xy.y), Vector2i(unit.cell.x, unit.cell.y),
					"ground plane alone misses unit %d at height %.1f" % [id, height])


func test_tiles_beside_and_in_front_of_an_enemy_stay_moves() -> void:
	## Clicking the floor next to or in front of an enemy must not pick the enemy.
	var state: CombatState = ScriptedFight.opening()
	var d: Unit = state.get_unit(ScriptedFight.D_NEAR)
	for offset in [Vector3i(-1, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 1, 0)]:
		var cell: Vector3i = d.cell + offset
		var ray := _ray_at(PresentationCoords.world_ground(cell))
		var body: Dictionary = Picking.body_under_ray(state, 0, ray[0], ray[1])
		assert_true(body.is_empty(), "floor at %s is not the enemy at %s" % [cell, d.cell])


func test_the_floor_point_directly_behind_an_enemy_is_hidden_by_their_body() -> void:
	## From the camera the body covers the middle of the tile behind it, so a click there is a
	## click on the body. That is what is drawn; the rest of that tile is still clickable.
	var state: CombatState = ScriptedFight.opening()
	var d: Unit = state.get_unit(ScriptedFight.D_NEAR)
	var behind := d.cell + Vector3i(1, 0, 0)
	var ray := _ray_at(PresentationCoords.world_ground(behind))
	var body: Dictionary = Picking.body_under_ray(state, 0, ray[0], ray[1])
	assert_false(body.is_empty())
	assert_eq((body["unit"] as Unit).id, ScriptedFight.D_NEAR)
	var edge := PresentationCoords.world_ground(behind) + Vector3(0.0, 0.0, 0.9)
	var side_ray := _ray_at(edge)
	assert_true(Picking.body_under_ray(state, 0, side_ray[0], side_ray[1]).is_empty())


func test_extracted_dead_and_hidden_floor_units_are_not_pickable() -> void:
	var state: CombatState = ScriptedFight.opening()
	var d: Unit = state.get_unit(ScriptedFight.D_NEAR)
	var ray := _ray_at(PresentationCoords.world_ground(d.cell) + Vector3(0.0, 1.0, 0.0))
	assert_false(Picking.body_under_ray(state, 0, ray[0], ray[1]).is_empty())
	d.dead = true
	assert_true(Picking.body_under_ray(state, 0, ray[0], ray[1]).is_empty(), "dead")
	d.dead = false
	d.extracted = true
	assert_true(Picking.body_under_ray(state, 0, ray[0], ray[1]).is_empty(), "extracted")
	d.extracted = false
	d.cell = Vector3i(d.cell.x, d.cell.y, 1)
	var up := _ray_at(PresentationCoords.world_ground(d.cell) + Vector3(0.0, 1.0, 0.0))
	assert_true(Picking.body_under_ray(state, 0, up[0], up[1]).is_empty(), "above the cutaway")
	assert_false(Picking.body_under_ray(state, 1, up[0], up[1]).is_empty(), "cutaway opened")


func test_a_downed_body_is_low_not_standing_height() -> void:
	var state: CombatState = ScriptedFight.opening()
	var d: Unit = state.get_unit(ScriptedFight.D_NEAR)
	var high := _ray_at(PresentationCoords.world_ground(d.cell) + Vector3(0.0, 1.5, 0.0))
	assert_false(Picking.body_under_ray(state, 0, high[0], high[1]).is_empty(), "standing")
	d.bleeding = true
	assert_true(Picking.body_under_ray(state, 0, high[0], high[1]).is_empty(), "lying down")
	var low := _ray_at(PresentationCoords.world_ground(d.cell) + Vector3(0.0, 0.3, 0.0))
	assert_false(Picking.body_under_ray(state, 0, low[0], low[1]).is_empty(), "still clickable")


func test_nearest_body_wins() -> void:
	## Two bodies on one line of sight: the nearer one is picked.
	var state := CombatState.new()
	state.map = BowlMap.new()
	var far := Unit.new(1, Vector3i(9, 4, 0), Taxonomy.Faction.DRIFTER)
	var near := Unit.new(2, Vector3i(8, 4, 0), Taxonomy.Faction.DRIFTER)
	state.add_unit(far)
	state.add_unit(near)
	var ray := _ray_at(PresentationCoords.world_ground(near.cell) + Vector3(0.0, 1.0, 0.0))
	var body: Dictionary = Picking.body_under_ray(state, 0, ray[0], ray[1])
	assert_eq((body["unit"] as Unit).id, 2)


## What you see is what you click. A swimmer's tile is drawn on the water surface, so a click
## there must resolve on that plane. Casting at the street floor lands about a cell behind it.
func _street_and_roof() -> BowlMap:
	var map := BowlMap.new()
	for x in range(0, 12):
		for y in range(0, 8):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(4, 4, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	return map


func _plane(step: Taxonomy.WaterStep) -> Callable:
	return func(z: int) -> float: return PresentationCoords.play_y(z, step, 0)


func test_a_click_on_the_water_surface_picks_the_cell_drawn_there() -> void:
	var map := _street_and_roof()
	var flooded := Taxonomy.WaterStep.FLOODED
	for cell in [Vector3i(3, 3, 0), Vector3i(7, 2, 0), Vector3i(9, 5, 0)]:
		var ray := _ray_at(PresentationCoords.world_play(cell, flooded, 0))
		var hit: Dictionary = Picking.cell_under_ray(map, 0, ray[0], ray[1], _plane(flooded))
		assert_eq(hit.get("cell"), cell, "flooded: the surface is where the tile is drawn")
		var on_floor: Dictionary = Picking.cell_under_ray(map, 0, ray[0], ray[1], _plane(Taxonomy.WaterStep.DRY))
		assert_ne(on_floor.get("cell"), cell, "casting at the floor would have landed off the tile")


func test_a_high_cutaway_does_not_shift_a_street_click() -> void:
	## With every level open the ray meets the upper planes first; it must not adopt their x/y for
	## the street it was really aimed at.
	var map := _street_and_roof()
	var dry := Taxonomy.WaterStep.DRY
	var cell := Vector3i(3, 3, 0)
	var ray := _ray_at(PresentationCoords.world_play(cell, dry, 0))
	var hit: Dictionary = Picking.cell_under_ray(map, 2, ray[0], ray[1], _plane(dry))
	assert_eq(hit.get("cell"), cell)


func test_a_roof_picks_when_its_level_is_open_and_the_ray_meets_it() -> void:
	var map := _street_and_roof()
	var dry := Taxonomy.WaterStep.DRY
	var roof := Vector3i(4, 4, 1)
	var ray := _ray_at(PresentationCoords.world_play(roof, dry, 0))
	assert_eq(Picking.cell_under_ray(map, 1, ray[0], ray[1], _plane(dry)).get("cell"), roof)
	var closed: Dictionary = Picking.cell_under_ray(map, 0, ray[0], ray[1], _plane(dry))
	assert_ne(closed.get("cell"), roof, "cutaway 0 hides the roof, so it cannot be picked")


func test_a_ray_that_meets_no_authored_cell_picks_nothing() -> void:
	var map := _street_and_roof()
	var ray := _ray_at(Vector3(200.0, 0.0, 200.0))
	assert_true(Picking.cell_under_ray(map, 1, ray[0], ray[1], _plane(Taxonomy.WaterStep.DRY)).is_empty())
