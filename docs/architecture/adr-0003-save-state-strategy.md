# ADR-0003: Save State Strategy

## Status
Proposed

## Date
2026-05-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (FileAccess / IDBFS / WASM persistence) |
| **Knowledge Risk** | HIGH — CRITICAL breaking change in 4.4: `FileAccess.store_*` returns `bool` (was `void` in ≤4.3) |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md` (FileAccess 4.4 change), `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | `FileAccess.store_string()` / `store_var()` returning `bool` (since 4.4); `FileAccess.get_open_error()` for Private Mode detection |
| **Verification Required** | VS-tier: (1) Safari ITP touch-refresh — re-writing user:// resets 7-day timer; verify on Safari 17+; (2) Private Mode detection — `FileAccess.open()` returns null + error code in Safari Private; (3) Schema migration boot time ≤900ms on WASM cold start |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-006 State Machine Contract (Accepted 2026-05-28 — N-002 sync 2026-05-28) — Contract 10 (migration budget), Contract 11 (IDB fence semantics, FileAccess bool), IPersistence interface. ADR-001 (Proposed) — 512MB WASM memory ceiling applies to IndexedDB quota allocation. |
| **Enables** | ADR-004 (CORS/cross-origin auth) — cross-origin state sync depends on persistence strategy. ADR-005 (Loot Rarity Formula) — loot state persistence contract defined here. |
| **Blocks** | VS-tier implementation of #3 PersistenceLayer GDD (all stories); #1 GSM boot-sequence stories referencing save state |
| **Ordering Note** | ADR-003 ratifies decisions implicit in #1 GSM GDD + #3 PersistenceLayer GDD. ADR-003 Accepted gates PersistenceLayer sprint start; stories may use IPersistence interface (ADR-006) before ADR-003 Accepted, but Private Mode detection implementation requires this ADR. |

## Context

### Problem Statement
Mirror Hero needs a durable persistence strategy that survives: browser tab close, iOS Safari app switch, bfcache restore, multi-device handoff, and server restarts. This ADR formally ratifies the hierarchy (backend-primary + IndexedDB local secondary + in-memory fallback), technology choice (IndexedDB over localStorage), conflict resolution rules, Safari ITP mitigation, and the schema migration protocol — integrating decisions spread across game-concept.md, #1 GSM GDD, #3 PersistenceLayer GDD, and ADR-006.

### Constraints
- Primary platform: iOS Safari Web Export (WASM, single-thread)
- IndexedDB is the only Godot `user://` backing on Web Export (Emscripten IDBFS — NOT localStorage)
- `FileAccess.store_*` bool = in-memory MEMFS write OK (IDB flush via `IDBFS.syncfs()` is asynchronous — no GDScript-visible fence, per 4.4 breaking change + ADR-006 Contract 11)
- Safari ITP: IndexedDB evicted after 7 days of origin inactivity
- Safari Private Mode: IndexedDB disabled entirely (`FileAccess.open()` returns null)
- GymSys backend is the source of truth for workout state and session token (per game-concept.md)

### Requirements
- Must persist across browser tab close + iOS Safari app switch
- Must support offline boot from local cache when GymSys unreachable
- Must protect LootDrop against data loss (Pillar 3 hard guarantee)
- Must handle Safari Private Mode without silent data loss (Pillar 3)
- Must migrate schema across versions without data loss (bounded budget)
- Must stay within 512MB WASM memory ceiling (ADR-001)

## Decision

### Persistence Hierarchy

Three-tier persistence, checked in priority order:

```
Tier 1: GymSys Backend (primary, authoritative)
  └─ Workout state, session token, loot cache+commit (via ADR-002 endpoints)
  └─ Source of truth for non-LootDrop reconciliation

Tier 2: IndexedDB (user://state.json via Godot user://)
  └─ Local cache for offline boot
  └─ Tombstone pending_transition (forward-recovery)
  └─ loot_pending, loot_reveal_pending (Pillar 3 second line of defence)
  └─ session_token, _transition_id_counter, _last_weekly_tick_unix

Tier 3: In-memory (session scope, tab-close lost)
  └─ Activated when user:// unavailable (Safari Private Mode)
  └─ LootDrop grants disabled in Private Mode (Pillar 3 detect-and-gate)
```

### Technology Choice: IndexedDB (user://) over localStorage

| Criterion | IndexedDB via `user://` | localStorage |
|-----------|------------------------|--------------|
| **Quota** | ~50MB–1GB (origin-specific) | ~5MB |
| **Safari ITP** | 7-day inactivity eviction | 7-day inactivity eviction |
| **Structured data** | Native JSONB-style | String-only (manual JSON.stringify) |
| **Godot API** | `FileAccess` (idiomatic) | Requires JavaScriptBridge.eval (non-idiomatic) |
| **Private Mode** | Disabled → null FileAccess | Disabled → exception |
| **Verdict** | ✅ **Chosen** | ❌ **Forbidden** |

