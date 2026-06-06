## PRDeltaCalc — #18 shared static calc (Story 001).
##
## Driving GDD: design/gdd/pr-detection.md Formula 1 (Epley e1RM, rep-clamped — D7)
## + Formula 3 (pr_delta — source of truth is #11 stat-system.md Formula 2;
## the CALLER computes the delta per #11 L255, this class is that caller's
## single shared implementation — D3: never inline-copy the #11 knobs).
## Driving Story: production/epics/pr-detection/story-001-pr-delta-calc-formulas.md
## Governing ADRs: ADR-0005 (PR_BASE 6.0 PROVISIONAL — #11/ADR-0005 own, read
## via preload, NOT copied); ADR-0011 D-2.1 (server formula parity mirrors
## exactly this Epley: divisor 30.0 float + min(reps, 12) clamp, no reps=1
## special case).
##
## FORMULAS:
##   e1rm     = weight × (1 + min(reps, REP_CAP) / 30.0)
##   pr_delta = PR_BASE × magnitude × (1 − (current_stat / MAX_STAT_VALUE) ^ PR_DIMINISH_EXP)
##
## Worked example (#11 L338-340 golden): compute(12.0, 0.0833) ≈ 0.500.
## Cap guarantee: compute(999.0, any) == 0.0 (diminishing factor hits exact 0).
class_name PRDeltaCalc


## #11 constants read at compile time from the single source — D3 knob-drift guard.
## (PR_BASE / PR_DIMINISH_EXP / MAX_STAT_VALUE are #11-owned; do NOT copy values here.)
const _STAT_SYSTEM := preload("res://src/autoload/stat_system.gd")

## PR-candidate rep clamp (D7 — clamp, NOT skip: e1rm(W, 15) == e1rm(W, 12) is a
## true lower bound; rep-only growth past 12 never moves e1RM, added weight does).
## Knob [8, 15] — #18-owned (GDD Tuning Knobs).
const REP_CAP: int = 12

## Epley extrapolation divisor — LOCKED (changing it is no longer Epley; the
## server baseline parity contract ADR-0011 D-2.1 pins the same 30.0).
## MUST stay a float literal: `reps / 30` would int-divide to 0 for reps < 30.
const E1RM_DIVISOR: float = 30.0


## Formula 1 — estimated 1RM (Epley, rep-clamped).
## reps=1 goes through the same formula (no special case — same ruler for all sets).
## Example: e1rm(60.0, 5) == 70.0; e1rm(100.0, 15) == e1rm(100.0, 12) == 140.0.
static func e1rm(weight: float, reps: int) -> float:
	var effective_reps: int = mini(reps, REP_CAP)
	return weight * (1.0 + float(effective_reps) / E1RM_DIVISOR)


## Formula 3 — pr_delta (#11 Formula 2, caller-computed).
## current_stat is the BASE stat (PR_BREAKTHROUGH only targets base — #18 Rule 6.2);
## magnitude is the clamped pr_magnitude ∈ [0, 2.0].
## At current_stat == MAX_STAT_VALUE the diminishing factor is exactly 0 → delta 0.0
## (the #18 Rule 6.3 short-circuit relies on this exact zero).
## Example: compute(12.0, 0.0833) ≈ 0.500 (#11 worked example).
static func compute(current_stat: float, magnitude: float) -> float:
	var ratio: float = current_stat / _STAT_SYSTEM.MAX_STAT_VALUE
	var diminishing: float = 1.0 - pow(ratio, _STAT_SYSTEM.PR_DIMINISH_EXP)
	return _STAT_SYSTEM.PR_BASE * magnitude * maxf(diminishing, 0.0)
