## Unit tests — AttentionBudgetPolicy Story 003
## is_notification_permitted() full Formula 2 derivation + B1 sentinel guard,
## plus AttentionBudget.CRITICAL_NOTIFICATION_KINDS + is_critical_notification().
##
## Coverage (GDD Formula 2 / Rule 7 + AC table):
##   AC-07   — Rule 7 suppress: phase == SET_ACTIVE → false (incl. SET_ACTIVE + IDLE GSM,
##             proving the phase term is independent of GSM state).
##   AC-08   — Rule 7 permit: phase == REST_PERIOD + GSM ∉ suppressed set → true;
##             edge: phase == REST_PERIOD + GSM == LOOT_DROP → false (LOOT_DROP term).
##   Formula2 full — BOOTING → false; SUSPENDED → false; LOOT_DROP → false;
##             IDLE+IDLE → true; WORKOUT_ACTIVE(GSM)+WARM_UP → TRUE (GSM floor is NOT
##             a Formula 2 suppression term — only SET_ACTIVE/BOOTING/SUSPENDED/LOOT_DROP).
##   H1      — phase == WORKOUT_COMPLETE + GSM == IDLE → true (milestone window).
##   B1      — sentinel: invalid GSM int 999 → false (fail-closed, consistency w/ input).
##   AC-10   — null guard: _gsm = null → false (fail-closed, EC-2).
##   AC-18a  — AttentionBudget.is_critical_notification() allowlist membership.
##   Allowlist — CRITICAL_NOTIFICATION_KINDS exact size/content.
##
## Framework: GUT (Godot Unit Testing) v9.x
## NOTE: GUT collects test_*.gd files only; *_test.gd suffix is silently ignored.
##       All test functions must use test_ prefix.
extends GutTest


# ============================================================================
# Stub classes — local to this test file (same pattern as Story 002 test)
# ============================================================================

## Minimal fake GSM — duck-typed surface: get_current_state().
## Mutable via set_state() without emitting any signal (pure-pull).
class _FakeGSM:
	extends RefCounted
	var _state: int = GameStateMachine.GameState.IDLE

	func get_current_state() -> int:
		return _state

	func set_state(s: int) -> void:
		_state = s


## Minimal fake WST — duck-typed surface: get_current_phase().
## Mutable via set_phase() without emitting any signal (pure-pull).
class _FakeWST:
	extends RefCounted
	var _phase: int = WorkoutStateTracker.WorkoutPhase.IDLE

	func get_current_phase() -> int:
		return _phase

	func set_phase(p: int) -> void:
		_phase = p


# ============================================================================
# Constants — shortcuts for readability
# ============================================================================

const _GS := GameStateMachine.GameState
const _WP := WorkoutStateTracker.WorkoutPhase


# ============================================================================
# Test fixtures
# ============================================================================

var _fake_gsm: _FakeGSM
var _fake_wst: _FakeWST


func before_each() -> void:
	_fake_gsm = _FakeGSM.new()
	_fake_wst = _FakeWST.new()


## Helper — build a policy injected with the current fakes.
func _make_policy() -> AttentionBudgetPolicy:
	return AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)


# ============================================================================
# AC-07 — Rule 7 suppress: SET_ACTIVE phase → false (phase term independent of GSM)
# ============================================================================

## AC-07: phase == SET_ACTIVE → is_notification_permitted() false.
func test_ac07_set_active_phase_suppresses_notification() -> void:
	# Arrange
	_fake_gsm.set_state(_GS.REST_PERIOD)  # non-suppressed GSM state
	_fake_wst.set_phase(_WP.SET_ACTIVE)
	var policy := _make_policy()

	# Act + Assert
	assert_false(
		policy.is_notification_permitted(),
		"AC-07: SET_ACTIVE phase must suppress notifications (Rule 7)"
	)


## AC-07 edge: SET_ACTIVE phase + GSM == IDLE → still false (phase term independent).
func test_ac07_set_active_phase_idle_gsm_still_suppressed() -> void:
	# Arrange — GSM is a fully open state; only the phase suppresses.
	_fake_gsm.set_state(_GS.IDLE)
	_fake_wst.set_phase(_WP.SET_ACTIVE)
	var policy := _make_policy()

	# Act + Assert
	assert_false(
		policy.is_notification_permitted(),
		"AC-07: SET_ACTIVE + IDLE GSM must still suppress (phase term independent of GSM)"
	)


# ============================================================================
# AC-08 — Rule 7 permit: REST_PERIOD phase + GSM ∉ suppressed → true
# ============================================================================

## AC-08: phase == REST_PERIOD + GSM == REST_PERIOD(GSM state) → true.
func test_ac08_rest_period_permits_notification() -> void:
	# Arrange
	_fake_gsm.set_state(_GS.REST_PERIOD)
	_fake_wst.set_phase(_WP.REST_PERIOD)
	var policy := _make_policy()

	# Act + Assert
	assert_true(
		policy.is_notification_permitted(),
		"AC-08: REST_PERIOD phase + REST_PERIOD(GSM) must permit notifications"
	)


