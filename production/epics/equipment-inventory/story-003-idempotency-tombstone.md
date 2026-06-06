# Story 003: Idempotency + timestamped tombstone + prune

> **Epic**: Equipment & Inventory (#17)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (~2h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/equipment-inventory.md` — Rule 2 + Formula 6 + EC-6
**ADR Governing Implementation**: ADR-0006(primary — Contract 2 transition_id opaque)
**ADR Decision Summary**: `transition_id` 全域 unique(backend UNIQUE constraint)且 **opaque — 禁止 parse**;所以 tombstone 必須自帶 timestamp。

**Engine**: Godot 4.6 | **Risk**: LOW
**Control Manifest Rules**: Forbidden: parse transition_id(Contract 2)。

---

## Acceptance Criteria

- [ ] **Formula 6**:`item_id = StringName(source_transition_id + "_" + str(drop_index))` — **無 hash**(32-bit collision = silent loot loss)
- [ ] **AC-07**:GIVEN 已入庫 `(transition_id, drop_index)`,WHEN 重入,THEN no-op return `DUPLICATE_NOOP`;AND 同 transition 唔同 drop_index ×2 THEN 兩件都入庫;AND 已 SALVAGED 嘅 item_id replay THEN 唔復活、shard 不變(tombstone dedup)
- [ ] Tombstone = `{item_id: salvaged_at_unix}` Dictionary(唔存 full item;`salvaged_at_unix` 經 TimeProvider stamp)
- [ ] **AC-39**:GIVEN injected `now_unix = T` + tombstone `salvaged_at_unix = T - 38d`,WHEN boot prune,THEN 條目刪除;AND `T - 36d` THEN 保留(**37日 boundary** = #15 `HARD_CAP_DAYS`,LOCKED;backend retention 同 37d per ADR-0006 Contract 15)

---

## Implementation Notes

- Dedup check 順序:active items → tombstone → 新 item(Rule 2)。
- Prune 喺 boot INITIALISING 行(Story 014 wire;本 story 提供 pure function `prune_tombstones(tombstones, now_unix) -> Dictionary`)。
- **唔好** parse item_id 攞 timestamp — 用 tombstone value。
- 37 日係 cite #15 `HARD_CAP_DAYS` 常數(data-driven,唔 hardcode magic number — 引用 shared const 或 config)。

## Out of Scope

- Story 010:salvage 寫 tombstone(本 story 提供 dedup + prune 機制)
- Story 014:boot wiring

## QA Test Cases

GDD AC-07/AC-39 GWT 直接實作。Edge cases:
- drop_index 0 vs 1 同 transition → 兩個唔同 item_id
- tombstone 同 active 同時存在同 id(理論不可能)→ active 優先 no-op
- prune boundary 啱啱 37.0d → 保留(嚴格 早過 先刪)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/equipment/test_idempotency_tombstone.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 002
- Unlocks: Story 010(salvage tombstone write)、Story 014(boot prune)
