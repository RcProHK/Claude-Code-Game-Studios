# Story 014: Spawn position + arena constraint

> **Epic**: Boss System
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/boss-system.md` — Rule 14 (spawn position + ArenaConstraintMode)
**Requirement**: `TR-boss-013` (spawn position bounded by ArenaConfig.tres — #14 arena_config single source of truth)

**ADR Governing Implementation**: ADR-0006 (transition_id provenance / shared config) — primary
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `EnemyDirector.arena_config.arena_width_px` (single source — #14 loads ArenaConfig.tres; #16 reads, doesn't re-load). `arena_constraint_px` are world-space pixels at zoom 1.0 (unaffected by the 1.4× reveal zoom or SubViewport oversample — constraint uses world position).

**Control Manifest Rules (Feature)**: ArenaConfig.tres is the cross-system SoT (Camera #7 + spawn #16 + #14 patrol all reference it). Forward constraint to #14 (Followup #13 — #14 owns ArenaConfig ownership/exposure).

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-14**: boss spawns + pursues avatar past `arena_constraint_px.x` → position clamped to constraint; never exits arena bounds.
- [ ] Default spawn `avatar.position + Vector2(arena_width_px × 0.6, 0)` (right off-screen near edge). `ArenaConstraintMode`: WORLD_ABSOLUTE / SPAWN_RELATIVE (default, `arena_constraint_px=Vector2(300,200)`) / AVATAR_LEASH — each clamps per Rule 14 table.

---

## Implementation Notes

*From GDD Rule 14:*

- SPAWN_RELATIVE (default): `boss.position.x ∈ [spawn_pos.x ± arena_constraint_px.x]` (+ y). WORLD_ABSOLUTE: clamp to `Vector2.ZERO ± arena_constraint_px`. AVATAR_LEASH: `abs(boss.position - avatar.position) ≤ arena_constraint_px`.
- Coordinate space = world pixels at zoom 1.0; do not use screen position.

---

## Out of Scope

- ArenaConfig.tres schema + #14 ownership (Followup #13, #14 GDD). The reveal zoom (Story 010).

---

## QA Test Cases

- **AC-14**: SPAWN_RELATIVE, drive boss toward avatar past constraint.x → assert position clamped, never exits. Edge: AVATAR_LEASH — move avatar, assert boss stays within leash radius. Use a stub arena_config (injected width) — deterministic.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feature/boss_system/test_spawn_position_bounded.gd` + `test_ai_state_inheritance.gd` (AC-15 confirm) — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (BossInstance position/_ai_state), Story 007 (spawn_pos)
- Unlocks: None
