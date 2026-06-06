# Story 009: Stat 生效 path(all-or-nothing / cap short-circuit)

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Rule 6.1-6.3 / EC-3)
**ADR**: ADR-0006(C4 — #11 接口);secondary ADR-0011 §D-3(guarantee mapping:#18 自己層 clamp 係防線)
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-08**:`apply_stat_delta` mock false → baseline 不變、零 signal、lifetime_count 不變、summary 不變、零 persist(all-or-nothing 三 count 面 enumerate)
- [ ] **AC-13(short-circuit 半)**:capped 玩家(stat 999,δ==0)→ **零** `apply_stat_delta` call、baseline 照升、signal/count 照 emit

## Implementation Notes

- `pr_delta > 0.0` 先 call;`==0.0` short-circuit 行 6.4-6.7(唔依賴 #11 zero-delta 未 pin 行為)。`ok==false` → abort 成個事件(#2 redelivery 重判 — under-count-safe)。
- Caller = `src/autoload/pr_detection.gd`(CI whitelist — 002 已 amend)。

## Out of Scope

- Emit gate(011)。

## QA Test Cases

GDD AC-08 / AC-13 GWT。

## Test Evidence

**Required**:`tests/unit/pr_detection/test_stat_effect_path.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 001, 005
- Unlocks: 011
