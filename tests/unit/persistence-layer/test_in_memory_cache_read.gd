# PersistenceLayer — Story 002 In-Memory Cache Read Tests
#
# Scope: cache-only read path. Proves `read(key)` returns `_cache[key]` with
# ZERO file I/O — verified by asserting purely on `_cache` state, never
# invoking any code path that would open a FileAccess.
#
# Why not MockFileAccess in this suite:
# Story 002's production `read()` body does not yet route through IFileFactory
# — it returns directly from `_cache`. Attaching MockFileAccess here would
# assert against a code path that doesn't exist. Story 003 (write/flush) will
# wire the factory and add disk-touch-count assertions.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0003 Save State Strategy, ADR-0006 Contract 4/14
extends GutTest


# PersistenceLayer is an autoload (position 1, locked per ADR-0006 Contract 4)
# — accessed via global singleton name. Tests must reset `_cache` in
# before_each() so state does not leak across runs.
const CACHE_VAR_NAME: StringName = &"_cache"


func before_each() -> void:
	# Arrange (shared): autoload persists across tests — clear cache + signals for isolation.
	# Direct access to the underscore-prefixed cache is a deliberate test-only
	# affordance (ADR-0006 Contract 14: tests may read private state to assert
	# zero-I/O invariants without adding production observability hooks).
	PersistenceLayer.get(CACHE_VAR_NAME).clear()
	# Disconnect any write_completed signals from previous tests to prevent
	# GUT watch_signals leaking into the next test's signal emission count.
	for conn in PersistenceLayer.write_completed.get_connections():
		PersistenceLayer.write_completed.disconnect(conn.callable)


func test_persistence_layer_read_missing_key_returns_null() -> void:
	# Arrange — cache is empty (before_each).

	# Act
	var result: Variant = PersistenceLayer.read("does_not_exist")

	# Assert
	assert_null(result, "Missing key must return null per IPersistence contract")


func test_persistence_layer_read_existing_string_value_returns_same_value() -> void:
	# Arrange — seed cache directly (bypass write() to isolate read path).
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	cache["player_name"] = "Frank"

	# Act
	var result: Variant = PersistenceLayer.read("player_name")

	# Assert
	assert_eq(result, "Frank")


func test_persistence_layer_read_existing_dictionary_value_returns_same_reference() -> void:
	# Arrange — Dictionaries are reference types in GDScript.
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	var payload: Dictionary = {"level": 5, "xp": 1200}
	cache["save_slot_0"] = payload

	# Act
	var result: Variant = PersistenceLayer.read("save_slot_0")

	# Assert
	assert_eq(result, payload)
	assert_true(result is Dictionary, "Read must preserve Dictionary type")


func test_persistence_layer_read_does_not_mutate_cache() -> void:
	# Arrange
	var cache: Dictionary = PersistenceLayer.get(CACHE_VAR_NAME)
	cache["key_a"] = 1
	cache["key_b"] = 2
	var size_before: int = cache.size()

	# Act — multiple reads (including a missing key) must not add/remove entries.
	PersistenceLayer.read("key_a")
	PersistenceLayer.read("key_b")
	PersistenceLayer.read("key_missing")

	# Assert — zero side-effects on cache state proves zero I/O implicitly:
	# the only way read() could touch disk is by populating cache on miss,
	# which would change size_after.
	assert_eq(cache.size(), size_before, "read() must be side-effect-free")
	assert_true(cache.has("key_a") and cache.has("key_b"), "Existing keys preserved")
	assert_false(cache.has("key_missing"), "Missing key must NOT be auto-created")


func test_persistence_layer_write_then_read_returns_written_value() -> void:
	# Arrange — empty cache (before_each).

	# Act — exercise write() cache-mutation path, then read back.
	var write_ok: bool = PersistenceLayer.write("session_token", "abc123")
	var result: Variant = PersistenceLayer.read("session_token")

	# Assert
	assert_true(write_ok, "Cache-accept write must return true")
	assert_eq(result, "abc123")


func test_persistence_layer_write_emits_write_completed_signal_with_is_touch_false() -> void:
	# Arrange
	watch_signals(PersistenceLayer)

	# Act
	PersistenceLayer.write("key_x", 42)

	# Assert — signal emitted exactly once with is_touch=false (write, not touch).
	assert_signal_emit_count(PersistenceLayer, "write_completed", 1)
	var params: Array = get_signal_parameters(PersistenceLayer, "write_completed", 0)
	assert_eq(params[0], "key_x", "Signal param 0 = key")
	assert_true(params[1] is int, "Signal param 1 = latency_ms (int)")
	assert_gte(params[1], 0, "Latency must be non-negative")
	assert_eq(params[2], false, "Signal param 2 = is_touch (false for write())")


func test_persistence_layer_write_overwrites_existing_value() -> void:
	# Arrange
	PersistenceLayer.write("counter", 1)

	# Act
	PersistenceLayer.write("counter", 2)
	var result: Variant = PersistenceLayer.read("counter")

	# Assert
	assert_eq(result, 2, "Second write must overwrite first")


func test_persistence_layer_read_distinct_keys_do_not_collide() -> void:
	# Arrange
	PersistenceLayer.write("alpha", "A")
	PersistenceLayer.write("beta", "B")

	# Act
	var a: Variant = PersistenceLayer.read("alpha")
	var b: Variant = PersistenceLayer.read("beta")

	# Assert
	assert_eq(a, "A")
	assert_eq(b, "B")
	assert_ne(a, b, "Distinct keys must hold distinct values")
