# Story 022: BLOCKED — Mobile Particle Floor Benchmark

> **Epic**: Enemy Director
> **Status**: Blocked
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2h (when unblocked)
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001
**ADR Decision Summary**: ADR-0001 structural decisions cap particles at `MAX_CONCURRENT_PARTICLE_EMITTERS=8`; the 30fps floor benchmark on iPhone 12 + iOS 17+ Safari is the empirical validation that the cap is sufficient. Reclassified from Logic|unit to hardware benchmark.

**Engine**: Godot 4.6 | **Risk**: HIGH

---

## Blockers

- **BLOCKED**: Requires iPhone 12 + iOS 17+ Safari real hardware. Headless CI cannot verify real `frame_time`. This AC was reclassified from Logic|unit to hardware benchmark — automated simulation cannot substitute for real device rendering.

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-25 [Logic|ADVISORY|benchmark-hardware]: Given: iPhone 12 + iOS 17+ Safari. When: 8-enemy AOE + LootDrop particle burst triggered simultaneously (worst-case `MAX_TARGETS_PER_CAST=8`). Then: `frame_time ≤ 33ms` sustained (30fps floor). 3+ consecutive frames >33ms = FAIL. (Falsifiable Test #5 binding, FR-4)

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Run AFTER Story 015 (particle throttle) fully implemented and CI-green.
- Test scenario: spawn 8 enemies; trigger AOE ability cast on all 8; simultaneously trigger LootDrop particle reveal (worst-case overlap).
- Measurement tool: Godot profiler export + Safari Web Inspector timeline.
- Record: frame times for 10 consecutive frames during burst. Calculate: count of frames >33ms.
- Pass: ≤ 2 frames >33ms in the burst window (up to 2 isolated spikes acceptable; 3+ consecutive = FAIL).
- If FAIL: escalate to ADR-0001 — reduce `MAX_CONCURRENT_PARTICLE_EMITTERS` or adjust throttle thresholds. Document in ADR-0001 as empirical result.
- Results file must include: device model, iOS version, Safari version, Godot export settings, frame time array, pass/fail verdict.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 015: Particle throttle implementation (must be complete before this benchmark)
- Story 004: CI lint enforcing `const MAX_CONCURRENT_PARTICLE_EMITTERS`

---

## QA Test Cases

*Cannot be automated — requires real iPhone 12 hardware + Safari.*

**AC-25**: Record frame times during particle burst. Pass criteria: fewer than 3 consecutive frames >33ms. Evidence: raw frame time array + annotated screenshot from profiler.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `production/qa/evidence/enemy_director_mobile_particle_floor.md`
**Status**: [ ] Not yet created (blocked)

---

## Dependencies

- Depends on: Story 015 (particle throttle fully implemented), real mobile hardware (iPhone 12 + iOS 17+) available
- Unlocks: ADR-0001 CPU/particle budget empirical ratification
