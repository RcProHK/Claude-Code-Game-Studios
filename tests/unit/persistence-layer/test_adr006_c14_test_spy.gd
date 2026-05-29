# ADR-006 Contract 14 binding — test spy interface
# Gate: Story 015 AC-32
extends GutTest

func before_each() -> void:
	PersistenceLayer.get(&"_cache").clear()
	PersistenceLayer._test_force_substate(&"READY")
	PersistenceLayer.clear_spies()

func test_adr006_c14_production_spy_is_noop() -> void:
	var calls: Array = []
	PersistenceLayer.attach_write_spy(calls.append)
	PersistenceLayer.write("c14_key", "val")
	assert_eq(calls.size(), 0,
		"ADR-006 Contract 14: production attach_write_spy must be no-op")

func test_adr006_c14_mock_spy_records() -> void:
	var mock := MockPersistenceLayer.new()
	var log: Array = []
	mock.attach_write_spy(log.append)
	mock.write("key", "val")
	assert_eq(log.size(), 1,
		"ADR-006 Contract 14: MockPersistenceLayer must record writes via spy")
