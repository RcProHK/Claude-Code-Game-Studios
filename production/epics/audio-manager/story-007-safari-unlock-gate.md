# Story 007: Mobile Safari unlock gate (`_audio_unlocked` 正交 flag)

> **Epic**: Audio Manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-005`
*(See EPIC.md GDD Requirements table.)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps) — Web Export audio unlock
**ADR Decision Summary**: Web Export 約束；raw `JavaScriptBridge.eval()` 只准喺 `platform_detect.gd`。Q3 resolved：Godot 4.6 Web audio driver 引擎層喺首 user input **自動 resume** suspended AudioContext，AudioManager 無需 JSBridge → 無 ADR-0001 衝突。

**Engine**: Godot 4.6 | **Risk**: MEDIUM (Q3 godot-resolved; real-device Safari ADVISORY — Q7)
**Engine Notes**: `_input()` 喺任何 Control 之前 fire；首個 `InputEventScreenTouch`/`InputEventMouseButton` → `_do_unlock()`。Desktop/native boot 即 `_audio_unlocked=true`。PlatformDetect injection seam **untyped** `var _platform_detect`（stub `is_web()`）。

**Control Manifest Rules (Foundation)**:
- Required: `_audio_unlocked` 獨立 boolean flag（**非** GSM state）；`_do_unlock()` idempotent（early-return if already true）
- Forbidden: raw `JavaScriptBridge.eval()`（只准 platform_detect.gd）；stale SFX replay；`OS.has_feature("web")` 直接 call（經 `_platform_detect`）
- Guardrail: LOCKED window 須極短（#20 banner 引導首 tap）

---

## Acceptance Criteria

- [ ] **AC-05** GIVEN web + LOCKED，WHEN `play_bgm(A)` 然後首 gesture，THEN unlock 時起播 + `audio_unlocked` emit 一次
- [ ] **AC-06** GIVEN LOCKED，WHEN `play_sfx`，THEN dropped + warn，無 crash
- [ ] **AC-06b** GIVEN web + LOCKED，WHEN `is_audio_unlocked()`→`false`；首 InputEvent → `audio_unlocked` emit 一次後 `is_audio_unlocked()`→`true`（#20 banner 訂閱）
- [ ] **AC-19a** GIVEN `_audio_unlocked==false` 連 `play_bgm(A/B/C)` + mock GSM current 有 map entry（WORKOUT_ACTIVE→focus_low），WHEN unlock，THEN 起播 == **GSM-mapped track**（focus_low，非 deferred C）+ `bgm_changed` emit ≤1 + payload==focus_low
- [ ] **AC-19b** GIVEN 同上但 GSM current **無** map entry，WHEN unlock，THEN deferred slot==C + 起播==C + emit ≤1（fallback）；子: 重複 `play_bgm(A)` → slot 維持 A，unlock 起一次
- [ ] **AC-26** GIVEN web + `_audio_unlocked==false`，WHEN 首 InputEvent，THEN `audio_unlock_confirm` 播一次 + `audio_unlocked` emit 一次
- [ ] **AC-31** GIVEN desktop（boot `_audio_unlocked==true`），WHEN 任何 InputEvent，THEN `audio_unlock_confirm` 唔播 + `audio_unlocked` 唔 emit
- [ ] **AC-32b** PlatformDetect 經 untyped `var _platform_detect` seam；inject `is_web()==true`→AC-05/06b 可驗；`==false`→AC-31 可驗

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 5:*

- `unlocked` = **獨立 boolean flag** `_audio_unlocked`，**唔係** GSM state。LOCKED = `is_web AND NOT _audio_unlocked` derived。SUSPENDED 可同「未 unlock」正交共存（Story 008）。
- `_do_unlock()`：(1) `_audio_unlocked=true` + emit `audio_unlocked`；(2) 播 `audio_unlock_confirm`（mid priority，唔俾 steal）；(3) **重 query GSM 當前 state 起 BGM**（唔直接補播 deferred，防 stale boss_theme churn）；deferred slot 只做 GSM 無 map entry 時 fallback。
- 兩條 unlock 路徑 idempotent early-return if already true：`_input()` = engine fallback（任何 stray tap）；#20 banner `pressed` = canonical UX。任一先到 unlock，另一無副作用。
- LOCKED：`play_bgm` 入 single-slot deferred（latest-wins）；`play_sfx` drop + warn（**唔** stale replay）。
- **平台判斷一律經 `_platform_detect`**（唔直接 call PlatformDetect singleton / `OS.has_feature`）— 否則 headless 走 default 分支 phantom-pass。

---

## Out of Scope

- **EG-1**（external，#9 side）：pre-unlock workout SFX forwarding（#9 WST hold mid/high SFX until `audio_unlocked`）— #4 只 expose `is_audio_unlocked()` + `audio_unlocked` signal contract，**唔做** time-windowed defer-replay（stateless gateway）
- **EG-2**（external，#20 side）：silent-mode banner 視覺/文案（#4 只定 contract）
- Story 008: LOCKED×SUSPENDED 共存 resume（AC-14c）
- Story 006: GSM map（呢度 unlock query 重用 006 map）

---

## QA Test Cases

*Integration — inject mock `_platform_detect` + `_gsm`。*

- **AC-05/06b**: web unlock — Given inject `is_web()==true` + LOCKED + `play_bgm(A)` / When 首 InputEvent / Then A（或 GSM-current）起播 + `audio_unlocked` emit 一次 + `is_audio_unlocked()`→true。
- **AC-06**: LOCKED drop sfx — Given LOCKED / When `play_sfx` / Then dropped + warn，無 crash，無 defer。
- **AC-19a**: GSM-priority on unlock — Given pre-unlock `play_bgm(A/B/C)` + mock GSM current WORKOUT_ACTIVE→focus_low / When unlock / Then 起播 focus_low（非 C）+ emit payload focus_low。
- **AC-19b**: deferred fallback — Given 同上但 GSM 無 map entry / When unlock / Then 起播 C（deferred）。子: `play_bgm(A)`×2 → unlock 起一次。
- **AC-26**: unlock confirm — Given web LOCKED / When 首 InputEvent / Then `audio_unlock_confirm` playcall==1 + `audio_unlocked` emit 1。
- **AC-31**: desktop no-confirm — Given inject `is_web()==false`（boot unlocked）/ When InputEvent / Then confirm playcall==0 + `audio_unlocked` 唔 emit。
- **AC-32b**: platform seam — inject true/false 切換 web/desktop 分支可 headless verify（無真 PlatformDetect autoload）。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio/test_safari_unlock_gate.gd` — must exist and pass（⚠️ GUT 只收 `test_*.gd` prefix — [[reference_gut_filename_convention]]）
**Status**: [ ] Not yet created

