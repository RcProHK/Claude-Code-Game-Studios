# Story 002: BossInstance scene-tree contract + HP mutator

> **Epic**: Boss System
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/boss-system.md` — Rule 1 (BossInstance class — Pass 4 A1.1 runtime scene tree contract)
**Requirement**: `TR-boss-001` (schema), `TR-boss-004` (frozen snapshot field), `TR-boss-012` (AI state inheritance)

**ADR Governing Implementation**: ADR-0009 (Signal Payload Schema) — primary (`hp_changed` signal); ADR-0006 (transition_id provenance) secondary
**ADR Decision Summary**: signals minimal + intrinsic; payload class naming PascalCase + `Payload`; every GSM-correlated payload carries `transition_id: String`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `BossInstance extends Node2D` (world-space, NOT Control). `player_stat_snapshot: CombatResolver.StatSnapshot` — nested class @ combat_resolver.gd:142, **plain `var` NOT `@export`** (RefCounted is non-exportable). `_ai_state: int = EnemyDirector.EnemyAIState.SPAWNING` (autoload-nested enum, prefix required; mirror src/ai/enemy.gd:21). EXACTLY ONE `_ready()` (Pass 7 merge).

**Control Manifest Rules (Feature layer)**:
- Required: every HP write routes through a single `_set_current_hp(value)` mutator (clamp [0,max_hp] → emit `hp_changed` → DD#1 persist) — Pillar-2 single-source.
- Forbidden: direct `BossInstance.new()` / `preload().instantiate()` outside `BossSystem.spawn_boss()` (Pillar 1 chain — transition_id null). Runtime mutation of immutable fields = bug (NEVER #8).

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] `BossInstance extends Node2D` with: immutable `boss_id`/`boss_template`/`transition_id`/`player_stat_snapshot` (set in spawn_boss before add_child); runtime `current_hp`/`max_hp`/`attack_count`/`_last_emitted_pattern_id`/`_spawned_emitters`/`_ai_state`.
- [ ] `signal hp_changed(current_hp: int, max_hp: int)` declared; every HP write goes through `_set_current_hp(value)` → `clampi(value,0,max_hp)` → emit → `PersistenceLayer.write("boss.current_hp", current_hp)`.
- [ ] SINGLE `_ready()`: asserts (transition_id != "", snapshot != null, `$AnimationPlayer`, `$CollisionShape2D`); `max_hp = BossFormulas.compute_max_hp(...)`; `_set_current_hp(max_hp)`; `_persist_fight_anchor()`; `$AnimationPlayer.play("idle")`; `EnemyDirector.enemy_killed.connect(_on_enemy_killed_self_listen)`; bfcache `page_shown_from_bfcache` subscribe if PlatformDetect has signal.
- [ ] Required child node contract: `$AnimationPlayer`/`$CollisionShape2D`/`$Sprite2D`/`$HitArea2D`; required anim names (idle/telegraph/attack_<id>/staggered/death).
- [ ] **AC-15**: `_ai_state` uses `EnemyDirector.EnemyAIState` exactly (SPAWNING/IDLE/PURSUING/ATTACKING/STAGGERED/DYING); no BOSS_PHASE_TRANSITION in MVP.

---

## Implementation Notes

*From GDD Rule 1 + Rule 11 + Rule 15:*

- `BossInstance.tscn` root type = BossInstance + the 4 required children. `_instantiate_boss` (Story 007) instantiates the PackedScene, NOT a bare `.new()`.
- `_exit_tree()` calls idempotent `_cleanup_resources()` (Story 012 owns the body).
- `player_stat_snapshot: CombatResolver.StatSnapshot` — plain typed var, runtime-set. Use the `CombatResolver.` prefix (nested class).

---

## Out of Scope

- **Story 003**: `BossFormulas.compute_max_hp` body (called in `_ready`).
- **Story 011**: `_on_enemy_killed_self_listen` body + death path.
- **Story 012**: `_cleanup_resources` / `_persist_fight_anchor` body / bfcache restore.

---

## QA Test Cases

- **_set_current_hp single-source**: Given a BossInstance with max_hp=100; When `_set_current_hp(150)`; Then `current_hp==100` (clamped) + `hp_changed(100,100)` emitted + `PersistenceLayer.write("boss.current_hp",100)` called. Edge: `_set_current_hp(-5)` → 0.
- **_ready asserts**: Given a BossInstance with transition_id="" ; When `_ready`; Then assert fails (`transition_id MUST be set`). Repeat for null snapshot / missing $AnimationPlayer.
- **AC-15 state enum**: assert `_ai_state` default == `EnemyDirector.EnemyAIState.SPAWNING`; state ids match the #14 enum exactly.
- Use a stub `_camera`/`_gsm`-style duck seam — BossInstance is driven via injected scene children in tests, not a real Camera2D.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feature/boss_system/test_boss_instance_contract.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (schema)
- Unlocks: Story 003, Story 007, Story 011, Story 012
