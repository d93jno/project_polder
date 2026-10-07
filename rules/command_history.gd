class_name CommandHistory
extends RefCounted
## The player's undo stack (UI §5, plan 05 §5.1). Undo is "hold the previous state", never an inverse
## command: a second implementation of every rule is what this avoids.
##
## Only a run of unrevealing moves stays on the stack. Anything that revealed, acted or confirmed
## stands, and clears what is behind it: undoing past it would let the player replan with information
## they were not owed. A phase ending clears it too, and the history is the player's own phase only.

## States before each reversible command, oldest first. Each is a private copy.
var _before: Array[CombatState] = []


## Note that `command` was applied to `state_before` with `outcome`. Returns its tier.
func record(command: Command, state_before: CombatState, outcome: CommandOutcome) -> CommitPolicy.Tier:
	var tier := CommitPolicy.tier_of(command, state_before, outcome)
	if CommitPolicy.is_undoable(tier):
		## A copy, so nothing the caller does to its own state afterwards can reach the history.
		_before.append(state_before.duplicate_state())
	else:
		clear()
	return tier


func can_undo() -> bool:
	return not _before.is_empty()


## How many reversible commands in a row can be taken back.
func depth() -> int:
	return _before.size()


## The state before the last reversible command, or null when there is none.
func undo() -> CombatState:
	if _before.is_empty():
		return null
	return _before.pop_back()


## A phase ended, a reveal stood, or the fight restarted.
func clear() -> void:
	_before.clear()
