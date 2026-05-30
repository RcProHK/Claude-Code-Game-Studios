# AbilitySystem — Story 008 GSM Suspended Gate + Reconciling Re-read (AC-15 / AC-15b) Integration.
#
# Scope (Rule 14 / TR-ability-012):
#   AC-15  — GSM delivers a transition to SUSPENDED → the mutation API rejects:
#            unlock_ability returns false + ability_mutation_rejected(..., "suspended_substate"),
#            cast_ability returns CastResult.GSM_REJECT, NO PersistenceLayer.write. Read-only
#            get_unlocked_abilities() succeeds normally during Suspended.
#   AC-15b — exit Suspended → Reconciling re-reads all ability.unlocked.* keys; a backend key
#            unlocked during suspension is added + ability_unlocked emitted; substate returns to
#            READY; a subsequent unlock succeeds (gate released).
#
# State delivery is ENUM-typed (mirrors the GSM callv layout) via a capturing MockGSM, exactly as
# the StatSystem Story 009 suspended-gate test does.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/ability-system.md Rules 11/12 + EC-30
# Story: production/epics/ability-system/story-008-gsm-suspended-permanent-unlock.md
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")


## MockGSM — captures the subscriber callable so the test drives GSM transitions manually with
## ENUM-typed state args (mirrors the GSM callv layout). get_current_state defaults to COMBAT_ACTIVE
## so a non-gated cast would pass the cast-time GSM gate (Step 5) — the Suspended REJECT under test
## is the substate gate (Step 1b), not the cast-time state check.
class MockGSM extends RefCounted:
	var _subscriber: Callable = Callable()
	var _current_state: int = GameStateMachine.GameState.COMBAT_ACTIVE

	func connect_for_initial_state(callable: Callable) -> void:
		_subscriber = callable

	func get_current_state() -> int:
		return _current_state

	func deliver(
		from_state: GameStateMachine.GameState,
		to_state: GameStateMachine.GameState,
		payload: StateTransitionPayload = null,
	) -> void:
		_subscriber.callv([from_state, to_state, payload])


## MockStatSystem — captures connect_for_initial_state; get_stat returns a high value so the
## cast-time stat gate would pass if a cast ever reached it (it does not during Suspended).
class MockStatSystem extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass

	func get_stat(_stat_id: StringName) -> float:
		return 100.0


var _sut
var _mock_persistence: MockPersistenceLayer
var _mock_gsm: MockGSM
var _mock_stat: MockStatSystem


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()
	_mock_gsm = MockGSM.new()
	_mock_stat = MockStatSystem.new()
	_sut = AbilitySystem.new()
	_sut._persistence = _mock_persistence
	_sut._gsm = _mock_gsm
	_sut._stat_system = _mock_stat
	add_child_autofree(_sut)  # boot to READY; captures the GSM callable


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_mock_gsm = null
	_mock_stat = null


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


## Unlock an ability through the internal permitted chokepoint (tests are not on the caller
## whitelist; open the window the same way the production handler does).
func _unlock_via_chokepoint(ability_id: StringName, source: int, expected_class: int) -> bool:
	_sut._unlock_call_permitted = true
	var ok: bool = _sut.unlock_ability(ability_id, source, expected_class)
	_sut._unlock_call_permitted = false
	return ok


# --- AC-15: Suspended latches + mutation API rejects ------------------------------------------

func test_transition_to_suspended_latches_substate() -> void:
	# Act
	_enter_suspended()

	# Assert
	assert_eq(_sut._substate, AbilitySystem.Substate.SUSPENDED,
		"AC-15: a transition to GameState.SUSPENDED latches the SUSPENDED substate")


func test_suspended_rejects_unlock_ability() -> void:
	# Arrange
	_enter_suspended()
	watch_signals(_sut)
	var write_log: Array = []
	_mock_persistence.attach_write_spy(write_log.append)

	# Act — attempt an unlock through the permitted chokepoint while Suspended.
	var ok: bool = _unlock_via_chokepoint(
		_sut.AbilityId.STRIKE_TIER_1_JAB,
		_sut.UnlockSource.PR_BREAKTHROUGH,
		_sut.AbilityClass.STRIKE,
	)

	# Assert: AC-15 — rejected, table unchanged, canonical reason, NO persist.
	assert_false(ok, "AC-15: unlock_ability returns false during Suspended")
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-15: the unlock table is unchanged during Suspended")
	assert_signal_emit_count(_sut, "ability_mutation_rejected", 1,
		"AC-15: a Suspended-gated unlock emits ability_mutation_rejected once")
	var params: Array = get_signal_parameters(_sut, "ability_mutation_rejected", 0)
	assert_eq(params[2], "suspended_substate", "AC-15: reject reason must be 'suspended_substate'")
	assert_eq(write_log.size(), 0, "AC-15: NO PersistenceLayer.write occurs on a gated unlock")


func test_suspended_rejects_cast_with_gsm_reject() -> void:
	# Arrange — unlock an ability FIRST (while READY), then enter Suspended.
	_unlock_via_chokepoint(_sut.AbilityId.STRIKE_TIER_1_JAB, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityClass.STRIKE)
	_enter_suspended()
	watch_signals(_sut)

	# Act — cast during Suspended.
	var result: int = _sut.cast_ability(_sut.AbilityId.STRIKE_TIER_1_JAB, null, null)

	# Assert: AC-15 — cast rejected GSM_REJECT.
	assert_eq(result, _sut.CastResult.GSM_REJECT, "AC-15: cast_ability returns GSM_REJECT during Suspended")
	assert_signal_emit_count(_sut, "ability_cast_rejected", 1,
		"AC-15: a Suspended-gated cast emits ability_cast_rejected once")


