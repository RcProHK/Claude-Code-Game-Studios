# Epic: Streak System

> **Layer**: Foundation
> **GDD**: design/gdd/streak-system.md
> **Architecture Module**: StreakSystem (autoload pos 8, `src/autoload/streak_system.gd`)
> **Status**: Complete 10/10 CI-green (verified 2026-06-01); AC-38 deferred (VS-tier playtest, non-story)
> **Stories**: 8 closed 2026-05-29; 009/010 added + closed 2026-06-01 after ADR-0003 Accepted (incl. Story 002 drift-gate directional revision); combined GUT 1321/1322, 0 fail

## Overview

StreakSystem 追蹤玩家跨日 gym 訓練連續紀錄，係 Mirror Hero Pillar 1（Real Body, Real Power）嘅「4-layer architectural defense」之一：closed API + CI mutator ban + CI caller whitelist + namespace isolation。透過 `streak.*` PersistenceLayer namespace 持久化，使用 drift-tolerant `is_expired()` helper（ADR-0006 Contract 9）容忍 ±300s wall-clock drift（跨設備、DST、NTP 調整）。`milestone_thresholds` 係唯一 registered entity，提供 streak buff multiplier 比 LootDrop System 消費（Pillar 3 supporting）同 Mirror Moment（Pillar 5 supporting）。佢係 Foundation layer 最後嘅「cross-day temporal accumulation」fantasy vocab partition。Tier = Pre-MVP（唔係 VS），但 GDD 已 Approved，可以提前 implement。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003 (Accepted ✅ 2026-05-30) | Save State Strategy — `streak.*` namespace + drift-tolerant TTL + cross-device sync。confirms #15+#29 ONLY rarity-modifier callers (FR-3) | LOW |
| ADR-0006 Contracts 6+9 (Accepted ✅) | `connect_for_initial_state` subscription + `is_expired()` drift-tolerant TTL | LOW |
| ADR-0002 (Accepted data-contract ✅ 2026-05-31) | GymSys differential event cursor = retro-credit delivery mechanism (FR-1, Story 010 secondary) | LOW |

> ✅ ADR-0003 Accepted (2026-05-30) — 3 個前 ADR-RATIFICATION-GATED ACs 拆解如下（`/propagate-design-change` 2026-06-01）：
> - **AC-39** (FR-3 caller whitelist) → **完全解鎖 → Story 009 Ready**（headless GDScript CI lint）
> - **AC-37** (FR-1 Phone-Lost retro-credit) → **ADR gate cleared → Story 010 Ready**（mock-GymSys headless；live-backend cursor replay 留畀 ADR-0002 VS-tier）
> - **AC-38** (FR-2 drift FPR threshold) → **仍 DEFERRED** — 需 VS-tier ≥100-session playtest telemetry + ADR 定義 acceptable rate；headless 測唔到 false-positive RATE。唔 story-scope。

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
| 009 | [expanded-caller-whitelist-ci](story-009-expanded-caller-whitelist-ci.md) | Logic | ✅ Complete | ADR-0003 |
| 010 | [phone-lost-retro-credit](story-010-phone-lost-retro-credit.md) | Integration | ✅ Complete | ADR-0003 + ADR-0002 |

## Next Step

All 8 stories implemented + closed (impl order 008-aware: 001 → 002 → 003 → 004 → 008 → 005 → 006 → 007).

**Outstanding (not story-scoped):**
1. ✅ **Tests verified green** — combined GUT gate (`tests/unit,tests/integration,tests/static`) re-run 2026-06-01: 1313 tests, 1312 pass, 0 fail, 1 pending (pre-existing AC-37 WST, 非 streak). 7 streak test files + 2 CI shell scripts present.
2. ✅ **Committed** — streak files (`src/autoload/streak_system.gd`, `tests/unit/streak/*`, `tests/integration/streak/*`, `tools/ci/check_streak_*.sh`, 8 story files) already tracked + clean in git (committed in prior session; confirmed absent from working-tree diff 2026-06-01).
3. ⚠️ **3 ADR-0003-gated ACs deferred** (AC-37/38/39 cross-device sync) — blocked until ADR-0003 ratifies. NOTE: ADR-0003 is now **Accepted (2026-05-30)** per technical-preferences.md — these 3 ACs may be re-openable via `/propagate-design-change`.
