# Epic: Screen Effects System

> **Layer**: Foundation
> **GDD**: design/gdd/screen-effects-system.md
> **Architecture Module**: ScreenEffects (autoload pos 14, `src/autoload/screen_effects.gd`)
> **Status**: Implemented 10/11 — 001-010 Complete (CI-green 1266/1267), 011 BLOCKED (ADR-0001 hw ratification)
> **Stories**: 11 stories（001-010 Complete, 011 BLOCKED）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | shake/hit_pause/set_motion_intensity API + Input Validation | Logic | Complete | ADR-0001 |
| 002 | Trauma² Decay + noise_sample + Epsilon Short-circuit | Logic | Complete | ADR-0001 |
| 003 | Trauma Combiner + Motion Intensity + Hierarchy Invariant | Logic | Complete | ADR-0001 |
| 004 | Hit Pause Formulas — max-remaining + ceiling | Logic | Complete | ADR-0001 |
| 005 | Selective Freeze + PROCESS_MODE_ALWAYS + hit_pause_started Signal | Integration | Complete | ADR-0001 |
| 006 | Dispatch Table + burst_started Auto-Reaction | Integration | Complete | ADR-0001 |
| 007 | Re-entry Guard + Suspended State + bfcache Hardening | Integration | Complete | ADR-0001 |
| 008 | Boot Sequence + Autoload Pos 14 + CI Lint + Persistence Ban | Integration | Complete | ADR-0001 |
| 009 | SettingsManager Propagation Contract | Integration | Complete | ADR-0006 |
| 010 | HUD Toggle + CanvasLayer Topology | Visual/Feel | Complete | ADR-0001 |
| 011 | [BLOCKED] ADR-001 Hardware Ratification FR-1/2/3 | Visual/Feel | Blocked | ADR-0001 |

## Overview

ScreenEffects 係 Mirror Hero 嘅「體感反饋 channel」infrastructure，與 ParticleSystemWrapper（視覺 channel）配對。實現 Trauma² decay 公式嘅 shader-uniform-based 畫面震動（NOT `Camera2D.offset` — CI 強制禁止）、hit pause（凍結 `get_tree().paused` + `Engine.time_scale` 受控使用）、慢動作（`Engine.time_scale`）、同 Reduce Motion accessibility slider（`motion_intensity` [0.0, 1.0]）。所有震動透過 shader uniform `screen_shake_strength` 實現，確保同 camera 系統完全解耦。係 CombatResolver 嘅 critical feedback path — crit hit → `add_trauma(COMBAT, amount)` 讓玩家感受到「DNF 重擊」Pillar 3 衝擊感。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001 (Accepted-structural ✅ 2026-05-30) | Web Export Budget Caps — shader uniform path, CanvasLayer topology, `Camera2D.offset` CI ban. Structural decisions Accepted; CPU/perf *numbers* remain Provisional pending VS-tier profiling | HIGH |
| ADR-0006 Contracts 4+6 (Accepted ✅) | Boot order pos 14 (after ParticleSystemWrapper pos 12), `connect_for_initial_state` for GSM subscription | MEDIUM |

> ✅ ADR-0001 結構決策 Accepted（2026-05-30）— Stories 001-010 可即刻實作（structural + behavioral ACs 全 headless-testable）。3 個 perf/hardware ACs（AC-27 FR-1 CPU、AC-28 FR-2 playtest、AC-29 FR-3 CI-drift）係 ADR-RATIFICATION-GATED，收喺 Story 011 (BLOCKED) 直至 VS hardware spike 完成。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-screen-001 | Screen shake via shader uniform (NOT `Camera2D.offset` — CI enforced) | ADR-0001 ⚠️ |
| TR-screen-002 | `motion_intensity` accessibility slider [0.0, 1.0] — Reduce Motion support | ADR-0001 ⚠️ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 14 TR-screen-* entries.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/screen-effects-system.md` (29 ACs: 25 BLOCKING + 1 ADVISORY + 3 RATIFICATION-GATED) verified
- Logic stories: Trauma² decay formula unit test + hit pause timing test in `tests/unit/screen_effects/`
- Visual/Feel stories: screenshot evidence + motion_intensity=0 smoke test in `production/qa/evidence/`
- CI lint `tools/ci/check_screen_effects_callers.gd` passes (no direct `Camera2D.offset` mutation outside screen_effects.gd)

## Next Step

Run `/create-stories screen-effects-system` to break this epic into implementable stories.