**localStorage is explicitly FORBIDDEN** — see Forbidden Patterns section and `technical-preferences.md` update below.

### Conflict Resolution Rules (ratifying #1 GSM Rule 5)

| Priority | Condition | Winner | Rationale |
|----------|-----------|--------|-----------|
| 0 (highest) | HTTP 401 received (session invalidated) | Backend force-boot | Device handoff |
| 0.5 | loot_pending > 30 days hard cap | Force LootDrop reveal on boot | Pillar 3 ritual preservation |
| **1** | **Local has unsynced LootDrop (loot_reveal_pending=true AND backend GET /lootdrop/:cache returns 404)** | **Client wins (unsynced only)** | Pillar 3 guarantee |
| **1.5** | **Local has LootDrop AND backend also has synced record (GET returns 200)** | **Backend canonical payload wins** | Pillar 3 dedup — backend is single source of truth for synced loot |
| 2 | Valid tombstone within TTL | Client forward-recovery | Atomicity |
| 3 | Backend reachable + local/backend non-LootDrop disagree | Backend wins | Source of truth |
| 4 | Backend unreachable + valid local | Client wins (offline mode) | Frictionless |
| 5 | Local corrupt + backend unreachable | Boot to Idle | Recovery |

**Critical clarification** (TD CONCERNS fix — priority 1 vs 1.5): "Client wins" for LootDrop applies ONLY to *unsynced* local entries (backend has no record). If backend already has a cached/committed entry, backend canonical payload takes precedence to prevent race-induced deduplication failure. This is an extension of ADR-006 Contract 15 (server-authoritative pending_since).

### Safari ITP Mitigation

Safari ITP evicts IndexedDB after 7 days of origin inactivity. Mitigation:

```gdscript
# In PersistenceLayer._ready() + on NOTIFICATION_APPLICATION_RESUMED
func _touch_idb() -> void:
    if not _has_any_data(): return  # skip on fresh install
    var f := FileAccess.open("user://state.json", FileAccess.READ_WRITE)
    if f:
        # Rewrite current content to trigger IDBFS.syncfs()
        f.seek(0)
        f.store_var(_cached_state_dict)  # bool return checked
        f.close()
```

Also triggered on `pageshow` event (via JSBridge) for bfcache resume path.

**Why rewrite triggers ITP reset**: `FileAccess.store_*` triggers Emscripten's `IDBFS.syncfs()` flush, which constitutes an IDB "write" — Safari ITP resets the inactivity timer on any IDB write within the origin.

### Safari Private Mode: Detect & Gate

```gdscript
# PersistenceLayer._ready() — at earliest possible moment
func _detect_storage_mode() -> void:
    var test_file := FileAccess.open("user://idb_probe", FileAccess.WRITE)
    if test_file == null:
        _storage_mode = StorageMode.PRIVATE
        push_warning("PersistenceLayer: IndexedDB unavailable (Private Mode) — in-memory fallback")
        _emit_private_mode_detected()  # #1 GSM + UI subscribe for banner
    else:
        test_file.close()
        DirAccess.remove_absolute("user://idb_probe")
        _storage_mode = StorageMode.NORMAL
```

**Private Mode consequences**:
1. All `write()` calls operate on in-memory Dictionary only (no persistence)
2. **LootDrop grants DISABLED** — `loot_reveal_pending` cannot be reliably persisted; Loot Drop System must check `PersistenceLayer.is_private_mode() → bool` before granting any loot
3. Non-dismissable banner: "Opening in Private Mode — workout loot won't be saved. Open in normal browser tab to earn loot."
4. Session token still requested from backend (session works, only local persistence is impaired)

This is the mandatory Pillar 3 mitigation replacing silent loss.

### FileAccess bool Return Semantics (4.4 breaking change)

```gdscript
var success: bool = f.store_var(data)
# success = true  → in-memory MEMFS write succeeded
# success = false → MEMFS write failed (disk error, quota)
# IDB commit status is UNKNOWN — Emscripten IDBFS.syncfs() runs async
```

