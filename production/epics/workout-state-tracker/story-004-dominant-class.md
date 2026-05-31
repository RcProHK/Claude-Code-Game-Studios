# Story 004: dominant_class Derivation + Hysteresis + VS Stub

> **Epic**: Workout State Tracker
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/workout-state-tracker.md`
**Requirements**: `TR-wst-009`, `TR-wst-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation (primary)**: ADR-0007: Class & Domain Enum Convention
**ADR Decision Summary**: `AbilityClass { STRIKE, CONTROL, MOBILITY, UNKNOWN }` declaration order is LOCKED (ordinals 0/1/2/3). `UNKNOWN` is always last (sentinel). Zero-default fabrication of `STRIKE` (ordinal 0) is FORBIDDEN. Canonical enum shared across #9/#11/#12/#14/#15 — a second declaration is a CI error.

**Secondary ADR**: ADR-0006: State Machine Contract (transition_id, boot order)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `find_key()` for enum-to-string serialization (stable 4.4+). `StringName` (`&"UNKNOWN"`) stable since Godot 4.0.

**Control Manifest Rules (Core layer)**:
- Required: `AbilityClass` is the ONE canonical class enum — import the shared definition, never re-declare (ADR-0007)
- Required: `get_dominant_ability_class()` returns `AbilityClass.UNKNOWN` explicitly when undetermined — never rely on zero-default (ADR-0007 + GDD Rule 16 NEVER #3)
- Required: AC-10 cooldown test uses injectable time-source seam (untyped Node DI per project DI convention)
- Forbidden: `AbilityClass` member named `NEUTRAL` (retired — valid only as `ClassTag.NEUTRAL`) (ADR-0007)
- Forbidden: Zero-default `var x: AbilityClass` — silent STRIKE fabrication (ADR-0007 Family B)

---

## Acceptance Criteria

*From GDD `design/gdd/workout-state-tracker.md`, scoped to this story:*

- [ ] **AC-10** (Rule 5 + EC-21 + Knob `DOMINANT_CLASS_CHANGE_COOLDOWN_S=30s`): GIVEN `dominant_class == MOBILITY` + last change time = T (injected clock), WHEN STRIKE-dominant set count arrives within 30s, THEN `dominant_class_changed` NOT emitted; only after T+30s re-evaluate; INV-4 violation → assert fail.
- [ ] **AC-13** (Rule 5 + CI-3): GIVEN `set_logged` with `exercise_id` not in #10 stub mapping, WHEN compute `dominant_class`, THEN that set skipped in `set_counts` tally; full workout all-UNKNOWN exercises → `get_dominant_ability_class()` returns `&"UNKNOWN"`; WST NEVER fallbacks to STRIKE.
- [ ] **AC-18** (Formula 3 + tiebreak): GIVEN 8-set history (Section D Example): PUSH(squat)=3, CONTROL(row)=3, MOBILITY(lunge)=2 chronological, WHEN compute `dominant_class`, THEN returns `STRIKE` (reverse-walk finds solo leader at i=6); if `previous_dominant_class == null` + full 3-way tie with no prior solo leader → return `&"UNKNOWN"` (NOT alphabetical, NOT STRIKE).
- [ ] **AC-28** (CI-3 — narrowed to #9 surface): GIVEN WST returns `&"UNKNOWN"` per AC-13, WHEN WST emits `dominant_class_changed`, THEN WST signal spy confirms emitted value == `&"UNKNOWN"`, NEVER `STRIKE`. (Note: `#14 internal fallback activates STRIKE` is #14's EC-09 responsibility — DEFERRED to #14 integration test.)
- [ ] **AC-43** (FR-2 VS-tier stub): GIVEN VS-tier inline stub `{bench_press: STRIKE, row: CONTROL, squat: MOBILITY}`, WHEN feed 20 `exercise_id`s (3 in-stub + 17 out-of-stub), THEN in-stub correctly classified; all 17 out-of-stub return `&"UNKNOWN"` (zero hallucination, NEVER guess STRIKE).

---

## Implementation Notes

*Derived from ADR-0007 + GDD Rule 5 + Formula 3 specs:*

- **Formula 3 algorithm** (deterministic, no randomness):
  1. Build `set_counts = {STRIKE: 0, CONTROL: 0, MOBILITY: 0}` from `set_history`. Skip `UNKNOWN` exercises.
  2. `max_count = max(set_counts.values())`. If `max_count == 0` → return `&"UNKNOWN"`.
  3. `leaders = [class for class if set_counts[class] == max_count]`.
  4. If `|leaders| == 1` → return `leaders[0]`, update `previous_dominant_class`.
  5. If `|leaders| > 1` (tie) → walk `set_history` reverse-chronologically, find last index `i` where one leader class has a STRICT solo max. Return that class.
  6. If walk finds no solo leader → return `previous_dominant_class` (sticky). If null → return `&"UNKNOWN"`.
- **`_cached_dominant_class`** — updated synchronously inside `_on_set_logged` handler (NOT `call_deferred`) to avoid 1-frame staleness for #14 4Hz tick reads.
- **`dominant_class_changed`** — emit ONLY when returned value genuinely flips. Apply 30s cooldown via injectable `_get_now_ms()` seam (untyped Node, per project DI convention). Do NOT emit on each `set_logged`.
- **VS-tier stub** — inline 3-exercise map: `{"bench_press": AbilityClass.STRIKE, "row": AbilityClass.CONTROL, "squat": AbilityClass.MOBILITY}`. All other `exercise_id`s → `AbilityClass.UNKNOWN`. Replaced by #10 ExerciseClassMapping when that epic is designed.
- **`AbilityClass` enum** — import the project's shared declaration. DO NOT re-declare. A second declaration of `STRIKE|CONTROL|MOBILITY` is a CI error.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: WorkoutPhase FSM (prerequisite)
- [Story 005]: `get_dominant_ability_class()` public API surface + immutability
- [Story 011]: CI-3 cross-system integration test (#14 fallback assertion — DEFERRED)

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these exactly.*

### AC-10 — dominant_class cooldown hysteresis (EC-21)
```
Given: dominant_class == MOBILITY; last_change_time == T (inject clock via seam)
When:  STRIKE-dominant set count arrives at T+10s (within 30s cooldown)
Then:  dominant_class_changed NOT emitted
When:  advance injected clock to T+30s+ and re-evaluate
Then:  change permitted; dominant_class_changed emitted
Edge:  INV-4 — emit before T+30s is assert fail
Note:  use injectable _get_now_ms() seam (untyped Node DI), NOT wall-clock
```

### AC-13 — UNKNOWN honest return (CI-3)
```
Given: set_logged with exercise_id NOT in #10 stub
When:  compute dominant_class
Then:  that set skipped in set_counts tally (count unchanged for all classes)
Given: full workout all-UNKNOWN exercises
When:  get_dominant_ability_class()
Then:  returns &"UNKNOWN" (NEVER STRIKE)
Edge:  log WST_ALL_UNKNOWN_001 at WARN with payload workout_id + set_count (EC-19)
```

### AC-18 — Formula 3 tiebreak walk
```
Given: 8-set chronological history from GDD Section D:
       [squat(STRIKE), row(CONTROL), bench(STRIKE), lunge(MOBILITY),
        deadlift(CONTROL), press(STRIKE), curl(CONTROL), calf(MOBILITY)]
       set_counts = {STRIKE:3, CONTROL:3, MOBILITY:2}
When:  compute dominant_class
Then:  returns STRIKE (reverse-walk i=8..1; at i=6 STRIKE has solo lead {S:3,C:2,M:1})

Given: full 3-way tie AND previous_dominant_class == null
When:  resolve() reaches case 4 (no prior solo leader found)
Then:  returns &"UNKNOWN" (NOT STRIKE, NOT alphabetical)
Edge:  per EC-20, first-set scenario can never reach case 4 (one set = one class unambiguous)
```

### AC-28 — WST never fabricates STRIKE fallback (CI-3) [#9 surface only]
```
Given: WST returns &"UNKNOWN" per AC-13 (all-UNKNOWN workout)
When:  WST emits dominant_class_changed
Then:  signal spy confirms emitted value == &"UNKNOWN", NEVER STRIKE
Deferred: "#14 internal fallback activates STRIKE" is #14 EC-09 behavior — DEFERRED to #14 integration test
```

### AC-43 — VS-tier stub classification boundary (FR-2)
```
Given: VS-tier inline stub {bench_press:STRIKE, row:CONTROL, squat:MOBILITY}
When:  feed 20 exercise_ids (bench_press, row, squat + 17 others)
Then:  bench_press → STRIKE; row → CONTROL; squat → MOBILITY (correct)
       all 17 out-of-stub → &"UNKNOWN" (zero hallucination)
Edge:  empty exercise_id / null → &"UNKNOWN" (no crash)
Edge:  UNKNOWN exercise → set_counts NOT incremented (never contributes to any class tally)
```

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/workout_state_tracker/test_dominant_class.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/core/workout_state_tracker/test_dominant_class.gd`

---

## Dependencies

- Depends on: Story 001 (WorkoutPhase FSM) must be DONE
- Unlocks: Story 005 (RO API surfaces `get_dominant_ability_class()`), Story 011 (DEFERRED CI-3 integration)

---

## Completion Notes
**Completed**: 2026-05-30
**Criteria**: 5/5 passing (AC-18 case 2 proven via defensive path — mathematically unreachable in production per first-set invariant)
**Deviations**:
- ADVISORY: AC-18 3-way-tie "no prior solo leader" test uses `_resolve_tiebreak` directly with empty history (production unreachable path). QL-TEST-COVERAGE confirmed adequate.
- ADVISORY: EC-19 WST_ALL_UNKNOWN_001 log moved from _update_dominant_class (was dead code) to _on_workout_completed — spec-aligned improvement
**Test Evidence**: Logic — `tests/unit/core/workout_state_tracker/test_dominant_class.gd` (14 tests)
**Code Review**: Complete (APPROVED WITH SUGGESTIONS — all fixes applied)
