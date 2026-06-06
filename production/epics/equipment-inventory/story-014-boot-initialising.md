# Story 014: Boot INITIALISING 8 步

> **Epic**: Equipment & Inventory (#17)
> **Status**: Complete ✅ (CI-green, merged main PR #21 b7ded42 2026-06-06)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06 (autonomous implementation run)

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 14(8 步)+ EC-20 + EC-1 drain side
**ADR Governing Implementation**: ADR-0006(primary — Contract 4 sequential boot + Contract 6);ADR-0008(secondary — position)
**ADR Decision Summary**: boot ordering 靠 ADR-0008 position assert(`is_boot_completed()` sync getter),**唔 await signal**(Contract 4 trap:signal 喺 #17 入 tree 前已 fire)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Control Manifest Rules**: Required: `connect_for_initial_state`(Contract 6,3-arg callable、no `.bind()`)。Forbidden: await `boot_completed`。

---

## Acceptance Criteria

- [ ] 8 步順序:load → hydrate(persisted-trust,schema-shape guard only)→ shard guard → mailbox sweep → recovery drain → compute aggregate(**唔 push**)→ GSM-gated push(恰好一次,合一 dedup flag)→ boot flush + recovery-clear
- [ ] **AC-36**:GIVEN persisted 含 1 壞 dict + 2 valid,WHEN boot step 2,THEN 壞 dict 棄 + CRITICAL telemetry,2 valid 照 load
- [ ] **AC-26**:GIVEN persisted shard = -500,WHEN step 3,THEN balance = 0 + `inventory.shard.balance_corrupted` CRITICAL
- [ ] **AC-28**:GIVEN `loot.pending.recovery` 2 records(1 已 tombstone),WHEN step 5 drain,THEN 新 record 入庫、tombstoned no-op、namespace 清空(**清空喺 step 8 flush 之後** — no-loss 次序)
- [ ] **AC-40**:GIVEN boot 觸發 shard clamp + sweep + drain(多 mutation),THEN persist 恰好一次 batched write,recovery-clear 喺該 write 之後
- [ ] **AC-06**:GIVEN persisted functional dict 注入 `{STR: 20, ATTACK_POWER: -5}`,WHEN boot re-hydrate + guard,THEN STR dropped、負 delta clamp 0、各 emit `inventory.stat_key.dropped`
- [ ] EC-2 scope negative assert:persisted LEGENDARY 無 receipt → boot **唔**誤殺(drop-provenance validation 只跑 drop path)
- [ ] Boot 開頭 assert `StatSystem.is_boot_completed()`(Story 009 API)

---

## Implementation Notes

- Recovery drain ownership:#15 write,#17 read + drain + clear(#15 L297 exception 已 amend);clear 必須 after `inventory.*` flush — 反次序 crash = loss,正次序 crash = double-drain(dedup 無害)。
- GSM Suspended-at-boot(crash recovery)→ `_pending_boot_replay` flag,Ready handler push(Story 015 共用機制)。
- Tombstone prune(Story 003)wire 入 step 2 後。

## Out of Scope

- Story 015:SUSPENDED queue / resume drain(本 story 只 boot path + pending flag set)
- Story 009:`is_boot_completed()` 實作

## QA Test Cases

GDD AC-06/26/28/36/40 GWT(全部 injected TimeProvider + persistence mock + GSM mock)。Edge cases:
- recovery drain 全部 duplicate → 零入庫、namespace 照清
- GSM gameplay-ready at boot → push 即發生(一次)
- GSM Suspended at boot → push 唔發生、flag set(AC-30 嘅 boot half — full path Story 015)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/equipment/test_boot_initialising.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 003/005/008/009/013
- Unlocks: Story 015
