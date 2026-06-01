# Story 002: Input Validation + Parameter Guards

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-camera-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: `request_focal(target_position, duration, zoom_level)` 第一步 `is_finite` validate（NaN/±INF reject + push_error + counter）。over-limit 係 valid-but-clamped（duration→MAX_FOCAL_DURATION=10.0、zoom→FOCAL_ZOOM_CAP=4.0）+ push_warning，唔 reject。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 區分 reject（non-finite，counter++）vs clamp（over-limit，warn 唔 counter）。Vector2 NaN check：任一 component non-finite → reject。

**Control Manifest Rules (this layer — Foundation)**:
- Required: `is_finite` check 先於 clamp
- Forbidden: silent-clamp non-finite（會 mask caller bug）
- Guardrail: Foundation 唔 throw — fail-loud reject

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-02** — `request_focal(Vector2(NaN,0))` / `(target, duration=NaN)` / `(target, zoom=±INF)` → `is_finite` fail → reject + push_error + `_rejected_calls += 1`；無 state change（EC-02）。
- [ ] **AC-03** — `request_focal(target, duration=15.0, zoom=5.0)` → duration clamp `MAX_FOCAL_DURATION=10.0` + zoom clamp `FOCAL_ZOOM_CAP=4.0`（tween 前）；兩個 clamp emit push_warning（EC-03/EC-05）。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 4 / EC-02/03/04/05:*

- `request_focal` 入口：`_is_finite_vec2(target_position) and is_finite(duration) and is_finite(zoom_level)` → 否則 push_error + `_rejected_calls += 1` + return。
- clamp（after finite + after gating Story 006）：`duration = clampf(duration, 0.1, MAX_FOCAL_DURATION)`（EC-03，<0.1 floor 亦 clamp）；`zoom_level <= 0` → push_error reject（EC-04 division-by-zero）；`zoom_level = min(zoom_level, FOCAL_ZOOM_CAP)`（EC-05）；over-limit 各 emit push_warning（**唔** increment `_rejected_calls`）。
- 暴露 resolved duration/zoom（e.g. tween 前 store）令 test 讀到 clamped value 唔使量 tween timing。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 006: GSM state gating（request_focal 喺 gating 之前 validate；test 設 BOSS_ENCOUNTER 隔離 finite check）
- Story 004: tween execution（呢度只 validate + clamp params）

---

## QA Test Cases

> **Seams**: `_gsm.current_state` 設 BOSS_ENCOUNTER 隔離 finite-check from gating；`_rejected_calls` readable（before_each reset）；resolved duration/zoom 暴露。push_error/warning 用 counter/value proxy（唔 override）。

- **AC-02**: non-finite reject
  - Given: Following（camera+target registered）；`_gsm.current_state = BOSS_ENCOUNTER`（隔離 finite from gating）
  - When: 4 calls — `request_focal(Vector2(NAN,0))`、`(valid_pos, duration=NAN)`、`(valid_pos, zoom=INF)`、`(valid_pos, zoom=-INF)`
  - Then: 每個 return false；無 focal tween（state Following）；`_rejected_calls` 每 bad call +1（final==4）；push_error fired
  - Edge: NaN-in-position、NaN-in-duration、+INF/-INF-in-zoom 分開測；`Vector2(NAN,0)` 任一 component non-finite → reject

- **AC-03**: over-limit clamp + warn（唔 reject）
  - Given: Following；`_gsm.current_state = BOSS_ENCOUNTER`
  - When: `request_focal(target, duration=15.0, zoom=5.0)`
  - Then: call SUCCEEDS（clamp 唔 reject）；effective duration==10.0；effective zoom==4.0；push_warning 兩個 clamp
  - Edge: 對比 AC-02（non-finite reject vs over-limit clamp）；boundary duration==10.0 / zoom==4.0 唔 warn。讀 resolved value 唔量 tween timing。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/camera/test_focal_input_validation.gd` — must exist and pass（AC-02, AC-03）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（request_focal API surface）
- Unlocks: Story 004（focal tween 假設 validated params）
