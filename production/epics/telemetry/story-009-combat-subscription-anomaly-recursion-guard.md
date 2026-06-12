# Story 009: #14 combat subscription + anomaly critical channel + Rule 15 recursion guard

> **Epic**: Telemetry / Analytics(#28)
> **Status**: ✅ Complete(2026-06-12 — 3 #14 combat handlers + Formula 3/4 wiring + anomaly CRITICAL channel + Rule 15 recursion guard + self-error diagnostic; GUT 2-script 10/10, 23 asserts; AC-10 order-resilience + AC-12 recursion + EC-11 suspended-buffer all green)
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Interactions(#14 3 signals)+ Rule 15(recursion guard)+ Rule 8 wiring + EC-06/EC-11。AC-10/12。
**ADR Governing Implementation**: ADR-0009(payload schema)
**ADR Decision Summary**: payload minimal+intrinsic;observe-only。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: #14 emit `hit_resolved(HitResolvedPayload)` / `enemy_killed(EnemyKilledPayload)` / `combat_metric_anomaly(CombatAnomalyPayload)`（#13 owns 定義）。#14 Rule 17 已 upstream rate-limit 10/sec/reason + aggregate。**#13 EC-49 28-recursion-guard**。

**Control Manifest Rules (Polish layer)**:
- Required: anomaly = CRITICAL priority;recursion-safe handler
- Forbidden: telemetry self-error re-emit 做 `combat_metric_anomaly`（遞迴）
- Guardrail: combat handler O(1)（hit 高頻）

---

## Acceptance Criteria

- [ ] 訂閱 #14 3 signal,late-boot 即收（**AC-10 order-resilience**:boot Last 後 emit 全部 capture,零 silent drop;`game_state` stamp == back-filled）
- [ ] `hit_resolved` → 餵 Story 005 sample + lossless aggregate
- [ ] `enemy_killed` → STANDARD event;`combat_metric_anomaly` → **CRITICAL** channel(silent-fail backstop,FR-5)
- [ ] **Rule 15 recursion guard(AC-12,#13 EC-49)**:telemetry 自身 error 入獨立 diagnostic channel(`push_warning` + `telemetry_self_error` LOW meta),**永不** re-emit `combat_metric_anomaly`;handler re-entrancy-safe
- [ ] **EC-11**:SUSPENDED 期間仍收到 combat signal → 仍 buffer（唔丟,如實記錄）

---

## Implementation Notes

*Derived from GDD Rule 15 + Interactions + #13 EC-49:*

- 3 signal plain `.connect()`;#14 已 implemented + signal contract grep-verified EXACT。
- `hit_resolved` handler 轉發 Story 005 sample/aggregate 邏輯。
- recursion guard:handler 包 try-style guard（GDScript 無 try,用 re-entrancy flag `_in_handler`）—— 若 handler 內出錯,記 diagnostic,**唔** call 任何會觸發 anomaly 嘅路徑。
- **AC-10 order-resilience** 係 integration 重點:mock #14 喺 telemetry boot 後 emit,斷言全部入 buffer + game_state stamp 正確。
- EnemyKilledPayload 用 `enemy_instance_id`（#25 grep erratum 教訓:非 target_id）。

---

## Out of Scope

- Story 005:sample/aggregate 邏輯本體（此處 wire）
- Story 011:flush 送 combat_aggregate

---

## QA Test Cases

- **AC-1 (order-resilience, AC-10)**:
  - Given: telemetry boot Last,mock #14 boot 後 emit 3 signal
  - When: emit
  - Then: 三者全部 capture（零 silent drop）;首批 event game_state stamp == cfis back-filled current_state
  - Edge cases: anomaly → CRITICAL priority;enemy_killed → STANDARD
- **AC-2 (recursion guard, AC-12)**:
  - Given: anomaly handler 內注入 serialize 失敗
  - When: 觸發
  - Then: 記 diagnostic channel（push_warning + telemetry_self_error);**無** re-emit combat_metric_anomaly;無無限遞迴
  - Edge cases: 連續多個 anomaly + self-error → 唔互相觸發
- **AC-3 (EC-11 suspended)**:
  - Given: telemetry SUSPENDED,收到 hit_resolved
  - When: 處理
  - Then: 仍 buffer（如實記錄,唔丟）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/telemetry/test_boot_order_resilience.gd`(AC-10) + `tests/unit/telemetry/test_recursion_guard.gd`(AC-12)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 / 003 / 004 / 005
- Unlocks: Story 011
