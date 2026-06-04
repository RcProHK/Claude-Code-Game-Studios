## Integration tests — AttentionBudgetPolicy Story 006
## Phone-lock / app-switch recovery (hard-contract #4)
##
## ## Thesis: ZERO new production code
##
## Story 006 adds NO production code. Recovery is an architectural consequence of
## Story 002's pure-pull derivation (GDD Rule 2): is_input_permitted() holds NO
## cached gate state, so a suspend→resume sequence cannot leave a stale lock or a
## stale open. The gate always reflects the CURRENT live (GSM state, WST phase).
##
## These integration tests PROVE that property by driving a SINGLE policy instance
## through a suspend→resume sequence — mutating the fake GSM/WST enums between
## queries WITHOUT emitting any signal and WITHOUT any reset/restore call — and
## asserting is_input_permitted() is automatically correct at each step.
##
## The single shared policy instance is deliberate: it demonstrates that the SAME
## object, never reset, yields the right answer across the lifecycle. If recovery
## required a reset hook, these tests would be impossible to write without calling it.
##
## Coverage (GDD EC-6 / EC-7 / Rule 2 / Story 006 AC-11):
##   AC-11      — suspend mid-set → SUSPENDED → resume to non-floor REST_PERIOD → true
##                (the core no-stale-lock proof: suspend-time lock left NO residue)
##   AC-11 edge — resume to floor COMBAT_ACTIVE → false (current-truth floor lock,
##                NOT a stale lock — proves floor-lock ≠ stale-lock)
##   EC-6       — suspend@SET_ACTIVE → SUSPENDED → resume@REST_PERIOD → true
##                (the SET_ACTIVE mid-set lock during suspend fully cleared)
##   EC-7       — resume where #9 reconciles phase=SET_ACTIVE → false
##                (#33 honors #9's reconciled phase; does not second-guess #9)
##   Pure-pull  — every transition above happens via raw enum mutation, no signal
##                (this is the mechanism that makes recovery automatic; ties AC-04
##                 into the recovery context)
##
## Out of scope (per story): WST snapshot reconcile itself (#9), #1 SUSPENDED
## detection, #20 bfcache reconcile, real OS suspend / browser bfcache. This file
## only proves the #33 input-policy layer is correct under a mocked suspend/resume.
##
## Framework: GUT (Godot Unit Testing) v9.x
## NOTE: GUT collects test_*.gd files only; *_test.gd suffix is silently ignored.
##       All test functions must use the test_ prefix.
extends GutTest


# ============================================================================
# Stub classes — reused from the Story 002 unit-test pattern
# (test_input_permitted_derivation.gd). Duck-typed surface, mutable WITHOUT
# emitting any signal so the test can simulate a suspend/resume sequence purely
# by overwriting the returned enum value (AC-04 pure-pull mechanism).
# ============================================================================

## Minimal fake GSM — duck-typed surface: get_current_state().
## set_state() mutates the backing int with NO signal — this is what lets the
## test simulate "OS resume restored the GSM state" without any real lifecycle.
class _FakeGSM:
	extends RefCounted
	var _state: int = GameStateMachine.GameState.IDLE

	func get_current_state() -> int:
		return _state

	func set_state(s: int) -> void:
		_state = s


## Minimal fake WST — duck-typed surface: get_current_phase().
## set_phase() mutates the backing int with NO signal — simulates "#9 reconciled
## the WorkoutPhase from its snapshot after resume" without any real reconcile.
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
# Test fixtures — ONE policy instance per test, driven through the lifecycle.
# ============================================================================

var _fake_gsm: _FakeGSM
var _fake_wst: _FakeWST
var _policy: AttentionBudgetPolicy


func before_each() -> void:
	_fake_gsm = _FakeGSM.new()
	_fake_wst = _FakeWST.new()
	# Single shared instance — never reset across the suspend/resume sequence.
	_policy = AttentionBudgetPolicy.new(_fake_gsm, _fake_wst)


## Helper: simulate one lifecycle step by overwriting both fake enums (NO signal),
## then return the freshly derived gate value. The absence of any reset/restore
## call here is the whole point — recovery is automatic.
func _step(gsm_state: int, wst_phase: int) -> bool:
	_fake_gsm.set_state(gsm_state)
	_fake_wst.set_phase(wst_phase)
	return _policy.is_input_permitted()


# ============================================================================
# AC-11 — core recovery: suspend mid-set → resume to non-floor REST_PERIOD → true
#
# The three-step sequence is the heart of Story 006. Step 3 is the proof:
# after resume to a NON-floor state, input is permitted — the suspend-time lock
# left NO residue. The same _policy object derives all three answers with no reset.
# ============================================================================