**This does NOT mean data is durably committed.** ~0.05% per-write loss window exists between MEMFS write and IDB flush (per ADR-006 Contract 11 VS-tier acceptance). Mitigation: tombstone forward-recovery (Rule 2 #1 GSM) catches any missed writes on next boot.

### Schema Migration Protocol

Ratifying #3 PersistenceLayer GDD + ADR-006 Contract 10:

- **Schema version key**: `user://state.json['schema_version']` (int, compared against `const SCHEMA_VERSION = 1`)
- **Chain length limit**: `MAX_MIGRATION_CHAIN_LENGTH = 6` steps per boot
- **Per-step budget**: `MIGRATION_BUDGET_MS = 150ms` (measured via `Time.get_ticks_msec()`)
- **Total ceiling**: 6 × 150ms = **900ms** — this is the project-standard boot migration ceiling (per ADR-006 Contract 10 ratified ceiling — both ADRs consistent post-ADR-006 Accepted 2026-05-28; N-004 sync 2026-05-28 replaces prior "corrects stale 5000ms" prose)
- **Splash threshold**: If migration takes > 300ms, show "Updating save…" progress indicator (per TD recommendation — sets user expectation, prevents perceived hang)
- **Hard abort**: If migration step exceeds `MIGRATION_BUDGET_MS` → abort chain → corrupt-save path → boot to Idle + `critical_save_failed` emit

### Architecture Diagram

```
Boot sequence (Godot WASM)
├─ PersistenceLayer._ready() (position 1, first autoload)
│  ├─ _detect_storage_mode() → StorageMode.NORMAL | PRIVATE
│  ├─ If PRIVATE: in-memory fallback + emit signal (banner + loot disable)
│  └─ If NORMAL: FileAccess.open("user://state.json") → read
│
├─ GameStateMachine._ready() (position 2)
│  ├─ Read schema_version; if mismatch → PersistenceLayer.migrate()
│  │  └─ show "Updating save…" if > 300ms
│  └─ Rule 5 reconciliation (priority 0→5 table above)
│
├─ All other autoloads (position 3+)
│  └─ Observe _current_state via connect_for_initial_state
│
└─ Scene loads → gameplay begins
```

### Key Interfaces

```gdscript
# PersistenceLayer (extends IPersistence — ADR-006)
func read() -> Dictionary                           # sync, from MEMFS
func write(key: String, value: Variant) -> bool    # bool = MEMFS success (not IDB)
func delete(key: String) -> bool
func migrate(from_version: int, to_version: int) -> bool  # bounded: 6×150ms
func is_private_mode() -> bool                     # true if IndexedDB unavailable
func touch() -> void                               # ITP refresh (rewrite state.json)

# Signals (from PersistenceLayer)
signal private_mode_detected()   # → UI: show banner; LootDropSystem: disable grants
signal write_completed(latency_ms: int)  # ADR-006 Contract 11 telemetry
signal critical_save_failed(reason: String, context: String)
```

## Alternatives Considered

### Alternative 1: localStorage primary, IndexedDB secondary
- **Description**: Use localStorage for game state (simpler JS interop); IndexedDB only for large assets
- **Pros**: Universal support; `window.localStorage` is well-known API
- **Cons**: 5MB quota severely limits state size; requires JavaScriptBridge (non-idiomatic Godot); same 7-day Safari ITP; Godot user:// is idiomatic — no reason to bypass it
- **Rejection Reason**: IndexedDB via `user://` covers all requirements with Godot's native API. localStorage is FORBIDDEN by this ADR.

### Alternative 2: Client-primary (offline-first)
- **Description**: Local state is authoritative; backend syncs asynchronously
- **Pros**: Faster perceived writes; works fully offline
- **Cons**: Multi-device handoff (Decision #4 in #1 GSM) requires single source of truth; client-primary creates divergence risk when two devices edit state concurrently
- **Rejection Reason**: Backend-primary already locked in #1 GSM Rule 5 priority 3. Multi-device session lock (ADR-002 /session/claim) enforces single active device, making client-primary safe only for LootDrop (which uses backend cache as second copy via ADR-002).

### Alternative 3: localStorage fallback for Private Mode
- **Description**: When IndexedDB unavailable, fall back to localStorage
- **Pros**: Preserves LootDrop in Private Mode (5MB is sufficient for loot payload)
- **Cons**: Two storage code paths to maintain; localStorage same 7-day ITP — no durability improvement; adds JavaScriptBridge dependency; solo-dev scope; TD recommendation: prohibited
- **Rejection Reason**: Detect-and-gate is simpler and honest. A user who deliberately uses Private Mode is explicitly opting out of session persistence. Disabling loot grants is the correct Pillar 3 response vs silently losing loot in localStorage.

## Consequences

### Positive
- PersistenceLayer stories can begin with a clear, ratified storage API and migration protocol
- Private Mode handling is explicit and Pillar 3-compliant (no silent loss)
- LootDrop conflict resolution is unambiguous (unsynced-only client wins)
- 900ms migration ceiling is documented — VS-tier can budget for it
- localStorage prohibition prevents accidental fragmentation of storage paths

### Negative
- Private Mode disables loot — users who habitually use Private Mode cannot earn loot (may be frustrating)
- 900ms migration ceiling is tight; very complex migrations may need squashing to stay within bound
- Detect-and-gate banner adds UI surface owned by #22 Character Screen / #21 Loot Drop Modal team

### Risks
- **Risk 1**: ITP touch-refresh doesn't work as expected on future Safari versions (ITP policy changes). **Mitigation**: LootDrop always synced to backend (ADR-002) — backend is durable safety net even if ITP evicts local
- **Risk 2**: IDBFS syncfs latency causes unexpected UI jank on heavy writes. **Mitigation**: All writes are async from player's perspective; write_completed telemetry (ADR-006 Contract 11) monitors latency
- **Risk 3**: Schema migration abort leaves partial state. **Mitigation**: Tombstone forward-recovery (#1 GSM Rule 2) catches any interrupted writes on next boot; corrupt-save path defaults to Idle boot

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| persistence-layer.md (#3) | IPersistence interface (read/write/delete/migrate) | Ratified; is_private_mode() added to interface |
| persistence-layer.md (#3) | MAX_MIGRATION_CHAIN_LENGTH=6, MIGRATION_BUDGET_MS=150ms, total 900ms | ADR-003 formally ratifies 900ms — consistent with ADR-006 Contract 10 post-Accepted 2026-05-28 (N-004 sync 2026-05-28 — replaces prior "corrects stale 5000ms" prose) |
| game-state-machine.md (#1) | Storage Backend: IndexedDB via user:// (Decision #5) | IndexedDB technology choice ratified as project standard |
| game-state-machine.md (#1) | Rule 5 priority 1 "client wins" LootDrop | Extended to "unsynced-only client wins" (priority 1.5 synced → backend canonical) |
| game-state-machine.md (#1) | Q-E1 Private Mode IndexedDB unavailable | Detect-and-gate + banner + loot disable ratified as mandatory Pillar 3 mitigation |
| game-state-machine.md (#1) | Safari ITP touch-refresh every resume | Ratified as touch() method called on NOTIFICATION_APPLICATION_RESUMED + pageshow |
| game-state-machine.md (#1) | ADR-006 Contract 11 FileAccess bool semantics | Formally ratified: bool = in-memory MEMFS write; IDB flush async; ~0.05% loss accepted VS-tier |

## Performance Implications
- **CPU**: PersistenceLayer._ready() adds boot time: _detect_storage_mode() ~1ms; touch() ~0.5ms per call (async, not blocking frame)
- **Memory**: user://state.json estimated 1-50KB (well within `max_state_file_bytes = 1MB` limit from registry); in-memory fallback duplicates this in RAM
- **Load Time**: Schema migration: 0ms normally; up to 900ms on version bump (first-boot after upgrade); show splash >300ms
- **Network**: Backend-primary writes via ADR-002 — one write per state transition, fire-and-forget; not on critical path

## Migration Plan

**ADR-003 is a new ADR** (no prior persistence architecture to migrate from). Applies to #3 PersistenceLayer GDD implementation sprint.

**technical-preferences.md update required** (localStorage prohibition):
Add to `## Forbidden Patterns`:
```
- `window.localStorage` — use Godot `user://` (FileAccess) instead. localStorage has 5MB quota limit and requires JavaScriptBridge. All save state goes through PersistenceLayer.
```
CI enforcement: `tools/ci/check_local_storage_calls.gd` — grep for `window.localStorage` outside `tests/` + `tools/debug/`.

## Validation Criteria
1. Normal Mode: write → read round-trip produces identical data; `is_private_mode() == false`
2. Private Mode: `FileAccess.open()` returns null → `is_private_mode() == true` → `private_mode_detected` signal emitted → Loot Drop System disables grants
3. ITP test (requires Safari): close+reopen origin after 6 days 23 hours → state still readable (touch refresh kept ITP alive)
4. Schema migration: boot with `schema_version = 0` → migrate to version 1 → success within 150ms; show splash if > 300ms
5. Schema chain abort: inject 200ms migration step → abort at step 1 → `critical_save_failed` emitted → boot to Idle
6. Unsynced LootDrop: local has loot_reveal_pending=true + backend returns 404 → client wins (loot preserved). Synced LootDrop: local has loot_reveal_pending=true + backend returns 200 → backend canonical payload used
7. WASM boot: Cold WASM start + schema migration ≤ 900ms on device baseline

## Related Decisions
- **ADR-006**: State Machine Contract — Contract 10 (migration), Contract 11 (FileAccess bool), IPersistence interface
- **ADR-001**: Web Export Budget Caps — 512MB memory ceiling applies to IndexedDB allocation
- **ADR-002**: GymSys Integration Protocol — backend-primary persistence for LootDrop via cache/commit endpoints
- **ADR-004** (pending): CORS/cross-origin auth — cross-origin header required for backend state writes
- **game-concept.md**: "backend-primary (`game_state.json` per user in GymSys backend), localStorage cache for offline boot" — this ADR updates "localStorage" to IndexedDB (the correct Godot Web Export storage backing)
