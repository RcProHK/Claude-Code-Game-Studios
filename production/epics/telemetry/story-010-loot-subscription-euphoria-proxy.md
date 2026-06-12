# Story 010: #15 loot subscription + drop-euphoria proxy (Rule 10)

> **Epic**: Telemetry / Analytics(#28)
> **Status**: ✅ Complete(2026-06-12 — loot_dropped frozen-v1 + ceremony_capped CRITICAL + pending_recovered + drop_unbound + EC-03 dedup + Rule 10 session-max-rarity; GUT 2-script 9/9, 24 asserts. ERRATUM: #15 shipped only emits loot_ceremony_capped/loot_pending_recovered; loot_drop_unbound + loot_zero_workout_floor_applied + loot_rarity_mismatch NOT in #15 surface — _connect_if skips absent, handlers ready)
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 10(drop-euphoria proxy)+ Interactions(#15 signals)+ EC-03(dup)/ EC-14(unbound)。
**ADR Governing Implementation**: ADR-0009(payload schema)
**ADR Decision Summary**: payload minimal+intrinsic;observe-only。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: #15 emit `loot_dropped(drop_id, rarity_tier, item_type, transition_id)` per **frozen `loot_dropped_v1`**(FR-LOOT-3)+ telemetry-only `loot_ceremony_capped(workout_id,capped_kill_count)` / `loot_zero_workout_floor_applied` / `loot_rarity_mismatch` / `loot_drop_unbound(transition_id,reason)` / `loot_pending_recovered`。

**Control Manifest Rules (Polish layer)**:
- Required: `loot_dropped` 跟 frozen v1 schema(G-TEL-4)
- Forbidden: 改 loot_dropped 欄位無 version bump
- Guardrail: loot 異常族 = CRITICAL priority

---

## Acceptance Criteria

- [ ] 訂閱 #15 `loot_dropped`(STANDARD,euphoria proxy:rarity 分布)+ 5 個 telemetry-only loot 審計 signal
- [ ] loot 異常族(`loot_ceremony_capped` / `loot_zero_workout_floor_applied` / `loot_rarity_mismatch` / `loot_drop_unbound`)→ **CRITICAL** channel
- [ ] `loot_pending_recovered` → record(ADR-0003 durability 驗證 signal)
- [ ] **Rule 10**:session-open meta-event 帶 `last_session_max_rarity` context stamp(跨 session 相關性留 backend)
- [ ] **EC-03 dup**:同 `event_name+transition_id` 喺 `dup_window_ms` 內兩次 → 兩個都如實 record + emit `duplicate_transition_observed`(CRITICAL)
- [ ] **EC-14 unbound**:`loot_drop_unbound(reason="no_active_workout")` → record 審計 event(STANDARD,非 error)

---

## Implementation Notes

*Derived from GDD Rule 10 + Interactions + EC-03/14:*

- 全部 #15 signal plain `.connect()`;#15 已 implemented + contract grep-verified EXACT。
- `loot_dropped` serialize **必須**跟 frozen `loot_dropped_v1` field set（G-TEL-4 lint Story 015 守）。
- `last_session_max_rarity`:telemetry 記低本 session 見過嘅最高 rarity,下次 session_started 時 stamp（Story 008 session meta 帶上）。
- EC-03 dup detection:telemetry 維持一個 `(event_name, transition_id)` recent-window set（`dup_window_ms`,injected clock 測）。

---

## Out of Scope

- Story 008:session_started meta-event 本體（此處餵 last_session_max_rarity 值）
- Story 015:frozen schema CI lint

---

## QA Test Cases

- **AC-1 (rarity distribution + frozen schema)**:
  - Given: 多個 loot_dropped 不同 rarity
  - When: record
  - Then: 各 event payload = 恰好 4 欄(drop_id,rarity_tier,item_type,transition_id);rarity 分布可聚合
  - Edge cases: rarity_tier 係 de-id enum string
- **AC-2 (loot anomaly CRITICAL)**:
  - Given: `loot_ceremony_capped` / `loot_rarity_mismatch` 等
  - When: record
  - Then: priority == CRITICAL(永不 drop/sample)
  - Edge cases: `loot_drop_unbound` → STANDARD 審計(EC-14,非 error)
- **AC-3 (dup detection, EC-03)**:
  - Given: 同 event_name+transition_id 喺 dup_window_ms 內兩次
  - When: 處理
  - Then: 兩個都 record + 一個 `duplicate_transition_observed`(CRITICAL)
  - Edge cases: 超 window → 唔當重複

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/telemetry/test_loot_subscription_euphoria.gd` + `tests/unit/telemetry/test_duplicate_transition.gd`(EC-03)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 / 003 / 004 / 008(session meta)
- Unlocks: Story 011 / 015(frozen-schema lint 對象)
