class_name LiveWatch
extends RefCounted
## A loaded Watch cone (GDD §5.2). Spent watches are removed or flagged spent.

var unit_id: int = -1
var facing: Vector3i = Vector3i(1, 0, 0)
var spent: bool = false


func _init(
	p_unit_id: int = -1,
	p_facing: Vector3i = Vector3i(1, 0, 0),
	p_spent: bool = false,
) -> void:
	unit_id = p_unit_id
	facing = p_facing
	spent = p_spent
