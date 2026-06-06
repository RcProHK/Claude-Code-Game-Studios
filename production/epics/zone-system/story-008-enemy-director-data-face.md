# Story 008: #14 data face(pool sentinel + zero-churn 三件套)

> **Epic**: Zone System (#19)
> **Status**: ✅ Complete(2026-06-06 — combined gate 1930/1929,0 fail)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/zone-system.md`(Rule 5 / Rule 8 / AC-09 / G-Z-2)
**ADR**: N/A — data-face contract,無 architectural pattern(G-Z-2 v0.2 先有 #14 改動)
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-09a(Logic)**:MVP registry pools 空 → `get_active_zone().wave_archetype_pool.is_empty()`(unfiltered sentinel — data assert,test 自己 call)
- [ ] **AC-09b(regression gate)**:combined CI green,#14 suite 零變化(現有 evidence — 唔使新 test)
- [ ] **AC-09c(static gate,story-done check)**:grep `enemy_director.gd` 零 `ZoneSystem` reference(MVP zero-churn)
- [ ] Rule 8 lateral loot forward contract 喺 GDD 完好(doc verify — power-budget-neutral binding,v0.2 content enforce)

## QA Test Cases

AC-09 三件套(per GDD 拆法)。

## Test Evidence

**Required**:`tests/integration/zone_system/test_data_face.gd`(09a)+ combined gate(09b)+ grep 記錄(09c)。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 002
- Unlocks: —(G-Z-2 v0.2)
