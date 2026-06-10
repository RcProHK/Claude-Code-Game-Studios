# ADR-0008: Autoload Position Map

## Status
**Accepted 2026-06-01** — ratified focused. The canonical map matches `project.godot` ground truth (F-SETUP-4); dependencies are met — ADR-0006 (Accepted, Contract 4 locks positions 1–2) + ADR-0001 (Accepted-structural, PlatformDetect ordering). Foundation boot verified green (combined GUT gate 1321/1322, 0 fail post-PR #10). The partial-order constraints (§Binding ordering) hold against the current tree. Closes architecture-review GAP-002. Unblocks deterministic autoload placement for the 4 unwritten autoloads — **#10 ExerciseClassMapping (after GymSysBackendClient → pos 5)**, **#4 AudioManager (top of Presentation block, ~pos 11 around AvatarRenderer)**, #28 Telemetry (last), #33 AttentionBudget (after WorkoutStateTracker). No measurement/hardware gate (boot ordering is structural, already test-verified).
*(Previously: Proposed)*

**Amendment 2026-06-02 (technical-director sign-off)** — added the #10 ExerciseClassMapping insertion rule (predecessor constraints + recommended pos 5) per its design-review Q1 resolution (autoload, static option dropped). This is a focused additive amendment: the current canonical map (= `project.godot` ground truth) is unchanged because #10 is not yet written into `project.godot`; #10 joins the reserved-insertion-rules table alongside #4/#28/#33. New binding constraint 7 (`ExerciseClassMapping ≺ StatSystem`) added. No re-ratification needed — additive, no constraint conflict, no measurement gate. Unblocks #10 Pass 2 fresh re-review.

**Amendment 2026-06-07 (#22 G-CS-8)** — added the #22 CharacterScreenCoordinator insertion rule (tail append after LootRevealCoordinator; #28 Telemetry still reserved Last). Focused additive — canonical map unchanged until #22 story 002 writes `project.godot`; no re-ratification needed.

**Amendment 2026-06-07 (#23 G-IU-2)** — added the #23 InventoryUICoordinator insertion rule (tail append after CharacterScreenCoordinator; #28 Telemetry still reserved Last; explicit **NO #22 constraint** — tail position is convention, not binding). Focused additive — canonical map unchanged until #23 story 002 writes `project.godot`; no re-ratification needed.

**Amendment 2026-06-08 (#24 G-LS-2)** — added the #24 LoginShellCoordinator insertion rule (tail append after InventoryUICoordinator; #28 Telemetry still reserved Last; explicit **NO #21/#22/#23 binding constraint** — tail position is convention, not binding, per the #23 precedent). Focused additive — canonical map unchanged until #24 story 003 writes `project.godot`; no re-ratification needed.

**Amendment 2026-06-06 (#17 G-4, design-review Pass 1)** — added binding constraint 8 (`StatSystem ≺ InventorySystem ≺ LootDropSystem`) and the #17 InventorySystem reserved insertion rule. The second half of the constraint is binding, not coincidence: #15 calls `Inventory.receive_loot()` at runtime and during boot catch-up (#15 L300/EC-48). Recommended slot = the position immediately before LootDropSystem that satisfies `StatSystem ≺ here` (e.g. between WorkoutStateTracker and LootDropSystem; renumber downstream on insertion). Focused additive — canonical map unchanged (InventorySystem not yet in `project.godot`); no re-ratification needed.

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
| 11 | ParticleSystemWrapper | Presentation | **Before ScreenEffects** (screen-effects depends on it) + **before AvatarRenderer** (#26 hard pred, G-AR-1) |
| 12 | AvatarRenderer | Presentation | **After {#11 Stat, #12 Ability, #3 Persistence, #1 GSM, #5 ParticleSystemWrapper}** — ADR-0008 v2 amendment 2026-06-10 (G-AR-1, avatar-renderer.md v2.1). v1 "pos 11/F-5" hardcode SUPERSEDED (it placed #26 before its #5 predecessor) |
| 13 | CameraController | Presentation | Camera mutation single-owner (ADR-0001) |
| 14 | ScreenEffects | Presentation | After ParticleSystemWrapper |

### Binding ordering constraints (partial order — survive renumbering)
1. `PersistenceLayer ≺ GameStateMachine` ≺ everything (LOCKED, ADR-0006 C4).
2. `PlatformDetect` ≺ every web-export-sensitive autoload (ADR-0001).
3. `LootDropSystem ≺ EnemyDirector` (#13 EC-43, Rule 9).
4. `ParticleSystemWrapper ≺ ScreenEffects`.
4b. `{StatSystem, AbilitySystem, PersistenceLayer, GameStateMachine, ParticleSystemWrapper} ≺ AvatarRenderer` (#26 hard predecessors, avatar-renderer.md v2.1 / **G-AR-1 amendment 2026-06-10** — supersedes v1 "pos 11/F-5" which placed #26 before #5). `AvatarRenderer ≺ MirrorMomentCoordinator` (#29 tail, G-MM-1; one-directional #29→#26).
5. `StatSystem ≺ AbilitySystem` (class-tier derivation).
6. Any subscriber using `connect_for_initial_state` is **order-resilient** to GSM
   (Contract 6 sentinel) and need only satisfy its data-producer predecessors.
7. `ExerciseClassMapping ≺ StatSystem` (#10) — the exercise→class lookup must be
   live before the Core stat/ability/workout pipeline boots, so any class lookup
   issued during Core init resolves against a loaded `ExerciseRegistry.tres`. The
   mapping is a pure categorical lookup (order-resilient, emits no boot events), so
   this is the only forward constraint it imposes.
8. `StatSystem ≺ InventorySystem ≺ LootDropSystem` (#17, added 2026-06-06 G-4) —
   InventorySystem's boot replay calls `apply_equipment_modifier` (needs StatSystem
   Ready, asserted via `is_boot_completed()`); LootDropSystem calls
   `Inventory.receive_loot()` at runtime and during boot catch-up (#15 L300/EC-48),
   so Inventory must precede it. **The second half is binding, not coincidence** —
   before this constraint it held only because "after StatSystem" happened to land
   before LootDrop's position.

### Reserved insertion rules for the 4 unwritten autoloads
These define *predecessor constraints*, not fixed numbers. On insertion, place at
the earliest position satisfying the constraints, renumber `project.godot`
downstream, and do NOT write the resulting absolute number into any GDD.

| System | Predecessor constraints | Recommended placement |
|--------|------------------------|-----------------------|
| **#10 ExerciseClassMapping** | After PlatformDetect (loads `ExerciseRegistry.tres`); after GymSysBackendClient (preserves the Backend ≺ Core boundary — the mapping classifies the exercises the backend reports). **Before StatSystem** (binding constraint 7). Pure categorical lookup — order-resilient, emits no boot events. | Immediately after GymSysBackendClient (current pos 4 → new pos 5; StatSystem … ScreenEffects all shift +1) |
| **#33 AttentionBudget & Interaction Policy** | After GameStateMachine (reads GSM state) **and** WorkoutStateTracker (input gating keys off active workout). Pillar 2 owner — must be live before combat/loot input gating. | Immediately after WorkoutStateTracker (current pos 8 → new pos 9; LootDrop/EnemyDirector shift down) |
| **#4 AudioManager** | After GameStateMachine (subscribes state for combat/boss/loot stingers); presentation-adjacent. Order-resilient via `connect_for_initial_state`. | Top of the Presentation block (around AvatarRenderer) |
| **#28 Telemetry** | Pure observer, no downstream consumers. Order-resilient (`connect_for_initial_state` back-fills initial state for late join). | **Last** — boots after all producers so it subscribes to a fully-booted tree |
| **#17 InventorySystem** (added 2026-06-06 G-4, GDD Pass 1) | After StatSystem (boot replay pushes `&"equipment_aggregate"` modifier; asserts `is_boot_completed()` — never awaits the signal, Contract 4 trap). **Before LootDropSystem** (binding constraint 8 — #15 calls `Inventory.receive_loot` at runtime/catch-up). Subscribes GSM via `connect_for_initial_state` (Suspended-at-boot → pending-replay flag). | The slot immediately before LootDropSystem satisfying `StatSystem ≺ here` (i.e. between WorkoutStateTracker and LootDropSystem; renumber downstream) |
| **#18 PrDetection** (added 2026-06-06 G-PR-3, GDD APPROVED) | After GymSysBackendClient ≺ ExerciseClassMapping ≺ StatSystem ≺ **{AbilitySystem, WST}** (the two reverse-wire targets — #18 connects its own `pr_breakthrough` into `AbilitySystem._on_pr_breakthrough` [G-PR-4 pinned] + the #9 G-PR-2 handler in `_ready()`; AbilitySystem/WST carry NO mutual constraint — current project.godot relative order stays). Caller path LOCKED `src/autoload/pr_detection.gd` (ADR-0011 §D-4). | **Tail append after AttentionBudget** (#28 Telemetry still reserved Last) — ✅ executed 2026-06-06 (#18 story 002) |
| **#19 ZoneSystem** (added 2026-06-06 G-Z-1, GDD APPROVED) | After PersistenceLayer (boot loads `zone.state` envelope) **and** WorkoutStateTracker (plain-connects `workout_completed_forwarded` — late-boot consumer, no reverse-wire needed). **NO EnemyDirector constraint** (#14 MVP has zero zone touchpoints; the v0.2 G-Z-2 read happens at workout-start runtime, not boot). | **Tail append after PrDetection** (#28 Telemetry still reserved Last) — pending #19 story 002 |
| **#21 LootRevealCoordinator** (added 2026-06-07 G-LM-5, GDD APPROVED) | `{LootDropSystem, GameStateMachine (C6), AttentionBudget, CameraController, ScreenEffects, ParticleSystemWrapper, AudioManager, PlatformDetect} ≺ #21` — pull-consumer of #15 queue, subscribes GSM via `connect_for_initial_state` (boot force-reveal), calls #5/#6/#7/#4 presentation APIs at runtime, `announce_aria` via PlatformDetect. Owns CelebrationVFXLayer (110) + ModalLayer (120) — #5 LOOT pool reparent handshake (G-LM-2) fires post-#21-boot precisely because #21 is tail. | **Tail append after ZoneSystem** (#28 Telemetry still reserved Last) — pending #21 story 002 |
| **#22 CharacterScreenCoordinator** (added 2026-06-07 G-CS-8, GDD APPROVED) | `{GameStateMachine (C6), StatSystem, InventorySystem, AvatarRenderer, ScreenEffects, CameraController, PlatformDetect, AudioManager, PersistenceLayer} ≺ #22` — open-time sync-reads #11 (`get_stat` ×7) / #17 (loadout getters) / #26 (5 read-only getters); subscribes GSM + #11 via `connect_for_initial_state`, #26 via plain `connect` (#26 does not expose cfis — #22 GDD Pass 1 phantom fix); writes `settings.*`/`charscreen.*` via PersistenceLayer; calls #6/#7/#4 setters + `announce_aria` at runtime. Owns CharacterScreenLayer (60, PAUSABLE — ADR-0001 #22 revision). Boot invariant: zero subscriptions while CLOSED (Rule 8). | **Tail append after LootRevealCoordinator** (#28 Telemetry still reserved Last) — pending #22 story 002 |
| **#23 InventoryUICoordinator** (added 2026-06-07 G-IU-2, GDD APPROVED) | `{GameStateMachine (C6), InventorySystem, AudioManager, PlatformDetect} ≺ #23` — subscribes GSM via `connect_for_initial_state` (LOOT_DROP force-close + boot state); all item data flows through #17 commands/getters (incl. the G-IU-1 additive getters); calls #4 `play_sfx` + `announce_aria` via PlatformDetect at runtime. **NO #22 CharacterScreenCoordinator constraint** — the tail slot after #22 is convention, not binding: the two coordinators have zero boot-order dependency (the G-IU-4 glue is a runtime one-shot `call_deferred` + `has_method` guard on `/root/InventoryUICoordinator`; the script is a plain resource) — do not invent a phantom constraint (#19 G-Z-1「NO EnemyDirector」precedent). Explicitly NOT listed (zero touchpoints, #23 GDD): StatSystem / AvatarRenderer / PersistenceLayer / ScreenEffects / CameraController (#23 owns zero persisted state, zero #11/#26 subscriptions, no screen-effects or camera calls). Owns InventoryUILayer (61, PAUSABLE — ADR-0001 #23 revision). | **Tail append after CharacterScreenCoordinator** (#28 Telemetry still reserved Last) — pending #23 story 002 |
| **#24 LoginShellCoordinator** (added 2026-06-08 G-LS-2, GDD APPROVED) | `{GameStateMachine (C6), GymSysBackendClient (#2), PersistenceLayer (#3), StreakSystem (#8), StatSystem (#11), AbilitySystem (#12), AttentionBudget (#33), PlatformDetect} ≺ #24` — subscribes GSM via `connect_for_initial_state` (boot shell-state + `auth_required` boot-race); reverse-reads #2 `is_auth_required()` pull-check in `_ready()` (Rule 2 / G-LS-4(c) boot-window close) + subscribes #2 `auth_required`/connection errors; plain-connects the runtime save-failed signals it surfaces as banners — #8 `streak_persistence_failed` (G-LS-9 erratum: shipped `(error_code, key)` dual-arg) / #11 `stat_critical_save_failed` / #12 `ability_unlock_save_failed` — and reads #3 `get_pending_errors()` (G-LS-8 additive); respects #33 attention budget (EC-13); `announce_aria` via PlatformDetect (AC-UX a11y). All predecessors are subscribe/pull consumers (plain `connect` for the runtime transients — late-boot-safe, no reverse-wire), so tail trivially satisfies them. **NO #21/#22/#23 coordinator constraint** — the tail slot after #23 is convention, not binding: #24's downstream glue to #22/#23 (`request_open()` arbiter, G-LS-5 `loadout_view_all_tap` migration) is a runtime `has_method`-guarded call, not a boot dependency (#23 G-IU-2「NO #22 constraint」precedent). Explicitly NOT listed (zero touchpoints, #24 GDD): AudioManager (banner is zero-audio, Rule 8) / ScreenEffects / CameraController / AvatarRenderer / InventorySystem (#24 calls no presentation-effect or world API; its layers are captured positionally by BackBufferCopy but it invokes no ScreenEffects method). Owns LoginShellLayer (62, PAUSABLE) + ErrorBannerLayer (111, ALWAYS) — ADR-0001 #24 revision. | **Tail append after InventoryUICoordinator** (#28 Telemetry still reserved Last) — pending #24 story 003 |

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
| exercise-class-mapping.md (#10) | Autoload (Q1 resolved); must boot before Core consumers; no hard-coded position | Insertion rule places it after GymSys → pos 5; binding constraint 7 |
| (systems-index) #33 AttentionBudget | Pillar 2 owner — gates input from session start | Insertion rule places it before combat/loot gating |
| loot-drop-system.md / enemy-director.md | LootDrop must boot before EnemyDirector (EC-43, Rule 9) | Constraint 3 + map positions 9<10 |
| particle-system-wrapper.md / screen-effects-system.md | ParticleSystemWrapper precedes ScreenEffects | Constraint 4 + map positions 12<14 |
| avatar-renderer.md (#26) | After {#11 Stat, #12 Ability, #3 Persistence, #1 GSM, #5 ParticleSystemWrapper} — **v2.1 partial-order, G-AR-1 amendment 2026-06-10** (supersedes v1 "pos 11/F-5" which mis-placed #26 before #5) | Constraint 4b + map positions 11(#5)<12(#26) |
| mirror-moment.md (#29) | MirrorMomentCoordinator tail-appends after AvatarRenderer (#26); one-directional #29→#26; terminal | Constraint 4b (G-MM-1) + insertion rule (tail) |

## Performance Implications
- **CPU / Memory / Load Time**: None — boot order does not change runtime cost; it
  only sequences one-time `_ready()` calls. Foundation boot already within budget.
- **Network**: None.

## Migration Plan
1. Adopt the map as documentation; `project.godot` is already aligned — no code change.
2. Reconcile registry: update PlatformDetect `position 0` → `position 3`
   (registry update, asked separately).
3. When #10 / #4 / #28 / #33 GDDs are authored, apply their insertion rule, edit
   `project.godot`, regenerate position audits + control manifest. #10 inserts at
   pos 5 (renumbers StatSystem … ScreenEffects +1) — `project.godot` edit + CI
   position audit / control manifest regeneration only; no GDD holds an absolute number.

## Validation Criteria
- Boot smoke test passes with the documented order (already green).
- Grep: no GDD asserts an absolute autoload number as authoritative (all phrased
  as constraints or "per project.godot").
- After any insertion, the partial-order constraints (§Binding ordering) still hold.

## Related Decisions
- ADR-0006 (State Machine Contract) — Contract 4 locks positions 1–2 and boot discipline.
- ADR-0001 (Web Export Budget Caps) — PlatformDetect ordering rationale.
- ADR-0009 (Signal Payload Schema) — `connect_for_initial_state` resilience referenced here.
