# Story 007: Soft-confirm D8(pending / corroborate / discard)+ INV-PR-2

> **Epic**: PR Detection & Avatar Progression (#18)
> **Status**: ✅ Complete(2026-06-06 — gate green:combined 1889/1888,0 fail)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M-L
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/pr-detection.md`(D8 pipeline block / EC-5 / EC-15 / INV-PR-2)
**ADR**: ADR-0011(§D-2.3 server ratchet 包 D8 語意 — client 半邊喺本 story)
**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-07 三路徑**:raw m=3.5 → PENDING(零 delta/signal/count/baseline)+ `pr.magnitude_anomaly` + `pr.pending_opened`;(a) corroborate(e1rm ≥ pending×0.95)→ commit(**commit-time 重計 magnitude** → clamp;baseline 升 raw)+ `pr.pending_corroborated`;(b) `current_seq > opened_seq` 嘅 `workout_completed` 仍無 corroboration → discard + `pr.pending_discarded`;(c) m=0.25 → 即時 confirmed
- [ ] **AC-29(interleaved 重計)**:70 → suspect 94.5(pending)→ interleaved PR 76.0 → corroborate 92.0 → commit m=(94.5−76)/76≈**0.2434**(唔係 stored 0.35);Σm≈0.3291 ≤ 0.35
- [ ] **AC-31(INV-PR-2 property)**:步進序列 70→75.83→80→90 assert `ln(90/70) ≤ Σm ≤ 20/70`(±1e-6)+ micro-step ×20 同 bound

## Implementation Notes

- D8 pipeline 順序 binding:pending 存在 → corroboration check **先行** → commit(重計)→ 本 set 對最新 baseline 判定。Keep-highest replace + `pr.pending_replaced`。Per-exercise pending dict。
- EC-15 replay self-corroboration 殘餘 accept(server-truth 自我修正)— telemetry 記 (reps, weight)。

## Out of Scope

- Server ratchet D8 語意(EXTERNAL 015)。

## QA Test Cases

GDD AC-07 / AC-29 / AC-31 GWT(全 pinned 數字)。

## Test Evidence

**Required**:`tests/unit/pr_detection/test_soft_confirm.gd`。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 005
- Unlocks: —
