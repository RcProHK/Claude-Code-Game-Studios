# ADR-0012: Telemetry Data Pipeline & Privacy

## Status
**Accepted (contract) 2026-06-12** — focused authoring-time ratification following the ADR-0002 / ADR-0004 partial-ratification precedent: the **transport/privacy contract is Locked** (endpoint pair, dedicated-isolated channel, `(session_id, client_event_id)` dedup, beacon token-in-body, 180-day retention, opt-out two-layer). All upstream deps (ADR-0002/0003/0004/0008) are **Accepted** and this is an additive contract/topology decision with **no measurement gate** for the design choices — so it reaches Accepted at authoring. Downstream #28 Story 011 (flush) + Story 012 (beacon) may now implement against this contract.
*(Previously: Proposed — drafted this session.)*

> Authoring context: degraded-inline `/architecture-decision` (full review mode — engine-specialist validation + TD-ADR coherence performed inline per project convention; grep-verified against shipped ADR-0002/0003/0004 + `docs/registry/architecture.yaml` + `design/gdd/telemetry.md` + Story 011/012). The **HOW** layer for #28 Telemetry: the GDD (`telemetry.md`) ratifies WHAT/WHY (passive observer, de-id envelope, flush triggers); this ADR ratifies HOW the buffered events reach the player's own GymSys backend (transport channel, endpoint contract, beacon path, dedup, retention, opt-out enforcement).
>
> **Transport / empirical validation remains VS-tier-gated + Provisional** (see *Verification Required* §) — same honesty posture as ADR-0002/0004: no live `navigator.sendBeacon` arrival, token-in-body auth, or backend dedup is claimed validated until a real GymSys backend + nginx deploy exists. Tag with `(verified YYYY-MM-DD)` when deployment validation lands to mark *fully* Accepted.
>
> **Recommended**: fold this ADR into the traceability matrix via `/architecture-review` in a **fresh session** (independent of this authoring context).

## Date
2026-06-12

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Networking (HTTP REST batch POST + Web `navigator.sendBeacon` via JavaScriptBridge seam) |
| **Knowledge Risk** | LOW for `HTTPRequest` (stable API 4.0+, same pattern as ADR-0002); MEDIUM for `sendBeacon` (Web-only, routed through `platform_detect` JS seam — requires VS-tier validation, same gate class as ADR-0002 SSE) |
| **References Consulted** | `docs/engine-reference/godot/modules/networking.md`, `docs/engine-reference/godot/VERSION.md`, ADR-0002 (HTTPRequest-per-channel precedent), ADR-0001 (JavaScriptBridge seam forbidden-pattern) |
| **Post-Cutoff APIs Used** | `HTTPRequest` + `custom_headers` (stable 4.0+); `JavaScriptBridge.eval()` for `navigator.sendBeacon` — confined to `src/autoload/platform_detect.gd` per ADR-0001 forbidden-pattern `raw_javascript_bridge_eval`. No threading / SharedArrayBuffer dependency. |
| **Verification Required** | VS-tier: (1) `POST /api/game/telemetry` with `X-Session-Token` header reaches FastAPI `/api/game/` router (same-origin, no preflight); (2) `navigator.sendBeacon('/api/game/telemetry/beacon', blob)` fires on `pagehide` and arrives at backend with **token-in-body** (sendBeacon cannot set custom headers — see Decision §Beacon); (3) backend `UNIQUE(session_id, client_event_id)` dedup round-trip (POST same batch twice → zero duplicate rows); (4) retention prune job removes rows older than `TELEMETRY_RETENTION_DAYS`; (5) opt-out: backend drops events for `telemetry_opt_out` accounts even if a stale client flushes. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 CORS/Cross-Origin Topology (Accepted) — same-origin `/api/game/` namespace + relative URL; ADR-0002 GymSys Integration Protocol (Accepted) — `X-Session-Token` auth + HTTPRequest-per-channel idiom + `session_token` source; ADR-0003 Save State Strategy (Accepted) — `user://` spool only, localStorage FORBIDDEN, private-mode gate; ADR-0008 Autoload Position Map (Accepted) — #28 boots Last. **All deps already Accepted** — this ADR can reach Accepted with no upstream gate. |
| **Enables** | #28 Telemetry Story 011 (flush model async batch POST) + Story 012 (page-hide beacon) — both `Status: Blocked` pending this ADR (G-TEL-5). |
| **Blocks** | #28 Story 011 + Story 012 cannot start until this ADR is **Accepted**. All other #28 stories (001–010, 013–018) are independent of this ADR. |
| **Ordering Note** | This ADR is **additive** to ADR-0002 — it extends the same `/api/game/` topology with a telemetry channel; it does not modify any ADR-0002 endpoint. The telemetry HTTP channel is **separate** from ADR-0002's 4-channel `MAX_INFLIGHT_REQUESTS=4` pool (owned by #2 GymSysBackendClient) — see Decision §Transport. |

