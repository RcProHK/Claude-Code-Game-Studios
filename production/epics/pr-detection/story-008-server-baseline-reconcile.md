# Story 008: Server baseline reconcile(validation / floor / fail-closed)

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: ✅ Complete(2026-06-06 — gate green:combined 1896/1895,0 fail)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Rule 8 / D2 / EC-7 / EC-7b / EC-8 / EC-16 / BASELINE_SYNCING)
**ADR**: **ADR-0011 §D-2**(四 sub-spec — 本 story 實作 client 半邊:per-entry validation + reconcile 規則 + sync timing 消費面)
**Engine**: Godot 4.6 | **Risk**: LOW(server 面 EXTERNAL 015;本 story 用 capture-release mock)

## Acceptance Criteria

- [ ] **AC-14**:local 70 + server 85(validated)→ baseline 85(server 贏 pre-session)
- [ ] **AC-15**:sync fail →(a)有 local cache 照判定(grace);(b)無 local cache → establishment-only 零 PR(INV-PR-1 fail-closed)
- [ ] **AC-16(double-count race)**:SYNCING 期間 local PR confirmed(75.833)→ server 返 70 → baseline 維持 75.833(session-confirmed floor)+ `pr.baseline_conflict`;replay → no-op
- [ ] **AC-23**:server 回 `{a:0, b:-10, c:INF, d:0.5, e:800, f:85}` → a-e reject(`pr.baseline_invalid` ×5)、f 採納(validation = `is_finite ∧ v≥WEIGHT_SANITY_MIN ∧ v≤WEIGHT_SANITY_MAX×(1+REP_CAP/30)`)

## Implementation Notes

- Baseline ride 喺 #2 polling state response field(§D-2.4)— mock 做 capture-and-release async seam(seam ②)。EC-7(server-HIGHER:覆寫,已 apply delta 唔回收,one-shot)同 EC-7b(floor)兩方向都要。

## Out of Scope

- GymSys server 端(015 EXTERNAL)。

## QA Test Cases

GDD AC-14/15/16/23 GWT(capture-release ordering)。

## Test Evidence

**Required**:`tests/unit/pr_detection/test_baseline_reconcile.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 003, 006
- Unlocks: —
