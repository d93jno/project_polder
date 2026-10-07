class_name CommitPolicy
extends Object
## What stands and what the player can take back (UI §5, plan 05). Pure: reads a command, the state it
## was applied to and its outcome, and names the tier. Nothing here mutates, and the view decides nothing.
##
## FREE has no value to compute: camera, cutaway, hover, selection and path planning are never commands.

enum Tier {
	FREE, ## Costs nothing, commits nothing. Never returned by `tier_of`: only commands have a tier.
	REVERSIBLE, ## A command that revealed nothing: undoable.
	COMMITTED, ## It revealed something, or it was an act. Stands.
	CONFIRMED, ## Irreversible and ugly: asks once, stating the cost.
}


## `state` is the state the command was applied to, not the one it produced.
static func tier_of(command: Command, state: CombatState, outcome: CommandOutcome) -> Tier:
	if command.needs_confirm(state):
		return Tier.CONFIRMED
	if outcome.reveal.anything_revealed():
		return Tier.COMMITTED
	return Tier.REVERSIBLE


## Only a command that revealed nothing can be taken back. A confirmed one is irreversible by definition.
static func is_undoable(tier: Tier) -> bool:
	return tier == Tier.REVERSIBLE
