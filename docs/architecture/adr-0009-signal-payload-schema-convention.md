# ADR-0009: Signal Payload Schema Convention

## Status
Proposed

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (signals + serialization) |
| **Knowledge Risk** | MEDIUM — typed signal parameters + `Resource` subclass serialization behaviour shifted across 4.4/4.5 |
| **References Consulted** | `src/core/state_transition_payload.gd`; `src/core/boss_payload.gd`; ADR-0006 Contract 2 (transition_id) + Contract 3 (envelope); `docs/registry/architecture.yaml` (SerializableResource, payload_type stances); `design/gdd/loot-drop-system.md` §7.5 (workout_id resolution) |
| **Post-Cutoff APIs Used** | `get_script().get_global_name()` for payload type tagging (relied on by Contract 3); typed `signal` parameter declarations |
| **Verification Required** | Payload round-trip already green (224/224); confirm any new payload subclass round-trips via its `to_dict`/`from_dict` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0006 (Contract 2 transition_id, Contract 3 SerializableResource envelope); ADR-0007 (enum string-name serialization for enum-carrying payloads) |
| **Enables** | Consistent signal contracts across #9 / #14 / #15 / #16 / #29; LootDrop §7.5 workout_id resolution; future per-system signal authoring |
| **Blocks** | Stories that define new cross-system signals carrying structured payloads |
| **Ordering Note** | MEDIUM. Closes architecture-review GAP-003 (signal payload schema convention; workout_id late-binding from #15 Pass 2 F-12). |

## Context

### Problem Statement
Cross-system signals carry payloads in several shapes with no governing convention.
The concrete defect that surfaced this (#15 LootDrop Pass 2 F-1/F-12): `boss_killed`
and `enemy_killed` payloads carry `(transition_id, boss_id|faction, tier)` but **not**
`workout_id`, yet LootDrop's ceremony-cap key needs `workout_id`. The two reasonable
responses are (a) stuff `workout_id` into every combat payload, or (b) have the
handler late-bind it from `WorkoutStateTracker.get_active_workout_id()`. Without a
ruling, every system answers differently — producing fat, redundant payloads in some
places and silent `null` assumptions in others (the exact bug INV-12 guards against).

There is also no single rule for: which payloads must be typed `SerializableResource`
envelopes vs plain Dictionaries; how payload type is tagged for forward-recovery; and
how signals/fields are named.

### Constraints
- Any Resource subclass embedded in a persisted payload MUST extend
  `SerializableResource` (registry binding, ADR-0006 Contract 3) and tag its type via
  `get_script().get_global_name()` — `Object.get_class()` is FORBIDDEN (returns
  `"Resource"`, breaks forward-recovery).
- WASM is single-threaded; signal handlers run on the main thread and may fire during
  an in-flight GSM transition (re-entrancy guarded by Contract 1).
- `transition_id` is the opaque correlation key already threaded through GSM/loot/boss
  events (Contract 2).

### Requirements
- One rule for payload **shape** (typed envelope vs Dictionary).
- One rule for **what a payload carries** vs what a handler resolves.
- One rule for **type tagging** and **naming**.

## Decision

### 1. Payloads are MINIMAL + intrinsic
A signal payload carries only (a) the event's **intrinsic** data and (b) the
`transition_id` correlation key. It does NOT carry **cross-cutting ambient context**
that the receiver can resolve itself (e.g. active workout, current GSM state, current
zone). Rationale: ambient context drifts and duplicates; threading it through every
payload couples unrelated producers to it.

### 2. Cross-cutting context is LATE-BOUND at the handler, with explicit null branch
A handler needing ambient context queries the owning system's read API at handle
time, and MUST branch explicitly on the null/absent case — never assume non-null:

```gdscript
func _on_boss_killed(p: BossKilledPayload) -> void:
    var wid: Variant = WorkoutStateTracker.get_active_workout_id()  # String | null
    if wid == null:
        _route_non_ceremony(p)          # explicit: no active workout
    else:
        _route_ceremony(p, wid)         # active workout context
```
This is the LootDrop §7.5 / INV-12 rule, generalised. CI-enforceable
(`check_loot_workout_id_resolution.gd` is the prototype; future handlers follow it).

### 3. Structured / persisted payloads are typed `SerializableResource` envelopes
- A payload that is persisted (tombstone, loot.pending, etc.) **or** carries a typed
  sub-object MUST be a `SerializableResource` subclass with `to_dict()` / `from_dict()`
  and a `payload_type` set via `get_script().get_global_name()`.
- Enum fields inside payloads serialize as **string names** per ADR-0007
  (`EnumType.find_key` / `EnumType.get(name, SENTINEL)`).
- A purely transient, never-persisted signal MAY use primitive typed args directly
  (e.g. `pr_breakthrough(lift: StringName, magnitude: float)`), but if it ever needs
  persistence it is promoted to an envelope (no Dictionary-with-magic-keys middle ground).

### 4. Naming
- **Signals**: `snake_case`, past tense — `workout_completed`, `boss_killed`,
  `ability_unlocked`, `loot_dropped`.
- **Payload classes**: `PascalCase` + `Payload` suffix — `StateTransitionPayload`,
  `BossPayload`, `BossKilledPayload`.
- **Payload fields**: `snake_case`. Every payload carries `transition_id: String`
  when it participates in a GSM-correlated flow; carries `source_event: String` when
  delivered through `state_changed` (sentinel detection, Contract 6).

### Key Interfaces
```gdscript
# Envelope base (existing)
class_name SerializableResource extends Resource
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> SerializableResource

# Correlation key on every cross-system structured payload
var transition_id: String

# Late-binding resolver shape (per owning system)
func get_active_workout_id() -> Variant   # String | null  — caller MUST null-branch
```

## Alternatives Considered

### Alternative 1: Fat payloads — every payload carries all context it might need
- **Description**: Add `workout_id`, current state, zone, etc. to each combat/loot payload.
- **Pros**: Handlers never query; self-contained.
- **Cons**: Couples every producer to ambient systems; duplicated/stale fields; payload schema churns whenever a new consumer wants new context.
- **Rejection Reason**: Drift + coupling; INV-12 explicitly forbids assuming such fields are present.

### Alternative 2: Dictionary payloads with documented keys
- **Description**: Pass `Dictionary` with string keys instead of typed classes.
- **Pros**: Flexible, no class boilerplate.
- **Cons**: No type checking; magic-string keys; loses enum typing on round-trip (ADR-0006 already rejected this for `BossOutcome`); debug-hostile.
- **Rejection Reason**: Same reasons ADR-0006 chose `SerializableResource` over raw Dict.

### Alternative 3: Global event bus with untyped Variant payloads
- **Description**: One signal `event(name, data)` for everything.
- **Pros**: Minimal signal surface.
- **Cons**: Erases type safety, makes `connect_for_initial_state` typed delivery impossible, hides contracts.
- **Rejection Reason**: Contradicts GSM Contract 6 typed delivery + project typed-signal idiom.

## Consequences

### Positive
- Payloads stay small + typed; the workout_id class of bug (silent null) is
  structurally prevented by the explicit-branch rule.
- One serialization story (`SerializableResource` + string-name enums) across all
  persisted payloads.
- Clear authoring checklist for every new signal.

### Negative
- Handlers needing ambient context must write the late-bind query + null branch
  (slightly more code than reading a payload field) — accepted for correctness.
- Producers must expose a read API for any context other systems late-bind (e.g.
  `get_active_workout_id()`), which is a small interface obligation.

### Risks
- **Risk**: A handler forgets the null branch and assumes an active workout.
  **Mitigation**: CI lint pattern (`check_loot_workout_id_resolution.gd` generalised);
  INV-12-style invariant per consuming GDD.
- **Risk**: A transient signal later needs persistence and is retrofitted awkwardly.
  **Mitigation**: rule §3 — promote to envelope rather than bolt on a Dictionary.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| loot-drop-system.md | §7.5 / INV-12: every `boss_killed`/`enemy_killed` handler queries `get_active_workout_id()` with explicit null branch | Generalises this into the late-binding rule (§2) |
| workout-state-tracker.md | Provides `workout_completed(workout_id, completed_exercises)` + `get_active_workout_id()` | Confirms #9 owns the ambient-workout read API |
| game-state-machine.md | `state_changed(from, to, payload: StateTransitionPayload)`; `source_event` sentinel | Payload-envelope + naming rules ratify the existing contract |
| boss-system.md | `boss_killed` carries `(transition_id, boss_id, tier)`; BossPayload outcome | Minimal-payload + typed-envelope rules apply |
| mirror-moment-system (future #29) | Composes weekly snapshots from correlated events | Inherits transition_id correlation + envelope rules |

## Performance Implications
- **CPU**: One extra read-API call per handler that late-binds context — negligible, off hot paths.
- **Memory**: Smaller payloads than the fat-payload alternative.
- **Load Time / Network**: None.

## Migration Plan
1. Existing payloads (`StateTransitionPayload`, `BossPayload`) already comply — no change.
2. New cross-system signals follow the checklist (minimal + transition_id; late-bind
   ambient context; envelope if persisted/typed; naming).
3. LootDrop §7.5 is already the reference implementation; no migration there.

## Validation Criteria
- Grep: no persisted payload uses `Object.get_class()` for type tagging (forbidden-pattern lint already exists).
- Every handler that needs ambient context has an explicit null branch (CI lint per consuming system).
- Round-trip test for each new `SerializableResource` payload subclass.
- No new signal carries a duplicated ambient field that a read API already exposes.

## Related Decisions
- ADR-0006 (State Machine Contract) — Contract 2 (transition_id) + Contract 3 (envelope) are the substrate.
- ADR-0007 (Class & Domain Enum Convention) — enum string-name serialization inside payloads.
- ADR-0005 (Loot Rarity Formula) — consumes correlated `transition_id` payloads.
