# Epic: Particle System Wrapper

> **Layer**: Foundation
> **GDD**: design/gdd/particle-system-wrapper.md
> **Architecture Module**: ParticleSystemWrapper (autoload pos 12, `src/autoload/particle_system_wrapper.gd`)
> **Status**: Implemented 8/9 — 001-008 Complete (CI-green), 009 BLOCKED (ADR-0001 CPU ratification)
> **Stories**: 9 stories（001-008 Complete, 009 BLOCKED）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | play() API + ParticleHandle Contract | Logic | Complete | ADR-0001 |
| 002 | Object Pool + Tier Selection + No-Realloc | Logic | Complete | ADR-0001 |
| 003 | CPU Ledger + Formula 1 Multiplier Composition | Logic | Complete | ADR-0001 |
| 004 | LRU Eviction + Hybrid LOOT Carve-Out | Logic | Complete | ADR-0001 |
| 005 | Mobile UA Detection (Boot-Cached) | Logic | Complete | ADR-0001 |
| 006 | burst_started Signal + Re-entry Guard + CI Lint | Logic | Complete | ADR-0001 |
| 007 | Boot Sequence + State Machine + Lifecycle | Integration | Complete | ADR-0006 C6 |
| 008 | Preset Library + Visual Spec .tres Assets | Config/Data | Complete | ADR-0001 |
| 009 | [BLOCKED] ADR-0001 Hardware Ratification FR-1/2/3 | Visual/Feel | Blocked | ADR-0001 |

## Overview

ParticleSystemWrapper 係 Mirror Hero 嘅 GPU particle 唯一 gateway，管理 16-node pool（8 Small / 6 Medium / 2 Large）同 9 個命名 presets（HIT_LIGHT / HIT_HEAVY / PARRY / DEATH / LOOT_BURST / LOOT_RARE_BURST / STATUS_BURN / STATUS_FREEZE / STATUS_STUN — authoritative names per GDD），透過 LRU eviction 策略確保 ≤200 active particles（desktop）/ ≤100（mobile 0.5×）。Mobile UA detection（cached at boot via JavaScriptBridge）決定 tier。直接 `GPUParticles2D` 初始化被 CI lint 禁止 — 所有 particle emission 必須過呢個 wrapper。佢係 EnemyDirector (#14) + CombatResolver (#13) 嘅核心視覺反饋渠道，直接影響 Pillar 3 Drop Euphoria 嘅儀式感質量。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001 (Accepted-structural ✅ 2026-05-30) | Web Export Budget Caps — ≤200 particles (desktop) / ≤100 (mobile); 9 preset architecture; WASM bundle ≤50MB. Structural decisions Accepted (renderer/topology/CI/particle-cap); CPU budget *numbers* remain Provisional pending VS-tier mobile profiling | HIGH |
| ADR-0006 Contract 6 (Accepted ✅) | `connect_for_initial_state` for GSM subscription + boot order pos 12 | MEDIUM |

> ⚠️ ADR-0001 結構決策 **Accepted**（renderer/topology/CI/particle-cap），可起普通 stories。但 CPU/perf budget **數字** 仍 Provisional（VS-tier mobile profiling 未做）。3 個 perf ACs（AC-24/25/26 = FR-1/2/3 hardware claims）係 ADR-RATIFICATION-GATED，留喺 Story 009 (BLOCKED) 直至 VS hardware spike 完成。

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-particle-001 | GPUParticles2D ≤200 active (desktop), ≤100 (mobile 0.5×) — LRU eviction | ADR-0001 ✅ (cap structural; perf number Provisional) |
| TR-particle-002 | 9 named presets via `ParticleSystemWrapper.PresetId` enum | ADR-0001 ✅ |
| TR-particle-003 | Mobile UA detection via JavaScriptBridge (cached at boot, immutable after `_ready`) | ADR-0001 ✅ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 23 TR-particle-* entries.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/particle-system-wrapper.md` (27 ACs: 23 BLOCKING + 4 ADVISORY) verified
- Logic stories: passing unit tests in `tests/unit/particle/` (pool management, preset dispatch, LRU eviction)
- Visual/Feel stories: screenshot evidence in `production/qa/evidence/` + lead sign-off
- ADR-0001 ratification stories: VS hardware spike on iOS Safari WebGL2 + update provisional CPU values
- CI lint `tools/ci/check_particle_callers.gd` passes (no direct GPUParticles2D instantiation)

## Next Step

Run `/create-stories particle-system-wrapper` to break this epic into implementable stories.

> ✅ ADR-0001 結構決策 Accepted — Stories 001-008 可即刻起（structural ACs + behaviour 全部 headless-testable）。ADR-0001 hardware spike 收喺 **Story 009 (BLOCKED)**，只 gate perf ACs (AC-24/25/26)，唔再 block 其餘 stories。