func test_suspended_read_only_get_unlocked_abilities_succeeds() -> void:
	# Arrange — unlock one ability (READY), then enter Suspended.
	_unlock_via_chokepoint(_sut.AbilityId.STRIKE_TIER_1_JAB, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityClass.STRIKE)
	_enter_suspended()

	# Act / Assert — the read-only API is NOT gated.
	var unlocked: Dictionary = _sut.get_unlocked_abilities()
	assert_eq(unlocked.size(), 1, "AC-15: get_unlocked_abilities() returns normally during Suspended")
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-15: get_ability_state() reads normally during Suspended")


func test_suspended_rejects_each_consecutive_unlock_independently() -> void:
	# Arrange
	_enter_suspended()
	watch_signals(_sut)

	# Act — three consecutive gated unlocks.
	_unlock_via_chokepoint(_sut.AbilityId.STRIKE_TIER_1_JAB, _sut.UnlockSource.PR_BREAKTHROUGH, _sut.AbilityClass.STRIKE)
	_unlock_via_chokepoint(_sut.AbilityId.CONTROL_TIER_1_PARRY, _sut.UnlockSource.STAT_THRESHOLD, _sut.AbilityClass.CONTROL)
	_unlock_via_chokepoint(_sut.AbilityId.MOBILITY_TIER_1_DASH, _sut.UnlockSource.STAT_THRESHOLD, _sut.AbilityClass.MOBILITY)

	# Assert — each independently rejected.
	assert_signal_emit_count(_sut, "ability_mutation_rejected", 3,
		"AC-15: each consecutive Suspended unlock is independently rejected")


# --- AC-15b: Reconciling re-read emits delta unlocks ------------------------------------------

func test_resume_reconciles_backend_unlock() -> void:
	# Arrange — enter Suspended, then the backend unlocks CONTROL_TIER_2 during suspension.
	_enter_suspended()
	var record := AbilitySystem.UnlockRecord.new()
	record.first_unlocked_at_unix = 1_700_000_000
	record.source = _sut.UnlockSource.PR_BREAKTHROUGH
	_mock_persistence.write(
		"ability.unlocked." + String(_sut.AbilityId.CONTROL_TIER_2_HOOK_PULL),
		record.to_dict(),
	)
	watch_signals(_sut)

	# Act — GSM resumes (exit Suspended → Reconciling → READY).
	_resume()

	# Assert: AC-15b — the backend unlock is reconciled in + announced, substate back to READY.
	assert_true(_sut.get_ability_state(_sut.AbilityId.CONTROL_TIER_2_HOOK_PULL)["unlocked"],
		"AC-15b: the backend-unlocked ability is present after Reconciling")
	assert_eq(_sut._substate, AbilitySystem.Substate.READY,
		"AC-15b: substate returns to READY after Reconciling")
	assert_signal_emit_count(_sut, "ability_unlocked", 1,
		"AC-15b: exactly one ability_unlocked delta for the backend unlock")
	var params: Array = get_signal_parameters(_sut, "ability_unlocked", 0)
	assert_eq(params[0], _sut.AbilityId.CONTROL_TIER_2_HOOK_PULL, "AC-15b: the delta carries the reconciled id")
	assert_eq(params[1], int(_sut.UnlockSource.PR_BREAKTHROUGH), "AC-15b: the delta source is PR_BREAKTHROUGH")


func test_resume_no_backend_change_emits_nothing() -> void:
	# Arrange — enter Suspended; the backend unlocks nothing.
	_enter_suspended()
	watch_signals(_sut)

	# Act
	_resume()

	# Assert — no delta, substate back to READY.
	assert_signal_emit_count(_sut, "ability_unlocked", 0,
		"AC-15b: an unchanged backend emits no ability_unlocked on resume")
	assert_eq(_sut._substate, AbilitySystem.Substate.READY,
		"AC-15b: substate returns to READY even with no delta")


func test_unlock_succeeds_after_reconciling_gate_released() -> void:
	# Arrange — Suspended then resume (gate released).
	_enter_suspended()
	_resume()

	# Act — a normal unlock post-resume through the chokepoint.
	var ok: bool = _unlock_via_chokepoint(
		_sut.AbilityId.STRIKE_TIER_1_JAB,
		_sut.UnlockSource.PR_BREAKTHROUGH,
		_sut.AbilityClass.STRIKE,
	)

	# Assert — the gate is released; the unlock lands.
	assert_true(ok, "AC-15b: unlock_ability succeeds once Reconciling returns to READY")
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-15b: the post-resume unlock is recorded")


func test_initial_state_suspended_latches_after_boot() -> void:
	# Arrange — EC-30: an INITIAL_STATE sentinel whose `to` is SUSPENDED (backend already suspended
	# at connect time). It still latches Suspended after boot.
	var payload := StateTransitionPayload.new()
	payload.source_event = GameStateMachine.INITIAL_STATE_PAYLOAD_SOURCE_EVENT

	# Act
	_mock_gsm.deliver(
		GameStateMachine.GameState.SUSPENDED,
		GameStateMachine.GameState.SUSPENDED,
		payload,
	)

	# Assert: EC-30 — latched Suspended; a subsequent unlock is rejected.
	assert_eq(_sut._substate, AbilitySystem.Substate.SUSPENDED,
		"EC-30: an initial-state SUSPENDED delivery latches SUSPENDED after boot")
	var ok: bool = _unlock_via_chokepoint(
		_sut.AbilityId.STRIKE_TIER_1_JAB,
		_sut.UnlockSource.PR_BREAKTHROUGH,
		_sut.AbilityClass.STRIKE,
	)
	assert_false(ok, "EC-30: mutations are rejected immediately after an initial Suspended latch")
