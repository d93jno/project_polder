class_name Comms
extends Object
## Who shares knowledge with whom. One predicate — earshot now, radios later (plan 04 §7.3).
## Sound is not sight: walls do not dampen. Symmetric.


static func shares(state: CombatState, a: Unit, b: Unit) -> bool:
	if a == null or b == null:
		return false
	if a.id == b.id:
		return false
	if a.faction != b.faction:
		return false
	if not a.is_active() or not b.is_active():
		return false
	## Radios later: a Unit flag widens this check and nothing else changes.
	return _chebyshev(a.cell, b.cell) <= RulesConstants.EARSHOT_RADIUS


static func _chebyshev(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), maxi(absi(a.y - b.y), absi(a.z - b.z)))
