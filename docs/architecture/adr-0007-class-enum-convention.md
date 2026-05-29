# ADR-0007: Class & Domain Enum Convention

## Status
**Accepted 2026-05-29** (ratified via `/architecture-review ratify` — cross-ADR conflict scan clean; engine audit clean (Godot 4.6, `find_key`/`get` post-cutoff APIs verified 224/224 green); no dependencies. Closes GAP-001.)

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | MEDIUM — enum reflection APIs (`Object.find_key`, `Dictionary.get`) shifted across 4.4/4.5 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0006 §Contract 3 (line 205 `find_key` binding); `src/autoload/game_state_machine.gd` (GameState); `src/core/boss_payload.gd` (BossOutcome) |
| **Post-Cutoff APIs Used** | `NamedEnum.find_key(value)` (enum int → key String; Godot 4.4+) and `NamedEnum.get(key, default)` (key String → int) — both used for string-name serialization of enums |
| **Verification Required** | `find_key()` returns `null` (not error) for out-of-range int — confirmed in `boss_payload.gd:118` conservative fallback. Already exercised by 224/224 green suite. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (codifies conventions already proven in ADR-0006-governed code) |
| **Enables** | ADR-0009 (signal payload schema reuses the string-name serialization rule); VS-tier implementation of #9 / #10 / #12 / #13 / #14 / #15 (Class-tagged systems) |
| **Blocks** | Any story implementing `AbilityClass` consumption across #9 WorkoutStateTracker, #10 Exercise→Class Mapping, #12/#13 Ability/Combat, #14 EnemyDirector, #15 LootDrop — cannot start until the canonical enum identity + 4th-member name is locked |
| **Ordering Note** | HIGH / pre-VS. Closes architecture-review GAP-001 (STRIKE/CONTROL/MOBILITY naming not locked cross-system). |

## Context