## AC-08 edge: phase == REST_PERIOD + GSM == LOOT_DROP → false (LOOT_DROP term).
func test_ac08_rest_period_loot_drop_gsm_suppressed() -> void:
	# Arrange — phase is permissive but the ceremony GSM term suppresses.
	_fake_gsm.set_state(_GS.LOOT_DROP)
	_fake_wst.set_phase(_WP.REST_PERIOD)
	var policy := _make_policy()

	# Act + Assert
	assert_false(
		policy.is_notification_permitted(),
		"AC-08 edge: REST_PERIOD phase + LOOT_DROP GSM must suppress (LOOT_DROP ceremony term)"
	)


# ============================================================================
# Formula 2 full coverage — each suppression term + permit cases
# ============================================================================

## Formula 2: GSM == BOOTING → false (lifecycle suppression term).
func test_formula2_booting_suppresses() -> void:
	_fake_gsm.set_state(_GS.BOOTING)
	_fake_wst.set_phase(_WP.IDLE)
	var policy := _make_policy()
	assert_false(
		policy.is_notification_permitted(),
		"Formula 2: BOOTING must suppress notifications (lifecycle term)"
	)


## Formula 2: GSM == SUSPENDED → false (lifecycle suppression term).
func test_formula2_suspended_suppresses() -> void:
	_fake_gsm.set_state(_GS.SUSPENDED)
	_fake_wst.set_phase(_WP.IDLE)
	var policy := _make_policy()
	assert_false(
		policy.is_notification_permitted(),
		"Formula 2: SUSPENDED must suppress notifications (lifecycle term)"
	)


## Formula 2: GSM == LOOT_DROP → false (ceremony suppression term).
func test_formula2_loot_drop_suppresses() -> void:
	_fake_gsm.set_state(_GS.LOOT_DROP)
	_fake_wst.set_phase(_WP.WORKOUT_COMPLETE)
	var policy := _make_policy()
	assert_false(
		policy.is_notification_permitted(),
		"Formula 2: LOOT_DROP must suppress notifications (ceremony term)"
	)


## Formula 2: GSM == IDLE + phase == IDLE → true (fully open, no suppression term).
func test_formula2_idle_idle_permits() -> void:
	_fake_gsm.set_state(_GS.IDLE)
	_fake_wst.set_phase(_WP.IDLE)
	var policy := _make_policy()
	assert_true(
		policy.is_notification_permitted(),
		"Formula 2: IDLE + IDLE must permit notifications (no suppression term hit)"
	)


## Formula 2: GSM == WORKOUT_ACTIVE + phase == WARM_UP → TRUE.
## The GSM floor (WORKOUT_ACTIVE/COMBAT_ACTIVE/BOSS_ENCOUNTER) is NOT a Formula 2
## suppression term — only SET_ACTIVE/BOOTING/SUSPENDED/LOOT_DROP suppress.
## A notification while WORKOUT_ACTIVE-but-resting (phase != SET_ACTIVE) is fine.
## This is the key divergence between Formula 1 (input) and Formula 2 (notification).
func test_formula2_workout_active_warmup_permits() -> void:
	_fake_gsm.set_state(_GS.WORKOUT_ACTIVE)
	_fake_wst.set_phase(_WP.WARM_UP)
	var policy := _make_policy()
	assert_true(
		policy.is_notification_permitted(),
		"Formula 2: WORKOUT_ACTIVE(GSM) + WARM_UP must PERMIT — GSM floor is NOT a "
		+ "notification-suppression term (only SET_ACTIVE/lifecycle/ceremony suppress)"
	)


## Formula 2 contrast: WORKOUT_ACTIVE(GSM) + SET_ACTIVE phase → false.
## Confirms the suppression comes from the SET_ACTIVE phase term, not the GSM state.
func test_formula2_workout_active_set_active_suppressed() -> void:
	_fake_gsm.set_state(_GS.WORKOUT_ACTIVE)
	_fake_wst.set_phase(_WP.SET_ACTIVE)
	var policy := _make_policy()
	assert_false(
		policy.is_notification_permitted(),
		"Formula 2: WORKOUT_ACTIVE + SET_ACTIVE must suppress (SET_ACTIVE phase term)"
	)


# ============================================================================
# H1 — WORKOUT_COMPLETE milestone window permit (intentional per GDD H1)
# ============================================================================

