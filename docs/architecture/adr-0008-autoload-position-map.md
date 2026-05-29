# ADR-0008: Autoload Position Map

## Status
Proposed

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (boot sequence / autoload) |
| **Knowledge Risk** | MEDIUM — Godot autoload `_ready()` ordering is per-project-setting-order, sequential (not batched); verified against 4.6 SceneTree behaviour in ADR-0006 Contract 4 |
| **References Consulted** | `project.godot` `[autoload]` block; ADR-0006 Contract 4 (boot discipline); ADR-0001 (PlatformDetect web-export ordering); `docs/registry/architecture.yaml`; `design/gdd/*.md` Dependencies sections |
| **Post-Cutoff APIs Used** | None — relies only on the documented sequential autoload `_ready()` ordering |
| **Verification Required** | Foundation boot order already verified green (224/224); when #4 / #28 / #33 land, re-confirm their predecessors are present before their `_ready()` runs |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0006 (Contract 4 locks positions 1–2); ADR-0001 (PlatformDetect must precede web-export-sensitive autoloads) |
| **Enables** | Authoring of #4 AudioManager, #28 Telemetry, #33 AttentionBudget GDDs (each gets a deterministic insertion rule); /create-control-manifest boot section |
| **Blocks** | Any story that inserts a new autoload — must follow this map's insertion procedure |
| **Ordering Note** | MEDIUM / pre-Pre-MVP. Closes architecture-review GAP-002. |

## Context

### Problem Statement
Autoload positions 4–14 were never ratified in a master ADR. `project.godot` is the
de-facto ground truth (F-SETUP-4), but three Pillar-relevant autoloads are still
unwritten — **#4 AudioManager**, **#28 Telemetry**, **#33 AttentionBudget &
Interaction Policy** — and there is no rule for *where* they slot in or how their
insertion renumbers the systems below them. The 2026-05-28 GDD-sync pass spent 23
edits fixing position drift caused by GDDs hard-coding absolute position numbers
that fell out of sync with `project.godot`. Without a single map + an insertion
procedure, the same drift recurs.

A registry staleness also needs reconciliation: `docs/registry/architecture.yaml`
records PlatformDetect as "Autoload position 0", but `project.godot` places it at
**position 3** (after the Contract-4-locked Persistence + GSM). `project.godot` is
authoritative.

### Constraints
- Godot runs autoload `_ready()` **sequentially in the order listed in
  `project.godot`** (ADR-0006 Contract 4). Position numbers are 1-based by listing.
- Positions 1–2 are LOCKED (ADR-0006 Contract 4): PersistenceLayer, GameStateMachine.
- Inserting an autoload shifts every position below it by one — so GDDs must NOT
  hard-code absolute numbers (F-SETUP-4). Ordering is expressed as a **partial
  order of predecessor constraints**; absolute numbers are derived from `project.godot`.

### Requirements
- One canonical, ground-truth-aligned position map.
- The binding ordering constraints (which pairs/groups are locked, and why).
- A deterministic insertion rule for each of the 3 unwritten autoloads.

## Decision

### Current canonical map (ground truth = `project.godot`, 2026-05-29)

