# Story 002: Autoload 骨架 + boot lifecycle + gates(G-Z-1 / G-Z-3)

> **Epic**: Zone System (#19)
> **Status**: ✅ Complete(2026-06-06 — combined gate 1930/1929,0 fail)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S-M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/zone-system.md`(Rule 10 / States)
**ADR**: ADR-0008(G-Z-1)+ ADR-0006 C4
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-12**:`_ready` 完結時 READY(synchronous)+ #9 `is_connected` true + envelope 已 load(read spy ≥1);load≺sweep 由 AC-05 functional 證明
- [ ] **AC-01**:MVP registry boot → `get_active_zone().zone_id == &"zone_verdant_forest"`、`is_zone_unlocked()` true(derived)、persisted manifest 唔含 ALWAYS(Rule 4)
- [ ] `ZoneSystem` autoload 登記(constraint `Persistence ≺ WST ≺ ZoneSystem`;append 鏈尾 PrDetection 之後)
- [ ] **G-Z-1**:ADR-0008 amendment(**同 #18 story 002 嘅 G-PR-3 共用一次 amendment** — 如 #18 002 已行,本 story 只 verify;未行就本 story 執行兩個 insertion)
- [ ] **G-Z-3**:VALID_NAMESPACES 加 `"zone."` 一行 + #3 GDD Rule 12 registry 一行 + namespace lint create-or-amend(同 #18 G-PR-6 共用 lint 面)
- [ ] 讀面 API:`is_zone_unlocked` / `get_unlocked_zone_ids`(defensive copy)/ `get_active_zone`

## Implementation Notes

- 4 untyped DI seams stub(persistence / registry 注入 / workout source / telemetry append-log #15/#17 verbatim)。Wiring = plain consumer connect(G-PR-4 reverse-wire **唔適用** — GDD Rule 10)。

## QA Test Cases

GDD AC-01 / AC-12(functional form)。

## Test Evidence

**Required**:`tests/unit/zone_system/test_boot_lifecycle.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 001
- Unlocks: 003-008
