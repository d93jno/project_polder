extends GutTest

## Dispatch and the way home (plan 07 §7.3): where the basin meets the tactical layer.

const Opening := preload("res://rules/fixtures/table_opening.gd")
const Ring := preload("res://rules/fixtures/basin_ring.gd")
const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")

const B := Campaign.Bucket


func _ids(list: Array) -> Array[int]:
	var out: Array[int] = []
	for id in list:
		out.append(int(id))
	return out


func _send(campaign: Campaign, bowl: String = Ring.TERRACE, who: Array = [1, 2, 3, 4]) -> Campaign:
	var cmd := DispatchCommand.new(bowl, _ids(who))
	assert_true(cmd.validate(campaign).ok, cmd.validate(campaign).reason)
	return cmd.apply(campaign)


func _extract(fight: CombatState, ids: Array) -> void:
	for id in ids:
		fight.get_unit(id).extracted = true


func _kill(fight: CombatState, ids: Array) -> void:
	for id in ids:
		fight.get_unit(id).dead = true
		fight.get_unit(id).hp = 0


func _home(campaign: Campaign, fight: CombatState) -> Campaign:
	var cmd := HomeCommand.new(fight)
	assert_true(cmd.validate(campaign).ok, cmd.validate(campaign).reason)
	return cmd.apply(campaign)


## --- Dispatch ---


func test_dispatch_says_why_it_refuses() -> void:
	var c := Opening.opening()
	assert_eq(DispatchCommand.new(Ring.SUMP, _ids([1])).validate(c).reason, "that bowl is unknown")
	assert_eq(DispatchCommand.new("nowhere", _ids([1])).validate(c).reason, "that bowl is unknown")
	assert_eq(DispatchCommand.new(Ring.RIDGE_W, _ids([1])).validate(c).reason, "no known map")
	assert_eq(DispatchCommand.new(Ring.TERRACE, _ids([])).validate(c).reason, "send at least one")
	assert_eq(DispatchCommand.new(Ring.TERRACE, _ids([1, 2, 3, 4, 5])).validate(c).reason, "no more than 4 go")
	assert_eq(DispatchCommand.new(Ring.TERRACE, _ids([1, 1])).validate(c).reason, "the same person twice")
	assert_eq(DispatchCommand.new(Ring.TERRACE, _ids([1, 9])).validate(c).reason, "9 is not on the bench")


func test_an_empty_bench_cannot_send_anyone() -> void:
	var c := Opening.opening()
	c.bench.clear()
	assert_eq(DispatchCommand.new(Ring.TERRACE, _ids([1])).validate(c).reason, "1 is not on the bench")


func test_a_dispatch_marks_them_out_and_the_day_has_its_one() -> void:
	var c := Opening.opening()
	var out := _send(c)
	assert_eq(out.deployment["bowl"], Ring.TERRACE)
	assert_true(out.dispatched_today)
	assert_true(c.deployment.is_empty(), "the campaign it came from is untouched")
	assert_eq(DispatchCommand.new(Ring.TERRACE, _ids([1])).validate(out).reason, "the fireteam is already out")


func test_the_day_cannot_end_while_the_fireteam_is_out() -> void:
	var out := _send(Opening.opening())
	assert_eq(EndDayCommand.new().validate(out).reason, "the fireteam is still out")


## --- The fight ---


func test_the_fight_is_the_same_opening_fight_view_loads_at_the_basins_water() -> void:
	var c := Opening.opening()
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]))
	var reference := FloodedTerrace.opening(c.basin.bowl(Ring.TERRACE).step)
	assert_eq(fight.units.keys().size(), reference.units.keys().size())
	for id in reference.units:
		assert_eq(fight.get_unit(id).cell, reference.get_unit(id).cell, "unit %d" % id)
	assert_eq(fight.machines.keys().size(), reference.machines.keys().size())
	assert_eq(fight.map.cells.size(), reference.map.cells.size())
	assert_eq(fight.map.water_step, reference.map.water_step)


