# ADR-0004: CORS / Cross-Origin Auth Topology

## Status
**Accepted (structural) 2026-05-31** — ratified via focused partial ratification (co-ratified with ADR-0002 data contract; see `architecture-review-ratification-2026-05-31.md`). The **topology decision** — same-origin nginx reverse proxy; `/mirror-hero/` static + `/api/game/` proxy routing; `/api/game/` FastAPI APIRouter namespace; relative-URL `HTTPRequest`; `<base href="/mirror-hero/">` HTML shell; `X-Session-Token` chosen CORS-safe-by-design — is a sound architecture choice with no measurement gate and is now Accepted. The **VS-tier empirical Validation Criteria** (deployment loads at `/mirror-hero/`; `X-Session-Token` arrives at FastAPI case-insensitively; CORS preflight clean on production origin; trailing-slash redirect; COOP/COEP Q-A4 spike) **remain Provisional** pending real nginx + GymSys deployment. Tag with `(verified YYYY-MM-DD)` when deployment validation lands to mark *fully* Accepted.
*(Previously: Proposed)*

## Date
2026-05-27

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Networking (HTTP topology — browser-level; not Godot API-sensitive) |
| **Knowledge Risk** | LOW — CORS is browser-managed; Godot HTTPRequest in Web Export uses `fetch()` transparently |
| **References Consulted** | `docs/engine-reference/godot/modules/networking.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None — `HTTPRequest` + custom_headers API stable since 4.0; relative URL resolution unchanged |
| **Verification Required** | VS-tier: (1) `/mirror-hero/` subdirectory export — verify all asset paths resolve after nginx subpath routing; (2) `X-Session-Token` custom header arrives at FastAPI (browser lowercases header names — backend must match case-insensitively); (3) Trailing slash redirect for `/mirror-hero` → `/mirror-hero/` in nginx; (4) COOP/COEP headers if WASM threading enabled (Q-A4 spike) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-002 (GymSys Integration Protocol — endpoint contracts defined there; this ADR ratifies how those endpoints are reached); ADR-003 (Save State Strategy — same-origin topology makes local + backend persistence consistent) |
| **Enables** | ADR-002 Accepted status (ADR-002 was explicitly blocked pending this CORS resolution); VS-tier implementation stories for #2 GymSys Backend Client |
| **Blocks** | None (this ADR resolves the ADR-002 blocker) |
| **Ordering Note** | ADR-004 must be Accepted before ADR-002 can be Accepted. Both can be Proposed simultaneously. |

## Context

### Problem Statement
Mirror Hero (Godot 4.6 Web Export) must call GymSys backend APIs from the browser. Without a defined deployment topology, browser CORS restrictions will silently block `HTTPRequest` calls — failure is only visible in browser console, not GDScript. This ADR resolves game-concept.md Q1 ("GymSys 同 game 嘅 deployment topology 點接?") and unblocks ADR-002 Accepted status.

### Constraints
- GymSys backend (studiosys) already deployed at `\\rcprohk\docker\studiosys` — existing web UI at `https://rcprohk.com/` must be preserved
- `X-Session-Token` custom header locked by ADR-006 + ADR-002; cannot switch to Cookie-based auth
- Solo developer: minimal operational complexity required
- Web Export WASM runs in browser; Godot cannot configure CORS — only server-side configuration matters
- ADR-004 Accepted is required before ADR-002 can be Accepted

### Requirements
- Must serve game and GymSys API from the same origin (or provide CORS escape hatch)
- Must preserve studiosys existing web UI (no disruption to dance studio booking system)
- Must allow `X-Session-Token` custom header without preflight overhead
- Must work in dev (localhost) with identical architecture to production
- Must support HTTPS in production

## Decision

### Deployment Topology: Same Origin via Nginx Reverse Proxy

Game client and GymSys API share one origin (`https://rcprohk.com`), routed by nginx:

```
https://rcprohk.com/                → studiosys web UI (existing — unchanged)
https://rcprohk.com/mirror-hero/    → Godot Web Export static files (new)
https://rcprohk.com/api/game/       → GymSys backend game endpoints (new, proxy → :9120)
https://rcprohk.com/api/            → GymSys backend existing API (existing — unchanged)
```

