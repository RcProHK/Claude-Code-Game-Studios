# Story 003: Event envelope schema + TelemetryEvent type + Rule 4 de-identification

> **Epic**: Telemetry / Analytics(#28)
> **Status**: ✅ Complete(2026-06-12 — TelemetryEvent envelope (8-field) + TelemetryDeId + factory + clock seam; unit GUT 9/9, 42 asserts; monotonic id + de-id [0,2.0] no-PII + monotonic/wall independence + GSM-enum drift guard all green)
> **Layer**: Polish
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 3(envelope schema)+ Rule 4(de-identification)。
**ADR Governing Implementation**: ADR-0009 Signal Payload Schema Convention(primary)
**ADR Decision Summary**: payload minimal + intrinsic;persisted/serialized payload = typed envelope;cross-cutting context late-bind null-safe。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_ticks_msec()`(monotonic)+ `Time.get_unix_time_from_system()`(wall-clock)。

**Control Manifest Rules (Polish layer)**:
- Required: typed envelope;de-id payload(無原始身體數據)
- Forbidden: payload 載原始 kg / 絕對 1RM / bodyweight(G-TEL-3)
- Guardrail: envelope 構造 allocation-light(Rule 2)

---

## Acceptance Criteria

- [ ] `TelemetryEvent` 類型(envelope）含 8 欄:`event_name: StringName / schema_version: int / client_event_id: int / session_id: String / client_ts_unix: int / client_ts_monotonic_ms: int / game_state: StringName / payload: Dictionary`
- [ ] `client_event_id` 係本 session monotonic 序號(per session,去重 + 排序)
- [ ] **Rule 4 de-id**:任何 payload 構造路徑零原始身體數據;magnitude 只存正規化/分桶形式(pr_magnitude [0,2.0] / rarity enum / volume = exercise-count)
- [ ] `schema_version` per-event-name（Story 015 frozen-schema lint 守 `loot_dropped_v1`）
- [ ] envelope factory 純函數可單測

---

## Implementation Notes

*Derived from ADR-0009 + GDD Rule 3/4:*

- envelope 由一個 factory（`_make_event(name, payload, priority)`）統一構造,集中 stamp `client_event_id++` / `session_id` / 兩個 ts / `game_state`。
- de-id 喺**每個 handler 翻譯時**做(handler 只放已正規化值入 payload)—— envelope factory 唔負責「過濾」,但 G-TEL-3 lint（Story 014）grep 整個 source 守 denylist。
- `client_ts_monotonic_ms` = `Time.get_ticks_msec()`（排序 + drift-immune,EC-07）;`client_ts_unix` = wall-clock 絕對 stamp（可跳）。
- priority(CRITICAL/STANDARD/LOW)係 envelope metadata（Story 004 buffer 用）。

---

## Out of Scope

- Story 004:ring buffer 收 envelope
- Story 014:de-id denylist CI lint
- Story 015:frozen schema CI lint

---

## QA Test Cases

- **AC-1 (envelope 8 fields)**:
  - Given: `_make_event(&"hit_resolved", {...}, LOW)`
  - When: 構造
  - Then: 回傳 8 欄齊全;`client_event_id` 比上一個大 1;`session_id` == 當前 session
  - Edge cases: 連續構造 N 個 → client_event_id 嚴格遞增無重複
- **AC-2 (de-id)**:
  - Given: 一個帶 PR 嘅 event
  - When: 構造 payload
  - Then: payload 只含 `pr_magnitude`(∈[0,2.0]),**無** kg / 絕對 1RM key
  - Edge cases: volume context = `completed_exercises_count` 整數,非 kg
- **AC-3 (monotonic vs wall stamp)**:
  - Given: injected clock
  - When: 構造兩個 event,中間 wall-clock 跳 +3600s
  - Then: `client_ts_monotonic_ms` 嚴格遞增;`client_ts_unix` 反映跳變（不影響排序,EC-07 Story 016 詳測）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/telemetry/test_event_envelope_deid.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(scaffold;session_id source）
- Unlocks: Story 004 / 005 / 008 / 009 / 010
