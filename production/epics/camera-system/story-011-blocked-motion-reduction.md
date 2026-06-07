# Story 011: Motion Reduction Accessibility API(原 BLOCKED #22 — 已解鎖)

> **Epic**: Camera System
> **Status**: ✅ Complete(2026-06-07 — 由 #22 epic story 013 / G-CS-2 交付:`set_motion_reduction` setter + AC-27 silent no-op + dead-zone 0% hard-lock + smoothing policy + boot self-read `settings.reduce_camera_motion`(consumer-self-read,SettingsManager 措辭 erratum 已落 GDD L697);tests `tests/integration/camera/test_camera_motion_reduction.gd` 6/6 + AC-06a tripwire 反轉做 AC-06b presence + AC-21 scoped amendment;camera 48/48 green)
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: AC-06b + AC-27（`set_motion_reduction` API + behaviour — UI Requirements Q-V1 future contract）
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (State Machine Contract) — N/A formula; SettingsManager setter contract
**ADR Decision Summary**: `set_motion_reduction(enabled)` 由 SettingsManager autoload（pending #22 Character Screen GDD）call。enabled=true → Focal disabled（request_focal silent no-op，唔 push_warning — expected opt-out）+ Following `position_smoothing_enabled=false` + drag margins ALL 0.0（dead-zone 0% hard-lock — eliminates optical flow AND stroboscopic edge-crossing，vestibular-safe per Apple HIG Reduce Motion）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: BLOCKED — #22 Character Screen GDD + SettingsManager autoload contract 未 ratified。AC-06a（Story 001）明確 assert `set_motion_reduction` **唔可存在** 喺 VS-tier scope；本 story 加 6th method 係 post-#22。

---

## BLOCKED

> **BLOCKED: #22 Character Screen GDD + SettingsManager contract 未 ratified。**
>
> AC-06a（Story 001）current-scope assert `set_motion_reduction` 唔存在。本 story（AC-06b + AC-27）加 6th public method + 行為，**只可** 喺 #22 GDD authored + SettingsManager setter contract ratified 之後實作。在此之前唔好實作 — 否則 AC-06a surface-lock 會 fail。
>
> **Unblock 條件**：#22 Character Screen GDD 寫成 + SettingsManager autoload + `/ux-design` motion-reduction toggle spec（`design/ux/character-screen-accessibility.md`）。

---

## Acceptance Criteria

*From GDD Section H — post-#22 GDD gated:*

- [ ] **AC-06b** — #22 GDD authored 後，`set_motion_reduction(enabled: bool)` 作為 6th public method 存在（extend AC-06a surface test）。
- [ ] **AC-27** — `set_motion_reduction(true)` 後 `request_focal()` during BOSS_ENCOUNTER → silent no-op（NOT push_warning — expected opt-out）；Following：`position_smoothing_enabled=false` + 全 drag margin = 0.0（dead-zone 0% hard-lock，camera always centred，no motion — eliminates optical flow AND stroboscopic edge-crossing）。

---

## Implementation Notes

*Blocked — do not implement until #22 GDD + SettingsManager contract ratified.*

- `set_motion_reduction(enabled)`：store `_motion_reduction`；enabled → `_camera.position_smoothing_enabled=false` + 全 drag margin 0.0；disabled → restore defaults（smoothing true，8%×12%）。
- `request_focal` 入口：`if _motion_reduction: return`（silent no-op，唔 counter，唔 warning — expected user opt-out per Q-V1）。
- mirror #6 ScreenEffects `set_motion_intensity` SettingsManager setter pattern。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 001 AC-06a: current-scope surface（`set_motion_reduction` absent）
- #22 Character Screen GDD: toggle UI surface（`design/ux/character-screen-accessibility.md`）

---

## QA Test Cases

*Post-#22 GDD — Integration. BLOCKED until SettingsManager contract ratified.*

- **AC-06b**: `has_method("set_motion_reduction") == true`（extend AC-06a；post-#22）
- **AC-27**: `set_motion_reduction(true)` → `request_focal()` during BOSS_ENCOUNTER silent no-op（no counter, no warning）；Following `position_smoothing_enabled==false` + 全 drag margin==0.0（hard-lock）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/camera/test_camera_motion_reduction.gd`（post-#22 GDD）

**Status**: [ ] BLOCKED — not startable until #22 Character Screen GDD + SettingsManager contract ratified

---

## Dependencies

- Depends on: Story 001（API surface）+ **#22 Character Screen GDD + SettingsManager autoload (external blocker)**
- Unlocks: #22 accessibility panel（Camera motion-reduction toggle）
