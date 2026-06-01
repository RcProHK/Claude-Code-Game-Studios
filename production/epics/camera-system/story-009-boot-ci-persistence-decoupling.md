# Story 009: Boot + GSM Subscription + CI Lint + Persistence Ban + ScreenEffects Decoupling

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-camera-012`, `TR-camera-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**) primary; ADR-0006 Contract 6 secondary
**ADR Decision Summary**: `_ready` 用 `connect_for_initial_state`（NOT direct .connect，ADR-0006 C6）。Persistence ban（Rule 14 — 無 PersistenceLayer/FileAccess）。CI lint `check_camera_callers.gd`（ban `Camera2D.position=`/`zoom=`/`make_current()`/`get_viewport().get_camera_2d()`，owner exempt）。解耦 ScreenEffects — Camera 永不寫 `Camera2D.offset`（debug runtime guard EC-24）。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: CI lint test = inline RegEx + comment-skip + violation/clean/real-source 三段（mirror `test_particle_ci_lint.gd`）。EC-24 debug guard：`if _debug_build_override（or OS.is_debug_build()）: if _camera.offset != Vector2.ZERO: push_error` — **NOT assert()**（crashes GUT）。owner-exempt：`camera_controller.gd` 可 mutate position/zoom。

**Control Manifest Rules (this layer — Foundation)**:
- Required: `connect_for_initial_state`；persists nothing；Camera2D.offset always ZERO（owned by #6）
- Forbidden: `Camera2D.position/zoom/make_current/get_viewport().get_camera_2d()` outside owner；PersistenceLayer access；`.bind()` on connect_for_initial_state
- Guardrail: zero ScreenEffects coupling

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-21** [Rule 14] — `camera_controller.gd` 無 `PersistenceLayer` / `FileAccess` / `.read(` / `.write(`（static scan）；hard reload → fresh Booting，無 persisted recovery。
- [ ] **AC-24** [ADR-0006 C6] — `_ready` 用 `connect_for_initial_state`（NOT direct .connect to GSM signals）；stub spy connect count ≥1 + raw_connect 0。
- [ ] **AC-25** [Falsifiable #4] — ScreenEffects shake active → `_camera.offset == Vector2.ZERO` every `update()` frame（Camera 從不寫 offset）。
- [ ] **AC-28** [Rule 13 CI] — `check_camera_callers.gd`：violation fixture（`Camera2D.position=`/`zoom=`/`make_current()`/`get_viewport().get_camera_2d()`）→ matches；clean → 0；real source（owner-exempt）→ 0。
- [ ] **AC-29** [EC-24 debug guard] — debug build inject `_camera.offset=Vector2(1,0)` → next `update()` → push_error + `_offset_violation_count++`；release（override false）→ guard 唔 fire。

---

## Implementation Notes

*Derived from ADR-0001 + ADR-0006 + GDD Rule 13/14 / EC-24:*

- `_ready`：`_gsm = GameStateMachine if null`；`_gsm.connect_for_initial_state(_on_gsm_state_changed)`（NO .bind）。process_mode PAUSABLE（default）。
- Persistence ban：無 `_persistence`，無 save/load，無 `user://`，無 FileAccess。
- 新 CI lint `tools/ci/check_camera_callers.gd`（mirror `check_particle_callers.gd`）：scan src/ outside `camera_controller.gd`（owner exempt）；4 patterns（`Camera2D\.[^.]*\.position\s*=`、`Camera2D\.[^.]*\.zoom\s*=`、`\.make_current\s*\(`、`get_viewport\(\)\.get_camera_2d\(\)`）→ exit 1。注意：`Camera2D.offset` 唔喺呢個 lint（#6 ScreenEffects 個 lint own）；`limit_*` 唔 ban（scene-direct Rule 10）。
- EC-24 runtime guard（`update` 尾）：`if (_debug_build_override if _debug_build_override != null else OS.is_debug_build()): if _camera.offset != Vector2.ZERO: push_error(...) + _offset_violation_count += 1`（exact equality，NOT assert）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 006-007: GSM handler 行為（呢度只 wire subscription + verify）
- Story 012: FR-3 caller-gating CI（`check_focal_caller_states.gd`）— RATIFICATION-GATED

---

## QA Test Cases

> **Seams**: CI lint inline RegEx（const pattern 對齊 lint script）+ fixtures violation/clean；`MockGSM` connect spy（connect_for_initial_state_count + raw_connect_count）；`_debug_build_override`；`_offset_violation_count`；`func update(delta)`。

- **AC-21**: persistence ban（static scan）
  - When: read `camera_controller.gd` source；scan `PersistenceLayer`/`FileAccess`/`\.read\(`/`\.write\(`
  - Then: 0 call-site matches（regex on call-sites 避免 doc-comment false positive）
  - Edge: FileAccess.open source-as-text 喺 test 係 meta-test（allowed — ban 係 camera **runtime** 用 persistence，唔係 test 讀 file）

- **AC-24**: connect_for_initial_state（spy）
  - Given: `MockGSM` spy（connect_for_initial_state_count + raw_connect_count）injected before add_child
  - When: add_child_autofree boots SUT
  - Then: `connect_for_initial_state_count >= 1`；`raw_connect_count == 0`
  - Edge: prefer spy（behavioral）over source regex（backup）

- **AC-25**: ScreenEffects decoupling
  - Given: Following；ScreenEffects shake active（或 simulate）
  - When: `update(1/60)` × ~12 frames
  - Then: `_camera.offset == Vector2.ZERO` EVERY frame（assert inside loop）
  - Edge: camera 永不寫 offset（#6 走 shader uniform）；per-frame assert

- **AC-28**: CI lint（fixtures + real source）
  - Fixtures: `tests/fixtures/camera_callers_violation.gd`（`Camera2D.position=`/`zoom=`/`make_current()`/`get_viewport().get_camera_2d()` 各一）；`camera_callers_clean.gd`（API calls + commented banned）
  - Then: violation matches==4；clean==0；real `camera_controller.gd`==0（owner exempt — position/zoom mutation legal）
  - Edge: 4 forbidden forms 各別測；comment-skip；owner-exemption（real file 唔 flag）

- **AC-29**: debug offset guard
  - Given: `_debug_build_override=true`；`_camera.offset=Vector2(1,0)`
  - When: `update(1/60)`
  - Then: push_error fired + `_offset_violation_count==1`
  - And release: `_debug_build_override=false` → guard 唔 fire（count==0）
  - Edge: mirror StatSystem debug/release seam；null override defers OS.is_debug_build()；after_each reset override null。Assert counter（唔 override push_error）。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/static/test_camera_ci_lint.gd`（AC-28）+ `tests/integration/camera/test_camera_gsm_subscription.gd`（AC-24,25）+ `tests/unit/camera/test_no_persistence.gd`（AC-21）+ `tests/unit/camera/test_camera_offset_guard.gd`（AC-29）
- `tools/ci/check_camera_callers.gd`（exists — verify covers 4 patterns）+ `tests/fixtures/camera_callers_{violation,clean}.gd`
- `tests/static/test_camera_autoload_position.gd`（pos 13 after particle 12, before ScreenEffects 14）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001-008（boot wires full surface）、**#1 GameStateMachine (Complete)**
- Unlocks: epic close-out；Story 012（FR-3 caller-gating CI extends）
