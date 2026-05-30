# Story 010: ADR-Ratification-Gated — CPU Budget Benchmark

> **Epic**: Combat Resolver
> **Status**: Blocked
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

> ⚠️ **BLOCKED**: Requires **ADR-0001 Accepted** (currently Proposed — pending VS-tier mobile profiling on target hardware). ADR-0001 Status: Proposed (provisional CPU budget values pending measurement). This story implements the benchmark and ratification evidence.

## Context

**GDD**: `design/gdd/combat-resolver.md`
**Requirements**: `TR-combat-018`
*(TR-combat-018: CPU budget ≤ 1.0ms per combat tick (ADR-001 FR-3).)*

**ADR Governing Implementation**: ADR-0001 (Proposed ⚠️) — Web Export Budget Caps; FR-3 combat tick CPU budget ≤ 1.0ms p95 mobile (iPhone 12 / iOS 17+ Safari).
**ADR Decision Summary**: BLOCKED — provisional values. Once ADR-0001 ratified with measured values, update AC-35 threshold and run benchmark. If budget exceeded, mitigation options: (a) enforce Rule 18 catch-up × AOE serialization; (b) reduce MAX_TARGETS_PER_CAST from 8 to 6; (c) raise ADR-0001 budget cap (requires re-ratification).

---

## Acceptance Criteria

- [ ] **AC-35** — GIVEN AOE cast with 8 targets × 3 hits each (worst-case 24 hits per frame), WHEN benchmark run on mobile reference hardware (per ADR-0001 §Validation Methodology — iPhone 12 / iOS 17+ Safari), THEN total `resolve_hit` CPU time p95 ≤ 1.0ms, p99 ≤ 1.5ms.
  - Gate: **ADR-0001 RATIFICATION-GATED** — provisional pending VS-tier mobile profiling.
  - Path: `tests/unit/combat/test_combat_resolver_benchmark.gd` (GUT timing instrumentation).

---

## Implementation Notes

*Deferred — see GDD FR-3 + ADR-0001 §Validation Methodology.*

When unblocked:
- Run `resolve_hit` 1000 times with worst-case CombatContext (AOE 8 targets)
- Measure with `Time.get_ticks_usec()` — 1000μs = 1ms budget
- If GUT headless test exceeds budget on CI runner → flag for mobile profiling (CI runner ≠ mobile)
- Real measurement requires VS-tier mobile build + ADR-0001 §Validation Methodology

---

## QA Test Cases

*Deferred — BLOCKED on ADR-0001 ratification.*

---

## Test Evidence

**Story Type**: Logic (benchmark)
**Required evidence**: `tests/unit/combat/test_combat_resolver_benchmark.gd` — BLOCKED.

**Status**: [ ] BLOCKED

---

## Dependencies

- Depends on: Stories 001-009 ALL Complete AND **ADR-0001 Accepted** (Proposed → Accepted requires VS-tier mobile profiling)
- Unlocks: CombatResolver epic fully complete
