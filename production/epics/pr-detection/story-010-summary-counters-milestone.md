# Story 010: Session summary(Formula 5)+ lifetime counters + milestone

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: ✅ Complete(2026-06-06 — gate green:combined 1905/1904,0 fail)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Formula 5 / Rule 9 / EC-12 / EC-13)
**ADR**: ADR-0009(payload minimal);secondary ADR-0006 C3
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-18**:同 exercise 兩 PR → 1 entry = m 最大 set 嘅完整 tuple(weight_kg=65.0/reps=5/e1rm_kg=75.833±0.001/magnitude=0.0833 — 四 field 同源);兩 exercise → 2 entries;`workout_completed` 後 summary **仍在**;下一 `workout_started` 先 clear
- [ ] **AC-19**:count 9→10 → `pr_milestone_reached(10)`;boot 載入 count=10 → 零 re-emit(crossing-only)
- [ ] **AC-20**:config [10,5,50] → `validate_milestone_config()==false` + push_error(spy — 唔用 raw assert)
- [ ] EC-13:`workout_completed` 後遲到 set 判 PR → stat 照生效,**唔入 summary** + `pr.late_set`

## Implementation Notes

- Summary clear 訂 #2 `workout_started`(唔係 workout_completed — subscriber-order race);`e1rm_kg` 命名(唔係 one_rm — Pillar 1 honesty)。`lifetime_pr_score += magnitude`(#19 v0.2 PR_SCORE data surface)。Milestone thresholds `PRMilestoneConfig.tres` PROVISIONAL — **MVP 無 consumer(telemetry only;#19 P2 裁決)**。
- `get_session_pr_summary()` / `get_baselines()` read-only defensive copies。

## Out of Scope

- Receipt 製作(#15/#17 consumer 面)。

## QA Test Cases

GDD AC-18/19/20 GWT + EC-13 vector。

## Test Evidence

**Required**:`tests/unit/pr_detection/test_summary_milestone.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 005
- Unlocks: —
