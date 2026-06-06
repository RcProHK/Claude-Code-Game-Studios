# Story 010: Salvage + bulk-salvage + transaction atomicity

> **Epic**: Equipment & Inventory (#17)
> **Status**: Complete ✅ (CI-green, merged main PR #21 b7ded42 2026-06-06)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-06 (autonomous implementation run)

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 9 + Formula 2 + EC-13/17/19/20
**ADR Governing Implementation**: ADR-0003(primary — 單 write);ADR-0001(secondary — frame budget)
**ADR Decision Summary**: bulk-salvage N 件 = **1 次** persist write(50 次 full rewrite + syncfs 一個 frame 會爆 budget)。

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] **Formula 2**:`salvage_yield(rarity) = floori(SHARD_BASE × RARITY_SHARD_MULT[rarity])` = 100/150/250/450/800;config-load assertion `salvage_yield(t+1) > salvage_yield(t)`(monotonic)
- [ ] **AC-24**:GIVEN RARE item,WHEN salvage,THEN `forge_shard` += 250
- [ ] **AC-20**:GIVEN EQUIPPED item + backfill candidate,WHEN `salvage(item_id)` return,THEN (a) `SALVAGED` + candidate `EQUIPPED`;(b) #11 mock 恰好一次 final push(**喺所有 mutation 之後** — call-order spy);(c) shard + state 同一 commit;(d) persist 恰好一次
- [ ] **AC-25**:GIVEN 5 unlocked + 1 locked + 1 unlocked-with-receipt COMMON,WHEN `bulk_salvage(COMMON)`,THEN 拆 6 件 unlocked(locked 保留),shard += 600,persist 恰好一次;AND `bulk_salvage_preview(COMMON)` → `{count: 6, yield: 600, receipt_count: 1}`
- [ ] EQUIPPED 唔可直接 salvage — batch(unequip + SALVAGED + shard + backfill)→ 單 push → 單 write(Rule 9 Pass 3 ordering)
- [ ] Locked item 絕對排除(API 無 bypass param);tombstone write(Story 003 機制)

---

## Implementation Notes

- Transaction = in-memory commit 單元;persist fail → 全 rollback + telemetry(EC-19)。
- `bulk_salvage_preview` 係 #17 提供,#23 confirm UI 顯示 receipt warning(ownership Pass 3 統一)。
- Shards int64;balance 變化 emit signal(#23 display)。

## Out of Scope

- Story 005:mailbox auto-salvage(reuse Formula 2)
- Story 011:lock 寫入
- v0.2:craft / upgrade(INV-E1/E2 唔喺 MVP)

## QA Test Cases

GDD AC-20/24/25 GWT。Edge cases:
- salvage 不存在 id → error result,零 mutation
- bulk_salvage(rarity 無 item)→ `{count: 0}`,零 write
- monotonic assertion:注入 RARITY_SHARD_MULT 反轉 → config-load fail loud
- persist mock fail → shard 同 state 都 rollback(EC-19)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_salvage_bulk_atomicity.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 003(tombstone)、Story 006(backfill)、Story 008(push boundary)
- Unlocks: Story 013
