## BossSpawnContext — frozen player snapshot for boss scaling (Story 002, AC-22)
##
## Driving GDD:
##   * design/gdd/boss-system.md — Rule 5 (CF-3 snapshot caching) + AC-22
##     (「BossSpawnContext resource that wraps single snapshot + pass to both formulas」)
##
## Driving Story: production/epics/boss-system/story-002-boss-instance-contract.md
## Implementing TR: TR-boss-004 (snapshot frozen at COMMITTED)
##
## WHY this exists (NOT CombatResolver.StatSnapshot):
## The shipped `CombatResolver.StatSnapshot` (combat_resolver.gd:142) carries ONLY
## `attack_power` + `crit_chance` — Formula 1 also needs `workout_duration_sec`
## (bootstrap ramp) and Formula 2 needs `max_hp`. This richer context is the single
## frozen-at-COMMITTED reference both formulas read (CF-3 / AC-22 object identity) —
## the #14 EnemyDirector caller populates it at BossAnchor commit (StatSystem.get_stat
## MAX_HP / ATTACK_POWER + #9 WorkoutSummaryRO duration) and passes it to spawn_boss.
##
## Transient RefCounted (like CombatResolver.StatSnapshot) — frozen, never mutated
## post-spawn; GC-released when the BossInstance frees (no explicit clear API).
class_name BossSpawnContext extends RefCounted

## Player ATTACK_POWER at COMMITTED (0 -> Formula 1 first-session bootstrap).
var attack_power: float = 0.0

## Player MAX_HP at COMMITTED (Formula 2 damage scaling). Floored at 1 like #11.
var max_hp: int = 1

## Player CRIT_CHANCE at COMMITTED (carried for completeness / future use).
var crit_chance: float = 0.0

## #9 WorkoutSummaryRO workout duration (seconds) — Formula 1 bootstrap ramp only.
var workout_duration_sec: float = 0.0
