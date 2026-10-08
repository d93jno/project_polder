class_name TableCommand
extends RefCounted
## A table action (plan 07). The same shape as the tactical `Command`: `validate` never mutates and
## returns a `CommandResult`; `apply` returns a new `Campaign` and leaves its input alone.


func validate(_campaign: Campaign) -> CommandResult:
	return CommandResult.failure("not implemented")


func apply(campaign: Campaign) -> Campaign:
	var check := validate(campaign)
	if not check.ok:
		push_error("TableCommand.apply on invalid command: %s" % check.reason)
		return campaign.duplicate_campaign()
	return _apply(campaign.duplicate_campaign())


## Irreversible: the player confirms once, with the cost stated (UI §5, plan 05).
func needs_confirm(_campaign: Campaign) -> bool:
	return false


func _apply(next: Campaign) -> Campaign:
	return next
