# Story 006: Boot retroactive sweep(純 local recovery)

> **Epic**: Zone System (#19)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/zone-system.md`(Rule 7 / EC-1 / EC-3)
**ADR**: ADR-0003(recovery = local sweep;**零 backend 恢復面** — Pass 1 已糾正 phantom)
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-05**:count 已 persist 25 + 注入新 zone(threshold 20)→ boot sweep 即時 unlock + ceremony queue(EC-3 retroactive — v0.2 加 zone 老玩家場景)
- [ ] Sweep 冪等(已 unlocked skip);count=0 + 只有 ALWAYS → no-op 零 persist 零 queue
- [ ] EC-1 recovery:manifest 損壞 → ALWAYS derived 可用,earned unlocks 由 count sweep 重 derive;count 都冇 → reset 0 + telemetry(唯一 non-derivable primary state — 誠實)

## QA Test Cases

GDD AC-05 + sweep 冪等 + EC-1 recovery vectors。

## Test Evidence

**Required**:`tests/unit/zone_system/test_boot_sweep.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 005
- Unlocks: —