Same-origin routing means: **zero CORS configuration required** for VS-tier. `X-Session-Token` header passes without preflight. No `Access-Control-Allow-*` headers needed on game routes.

---

### Nginx Configuration

#### Production (`/etc/nginx/conf.d/rcprohk.conf` or docker-compose nginx service)

```nginx
server {
    listen 443 ssl;
    server_name rcprohk.com;

    # TLS — managed by Let's Encrypt (Certbot or nginx-certbot docker; DevOps sprint)
    ssl_certificate     /etc/letsencrypt/live/rcprohk.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/rcprohk.com/privkey.pem;

    # Existing studiosys web UI (preserve — no change)
    location / {
        proxy_pass http://localhost:9120;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Mirror Hero game static files (Godot Web Export)
    location /mirror-hero/ {
        alias /var/www/mirror-hero/;  # Godot export output directory
        try_files $uri $uri/ /mirror-hero/index.html;
        # Trailing slash enforcement: /mirror-hero → /mirror-hero/
        # Godot WASM loads .pck/.wasm relative to index.html — co-location required

        # COOP/COEP headers (REQUIRED if Godot threading / SharedArrayBuffer enabled — Q-A4 spike)
        # Uncomment when threading is confirmed:
        # add_header Cross-Origin-Opener-Policy same-origin;
        # add_header Cross-Origin-Embedder-Policy require-corp;
    }

    # GymSys game API endpoints (proxy to FastAPI :9120 — namespace /api/game/)
    location /api/game/ {
        proxy_pass http://localhost:9120/api/game/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Session-Token $http_x_session_token;  # forward custom header
    }
}

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name rcprohk.com;
    return 301 https://$host$request_uri;
}
```

#### Development (`docker-compose.dev.yml` or local nginx)

```nginx
server {
    listen 80;
    server_name localhost;

    # studiosys web UI
    location / {
        proxy_pass http://localhost:9120;
    }

    # Mirror Hero game (Godot dev export or python -m http.server)
    location /mirror-hero/ {
        proxy_pass http://localhost:8060/;  # Godot export dev server port
        proxy_set_header Host $host;
    }

    # GymSys game API
    location /api/game/ {
        proxy_pass http://localhost:9120/api/game/;
        proxy_set_header Host $host;
        proxy_set_header X-Session-Token $http_x_session_token;
    }
}
```

---

### Godot Web Export Configuration (TD must-fix #1)

Godot Web Export served from a subdirectory requires a `<base>` tag in the HTML shell for correct asset resolution.

**Custom HTML Shell** (`res://export/web_template.html`):
```html
<head>
    <meta charset="UTF-8">
    <base href="/mirror-hero/">  <!-- CRITICAL: without this, .pck/.wasm paths 404 at subpath -->
    ...Godot-generated script tags...
</head>
```

**Export Preset** (Project → Export → Web → HTML):
- Set "Custom HTML Shell" to `res://export/web_template.html`
- Ensure all exported files (`.html`, `.js`, `.wasm`, `.pck`, `.worker.js`) are in same directory

**Note**: Godot `HTTPRequest` should use **relative URLs** to remain portable across dev/prod:
```gdscript
# Recommended:
req.request("/api/game/state?last_event_id=" + str(cursor))

# Not recommended (hard-coded domain breaks dev ↔ prod parity):
req.request("https://rcprohk.com/api/game/state?last_event_id=" + str(cursor))
```

---

### GymSys API Namespace Rule (TD must-fix #2)

All Mirror Hero game endpoints in GymSys FastAPI MUST use `/api/game/` prefix:

```python
# studiosys/server/main.py — add this router
game_router = APIRouter(prefix="/api/game", tags=["mirror-hero-game"])

# Game endpoints mount under /api/game/
@game_router.get("/state")               # → GET /api/game/state
@game_router.post("/session/claim")      # → POST /api/game/session/claim
@game_router.post("/lootdrop/{id}/cache") # → POST /api/game/lootdrop/...
```

**FORBIDDEN**: Mirror Hero endpoints MUST NOT use studiosys existing namespaces:
- `/api/students/` — studiosys student management
- `/api/classes/` — studiosys class booking
- `/api/bookings/` — studiosys bookings
- `/api/company/` — studiosys company settings

