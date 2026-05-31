# Story 012: [BLOCKED] Live #2 Signal Subscription + Anti-Fabrication Chain

> **Epic**: Workout State Tracker
> **Status**: Blocked
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3h (when unblocked)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Blockers

**BLOCKED: ADR-0002 Proposed** — GymSys Integration Protocol. The 7 workout signal names + payload schemas are defined by ADR-0002. Until Accepted, these are subject to change. Live subscription to #2 GymSysClient cannot be locked.

**To unblock**: Run `/architecture-decision` to advance ADR-0002 to Accepted (requires ADR-0004 CORS resolution + VS-tier endpoint validation). Then remove BLOCKED status.

---

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirements**: `TR-wst-001`, `TR-wst-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Proposed ⚠️) — GymSys Integration Protocol
**ADR Decision Summary**: 7 typed workout signals with locked payload schemas; differential event cursor; 5s ±0.5s polling cadence; idempotent re-poll on bfcache resume.

**Secondary ADR**: ADR-0006 Contract 6 (`connect_for_initial_state` for position-independent subscription)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (ADR-0002 Knowledge Risk: LOW for HTTPRequest, MEDIUM for JavaScriptBridge SSE)

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [ ] **AC-01** (Rule 1): GIVEN `WorkoutStateTracker._ready()` complete with #2 GymSysClient mock injected, WHEN check connected signals list, THEN exactly subscribed to: `workout_started`, `set_logged`, `rest_started`, `rest_ended`, `workout_completed`, `poll_failed`, `poll_recovered`; any missing → assert fail.
- [ ] **AC-42** (Falsifiable Test #3 + FR-3): GIVEN scenario: skip `workout_started`; directly emit `set_logged` + `workout_completed` (mock #2/#3/#11/#14/#9), WHEN observe full 5-system anti-fabrication chain, THEN boss NOT spawned; loot NOT dropped; `set_progress` stays 0; `Stat.apply_stat_delta` NEVER invoked. Any reward without workout = anti-fabrication chain failure.
- [ ] **AC-40** *(ADVISORY — Manual playtest, DEFERRED to VS playtest)* (Falsifiable Test #1 + FR-1): GIVEN playtester pool (leg-dominant / push-dominant / pull-dominant / mixed workouts), WHEN play Mirror Hero 30 min without menu labels, THEN ≥ 70% report distinct fight-feel differences by class. VS-tier: n ≥ 2 ADVISORY; MVP gate: n ≥ 8 BLOCKING. Evidence: `production/qa/evidence/wst_blind_playtest.md`.

---

## Implementation Notes

*(Document here when unblocked — reference ADR-0002 signal payload schema for each of the 7 signals.)*

- **Signal subscription** — use `connect_for_initial_state(callable)` from ADR-0006 Contract 6 for position-independent subscription. Subscription happens in `_ready()` after `_substate = INITIALISING`.
- **Anti-fabrication guard** — all 5 systems (#2→#3→#11→#14→#9) must honor closed-API + truth-gate posture. AC-42 tests the failure path: what happens when the chain is bypassed.
- **AC-40 playtest** — solo dev scenario: 8 sessions covering all 4 class types. Document qualitative fight-feel observations. No automation path.

---

## Out of Scope

*(When unblocked, verify live #2 subscription only — do not re-implement internal logic tested in Stories 001-010.)*

---

## QA Test Cases

*(Test specs ready — implement when unblocked.)*

### AC-01 — 7-signal subscription (Rule 1) [ADEQUATE with mock — unblockable once ADR-0002 Accepted]
```
Given: WorkoutStateTracker._ready() complete; #2 GymSysClient mock injected
When:  inspect connected signals (get_signal_list / get_signal_connection_list)
Then:  subscribed to exactly: workout_started, set_logged, rest_started, rest_ended,
       workout_completed, poll_failed, poll_recovered
       any missing signal → assert fail
Edge:  no extra subscriptions beyond the 7 (defensive: unknown signal names → CI smell)
```

### AC-42 — 5-system anti-fabrication chain (Falsifiable Test #3) [Integration, controlled env]
```
Given: mock instances of #2 GymSysClient + #3 PersistenceLayer + #11 StatSystem + #14 EnemyDirector + #9 WST
       SKIP workout_started — directly emit set_logged + workout_completed
When:  observe the full chain
Then:  boss NOT spawned (#14 spy records 0 pre-spawn events)
       loot NOT dropped (#15 spy records 0 loot-roll events)
       set_progress stays 0 (WorkoutStateTracker.get_set_progress() == 0.0)
       Stat.apply_stat_delta NEVER invoked (#11 spy invocation count == 0)
       any reward emitted without preceding workout_started == anti-fabrication chain failure (hard assert)
Note:  controlled-env integration test, NOT full build (BLOCKED on deps, not DEFERRED)
```

### AC-40 — blind dominant_class playtest [Manual ADVISORY — DEFERRED]
```
Manual verification steps:
1. Recruit playtesters: 4 sessions covering leg-dominant, push-dominant, pull-dominant, mixed
2. Each plays Mirror Hero 30 min WITHOUT seeing menu/class labels
3. Collect free-text descriptions of "fight feel" after session
Pass: >= 70% report leg/push/pull sessions feel noticeably different from each other
     MOBILITY players describe "enemies move fast, need to dodge"
     STRIKE players describe "enemies tank hits, need to break through"
Gate: VS-tier n >= 2 ADVISORY; MVP gate n >= 8 BLOCKING (per CD F-11)
Evidence path: production/qa/evidence/wst_blind_playtest.md
Deferred: requires players + full build — DEFERRED to VS/MVP playtest milestone
```

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/core/workout_state_tracker/test_live_signal_subscription.gd` + `test_anti_fabrication_chain.gd` — must exist and pass (when unblocked)
**Advisory evidence**: `production/qa/evidence/wst_blind_playtest.md` (manual playtest, DEFERRED)

**Status**: [ ] BLOCKED — not started

---

## Dependencies

- Depends on: Stories 001-011 DONE; ADR-0002 Accepted; #14 EnemyDirector + #15 LootDrop instances available
- Unlocks: Full epic DoD (all 43 ACs verified)
