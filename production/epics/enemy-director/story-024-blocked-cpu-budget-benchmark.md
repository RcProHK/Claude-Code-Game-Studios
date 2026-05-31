# Story 024: BLOCKED — CPU Budget Benchmark

> **Epic**: Enemy Director
> **Status**: Blocked
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2h (when unblocked)
> **Manifest Version**: 2026-05-29
> **Last Updated**:

## Context

**GDD**: `design/gdd/enemy-director.md`
**Requirements**: `TR-enemy-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (CPU Provisional)
**ADR Decision Summary**: ADR-0001 CPU budget numbers remain Provisional pending VS-tier mobile profiling — the p95/p99 thresholds (0.5ms / 0.7ms) are estimated; AC-38 is explicitly ADR-RATIFICATION-GATED and cannot be verified until ADR-0001 CPU numbers are confirmed via vertical slice profiling.

**Engine**: Godot 4.6 | **Risk**: HIGH

---

## Blockers

- **BLOCKED**: ADR-0001 CPU budget numbers remain Provisional pending VS-tier mobile profiling. AC-38 is explicitly `ADR-RATIFICATION-GATED` — this story cannot be completed until ADR-0001 CPU section is ratified with confirmed p95/p99 thresholds from real vertical slice benchmarks.
- **BLOCKED**: Requires iPhone 12 + iOS 17+ Safari real hardware (same hardware reference as Story 022). Headless CI cannot verify real CPU orchestration timing.

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-director.md`, scoped to this story:*

- [ ] AC-38 [Logic|ADR-RATIFICATION-GATED|benchmark]: Given: iPhone 12 + iOS 17+ Safari (ADR-0001 reference hardware). When: AOE 8-target × 3 AOE hits/frame (worst-case). When: benchmark `_physics_process` + `_on_ability_cast` orchestration. Then: total CPU orchestration p95 ≤ 0.5ms; p99 ≤ 0.7ms. (Falsifiable Test #4 binding)

**Note**: Threshold values (0.5ms p95 / 0.7ms p99) are PROVISIONAL and will be revised when ADR-0001 CPU section is ratified. Do not treat these as final until ADR-0001 ratification completes.

---

## Implementation Notes

*Derived from GDD Rules and ADR guidelines:*

- Run AFTER Stories 014, 015, 018 (full pipeline implemented) AND ADR-0001 CPU ratification complete.
- Worst-case scenario: 3 simultaneous AOE ability casts, each targeting 8 enemies (24 `resolve_hit` calls in one `_physics_process` frame).
- Measurement: instrument `_physics_process` with `Time.get_ticks_usec()` before/after EnemyDirector logic (excluding Godot engine overhead). Record orchestration-only time (subtract physics engine tick time).
- Sample: 1000 frames of worst-case scenario. Calculate p95 and p99 from sample.
- Pass: `p95 ≤ 0.5ms AND p99 ≤ 0.7ms` (thresholds subject to ADR-0001 ratification).
- If FAIL post-ratification: profile hot path; optimize `_expand_targets()` sort; consider spatial hash for AOE radius queries; reduce stat snapshot overhead.
- Evidence must include: device/OS/browser, sample size, raw timing array (or histogram), p95/p99 values, pass/fail verdict vs ratified thresholds.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 014: Locomotion + 4Hz perception (separate CPU budget)
- Story 015: Particle throttle (separate particle budget from orchestration budget)
- Story 018: Full AOE pipeline (must be implemented before this benchmark runs)

---

## QA Test Cases

*Cannot be automated — requires real iPhone 12 hardware + performance profiling.*

**AC-38**: Instrument `_physics_process`. Trigger 3× AOE casts per frame for 1000 frames. Record orchestration time per frame. Compute: `sort(times)[949]` = p95; `sort(times)[989]` = p99. Pass: both ≤ ratified thresholds.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/performance/enemy_director/test_orchestration_cpu_budget.gd`
**Status**: [ ] Not yet created (blocked)

---

## Dependencies

- Depends on: Stories 014, 015, 018 (full pipeline implemented), ADR-0001 CPU ratification complete, real mobile hardware (iPhone 12 + iOS 17+) available
- Unlocks: ADR-0001 full ratification (both structural and CPU budget)
