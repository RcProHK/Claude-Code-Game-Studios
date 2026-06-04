# Story 010: Reveal ritual dispatch (Camera-leading)

> **Epic**: Boss System
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/boss-system.md` — Rule 7 (reveal ritual coordination, Camera-leading timeline)
**Requirement**: `TR-boss-014` (reveal ritual dispatch), `TR-boss-009` (intensity feed)

**ADR Governing Implementation**: ADR-0001 (budget — particle/shake/focal caps) — primary; ADR-0009 (boss_committed payload) secondary
**Engine**: Godot 4.6 | **Risk**: MEDIUM (ADR-0001 CPU/particle budget, Provisional)
**Engine Notes**: Real autoload names — `CameraController.request_focal(...)`, `ScreenEffects.shake(...)`, `ParticleSystemWrapper.spawn(preset=ParticleSystemWrapper.PresetId.LOOT_RARE_BURST, caller_mult=...)`, `AudioManager.play_cue(...)`. Subscriber `_on_boss_committed` connected at `_ready` via `connect_for_initial_state`. Camera focal LEADS (frame 0); shake+particles+audio follow (frame 1-2 after `await get_tree().process_frame`).

**Control Manifest Rules (Presentation callers)**: shake via `ScreenEffects.add_trauma`/`shake` (shader uniform path), NOT Camera2D.offset; caller_mult ≤ #5 ceiling 1.5.

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-07**: mock #5/#6/#7 spies — (a) `CameraController.request_focal` dispatched FIRST (call_order 0); (b) shake+particle dispatched frame 1-2 AFTER camera; (c) ≤2 process frames; (d) Camera target === `spawn_pos` payload (not late global_position read); (e) each caller_mult == `reveal_ritual_intensity`; (f) `boss.global_position == spawn_pos`.
- [ ] **AC-07b**: logical dispatch budget — injectable MockClock (`MOCK_FRAME_MS=16`/frame); 2-frame dispatch = 32ms ≤ 200ms PASS; 250ms single-frame stall = FAIL. Deterministic, frame-rate-independent.
- [ ] EC-13/14/15: Camera SUSPENDED → reveal continues without focal + `boss.partial_reveal` (WARN); particle budget exhausted → spawn without particles; per-call try/except (no-cascade-failure).

---

## Implementation Notes

*From GDD Rule 7 timeline:*

- `_on_boss_committed(template, boss, snapshot, spawn_pos, transition_id)`: Camera frame 0; `await get_tree().process_frame`; shake/particles/audio frame 1-2, all using cached `spawn_pos` (never late `boss.global_position`).
- Dispatch budget ≤200ms / ≤2 frames is the Pillar-2 sub-500ms boss-visible budget (inherited #9 AC-41 + #14 FR-2), NOT a new knob. Focal hold 0.6s × mult runs async after dispatch (non-blocking).

---

## Out of Scope

- **Story 006**: the intensity formula. The actual #5/#6/#7 implementations (Approved/implemented).

---

## QA Test Cases

- **AC-07**: spies assert call order Camera(0) < shake/particle; target arg === spawn_pos; caller_mult == intensity.
- **AC-07b**: MockClock 16ms/frame × 2 = 32ms → PASS; inject 250ms jump → FAIL (both asserted).
- **EC-13**: mock Camera returns false (SUSPENDED) → reveal continues + partial_reveal WARN.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/feature/boss_system/test_reveal_ritual_sequence.gd` + `tests/unit/feature/boss_system/test_ac07b_logical_dispatch_budget.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007 (boss_committed emit), Story 006 (intensity mult)
- Unlocks: None
