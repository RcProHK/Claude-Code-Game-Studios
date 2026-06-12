# Story 006: Formula 1 switch-latency glance proxy (bucketed)

> **Epic**: Telemetry / Analytics(#28)
> **Status**: ✅ Complete(2026-06-12 — Formula 1 switch_latency_ms/bucket (5-bucket [5000,15000,60000,180000]) + SwitchLatencyTracker anchor FSM; unit GUT 9/9; AC-05 12s→bucket1 + boundary + edge(a)/(b) + INV-T3 ascending all green)
> **Layer**: Polish
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 9(glance-proxy)+ Formula 1(exercise_switch_latency)+ EC-04。AC-05。
**ADR Governing Implementation**: ADR-N/A — pure formula,no architectural pattern
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: monotonic ms 計時源;integer-ms 紀律。

**Control Manifest Rules (Polish layer)**:
- Required: latency 送 bucket index 唔送原值（de-id）
- Forbidden: 送原始 rest 時長（反推訓練細節洩漏）
- Guardrail: 只喺有 REST_PERIOD anchor 時計

---

## Acceptance Criteria

- [ ] **Formula 1**:`switch_latency_ms = ts_set_active_entry − ts_rest_period_entry`(兩者 = 對應 `phase_changed` 時嘅 `client_ts_monotonic_ms`)
- [ ] 分桶 `SWITCH_LATENCY_BUCKETS_MS` → `{<5s, 5–15s, 15–60s, 60–180s, >180s}`,**只送 bucket index**
- [ ] **EC-04 edge (a)**:REST_PERIOD→WORKOUT_COMPLETE → 唔產生 latency event
- [ ] **edge (b)**:首個 SET_ACTIVE（WARM_UP→SET_ACTIVE,冇前置 REST_PERIOD）→ 唔產生 latency event（只喺有記錄 REST_PERIOD entry 後計）
- [ ] INV-T3 `SWITCH_LATENCY_BUCKETS_MS` 嚴格升序斷言

---

## Implementation Notes

*Derived from GDD Formula 1 + Rule 9:*

- telemetry 記低最近一次 `phase_changed(_, REST_PERIOD)` 嘅 monotonic ts 做 anchor;見到下一個 `phase_changed(_, SET_ACTIVE)` 計 delta → 分桶 → emit `switch_latency`(STANDARD) → 清 anchor。
- 無 anchor 時收到 SET_ACTIVE → skip（edge b）。REST_PERIOD→WORKOUT_COMPLETE → 清 anchor 唔 emit（edge a）。
- 本 story 做 latency 邏輯 + bucketing;真 `phase_changed` 訂閱 wiring 在 Story 008。測試用直接餵 phase 事件。

---

## Out of Scope

- Story 007:foreground-ratio glance proxy
- Story 008:真 `phase_changed` 訂閱 wiring

---

## QA Test Cases

- **AC-1 (latency + bucket, AC-05)**:
  - Given: REST_PERIOD @ monotonic 120000ms,SET_ACTIVE @ 132000ms
  - When: 計 latency
  - Then: 12000ms → bucket index 對應 `5–15s`;event 只帶 bucket index
  - Edge cases: 4999ms→`<5s`;181000ms→`>180s`(邊界)
- **AC-2 (edge a + b)**:
  - Given: (a) REST_PERIOD→WORKOUT_COMPLETE;(b) WARM_UP→SET_ACTIVE 無前置 REST
  - When: 處理
  - Then: 兩者皆唔產生 latency event
  - Edge cases: 有 REST anchor 後正常 emit,清 anchor 後再來 SET_ACTIVE 無 anchor→skip
- **AC-3 (INV-T3)**:
  - Given: 非升序 buckets config
  - When: 啟動
  - Then: 斷言 fail

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/telemetry/test_switch_latency.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(envelope)
- Unlocks: Story 008（workout subscription wires phase_changed）
