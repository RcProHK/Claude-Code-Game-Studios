# Epic: Camera System

> **Layer**: Foundation
> **GDD**: design/gdd/camera-system.md
> **Architecture Module**: CameraController (autoload pos 13, `src/autoload/camera_controller.gd`)
> **Status**: Implemented (10/12 CI-green 2026-06-01)
> **Stories**: 12 stories（001-010 Complete CI-green, 011 BLOCKED #22, 012 BLOCKED ADR-001 hw）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Camera Registration + API Surface | Logic | Complete | ADR-0001 |
| 002 | Input Validation + Parameter Guards | Logic | Complete | ADR-0001 |
| 003 | Follow Math + Dead-zone + Pillar 2 Lock-on | Logic | Complete | ADR-0001 |
| 004 | Focal Entry Tween + Quart Ease + Defaults | Logic | Complete | ADR-0001 |
| 005 | Focal Exit Tween + Cubic Ease + PAUSABLE | Integration | Complete | ADR-0001 |
| 006 | Focal Gating + Re-entry Guard + Force-clear | Integration | Complete | ADR-0001 |
| 007 | Suspended Cancel + bfcache Resume | Integration | Complete | ADR-0001 |
| 008 | Lifecycle — target-lost + Viewport + Focal-clamp | Integration | Complete | ADR-0001 |
| 009 | Boot + GSM + CI Lint + Persistence + Decoupling | Integration | Complete | ADR-0006 |
| 010 | Focal Invitation Perceptual Playtest | Visual/Feel | Complete | ADR-0001 |
| 011 | [BLOCKED #22] Motion Reduction Accessibility API | Integration | Blocked | ADR-0006 |
| 012 | [BLOCKED] ADR-001 Hardware Ratification FR-1/2/3 | Performance | Blocked | ADR-0001 |

## Overview

CameraSystem 係 Mirror Hero 嘅「Silent Showrunner」— 玩家唔會直接感知到佢，但佢持續框住行動、引導視覺焦點、配合 boss 戲劇性時刻。實現 Camera2D frame-rate-independent position smoothing（Godot 4.6 `position_smoothing`，Compatibility renderer 驗證 HIGH priority）、Normal follow mode、同 Focal mode（boss encounter 時 lock focus 到 boss）。所有 `Camera2D.position/zoom/make_current()` mutation 必須透過此 autoload（CI 強制）。畫面震動 via ScreenEffects shader uniform，唔係 `Camera2D.offset`（CI 強制 + signal 解耦）。14 Rules + 36 ACs（32 BLOCKING）覆蓋 bfcache resume、zoom smoothing、focal override 等邊緣情況。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001 (Accepted-structural ✅ 2026-05-30) | Web Export Budget Caps — Camera2D.position_smoothing Compatibility renderer compat. Structural decisions Accepted; CPU/perf/smoothness *numbers* remain Provisional pending VS-tier profiling | HIGH |
| ADR-0006 Contracts 4+6 (Accepted ✅) | Boot order pos 13 (after ScreenEffects pos 14? No — after ParticleWrapper pos 12 + before ScreenEffects pos 14), `connect_for_initial_state` for GSM subscription, decoupled from ScreenEffects via CI Rule 13 | MEDIUM |

> ✅ ADR-0001 結構決策 Accepted（2026-05-30）— Stories 001-010 可即刻實作（structural + behavioral ACs 全 headless-testable）。3 個 perf/hardware ACs（AC-33 FR-1 CPU、AC-34 FR-2 smoothness、AC-35 FR-3 CI-caller-gating）係 ADR-RATIFICATION-GATED，收喺 Story 012 (BLOCKED) 直至 VS hardware spike 完成。AC-06b + AC-27（post-#22 GDD gated）收喺 Story 011 (BLOCKED)。

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
