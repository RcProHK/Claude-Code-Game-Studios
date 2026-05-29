# Requirements Traceability Matrix

**Generated**: 2026-05-28
**Source**: `docs/architecture/architecture.md` v1.0
**GDDs Covered**: 12 Approved (#1-#3, #5-#9, #11-#14)
**ADRs Referenced**: ADR-0001..ADR-0006

---

## Coverage Summary

| Layer | Requirements | ADR-Covered | Gap |
|-------|-------------|-------------|-----|
| Foundation | 21 | 21 | 0 |
| Core (approved) | 17 | 17 | 0 |
| Cross-cutting | 2 structural | 0 | **2 GAPS** |
| **Total** | **40** | **38** | **2** |

---

## Foundation Layer Requirements

| TR ID | System | Requirement | ADR | Status |
|-------|--------|-------------|-----|--------|
| TR-GSM-001 | #1 GameStateMachine | Atomic state transitions — generational lock | ADR-0006 Contract 1 | ✅ |
| TR-GSM-002 | #1 GameStateMachine | transition_id collision-safety — monotonic counter | ADR-0006 Contract 2 | ✅ |
| TR-GSM-003 | #1 GameStateMachine | Tombstone forward-recovery on boot | ADR-0006 Contract 3 | ✅ |
| TR-GSM-004 | #1 GameStateMachine | Sequential autoload boot order | ADR-0006 Contract 4 | ✅ |
| TR-GSM-005 | #1 GameStateMachine | connect_for_initial_state sentinel | ADR-0006 Contract 6 | ✅ |
| TR-GYMSYS-001 | #2 GymSys | HTTP polling 5s ±0.5s jitter | ADR-0002 | ✅ |
| TR-GYMSYS-002 | #2 GymSys | Server-authoritative session lock | ADR-0002 | ✅ |
| TR-GYMSYS-003 | #2 GymSys | CORS same-origin nginx proxy | ADR-0004 | ✅ |
| TR-GYMSYS-004 | #2 GymSys | SSE v0.2 upgrade path | ADR-0002 | ✅ |
| TR-PERSIST-001 | #3 PersistenceLayer | Backend-primary + IndexedDB secondary | ADR-0003 | ✅ |
| TR-PERSIST-002 | #3 PersistenceLayer | Migration chain ≤900ms | ADR-0003, ADR-0006 Contract 10 | ✅ |
| TR-PERSIST-003 | #3 PersistenceLayer | Private Mode detection + loot-disable | ADR-0003 | ✅ |
| TR-PERSIST-004 | #3 PersistenceLayer | Wall-clock drift tolerance ±300s | ADR-0003 | ✅ |
| TR-PARTICLE-001 | #5 ParticleWrapper | GPUParticles2D ≤200/≤100 mobile | ADR-0001 | ✅ |
| TR-PARTICLE-002 | #5 ParticleWrapper | 9 named presets via PresetId enum | ADR-0001 | ✅ |
| TR-PARTICLE-003 | #5 ParticleWrapper | Mobile UA detection (JavaScriptBridge) | ADR-0001 | ✅ |
| TR-SCREEN-001 | #6 ScreenEffects | Shader-based shake (NOT Camera.offset) | ADR-0001 | ✅ |
| TR-SCREEN-002 | #6 ScreenEffects | Reduce Motion accessibility slider | ADR-0001 | ✅ |
| TR-CAMERA-001 | #7 Camera | Camera2D.position_smoothing | ADR-0001 | ✅ |
| TR-CAMERA-002 | #7 Camera | Focal mode for boss encounters | ADR-0001 | ✅ |
| TR-STREAK-001 | #8 Streak | Cross-day accumulation + drift tolerance | ADR-0003 | ✅ |

---

## Core Layer Requirements (Approved GDDs)

| TR ID | System | Requirement | ADR | Status |
|-------|--------|-------------|-----|--------|
| TR-WORKOUT-001 | #9 WorkoutTracker | set_progress O(1) per 4Hz tick | ADR-0002, ADR-0006 | ✅ |
| TR-WORKOUT-002 | #9 WorkoutTracker | dominant_class derived from set-count-weighted | ADR-0006 | ✅ |
| TR-WORKOUT-003 | #9 WorkoutTracker | Anti-fabrication: events MUST come from GymSys | ADR-0002 | ✅ |
| TR-STAT-001 | #11 StatSystem | Closed mutation API | ADR-0003 | ✅ |
| TR-STAT-002 | #11 StatSystem | VOLUME_TICK batching per set | ADR-0002 | ✅ |
| TR-STAT-003 | #11 StatSystem | PR breakthrough formula (provisional) | ADR-0005 | ✅ |
| TR-ABILITY-001 | #12 AbilitySystem | Unlock via PR breakthrough signal | ADR-0005, ADR-0006 | ✅ |
| TR-ABILITY-002 | #12 AbilitySystem | cast_ability caller whitelist (CI enforced) | ADR-0006 | ✅ |
| TR-COMBAT-001 | #13 CombatResolver | Stateless pure-function combat math | ADR-0006 | ✅ |
| TR-COMBAT-002 | #13 CombatResolver | Hit pause via ScreenEffects signal | ADR-0001 | ✅ |
| TR-COMBAT-003 | #13 CombatResolver | CPU ≤1.0ms per combat tick | ADR-0001 | ✅ |
| TR-ENEMY-001 | #14 EnemyDirector | Wave archetype driven by dominant_class | ADR-0006 | ✅ |
| TR-ENEMY-002 | #14 EnemyDirector | Boss pre-spawn trigger at set_progress threshold | ADR-0006 | ✅ |
| TR-ENEMY-003 | #14 EnemyDirector | enemy_killed carries transition_id | ADR-0005, ADR-0006 | ✅ |
| TR-ENEMY-004 | #14 EnemyDirector | Orchestration CPU ≤0.5ms p95 | ADR-0001 | ✅ |
| TR-LOOT-001 | (ADR-0005) | loot_rarity_score = workout_score×0.75 + rng×0.25 | ADR-0005 | ✅ |
| TR-LOOT-002 | (ADR-0005) | Pillar 1 floor: max RNG = 0.25 < EPIC threshold | ADR-0005 | ✅ |

---

## Structural Gaps (Required New ADRs)

| Gap ID | Description | Impacted Systems | Required ADR | Priority |
|--------|-------------|-----------------|-------------|----------|
| GAP-001 | STRIKE/CONTROL/MOBILITY enum naming convention not locked | #9, #12, #14, all downstream | ADR-0007 | **HIGH — pre-VS implementation** |
| GAP-002 | Autoload position map incomplete for positions 5+ (WorkoutTracker, Audio, Streak, AttentionBudget) | #4, #8, #9, #33 | ADR-0008 | MEDIUM — pre-Pre-MVP sprint |

---

## ADR Acceptance Status

| ADR | Status | Blocks |
|-----|--------|--------|
| ADR-0001 | **Proposed** ⚠️ | #5 AC-24, #6 AC-27/33/34/35, #7 AC-33/34/35 — hardware verification pending |
| ADR-0002 | **Proposed** ⚠️ | #2 CD-CASCADE-A/B/C acceptance criteria |
| ADR-0003 | **Proposed** ⚠️ | #3 Q-E1, #8 AC-37/38/39, #11 stat namespace |
| ADR-0004 | **Proposed** ⚠️ | #2 CORS deployment |
| ADR-0005 | **Proposed** ⚠️ | #9 CI-5 volume_factor, #13 FR-2, #14 FR-2 |
| ADR-0006 | **Accepted 2026-05-28** ✅ | All 15-contract downstream systems (N-002 sync 2026-05-28) |

> **All 6 ADRs must reach Accepted before Production phase.** Run fresh-session `/architecture-review` to generate independent PASS verdict, then flip ADR statuses.
