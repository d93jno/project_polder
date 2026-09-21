extends GutTest

## Combat commands: pin, watch cancel, health, bleed, trauma kit (plan §1.5).


func _air_corridor(map: BowlMap, x0: int, x1: int) -> void:
	for x in range(x0, x1 + 1):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))


func _two_unit_fight(
	player_weapon: Taxonomy.WeaponClass = Taxonomy.WeaponClass.PISTOL,
	enemy_weapon: Taxonomy.WeaponClass = Taxonomy.WeaponClass.PISTOL,
) -> CombatState:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_air_corridor(map, 0, 4)
	var state := CombatState.new()
	state.map = map
	state.active_side = CombatState.PhaseSide.PLAYER
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER, player_weapon)
	var enemy := Unit.new(2, Vector3i(4, 0, 0), Taxonomy.Faction.DRIFTER, enemy_weapon)
	state.add_unit(player)
	state.add_unit(enemy)
	return state


func test_validate_does_not_mutate() -> void:
	var state := _two_unit_fight()
	var ap_before: int = state.get_unit(1).ap
	var cmd := ShootCommand.new(1, 2)
	var result := cmd.validate(state)
	assert_true(result.ok)
	assert_eq(state.get_unit(1).ap, ap_before)
	assert_eq(state.get_unit(2).hp, RulesConstants.HP_PIPS)


func test_pistol_pins_then_second_shot_drops() -> void:
	var state := _two_unit_fight()
	state = ShootCommand.new(1, 2).apply(state)
	var enemy: Unit = state.get_unit(2)
	assert_eq(enemy.hp, 1)
	assert_eq(enemy.pin, Unit.PinState.DUCKING_NEXT, "hit in opponent's phase")
	assert_false(enemy.bleeding)

	state = state.end_phase() ## enemy phase — enemy is ducked
	assert_eq(state.active_side, CombatState.PhaseSide.ENEMY)
	assert_eq(state.get_unit(2).pin, Unit.PinState.DUCKED)
	assert_eq(state.get_unit(2).ap, 0)

	state = state.end_phase() ## back to player; duck clears for enemy
	assert_eq(state.get_unit(2).pin, Unit.PinState.NONE)

	state = ShootCommand.new(1, 2).apply(state)
	enemy = state.get_unit(2)
	assert_true(enemy.bleeding)
	assert_eq(enemy.bleed_rounds_left, RulesConstants.BLEED_ROUNDS)


func test_rifle_drops_in_one_hit() -> void:
	var state := _two_unit_fight(Taxonomy.WeaponClass.RIFLE)
	state = ShootCommand.new(1, 2).apply(state)
	var enemy: Unit = state.get_unit(2)
	assert_true(enemy.bleeding)
	assert_eq(enemy.hp, 0)
	assert_eq(enemy.pin, Unit.PinState.NONE)


