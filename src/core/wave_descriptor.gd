# WaveDescriptor — one wave archetype's spawn + stat configuration (Story 010).
#
# Driving GDD: design/gdd/enemy-director.md (Rule 12, Wave Archetype Spec).
# Governing ADR: ADR-0007 (enum string-name serialization; faction as int ordinal).
#
# One WaveDescriptor per archetype (STRIKE / CONTROL / MOBILITY), stored under its
# archetype key in EnemyRegistry.archetypes. Data-driven per coding-standards (no
# hardcoded gameplay values in code) — all baseline numbers live in the .tres.
#
# Move-speed field is named `_template_move_speed` to preserve the move-cap CI lint
# contract (tools/ci/check_enemy_template_move_cap.gd, Story 004 AC-31): every
# template move speed in EnemyRegistry.tres must be ≤ ENEMY_MOVE_CAP (420 px/s, INV-7).
class_name WaveDescriptor
extends Resource

## Enemy template ids this archetype may spawn (≥1). Resolved to PackedScenes by
## EnemyRegistry.get_preloaded_pool() in Story 012.
@export var enemy_templates: Array[StringName] = []

## Base spawn interval in seconds (>0). Multiplied by archetype_cadence_mult at runtime.
@export var spawn_cadence_sec: float = 1.0

## Archetype cadence multiplier (Formula 1). STRIKE=1.0 / CONTROL=1.25 / MOBILITY=0.75.
@export var archetype_cadence_mult: float = 1.0

## How many enemies this archetype spawns per completed workout set.
@export var spawn_count_per_set: int = 1

## Outline colour for wave readability (Pillar 2). STRIKE=RED / CONTROL=BLUE / MOBILITY=GREEN.
@export var primary_outline_color: Color = Color(1, 1, 1)

## Faction ordinal (EnemyDirector.Faction). 1 = ENEMY for all combat archetypes.
@export var faction: int = 1

## Per-tier max HP: [tier_1, tier_2, tier_3].
@export var max_hp: Array[int] = []

## Per-tier defense: [tier_1, tier_2, tier_3].
@export var defense: Array[int] = []

## Template move speed (px/s). Named `_template_move_speed` for the move-cap CI lint.
## MUST be ≤ 420 (ENEMY_MOVE_CAP / INV-7).
@export var _template_move_speed: float = 0.0
