# Epic: Attention Budget & Interaction Policy

> **Layer**: Core
> **GDD**: — (Not Started — Tier: Pre-MVP)
> **Architecture Module**: AttentionBudget (`src/autoload/attention_budget.gd` — position TBD per ADR-0008)
> **Status**: Placeholder — GDD required
> **Stories**: Cannot be created until GDD is authored and approved

## Overview

AttentionBudget 係 Mirror Hero Pillar 2（Frictionless Companion）嘅 PRIMARY owner — 係 CD-SYSTEMS gate 加入嘅系統，防止呢個 pillar 嘅 enforcement 喺 GDD authoring drift 中消失。佢定義 hard contracts：每 set 最多 0 次玩家互動（gym session 期間 game 係 companion，唔係主角）、glance budget < 2 秒、notification suppression rules（唔可以在 set active 時觸發任何非致命 notification）、phone-lock/app-switch recovery behavior。消費 GameStateMachine (#1) state_changed + WorkoutStateTracker (#9) phase events 決定 何時可以顯示 UI 元素。對設計而言係 Pillar 2 嘅 constitutional law。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0008 (Queued ❌) | Autoload Full Position Registry — AttentionBudget position undefined | LOW |
| ADR-0006 Contract 4 (Accepted ✅) | Boot order constraint — AttentionBudget pos 11+ | LOW |

> ⚠️ 無 GDD — 此 epic 係 **Pillar 2 placeholder**。所有 stories blocked 直至：
> 1. GDD authored + Approved (`/design-system 33`)
> 2. ADR-0008 specifies AttentionBudget autoload position
> 
> **Risk**: Delaying this GDD means Pillar 2 has no enforcement contract — other systems (HUD, notifications) will drift without it.

## GDD Requirements

> 無 tr-registry.yaml entries — GDD authoring 時填入。

## Definition of Done

This epic is complete when:
- GDD is authored (`/design-system 33`) and passes `/design-review`
- ADR-0008 specifies AttentionBudget autoload position
- All stories are implemented, reviewed, and closed via `/story-done`
- Hard contracts verified: max 0 interactions per SET_ACTIVE state
- Glance budget test: any UI triggered during SET_ACTIVE fails CI lint
- Phone-lock recovery test: game resumes correct WorkoutPhase state after app-switch

## Next Step

1. Run `/architecture-decision "Autoload Full Position Registry"` for ADR-0008
2. Run `/design-system 33` to author the Attention Budget & Interaction Policy GDD
3. Then run `/create-stories attention-budget-policy`

> ★ Pillar 2 PRIMARY — author this GDD before any Presentation layer HUD work begins.
