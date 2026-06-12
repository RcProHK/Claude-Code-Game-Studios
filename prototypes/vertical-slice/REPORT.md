# Vertical Slice Report — Mirror Hero (Production Sprint 1, VS-2)

> **Date**: 2026-06-12
> **Type**: Mock-fed end-to-end loop-chain proof (technical half of the Pre-Prod→Prod vertical-slice gate)
> **Harness**: `prototypes/vertical-slice/vertical_slice_harness.gd` (standalone SceneTree script)
> **Run**: `godot --headless --path . --script prototypes/vertical-slice/vertical_slice_harness.gd` → **EXIT 0**
> **Verdict**: **PROCEED (technical) — with 1 discovered blocker to close + experiential validation deferred to Milestone 1**

## What this slice IS and IS NOT

- **IS**: proof that the core-loop **signal chain** is achievable end-to-end through the REAL autoload graph (28 autoloads boot + coexist; a mock workout drives the downstream chain). No live GymSys backend, no game scene, no real sprites needed — drives the loop at its real signal seams.
- **IS NOT**: a playable build or a fun/feel validation. The **experiential half** of the vertical-slice gate ("is the mid-set glance watchable? is the loot worth returning for?") requires real art + a real workout + a human — that is **Milestone 1** (`production/milestones/milestone-01-premvp-hypothesis.md`), human-gated.

## Harness trace (actual run output)

```
[BOOT]    10/10 core autoloads present
[OBSERVE] downstream observers wired
[DRIVE]   FakeGymSysClient injected + wired
    ↳ dominant_class_changed       new_class=0   (#10 exercise→class derive)
    ↳ loot_dropped                 rarity=UNCOMMON type=WEAPON
                                   tid=…_WORKOUT_ACTIVE_LOOT_DROP   (#15 Pillar 3 — fired NATURALLY)
    ↳ loot_disabled                reason=persistence_unavailable
    ↳ workout_completed_forwarded  completed_at=1749700000
[DRIVE]   WST phase=4 dominant_class=0 completed_exercises=2
[LOOT]    EnemyDirector.enemy_killed emitted (boss-kill sim)
PASS: workout→WST entry spine fired through real autoloads
```

## ✅ What fired (loop is wired)

