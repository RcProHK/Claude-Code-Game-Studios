# Control Manifest

> **Engine**: Godot 4.6 (Web Export, Compatibility Renderer)
> **Last Updated**: 2026-05-29 (regenerated — added ADR-0007 + ADR-0009; fixed GUT v7→v9)
> **Manifest Version**: 2026-05-29
> **ADRs Covered**: ADR-0006 (Accepted), ADR-0007 (Accepted 2026-05-29), ADR-0009 (Accepted 2026-05-29)
> **Status**: Active — regenerate with `/create-control-manifest` when new ADRs are Accepted

`Manifest Version` is the date this manifest was generated. Story files embed this date when created.
`/story-readiness` compares a story's embedded version to this field to detect stories written against stale rules.
Always matches `Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs, technical preferences,
and engine reference docs. For the reasoning behind each rule, see the referenced ADR.

> ⚠️ **Partial coverage**: ADR-0006, ADR-0007, ADR-0009 Accepted. ADRs 0001–0005 still Proposed; ADR-0008, ADR-0010 Proposed.
> Systems governed by Proposed ADRs (GymSys, Particles, Camera, ScreenEffects, PersistenceLayer storage strategy,
> Loot formula, Autoload position map, MirrorMoment ceremony split) have incomplete manifest coverage until ratification.

---

## Foundation Layer Rules

*Applies to: autoload lifecycle, GameStateMachine, PersistenceLayer, boot sequence, save/load*

### Required Patterns

- **PersistenceLayer = autoload position 1, GameStateMachine = position 2 — hard-locked** — verified in `project.godot` + CI test. All other autoloads = position 3+. — source: ADR-0006 Contract 4
- **Autoload boot order is per-instance sequential**: each autoload's `_enter_tree` → `_ready` completes fully before the next autoload begins. NOT batched. — source: ADR-0006 Contract 4
- **GSM subscribers MUST use `connect_for_initial_state(callable)` helper** — direct `state_changed.connect()` in `_ready()` loses the signal (emit fired before subscription). — source: ADR-0006 Contract 6
- **Initial-state delivery uses self-loop sentinel pattern**: `callable.callv([captured_state, captured_state, _initial_state_payload])` — `from == to == current_state`. Detect initial delivery via `payload.source_event == "initial_state"`. — source: ADR-0006 Contract 6 Addendum 2026-05-28
- **`_last_emit_tick` race guard in `connect_for_initial_state`**: capture `_last_emit_tick` at connect time; deferred lambda checks `_last_emit_tick > captured_tick` before delivering — skip if real transition already fired. — source: ADR-0006 Contract 7
- **Follow-up transitions from `state_changed` subscriber MUST use `process_frame.connect` pattern**:
  ```gdscript
  get_tree().process_frame.connect(
      func(): state_machine._request_transition(event),
      CONNECT_ONE_SHOT
  )
  ```
  — source: ADR-0006 Contract 5
- **Every Resource payload crossing persistence boundary MUST extend `SerializableResource`** and implement both `to_dict() -> Dictionary` and `static func from_dict(data: Dictionary) -> SerializableResource`. — source: ADR-0006 Contract 3
- **`payload_type` in tombstone MUST use `get_script().get_global_name()`** (NOT `get_class()` — returns `"Resource"` for all GDScript classes, silently breaks forward-recovery). — source: ADR-0006 Contract 3
- **Forward-recovery MUST reuse tombstone's `transition_id` verbatim** — extract `tombstone["transition_id"]` and use unchanged through Rule 2 step 3-8 replay. — source: ADR-0006 Contract 2
- **`transition_id` generation = `"%d_%d_%s_%s" % [wall_clock_ms, counter, from, to]`** — counter persisted in PersistenceLayer (`_transition_id_counter` key), incremented BEFORE writing. — source: ADR-0006 Contract 2
- **`_assert_knob_invariants()` MUST be called from `GameStateMachine._ready()` BEFORE Rule 5 reconciliation** — catches violated knob invariants in debug builds before VS playtest. — source: ADR-0006 Contract 8
- **Schema migration chain: bounded at MAX_CHAIN_LENGTH = 6 steps × MIGRATION_BUDGET_MS = 150ms** — total ceiling = 900ms. Fail-fast if chain length > 6. — source: ADR-0006 Contract 10
- **`is_expired()` drift-tolerant TTL: `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300`** — compare wall_diff vs mono_diff; use monotonic if |wall_diff - mono_diff| > 300s. — source: ADR-0006 Contract 9
- **Test spy interfaces MUST use the formal Contract 14 set** — `IPersistence.attach_write_spy / attach_delete_spy / clear_spies`; `GameStateMachine.attach_in_memory_spy / clear_spies`. ACs referencing a spy MUST use the exact interface name. — source: ADR-0006 Contract 14
- **`IInputPolicy` interface for input permission** — `AttentionBudgetPolicy extends IInputPolicy`; input handlers accept `IInputPolicy` via constructor injection (NOT direct reference to `AttentionBudgetPolicy`). — source: ADR-0006 Contract 13
- **`pending_since_server` (backend timestamp) is authoritative for hard-cap loot eviction** — client `pending_since` is mirror only, used for offline UX. Never use client timestamp for hard-cap decisions. — source: ADR-0006 Contract 15
- **Classification enum fields MUST be explicitly initialised — zero-default is FORBIDDEN** — for Classification enums (e.g. `AbilityClass`), ordinal 0 is a real class value (STRIKE), not a sentinel. An uninitialised `var x: AbilityClass` silently fabricates STRIKE, violating Pillar 1. Initialise explicitly or return `UNKNOWN` explicitly. — source: ADR-0007 Family B
- **Outcome/State enum ordinal 0 = safe/uninitialised value (hard rule)** — for Family A enums (`GameState`, `BossOutcome`), the zero-default is the conservative "nothing happened yet" value. Declaration order carries persisted-migration meaning; do NOT renumber existing members. — source: ADR-0007 Family A
- **Canonical `AbilityClass` enum declaration order is LOCKED** — `enum AbilityClass { STRIKE, CONTROL, MOBILITY, UNKNOWN }` (ordinals 0/1/2/3). Declaration order is load-bearing for Ability Formula 3 emit ordering and #9 tiebreak walk. Never reorder. `UNKNOWN` is always last (sentinel). — source: ADR-0007 Decision
- **Signal payloads MUST be minimal + intrinsic** — carry only the event's own data + `transition_id`. Do NOT include ambient context (active `workout_id`, current GSM state, current zone) in the payload — these drift and couple unrelated producers. — source: ADR-0009 §1
- **Handlers needing ambient context MUST late-bind via read API + explicit null branch** — query the owning system's read API at handle time (e.g. `WorkoutStateTracker.get_active_workout_id()`) and MUST branch on `null` before consuming. Never assume non-null. — source: ADR-0009 §2
- **Structured / persisted signal payloads MUST extend `SerializableResource`** — with `to_dict()` / `from_dict()` and `payload_type` set via `get_script().get_global_name()`. Purely transient never-persisted signals MAY use primitive typed args. No Dictionary-with-magic-keys middle ground. — source: ADR-0009 §3

### Forbidden Approaches

- **Never use Mutex for transition lock** — adds API friction, no benefit in single-thread WASM; generational lock is future-proof for both threading modes. — source: ADR-0006 Contract 1 (Alt 1 rejected)
- **Never use pure `call_deferred` frame-boundary atomicity** — delays every transition by 1 frame (16.6ms); boss-defeat → LootDrop ritual has perceivable hiccup; Pillar 3 violation. — source: ADR-0006 Contract 1 (Alt 2 rejected)
- **Never use `var_to_bytes()` + base64 for payload serialization** — opaque blob in IndexedDB devtools; schema migration requires manual byte-level rewrite. — source: ADR-0006 Contract 3 (Alt 4 rejected)
- **Never use backend-allocated `transition_id`** — offline mode fails closed; Pillar 2 (Frictionless) violation. — source: ADR-0006 Contract 2 (Alt 5 rejected)
- **Never emit `state_changed` from `GameStateMachine._ready()`** — downstream autoloads (pos 3+) have not yet connected; emit is silently lost. Use `connect_for_initial_state` instead. — source: ADR-0006 Contract 4
- **Never call `_generate_transition_id()` inside any `_forward_recover*` function** — CI scan enforces this. Forward-recovery MUST reuse tombstone's existing ID. — source: ADR-0006 Contract 2
- **Never pass `.bind()` callables to `connect_for_initial_state`** — shifts positional arg layout; `callv` mis-delivers initial state silently. CI enforces: `connect_for_initial_state(*.bind(*))` pattern is a CI error. — source: ADR-0006 Contract 6
- **Never use `Object.get_class()` for payload_type** — returns engine class `"Resource"` for all GDScript classes, breaking forward-recovery round-trip. — source: ADR-0006 Contract 3
- **Never parse `transition_id` string to recover `from`/`to` state names** — state names contain underscores (e.g., `workout_active`); split is ambiguous. Read from tombstone Dictionary fields directly. — source: ADR-0006 Contract 2
- **Never use `transition_id` as a display string or UI label** — opaque internal identifier; format may change across ADR versions. — source: ADR-0006 Contract 2
- **Never name the 4th `AbilityClass` member anything other than `UNKNOWN`** — `NEUTRAL` is retired as an `AbilityClass` member (it is valid only as `ClassTag.NEUTRAL` — a distinct loot-item outcome enum). Using NEUTRAL in AbilityClass breaks cross-system serialization round-trips. — source: ADR-0007 Decision
- **Never use integer ordinals to serialize enum values** — migration-fragile (any reorder corrupts saves); debug-hostile in IndexedDB. Serialize as string name: `EnumType.find_key(value)` → String. — source: ADR-0007 (reaffirms ADR-0006 Contract 3)
- **Never stuff ambient context into signal payloads** — fat payloads couple producers to consumers; payload fields for workout_id / current state / zone are forbidden unless they are intrinsic to the event itself. — source: ADR-0009 §1 (Alt 1 rejected)
- **Never assume ambient context is non-null in a handler** — always explicit null branch when late-binding ambient context from a read API. Silent null-assumption is the exact defect INV-12 guards against. — source: ADR-0009 §2

### Performance Guardrails

- **State transition CPU**: < 0.5ms (single-thread WASM, no `await`, no IDB flush) — source: ADR-0006 Performance Implications
- **PersistenceLayer + GameStateMachine `_ready()` boot combined**: target < 50ms, budget < 100ms — source: ADR-0006 Performance Implications
- **Schema migration chain total**: ≤ 900ms (6 steps × 150ms) — source: ADR-0006 Contract 10
- **Forward-recovery on cold boot**: target < 100ms, budget < 200ms — source: ADR-0006 Performance Implications

---

## Core Layer Rules

*Applies to: core gameplay loops, input policy, state machine consumers*

### Required Patterns

- **`AttentionBudgetPolicy` implements `IInputPolicy`** — concrete Pillar 2 enforcement. `func is_input_permitted() -> bool` derives from `GameStateMachine.current_state`. — source: ADR-0006 Contract 13
- **`MockInputPolicy` for tests** — `extends IInputPolicy`; `func is_input_permitted() -> bool: return _permitted`. Inject into input handlers instead of real policy. — source: ADR-0006 Contract 14
- **All Resource subclasses used in transition payloads extend `SerializableResource`** — this applies to every layer that creates payloads consumed by GSM. — source: ADR-0006 Contract 3
- **`AbilityClass` is the one canonical class-archetype enum across ALL systems** — `#9 WorkoutStateTracker`, `#12 AbilitySystem`, `#13 CombatResolver`, `#14 EnemyDirector`, `#15 LootDrop` all import the same `AbilityClass`. A grep for a SECOND declaration of `STRIKE|CONTROL|MOBILITY` enum is a CI error. — source: ADR-0007 Validation
- **`#9.get_dominant_ability_class()` MUST return `AbilityClass.UNKNOWN` explicitly when class is undetermined** — never rely on zero-default to produce STRIKE as a fallback. That decision belongs to `#14 EnemyDirector EC-09`, never to `#9`. — source: ADR-0007 §B + GDD

