# ADR-0006: State Machine Contract

## Status

**Accepted 2026-05-28** (ratified via 2 parallel specialist gate signoffs — Gate A systems-designer APPROVE + Gate B creative-director APPROVE WITH CONCERN; both ratification reports archived in session-state active.md)

## Date

2026-05-25 (authored) / 2026-05-28 (ratified Proposed → Accepted)

## Last Verified

2026-05-28 (ratification verification — Gate A Contract 8 knob ranges + Gate B Contract 11 Pillar 3 tolerance)

## Decision Makers

Frank (Producer / Project Lead) + technical-director (TD-ADR APPROVE w/ non-blocking concerns) + godot-specialist (engine validation NEEDS REVISION → resolved) + gameplay-programmer / systems-designer / qa-lead / game-designer (consulted via 3 design-review passes on driving GDD)

**Ratification signoffs 2026-05-28** (Proposed → Accepted gate):
- **Gate A — systems-designer APPROVE**: Contract 8 corrected knob safe ranges (`STATE_TRANSITION_FALLBACK_MS` 100..1499, `MIN_REVEAL_WINDOW_SECONDS` 11..30) mathematically verified via Invariant 1 derivation. Designer flexibility loss judged as "unsafe corner" not valid tuning space. **Follow-up tracked (not blocking)**: Invariant 1 boundary gap at `FALLBACK=1499` + `MIN_REVEAL=11` (1499 > 1100=11×100) — combination is in safe range but violates invariant 1 at runtime assert. Resolution options: (a) tighten `STATE_TRANSITION_FALLBACK_MS` upper to 1100ms, OR (b) add cross-knob warning in GDD ("若 `MIN_REVEAL<15`, `FALLBACK` 必須同時降至 `MIN_REVEAL×100−1`"). Defer to follow-up story; production defaults (`FALLBACK=1000`, `MIN_REVEAL=15`) safely in invariant center.
- **Gate B — creative-director APPROVE WITH CONCERN** (game-designer perspective consulted inline): 0.05% pre-commit tombstone-loss window falls within Pillar 3 "Drop Euphoria" tolerance AT VS TIER specifically. Reasoning: pre-commit window only manifests when (i) ceremony already emitted AND (ii) crash within < 1 frame AND (iii) backend reconciliation (LootDrop Rule 17) fails to recover → triple-conditional rare event. Solo-dev player base: ~1 occurrence per 2,857 sessions per LootDrop transition = ~10-19 years per single player on weekly 3-5 workouts. Player perception class = "saw + reconciliation recovers next boot" (recoverable perception loss), NOT "saw but lost without recovery" (hard contract breach). **5 MVP escalation triggers MUST be enforced** (see Negative Consequences footnote below).

**Previous Note on Contract 8 corrected safe ranges (RESOLVED 2026-05-28)**: tightening derived from Invariant 1 math, not direct systems-designer signoff in this ADR session. Open follow-up: systems-designer to ratify corrected ranges at Pass 4 verification — if rejected, Contract 8 invariants relax or other knob adjusts. → **CLOSED via Gate A APPROVE 2026-05-28 with cross-knob warning follow-up tracked**.

## Summary

Game State Machine 經 3 輪 design-review 揭示 15 個 architectural-level contracts 必須 lock 死先可以實作 — atomic transition primitive、`transition_id` collision-safety、Resource serialization envelope、Godot 4.6 autoload boot ordering、IndexedDB async-commit semantics、knob invariant runtime enforcement、test spy contract 等。本 ADR 為 `game-state-machine.md` 嘅 9-state FSM 鎖定全部 engine-level + persistence-level 契約，supersede GDD §ADR-006 Escalation Boundary 列出嘅 15 個 deferred items；GDD prose 喺呢啲 item 上 provisional pending 本 ADR ratification。

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 (pinned 2026-02-12) |
| **Domain** | Core / Scripting (autoload lifecycle, Callable / signal semantics, Resource serialization, FileAccess + IndexedDB sync layer) |
| **Knowledge Risk** | HIGH — Godot 4.6 released Jan 2026, post-LLM-cutoff May 2025. Three relevant breaking changes between cutoff and pin: GDScript variadic args (4.5), `duplicate_deep()` for Resource (4.5), `FileAccess.store_*` returns bool (4.4). Autoload `_enter_tree`/`_ready` ordering verified against migration docs (cited below). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/deprecated-apis.md`, https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html, https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html |
| **Post-Cutoff APIs Used** | `FileAccess.store_*` returning bool (4.4); GDScript variadic args (4.5) — explicitly avoided in `Callable.call_deferred()` paths via single-arg discipline; `Enum.find_key()` (4.4+) used in `BossPayload.to_dict()` for safer enum-to-string. Considered but NOT used: `Resource.duplicate_deep()` (4.5) — payload round-trip uses explicit `to_dict`/`from_dict` (Contract 3), bypassing duplicate-deep semantics entirely. |
| **Verification Required** | (1) Godot 4.6 single-thread WASM atomicity assumption holds when COOP/COEP headers absent (Q-A4 VS spike); (2) `FileAccess.flush()` semantics on Web Export — confirm IDB commit ack vs WASM-side accept timing; (3) Autoload `_enter_tree` then `_ready` per-autoload sequential ordering (NOT batched) verified against actual 4.6 SceneTree behavior; (4) `JavaScriptBridge.create_callback()` GC retention behavior under bfcache restore |

> **Note**: Knowledge Risk is HIGH. This ADR must be re-validated when project upgrades to Godot 4.7+ or any 4.6.x patch that touches Core / FileAccess / Autoload. Flag as Superseded and write replacement ADR.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (no prior ADRs exist; this is the first ADR ratified for the project) |
| **Enables** | ADR-002 (GymSys integration protocol — needs `transition_id` contract + 401 + session API + LootDrop cache/commit endpoints); ADR-003 (PersistenceLayer save state strategy — needs IDB fence semantics + schema migration chain bounds + `BossPayload.to_dict()` envelope); GDD #3 (PersistenceLayer GDD authoring); GDD #2 (GymSys Backend Client GDD authoring) |
| **Blocks** | Pass 4 light verification of `game-state-machine.md` (cannot run until this ADR ratified); VS implementation of state machine (no story can begin without locked contracts); all downstream GDD authoring touching state machine signals/payloads |
| **Ordering Note** | Must be ratified BEFORE ADR-002 / ADR-003 / GDD #3 authoring begins. Decision #4 (single-device session lock) in GDD #1 specifies the schema this ADR binds; ADR-002 inherits the binding. |

## Context

### Problem Statement

Game State Machine 喺 3 輪 adversarial design-review 之後揭示，9-state FSM 嘅 prose 已涵蓋全部 gameplay rules + pillar enforcement，但 15 個 engineering-level contracts 仍然 ambiguous 或 incorrect — 包括 atomicity primitive 嘅 Godot-native 實現、`transition_id` 喺 WASM reload 之後嘅 collision-safety、`JSON.stringify(Resource)` silently 丟 BossPayload 嘅 bug、autoload `_enter_tree`/`_ready` 真實 ordering 同 GDD 描述自相矛盾、knob invariant math 喺 safe-range boundaries 失效等。任何 story 喺呢 15 個 contracts 未 lock 之前實作都會踩 Pillar 3 (Drop Euphoria hard guarantee) 或 Pillar 2 (Frictionless Companion) 嘅 anti-pattern。Pass 3 design-review verdict 為 NEEDS REVISION 並 escalated 全部 15 items 到本 ADR；GDD prose 喺呢啲 item 上 explicitly provisional。

### Current State

GDD `design/gdd/game-state-machine.md`（830 行，38 ACs，9-state enum，5 locked design decisions）prose-locked。§ADR-006 Escalation Boundary 列明 15 個 deferred contracts。Pass 3 結論：「atomicity bugs diverging not converging across 3 passes」— 即係用 prose 修改方式無法收斂；必須 architecture-level lock。

### Constraints

- **Engine**: Godot 4.6 Web Export (HTML5 / WASM) primary target；Compatibility renderer；single-thread JS event loop（COOP/COEP threading 預設 OFF — VS spike Q-A4 validate）
- **Platform**: iOS Safari + Android Chrome；Safari ITP 7-day eviction window；bfcache restore semantics
- **Storage**: IndexedDB via Godot `user://`；50MB-1GB quota；async-commit delay ~1 frame
- **Performance**: 60 fps target；16.6ms frame budget；transition function single-frame execution (no `await` 喺 `_transition_*` functions)
- **Memory**: 512MB browser ceiling — 持續 leak 不容許
- **Knowledge cutoff**: LLM training data May 2025；engine pinned Jan 2026 — 8 個月 gap，post-cutoff APIs 必須 verified-against-reference 而唔可以直接從 training data 推

### Requirements

- **Atomicity**: State transition 必須 atomic — 唔可以 mid-transition 被 subscriber 同步 re-enter 出第二個 transition (Pass 3 B1-B4 揭示 4 個 re-entrance vectors)
- **Idempotency**: Forward-recovery on WASM reload 必須 idempotent — 同一個 `transition_id` 重做任意次 都得 same final state，backend dedupe via UNIQUE constraint
- **Determinism**: Boot reconciliation 必須 deterministic — same persisted state input → same `current_state` output；schema migration chain 必須 bounded
- **Pillar 3 hard guarantee**: LootDrop 永遠唔可以因為 tab close / crash / 30-day inactivity 而 silently 消失 — 必須有 ritual recovery path
- **Pillar 2 enforcement**: 過渡無 blocking input requirement during active states；toast / modal gating
- **Testability**: 全部 38 ACs 必須 mechanically verifiable — 即 test spy interface 必須 explicit + portable across test authors
- **Engine-version verified**: 所有 API choice 必須對應 Godot 4.6 actual behavior，唔可以靠 LLM training-data 推測

