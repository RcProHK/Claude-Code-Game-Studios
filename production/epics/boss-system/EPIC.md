# Epic: Boss System

> **Layer**: Feature
> **GDD**: design/gdd/boss-system.md ✅ APPROVED 2026-06-05 (Pass 11 — STRUCTURAL FREEZE lifted)
> **Architecture Module**: #16 Boss System (Feature layer — boss content owner + #14 EnemyDirector BossAnchor lifecycle consumer)
> **Status**: Ready
> **Stories**: 15 created (Ready) — implement in dependency order (001 → …)

## Overview

The Boss System (#16) is the Feature-layer **boss content owner** and the **#14 EnemyDirector BossAnchor lifecycle consumer**. It defines the boss data schema (`BossTemplate` / `BossInstance` / `AttackPatternResource` / `BossVisualResource` / `BossFormulas`), the 3-class presentation-family variation (STRIKE / CONTROL / MOBILITY — MVP ships STRIKE fallback only), boss difficulty scaling that tracks the player's real-stat snapshot, and the mini-vs-final dramatic-weight distinction. It owns the Pillar 3 「DNF 式爆裝刺激」climax moment: on the player's last rep, #14 BossAnchor COMMITTED triggers `BossSystem.spawn_boss(...)` → the avatar auto-fights → `enemy_killed(payload)` → #15 LootDrop seeds RNG from `transition_id` → guaranteed loot. It does NOT own spawn timing / the BossAnchor state machine (#14), damage computation (#13), or the loot rarity formula (ADR-005 / #15) — it delivers「what the boss is, does, and is worth」as data + behavior spec, all driven by the frozen player snapshot (Pillar 1 anti-fabrication chain).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Loot Rarity Formula | boss kill `enemy_killed.transition_id` → #15 RNG seed → `loot_rarity_score` (volume×PR×streak); `loot_guarantee_min_tier = RARE` floor combined via `max()` | LOW |
| ADR-0006: State Machine Contract | `transition_id` provenance (Contract 2 — acquire via #1 GSM, propagate via #14 BossAnchor); `connect_for_initial_state` (Contract 6) for signal subscriptions | LOW |
| ADR-0001: Web Export Budget Caps | boss reveal particle storm respects MAX_ACTIVE_PARTICLES=200 + mobile FR-4 auto-degrade; `reveal_ritual_intensity ≤ 1.0 < #5 max_caller_multiplier 1.5` | MEDIUM (CPU numbers Provisional) |
| ADR-0003: Save State Strategy | DD#1 persists ONE ephemeral mid-fight record (`boss.current_hp` + `boss.transition_id` + `boss.fight_timestamp`) for exact bfcache restore; deleted on death/cleanup/TTL-expiry | LOW |
| ADR-0007: Class & Domain Enum Convention | `AbilityClass {STRIKE,CONTROL,MOBILITY,UNKNOWN}` ordinals (boss `class_archetype` stored as `@export_enum int` mirroring AbilitySystem.AbilityClass) | LOW |
| ADR-0009: Signal Payload Schema Convention | `boss_committed` payload (intrinsic + transition_id); `enemy_killed(payload: EnemyKilledPayload)` consumer | LOW |

**Engine Risk (highest among governing ADRs): MEDIUM** — ADR-0001 particle/CPU budget caps (numbers Provisional, VS-tier hardware ratification gated). All boss-specific TRs are LOW (data structure / state machine / cross-system).

## GDD Requirements

Traced via `docs/architecture/tr-registry.yaml` (TR-boss-001..018, all `status: active`). The GDD's **54 effective ACs** (Section H) are the authoritative testable requirement set; the TR-IDs below are the ADR-traced coverage map.

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-boss-001 | BossTemplate Resource schema (immutable @export fields) | ADR-0007/0001 ✅ |
| TR-boss-002 | Deterministic boss spawn selection via hash seed on transition_id (⚠️ TR text stale: DD#2 replaced `total_planned_sets` with `effort_score` gate — GDD authoritative) | ADR-0006 ✅ |
| TR-boss-003 | Class archetype mapping (STRIKE/CONTROL/MOBILITY); STRIKE fallback for UNKNOWN | ADR-0007 ✅ |
| TR-boss-004 | Player snapshot frozen at COMMITTED (CF-3) | ADR-0006/0009 ✅ |
| TR-boss-005 | Formula 3 attack-pattern anti-spam (deterministic, posmod-hardened FNV-1a) | ADR-0006 ✅ |
| TR-boss-006 | `enemy_killed.transition_id` chain integrity (verbatim spawn → #15) | ADR-0005/0006/0009 ✅ |
| TR-boss-007 | Formula 1 boss_max_hp_scaling clamped [MIN_BOSS_HP, MAX_BOSS_HP] | ADR-0001 ✅ |
| TR-boss-008 | Formula 2 boss_attack_damage_scaling (⚠️ TR text stale: Pass 11 reframed「anti-one-shot」→ texture-guard / live-HP input to #13; GDD authoritative) | — (Formula; #13 consumes) ✅ |
| TR-boss-009 | Formula 4 reveal_ritual_intensity (final-boss-only, categorical) | ADR-0001 ✅ |
| TR-boss-010 | AC-24: all reveal_ritual_intensity ≤ 1.0 (< #5 max_caller_multiplier 1.5) | ADR-0001 ✅ |
| TR-boss-011 | Boss cleanup ≤ 2 frames (`_spawned_emitters` released via #5 wrapper + queue_free) | ADR-0001 ✅ |
| TR-boss-012 | AI state inheritance from #14 `EnemyDirector.EnemyAIState` enum | ADR-0006 ✅ |
| TR-boss-013 | Spawn position bounded by ArenaConfig.tres (#14 arena_config SoT) | ADR-0006 ✅ |
| TR-boss-014..018 | (reveal ritual dispatch / bfcache DD#1 restore / idempotency / null-snapshot / NEVER traceability — per registry) | ADR-0001/0003/0006/0009 ✅ |

**ADR coverage: 18/18 TR-IDs traced to Accepted ADRs. Untraced requirements: None.**

> ⚠️ **TR-registry refresh note (non-blocking)**: TR-boss-002 (`total_planned_sets`) and TR-boss-008 (`anti-one-shot`) carry pre-Pass-6/11 wording. The **GDD is authoritative** (DD#2 effort_score gate; Formula 2 live-HP texture-guard). Refresh the TR text at the next `/architecture-review` — does not block story creation.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All 54 acceptance criteria from `design/gdd/boss-system.md` Section H are verified (the BLOCKING/runtime ACs gate; ADVISORY/Manual/CI-blocked ACs follow their documented promotion paths)
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Known external gates / sequencing (from GDD + deps)

- **Upstream (all Approved + implemented)**: #9 WST, #11 Stat, #13 CombatResolver, #14 EnemyDirector. Downstream visual-ritual callers #5/#6/#7 (Approved + implemented).
- **`spawn_boss` is invoked by #14** (caller-passed snapshot, A1.2/A1.3 4-param canonical). #14 EnemyDirector epic is Ready (24 stories) — boss spawn wiring co-depends on #14's BossAnchor path.
- **#15 LootDrop (Pass 2, Core)** consumes `loot_guarantee_min_tier` + the `enemy_killed` chain — loot-side ACs (AC-23) DEFERRED-TO-#15.
- **CI tooling stories (BOSS-AC-followup-08)**: `check_boss_no_persist` / `check_boss_nevers` / `check_boss_template_validity` / `check_boss_formulas_purity` / `check_boss_snapshot_caching` / scene-tree-contract / parent-identity — AC-12/16/33/36/41(e) are ADVISORY until these land.
- **Advisory followups (Pass 11, non-blocking)**: anticipation/ceremony two-peak; downed-animation must-not-read-as-fail (asset/Section-I scope); AC-39(B) prospective baseline; Coverage Map EC-03/06/09 deferred rows.

## Stories

| # | Story | Type | Status | Primary ADR | Depends on |
|---|-------|------|--------|-------------|-----------|
| 001 | BossTemplate / Visual / AttackPattern schema | Logic | ✅ Complete | ADR-0007 | — |
| 002 | BossInstance scene-tree contract + HP mutator | Logic | ✅ Complete | ADR-0009 | 001 |
| 003 | BossFormulas + Formula 1 HP-scaling + bootstrap | Logic | ✅ Complete | ADR-0001 | 001 (NOT 002) |
| 004 | Formula 2 damage scaling (live-HP) | Logic | ✅ Complete | ADR-0001 | 003 |
| 005 | Formula 3 attack-pattern selection (FNV-1a) | Logic | ✅ Complete | ADR-0006 | 003, 001 |
| 006 | Formula 4 reveal_ritual_intensity | Logic | ✅ Complete | ADR-0001 | 003, 001 |
| 007 | BossSystem autoload + spawn_boss + idempotency | Integration | ✅ Complete (autoload reg deferred → #14 wiring) | ADR-0006 | 002, 003 |
| 008 | Spawn selection — effort gate + archetype + UNKNOWN | Logic | ✅ Complete | ADR-0007 | 007, 001 |
| 009 | Snapshot freeze caching (CF-3) | Logic | Ready | ADR-0006 | 007, 003/004 |
| 010 | Reveal ritual dispatch (Camera-leading) | Integration | Ready | ADR-0001 | 007, 006 |
| 011 | enemy_killed → DYING self-filtered wiring | Integration | Ready | ADR-0009 | 002, 007 |
| 012 | Boss cleanup + bfcache DD#1 exact-restore | Integration | Ready | ADR-0003 | 011, 002 |
| 013 | Avatar-downed auto-recover + grace window | Logic | Ready | N/A (Pillar-2 behavior) | 004 |
| 014 | Spawn position + arena constraint | Logic | Ready | ADR-0006 | 002, 007 |
| 015 | Loot-tier combine + CI tooling + playtest gates | Integration | Ready (sub-items deferred) | ADR-0005 | 001, 011 |

**Implementation order**: 001 → 002 → 003 → {004, 005, 006} → 007 → {008, 009, 010, 011} → 012 → 013 → 014 → 015. Story 015 sub-items (8 CI-tooling lints → followup-08; playtest AC-29/30/35/39 → external; AC-23 → #15) are deferred/blocked, not on the critical path.

Type distribution: 9 Logic, 6 Integration. (Visual/Feel + Manual ACs — AC-29/30/35/39 — live in Story 015's deferred external-evidence sub-items.)

## Next Step

Run `/story-readiness production/epics/boss-system/story-001-boss-template-schema.md` → `/dev-story` to begin implementation (story 001 has no dependencies).

