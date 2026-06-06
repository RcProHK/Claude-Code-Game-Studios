# Story 013: Persistence round-trip + save 粒度 + Private Mode degrade

> **Epic**: Equipment & Inventory (#17)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 12/13 + EC-21
**ADR Governing Implementation**: ADR-0003(primary);ADR-0006 C3(secondary)
**ADR Decision Summary**: backend-primary + `user://` IndexedDB secondary;`inventory.*` namespace;localStorage FORBIDDEN;`IPersistence.write` = full-file rewrite → **flush 粒度 = per user action 一次 write**(key-level incremental 無著數)。

**Engine**: Godot 4.6 Web Export | **Risk**: LOW(ADR-0003 pattern 已有 #3/#11 shipped 先例)
**Control Manifest Rules**: Forbidden: `window.localStorage`(CI: check_local_storage_calls.gd)/ `.tres` 落 `user://`。

---

## Acceptance Criteria

- [ ] **AC-31**:GIVEN 120 items 其中 1 件 mutate,WHEN action 結尾 flush,THEN `IPersistence` mock 恰好一次 write(per-action 粒度)
- [ ] **AC-27**:GIVEN inventory + loadout + locks + shards persist,WHEN boot,THEN round-trip equality:item(id + state + is_locked + **source_receipt + provenance_text + acquired_at_unix**)集合、shard、per-slot loadout 還原,#11 mock 收到等價 aggregate
- [ ] **AC-32a**:GIVEN mock secondary 全 write fail(seam 8 分層),WHEN receive + salvage + boot replay,THEN 全部經 backend path 成功、state 經 backend reload 還原、secondary fail 只 logged warning
- [ ] **AC-32b**(VS-tier playtest,ADVISORY — deferred-tracked):真 browser Private Mode documented playtest,跟 ADR-0003 VS-tier gate
- [ ] Persist format = dict envelope(Story 001 to_dict/from_dict);`inventory.pending_queue` namespace 同步(Story 015 內容)

---

## Implementation Notes

- 跟 #3 `IPersistence` 現有 interface;G-5(`write_batch`)optional — per-action 單 write 已可實現,實作時如 #3 API 唔夠先開 followup。
- G-8:#3 namespace 表(persistence-layer.md L346 `gsm.inventory.*` TBD)→ 修一行做 `inventory.*`(本 story 順手做,一行 doc fix)。
- Debounce:`process_frame` ONE_SHOT(Contract 5 idiom)。

## Out of Scope

- Story 014:boot 順序本身(本 story 係 round-trip data 完整性)
- Schema migration(ADR-0003 900ms ceiling — MVP schema v1,無 migration path 要寫;留 forward note)

## QA Test Cases

GDD AC-27/31/32a GWT。Edge cases:
- bulk-salvage 50 件 → 1 write(AC-25 重 assert 喺 integration 層)
- receipt round-trip:LEGENDARY + full receipt → reload 後 signature_text 一致(A3 immunity 依賴)
- 空 inventory round-trip → 空集合,零 error

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/equipment/test_persistence_roundtrip.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 001/002/010
- Unlocks: Story 014
