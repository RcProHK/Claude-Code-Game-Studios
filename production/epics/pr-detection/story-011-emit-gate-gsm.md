# Story 011: Emit gate + one-slot buffer + GSM 靜默

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: ✅ Complete(2026-06-06 — gate green:combined 1909/1908,0 fail)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Rule 6.7 / Rule 10 GSM 段)
**ADR**: ADR-0006 C6(`connect_for_initial_state`);ADR-0011 §D-3(#12 EC-16 義務)
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-30**:GSM SUSPENDED + capped 玩家(short-circuit path — gate 係**唯一防線**,唔係 assert)→ 6.7 唔 emit、入 one-slot buffer;leave-SUSPENDED → flush(exactly once)。GSM 靜默:state 轉換零 active 行為(telemetry only)— **唯一例外 = buffer flush**
- [ ] SUSPENDED sliver 第二個 PR confirm → keep-latest overwrite(reachability 極窄 + self-healing — GDD Rule 10)

## Implementation Notes

- #12 `boot_completed` 半邊:結構保證(G-PR-3 鏈尾)+ `is_boot_completed()` getter(012 提供)做 assert surface。「GSM Ready」係 #12 loose wording — #18 解讀「非 SUSPENDED」(GSM enum 無 READY)。

## Out of Scope

- Reverse-wire 接線(013)。

## QA Test Cases

GDD AC-30 GWT(GSM mock seam ⑧)。

## Test Evidence

**Required**:`tests/unit/pr_detection/test_emit_gate.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 009
- Unlocks: 013
