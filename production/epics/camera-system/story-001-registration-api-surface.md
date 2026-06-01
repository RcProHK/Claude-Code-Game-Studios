# Story 001: Camera Registration + API Surface

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-camera-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**) primary; ADR-0006 Contract 6 secondary
**ADR Decision Summary**: CameraController autoload (pos 13) own 一個 Camera2D（scene-injected via `register_camera`）。Closed API：`register_camera` / `unregister_camera` / `set_follow_target` / `request_focal` / `clear_focal`。所有 `Camera2D.position/zoom/make_current` mutation 必須過此 autoload（CI enforced）。Foundation 唔 throw — invalid → reject + push_error。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 單 Camera2D model — double-register reject（preserve first）。null / freed Camera2D reject。State: Booting→Following on register + set_follow_target。`_camera` injectable duck-typed stub（test，唔係真 Camera2D node）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: closed API surface；single Camera2D via register_camera
- Forbidden: `Camera2D.position/zoom/make_current` mutation outside `camera_controller.gd`（CI: `check_camera_callers.gd`）
- Guardrail: Foundation 唔 throw — invalid input fail-loud（push_error）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-01** — `register_camera(valid Camera2D)` + `set_follow_target(avatar)` → state Booting→Following within 1 frame；`_follow_target` stored。
- [ ] **AC-04** — `register_camera(null)` / `register_camera(freed)` → reject + push_error；state remains Booting；`_camera` null（EC-19）。
- [ ] **AC-05** — second `register_camera()` → reject + push_error("already registered")；first Camera2D reference preserved（EC-20）。
- [ ] **AC-06a** — public methods 剛好 {register_camera, unregister_camera, set_follow_target, request_focal, clear_focal} + 3 signals {focal_completed, camera_target_lost, focal_target_clamped}；`set_motion_reduction` **唔可存在**（VS-tier scope；post-#22 = Story 011）。

---

## Implementation Notes

*Derived from ADR-0001 + ADR-0006 + GDD Rule 1 / EC-19/EC-20:*

- LifecycleState enum {BOOTING(0), FOLLOWING, FOCAL, SUSPENDED}（ADR-0007 Family A，0=BOOTING safe default）。
- `register_camera(cam)`：null / `not is_instance_valid(cam)` → push_error + return（state Booting）；already registered → push_error("already registered; first=%s second=%s") + return（preserve first）；else store `_camera` = cam。
- `set_follow_target(node)`：store `_follow_target`；若 `_camera` registered → Booting→Following。
- **DI seams（untyped）**: `_camera`（duck-typed stub: position/zoom/offset/limit_*/position_smoothing_enabled/speed）、`_gsm`、`_follow_target`、`_debug_build_override`、`_viewport_size_override`、`func update(delta)` public seam（`_process` delegates — deterministic frame-step）。Counters: `_rejected_calls`/`_focal_reentry_dropped_count`/`_focal_gating_rejected_count`/`_offset_violation_count`。`_cached_target_path: NodePath`。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: request_focal input validation；Story 003: follow math；Story 004-005: focal tweens
- Story 009: GSM subscription wiring + CI lint + persistence ban
- Story 011: `set_motion_reduction`（BLOCKED #22）

---

## QA Test Cases

> **Cross-cutting seams（programmer 必須 expose，stories 001-009 DoD）**: `func update(delta)` public（`_process` delegates — GUT 唔靠真 _process）；`_camera` duck-typed stub（position/zoom/offset/limit_*/smoothing）；`_gsm` stub（current_state:int + connect_for_initial_state）；`_follow_target`；`_debug_build_override`；`_viewport_size_override`；counters。SUT load `const SE := preload(...)`（autoload 無 class_name）。**唔 override native method**（phantom-pass guard）— stub 用 plain RefCounted duck-typed properties。

- **AC-01**: register + follow → Following
  - Given: fresh controller（Booting）；valid Camera2D stub；Node2D avatar（add_child_autofree）
  - When: `register_camera(stub)`；`set_follow_target(avatar)`；advance 1 frame（`update(1.0/60.0)` 或 await process_frame）
  - Then: state==Following；`_camera` is stub（identity）；`_follow_target` is avatar
  - Edge: transition within ONE frame（唔 deferred）

- **AC-04**: invalid register rejected
  - Given: fresh（Booting）。freed case：stub 然後 free（is_instance_valid false）
  - When: `register_camera(null)`；分開 `register_camera(freed)`
  - Then: 兩者 reject；state Booting；`_camera` null；push_error fired
  - Edge: null AND freed-but-non-null 分開測。Assert observable（state + _camera null），唔 override push_error。

- **AC-05**: double-register preserves first
  - Given: camera_a registered
  - When: `register_camera(camera_b)`
  - Then: reject；`_camera` STILL camera_a；push_error "already registered"
  - Edge: first reference 真係 preserved（唔係 overwrite then rollback）

- **AC-06a**: API surface lock
  - When: introspect `get_method_list()` / `has_method()` + `get_signal_list()`
  - Then: has_method true for 5 public methods；has_signal true for 3 signals；`has_method("set_motion_reduction") == FALSE`（hard surface-lock guard）
  - Edge: filter script-defined methods（skip built-in Node methods）；exact name match

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/camera/test_camera_registration_api.gd` — must exist and pass（AC-01,04,05,06a）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（foundational — 第一個 camera story）
- Unlocks: Story 002-009（全部建喺 API surface 上）
