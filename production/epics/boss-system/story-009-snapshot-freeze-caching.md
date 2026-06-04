# Story 009: Snapshot freeze caching (CF-3)

> **Epic**: Boss System
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/boss-system.md` — Rule 5 (snapshot caching enforcement, CF-3)
**Requirement**: `TR-boss-004` (player snapshot frozen at COMMITTED; mid-fight mutations don't affect boss)

**ADR Governing Implementation**: ADR-0006 (state machine / COMMITTED tick) — primary; ADR-0009 (snapshot intrinsic to spawn) secondary
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `boss.player_stat_snapshot: CombatResolver.StatSnapshot` is the frozen reference; Formula 1 + Formula 2 read `boss.player_stat_snapshot.*`, NEVER `StatSystem.get_*()` mid-fight. CI lint `check_boss_snapshot_caching.gd` bans `StatSystem.get_*()` inside boss src.

**Control Manifest Rules (Feature)**: snapshot caller-passed (Story 007); GC-released on `_exit_tree`, no explicit clear API.

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-05**: boss spawned at ATTACK_POWER=159; mid-fight #11 mutation → boss damage-per-hit unchanged (still 159 input); snapshot integrity preserved.
- [ ] **AC-36**: mid-fight `stat_changed` (159→200) → Formula 1/2 re-eval reads cached `boss.player_stat_snapshot.ATTACK_POWER==159`; cached snapshot identity preserved across N selections.
- [ ] **AC-22** (CI-1/CI-2): object identity — Formula1.input_snapshot === Formula2.input_snapshot (Resource reference equality, not call count).

---

## Implementation Notes

*From GDD Rule 5:*

- Both formulas MUST receive the SAME `boss.player_stat_snapshot` reference (consider a `BossSpawnContext` wrapper for architectural identity per AC-22).
- CI lint (`check_boss_snapshot_caching.gd`) is ADVISORY pending tooling (AC-12 pattern); the runtime cached-read behavior is the BLOCKING part.

---

## Out of Scope

- **Story 015**: the `check_boss_snapshot_caching.gd` CI lint file (followup-08/16).

---

## QA Test Cases

- **AC-05/36**: Given snapshot atk=159; When mock StatSystem emits stat_changed→200 mid-fight; Then boss reads 159 (cached). Edge: 0-mutation control case still 159.
- **AC-22**: assert `is_same(formula1_snapshot, formula2_snapshot)` (reference identity).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feature/boss_system/test_stat_snapshot_freeze.gd` + `test_ac36_snapshot_caching.gd` + `tests/integration/feature/boss_system/test_ci1_ci2_snapshot_source.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007 (snapshot caller-passed), Story 003/004 (formulas read it)
- Unlocks: None
