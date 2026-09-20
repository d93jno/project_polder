extends GutTest

## Unit data the break rule reads, and the copy discipline that keeps it honest (plan §1.5.1).
## Movement.path builds a probe per tile with duplicate_at() for exposure_per_cell, so a field
## that fails to copy makes every per-tile break read silently wrong.


func _script_var_names(obj: Object) -> Array[String]:
	var names: Array[String] = []
	for prop in obj.get_property_list():
		if (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			names.append(prop["name"])
	return names


## A value guaranteed different from `v`, for the types Unit uses.
func _mutated(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT:
			return (v as int) + 2
		TYPE_BOOL:
			return not (v as bool)
		TYPE_VECTOR3I:
			return (v as Vector3i) + Vector3i(3, 4, 5)
		_:
			fail_test("Unit gained a field of type %s; teach _mutated() about it" % typeof(v))
			return v


func _fully_mutated_unit() -> Unit:
	var u := Unit.new()
	for name in _script_var_names(u):
		u.set(name, _mutated(u.get(name)))
	return u


func test_defaults_are_the_honest_p0_values() -> void:
	var u := Unit.new()
	assert_false(u.adapted, "P0's cast is unadapted: basin folk against Drifters")
	assert_eq(u.scars, 0)
	assert_false(u.broken)
	assert_false(u.is_founder)


func test_mutation_actually_changes_every_field() -> void:
	## Guards the two tests below against passing vacuously.
	var base := Unit.new()
	var u := _fully_mutated_unit()
	var names := _script_var_names(u)
	assert_gt(names.size(), 15, "Unit exposes its fields to the property list")
	for name in names:
		assert_ne(u.get(name), base.get(name), "'%s' was mutated" % name)


func test_duplicate_unit_copies_every_field() -> void:
	var u := _fully_mutated_unit()
	var copy := u.duplicate_unit()
	for name in _script_var_names(u):
		assert_eq(copy.get(name), u.get(name), "duplicate_unit dropped '%s'" % name)


func test_duplicate_at_keeps_every_field_and_changes_only_the_cell() -> void:
	var u := _fully_mutated_unit()
	var to := Vector3i(-7, 8, 9)
	var probe := u.duplicate_at(to)
	assert_eq(probe.cell, to)
	for name in _script_var_names(u):
		if name == "cell":
			continue
		assert_eq(probe.get(name), u.get(name), "duplicate_at dropped '%s'" % name)
	assert_ne(u.cell, to, "the original did not move")


func test_duplicate_is_independent_of_the_original() -> void:
	var u := Unit.new(1)
	var copy := u.duplicate_unit()
	copy.broken = true
	copy.give_scar(Taxonomy.Scar.AGORAPHOBIA)
	assert_false(u.broken)
	assert_false(u.has_scar(Taxonomy.Scar.AGORAPHOBIA))


func test_duplicate_state_carries_the_new_fields() -> void:
	var state := CombatState.new()
	var u := Unit.new(4, Vector3i.ZERO, Taxonomy.Faction.PLAYER)
	u.is_founder = true
	u.adapted = true
	u.broken = true
	u.give_scar(Taxonomy.Scar.LUNG_DAMAGE)
	state.add_unit(u)
	var copy := state.duplicate_state().get_unit(4)
	assert_true(copy.is_founder)
	assert_true(copy.adapted)
	assert_true(copy.broken)
	assert_true(copy.has_scar(Taxonomy.Scar.LUNG_DAMAGE))


func test_scars_are_independent_bits() -> void:
	var u := Unit.new()
	assert_false(u.has_scar(Taxonomy.Scar.AGORAPHOBIA))
	u.give_scar(Taxonomy.Scar.AGORAPHOBIA)
	assert_true(u.has_scar(Taxonomy.Scar.AGORAPHOBIA))
	assert_false(u.has_scar(Taxonomy.Scar.LUNG_DAMAGE), "giving one scar does not give the other")
	u.give_scar(Taxonomy.Scar.LUNG_DAMAGE)
	assert_true(u.has_scar(Taxonomy.Scar.AGORAPHOBIA) and u.has_scar(Taxonomy.Scar.LUNG_DAMAGE))
	assert_ne(Taxonomy.Scar.AGORAPHOBIA, Taxonomy.Scar.LUNG_DAMAGE)


func test_call_radius_is_a_positive_working_default() -> void:
	assert_gt(RulesConstants.CALL_RADIUS, 0)
