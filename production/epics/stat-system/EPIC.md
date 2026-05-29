# Epic: Stat System

> **Layer**: Core
> **GDD**: design/gdd/stat-system.md
> **Architecture Module**: StatSystem (`src/autoload/stat_system.gd`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories stat-system`

## Overview

StatSystem 擁有並保護 Mirror Hero 嘅 7 個 player stats（ATK / HP / DEX / STR / VIT / MOVE_SPEED / CRIT_CHANCE），係 Pillar 1（Real Body, Real Power）anti-fabrication trio 成員（paired with #2 GymSys + #3 PersistenceLayer）。Closed mutation API（唔有外部 write path — 所有 mutation 只能透過內部事件處理）係 #11 確立嘅 template pattern，所有後續 Core 系統都要跟從。消費 GymSys `VOLUME_TICK`（per-rep 累積，`set_completed` 時 flush）同 `PR_BREAKTHROUGH` events 更新 stats。`stat_changed` signal 下游到 AbilitySystem / CombatResolver / EnemyDirector。`stat.*` namespace 係 PersistenceLayer 嘅 first Core-tier adopter。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003 (Proposed ⚠️) | Save State Strategy — `stat.*` namespace, closed mutation pattern | LOW |
| ADR-0005 (Proposed ⚠️) | Loot Rarity Formula — `PR_BASE` PROVISIONAL formula (Q-A1 pending cross-validation) | LOW |
| ADR-0006 Contracts 3/4/6 (Accepted ✅) | SerializableResource + boot order + connect_for_initial_state | LOW |

> ⚠️ ADR-0003 + ADR-0005 Proposed — 3 個 ADR-RATIFICATION-GATED ACs blocked 直至 ratification。PR breakthrough formula (TR-stat-003) provisional pending Q-A1 empirical data from VS playtest。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-stat-001 | Closed mutation API — only StatSystem may write stat values (no external write path) | ADR-0003 ⚠️ |
| TR-stat-002 | VOLUME_TICK batching — accumulate per rep, flush at set_completed signal | ADR-0002 ⚠️ |
| TR-stat-003 | PR breakthrough provisional formula (`PR_BASE` pending Q-A1 validation) | ADR-0005 ⚠️ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 17 TR-stat-* entries.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/stat-system.md` (37 ACs: 24 BLOCKING + 10 ADVISORY + 3 ADR-RATIFICATION-GATED) verified
- Logic stories: all 6 stat formula unit tests in `tests/unit/stat/`
- Closed mutation test: external write attempt blocked (push_error + no state change)
- VOLUME_TICK batching test: accumulate N reps, flush on set_completed → single stat update
- Cross-formula invariants (4) verified: no formula produces negative stat values

## Next Step

Run `/create-stories stat-system` to break this epic into implementable stories.