### Problem Statement
Six systems (#9, #10, #12, #13, #14, #15) all reference a "muscle → class" archetype
dimension, but the enum is not locked. Two divergences exist in the registries:

- **#9 WorkoutStateTracker** `get_dominant_ability_class()` output is documented as
  `{STRIKE, CONTROL, MOBILITY, UNKNOWN}` (`design/registry/entities.yaml:668`).
- **#15 LootDrop** class-affinity Formula E2 output is documented as
  `{STRIKE, CONTROL, MOBILITY, NEUTRAL}` (`entities.yaml:801`).

The same conceptual "no specific class" position is named **UNKNOWN** in one system
and **NEUTRAL** in another. Without a locked convention, six teams will implement
divergent enums, breaking the `enum int ↔ String` serialization round-trip that
ADR-0006 Contract 3 and ADR-0005 loot formulas depend on, and undermining the
Pillar 1 anti-fabrication guarantee (#9 must NEVER silently fall back to STRIKE).

Two enum *patterns* already exist in verified Foundation code and must be
reconciled into one convention:

- `GameState` (game_state_machine.gd) — a **state** enum; BOOTING=0 is the
  load-bearing pre-reconciliation default.
- `BossOutcome` (boss_payload.gd) — an **outcome** enum; ABANDONED=0 is the
  conservative fail-safe (an uninitialised payload never grants loot).

Both place the "safe / uninitialised" value at ordinal 0. But `AbilityClass`
declares STRIKE=0 (`entities.yaml:533` `class_ordinal {0,1,2}`), and STRIKE is a
*real* class — relying on a zero-default would silently fabricate STRIKE,
violating Pillar 1. The convention must distinguish these two enum families.

### Constraints
- `entities.yaml` + Ability System Formula 3 (deterministic same-frame emit
  ordering) + EnemyDirector Formula 1 already assume STRIKE=0 / CONTROL=1 /
  MOBILITY=2 declaration order. Reordering would ripple through ~6 GDDs and break
  the documented worked examples (e.g. AC-18 tiebreak walk).
- Godot enums are plain ints; an unset `@export var x: AbilityClass` defaults to 0.
- Serialization must survive WASM reload as a **string name**, not an int
  (int ordinals are migration-fragile; ADR-0006 Contract 3 already mandates names).

### Requirements
- One canonical enum identity + member set for the class-archetype dimension.
- A rule that prevents zero-default fabrication for classification enums.
- A single string-name (de)serialization rule reused by all enum-carrying payloads.

## Decision

Adopt a **two-family enum convention**. Every project enum is classified as either
an **Outcome/State enum** or a **Classification enum**, and follows that family's
rules.

### Family A — Outcome / State enums (e.g. `GameState`, `BossOutcome`)
- **Ordinal 0 = the conservative / safe / uninitialised value.** An unset field
  must mean "nothing happened yet" (BOOTING, ABANDONED). Declaration order may
  carry persisted-migration meaning; do NOT renumber existing members.
- Used when a default-constructed value is a legitimate, safe runtime state.

### Family B — Classification enums (e.g. `AbilityClass`)
- **Declaration order is semantically load-bearing** (drives deterministic emit
  ordering / tiebreaks) and is locked by GDD worked examples — `STRIKE=0`,
  `CONTROL=1`, `MOBILITY=2`.
- **The non-committal sentinel is named `UNKNOWN` and placed LAST** (`UNKNOWN=3`).
  `NEUTRAL` is retired as an `AbilityClass` member name (see GDD sync below).
- **Zero-default reliance is FORBIDDEN.** Because ordinal 0 is a real class
  (STRIKE), a classification field must be explicitly initialised. Producers that
  cannot determine a class MUST return `UNKNOWN` explicitly (never default to 0).
  This is the Pillar 1 anti-fabrication guard (#9 EC; #14 EnemyDirector EC-09 owns
  any deliberate fallback, never #9).

### Canonical enum (locked)
```gdscript
## Class-archetype dimension — Pillar 4 (Muscle = Class). 1:1 with STR/DEX/VIT
## (push/pull/leg). Declaration order is load-bearing (Ability Formula 3 emit
## ordering, #9 tiebreak walk). UNKNOWN is the anti-fabrication sentinel — a
## producer returns it EXPLICITLY when no dominant class exists; consumers MUST
## NOT treat a zero-default as STRIKE.
enum AbilityClass { STRIKE, CONTROL, MOBILITY, UNKNOWN }  # 0,1,2,3
```

### Naming & serialization rules (both families)
- **Member names**: `UPPER_SNAKE_CASE`.
- **Enum type names**: `PascalCase` (`AbilityClass`, `GameState`, `BossOutcome`).
- **Serialize as String name**, never int: write `EnumType.find_key(value)`;
  on `null` (out-of-range), fall back to the family's sentinel
  (`UNKNOWN` / `ABANDONED` / `BOOTING`) — never to a "real" value.
- **Deserialize** via `EnumType.get(name_string, SENTINEL)` (unknown name →
  sentinel, never crash).
- This is exactly the round-trip already shipped in `boss_payload.gd:117-148`;
  ADR-0007 generalises it.

### Key Interfaces
```gdscript
# Producer (#9) — explicit sentinel, no zero-default fabrication
func get_dominant_ability_class() -> AbilityClass   # returns UNKNOWN, never STRIKE-by-default

# Serialization helper pattern (per to_dict/from_dict)
var name := AbilityClass.find_key(value)             # int -> "STRIKE" | null
var v    := AbilityClass.get(name, AbilityClass.UNKNOWN)  # "STRIKE" -> int | UNKNOWN
```

## Alternatives Considered

### Alternative 1: Put UNKNOWN at ordinal 0 (UNKNOWN=0, STRIKE=1…)
- **Description**: Make the sentinel the zero-default, matching the Family A pattern.
- **Pros**: A single uniform rule ("0 is always safe"); zero-default is automatically anti-fabrication-safe.
- **Cons**: Breaks `entities.yaml:533` `class_ordinal {0,1,2}`, Ability Formula 3 declaration-order emit, EnemyDirector Formula 1, and every GDD worked example assuming STRIKE=0; ~6 GDD + registry rewrite.
- **Rejection Reason**: Cost/ripple far exceeds benefit; the two-family rule captures the same safety with an explicit-init mandate instead.

### Alternative 2: Allow each system its own 4th-member name (UNKNOWN vs NEUTRAL)
- **Description**: Leave the status quo; document both terms as synonyms.
- **Pros**: Zero edits now.
- **Cons**: Divergent enums cannot round-trip through one serializer; cross-system signal payloads (#9 → #15) would carry incompatible int/name spaces; perpetuates GAP-001.
- **Rejection Reason**: Defeats the purpose of the ADR.

### Alternative 3: Serialize enums as ints
- **Description**: Persist ordinal ints directly.
- **Pros**: Compact.
- **Cons**: Migration-fragile (any reorder corrupts saves); debug-hostile in IndexedDB; contradicts ADR-0006 Contract 3 string-name rule.
- **Rejection Reason**: Already rejected by ADR-0006; reaffirmed here.

## Consequences

### Positive
- Six Class-tagged systems share one enum identity + serialization rule.
- Pillar 1 anti-fabrication is structurally enforced (no zero-default STRIKE).
- New enums get an unambiguous decision tree (Family A vs B) instead of ad-hoc choices.

### Negative
- `#15` LootDrop must rename its `NEUTRAL` affinity term to `UNKNOWN` (or document
  NEUTRAL as a *weight-distribution outcome* distinct from the `AbilityClass`
  identity it consumes) — a GDD edit, see Migration Plan.
- Classification enums lose the convenience of a safe zero-default; authors must
  remember the explicit-init mandate (mitigated by CI lint, see Validation).

### Risks
- **Risk**: A future author adds a classification enum with a real value at 0 and
  relies on the default. **Mitigation**: CI lint `check_classification_enum_zero_default.gd`
  (new, deferred) greps for classification-tagged enums whose 0 member is not a
  sentinel and flags any `@export` field without an explicit initialiser.
- **Risk**: `find_key` API behaviour drift in a future Godot patch. **Mitigation**:
  Verification Required row; covered by existing green tests.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| ability-system.md | FR-1: `class_id` enum stays `{STRIKE, CONTROL, MOBILITY}`, 1:1 STR/DEX/VIT, no hybrid class | Locks the 3 core members + declaration order as Family B |
| workout-state-tracker.md | Formula 3 outputs `{STRIKE, CONTROL, MOBILITY, UNKNOWN}`; never fabricates STRIKE | Mandates UNKNOWN sentinel + forbids zero-default fabrication |
| loot-drop-system.md | Formula E2 class-affinity consumes `#9.get_dominant_ability_class()`; EC-35 NULL → uniform fallback | Canonicalises the input enum to UNKNOWN; flags NEUTRAL rename |
| enemy-director.md | Rule 12 wave archetype reads `get_dominant_ability_class()`; EC-09 owns deliberate fallback | Confirms #14 (not #9) owns any STRIKE fallback |
| boss-system.md / combat-resolver.md | Consume class-tagged abilities (STRIKE_TIER_n etc.) | Inherit the locked enum + string-name serialization |

## Performance Implications
- **CPU**: Negligible. `find_key`/`get` are O(members)=O(4) lookups, off hot paths (boot, transition, loot-roll).
- **Memory**: None (enums are ints; string names materialised only at serialization).
- **Load Time**: None.
- **Network**: None.

## Migration Plan
1. Introduce a single canonical `AbilityClass` enum (location: `#9` / a shared
   `src/core/ability_class.gd` const-enum holder — decided at implementation time
   with godot-specialist; must be importable by #9/#10/#12/#13/#14/#15).
2. **GDD sync (follow-up, not auto-applied here)**: `loot-drop-system.md` Formula
   E2 — rename `NEUTRAL` → `UNKNOWN`, OR add a one-line note that NEUTRAL names a
   weight-distribution *outcome* (even spread) and is not an `AbilityClass`
   identity. `entities.yaml:801` updated to match.
3. No code migration needed for Foundation (GameState/BossOutcome already comply).

## Validation Criteria
- All six Class-tagged systems import the one `AbilityClass`; grep finds no second
  declaration of `STRIKE|CONTROL|MOBILITY` enum.
- `#9.get_dominant_ability_class()` unit test: an all-UNKNOWN exercise set returns
  `UNKNOWN`, never `STRIKE` (anti-fabrication regression test).
- Round-trip test: every `AbilityClass` value → `find_key` → `get` → original.
- (Deferred) CI lint flags classification enums with a real value at ordinal 0 +
  uninitialised fields.

## Related Decisions
- ADR-0006 (State Machine Contract) — Contract 3 string-name serialization precedent (`find_key`).
- ADR-0005 (Loot Rarity Formula) — consumes the class-affinity dimension.
- ADR-0009 (Signal Payload Schema Convention) — reuses this string-name rule for enum-carrying payloads.
