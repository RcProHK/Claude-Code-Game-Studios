## AttentionBudgetPolicy — Pillar 2 input enforcement (#33 Attention Budget epic)
##
## Story 001: injection seam migration — replaces the Story 015 static autoload stub.
##   - Removes static INPUT_BLOCKED_STATES + static GameStateMachine call.
##   - Introduces _init(gsm_ref, wst_ref) untyped DI ctor (GDScript DI seam rule).
##   - Defines all constitutional constants (GDD Tuning Knobs / Constitutional constants table).
##
## Story 002: is_input_permitted() full Formula 1 Hybrid derivation — DONE.
##   - Added B1 sentinel guard (KNOWN_GSM_STATES / KNOWN_WST_PHASES): unknown enum
##     int fails-closed unconditionally, closing the fail-OPEN hole in Story 001.
##   - Finalized derivation: null guard → sentinel guard → NOT(floor OR ceremony
##     OR lifecycle OR refinement). Zero allocating constructs (AC-17a hot-path).
##
## Story 003: is_notification_permitted() full Formula 2 derivation — DONE.
##   - Added B1 sentinel guard (same KNOWN_GSM_STATES / KNOWN_WST_PHASES gate as
##     is_input_permitted): unknown enum int fails-closed, closing the fail-OPEN
##     hole left by the Story 001 placeholder.
##   - Finalized derivation: null guard → sentinel guard → NOT(SET_ACTIVE OR
##     BOOTING OR SUSPENDED OR LOOT_DROP). GSM floor intentionally NOT suppressed
##     (Formula 2 only mutes mid-set + lifecycle + ceremony). Zero allocation.
##   - CRITICAL_NOTIFICATION_KINDS + is_critical_notification() live on the
##     AttentionBudget autoload (src/autoload/attention_budget.gd).
##
## Driving GDD: design/gdd/attention-budget-policy.md (Approved 2026-06-04)
## Governing ADR: ADR-0006 Contract 13 (IInputPolicy), Contract 14 (MockInputPolicy spy)
##
## ## DI seam note (GDScript DI seam rule)
## _gsm and _wst refs are stored UNTYPED (Variant). Typed `Node` or `GameStateMachine`
## params would cause a GDScript compile-time member-check failure because the autoload
## type is not resolvable at parse time in all hosting contexts. Store as plain Variant
## and rely on the duck-typed assert in _init to catch wrong refs at construction time.
class_name AttentionBudgetPolicy extends IInputPolicy


# ============================================================================
# Constitutional constants — GDD Tuning Knobs / Constitutional constants table.
# These are constitutional law (Pillar 2); modification requires design review.
# Named constants are referenced in Formula 1 / 2; no literal hardcoding.
# ============================================================================

## B1 sentinel set: all known GSM GameState enum integer values.
## If a future GameState is added, this MUST be updated in lockstep or
## Formula 1 sentinel guard will fail-closed on the new state (Pillar 2
## constitutional NO is intentional: over-gate > stale-enum-fail-open).
const KNOWN_GSM_STATES: Array[int] = [
	GameStateMachine.GameState.BOOTING,
	GameStateMachine.GameState.DISCONNECTED,
	GameStateMachine.GameState.IDLE,
	GameStateMachine.GameState.WORKOUT_ACTIVE,
	GameStateMachine.GameState.REST_PERIOD,
	GameStateMachine.GameState.COMBAT_ACTIVE,
	GameStateMachine.GameState.BOSS_ENCOUNTER,
	GameStateMachine.GameState.LOOT_DROP,
	GameStateMachine.GameState.SUSPENDED,
]

## B1 sentinel set: all known WST WorkoutPhase enum integer values.
## Must be kept in sync with WorkoutStateTracker.WorkoutPhase.
const KNOWN_WST_PHASES: Array[int] = [
	WorkoutStateTracker.WorkoutPhase.IDLE,
	WorkoutStateTracker.WorkoutPhase.WARM_UP,
	WorkoutStateTracker.WorkoutPhase.SET_ACTIVE,
	WorkoutStateTracker.WorkoutPhase.REST_PERIOD,
	WorkoutStateTracker.WorkoutPhase.WORKOUT_COMPLETE,
]

## EC-2 / EC-17: null dependency → unconditional fail-closed. Constitutional const —
## must NOT be a var or exported. Runtime mutation = Pillar 2 constitutional breach.
## false would mean a null ref causes a null method-call crash, not safe fail-open.
const FAIL_CLOSED_ON_NULL_DEP: bool = true

## Rule 3 GSM floor (憲法強制鎖): states that unconditionally block input.
## Phase cannot override. Corresponds to the old stub's INPUT_BLOCKED_STATES,
## extended by Formula 1 to be one named set among several.
const GSM_FLOOR_LOCKED_STATES: Array[int] = [
	GameStateMachine.GameState.WORKOUT_ACTIVE,
	GameStateMachine.GameState.COMBAT_ACTIVE,
	GameStateMachine.GameState.BOSS_ENCOUNTER,
]