## AC-11: COMBAT_ACTIVE/SET_ACTIVE (false) → SUSPENDED (false) → REST_PERIOD/REST_PERIOD (true).
## Step 3 true is the no-stale-lock proof: the floor+mid-set lock that was in effect
## at suspend time did NOT persist into the non-floor resume state.
func test_ac11_suspend_mid_set_resume_non_floor_clears_lock() -> void:
	# Step 1 — mid-set, in combat: floor lock + SET_ACTIVE refinement → false.
	assert_false(
		_step(_GS.COMBAT_ACTIVE, _WP.SET_ACTIVE),
		"AC-11 step 1: COMBAT_ACTIVE + SET_ACTIVE (mid-set) must be false (floor + refinement lock)"
	)

	# Step 2 — phone locked: GSM drives to SUSPENDED → false (Rule 4 lifecycle).
	assert_false(
		_step(_GS.SUSPENDED, _WP.SET_ACTIVE),
		"AC-11 step 2: SUSPENDED must be false (Rule 4 lifecycle lock during suspend)"
	)

	# Step 3 — resume to a NON-floor state, #9 reconciled phase=REST_PERIOD.
	# CORE PROOF: input is permitted. The suspend-time lock left no residue — the
	# gate reflects current truth, not a remembered lock.
	assert_true(
		_step(_GS.REST_PERIOD, _WP.REST_PERIOD),
		"AC-11 step 3 (CORE): resume to non-floor REST_PERIOD must be true — "
		+ "the suspend-time lock left NO stale residue (Rule 2 pure-pull)"
	)


## AC-11 edge (floor-resume contrast): resume to COMBAT_ACTIVE → false.
## This is the contrast case proving floor-lock and stale-lock are DIFFERENT things:
## the false here is the CURRENT-TRUTH floor lock (we genuinely resumed into combat),
## NOT a leftover lock from the suspend. Same sequence as AC-11 but resume lands on
## a floor state instead of a rest state.
func test_ac11_edge_resume_to_floor_is_current_truth_not_stale() -> void:
	# Step 1 — mid-set in combat → false.
	assert_false(
		_step(_GS.COMBAT_ACTIVE, _WP.SET_ACTIVE),
		"AC-11 edge step 1: COMBAT_ACTIVE + SET_ACTIVE must be false"
	)

	# Step 2 — suspended → false.
	assert_false(
		_step(_GS.SUSPENDED, _WP.SET_ACTIVE),
		"AC-11 edge step 2: SUSPENDED must be false (Rule 4)"
	)

	# Step 3 — resume genuinely lands back in COMBAT_ACTIVE (still mid-fight).
	# false here = current-truth floor lock, NOT a stale lock. Proves the two are
	# distinct: had it been a stale lock, the non-floor resume case above would
	# also be false — but it is true. The gate tracks live state, not history.
	assert_false(
		_step(_GS.COMBAT_ACTIVE, _WP.REST_PERIOD),
		"AC-11 edge step 3: resume to COMBAT_ACTIVE must be false — this is the "
		+ "CURRENT-TRUTH floor lock, NOT a stale lock (contrast with non-floor true)"
	)


# ============================================================================
# EC-6 — phone-lock mid-set leaves no stale lock
#
# Drives the WORKOUT_ACTIVE/SET_ACTIVE variant (GDD EC-6 uses WORKOUT_ACTIVE as
# the "mid-set" example). Proves the SET_ACTIVE lock held during suspend is fully
# cleared after a resume into a non-floor rest state.
# ============================================================================

## EC-6: WORKOUT_ACTIVE/SET_ACTIVE (false) → SUSPENDED (false) → REST_PERIOD/REST_PERIOD (true).
## Proves the SET_ACTIVE mid-set lock present at suspend time completely cleared on resume.
func test_ec6_suspend_at_set_active_no_stale_lock_after_resume() -> void:
	# Suspend at SET_ACTIVE during an active workout → false (floor + refinement).
	assert_false(
		_step(_GS.WORKOUT_ACTIVE, _WP.SET_ACTIVE),
		"EC-6: WORKOUT_ACTIVE + SET_ACTIVE (mid-set) must be false before suspend"
	)

	# Phone locks → SUSPENDED → false.
	assert_false(
		_step(_GS.SUSPENDED, _WP.SET_ACTIVE),
		"EC-6: SUSPENDED must be false during phone-lock (Rule 4)"
	)

	# Resume: #9 reconciled phase=REST_PERIOD, GSM=REST_PERIOD → true.
	# The SET_ACTIVE lock that was active at suspend time is gone — no residue.
	assert_true(
		_step(_GS.REST_PERIOD, _WP.REST_PERIOD),
		"EC-6: resume to REST_PERIOD/REST_PERIOD must be true — the suspend-time "
		+ "SET_ACTIVE mid-set lock fully cleared (no stale lock, Rule 2)"
	)


# ============================================================================
# EC-7 — resume reconciles to SET_ACTIVE: #33 honors #9, maintains lock
#
# When #9 reconciles the WorkoutPhase snapshot back to SET_ACTIVE (player was
# genuinely mid-set when suspended and the set is still in progress), #33 must
# HONOR that phase and keep the lock — it does NOT second-guess #9 or race to
# open the gate. The lock persists until real rest_started updates #9's phase.
# ============================================================================

