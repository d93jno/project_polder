class_name EndDayCommand
extends TableCommand
## Day end: one explicit commit (plan 07, UI §8). Posts the pumps the hands and scrap reach, spends
## that scrap, ticks the basin, and opens the next morning with what moved. Never an End Turn with
## nothing decided: it is a Confirmed action, and a day with no decision should have been a deploy.


func validate(campaign: Campaign) -> CommandResult:
	if campaign.basin == null:
		return CommandResult.failure("there is no basin to tick")
	if not campaign.deployment.is_empty():
		return CommandResult.failure("the fireteam is still out")
	return CommandResult.success()


func needs_confirm(_campaign: Campaign) -> bool:
	return true


func _apply(next: Campaign) -> Campaign:
	next.close_day()
	return next