This is a hard constraint, not just a convention. Violations cause endpoint routing conflicts and silent misdirected requests.

---

### Migration Path: If GymSys Relocates (TD must-fix #3)

If GymSys backend moves to a different server/origin in the future (e.g., cloud migration), the same-origin topology breaks. Fallback procedure:

1. GymSys adds FastAPI CORS middleware:
```python
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(CORSMiddleware,
    allow_origins=["https://rcprohk.com/mirror-hero", "http://localhost:8060"],
    allow_credentials=True,
    allow_headers=["X-Session-Token", "X-Transition-Id", "Content-Type"],
    allow_methods=["GET", "POST", "OPTIONS"],
)
```

2. Game client switches from relative to absolute URLs for the new GymSys origin
3. HTTPS required on both origins for `credentials: include` to work (SameSite cookie policies)

**X-Session-Token is CORS-safe** — it was deliberately chosen as a custom header (not Cookie) to survive cross-origin scenarios without SameSite restrictions. Only backend CORS config change needed; no client-side auth changes.

---

### Architecture Diagram

```
Browser (https://rcprohk.com)
         │
         ▼
    nginx (443 TLS / 80 dev)
         │
    ┌────┴─────────────────────┐
    │  URL routing (same origin)│
    └────┬─────────────────────┘
         │
    ┌────┼──────────────────────────┐
    ▼    ▼                          ▼
 /       /mirror-hero/          /api/game/
studiosys Godot Web Export     GymSys FastAPI
(port    (static files from    /api/game/* router
 9120)    /var/www/mirror-hero) (port 9120)
```

### Key Interfaces

```
# Same-origin means:
# - HTTPRequest uses relative URLs
# - No Access-Control-* headers needed
# - X-Session-Token header arrives at FastAPI case-insensitively

# Required nginx: proxy_set_header X-Session-Token $http_x_session_token
# Required Godot: HTTPRequest with header ["X-Session-Token: " + session_token]
# Required FastAPI: APIRouter(prefix="/api/game")
# Required Godot HTML Shell: <base href="/mirror-hero/">
```

## Alternatives Considered

### Alternative 1: Cross-Origin (game CDN + GymSys CORS middleware)
- **Description**: Game hosted on itch.io or separate CDN; GymSys adds CORS middleware
- **Pros**: Game distribution via itch.io ecosystem; GymSys stays untouched
- **Cons**: CORS preflight on every POST (performance overhead); `Access-Control-Allow-Credentials: true` requires specific origin (not `*`); HTTPS required on both origins; studiosys existing session-cookie auth uses `SameSite=Strict` which blocks cross-site requests — would need separate cookie policy
- **Rejection Reason**: Same-origin via nginx is simpler, faster, and requires no backend CORS changes for VS-tier. Cross-origin migration path is documented as fallback.

### Alternative 2: Iframe Embed (game inside studiosys page)
- **Description**: studiosys serves Mirror Hero inside an `<iframe>`; postMessage for communication
- **Pros**: Zero new infrastructure; both on same origin automatically
- **Cons**: iframe limits full-screen game; postMessage adds communication complexity; GymSys session-cookie bleeds into game context; full-viewport Web Export experience degraded
- **Rejection Reason**: User experience severely compromised; WASM game in iframe has additional sandbox restrictions.

### Alternative 3: Separate subdomain (game.rcprohk.com)
- **Description**: Game on `game.rcprohk.com`; GymSys API on `rcprohk.com`
- **Pros**: Clean URL separation
- **Cons**: Different origin → back to CORS problem; subdomain CORS with credentials requires `Access-Control-Allow-Origin: https://game.rcprohk.com` (specific, not wildcard); more complex nginx + TLS config for two domains
- **Rejection Reason**: Same-domain path routing achieves equivalent URL clarity without CORS overhead.

## Consequences

### Positive
- ADR-002 Accepted is now unblocked
- Zero CORS configuration on GymSys for VS-tier — no backend changes needed for X-Session-Token
- Dev/prod architecture parity (both use nginx + same route rules)
- Relative URL usage in Godot HTTPRequest makes game portable to any proxy origin
- X-Session-Token chosen correctly for cross-origin escape hatch (does not require SameSite cookie workarounds)

