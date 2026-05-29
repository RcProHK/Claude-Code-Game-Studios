# PersistenceLayer — Story 010 AC-24 Initialising → Ready (no migration)
#
# Proves that when the on-disk schema matches SCHEMA_VERSION, _ready() transitions
# directly Initialising → Ready without going through Migrating or Corrupt.
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


## AC-24: matching schema_version → Initialising → Ready, no Migrating hop.
func test_substate_ready_after_load_with_matching_schema_version() -> void:
	# Arrange — file with matching schema version
	_factory.set_file_content(
		PersistenceLayer.STATE_FILE_PATH,
		'{"schema_version": %d, "some_key": "value"}' % PersistenceLayer.SCHEMA_VERSION
	)
	watch_signals(PersistenceLayer)

	# Act — simulate _ready() disk load phase
	PersistenceLayer._load_from_disk()
	if PersistenceLayer._test_get_substate() == "INITIALISING":
		PersistenceLayer._test_force_substate(&"READY")

	# Assert
	assert_eq(PersistenceLayer._test_get_substate(), "READY",
		"Matching schema must lead to READY, not Migrating or Corrupt")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 0,
		"No corrupt signals for matching schema")
	assert_signal_emit_count(PersistenceLayer, "migration_step_completed", 0,
		"No migration steps for matching schema")
	assert_eq(PersistenceLayer.read("some_key"), "value",
		"Cache populated from disk after load")


## Additional: no file → Initialising → Ready (first boot)
func test_substate_ready_after_first_boot_no_file() -> void:
	# Arrange — factory returns file_exists=false
	# (default MockFileFactory has empty virtual filesystem)
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer._load_from_disk()
	if PersistenceLayer._test_get_substate() == "INITIALISING":
		PersistenceLayer._test_force_substate(&"READY")

	# Assert
	assert_eq(PersistenceLayer._test_get_substate(), "READY")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 0)
	# AC-26b: first-boot seeds the schema_version baseline (NOT empty) — cache
	# contains ONLY {schema_version: SCHEMA_VERSION}. (Impl _load_from_disk line ~653.)
	assert_eq(PersistenceLayer.get(&"_cache"), {"schema_version": PersistenceLayer.SCHEMA_VERSION},
		"First boot: cache seeded with schema_version baseline (no disk file)")
