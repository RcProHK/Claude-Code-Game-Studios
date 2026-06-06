# Story 016: Re-entrancy guard + CI lint + autoload 登記

> **Epic**: Equipment & Inventory (#17)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (~2.5h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 6(mutation discipline + `_mutating` guard)+ EC-15
**ADR Governing Implementation**: ADR-0008(primary — autoload 登記);ADR-0006 C5(secondary — deferred idiom)
**ADR Decision Summary**: `StatSystem ≺ InventorySystem ≺ LootDropSystem`(constraint 8 binding);insertion = WorkoutStateTracker 同 LootDropSystem 之間,renumber downstream。

**Engine**: Godot 4.6 | **Risk**: LOW
**Control Manifest Rules**: Required: gateway lint **owner-exempt**(main-RED lesson:lint 必須豁免定義+守護 seam 嘅 owner)。

---

## Acceptance Criteria

- [ ] **AC-33**:GIVEN test 注入 `stat_changed` handler synchronous call 返 #17 mutation API,WHEN mutation operation push #11(emission 期間觸發),THEN `_mutating` guard 截住(`push_error` + deferred 至下一 frame),state 無 corruption
- [ ] `_mutating` window:持續到 #11 push **return 之後**先清(guard 喺 emission 期間必須生效)
- [ ] CI lint `tools/ci/check_inventory_reentrancy.gd`:`stat_changed` handler FORBIDDEN synchronous call #17 mutation API(**owner-exempt #17 自身**);跑 lint 驗 0 violation
- [ ] `InventorySystem` autoload 登記入 `project.godot`(ADR-0008 insertion rule:WST 同 LootDropSystem 之間;downstream renumber;ADR-0008 canonical map 同步更新)
- [ ] Boot 順序 CI-verifiable:combined GUT gate green(autoload 加入後全 suite 唔爆)

---

## Implementation Notes

- Lint pattern 跟現有 `tools/ci/check_*` 4-layer 先例(camera/particle/screen-effects/platform);grep handler connect 點 + call site。
- `project.godot` edit 係 ground truth(F-SETUP-4);ADR-0008 canonical map 加 InventorySystem row + 更新 positions。
- 新 autoload 後記住 `godot --headless --import` 刷 class cache。

## Out of Scope

- Story 006:mutation discipline 本體(本 story 係 guard + enforcement)

## QA Test Cases

GDD AC-33 GWT。Edge cases:
- handler deferred call(正路)→ guard 唔觸發,下一 frame 正常執行
- nested mutation 嘗試 ×2 → 各自 push_error,只 queue 一次
- lint self-test:注入一個 violating 檔案 fixture → lint fail;移除 → pass

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_reentrancy_guard.gd` + lint 0-violation run
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 008(push boundary 存在)
- Unlocks: None(epic 收尾 wiring)