## H1: phase == WORKOUT_COMPLETE + GSM == IDLE → true (milestone window open).
## WORKOUT_COMPLETE is a WST phase (not a GSM state) and is NOT in any suppression
## set — milestone notifications (e.g. #8 streak) may fire post-workout.
func test_h1_workout_complete_permits_notification() -> void:
	_fake_gsm.set_state(_GS.IDLE)
	_fake_wst.set_phase(_WP.WORKOUT_COMPLETE)
	var policy := _make_policy()
	assert_true(
		policy.is_notification_permitted(),
		"H1: WORKOUT_COMPLETE + IDLE must permit notifications (milestone window)"
	)


# ============================================================================
# B1 sentinel — unknown enum int → fail-closed (consistency with is_input_permitted)
# ============================================================================

## B1: GSM returns an invalid out-of-range int (999) → false (fail-closed).
## Notifications must also fail-closed on unknown enum, mirroring is_input_permitted.
func test_b1_sentinel_unknown_gsm_int_suppresses() -> void:
	_fake_gsm.set_state(999)  # not a valid GameState enum member
	_fake_wst.set_phase(_WP.IDLE)
	var policy := _make_policy()
	assert_false(
		policy.is_notification_permitted(),
		"B1 sentinel: unknown GSM int 999 must suppress notifications (fail-closed, not fail-OPEN)"
	)


## B1: WST returns an invalid out-of-range int (999) → false (fail-closed).
func test_b1_sentinel_unknown_wst_int_suppresses() -> void:
	_fake_gsm.set_state(_GS.IDLE)
	_fake_wst.set_phase(999)  # not a valid WorkoutPhase enum member
	var policy := _make_policy()
	assert_false(
		policy.is_notification_permitted(),
		"B1 sentinel: unknown WST int 999 must suppress notifications (fail-closed)"
	)


# ============================================================================
# AC-10-style null guard — null dependency ref → false (fail-closed, EC-2)
# ============================================================================

## AC-10 style: _gsm = null → is_notification_permitted() false (fail-closed).
## Uses reflection set() to simulate post-construction null without the _init assert.
func test_null_gsm_suppresses_notification() -> void:
	var policy := _make_policy()
	policy.set(&"_gsm", null)
	assert_false(
		policy.is_notification_permitted(),
		"Null guard: null _gsm must cause is_notification_permitted() false (fail-closed, EC-2)"
	)


## AC-10 style: _wst = null → is_notification_permitted() false (fail-closed).
func test_null_wst_suppresses_notification() -> void:
	var policy := _make_policy()
	policy.set(&"_wst", null)
	assert_false(
		policy.is_notification_permitted(),
		"Null guard: null _wst must cause is_notification_permitted() false (fail-closed, EC-2)"
	)


# ============================================================================
# AC-18a — AttentionBudget.is_critical_notification() closed allowlist membership
#
# AttentionBudget is not yet registered as an autoload (Story 004). Instantiate
# the node directly via preload, same as the Story 001 create_policy test.
# ============================================================================

## AC-18a: disconnect_warning + save_failed → true; non-critical / empty → false.
func test_ac18a_is_critical_notification_membership() -> void:
	# Arrange — instantiate AttentionBudget node (not registered autoload yet)
	var budget_node := preload("res://src/autoload/attention_budget.gd").new()
	add_child_autofree(budget_node)

	# Act + Assert — allowlist members
	assert_true(
		budget_node.is_critical_notification(&"disconnect_warning"),
		"AC-18a: disconnect_warning must be critical"
	)
	assert_true(
		budget_node.is_critical_notification(&"save_failed"),
		"AC-18a: save_failed must be critical"
	)

	# Non-critical kind → false
	assert_false(
		budget_node.is_critical_notification(&"streak_nag"),
		"AC-18a: streak_nag must NOT be critical (non-allowlisted = The Nag Engine if leaked)"
	)

	# Empty StringName → false
	assert_false(
		budget_node.is_critical_notification(&""),
		"AC-18a: empty StringName must NOT be critical"
	)


# ============================================================================
# CRITICAL_NOTIFICATION_KINDS — exact closed allowlist size + content
# ============================================================================

## Allowlist: CRITICAL_NOTIFICATION_KINDS == [&"disconnect_warning", &"save_failed"].
## Exact-match guard so any silent addition (The Nag Engine leak) is caught.
func test_critical_notification_kinds_exact_allowlist() -> void:
	# Arrange
	var budget_node := preload("res://src/autoload/attention_budget.gd").new()
	add_child_autofree(budget_node)
	var expected: Array[StringName] = [&"disconnect_warning", &"save_failed"]

	# Act + Assert — exact content (catches additions/removals/reordering)
	assert_eq(
		budget_node.CRITICAL_NOTIFICATION_KINDS,
		expected,
		"CRITICAL_NOTIFICATION_KINDS must be exactly [disconnect_warning, save_failed] (closed allowlist)"
	)
	assert_eq(
		budget_node.CRITICAL_NOTIFICATION_KINDS.size(),
		2,
		"CRITICAL_NOTIFICATION_KINDS must contain exactly 2 critical kinds"
	)
