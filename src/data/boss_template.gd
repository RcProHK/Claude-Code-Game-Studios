## BossTemplate — final-boss content schema (data-driven, immutable at runtime)
##
## Driving GDD:
##   * design/gdd/boss-system.md — Rule 1 (Boss Data Schema) + Rule 13 (UNKNOWN fallback)
##
## Governing ADRs:
##   * ADR-0007 (Class & Domain Enum Convention) — class_archetype mirrors the
##     ONE canonical AbilitySystem.AbilityClass; zero-default fabrication FORBIDDEN
##   * ADR-0001 (Web Export Budget Caps) — reveal_ritual_intensity ≤ #5 ceiling
##
## Driving Story: production/epics/boss-system/story-001-boss-template-schema.md
## Implementing TRs: TR-boss-001 (schema), TR-boss-003 (class archetype mapping)
##
## FINAL bosses only (MVP). Mini-bosses use #14 EnemyTemplate (CRIT-4 split) — the
## STANDARD tier was removed as dead code (CRIT-2). Templates are authored as
## `res://data/bosses/*.tres` and are IMMUTABLE at runtime (Rule 16 NEVER #8) —
## consumers read, never mutate.
##
## WHY class_archetype / loot_guarantee_min_tier are `@export_enum(...) var: int`
## (NOT a typed enum field):
##   * `AbilityClass` is a NESTED enum inside the AbilitySystem autoload
##     (ability_system.gd:49) — autoload-nested enums have NO `@export`-typeable
##     form. `LootEnums.RarityTier` is a nested enum under `class_name LootEnums`.
##   * The codebase pattern (exercise_class_mapping.gd) stores these as ordinal
##     ints. `@export_enum("A","B",...)` gives the designer an inspector dropdown
##     while persisting the ordinal — STRIKE=0…UNKNOWN=3 mirrors AbilityClass,
##     COMMON=0…LEGENDARY=4 mirrors RarityTier.
##   * A SECOND declaration of a `STRIKE|CONTROL|MOBILITY` enum is a CI error
##     (ADR-0007 Validation) — we store the ordinal, never redeclare the enum.
class_name BossTemplate extends Resource


## MVP ships only FINAL (STANDARD removed per CRIT-2; mini-boss = #14 EnemyTemplate
## per CRIT-4). Same-file enums are legal alongside a file-level class_name.
enum BossTier { FINAL }


## Spawn-position constraint interpretation (Rule 14). `arena_constraint_px` is
## read relative to this mode. SPAWN_RELATIVE is the MVP default.
enum ArenaConstraintMode { WORLD_ABSOLUTE, SPAWN_RELATIVE, AVATAR_LEASH }


## Unique identifier (e.g. &"STRIKE_FINAL_01"). Mirrors BossInstance.boss_id.
@export var boss_id: StringName = &""


## Class presentation family — ordinal mirrors `AbilitySystem.AbilityClass`
## (STRIKE=0, CONTROL=1, MOBILITY=2, UNKNOWN=3).
##
## DEFAULT = 3 (UNKNOWN), NOT 0 (STRIKE): per ADR-0007 Family B, ordinal 0 is a
## REAL class value, so a zero-default would silently FABRICATE a STRIKE boss
## from a .tres that forgot to set the field (Pillar 1 violation). Defaulting to
## the UNKNOWN sentinel makes a forgotten field honest — Rule 13 then maps
## UNKNOWN → STRIKE EXPLICITLY at spawn time (Story 008), which is a deliberate
## fallback decision, not a fabricated default.
@export_enum("STRIKE", "CONTROL", "MOBILITY", "UNKNOWN") var class_archetype: int = 3


## Boss tier. FINAL only for MVP (#16 never spawns anything else).
@export var tier: BossTier = BossTier.FINAL


## Pre-scaling baseline HP. Range [50, 500] (Formula 1 reads this directly per
## archetype; e.g. STRIKE final = 200). Story 003 scales it by player ATTACK_POWER.
@export var base_hp: int = 200


## Per-boss defense baseline (input to #13 Formula 1 damage computation).
@export var base_defense: int = 0


## Attack patterns this boss cycles through (Rule 6 + Formula 3 anti-spam).
## MVP final bosses author 2-4 patterns; Formula 3 (Story 005) waives anti-spam
## only when size == 1 (EC-11). An empty array is a config bug (EC-10).
@export var attack_patterns: Array[AttackPatternResource] = []


## The boss's PackedScene (GP-F3). `BossSystem._instantiate_boss()` (Story 007)
## instantiates THIS — never `BossInstance.new()` — because BossInstance needs
## its scene-tree children ($AnimationPlayer/$CollisionShape2D/$Sprite2D/$HitArea2D),
## which a bare `.new()` has none of (its `_ready` asserts would fail).
@export var boss_scene: PackedScene = null


## Visual bundle (sprite / animations / silhouette). Separate file per GP-F2.
@export var visual_template: BossVisualResource = null


## Audio cue id for #4 AudioManager (graceful no-op if #4 absent — MVP placeholder).
@export var audio_template_id: StringName = &""


## Guaranteed loot floor — ordinal = `LootEnums.RarityTier` (COMMON=0…LEGENDARY=4).
## DEFAULT = 2 (RARE) for FINAL bosses (Pass 4 A3.1 — raised UNCOMMON→RARE to
## preserve the dramatic-weight gradient over the mini-boss RARE ceiling). #15
## LootDrop combines this floor with the ADR-0005 rolled tier via `max()`
## (Story 015) — modifiers can push EPIC/LEGENDARY, never below this floor.
@export_enum("COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY") var loot_guarantee_min_tier: int = 2


## Reveal-ritual caller multiplier for #5/#6/#7 (Formula 4, Story 006). Default
## 1.0 for final bosses. Clamped to ≤ MAX_RITUAL_INTENSITY (1.0) < #5
## max_caller_multiplier (1.5) per CI-4 / AC-24.
@export var reveal_ritual_intensity: float = 1.0


## Spawn-position constraint mode (Rule 14). SPAWN_RELATIVE default.
@export var arena_constraint_mode: ArenaConstraintMode = ArenaConstraintMode.SPAWN_RELATIVE


## Constraint extent (world-space px at zoom 1.0). Interpretation depends on
## `arena_constraint_mode` (Rule 14 table). SPAWN_RELATIVE default ≈ (300, 200).
@export var arena_constraint_px: Vector2 = Vector2(300, 200)
