# Epic: Workout State Tracker

> **Layer**: Core
> **GDD**: design/gdd/workout-state-tracker.md
> **Architecture Module**: WorkoutStateTracker (autoload pos 9, `src/autoload/workout_state_tracker.gd`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories workout-state-tracker`

## Overview

WorkoutStateTracker 係 Mirror Hero 嘅「肌群預言家 / The Muscle Oracle」— Pillar 4（Muscle = Class）PRIMARY substrate。佢擁有 WorkoutPhase FSM（IDLE / WARM_UP / SET_ACTIVE / REST_PERIOD / WORKOUT_COMPLETE），管理 `set_progress` O(1) computation（4Hz perception tick）同 `dominant_class` derivation（set-count-weighted STRIKE/CONTROL/MOBILITY）。消費 GymSys Backend Client 嘅 workout event stream，係 anti-fabrication quintet 第五件套（#2→#3→#11→#14→#9 chain complete）。`set_progress ≥ pre_spawn_threshold` 觸發 boss pre-spawn，`workout_completed` signal 觸發 loot ritual chain。亦係 `wst.*` PersistenceLayer namespace 首個 adopter。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002 (Proposed ⚠️) | GymSys Integration Protocol — consumes 7 #2 signal contracts (set_completed, workout_completed) | MEDIUM |
| ADR-0006 Contracts 2/4/6/9 (Accepted ✅) | transition_id acquisition, boot order pos 9, connect_for_initial_state, is_expired TTL for snapshot | MEDIUM |

> ⚠️ ADR-0002 Proposed — gym event consumption stories auto-blocked 直至 ADR-0002 Accepted。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-wst-001 | `get_set_progress()` O(1) computation per 4Hz perception tick | ADR-0006 ✅ |
| TR-wst-002 | `get_dominant_class()` derived from set-count-weighted push/pull/leg | ADR-0006 ✅ |
| TR-wst-003 | Anti-fabrication: workout events MUST come from #2 GymSys backend only | ADR-0002 ⚠️ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 19 TR-wst-* entries.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/workout-state-tracker.md` (43 ACs: 41 BLOCKING + 1 ADVISORY + 1 ADR-RATIFICATION-GATED) verified
- Logic stories: set_progress formula unit tests + dominant_class derivation tests in `tests/unit/workout/`
- Integration story: GymSys event → WorkoutPhase transition integration test
- `workout_completed` signal carries `workout_id` (not null) — anti-fabrication chain verified
- 4Hz timer stability test: set_progress computed within ≤1ms per tick on WASM

## Next Step

Run `/create-stories workout-state-tracker` to break this epic into implementable stories.
