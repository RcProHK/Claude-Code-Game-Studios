# ADR-0002: GymSys Integration Protocol

## Status
Proposed

## Date
2026-05-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Networking (HTTP REST + SSE v0.2 upgrade path) |
| **Knowledge Risk** | LOW for `HTTPRequest` node (stable API 4.0+); MEDIUM for JavaScriptBridge SSE (v0.2 feature, requires VS spike validation) |
| **References Consulted** | `docs/engine-reference/godot/modules/networking.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `HTTPRequest.timeout: float` (stable); `JavaScriptBridge.create_callback()` + `JavaScriptBridge.eval()` returning `JavaScriptObject` (stable since 4.2); `SceneTree.create_timer(time_sec, process_always: bool = true)` — ADR prescribes explicit 4-param form `create_timer(delay, true, false, true)` to ensure pause + time_scale independence |
| **Verification Required** | VS-tier: (1) `HTTPRequest` HTTPS + custom header over actual GymSys origin; (2) JavaScriptBridge SSE callback — GDScript `func _on_sse_event(args: Array)` receives `args[0]` as event data; (3) CORS preflight pass with `X-Session-Token` header (blocked on ADR-004); (4) `server_epoch_id` mismatch detection round-trip |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-006 State Machine Contract (Accepted 2026-05-28 — N-002 sync 2026-05-28) — Contract 2 (transition_id format + UNIQUE constraint); Contract 15 (server-authoritative pending_since); Decision #3 (RestPeriod / GymSys-owned timer); Decision #4 (session lock + LootDrop idempotency). ADR-001 (Proposed) — Web Export budget constraints inform poll interval. **ADR-004 CORS/cross-origin auth (pending)** — endpoint spec finalized here but `Access-Control-Allow-Credentials` + origin allowlist deferred to ADR-004; ADR-002 cannot reach Accepted without ADR-004 resolving CORS for custom headers (N-003 follow-up — coordinated ratification needed). |
| **Enables** | ADR-003 (Save State Strategy) — backend LootDrop cache endpoint enables backend-primary persistence; ADR-005 (Loot Rarity Formula) — loot commit endpoint contract defines inventory payload schema |
| **Blocks** | VS-tier implementation stories for #2 GymSys Backend Client (#2 GDD: all 13 signals + retry matrix + session management); GymSys backend development sprint (new endpoints + schema) |
| **Ordering Note** | ADR-002 Proposed → enables GymSys backend sprint. ADR-002 Accepted requires ADR-004 CORS resolution + VS-tier endpoint validation. Backend Readiness Gate (§ below) stages which endpoints must exist by VS vs Post-VS. |

## Context

### Problem Statement
Mirror Hero's game loop depends on GymSys workout data (set completions, exercise switches, rest periods) to drive avatar progression and loot drops. This ADR defines the client–server integration protocol: which HTTP endpoints exist, how the game client polls for workout events, how session state and loot drops are durably committed across devices, and the upgrade path from MVP polling to v0.2 Server-Sent Events.

### Constraints
- GymSys backend is an existing system at `\\rcprohk\docker\studiosys` (not this project) — new endpoints must be additive, not breaking
- Single developer owns both sides — backend API surface must stay minimal for VS-tier
- Web Export primary target — SSE via `JavaScriptBridge.eval` only (no native Godot SSE support); native desktop keeps polling
- ADR-006 Contract 2 locks `transition_id` format; ADR-006 Contract 15 locks server-authoritative `pending_since_server`
- ADR-004 (CORS topology) pending — HTTPS + custom header CORS must be resolved before Accepted status

### Requirements
- Must support 5-second polling with ±0.5s jitter (game-concept §, #2 GDD Formula 1)
- Must implement single-device session lock (ADR-006 Decision #4)
- Must implement idempotent LootDrop cache + commit with transition_id UNIQUE per table (ADR-006 Contract 2)
- Must expose rest_started(duration_seconds) + rest_ended from backend (ADR-006 Decision #3)
- Must handle 401 (force-boot), 429 (Retry-After), 5xx (backoff) correctly (#2 GDD Rule 12)
- Must support event cursor persistence across GymSys server restarts (no silent data loss)

## Decision

### Polling Protocol (MVP)

**Endpoint**: `GET /api/game/state?last_event_id={N}&server_epoch_id={E}`

**Event cursor design** (TD HIGH fix):
- GymSys events table uses `DB BIGINT autoincrement event_id` — persistent across server restarts
- `server_epoch_id`: server's boot timestamp (unix ms), returned in every response
- Client stores both `last_event_id` + `server_epoch_id`
- On poll: if response `server_epoch_id != stored_epoch_id` → server restarted → client ignores `last_event_id`, performs full resync (force resync event clears stale cursor)

**Poll response format** (differential event list):
```json
{
  "server_epoch_id": 1748285000000,
  "last_event_id": 1042,
  "events": [
    { "id": 1040, "type": "set_logged",    "data": { "exercise_id": "bench_press", "reps": 8, "weight": 60.0, "completed_at": 1748284800 } },
    { "id": 1041, "type": "rest_started",  "data": { "duration_seconds": 90 } },
    { "id": 1042, "type": "rest_ended",    "data": {} }
  ]
}
```

**Event types** (maps 1:1 to #2 GymSys Backend Client GDD signals):

| type | Signal emitted by #2 GDD | Notes |
|------|--------------------------|-------|
| `workout_started` | `workout_started()` | — |
| `set_logged` | `set_logged(exercise_id, reps, weight)` | weight: float kg |
| `rest_started` | `rest_started(duration_seconds: int)` | GymSys owns timer per Decision #3 |
| `rest_ended` | `rest_ended()` | — |
| `workout_completed` | `workout_completed(completed_at: int)` | unix timestamp |

**Polling cadence**: `GYMSYS_POLL_INTERVAL_SECONDS = 5.0` ± `POLL_JITTER_SECONDS = 0.5s` (Formula 1 from #2 GDD: `actual_interval = 5.0 + randf_range(-0.5, 0.5)`)

**Godot pattern** (validated by godot-specialist):
```gdscript
# Orphan HTTPRequest per channel, queue_free after completion
var req := HTTPRequest.new()
req.timeout = POLL_TIMEOUT_SECONDS  # 4.0s
add_child(req)
req.request_completed.connect(
    func(result, code, headers, body): _on_poll_complete(result, code, headers, body); req.call_deferred("queue_free"),
    CONNECT_ONE_SHOT
)
req.request(gymsys_url + "/api/game/state", ["X-Session-Token: " + session_token], HTTPClient.METHOD_GET)
```

**Retry timer** (explicit params per godot-specialist advisory):
```gdscript
get_tree().create_timer(retry_delay_sec, true, false, true)  # process_always=true, ignore_time_scale=true
```

---

### Session Management (ADR-006 Decision #4)

**Claim endpoint**: `POST /api/session/claim`
- Request: `Authorization: X-Session-Token` (empty on first claim), or no auth header
- Response: `{"session_token": "abc123", "expires_at": 1748971200}`
- Backend: write `accounts.active_session_token = token`; invalidate prior active token; 401 on all prior-token requests

**Auth header**: `X-Session-Token: {token}` — on ALL authenticated requests (locked by ADR-006 registry + #1 GSM Decision #4)

**401 handling**: GymSys Client emits `session_invalidated()` → #1 GSM Rule 5 priority-0 force-boot reconciliation (active-state-deferred per Decision #4)

**Session renewal**: Backend returns `new_session_token` in any response if token approaching expiry (optional field); client updates stored token on receipt

---

### LootDrop Endpoints (ADR-006 Contract 2 + 15)

**UNIQUE constraint scope fix** (TD CRITICAL): Two separate tables, each with `transition_id VARCHAR(255) UNIQUE` (NOT a single table). Child suffix pattern (`transition_id + ':loot-cache'` vs `transition_id + ':loot-commit'`) eliminates collision risk.

#### 1. Cache endpoint (write on LootDrop transition)
`POST /api/game/lootdrop/{transition_id}:loot-cache/cache`
- Request body: `{"payload": {...loot data...}, "account_id": "..."}`
- Response: `{"pending_since_server": 1748284800}` (unix timestamp — source of truth per Contract 15)
- Backend: upsert `lootdrop_cache` table; `CONFLICT(transition_id)` → return existing `pending_since_server` (idempotent)
- Retention: 37 days (30-day hard cap + 7-day buffer per Contract 15 + `lootdrop_pending_hard_cap_days = 30`)

#### 2. Cache fetch endpoint (restore on boot / device switch)
`GET /api/game/lootdrop/{transition_id}:loot-cache/cache`
- Response: `{"payload": {...}, "pending_since_server": 1748284800}` OR `404` if expired/not found
- Used by #1 GSM Rule 5 priority-1 client-wins LootDrop restore + priority-0.5 30-day hard cap check

#### 3. Commit endpoint (player confirms loot)
`POST /api/game/lootdrop/{transition_id}:loot-commit/commit`
- Request body: `{"account_id": "..."}`
- Response: `{"canonical_inventory": [...all items...]}` (authoritative post-commit state)
- Backend: upsert `lootdrop_commit` table; `CONFLICT(transition_id)` → return existing canonical_inventory (idempotent — no double-grant)
- Client merges canonical_inventory into local state; clears `loot_pending`

---

### State Write Endpoint (ADR-006 Contract 2)

`POST /api/game/state`
- Headers: `X-Transition-Id: {transition_id}:state`, `X-Session-Token: {token}`
- Request body: `{"from_state": "...", "to_state": "...", "payload": {...}}`
- Response: `200 OK` (idempotent) OR `401` (session expired)
- Backend: DB row `(transition_id VARCHAR UNIQUE, account_id, from_state, to_state, payload, created_at)` — UNIQUE on `transition_id:state`; duplicate POST → 200 dedup

---

### Rest Period Timing (GSM Decision #3)

GymSys backend **owns** rest period duration. Client does NOT start a timer — it waits for the backend signals:

- `rest_started(duration_seconds: int)` — fired by GymSys `.rest-bar` UI when user starts rest timer
- `rest_ended()` — fired when timer expires OR user ends rest early

GymSys backend extension required: REST endpoint or event extension to include `duration_seconds` in `rest_started` event payload (if not already present).

Fallback: if `rest_started` event has no `duration_seconds` → client uses `REST_PERIOD_FALLBACK_SECONDS = 90` per #1 GSM GDD.

---

### Error Handling

| HTTP Status | Client behaviour |
|-------------|-----------------|
| `200 OK` | Process response normally |
| `204 No Content` | No new events since last_event_id; schedule next poll |
| `401 Unauthorized` | Emit `session_invalidated()`; GSM Rule 5 priority-0 force-boot |
| `429 Too Many Requests` | Read `Retry-After` header; delay next poll by that value; emit `dropped_poll_tick` |
| `5xx Server Error` | Apply `retry_delay(n)` exponential backoff; after `MAX_5XX_RETRY = 5` → emit `poll_failed` → GSM enters Disconnected |
| Network timeout | Same as 5xx path |

**Maximum concurrent in-flight**: `MAX_INFLIGHT_REQUESTS = 4` across 4 channels (poll, state_write, loot_cache, loot_commit). Single-flight per channel — new request drops if channel occupied.

---

### SSE v0.2 Upgrade Path (de-risked)

**Polling-forever is the acceptable long-term fallback.** SSE is a nice-to-have latency improvement; VS-tier + MVP ship with polling. SSE complexity (EventSource reconnect, credential refresh, Web-only code path) is significant for solo developer.

**If and when SSE is implemented (v0.2+)**:

- Backend: standard SSE endpoint `GET /api/game/stream` (EventStream mime type)
- Client (Web Export only):
```gdscript
var sse_callback := JavaScriptBridge.create_callback(_on_sse_event)
var _sse_obj: JavaScriptObject = JavaScriptBridge.eval("""
    (function(url, token, handler) {
        var es = new EventSource(url + '?token=' + token, {withCredentials: true});
        es.onmessage = function(e) { handler([e.data, '']); };
        es.onerror = function() { handler(['', '__error__']); };
        return es;
    })(arguments[0], arguments[1], arguments[2])
""", true, gymsys_sse_url, session_token, sse_callback)