### Forbidden Approaches

- **Never use `await` in any file under `src/core/state_machine/**.gd`** — CI scan-entire-file rule. Helper functions in those files are implicitly part of the transition execution graph. `HTTPRequest` completion handlers MUST `call_deferred` any state transition logic. — source: ADR-0006 Contract 12

---

## Feature Layer Rules

*Applies to: Boss System, Loot Drop, Equipment, secondary systems*

### Required Patterns

- **BossPayload, LootPayload and all cross-transition Resource payloads MUST extend `SerializableResource`** with `to_dict()`/`from_dict()` override — required for tombstone round-trip survival. — source: ADR-0006 Contract 3
- **`BossOutcome.find_key(value)` for enum-to-string serialization** — 4.4+ API; returns `null` on invalid enum value rather than masking with default. Use in all `to_dict()` overrides for enum fields. — source: ADR-0006 Contract 3
- **Enum fields in ALL payloads serialize as string names** — `EnumType.find_key(value)` → String; on `null` (out-of-range) fall back to the family sentinel (`UNKNOWN` / `ABANDONED` / `BOOTING`). Deserialize via `EnumType.get(name_string, SENTINEL)`. — source: ADR-0007 + ADR-0009 §3
- **Signal naming: snake_case past tense** — `workout_completed`, `boss_killed`, `ability_unlocked`, `loot_dropped`. Payload class naming: PascalCase + `Payload` suffix — `StateTransitionPayload`, `BossPayload`, `BossKilledPayload`. Every GSM-correlated payload carries `transition_id: String`. — source: ADR-0009 §4
- **Promote transient signals to `SerializableResource` envelope if they ever need persistence** — no Dictionary-with-magic-keys middle ground. Retrofitting is messier than promoting up front. — source: ADR-0009 §3

