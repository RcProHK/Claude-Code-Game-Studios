# Story 004: Focal Entry Tween + Quart Ease + Defaults + Invariants

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-camera-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: Focal entry = quart ease-out tween（`FOCAL_ENTRY_DURATION=0.6s`、`FOCAL_ZOOM_DEFAULT=1.4x`）。Formula 2 front-load：t=0.3 → ≥75% distance（decisive invitation）。Cinematographic invariants：entry > exit；zoom_default ≤ zoom_cap。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `quart_ease_out_value` 抽 **pure static func**（test 唔使 tween）。AC-D2（GDD line 473）authoritative threshold = `≥ 75.0`（描述性「76%」係 rounded；`1-(0.7)^4=0.7599=75.99`）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: ease funcs pure static（testable 無 tween）；default params from Section G constants
- Forbidden: ease curve runtime-change（compile-time locked TRANS_QUART/EASE_OUT）
- Guardrail: entry > exit（cinematographic）；zoom_default ≤ zoom_cap

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-11** [AC-D2 / Pillar 3] — `quart_ease_out_value(0.3, 0, 100) ≥ 75.0`（Formula 2 front-load，decisive invitation；GDD AC-D2 authoritative `≥75.0`）。
- [ ] **AC-13** [Rule 11] — `request_focal(target)` 無 explicit params → duration=`FOCAL_ENTRY_DURATION(0.6)`, zoom=`FOCAL_ZOOM_DEFAULT(1.4)`；exit duration=`FOCAL_EXIT_DURATION(0.5)`, return `DEFAULT_ZOOM(1.0,1.0)`。
- [ ] **AC-15** [AC-G2] — `FOCAL_ENTRY_DURATION > FOCAL_EXIT_DURATION`（0.6 > 0.5）。
- [ ] **AC-31** [AC-G3] — `FOCAL_ZOOM_DEFAULT(1.4) ≤ FOCAL_ZOOM_CAP(4.0)`。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 6/11 / Formula 2:*

- `static func quart_ease_out_value(t, start, end) -> float`: `start + (end-start) × (1 - pow(1-t, 4))`。
- `request_focal` default params：`duration=0.6`、`zoom_level=1.4`（Rule 6 signature defaults）。entry tween：`_camera.create_tween().set_process_mode(TWEEN_PROCESS_PAUSABLE)`（Rule 12，Story 005）；position+zoom EASE_OUT TRANS_QUART over duration。
- Constants: `FOCAL_ENTRY_DURATION=0.6`、`FOCAL_EXIT_DURATION=0.5`、`FOCAL_ZOOM_DEFAULT=1.4`、`FOCAL_ZOOM_CAP=4.0`、`DEFAULT_ZOOM=Vector2(1,1)`。
- 暴露 resolved entry/exit duration + target zoom（test 讀 const 唔量 timing）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: param validation/clamp；Story 005: exit tween + cubic + PAUSABLE
- Story 006: gating（呢度假設 gate passed，BOSS_ENCOUNTER）

---

## QA Test Cases

> **Seams**: `quart_ease_out_value` pure static（AC-11 零 tween）；resolved duration/zoom 暴露（AC-13 讀 field 唔量 timing）；`_gsm.current_state=BOSS_ENCOUNTER` 令 request_focal 過 gating。

- **AC-11**: quart front-load（pure static）
  - When: `v = quart_ease_out_value(0.3, 0.0, 100.0)`
  - Then: `assert_true(v >= 75.0)`（GDD AC-D2 authoritative；`0.7599→75.99 ≥ 75.0 ✓`）
  - Edge: t=0→start(0.0)；t=1→end(100.0) exact。**Note**: 描述性「76%」係 rounded，AC-D2 binding threshold 係 75.0 — 無 spec issue。

- **AC-13**: default params
  - Given: Following；`_gsm.current_state=BOSS_ENCOUNTER`
  - When: `request_focal(target)`（無 explicit duration/zoom）然後 `clear_focal()`
  - Then: entry duration==0.6；target zoom==1.4；exit duration==0.5；final zoom==Vector2(1,1)
  - Edge: assert constants 直接（讀 resolved field，唔量 wall-clock）

- **AC-15**: entry > exit
  - Then: `assert_true(FOCAL_ENTRY_DURATION > FOCAL_EXIT_DURATION)`（0.6 > 0.5）

- **AC-31**: zoom_default ≤ cap
  - Then: `assert_true(FOCAL_ZOOM_DEFAULT <= FOCAL_ZOOM_CAP)`（1.4 ≤ 4.0）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/camera/test_focal_entry_quart.gd` — must exist and pass（AC-11,13,15,31）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（request_focal）、Story 003（Focal disable follow smoothing）
- Unlocks: Story 005（exit tween）、Story 006（gating）
