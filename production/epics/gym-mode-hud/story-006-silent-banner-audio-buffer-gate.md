# Story 006: Silent-mode banner + audio-buffer gate + Formula 3

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-04

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (CR-6/7/8 banner, F3, EC-S2/S5/S8) · **UX**: P-09 single-tap
**Requirement**: GDD AC-CR-6 / AC-CR-7 / AC-F3 / AC-U-4 / AC-EC-S5 (no TR-ID — cite GDD AC-ID)

**ADR Governing Implementation**: ADR-0002 GymSys Integration (secondary, audio unlock context) · ADR-0001 (budget — banner pulse animation)
**ADR Decision Summary**: silent-mode banner 只 gate **audio buffer flush**,絕不 gate workout 計數/EXP 視覺(B1 decouple);banner 脈動係正當持續 animation(CR-3 poll 禁令豁免)。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: MEDIUM
**Engine Notes**: web audio pre-gesture LOCKED,`AudioManager.is_audio_unlocked()`/`audio_unlocked`;banner pulse = looping tween(`set_loops()`),`audio_unlocked` 即 `kill()`;`focus_mode=FOCUS_NONE`(one-tap touch,無 hover)。

**Control Manifest Rules**:
- Required: banner gate 只 gate audio buffer(唔 gate 計數/視覺);零祈使句(witness register)
- Forbidden: banner hold workout 計數;banner 全屏遮蔽
- Guardrail: banner alpha 脈動 only(非 scale),不搶餘光;touch target ≥44×44

---

## Acceptance Criteria

- [ ] **AC-CR-6**:`is_audio_unlocked()==false` 且離 Booting → banner 顯示==true;`==true`(desktop)→ ==false(永不出現)。
- [ ] **AC-CR-7**:banner 顯示中首 tap → `audio_unlocked` → one-shot dismiss、`banner_dismissed_this_session==true`;之後 resume 重評 → 不重現(即使再 LOCKED)。
- [ ] **AC-F3**:`base=0.7,amp=0.1,period=2.0`,`t=0.5`→≈0.8(峰,±0.001);`t=1.5`→≈0.7;`t` 極大 `fmod`→∈[base,base+amp];`pulse_period=0`→`P=max(0,0.5)=0.5` 不 NaN 不 livelock;`base=0.95,amp=0.15`→clamp ≤1.0;`audio_unlocked`→pulse `kill()`。
- [ ] **AC-U-4**:`banner.focus_mode==FOCUS_NONE`;`reduce_motion==true`→banner pulse 靜止(`banner_pulse_amp`→0 master override)。
- [ ] **AC-EC-S5(fallback #33)**:#33 未 implement,banner tap → 走「直接 tap→unlock」、banner-unlock tap 永遠豁免 `is_input_permitted`。

---

## Implementation Notes

- F3:`banner_alpha = clamp(base_alpha + pulse_amp*(0.5+0.5*sin(2π*fmod(t,P)/P)), 0,1)`,`P=max(pulse_period, MIN_PULSE_PERIOD=0.5)`;`fmod`+`max` 內嵌 body(div-0 + 長 session 精度 guard)。
- banner render 由 `is_audio_unlocked()==false && !banner_dismissed_this_session` 決定(非獨立 state,任何 non-Suspended/non-Booting state 都可疊;SM-A)。
- `banner_dismissed_this_session` = **in-memory non-persisted**(resume 唔重彈,新 session re-evaluate)。
- banner = bottom-center toast,non-fullscreen,不 push Z1(layout isolation,Story 011 / UX spec)。
- audio buffer gate:`is_audio_unlocked()` 只做 buffer flush ready signal(實際 buffer/flush 喺 Story 007);本 story 立 banner UI + unlock 訂閱 + dismiss。

---

## Out of Scope

- Story 007:audio buffer policy / flush / WorkoutAudioAdapter SFX(本 story 只 banner UI + unlock gesture)。
- Story 010:SUSPENDED 期 banner 復現 reconcile(EC-S2 — 本 story 立 dismiss flag,reconcile 喺 010)。
- Story 011:banner touch-target evidence (AC-UX-8) + copy walkthrough (AC-U-1)。

---

## QA Test Cases

- **AC-CR-6**:Given is_audio_unlocked F/T 離 Booting;Then banner T/F;Edge: desktop 開機 unlocked → 永不出現(EC-S8)。
- **AC-CR-7**:Given banner 顯示;When 首 tap → audio_unlocked;Then dismiss + flag T;再 resume LOCKED → 不重現。
- **AC-F3**:Given F3 純 func;When t=0.5/1.5/大/period=0/base=0.95;Then 0.8/0.7/∈range/不NaN/≤1.0;When audio_unlocked;Then tween kill。
- **AC-U-4**:Given banner;Then focus_mode==FOCUS_NONE;reduce_motion T → amp 0。
- **AC-EC-S5**:Given #33 未 impl;When banner tap;Then 直接 unlock 豁免 gating。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/gym_mode_hud/test_silent_banner_gate.gd` — must exist and pass (F3 portion may live in unit)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scaffold + BannerGate branch) · #4 Audio (merged)
- Unlocks: Story 007 (audio buffer flush on unlock) · Story 010 (banner reconcile)

---

## Completion Notes
**Completed**: 2026-06-04
**Criteria**: 5/5 passing (AC-CR-6 / AC-CR-7 / AC-F3 / AC-U-4 / AC-EC-S5); focus_mode actual-node binding deferred to .tscn
**Deviations**: `focus_mode==FOCUS_NONE` 以 contract const `BANNER_FOCUS_MODE`(=Control.FOCUS_NONE 0) + `get_banner_focus_mode()` 提供 — actual banner Control node 喺 HUD `.tscn`(未建,Story 011)apply。banner tap unlock 用 `_audio_manager._do_unlock()`(cross-call，#4 audio_manager.gd L215 comment 明確邀請「#20 banner pressed = canonical path」)。
**Test Evidence**: Integration — `tests/integration/gym_mode_hud/test_silent_banner_gate.gd` (14 test functions, 14/14 pass; gym integration 3 scripts 40 tests). Full gate 241 scripts / 1486 pass / 0 fail / 1 pending.
**Code Review**: Complete — APPROVED (F3 inline fmod+max guard、banner 只 gate audio buffer B1 decouple、dismiss in-memory 不重現、tap 豁免 #33 + canonical _do_unlock、reduce_motion amp override；對 GDD CR-6/7/F3 + ADR-0002)
**Files**: `src/ui/gym_mode_hud/gym_mode_hud.gd` (banner const + dismiss flag + should_show_banner + _on_banner_tapped + compute_banner_alpha F3), `tests/integration/gym_mode_hud/test_silent_banner_gate.gd` (created)
