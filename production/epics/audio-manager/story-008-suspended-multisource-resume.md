# Story 008: SUSPENDED multi-source + BGM resume-from-position

> **Epic**: Audio Manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L (4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-005`, `TR-audio-006`, `TR-audio-007`（suspend aspects）
*(See EPIC.md GDD Requirements table.)*

**ADR Governing Implementation**: ADR-0006 Contract 4 (sequential autoload boot / suspension posture) — primary; GDD-owned multi-source dedup
**ADR Decision Summary**: SUSPENDED 覆蓋 service axis（同 #6/#7/#8 posture）；autoload suspension 一致行為。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: 三 suspend source — GSM SUSPENDED / OS `NOTIFICATION_APPLICATION_PAUSED` / `NOTIFICATION_WM_WINDOW_FOCUS_OUT`（web-primary）。headless 唔發 OS notification → 抽純函數 `_handle_focus_change(paused)` 可測，wiring 留 ADVISORY。non-looping stream seek 需 variant + position。

**Control Manifest Rules (Foundation)**:
- Required: `_suspend_sources` bitmask（first-entry latch / last-exit resume）；SUSPENDED 覆蓋 service 但**唔覆蓋** `_audio_unlocked` flag axis
- Forbidden: double-pause（無去重）；resume 卡半 crossfade/duck 態
- Guardrail: suspend → kill 全部 retained Tween（crossfade + duck）

---

## Acceptance Criteria

- [ ] **AC-14** GIVEN READY + GSM→SUSPENDED，THEN 全部 paused 且 `_suspended_bgm_state.variant_id==<當前 variant_id>`；resume（bitmask 降 0）→ active player.stream==該 track
- [ ] **AC-14b** GIVEN A→B crossfade 中 GSM→SUSPENDED，THEN crossfade Tween `is_valid()==false` + pause all + `_suspended_bgm_state.variant_id==B`；resume → player.stream==B（唔卡半 crossfade）
- [ ] **AC-14c** GIVEN web + `_audio_unlocked==false` + `play_bgm(A)` deferred，WHEN GSM→SUSPENDED→resume（仍未 gesture），THEN `_audio_unlocked` 仍 false + deferred slot==A；首 gesture → unlock 起 GSM-current + emit 一次（無永久靜音）
- [ ] **AC-24a** GIVEN READY，WHEN `_handle_focus_change(false)`，THEN music paused；`(true)`→resume（純函數 headless 斷言）
- [ ] **AC-24b**（ADVISORY）GIVEN 真機，WHEN `NOTIFICATION_WM_WINDOW_FOCUS_OUT`，THEN 正確 wire 去 `_handle_focus_change(false)`
- [ ] **AC-30** GIVEN READY，GSM→SUSPENDED（bit0，0→1）pause once；`_handle_focus_change(false)`（bit2，1→5）唔再 pause；GSM clear（5→4）唔 resume；`(true)`（4→0）resume once
- [ ] **AC-33** GIVEN duck active，WHEN `_handle_focus_change(false)`/SUSPENDED，THEN duck Tween killed + Music bus hard-set `base_music_db` + `_active_ducks` **保留**；resume → 重 spawn duck tween target==`_compute_duck_target(_active_ducks)`
- [ ] **AC-34** GIVEN BOSS_ENCOUNTER（boss_theme 播 + `_paused_focus_low=={focus_low_v1,12.3}`），WHEN SUSPENDED，THEN `_suspended_bgm_state.variant_id=="boss_theme"` 且 `_paused_focus_low` 不變；resume 還原 boss_theme；後 GSM→WORKOUT_ACTIVE → 用 `_paused_focus_low` resume-from-position

---

## Implementation Notes

*Derived from ADR-0006 C4 + GDD States table + EC:*

- **`_suspend_sources` bitmask**：bit0=GSM SUSPENDED / bit1=OS `APPLICATION_PAUSED` / bit2=`WM_WINDOW_FOCUS_OUT`。任一 set → bitmask 0→non-zero 先 pause + 記 BGM state（first-entry latch）；任一 clear → bitmask 降 0 先 resume（last-exit）。`_handle_focus_change(paused)` 走同一 bitmask（set/clear bit2）。
- **`_suspended_bgm_state` = `{variant_id, position_sec}`**（canonical 名，**非** `_suspended_bgm_track`；Pass 6 收口）。resume 還原到原 variant + position（non-looping stream 安全 seek）。
- **`_audio_unlocked` flag 不受 SUSPENDED 影響**（正交雙軸）→ 杜絕「routed to SUSPENDED 後 unlock 被吞 → 永久靜音」。
- **suspend duck-kill**：kill duck Tween + Music bus hard-set `base_music_db`，但 `_active_ducks` dict **唔清**（保留 handles）；resume 由 `_compute_duck_target(_active_ducks)` 重算 re-spawn。
- **`_paused_focus_low` × `_suspended_bgm_state` 獨立**：BOSS_ENCOUNTER 時 boss_theme 正播 / focus_low 已 paused；SUSPENDED → `_suspended_bgm_state`=boss_theme，`_paused_focus_low` 保留 focus_low。兩 field 各記各。

---

## Out of Scope

- Story 004: duck Tween primitive（呢度只 kill + resume re-spawn）
- Story 005: crossfade primitive
- Story 007: unlock flag（呢度只驗 SUSPENDED 唔覆蓋 flag）
- Story 006: focus_low boss-exit resume-from-position 主路徑（呢度只驗 suspend 期間 field 獨立性 + resume 後交回 006 路徑）

---

## QA Test Cases

*Integration — inject mock `_gsm`；`_handle_focus_change` 純函數直接 call。*

- **AC-14/14b**: suspend pause/resume + mid-crossfade — Given READY（或 A→B crossfade）+ GSM→SUSPENDED / Then pause all + crossfade tween invalid + `_suspended_bgm_state.variant_id` 記正確；resume → player.stream 還原。
- **AC-14c**: LOCKED×SUSPENDED — Given web unlocked==false + deferred A + SUSPENDED→resume / Then `_audio_unlocked` 仍 false + deferred==A；首 gesture → unlock，無永久靜音。
- **AC-24a**: focus pure fn — `_handle_focus_change(false)`→pause、`(true)`→resume（headless）。
- **AC-30**: bitmask dedup — GSM SUSPEND（pause once）→ focus_out（唔再 pause）→ GSM clear（唔 resume）→ focus_in（resume once）。斷言 pause/resume callback 各剛好一次。
- **AC-33**: suspend duck-kill — Given `_register_duck(−8)` active + SUSPENDED / Then duck tween invalid + bus dB==base + `_active_ducks` 含 handle；resume → target==−14。子: resume 前 release → resume target==base。
- **AC-34**: field independence — Given BOSS_ENCOUNTER + `_paused_focus_low={focus_low_v1,12.3}` + SUSPENDED / Then `_suspended_bgm_state.variant_id=="boss_theme"` 且 `_paused_focus_low` 不變；resume boss_theme；後 WORKOUT_ACTIVE → player.stream==focus_low_v1。
- **AC-24b**（ADVISORY）: OS notification wiring — 真機 playtest，headless 唔測。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio/test_suspend_resume_multisource.gd` — must exist and pass（AC-24b = ADVISORY playtest doc）（⚠️ GUT 只收 `test_*.gd` prefix — [[reference_gut_filename_convention]]）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 004 (duck tween) ✅, 005 (crossfade) ✅, 006 (GSM handling) ✅, 007 (`_audio_unlocked` flag) ✅
- Unlocks: None（suspend integration 收口）

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: AC-14/14b/14c/24a/24b/30/33/34 covered + local-verified
**Files**: `src/autoload/audio_manager.gd`（`_suspend_sources` bitmask + `_SUSPEND_GSM/OS/FOCUS` consts；`_set_suspend_source` first-entry-latch/last-exit；`_pause_audio` [kill duck+crossfade tween + Music hard-set base + finalize crossfade-to-target + record `_suspended_bgm_state` + stream_paused; `_active_ducks` RETAINED; `_audio_unlocked` UNTOUCHED]；`_resume_audio` [unpause + `_apply_duck` recompute]；`_handle_focus_change`；`_notification` OS/window wiring；`_bgm_position`；`_on_gsm_state_changed` SUSPENDED branch + `_paused_focus_low` recording；`_suspended_bgm_state`/`_paused_focus_low`/`_pause_fire_count`/`_resume_fire_count` members）· `tests/integration/audio/test_suspend_resume_multisource.gd`（8 tests）
**Test Evidence**: Integration — `test_suspend_resume_multisource.gd` ✅ **LOCAL GUT 8/8**（audio 60/60）。**Full gate 240 scripts / 1460 tests / 1459 pass / 1 pending(AC-37) / 0 fail** — no regression.
**Deviations / notes**: `_notification` real OS dispatch + Q7 real-device = ADVISORY (headless); logic verified via `_handle_focus_change`/`_notification` direct calls. `_audio_unlocked` orthogonal to SUSPENDED (LOCKED×SUSPENDED coexist — no permanent mute). `_active_ducks` retained on suspend, recomputed on resume. No out-of-scope files.
**Code Review**: Complete (/code-review APPROVED WITH SUGGESTIONS).
