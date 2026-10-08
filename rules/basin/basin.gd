class_name Basin
extends RefCounted
## The graph of bowls (plan 07 §7.0). Bowls keep an authored order, so a tick is deterministic whatever
## a dictionary does. `duplicate_basin` copies every bowl: a day returns a new basin and never edits one.

var bowls: Dictionary = {} ## String id -> BasinBowl
var order: Array[String] = []


func add_bowl(bowl: BasinBowl) -> BasinBowl:
	if not bowls.has(bowl.id):
		order.append(bowl.id)
	bowls[bowl.id] = bowl
	return bowl


func bowl(id: String) -> BasinBowl:
	return bowls.get(id)


func has_bowl(id: String) -> bool:
	return bowls.has(id)


func ids() -> Array[String]:
	return order.duplicate()


func duplicate_basin() -> Basin:
	var copy := Basin.new()
	for id in order:
		copy.add_bowl((bowls[id] as BasinBowl).duplicate_bowl())
	return copy
