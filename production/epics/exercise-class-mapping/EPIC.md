# Epic: Exercise → Class Mapping

> **Layer**: Core
> **GDD**: [design/gdd/exercise-class-mapping.md](../../../design/gdd/exercise-class-mapping.md) — Designed (pending review) 2026-06-01, lean pass
> **Architecture Module**: ExerciseClassMapping (`src/autoload/exercise_class_mapping.gd` OR static lookup — Open Question Q1; position per ADR-0008 insertion before Stat/Ability/WST)
> **Status**: GDD authored (pending `/design-review`) — all 3 prereq ADRs now Accepted (0007/0008/0003); stories gated on design-review Approved + Q1 autoload-vs-static decision
> **Stories**: Cannot be created until GDD reviewed/approved + Q1 resolved

## Overview

ExerciseClassMapping 係 Pillar 4（Muscle = Class）嘅資料層，將 gym exercises 映射到 STRIKE / CONTROL / MOBILITY ability classes。係 AbilitySystem（#12）同 WorkoutStateTracker（#9）`dominant_class` derivation 嘅 dependency。呢個系統擁有 exercise-to-class lookup table，確保玩家做乜 exercise 就對應邊個 RPG class（e.g., bench press = STRIKE, yoga = CONTROL, cardio = MOBILITY）。Class enum naming convention 必須由 ADR-0007 先鎖定，先可以開始 GDD 設計同 implementation。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007 (Accepted ✅ 2026-05-29) | Class Enum Convention — AbilityClass {STRIKE,CONTROL,MOBILITY,UNKNOWN} locked | LOW |
| ADR-0008 (Accepted ✅ 2026-06-01) | Autoload Position Map — #10 insertion before Stat/Ability/WST (OR static lookup, Q1) | LOW |
| ADR-0003 (Accepted ✅ 2026-05-30) | Save State Strategy — N/A: #10 is static config, NO per-player persistence (Detailed Design) | LOW |

> ✅ 全部 3 prereq ADR Accepted + GDD authored（Designed，pending review）。**Stories blocked** 直至：
> 1. `/design-review design/gdd/exercise-class-mapping.md`（fresh session）→ Approved
> 2. Open Question Q1 resolved（autoload-vs-static + ADR-0008 insertion position）

## GDD Requirements

> 無 tr-registry.yaml entries — GDD authoring 時填入。

## Definition of Done

This epic is complete when:
- GDD is authored (`/design-system 10`) and passes `/design-review`
- ADR-0007 is written and Accepted (STRIKE/CONTROL/MOBILITY enum locked)
- ADR-0008 specifies ExerciseClassMapping autoload position
- All stories are implemented, reviewed, and closed via `/story-done`
- Exercise-to-class mapping table is data-driven (configurable `ExerciseRegistry.tres`, not hardcoded)

## Next Step

1. Run `/architecture-decision "Class Enum Naming Convention"` for ADR-0007 (HIGH priority — blocks #12 + #14 too)
2. Run `/design-system 10` to author the Exercise → Class Mapping GDD
3. Then run `/create-stories exercise-class-mapping`
