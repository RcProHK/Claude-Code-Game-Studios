# Story 007: Suspended Cancel + bfcache Resume

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-camera-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**) primary; ADR-0006 Contract 6 secondary
**ADR Decision Summary**: GSM Suspended（覆蓋一切）→ kill all tweens + snap to current interpolated position + reset zoom DEFAULT + cache `_follow_target` NodePath + `reset_smoothing()`。Resume（非-Suspended）→ restore Following via `get_node_or_null(cached_path)`；stale → Booting + `camera_target_lost`。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Web Export bfcache — `TWEEN_PROCESS_PAUSABLE` 唔 auto-pause on browser visibilitychange；GSM SUSPENDED signal-driven kill-all 係唯一可靠路徑。snap-to-interpolated（唔 reset to default）避免 visible jolt。`reset_smoothing()` zero velocity 防 rubber-band。

**Control Manifest Rules (this layer — Foundation)**:
- Required: Suspended kill-all + cache NodePath；resume re-resolve
- Forbidden: rely on Tween auto-pause for Web Export suspend
- Guardrail: bfcache resume 無 half-zoomed Focal frame

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-17** [Rule 8 / Falsifiable #3] — Focal tween mid-flight（~300ms/600ms），GSM → SUSPENDED → tween kill immediately + Camera2D snap to current interpolated position（NOT default）+ zoom = DEFAULT_ZOOM + `_cached_target_path` saved + state==Suspended within 1 frame。
- [ ] **AC-18** [Rule 9 bfcache] — Suspended + valid `_cached_target_path`，GSM → IDLE → state Following + cached target resolved；stale path（freed）→ state Booting + `camera_target_lost()` emit。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 8/9 / EC-09/11:*

- `_on_gsm_state_changed`：new==SUSPENDED → kill `_active_tween`/`_exit_tween`（snap Camera2D to current interpolated pos — 唔 reset position to default，只 zoom = DEFAULT_ZOOM）；`_camera.position_smoothing_enabled=true`；`_camera.reset_smoothing()`；`_cached_target_path = _follow_target.get_path() if is_instance_valid else NodePath("")`；state=SUSPENDED。
- resume（from SUSPENDED，new != SUSPENDED）→ `_restore_from_suspend`：`resolved = get_node_or_null(_cached_target_path)`；resolved → `_follow_target=resolved`，`_camera.global_position=resolved.global_position`（snap before re-enable smoothing），`reset_smoothing()`，state=Following；stale → `_follow_target=null`，state=Booting，`camera_target_lost.emit()`。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 006: force-clear-to-Following（GSM exit to non-suspended focal-disallowed — 唔同 Suspended）
- Story 008: target-lost via queue_free（呢度 cover bfcache stale path）

---

## QA Test Cases

> **Seams**: `_gsm` stub + state-sync entrypoint；`_cached_target_path` inspect/seed；`watch_signals(_sut)`；live Node2D via add_child_autofree（NodePath resolves）。after_each restore paused。

- **AC-17**: Suspended kill + snap
  - Given: focal entry tween live advanced ~300ms（mid-interpolation）；valid `_follow_target`；record `_camera.position` pre-suspend
  - When: `_gsm.current_state=SUSPENDED`；invoke state-sync
  - Then: tween killed（next frame no further interpolation）；`_camera` snapped to CURRENT interpolated position（唔係 start/end）；`_camera.zoom==DEFAULT_ZOOM`；`_cached_target_path==_follow_target path`；state==Suspended
  - Edge: post-suspend +1 frame position == captured value（frozen，no drift）

- **AC-18**: resume restore（two cases）
  - Case A: Suspended，`_cached_target_path` → live Node2D；resume IDLE → state Following，`_follow_target` re-resolved（identity）
  - Case B: Suspended，cached path → freed node；resume IDLE → state Booting + `camera_target_lost` emit_count==1
  - Edge: 兩 branch 分開 test；Case B free node + remove from tree（`get_node_or_null` null）。use add_child_autofree for live node。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/camera/test_suspend_bfcache_resume.gd` — must exist and pass（AC-17, AC-18）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005（tweens to kill）、Story 006（GSM handler）
- Unlocks: Story 008（lifecycle signals）
