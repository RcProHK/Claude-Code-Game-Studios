# Story 013: ADR-RATIFICATION-GATED (FR-1 / FR-2 / FR-3)

> **Epic**: Stat System
> **Status**: Blocked
> **Layer**: Core
> **Type**: Mixed (Static + Integration + Composite/Binary)
> **Estimate**: L (4-6 hours — after ADR-003 + ADR-005 Accepted)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/stat-system.md`
**Requirements**: `TR-stat-003` (StatSource exhaustiveness), `TR-stat-016` (DEBUG_OVERRIDE triple defense)

**ADR Governing Implementation**: ADR-0003 (Proposed ⚠️ — Save State Strategy); ADR-0005 (Proposed ⚠️ — Loot Rarity Formula)
**ADR Decision Summary**: These 3 ACs are gated on both ADR-003 AND ADR-005 being Accepted. They verify the full anti-fabrication guarantee (FR-1/FR-2/FR-3 from GDD Section B Fantasy Risk Register). VS-tier shipping allows Stories 001-012 to be marked Complete; this story remains Blocked until both ADRs are ratified.

> **BLOCKED — DO NOT IMPLEMENT**: Both ADR-003 (Save State Strategy) and ADR-0005 (Loot Rarity Formula) must be Accepted before this story can begin. Current status: ADR-0003 = Proposed, ADR-0005 = Proposed. When both are Accepted, advance this story to Ready and schedule for the next sprint.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (export pipeline binary inspection for FR-3)

---

## Acceptance Criteria

- [ ] **AC-35 (ADR-RATIFICATION-GATED — FR-1)** — GIVEN ADR-005 (Loot Rarity) Accepted AND loot system (#17) shipped, WHEN codebase is searched for any `StatSource` member beyond the locked 5 (`PR_BREAKTHROUGH / VOLUME_TICK / EQUIPMENT / DEBUG_OVERRIDE / INITIAL_STATE`), THEN none found — any RNG-influenced stat boost MUST go through `EQUIPMENT` modifier path per Rule 5; CI lint `tools/ci/check_stat_source_enum_closed.gd` enforces this. *(Type: static-analysis | Gate: ADR-RATIFICATION-GATED: ADR-005 Accepted)*
- [ ] **AC-36 (ADR-RATIFICATION-GATED — FR-2)** — GIVEN ADR-005 Accepted AND loot system generates EQUIPMENT modifier deltas based on PR-anchored rarity, WHEN 1000 simulated PR sessions are run and `equipment_*_mod` value distribution is captured, THEN distribution correlates with `pr_magnitude` input (Pearson r ≥ 0.7 per ADR-005 Pillar 1 binding); AND no pure-RNG loot path exists. *(Type: integration | Gate: ADR-RATIFICATION-GATED: ADR-005 Accepted + balance simulation)*
- [ ] **AC-37 (ADR-RATIFICATION-GATED — FR-3)** — GIVEN release build pipeline active (export template + CI gate + runtime guard), WHEN all three defense layers are verified independently: (a) Runtime: AC-13 ✓ (Story 008 Complete); (b) CI lint: AC-14 ✓ (Story 001 Complete); (c) Export-template strip: editor-only code blocks absent from release `.pck` binary (binary diff vs debug shows DEBUG_OVERRIDE block stripped), THEN all three defenses pass — failure of any one layer = FR-3 violation. *(Type: composite integration + binary inspection | Gate: ADR-RATIFICATION-GATED: ADR-003 Accepted + export pipeline tooling complete)*

---

## Implementation Notes

*From GDD Fantasy Risk Register FR-1/FR-2/FR-3:*

1. **AC-35 (`check_stat_source_enum_closed.gd`)**: Grep `enum StatSource` definition; extract member names; assert set equals exactly 5 known members. Flag any additions. This is a post-#17-ship validation — run as part of integration gate after loot system is live.

2. **AC-36 (1000-session correlation test)**: Requires #17 Equipment Inventory + #15 LootDrop shipped. Mock 1000 workout sessions with varying `pr_magnitude` (0.01–2.0 range); capture resulting `equipment_*_mod` values; compute Pearson r between `pr_magnitude` and equipment delta; assert r ≥ 0.7. Threshold may be revised per Q-A4 after ADR-005 ratification + simulation results.

3. **AC-37 (binary inspection)**: Requires export pipeline tooling. Export a release build + a debug build; binary-diff the `.pck` files; assert `DEBUG_OVERRIDE` block is absent in release `.pck`. Tools: `godot --export-release` + custom diff script or `strings` + grep on `.pck`. Script: `tools/ci/check_release_binary_strips_debug_override.sh`.

4. **GDD AC body note** (Q-A4): AC-36 Pearson threshold 0.7 is provisional pending ADR-005 ratification — may settle at 0.65 or 0.75 based on balance simulation. Confirm threshold in ADR-005 text when ratified.

---

## Out of Scope

- All other stat-system stories (001-012) — complete those before unblocking this one
- ADR-003 / ADR-005 ratification itself — produced by separate `/architecture-review ratify` session

---

## QA Test Cases

**Story Type**: Mixed (unblockable until ADRs ratified — placeholder only)

- **AC-35**: StatSource exhaustiveness (post ADR-005 ratification)
  - Setup: ADR-005 Accepted + #17 shipped
  - Then: Run `check_stat_source_enum_closed.gd` → exit 0 confirming exactly 5 values

- **AC-36**: EQUIPMENT modifier PR-anchor correlation
  - Setup: ADR-005 Accepted + 1000-session simulation tool built
  - Then: Pearson r ≥ 0.7 between pr_magnitude and equipment delta distribution

- **AC-37**: Triple defense composite
  - Setup: Release export pipeline configured
  - Then: AC-13 ✓ + AC-14 ✓ + binary inspection ✓ all pass independently

---

## Test Evidence

**Story Type**: Mixed
**Required evidence**:
- Static: `tools/ci/check_stat_source_enum_closed.gd` (AC-35)
- Integration: `tests/integration/stat_system/test_fr2_loot_pr_anchor_correlation.gd` (AC-36)
- Composite: `tests/integration/stat_system/test_fr3_debug_override_triple_defense.gd` + `tools/ci/check_release_binary_strips_debug_override.sh` (AC-37)

**Status**: [ ] BLOCKED — Not yet implementable

---

## Dependencies

- Depends on: Stories 001-012 (all Ready stories Complete), ADR-003 Accepted, ADR-0005 Accepted, #17 Equipment Inventory shipped, export pipeline tooling complete
- Unlocks: Stat System Epic COMPLETE (all 37 ACs verified)
