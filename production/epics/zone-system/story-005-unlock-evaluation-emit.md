# Story 005: Unlock 評估 + write-success-then-emit + rollback

> **Epic**: Zone System (#19)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/zone-system.md`(Rule 3 / Rule 4 / Rule 5 / EC-2 / EC-7)
**ADR**: ADR-0003(flush=true anchor);#8 Rule 7 milestone-unlock 樣板(`streak-system.md:285-293`)
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-02**:注入 registry 第二 zone(WORKOUT_COUNT 2)+ count 1 → forwarded(新 day)→ count 2、`write(flush=true)` **先於** emit(shared-log spy order)、emit 一次、queue 含 zone_id、`zone.unlocked` telemetry
- [ ] **AC-03**:同 txn replay → 不變 / 零第二 emit / 零 queue dup
- [ ] **AC-10**:write false → 零 emit、`unlocked_zone_ids` rollback、**queue 唔含該 zone_id**(兩 append 同步 rollback;count/cursors keep — deliberate)、`zone.persist_failed`;下次 boot sweep 補返(零 duplicate)

## Implementation Notes

- 永久性 binding:unlocked_zone_ids 只加不減(runtime mutation guard — 唯一寫路徑 Rule 3 append;load validate → EC-1,**唔用 raw assert**)。ALWAYS derived-not-persisted。

## QA Test Cases

GDD AC-02/03/10 GWT。

## Test Evidence

**Required**:`tests/unit/zone_system/test_unlock_evaluation.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 004
- Unlocks: 006, 007