# GDScript callback signature (godot-specialist advisory):
func _on_sse_event(args: Array) -> void:
    var data: String = args[0]
    if data.begins_with("__error__"): _on_sse_error()
    else: _process_event_json(data)
```
- Fallback: if EventSource fails → revert to polling (same `_process_event_json` path)
- Native desktop: continues polling (no JavaScriptBridge)

---

### Backend Readiness Gate (VS-tier staging)

**Phase A — Required before VS-tier implementation**:
1. `GET /api/game/state?last_event_id={N}&server_epoch_id={E}` — differential events with DB cursor
2. `POST /api/session/claim` → session_token
3. `POST /api/game/state` — state write with transition_id header

**Phase B — Required before Pre-MVP ship**:
4. `POST /api/game/lootdrop/{id}:loot-cache/cache`
5. `GET /api/game/lootdrop/{id}:loot-cache/cache`
6. `POST /api/game/lootdrop/{id}:loot-commit/commit`

**Phase C — v0.2 (nice-to-have)**:
7. `GET /api/game/stream` (SSE endpoint)

---

### Architecture Diagram

```
Game Client (Godot WASM)          GymSys Backend
─────────────────────             ─────────────────────
GymSysClient autoload             REST API
  ├─ poll channel ─────────────→  GET /api/game/state
  │    ↑ 5s±0.5s                     → events[] since last_event_id
  │    ↓ events                       → server_epoch_id (drift detection)
  │
  ├─ state_write channel ──────→  POST /api/game/state
  │    X-Transition-Id: id:state
  │
  ├─ loot_cache channel ───────→  POST/GET /api/game/lootdrop/{id}:loot-cache/cache
  │                                  ← pending_since_server (authoritative)
  │
  └─ loot_commit channel ──────→  POST /api/game/lootdrop/{id}:loot-commit/commit
                                    ← canonical_inventory (no double-grant)

