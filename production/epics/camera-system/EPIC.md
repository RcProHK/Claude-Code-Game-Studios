# Epic: Camera System

> **Layer**: Foundation
> **GDD**: design/gdd/camera-system.md
> **Architecture Module**: CameraSystem (autoload pos 7, `src/autoload/camera_system.gd`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories camera-system`

## Overview

CameraSystem 係 Mirror Hero 嘅「Silent Showrunner」— 玩家唔會直接感知到佢，但佢持續框住行動、引導視覺焦點、配合 boss 戲劇性時刻。實現 Camera2D frame-rate-independent position smoothing（Godot 4.6 `position_smoothing`，Compatibility renderer 驗證 HIGH priority）、Normal follow mode、同 Focal mode（boss encounter 時 lock focus 到 boss）。所有 `Camera2D.position/zoom/make_current()` mutation 必須透過此 autoload（CI 強制）。畫面震動 via ScreenEffects shader uniform，唔係 `Camera2D.offset`（CI 強制 + signal 解耦）。14 Rules + 36 ACs（32 BLOCKING）覆蓋 bfcache resume、zoom smoothing、focal override 等邊緣情況。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001 (Proposed ⚠️) | Web Export Budget Caps — Camera2D.position_smoothing Compatibility renderer compat, FR-1/2/3 ratification-gated | HIGH |
| ADR-0006 Contracts 4+6 (Accepted ✅) | Boot order pos 7, `connect_for_initial_state` for GSM subscription, decoupled from ScreenEffects via CI Rule 13 | MEDIUM |

> ⚠️ ADR-0001 Proposed — Camera2D.position_smoothing iOS Safari WebGL2 stability unverified (QQ-01). 3 個 ACs（FR-1/2/3）blocked。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-camera-001 | `Camera2D.position_smoothing` (frame-rate-independent, Compatibility renderer) | ADR-0001 ⚠️ |
| TR-camera-002 | Focal mode for boss encounters (EnemyDirector forward contract) | ADR-0001 ⚠️ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 14 TR-camera-* entries.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/camera-system.md` (36 ACs: 32 BLOCKING + 1 ADVISORY + 3 RATIFICATION-GATED) verified
- Logic stories: follow mode + focal mode unit tests in `tests/unit/camera/`
- Visual/Feel stories: screenshot evidence showing focal mode on boss + `production/qa/evidence/` sign-off
- ADR-0001 hardware spike: `Camera2D.position_smoothing` verified on iOS Safari WebGL2
- CI lint `tools/ci/check_camera_callers.gd` passes (no direct Camera2D mutation outside camera_controller.gd)

## Next Step

Run `/create-stories camera-system` to break this epic into implementable stories.
