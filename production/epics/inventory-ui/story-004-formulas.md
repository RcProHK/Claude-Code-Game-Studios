# Story 004: F1 retention date + F2-M mailbox comparator + sort identity seam

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-08

## Context

**GDD**: `design/gdd/inventory-ui.md` — F1(−86400 最後完整保證日 + render guards + D2/D3)+ F2-M(acquired asc → item_id asc)+ Rule 7
**Requirement**: direct GDD trace(AC-01 / AC-02 / AC-03)

**ADR Governing Implementation**: N/A — pure formula(#22 F1-F4 先例);ADR-0007(secondary — RarityTier 唔喺本 story)
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_date_dict_from_unix_time` device-local 行為要經 injected tz offset seam 包(AC-01 determinism — CI UTC vs 本機 HKT)

**Control Manifest Rules**: gameplay values data-driven(TTL referenced #17 const,唔 hardcode 7)

---

## Acceptance Criteria

- [x] **AC-01**:GIVEN acquired 6月1日 09:00(injected clock + tz),WHEN F1,THEN「保留至 6月7日」(−1 day;formatter round-trip + fixed-tz golden 兩條腿);receipt 件 → 無 retention 行 + note;`acquired_at_unix <= 0` → 無 retention 行
- [x] **AC-02**:filter predicate unit(`slot_affinity == chip`;filter 值不變)— `tests/unit/inventory_ui/test_inventory_filter.gd`
- [x] **AC-03**:`SORT_COMPARATOR` const seam = `Callable(preload(char_screen_formulas), "picker_before")` identity assert + 真 fixture byte-identical;F2-M golden vectors(acquired asc / 同秒 tie → item_id asc;shuffle 收斂 strict total order)

## Implementation Notes

- 新 file `src/ui/inventory_ui/inv_ui_formulas.gd`(static funcs;`mailbox_before` 喺度)+ `SORT_COMPARATOR` const(identity seam)
- F1 formula:`date_local(acquired + TTL×86400 − 86400)`;TTL 讀 `InventorySystem.OVERFLOW_MAILBOX_TTL_DAYS`(referenced — 唔 duplicate)
- 過去日期照 render 原文案(D2)— render guard 三條全喺 formula 層 return null/skip 信號

## Out of Scope

- Story 006:binding(formula consume);Story 008:retention 行 render

## QA Test Cases

- **AC-01**: Given fixture acquired_at,When retention_date(injected tz),Then golden「6月7日」;receipt → null;<=0 → null;邊界:acquired 23:59 跨日
- **AC-03**: Given SORT_COMPARATOR,When Callable equality,Then == picker_before(fork 必不等);Given shuffle ×3,When sort F2-M,Then byte-identical 序

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/inventory_ui/test_retention_date.gd` + `test_inventory_filter.gd` + `test_invui_sort.gd`
**Status**: [x] Created — 16 tests(8+3+5)全 pass;combined gate CLEAN 2284/2283/0 fail(2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 3/3 passing
**Deviations**: None — `src/ui/inventory_ui/inv_ui_formulas.gd`(static funcs + SORT_COMPARATOR const seam + FILTER_ALL sentinel [避免 coordinator enum 雙向 coupling — binding 層 story 006 做 mapping]);TTL referenced `InventorySystem.OVERFLOW_MAILBOX_TTL_DAYS`(唔 hardcode);tz injected seam(production offset 接線留 006/008)
**Test Evidence**: 16 tests — F1 goldens(HKT/UTC/tz divergence/23:59 跨日/round-trip)+ guards(receipt / <=0)+ D2 past-date verbatim;filter ALL/chip/pure;identity assert + byte-identical + F2-M goldens + rarity-blind + 3-permutation 收斂
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續)

## Dependencies

- Depends on: Story 002(dir 結構;可實際並行)
- Unlocks: 006 / 008
