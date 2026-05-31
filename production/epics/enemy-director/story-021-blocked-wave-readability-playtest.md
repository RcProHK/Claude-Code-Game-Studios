# Story 021: BLOCKED — Wave Archetype Readability Playtest

> **Epic**: Enemy Director
> **Status**: Blocked
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: 2h (when unblocked)
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007
**ADR Decision Summary**: ADR-0007 locks the AbilityClass enum to `{STRIKE, CONTROL, MOBILITY, UNKNOWN}` — archetype visual readability must map to these 3 active classes at ≥60% correct identification rate.

**Engine**: Godot 4.6 | **Risk**: MEDIUM

---

## Blockers

- **BLOCKED**: Pending art assets — enemy sprites, archetype silhouettes, and outline colors must be visible on-screen. FR-1 playtest requires visual output; cannot run headlessly.
- **BLOCKED**: Requires MOBILITY/CONTROL/STRIKE mob art-bible sign-off from art director before playtest is valid.

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-18 [Logic|ADVISORY|playtest]: 3 testers × 10s silent gameplay (mute audio + hide HUD) for each of 3 wave types. ≥60% correct class identification (3-class random baseline=33%; 60% is significantly above chance). (Falsifiable Test #1 + FR-1 binding)

**Scoring**: 3 testers × 3 wave types × 1 guess each = 9 total guesses. Pass threshold: ≥6 correct (≥67%). Minimum pass: each wave type identified correctly by ≥2/3 testers.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Run playtest AFTER:
  - Enemy sprites implemented with archetype silhouettes (STRIKE: heavy/boxy, CONTROL: robed, MOBILITY: lean/agile)
  - Primary outline colors applied per GDD spec (STRIKE=RED, CONTROL=BLUE, MOBILITY=GREEN) from EnemyRegistry.tres
  - Art bible archetype silhouette sign-off received
- Playtest protocol:
  1. Spawn single wave type (3 enemies of same archetype)
  2. Tester watches 10s gameplay clip with audio muted + HUD hidden
  3. Tester guesses: "STRIKE / CONTROL / MOBILITY"
  4. Record result
  5. Repeat for all 3 wave types in random order per tester
- Results recorded in `production/qa/evidence/enemy_director_archetype_readability_signoff.md`
- Failure (< 60%): escalate to art director for silhouette redesign before unblocking this story

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 010: EnemyRegistry.tres data (outline colors defined there)
- Story 013: AI state machine (visual states drive animation that aids readability)

---

## QA Test Cases

*Cannot be automated — requires human testers and visual output.*

**AC-18**: Protocol above. Document: tester ID, wave type shown, guess made, correct/incorrect. Calculate: total correct / 9 = pass rate. Pass if ≥ 6/9 correct AND no single wave type scores 0/3.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/enemy_director_archetype_readability_signoff.md`
**Status**: [ ] Not yet created (blocked)

---

## Dependencies

- Depends on: Story 010 (registry with outline colors), art-bible approval, enemy sprites implemented, MOBILITY/CONTROL/STRIKE mob art sign-off
- Unlocks: Nothing gated on this (ADVISORY — does not block DoD, but should pass before ship)
