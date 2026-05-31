# Story 012: Live #2 Signal Subscription + Anti-Fabrication Chain

> **Epic**: Workout State Tracker
> **Status**: Complete (mock-scoped)
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-31
> **Completed**: 2026-05-31

## Unblock Status

**UNBLOCKED 2026-05-31 (mock-scoped)** — ADR-0002 partial ratification (`Accepted (data contract)`): the 7-signal subscription contract is now **Locked** — 5 workout events (`workout_started`, `set_logged`, `rest_started`, `rest_ended`, `workout_completed`) from ADR-0002, plus the `poll_failed` / `poll_recovered` connection-health signals from #2 GDD Rule 12. Signal names + payload schemas will not churn. AC-01 + AC-42 are implementable now against a mock #2 GymSysClient + mock #3/#11/#14/#15 spies — neither AC needs the live GymSys backend.

**Still gated (post-VS)**: live #2 subscription against the *real* GymSys backend (HTTPRequest over real origin, CORS preflight, `X-Session-Token` arrival) is VS-tier empirical — verify when ADR-0002 reaches *fully* Accepted. AC-40 blind playtest stays ADVISORY / DEFERRED to VS playtest milestone.

---

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirements**: `TR-wst-001`, `TR-wst-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Accepted — data contract ✓) — GymSys Integration Protocol
**ADR Decision Summary**: 5 typed workout signals with **Locked** payload schemas (+ 2 connection-health signals from #2 GDD); differential event cursor; 5s ±0.5s polling cadence; idempotent re-poll on bfcache resume. Transport/CORS empirical validation stays VS-tier-gated (does not affect this story's mock-scoped ACs).

**Secondary ADR**: ADR-0006 Contract 6 (`connect_for_initial_state` for position-independent subscription)

**Engine**: Godot 4.6 | **Risk**: MEDIUM (ADR-0002 Knowledge Risk: LOW for HTTPRequest, MEDIUM for JavaScriptBridge SSE)

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [x] **AC-01** (Rule 1): GIVEN `WorkoutStateTracker._ready()` complete with #2 GymSysClient mock injected, WHEN check connected signals list, THEN exactly subscribed to: `workout_started`, `set_logged`, `rest_started`, `rest_ended`, `workout_completed`, `poll_failed`, `poll_recovered`; any missing → assert fail. — `_connect_gym_sys_signals()` (`src/autoload/workout_state_tracker.gd`); `test_live_signal_subscription.gd` (9 funcs, GUT-green 9/9)
- [x] **AC-42** (Falsifiable Test #3 + FR-3): GIVEN scenario: skip `workout_started`; directly emit `set_logged` + `workout_completed` (mock #2/#3/#11/#14/#9), WHEN observe full 5-system anti-fabrication chain, THEN boss NOT spawned; loot NOT dropped; `set_progress` stays 0; `Stat.apply_stat_delta` NEVER invoked. Any reward without workout = anti-fabrication chain failure. — EC-01/EC-02 guards (`_on_set_logged` / `_on_workout_completed`); `test_anti_fabrication_chain.gd` (4 funcs, GUT-green)
- [ ] **AC-40** *(ADVISORY — Manual playtest, DEFERRED to VS playtest)* (Falsifiable Test #1 + FR-1): GIVEN playtester pool (leg-dominant / push-dominant / pull-dominant / mixed workouts), WHEN play Mirror Hero 30 min without menu labels, THEN ≥ 70% report distinct fight-feel differences by class. VS-tier: n ≥ 2 ADVISORY; MVP gate: n ≥ 8 BLOCKING. Evidence: `production/qa/evidence/wst_blind_playtest.md`.

---

## Implementation Notes

- **Signal subscription** — Story 012 wires 7 #2 GymSysBackendClient signals via a `_connect_gym_sys_signals()` helper driven by an untyped `_gym_sys_client` DI seam (project convention — typed Node rejects RefCounted doubles via `Object.set()`). Null-safe no-op until the #2 GymSysBackendClient autoload exists. ADR-0006 Contract 6 `connect_for_initial_state` is used only for the #1 GSM `state_changed` subscription (already wired in Story 002); #2 workout signals are event-stream signals (not initial-state), so direct `.connect` is correct.
- **`_on_rest_started(_duration_seconds: int = 0)`** — param added to satisfy the ADR-0002 `rest_started(duration_seconds: int)` Locked contract; WST ignores the value (GymSys owns the rest timer per ADR-0006 Decision #3).
- **Anti-fabrication guard** — all 5 systems (#2→#3→#11→#14→#9) honor closed-API + truth-gate posture. AC-42 tests the failure path: events bypassing `workout_started` are dropped by WST's EC-01/EC-02 guards before any stat/loot/boss effect.
- **AC-40 playtest** — solo dev scenario: sessions covering all 4 class types. Document qualitative fight-feel observations. No automation path. DEFERRED to VS/MVP playtest milestone.

---

## Out of Scope

- Live #2 subscription against the *real* GymSys backend (HTTPRequest transport, CORS, `X-Session-Token`) — VS-tier-gated.
- Internal WST logic already tested in Stories 001-010 (FSM, set_progress, dominant_class, persistence) — not re-implemented here.
- Production assignment of `_gym_sys_client = GymSysBackendClient` in `_ready()` — deferred until the #2 GymSysBackendClient epic ships its autoload.

---

## QA Test Cases

### AC-01 — 7-signal subscription (Rule 1) [DONE — GUT 9/9]
```
Given: WorkoutStateTracker with FakeGymSysClient (7 Locked signals) injected; _connect_gym_sys_signals() called
When:  inspect each signal's connection to the matching _on_* handler (Signal.is_connected)
Then:  subscribed to exactly: workout_started, set_logged, rest_started, rest_ended,
       workout_completed, poll_failed, poll_recovered
       any missing signal → assert fail
