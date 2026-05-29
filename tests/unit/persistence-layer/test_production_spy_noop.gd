# PersistenceLayer — Story 005 AC-11 Production Spy No-Op Tests
#
# Scope: proves the production PersistenceLayer.attach_write_spy /
# attach_delete_spy / clear_spies methods are TRUE no-ops — the attached
# Callable must NEVER be invoked, regardless of when it was attached
# relative to subsequent writes.
#
# AC-11 (GDD design/gdd/persistence-layer.md):
#   GIVEN real PersistenceLayer + `attach_write_spy(my_cb)`,
#   WHEN  `write("foo", "bar")`,
#   THEN  `my_cb` NEVER invoked; no error.
#
# Why this matters: ADR-0006 Contract 14 requires the spy interface to
# exist in production builds (no conditional compilation) so that
# MockPersistenceLayer is a true drop-in replacement. The production
# methods must be safe to call but inert — any accidental recording would
# leak test instrumentation into shipped builds.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 14
extends GutTest


const CACHE_VAR_NAME: StringName = &"_cache"


func before_each() -> void:
	# Isolation: clear cache + drop any leftover write_completed connections
	# from prior suites so signal emissions don't bleed into other tests.
	PersistenceLayer.get(CACHE_VAR_NAME).clear()
	for conn in PersistenceLayer.write_completed.get_connections():
		PersistenceLayer.write_completed.disconnect(conn.callable)
	# Defensive: clear_spies() is itself a production no-op, but call it to
	# guard against future regressions where someone wires a real spy list.
	PersistenceLayer.clear_spies()


## AC-11: a spy attached to the production PersistenceLayer is never invoked.
func test_persistence_layer_production_spy_never_invoked_on_write() -> void:
	# Arrange
	var call_log: Array = []
	PersistenceLayer.attach_write_spy(call_log.append)

	# Act
	PersistenceLayer.write("foo", "bar")

	# Assert
	assert_eq(call_log.size(), 0, "Production spy must never be invoked")
	assert_eq(PersistenceLayer.read("foo"), "bar",
		"Write must still succeed normally even though spy is no-op")


## AC-11 edge: pre-attach writes do not retroactively fire the spy AND
## post-attach writes do not fire it either — true no-op in both directions.
func test_persistence_layer_production_spy_not_retroactive() -> void:
	# Arrange
	PersistenceLayer.write("a", 1)
	PersistenceLayer.write("b", 2)
	PersistenceLayer.write("c", 3)
	var call_log: Array = []

	# Act
	PersistenceLayer.attach_write_spy(call_log.append)
	PersistenceLayer.write("d", 4)

	# Assert
	assert_eq(call_log.size(), 0,
		"Spy must not be called even for post-attach writes (production no-op)")


## Additional: clear_spies() is a production no-op and does not crash even
## when called with previously attached callables.
func test_persistence_layer_clear_spies_noop_no_error() -> void:
	# Arrange
	PersistenceLayer.attach_write_spy(func(_x: Variant) -> void: pass)

	# Act
	PersistenceLayer.clear_spies()
	var result: bool = PersistenceLayer.write("test", "value")

	# Assert
	assert_true(result, "write() must work normally after clear_spies() no-op")
