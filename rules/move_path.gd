class_name MovePath
extends RefCounted
## Annotated path for the move preview (UI §4.1, §4.2).

var cells: Array[Vector3i] = []
var cost_per_cell: Array[int] = []
var exposure_per_cell: Array = [] ## Exposure
var watches_crossed: Array = [] ## WatchCrossing
## Last index where a shot is still affordable after arriving; -1 if never.
var shot_reserve_at: int = -1
## Last index where setting a Watch is still affordable after arriving; -1 if never.
var watch_reserve_at: int = -1
var reachable: bool = false
var total_cost: int = 0


func remaining_ap_at(unit_ap: int, index: int) -> int:
	var spent := 0
	for i in range(0, mini(index, cost_per_cell.size() - 1) + 1):
		spent += cost_per_cell[i]
	return unit_ap - spent
