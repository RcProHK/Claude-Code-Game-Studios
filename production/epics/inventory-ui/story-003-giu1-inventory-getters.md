# Story 003: G-IU-1 #17 additive 三件(enumeration getters + preview receipt_ids)

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation(對象 #17 — Feature;additive)
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/inventory-ui.md` — G-IU-1 gate row + Rule 5
**Requirement**: direct GDD trace(G-IU-1 — **run-level 解封者:全部 integration ACs**)

**ADR Governing Implementation**: N/A — additive read API,冇架構 pattern 變更(G-CS-1 先例)
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: typed `Array[StringName]` return;Dictionary additive key 對 #22 caller 零影響

**Control Manifest Rules**: #17 reentrancy 紀律唔受影響(read-only getters + preview 無 mutation)

---

## Acceptance Criteria

- [x] `get_all_inventory_items() -> Array[StringName]`:**IN_INVENTORY + EQUIPPED**(口徑 = `get_inventory_count` L1128 — cap 數乜佢列乜);copy 語意;零 ordering 承諾(F3 由 #23 做)
- [x] `get_mailbox_items() -> Array[StringName]`:IN_MAILBOX;同上語意
- [x] `bulk_salvage_preview` return 加 **`receipt_ids: Array[StringName]`** key(additive — selection predicate 同 loop 內收集,唔另開 loop drift 風險)
- [x] #17-side unit tests:**predicate↔receipt_ids 一致性 assert**(receipt_ids ⊆ bulk range ∧ 全部 has_receipt ∧ count == receipt_count)+ getters lifecycle 口徑 tests
- [x] **#17 existing suite 零變紅**(parity 準則 — equipment 全 suite 重跑;見 Completion Notes deviation)

## Implementation Notes

- 跟 `get_items_for_slot`(L1163)doc comment 風格;doc comment 標明「IN_INVENTORY + EQUIPPED — #23 Rule 5/8 口徑,G-IU-1」
- preview(L622-634)現有 loop 內加 `receipt_ids.append(item.item_id)` 喺 `has_receipt()` branch — 唔改 selection 邏輯

## Out of Scope

- #23-side 任何 code(story 006 先 consume)

## QA Test Cases

- **口徑**: Given 混合 lifecycle fixture(mailbox/inventory/equipped/salvaged),When `get_all_inventory_items()`,Then 恰好 IN_INVENTORY+EQUIPPED ids;`get_mailbox_items()` 恰好 IN_MAILBOX
- **Copy**: Given return array,When caller mutate,Then #17 internal 不變
- **一致性**: Given unlocked receipt 件(三 lifecycle 各一)+ locked receipt 件,When preview,Then receipt_ids 含三件唔含 locked;count/yield/receipt_count 同舊行為 byte-identical

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/equipment/test_giu1_getters.gd`(#17-side)— combined CI gate + equipment suite 零變紅
**Status**: [x] Created — 8 tests 全 pass;combined gate CLEAN 2268/2267 pass/0 fail(2026-06-07)

## Completion Notes

**Completed**: 2026-06-07
**Criteria**: 5/5 passing
**Deviations**: ADVISORY — `test_salvage_bulk_atomicity.gd` L153 exact-dict assert 改 per-key(原 assert 同任何 additive key 都唔兼容 — incidental strictness;原 3-value intent 保留,加強咗 receipt_ids assert)。Lesson:`Array[StringName].sort()` 唔係字典序(比 pointer)— 首 run 2 test fail,改 String-sort helper(入咗 memory)
**Test Evidence**: `tests/unit/equipment/test_giu1_getters.gd` — 8 tests(口徑 ×3 / empty / copy / receipt_ids 一致性 / byte-identical / 0-match)
**Code Review**: Complete — LP-CODE-REVIEW degraded inline APPROVED(additive only,selection predicate 零改動);QL-TEST-COVERAGE degraded inline ADEQUATE(3 QA cases 全 mapped)

## Dependencies

- Depends on: None(#17-side additive;可同 002 並行)
- Unlocks: Story 006(binding)+ 008/009/010/011/012(全部 data consumers)