func test_the_basins_water_reaches_the_fight_through_with_water() -> void:
	var c := Opening.opening()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.FALLING
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]))
	assert_eq(fight.map.water_step, Taxonomy.WaterStep.FALLING)
	assert_eq(c.basin.bowl(Ring.TERRACE).step, Taxonomy.WaterStep.FALLING, "the basin was only read")


func test_only_the_chosen_squad_is_seated() -> void:
	var fight := TableDispatch.build_fight(Opening.opening(), Ring.TERRACE, _ids([2, 4]))
	var players := fight.units_of_faction(Taxonomy.Faction.PLAYER)
	assert_eq(players.size(), 2)
	assert_not_null(fight.get_unit(2))
	assert_not_null(fight.get_unit(4))
	assert_null(fight.get_unit(1))
	assert_true(fight.units_of_faction(Taxonomy.Faction.DRIFTER).size() > 0, "the other side is still there")


func test_building_a_fight_never_changes_the_campaign_or_its_basin() -> void:
	var c := Opening.opening()
	var step := c.basin.bowl(Ring.TERRACE).step
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1]))
	fight.map = fight.map.with_water(Taxonomy.WaterStep.DRY, 0)
	assert_eq(c.basin.bowl(Ring.TERRACE).step, step)
	assert_eq(c.bench.size(), 4)


func test_nothing_in_the_tactical_rules_reads_the_basin_or_the_campaign() -> void:
	## One water, one combat model: the basin meets a fight only through `TableDispatch`.
	var allowed := [
		"res://rules/campaign.gd", "res://rules/table_dispatch.gd", "res://rules/dispatch_result.gd",
		"res://rules/campaign_codec.gd", "res://rules/campaign_save.gd",
	]
	var offenders: Array[String] = []
	for dir in ["res://rules", "res://rules/commands"]:
		for file in DirAccess.get_files_at(dir):
			var path: String = dir.path_join(file)
			if not path.ends_with(".gd") or path in allowed:
				continue
			for line in FileAccess.get_file_as_string(path).split("\n"):
				var code := line.split("#")[0] ## prose may say "campaign"; code may not name the table
				if code.contains("Campaign") or code.contains("BasinBowl") or code.contains("Basin."):
					offenders.append(path)
					break
	assert_eq(offenders, [] as Array[String], "tactical rules that know about the table: %s" % [offenders])


## --- The way home ---


func test_coming_home_needs_a_finished_fight_and_someone_out() -> void:
	var c := Opening.opening()
	assert_eq(HomeCommand.new(CombatState.new()).validate(c).reason, "nobody is out")
	var out := _send(c)
	var fight := TableDispatch.build_fight(out, Ring.TERRACE, _ids([1, 2, 3, 4]))
	assert_eq(HomeCommand.new(fight).validate(out).reason, "the fight is not over")


func test_the_lost_leave_the_bench_and_the_pool_and_the_morning_opens_on_it() -> void:
	var c := _send(Opening.opening())
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]))
	_extract(fight, [1, 2])
	_kill(fight, [3])
	## Unit 4 is left behind, bleeding on the roof: lost until the MEDEVAC rules exist.
	fight.get_unit(4).bleeding = true
	fight.get_unit(4).hp = 0
	var home := _home(c, fight)
	assert_eq(home.bench, _ids([1, 2]))
	assert_eq(home.people(), 8, "two people are gone from the camp")
	assert_true(home.deployment.is_empty())
	assert_eq(home.day, 2, "a dispatch spends the day")
	assert_not_null(home.morning)
	assert_eq(c.people(), 10, "the campaign it came from is untouched")


func test_the_loss_comes_from_the_roster_first_then_the_idle() -> void:
	var c := _send(Opening.opening()) ## one on the roster, four idle
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]))
	_kill(fight, [1, 2, 3])
	_extract(fight, [4])
	var home := _home(c, fight)
	assert_eq(home.hands(B.ROSTER), 0)
	assert_eq(home.hands(B.IDLE), 2, "the first from the roster, then two idle hands")
	assert_eq(home.people(), 7)


func test_a_wiped_squad_costs_every_body_sent() -> void:
	var c := _send(Opening.opening())
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]))
	_kill(fight, [1, 2, 3, 4])
	assert_eq(fight.outcome(), CombatState.FightOutcome.WIPED)
	var home := _home(c, fight)
	assert_true(home.bench.is_empty())
	assert_eq(home.people(), 6)


