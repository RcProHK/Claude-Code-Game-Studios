# Story 009: SettingsManager Propagation Contract

> **Epic**: Screen Effects System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (State Machine Contract) — N/A formula; this is the SettingsManager setter-propagation contract
**ADR Decision Summary**: SettingsManager autoload（pending #22）call `ScreenEffects.set_motion_intensity(scale)` 喺 boot（load saved a11y value）+ user 改 slider 時。ScreenEffects 唔 read PersistenceLayer 直接（Rule 16）。propagation 必須即時 — set 之後下一 `shake()` 即用新 multiplier。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_settings` untyped DI seam（typed Node fails compile-time member check）。confirm propagation 方向（push signal `settings_changed` → handler，定 direct setter call）before implementing — GDD Interaction #3 寫 setter call pattern（boot + on-change）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: `set_motion_intensity` 即時生效於下一 shake（input-side composition）
- Forbidden: ScreenEffects read PersistenceLayer 直接（Rule 16）
- Guardrail: motion_intensity 唔影響 hit_pause（time perturbation ≠ vestibular）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-24** — SettingsManager call `set_motion_intensity(0.5)` → `_motion_intensity = 0.5` stored；下一 `shake(0.6, ...)` 用 0.5 multiplier（Formula 2：`trauma += 0.6 × 0.5 = 0.3`）。

---

## Implementation Notes

*Derived from ADR-0006 + GDD Interaction #3 / Rule 3:*

- `set_motion_intensity(scale)`（已喺 Story 001/003）係 SettingsManager 嘅 entry。呢個 story 驗 end-to-end propagation：setter store → 下一 shake 用新值（Formula 2 input-side multiply）。
- propagation 即時（無 frame delay）。
- 若 GDD 後續 confirm signal-driven（`settings_changed` → `_on_settings_changed` → setter），wire handler；否則 direct setter（GDD Interaction #3 寫 setter call pattern）。default：direct setter（per GDD）。
- `_settings` untyped seam（stub 注入測 propagation）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 001: `set_motion_intensity` validation（clamp/NaN）
- Story 003: motion=0 bypass（AC-08）+ Formula 2 combiner math
- #22 Character Screen GDD: slider UI chrome / placement（呢度只 backend setter contract）

---

## QA Test Cases

> **Precondition seams**: `_settings` untyped DI stub；`_motion_intensity`/`_trauma` readable。confirm wiring 方向（push signal vs direct setter）before writing — default direct setter（GDD Interaction #3）。

- **AC-24**: setter propagation live
  - Given: SUT ACTIVE；`_motion_intensity=1.0`；`_trauma=0`；stub `_settings` 注入
  - When: `_sut.set_motion_intensity(0.5)`（或 stub emit `settings_changed` → handler call setter）
  - Then: `assert_almost_eq(_motion_intensity, 0.5, 0.0001)`（stored）
  - When2: `_sut.shake(0.6, 0.08)`
  - Then2: `assert_almost_eq(_trauma, 0.3, 0.0001)`（Formula 2：0.6 × 0.5 = 0.3 — propagation live）
  - Edge: `set_motion_intensity(0.0)` 然後 `shake(0.6)` → `_trauma==0`（full Reduce Motion；overlap AC-08 但呢度證 settings-driven path）。propagation 即時無 frame delay。Headless: stub via untyped `_settings`；若 signal-driven 就 emit stub signal 再驗 downstream。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/screen_effects/test_screen_effects_settings_propagation.gd` — must exist and pass（AC-24）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（`set_motion_intensity`）、Story 003（Formula 2 用 `_motion_intensity`）
- Unlocks: #22 Character Screen（SettingsManager → setter contract，pending GDD）
