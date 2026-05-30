# StatSystem — Story 006 Atomic write, persist-first failure path (AC-18) Integration Tests.
#
# Scope: apply_stat_delta persists BEFORE mutating _base. If the write fails:
#   - apply_stat_delta returns false
#   - _base is unchanged (no divergence between memory and disk)
#   - stat_critical_save_failed(stat_id) is emitted
#   - NO stat_changed is emitted (the mutation never "happened")
#
# MockPersistenceLayer.write() hard-returns true, so this test uses a
# FailingPersistence inline mock whose write() returns false.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-18 (Rule 7 atomicity)
# Story: production/epics/stat-system/story-006-persistence-atomic-write.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


## Persistence whose write() always fails. read() returns null (first-boot
## defaults), so _base[STR] starts at the 10.0 baseline.
class FailingPersistence extends RefCounted:
	var write_call_count: int = 0

	func read(_key: String) -> Variant:
		return null

	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		write_call_count += 1
		return false  # simulate a disk/quota failure


var _sut
var _persistence: FailingPersistence


func before_each() -> void:
	_persistence = FailingPersistence.new()
	_sut = StatSystem.new()
	_sut._persistence = _persistence
	_sut._gsm = MockGSM.new()
	add_child_autofree(_sut)  # boot to READY (read() null → STR == 10.0)


func after_each() -> void:
	_sut = null
	_persistence = null


func test_write_failure_returns_false() -> void:
	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: AC-18 — a failed persist makes apply_stat_delta return false.
	assert_false(ok, "AC-18: apply_stat_delta must return false when persist fails")
	assert_eq(_persistence.write_call_count, 1, "persist must be attempted exactly once (persist-first)")


func test_write_failure_leaves_base_unchanged() -> void:
	# Arrange: snapshot the pre-mutation base value.
	var before: float = _sut.get_stat(_sut.StatId.STR)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: AC-18 — _base must NOT advance when the write failed.
	assert_eq(_sut.get_stat(_sut.StatId.STR), before,
		"AC-18: _base[STR] must be unchanged after a failed persist (10.0, not 11.0)")


func test_write_failure_emits_critical_save_failed() -> void:
	# Arrange
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: AC-18 — the failure is surfaced via stat_critical_save_failed.
	assert_signal_emit_count(_sut, "stat_critical_save_failed", 1,
		"AC-18: a failed persist must emit stat_critical_save_failed once")
	var params: Array = get_signal_parameters(_sut, "stat_critical_save_failed")
	assert_eq(params[0], _sut.StatId.STR, "AC-18: the failure signal must carry the offending stat_id")


func test_write_failure_emits_no_stat_changed() -> void:
	# Arrange
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: AC-18 — a mutation that never persisted must not broadcast stat_changed.
	assert_signal_emit_count(_sut, "stat_changed", 0,
		"AC-18: no stat_changed may be emitted when the persist failed")