Edge:  null client → _connect_gym_sys_signals() is a graceful no-op (behavioural test: re-inject + emit drives WARM_UP)
```

### AC-42 — 5-system anti-fabrication chain (Falsifiable Test #3) [DONE — GUT 4/4]
```
Given: FakeGymSysClient + FakePersistenceLayer + FakeStatSystemSpy injected into WST
       SKIP workout_started — emit set_logged + workout_completed via the live wiring
When:  observe the full chain
Then:  set_progress stays 0 (WorkoutStateTracker.get_set_progress() == 0.0)
       Stat.apply_stat_delta NEVER invoked (spy apply_delta_count == 0)
       no workout_summary_available emitted (no loot path)
       no workout_completed_forwarded emitted (no boss/loot trigger)
       phase stays IDLE (EC-01/EC-02 drop)
Note:  controlled-env integration test, events emitted through the Story 012 wiring path
```

### AC-40 — blind dominant_class playtest [Manual ADVISORY — DEFERRED]
```
Manual verification steps:
1. Recruit playtesters: sessions covering leg-dominant, push-dominant, pull-dominant, mixed
2. Each plays Mirror Hero 30 min WITHOUT seeing menu/class labels
3. Collect free-text descriptions of "fight feel" after session
Pass: >= 70% report leg/push/pull sessions feel noticeably different from each other
Gate: VS-tier n >= 2 ADVISORY; MVP gate n >= 8 BLOCKING (per CD F-11)
Evidence path: production/qa/evidence/wst_blind_playtest.md
Deferred: requires players + full build — DEFERRED to VS/MVP playtest milestone
```

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/core/workout_state_tracker/test_live_signal_subscription.gd` (AC-01, 9 funcs) + `test_anti_fabrication_chain.gd` (AC-42, 4 funcs) — both exist + GUT-green.

**Local GUT run 2026-05-31** (Godot 4.6.2 + GUT 9.6.0): full WST integration folder PASS — Story 012 = 13/13. CI GUT gate (Godot 4.6.0) is the authoritative gate; verified on next push.

**Advisory evidence**: `production/qa/evidence/wst_blind_playtest.md` (manual playtest, DEFERRED to VS-tier).

**Status**: [x] Complete (mock-scoped) — AC-01 + AC-42 automated + GUT-green; AC-40 DEFERRED.

---

## Completion Notes

**Completed 2026-05-31** (mock-scoped). Code review: APPROVE.

**Implementation** (`src/autoload/workout_state_tracker.gd`):
- Untyped `_gym_sys_client` DI seam.
- `_connect_gym_sys_signals()` + `_disconnect_gym_sys_signals()` — null-safe; wire/unwire exactly the 7 Locked ADR-0002 signals.
- `_on_rest_started(_duration_seconds: int = 0)` param to match ADR-0002 contract.
- `_ready()` TODO replaced with `_connect_gym_sys_signals()` call. Production path never references the not-yet-existing `GymSysBackendClient` global name.

**Bug found + fixed during local GUT run**: `test_anti_fabrication_chain.gd`'s `FakeStatSystemSpy` originally overrode `has_signal()` / `has_method()` — Godot 4.6 treats overriding a native `Object` method as a warning-as-error, so the whole file parse-failed and GUT silently skipped it (AC-42 would have been a phantom pass in CI). Removed the overrides; built-in `has_method()` auto-detects class-body methods. Re-ran: file loads + passes. (Logged to dev-environment memory.)

**Gates / caveats**:
- **AC-40** DEFERRED to VS-tier playtest (ADVISORY — needs players + full build).
- **Live transport still VS-tier-gated**: mock-scoped only. Real GymSys subscription verified when ADR-0002 reaches *fully* Accepted.
- One non-blocking minor (deferred): "exactly 7 — no extra subscription" defensive assertion not separately tested; an 8th connection would need an 8th declared signal → compile error in the fake, so risk is negligible.

---

## Dependencies

- Depends on: Stories 001-010 Complete; ADR-0002 data contract Locked (Accepted — data contract); Story 011 BLOCKED but unrelated (011 needs real #14 + live transport; 012 is mock-scoped — proceeded per dependency-risk [A]).
- Unlocks: WST epic 11/12 Complete. Full epic DoD (all 43 ACs) still pending Story 011 (#14 EnemyDirector + ADR-0002 live transport).
