# Architecture Review — Focused ADR Ratification

> **Date**: 2026-05-30
> **Mode**: `/architecture-review` focused ratification (ADR-0001, ADR-0002, ADR-0003, ADR-0005)
> **Engine**: Godot 4.6
> **Trigger**: #11/#12/#13 (ADR-0006-governed) implemented + CI-green + merged; next tier (#5/#6/#7/#9/#14/#15) gated on Proposed ADRs. Fresh-review (these ADRs authored in prior sessions — never same session as authoring).

---

## Verdict: 3 of 4 Ratified

| ADR | Verdict | Reasoning |
|-----|---------|-----------|
| **ADR-0001** Web Export Budget Caps | ✅ **Accepted (structural)** | Renderer-per-platform / CanvasLayer topology / mobile detection / CI enforcement / GPU particle-cap concept are sound design choices with no measurement gate. CPU budget **numeric figures stay Provisional** pending VS-tier mobile profiling — CPU-benchmark RATIFICATION-GATED ACs (CombatResolver AC-35, #5/#6/#7 CPU ACs) remain gated. This is exactly the split the ADR's own Status note + Ordering note prescribe. |
| **ADR-0003** Save State Strategy | ✅ **Accepted** | Structural/design decisions (backend-primary + IDB hierarchy, IDB-over-localStorage, conflict resolution, Safari ITP, migration protocol); depends only on ADR-006 (Accepted). #3 PersistenceLayer already implemented + CI-green validates the IPersistence contract in practice. No measurement/backend gate. |
| **ADR-0005** Loot Rarity Formula | ✅ **Accepted** | Depends On: None. Formula fully specified + deterministic (RNG seeded on transition_id). Reconciles prior discrepancy (systems-index "Accepted 2026-05-27" vs ADR/technical-preferences "Proposed"). #11 Stat already ships PR_BASE provisional. |
| **ADR-0002** GymSys Integration Protocol | ❌ **Kept Proposed** | ADR's own Status: "cannot reach Accepted without ADR-0004 resolving CORS"; ADR-0004 is also Proposed. Both carry **Verification Required** sections demanding VS-tier validation against the actual GymSys backend (HTTPRequest over real origin, CORS preflight pass, X-Session-Token arrival at FastAPI). No backend integration built → ratifying would be dishonest. |

## Cross-ADR Consistency (ratifiable set)

✅ No conflicts among ADR-0001/0003/0005.
- ADR-0003 references ADR-0001's 512MB ceiling for IDB quota — consistent.
- ADR-0003 "Enables ADR-0005 loot-state persistence" — ADR-0005 loot state persists via ADR-0003. Consistent.
- ADR-0001 vs ADR-0005 — no overlap.
- Dependency foundation = ADR-0006 (Accepted). No cycles in the ratifiable set.
- Engine: all Godot 4.6; no deprecated-API references flagged.

## What This Unblocks

**Now implementable** (Accepted ADR coverage):
- **#5 ParticleSystemWrapper / #6 ScreenEffects / #7 Camera** — structural stories (renderer/topology/CI ACs). CPU-budget ACs stay gated on ADR-0001 numeric figures.
- **#15 LootDrop System** — rarity formula stories (ADR-0005).
- **stat-system story-013** (ADR-0003 + ADR-0005 ratification-gated ACs — was BLOCKED).
- **ability-system story-010** — ADR-0003 AC-33 (namespace permanent) now unblocked; AC-31 (#10 GDD) + AC-32 (ADR-0002) stay blocked.
- **combat-resolver** — ADR-0005 FR-2 enemy_killed chain confirmed Accepted.

**Still blocked** (ADR-0002 Proposed — needs real GymSys backend):
- #2 GymSys Backend Client, #9 WorkoutStateTracker gym-consumption stories, #14 EnemyDirector catchup stories, ability story-010 AC-32.
- ADR-0001 CPU-benchmark ACs (combat AC-35, #5/#6/#7 CPU budget) — need VS-tier mobile profiling.

## Follow-ups
- Re-run `/create-control-manifest` to fold ADR-0001/0003/0005 rules into the control manifest (currently covers ADR-0006/0007/0009).
- ADR-0002/0004 co-ratification requires building the GymSys integration + nginx subpath + verifying CORS against the real backend (VS-tier).
- ADR-0001 fully-Accepted requires VS-tier mobile CPU profiling to replace provisional budget numbers.
