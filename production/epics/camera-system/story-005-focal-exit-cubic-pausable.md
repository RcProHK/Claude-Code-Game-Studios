# Story 005: Focal Exit Tween + Cubic Ease + PAUSABLE Freeze

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-camera-006`, `TR-camera-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: Focal exit = cubic ease-in-out 0.5s（symmetric breath-out，Formula 3：f(0.5)=0.5 exact）。所有 Focal tween `TWEEN_PROCESS_PAUSABLE` — `get_tree().paused=true`（#6 hit_pause）期間 freeze，resume 無 phase jump。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `cubic_ease_in_out_value` pure static func（test 唔使 tween）。PAUSABLE freeze test 需真 Tween + SceneTree（GUT headless 真實）。`after_each` 必須 restore `get_tree().paused=false`。tween 用 `_camera.create_tween()`（inherit PAUSABLE）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: exit cubic ease-in-out；Focal tween PROCESS_MODE_PAUSABLE
- Forbidden: premature `focal_completed` emit（paused 期間）
- Guardrail: paused → tween freeze，resume 同 interpolation point

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-12** [AC-D3] — `cubic_ease_in_out_value(0.5, 0, 1) == 0.5`（±1e-6，Formula 3 symmetric midpoint）。
- [ ] **AC-14** [Rule 12 / DNF freeze] — Focal entry tween running，`get_tree().paused=true` → tween freeze（PAUSABLE）；`paused=false` → resume 同 interpolation point（無 phase jump）；`focal_completed` 唔 premature emit。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 7/12 / Formula 3:*

- `static func cubic_ease_in_out_value(t, start, end)`: `f(t) = 4t³ if t<0.5 else 1-pow(-2t+2,3)/2`；`start + (end-start) × f(t)`。
- exit tween（`_on_focal_complete`）：`_camera.create_tween().set_process_mode(TWEEN_PROCESS_PAUSABLE)`；position+zoom EASE_IN_OUT TRANS_CUBIC over `FOCAL_EXIT_DURATION`；chain `_on_focal_exit_complete` → state Following + re-enable smoothing。`focal_completed.emit` 喺 exit tween **開始之前**（caller chain via signal）。
- Camera autoload process_mode = PAUSABLE（default，唔 override — Rule 12）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 004: entry tween + quart；Story 006: gating + re-entry
- Story 007: Suspended kill（覆蓋 PAUSABLE freeze）

---

## QA Test Cases

> **Seams**: `cubic_ease_in_out_value` pure static（AC-12 零 tween）；`watch_signals(_sut)`；tween 用 `_camera.create_tween()`（PAUSABLE）。**CRITICAL**: `after_each` restore `get_tree().paused=false`。AC-14 係唯一真正需要 real Tween/SceneTree 嘅 focal test。

- **AC-12**: cubic symmetric（pure static）
  - When: `v = cubic_ease_in_out_value(0.5, 0.0, 1.0)`
  - Then: `assert_almost_eq(v, 0.5, 1e-6)`
  - Edge: t=0→0.0；t=1→1.0；symmetry `f(0.25)+f(0.75) ≈ 1.0`

- **AC-14**: PAUSABLE freeze + resume
  - Given: `request_focal` started（entry tween live PAUSABLE，_sut-owned）；`watch_signals(_sut)`
  - When: advance partial frames；`get_tree().paused=true`；advance more；`paused=false`；advance to completion
  - Then: paused 期間 interpolated value 唔前進（sample `_camera.zoom` before/after paused window → equal）；`focal_completed` mid-pause emit_count==0；resume+complete → `focal_completed` exactly once
  - Edge: resume 由同一 interpolation point 繼續（無 jump/restart）。after_each restore paused=false。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/camera/test_focal_exit_cubic.gd`（AC-12）+ `tests/integration/camera/test_camera_pause.gd`（AC-14）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004（entry tween → exit tween chain）
- Unlocks: Story 007（Suspended kill 覆蓋 PAUSABLE）
