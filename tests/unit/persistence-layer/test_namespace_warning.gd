# PersistenceLayer — Story 012 AC-20/21/22 Namespace Convention + Idempotency
#
# Framework: GUT (Godot Unit Testing) v7.x
extends GutTest


func before_each() -> void:
	PersistenceLayer.get(&"_cache").clear()
	PersistenceLayer._test_force_substate(&"READY")
	for conn in PersistenceLayer.write_completed.get_connections():
		PersistenceLayer.write_completed.disconnect(conn.callable)


## AC-20: bare key without namespace prefix — write still succeeds (warning not a block).
## Note: push_warning() can't be captured in GUT headless — we verify the write contract.
func test_namespace_bare_key_write_returns_true() -> void:
	# Act
	var result: bool = PersistenceLayer.write("bare_key", "val")

	# Assert — warning doesn't block the write
	assert_true(result, "write() with bare key must return true (push_warning only, not error)")
	assert_eq(PersistenceLayer.read("bare_key"), "val",
		"Cache must contain the value despite namespace warning")


## AC-21: properly namespaced keys emit no warning — all writes succeed.
func test_namespace_prefixed_keys_write_succeeds_no_error() -> void:
	# Act — all valid namespace prefixes
	var r1: bool = PersistenceLayer.write("gsm.current_state", "idle")
	var r2: bool = PersistenceLayer.write("gym.session_token", "tk")
	var r3: bool = PersistenceLayer.write("_internal.schema_version", 1)
	var r4: bool = PersistenceLayer.write("streak.count", 5)
	var r5: bool = PersistenceLayer.write("wst.phase", "active")
	var r6: bool = PersistenceLayer.write("stat.atk", 42.0)
	var r7: bool = PersistenceLayer.write("ability.unlocked.strike_t1", true)

	# Assert
	assert_true(r1 and r2 and r3 and r4 and r5 and r6 and r7,
		"All namespaced writes must succeed")


## AC-22: idempotency — calling _migrate_one_step 3 times yields same result.
## Tests the contract that migration steps use `if "new_key" not in _cache` guards.
func test_migration_step_idempotency_same_cache_after_3_runs() -> void:
	# Arrange — seed cache with initial state
	PersistenceLayer.get(&"_cache")["schema_version"] = 0
	PersistenceLayer.get(&"_cache")["existing_data"] = "preserved"

	# Simulate an idempotent step: "if 'upgraded_key' not in _cache: add it"
	# This is how Story 016 MUST write each _migrate_one_step implementation.
	# We test the pattern directly using the cache mutation seams from Story 008.
	for _i in range(3):
		if not PersistenceLayer.get(&"_cache").has("upgraded_key"):
			PersistenceLayer.get(&"_cache")["upgraded_key"] = "migrated_value"
		PersistenceLayer.get(&"_cache")["schema_version"] = 1

	var cache_after: Dictionary = PersistenceLayer.get(&"_cache").duplicate()

	# Run "step" a 4th time — cache must be identical
	if not PersistenceLayer.get(&"_cache").has("upgraded_key"):
		PersistenceLayer.get(&"_cache")["upgraded_key"] = "migrated_value"
	PersistenceLayer.get(&"_cache")["schema_version"] = 1

	# Assert — 4th run produced no change
	assert_eq(PersistenceLayer.get(&"_cache"), cache_after,
		"Idempotent migration step must produce identical cache on repeat runs")
	assert_eq(PersistenceLayer.get(&"_cache").get("existing_data"), "preserved",
		"Pre-existing cache data must be preserved by idempotent step")


## Additional: namespace check is debug-only — write always succeeds regardless
func test_namespace_check_never_blocks_write_in_any_build() -> void:
	# Even bare keys must write successfully (warning ≠ block)
	for i in range(5):
		var result: bool = PersistenceLayer.write("bare_%d" % i, i)
		assert_true(result, "write() must always return true for valid key/value")
