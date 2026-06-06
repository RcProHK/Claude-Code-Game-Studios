# Story 006: Establishment window(INV-PR-1)+ Baseline Forged

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Formula 4 / Rule 4 / Rule 11 / EC-10 / INV-PR-1)
**ADR**: ADR-0011(fail-closed 係 §D-1 anti-fabrication 嘅 client 半邊)
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-03(warmup-ramp golden)**:無 trusted baseline,同 workout 40×5→50×5→60×5 全零 PR;`workout_completed` → baseline=70.0 + `baseline_established("…",70.0)` + telemetry;下一 workout 65×5 → 正常 PR(m≈0.0833)
- [ ] **AC-28(binding experience)**:establishment commit emit `baseline_established(exercise_id, e1rm)`(handler spy + payload assert;presentation 面由 #20 own — forward contract)
- [ ] Server baseline window 期間到達 → window 即終止,subsequent sets 對 server baseline 判定(candidate 棄用 — GDD Formula 4 注)
- [ ] Mid-workout crash → candidates 遺失 → window 重開(零假 PR;boot stale discard 由 003 cover)

## Implementation Notes

- Candidates:只推高(max);commit 於 #2 `workout_completed`;`baseline_import_completed(count)` reveal hook(首次 non-empty server sync — Rule 11)。
- INV-PR-1 全稱:「local persisted 無 + 本 boot server sync 未成功提供」→ establishment-only。

## Out of Scope

- BASELINE_SYNCING reconcile 細節(008)。

## QA Test Cases

GDD AC-03 / AC-28 GWT + EC-10 vectors。

## Test Evidence

**Required**:`tests/unit/pr_detection/test_establishment_window.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 005
- Unlocks: 008
