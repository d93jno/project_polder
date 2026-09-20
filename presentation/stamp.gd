class_name Stamp
extends Resource
## Draw-table entry for a multi-cell (or connector) kit piece (plan 3.2).
## Cells stay the rules truth; a stamp never adds a rule — it only names the mesh.

@export var piece_id: String = ""
@export var origin: Vector3i = Vector3i.ZERO
@export var yaw: float = 0.0


func _init(
	p_piece_id: String = "",
	p_origin: Vector3i = Vector3i.ZERO,
	p_yaw: float = 0.0,
) -> void:
	piece_id = p_piece_id
	origin = p_origin
	yaw = p_yaw
