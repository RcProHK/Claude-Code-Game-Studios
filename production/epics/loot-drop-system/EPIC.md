# Epic: Loot Drop System

> **Layer**: Core
> **GDD**: design/gdd/loot-drop-system.md — **Pass 2 Revised (2026-05-28), awaiting Pass 3 re-review**
> **Architecture Module**: LootDropSystem (`src/autoload/loot_drop_system.gd`)
> **Status**: Ready (with GDD caveat — see below)
> **Stories**: **15 stories created** (12 Ready, 3 Blocked)

## Overview

LootDrop 係 Mirror Hero Pillar 3（Drop Euphoria）的最終 delivery system，同時係 Pillar 1（Real Body, Real Power）anti-fabrication sextet 第六件套（#2→#3→#11→#14→#9→#15）。`loot_rarity_score = workout_score×0.75 + rng_roll×0.25`（ADR-0005）確保 RNG ceiling 係 0.25，低過 EPIC threshold 0.72，Pillar 1 floor 數學上不可被純 RNG bypass。呢個系統管理 ceremony budget（MINI_BOSS_CEREMONY_CAP=5，FINAL_BOSS_RESERVED=1 guarantee）、workout-locked daily guarantee（唔係 entitlement，係真實訓練獎勵）、同 4 個 ceremony tiers（micro_ack / mini / major / final boss reveal）。消費 `enemy_killed.transition_id`、`StreakSystem.get_streak_buff_multiplier()`、同 `WorkoutStateTracker.get_active_workout_id()`。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005 (**Accepted** 2026-05-30) | Loot Rarity Formula — `loot_rarity_score = workout_score×0.75 + rng_roll×0.25`; Pillar 1 floor: max RNG = 0.25 < EPIC threshold 0.72 | LOW |
| ADR-0003 (**Accepted** 2026-05-30) | Save State Strategy — `loot.*` namespace + Private Mode gate | LOW |
| ADR-0006 (**Accepted**) | State Machine Contract — `transition_id` atomicity + `connect_for_initial_state` | LOW |
| ADR-0007 (**Accepted** 2026-05-29) | Enum Convention — `ClassTag.NEUTRAL` ≠ `AbilityClass.UNKNOWN` clarified | LOW |
| ADR-0009 (**Accepted** 2026-05-29) | Signal Payload Schema — workout_id late-bound (INV-12) | LOW |
| ADR-0002 (**Proposed** ⚠️) | GymSys Integration — backend endpoints; blocks Stories 013/014/015 | LOW |

> ✅ ADR-0005 Accepted 2026-05-30 — formula stories unblocked.
> ✅ ADR-0003/0006 Accepted — AC-23/24/35/37 (previously ADR-RATIFICATION-GATED) now BLOCKING.
> ⚠️ ADR-0002 Proposed — Stories 013/014/015 remain BLOCKED until #2 GymSys implemented.
> ⚠️ GDD Pass 2 Revised — pass 3 formal review pending but stories created per handoff state (ADR-0005 Accepted unblocks all formula stories).

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-loot-001 | `loot_rarity_score = workout_score×0.75 + rng_roll×0.25` | ADR-0005 ⚠️ |
| TR-loot-002 | Pillar 1 floor: `max(raw_tier, COMMON)` — final tier cannot go below COMMON via pure RNG | ADR-0005 ⚠️ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 19 TR-loot-* entries.

## Definition of Done

This epic is complete when:
- GDD passes Pass 3 fresh-session `/design-review` (PENDING)
- ADR-0005 Accepted
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/loot-drop-system.md` (44 ACs) verified
- Logic stories: rarity formula unit tests + ceremony budget tests in `tests/unit/loot/`
- `loot_rarity_formula_test.gd` (existing 2026-05-28) updated to GUT v7.x API + expanded for Pass 2 changes
- Pillar 1 floor test: `max_rng_contribution = 0.25 < EPIC_THRESHOLD = 0.72` proven by exhaustive test
- ceremony_cap: final boss always gets loot_guarantee (FINAL_BOSS_RESERVED=1 test)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | CI Lints — Closed API + Namespace + Config Integrity | Logic | Ready | ADR-0005 |
| 002 | LootRarityConfig Resource + Data Record + Enum Declarations | Logic | Ready | ADR-0005, ADR-0007 |
| 003 | Formula 1 apply_tier_ceiling_floor + Pillar 1 Anti-Fabrication Proofs | Logic | Ready | ADR-0005 |
| 004 | Formula 2 ceremony_cap_check — Dual Pool + micro_ack | Integration | Ready | ADR-0005, ADR-0009 |
| 005 | Formula 3 (Pending TTL Expiry) + Formula 4 (bfcache Resume Action) | Logic | Ready | ADR-0003, ADR-0006 |
| 006 | Formula 5 (Local vs Backend Reconcile) + Formula 6 (Catch-up Compression) | Integration | Ready | ADR-0003 |
| 007 | Formula E1 (Item Type) + E2 (Class Affinity) + E4 (Inventory Overflow) | Logic | Ready | ADR-0005, ADR-0007 |
| 008 | Formula E3 — Anti-Pillar Weekly Distribution (Monte Carlo) | Logic | Ready | ADR-0005 |
| 009 | LootDropSystem Autoload — Boot Sequence + State Machine + Private Mode Gate | Integration | Ready | ADR-0005, ADR-0003, ADR-0006, ADR-0009 |
| 010 | Idempotency + Malformed ID Guard + Release Guard + Unknown Tier Fallback | Logic | Ready | ADR-0005, ADR-0006 |
| 011 | Daily Token Gate + Trigger Routing + Source-Event Classification | Logic | Ready | ADR-0005, ADR-0009 |
| 012 | 5-Step Optimistic Persistence + Rollback + Schema Migration + transition_id Format | Integration | Ready | ADR-0003, ADR-0006 |
| 013 | Backend Authority — Server Tier Correction + ACK Commit + Mismatch Alert | Integration | **Blocked** (#2 GymSys) | ADR-0002 |
| 014 | Signal Pipeline Integration — Autoload Position 7 + Class Affinity from #9 | Integration | **Blocked** (#9/#14) | ADR-0005 |
| 015 | bfcache Reconcile End-to-End (Composite) | Integration | **Blocked** (#2/#9/#14) | ADR-0002, ADR-0003 |

## Next Step

Run `/story-readiness production/epics/loot-drop-system/story-001-ci-lints-closed-api.md` then `/dev-story` to begin implementation. Work through stories 001 → 012 in order (each story's `Depends on:` field shows prerequisites).
