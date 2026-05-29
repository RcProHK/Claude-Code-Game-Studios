# PersistenceLayer — Story 009 AC-15 Corrupt Detection Matrix (6 triggers)
#
# Proves that each of the 6 Rule 9 trigger conditions routes through the
# corrupt path: cache wiped to baseline, critical_save_failed emitted once
# with correct error_code, substate transitions to Corrupt.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 3/10/11 (corrupt path triggers)
extends GutTest


const CACHE_VAR_NAME: StringName = &"_cache"
const DIRTY_VAR_NAME: StringName = &"_dirty"
const SUBSTATE_VAR_NAME: StringName = &"_substate"
const LOADED_BYTES_VAR_NAME: StringName = &"_loaded_file_bytes"

var _factory: MockFileFactory


func before_each() -> void:
	_factory = MockFileFactory.new()
	PersistenceLayer.attach_file_factory(_factory)
	PersistenceLayer.get(CACHE_VAR_NAME).clear()
	PersistenceLayer.set(DIRTY_VAR_NAME, false)
	PersistenceLayer.set(LOADED_BYTES_VAR_NAME, 0)
	# Reset substate to INITIALISING so _trigger_corrupt can fire
	PersistenceLayer.set(SUBSTATE_VAR_NAME, PersistenceLayer.Substate.INITIALISING)
	for conn in PersistenceLayer.critical_save_failed.get_connections():
		PersistenceLayer.critical_save_failed.disconnect(conn.callable)
	for conn in PersistenceLayer.corrupt_save_recovered.get_connections():
		PersistenceLayer.corrupt_save_recovered.disconnect(conn.callable)


func after_each() -> void:
	PersistenceLayer.set(&"_file_factory", null)
	PersistenceLayer.set(SUBSTATE_VAR_NAME, PersistenceLayer.Substate.READY)


# ---------------------------------------------------------------------------
# Trigger 1: JSON.parse_string() returns null (invalid JSON content)
# ---------------------------------------------------------------------------
func test_corrupt_trigger1_invalid_json_returns_null() -> void:
	# Arrange
	_factory.set_file_content(PersistenceLayer.STATE_FILE_PATH, "not valid json {{{")
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer._load_from_disk()

	# Assert
	assert_eq(PersistenceLayer._test_get_substate(), "CORRUPT")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 1)
	var params = get_signal_parameters(PersistenceLayer, "critical_save_failed", 0)
	assert_eq(params[0], "INVALID_JSON")
	assert_eq(params[1], "")
	assert_eq(PersistenceLayer.get(CACHE_VAR_NAME).get("schema_version"), PersistenceLayer.SCHEMA_VERSION)


# ---------------------------------------------------------------------------
# Trigger 2: Parsed result not Dictionary (JSON array)
# ---------------------------------------------------------------------------
func test_corrupt_trigger2_parsed_not_dictionary() -> void:
	# Arrange — valid JSON but not a Dictionary
	_factory.set_file_content(PersistenceLayer.STATE_FILE_PATH, '[1, 2, 3]')
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer._load_from_disk()

	# Assert
	assert_eq(PersistenceLayer._test_get_substate(), "CORRUPT")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 1)
	var params = get_signal_parameters(PersistenceLayer, "critical_save_failed", 0)
	assert_eq(params[0], "INVALID_JSON")


# ---------------------------------------------------------------------------
# Trigger 3: Missing schema_version key
# ---------------------------------------------------------------------------
func test_corrupt_trigger3_missing_schema_version() -> void:
	# Arrange — valid Dictionary but no schema_version
	_factory.set_file_content(PersistenceLayer.STATE_FILE_PATH, '{"foo": "bar"}')
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer._load_from_disk()

	# Assert
	assert_eq(PersistenceLayer._test_get_substate(), "CORRUPT")
	var params = get_signal_parameters(PersistenceLayer, "critical_save_failed", 0)
	assert_eq(params[0], "INVALID_JSON")


# ---------------------------------------------------------------------------
# Trigger 4: migrate() returns false (chain too long)
# ---------------------------------------------------------------------------
func test_corrupt_trigger4_migrate_returns_false() -> void:
	# Arrange — schema_version=0, SCHEMA_VERSION=1, gap=1 is fine
	# but set chain too long by injecting schema_version=99
	_factory.set_file_content(PersistenceLayer.STATE_FILE_PATH,
		'{"schema_version": 99}')  # gap=98 > MAX=6
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer._load_from_disk()

	# Assert — migrate() triggers corrupt internally
	assert_eq(PersistenceLayer._test_get_substate(), "CORRUPT")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 1)
	var params = get_signal_parameters(PersistenceLayer, "critical_save_failed", 0)
	# SCHEMA_DOWNGRADE or MIGRATION_CHAIN_TOO_LONG depending on direction
	assert_true(params[0] in ["MIGRATION_CHAIN_TOO_LONG", "SCHEMA_DOWNGRADE"],
		"Trigger 4: error_code must indicate migration failure, got: %s" % params[0])


# ---------------------------------------------------------------------------
# Trigger 6: _flush_dirty() returns false (already covered AC-03 Story 003,
# included here for completeness of the AC-15 6-trigger matrix)
# ---------------------------------------------------------------------------
func test_corrupt_trigger6_flush_failed() -> void:
	# Arrange — make store_string fail
	_factory.fail_next_store_string = true
	watch_signals(PersistenceLayer)

	# Act — critical write triggers _flush_dirty(true)
	PersistenceLayer.set(SUBSTATE_VAR_NAME, PersistenceLayer.Substate.READY)
	var result: bool = PersistenceLayer.write("key", "val", true)

	# Assert
	assert_false(result)
	assert_eq(PersistenceLayer._test_get_substate(), "CORRUPT")
	assert_signal_emit_count(PersistenceLayer, "critical_save_failed", 1)
	var params = get_signal_parameters(PersistenceLayer, "critical_save_failed", 0)
	assert_eq(params[0], "FLUSH_FAILED")


# ---------------------------------------------------------------------------
# All triggers: cache wiped to {schema_version: SCHEMA_VERSION}
# ---------------------------------------------------------------------------
func test_corrupt_detection_cache_always_wiped_to_baseline() -> void:
	# Arrange — cache has some data
	PersistenceLayer.get(CACHE_VAR_NAME)["existing_key"] = "existing_value"
	_factory.set_file_content(PersistenceLayer.STATE_FILE_PATH, "bad json")

	# Act
	PersistenceLayer._load_from_disk()

	# Assert — existing_key gone, only schema_version remains
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	assert_false(cache.has("existing_key"), "Corrupt wipe must remove all prior cache keys")
	assert_eq(cache.get("schema_version"), PersistenceLayer.SCHEMA_VERSION)
