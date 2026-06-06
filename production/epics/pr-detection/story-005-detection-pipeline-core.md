# Story 005: 判定 pipeline core(confirm / replay / floor / 連續 PR)

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(Rule 4 / Rule 5 / Rule 6 / Rule 7 / D5 / EC-2 / EC-4 / Formula 2)
**ADR**: ADR-0011;secondary ADR-0005(delta 經 001)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:D5 monotonic idempotency(baseline 升咗 → replay no-op);MAGNITUDE_EPS 1e-9 float 邊界
- Forbidden:set-level dedup id(payload 冇 — #2 schema locked)

## Acceptance Criteria

- [ ] **AC-01**:baseline 70.0 + STR=12.0 → `set_logged("bench_press",5,65.0)` → `apply_stat_delta(&"str", PR_BREAKTHROUGH, δ≈0.500)` once、`pr_breakthrough(&"str", 0.0833±0.001)`、baseline → 75.833、一次 flush、`pr.detected`
- [ ] **AC-02**:同 set replay → 零 call / 零 signal / baseline 不變 / 零 persist write
- [ ] **AC-06**:m=0.008(86.4×5 vs baseline 100)→ 唔算 PR
- [ ] **AC-24**:m == 0.01 整(101/100)→ PR confirmed(epsilon guard)
- [ ] **AC-10**:連續 PR 70→75.833(m₁≈0.0833)→ 75×2(e1rm 80.0,m₂≈0.0550)各自生效
- [ ] **AC-05(pipeline 半)**:rep-only 12→15 同重 → 零 PR;110×15 → PR(m=0.1)

## Implementation Notes

- Rule 6 順序 binding(6.1-6.7);6.4 baseline 升 raw;6.5 summary/counters(010 實作 — stub 接口);6.6 一次 flush;6.7 emit(011 實作 gate — 本 story 直 emit + TODO gate)。
- D5 crash-window caveat 係 deliberate(under-count 更傷)— `pr.replay_recheck` telemetry。

## Out of Scope

- Establishment window(006)/ soft-confirm(007)/ reconcile(008)/ short-circuit + all-or-nothing 深度(009)。

## QA Test Cases

GDD AC-01/02/06/24/10/05 GWT(全 pinned;δ golden 重用 AC-12)。

## Test Evidence

**Required**:`tests/unit/pr_detection/test_detection_pipeline.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 001, 003, 004
- Unlocks: 006, 007, 009
