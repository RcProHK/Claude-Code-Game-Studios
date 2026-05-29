# PersistenceLayer — Story 010 AC-25 Initialising → Migrating → Ready
#
# Proves that when the on-disk schema_version is older than SCHEMA_VERSION,
# _ready() enters Migrating during the migration chain and then transitions
# to Ready on success. Also verifies that read() calls during Migrating
# emit critical_save_failed("MIGRATION_IN_PROGRESS").
#
# Framework: GUT (Godot Unit Testing) v7.x
extends GutTest


var _factory: MockFileFactory


func before_each() -> void:
	_factory = MockFileFactory.new()
	PersistenceLayer.attach_file_factory(_factory)
	PersistenceLayer.get(&"_cache").clear()
	PersistenceLayer.set(&"_loaded_file_bytes", 0)
	PersistenceLayer._test_force_substate(&"INITIALISING")
	for conn in PersistenceLayer.critical_save_failed.get_connections():
		PersistenceLayer.critical_save_failed.disconnect(conn.callable)
	for conn in PersistenceLayer.migration_step_completed.get_connections():
		PersistenceLayer.migration_step_completed.disconnect(conn.callable)


func after_each() -> void:
	PersistenceLayer.set(&"_file_factory", null)
	PersistenceLayer._test_force_substate(&"READY")


## AC-25: schema mismatch → migration runs → substate ends at Ready.
func test_substate_migrating_to_ready_after_schema_upgrade() -> void:
	# Arrange — on-disk schema is 0, target is SCHEMA_VERSION (1)
	# The 1-step migration completes in <<150ms → success
	_factory.set_file_content(
		PersistenceLayer.STATE_FILE_PATH,
		'{"schema_version": 0}'
	)
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer._load_from_disk()
	if PersistenceLayer._test_get_substate() == "INITIALISING":
		PersistenceLayer._test_force_substate(&"READY")

	# Assert — ended at READY after migration
	assert_eq(PersistenceLayer._test_get_substate(), "READY",
		"Successful migration must end in READY")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 0,
		"Successful migration: no corrupt signals")
	assert_signal_emit_count(PersistenceLayer, "migration_step_completed", 1,
		"1-step migration must emit migration_step_completed once")


## AC-25 extension: read() in Migrating emits MIGRATION_IN_PROGRESS.
func test_read_during_migrating_emits_migration_in_progress() -> void:
	# Arrange — force Migrating state directly
	PersistenceLayer._test_force_substate(&"MIGRATING")
	watch_signals(PersistenceLayer)

	# Act
	var result: Variant = PersistenceLayer.read("foo")

	# Assert
	assert_null(result, "read() in Migrating must return null")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 1)
	var p = get_signal_parameters(PersistenceLayer, "critical_save_failed", 0)
	assert_eq(p[0], "MIGRATION_IN_PROGRESS")
	assert_eq(p[1], "foo")


## Additional: migrate(0,1) sets Migrating during chain + clears to Ready.
func test_migrate_sets_migrating_substate_then_clears_to_ready() -> void:
	# Arrange — capture substate mid-migration. Array-wrapped: GDScript lambdas
	# capture scalars by value, so a plain String local would never update.
	var substate_during_migration: Array = [""]
	PersistenceLayer.migration_step_completed.connect(
		func(_f, _t, _ms) -> void:
			substate_during_migration[0] = PersistenceLayer._test_get_substate()
	)
	PersistenceLayer._test_force_substate(&"READY")

	# Act
	PersistenceLayer.migrate(0, 1)

	# Assert
	assert_eq(substate_during_migration[0], "MIGRATING",
		"Substate must be MIGRATING while migration_step_completed fires")
	assert_eq(PersistenceLayer._test_get_substate(), "READY",
		"Substate must return to READY after successful migrate()")