| Chain link | Evidence | Pillar |
|------------|----------|--------|
| GymSys(mock) → WorkoutStateTracker entry wiring | `workout_completed_forwarded` fired with completed_at + transition_id | 1 |
| WST exercise → dominant class derivation (#10) | `dominant_class_changed` fired | 4 |
| Workout → GSM WORKOUT_ACTIVE→LOOT_DROP → loot (#15) | `loot_dropped` fired **naturally** (UNCOMMON WEAPON) — the workout itself produced loot via the real GSM transition, not a forced call | 3 |
| 28-autoload graph boots + coexists | 10/10 core autoloads present, no crash | — |

> The most important positive: **a mock workout, fed only at the GymSys seam, produced a real loot drop through the GSM transition chain** — the Pillar-1→Pillar-3 spine auto-propagates through the shipped autoloads without any hand-holding.

## ✅ Discovered blocker — FOUND **and FIXED** this session (this is what a vertical slice is FOR)

**`assets/data/exercise_registry.tres` was MISSING from the repo — now authored + verified.**

> **Resolution (2026-06-12)**: authored `assets/data/exercise_registry.tres` (30 exercises, 10 per class)
> from the `design/gdd/exercise-class-mapping.md` 1:1:1 spine (push→STRIKE / pull→CONTROL / leg→MOBILITY).
> Re-ran the harness: **`registry loads (no missing error)`** + **`[CLASS-MAP] bench_press=0(STRIKE)
> deadlift=1(CONTROL) squat=2(MOBILITY) → REAL MAPPING ✓`** (the non-zero deadlift/squat results prove a
> real mapping, not the UNKNOWN/default fallback). Full combined GUT gate re-run after the fix:
> **440 scripts / 2969 tests / 2966 passing / 0 failing / 3 honest pending — zero regression** (ECM going
> FAILED→READY at boot broke nothing; unit tests inject their own mock registry).

**Original finding (kept for the record):**
- `ExerciseClassMapping._REGISTRY_PATH = "res://assets/data/exercise_registry.tres"` (exercise_class_mapping.gd:67). On boot it logged: *"registry missing or corrupt … all lookups will return UNKNOWN"*.
- Consequence: **Pillar 4 (Muscle = Class) is silently degraded in the real build** — every exercise maps to UNKNOWN, so the `dominant_class=0` observed is the **default fallback, not a real push→STRIKE mapping**.
- **Why CI is green anyway (phantom-green)**: the exercise-class-mapping tests inject a mock registry via the `_registry_loader` seam (set before tree entry), so the missing shipped `.tres` never trips the 2861-test suite. This is the classic "tests mock the data, so the missing production asset is invisible to CI" trap — exactly the integration gap an isolated test suite cannot catch and a vertical slice can.
- **Fix**: author `assets/data/exercise_registry.tres` from the canonical exercise→class table in `design/gdd/exercise-class-mapping.md` (push→STRIKE / pull→CONTROL / leg→MOBILITY). Tracked in `production/risk-register/external-gates.md`.

## ⚠️ Observed-but-expected (not bugs)

| Observation | Why it's expected |
|-------------|-------------------|
| `loot_disabled reason=persistence_unavailable` | Headless run has no real persistence backend; LootDrop defensively disables. A live build (Line A) has IndexedDB/backend. |
| `avatar_visual_updated` / `avatar_evolution_milestone` did NOT fire | A single mock workout does not cross an evolution-tier milestone (#26). Avatar evolution needs accumulated progression — correct behaviour. |
| `ceremony_presented` (Mirror Moment) did NOT fire | #29 ceremony is gated on weekly cadence + a non-workout state; a single in-workout session won't trigger it — correct behaviour. |
| `stat.str/dex/vit absent → default 10.0` | Fresh headless StatSystem has no persisted stats; defaults are correct. |

> The avatar (#26) and Mirror Moment (#29) links are therefore **NOT exercised by this single-session harness** — they require multi-session progression / weekly cadence. They are proven instead by their dedicated integration suites (see traceability map).

## Traceability map — full loop link → proving evidence

| Loop link | Proven by |
|-----------|-----------|
| GymSys → WST (anti-fabrication + forwarding) | this harness + `tests/integration/core/workout_state_tracker/test_anti_fabrication_chain.gd` |
| Exercise → class (#10) | `tests/unit/exercise_class_mapping/*` (⚠️ via MOCK registry — shipped .tres missing, see blocker) |
| Stat deltas (#11) → Avatar (#26) | `tests/integration/avatar_renderer/*` |
| Combat resolve → enemy_killed (#13/#14) | `tests/integration/enemy_director/*`, `tests/integration/combat/*` |
| enemy_killed → loot_dropped (#15) | this harness (seam emit) + `tests/integration/loot/*` |
| loot → reveal ceremony (#21) | `tests/integration/loot_reveal/*` |
| avatar evolution → Mirror Moment (#29) | `tests/integration/mirror_moment/*` (weekly cadence) |

## Verdict

**PROCEED (technical wiring confirmed).** The full core-loop signal chain is achievable end-to-end through the real autoload graph; a mock workout produces real loot; class derivation now maps correctly. One gate remains before the slice is "done" in the full gate sense:

1. ~~Close the discovered blocker~~ — **DONE** this session: `exercise_registry.tres` authored + verified; Pillar 4 class derivation now works in the real build (deadlift→CONTROL, squat→MOBILITY); full gate green / zero regression.
2. **Experiential validation = Milestone 1** — real art (Line C) + real/mocked workout + a human, to answer the watchability + return-value hypotheses. This harness cannot and does not claim the loop is *fun* — only that it is *wired*. **This is the only remaining gate, and it is human-gated.**
