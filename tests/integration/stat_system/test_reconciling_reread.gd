# StatSystem — Story 009 Reconciling re-read (AC-new-reconciling) Integration Tests.
#
# Scope (Rule 14 / EC-23 — Pillar 1 anti-stale guarantee): while the system is
# Suspended the backend may advance a persisted base stat. On GSM resume (any
# non-SUSPENDED transition) the system enters RECONCILING, re-reads the 3 base
# keys synchronously, and emits a delta stat_changed for any key whose fresh
# persisted value differs from the pre-Suspension snapshot — then returns to READY.
#
# A backend value UNCHANGED during suspension emits nothing for that key.
# State delivery is ENUM-typed (mirrors the GSM callv layout) via a capturing MockGSM.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-new-reconciling (Rule 14 / EC-23)
# Story: production/epics/stat-system/story-009-gsm-suspended-gate-reconciling.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


## MockGSM capturing the subscriber so the test drives transitions with enum args.
class MockGSM extends RefCounted:
	var _subscriber: Callable = Callable()

	func connect_for_initial_state(callable: Callable) -> void:
		_subscriber = callable

	func deliver(
		from_state: GameStateMachine.GameState,
		to_state: GameStateMachine.GameState,
		payload: StateTransitionPayload = null,
	) -> void:
		_subscriber.callv([from_state, to_state, payload])


var _sut
var _mock_persistence: MockPersistenceLayer
var _mock_gsm: MockGSM


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()
	# Seed a persisted STR of 12.0 so _base[STR] boots to 12.0 (the AC pre-Suspension value).
	_mock_persistence.write("stat.str", 12.0)
	_mock_gsm = MockGSM.new()
	_sut = StatSystem.new()
	_sut._persistence = _mock_persistence
	_sut._gsm = _mock_gsm
	add_child_autofree(_sut)  # boot: _base[STR] == 12.0, substate READY


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


func _enter_suspended() -> void:
	_mock_gsm.deliver(
		GameStateMachine.GameState.IDLE,
		GameStateMachine.GameState.SUSPENDED,
	)


func _resume() -> void:
	_mock_gsm.deliver(
		GameStateMachine.GameState.SUSPENDED,
		GameStateMachine.GameState.IDLE,
	)


## AC-new-reconciling: backend advanced STR during suspension → resume re-reads
## and updates _base + emits the delta.
func test_resume_rereads_backend_updated_stat() -> void:
	# Arrange: boot at 12.0, enter Suspended (snapshot captures 12.0).
	assert_eq(_sut.get_stat(_sut.StatId.STR), 12.0, "precondition: STR boots to persisted 12.0")
	_enter_suspended()
	# Backend advances STR to 15.0 while we are gated.
	_mock_persistence.write("stat.str", 15.0)
	watch_signals(_sut)

	# Act: GSM resumes.
	_resume()

	# Assert: _base picked up the fresh value and the delta was broadcast.
	assert_eq(_sut.get_stat(_sut.StatId.STR), 15.0,
		"AC-new-reconciling: resume must re-read STR to the backend value 15.0")
	assert_eq(_sut._substate, StatSystem.Substate.READY,
		"AC-new-reconciling: substate must return to READY after reconciling")
	assert_signal_emit_count(_sut, "stat_changed", 1,
		"AC-new-reconciling: exactly one delta stat_changed for the advanced stat")
	var params: Array = get_signal_parameters(_sut, "stat_changed", 0)
	assert_eq(params[0], _sut.StatId.STR, "delta stat_id must be STR")
	assert_eq(params[1], 12.0, "old_value must be the pre-Suspension 12.0")
	assert_eq(params[2], 15.0, "new_value must be the reconciled 15.0")


## AC-new-reconciling: a backend value UNCHANGED during suspension emits nothing.
func test_resume_unchanged_backend_emits_nothing() -> void:
	# Arrange: enter Suspended; backend leaves STR at 12.0 (no change).
	_enter_suspended()
	watch_signals(_sut)

	# Act
	_resume()

	# Assert: no delta emitted; substate back to READY.
	assert_signal_emit_count(_sut, "stat_changed", 0,
		"AC-new-reconciling: an unchanged backend value must NOT emit stat_changed")
	assert_eq(_sut._substate, StatSystem.Substate.READY,
		"AC-new-reconciling: substate returns to READY even with no delta")


## AC-new-reconciling: after reconciling, mutations succeed again (gate released).
func test_mutation_succeeds_after_reconciling() -> void:
	# Arrange
	_enter_suspended()
	_mock_persistence.write("stat.str", 15.0)
	_resume()

	# Act: a normal mutation post-resume.
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: the gate is released — mutation lands on the reconciled value.
	assert_true(ok, "AC-new-reconciling: mutations succeed once reconciling returns to READY")
	assert_eq(_sut.get_stat(_sut.StatId.STR), 16.0,
		"AC-new-reconciling: +1 applies on top of the reconciled 15.0")
