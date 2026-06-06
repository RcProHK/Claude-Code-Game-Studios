## BossRegistry — final-boss content registry + spawn selection (Story 008)
##
## Driving GDD:
##   * design/gdd/boss-system.md — Rule 2 (spawn selection) + Rule 10 (low-effort)
##     + Rule 13 (UNKNOWN -> STRIKE fallback)
##
## Governing ADRs:
##   * ADR-0007 (Class Enum — UNKNOWN fallback discipline)
##   * ADR-0005 (effort_score = workout_score; the mini-vs-final classifier)
##
## Driving Story: production/epics/boss-system/story-008-spawn-selection-effort-gate.md
## Implementing TRs: TR-boss-002 (deterministic selection), TR-boss-003 (class mapping)
##
## Authored as `res://data/boss_registry.tres` (designer fills `final_templates`).
## OWNERSHIP (Story 008 design): #16 owns the SELECTION (boss content knowledge);
## #14 EnemyDirector owns the ORCHESTRATION — at BossAnchor COMMITTED it calls
## `select_final_template(dominant_class, effort_score, transition_id)`:
##   * null  -> low effort OR no candidate -> #14 runs its mini-boss wave path (Rule 10)
##   * template -> #14 calls `BossSystem.spawn_boss(template, ...)`
## This is what the GDD means by「the gate check happens at the #14 caller side」—
## #14 invokes #16's pure selector and branches on the result.
class_name BossRegistry extends Resource

## FINAL boss templates (mini-bosses are #14 EnemyTemplate, CRIT-4 split).
@export var final_templates: Array[BossTemplate] = []

## DD#2 mini-vs-final gate (ADR-0005 workout_score scale [0,1]). MUST stay
## byte-identical with #14's value (INV-7 single source of truth; Followup #25
## sync lint — manual check until #14 aligns). Range-guarded [0.15, 0.40].
const MINI_BOSS_EFFORT_THRESHOLD: float = 0.25

# AbilityClass ordinals (mirror AbilitySystem.AbilityClass — ADR-0007).
const _CLASS_STRIKE: int = 0
const _CLASS_UNKNOWN: int = 3


## All FINAL templates of a given class archetype (ordinal).
func query_final(class_archetype: int) -> Array:
	return final_templates.filter(func(t: BossTemplate) -> bool:
		return t.class_archetype == class_archetype)


## Select the FINAL boss template for this workout, or `null` to defer to #14's
## mini-boss path. Pure + deterministic (same inputs -> same template, Pillar 1).
##
## @param dominant_class  #9 WorkoutSummaryRO dominant class ordinal (UNKNOWN=3).
## @param effort_score    ADR-0005 workout_score [0,1] (DD#2 gate, NOT set-count).
## @param transition_id   #14 BossAnchor commit id (deterministic seed).
## @return                A FINAL BossTemplate, or null (low effort OR no candidate -> #14 mini path).
func select_final_template(dominant_class: int, effort_score: float, transition_id: String) -> BossTemplate:
	# Rule 10 / DD#2 — boundary == threshold spawns FINAL (strict-less-than for mini).
	if effort_score < MINI_BOSS_EFFORT_THRESHOLD:
		return null
	# Rule 13 — UNKNOWN never fabricates a synthetic class; it maps to STRIKE EXPLICITLY.
	var selected_class: int = dominant_class if dominant_class != _CLASS_UNKNOWN else _CLASS_STRIKE
	var candidates: Array = query_final(selected_class)
	if candidates.is_empty():
		candidates = query_final(_CLASS_STRIKE)  # EC-03 STRIKE fallback
	if candidates.is_empty():
		return null  # EC-03 — no candidate at all (build error; #14 falls back)
	# Deterministic pick (FNV-1a, cross-platform — same as Formula 3).
	var idx: int = posmod(DeterministicHash.deterministic_hash(transition_id), candidates.size())
	return candidates[idx]
