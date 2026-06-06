# Story 015: Loot-tier combine contract + CI tooling + playtest gates

> **Epic**: Boss System
> **Status**: Complete (core) — deferred sub-items remain (CI tooling → followup-08; playtest → external; AC-23 → #15)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (split — see Out of Scope for deferred sub-items)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06

**Completion Notes (2026-06-06)**: `BossFormulas.resolve_boss_loot_tier(loot_guarantee_min_tier, adr005_rolled_tier) -> int` (max-combine contract #15 consumes) + `tests/unit/boss_system/test_loot_guarantee_flag.gd` (5 tests) + `design/gdd/boss-system-never-traceability.md` (AC-40 matrix, 13/13 NEVERs → ACs). combined 270scr/1768/1767pass/0fail/1pending. AC-09 (final default loot floor RARE=2), combine (floor wins when roll lower, roll wins when higher), INV-8 (final floor RARE ≥ mini ceiling RARE, joint-equal valid — distributional gradient).
- **DEFERRED (still remaining, per the story's Out of Scope)**: 8 CI-tooling lints (BOSS-AC-followup-08: check_boss_no_persist / check_boss_nevers / check_boss_template_validity / check_boss_formulas_purity / check_boss_snapshot_caching / check_boss_scene_tree_contract / check_boss_parent_identity_transform / check_boss_direct_instantiate) — these promote the ADVISORY static ACs (AC-12/16/33/36/41e) to BLOCKING; playtest/manual ACs (AC-29a/c/d, AC-30, AC-35, AC-39 — external evidence, VS/MVP-gate); AC-23 (loot chain → #15 implementation). These are followup-08/external/cross-epic, not #16-core code.

## Context

**GDD**: `design/gdd/boss-system.md` — Rule 9 (loot guarantee + tier combine) + Section H ADVISORY/Static ACs
**Requirement**: `TR-boss-006` (chain integrity), `TR-boss-016..018` (idempotency / NEVER traceability per registry)

**ADR Governing Implementation**: ADR-0005 (Loot Rarity Formula — combine contract) — primary
**ADR Decision Summary**: `loot_rarity_score = workout_score×0.75 + rng_roll×0.25`; Pillar-3 floor `final_tier = max(raw, loot_guarantee_min_tier)`; RNG seeded on transition_id.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: combine = `maxi(adr005_rolled, loot_guarantee_min_tier)` (RarityTier ordinal-ordered, `LootEnums.RarityTier`). Real roll class = `LootRarityCalc` (loot_rarity_calc.gd:22), the transition_id-seeded entry is #15's path.

**Control Manifest Rules (Feature)**: `loot_guarantee_min_tier` is #16's flag; #15 implements actual loot generation. Never guarantee a drop without `enemy_killed` emission (NEVER #6).

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-09**: every FINAL BossTemplate has `loot_guarantee_min_tier == RARE` (ordinal 2); #15 combine honours the floor (`max()` — modifiers push EPIC/LEGENDARY, never below RARE).
- [ ] INV-8: `loot_guarantee_min_tier (RARE) ≥ EnemyTemplate.loot_rarity_ceiling (RARE)` — joint-equal valid; gradient is DISTRIBUTIONAL (full-workout modifiers), not static.
- [ ] **AC-40** (Static, ADVISORY): Rule 16 NEVER→AC traceability matrix `design/gdd/boss-system-never-traceability.md` — every NEVER (13) has ≥1 AC; zero「lint-only」without runtime check.

---

## Implementation Notes

*From GDD Rule 9:*

- `loot_guarantee_min_tier` exposed for #15; #16 does NOT roll loot. The combine pseudocode is the contract #15 stories cite.
- AC-23 (full transition_id chain to #15 RNG) is **DEFERRED-TO-#15** (not testable until #15 designed/implemented).

---

## Out of Scope (deferred sub-items — separate stories OR followup-blocked)

- **CI tooling (BOSS-AC-followup-08, ADVISORY until landed)**: `check_boss_no_persist.gd` (AC-12), `check_boss_nevers.gd` (AC-16), `check_boss_template_validity.gd` (AC-33b), `check_boss_formulas_purity.gd` (AC-41e), `check_boss_snapshot_caching.gd` (AC-36 CI), `check_boss_scene_tree_contract.gd`, `check_boss_parent_identity_transform.gd`, `check_boss_direct_instantiate.gd`. → a Producer CI-tooling story (or #16 sprint-3) — these promote the ADVISORY static ACs to BLOCKING.
- **Playtest / manual ACs (external evidence, VS-tier / MVP-gate)**: AC-29a/c/d (Likert), AC-30a/b-vs/polish (latency), AC-35 (gym sync), **AC-39** (novelty-retention — producer-scheduled ≥3-week n≥12 window, hard MVP gate). → recruit + `production/qa/evidence/*` docs.
- **AC-23** loot chain → #15 LootDrop implementation.

---

## QA Test Cases

- **AC-09**: iterate FINAL templates → all `loot_guarantee_min_tier == 2 (RARE)`. Combine: `maxi(rolled, floor)` — rolled COMMON → RARE; rolled EPIC → EPIC.
- **INV-8**: assert `loot_guarantee_min_tier (2) >= ceiling (2)`.
- **AC-40**: parse the traceability matrix → every NEVER #1..13 maps to ≥1 AC id.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/feature/boss_system/test_loot_guarantee_flag.gd` + `design/gdd/boss-system-never-traceability.md` (AC-40) — must pass / exist. CI-tooling + playtest evidence per deferred sub-items above.
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (loot_guarantee_min_tier field), Story 011 (enemy_killed chain)
- Unlocks: #15 LootDrop boss-loot stories (cross-epic)