## Rule 3b ceremony lock: loot-reveal ceremony locks surroundings.
## Loot modal dismiss tap handled via exempt handler (Rule 6 pattern, #21).
const CEREMONY_LOCKED_STATES: Array[int] = [
	GameStateMachine.GameState.LOOT_DROP,
]

## Rule 4 lifecycle safety gate: system not ready or reconciling.
const LIFECYCLE_LOCKED_STATES: Array[int] = [
	GameStateMachine.GameState.BOOTING,
	GameStateMachine.GameState.SUSPENDED,
]

## Rule 3 WST refinement: phases that block input (only tightens, never loosens).
## SET_ACTIVE = mid-set window — zero player interactions (hard-contract #1).
const INPUT_LOCKED_PHASES: Array[int] = [
	WorkoutStateTracker.WorkoutPhase.SET_ACTIVE,
]

## Hard-contract #1 constitutional 0 — documents the Pillar 2 red line.
## Not a tuning knob: removing SET_ACTIVE from INPUT_LOCKED_PHASES = Pillar 2 death.
const MAX_SET_ACTIVE_INTERACTIONS: int = 0


# ============================================================================
# Private DI refs — UNTYPED (Variant) per GDScript DI seam rule.
# Duck-typed assert in _init catches wrong refs at construction time.
# ============================================================================
var _gsm  ## GameStateMachine autoload ref (untyped — see DI seam note above)
var _wst  ## WorkoutStateTracker autoload ref (untyped — see DI seam note above)


## Constructor — injects the two live dependency refs.
##
## Both params are intentionally UNTYPED (Variant). Typed Node params cause a
## GDScript compile-time member-check failure in some hosting contexts (GDScript
## DI seam rule; reference_gdscript_di_seam memory). Duck-typed asserts below
## move wrong-ref errors to construction time instead of a silent query-time crash.
##
## AC-21: duck-typed guard asserts correct method surface at construction.
func _init(gsm_ref, wst_ref) -> void:
	assert(
		gsm_ref != null and gsm_ref.has_method(&"get_current_state"),
		"AttentionBudgetPolicy: gsm_ref missing get_current_state — wrong ref or arg order?"
	)
	assert(
		wst_ref != null and wst_ref.has_method(&"get_current_phase"),
		"AttentionBudgetPolicy: wst_ref missing get_current_phase — wrong ref or arg order?"
	)
	_gsm = gsm_ref
	_wst = wst_ref


## Returns true if input events should be processed in the current context.
##
## Full Formula 1 Hybrid derivation (GDD Formula 1, finalized Story 002):
##
##   1. Null guard (highest precedence, EC-2):
##      If either dependency ref is null → unconditional false (fail-closed).
##      FAIL_CLOSED_ON_NULL_DEP is a constitutional const true; null ref → null
##      method call crash, NOT safe fail-open.
##
##   2. B1 sentinel guard (Pillar 2 constitutional NO, EC-16):
##      If gsm_state not in KNOWN_GSM_STATES or wst_phase not in KNOWN_WST_PHASES
##      → false. An unknown/future enum integer not covered by any lock set would
##      fall through to the derivation and return true (fail-OPEN). The sentinel
##      blocks that hole: unknown enum int → fail-closed unconditionally.
##      Implementors: update KNOWN_GSM_STATES / KNOWN_WST_PHASES in lockstep
##      whenever GameState or WorkoutPhase gains a new member.
##
##   3. Hybrid derivation — NOT(floor OR ceremony OR lifecycle OR refinement):
##      - GSM floor (Rule 3): WORKOUT_ACTIVE/COMBAT_ACTIVE/BOSS_ENCOUNTER → false;
##        WST phase cannot override (憲法強制鎖).
##      - Ceremony lock (Rule 3b): LOOT_DROP → false; surroundings locked, loot
##        modal dismiss tap is handled via exempt handler (#21, Rule 6 pattern).
##      - Lifecycle lock (Rule 4): BOOTING/SUSPENDED → false (system not ready).
##      - WST refinement (Rule 3): SET_ACTIVE → false; tightens only, never loosens.
##
## AC-10 (EC-2): null ref → unconditional false.
## AC (B1 sentinel, EC-16): unknown enum int → unconditional false (fail-closed).
## AC-17a (hot-path perf): zero allocating constructs — no inline []/{}/.new()/
##   string concat/closure. Two local int vars + const-array `in` membership only.
## AC-04 (pure-pull, Rule 2): no cached gate state; live values read on every call.
func is_input_permitted() -> bool:
	# Null guard — highest precedence (fail-closed; EC-2 / FAIL_CLOSED_ON_NULL_DEP).
	if _gsm == null or _wst == null:
		return false

	# Pull live enum values into typed locals — zero allocation (int copy only).
	var gsm_state: int = _gsm.get_current_state()
	var wst_phase: int = _wst.get_current_phase()

	# B1 sentinel guard (EC-16): unknown/out-of-range enum int → fail-closed.
	# An int not in KNOWN_* would not match any lock set → derivation returns true
	# (fail-OPEN), violating Pillar 2. Block it here unconditionally.
	if gsm_state not in KNOWN_GSM_STATES or wst_phase not in KNOWN_WST_PHASES:
		return false

	# Hybrid derivation (Formula 1): NOT(floor OR ceremony OR lifecycle OR refinement).
	# All lock sets are pre-built consts — no allocation at call time.
	return not (
		gsm_state in GSM_FLOOR_LOCKED_STATES
		or gsm_state in CEREMONY_LOCKED_STATES
		or gsm_state in LIFECYCLE_LOCKED_STATES
		or wst_phase in INPUT_LOCKED_PHASES
	)