Session management:
  GymSysClient ───────────────→  POST /api/session/claim
                 X-Session-Token   ← session_token, expires_at
```

### Key Interfaces

**Backend schema additions** (GymSys side):
```sql
-- accounts table extension
ALTER TABLE accounts ADD COLUMN active_session_token VARCHAR(255);

-- New tables
CREATE TABLE game_events (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    account_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    event_data JSONB NOT NULL,
    created_at BIGINT NOT NULL  -- unix ms
);
CREATE INDEX idx_game_events_account_created ON game_events(account_id, id);

CREATE TABLE lootdrop_cache (
    transition_id VARCHAR(255) PRIMARY KEY,  -- UNIQUE per ADR-006 Contract 2 child ':loot-cache'
    account_id VARCHAR(255) NOT NULL,
    payload JSONB NOT NULL,
    pending_since_server BIGINT NOT NULL,    -- unix timestamp (Contract 15)
    created_at BIGINT NOT NULL,
    expires_at BIGINT NOT NULL               -- created_at + 37days
);

CREATE TABLE lootdrop_commit (
    transition_id VARCHAR(255) PRIMARY KEY,  -- UNIQUE per ADR-006 Contract 2 child ':loot-commit'
    account_id VARCHAR(255) NOT NULL,
    canonical_inventory JSONB NOT NULL,
    committed_at BIGINT NOT NULL
);

