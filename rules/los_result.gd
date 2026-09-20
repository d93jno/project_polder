class_name LosResult
extends RefCounted
## Outcome of a line-of-sight query. Blocker fields are meaningful when clean is false.

var clean: bool = true
var blocker: Taxonomy.CoverMaterial = Taxonomy.CoverMaterial.AIR
var blocker_cell: Vector3i = Vector3i.ZERO


static func ok() -> LosResult:
	return LosResult.new()


static func blocked(material: Taxonomy.CoverMaterial, cell: Vector3i) -> LosResult:
	var r := LosResult.new()
	r.clean = false
	r.blocker = material
	r.blocker_cell = cell
	return r
