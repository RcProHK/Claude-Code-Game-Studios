# GameStateMachine — Story 015 Rule 6 Zero-Input (Pillar 2)
#
# REPAIRED 2026-06-06 (#18 story 002 gate run): this file predates the #33
# 2-arg DI ctor (gsm_ref, wst_ref) and had been silently parse-failing since
# 2026-06-04 — GUT only WARNS on load failure, so it was a phantom-pass.
# Now uses the canonical #33 fake pattern (test_input_permitted_derivation.gd)
# so it is deterministic under the combined gate (no autoload state leakage).
extends GutTest


## Minimal fake GSM — duck-typed get_current_state() (pure-pull, no signals).
class _FakeGSM:
	extends RefCounted
	var _state: int = GameStateMachine.GameState.IDLE

	func get_current_state() -> int:
		return _state

	func set_state(s: int) -> void:
		_state = s


## Minimal fake WST — duck-typed get_current_phase(); stays IDLE (this file
## tests the GSM floor axis only — WST refinement is #33's own suite).
class _FakeWST:
	extends RefCounted
	var _phase: int = WorkoutStateTracker.WorkoutPhase.IDLE

	func get_current_phase() -> int:
		return _phase


const _GS := GameStateMachine.GameState

var _fake_gsm: _FakeGSM
var _fake_wst: _FakeWST
var _policy: AttentionBudgetPolicy


func before_each() -> void:
	_fake_gsm = _FakeGSM.new()
	_fake_wst = _FakeWST.new()
	_policy = AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)


## AC-gsm-r6-1: WORKOUT_ACTIVE → input blocked
func test_attention_budget_blocks_input_in_workout_active() -> void:
	_fake_gsm.set_state(_GS.WORKOUT_ACTIVE)
	assert_false(_policy.is_input_permitted(),
		"AC-r6-1: WORKOUT_ACTIVE must block input")


## AC-gsm-r6-1 (also): COMBAT_ACTIVE blocked
func test_attention_budget_blocks_input_in_combat_active() -> void:
	_fake_gsm.set_state(_GS.COMBAT_ACTIVE)
	assert_false(_policy.is_input_permitted(),
		"COMBAT_ACTIVE must block input (Pillar 2)")


## AC-gsm-r6-1 (also): BOSS_ENCOUNTER blocked
func test_attention_budget_blocks_input_in_boss_encounter() -> void:
	_fake_gsm.set_state(_GS.BOSS_ENCOUNTER)
	assert_false(_policy.is_input_permitted(),
		"BOSS_ENCOUNTER must block input")


## AC-gsm-r6-2: IDLE → input allowed
func test_attention_budget_allows_input_in_idle() -> void:
	_fake_gsm.set_state(_GS.IDLE)
	assert_true(_policy.is_input_permitted(),
		"AC-r6-2: IDLE must allow input")


## AC-gsm-r6-3: transition from blocked → allowed
func test_attention_budget_transitions_blocked_to_allowed() -> void:
	# Arrange/Act/Assert — blocked
	_fake_gsm.set_state(_GS.WORKOUT_ACTIVE)
	assert_false(_policy.is_input_permitted())
	# Transitioned to allowed (pure-pull — no signal needed)
	_fake_gsm.set_state(_GS.REST_PERIOD)
	assert_true(_policy.is_input_permitted(),
		"AC-r6-3: WORKOUT_ACTIVE → REST_PERIOD must flip input permission")