func test_hit_in_own_phase_ducks_immediately() -> void:
	## Enemy watches the corridor; player walks into the cone → reaction pin.
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_air_corridor(map, 0, 4)
	map.set_cell(Vector3i(4, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var state := CombatState.new()
	state.map = map
	var player := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	var enemy := Unit.new(
		2, Vector3i(4, 1, 0), Taxonomy.Faction.DRIFTER, Taxonomy.WeaponClass.PISTOL, Vector3i(0, -1, 0)
	)
	state.add_unit(player)
	state.add_unit(enemy)
	state.add_watch(LiveWatch.new(2, Vector3i(0, -1, 0)))

	state = MoveCommand.new(1, Vector3i(4, 0, 0)).apply(state)
	var p: Unit = state.get_unit(1)
	assert_eq(p.pin, Unit.PinState.DUCKED, "reaction fire pins in own phase")
	assert_eq(p.ap, 0)
	assert_true(state.live_watch_for(2) == null or state.watches[0].spent)


func test_pin_cancels_live_watch() -> void:
	var state := _two_unit_fight()
	state.in_contact = true ## Watch needs phases (GDD §3.1)
	state = WatchCommand.new(1, Vector3i(1, 0, 0)).apply(state)
	assert_not_null(state.live_watch_for(1))
	state = state.end_phase()
	## Enemy shoots the player — opponent's phase hit cancels watch.
	state = ShootCommand.new(2, 1).apply(state)
	assert_eq(state.get_unit(1).pin, Unit.PinState.DUCKING_NEXT)
	assert_null(state.live_watch_for(1))
	assert_true((state.watches[0] as LiveWatch).spent)


func test_no_stunlock_second_pin_ignored() -> void:
	var state := _two_unit_fight(Taxonomy.WeaponClass.PISTOL, Taxonomy.WeaponClass.PISTOL)
	## First pistol hit from player → enemy DUCKING_NEXT, 1 hp
	state = ShootCommand.new(1, 2).apply(state)
	assert_eq(state.get_unit(2).pin, Unit.PinState.DUCKING_NEXT)
	## End to enemy phase (ducked), end to player again with pin cleared —
	## instead hit twice in one enemy phase while already ducked:
	state = state.end_phase()
	assert_eq(state.get_unit(2).pin, Unit.PinState.DUCKED)
	## Player can't shoot in enemy phase. Have enemy end and player shoot again
	## while... actually test apply_pin directly while already ducked:
	state = state.end_phase()
	state = ShootCommand.new(1, 2).apply(state) ## drops to bleeding
	assert_true(state.get_unit(2).bleeding)

	## Fresh fight: pin then pin again without dropping
	state = _two_unit_fight()
	var enemy: Unit = state.get_unit(2)
	enemy.hp = 2
	state.apply_pin(enemy)
	assert_eq(enemy.pin, Unit.PinState.DUCKING_NEXT)
	state.apply_pin(enemy)
	assert_eq(enemy.pin, Unit.PinState.DUCKING_NEXT, "still one pinned phase — no stunlock")
	assert_eq(enemy.hp, 2, "apply_pin alone does not damage")


func test_watch_is_refused_before_contact() -> void:
	## GDD §3.1: squad mode has no AP coin, no End Turn and no Watch. Phases start at contact.
	var state := _two_unit_fight()
	assert_false(state.in_contact, "precondition: nothing has started phases")
	var check := WatchCommand.new(1, Vector3i(1, 0, 0)).validate(state)
	assert_false(check.ok, "no Watch while walking")
	assert_true(check.reason.contains("contact"), "the refusal says why: %s" % check.reason)
	assert_eq(state.get_unit(1).ap, RulesConstants.AP_POOL, "validate spends nothing")
	assert_null(state.live_watch_for(1))
	state.in_contact = true
	assert_true(WatchCommand.new(1, Vector3i(1, 0, 0)).validate(state).ok, "same state, once phases have started")


func test_watch_one_shot_then_spent() -> void:
	var state := _two_unit_fight()
	state.in_contact = true ## Watch needs phases (GDD §3.1)
	state = WatchCommand.new(1, Vector3i(1, 0, 0)).apply(state)
	assert_false(WatchCommand.new(1, Vector3i(1, 0, 0)).validate(state).ok)
	assert_not_null(state.live_watch_for(1))


func test_trauma_kit_stops_bleed_clock() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	_air_corridor(map, 0, 2)
	var state := CombatState.new()
	state.map = map
	var medic := Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER)
	medic.has_trauma_kit = true
	var ally := Unit.new(2, Vector3i(1, 0, 0), Taxonomy.Faction.PLAYER)
	ally.bleeding = true
	ally.bleed_rounds_left = 3
	ally.hp = 0
	state.add_unit(medic)
	state.add_unit(ally)

	state = InteractCommand.new(1, Vector3i(1, 0, 0), InteractCommand.Kind.TRAUMA_KIT).apply(state)
	assert_true(state.get_unit(2).bleed_stabilized)
	assert_false(state.get_unit(1).has_trauma_kit)

	## Stabilized bleeder survives round ticks.
	state = state.end_phase().end_phase()
	state = state.end_phase().end_phase()
	state = state.end_phase().end_phase()
	assert_false(state.get_unit(2).dead)
	assert_true(state.get_unit(2).bleeding)


func test_bleed_out_kills_after_three_rounds() -> void:
	var state := _two_unit_fight(Taxonomy.WeaponClass.RIFLE)
	state = ShootCommand.new(1, 2).apply(state)
	assert_true(state.get_unit(2).bleeding)
	## Three full rounds (each = player end + enemy end).
	for _i in range(3):
		state = state.end_phase().end_phase()
	assert_true(state.get_unit(2).dead)


func test_throw_smoke_blocks_line() -> void:
	var state := _two_unit_fight()
	state = ThrowCommand.new(1, Vector3i(2, 0, 0), ThrowCommand.Kind.SMOKE).apply(state)
	assert_eq(state.map.get_cell(Vector3i(2, 0, 0)).material, Taxonomy.CoverMaterial.SMOKE)
	var shot := ShootCommand.new(1, 2).validate(state)
	assert_false(shot.ok)
	assert_eq(shot.reason, "no clean line")


func test_two_unit_exchange_through_commands() -> void:
	var state := _two_unit_fight(
		Taxonomy.WeaponClass.PISTOL, Taxonomy.WeaponClass.PISTOL
	)
	## Player advances and shoots.
	assert_true(MoveCommand.new(1, Vector3i(2, 0, 0)).validate(state).ok)
	state = MoveCommand.new(1, Vector3i(2, 0, 0)).apply(state)
	state = ShootCommand.new(1, 2).apply(state)
	assert_eq(state.get_unit(2).hp, 1)
	assert_eq(state.get_unit(2).pin, Unit.PinState.DUCKING_NEXT)

	state = state.end_phase()
	assert_eq(state.active_side, CombatState.PhaseSide.ENEMY)
	assert_eq(state.get_unit(2).pin, Unit.PinState.DUCKED)
	## Ducked enemy cannot shoot.
	assert_false(ShootCommand.new(2, 1).validate(state).ok)

	state = state.end_phase()
	assert_eq(state.active_side, CombatState.PhaseSide.PLAYER)
	assert_eq(state.get_unit(2).pin, Unit.PinState.NONE)
	state = ShootCommand.new(1, 2).apply(state)
	assert_true(state.get_unit(2).bleeding)