### Negative
- nginx added to deployment stack (new operational dependency alongside studiosys Docker)
- Godot Web Export requires custom HTML shell for `/mirror-hero/` subpath serving
- GymSys backend must use `/api/game/` APIRouter prefix (one-time refactor, low effort)
- Let's Encrypt TLS automation needed for production (deferred to DevOps sprint)

### Risks
- **Risk 1**: Godot export assets (`.pck`/`.wasm`) fail to load at `/mirror-hero/` subpath without `<base>` tag. **Mitigation**: Custom HTML shell + VS-tier deployment test
- **Risk 2**: GymSys namespace collision if developer forgets `/api/game/` prefix. **Mitigation**: FastAPI `APIRouter(prefix="/api/game")` enforces at Python level; lint rule as future enforcement
- **Risk 3**: COOP/COEP headers required if Godot 4.6 WASM threading enabled (Q-A4 spike). **Mitigation**: nginx config includes commented COOP/COEP headers ready to uncomment; threading not used in VS-tier
- **Risk 4**: nginx misconfiguration (missing trailing slash on `/mirror-hero/`) causes 301 redirect loop. **Mitigation**: `location /mirror-hero/ {}` with `try_files` is standard nginx pattern; test with `/mirror-hero` (no slash) request

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| gymsys-backend-client.md (#2) | All 13 poll/session/lootdrop/state-write HTTP requests must reach GymSys origin | Same-origin proxy ensures all requests succeed; no CORS preflight overhead on polling |
| gymsys-backend-client.md (#2) | `X-Session-Token` header on all authenticated requests (ADR-006 lock) | Same-origin: no CORS restriction on custom headers; FastAPI receives header case-insensitively |
| game-state-machine.md (#1) | ADR-002 session claim + LootDrop commit must be reachable | Nginx `/api/game/` proxy route to GymSys:9120 enables all ADR-002 endpoints |

## Performance Implications
- **CPU**: Nginx proxy add <1ms per request (TCP loopback, no TLS overhead between nginx and FastAPI)
- **Memory**: Nginx adds ~5MB RAM at idle (negligible)
- **Load Time**: Same-origin eliminates CORS preflight OPTIONS request (~50-100ms saving per POST)
- **Network**: TLS termination at nginx (not FastAPI) — standard pattern, no overhead change

## Migration Plan

**Game client side**: 
1. Create custom HTML shell with `<base href="/mirror-hero/">`
2. Switch all `HTTPRequest` to relative URLs (`"/api/game/..."`)
3. Export game to `/var/www/mirror-hero/` or equivalent static directory

**GymSys backend side (studiosys repo)**:
1. Add `APIRouter(prefix="/api/game")` for all Mirror Hero endpoints
2. Mount router in `server/main.py` alongside existing routers
3. No CORS middleware changes needed for VS-tier (same-origin)

**Infrastructure side**:
1. Add nginx service to studiosys `docker-compose.yml` (or create `docker-compose.override.yml`)
2. Configure nginx routes per spec above
3. DevOps sprint: Let's Encrypt certbot auto-renewal in nginx service

## Validation Criteria
1. `GET https://rcprohk.com/mirror-hero/` loads Godot game (not 404)
2. `GET https://rcprohk.com/api/game/state` reaches FastAPI (200 or expected error, not 404/CORS error)
3. `POST https://rcprohk.com/api/game/session/claim` with `X-Session-Token` header — header arrives at FastAPI; no CORS preflight error in browser console
4. `GET https://rcprohk.com/` still serves studiosys web UI (existing functionality preserved)
5. Godot game at `/mirror-hero/` loads `.pck` correctly (no 404 on assets)
6. Dev: `http://localhost/mirror-hero/` + `http://localhost/api/game/state` both work with localhost nginx

## Related Decisions
- **ADR-002**: GymSys Integration Protocol — endpoint contracts; this ADR makes them reachable; ADR-002 Accepted now unblocked
- **ADR-003**: Save State Strategy — same-origin ensures `user://` (IndexedDB) and backend writes are on consistent origin
- **ADR-001**: Web Export Budget Caps — nginx serves Godot export; COOP/COEP headers may be needed if WASM threading enabled (Q-A4)
- **game-concept.md Q1** (resolved): "GymSys 同 game 嘅 deployment topology 點接?" → Answer: same origin via nginx reverse proxy
