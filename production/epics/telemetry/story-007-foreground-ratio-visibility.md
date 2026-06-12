# Story 007: Formula 2 foreground-ratio + platform_detect Page Visibility hook

> **Epic**: Telemetry / Analytics(#28)
> **Status**: ✅ Complete(2026-06-12 — Formula 2 foreground_ratio + ForegroundTracker + platform_detect visibility_changed/is_page_visible seam (additive) + telemetry wiring; integration GUT 6/6; EC-06 total0→1.0 + visible/hidden banking + non-web fallback 1.0 + seam-connect all green)
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 9(glance-proxy:page-visibility + foreground ratio)+ Formula 2(foreground_time_ratio)。AC-08。
**ADR Governing Implementation**: ADR-N/A — platform seam（JS bridge via platform_detect),no new architectural pattern。受 ADR-0001 forbidden-pattern 約束（raw JS 只經 platform_detect）
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Page Visibility API(`visibilitychange` / `document.visibilityState`)經 `platform_detect.gd` 嘅 JS seam;raw `JavaScriptBridge.eval()` **唔可**喺 telemetry,只可喺 platform_detect（ADR-001 forbidden-pattern）。

**Control Manifest Rules (Polish layer)**:
- Required: Page Visibility 經 platform_detect seam
- Forbidden: telemetry 直接 `JavaScriptBridge.eval()`（ADR-001）
- Guardrail: visibility poll interval = `foreground_sample_interval_ms`(唔食 CPU)

---

## Acceptance Criteria

- [ ] platform_detect expose Page Visibility hook（`visibility_changed(visible: bool)` signal 或 polled getter）—— 若未有則本 story 加（屬 platform_detect seam,非 telemetry 直接 JS）
- [ ] telemetry 累加 `foreground_ms`(tab visible 時長)+ record visibility transition 計數
- [ ] **Formula 2**:`foreground_ratio = foreground_ms / max(session_duration_ms, 1)`,輸出 [0.0, 1.0]
- [ ] div-by-zero 守（boot 瞬間 d=0 → ratio 有定義）
- [ ] foreground_ratio 送 raw float（已正規化,非身體數據）

---

## Implementation Notes

*Derived from GDD Formula 2 + Rule 9 + Rule 12 seam:*

- platform_detect 加 Page Visibility seam（`visibilitychange` listener，desktop fallback：window focus/blur）。telemetry **訂 platform_detect signal**,唔自己掂 JS。
- foreground_ms 累加:visible 期間每 `foreground_sample_interval_ms` tick + transition 即時結算。
- ratio 喺 session boundary（Story 008 session_ended）計算送出。
- 若 platform_detect 已有 visibility seam,複用;否則本 story 加（屬 platform_detect file edit,ADR-001-compliant）。

---

## Out of Scope

- Story 012:page-hide beacon flush（用同一 visibility seam 但係 flush 路徑）
- Story 008:session lifecycle（提供 session_duration_ms）

---

## QA Test Cases

- **AC-1 (foreground ratio, AC-08)**:
  - Given: foreground=1,260,000ms / duration=1,800,000ms
  - When: 計 ratio
  - Then: =0.70
  - Edge cases: duration=0 → max(.,1) 守,ratio 有定義;ratio∈[0,1]
- **AC-2 (visibility accumulation)**:
  - Given: mock visibility transitions（visible 10s → hidden 5s → visible 5s）
  - When: 累加
  - Then: foreground_ms ≈ 15000;transition 計數 = 2
  - Edge cases: 全程 hidden → foreground_ms≈0,ratio≈0（glance 警號 signal）
- **AC-3 (no direct JS)**:
  - Given: telemetry source grep
  - When: 搜 `JavaScriptBridge`
  - Then: 零命中（只經 platform_detect seam,ADR-001）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/telemetry/test_foreground_ratio.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(scaffold)/ Story 003(envelope)
- Unlocks: Story 012（beacon 用同 visibility seam）
