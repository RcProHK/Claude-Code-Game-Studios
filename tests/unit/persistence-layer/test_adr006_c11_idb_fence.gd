# ADR-006 Contract 11 binding — best-effort IDB fence (no await, sync emit)
# Gate: Story 015 AC-32
extends GutTest

func before_each() -> void:
	PersistenceLayer.get(&"_cache").clear()
	PersistenceLayer._test_force_substate(&"READY")
	for conn in PersistenceLayer.write_completed.get_connections():
		PersistenceLayer.write_completed.disconnect(conn.callable)

func test_adr006_c11_write_completed_emits_synchronously() -> void:
	# watch_signals (NOT a lambda counter — GDScript captures scalars by value).
	watch_signals(PersistenceLayer)

	PersistenceLayer.write("c11_key", "value")

	assert_signal_emit_count(PersistenceLayer, "write_completed", 1,
		"ADR-006 Contract 11: write_completed must emit synchronously (no await)")

func test_adr006_c11_no_tombstone_write_completed_on_persistence_layer() -> void:
	var names: Array = []
	for s in PersistenceLayer.get_signal_list():
		names.append(s["name"])
	assert_false(names.has("tombstone_write_completed"),
		"ADR-006 Contract 11: PersistenceLayer must never declare tombstone_write_completed")
