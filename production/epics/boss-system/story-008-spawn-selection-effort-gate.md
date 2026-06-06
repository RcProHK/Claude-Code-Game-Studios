# Story 008: Spawn selection — effort gate + class archetype + UNKNOWN fallback

> **Epic**: Boss System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06

**Completion Notes (2026-06-06)**: `src/data/boss_registry.gd` (`class_name BossRegistry extends Resource`) + `tests/unit/boss_system/test_spawn_selection.gd` (8 tests; combined 266scr/1748/1747pass/0fail/1pending). AC-02 (determinism), AC-03/AC-10 (effort gate 0.10→null / 0.50→FINAL), AC-04/AC-13 (class routing + UNKNOWN→STRIKE), EC-22 (==threshold→FINAL), EC-03 (missing class→STRIKE fallback→null).
- **OWNERSHIP DESIGN RESOLVED**: #16 owns the SELECTION (`BossRegistry.select_final_template(dominant_class, effort_score, transition_id)` — pure: effort gate + class→template + Rule 13 UNKNOWN→STRIKE + deterministic FNV-1a pick). #14 owns ORCHESTRATION — at COMMITTED it calls the selector and branches: null → #14 mini-boss wave path (Rule 10); template → `BossSystem.spawn_boss(template,...)`. This IS the GDD's「gate check at #14 caller side」(#14 invokes #16's pure selector). spawn_boss itself doesn't take effort_score.
- `MINI_BOSS_EFFORT_THRESHOLD=0.25` const (synced #14↔#16 INV-7, range [0.15,0.40]). Boundary `< threshold → mini` (strict-less-than). `BossRegistry` authored as `res://data/boss_registry.tres`.

## Context

**GDD**: `design/gdd/boss-system.md` — Rule 2 (spawn selection), Rule 10 (low-effort), Rule 13 (UNKNOWN fallback)
**Requirement**: `TR-boss-002` (deterministic selection), `TR-boss-003` (class archetype mapping + STRIKE fallback for UNKNOWN)

**ADR Governing Implementation**: ADR-0007 (Class Enum — UNKNOWN fallback discipline) — primary; ADR-0005 (effort_score = workout_score) secondary
**ADR Decision Summary**: never zero-default-fabricate STRIKE; UNKNOWN→STRIKE is an EXPLICIT Rule-13 decision (EC-09 pattern). effort_score = ADR-005 `workout_score` (already computed for loot).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: deterministic `pick_deterministic(candidates, seed=DeterministicHash.deterministic_hash(transition_id))`.

**Control Manifest Rules (Core/Feature)**: `AbilityClass.UNKNOWN` returned explicitly; the UNKNOWN→STRIKE boss-archetype decision belongs to #16 Rule 13, never fabricated by zero-default.

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-02**: deterministic — same (transition_id, dominant_class, effort_score≥threshold) → same boss_template_id both calls.
- [ ] **AC-03 / AC-10** (DD#2 effort gate): `effort_score=0.10 (< MINI_BOSS_EFFORT_THRESHOLD=0.25)` → #16 early-returns null, NO BossInstance, NO boss_committed (#14 wave handles mini); `effort_score=0.50 (≥)` → #16 spawns FINAL with `loot_guarantee_min_tier=RARE` + `reveal_ritual_intensity==1.0`. Gate is `effort_score` NOT `total_planned_sets`.
- [ ] **AC-04 / AC-13**: dominant_class STRIKE/CONTROL/MOBILITY → matching `class_archetype`; `UNKNOWN` → STRIKE fallback (Rule 13) + `boss.unknown_class_fallback` telemetry. EC-22: boundary `effort_score == threshold` → FINAL (strict-less-than for mini).

---

## Implementation Notes

*From GDD Rule 2 + Rule 10 + Rule 13:*

- `if effort_score < MINI_BOSS_EFFORT_THRESHOLD: return` (no #16 action). `selected_class = dominant_class if != UNKNOWN else STRIKE`. `candidates = BossRegistry.query(tier==FINAL, class_archetype==selected_class)`; `pick_deterministic(...)`.
- `MINI_BOSS_EFFORT_THRESHOLD=0.25` TUNABLE, range-guarded [0.15,0.40]; MUST stay synced #14↔#16 (INV-7, Followup #25 sync lint — manual check until #14 aligns).
- `total_planned_sets` survives ONLY as the EC-23 `==0` empty-guard (Story 007 AC-26).

---

## Out of Scope

- **Story 007**: spawn_boss mechanics. Mini-boss EnemyTemplate path (#14). `MINI_BOSS_EFFORT_THRESHOLD` sync CI lint (Followup #25, #14-blocked).

---

## QA Test Cases

- **AC-02**: same inputs twice → same template id (deterministic hash).
- **AC-03/10**: effort 0.10 → null + no boss_committed; effort 0.50 → FINAL + loot_guarantee RARE + ritual 1.0. Edge: effort==0.25 → FINAL.
- **AC-04/13**: each class → matching archetype; UNKNOWN → STRIKE + telemetry. Assert NO second STRIKE/CONTROL/MOBILITY enum declared (manifest CI).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feature/boss_system/test_spawn_selection_determinism.gd` + `test_tier_distinction.gd` + `test_class_archetype_routing.gd` + `test_unknown_class_fallback.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007 (spawn_boss + BossRegistry), Story 001 (class_archetype field)
- Unlocks: None
