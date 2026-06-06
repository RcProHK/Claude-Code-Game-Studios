# Story 006: Slot model + auto-equip-if-better orchestration

> **Epic**: Equipment & Inventory (#17)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 5/6 + EC-11/12
**ADR Governing Implementation**: ADR-0006(primary — mutation discipline 係 Contract 1 精神嘅 #17 版)
**ADR Decision Summary**: #17 所有 internal state mutation 完成先 push #11(push 永遠最後一步);`stat_changed` handler 觀察到嘅 state 永遠 post-swap consistent。

**Engine**: Godot 4.6 | **Risk**: LOW
**Control Manifest Rules**: Required: deterministic tie-break。Forbidden: auto-equip 郁 COSMETIC slot / locked item slot。

---

## Acceptance Criteria

- [ ] Slot model:WEAPON/ARMOR/ACCESSORY ×1(1:1 item_type)+ COSMETIC ×1(manual-only)
- [ ] **AC-23**:GIVEN 各 item_type 一件,WHEN receive,THEN 各落正確 slot affinity;CONSUMABLE 入庫、`slot_affinity == null`、唔觸發 auto-equip;COSMETIC 入 cosmetic pipeline
- [ ] **AC-12**:GIVEN WEAPON slot 現裝 RARE(+22),WHEN 收 EPIC weapon(+45,unlocked),THEN swap,舊件 → `IN_INVENTORY`
- [ ] **AC-13**:GIVEN EQUIPPED weapon `is_locked = true`,WHEN 更強 weapon 到,THEN skip,新件 `IN_INVENTORY`,loadout 不變
- [ ] **AC-14**:GIVEN 兩 candidate score 相等,THEN tie-break rarity↓ → acquired_at↑ → item_id↑,deterministic 重跑同結果
- [ ] **AC-15**:GIVEN WEAPON slot 空 + inventory 有 COMMON weapon,WHEN backfill 評估,THEN 正分 candidate equip(baseline 0);AND COSMETIC slot 空 + 收 cosmetic THEN 唔 auto-equip
- [ ] **AC-41**:GIVEN mailbox claim 成功且 item 強過現役,THEN auto-equip 評估跑、item `EQUIPPED`
- [ ] Trigger set:{receive_loot 後、claim 後、salvage-induced-unequip 後 backfill}
- [ ] 比較鍵 = **loadout-level marginal(clamp-aware)**:swap 後 loadout_score 嚴格大於現役先 swap(Story 007 formula)

---

## Implementation Notes

- 比較用 Formula 1(Story 007 pure function)— swap 候選 = 重算成個 loadout effective(經 Formula 4 clamp,Story 008)。實作順序彈性:可先用 stub clamp(pass-through)落 orchestration,Story 008 完成後 integration 自然收緊;AC-12/13/14/15 fixtures 設計成 clamp 唔 bind 嘅 region(table 值細過 cap)。
- Mutation discipline:swap = in-memory(slot 指派 + state 轉換 + dirty mark)→ 最後先 call push(Story 008 boundary)。
- Score ≤ 0 永不 auto-equip(Rule 1 非負 guard 下 MVP 唔出現 — defense-in-depth assert)。

## Out of Scope

- Story 007:loadout_score formula 本體
- Story 008:clamp + #11 push
- Story 011:manual equip/unequip(本 story 只 auto path)

## QA Test Cases

GDD AC-12/13/14/15/23/41 GWT。Edge cases:
- 三 slot 全空 + 收三件 → 三件各自 backfill
- 收 CONSUMABLE → 入庫、零 slot 變化、零 auto-equip call
- tie-break:同 score 同 rarity → 舊 acquired_at 保留(churn 減)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_auto_equip_orchestration.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 004、Story 007
- Unlocks: Story 008(push boundary)、Story 011
