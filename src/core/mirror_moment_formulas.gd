class_name MirrorMomentFormulas
extends RefCounted
## Pure, deterministic Mirror Moment (#29) gating/selection formulas — no autoload,
## no RNG, no wall-clock except where explicitly passed in. Every tier number is
## supplied by the caller (read from #26 get_evolution_snapshot()); these functions
## NEVER derive a tier (CR-M14 / CI-MM-1). See design/gdd/mirror-moment.md Formulas 1-3.

## Formula 2 content selection result codes (declaration order load-bearing; NONE last
## as the honest-skip default — Pillar 1).
const CONTENT_EVOLUTION: int = 0
const CONTENT_REFLECTION: int = 1
const CONTENT_NONE: int = 2

## CR-M12 resume result codes.
const RESUME_CONTINUE: int = 0
const RESUME_COLLAPSE: int = 1


## Formula 1 — ceremony_arm_check (DORMANT → ARMED gate). cadence window open ∧ has_change
## ∧ not-presented-this-window. `presented_this_window` is the exact negation of
## `cadence_open` (same comparison, single source of truth), so it is folded in here.
static func ceremony_arm_check(
		now_unix: int, last_ceremony_unix: int, cadence_seconds: int,
		pending_evolution: bool, week_had_change: bool) -> bool:
	var cadence_open := (now_unix - last_ceremony_unix) >= cadence_seconds
	var has_change := pending_evolution or week_had_change
	return cadence_open and has_change


## Convenience predicate used by both Formula 1 and CR-M9 once-per-window guard.
static func cadence_open(now_unix: int, last_ceremony_unix: int, cadence_seconds: int) -> bool:
	return (now_unix - last_ceremony_unix) >= cadence_seconds


## Formula 2 — content_tier_selection (ARMED → PRESENTING content choice). Priority
## EVOLUTION > REFLECTION > NONE. NONE is defense-in-depth (Formula 1 has_change gate
## makes it unreachable from ARMED, but a race that clears the flags collapses here).
static func content_tier_selection(pending_evolution: bool, week_had_change: bool) -> int:
	if pending_evolution:
		return CONTENT_EVOLUTION
	if week_had_change:
		return CONTENT_REFLECTION
	return CONTENT_NONE


## Formula 3 — before_after_resolution (show_ghost). EVOLUTION with a real prior tier and
## a non-empty prior sprite → before→after ghost; REFLECTION (same tier) or first-ever
## tier-up (prior_sprite == "") → single hero-pose frame, no ghost (EC-MM-7 / EC-MM-9).
static func should_show_ghost(content: int, prior_tier: int, after_tier: int, prior_sprite: String) -> bool:
	return content == CONTENT_EVOLUTION and prior_tier < after_tier and prior_sprite != ""


## CR-M12 — bfcache/SUSPENDED resume action. Δ ≤ threshold → continue the ceremony;
## Δ > threshold or negative (untrusted clock) → collapse + keep the window marker.
static func resume_action(raw_delta_ms: int, threshold_ms: int) -> int:
	if raw_delta_ms < 0 or raw_delta_ms > threshold_ms:
		return RESUME_COLLAPSE
	return RESUME_CONTINUE
