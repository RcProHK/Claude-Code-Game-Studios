# Story 010: G-CS-1 — #17 additive read getters(get_loadout + get_items_for_slot)

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation(對象係 Feature #17 — gate-inside-epic)
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` G-CS-1 row;equipment-inventory.md L127(「loadout state + per-item detail」應承,shipped code 只有 `get_item`,`_loadout` private — grep-verified)
**Requirement**: direct GDD trace

**ADR Governing Implementation**: N/A — additive read-only getters,零 architectural pattern 新增(#17 G-LM-9 batch seam 先例)
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: return **copy**(`get_loadout`)— #17 唔 expose live `_loadout` dict;`get_items_for_slot` 回 Array[StringName](IN_INVENTORY + slot_affinity filter;F3 排序由 #22 做)

---

## Acceptance Criteria

- [ ] `get_loadout() -> Dictionary`(slot → item_id **copy**)— mutation caller copy 唔影響 internal
- [ ] `get_items_for_slot(slot) -> Array[StringName]` — 只列 IN_INVENTORY + `slot_affinity == slot`(cosmetic slot → cosmetic-only)
- [ ] #17-side unit tests(getter 行為 + copy 語意 + filter 正確性)
- [ ] **#17 existing tests 零變紅**(additive 驗證)+ combined CI gate green

## Implementation Notes

- 跟 G-LM-9 / #11 G-2 additive API story 先例;doc comment 註明 caller(#22)
- 唔 expose score / 唔 expose `_candidate_beats`(#22 picker 自己 F3 排序 — 方向 intentionally 唔同)

## Out of Scope

- Story 014/017:#22-side consumers;任何 #17 行為改動(純 additive)

## QA Test Cases

- **get_loadout copy**: Given loadout {WEAPON: sword},When mutate returned dict,Then internal 不變
- **filter**: Given 混合 slot_affinity + states,When get_items_for_slot(WEAPON),Then 只回 IN_INVENTORY WEAPON 件
- **empty**: 0 件 → 空 array(非 null)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/equipment/test_inventory_read_getters.gd`(#17-side)+ combined CI
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(可同 002-009 並行)
- Unlocks: Story 014(AC-20)/ Story 017(AC-31)— **解封者,先行於 loadout/picker**
