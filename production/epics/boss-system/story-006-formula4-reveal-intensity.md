# Story 006: Formula 4 reveal_ritual_intensity_scaling

> **Epic**: Boss System
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/boss-system.md` — Formula 4 (final-boss-only, categorical)
**Requirement**: `TR-boss-009` (final-boss-only categorical), `TR-boss-010` (all reveal_ritual_intensity ≤ 1.0 < #5 max_caller_multiplier 1.5)

**ADR Governing Implementation**: ADR-0001 (Web Export Budget — caller_mult ceiling) — primary
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ritual_caller_mult = clamp(template.reveal_ritual_intensity, MIN_RITUAL_INTENSITY, MAX_RITUAL_INTENSITY)`; feeds `CameraController.request_focal` / `ScreenEffects.shake` / `ParticleSystemWrapper.spawn` (real autoload names). CI-4: must be ≤ #5 `max_caller_multiplier=1.5`.

**Control Manifest Rules (Presentation callers)**: caller_mult never exceeds the downstream system's budget ceiling.

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-21**: reveal_ritual_intensity 0.6/1.0/1.5(invalid) → outputs 0.6/1.0/1.0 (clamped to MAX_RITUAL_INTENSITY).
- [ ] **AC-24** (CI-4): all BossTemplate.reveal_ritual_intensity in registry ≤ 1.0 (well below #5 max_caller_multiplier=1.5).
- [ ] CF-5: `ritual_caller_mult ≤ MAX_RITUAL_INTENSITY=1.0`. Mini-boss = DEAD PATH for #16 (categorical NO focal; #14 lite path).

---

## Implementation Notes

*From GDD Formula 4:*

- Single multiplier drives all 3 visual calls (Story 010). Defaults: MIN_RITUAL_INTENSITY=0.4, MAX_RITUAL_INTENSITY=1.0. Final boss template default reveal_ritual_intensity=1.0.
- #16 Formula 4 NEVER executes for mini-boss (that path is #14 wave system's hardcoded 0.6, no focal).

---

## Out of Scope

- **Story 010**: the actual dispatch to Camera/ScreenEffects/Particle using this mult.

---

## QA Test Cases

- **AC-21**: inputs {0.6,1.0,1.5} → {0.6,1.0,1.0}. Edge: 0.3 (below MIN) → 0.4.
- **AC-24**: iterate registry FINAL templates, assert all ≤ 1.0.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feature/boss_system/test_formula4_ritual_clamp.gd` + `test_ci4_caller_mult_compliance.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (BossFormulas), Story 001 (template field)
- Unlocks: Story 010 (reveal dispatch)