func test_the_fight_state_is_not_changed_by_coming_home() -> void:
	var c := _send(Opening.opening())
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]))
	_extract(fight, [1, 2, 3, 4])
	_home(c, fight)
	assert_true(fight.get_unit(1).extracted)
	assert_eq(fight.units.size() >= 4, true)


## --- A sluice opened in the fight ---


func _sluice_fight(campaign: Campaign) -> CombatState:
	var fight := TableDispatch.build_fight(campaign, Ring.TERRACE, _ids([1, 2, 3, 4]))
	fight.in_contact = true
	fight.active_side = CombatState.PhaseSide.PLAYER
	fight.get_unit(FloodedTerrace.P2).cell = FloodedTerrace.SLUICE + Vector3i(-1, 0, 0)
	return fight


func test_a_sluice_opened_in_the_fight_leaves_the_bowl_a_step_wetter_and_held() -> void:
	var c := Opening.opening()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.FALLING
	c = _send(c)
	var fight := _sluice_fight(c)
	var open := MachineCommand.new(FloodedTerrace.P2, FloodedTerrace.SLUICE)
	assert_true(open.validate(fight).ok, open.validate(fight).reason)
	fight = open.apply(fight)
	assert_eq(fight.map.water_step, Taxonomy.WaterStep.FLOODED)
	_extract(fight, [1, 2, 3, 4])
	var home := _home(c, fight)
	var terrace := home.basin.bowl(Ring.TERRACE)
	assert_eq(terrace.step, Taxonomy.WaterStep.FLOODED, "the redirection is the bowl's water now")
	assert_eq(terrace.hang_days, BasinRules.REDIRECTION_HANG_DAYS - 1, "held wet, and a day of it has gone")
	assert_eq(c.basin.bowl(Ring.TERRACE).step, Taxonomy.WaterStep.FALLING, "the campaign before it is unchanged")


func test_a_fight_that_changed_nothing_leaves_the_water_and_the_hang_alone() -> void:
	var c := _send(Opening.opening())
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]))
	_extract(fight, [1, 2, 3, 4])
	var home := _home(c, fight)
	assert_eq(home.basin.bowl(Ring.TERRACE).hang_days, 0)


func test_a_redirected_bowl_stays_wet_for_days_and_then_dries_again() -> void:
	var held := BasinBowl.new("held")
	var basin := Basin.new()
	for id in [Ring.RIDGE_W, Ring.RIDGE_N]:
		var ridge := BasinBowl.new(id)
		ridge.grade = BasinBowl.Grade.RIM
		ridge.step = Taxonomy.WaterStep.DRY
		basin.add_bowl(ridge)
	held = BasinBowl.new(Ring.TERRACE)
	held.step = Taxonomy.WaterStep.FLOODED
	held.feeders = [Ring.RIDGE_W, Ring.RIDGE_N] as Array[String]
	held.hang_days = BasinRules.REDIRECTION_HANG_DAYS
	basin.add_bowl(held)
	var posted := {Ring.TERRACE: true, Ring.RIDGE_W: true, Ring.RIDGE_N: true}
	for _day in BasinRules.REDIRECTION_HANG_DAYS:
		var result := BasinDay.end(basin, posted)
		basin = result.basin
		assert_eq(basin.bowl(Ring.TERRACE).walk, BasinBowl.Walk.NONE, "held: it does not even start walking")
	assert_eq(basin.bowl(Ring.TERRACE).hang_days, 0)
	basin = BasinDay.end(basin, posted).basin
	assert_eq(basin.bowl(Ring.TERRACE).walk, BasinBowl.Walk.DRIER, "the hang is over, and the water can walk back")


## --- Refusing the sluice (plan 08 §8.5) ---


