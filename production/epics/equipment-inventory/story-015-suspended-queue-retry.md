# Story 015: SUSPENDED durable queue + drain + rejection retry

> **Epic**: Equipment & Inventory (#17)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~3.5h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 15 + EC-14/22
**ADR Governing Implementation**: ADR-0006(primary — Contract 5 deferred idiom + Contract 6)
**ADR Decision Summary**: resume-path push 一律 `process_frame` ONE_SHOT 延一 frame(避 #11 Reconciling single-frame reject window)+ `stat_mutation_rejected` retry。

**Engine**: Godot 4.6 Web Export(bfcache)| **Risk**: LOW
**Control Manifest Rules**: Required: Contract 6 `connect_for_initial_state`。

---

## Acceptance Criteria

- [ ] **AC-29**:GIVEN `SUSPENDED`,WHEN `receive_loot` ×3(含 1 dup;各 return `QUEUED_SUSPENDED`),WHEN resume drain,THEN FIFO 入庫、dup no-op、aggregate/push/persist 各恰好一次(batch);AND GIVEN `READY` 連發 ×3(boot force-reveal burst)THEN 同樣 batch
- [ ] **AC-30**:GIVEN GSM Suspended-at-boot,WHEN boot 完成,THEN push 未發生(flag set);WHEN GSM 轉 Ready,THEN deferred push 恰好一次
- [ ] **AC-21**:GIVEN #11 mock 回 `stat_mutation_rejected`,WHEN auto-equip swap,THEN `_pending_stat_push` set,mock Ready 後 deferred re-push 成功,無 desync
- [ ] **Durable queue**:SUSPENDED 期間 record 同步寫 `inventory.pending_queue`(#17 own namespace — 唔掂 #15 `loot.*`);drain 成功 + persist 後 clear;browser discard tab 唔 loss
- [ ] `_pending_boot_replay` + `_pending_stat_push` 合一 dedup(push 恰好一次,唔 double)

---

## Implementation Notes

- GSM 訂閱經 `connect_for_initial_state`(3-arg callable、no `.bind()` — Contract 6)。
- Drain 用 `process_frame.connect(..., CONNECT_ONE_SHOT)`(Contract 5 preferred idiom;`call_deferred` flagged)。
- Rejected handler filter `source == EQUIPMENT`(#17 係唯一 equipment caller)。

## Out of Scope

- Story 014:boot 8 步本身
- #11 Reconciling 行為(上游;mock)

## QA Test Cases

GDD AC-21/29/30 GWT(GSM mock seam 6)。Edge cases:
- queue 持久化 round-trip:SUSPENDED 寫 queue → 模擬 crash(reload state)→ boot 時 queue drain
- drain 中途再 SUSPENDED → 餘下 record 留 queue
- rejected ×2 連續 → retry 唔疊加(單 flag)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/equipment/test_suspended_queue_retry.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 008/013/014
- Unlocks: None(leaf)
