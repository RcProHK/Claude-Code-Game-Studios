class_name OnboardingFormulas
extends RefCounted
## Pure, deterministic Onboarding (#27) gating / timing / resume formulas — no autoload,
## no RNG, no wall-clock (every clock value is passed in by the caller). Onboarding holds
## ZERO gameplay numbers (thin presentation/flow layer, #24 precedent); these functions
## only formalise the three UI gating/timing/resume rules. See design/gdd/onboarding-flow.md
## Formulas 1-3. Integer-ms discipline: callers convert float-sec knobs to int ms once at
## load; every comparison here is integer ms (no float boundary flake).

## FSM states (declaration order = the OnboardingCoordinator enum; DORMANT=0 is the safe
## ordinal-0 default per ADR-0007 Outcome/State convention). Mirrored as constants so the
## pure formula module needs no coordinator import.
const STATE_DORMANT: int = 0
const STATE_WELCOME: int = 1
const STATE_PREVIEW: int = 2
const STATE_COACHING: int = 3
const STATE_COMPLETE: int = 4

## Step indices for the four per-step latches (Rule 2).
const STEP_CONNECT: int = 0
const STEP_PREVIEW: int = 1
const STEP_CLASS: int = 2
const STEP_FIRST_DROP: int = 3


## Formula 1 — may_show (coach-mark display gate, Rule 4 / AC-10). A coach-mark for `step`
## may show this frame iff: not DORMANT, the step's latch is unset, the game is NOT in a
## workout-critical GSM state (WORKOUT_ACTIVE/REST_PERIOD/LOOT_DROP — the caller resolves
## membership against the live GSM enum and passes the boolean), and no other coach-mark is
## visible (single-slot discipline). Workout-critical ⇒ always false (Pillar 2 命脈).
static func may_show(
		fsm_state: int, latch_done: bool,
		gsm_is_workout_critical: bool, other_coachmark_visible: bool) -> bool:
	return (fsm_state != STATE_DORMANT) \
		and (not latch_done) \
		and (not gsm_is_workout_critical) \
		and (not other_coachmark_visible)


## Formula 2 — auto-dismiss countdown (Rule 4 / AC-11/12). A shown coach-mark is dismissed
## when the player tapped OR the auto-dismiss window elapsed (monotonic ms, injected clock).
static func is_dismissed(now_ms: int, shown_at_ms: int, auto_dismiss_ms: int, tapped: bool) -> bool:
	return tapped or ((now_ms - shown_at_ms) >= auto_dismiss_ms)


## Visibility = shown AND not dismissed.
static func is_visible(shown: bool, now_ms: int, shown_at_ms: int, auto_dismiss_ms: int, tapped: bool) -> bool:
	return shown and not is_dismissed(now_ms, shown_at_ms, auto_dismiss_ms, tapped)


## Defer-expiry (EC-12 / AC-13). A coach-mark deferred (workout-critical) longer than
## COACH_MAX_DEFER_MS is silently latched — stale teaching is worse than none (Pillar 2).
static func defer_expired(now_ms: int, pending_since_ms: int, max_defer_ms: int) -> bool:
	return (now_ms - pending_since_ms) >= max_defer_ms


## Formula 3 — boot resume state selection (Rule 7 / States §boot resume). Pure decision over
## the persisted latches; completed-first (EC-08 corruption guard). Four-steps-but-no-completed
## (crash window, EC-09) resolves to COMPLETE → the coordinator self-heals by writing completed.
static func resume_state(
		completed: bool, step_connect: bool, step_preview: bool,
		step_class: bool, step_first_drop: bool) -> int:
	if completed:
		return STATE_DORMANT
	if not step_connect:
		return STATE_WELCOME
	if not step_preview:
		return STATE_PREVIEW
	if (not step_class) or (not step_first_drop):
		return STATE_COACHING
	return STATE_COMPLETE
