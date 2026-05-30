# Story 014: Signal Pipeline Integration — Autoload Position 7 + Class Affinity from #9

> **Epic**: Loot Drop System
> **Status**: Blocked
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-019`
*(Requirement: "44 ACs" — signal pipeline integration portion)*

**ADR Governing Implementation**: ADR-0002 (GymSys Integration Protocol, **Proposed ⚠️**) secondary; ADR-0005 (Accepted) primary
**ADR Decision Summary**: `#15 LootDropSystem` must be registered in `project.godot` at position 7 (after `#14 EnemyDirector`, before `#21 LootRevealModal`). This requires #14 EnemyDirector to exist as a registered autoload. `get_dominant_ability_class()` from #9 WorkoutStateTracker drives Formula E2 class affinity — integration test requires real #9 signal.

> **BLOCKED**: #9 WorkoutStateTracker NOT implemented. #14 EnemyDirector NOT implemented. Cannot register LootDropSystem at position 7 or test real signal pipeline until both prerequisites are done.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Autoload position in `project.godot` is source of truth per ADR-0008. Modifying it without #14 existing would create dangling dependency.

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-32** — Clean autoload boot order: `#15 LootDropSystem._ready()` fires at position 7 (after `#14 EnemyDirector` ready, before `#21 LootRevealModal`); upstream signal subscriptions occur AFTER `GymSysClient.backend_ready` *(BLOCKED — needs #14 EnemyDirector)*
- [ ] **AC-42** — Workout session chest-only (chest_volume = 100% total_volume) → daily LootDrop → `class_affinity_score[STRIKE] >= 0.65` (deterministic from #9.`get_dominant_ability_class()`) *(BLOCKED — needs #9 WorkoutStateTracker)*

---

## Implementation Notes

*Will be implemented after #9 WorkoutStateTracker and #14 EnemyDirector epics are complete.*

Key implementation points when unblocked:
- Register `LootDropSystem` in `project.godot` autoloads at position 7
- Wire `enemy_killed.connect(_handle_enemy_killed)` via `connect_for_initial_state` after `await _gymsys_client.backend_ready`
- Wire `boss_killed.connect(_handle_boss_killed)` and `workout_completed.connect(_handle_workout_completed)`
- AC-42: integration test injecting real `#9 WorkoutStateTracker` stub with `get_dominant_ability_class()` returning `AbilityClass.STRIKE` (STRIKE workout session)

---

## QA Test Cases

*(Deferred — tests require #9 + #14 to exist)*

**AC-32**: `test_autoload_boot_position_7.gd` — verify #15 `_ready()` fires after #14, before #21 via boot order logging.

**AC-42**: `test_class_affinity_derived_from_workout.gd` — inject MockWorkoutStateTracker returning AbilityClass.STRIKE; verify Formula E2 returns ClassTag.STRIKE with probability ≥ 0.65 (deterministic for fixed seed).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: 
- `tests/integration/loot/test_autoload_boot_position_7.gd` (AC-32) — not yet created
- `tests/integration/loot/test_class_affinity_derived_from_workout.gd` (AC-42) — not yet created

**Status**: [ ] BLOCKED — waiting on #9 WorkoutStateTracker + #14 EnemyDirector

---

## Dependencies

- Depends on: Story 009 (autoload shell), **#9 WorkoutStateTracker (NOT implemented)**, **#14 EnemyDirector (NOT implemented)**
- Unlocks: Story 015 (full reconcile end-to-end — also BLOCKED)