func test_a_held_sluice_is_locked_and_refused_with_a_reason() -> void:
	var c := Opening.opening()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.FALLING
	var cmd := DispatchCommand.new(Ring.TERRACE, _ids([1, 2, 3, 4]), true)
	assert_true(cmd.validate(c).ok)
	c = cmd.apply(c)
	assert_true(bool(c.deployment.get("hold_sluice", false)))
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]), true)
	fight.in_contact = true
	fight.active_side = CombatState.PhaseSide.PLAYER
	fight.get_unit(FloodedTerrace.P2).cell = FloodedTerrace.SLUICE + Vector3i(-1, 0, 0)
	var open := MachineCommand.new(FloodedTerrace.P2, FloodedTerrace.SLUICE)
	var result := open.validate(fight)
	assert_false(result.ok)
	assert_eq(result.reason, "the sluice is held shut")


func test_holding_the_sluice_locks_only_sluices() -> void:
	var c := _send(Opening.opening())
	var held := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]), true)
	var free := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]))
	for m in held.machines.values():
		assert_eq(m.locked, m.kind == Machine.Kind.SLUICE)
	for m in free.machines.values():
		assert_false(m.locked)


func test_a_held_fight_brought_home_redirects_nothing() -> void:
	var c := Opening.opening()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.FALLING
	c = DispatchCommand.new(Ring.TERRACE, _ids([1, 2, 3, 4]), true).apply(c)
	var fight := TableDispatch.build_fight(c, Ring.TERRACE, _ids([1, 2, 3, 4]), true)
	_extract(fight, [1, 2, 3, 4])
	var home := _home(c, fight)
	assert_eq(home.basin.bowl(Ring.TERRACE).step, Taxonomy.WaterStep.FALLING)
	assert_eq(home.redirections.size(), 0)


## --- Fuel for the leg (plan 09 §9.2) ---

const Queries := preload("res://presentation/table_queries.gd")


func test_a_dispatch_spends_the_fuel_for_the_leg_there_and_back() -> void:
	var c := Opening.opening()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.MUD
	c.fuel = 5
	var sent := _send(c)
	assert_eq(sent.fuel, 1, "mud costs two each way")
	assert_eq(c.fuel, 5, "the campaign before it is unchanged")


func test_each_step_prices_the_leg_by_its_water() -> void:
	var c := Opening.opening()
	var cost := {}
	for step in [Taxonomy.WaterStep.FLOODED, Taxonomy.WaterStep.FALLING, Taxonomy.WaterStep.MUD, Taxonomy.WaterStep.DRY]:
		c.basin.bowl(Ring.TERRACE).step = step
		cost[step] = Economy.leg_cost(c, Ring.TERRACE)
	assert_eq(cost[Taxonomy.WaterStep.FLOODED], 2)
	assert_eq(cost[Taxonomy.WaterStep.MUD], 4)
	assert_eq(cost[Taxonomy.WaterStep.DRY], 0, "they walk")


func test_a_dispatch_the_fuel_cannot_cover_is_refused_with_a_reason() -> void:
	var c := Opening.opening()
	c.fuel = 1
	var cmd := DispatchCommand.new(Ring.TERRACE, _ids([1, 2, 3, 4]))
	var result := cmd.validate(c)
	assert_false(result.ok)
	assert_true(result.reason.contains("fuel"))
	assert_true(result.reason.contains("needs 2, have 1"))


func test_the_slot_says_the_leg_reaches_home_exactly_when_the_command_allows_it() -> void:
	for fuel in [0, 1, 2, 3, 4]:
		var c := Opening.opening()
		c.fuel = fuel
		var line := Queries.fuel_line(c, Ring.TERRACE)
		var allowed := DispatchCommand.new(Ring.TERRACE, _ids([1, 2, 3, 4])).validate(c).ok
		assert_eq(not line.contains("does not reach home"), allowed, "fuel %d: %s" % [fuel, line])


func test_a_dry_bowl_needs_no_fuel() -> void:
	var c := Opening.opening()
	c.basin.bowl(Ring.TERRACE).step = Taxonomy.WaterStep.DRY
	c.fuel = 0
	assert_true(DispatchCommand.new(Ring.TERRACE, _ids([1, 2, 3, 4])).validate(c).ok)
	assert_eq(Queries.fuel_line(c, Ring.TERRACE), "on foot: no fuel needed")