### Forbidden Approaches

- **Never parse `transition_id` back into its component parts** — opaque contract; format may change in future ADR. Read context from tombstone Dictionary fields directly. — source: ADR-0006 Contract 2

---

## Presentation Layer Rules

*Applies to: UI, VFX, shaders, audio, camera*

### Required Patterns

- **Screen shake MUST use shader uniform `screen_shake_strength`** — routed through `ScreenEffects.add_trauma()`. NOT via `Camera2D.offset`. — source: technical-preferences.md (ADR-0001 enforcement — pending ratification)

### Forbidden Approaches

- **Never mutate `Camera2D.position`, `Camera2D.zoom`, or call `Camera2D.make_current()` outside `src/autoload/camera_controller.gd`** — CI enforced (`tools/ci/check_camera_callers.gd`). — source: technical-preferences.md
- **Never mutate `Camera2D.offset` outside `src/autoload/screen_effects.gd`** — screen shake uses shader uniform path; Camera.offset is reserved. CI enforced (`tools/ci/check_screen_effects_callers.gd`). — source: technical-preferences.md
- **Never instantiate `GPUParticles2D` directly** — all particle emission via `ParticleSystemWrapper.play(preset_id, position, multiplier)`. CI enforced (`tools/ci/check_particle_callers.gd`). — source: technical-preferences.md

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController`, `GameStateMachine` |
| Variables | snake_case | `move_speed`, `_lock_gen` |
| Signals / Events | snake_case past tense | `state_changed`, `health_changed` |
| Files | snake_case matching class | `player_controller.gd`, `game_state_machine.gd` |
| Scenes / Prefabs | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` |

