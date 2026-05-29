# Epic: Game State Machine

> **Layer**: Foundation
> **GDD**: design/gdd/game-state-machine.md
> **Architecture Module**: GameStateMachine (autoload pos 2, `src/autoload/game_state_machine.gd`)
> **Status**: Ready
> **Stories**: 17 stories — **16/17 Complete** ✅ (Story 017 bfcache spike Deferred — requires manual Web Export evidence)

## Overview

GameStateMachine 係 Mirror Hero 嘅頂層狀態協調器，負責管理 9 個互斥 top-level game states（Booting / Disconnected / Idle / WorkoutActive / RestPeriod / CombatActive / BossEncounter / LootDrop / Suspended）。每次 state transition 經過 8-step atomic protocol（acquire generational lock → validate → write tombstone → commit final state → in-memory update → remove tombstone → backend write → emit signal → release lock），確保 WASM single-thread 環境下唔出現 partial state。`connect_for_initial_state` sentinel helper（ADR-0006 Contract 6）令每個後啟動 autoload 都能安全訂閱當前 state，解決 boot-order race condition 問題。呢個系統係所有其他 autoload 嘅 event bus backbone。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006 (Accepted ✅) | State Machine Contract — 15 Contracts covering atomic transition, transition_id, tombstone recovery, boot order, sentinel delivery, race guard, reconnection, suspension | HIGH |
| ADR-0003 (Proposed ⚠️) | Save State Strategy — PersistenceLayer write path for `gsm.*` namespace (tombstone + state) | MEDIUM |

> ⚠️ ADR-0003 係 Proposed — 依賴 PersistenceLayer tombstone write 嘅 stories 會 auto-blocked 直至 ADR-0003 Accepted。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-gsm-001 | Rule 1: 9-state enum, exactly one active top-level state | ADR-0006 Contract 1 ✅ |
| TR-gsm-002 | Rule 2: 8-step atomic transition protocol | ADR-0006 Contract 1 ✅ |
| TR-gsm-003 | Generational lock `_lock_gen` + `_force_clear_timer` per-transition fallback | ADR-0006 Contract 1 ✅ |
| TR-gsm-004 | `transition_id` format: `wall_clock_ms×1000 + monotonic_counter`, persisted | ADR-0006 Contract 2 ✅ |
| TR-gsm-005 | Forward-recovery reuses tombstone `transition_id` verbatim (CI enforced) | ADR-0006 Contract 3 ✅ |
| TR-gsm-006 | Tombstone via Contract 3 `to_dict()`/`from_dict()` + `get_script().get_global_name()` | ADR-0006 Contract 3 ✅ |
| TR-gsm-007 | Subscriber re-entry blocked; follow-up via `process_frame.connect(CONNECT_ONE_SHOT)` | ADR-0006 Contract 7 ✅ |
| TR-gsm-008 | `connect_for_initial_state` sentinel (`source_event="initial_state"`) + skip-stale race guard | ADR-0006 Contract 6+7 ✅ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 24 TR-gsm-* entries.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/game-state-machine.md` (45 ACs) are verified
- All Logic and Integration stories have passing test files in `tests/unit/state_machine/` and `tests/integration/`
- `tests/unit/state_machine/connect_for_initial_state_test.gd` passes (5 scenarios — already written 2026-05-28)
- Rule 2 full transition primitive (Contract 1 lock + Contract 2 transition_id + Contract 3 tombstone) implemented and tested
- CI lint `tools/ci/check_connect_for_initial_state_bind.gd` passes with no violations

## Next Step

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [gamestate-enum-rule1](story-001-gamestate-enum-rule1.md) | Logic | **Complete** ✅ | ADR-0006 C1 |
| 002 | [rule2-atomic-transition](story-002-rule2-atomic-transition.md) | Logic | **Complete** ✅ | ADR-0006 C1 |
| 003 | [transition-id-generation](story-003-transition-id-generation.md) | Logic | **Complete** ✅ | ADR-0006 C2 |
| 004 | [tombstone-serialization](story-004-tombstone-serialization.md) | Integration | **Complete** ✅ | ADR-0006 C2+C3 |
| 005 | [knob-invariants](story-005-knob-invariants.md) | Logic | **Complete** ✅ | ADR-0006 C8 |
| 006 | [subscriber-reentry-guard](story-006-subscriber-reentry-guard.md) | Logic | **Complete** ✅ | ADR-0006 C1 |
| 007 | [no-await-ci-test-spy](story-007-no-await-ci-test-spy.md) | Logic | **Complete** ✅ | ADR-0006 C12+C14 |
| 008 | [iinputpolicy-interface](story-008-iinputpolicy-interface.md) | Logic | **Complete** ✅ | ADR-0006 C13 |
| 009 | [event-intake-queue](story-009-event-intake-queue.md) | Logic | **Complete** ✅ | ADR-0006 C1 |
| 010 | [connect-for-initial-state-tests](story-010-connect-for-initial-state-tests.md) | Logic | **Complete** ✅ | ADR-0006 C6+C7 |
| 011 | [boot-reconciliation-rule5](story-011-boot-reconciliation-rule5.md) | Integration | **Complete** ✅ | ADR-0006 C3 |
| 012 | [weekly-tick-replay](story-012-weekly-tick-replay.md) | Logic | **Complete** ✅ | ADR-0006 C9 |
| 013 | [workout-completed-force-transition](story-013-workout-completed-force-transition.md) | Integration | **Complete** ✅ | ADR-0006 C1 |
| 014 | [lootdrop-reveal-gating](story-014-lootdrop-reveal-gating.md) | Logic | **Complete** ✅ | ADR-0006 C1 |
| 015 | [rule6-zero-input-pillar2](story-015-rule6-zero-input-pillar2.md) | Logic | **Complete** ✅ | ADR-0006 C13 |
| 016 | [bossoutcome-storage-keys](story-016-bossoutcome-storage-keys.md) | Logic | **Complete** ✅ | ADR-0006 C3 |
| 017 | [bfcache-resume-spike](story-017-bfcache-resume-spike.md) | Integration | Deferred (spike — manual evidence required) | ADR-0006 C1 |

## Next Step

Run `/story-readiness production/epics/game-state-machine/story-001-gamestate-enum-rule1.md` then `/dev-story` to begin implementation.

> Implementation order: 001 → 005 → 007 → 008 → 002 → 006 → 003 → 004 → 009 → 010(done) → 016 → 011 → 012 → 013 → 014 → 015 → 017
