# Story 004: Training-day count(dedup + monotone date guard)

> **Epic**: Zone System (#19)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/zone-system.md`(Rule 2 / Formula / EC-2 / EC-8)
**ADR**: ADR-0002(epoch full-resync 語意 — monotone guard 嘅理由)+ ADR-0009
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:**`completed_at` 係 unix MS**(`workout_state_tracker.gd:68`)— derive 前 ÷1000(`Time.get_datetime_string_from_unix_time` 食 seconds;唔 pin = per-day cap 靜默失效)
- Forbidden:wall clock / TimeProvider(date 係 payload 純函數 — deliberate 零 clock seam)

## Acceptance Criteria

- [ ] **AC-06**:count 4 + threshold 5 — (a) 同 UTC day(txn-C)→ 不變(cap);(b) stale date(txn-E,`< cursor` — epoch resync 重派)→ 不變(monotone guard);(c) 新 day(txn-D)→ count 5 + unlock。**Fixtures unix ms + UTC 邊界 pair(23:59:59Z vs 00:00:00Z)**
- [ ] **AC-03(dedup 半)**:同 transition_id replay → count 不變

## Implementation Notes

- 三步:transition_id == cursor → no-op;`utc_date(ms/1000) <= last_counted_date` → no-op(ISO 字典序 = 日期序);否則 +1 + cursors update + Rule 3 評估 + persist。

## QA Test Cases

GDD AC-06(三 vector + 邊界 pair)/ AC-03 dedup。

## Test Evidence

**Required**:`tests/unit/zone_system/test_training_day_count.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 003
- Unlocks: 005