## Decision

本 ADR lock 死 15 個 sub-contracts，每個對應 GDD §ADR-006 Escalation Boundary 嘅一個 item。Items 編號保留 GDD 嘅 1-15 對應，方便 cross-ref。

### Contract 1 — Atomic Transition Primitive: Generational Lock ID + `call_deferred` Discipline

**Chosen approach**: Generational lock ID + mandated `call_deferred` discipline for all subscriber re-entry paths. Works in single-thread WASM (Godot 4.6 default) AND future-proofs COOP/COEP threading (Q-A4).

**Mechanism**:

```gdscript
class_name GameStateMachine extends Node

var _transitioning: bool = false
var _lock_gen: int = 0                    # generational counter — increments each transition
var _last_emit_tick: int = -1             # see Contract 7
var _force_clear_timer: SceneTreeTimer    # per-transition scoped, not global

func _request_transition(event: TransitionEvent) -> void:
    if _transitioning:
        emit_signal("dropped_event", event, "lock_held")
        return
    _transitioning = true
    _lock_gen += 1
    var my_gen: int = _lock_gen
    # Per-transition fallback timer (Contract 1.b — NOT a process-global timer).
    # Stale timers from prior transitions may still emit `timeout` after release;
    # they harmlessly invoke `_force_clear_lock(old_gen)` and the generational
    # check below ensures the lock is cleared only when the captured_gen matches.
    _force_clear_timer = get_tree().create_timer(STATE_TRANSITION_FALLBACK_MS / 1000.0)
    _force_clear_timer.timeout.connect(_force_clear_lock.bind(my_gen), CONNECT_ONE_SHOT)
    # ... Rule 2 steps 1-7 ...
    _last_emit_tick = Time.get_ticks_usec()
    state_changed.emit(from, to, payload)  # subscribers run synchronously here
    _transitioning = false                  # released AFTER emit (per GDD Rule 2)

func _force_clear_lock(captured_gen: int) -> void:
    # Only clear if THIS generation's lock is still stuck — guards against
    # spurious clears across generations.
    if captured_gen == _lock_gen and _transitioning:
        _transitioning = false
```

**Re-entrance guarantees**:

