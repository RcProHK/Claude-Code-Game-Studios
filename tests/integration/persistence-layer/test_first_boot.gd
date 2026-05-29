# PersistenceLayer — Story 013 AC-26/26b First-Boot Edge Case Tests
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


func after_each() -> void:
	PersistenceLayer.set(&"_file_factory", null)
	PersistenceLayer._test_force_substate(&"READY")


## AC-26: first boot (no file) → cache has schema_version; no critical_save_failed.
func test_first_boot_no_file_initialises_cache_with_schema_version() -> void:
	# Arrange — factory has empty virtual filesystem (no file)
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer._load_from_disk()

	# Assert
	var cache: Dictionary = PersistenceLayer.get(&"_cache")
	assert_eq(cache.get("schema_version"), PersistenceLayer.SCHEMA_VERSION,
		"First boot cache must contain schema_version baseline")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 0,
		"First boot must NOT trigger corrupt path")


## AC-26b: first boot cache contains ONLY schema_version (nothing else).
func test_first_boot_cache_contains_only_schema_version() -> void:
	# Arrange — ensure cache was empty before
	PersistenceLayer.get(&"_cache").clear()

	# Act
	PersistenceLayer._load_from_disk()

	# Assert
	var cache: Dictionary = PersistenceLayer.get(&"_cache")
	assert_eq(cache.size(), 1,
		"First boot cache must contain exactly 1 key (schema_version)")
	assert_true(cache.has("schema_version"),
		"First boot cache must contain schema_version key")


## Additional: first boot with existing dirty cache → overwritten with clean baseline
func test_first_boot_overwrites_dirty_cache_with_clean_baseline() -> void:
	# Arrange — pollute cache before first boot
	PersistenceLayer.get(&"_cache")["stale_key"] = "stale_value"

	# Act — no file → should reinitialise
	PersistenceLayer._load_from_disk()

	# Assert — stale_key gone
	var cache: Dictionary = PersistenceLayer.get(&"_cache")
	assert_false(cache.has("stale_key"), "First boot must clear stale cache entries")
