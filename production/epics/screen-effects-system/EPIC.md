# Epic: Screen Effects System

> **Layer**: Foundation
> **GDD**: design/gdd/screen-effects-system.md
> **Architecture Module**: ScreenEffects (autoload pos 6, `src/autoload/screen_effects.gd`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories screen-effects-system`

## Overview

ScreenEffects 係 Mirror Hero 嘅「體感反饋 channel」infrastructure，與 ParticleSystemWrapper（視覺 channel）配對。實現 Trauma² decay 公式嘅 shader-uniform-based 畫面震動（NOT `Camera2D.offset` — CI 強制禁止）、hit pause（凍結 `get_tree().paused` + `Engine.time_scale` 受控使用）、慢動作（`Engine.time_scale`）、同 Reduce Motion accessibility slider（`motion_intensity` [0.0, 1.0]）。所有震動透過 shader uniform `screen_shake_strength` 實現，確保同 camera 系統完全解耦。係 CombatResolver 嘅 critical feedback path — crit hit → `add_trauma(COMBAT, amount)` 讓玩家感受到「DNF 重擊」Pillar 3 衝擊感。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001 (Proposed ⚠️) | Web Export Budget Caps — shader uniform path, CanvasLayer topology, `Camera2D.offset` CI ban | HIGH |
| ADR-0006 Contracts 4+6 (Accepted ✅) | Boot order pos 6 (after ParticleWrapper), `connect_for_initial_state` for GSM subscription | MEDIUM |

> ⚠️ ADR-0001 Proposed — 3 個 ACs（FR-1/2/3）係 ADR-RATIFICATION-GATED。

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