- **Synchronous re-entry from subscriber** (e.g., `state_changed` handler immediately calls `_request_transition`): blocked by `_transitioning == true` guard → `dropped_event` signal fires → subscriber MUST use `call_deferred("_request_transition", event)` for follow-up transitions (binding rule, AC-04a verifies).
- **`HTTPRequest.request_completed` re-entry**: handler MUST `call_deferred` any state transition logic; direct synchronous transition call from `request_completed` is forbidden. Static analyzer (Contract 12) scans for this.
- **Fallback timer cross-transition unlock**: timer captures `my_gen` at creation; on fire, only clears lock IF current `_lock_gen` matches (i.e., still THIS transition's lock). Eliminates Pass 3 B2 cross-transition unlock bug.
- **`add_child` deferred ordering for orphan HTTPRequest**: mandated pattern (Contract 1.c) — `add_child(http_node)` then `await get_tree().process_frame` is FORBIDDEN inside transition function; instead, `add_child` followed by `http_node.request(url)` is permitted. Godot 4.6 verified behavior: `add_child` adds to tree synchronously when parent is in tree, and `request()` *call site* runs synchronously without needing `_ready` to have fired. **Completion arrives asynchronously via `request_completed` signal (next frame at earliest)** — the handler MUST `call_deferred` any state transition logic (Contract 5 idiom).
- **Forward-recovery `transition_id` regeneration**: forward-recovery code path MUST reuse tombstone's persisted `transition_id` verbatim — NEVER call `_generate_transition_id()`. Enforced by static analyzer + AC-32a.

**Why generational lock over Mutex**: Godot 4.6 Web Export defaults to single-thread (COOP/COEP off). Mutex adds API friction with zero benefit until Q-A4 spike confirms threading. Generational lock works identically in both threading modes — future-proof without immediate overhead.

**Why over pure `call_deferred` frame-boundary lock**: pure `call_deferred` would delay every transition by 1 frame (16.6ms). Boss-defeat → LootDrop transition delayed = Pillar 3 ritual hiccup. Generational lock allows synchronous transition with safe re-entrance check.

### Contract 2 — `transition_id` Collision-Safe Generation Across WASM Reload

**Chosen approach**: `wall_clock_anchor_ms × 1000 + persisted_monotonic_counter`. Counter persisted in `user://state.json` (NEW key `_transition_id_counter: int`). Forward-recovery MUST reuse tombstone's `transition_id` verbatim.

**Generation algorithm**:

```gdscript
const TRANSITION_ID_COUNTER_KEY: String = "_transition_id_counter"

func _generate_transition_id(from: String, to: String) -> String:
    var wall_clock_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
    var counter: int = PersistenceLayer.read().get(TRANSITION_ID_COUNTER_KEY, 0)
    counter += 1
    PersistenceLayer.write(TRANSITION_ID_COUNTER_KEY, counter)  # increment FIRST
    # Format: <unix_ms>_<counter>_<from>_<to>
    # Backend UNIQUE constraint on this exact string.
    return "%d_%d_%s_%s" % [wall_clock_ms, counter, from, to]

# Forward-recovery path
func _forward_recover_from_tombstone(tombstone: Dictionary) -> void:
    var existing_id: String = tombstone["transition_id"]   # REUSE — never regenerate
    # ... Rule 2 step 3-8 with existing_id ...
```

**Collision-safety guarantee**:

- Within same boot session: `counter` monotonically increases → no collision even if two transitions happen in same millisecond.
- Across WASM reload: `counter` persisted → reload reads `counter = 42`, next transition uses `43`. No reset.
- Across NTP clock drift: `wall_clock_anchor_ms` jumps tolerated — `counter` portion guarantees uniqueness even if clock rolls back.
- Across device handoff: account-scoped backend `UNIQUE` constraint catches any rare overlap (different devices' wall-clock + counter combine to different strings; collision odds < 10^-9 per workout session).

**Forward-recovery rule (binding)**: `_forward_recover_from_tombstone` MUST extract `tombstone["transition_id"]` and use it verbatim through Rule 2 step 3-8 replay. Static analyzer (Contract 12) scans for `_generate_transition_id` calls inside any function name matching `_forward_recover*` — if found, CI fails.

**Counter persistence cost**: 1 extra `PersistenceLayer.write` per transition (one `int` field). Acceptable given transitions happen < 10/min in normal play.

**`transition_id` is opaque** (binding rule): the format `<unix_ms>_<counter>_<from>_<to>` is for backend UNIQUE constraint lookup + debug log inspection ONLY. No code path may parse `transition_id` to recover `from` / `to` / counter — state names may contain underscores (e.g., `workout_active`, `rest_period`) which makes the split ambiguous. If recovery context is needed, read it from the tombstone Dictionary fields directly.

### Contract 3 — Tombstone Serialization Envelope: `to_dict()` / `from_dict()` Explicit Schema

**Chosen approach**: Resource type preserved in code (debugger + IDE auto-complete benefit), but serialization to `user://state.json` MUST route through explicit `to_dict()` / `from_dict()` methods. Each Resource payload class MUST implement both methods.

**Mandatory Resource interface**:

```gdscript
class_name SerializableResource extends Resource

# Override in subclasses. Default returns empty Dictionary — must be overridden.
func to_dict() -> Dictionary:
    push_error("SerializableResource.to_dict() not overridden by %s" % get_class())
    return {}

static func from_dict(_data: Dictionary) -> SerializableResource:
    push_error("SerializableResource.from_dict() not overridden")
    return null
```

**Example: `BossPayload`**:

```gdscript
class_name BossPayload extends SerializableResource

enum BossOutcome { DEFEATED, INTERRUPTED_WITH_CREDIT, ABANDONED }

@export var outcome: BossOutcome
@export var boss_id: int
@export var hp_at_interrupt: int
@export var hp_max: int

func to_dict() -> Dictionary:
    # Use BossOutcome.find_key(outcome) — 4.4+ API; returns null on invalid enum value
    # rather than masking with .keys()[0] = "DEFEATED" on uninitialized default.
    var outcome_str: Variant = BossOutcome.find_key(outcome)
    return {
        "outcome": outcome_str if outcome_str != null else "ABANDONED",
        "boss_id": boss_id,
        "hp_at_interrupt": hp_at_interrupt,
        "hp_max": hp_max,
    }

static func from_dict(data: Dictionary) -> BossPayload:
    var p := BossPayload.new()
    p.outcome = BossOutcome[data.get("outcome", "ABANDONED")]
    p.boss_id = data.get("boss_id", 0)
    p.hp_at_interrupt = data.get("hp_at_interrupt", 0)
    p.hp_max = data.get("hp_max", 0)
    return p
```

**Tombstone write path**:

```gdscript
# Rule 2 step 2: write tombstone
# CRITICAL: payload_type MUST use get_script().get_global_name() — NOT get_class().
# In Godot 4.6, Object.get_class() returns the engine class ("Resource"), NOT the
# GDScript class_name. Using get_class() would silently produce "Resource" for
# every payload and break forward-recovery (round-trips to null). The
# get_script().get_global_name() API returns the registered class_name (e.g.,
# "BossPayload") as required.
var payload_type: String = ""
if payload != null and payload.get_script() != null:
    payload_type = payload.get_script().get_global_name()

var tombstone: Dictionary = {
    "transition_id": tid,
    "from": from_state,
    "to": to_state,
    "wall_clock_anchor": Time.get_unix_time_from_system(),
    "monotonic_anchor": Time.get_ticks_usec(),
    "payload": payload.to_dict() if payload is SerializableResource else {},
    "payload_type": payload_type,
}
PersistenceLayer.write("pending_transition", tombstone)
```

**Tombstone read path (forward-recovery)**:

```gdscript
var tombstone: Dictionary = PersistenceLayer.read().get("pending_transition", {})
var payload_data: Dictionary = tombstone.get("payload", {})
var payload_type: String = tombstone.get("payload_type", "")
var payload: SerializableResource = null
match payload_type:
    "BossPayload": payload = BossPayload.from_dict(payload_data)
    "LootPayload": payload = LootPayload.from_dict(payload_data)
    "StateTransitionPayload": payload = StateTransitionPayload.from_dict(payload_data)
    "": payload = null   # no payload
    _:
        push_error("Unknown payload_type '%s' in tombstone — payload lost" % payload_type)
        payload = null
```

**Why over `var_to_bytes` + base64**: debug-readability is critical for VS — `pending_transition` blob 喺 IndexedDB devtools 必須人類可讀。`var_to_bytes` 變 binary blob，schema migration 寫 manual byte-level rewrite。`to_dict` 對應 community Godot pattern，schema migration 就係 `Dictionary` 操作。

**Why over `Dictionary` throughout (drop Resource type)**: lose `BossOutcome` enum type-checking → AC-11a 嘅 `outcome == INTERRUPTED_WITH_CREDIT` 變 string compare with no IDE warning on typo。Code-side Resource preserves type-safety；serialization-boundary explicit conversion gets best of both worlds.

**Binding rule**: 任何 Resource subclass 嘅 instance 傳入 `StateTransitionPayload.data` Dictionary 都必須 extends `SerializableResource` + implement 兩個 methods。Static analyzer (Contract 12) scans `extends Resource` declarations that appear in `StateTransitionPayload` usage paths — flag missing `to_dict` override.

### Contract 4 — Autoload `_enter_tree` / `_ready` Ordering (Godot 4.6 Verified Behavior)

**Verified Godot 4.6 behavior** (cross-referenced against Godot SceneTree autoload source + 4.5→4.6 migration doc):

> Autoloads are added to the root in Project Settings → Autoload list order. Each autoload's `_enter_tree` is called immediately upon `add_child`, followed by `_ready` once the node has finished setup. **The next autoload in the list is NOT added until the previous autoload's `_ready` has fully returned.** Per-autoload sequential, NOT batched.

**Correct boot model** (supersedes GDD Phase B/C "batched" framing — Phase B/C in GDD §Boot Sequence is rewritten by this contract):

```
For each autoload in Project Settings list order:
  1. Engine calls add_child(autoload_instance)
  2. autoload._enter_tree() runs to completion
  3. autoload._ready() runs to completion
  4. Engine proceeds to next autoload

Autoload load order (locked):
  1. PersistenceLayer
  2. GameStateMachine
  3. EnemyDirector / LootDropSystem / AttentionBudget / GymSysClient / ...
```

**Implication for `state_changed` signal**:

- `PersistenceLayer._ready()` completes BEFORE `GameStateMachine._ready()` begins → `PersistenceLayer.read()` is safe to call synchronously from `GameStateMachine._ready()`.
- `GameStateMachine._ready()` completes BEFORE downstream autoloads (`EnemyDirector`, etc.) begin → if GameStateMachine emits `state_changed` from its `_ready`, downstream autoloads have NOT YET CONNECTED → emit is lost.
- **DO NOT emit "initial" `state_changed` from `GameStateMachine._ready()`.** Instead, expose `connect_for_initial_state(callable: Callable)` helper. See Contract 6 + 7.

**GDD §Boot Sequence Phase B + Phase C replacement** (supersedes lines 401-419 of `game-state-machine.md`):

> **Phase B + C (merged) — Autoload per-instance sequential**: For each autoload in Project Settings list order:
> 1. Engine adds autoload to root.
> 2. `_enter_tree()` runs synchronously to completion.
> 3. `_ready()` runs synchronously to completion.
> 4. Engine proceeds to next autoload.
>
> `PersistenceLayer` autoload (position 1) completes both `_enter_tree` + `_ready` before `GameStateMachine` (position 2) begins. `GameStateMachine._ready()` may safely call `PersistenceLayer.read()` synchronously. `GameStateMachine._ready()` must NOT emit `state_changed` — downstream subscribers (positions 3+) have not yet connected; emit would be lost. Subscribers obtain initial state via `connect_for_initial_state(callable)` helper (see Contract 6 + 7).

### Contract 5 — `Callable.call_deferred()` Signature Under Godot 4.6 Variadic Args

**Verified Godot 4.6 behavior**: GDScript 4.5+ introduced variadic args (`Variant...`). `Callable.call_deferred(args...)` accepts variadic params but the resolution under typed signal contexts can be ambiguous when payload type is a Resource subclass.

**Mandated safer idiom** for all deferred re-entry from subscribers:

```gdscript
# FORBIDDEN — ambiguous typed-resource resolution under variadic
state_machine._request_transition.call_deferred(event)

# REQUIRED — single-shot signal-driven deferred path
get_tree().process_frame.connect(
    func(): state_machine._request_transition(event),
    CONNECT_ONE_SHOT
)
```

**Why**: `CONNECT_ONE_SHOT` guarantees one-time invocation; lambda captures `event` by value at connection time (Resource ref-counted, safe); `process_frame` signal fires at next frame's top — deterministic ordering. Variadic-args ambiguity bypassed by lambda wrapping.

**Verification required**: VS spike to confirm Godot 4.6 `Callable.call_deferred(BossPayload_instance)` works identically to lambda+connect pattern. If verified equivalent, downgrade this contract to "either pattern acceptable"; if any divergence found, lambda+connect remains binding.

**Status (VS tier)**: lambda + `process_frame.connect` ONE_SHOT is the **preferred idiom**. Direct `_request_transition.call_deferred(event)` is **flagged but not blocked** in CI — VS spike measures actual variadic-resolution behavior. If spike confirms identical semantics under 4.6, this contract downgrades to "either pattern acceptable"; if any divergence found, lambda+connect becomes binding (this ADR re-rated to MEDIUM risk under that scenario).

**Static analyzer enforcement** (Contract 12): scan for `_request_transition.call_deferred(` literal pattern outside of `_request_transition` itself — emit CI warning (NOT failure) until VS spike outcome.

### Contract 6 — Initial-State Delivery Typed-Signal Contract

**Problem**: `connect_for_initial_state(callable)` helper passes a payload to subscriber. Current GDD draft passes `null` as `payload: StateTransitionPayload` — null-deref footgun (Pass 3 godot-specialist B3).

**Solution — sentinel payload**:

```gdscript
class_name GameStateMachine extends Node

const INITIAL_STATE_PAYLOAD_SOURCE_EVENT: String = "initial_state"

# Singleton sentinel payload, constructed once at boot. Subscribers can
# `if payload.source_event == "initial_state"` to detect initial-state delivery.
var _initial_state_payload: StateTransitionPayload

func _ready() -> void:
    _initial_state_payload = StateTransitionPayload.new()
    _initial_state_payload.source_event = INITIAL_STATE_PAYLOAD_SOURCE_EVENT
    _initial_state_payload.data = {}
    # ... rest of _ready ...

func connect_for_initial_state(callable: Callable) -> void:
    state_changed.connect(callable)
    # Deferred so subscriber's connect to other signals completes first
    var captured_state: String = _current_state
    var captured_tick: int = _last_emit_tick  # Contract 7 race guard
    get_tree().process_frame.connect(
        func(): _deliver_initial_state(callable, captured_state, captured_tick),
        CONNECT_ONE_SHOT
    )

func _deliver_initial_state(callable: Callable, captured_state: String, captured_tick: int) -> void:
    # Contract 7 race guard: if a real transition fired since connect, skip
    # initial-state delivery — subscriber already got the up-to-date state.
    if _last_emit_tick > captured_tick:
        return
    # Use callv with positional array — matches Godot's signal-dispatcher behavior
    # for non-bound Callables. We deliberately bypass signal.emit() here because
    # emit() would broadcast to ALL subscribers, not just the newly-connected one.
    # See "Initial-state delivery contract" rule below.
    callable.callv(["", captured_state, _initial_state_payload])
```

**Initial-state delivery contract** (binding semantics — NOT identical to `signal.emit`):

`connect_for_initial_state` delivers the initial state by invoking the registered Callable directly via `Callable.callv([from, to, payload])`, NOT by calling `state_changed.emit(...)`. This is intentional: `emit()` would broadcast to every subscriber, including those already up-to-date. Direct `callv` targets only the newly-connecting subscriber.

**Consequence**: the Callable passed to `connect_for_initial_state` MUST accept the standard 3-argument signature `(from_state: String, to_state: String, payload: StateTransitionPayload)` and MUST NOT be created with `.bind()` extra args. `.bind()` would shift the positional argument layout and silently mis-deliver the initial state.

```gdscript
# CORRECT
state_machine.connect_for_initial_state(_on_state_changed)
func _on_state_changed(from: String, to: String, payload: StateTransitionPayload) -> void:
    if payload.source_event == "initial_state":
        # initial-state delivery — handle differently if needed
        pass

# FORBIDDEN — .bind() shifts arg positions; callv will mis-deliver
state_machine.connect_for_initial_state(_on_state_changed.bind(my_extra_context))
```

CI rule (Contract 12 scope addition): scan for `connect_for_initial_state(*.bind(*))` literal pattern — flag as error.

**Sentinel detection**: subscribers handling `state_changed` MAY check `payload.source_event == "initial_state"` if they need to distinguish initial-state delivery from real transitions. The sentinel reaches the subscriber identically via callv (initial) or emit (real transitions) — same arg positions. AC-30 rewrites to verify sentinel pattern.

### Contract 6 Addendum — Self-Loop Pattern Ratification (2026-05-28 F-STEP4-1 resolution)

**Background**: The Contract 6 code sample above (line 374) shows `callable.callv(["", captured_state, _initial_state_payload])` — the first argument is an empty String `""` for `from_state`. This is incompatible with the canonical typed signal contract: GDD `design/gdd/game-state-machine.md` line 576 declares `signal state_changed(from_state: GameState, to_state: GameState, payload: StateTransitionPayload)` — `GameState` is an enum, not a String. Passing `""` to a typed-enum callable parameter violates the typed signature (Godot 4.6 callv either fails silently in release or asserts in debug, depending on the callable's typed-bind state).

This divergence surfaced during Foundation chain step 4 (2026-05-28 godot-gdscript-specialist implementation pass). The specialist surfaced the type mismatch when implementing `connect_for_initial_state` in `src/autoload/game_state_machine.gd` against the enum-typed signal contract.

**Two resolution options were considered**:

- **(a) Self-loop sentinel pattern**: callv args become `[_current_state, _current_state, _initial_state_payload]` (i.e., `from == to == current state`). Subscribers detect initial-state delivery via `payload.source_event == INITIAL_STATE_PAYLOAD_SOURCE_EVENT` ("initial_state"). Zero ripple to GameState enum or downstream ACs.
- **(b) Introduce `GameState.INITIAL` enum value**: would extend the canonical 9-state enum to 10 states. Cascades through 51 ACs in `design/gdd/game-state-machine.md` + every downstream GDD that enumerates the state set + every subscriber's exhaustive match logic. Major design surface change.

**Ratified resolution (2026-05-28): Option (a) self-loop pattern.**

Rationale:
- Preserves canonical 9-state GameState enum locked by GDD §Decision (no AC ripple)
- Sentinel-by-`source_event` is the contract Contract 6 already documented for distinguishing initial from real transitions (line 397) — subscribers were already supposed to use this discriminator, not `from == ""`
- Zero downstream blast radius — no GDD revision required across the 7+ subscriber systems
- Matches the implementation that landed in `src/autoload/game_state_machine.gd` Foundation chain step 4 + the test that landed in `tests/unit/state_machine/connect_for_initial_state_test.gd` step 6

**Updated Contract 6 code sample** (supersedes line 374 + line 627 of GDD code samples):

```gdscript
func _deliver_initial_state(callable: Callable, captured_state: GameState, captured_tick: int) -> void:
    if _last_emit_tick > captured_tick:    # Contract 7 race guard — real transition fired since connect → skip stale
        return
    # Self-loop sentinel: from == to == current state. Subscribers detect via
    # payload.source_event == "initial_state" (NOT via from == "" — that pattern
    # is incompatible with GameState-typed signal signature).
    callable.callv([captured_state, captured_state, _initial_state_payload])
```

**Note on `captured_state` type**: also changed from `String` to `GameState` (Contract 6 code line 358 type sync). The original `String` annotation was an artifact of pre-enum framing; the GDD's enum-typed signal contract is canonical.

**Implementation locations honoring this addendum**:
- `src/autoload/game_state_machine.gd` — `connect_for_initial_state` + `_deliver_initial_state` per Foundation step 4
- `design/gdd/game-state-machine.md` lines 615-630 — code sample updated to self-loop pattern per F-STEP4-2 GDD sync 2026-05-28
- `tests/unit/state_machine/connect_for_initial_state_test.gd` — `test_initial_state_delivered_on_next_process_frame` asserts `from == to == _current_state` (self-loop verification)
- `tools/ci/check_connect_for_initial_state_bind.gd` — CI lint enforces `.bind()` prohibition (Contract 6 line 391 binding)

**ADR-006 supersedes**: Contract 6 code sample line 374 (deprecated `["", captured_state, _initial_state_payload]` pattern) is now superseded by the self-loop pattern above. The line 374 prose remains as historical record; readers should refer to this addendum for current binding semantics.

### Contract 7 — `connect_for_initial_state` Race Guard

**Problem** (Pass 3 godot-specialist B4): subscriber A connects via `connect_for_initial_state(my_handler)`. Before next frame, GymSys poll triggers real transition → `state_changed` fires → A's `my_handler` runs with NEW state. Then deferred initial-state lambda fires → A's `my_handler` runs AGAIN with OLD (now stale) state. A sees: new → old → desync.

**Solution — `_last_emit_tick` capture + skip-stale guard** (already shown in Contract 6 code above):

- `connect_for_initial_state` captures `_last_emit_tick` at connect time.
- Deferred lambda checks `_last_emit_tick > captured_tick` → if true, real transition fired since connect → skip initial-state delivery.
- `_last_emit_tick` updated in Rule 2 step 7 (right before `state_changed.emit`).

**Acceptance check (NEW AC-30a, derived from existing AC-30)**: Test connects subscriber, then immediately calls `_request_transition` before next frame; subscriber should receive ONLY the real transition, never the stale initial-state delivery.

### Contract 8 — Knob Invariant Runtime `assert()` Enforcement

**Chosen approach**: Move all knob invariants from prose-only to runtime `assert()` at autoload boot. Pass 3 systems-designer B1-B4 揭示 4 個 invariants fail at safe-range boundaries — runtime check catches before VS playtest.

**Boot-time invariant check** (called from `GameStateMachine._ready()` after knob constants loaded):

```gdscript
func _assert_knob_invariants() -> void:
    # Invariant 1 (was: STATE_TRANSITION_FALLBACK_MS ≤ EXERCISE_SWITCH_TIMEOUT × 0.1
    #               which failed at boundaries. Replaced per Decision #3.)
    assert(
        STATE_TRANSITION_FALLBACK_MS <= MIN_REVEAL_WINDOW_SECONDS * 100,
        "Invariant 1 violated: STATE_TRANSITION_FALLBACK_MS (%d) > MIN_REVEAL_WINDOW_SECONDS (%d) × 100" %
            [STATE_TRANSITION_FALLBACK_MS, MIN_REVEAL_WINDOW_SECONDS]
    )
    # Invariant 2: TOMBSTONE_TTL_SECONDS < SUSPENSION_TTL_SECONDS (strict <, not ≤)
    assert(
        TOMBSTONE_TTL_SECONDS < SUSPENSION_TTL_SECONDS,
        "Invariant 2: TOMBSTONE_TTL (%d) must be STRICTLY less than SUSPENSION_TTL (%d)" %
            [TOMBSTONE_TTL_SECONDS, SUSPENSION_TTL_SECONDS]
    )
    # Invariant 3: LOOTDROP_PENDING_TTL_DAYS < LOOTDROP_PENDING_HARD_CAP_DAYS
    assert(
        LOOTDROP_PENDING_TTL_DAYS < LOOTDROP_PENDING_HARD_CAP_DAYS,
        "Invariant 3: SOFT_TTL (%d) must be < HARD_CAP (%d)" %
            [LOOTDROP_PENDING_TTL_DAYS, LOOTDROP_PENDING_HARD_CAP_DAYS]
    )
    # Invariant 4: BASE_DELAY > 0 AND RETRY_CAP ≥ BASE_DELAY (Formula 1 preconditions)
    assert(BASE_DELAY > 0.0, "Invariant 4a: BASE_DELAY must be > 0")
    assert(RETRY_CAP >= BASE_DELAY, "Invariant 4b: RETRY_CAP must be ≥ BASE_DELAY")
    # Invariant 5: ATTEMPT_CAP fixed at 30 (IEEE 754 overflow guard)
    assert(ATTEMPT_CAP == 30, "Invariant 5: ATTEMPT_CAP must remain 30 (overflow guard)")
    # Invariant 6: MAX_WEEKLY_TICK_CATCHUP ≤ 52 (sanity cap, prevents 1-year lapse stalling boot)
    assert(MAX_WEEKLY_TICK_CATCHUP <= 52, "Invariant 6: MAX_WEEKLY_TICK_CATCHUP must be ≤ 52")
    # Invariant 7: WALL_CLOCK_DRIFT_TOLERANCE_SECONDS > 0 (see Contract 9)
    assert(WALL_CLOCK_DRIFT_TOLERANCE_SECONDS > 0, "Invariant 7: DRIFT_TOLERANCE must be > 0")
    # Invariant 8: MAX_MIGRATION_CHAIN_LENGTH > 0 (see Contract 10)
    assert(MAX_MIGRATION_CHAIN_LENGTH > 0, "Invariant 8: MAX_MIGRATION_CHAIN_LENGTH must be > 0")
```

**Fail-fast on `assert()` violation**: GDScript `assert()` triggers crash in debug builds, silently no-op in release. Project policy: VS + Pre-MVP + MVP builds run as debug (asserts active) UNTIL Production stage — invariants caught in CI smoke test.

**Safe range corrections** (apply to GDD Tuning Knobs section in same write pass as ADR ratification — see GDD Sync block):

| Knob | Current safe range (GDD) | Corrected safe range (this ADR) | Reason |
|------|--------------------------|----------------------------------|--------|
| `STATE_TRANSITION_FALLBACK_MS` | 100..5000 (default 1000) | 100..1499 (default 1000) | Invariant 1 hard upper bound = MIN_REVEAL_WINDOW_SECONDS × 100 = 1500ms (at `MIN_REVEAL_WINDOW_SECONDS = 15`). Tightened. |
| `TOMBSTONE_TTL_SECONDS` | 3600..86400 (default 7200) | 3600..(SUSPENSION_TTL_SECONDS - 1) | Strict-less constraint |
| `MIN_REVEAL_WINDOW_SECONDS` | 5..30 (default 15) | 11..30 (default 15) | Lower bound raised: 5×100 = 500ms < typical `STATE_TRANSITION_FALLBACK_MS = 1000ms` violates Invariant 1. Floor at 11 (1100ms ≥ 1000ms default). |
| `BASE_DELAY` | 0.5..2.0 (default 1.0) | unchanged | Already correct |
| `RETRY_CAP` | 16..60 (default 16) | unchanged | Already correct (Invariant 4b auto-satisfied) |

### Contract 9 — Wall-Clock TTL with Clock-Drift Tolerance

**Problem** (Pass 3 systems-designer R2): NTP drift > 5s can silently nuke valid tombstones if tombstone TTL check uses naive `now - wall_clock_anchor > TOMBSTONE_TTL_SECONDS`.

**Solution — drift-tolerant TTL check + monotonic fallback**:

```gdscript
const WALL_CLOCK_DRIFT_TOLERANCE_SECONDS: int = 300   # 5 min; safe 60..3600

func _is_tombstone_expired(tombstone: Dictionary) -> bool:
    var now_wall: int = int(Time.get_unix_time_from_system())
    var anchor_wall: int = tombstone.get("wall_clock_anchor", 0)
    var now_mono: int = Time.get_ticks_msec()
    var anchor_mono: int = tombstone.get("monotonic_anchor_ms", 0)
    
    var wall_diff: int = now_wall - anchor_wall
    var mono_diff_sec: int = (now_mono - anchor_mono) / 1000
    
    # Detect clock drift: if wall_diff differs from mono_diff by more than tolerance,
    # wall clock has drifted (NTP correction, manual time change, DST jump).
    # Trust monotonic in that case — but monotonic resets across WASM reload.
    if anchor_mono > 0 and now_mono > 0 and abs(wall_diff - mono_diff_sec) > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS:
        push_warning("Wall-clock drift detected: wall=%ds mono=%ds — using monotonic" % [wall_diff, mono_diff_sec])
        return mono_diff_sec > TOMBSTONE_TTL_SECONDS
    
    # Default path: trust wall-clock (monotonic resets across WASM reload, so wall is
    # the only reliable cross-reload clock).
    return wall_diff > TOMBSTONE_TTL_SECONDS
```

**`LootDrop pending_since` authoritative clock** (Contract 15 cross-ref): server-side timestamp at `POST /lootdrop/{transition_id}/cache` write time — client-side `pending_since` is mirror only, NOT authoritative for hard-cap eviction.

### Contract 10 — Schema Migration Chain Bounded Cost

**Problem** (Pass 3 systems-designer R4): `PersistenceLayer.migrate(from, to)` chain has no length or time bound — old client opening newer schema can stall boot indefinitely.

**Solution — bounded migration chain + per-step budget**:

```gdscript
const MAX_MIGRATION_CHAIN_LENGTH: int = 6     # Revised 2026-05-27 per ADR-003 ratification (was 10)
const MIGRATION_BUDGET_MS: int = 150          # per-step max time; total boot budget = 900ms (Revised 2026-05-27 per ADR-003 ratification; was 500ms/step = 5000ms total)

func migrate(from_version: int, to_version: int) -> bool:
    var chain_length: int = to_version - from_version
    if chain_length > MAX_MIGRATION_CHAIN_LENGTH:
        push_error("Migration chain too long: %d -> %d (max %d)" %
            [from_version, to_version, MAX_MIGRATION_CHAIN_LENGTH])
        return false   # → corrupt save path per Rule 5 priority 5

    var current_version: int = from_version
    while current_version < to_version:
        var step_start: int = Time.get_ticks_msec()
        var ok: bool = _migrate_one_step(current_version, current_version + 1)
        var step_elapsed: int = Time.get_ticks_msec() - step_start
        if not ok or step_elapsed > MIGRATION_BUDGET_MS:
            push_error("Migration step %d->%d failed or exceeded budget (%dms / %dms)" %
                [current_version, current_version + 1, step_elapsed, MIGRATION_BUDGET_MS])
            return false
        current_version += 1
    return true
```

**Cross-ref**: ADR-003 (PersistenceLayer save state strategy) inherits this contract and specifies `_migrate_one_step` implementations.

### Contract 11 — IndexedDB Async-Commit Fence: Best-Effort (VS Tier)

**Chosen approach (VS tier)**: NO fence. `FileAccess.store_*` returns `bool` (4.4+) indicating **WASM-side serialization success**, NOT IndexedDB transaction commit. Working assumption: IDB commit lags ~1 frame behind WASM accept. **This assumption is unverified on Godot 4.6 Web Export — VS spike Q-A4 task list adds explicit IDB-commit-vs-WASM-accept timing measurement before VS implementation begins.**

**Rationale (conditional on assumption holding)**: `STATE_TRANSITION_FALLBACK_MS = 1000ms` budget is 60× larger than typical 16ms IDB commit window. Risk window (tab killed in 1-frame gap between WASM accept + IDB commit) is < 0.05% per transition. Boss-defeat critical-path frame penalty unacceptable.

**If VS spike measures > 5-frame lag or non-deterministic commit timing**: this contract upgrades to Option B (FileAccess.flush + 1-frame await on critical writes). Decision deferred to spike outcome.

**Implementation rule**: Rule 2 step 4 (PersistenceLayer write) does NOT `await` IDB ack. State machine progresses immediately to step 5/6/7.

**Risk acceptance** (logged in this ADR):

- VS tier: accept ~0.05% per-transition tombstone-loss risk window.
- MVP reassessment: if VS telemetry shows ≥ 1 in 10,000 transitions exhibits "tombstone in IDB after WASM accept but tab killed before commit" → upgrade to `FileAccess.flush() + 1-frame await` (Option B from initial design choice; cost: 16-32ms per critical write).

**Telemetry hook** (NEW): GameStateMachine emits `tombstone_write_completed(transition_id, latency_ms)` for downstream telemetry. Latency measured WASM-side only; MVP reassessment uses this signal.

### Contract 12 — `@no-await` Static Analysis: Scan-Entire-File Rule

**Problem** (Pass 3 gameplay-programmer R3 + qa-lead B3): AC-18 regex only scans `_transition_*` functions for `await` — helper-via-await escape (e.g., `_transition_to_idle` calls `_helper_foo` which contains `await`) escapes detection.

**Solution — scan-entire-file no-await rule** (simpler than call-graph walker, sufficient):

**CI rule**: any file matching `src/core/state_machine/**.gd` MUST contain ZERO `await` statements anywhere in the file. Helper functions in those files are implicitly part of the transition execution graph.

**Implementation** (`tools/ci/check_no_await.gd` or shell script):

```bash
# CI step (POSIX shell)
if rg --glob "src/core/state_machine/**/*.gd" "\\bawait\\b" --files-with-matches; then
    echo "FAIL: 'await' found in state machine files — see ADR-0006 Contract 12"
    exit 1
fi
```

**Forbidden file paths** (binding): `src/core/state_machine/*.gd` — no `await` permitted anywhere.

**Allowed escape**: HTTPRequest callbacks. `_on_http_request_completed` handler MUST NOT `await`; if HTTP follow-up logic needs to defer, use `call_deferred` or `process_frame.connect(... CONNECT_ONE_SHOT)`.

**AC-18 rewrite**: from "regex scan `_transition_*` for `await`" to "CI grep `src/core/state_machine/**/*.gd` for `\\bawait\\b` returns empty".

### Contract 13 — AC-15b Pillar 2 Derivation Enforcement: `IInputPolicy` Interface

**Problem** (Pass 3 qa-lead B4): AC-15b currently does literal-name regex match on `is_input_permitted()` — refactor to `IInputPolicy` interface param breaks test silently.

**Solution — formal `IInputPolicy` interface contract**:

```gdscript
class_name IInputPolicy extends RefCounted

# Returns true if input events should be processed in the current state.
# Implementations: AttentionBudgetPolicy (real), MockInputPolicy (test).
func is_input_permitted() -> bool:
    push_error("IInputPolicy.is_input_permitted() must be overridden")
    return false
```

**Architectural placement**:

- `AttentionBudgetPolicy` (#33) `extends IInputPolicy` and implements actual derivation from `GameStateMachine.current_state`.
- Input handlers (HUD, modals) accept `IInputPolicy` via constructor injection — NOT direct reference to `AttentionBudgetPolicy`.
- `MockInputPolicy` for tests: `func is_input_permitted() -> bool: return _permitted`.

**AC-15b rewrite** (from literal-name regex to interface contract test):

- Test injects `MockInputPolicy` with `_permitted = false`.
- Trigger input event during `WorkoutActive`.
- Assert: `MockInputPolicy.is_input_permitted` was called exactly once AND input event was dropped.

**Pillar 2 architectural enforcement layer**: this interface places Pillar 2 enforcement at the input-handler boundary, not at the state-machine boundary. State machine remains source of truth (read-only `current_state`); `IInputPolicy` is the gate that input handlers respect.

### Contract 14 — Test Spy Contract: Formal Interface Set

**Problem** (Pass 3 qa-lead B2): `_set_in_memory` referenced in AC-04a/16/21 but not in `IPersistence` interface (only `read/write/delete/migrate`). Spy attachment not portable across test authors.

**Solution — formal Test Spy Contract** (binding interface set):

```gdscript
class_name IPersistence extends RefCounted

# Production interface
func read() -> Dictionary: push_error("override"); return {}
func write(key: String, value: Variant) -> bool: push_error("override"); return false
func delete(key: String) -> bool: push_error("override"); return false
func migrate(from_version: int, to_version: int) -> bool: push_error("override"); return false

# Test spy interface — implemented ONLY by MockPersistenceLayer; production
# implementation returns null / no-op.
func attach_write_spy(spy: Callable) -> void: pass
func attach_delete_spy(spy: Callable) -> void: pass
func clear_spies() -> void: pass
```

**Full spy set** (binding for all test authors):

| Spy interface | Method | Purpose | Used in ACs |
|---|---|---|---|
| `IPersistence.attach_write_spy(Callable)` | call(key, value) → void | Record every write | AC-04a, AC-16, AC-21, AC-31a |
| `IPersistence.attach_delete_spy(Callable)` | call(key) → void | Record every delete | AC-16, AC-21 |
| `GameStateMachine.attach_in_memory_spy(Callable)` | call(old_state, new_state) → void | Record in-memory `_current_state` mutations | AC-04a, AC-16, AC-21 |
| `Input.parse_input_event_spy` | spy registered via `Input.set_test_spy()` (NEW API mock) | Record input events | AC-15a, AC-15b |
| `MockToastQueue.attach_enqueue_spy(Callable)` | call(toast_msg, priority) → void | Record toast enqueues | AC-31a/b/c, AC-32a/b, AC-34a/b |
| `MockInventory.attach_grant_spy(Callable)` | call(item_id, qty) → void | Record inventory grants | AC-19, AC-31a |
| `MockEnemyDirector.attach_spawn_spy(Callable)` | call(enemy_id) → void | Record enemy spawns | AC-13 |
| `MockEnemyDirector.attach_boss_defeated_spy(Callable)` | call(BossPayload) → void | Record boss defeat with full payload | AC-14 |

**Test helper generation**: `/test-helpers` skill (existing in project) MUST generate this spy set when invoked for state machine system. Add to `tests/helpers/state_machine_spies.gd`.

**Discoverability rule**: any AC text referencing a spy MUST use the exact spy interface name from the table above. Test author can grep the spy name to find correct attachment pattern.

### Contract 15 — Cross-Device `loot_reveal_pending` + `pending_since` Authoritative Clock

**Problem** (Pass 3 game-designer B5): which device's wall-clock wins for `pending_since` hard-cap eviction (30-day backstop)?

**Solution — backend mirror + server-side timestamp at cache write**:

- `POST /lootdrop/{transition_id}/cache` (ADR-002 endpoint) writes server-side timestamp `pending_since_server: int (unix)` at row insertion.
- Client `pending_since` is mirror only — used for offline-mode UX; NOT authoritative for hard-cap eviction.
- Hard-cap eviction check (Rule 5 priority 0.5) uses `pending_since_server` from `GET /lootdrop/{transition_id}/cache` response.
- Offline mode (backend unreachable): client uses local `pending_since` for soft TTL; defers hard-cap eviction until backend reachable.
- Backend retention: `lootdrop_cache` rows persist for `LOOTDROP_PENDING_HARD_CAP_DAYS + 7` (37 days) before auto-prune — gives 7-day window for offline player to come online.

**ADR-002 binding (inherited)**:

- `lootdrop_cache` schema: `transition_id PK, account_id, payload JSON, pending_since_server INT, committed_at INT NULL`
- `GET /lootdrop/{transition_id}/cache` response includes `pending_since_server`
- Auto-prune cron: `DELETE FROM lootdrop_cache WHERE committed_at IS NULL AND pending_since_server < now - (37 * 86400)`

### Architecture

```
                  ┌─────────────────────────────────────┐
                  │     GameStateMachine (autoload #2)  │
                  │  ┌───────────────────────────────┐  │
                  │  │ _current_state: String        │  │
                  │  │ _transitioning: bool          │  │
                  │  │ _lock_gen: int                │  │
                  │  │ _last_emit_tick: int          │  │
                  │  │ _initial_state_payload (sentinel) │
                  │  └───────────────────────────────┘  │
                  │  ┌─────────────────────────────┐    │
                  │  │ Event Intake Queue          │    │
                  │  │ (priority FIFO, 1/frame)    │    │
                  │  └─────────────────────────────┘    │
                  └────┬──────────────┬─────────────────┘
                       │              │
            connect_for_initial_   state_changed
            state(callable)       (from, to, payload)
                       │              │
                       ▼              ▼
              ┌────────────────────────────┐
              │   Subscribers (autoloads   │
              │   3+: EnemyDirector,       │
              │   LootDropSystem, etc.)    │
              └────────────────────────────┘
                       │
                       │ follow-up transitions via
                       │ get_tree().process_frame.connect(
                       │   func(): GSM._request_transition(event),
                       │   CONNECT_ONE_SHOT
                       │ )
                       ▼
              ┌────────────────────────────┐
              │   GameStateMachine event   │
              │   queue (priority 2)       │
              └────────────────────────────┘

       ┌─────────────────────────┐         ┌────────────────────────┐
       │ PersistenceLayer (#1)   │◄────────┤ GameStateMachine       │
       │ - read() sync           │  Rule 2 │   write tombstone +    │
       │ - write() sync          │  step   │   write final state +  │
       │ - migrate(from, to)     │  2,3,5  │   remove tombstone     │
       │   bounded chain         │         │                        │
       │ - to_dict/from_dict     │         └────────────────────────┘
       │   envelope for Resource │
       │   payloads              │                  │
       └─────────────────────────┘                  │ step 6:
                  ▲                                  │ dual-target backend write
                  │                                  │ (fire-and-forget, idempotent
                  │                                  │  via transition_id UNIQUE)
              user://state.json                      ▼
              (IndexedDB on Web)              ┌──────────────────────┐
                                               │ GymSysClient (#2)    │
                                               │  - X-Session-Token   │
                                               │  - 401 → priority 0  │
                                               │  - POST /lootdrop/   │
                                               │    {tid}/cache+commit│
                                               └──────────────────────┘
```

### Key Interfaces

```gdscript
# ────────────────────────────────────────────────────────────────────────
# GameStateMachine (autoload position 2)
# ────────────────────────────────────────────────────────────────────────
signal state_changed(from_state: String, to_state: String, payload: StateTransitionPayload)
signal dropped_event(event: TransitionEvent, reason: String)
signal critical_save_failed(error_code: int, key: String)
signal session_invalidated()
signal auth_required()
signal tombstone_write_completed(transition_id: String, latency_ms: int)
signal weekly_tick_catchup_capped(missed_count: int, capped_at: int)

# Per Contract 6 + 7: subscribers obtain initial state via this helper.
func connect_for_initial_state(callable: Callable) -> void

# Per Contract 1: external code triggers transitions via this entry point.
func _request_transition(event: TransitionEvent) -> void

# Read-only current state (e.g., for HUD layout selection).
var current_state: String  # @export read-only

# Test spy interface (Contract 14)
func attach_in_memory_spy(spy: Callable) -> void
func clear_spies() -> void

# ────────────────────────────────────────────────────────────────────────
# IPersistence (autoload #1; Contract 14)
# ────────────────────────────────────────────────────────────────────────
class_name IPersistence extends RefCounted
func read() -> Dictionary
func write(key: String, value: Variant) -> bool
func delete(key: String) -> bool
func migrate(from_version: int, to_version: int) -> bool
# Test spy interface
func attach_write_spy(spy: Callable) -> void
func attach_delete_spy(spy: Callable) -> void
func clear_spies() -> void

# ────────────────────────────────────────────────────────────────────────
# IInputPolicy (Contract 13)
# ────────────────────────────────────────────────────────────────────────
class_name IInputPolicy extends RefCounted
func is_input_permitted() -> bool

# ────────────────────────────────────────────────────────────────────────
# SerializableResource (Contract 3)
# ────────────────────────────────────────────────────────────────────────
class_name SerializableResource extends Resource
func to_dict() -> Dictionary
static func from_dict(data: Dictionary) -> SerializableResource

# ────────────────────────────────────────────────────────────────────────
# StateTransitionPayload + sentinel (Contract 6)
# ────────────────────────────────────────────────────────────────────────
class_name StateTransitionPayload extends SerializableResource
@export var source_event: String   # "boss_defeated" | "workout_completed" | "initial_state" | "deferred_reveal" | "deferred_reveal_hard_cap" | ...
@export var data: Dictionary       # opaque per-transition payload — e.g., {"boss": BossPayload}
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> StateTransitionPayload

# ────────────────────────────────────────────────────────────────────────
# BossPayload (Contract 3 example; binding for #14 EnemyDirector)
# ────────────────────────────────────────────────────────────────────────
class_name BossPayload extends SerializableResource
enum BossOutcome { DEFEATED, INTERRUPTED_WITH_CREDIT, ABANDONED }
@export var outcome: BossOutcome
@export var boss_id: int
@export var hp_at_interrupt: int
@export var hp_max: int
func to_dict() -> Dictionary    # serializes outcome as STRING name
static func from_dict(d: Dictionary) -> BossPayload
```

### Implementation Guidelines

1. **Single autoload position locked**: PersistenceLayer = 1, GameStateMachine = 2. All other autoloads = 3+. Verified in `project.godot` AND in CI (test that fails if order changes).
2. **No `await` in `src/core/state_machine/**.gd`**. CI enforces.
3. **Every `Resource` payload that crosses persistence boundary `extends SerializableResource`**. Static analyzer scans `StateTransitionPayload.data` usage and flags any `Resource`-subclass instance that does NOT extend `SerializableResource`.
4. **Test helpers generation**: run `/test-helpers state_machine` once during VS setup to scaffold `tests/helpers/state_machine_spies.gd` per Contract 14.
5. **Knob invariants run at boot**: `_assert_knob_invariants()` called from `GameStateMachine._ready()` BEFORE Rule 5 reconciliation. Debug builds crash on violation; release builds no-op (acceptable — VS/MVP run debug).
6. **Resource files**: `BossPayload`, `LootPayload`, `StateTransitionPayload` saved as `.tres` Resource scripts only — instances created per-transition, never preloaded singletons (except `INITIAL_STATE_PAYLOAD` sentinel, which is constructed once at boot).

## Alternatives Considered

### Alternative 1: Mutex-based atomic primitive (assumes single-thread WASM)

- **Description**: Use `Mutex.try_lock()` for transition lock; assert COOP/COEP threading is OFF at boot.
- **Pros**: idiomatic Godot threading API; familiar to engineers from non-web Godot work.
- **Cons**: requires Q-A4 spike validation BEFORE implementation; if Godot 4.6 Web Export ever enables threading by default in future patch, all atomicity assumptions break silently; Mutex API friction with no benefit in single-thread mode.
- **Estimated Effort**: similar (slightly less code in single-thread; significantly more if threading future-proofing needed).
- **Rejection Reason**: generational lock works identically in both threading modes — future-proof without immediate cost; avoids Q-A4 as a blocker.

### Alternative 2: Pure `call_deferred` frame-boundary atomicity

- **Description**: All `_request_transition` calls go through `call_deferred`; lock is just `bool _transitioning`. Synchronous re-entrance impossible because everything runs at next-frame boundary.
- **Pros**: simplest model; eliminates entire re-entrance class.
- **Cons**: every transition delayed by 1 frame (16.6ms); boss-defeat → LootDrop ritual transition has perceivable hiccup; Pillar 3 (Drop Euphoria) compromise; `workout_completed` (Rule 7 reality-wins) latency increases.
- **Estimated Effort**: significantly less code; significantly more UX polish work to mask frame delays.
- **Rejection Reason**: Pillar 3 unacceptable compromise. Frame delay measurable in user perception at boss kill moment.

### Alternative 3: Split into 3 ADRs (006/007/008) instead of comprehensive single ADR

- **Description**: ADR-006 = atomicity + transitions; ADR-007 = persistence serialization + IDB fence + clock drift + migration chain; ADR-008 = test spy + static analysis.
- **Pros**: smaller, more focused ADRs; easier to review individually; clearer ADR-level dependencies.
- **Cons**: 3× ratification overhead; ADR-007 and ADR-008 would depend on ADR-006 contracts (atomicity affects serialization timing; static analysis enforces atomicity rules) — circular-ish; Pass 4 verification has to wait for all 3.
- **Estimated Effort**: 3× authoring + 3× review cycles ≈ 2-3× total time vs single ADR.
- **Rejection Reason**: 15 items are tightly coupled (atomicity ↔ transition_id ↔ serialization ↔ autoload ordering ↔ test spy all reference each other). Splitting creates depends-on chains that delay Pass 4. User selected comprehensive single ADR per session-start AskUserQuestion.

### Alternative 4: `var_to_bytes` + base64 serialization envelope

- **Description**: Tombstone payload serialized via `var_to_bytes(payload)` → base64-encoded into JSON. Resource type preserved automatically by Godot.
- **Pros**: zero per-class boilerplate; Resource type round-trip handled by engine.
- **Cons**: tombstone becomes opaque base64 blob in IndexedDB devtools — debugging requires manual decode; schema migration requires manual byte-level rewrite; community tooling cannot inspect; future-developer hostile.
- **Rejection Reason**: VS-tier debugging speed matters. `to_dict()` boilerplate is one-time cost per Resource class (5-10 lines); debug-readability benefit is permanent.

### Alternative 5: Backend-allocated `transition_id`

- **Description**: Every transition pre-requests `transition_id` from backend; backend allocates serial id.
- **Pros**: zero collision risk; backend has full audit trail.
- **Cons**: offline mode fails closed — Pillar 2 (Frictionless Companion) violation; every transition gains backend round-trip latency.
- **Rejection Reason**: offline mode is mandatory (Pillar 2). Cannot ship.

## Consequences

### Positive

- 15 architectural-level contracts locked → no further "atomicity bugs diverging not converging across passes" (Pass 3 verdict resolved)
- Pillar 3 (Drop Euphoria) hard guarantee mechanically enforced **for committed tombstones** — forward-recovery `transition_id` reuse rule (Contract 2) + serialization envelope (Contract 3) preserve LootDrop across WASM reload. **Pre-commit window risk (Contract 11) is VS-tier accepted with telemetry-gated MVP upgrade path** — not zero, but bounded < 0.05% per transition with explicit revisit threshold.
- Pillar 2 (Frictionless) architecturally enforced via `IInputPolicy` interface — refactor-safe
- 38 ACs become mechanically testable via formal Test Spy Contract
- Future engine upgrade (Godot 4.6 → 4.7) requires ADR re-validation — explicit gate
- ADR-002, ADR-003, GDD #2, GDD #3 authoring unblocked

### Negative

- ~0.05% per-transition pre-commit tombstone-loss risk window accepted at VS tier (Contract 11) — **Pillar 3 "hard guarantee" knowingly leaves a sub-1-frame crack between WASM accept and IDB commit**. Requires creative-director / game-designer explicit ratification that this falls within Pillar 3 tolerance for VS. If pillar owners reject the 0.05% window during Pass 4, this ADR upgrades Contract 11 to Option B (flush + 1-frame await) pre-VS implementation. → **RESOLVED 2026-05-28 via Gate B APPROVE WITH CONCERN** — 5 MVP escalation triggers binding (see footnote below).

  **MVP Escalation Triggers (Gate B 2026-05-28 binding — 5 conditions)**:

  | # | Trigger | Owner | Due Date | Action on Trigger |
  |---|---------|-------|----------|-------------------|
  | 1 | `tombstone_write_completed` telemetry shows ≥ 1 / 10,000 transitions exhibit "WASM accept → tab killed before IDB commit" | Producer (VS playtest end review) | End of VS playtest milestone | **Force upgrade** Contract 11 to Option B (flush + 1-frame await) pre-MVP implementation |
  | 2 | Q-A4 spike measures IDB-commit vs WASM-accept timing > 5-frame lag OR non-deterministic | Engine-programmer + godot-specialist | Before any state machine story enters sprint | **Auto-upgrade** ADR to Contract 11 Option B per Contract 11 §"If VS spike measures..." clause |
  | 3 | VS playtest player reports "ceremony emitted but loot disappeared, next session also missing" | qa-lead + Producer | Continuous during VS playtest | **Immediate escalation** — indicates reconciliation path itself broken (NOT the 0.05% window's intent) |
  | 4 | FT-2 falsification test inverse: player attribution interview frequency of "件 loot 唔見咗" > "件 loot 好彩" | qa-lead + creative-director | VS playtest end synthesis | **Pillar 3 ritual contract breached at perception layer** — escalate to Option B + UX intervention |
  | 5 | Producer-tracked MVP gate review skipped or delayed past VS playtest end date | Producer (accountability gate) | End of VS playtest milestone (calendared) | **Forbidden** — silently missing this gate converts 0.05% accepted risk into permanent silent floor; Producer must enforce calendar |

  **Note on enforcement scope**: All 5 triggers apply to VS → MVP transition gate. Post-MVP launch ratification of any residual risk window requires a NEW ADR (this ADR explicitly does NOT cover launch tolerance — only VS tier).
- Single autoload load order locked → future autoload additions must respect `PersistenceLayer = 1, GameStateMachine = 2` constraint (minor cost)
- Every `Resource` payload extends `SerializableResource` boilerplate (~5-10 lines per class)
- Knob safe range tightening (Contract 8) reduces designer freedom — `STATE_TRANSITION_FALLBACK_MS` upper bound dropped from 5000ms to 1499ms; `MIN_REVEAL_WINDOW_SECONDS` lower bound raised from 5s to 11s. Designer flexibility traded for invariant safety.

### Neutral

- 9-state enum + Rule 1-7 unchanged (this ADR does not touch FSM topology, only contracts beneath it)
- 5 locked decisions (Natural-Pause Reveal, BossOutcome enum, RestPeriod rename, Single-Device Session Lock, Weekly Tick Replay) unchanged
- Event Intake Queue priority taxonomy unchanged

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| COOP/COEP threading enabled by default in future Godot 4.6.x patch | Low | High (atomicity assumptions break) | Generational lock works in both modes; Q-A4 spike validates current state; CI test detects threading mode at boot |
| `FileAccess.flush()` semantics differ on Web Export vs documentation | Medium | Medium (IDB fence assumption wrong) | VS spike verification; telemetry hook (Contract 11) records latency; MVP reassessment gate |
| `Resource.duplicate_deep()` (4.5+) edge case in nested SerializableResource | Low | Medium (forward-recovery payload corrupt) | `to_dict()/from_dict()` round-trip test in unit test suite; doesn't depend on `duplicate_deep` |
| `JavaScriptBridge.create_callback()` GC under bfcache | Medium | High (pageshow listener lost) | `_listeners_bound: bool` guard; idempotent re-registration on `_ready`; explicit reference held in autoload member |
| 0.05% tombstone-loss window manifests at >1/10K rate in VS playtest | Medium | High (Pillar 3 hard test fails) | Telemetry hook; MVP gate to upgrade to flush+await |
| Static analyzer (Contract 12) misses indirect `await` paths | Low | Medium | Scan-entire-file rule catches transitive helpers; complement with code review of any new file in `src/core/state_machine/` |
| Knob invariant `assert()` fires in shipped release build | Low | Low | Asserts are debug-only in GDScript; release no-op; CI smoke catches violation pre-ship |
| Future engineer accidentally uses `Object.get_class()` instead of `get_script().get_global_name()` for payload tagging (Contract 3) | Medium | High (silent forward-recovery break — all payloads round-trip to null) | Code comment in tombstone write path explicitly warns; unit test verifies BossPayload + LootPayload round-trip preserves `payload_type` field as class_name (not "Resource") |
| Subscriber connects via `connect_for_initial_state(callable.bind(extra))` (Contract 6) — `.bind()` shifts arg positions, callv mis-delivers | Medium | Medium (subscriber gets garbage initial state) | Contract 12 CI scan for `connect_for_initial_state(*.bind(*))` literal pattern blocks; documented in initial-state delivery contract section |

## Performance Implications

| Metric | Before (GDD spec) | Expected After (this ADR) | Budget |
|--------|-------------------|---------------------------|--------|
| Transition CPU | Unspecified | < 0.5ms (single-thread WASM, no `await`, no flush) | < 1ms (1/16 frame) |
| Transition memory churn | Unspecified | 1 `StateTransitionPayload` + 1 `Resource` subclass per transition (~200 bytes) — ref-counted, GC'd within frame | < 1KB / transition |
| Boot time (PersistenceLayer + GameStateMachine `_ready`) | Unspecified | < 50ms (sync read + Rule 5 reconciliation + Rule 5.5 weekly tick replay) | < 100ms |
| Migration chain max time | Unbounded | **6 steps × 150ms = 900ms** (Revised 2026-05-27 per ADR-003 ratification) | 900ms (Contract 10) |
| Forward-recovery on cold boot | Unspecified | < 100ms (read tombstone + replay step 3-8) | < 200ms |
| `transition_id` generation cost | Unspecified | 1 `PersistenceLayer.write(int)` per transition (~5ms IDB write) | tolerable; transitions < 10/min in normal play |
| Network (per transition, fire-and-forget) | Unspecified | 1× state POST + (LootDrop only) 1× lootdrop/cache POST | 2-5 KB per LootDrop transition |

## Migration Plan

No existing code — this ADR is foundational and precedes implementation. Migration consists of:

1. Ratify this ADR (move Status: Proposed → Accepted).
2. Update `docs/registry/architecture.yaml` with locked stances (see Closing — registry candidates).
3. Run Pass 4 light verification on `game-state-machine.md` (`/design-review` --depth lean) — verify ACs trace to contracts.
4. Apply GDD §Boot Sequence Phase B/C rewrite per Contract 4 + knob safe range corrections per Contract 8 (same-pass with this ADR's write per GDD sync check below).
5. Author ADR-002 (GymSys integration protocol) inheriting Contract 15 bindings.
6. Author ADR-003 (PersistenceLayer save state strategy) inheriting Contracts 3, 9, 10, 11.
7. Author GDD #2 (GymSys Backend Client) — `state_changed` consumer + endpoint contracts.
8. Author GDD #3 (PersistenceLayer) — `IPersistence` interface implementation per Contract 14.
9. `/test-helpers state_machine` once during first VS sprint to scaffold spy set.
10. Begin VS implementation of state machine (stories from `/create-epics` → `/create-stories`).
11. **MVP gate ownership**: Producer to schedule MVP-tier review of `tombstone_write_completed` telemetry signal against the 1/10K loss-rate threshold at end of VS playtest (Contract 11). If threshold exceeded → Contract 11 upgrades to Option B (flush + 1-frame await) for MVP. If gate is missed, 0.05% accepted risk becomes silent permanent floor — explicit producer accountability required.

**Rollback plan**: If VS playtest reveals any of Contracts 1, 2, 3, 11 is fundamentally wrong, supersede this ADR with new ADR (e.g., ADR-006a). All 15 contracts are interdependent — partial rollback not possible; supersede-entire-ADR is the only rollback model.

**Rollback tripwire**: If Contract 1 / 2 / 3 / 11 changes during VS implementation, **all completed state-machine stories must be re-verified against the new contract version**. Producer tracks this in sprint planning; affected stories regress to Status: Needs Re-Verification, and acceptance criteria are re-evaluated per the superseding ADR.

## Validation Criteria

- [ ] All 38 ACs in `game-state-machine.md` mechanically reference spy interfaces from Contract 14
- [ ] CI passes: `rg --glob "src/core/state_machine/**/*.gd" "\\bawait\\b"` returns empty
- [ ] CI passes: `_assert_knob_invariants()` runs at boot in debug builds without crash
- [ ] Unit test: transition + forward-recovery produces identical `transition_id` (Contract 2)
- [ ] Unit test: `BossPayload.to_dict() → from_dict()` round-trip preserves all fields (Contract 3)
- [ ] Unit test: tombstone write captures `payload_type = "BossPayload"` (NOT `"Resource"`) — verifies `get_script().get_global_name()` path (Contract 3)
- [ ] Unit test: subscriber connected via `connect_for_initial_state` followed by immediate real transition receives ONLY real transition, never stale initial (Contract 6 + 7)
- [ ] Unit test: synchronous re-entry from `state_changed` handler → `dropped_event("lock_held")` fires (Contract 1)
- [ ] Unit test: generational lock invariants hold under simulated 2-thread re-entrance (cheap insurance even if Q-A4 confirms single-thread default — surfaces broken assumptions before threading ever enabled) (Contract 1)
- [ ] VS spike Q-A4: COOP/COEP threading default state in Godot 4.6 Web Export confirmed
- [ ] VS spike: `FileAccess.flush()` IDB ack timing measured; telemetry hook records < 1/10K loss rate
- [ ] Pass 4 light verification of `game-state-machine.md` returns PASS verdict

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/game-state-machine.md` | Game State Machine | Item #1: Atomic transition primitive | Contract 1 — generational lock + call_deferred discipline (AC-04a, AC-32a) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #2: `transition_id` collision-safety across WASM reload | Contract 2 — wall_clock_ms × 1000 + persisted counter; forward-recovery reuse rule (AC-32a) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #3: Tombstone serialization (BossPayload round-trip) | Contract 3 — SerializableResource interface + to_dict/from_dict (AC-11a, AC-14, AC-21) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #4: Autoload `_enter_tree`/`_ready` ordering correction | Contract 4 — per-autoload sequential; GDD Phase B/C rewrite (AC-30) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #5: `Callable.call_deferred` signature under 4.6 variadic | Contract 5 — lambda + process_frame.connect ONE_SHOT (CI scan; AC-04a, AC-32a) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #6: Initial-state typed-signal contract | Contract 6 — INITIAL_STATE sentinel payload + source_event (AC-30) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #7: `connect_for_initial_state` race vs real transition | Contract 7 — `_last_emit_tick` capture + skip-stale guard (AC-30a NEW) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #8: Knob invariant boundary math | Contract 8 — runtime `_assert_knob_invariants()` + safe range corrections (AC-17, AC-20) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #9: Wall-clock TTL clock-drift formula | Contract 9 — DRIFT_TOLERANCE + monotonic fallback (AC-22a NEW) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #10: Schema migration chain bounded cost | Contract 10 — MAX_CHAIN_LENGTH + MIGRATION_BUDGET_MS (AC-26 NEW) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #11: IndexedDB async-commit fence semantics | Contract 11 — best-effort VS, telemetry hook for MVP gate (AC-21, AC-33 NEW) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #12: `@no-await` static analysis transitive | Contract 12 — scan-entire-file CI rule (AC-18 rewrite) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #13: AC-15b Pillar 2 derivation enforcement | Contract 13 — IInputPolicy interface contract (AC-15b rewrite) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #14: Mock spy hook contract canonicalisation | Contract 14 — formal Test Spy Contract interface set (AC-04a, AC-13, AC-14, AC-15a, AC-15b, AC-16, AC-19, AC-21, AC-31a/b/c, AC-32a/b, AC-34a/b) |
| `design/gdd/game-state-machine.md` | Game State Machine | Item #15: Cross-device `pending_since` authoritative clock | Contract 15 — backend server-side timestamp + retention (AC-19, AC-31b — refined) |
| `design/gdd/systems-index.md` | (#3 PersistenceLayer placeholder) | `IPersistence` interface + migrate() contract | Contracts 3, 10, 14 inherited by ADR-003 + GDD #3 |
| `design/gdd/systems-index.md` | (#2 GymSys Backend Client placeholder) | `transition_id` + session API + lootdrop endpoints | Contracts 2, 15 inherited by ADR-002 + GDD #2 |
| `design/gdd/game-state-machine.md` (Decision #4) | Decision #4: Single-device session lock | Contract 15 server-side timestamp + 401 priority-0 | Contract 1 (generational lock survives 401 force-boot) + Contract 15 |

**AC trace summary** (per Pass 4 anticipated verification): all 38 ACs reference at least one Contract; cross-table coverage = 15 / 15 Contracts.

**Trust caveat**: the forward mapping (Contract → ACs) is asserted in this ADR. The reverse mapping (each AC → at least one Contract) is NOT mechanically verified here; Pass 4 light verification (`/design-review --depth lean`) is the hard gate. **This ADR is ratifiable pre-Pass 4; Pass 4 failure auto-supersedes this ADR** — i.e., if Pass 4 finds an AC with no Contract coverage, this ADR moves to Status: Superseded and a replacement is authored covering the gap.

## Related

- `design/gdd/game-state-machine.md` (driving GDD; §ADR-006 Escalation Boundary enumerates 15 items)
- `design/gdd/systems-index.md` (downstream systems blocked: #2, #3)
- `design/gdd/reviews/game-state-machine-review-log.md` (3rd-pass review escalating 15 items)
- ADR-002 (GymSys integration protocol — to be authored, inherits Contracts 2, 15)
- ADR-003 (PersistenceLayer save state strategy — to be authored, inherits Contracts 3, 9, 10, 11)
- Engine reference: `docs/engine-reference/godot/breaking-changes.md`, `current-best-practices.md`, `deprecated-apis.md`
- Q-A2 (closed by this ADR), Q-A4 (open, validates Contract 1 + 11), Q-A5 (closed by this ADR)
