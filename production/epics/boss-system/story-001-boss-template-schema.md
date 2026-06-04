# Story 001: BossTemplate / BossVisualResource / AttackPatternResource schema

> **Epic**: Boss System
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/boss-system.md` — Rule 1 (Boss Data Schema)
**Requirement**: `TR-boss-001` (BossTemplate Resource schema, immutable @export fields), `TR-boss-003` (class archetype field)

**ADR Governing Implementation**: ADR-0007 (Class & Domain Enum Convention) — primary; ADR-0001 (Web Export Budget — particle/visual fields) secondary
**ADR Decision Summary**: `AbilityClass {STRIKE,CONTROL,MOBILITY,UNKNOWN}` is the ONE canonical class enum (Family B Classification — ordinal load-bearing, zero-default fabrication FORBIDDEN). Boss `class_archetype` mirrors it.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `@export_enum("STRIKE","CONTROL","MOBILITY","UNKNOWN") var class_archetype: int` — Godot 4.5+ enum-export-as-ordinal-int. Autoload-nested enums (`AbilitySystem.AbilityClass`) have NO @export-typeable form → store the ordinal int (mirror ordinals STRIKE=0…UNKNOWN=3). `BossVisualResource` lives in its OWN file `res://src/data/boss_visual_resource.gd` (GP-F2 — one file-level `class_name` per script).

**Control Manifest Rules (Feature layer)**:
- Required: Classification enum fields MUST be explicitly initialised — zero-default FORBIDDEN (ADR-0007 Family B). `class_archetype` default = 0 (STRIKE) is an EXPLICIT designer choice per .tres, not a fabricated fallback.
- Forbidden: a SECOND declaration of a `STRIKE|CONTROL|MOBILITY` enum is a CI error — `class_archetype` stores the AbilitySystem.AbilityClass ordinal, does NOT redeclare the enum.

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-01**: `BossRegistry` loaded with FINAL templates — each template's fields (`boss_id`, `class_archetype`, `tier`, `base_hp`, `base_defense`, `attack_patterns`, `loot_guarantee_min_tier`, `reveal_ritual_intensity`, `boss_scene`, `visual_template`, `arena_constraint_mode/px`) present + types correct + immutable at runtime.
- [ ] `class_archetype` is an `@export_enum("STRIKE","CONTROL","MOBILITY","UNKNOWN") var: int` (ordinal mirrors `AbilitySystem.AbilityClass`); `loot_guarantee_min_tier` is an `@export_enum("COMMON"…"LEGENDARY") var: int` default 2 (RARE).
- [ ] `enum BossTier { FINAL }` and `enum ArenaConstraintMode { WORLD_ABSOLUTE, SPAWN_RELATIVE, AVATAR_LEASH }` declared in the BossTemplate script (same-file enums, legal).
- [ ] `BossVisualResource` declared `class_name BossVisualResource extends Resource` in its OWN file `res://src/data/boss_visual_resource.gd`.
- [ ] `AttackPatternResource` declared `class_name AttackPatternResource extends Resource` (pattern_id / telegraph_duration_sec / hit_radius_px / damage_multiplier / cooldown_sec / animation_name).

---

## Implementation Notes

*From ADR-0007 + GDD Rule 1:*

- `class_name BossTemplate extends Resource`. All gameplay fields `@export`. `class_archetype` + `loot_guarantee_min_tier` use `@export_enum(...) var: int` (NOT a bare nested-enum type — those don't @export). Comment the ordinal mapping.
- BossTemplate, BossVisualResource, AttackPatternResource each get their own `.gd` file (one file-level `class_name` per script — a second `class_name` in the same file is a parse error).
- Templates are `res://data/bosses/*.tres`; immutable at runtime (Rule 16 NEVER #8).
- Do NOT redeclare STRIKE/CONTROL/MOBILITY anywhere — store the ordinal int.

---

## Out of Scope

- **Story 002**: BossInstance runtime scene-tree class + lifecycle.
- **Story 003**: BossFormulas (the formulas that READ these fields).
- BossRegistry validation CI lint (Story 015 / followup-08).

---

## QA Test Cases

- **AC-01**: introspect each FINAL `.tres`
  - Given: a BossRegistry with ≥1 FINAL BossTemplate `.tres`
  - When: load + introspect `@export` fields
  - Then: all required fields present with correct types; `class_archetype ∈ [0,3]`; `loot_guarantee_min_tier ∈ [0,4]`; `tier == FINAL`
  - Edge cases: missing `boss_scene` → caught later (Story 007 `_instantiate_boss` assert); `class_archetype` not explicitly set in .tres → defaults 0 (STRIKE) by EXPLICIT field default (acceptable, not a fabricated runtime fallback)
- **Schema enums**: assert `BossTier` has only `FINAL` (no STANDARD — CRIT-2); `ArenaConstraintMode` has 3 members in declaration order.
- **Separate files**: grep `boss_template.gd` contains exactly ONE `class_name`; `boss_visual_resource.gd` declares `class_name BossVisualResource`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feature/boss_system/test_template_schema.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (schema root)
- Unlocks: Story 002, Story 003, Story 008
