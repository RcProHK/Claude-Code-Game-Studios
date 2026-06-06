# Story 011: Manual override + item-level lock

> **Epic**: Equipment & Inventory (#17)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (~2h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 7(Pass 3 interplay 明寫)
**ADR Governing Implementation**: N/A — 行為規則,no architectural pattern beyond mutation discipline(Story 006/016)
**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] **AC-34**:GIVEN #22 `equip(item_id, slot)` 較弱 item(unlocked),THEN equip 成功(manual 唔受 score 限制)+ 恰好一次 re-push;AND 下次 auto-equip trigger THEN 較強件換返(**唔 lock 唔尊重 — by design**);AND `unequip(slot)` THEN item → `IN_INVENTORY` + re-push
- [ ] `set_lock(item_id, bool)` — **item-level**(唔係 slot-level);persist 入 `inventory.*`
- [ ] Locked item:auto-equip 唔郁佢 slot(AC-13 Story 006)+ 免疫 salvage/bulk/auto-salvage(Stories 005/010 assert)
- [ ] Type mismatch guard:`equip(weapon_id, ARMOR_slot)` → error result,零 mutation
- [ ] Forward flag(#22 UX spec):manual equip 較弱 item 時 UI 須露 lock affordance(documented in story close notes → #22)

---

## Implementation Notes

- Manual path 同 auto path 共用 swap 內核(mutation discipline 一致);分別只係 score gate 有無。
- Lock flag 喺 `EquipmentItem.is_locked`(Story 001 schema)。

## Out of Scope

- #22 UI 本身(Presentation tier)
- Story 006:auto-equip 比較

## QA Test Cases

GDD AC-34 GWT。Edge cases:
- equip 已 EQUIPPED 嘅 item 落另一 slot(type mismatch)→ error
- unequip 空 slot → no-op result
- set_lock 不存在 id → error result
- lock EQUIPPED item → auto-equip skip 該 slot(integration assert with Story 006)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_manual_override_lock.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 006
- Unlocks: None(leaf)
