# Story 014: G-PR-2 — #9 additive(handler + getter + daily)+ count 鏈

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: Ready
> **Layer**: Feature(cross-epic touch — #9 Core)
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(D6 / G-PR-2 gate row)
**ADR**: ADR-0009(payload);Approved-upstream additive amendment
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] #9 additive:`pr_breakthrough` handler(**#18 reverse-wire** — 方向同 #12 一致,#9 唔主動訂)+ `get_pr_count_today() -> int` getter + daily reset 語意(**#9 own;TimeProvider seam #9-side** — #9 已有 local-date 慣例)
- [ ] **AC-22**:#18-side PR ×3 → emit ×3(handler spy);count 累計 + daily reset = **#9-side assert**(本 story 內,用 #9 TimeProvider seam)
- [ ] #15 L293 `get_pr_count_today()` 讀面 contract 滿足(#15 deferred 面補完 — 零 #15 churn)
- [ ] #9 GDD focused amendment note(additive)

## Implementation Notes

- 呢個 story **就係** G-PR-2 gate 嘅執行 — 完成後 AC-22 嘅 GATED 標記解除。Daily 語意跟 #9 現有 local-date 慣例(唔 hardcode UTC — GDD N-14 裁決)。

## QA Test Cases

GDD AC-22(#18-side emit count + #9-side count/reset 用 #9 seam)。Edge:跨日界 reset;suspended 期間 emit(buffer flush 後先到 — 011 interplay)。

## Test Evidence

**Required**:`tests/integration/pr_detection/test_pr_count_chain.gd` + `tests/unit/workout_state_tracker/`(additive)。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 011(emit gate 先 stable)
- Unlocks: —(#15 pr_factor 鏈 — 已 shipped read spec)
