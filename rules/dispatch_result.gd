class_name DispatchResult
extends RefCounted
## What came home from a fight (plan 07 §7.3): who, and what the water was left at. A value the campaign
## applies. Not the same thing as `CombatState.FightOutcome`, which only says how a fight ended.

var bowl_id: String = ""
var ended: CombatState.FightOutcome = CombatState.FightOutcome.ONGOING
var survivors: Array[int] = []
## Everyone deployed who is not home: dead, or left behind. A bleeder left behind is lost until the
## MEDEVAC rules exist (GDD 1.11), which is a slice of its own.
var lost: Array[int] = []
var water_after: Taxonomy.WaterStep = Taxonomy.WaterStep.FLOODED


static func from_fight(fight: CombatState, p_bowl_id: String, deployed: Array[int]) -> DispatchResult:
	var result := DispatchResult.new()
	result.bowl_id = p_bowl_id
	result.ended = fight.outcome()
	result.water_after = fight.map.water_step
	for id in deployed:
		var unit: Unit = fight.get_unit(id)
		if unit != null and unit.extracted:
			result.survivors.append(id)
		else:
			result.lost.append(id)
	return result
