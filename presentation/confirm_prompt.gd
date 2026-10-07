extends RefCounted
## One confirm for every Confirmed-tier action (UI §5, plan 05 §5.3). Preloaded, not class_named.
##
## `Command.needs_confirm(state)` says *which* actions confirm; this only holds the arming. The first
## press arms it and the HUD states the cost; a second press on the same action commits; Esc, or
## moving the hover off the target, disarms it. The text names a cost, never a probability (UI §1).

var _key: String = ""
var _anchor: Vector3i = Vector3i.ZERO


func is_armed() -> bool:
	return not _key.is_empty()


## Returns true when this press commits: the same action, already armed. Otherwise arms it and
## returns false. `anchor` is the cell the player is pointing at; moving off it disarms.
func press(command: Command, anchor: Vector3i) -> bool:
	var key := key_of(command)
	if key == _key:
		cancel()
		return true
	_key = key
	_anchor = anchor
	return false


func cancel() -> void:
	_key = ""


## The pointer moved. Disarm unless it is still on the cell that armed the action.
func hover_moved(cell: Vector3i) -> void:
	if is_armed() and cell != _anchor:
		cancel()


## What the HUD says while armed: what it does, what it costs, how to go on.
static func text_for(command: Command, state: CombatState) -> String:
	return "confirm: %s, %d AP — click again · Esc cancels" % [
		_what(command, state), _cost_ap(command, state)
	]


static func key_of(command: Command) -> String:
	if command is ShootCommand:
		return "shoot:%d:%d" % [command.attacker_id, command.target_id]
	if command is InteractCommand:
		return "interact:%d:%d:%s" % [command.unit_id, command.kind, command.target_cell]
	if command is MachineCommand:
		return "machine:%d:%s:%s" % [command.unit_id, command.machine_cell, command.turn_on]
	return str(command.get_instance_id())


static func _what(command: Command, state: CombatState) -> String:
	if command is ShootCommand:
		return "kills a bleeder"
	if command is InteractCommand and command.kind == InteractCommand.Kind.TRAUMA_KIT:
		return "uses the Trauma Kit and starts its MEDEVAC window"
	if command is MachineCommand and command.needs_confirm(state):
		return "opens the sluice, and the water rises from %s to %s" % [
			_step_word(state.map.water_step), _step_word(command.water_step_after(state))
		]
	return "cannot be taken back"


static func _cost_ap(command: Command, state: CombatState) -> int:
	if command is ShootCommand:
		var attacker: Unit = state.get_unit(command.attacker_id)
		return RulesConstants.shot_cost(attacker.weapon) if attacker != null else 0
	if command is InteractCommand or command is MachineCommand:
		return RulesConstants.INTERACT_COST
	return 0


static func _step_word(step: Taxonomy.WaterStep) -> String:
	return str(Taxonomy.WaterStep.keys()[step]).to_lower()
