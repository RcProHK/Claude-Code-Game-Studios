## AttackPatternResource — one boss attack pattern (data-driven, per Rule 6)
##
## Driving GDD:
##   * design/gdd/boss-system.md — Rule 6 (Attack Pattern System) + Formula 3
##
## Governing ADR:
##   * ADR-0001 (Web Export Budget Caps) — boss content is data-driven .tres
##
## Driving Story: production/epics/boss-system/story-001-boss-template-schema.md
## Implementing TR: TR-boss-001 (schema), TR-boss-005 (Formula 3 consumes these)
##
## A boss cycles through its `BossTemplate.attack_patterns` array via the
## deterministic anti-spam selection of Formula 3 (Story 005). This resource is
## pure data — it carries no behaviour. `damage_multiplier` is multiplied with
## the Formula 2 `boss_attack_damage` (Story 004) at attack-resolution time.
class_name AttackPatternResource extends Resource


## Stable identifier for this pattern. Formula 3 anti-spam compares
## `pattern_id` against `_last_emitted_pattern_id` to guarantee「no same pattern
## twice in a row」when ≥ 2 patterns exist (boss-system.md Rule 6 + EC-11).
@export var pattern_id: StringName = &""


## Pre-attack windup duration (seconds). The `"telegraph"` animation plays for
## this long on ATTACKING-state entry before the hit resolves.
@export var telegraph_duration_sec: float = 0.5


## Hit detection radius (world-space pixels) for this pattern.
@export var hit_radius_px: float = 0.0


## Per-pattern damage scalar, multiplied with the Formula 2 `boss_attack_damage`
## base number (Story 004). Signature attacks use 1.5+. Clamped to [0.5, 2.5] at
## Formula 2 invocation (EC-08 typo guard) — the value here is the authored intent.
@export var damage_multiplier: float = 1.0


## Cooldown (seconds) after this pattern fires before the next attack may begin.
@export var cooldown_sec: float = 2.0


## Name of the AnimationPlayer animation to play for this pattern. Must exist in
## the boss's SpriteFrames / AnimationPlayer library as `attack_<pattern_id>`
## (BossInstance required-animation contract, Story 002).
@export var animation_name: StringName = &""