> ⚠️ EG-1（#9 forwarding）+ EG-2（#20 banner）係 external GDD 軌道，唔阻 #4 story；#4 側只 expose `is_audio_unlocked()`/`audio_unlocked`，呢個 contract 喺本 story 完整實作 + 測。Q7 real-device Safari AudioContext resume = ADVISORY playtest（post-cutoff，headless 唔測）。

---

## Dependencies

- Depends on: 001 (`_platform_detect` seam) ✅, 006 (GSM map for unlock query) ✅
- Unlocks: 008 (LOCKED×SUSPENDED coexistence)

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: AC-05/06/06b/19a/19b/26/31/32b covered + local-verified
**Files**: `src/autoload/audio_manager.gd`（`_do_unlock()` idempotent [set flag + emit audio_unlocked + play audio_unlock_confirm + re-query GSM-current track, deferred fallback]；`_input()` engine fallback [InputEventScreenTouch/MouseButton → _do_unlock, no event consumption]；play_bgm LOCKED → `_deferred_bgm_track` single-slot latest-wins；`_deferred_bgm_track` member）· `tests/integration/audio/test_safari_unlock_gate.gd`（8 tests）
**Test Evidence**: Integration — `test_safari_unlock_gate.gd` ✅ **LOCAL GUT 8/8**（audio 52/52）。**Full gate 239 scripts / 1452 tests / 1451 pass / 1 pending(AC-37) / 0 fail** — no regression.
**Deviations / notes**:
- ⚠️ **EG-1 (#9 WST pre-unlock SFX forwarding)** + **EG-2 (#20 banner soft-gate)** are EXTERNAL — #4 only exposes `is_audio_unlocked()` + `audio_unlocked` signal + idempotent `_do_unlock()` (callable by #20 banner `pressed`). Implemented + tested the #4 contract side.
- Unlock prefers GSM-current track over the stale deferred slot (anti-stale, GDD Pass-2 fix); deferred is fallback when current state has no mapping.
- `_input` real engine dispatch + Q7 real-device Safari AudioContext auto-resume = ADVISORY (headless can't test); unlock LOGIC verified via `_do_unlock()`.
- No `JavaScriptBridge` (ADR-0001 — `_is_web` uses the seam / `OS.has_feature` fallback). No out-of-scope files.
**Code Review**: Complete (/code-review APPROVED WITH SUGGESTIONS).
