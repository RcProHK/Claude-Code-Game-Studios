# Story 008: Lifecycle — target-lost + Viewport Resize + Focal-clamp Signal

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-camera-001`, `TR-camera-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: follow target queue_free mid-frame → freeze + `camera_target_lost`（unified signal，debounced）。viewport resize → dead-zone world extents auto-recompute（Formula 5），no jolt（world-coord locked）。Focal target 超 `Camera2D.limit_*` → clamp + `focal_target_clamped(requested, clamped)` signal。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `is_instance_valid` guard in `update`；`camera_target_lost` debounced（多 frame 後 emit 一次）。viewport via `_viewport_size_override` seam（AC-28 ban `get_viewport().get_camera_2d()` 唔 ban `.size`，但 seam 令 test deterministic）。focal clamp：stub camera 唔做 engine-clamp，實作明確 clamp center 到 limit。

**Control Manifest Rules (this layer — Foundation)**:
- Required: target-lost unified signal（debounced）；viewport recompute；focal clamp signal
- Forbidden: per-frame signal spam；`get_viewport().get_camera_2d()`（CI banned）
- Guardrail: viewport resize 無 camera jolt（world-locked）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-22** [EC-16] — `_follow_target.queue_free()` mid-frame → next `update()` → `is_instance_valid` false → camera freeze at last pos + `camera_target_lost()` emit **exactly once**（second update 唔 re-emit — unified debounced）。
- [ ] **AC-23** [EC-14] — viewport size change mid-Following → dead-zone box world extents recompute next frame（Formula 5）；camera position UNCHANGED across resize（world-coord locked，no jolt）。
- [ ] **AC-26** [EC-23] — `_camera.limit_right=1024`，`request_focal(Vector2(5000,0), zoom=1.4)` during BOSS_ENCOUNTER → Focal completes，final position clamped to limit，`focal_target_clamped(requested=Vector2(5000,0), clamped=Vector2(1024,0))` emit exactly once。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 9/10 / EC-14/16/23 / Formula 5:*

- `update`：`if _follow_target != null and not is_instance_valid(_follow_target)` → freeze（keep last pos）+ `_follow_target=null` + `camera_target_lost.emit()` once（debounce: emit only on the null-transition，唔每 frame）。
- viewport recompute：dead-zone extents derived from `_viewport_size_override`（or `get_viewport_rect().size`）× margins / zoom；recompute each frame（or on resize）；camera world position invariant。
- focal target clamp：entry tween target x/y clamp to `[_camera.limit_left, limit_right]` etc.；if clamped != requested → `focal_target_clamped.emit(requested, clamped)` once。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003: dead-zone math（呢度只 viewport-resize recompute）
- Story 007: bfcache stale target（呢度 queue_free mid-frame，唔同 resume path）

---

## QA Test Cases

> **Seams**: `func update(delta)`；`_follow_target`（add_child_autofree，queue_free-able）；`_viewport_size_override`；`watch_signals(_sut)`；`get_signal_parameters`。

- **AC-22**: target-lost debounced
  - Given: Following + valid `_follow_target`；`watch_signals`；record `_camera.position`
  - When: `_follow_target.queue_free()`；await 1 frame（free completes）；`update(1/60)`
  - Then: 無 crash；`_camera.position == last`（frozen）；`camera_target_lost` emit_count==1；**second `update()` 唔 re-emit**（still 1）
  - Edge: "exactly once" across multiple post-loss frames（防 per-frame spam）

- **AC-23**: viewport resize no jolt
  - Given: Following，camera settled
  - When: set `_viewport_size_override` 新值（或 recompute entrypoint）；advance 1 frame
  - Then: dead-zone half-extents recompute（new != old）；`_camera.position` UNCHANGED across resize（world-locked）
  - Edge: shrink AND grow；camera world pos invariant

- **AC-26**: focal target clamp signal
  - Given: `_camera.limit_right=1024`；`_gsm.current_state=BOSS_ENCOUNTER`；`watch_signals`
  - When: `request_focal(Vector2(5000,0), zoom=1.4)`；advance focal to completion
  - Then: `focal_completed` emit；final position.x clamped to 1024；`focal_target_clamped` emit_count==1，params `[Vector2(5000,0), Vector2(1024,0)]`
  - Edge: requested WITHIN limits → NO clamp signal（emit_count==0）。測 clamped + unclamped 兩 path。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/camera/test_lifecycle_signals_clamp.gd` — must exist and pass（AC-22,23,26）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003（follow update loop）、Story 004（focal target for clamp）
- Unlocks: #26 AvatarRenderer（set_follow_target + camera_target_lost subscriber，pending GDD）