## Context

### Problem Statement
#28 Telemetry (`design/gdd/telemetry.md`) is a pure passive observer that buffers de-identified `TelemetryEvent` envelopes and flushes them to the player's own GymSys backend. The GDD deliberately scopes itself to **behavior** (which events, what envelope, how aggregated, how the Pre-MVP gate is satisfied) and defers the **transport/privacy implementation** to "a future ADR-0012" (telemetry.md L20, Dependencies §Governing ADRs L276, Open Questions Q-T2/T3/T6/T7). Without this ADR, Story 011 (flush) and Story 012 (beacon) have no ground-truth transport contract and are correctly marked `Blocked` (G-TEL-5). This ADR resolves Q-T2/T3/T6/T7 and unblocks them.

The telemetry system exists to answer one production question — the Pre-MVP PIVOT/KILL hypothesis (`systems-index.md` L331: "Telemetry data after Month 4 fails to show『players glance + drop excitement』signals → PIVOT or KILL"). For that data to be usable, it must (a) reliably reach the backend without ever touching gameplay, and (b) honour the first-party-only / de-identified privacy posture the GDD locks (telemetry.md L18, Rule 4).

### Constraints
- **Pillar 2 hard constraint** — telemetry is 100% passive; the transport layer must never block a gameplay frame and must never affect the gameplay session (e.g. a telemetry auth failure must NOT trigger #2's 401 force-boot).
- **First-party-only privacy** — flush target is the player's own GymSys backend (same-origin per ADR-0004). **No third-party analytics SaaS. No PII. No raw body data.** This is a hard constraint aligned with the game's premium / non-predatory positioning.
- **Web platform reality** — the tab can be killed at any time (mobile Safari especially); a best-effort page-hide flush is required. `navigator.sendBeacon` is the correct primitive but **cannot set custom request headers** (browser API limitation), so the normal `X-Session-Token` header auth does not work on the beacon path.
- **Engine constraints (carried from prior ADRs)** — raw `JavaScriptBridge.eval` only in `platform_detect.gd` (ADR-0001); relative URLs only (ADR-0004); `user://` spool only, localStorage FORBIDDEN (ADR-0003).
- **Solo developer** — backend surface must stay minimal (one table, two endpoints) and additive to studiosys.

### Requirements
- Must flush batched events to `/api/game/telemetry` same-origin with at-least-once delivery + backend dedup.
- Must isolate telemetry transport from gameplay-critical #2 channels (never starve a `loot_commit`).
- Must support a best-effort `sendBeacon` flush on `visibilitychange→hidden` / `pagehide`, with an XHR fallback (telemetry.md Rule 12, EC-18).
- Must enforce de-identification at both client (CI-2 denylist) and backend (reject out-of-schema fields) — defense in depth.
- Must honour player opt-out (`telemetry_enabled=false`, EC-17) at client (zero bytes out) and backend (drop stale-client events).
- Must define a retention period that covers the Month-4 Pre-MVP analysis window, with player-initiated deletion.

## Decision

### 1. Endpoint Contract (resolves Q-T2)

Two endpoints under the existing ADR-0004 `/api/game/` FastAPI APIRouter (relative URL, same-origin, no CORS):

| Endpoint | Method | Auth | Body | Response | Trigger |
|---|---|---|---|---|---|
| `/api/game/telemetry` | `POST` | `X-Session-Token` **header** | batch envelope (below) | `200 {"accepted": int, "duplicates": int}` / `401` / `429` / `5xx` | Normal async batch flush (Rule 6 a/b/c) |
| `/api/game/telemetry/beacon` | `POST` | `session_token` **in body** | batch envelope + `session_token` field | `204 No Content` (fire-and-forget) | Page-hide best-effort beacon (Rule 12) |

The **beacon endpoint is deliberately separate** from the header-authed main endpoint so the weaker token-in-body auth is explicit and never weakens the main flush path. Both write the same `game_telemetry` table.

**Batch envelope** (JSON):
```json
{
  "session_id": "a1b2c3...",
  "client_batch_id": 7,
  "schema_envelope_version": 1,
  "events": [
    {
      "event_name": "hit_resolved",
      "schema_version": 1,
      "client_event_id": 1042,
      "session_id": "a1b2c3...",
      "client_ts_unix": 1749700000,
      "client_ts_monotonic_ms": 183400,
      "game_state": "combat_active",
      "payload": { /* de-identified per Rule 4 */ }
    }
  ]
}
```
(Per-event envelope = telemetry.md Rule 3, unchanged. The batch wrapper adds `client_batch_id` for client-side retry tracking and `schema_envelope_version` for the batch protocol itself.)

The beacon variant adds one top-level field: `"session_token": "<token>"` (read by the backend instead of the `X-Session-Token` header).

### 2. Transport Channel — Dedicated & Isolated (resolves Q-T3)

Telemetry owns **its own orphan `HTTPRequest` node** (a 5th channel), created in the telemetry autoload, **separate from #2 GymSysBackendClient's 4-channel `MAX_INFLIGHT_REQUESTS=4` pool** (poll / state_write / loot_cache / loot_commit).

- **Single in-flight per telemetry channel.** A new flush is skipped (events stay buffered) if a flush is already in-flight.
- **Rejected: reuse #2's HTTP path.** Mixing telemetry into #2's pool would let a telemetry batch occupy a slot and delay a gameplay-critical `loot_commit` — a direct Pillar 3 risk and a violation of telemetry.md Rule 1 (pure observer, zero gameplay side-effect) at the transport layer. Telemetry being a separate orphan node keeps the observer one-directional even over the wire.
- **Browser HTTP/1.1 connection budget**: 4 (#2) + 1 (telemetry) = 5 concurrent, well within the ~6-per-host limit (same headroom analysis as ADR-0002 `http_request_per_channel`).
- **Godot pattern** — same idiom as ADR-0002: orphan `HTTPRequest`, `request_completed` connected `CONNECT_ONE_SHOT`, `call_deferred("queue_free")` after completion. No `await` in the handler path.

### 3. Auth & 401 Handling — Observer Never Force-Boots

- Main flush uses `X-Session-Token: <token>` header — the same `session_token` issued by `POST /api/session/claim` (ADR-0002; state owner `gymsys-backend`, telemetry is a **reader** only — no registry ownership change).
- **Pre-session buffering**: if no `session_token` exists yet (session not claimed), telemetry **keeps events buffered** and flushes once a token is available. It never blocks gameplay and never fabricates a token.
- **401 on telemetry flush → transient, NOT force-boot.** Unlike #2 (where 401 → GSM priority-0 force-boot), a telemetry 401 only drops the in-flight attempt, keeps the buffer, and waits for #2's session lifecycle to refresh the token. **A telemetry auth failure must never affect the gameplay session** (Rule 1 consequence). This is the single most important divergence from the #2 transport contract.
- `429` → honour `Retry-After`; `5xx` / timeout → Formula 5 exponential backoff (`min(BASE × 2^(n−1), CAP)`, telemetry knobs `TELEMETRY_FLUSH_BASE_DELAY` / `TELEMETRY_FLUSH_RETRY_CAP`). Buffer retained throughout (telemetry.md AC-09/AC-20).

### 4. Beacon Path (resolves Story 012 transport)

On `platform_detect` reporting `visibilitychange→hidden` / `pagehide`, telemetry does one best-effort synchronous flush via a new **`platform_detect` seam method**:

```gdscript
# src/autoload/platform_detect.gd — NEW seam (raw JS confined here per ADR-0001)
func send_beacon(url: String, body: String) -> bool:
    # Web: navigator.sendBeacon(url, Blob([body],{type:'application/json'})) → bool
    # Non-Web / unavailable: return false → caller uses XHR fallback (EC-18)
```

- **sendBeacon cannot set custom headers** → auth travels **in the body** (`session_token` field) to `/api/game/telemetry/beacon`. This is the engine/browser constraint that forces the separate endpoint (Decision §1).
- `send_beacon` returns `false` (unavailable / non-Web) → telemetry falls back to a synchronous best-effort `XHR` on `pagehide` (EC-18). Both are fire-and-forget; further failure is accepted loss (telemetry.md EC-02 bounds the loss to the last unflushed batch because every `workout_completed` + session boundary already flushed).
- Telemetry NEVER calls `JavaScriptBridge.eval` directly — only through this `platform_detect` seam (ADR-0001 `raw_javascript_bridge_eval` forbidden-pattern; Story 012 control-manifest rule).

### 5. Backend Schema & Dedup (resolves Q-T6)

Additive to studiosys, one new table under the `/api/game/` namespace:

```sql
CREATE TABLE game_telemetry (
    id BIGINT PRIMARY KEY AUTOINCREMENT,
    account_id VARCHAR(255) NOT NULL,
    session_id VARCHAR(64) NOT NULL,
    client_event_id BIGINT NOT NULL,
    event_name VARCHAR(64) NOT NULL,
    schema_version INT NOT NULL,
    client_ts_unix BIGINT,
    client_ts_monotonic_ms BIGINT,
    game_state VARCHAR(64),
    payload JSONB NOT NULL,
    received_at BIGINT NOT NULL,          -- server unix ms
    UNIQUE (session_id, client_event_id)  -- idempotent at-least-once dedup (Q-T6)
);
CREATE INDEX idx_game_telemetry_account_session ON game_telemetry(account_id, session_id);
```

- **Dedup key = `(session_id, client_event_id)`** (Q-T6 RESOLVED). Client guarantees at-least-once; backend `CONFLICT(session_id, client_event_id)` → ignore (no double-count). This is why the client removes events from its buffer only after a successful `200` ACK (telemetry.md Rule 6), and why a re-flushed batch (EC-12) is safe.
- **De-id defense in depth**: backend rejects any `payload` field outside the per-`event_name` frozen schema (mirror of client CI-2 / CI-3). A forbidden field (raw kg / absolute 1RM / bodyweight) on the wire → backend drops the field and logs (never stores PII even if a buggy client sends it).

### 6. Retention & Privacy (resolves Q-T7)

- **Retention** = `TELEMETRY_RETENTION_DAYS = 180` (backend knob). 180 days covers the Month-4 Pre-MVP analysis window plus a full analysis/iteration buffer. A periodic prune removes rows where `received_at < now - 180d`. (Telemetry is a transient measurement instrument — it is not a permanent player-data store.)
- **First-party only** — data lives only in the player's own GymSys backend (`game_telemetry` table on `:9120`). No egress to any third party. No external analytics SDK. This is enforced architecturally by ADR-0004 same-origin + the relative-URL forbidden-pattern (`absolute_game_api_urls`) — telemetry literally cannot POST to a foreign origin without violating an existing CI lint.
- **Player deletion** — a player may purge their telemetry (`DELETE` all rows `WHERE account_id = ?`). This is a privacy right, not a gameplay feature; the UI for it (like the opt-out toggle) belongs to the settings/login surface (#24), not to #28.
- **Opt-out (EC-17) — two layers**: (a) client `telemetry_enabled=false` → zero bytes leave the device; (b) backend honours a per-account `telemetry_opt_out` flag and drops events even if a stale client flushes. Default = enabled (first-party, premium single-player).

### Architecture Diagram

```
Telemetry autoload (boots Last, ADR-0008)        GymSys backend (/api/game/ — ADR-0004)
──────────────────────────────────────           ─────────────────────────────────────
ring buffer (Rule 5/7)
   │
   ├─ telemetry HTTP channel (5th — ISOLATED) ──► POST /api/game/telemetry
   │     X-Session-Token header                      (header auth)
   │     single in-flight, own backoff               └─ INSERT … ON CONFLICT
   │     401 → keep buffer (NO force-boot)               (session_id, client_event_id) DO NOTHING
   │                                                  ◄─ 200 {accepted, duplicates}
   │
   └─ page-hide path (Rule 12) ──────────────────► POST /api/game/telemetry/beacon
         platform_detect.send_beacon(url, body)        (token-in-body — sendBeacon has no headers)
         └─ false → XHR fallback (EC-18)            ◄─ 204
                                                        │
                                              game_telemetry table
                                              UNIQUE(session_id, client_event_id)
                                              retention 180d · first-party only · opt-out drop

      (separate from #2 GymSysBackendClient's 4-channel MAX_INFLIGHT=4 pool — never starves loot_commit)
```

### Key Interfaces

```
# Client (telemetry autoload):
#   - dedicated orphan HTTPRequest (5th channel; NOT in #2's pool)
#   - relative URLs: "/api/game/telemetry", "/api/game/telemetry/beacon"
#   - X-Session-Token header on main flush; session_token in body on beacon
#   - 401 → keep buffer, no force-boot

# platform_detect seam (NEW — raw JS confined here per ADR-0001):
#   func send_beacon(url: String, body: String) -> bool

# Backend (GymSys FastAPI, /api/game/ router):
#   POST /api/game/telemetry        (X-Session-Token header) → 200 {accepted, duplicates}
#   POST /api/game/telemetry/beacon (session_token in body)  → 204
#   table game_telemetry, UNIQUE(session_id, client_event_id)
```

## Alternatives Considered

### Alternative 1: Reuse #2 GymSysBackendClient's HTTP path for flush
- **Description**: Telemetry calls a method on #2 to enqueue a flush through #2's existing channels.
- **Pros**: One transport code path; reuses #2's retry matrix.
- **Cons**: Telemetry would share #2's `MAX_INFLIGHT_REQUESTS=4` budget and could delay a gameplay-critical `loot_commit` / `state_write`; couples a Polish-layer observer to a Foundation autoload's lifecycle; #2's 401→force-boot semantics would leak into telemetry.
- **Rejection Reason**: Violates telemetry.md Rule 1 (pure observer) at the transport layer and risks Pillar 3 (delayed loot commit). A dedicated isolated channel is the only way to keep the observer one-directional over the wire.

### Alternative 2: sendBeacon with X-Session-Token header
- **Description**: Use `navigator.sendBeacon` for all flushes and attach the auth header.
- **Pros**: One endpoint; uniform auth.
- **Cons**: **Browser API does not support custom headers on `sendBeacon`** — the header is silently dropped; the backend would see an unauthenticated request.
- **Rejection Reason**: Technically impossible. The token-in-body beacon endpoint is the standard workaround; kept on a separate endpoint so the main path stays header-authed.

### Alternative 3: Third-party analytics SaaS (e.g. self-host PostHog / external)
- **Description**: Ship events to a dedicated analytics platform.
- **Pros**: Rich dashboards out of the box; no backend schema work.
- **Cons**: Sends real-body-derived data off the player's own infrastructure to a third party; conflicts with the first-party / non-predatory positioning; adds an external SDK + origin (breaks ADR-0004 same-origin + relative-URL lint); privacy/legal surface for body data.
- **Rejection Reason**: Hard constraint in telemetry.md L18 — first-party only, no third-party SaaS, no PII egress. Dashboards are an analysis-time concern on the player's own backend.

### Alternative 4: No retention limit (keep telemetry forever)
- **Description**: Never prune `game_telemetry`.
- **Pros**: Full history.
- **Cons**: Unbounded table growth for a transient measurement instrument; weaker privacy posture (indefinite body-derived data retention).
- **Rejection Reason**: Telemetry serves a Pre-MVP gate, not a permanent record. 180 days covers the analysis window with buffer; bounded retention is the privacy-correct default.

## Consequences

### Positive
- #28 Story 011 + Story 012 are unblocked (G-TEL-5 satisfied).
- Telemetry transport is provably isolated from gameplay-critical channels (Rule 1 honoured over the wire; no `loot_commit` starvation).
- First-party-only is architecturally enforced (same-origin + relative-URL lint make foreign-origin egress impossible without tripping an existing CI gate).
- De-id is defense-in-depth (client CI-2/CI-3 + backend field rejection).
- Backend surface is minimal: one table + two endpoints, additive to studiosys.

### Negative
- One additional `HTTPRequest` node + a new `platform_detect.send_beacon` seam to maintain.
- Two endpoints (header-auth + token-in-body beacon) instead of one — a small surface duplication forced by the sendBeacon header limitation.
- GymSys backend needs a `game_telemetry` table + prune job + opt-out flag (parallel backend sprint, like ADR-0002 Phase A/B).

### Risks
- **Risk 1**: `sendBeacon` unavailable or silently fails on some mobile browsers. **Mitigation**: XHR fallback (EC-18); EC-02 bounds loss to the last unflushed batch since every `workout_completed` already flushed; accepted best-effort loss.
- **Risk 2**: token-in-body beacon is a weaker auth surface (token in request body). **Mitigation**: same-origin only (no cross-site exfil path); beacon writes are append-only de-identified events with `UNIQUE` dedup — no privilege escalation, no overwrite; separate endpoint keeps the main path header-authed.
- **Risk 3**: telemetry flush competes for bandwidth on a slow mobile connection. **Mitigation**: batched (~100 events/flush), lowest priority, single in-flight, own backoff; never blocks a frame; `429`/`5xx` backoff yields to the network.
- **Risk 4**: backend dedup key collision if `client_event_id` resets without a new `session_id`. **Mitigation**: `client_event_id` is monotonic per `session_id` (telemetry.md Rule 3/11); a new session always mints a new `session_id`; `UNIQUE(session_id, client_event_id)` is collision-safe by construction.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| telemetry.md (#28) | Rule 6 — flush model (async batch, triggers a/b/c/d, at-least-once + backend dedup) | `POST /api/game/telemetry` batch envelope; remove-on-ACK; `UNIQUE(session_id, client_event_id)` dedup |
| telemetry.md (#28) | Rule 12 + EC-18 — page-hide best-effort beacon, sendBeacon via platform_detect seam, XHR fallback | `/api/game/telemetry/beacon` token-in-body; `platform_detect.send_beacon()`; XHR fallback |
| telemetry.md (#28) | Rule 1 — pure observer, zero gameplay side-effect | dedicated isolated 5th HTTP channel; 401 keeps buffer (no force-boot) |
| telemetry.md (#28) | Rule 4 + AC-02 — de-identification | client CI-2 denylist + backend out-of-schema field rejection (defense in depth) |
| telemetry.md (#28) | Rule 14 + AC-11 — frozen schema (`loot_dropped_v1`) | per-`event_name` `schema_version`; backend validates frozen field set |
| telemetry.md (#28) | EC-17 — opt-out | client `telemetry_enabled=false` (zero bytes) + backend `telemetry_opt_out` drop |
| telemetry.md (#28) | Formula 5 — flush backoff | `429`/`5xx` → `min(BASE × 2^(n−1), CAP)` with telemetry knobs |
| telemetry.md (#28) | Q-T2/T3/T6/T7 (Open Questions) | endpoint (Q-T2), dedicated channel (Q-T3), dedup key (Q-T6), retention 180d (Q-T7) — all RESOLVED |

## Performance Implications
- **CPU**: Flush serialize + dispatch is off the gameplay hot path (FLUSHING state, async); handler stays O(1) non-blocking (telemetry.md Rule 2/AC-19). No per-frame cost.
- **Memory**: Bounded by `TELEMETRY_BUFFER_MAX` (default 2000 events) + one `HTTPRequest` node. Within the 512MB browser ceiling.
- **Load Time**: No impact — first flush fires after autoloads boot (#28 boots Last) and only on Rule 6 triggers.
- **Network**: ~100 events × ~200 bytes ≈ 20KB per flush, every 30s / workout boundary — negligible vs #2's 5s polling. Lowest priority, yields to gameplay channels.

## Migration Plan

**Client side** (new code — Story 011/012):
1. Add a dedicated orphan `HTTPRequest` telemetry channel in the telemetry autoload (ADR-0002 idiom; outside #2's pool).
2. Implement batch serialize → `POST /api/game/telemetry` with `X-Session-Token`; remove-on-ACK; Formula 5 backoff; 401 keeps buffer.
3. Add `platform_detect.send_beacon(url, body) -> bool` seam (raw JS confined per ADR-0001); telemetry calls it on page-hide with token-in-body to `/api/game/telemetry/beacon`; XHR fallback.

**Backend side** (GymSys at `\\rcprohk\docker\studiosys` — additive):
1. Add `game_telemetry` table + `idx_game_telemetry_account_session` + `UNIQUE(session_id, client_event_id)`.
2. Add `POST /api/game/telemetry` (header auth) + `POST /api/game/telemetry/beacon` (token-in-body) to the `/api/game/` APIRouter.
3. Add backend out-of-schema field rejection + `telemetry_opt_out` per-account drop + a retention prune job (`received_at < now - TELEMETRY_RETENTION_DAYS`).

## Validation Criteria
1. `POST /api/game/telemetry` with `X-Session-Token` reaches FastAPI; `200 {accepted, duplicates}`.
2. Same batch POSTed twice → second response `duplicates == N`, zero new rows (dedup on `(session_id, client_event_id)`).
3. `navigator.sendBeacon('/api/game/telemetry/beacon', blob)` fires on `pagehide`, token-in-body auth accepted; `send_beacon` returns false on non-Web → XHR fallback path exercised (EC-18).
4. 401 on telemetry flush → buffer retained, gameplay session unaffected, NO force-boot (contrast #2 behaviour).
5. Backend drops a deliberately-injected forbidden payload field (raw kg) — never stored.
6. Opt-out: `telemetry_opt_out` account → stale-client flush stored zero rows.
7. Retention prune removes rows older than `TELEMETRY_RETENTION_DAYS`.

## Related Decisions
- **ADR-0004**: CORS / Cross-Origin Topology — same-origin `/api/game/` + relative URL; makes first-party-only architecturally enforceable.
- **ADR-0002**: GymSys Integration Protocol — `X-Session-Token` auth, HTTPRequest-per-channel idiom, `session_token` source; this ADR adds a separate telemetry channel without touching #2's 4-channel pool.
- **ADR-0003**: Save State Strategy — `user://` spool (telemetry overflow durability), localStorage FORBIDDEN, private-mode DEGRADED gate.
- **ADR-0001**: Web Export Budget Caps — `raw_javascript_bridge_eval` confined to `platform_detect` (the `send_beacon` seam lives there).
- **ADR-0008**: Autoload Position Map — #28 boots Last; combat/loot signals are runtime so late boot catches all.
- **design/gdd/telemetry.md** (#28): WHAT/WHY layer this ADR implements; Open Questions Q-T2/T3/T6/T7 resolved here.
