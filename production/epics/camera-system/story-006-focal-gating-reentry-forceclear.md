# Story 006: Focal State Gating + Re-entry Guard + Force-clear

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-camera-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**) primary; ADR-0006 Contract 6/7 secondary
**ADR Decision Summary**: `request_focal` HARD gate to GSM state ∈ {BOSS_ENCOUNTER, LOOT_DROP}（Pillar 2 mid-set frictionless contract）；其他 state → reject + counter。re-entry strict reject（depth 0）。GSM 中途離開 focal-allowed state → force-clear（skip exit tween，snap to Following）。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `_gsm.current_state` read synchronously（ADR-0006 Contract 7 write-before-emit ordering 假設）。stub GSM untyped（current_state:int）。force-clear synchronous（同 frame，唔 await tween）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: focal gate {BOSS_ENCOUNTER, LOOT_DROP} only；re-entry strict reject
- Forbidden: focal during WORKOUT_ACTIVE/COMBAT_ACTIVE（Pillar 2 violation）；focal queue/stack
- Guardrail: mid-set Focal = anti-Pillar-2

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-16** [Rule 5 strict reject] — Focal active + second `request_focal()` → reject + `_focal_reentry_dropped_count += 1`；current tween 不受影響。
- [ ] **AC-19** [Rule 4 / Pillar 2 hard] — `_gsm.current_state` 非 {BOSS_ENCOUNTER, LOOT_DROP}（e.g. WORKOUT_ACTIVE）→ `request_focal()` reject + `_focal_gating_rejected_count += 1`；state remains Following。
- [ ] **AC-20** [EC-07] — Focal active during BOSS_ENCOUNTER，GSM → IDLE → `_force_clear_focal_sync()` + skip exit tween + snap to Following defaults；state==Following within 1 frame。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 4/5 / EC-07/08:*

- `request_focal` gating（after finite validate Story 002）：`if _gsm.current_state not in [BOSS_ENCOUNTER, LOOT_DROP]` → push_warning + `_focal_gating_rejected_count += 1` + return；`if _state == FOCAL` → push_warning + `_focal_reentry_dropped_count += 1` + return（Rule 5 depth 0）。
- `_on_gsm_state_changed`：若 `_state == FOCAL` and new state ∉ {BOSS_ENCOUNTER, LOOT_DROP} and != SUSPENDED → `_force_clear_focal_sync()`（kill tweens，snap zoom DEFAULT_ZOOM，state Following，re-enable smoothing，**skip** exit tween）。
- GameState enum via `GameStateMachine.GameState.BOSS_ENCOUNTER` / `.LOOT_DROP`。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 007: Suspended（覆蓋一切，唔同 force-clear-to-Following）
- Story 002: finite validate；Story 004-005: tween bodies

---

## QA Test Cases

> **Seams**: inline `MockGSM extends RefCounted`（`current_state:int` + `connect_for_initial_state`）；`_focal_reentry_dropped_count`/`_focal_gating_rejected_count` readable；GameState enum via preload of GSM script。after_each restore paused。

- **AC-16**: re-entry strict reject
  - Given: `_gsm.current_state=BOSS_ENCOUNTER`；`request_focal(target_a)` active
  - When: `request_focal(target_b)`
  - Then: second return false；`_focal_reentry_dropped_count==1`；active focal STILL target_a（唔 retarget）
  - Edge: 第三 call → counter==2。Assert original tween 存活（sample target/zoom before/after）。

- **AC-19**: gating reject（PARAMETRIC）
  - Given: `_gsm.current_state=WORKOUT_ACTIVE`（+ 其他非-focal states parametric）
  - When: `request_focal(target)`
  - Then: return false；`_focal_gating_rejected_count==1`；state Following；無 tween created
  - Edge: 每個 non-focal state（IDLE/WORKOUT_ACTIVE/COMBAT_ACTIVE/etc.）reject；確認 BOSS_ENCOUNTER+LOOT_DROP 係 ONLY two permit

- **AC-20**: force-clear on GSM exit
  - Given: Focal active under BOSS_ENCOUNTER
  - When: `_gsm.current_state=IDLE`；invoke GSM state-sync handler
  - Then: exit tween SKIPPED（synchronous snap，唔係 0.5s tween）；`_camera.zoom==DEFAULT_ZOOM` immediately；state==Following within 1 frame；live tween killed
  - Edge: 對比 AC-13 normal clear（行 0.5s exit tween）；確認無 orphan tween

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/camera/test_focal_gating_forceclear.gd` — must exist and pass（AC-16,19,20）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004（focal entry）、Story 005（exit tween）、**#1 GameStateMachine (Complete)**
- Unlocks: Story 007（Suspended override）
