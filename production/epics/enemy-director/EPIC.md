# Epic: Enemy Director

> **Layer**: Core
> **GDD**: design/gdd/enemy-director.md
> **Architecture Module**: EnemyDirector (autoload pos 10 — LAST among current autoloads, `src/autoload/enemy_director.gd`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories enemy-director`

## Overview

EnemyDirector 係「無形軍師」— Pillar 2（Frictionless Companion）PRIMARY protector 同 Pillar 3（Drop Euphoria）PRIMARY substrate。佢擁有 wave spawn lifecycle、boss anchor、同 AI state machines，orchestrating 玩家看到嘅所有敵人動態。Wave archetype selection（STRIKE/CONTROL/MOBILITY × 3 difficulty tiers）由 WorkoutStateTracker.dominant_class 驅動（anti-fabrication chain 延伸）。Boss pre-spawn trigger at `set_progress ≥ pre_spawn_threshold`，boss anchor commit 後 `enemy_killed` signal 攜帶 `transition_id` 作為 loot chain seed（ADR-0005 FR-2）。自動處理 catchup backlog（5s polling cadence bound）。`pos 10 = LAST` 確保所有 upstream autoloads（特別係 Particles/ScreenEffects/Camera）ready 先可以 spawn。12-layer CI lint suite 係 Foundation+Core 最全面嘅架構防衛。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001 (Proposed ⚠️) | Web Export Budget Caps — FR-4 mobile particle floor, 0.5ms p95 orchestration CPU budget | HIGH |
| ADR-0002 (Proposed ⚠️) | GymSys Integration Protocol — catchup backlog cadence bound by 5s polling | MEDIUM |
| ADR-0005 (Proposed ⚠️) | Loot Rarity Formula — FR-2 `enemy_killed.transition_id` → #15 LootDrop 4-hop chain binding | LOW |
| ADR-0006 Contracts 2+4+6 (Accepted ✅) | transition_id atomicity, boot order pos 10 LAST, connect_for_initial_state | MEDIUM |
| ADR-0007 (Queued ❌) | Class Enum Naming Convention — wave archetype data files (STRIKE/CONTROL/MOBILITY Faction enum) | LOW |

> ⚠️ **ADR-0007 untraced gap**: wave archetype Faction/EnemyAIState/BossAnchorState enum naming convention 未 locked。Implementation stories for wave archetype data files blocked until ADR-0007 Accepted。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-enemy-001 | Wave archetype selection driven by `WorkoutStateTracker.get_dominant_class()` | ADR-0006 ✅ |
| TR-enemy-002 | Boss pre-spawn trigger at `set_progress ≥ pre_spawn_threshold` | ADR-0006 ✅ |
| TR-enemy-003 | `enemy_killed` signal carries `transition_id` (loot chain seed) | ADR-0005 ⚠️ + ADR-0006 Contract 2 ✅ |
| TR-enemy-004 | Orchestration CPU ≤0.5ms p95 per frame | ADR-0001 ⚠️ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 21 TR-enemy-* entries.
> ⚠️ Untraced: wave archetype enum convention (pending ADR-0007).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/enemy-director.md` (38 ACs: 31 BLOCKING + 5 ADVISORY + 2 ADR-RATIFICATION-GATED) verified
- ADR-0007 Accepted before wave archetype data file stories start
- Logic stories: wave archetype selection tests + boss pre-spawn trigger tests in `tests/unit/enemy/`
- Integration stories: EnemyDirector ↔ WorkoutStateTracker + ↔ CombatResolver integration tests
- CPU benchmark: orchestration ≤0.5ms p95 on WASM target (mock particle spawns)
- `enemy_killed.transition_id` chain test: signal carries valid non-null transition_id from GSM

## Next Step

Run `/create-stories enemy-director` to break this epic into implementable stories.

> ⚠️ EnemyDirector requires #5 Particles + #6 ScreenEffects + #7 Camera + #9 WorkoutStateTracker + #13 CombatResolver all ready before integration stories can run.