CREATE TABLE state_writes (
    transition_id VARCHAR(255) PRIMARY KEY,  -- UNIQUE per ADR-006 Contract 2 child ':state'
    account_id VARCHAR(255) NOT NULL,
    from_state VARCHAR(64),
    to_state VARCHAR(64),
    payload JSONB,
    created_at BIGINT NOT NULL
);
```

**Client-side constants** (already in design/registry/entities.yaml):
```
gymsys_poll_interval_seconds = 5.0
poll_jitter_seconds = 0.5
poll_timeout_seconds = 4.0
write_timeout_seconds = 10.0
max_inflight_requests = 4
max_committed_cache_entries = 50
max_5xx_retry_attempts = 5
```

## Alternatives Considered

### Alternative 1: WebSocket instead of polling + SSE
- **Description**: Replace REST polling with WebSocket bi-directional connection
- **Pros**: Real-time; both directions; lower latency
- **Cons**: GymSys is a REST API server; adding WebSocket requires significant backend migration; Web Export WebSocket API (via JavaScriptBridge) is more complex; overkill for 5-event-per-minute workout update rate
- **Rejection Reason**: VS-tier scope; polling 5s is sufficient for workout cadence; SSE v0.2 upgrade path provides latency improvement without full WebSocket migration cost

### Alternative 2: Full snapshot poll response
- **Description**: Each poll returns full game state snapshot (current workout, all completed sets, current loot status)
- **Pros**: Simpler client — no event replay, just overwrite local state
- **Cons**: Larger response payload on every poll; workout sessions can grow to many sets (~800 bytes/set × 50 sets = 40KB per session); wastes bandwidth on every 5s poll
- **Rejection Reason**: Differential event list is smaller per poll; event-stream model also enables natural SSE upgrade

### Alternative 3: Polling-only forever (no SSE path)
- **Description**: Keep HTTP polling in perpetuity; never invest in SSE
- **Pros**: Simplest long-term maintenance; proven stable
- **Cons**: 5s latency for `rest_started(duration_seconds)` creates ≤5s mismatch between actual rest start and game response; for v0.2 this may frustrate users
- **Rejection Reason**: ADR acknowledges polling-forever is acceptable fallback; SSE path is de-risked as optional v0.2 feature — not blocking anything

### Alternative 4: In-memory cursor only (no DB autoincrement)
- **Description**: Simple integer counter reset on server restart; clients resync by getting all recent events
- **Pros**: Simpler backend implementation
- **Cons**: Server restart = clients miss events between restart and resync; for workout completion this could mean missing a `workout_completed` event = no guaranteed loot drop = Pillar 3 violation
- **Rejection Reason**: DB autoincrement BIGINT has trivial cost; event persistence is required for Pillar 3 guarantee

## Consequences

### Positive
- #2 GymSys Backend Client GDD all 13 signals + retry logic can be implemented against concrete endpoint contracts
- LootDrop idempotency guaranteed at DB layer (separate UNIQUE tables) — no application-level dedupe logic needed
- Server restart resilience via `server_epoch_id` — no silent data loss
- Backend Readiness Gate stages development risk — VS-tier only needs Phase A (3 endpoints)

### Negative
- GymSys backend requires schema migration + 6 new endpoints — parallel backend dev sprint needed
- ADR cannot reach Accepted until ADR-004 CORS resolved — X-Session-Token custom header requires CORS policy
- SSE v0.2 path adds Web-only JavaScript bridge code — testing complexity for solo developer

### Risks
- **Risk 1**: GymSys backend `rest_started` event doesn't include `duration_seconds` in existing schema. **Mitigation**: `REST_PERIOD_FALLBACK_SECONDS = 90` in client; vs-tier playtest validates; ADR notes as backend extension requirement
- **Risk 2**: CORS preflight fails for `X-Session-Token` header. **Mitigation**: ADR-004 must address before Accepted; ADR-002 explicitly depends on ADR-004
- **Risk 3**: `game_events` table grows unboundedly. **Mitigation**: retention policy = events older than 7 days pruned (workout sessions ≤90min; 7-day window is several orders of magnitude excess)
- **Risk 4**: GymSys backend sprint vs game client sprint timeline mismatch (both solo dev). **Mitigation**: Backend Readiness Gate — client can be built with mock server for Phase B/C endpoints; only Phase A needed to start real integration testing

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| gymsys-backend-client.md (#2) | All 13 signals (workout + auxiliary) normalised from polling | Poll event types map 1:1 to #2 GDD signals; differential event list format defined |
| gymsys-backend-client.md (#2) | Rule 12 retry matrix: 5xx → retry_delay backoff × 5 | Error handling table ratifies client retry behaviour; backend must respond per HTTP standards |
| gymsys-backend-client.md (#2) | `MAX_INFLIGHT_REQUESTS = 4` (4 channels) | 4 endpoint families ratified (poll, state_write, loot_cache, loot_commit) |
| game-state-machine.md (#1) | Decision #3: GymSys owns rest_started(duration_seconds) + rest_ended | Backend event format includes `duration_seconds` in `rest_started` event data |
| game-state-machine.md (#1) | Decision #4: session lock + LootDrop idempotency + transition_id backend dedupe | POST /session/claim + 3 LootDrop endpoints + state_write endpoint with UNIQUE constraints |
| game-state-machine.md (#1) | ADR-006 Contract 15: server-authoritative pending_since_server | POST /lootdrop/:loot-cache/cache returns `pending_since_server` from backend DB timestamp |
| game-state-machine.md (#1) | ADR-006 Contract 2: transition_id UNIQUE for double-grant prevention | Separate tables per endpoint family (lootdrop_cache, lootdrop_commit, state_writes) each with UNIQUE on transition_id |

## Performance Implications
- **CPU**: Poll processing: <0.1ms per received event (JSON parse + signal dispatch); within Foundation autoloads 2.0ms mobile budget (ADR-001)
- **Memory**: `MAX_COMMITTED_CACHE_ENTRIES = 50` entries in `_committed_transitions` (Rule 15); `game_events` table retention 7 days; lootdrop tables retention 37 days
- **Load Time**: No impact on initial load; first poll fires after `GameStateMachine._ready()` completes
- **Network**: 5s poll × ~500 bytes response (typical) = 100 bytes/s bandwidth — negligible on any connection

## Migration Plan

**Client side**: ADR-002 is a new ADR (no prior client networking code to migrate from). Applies immediately to VS-tier #2 GymSys Backend Client implementation.

**Backend side (GymSys at `\\rcprohk\docker\studiosys`)**:
1. Phase A (before VS-tier implementation): Add `game_events` table; extend accounts schema; implement `/api/game/state` (poll), `/api/session/claim`, `/api/game/state` (write)
2. Phase B (before Pre-MVP ship): Add `lootdrop_cache` + `lootdrop_commit` + `state_writes` tables; implement 3 LootDrop endpoints
3. Phase C (v0.2, optional): Add SSE endpoint `/api/game/stream`

## Validation Criteria
1. Phase A backend endpoints live and accessible from Godot WASM at `localhost` dev environment
2. `server_epoch_id` mismatch correctly triggers full resync (test: restart dev GymSys, verify client resyncs)
3. LootDrop idempotency: same `transition_id:loot-commit` POST twice → same `canonical_inventory` response, zero inventory duplication
4. `X-Session-Token` from non-active device → 401 → GSM force-boot observed in test
5. `rest_started(duration_seconds)` received with non-null duration → GSM RestPeriod duration data-driven
6. ADR-004 CORS review: `X-Session-Token` header passes preflight on production origin

## Related Decisions
- **ADR-006**: State Machine Contract — Contracts 2+15 (transition_id, pending_since_server); Decision #3+#4
- **ADR-001**: Web Export Budget Caps — poll interval + HTTP channel CPU within Foundation autoload budget; JavaScriptBridge patterns
- **ADR-004** (pending): CORS / cross-origin auth topology — required for `X-Session-Token` custom header; ADR-002 Accepted blocked on this
- **ADR-003** (pending): Save State Strategy — LootDrop backend-mirror cache (POST /lootdrop/:cache) is part of backend-primary persistence design
- **game-concept.md**: "GymSys polling /api/game/state every 5s" + "backend save state via GymSys" — sources of polling interval + persistence strategy
