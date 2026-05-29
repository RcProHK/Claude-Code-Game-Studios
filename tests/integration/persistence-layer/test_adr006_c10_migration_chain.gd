# ADR-006 Contract 10 binding — migration chain bounded (≤6 steps × 150ms)
# Gate: Story 015 AC-32
extends GutTest

func before_each() -> void:
	PersistenceLayer.get(&"_cache").clear()
	PersistenceLayer._test_force_substate(&"READY")

func after_each() -> void:
	PersistenceLayer._test_force_substate(&"READY")

func test_adr006_c10_max_chain_constant_is_6() -> void:
	assert_eq(PersistenceLayer.MAX_MIGRATION_CHAIN_LENGTH, 6,
		"ADR-006 Contract 10: MAX_MIGRATION_CHAIN_LENGTH must be 6")

func test_adr006_c10_budget_constant_is_150ms() -> void:
	assert_eq(PersistenceLayer.MIGRATION_BUDGET_MS, 150,
		"ADR-006 Contract 10: MIGRATION_BUDGET_MS must be 150")

func test_adr006_c10_chain_too_long_fails_fast() -> void:
	for conn in PersistenceLayer.critical_save_failed.get_connections():
		PersistenceLayer.critical_save_failed.disconnect(conn.callable)
	PersistenceLayer._test_force_substate(&"INITIALISING")
	watch_signals(PersistenceLayer)

	PersistenceLayer.migrate(0, 7)  # gap=7 > MAX=6 → fail-fast

	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 1)
	assert_signal_emit_count(PersistenceLayer, "migration_step_completed", 0)
