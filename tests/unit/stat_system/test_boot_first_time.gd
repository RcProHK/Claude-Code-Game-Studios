# StatSystem — Story 004 Boot Reconciliation, first-time boot (AC-10) Unit Tests.
#
# Scope: a fresh install has no persisted stat.* keys. Boot must default all three
# base stats to DEFAULT_BASE_VALUE (10.0), reach Substate.READY, emit boot_completed
# exactly once, and emit NO stat_changed during boot (subscribers connect later).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-10 (Rule 6/7 boot)
# Story: production/epics/stat-system/story-004-boot-reconciliation.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


## Minimal mock GSM — records the connect_for_initial_state call so the boot
## subscription (ADR-0006 Contract 6) can be asserted. No state_changed signal:
## if production used a direct .connect() this mock would runtime-error (the
## Contract 6 protection, same pattern as the StreakSystem boot test).
class MockGSM extends RefCounted:
	var connect_for_initial_state_call_count: int = 0
	var registered_callable: Callable = Callable()

	func connect_for_initial_state(callable: Callable) -> void:
		connect_for_initial_state_call_count += 1
		registered_callable = callable


var _sut
var _mock_persistence: MockPersistenceLayer
var _mock_gsm: MockGSM


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()  # empty _data → read() returns null
	_mock_gsm = MockGSM.new()
	_sut = StatSystem.new()
	_sut._persistence = _mock_persistence
	_sut._gsm = _mock_gsm


func after_each() -> void:
	_sut.free()
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


func test_boot_first_time_defaults_all_base_stats_to_ten() -> void:
	# Arrange: empty persistence (no stat.* keys) — done in before_each.
	# Act
	add_child_autofree(_sut)  # triggers _ready()
	await get_tree().process_frame  # _ready() already ran synchronously in add_child; settle one frame (awaiting _sut.ready would hang — it already fired)

	# Assert: AC-10 — every base stat falls back to the 10.0 default.
	assert_eq(_sut.get_stat(_sut.StatId.STR), 10.0, "AC-10: STR must default to 10.0 on first boot")
	assert_eq(_sut.get_stat(_sut.StatId.DEX), 10.0, "AC-10: DEX must default to 10.0 on first boot")
	assert_eq(_sut.get_stat(_sut.StatId.VIT), 10.0, "AC-10: VIT must default to 10.0 on first boot")


func test_boot_first_time_reaches_ready_substate() -> void:
	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame  # _ready() already ran synchronously in add_child; settle one frame (awaiting _sut.ready would hang — it already fired)

	# Assert: AC-10 — boot completes into READY.
	assert_eq(_sut._substate, StatSystem.Substate.READY,
		"AC-10: _substate must be READY after _ready() completes")


func test_boot_first_time_emits_boot_completed_exactly_once() -> void:
	# Arrange: watch BEFORE _ready() fires.
	watch_signals(_sut)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame  # _ready() already ran synchronously in add_child; settle one frame (awaiting _sut.ready would hang — it already fired)

	# Assert: AC-22 — boot_completed emits exactly once.
	assert_signal_emit_count(_sut, "boot_completed", 1,
		"AC-22: boot_completed must emit exactly once during boot")


func test_boot_first_time_emits_no_stat_changed_during_boot() -> void:
	# Arrange
	watch_signals(_sut)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame  # _ready() already ran synchronously in add_child; settle one frame (awaiting _sut.ready would hang — it already fired)

	# Assert: AC-10 — no stat_changed during boot (subscribers connect via
	# connect_for_initial_state AFTER boot, never during it).
	assert_signal_emit_count(_sut, "stat_changed", 0,
		"AC-10: no stat_changed may be emitted during boot")


func test_boot_first_time_subscribes_to_gsm_once() -> void:
	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame  # _ready() already ran synchronously in add_child; settle one frame (awaiting _sut.ready would hang — it already fired)

	# Assert: AC-22 — GSM subscription wired via connect_for_initial_state.
	assert_eq(_mock_gsm.connect_for_initial_state_call_count, 1,
		"boot must subscribe to GSM via connect_for_initial_state exactly once")
	assert_true(_mock_gsm.registered_callable.is_valid(),
		"a valid callable must be registered with the GSM")
