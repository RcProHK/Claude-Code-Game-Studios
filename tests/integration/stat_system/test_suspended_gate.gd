# StatSystem — Story 009 GSM Suspended gate (AC-20 / AC-20b) Integration Tests.
#
# Scope (Rule 14 — mutation API gated while GSM holds the system Suspended):
#   AC-20  — after GSM delivers a transition to SUSPENDED, apply_stat_delta rejects:
#            returns false, stat_mutation_rejected(..., "suspended_substate") emits,
#            push_warning fires, stat unchanged.
#   AC-20b — get_stat() is NOT gated during Suspended (read-only); AND
#            apply_equipment_modifier is gated the same way as apply_stat_delta
#            (mutation API uniformly rejected).
#   EC-24  — an INITIAL_STATE delivery whose `to` is SUSPENDED latches Suspended
#            immediately after boot (backend already suspended at connect time).
#
# State comparison is ENUM-typed per the Q1 decision: the handler receives
# (from: GameState, to: GameState, payload) and compares
# `to == GameStateMachine.GameState.SUSPENDED` — NOT string-name parsing. The
# MockGSM captures the callable and re-delivers with enum args to mirror the GSM
# callv layout (ADR-0006 Contract 6).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-20 / AC-20b (Rule 14)
# Story: production/epics/stat-system/story-009-gsm-suspended-gate-reconciling.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


## MockGSM that captures the subscriber callable so the test can drive GSM
## transitions manually with ENUM-typed state args (mirrors the GSM callv layout).
class MockGSM extends RefCounted:
	var _subscriber: Callable = Callable()

	func connect_for_initial_state(callable: Callable) -> void:
		_subscriber = callable

	## Deliver a transition exactly as the real GSM would: positional
	## [from_state, to_state, payload]. `payload` may be a real StateTransitionPayload
	## (an initial-state sentinel) or null (a plain real transition).
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
	_mock_gsm = MockGSM.new()
	_sut = StatSystem.new()
	_sut._persistence = _mock_persistence
	_sut._gsm = _mock_gsm
	add_child_autofree(_sut)  # boot to READY (STR == 10.0); captures the callable


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


## Helper: drive the SUT into Suspended via a real (non-sentinel) transition.
func _enter_suspended() -> void:
	_mock_gsm.deliver(
		GameStateMachine.GameState.IDLE,
		GameStateMachine.GameState.SUSPENDED,
	)


# --- AC-20: apply_stat_delta rejected during Suspended ------------------------

func test_suspended_substate_latched_on_transition() -> void:
	# Act
	_enter_suspended()

	# Assert: the enum comparison latched the SUSPENDED substate.
	assert_eq(_sut._substate, StatSystem.Substate.SUSPENDED,
		"AC-20: a transition to GameState.SUSPENDED must latch the SUSPENDED substate")


func test_suspended_rejects_apply_stat_delta() -> void:
	# Arrange
	_enter_suspended()
	watch_signals(_sut)
	var before: float = _sut.get_stat(_sut.StatId.STR)

	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: AC-20 — mutation rejected, stat unchanged, canonical reason emitted.
	assert_false(ok, "AC-20: apply_stat_delta must return false during Suspended")
	assert_eq(_sut.get_stat(_sut.StatId.STR), before, "AC-20: STR must be unchanged during Suspended")
	assert_signal_emit_count(_sut, "stat_mutation_rejected", 1,
		"AC-20: a Suspended-gated mutation must emit stat_mutation_rejected once")
	var params: Array = get_signal_parameters(_sut, "stat_mutation_rejected")
	assert_eq(params[0], _sut.StatId.STR, "AC-20: rejected stat_id must be STR")
	assert_eq(params[1], _sut.StatSource.PR_BREAKTHROUGH, "AC-20: rejected source must be PR_BREAKTHROUGH")
	assert_eq(params[3], "suspended_substate", "AC-20: reason must be 'suspended_substate'")


func test_suspended_rejects_no_stat_changed() -> void:
	# Arrange
	_enter_suspended()
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: AC-20 — a gated mutation never broadcasts a change.
	assert_signal_emit_count(_sut, "stat_changed", 0,
		"AC-20: a Suspended-gated mutation must NOT emit stat_changed")


func test_suspended_rejects_each_consecutive_call_independently() -> void:
	# Arrange
	_enter_suspended()
	watch_signals(_sut)

	# Act: three consecutive gated mutations.
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)
	_sut.apply_stat_delta(_sut.StatId.DEX, _sut.StatSource.VOLUME_TICK, 1.0)
	_sut.apply_stat_delta(_sut.StatId.VIT, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: each is independently rejected.
	assert_signal_emit_count(_sut, "stat_mutation_rejected", 3,
		"AC-20: each consecutive Suspended mutation is independently rejected")


# --- AC-20b: read-only get_stat NOT gated; equipment modifier IS gated --------

func test_get_stat_not_gated_during_suspended() -> void:
	# Arrange
	_enter_suspended()

	# Act / Assert: read-only API returns the current value normally.
	assert_eq(_sut.get_stat(_sut.StatId.STR), 10.0,
		"AC-20b: get_stat() must NOT be gated during Suspended (read-only)")


func test_apply_equipment_modifier_gated_during_suspended() -> void:
	# Arrange
	_enter_suspended()
	watch_signals(_sut)
	var modifier := StatSystem.StatModifier.new({_sut.StatId.MAX_HP: 50.0})

	# Act
	_sut.apply_equipment_modifier(&"ring", modifier)

	# Assert: AC-20b — the equipment modifier path is gated identically. No derived
	# stat_changed should fire, and the modifier must NOT enter the table.
	assert_signal_emit_count(_sut, "stat_changed", 0,
		"AC-20b: apply_equipment_modifier must not emit stat_changed during Suspended")
	assert_signal_emit_count(_sut, "stat_mutation_rejected", 1,
		"AC-20b: apply_equipment_modifier must emit stat_mutation_rejected during Suspended")
	var params: Array = get_signal_parameters(_sut, "stat_mutation_rejected")
	assert_eq(params[3], "suspended_substate", "AC-20b: equipment reject reason must be 'suspended_substate'")
	assert_false(_sut._equipment_modifiers.has(&"ring"),
		"AC-20b: a gated equipment modifier must NOT be stored")


# --- EC-24: initial-state delivery of SUSPENDED latches after boot ------------

func test_ec24_initial_suspended_latches_suspended_after_boot() -> void:
	# Arrange: an INITIAL_STATE sentinel whose `to` is SUSPENDED (backend already
	# suspended at connect time).
	var payload := StateTransitionPayload.new()
	payload.source_event = GameStateMachine.INITIAL_STATE_PAYLOAD_SOURCE_EVENT

	# Act
	_mock_gsm.deliver(
		GameStateMachine.GameState.SUSPENDED,
		GameStateMachine.GameState.SUSPENDED,
		payload,
	)

	# Assert: EC-24 — the system latches Suspended despite this being the initial burst.
	assert_eq(_sut._substate, StatSystem.Substate.SUSPENDED,
		"EC-24: an initial-state SUSPENDED delivery must latch the SUSPENDED substate")
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)
	assert_false(ok, "EC-24: mutations are rejected immediately after an initial Suspended latch")
