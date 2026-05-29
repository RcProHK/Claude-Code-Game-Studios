# Epic: Streak System

> **Layer**: Foundation
> **GDD**: design/gdd/streak-system.md
> **Architecture Module**: StreakSystem (autoload pos 8, `src/autoload/streak_system.gd`)
> **Status**: Implementation Complete (2026-05-29) — 3 ADR-0003-gated ACs deferred
> **Stories**: 8 stories created + implemented + reviewed + closed 2026-05-29

## Overview

StreakSystem 追蹤玩家跨日 gym 訓練連續紀錄，係 Mirror Hero Pillar 1（Real Body, Real Power）嘅「4-layer architectural defense」之一：closed API + CI mutator ban + CI caller whitelist + namespace isolation。透過 `streak.*` PersistenceLayer namespace 持久化，使用 drift-tolerant `is_expired()` helper（ADR-0006 Contract 9）容忍 ±300s wall-clock drift（跨設備、DST、NTP 調整）。`milestone_thresholds` 係唯一 registered entity，提供 streak buff multiplier 比 LootDrop System 消費（Pillar 3 supporting）同 Mirror Moment（Pillar 5 supporting）。佢係 Foundation layer 最後嘅「cross-day temporal accumulation」fantasy vocab partition。Tier = Pre-MVP（唔係 VS），但 GDD 已 Approved，可以提前 implement。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003 (Proposed ⚠️) | Save State Strategy — `streak.*` namespace + drift-tolerant TTL + cross-device sync | LOW |
| ADR-0006 Contracts 6+9 (Accepted ✅) | `connect_for_initial_state` subscription + `is_expired()` drift-tolerant TTL | LOW |

> ⚠️ ADR-0003 Proposed — 3 個 ACs（AC-37/38/39 ADR-RATIFICATION-GATED）blocked 直至 ADR-0003 Accepted。Core implementation（closed API + streak counter + milestone）可先行。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-streak-001 | Cross-day accumulation with drift-tolerant `is_expired()` (±300s WALL_CLOCK_DRIFT_TOLERANCE_SECONDS) | ADR-0003 ⚠️ + ADR-0006 Contract 9 ✅ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 12 TR-streak-* entries.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/streak-system.md` (33 ACs: 28 BLOCKING + 2 ADVISORY + 3 ADR-RATIFICATION-GATED) verified
- Logic stories: unit tests for streak accumulation + `is_expired()` edge cases in `tests/unit/streak/`
- `record_today_workout()` idempotency test (double-call within same day)
- `get_streak_buff_multiplier()` returns expected values at each milestone threshold
- CI caller whitelist enforced: only `loot_drop_system.gd` and `mirror_moment_system.gd` may call `get_streak_buff_multiplier()`

## Next Step

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [state-machine-boot](story-001-state-machine-boot.md) | Integration | ✅ Complete | ADR-0006 C6 |
| 002 | [core-api-drift-gate](story-002-core-api-drift-gate.md) | Logic | ✅ Complete | ADR-0006 C9 |
| 003 | [calendar-formulas](story-003-calendar-formulas.md) | Logic | ✅ Complete | ADR-0006 C9 |
| 004 | [buff-multiplier-milestones](story-004-buff-multiplier-milestones.md) | Logic | ✅ Complete | N/A |
| 005 | [atomic-persistence-write](story-005-atomic-persistence-write.md) | Integration | ✅ Complete | ADR-0006 C9 |
| 006 | [failed-state-error-handling](story-006-failed-state-error-handling.md) | Logic | ✅ Complete | ADR-0006 C9 |
| 007 | [ci-defense-4layer](story-007-ci-defense-4layer.md) | Logic | ✅ Complete | ADR-0006 C12 |
| 008 | [drift-constant-consistency](story-008-drift-constant-consistency.md) | Logic | ✅ Complete | ADR-0006 C9 |

## Next Step

All 8 stories implemented + closed (impl order 008-aware: 001 → 002 → 003 → 004 → 008 → 005 → 006 → 007).

**Outstanding (not story-scoped):**
1. ⚠️ **Run tests locally** — `godot --headless` GUT suite (8 streak test files) + `sh tools/ci/check_streak_*.sh`. Tests were authored but NOT executed this session (harness Bash blocked by session-env EEXIST). Confirm green before commit.
2. ⚠️ **3 ADR-0003-gated ACs deferred** (AC-37/38/39 cross-device sync) — blocked until ADR-0003 (Proposed) ratifies. Re-open via `/propagate-design-change` when ADR-0003 → Accepted.
3. Suggested commit covering `src/autoload/streak_system.gd`, `tests/unit/streak/*`, `tests/integration/streak/*`, `tools/ci/check_streak_*.sh`, and the 8 story files.
