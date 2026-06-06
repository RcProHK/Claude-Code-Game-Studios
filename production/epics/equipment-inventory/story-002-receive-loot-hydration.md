# Story 002: receive_loot hydration + validation + ReceiveResult contract

> **Epic**: Equipment & Inventory (#17)
> **Status**: Implemented (pending CI verification)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06 (autonomous implementation run)

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 1 + EC-1/2/3 + D9
**ADR Governing Implementation**: ADR-0006(primary); ADR-0009(secondary — telemetry payload)
**ADR Decision Summary**: failure path 唔可以 silent;`loot.pending.recovery` write 係 #15 EC-48 responsibility(L297 sole-writer exception 已 amend)— #17 只 return `FAILED_ROLLBACK` + emit CRITICAL。

**Engine**: Godot 4.6 | **Risk**: LOW
**Control Manifest Rules**: Required: 公開 API doc comments;data-driven。Forbidden: 直接 throw 越 boundary(用 return contract)。

---

## Acceptance Criteria

- [ ] **AC-01**:GIVEN valid `loot_drop_record`(metadata 齊)+ inventory 有位,WHEN `receive_loot()`,THEN typed `EquipmentItem` 產生,`stat_modifiers` == Stat Assignment Table 該格,state = `IN_INVENTORY`,return `OK`
- [ ] **AC-02**:GIVEN metadata 缺 `source_transition_id`,WHEN `receive_loot()`,THEN return `FAILED_ROLLBACK` + emit `loot.inventory.grant_fail` CRITICAL,inventory size 不變
- [ ] **AC-03**:GIVEN LEGENDARY 缺 `source_receipt`,THEN return `FAILED_ROLLBACK` + CRITICAL(F-12 binding);AND COMMON 缺 receipt THEN return `OK` 入庫(receipt=null,provenance_text 仍生成)
- [ ] **AC-04**:GIVEN `rarity` missing,THEN rarity = COMMON,無 rollback(Pillar 3 floor)
- [ ] **AC-35**:GIVEN `item_type` = unknown string,THEN return `FAILED_ROLLBACK` + CRITICAL
- [ ] `class_tag` missing/null → NEUTRAL;cosmetic 強制 NEUTRAL
- [ ] **D9 binding**:drop path 嘅 `item_metadata` **唔讀 stat keys**(table authoritative);metadata 帶 stat keys → detection-only telemetry,唔 merge

---

## Implementation Notes

- `receive_loot(loot_drop_record) -> ReceiveResult`(Rule 1)— validation 順序跟 GDD bullet order。
- 失敗 = return,**唔係 throw**(#15 catch return / throws 兩款都兜;#15 寫 recovery namespace)。
- Telemetry events 用 signal emit(可 spy):`loot.inventory.grant_fail` / `inventory.stat_key.dropped`。
- `acquired_at_unix` stamping 經 `TimeProvider.now_unix()`(seam 1)。
- 檔案:`src/feature/equipment/inventory_system.gd`(autoload 主體,本 story 起 scaffold)。

## Out of Scope

- Story 003:idempotency dedup(本 story 假設新 item)
- Story 004:cap/mailbox routing(本 story 假設有位)
- Story 012:cosmetic dupe convert(`CONVERTED_DUPE` branch stub)
- Story 015:`QUEUED_SUSPENDED` branch(stub return)

## QA Test Cases

GDD AC-01/02/03/04/35 GWT 直接實作(見上)。Edge cases:
- metadata 帶 `{STR: 20}` → STR 唔入 final dict + `inventory.stat_key.dropped` emit(detection-only)
- LEGENDARY + receipt 齊 → OK + receipt attached
- rarity missing + LEGENDARY receipt missing 同時 → rarity floor 先行 → COMMON → receipt nullable → OK(validation 順序)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_receive_loot_hydration.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 001
- Unlocks: Story 003/004/012
