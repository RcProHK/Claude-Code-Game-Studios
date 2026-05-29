# Epic: Exercise → Class Mapping

> **Layer**: Core
> **GDD**: — (Not Started — Tier: Pre-MVP)
> **Architecture Module**: ExerciseClassMapping (`src/autoload/exercise_class_mapping.gd` — position TBD per ADR-0008)
> **Status**: Placeholder — GDD + ADR-0007 + ADR-0008 required
> **Stories**: Cannot be created until GDD is authored and approved

## Overview

ExerciseClassMapping 係 Pillar 4（Muscle = Class）嘅資料層，將 gym exercises 映射到 STRIKE / CONTROL / MOBILITY ability classes。係 AbilitySystem（#12）同 WorkoutStateTracker（#9）`dominant_class` derivation 嘅 dependency。呢個系統擁有 exercise-to-class lookup table，確保玩家做乜 exercise 就對應邊個 RPG class（e.g., bench press = STRIKE, yoga = CONTROL, cardio = MOBILITY）。Class enum naming convention 必須由 ADR-0007 先鎖定，先可以開始 GDD 設計同 implementation。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007 (Queued ❌) | Class Enum Naming Convention — STRIKE/CONTROL/MOBILITY naming standard + narrative display name localization separation | LOW |
| ADR-0008 (Queued ❌) | Autoload Full Position Registry — ExerciseClassMapping position undefined | LOW |
| ADR-0003 (Proposed ⚠️) | Save State Strategy — class mapping persisted via `exercise.*` namespace (pending GDD) | LOW |

> ⚠️ 無 GDD — 此 epic 係 **placeholder**。**所有 stories blocked** 直至：
> 1. ADR-0007 Class Enum Naming Convention written + Accepted
> 2. GDD authored + Approved (`/design-system 10`)
> 3. ADR-0008 autoload position specified

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
