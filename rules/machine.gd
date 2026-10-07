class_name Machine
extends RefCounted
## A machine on a bowl (plan 06 §6.0): a hatch, a pump house or a sluice. Where it stands is authored
## data on the bowl; whether it is on is fight state, held in `CombatState.machines` and copied with it.
## The same split as `Cell.occupant` (truth) and fog (knowledge), so a command result stays branchable.

enum Kind {
	HATCH, ## A vertical connector. Open carries the climb; closed does not (plan 06 §6.0).
	PUMP, ## Flippable state only; its effect on water is table mode's (plan 06 §7.4)
	SLUICE, ## Opening steps the bowl's water one wetter. One way within a fight (plan 06 §7.3)
}

var cell: Vector3i
var kind: Kind
## Hatch: open. Pump: running. Sluice: open.
var on: bool = false


func _init(p_cell: Vector3i = Vector3i.ZERO, p_kind: Kind = Kind.HATCH, p_on: bool = false) -> void:
	cell = p_cell
	kind = p_kind
	on = p_on


func duplicate_machine() -> Machine:
	return Machine.new(cell, kind, on)
