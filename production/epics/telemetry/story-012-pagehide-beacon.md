# Story 012: Page-hide best-effort beacon (sendBeacon seam)

> **Epic**: Telemetry / Analytics(#28)
> **Status**: **Complete** — `platform_detect.send_beacon`/`send_sync_xhr` seam(raw JS confined,ADR-0001)+ telemetry token-in-body beacon 落地。
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12(ADR-0012 unblock)

## Context

**GDD**: `design/gdd/telemetry.md`
**Requirement**: 直接 trace GDD — Rule 12(page-hide best-effort beacon)+ EC-02/EC-18。AC-13。
**ADR Governing Implementation**: **ADR-0012(Accepted-contract 2026-06-12)**(primary)+ ADR-0004(same-origin)+ ADR-0001(JS seam via platform_detect)
**ADR Decision Summary**: ✅ **RESOLVED** — `POST /api/game/telemetry/beacon`(**token-in-body**,因 `sendBeacon` 無 header 能力)+ `platform_detect.send_beacon(url, body) -> bool` seam;`false` → XHR fallback(EC-18)。**分開 endpoint** 令 token-in-body 弱 auth 唔削弱 header-authed 主 path。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: **engine 硬約束:`navigator.sendBeacon` 唔可以 set custom header** → `X-Session-Token` 行唔通 → auth 入 body。`sendBeacon` 經 platform_detect JS seam(raw JS 唔可喺 telemetry,ADR-001 `raw_javascript_bridge_eval`);unavailable / non-Web → pagehide 同步 best-effort XHR fallback。

**Control Manifest Rules (Polish layer)**:
- Required: sendBeacon 經 platform_detect seam
- Forbidden: telemetry 直接 `JavaScriptBridge.eval()`
- Guardrail: beacon = best-effort fire-and-forget(唔 block)

---

## Acceptance Criteria

*ADR-0012 Accepted (contract) → finalized:*

- [x] platform_detect `visibility_changed(false)` → telemetry `_on_visibility_changed` → `_beacon_flush()` best-effort + ACTIVE→SUSPENDED
- [x] **Rule 12**:`platform_detect.send_beacon(url, body) -> bool`(Web `navigator.sendBeacon` Blob;non-Web false)+ telemetry `_serialize_batch(.., include_token=true)` top-level `session_token`(token-in-body)→ `/api/game/telemetry/beacon`(test `test_hidden_triggers_beacon_token_in_body` JSON-parse body 驗 token)
- [x] **EC-18**:`send_beacon` false → `platform_detect.send_sync_xhr` 同步 XHR fallback(test `test_send_beacon_false_falls_back_to_xhr`)
- [x] **EC-02**:Story 011 每 workout_completed + session boundary 已 flush,beacon best-effort(無 remove-on-ACK,backend UNIQUE 去重)
- [x] **AC-13**:hidden 觸發 beacon + fallback path 可達(5 tests)
- [x] **ADR-001 compliance**:telemetry 經 `platform_detect.send_beacon`/`send_sync_xhr` seam,**零直接 JavaScriptBridge**(`check_platform_detect_callers` exit 0 + `check_telemetry_no_gameplay_emit` exit 0)

---

## Implementation Notes

*ADR-0012 §Beacon Path:*

- 復用 Story 011 serialize;**beacon endpoint = `POST /api/game/telemetry/beacon`**(分開 main flush 嘅 header-authed `/api/game/telemetry`)。
- platform_detect 加 `func send_beacon(url: String, body: String) -> bool` seam(raw JS confined here per ADR-0001):Web → `navigator.sendBeacon(url, Blob([body],{type:'application/json'}))`;non-Web / unavailable → return `false`。
- **token-in-body**:beacon envelope = Story 011 envelope **+ top-level `session_token` field**(backend 由 body 讀 token,非 `X-Session-Token` header)。
- SUSPENDED state(Story 002 FSM)入場先做一次 beacon flush(telemetry.md Rule 12 / States table)。
- pre-session edge:page-hide 時 session 未 claim(無 token)→ best-effort,可能被 drop(罕見,接受;EC-02 已 bound loss)。

---

## Out of Scope

- Story 011:常規 async batch flush(此 story 係緊急 page-hide 路徑)
- Story 007:foreground visibility 累加(同 seam 但係 glance 統計路徑)

---

## QA Test Cases

*待 ADR-0012 finalize:*

- **AC-1 (beacon on hide, AC-13)**:
  - Given: mock platform_detect `visibilitychange→hidden`
  - When: 觸發
  - Then: 一次 best-effort beacon flush
  - Edge cases: EC-18 sendBeacon unavailable → XHR fallback;再失敗接受損失
- **AC-2 (EC-02 bounded loss)**:
  - Given: workout_completed 已 flush + page kill
  - When: 重連
  - Then: in-flight 損失局限最後一批;backend 去重無雙計

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/telemetry/test_pagehide_beacon.gd`
**Status**: [x] `test_pagehide_beacon.gd`(5 tests:hidden→beacon token-in-body + SUSPENDED / EC-18 XHR fallback / visible→ACTIVE / empty-buffer / opt-out suppresses)。全 pass。real sendBeacon arrival = VS-tier-gated(ADR-0012 §Verification 2)

---

## Dependencies

- Depends on: ✅ **ADR-0012 Accepted (contract)**(G-TEL-5 滿足)+ Story 007(visibility seam)/ 011(serialize)
- Unlocks: None