## Returns true if non-critical notifications are permitted in the current context.
##
## Full Formula 2 derivation (GDD Formula 2 / Rule 7, finalized Story 003):
##
##   is_notification_permitted() =
##       NOT ( wst_phase == SET_ACTIVE
##             OR gsm_state == BOOTING
##             OR gsm_state == SUSPENDED
##             OR gsm_state == LOOT_DROP )
##
##   1. Null guard (highest precedence, EC-2):
##      Either dependency ref null → unconditional false (fail-closed). Same
##      principle as is_input_permitted; null ref → null method call crash,
##      NOT safe fail-open.
##
##   2. B1 sentinel guard (Pillar 2 constitutional NO, EC-16):
##      Unknown/out-of-range gsm_state or wst_phase int → false. An enum int not
##      covered by any suppression set would fall through and return true
##      (fail-OPEN), leaking a notification in an unknown context. Notifications
##      fail-closed on unknown enum for consistency with is_input_permitted and
##      Pillar 2 (over-suppress > stale-enum-fail-open). KNOWN_GSM_STATES /
##      KNOWN_WST_PHASES must be kept in lockstep with the source enums.
##
##   3. Formula 2 suppression — NOT(SET_ACTIVE OR BOOTING OR SUSPENDED OR LOOT_DROP):
##      - SET_ACTIVE phase (Rule 7 / INPUT_LOCKED_PHASES): mid-set window — no toast.
##      - BOOTING / SUSPENDED (Rule 4 lifecycle / LIFECYCLE_LOCKED_STATES): not ready.
##      - LOOT_DROP (Rule 3b ceremony / CEREMONY_LOCKED_STATES): non-critical toast
##        must not cover the loot-reveal ceremony (Formula 2 adds this term over
##        Formula 1 — input allows dismiss, notification does not interrupt).
##      NOTE: the GSM floor (WORKOUT_ACTIVE/COMBAT_ACTIVE/BOSS_ENCOUNTER) is NOT
##      suppressed here — Formula 2 only suppresses SET_ACTIVE + lifecycle +
##      ceremony, NOT the floor. A notification while WORKOUT_ACTIVE-but-resting
##      (phase REST_PERIOD/WARM_UP) is intentionally permitted (GDD: only mid-set
##      and lifecycle/ceremony suppress non-critical notifications).
##
## AC-07 (Rule 7 suppress): SET_ACTIVE phase → false (phase term independent of GSM).
## AC-08 (Rule 7 permit): REST_PERIOD phase + GSM ∉ suppressed set → true.
## AC-10-style null guard (EC-2): null ref → unconditional false.
## AC (B1 sentinel, EC-16): unknown enum int → unconditional false (fail-closed).
## AC-17a (hot-path perf): zero allocating constructs — no inline []/{}/.new()/
##   string concat. Two local int vars + const-array `in` membership only.
## Rule 2 (pure-pull): no cached gate state; live values read on every call.
func is_notification_permitted() -> bool:
	# Null guard — highest precedence (fail-closed; EC-2 / FAIL_CLOSED_ON_NULL_DEP).
	if _gsm == null or _wst == null:
		return false

	# Pull live enum values into typed locals — zero allocation (int copy only).
	var gsm_state: int = _gsm.get_current_state()
	var wst_phase: int = _wst.get_current_phase()

	# B1 sentinel guard (EC-16): unknown/out-of-range enum int → fail-closed.
	# Consistent with is_input_permitted — notifications also fail-closed on unknown
	# enum so an uncovered future state cannot fall through to fail-OPEN (Pillar 2).
	if gsm_state not in KNOWN_GSM_STATES or wst_phase not in KNOWN_WST_PHASES:
		return false

	# Formula 2 suppression: NOT(SET_ACTIVE OR BOOTING OR SUSPENDED OR LOOT_DROP).
	# LIFECYCLE_LOCKED_STATES = {BOOTING, SUSPENDED}; CEREMONY_LOCKED_STATES =
	# {LOOT_DROP}; INPUT_LOCKED_PHASES = {SET_ACTIVE}. All pre-built consts — no
	# allocation at call time. GSM floor is intentionally NOT suppressed (see above).
	return not (
		wst_phase in INPUT_LOCKED_PHASES
		or gsm_state in LIFECYCLE_LOCKED_STATES
		or gsm_state in CEREMONY_LOCKED_STATES
	)
