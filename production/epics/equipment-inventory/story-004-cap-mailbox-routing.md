# Story 004: Inventory cap + mailbox routing + claim-when-full

> **Epic**: Equipment & Inventory (#17)
> **Status**: Implemented (pending CI verification)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (~2h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06 (autonomous implementation run)

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 3 + EC-7/10
**ADR Governing Implementation**: ADR-0003(primary — inventory.* namespace)
**ADR Decision Summary**: `MAX_INVENTORY = 120`(DESIGN-FROZEN per #15;count 唔包 mailbox)。

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] **AC-08**:GIVEN inventory = 119,WHEN 連收 2 件,THEN 第 120 件 `IN_INVENTORY`、第 121 件 `IN_MAILBOX`(boundary 雙邊)
- [ ] **AC-11**:GIVEN mailbox item + inventory = 120,WHEN `claim(item_id)`,THEN block + 回傳 shortfall(「先騰 N 個位」data),state 不變;AND inventory = 119 THEN claim 成功 → `IN_INVENTORY`
- [ ] Claim 唔可以臨時超額(EC-10)
- [ ] Claim 成功後觸發 auto-equip 評估(Rule 6 trigger set — assert hook 存在;比較邏輯 Story 006)

---

## Implementation Notes

- `MAX_INVENTORY` 引用 config(data-driven;registry `max_inventory_slots` = 120)。
- Claim API:`claim(item_id) -> {ok: bool, shortfall: int}`(#23 用 shortfall 顯示)。
- Mailbox 容量上限(`MAILBOX_HARD_CAP` 180)+ evict 喺 Story 005。

## Out of Scope

- Story 005:mailbox TTL / hard-cap evict
- Story 006:auto-equip 比較邏輯(本 story 只 assert trigger hook)

## QA Test Cases

GDD AC-08/AC-11 GWT。Edge cases:
- inventory 120 + mailbox 0 → 新 drop 直入 mailbox
- claim 後 inventory 啱啱 120 → 下一個 claim block
- claim 不存在 item_id → no-op error result

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_cap_mailbox_routing.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 002
- Unlocks: Story 005、006
