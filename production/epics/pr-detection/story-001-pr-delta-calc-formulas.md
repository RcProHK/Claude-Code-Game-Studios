# Story 001: PRDeltaCalc shared static + Formula 1 e1rm goldens

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: ✅ Complete(2026-06-06 — 9/9 tests;combined gate 1853/1852/0 fail)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Formula 1 / Formula 3 / D3 / D7)
**Requirement**: GDD-direct(TR registry 未有 #18 entries — #16/#17 先例)
**ADR Governing Implementation**: ADR-0005(PR_BASE=6.0 PROVISIONAL — #11/ADR-0005 own,#18 只引用);secondary ADR-0011(D3 單一 source)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:gameplay values data-driven(讀 #11 config 常數,唔 inline 重抄 — D3 knob-drift 防線);doc comments on public APIs
- Forbidden:hardcode PR_BASE / DIMINISH_EXP / MAX_STAT_VALUE 喺 #18 側

## Acceptance Criteria

- [ ] **AC-11**:`e1rm(60,5)==70.0`;`e1rm(65,3)==71.5`;`e1rm(100,1)≈103.33`(reps=1 唔特判);`e1rm(100,15)==140.0`(D7 clamp)
- [ ] **AC-12**:`PRDeltaCalc.compute(12.0, 0.0833) ≈ 0.500`(±0.001;pinned 於 PROVISIONAL PR_BASE=6.0 — retune 時 update test)
- [ ] **AC-13(compute 半)**:`compute(999.0, m)==0.0` for m ∈ {0.01, 0.5, 2.0}
- [ ] **AC-05(formula 半)**:`e1rm(110,15)==154.0`(clamp 後加重照升)

## Implementation Notes

- `src/core/pr_delta_calc.gd`:`class_name PRDeltaCalc` static `compute(current_stat: float, magnitude: float) -> float` — 讀 #11 Formula 2 常數(grep `stat_system.gd` 確認常數所在;唔複製值)。新 class_name → CI 要 `godot --headless --import` 刷 cache。
- Formula 1 e1rm:static helper(放 PRDeltaCalc 或 PrDetection — 實作時定;`E1RM_DIVISOR` 必須 `30.0` **float literal**(`5/30` int division == 0 陷阱);`effective_reps = min(reps, REP_CAP)`。
- Goldens 全部 GDD qa-verified pinned vectors — 唔好自創。

## Out of Scope

- 判定 pipeline(005)/ eligibility(004)/ stat 生效 call(009)。

## QA Test Cases

GDD AC-11 / AC-12 / AC-13(sample set)/ AC-05 formula goldens — GWT 直接照 GDD(qa Pass 2 verified)。Edge:int division 陷阱 vector(`e1rm` 用 int args call 都要啱)。

## Test Evidence

**Required**:`tests/unit/pr_detection/test_pr_delta_calc.gd` — must pass。
**Status**: [x] `tests/unit/pr_detection/test_pr_delta_calc.gd` — 9/9 pass(combined gate green)

## Dependencies

- Depends on: None(pure formulas — START HERE)
- Unlocks: 005, 007, 009
