extends GutTest

# Phase 1.0 smoke test — proves make test runs headless and reports results.
func test_harness_is_alive() -> void:
	assert_eq(1 + 1, 2, "GUT harness should run headless assertions")
