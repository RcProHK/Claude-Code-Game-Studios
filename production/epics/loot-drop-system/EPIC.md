# Epic: Loot Drop System

> **Layer**: Core
> **GDD**: design/gdd/loot-drop-system.md — **Pass 2 Revised (2026-05-28), awaiting Pass 3 re-review**
> **Architecture Module**: LootDropSystem (`src/autoload/loot_drop_system.gd`)
> **Status**: Ready (with GDD caveat — see below)
> **Stories**: Not yet created — run `/create-stories loot-drop-system`

## Overview

LootDrop 係 Mirror Hero Pillar 3（Drop Euphoria）的最終 delivery system，同時係 Pillar 1（Real Body, Real Power）anti-fabrication sextet 第六件套（#2→#3→#11→#14→#9→#15）。`loot_rarity_score = workout_score×0.75 + rng_roll×0.25`（ADR-0005）確保 RNG ceiling 係 0.25，低過 EPIC threshold 0.72，Pillar 1 floor 數學上不可被純 RNG bypass。呢個系統管理 ceremony budget（MINI_BOSS_CEREMONY_CAP=5，FINAL_BOSS_RESERVED=1 guarantee）、workout-locked daily guarantee（唔係 entitlement，係真實訓練獎勵）、同 4 個 ceremony tiers（micro_ack / mini / major / final boss reveal）。消費 `enemy_killed.transition_id`、`StreakSystem.get_streak_buff_multiplier()`、同 `WorkoutStateTracker.get_active_workout_id()`。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005 (Proposed ⚠️) | Loot Rarity Formula — `loot_rarity_score = workout_score×0.75 + rng_roll×0.25`; Pillar 1 floor: max RNG = 0.25 < EPIC threshold 0.72 | LOW |

> ⚠️ ADR-0005 Proposed — formula implementation stories auto-blocked 直至 ADR-0005 Accepted。
> ⚠️ **GDD Pass 2 Revised only — NOT formally Approved**. Pass 3 fresh-session re-review pending。所有 stories tagged `PENDING-GDD-APPROVAL` 直至 Pass 3 passes。
> **建議**: 喺 /create-stories 之前先行 `/design-review design/gdd/loot-drop-system.md` Pass 3。

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

## Next Step

1. Run `/design-review design/gdd/loot-drop-system.md` (Pass 3 fresh session) to complete GDD approval
2. Then run `/create-stories loot-drop-system`
