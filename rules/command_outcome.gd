class_name CommandOutcome
extends RefCounted
## State after a command, plus what it revealed (plan 04 §4.5).


var state: CombatState = null
var reveal: RevealResult = null


static func of(p_state: CombatState, p_reveal: RevealResult = null) -> CommandOutcome:
	var o := CommandOutcome.new()
	o.state = p_state
	o.reveal = p_reveal if p_reveal != null else RevealResult.empty()
	return o
