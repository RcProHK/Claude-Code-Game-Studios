# Architecture Review — Focused Partial Ratification (ADR-0002 / ADR-0004)

> **Date**: 2026-05-31
> **Mode**: Focused partial ratification — ADR-0004 (structural) + ADR-0002 (data contract)
> **Engine**: Godot 4.6
> **Trigger**: WST Story 012 (`story-012-live-signal-wiring`) BLOCKED on ADR-0002 Proposed. Goal: unblock the story's mock-scoped automated ACs (AC-01 7-signal subscription, AC-42 anti-fabrication chain) without claiming live-backend validation that does not exist.

---

## Verdict: 2 Partial Ratifications

| ADR | Verdict | Scope |
|-----|---------|-------|
| **ADR-0004** CORS / Cross-Origin Auth Topology | ✅ **Accepted (structural)** | Same-origin nginx reverse-proxy topology, `/mirror-hero/` static + `/api/game/` proxy routing, `/api/game/` FastAPI namespace, relative-URL `HTTPRequest`, `<base href>` shell, `X-Session-Token` CORS-safe-by-design. No measurement gate. VS-tier deployment/CORS Validation Criteria stay **Provisional**. |
| **ADR-0002** GymSys Integration Protocol | ✅ **Accepted (data contract)** | 5 workout signal names + payload schemas, differential event cursor (`last_event_id` + `server_epoch_id`), 5s ±0.5s cadence, `X-Session-Token` session-lock header, idempotent LootDrop/state-write UNIQUE-table structure — **Locked**. Transport/empirical *Verification Required* items stay **Provisional + VS-tier-gated**. |

## Why this is honest (and what changed from 2026-05-30)

The `architecture-review-ratification-2026-05-30` pass **kept ADR-0002 Proposed**, ruling that ratifying without live-backend validation "would be dishonest." That ruling is **upheld here** — this pass does **not** claim any live GymSys integration was validated. What it does is separate two distinct concerns that the 2026-05-30 pass treated as one:

1. **Data contract** (signal names + payload schemas + cursor + cadence + idempotency tables) — a pure design artefact with **no measurement gate**. This is what downstream consumers subscribe against. Ratifiable today.
2. **Transport/empirical validation** (HTTPRequest over real origin, CORS preflight, `X-Session-Token` arrival at FastAPI, `server_epoch_id` round-trip, `rest_started.duration_seconds` in live schema) — requires a real GymSys backend + nginx. **Stays gated.** Unchanged from 2026-05-30.

This is the same **structural-Accepted / empirical-Provisional** split already applied to **ADR-0001** (topology Accepted, CPU numbers Provisional) and **ADR-0003** (design Accepted, validated by the shipped #3 PersistenceLayer). ADR-0004's topology resolves the *design-level* CORS dependency ADR-0002 carried, so the data-contract ratification has no unmet ADR dependency.

## Cross-ADR Consistency

✅ No new conflicts.
- ADR-0004 `Depends On` ADR-0002 (endpoint contracts) + ADR-0003 (Accepted). ADR-0002 data contract now Locked; ADR-0003 Accepted. No cycle blocks the structural layer (ADR-0002↔ADR-0004 co-dependency resolved by ratifying ADR-0004's design + ADR-0002's contract in the same pass; neither empirical gate depends on the other's empirical gate).
- ADR-0002 `X-Session-Token` header consistent with ADR-0004 `proxy_set_header X-Session-Token` and ADR-0006 registry lock.
- Engine: both Godot 4.6; `HTTPRequest` + custom headers stable since 4.0; no deprecated-API references.

## What This Unblocks

**Now implementable** (data contract Locked):
- **WST story-012** (`story-012-live-signal-wiring`) — AC-01 (7-signal subscription) + AC-42 (5-system anti-fabrication chain) against mock #2 GymSysClient + mock #3/#11/#14/#15 spies. Status: BLOCKED → Ready (mock-scoped). AC-40 blind playtest stays ADVISORY/DEFERRED.
- **ability story-010 AC-32** (referenced ADR-0002 signal contract) — schema now Locked; verify if the AC is mock-scoped.

**Still gated** (transport/empirical — needs real GymSys backend + nginx, VS-tier):
- #2 GymSys Backend Client live HTTP stories; #9 WST live-subscription-against-real-backend verification; #14 EnemyDirector catchup live stories.
- ADR-0002 *fully* Accepted; ADR-0004 *fully* Accepted (deployment validation).
- ADR-0001 CPU-benchmark ACs (separate VS-tier mobile profiling gate — unchanged).

## Follow-ups

- Tag ADR-0002 / ADR-0004 `(verified YYYY-MM-DD)` when VS-tier builds the GymSys integration + nginx subpath + verifies CORS against the real backend → promotes both to *fully* Accepted.
- `/dev-story` WST story-012 may now proceed (mock-scoped). Integration tests: `tests/integration/core/workout_state_tracker/test_live_signal_subscription.gd` + `test_anti_fabrication_chain.gd`.
- Consider `/create-control-manifest` refresh to fold ADR-0002 data-contract + ADR-0004 topology rules into the control manifest.
