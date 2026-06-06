# Story 004: Eligibility gate + class routing

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: ✅ Complete(2026-06-06 — gate green:combined 1872/1871,0 fail)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Rule 1 / Rule 2 / D4 / EC-1 / EC-6)
**ADR**: ADR-0011(D-1 facts);secondary ADR-0002(payload schema Locked)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:handler 簽名跟 #2 GDD `String`(citation 一致;String↔StringName implicit convert 無 bug)
- Forbidden:#18 永不行 raw count path 以外嘅 fabrication 面(Pillar 1 cardio gate)

## Acceptance Criteria

- [ ] **AC-04**:#10 回 UNKNOWN → skip:零 stat call / 零 signal / 零 baseline/candidate write / 零 persist + `pr.unknown_exercise`(spy)
- [ ] **AC-09**:push/pull/leg 三 exercise 各一 PR → route `&"str"` / `&"dex"` / `&"vit"`(D4 golden;**StatId 值係 lowercase StringName** — #17 Q-1 教訓)
- [ ] **AC-25**:`(reps=0)` / `(weight=0)` / `(weight=600)` / `(weight=0.5)` 四 vector 全 skip + `pr.input_invalid`,零 side effect

## Implementation Notes

- Rule 2 順序:reps/weight 基本 → WEIGHT_SANITY_MAX(500)/ MIN(1.0)→ #10 UNKNOWN。**高 rep 唔係 skip 條件**(D7 clamp 喺 Formula 1)。
- `set_logged(exercise_id: String, reps: int, weight: float)` 直訂 #2(SIBLING split,#9 L863)。

## Out of Scope

- 判定(005)/ establishment(006)。

## QA Test Cases

GDD AC-04 / AC-09 / AC-25 GWT(pinned vectors)。

## Test Evidence

**Required**:`tests/unit/pr_detection/test_eligibility_gate.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 002
- Unlocks: 005
