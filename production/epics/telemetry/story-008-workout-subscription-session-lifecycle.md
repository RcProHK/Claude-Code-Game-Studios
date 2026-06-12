# Story 008: #9 workout lifecycle subscription + session lifecycle (Rule 11)

> **Epic**: Telemetry / Analytics(#28)
> **Status**: ✅ Complete(2026-06-12 — 7 WST signal handlers + Rule 11 session lifecycle + EC-09 bfcache TTL + phase_changed→Formula 1 wiring + flush hook; integration GUT 8/8, 23 asserts all green)
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 11(session lifecycle)+ Interactions(#9 7 signals)+ EC-09(bfcache)/ EC-13(cold-join)。AC-14/17。
**ADR Governing Implementation**: ADR-0006(primary,connect_for_initial_state)+ ADR-0009(payload schema)
**ADR Decision Summary**: late-join subscriber 用 cfis;cross-cutting context late-bind null-safe。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: #9 signals = `workout_started_forwarded` / `workout_completed_forwarded(completed_at,transition_id)` / `workout_summary_available(WorkoutSummaryRO)` / `set_progress_changed(float)` / `dominant_class_changed(AbilityClass)` / `phase_changed(from,to)` / `bfcache_resumed(was_mid_workout,restored_phase)`。

**Control Manifest Rules (Polish layer)**:
- Required: observe-only;handler O(1) non-blocking
- Forbidden: call 返 #9 mutating method
- Guardrail: 唔 fabricate workout start（EC-13）

---

## Acceptance Criteria

- [ ] 訂閱 #9 全部 7 signal(plain connect,late-boot 即收;`phase_changed` 餵 Story 006 latency)
- [ ] **Rule 11 session lifecycle**:boot 開 `session_id` + emit `session_started`(帶 platform/is_mobile/app_version/last_session_max_rarity);session 結束 emit `session_ended`(帶 foreground_ratio/total events)
- [ ] **EC-09 bfcache**:`bfcache_resumed` → record event;距上次活動 ≤ `session_resume_ttl_seconds` 保留同 session_id,超 TTL 開新 session（`resumed_from_bfcache=true`）
- [ ] **EC-13 cold-join**:收到 `workout_completed_forwarded` 但本 session 無見過 `workout_started_forwarded` → record `had_observed_start=false`,**唔 fabricate** start
- [ ] `workout_completed_forwarded` 觸發 flush boundary（接 Story 011 flush;此處標記 boundary）

---

## Implementation Notes

*Derived from GDD Rule 11 + Interactions + EC-09/13:*

- 全部 #9 signal plain `.connect()`（observe-only;#9 已 implemented,signal contract grep-verified EXACT）。
- `phase_changed` handler 轉發俾 Story 006 latency 邏輯。
- session boundary:`workout_completed_forwarded` = 最重要 flush trigger（Rule 6c）—— 此處標記 `_request_flush(REASON_WORKOUT_COMPLETE)` stub（真 flush Story 011）。
- bfcache session 連續性用 `session_resume_ttl_seconds`(injected clock 測 TTL)。
- **WST bfcache_resumed decl erratum**(Q-T8):WST L399 承諾 emit 但 decl block L117-123 漏列 → 隨本 story 或 G-TEL-1 回填 WST doc（跨 file,唔 block）。

---

## Out of Scope

- Story 010:loot subscription（last_session_max_rarity 來源喺 loot,session-open stamp 在此但值由 010 餵）
- Story 011:真 flush on workout boundary

---

## QA Test Cases

- **AC-1 (session lifecycle, AC-17)**:
  - Given: boot → events → unload
  - When: 檢視 stream
  - Then: `session_started`/`session_ended` 包夾,全部 event 共用同一 session_id
  - Edge cases: session_ended 帶 foreground_ratio + total events
- **AC-2 (bfcache continuity, AC-14)**:
  - Given: `bfcache_resumed`,injected clock
  - When: 距上次活動 ≤ TTL vs > TTL
  - Then: ≤TTL 保留 session_id;>TTL 開新 + resumed_from_bfcache=true
  - Edge cases: was_mid_workout=true record 正確
- **AC-3 (cold-join no fabricate, EC-13)**:
  - Given: workout_completed 但無前置 workout_started
  - When: 處理
  - Then: record completion 帶 had_observed_start=false;**無** fabricated start event

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/telemetry/test_workout_subscription_session.gd`(含 bfcache + cold-join)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 / 003 / 006(phase latency)
- Unlocks: Story 010 / 011
