## ZoneUnlockCondition — #19 per-zone unlock condition (Story 001).
##
## Driving GDD: design/gdd/zone-system.md Rule 1 (schema named `UnlockCondition`
## there — the Zone prefix is global-class_name hygiene only, zero semantic drift).
## ADR-0007 Classification enum: sentinel UNKNOWN LAST; loading an UNKNOWN kind
## is a config error (EC-6) — zero-default fabrication FORBIDDEN.
##
## P1/P2 rulings (Pass 1): STREAK_MILESTONE and PR_MILESTONE were REMOVED from
## this enum — streak gating is mathematically unreachable for 3x/week players
## (EG-4) and the PR-count axis was vetoed (v0.2 ratifies Σmagnitude PR_SCORE
## with a float threshold before any PR kind returns).
class_name ZoneUnlockCondition extends Resource


enum Kind { ALWAYS, WORKOUT_COUNT, UNKNOWN }

@export var kind: Kind = Kind.UNKNOWN
## WORKOUT_COUNT: training-day count threshold (≥1 — EC-6 validated). ALWAYS ignores it.
@export var threshold: int = 0
