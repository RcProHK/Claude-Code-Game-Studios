# Story 003: `zone.state` envelope + round-trip

> **Epic**: Zone System (#19)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S-M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/zone-system.md`(Rule 5 envelope / EC-1)
**ADR**: ADR-0006 C3 + ADR-0003 + ADR-0009
**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM(typed `Array[StringName]` JSON round-trip = **codebase 首例**)

## Acceptance Criteria

- [ ] **AC-08**:envelope(schema_version / workout_count / last_counted_transition_id / last_counted_date / unlocked_zone_ids / ceremony_pending)round-trip — **必須經 flush 落盤 + fresh load 真 path**(同 instance cache read = JSON coercion 零 exercise phantom pass);**assert typed `Array[StringName]` rebuild**(generic Array[String] → `from_dict` rebuild/`assign()`)
- [ ] **AC-04**:persist 回 garbage(三 vector:non-Dictionary / 缺 schema_version / unlocked_zone_ids 錯 type)→ ALWAYS zones 可用 + `zone.manifest_corrupt` telemetry、唔 crash

## Implementation Notes

- 經 `to_dict()/from_dict()`(GSM tombstone / loot 先例)。Test 用 fresh PersistenceLayer instance 行真 load path(review log Pass 3 note — 唔好自 call parse_string 模擬)。`last_counted_date` 初始 `""`(任何 ISO date > "" — guard 自然滿足;加 comment)。

## QA Test Cases

GDD AC-08 / AC-04 GWT。

## Test Evidence

**Required**:`tests/integration/zone_system/test_zone_persistence_roundtrip.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 002
- Unlocks: 004-007
