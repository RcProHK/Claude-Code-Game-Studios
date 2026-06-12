# Story 017: Registry knobs TelemetryConfig.tres + cross-knob INV-T

> **Epic**: Telemetry / Analytics(#28)
> **Status**: Complete
> **Layer**: Polish
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Tuning Knobs(13 knob)+ Cross-knob invariants(INV-T1..4)。
**ADR Governing Implementation**: ADR-N/A — data-driven config(.tres),no architectural pattern required
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: data-driven Resource(.tres);啟動斷言 INV-T。

**Control Manifest Rules (Polish layer)**:
- Required: 全 knob data-driven(無 hardcode)
- Forbidden: gameplay value hardcode
- Guardrail: INV-T 啟動斷言

---

## Acceptance Criteria

- [x] `assets/data/telemetry_config.tres`(+ `src/telemetry/telemetry_config.gd` Resource class)持 **12 knob**(GDD table = 12;header「13」係 off-by-one miscount,AC list 正好 12)全 GDD default。`dup_window_ms` 對齊 GDD=**1000**(Story 010 const 係 5000 drift,本 story reconcile runtime default)
- [x] **INV-T1**:`critical_reserved < buffer_max`(`TelemetryConfig.validate()` pure predicate,boundary buffer-1 OK / ==buffer FAIL)
- [x] **INV-T2**:`flush_batch_size ≤ buffer_max`
- [x] **INV-T3**:`switch_latency_buckets_ms` 嚴格升序(equal/descending/empty 全 reject)
- [x] **INV-T4**:`flush_base_delay_seconds ≤ flush_retry_cap_seconds`
- [x] config injectable seam(`set_config()` + pre-_ready `_config` DI override + 已 booted 重 apply;invalid → `set_config` guard 唔 apply;[[reference_test_persistence_isolation]] posture)

---

## Implementation Notes

*Derived from GDD Tuning Knobs + INV-T:*

- `.tres` data-driven;telemetry 啟動讀 config + 跑 INV-T 斷言(違反 push_error 唔啟動)。
- **injectable seam**:telemetry 提供 `set_config(cfg)` 或 ctor 注入,測試用 mock config 避免污染真 autoload(#22/#23/#24/#27 先例)。
- knob 全 float-sec → 內部轉 int-ms 用嘅地方保持 integer-ms 紀律。
- **registry note**:telemetry owns 零 cross-boundary fact → `entities.yaml` **無新 entry**(只 R-2 已回填 `state_changed_signal_signature` referrer)。本 story 唔改 registry。

---

## Out of Scope

- 各 knob 嘅消費邏輯(分散喺 004/005/006/007/008/010/011/016)
- registry entity 新增(無 — telemetry owns 零 cross-boundary fact)

---

## QA Test Cases

- **AC-1 (knobs loaded)**:
  - Given: `TelemetryConfig.tres`
  - When: 啟動讀 config
  - Then: 13 knob 值 == default;injectable seam 可覆寫
  - Edge cases: 缺欄 → default fallback
- **AC-2 (INV-T assertions)**:
  - Given: 違反 INV-T1/2/3/4 嘅 config
  - When: 啟動
  - Then: 各自 push_error/斷言 fail（非法配置唔啟動）
  - Edge cases: 邊界值(reserved == buffer-1 OK;== buffer fail)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check(`production/qa/smoke-*.md`)+ `tests/unit/telemetry/test_config_invariants.gd`(INV-T)
**Status**: [x] `test_config_invariants.gd`(10 tests:shipped-tres defaults / fresh=code-default / boot-apply / inject-override / pre-_ready DI / INV-T1..4 boundary / invalid-not-applied)。**full-project combined gate GREEN 422scr/2861/2858 pass/0 fail/3 honest pending**(揭發 + 修 Story 008 `_on_workout_completed transition_id:int→String` latent type bug,連帶 20 WST integration fail 全清;見 review note)

---

## Implementation Note — Story 008 erratum fixed (full-gate)

收 017 跑 full-project combined gate 時揭發:`telemetry.gd::_on_workout_completed` 嘅 `transition_id: int` 同真 `workout_state_tracker.gd:69 signal workout_completed_forwarded(completed_at: int, transition_id: String)` 唔夾 → 真 autoload 訂閱下每次真 workout 完成 throw `Cannot convert argument 2 from String to int`,連累 20 個 WST integration test fail。MockWST 照抄咗同款錯 int(phantom-pass)。修:handler `transition_id: String` + MockWST signal/emit/assert 3 處 + whole-class audit 全 14 handler vs 真 signal(唯一 type bug;phase_changed enum→int 合法)。see [[reference_mock_signal_type_phantom]]。

---

## Dependencies

- Depends on: Story 002(scaffold)
- Unlocks: Story 005 / 016(consume knobs)