*Source: `.claude/docs/technical-preferences.md`*

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60 fps |
| Frame budget | 16.6 ms |
| Draw calls | ≤ 200 (2D web target) |
| Memory ceiling | 512 MB (browser constraint) |
| WASM bundle | ≤ 50 MB (pending ADR-0001 ratification) |

*Source: `.claude/docs/technical-preferences.md`*

### Approved Libraries / Addons

- **GUT (Godot Unit Testing) v9.x (pinned v9.6.0)** — approved for all automated testing. Use `extends GutTest` (9.x convention; v7.x is Godot 3.x only — do NOT use). — source: technical-preferences.md

### Forbidden APIs (Godot 4.6)

These APIs are deprecated or behave differently from LLM training-data assumptions:

| Forbidden | Use Instead | Since | Notes |
|-----------|------------|-------|-------|
| `TileMap` | `TileMapLayer` | 4.3 | One node per layer |
| `yield()` | `await signal` | 4.0 | GDScript 2.0 coroutine syntax |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 | Typed callable connections |
| `instance()` / `PackedScene.instance()` | `instantiate()` | 4.0 | Renamed |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 | Time singleton preferred |
| `VisibilityNotifier2D` / `3D` | `VisibleOnScreenNotifier2D` / `3D` | 4.0 | Renamed |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 | Server-based API |
| `get_world()` | `get_world_3d()` | 4.0 | Explicit 2D/3D split |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 | Explicit deep copy — use when per-instance copies needed |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 | Moved to base class |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 | Moved to base class |
| `Texture2D` in shader parameters | `Texture` base type | 4.4 | Changed type — silent shader break |
| `GodotPhysics3D` for new projects | Jolt Physics 3D | 4.6 | Default since 4.6; better stability |
| String-based `connect()` | Typed signal connections | 4.0 | Type-safe, refactor-friendly |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables | — | GDScript compiler optimizations |
| `$NodePath` in `_process()` | `@onready var` cached reference | — | Performance: path lookup every frame |
| `rg --type gdscript` | `rg --glob "*.gd"` | — | **CI CRITICAL**: `gdscript` type invalid in ripgrep — hard error, scan never executes |

