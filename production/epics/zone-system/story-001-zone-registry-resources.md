# Story 001: ZoneDef / UnlockCondition / ZoneRegistry resources + validation

> **Epic**: Zone System (#19)
> **Status**: ✅ Complete(2026-06-06 — combined gate 1930/1929,0 fail)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S-M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/zone-system.md`(Rule 1 / EC-4 / EC-6)
**Requirement**: GDD-direct(TR registry 未有 #19 entries — 先例一致)
**ADR**: ADR-0007(`kind {ALWAYS, WORKOUT_COUNT, UNKNOWN}` — Classification enum,sentinel last,UNKNOWN = config error)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:data-driven config;新 class_name(ZoneDef / UnlockCondition / ZoneRegistry container)→ CI `--headless --import` 刷 cache
- Forbidden:Dictionary keyed registry(duplicate-id assert 物理不可觸發 — GDD Pass 1 godot F-6);手寫 .tres(typed-array-of-script-class silent null)

## Acceptance Criteria

- [ ] **AC-07**:duplicate zone_id / 0 entries / threshold 0 / kind UNKNOWN(四 vector)→ `validate_registry() == false` + push_error + `zone.registry_invalid` telemetry;**唔用 raw assert**
- [ ] `ZoneRegistry.tres`(MVP 1 entry:`zone_verdant_forest`,ALWAYS,pools 空 = unfiltered sentinel)**editor-saved** + headless `load()` smoke test(registry 載入 + 第一 entry script_class round-trip)

## Implementation Notes

- `Array[ZoneDef]` nested custom Resource — `EnemyRegistry.tres` shipped 先例(`assets/data/EnemyRegistry.tres:1-8`)。`background_scene_path: String`(唔用 PackedScene export)。

## QA Test Cases

GDD AC-07 GWT(四 vector)+ load smoke。

## Test Evidence

**Required**:`tests/unit/zone_system/test_zone_registry_validation.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(START HERE)
- Unlocks: 002-008
