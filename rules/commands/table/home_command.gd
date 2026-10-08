class_name HomeCommand
extends TableCommand
## The fireteam comes home (plan 07 §7.3, §7.5; GDD §3.1: coming home is the switch). Applies what
## the finished fight left: the lost leave the bench and the pool before anything else, so the morning
## opens on the loss (decision 7.6); a sluice that was opened leaves the bowl a step wetter and held there;
## and the day closes, as a dispatch spends it (decision 7.4).

var fight: CombatState


func _init(p_fight: CombatState = null) -> void:
	fight = p_fight


func validate(campaign: Campaign) -> CommandResult:
	if campaign.deployment.is_empty():
		return CommandResult.failure("nobody is out")
	if fight == null or fight.outcome() == CombatState.FightOutcome.ONGOING:
		return CommandResult.failure("the fight is not over")
	return CommandResult.success()


func _apply(next: Campaign) -> Campaign:
	var bowl_id: String = next.deployment["bowl"]
	var deployed: Array[int] = []
	for id in next.deployment["ids"]:
		deployed.append(int(id))
	var result := DispatchResult.from_fight(fight, bowl_id, deployed)
	for id in result.lost:
		next.bench.erase(id)
		next.lose_person()
	var bowl: BasinBowl = next.basin.bowl(bowl_id)
	if result.water_after != bowl.step:
		bowl.step = result.water_after
		bowl.walk = BasinBowl.Walk.NONE
		bowl.walk_days_left = 0
		bowl.hang_days = BasinRules.REDIRECTION_HANG_DAYS
	next.deployment = {}
	next.close_day()
	return next