*Source: `docs/engine-reference/godot/deprecated-apis.md`*

### Cross-Cutting Constraints

- **`window.localStorage` is FORBIDDEN** — use `user://` (FileAccess / PersistenceLayer) instead. ~5MB quota + requires JavaScriptBridge. CI: `tools/ci/check_local_storage_calls.gd`. — source: technical-preferences.md (ADR-0003)
- **`SubViewport.stretch_shrink` MUST be set as integer** — float value silently truncates. Use `SubViewport.size = display_size * Vector2(1.05, 1.05)` for oversample instead. — source: technical-preferences.md (ADR-0001)
- **`JavaScriptBridge.eval()` calls MUST go through `src/autoload/platform_detect.gd` only** — CI enforced (`tools/ci/check_platform_detect_callers.gd`). — source: technical-preferences.md
- **StatSystem mutation is CLOSED** — no external write path; all stat mutations via internal event processing only. Applies to all systems that read stats. — source: architecture.md (anti-fabrication principle)
- **`cast_ability()` caller whitelist** — only `combat_resolver.gd` may call `cast_ability()`. CI enforced. — source: architecture.md
- **Single-thread WASM assumption** — all Godot logic runs on main thread in Web Export. `HTTPRequest` callbacks arrive on main thread (pseudo-async). IndexedDB writes are truly async (JavaScriptBridge). PersistenceLayer owns all async-boundary management. — source: ADR-0006 Contract 11
- **GDScript 4.5+ `@abstract` annotation available** — use for abstract base classes that MUST be overridden. Replaces `push_error("override")` stubs in `SerializableResource`, `IInputPolicy`, `IPersistence`. — source: `docs/engine-reference/godot/current-best-practices.md`

---

## Post-Cutoff Engine Behaviors (Godot 4.6 — HIGH knowledge-gap risk)

These behaviors differ from LLM training data (Godot ~4.3). Always verify before assuming:

