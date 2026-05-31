# Story 010: EnemyRegistry.tres Data File

> **Epic**: Enemy Director
> **Status**: Ready
> **Layer**: Core
> **Type**: Config/Data
> **Estimate**: 2h
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (enum convention — faction, archetype keys)
**ADR Decision Summary**: ADR-0007 mandates string-name serialization for enum fields in resource files; classification enums use declaration-order-load-bearing values; UNKNOWN must be last sentinel.

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-17 [Config|BLOCKING|static]: `assets/data/EnemyRegistry.tres` exists with 3 archetype entries (`STRIKE` / `CONTROL` / `MOBILITY`). Each entry has mandatory fields: `enemy_templates: Array[StringName]` (≥1 entry) / `spawn_cadence_sec: float` (>0) / `archetype_cadence_mult: float` / `spawn_count_per_set: int` / `primary_outline_color: Color` (STRIKE=RED / CONTROL=BLUE / MOBILITY=GREEN) / `faction: int` (ENEMY faction=1). CI lint `check_enemy_registry_schema.gd` passes.
- [ ] (Story-level AC) Wave Archetype Spec baseline values populated per GDD spec:
  - STRIKE: `max_hp=[80, 220, 540]`, `defense=[8, 18, 32]`, `move_speed=120`, `archetype_cadence_mult=1.0`
  - CONTROL: `max_hp=[35, 95, 230]`, `defense=[2, 5, 10]`, `move_speed=90`, `archetype_cadence_mult=1.25`
  - MOBILITY: `max_hp=[55, 145, 360]`, `defense=[4, 10, 20]`, `move_speed=280`, `archetype_cadence_mult=0.75`
  - INV-7: all `move_speed` values ≤ 420 (STRIKE=120 ✓ / CONTROL=90 ✓ / MOBILITY=280 ✓)

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Resource class: `class_name EnemyRegistry extends Resource` with `@export var archetypes: Dictionary` (key: StringName archetype name, value: WaveDescriptor).
- `class_name WaveDescriptor extends Resource` with `@export` fields for all mandatory schema fields.
- Tier arrays (hp, defense) are 3 elements: `[tier_1, tier_2, tier_3]` corresponding to enemy level tiers.
- `primary_outline_color`: STRIKE = `Color(1, 0, 0)` (RED) / CONTROL = `Color(0, 0, 1)` (BLUE) / MOBILITY = `Color(0, 1, 0)` (GREEN).
- `faction: int` = 1 for all enemy archetypes (ENEMY faction per Faction enum Story 001).
- Also create: `class_name EnemyState extends RefCounted` with fields: `instance_id: int`, `enemy_id: StringName`, `hp: float`, `max_hp: float`, `defense: float`, `faction: int`.
- Create `class_name EnemyTemplate extends Resource` with per-archetype template data matching WaveDescriptor fields.
- CI lint `check_enemy_registry_schema.gd` (from Story 003 or written here): validate schema presence and type constraints.
- CI lint `check_enemy_template_move_cap.gd` (Story 004): run and must pass.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003: CI lint scripts that validate boot order (boot order file `project.godot` not this data file)
- Story 004: `check_enemy_template_move_cap.gd` CI script authoring (Story 004 writes the script, this story provides the data file it scans)
- Story 012: Spawn lifecycle that reads from this registry at runtime

---

## QA Test Cases

**AC-17 static**: Run `check_enemy_registry_schema.gd` on `assets/data/EnemyRegistry.tres`. Assert exit code 0. Verify: 3 archetype keys present (`STRIKE`, `CONTROL`, `MOBILITY`); each has required fields; no null values; `faction == 1` for all; `spawn_cadence_sec > 0` for all.

**Move cap static**: Run `check_enemy_template_move_cap.gd`. Assert exit code 0. Verify: STRIKE `move_speed=120 ≤ 420`, CONTROL `move_speed=90 ≤ 420`, MOBILITY `move_speed=280 ≤ 420`.

**Baseline values**: Load `EnemyRegistry.tres` in GUT test; read STRIKE archetype; assert `max_hp[0]==80`, `max_hp[1]==220`, `max_hp[2]==540`; `defense[0]==8`; `move_speed==120`; `archetype_cadence_mult==1.0`. Repeat for CONTROL and MOBILITY.

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: Static CI lint validation — `check_enemy_registry_schema.gd` and `check_enemy_template_move_cap.gd` both exit 0
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 003, 004 (lint scripts must exist before data file can be validated)
- Unlocks: Stories 011 (wave scheduler reads registry), 012 (spawn lifecycle reads registry), Story 004 AC-31 verification
