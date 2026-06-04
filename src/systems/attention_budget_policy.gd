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
## Story 003 scope: is_notification_permitted() Formula 2 full derivation.
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
## Story 001 minimal stub: only the null guard is live. Full Formula 2
## derivation (SET_ACTIVE suppression + lifecycle + ceremony suppression) is
## owned by Story 003. CRITICAL_NOTIFICATION_KINDS + is_critical_notification()
## are also Story 003 scope.
func is_notification_permitted() -> bool:
	# Null guard — fail-closed (same principle as is_input_permitted).
	if _gsm == null or _wst == null:
		return false

	# TODO Story 003: full Formula 2 derivation —
	#   NOT (wst_phase == SET_ACTIVE
	#        OR gsm_state == BOOTING
	#        OR gsm_state == SUSPENDED
	#        OR gsm_state == LOOT_DROP)
	# Conservative safe placeholder: suppress when any locked context detected.
	var gsm_state: int = _gsm.get_current_state()
	var wst_phase: int = _wst.get_current_phase()
	return not (
		wst_phase in INPUT_LOCKED_PHASES
		or gsm_state in LIFECYCLE_LOCKED_STATES
		or gsm_state in CEREMONY_LOCKED_STATES
	)
