# Story 010: ADR-Ratification-Gated

> **Epic**: Ability System
> **Status**: Blocked
> **Layer**: Core
> **Type**: Mixed
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

> ⚠️ **BLOCKED**: This story requires:
> - `#10 Exercise→Class Mapping` GDD authored + Accepted (for AC-31)
> - ADR-0002 Accepted + `#18 PR Detection` authored (for AC-32)
> - ADR-0003 Accepted (for AC-33)
> None of these are currently Accepted (all Proposed or Not Started). Do NOT begin implementation until all three are resolved.

## Context

**GDD**: `design/gdd/ability-system.md`
**Requirements**: FR-1 (class enum lock), FR-2 (PR server-validated), FR-3 (namespace permanent)

**ADR Governing Implementation**: ADR-0003 (Proposed ⚠️ — `ability.unlocked.*` namespace); ADR-0002 (Proposed ⚠️ — GymSys server-validated PR breakthrough); #10 Exercise→Class Mapping (Not Started).
**ADR Decision Summary**: BLOCKED — cannot implement until all three upstream dependencies ratified. Full description in GDD Section B Fantasy Risk Register.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core layer)**: Governed by upstream ADRs — consult at ratification time.

---

## Acceptance Criteria

- [ ] **AC-31** — FR-1: GIVEN `#10 Exercise→Class Mapping` GDD Accepted with class enum frozen, WHEN static analysis compares `AbilityClass.values()` to #10's published `ClassId.values()`, THEN both equal exactly `[STRIKE, CONTROL, MOBILITY]` (3 values — note: ADR-0007 adds UNKNOWN=4th to AbilityClass; #10's ClassId must NOT include UNKNOWN — ClassId is a pure 3-class output enum, separate from AbilityClass Family B). Mismatch fails build with note "FR-1 binding violation".
  - Gate: **ADR-RATIFICATION-GATED** (#10 GDD Accepted) | Path: `tests/unit/ability_system/test_fr1_class_enum_locked.gd`
- [ ] **AC-32** — FR-2: GIVEN ADR-0002 Accepted + #18 PR Detection authored, WHEN integration test injects fabricated `pr_breakthrough(bench_press, magnitude=0.5)` via client-side without server attestation token, THEN #18 rejects emit (never reaches AbilitySystem); AbilitySystem `_unlocked_abilities` unchanged; defensive check at AbilitySystem boundary (EC-35: `is_nan(magnitude) or magnitude < 0`) passes silently (no unlock attempted for valid-but-unattested magnitude).
  - Gate: **ADR-RATIFICATION-GATED** (ADR-0002 Accepted + #18 authored) | Path: `tests/integration/ability_system/test_fr2_pr_server_validated.gd`
- [ ] **AC-33** — FR-3: GIVEN ADR-0003 Accepted with `ability.unlocked.*` as backend-primary + IndexedDB secondary, STRIKE_TIER_2_HOOK persisted at session start, WHEN simulated 30-day absence (no stat_changed, no pr_breakthrough, no playtime) + reboot, THEN Rule 10 boot reconciliation reads `ability.unlocked.strike_tier_2_hook` key; `get_unlocked_abilities()` after boot contains `STRIKE_TIER_2_HOOK`; no `ability_relocked` / `ability_decayed` signal exists in codebase; no scheduled task deletes `ability.unlocked.*` keys.
  - Gate: **ADR-RATIFICATION-GATED** (ADR-0003 Accepted) | Path: `tests/integration/ability_system/test_fr3_namespace_permanent.gd`

---

## Implementation Notes

*Deferred — consult GDD Section B Fantasy Risk Register + Section H AC-31/32/33 at ratification time.*

Key considerations when unblocked:
- AC-31: Align #10 `ClassId` enum names with `AbilityClass` values; run `/consistency-check` at #10 GDD authoring time (EC-39)
- AC-32: #18 GDD must spec server-side validation path; AbilitySystem adds EC-35 `is_nan/magnitude<0` defensive check at unlock evaluation entry
- AC-33: ADR-003 ratification may require `ability.unlocked.*` namespace re-keying; verify migration path doesn't break existing persist-first ordering

---

## Out of Scope

Everything in stories 001-009 handles the core mechanics. This story ONLY handles the three ADR-gated guarantees.

---

## QA Test Cases

*Deferred — cannot define test scaffolding until upstream ADRs/GDDs resolved.*

Placeholder: `*Test cases not yet defined — gate on #10 Accepted + ADR-0002 Accepted + ADR-0003 Accepted.*`

---

## Test Evidence

**Story Type**: Mixed (static-analysis + integration)
**Required evidence**: See AC paths above — none created until ADRs accepted.

**Status**: [ ] BLOCKED — not to be created until all 3 gates resolved

---

## Dependencies

- Depends on: Stories 001-009 ALL Complete AND #10 GDD Accepted AND ADR-0002 Accepted AND ADR-0003 Accepted
- Unlocks: Ability System epic FULLY complete (current epic remains 9/10 complete until ADRs ratified)