| Behavior | Godot 4.6 Actual | LLM Training Assumption | Source |
|----------|-----------------|------------------------|--------|
| `FileAccess.store_*` return value | Returns `bool` (WASM-side success, NOT IDB commit ack) | May assume no return value | ADR-0006 Contract 11 |
| `Object.get_class()` on GDScript class | Returns engine base class name (`"Resource"`) — NOT `class_name` | May assume returns script class_name | ADR-0006 Contract 3 |
| `get_script().get_global_name()` | Returns registered `class_name` string (`"BossPayload"`) | May be unaware of this API | ADR-0006 Contract 3 |
| `Callable.call_deferred(BossPayload)` | Variadic-args ambiguity under typed signal contexts — unverified | May assume works identically to 4.3 | ADR-0006 Contract 5 |
| Autoload `_enter_tree`/`_ready` ordering | Per-autoload sequential (NOT batched) | May assume batched `_enter_tree` then batched `_ready` | ADR-0006 Contract 4 |
| Glow rendering (4.6) | Processes before tonemapping — existing glow setups look different | Pre-4.6 behavior assumed | current-best-practices.md |
| D3D12 on Windows (4.6) | Default Windows backend (was Vulkan) | Vulkan assumed | current-best-practices.md |
| Jolt Physics 3D (4.6) | Default 3D physics engine | GodotPhysics3D assumed | current-best-practices.md |
| `BossOutcome.find_key(value)` | 4.4+ API; returns `null` on invalid value | May not be aware of `find_key` | ADR-0006 Contract 3 |
| `duplicate_deep()` | 4.5+ explicit deep copy for nested resources | `duplicate()` assumed to deep copy | deprecated-apis.md |

*Full engine knowledge gaps: `docs/engine-reference/godot/VERSION.md` + `docs/engine-reference/godot/breaking-changes.md`*

---

## VS-Tier Verification Spikes Required Before Implementation

These rules have UNVERIFIED engine behaviors that must be confirmed during VS spike:

| Spike | Contract | Risk | Owner |
|-------|----------|------|-------|
| COOP/COEP threading default state in Godot 4.6 Web Export | ADR-0006 Contract 1 (Q-A4) | HIGH — atomicity assumptions | engine-programmer + godot-specialist |
| `FileAccess.flush()` IDB ack timing — measure vs WASM-accept timing | ADR-0006 Contract 11 (Q-A4) | HIGH — 0.05% tombstone-loss window | engine-programmer |
| `Callable.call_deferred(BossPayload)` vs lambda+connect semantics | ADR-0006 Contract 5 | MEDIUM — variadic-args ambiguity | godot-gdscript-specialist |
| GPUParticles2D iOS Safari WebGL2 performance (particle budget) | ADR-0001 (pending ratification) | HIGH — mobile particle floor | technical-artist |
| Camera2D.position_smoothing iOS Safari Compatibility renderer | ADR-0001 (pending ratification) | HIGH — camera follow on target hardware | gameplay-programmer |

---

## Pending Rule Coverage (Proposed ADRs — add to manifest when Accepted)

When these ADRs are ratified, re-run `/create-control-manifest` to add their rules:

| ADR | Domain | Missing Rule Areas |
|-----|--------|--------------------|
| ADR-0001 (Web Export Budget Caps) | Rendering, Particles, Camera | GPU budget limits, particle pool rules, camera smoothing rules, WASM bundle size |
| ADR-0002 (GymSys Integration) | Networking | HTTP polling pattern, session token handling, differential cursor rules |
| ADR-0003 (Save State Strategy) | Persistence | Namespace ownership, IDB backend sync, Private Mode gate, Safari ITP |
| ADR-0004 (CORS Auth Topology) | Networking | nginx proxy rules, relative URL requirement, JavaScriptBridge restrictions |
| ADR-0005 (Loot Rarity Formula) | Economy | RNG constraint rules, Pillar 1 floor enforcement, workout_score primacy |
| ADR-0008 (Autoload Position Map) | Foundation | Absolute autoload positions from project.godot, insertion rules for new autoloads (#33/#4/#28) |
| ADR-0010 (MirrorMoment Ceremony Ownership) | Presentation | AvatarRenderer render-only API boundary, MirrorMoment ceremony-trigger ownership |

> **Covered since last update (2026-05-29)**: ADR-0007 (Class & Domain Enum Convention) + ADR-0009 (Signal Payload Schema Convention) — rules now embedded in Foundation/Core/Feature layers above.
