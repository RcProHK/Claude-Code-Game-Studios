# Story 007: Ceremony queue + drain + aggregate

> **Epic**: Zone System (#19)
> **Status**: ✅ Complete(2026-06-06 — combined gate 1930/1929,0 fail)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/zone-system.md`(Rule 6 / EC-5)
**ADR**: ADR-0009;forward contract → #20/#29(**BLOCKED-ON consumer 面** — MVP queue 實際空,#19-side 語意照測)
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-11**:sweep 一次 unlock 3 zones → queue 3 entries + `drain_ceremony_queue()` 一次回 3 個並清空(aggregate reveal 由 consumer own — #19-side assert queue 語意)
- [ ] **Drain 後 persist**;write false → 唔 rollback drain(ceremony 已交付;殘留重播 = accepted over-deliver 方向)+ telemetry
- [ ] EC-5 defensive path(現行軸 unreachable — v0.2 PR_SCORE 先 activate;persist 即時 / queue / active zone 唔切)

## QA Test Cases

GDD AC-11 GWT + drain-persist-fail vector。

## Test Evidence

**Required**:`tests/unit/zone_system/test_ceremony_queue.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 005
- Unlocks: —(#20/#29 consumer 後補)