## EC-7: resume where #9 reconciles phase=SET_ACTIVE (GSM=IDLE) → false.
## Proves #33 honors #9's reconciled phase and maintains the lock — it does not
## assume "we just resumed, so open the gate". The SET_ACTIVE refinement still bites.
func test_ec7_resume_reconcile_to_set_active_maintains_lock() -> void:
	# Suspend mid-set → false.
	assert_false(
		_step(_GS.WORKOUT_ACTIVE, _WP.SET_ACTIVE),
		"EC-7: WORKOUT_ACTIVE + SET_ACTIVE must be false before suspend"
	)

	# Phone locks → SUSPENDED → false.
	assert_false(
		_step(_GS.SUSPENDED, _WP.SET_ACTIVE),
		"EC-7: SUSPENDED must be false during phone-lock (Rule 4)"
	)

	# Resume: #9 reconciles phase back to SET_ACTIVE; GSM settles to IDLE (set still
	# logically in progress per #9's snapshot). #33 HONORS the SET_ACTIVE phase →
	# WST refinement locks → false. #33 does not second-guess #9.
	assert_false(
		_step(_GS.IDLE, _WP.SET_ACTIVE),
		"EC-7: resume with #9-reconciled phase=SET_ACTIVE must be false — #33 honors "
		+ "#9's reconciled phase and maintains the lock (does not second-guess #9)"
	)


## EC-7 follow-through: after #9 advances phase=REST_PERIOD (real rest started),
## the lock releases on the SAME policy instance — no reset needed.
## Demonstrates the lock is held strictly by #9's phase, released the instant #9 moves.
func test_ec7_lock_releases_when_nine_advances_phase_to_rest() -> void:
	# Resume reconciled to SET_ACTIVE → still locked.
	assert_false(
		_step(_GS.IDLE, _WP.SET_ACTIVE),
		"EC-7 follow-through: reconciled SET_ACTIVE must be false (lock held)"
	)

	# #9 now emits the real rest_started; phase advances to REST_PERIOD.
	# Same _policy object, no reset — gate opens immediately because it pulls live #9.
	assert_true(
		_step(_GS.IDLE, _WP.REST_PERIOD),
		"EC-7 follow-through: once #9 advances phase to REST_PERIOD, gate opens "
		+ "immediately on the same policy instance (lock held by #9's phase, no reset)"
	)


# ============================================================================
# Pure-pull recovery mechanism (Rule 2 / AC-04 in the recovery context)
#
# Explicitly asserts that the entire recovery sequence works through raw enum
# mutation WITHOUT any signal and WITHOUT any reset call. This is the mechanism
# that makes recovery automatic — it is what Story 006 actually relies on.
# ============================================================================

## Pure-pull recovery: a full suspend→resume cycle on one instance, driven only by
## mutating the fakes (no signal, no reset), yields the correct gate at every step.
## This is the architectural proof that Story 006 needs zero recovery code.
func test_pure_pull_full_cycle_no_signal_no_reset_is_automatic() -> void:
	# Pre-suspend: resting, gate open.
	assert_true(
		_step(_GS.REST_PERIOD, _WP.REST_PERIOD),
		"pure-pull: pre-suspend REST_PERIOD must be true (gate open)"
	)

	# Player starts a set: mid-set lock engages purely from the phase mutation.
	assert_false(
		_step(_GS.WORKOUT_ACTIVE, _WP.SET_ACTIVE),
		"pure-pull: SET_ACTIVE engages lock with no signal (live pull)"
	)

	# Phone locks: SUSPENDED lock, again purely from mutation.
	assert_false(
		_step(_GS.SUSPENDED, _WP.SET_ACTIVE),
		"pure-pull: SUSPENDED engages lifecycle lock with no signal"
	)

	# Resume to rest: gate re-opens automatically — no reset, no signal, just the
	# next live pull. This is the entire basis of phone-lock recovery.
	assert_true(
		_step(_GS.REST_PERIOD, _WP.REST_PERIOD),
		"pure-pull: resume re-opens gate automatically via live pull — "
		+ "no reset call, no signal (Rule 2 architectural recovery)"
	)


## Pure-pull integrity: the SAME policy instance survives the whole cycle.
## Asserts the instance is never re-created mid-sequence (sanity-guards the test
## itself — if before_each's single instance were silently replaced, the
## "no reset" claim would be hollow).
func test_pure_pull_same_instance_survives_full_cycle() -> void:
	var instance_id_before: int = _policy.get_instance_id()

	# Run a full suspend/resume cycle.
	_step(_GS.COMBAT_ACTIVE, _WP.SET_ACTIVE)
	_step(_GS.SUSPENDED, _WP.SET_ACTIVE)
	_step(_GS.REST_PERIOD, _WP.REST_PERIOD)

	var instance_id_after: int = _policy.get_instance_id()

	assert_eq(
		instance_id_before,
		instance_id_after,
		"pure-pull integrity: the same policy instance must survive the full "
		+ "suspend/resume cycle (no re-construction = the 'no reset' claim is real)"
	)
