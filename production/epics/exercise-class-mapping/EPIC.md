# Epic: Exercise → Class Mapping

> **Layer**: Core
> **GDD**: [design/gdd/exercise-class-mapping.md](../../../design/gdd/exercise-class-mapping.md) — **Approved 2026-06-02 (Pass 2)**
> **Architecture Module**: #10 ExerciseClassMapping (`src/autoload/exercise_class_mapping.gd`, Core layer, autoload pos 5)
> **Status**: Ready
> **Stories**: 5 created 2026-06-02 (QL-STORY-READY all ADEQUATE, 26 QA test cases embedded)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Registry schema + core exercise lookup | Logic | ✅ Complete (CI-green 2026-06-02) | ADR-0007 |
| 002 | Movement-pattern lookup + MovementPattern enum | Logic | ✅ Complete (CI-green 2026-06-02) | ADR-0007 |
| 003 | Boot validation loop | Logic | Ready | ADR-0007 |
| 004 | Alias resolution + collision + is_known + edge/FAILED | Logic | Ready | ADR-0007 |
| 005 | Autoload pos 5 registration + CI mutator-ban lint | Integration | Ready | ADR-0008 |

Implementation order: 001 → 002 → 003 → 004 → 005 (each story's `Depends on:` lists prerequisites). Start: `/story-readiness production/epics/exercise-class-mapping/story-001-registry-lookup.md`.

## Overview

ExerciseClassMapping 係 Mirror Hero Pillar 4「Muscle = Class」嘅 canonical 資料層 — 一個 closed lookup service autoload，將 gym exercise_id 映射到 RPG ability class {STRIKE, CONTROL, MOBILITY} ordinal，data-driven 經 `ExerciseRegistry.tres`。核心 spine：push→STRIKE / pull→CONTROL / leg→MOBILITY（1:1:1 LOCKED，無 hybrid per #12 FR-1）。兩個獨立 pure entry point（`get_class_for_exercise` id-lookup / `get_class_for_movement_pattern` pattern-lookup，互不 fallback）+ `is_known_exercise`。未識別 → UNKNOWN sentinel（ADR-0007 no-fabrication，唔猜、唔默默 default 落 STRIKE）。STATELESS — 無 GSM subscription、無 persistence。`#9 WorkoutStateTracker` 擁有 streaming `dominant_class` 聚合，#10 只提供 per-set lookup。玩家唔直接見到，但佢 enable 咗「練乜肌群 = 變成邊個 class」嘅 Pillar 4 因果。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007 (Accepted ✅ 2026-05-29) | Class & Domain Enum Convention — AbilityClass {STRIKE,CONTROL,MOBILITY,UNKNOWN} Classification family; declaration order load-bearing, UNKNOWN sentinel last, zero-default fabrication FORBIDDEN | LOW |
| ADR-0008 (Accepted ✅ 2026-06-01, **#10 rule added 2026-06-02 TD sign-off**) | Autoload Position Map — #10 insertion (after GymSysBackendClient → pos 5) + binding constraint 7 (`ExerciseClassMapping ≺ StatSystem`); project.godot sole ground-truth | MEDIUM (autoload insertion / pos 5-14 renumber) |
| ADR-0003 (Accepted ✅ 2026-05-30) | Save State Strategy — N/A: #10 static config, read-only; NO per-player persistence | LOW |

**Epic Engine Risk: LOW** — 純 categorical lookup + `.tres` load。無 shader / GPUParticles2D / SubViewport / JavaScriptBridge / perf 風險。唯一 engine touchpoint = `.tres` load（Web Export MVP 3 entries 安全）+ autoload pos 5 插入（機械性 project.godot renumber，已有 ADR-0008 insertion rule）。

## GDD Requirements

> ⚠️ **TR-registry note**: tr-registry 暫無 #10 TR-ID（pending `/architecture-review` Phase 8）。下表將 GDD 核心 requirement 對映 governing ADR；建議 epic close 前補跑 /architecture-review 正式登記 TR-ID。Governing ADR 全部 Accepted，story AC 可直接 embed GDD AC（AC-01..AC-15）+ ADR refs（同 #5/#6/#7/#8 epic 創建時做法一致）。

| Requirement (GDD) | Source | ADR Coverage |
|-------------------|--------|--------------|
| AbilityClass enum 引用 canonical 共享 enum（`int` ordinal，inner-enum cross-file 不可作 return type，WST precedent）| Rule 1 | ADR-0007 ✅ |
| Closed lookup API（`get_class_for_exercise`/`get_class_for_movement_pattern`/`is_known_exercise`，無 mutator，CI ban 外部寫）| Rule 2 | ADR-0007 ✅ (no-fabrication posture) |
| `ExerciseRegistry.tres` schema（ExerciseEntry/ExerciseRegistry Resource，sentinel default `-1`）+ boot `_validate_entries()` | Rule 3 | ADR-0007 ✅ (zero-default FORBIDDEN) |
| Movement-pattern → class 1:1:1 spine + 7-member MovementPattern enum | Rule 4 / 4b | ADR-0007 ✅ |
| No fabrication（unmapped → UNKNOWN，consumer 自決 fallback）| Rule 6 | ADR-0007 ✅ |
| StringName/String type contract（`_normalize(raw)→String` cast point，String-keyed internal dicts）| Rule 2 Pass-2 note | (impl — Godot idiom) |
| Autoload pos 5（after GymSys，before StatSystem），STATELESS no-GSM-sub | Q1 / States | ADR-0008 ✅ |
| No per-player persistence（static config）| Overview / Tuning Knobs | ADR-0003 ✅ |
| Registry Coverage Invariant + CI build-time gate（對 GymSys taxonomy snapshot）| Dependencies | (impl — CI script) |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/exercise-class-mapping.md` (AC-01..AC-15) are verified
- All Logic stories have passing test files in `tests/unit/exercise_class_mapping/` (combined GUT gate green)
- `ExerciseClassMapping` autoload inserted at project.godot pos 5 (StatSystem…ScreenEffects renumbered +1); CI position audit + control manifest regenerated
- `check_*` CI lint for read-only mutator ban (owner self-exempt) present and green

### Cross-system epic-close gates (NOT #10 internal work — track separately, open early per producer PR-EPIC)
- **Q5 — #9 WorkoutStateTracker follow-up patch**: UNKNOWN-dominant session display policy (no silent inherit of old class = perceived-fabrication Pillar 4 break). #9 currently 11/12 Complete. Owner: game-designer + #9 WST GDD patch. **Open in parallel with #10 story 1 — do not wait for #10 epic close.**
- **entities.yaml — register full 7-member MovementPattern enum** (disambiguation note already added line 376; `class_id` NOT renamed to preserve merged #11). Owner: systems-designer. **0.5-day registry note, do day 1.**

## Next Step

Run `/create-stories exercise-class-mapping` to break this epic into implementable stories.