| Pos | Autoload | Layer | Boot constraint (why here) |
|-----|----------|-------|----------------------------|
| 1 | PersistenceLayer | Foundation | LOCKED (ADR-0006 C4) — read-safe source of truth before all |
| 2 | GameStateMachine | Foundation | LOCKED (ADR-0006 C4) — must precede all `connect_for_initial_state` subscribers |
| 3 | PlatformDetect | Foundation | Before any web-export-sensitive autoload (ADR-0001); after Persistence+GSM |
| 4 | GymSysBackendClient | Backend | After Persistence + GSM + PlatformDetect |
| 5 | StatSystem | Core | After GymSys (consumes backend data) |
| 6 | AbilitySystem | Core | After StatSystem (STR/DEX/VIT → class tiers) |
| 7 | StreakSystem | Core | After Persistence; subscribes GSM |
| 8 | WorkoutStateTracker | Core | After Stat/Ability; provides active-workout context |
| 9 | LootDropSystem | Combat | **Before EnemyDirector** (#13 EC-43 + Rule 9) |
| 10 | EnemyDirector | Combat | After LootDropSystem |
| 11 | AvatarRenderer | Presentation | Pinned pos 11 (avatar-renderer.md F-5) |
| 12 | ParticleSystemWrapper | Presentation | **Before ScreenEffects** (screen-effects depends on it) |
| 13 | CameraController | Presentation | Camera mutation single-owner (ADR-0001) |
| 14 | ScreenEffects | Presentation | After ParticleSystemWrapper |

### Binding ordering constraints (partial order — survive renumbering)
1. `PersistenceLayer ≺ GameStateMachine` ≺ everything (LOCKED, ADR-0006 C4).
2. `PlatformDetect` ≺ every web-export-sensitive autoload (ADR-0001).
3. `LootDropSystem ≺ EnemyDirector` (#13 EC-43, Rule 9).
4. `ParticleSystemWrapper ≺ ScreenEffects`.
5. `StatSystem ≺ AbilitySystem` (class-tier derivation).
6. Any subscriber using `connect_for_initial_state` is **order-resilient** to GSM
   (Contract 6 sentinel) and need only satisfy its data-producer predecessors.

### Reserved insertion rules for the 3 unwritten autoloads
These define *predecessor constraints*, not fixed numbers. On insertion, place at
the earliest position satisfying the constraints, renumber `project.godot`
downstream, and do NOT write the resulting absolute number into any GDD.

| System | Predecessor constraints | Recommended placement |
|--------|------------------------|-----------------------|
| **#33 AttentionBudget & Interaction Policy** | After GameStateMachine (reads GSM state) **and** WorkoutStateTracker (input gating keys off active workout). Pillar 2 owner — must be live before combat/loot input gating. | Immediately after WorkoutStateTracker (current pos 8 → new pos 9; LootDrop/EnemyDirector shift down) |
| **#4 AudioManager** | After GameStateMachine (subscribes state for combat/boss/loot stingers); presentation-adjacent. Order-resilient via `connect_for_initial_state`. | Top of the Presentation block (around AvatarRenderer) |
| **#28 Telemetry** | Pure observer, no downstream consumers. Order-resilient (`connect_for_initial_state` back-fills initial state for late join). | **Last** — boots after all producers so it subscribes to a fully-booted tree |

### Key Interfaces
- `project.godot` `[autoload]` block is the **single source of truth** for absolute
  position. No GDD, ADR prose, or comment may assert an absolute autoload number as
  authoritative — they reference *constraints* or cite "per project.godot".

## Alternatives Considered

### Alternative 1: Hard-code absolute positions in each GDD
- **Description**: Each system GDD states "I am autoload position N".
- **Pros**: Locally explicit.
- **Cons**: This is exactly what caused the 2026-05-28 drift (23 fix edits); any insertion invalidates every downstream GDD.
- **Rejection Reason**: Proven fragile; F-SETUP-4 already ruled `project.godot` is sole truth.

### Alternative 2: A dependency-injected boot orchestrator (no Godot autoload order)
- **Description**: One bootstrap autoload that `add_child`s the rest in code-defined order.
- **Pros**: Order independent of project settings.
- **Cons**: Fights Godot's idiom; loses editor visibility; ADR-0006 Contract 4 already proved native sequential ordering works and is tested.
- **Rejection Reason**: Unnecessary complexity; contradicts Contract 4.

## Consequences

### Positive
- One ground-truth map; insertions become mechanical and drift-free.
- The 3 unwritten autoloads have deterministic homes before their GDDs are written.
- Registry PlatformDetect staleness (pos 0 → pos 3) is corrected.

### Negative
- Inserting #33 renumbers positions 9–14 (LootDrop … ScreenEffects). This is a
  `project.godot` edit only (GDDs hold no absolute numbers), but the CI position
  audits / control manifest must be regenerated.

### Risks
- **Risk**: A GDD author re-hardcodes an absolute number. **Mitigation**: convention
  rule above + (deferred) CI lint greps GDDs for `position [0-9]+` assertions and
  flags any not phrased as "per project.godot".
- **Risk**: #28 Telemetry placed last misses an event emitted *during* an earlier
  autoload's `_ready()`. **Mitigation**: producers must not emit domain events from
  `_ready()` (Contract 4 already forbids this for GSM); telemetry back-fills via
  `connect_for_initial_state`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-machine.md | Contract 4 positions 1–2 locked; line 364 AttentionBudget consumes GSM state | Map locks 1–2; #33 placed after GSM |
| (systems-index) #33 AttentionBudget | Pillar 2 owner — gates input from session start | Insertion rule places it before combat/loot gating |
| loot-drop-system.md / enemy-director.md | LootDrop must boot before EnemyDirector (EC-43, Rule 9) | Constraint 3 + map positions 9<10 |
| particle-system-wrapper.md / screen-effects-system.md | ParticleSystemWrapper precedes ScreenEffects | Constraint 4 + map positions 12<14 |
| avatar-renderer.md | Avatar pinned position 11 (F-5) | Recorded in map |

## Performance Implications
- **CPU / Memory / Load Time**: None — boot order does not change runtime cost; it
  only sequences one-time `_ready()` calls. Foundation boot already within budget.
- **Network**: None.

## Migration Plan
1. Adopt the map as documentation; `project.godot` is already aligned — no code change.
2. Reconcile registry: update PlatformDetect `position 0` → `position 3`
   (registry update, asked separately).
3. When #4 / #28 / #33 GDDs are authored, apply their insertion rule, edit
   `project.godot`, regenerate position audits + control manifest.

## Validation Criteria
- Boot smoke test passes with the documented order (already green).
- Grep: no GDD asserts an absolute autoload number as authoritative (all phrased
  as constraints or "per project.godot").
- After any insertion, the partial-order constraints (§Binding ordering) still hold.

## Related Decisions
- ADR-0006 (State Machine Contract) — Contract 4 locks positions 1–2 and boot discipline.
- ADR-0001 (Web Export Budget Caps) — PlatformDetect ordering rationale.
- ADR-0009 (Signal Payload Schema) — `connect_for_initial_state` resilience referenced here.
