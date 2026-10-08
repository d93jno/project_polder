class_name EndDayCommand
extends TableCommand
## Day end: one explicit commit (plan 07, UI §8). Posts the pumps the hands and scrap reach, spends
## that scrap, ticks the basin, and opens the next morning with what moved. Never an End Turn with
## nothing decided: it is a Confirmed action, and a day with no decision should have been a deploy.


func validate(campaign: Campaign) -> CommandResult:
	if campaign.basin == null:
		return CommandResult.failure("there is no basin to tick")
	return CommandResult.success()


func needs_confirm(_campaign: Campaign) -> bool:
	return true


func _apply(next: Campaign) -> Campaign:
	var posted := next.posted_pumps()
	next.scrap -= posted.size() * Campaign.SCRAP_PER_POST
	var result := BasinDay.end(next.basin, posted)
	next.basin = result.basin
	next.morning = result
	next.day += 1
	next.assignments_today = 0
	next.dispatched_today = false
	return next
