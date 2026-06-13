# GymSys Integration Plan (Keystone)

> **Created**: 2026-06-13 (after VS-1 Milestone-1 desk-pass PROCEED → keystone investigation)
> **Status**: ✅ **Phase 1 (Option B) DONE + LIVE-VALIDATED 2026-06-13** — see Result below. Phase 2 (Option A live per-set) deferred.

## ✅ Result (2026-06-13) — Option B working end-to-end against live GYM
Proven: real GYM workout → real #2 client → ADR-0002 signal stream → WST → game loop.
- **Backend**: `GET /api/game/feed?since=<ms>` on GYM (FastAPI). curl round-trip verified:
  register → login → POST workout → feed returns correct projection (`exercise_id`, sets) +
  differential cursor (since=cursor → count 0, idempotent). GYM pytest 6 passed.
- **Client** (`src/autoload/gym_sys_backend_client.gd`): `login()` (POST /api/login → captures
  session cookie from Set-Cookie) + poll `/api/game/feed` + replay each workout as
  workout_started→set_logged×N→workout_completed. Live harness
  `prototypes/vertical-slice/GymsysLiveCheck.tscn` logged into the running GYM and emitted the
  seeded workout's signals (deadlift→CONTROL, overhead_press→STRIKE) end-to-end.
- **WST wired**: `workout_state_tracker.gd` binds `_gym_sys_client = GymSysBackendClient` at boot
  (IDLE until login). Full combined gate 441scr/2975/0 fail — zero regression.

### ⚠️ Two findings that bit us (record for the real deploy)
1. **GYM runs on `http://127.0.0.1:8090` (HTTP), NOT 9100/HTTPS.** (9100 = nothing listening.)
2. **Godot native HTTPRequest must use `127.0.0.1`, NOT `localhost`** — GYM binds IPv4 (`0.0.0.0`);
   Godot resolves `localhost`→`::1` (IPv6) and the request hangs (request_completed never fires).
   curl falls back to IPv4; Godot does not. Use the dotted IPv4 literal (or bind GYM on `::`).

### Remaining (final live wiring + deploy)
- Decide WHERE the game calls `GymSysBackendClient.login(base_url, user, pass)` — natural home is
  the Login/Shell screen (#24). For desktop dev: `http://127.0.0.1:8090`.
- **Web export CORS** (ADR-0004): a browser build calling GYM cross-origin needs nginx same-origin
  proxy (`/api/game/` → GYM) OR CORS headers on GYM. Desktop native has no CORS (proven working).

---

(original plan below)

> **Governing**: ADR-0002 (integration protocol), ADR-0004 (CORS/nginx topology)

## Investigation finding (ground truth)

The GymSys backend lives at `C:\Users\frank\Desktop\GYM` — **FastAPI + Uvicorn**, session-cookie auth.
It already has workout data + API:

- `GET /api/workouts`, `/api/workouts/{wid}`, `/api/workouts/calendar`, `/api/workouts/volume`
- `POST /api/workouts` — **saves a COMPLETE workout blob** (`{id, date, exercises:[{sets:[{weight,reps}]}]}`)
- `GET /api/exercises`, auth via `/api/session` `/api/login` `current_user`

**Critical gap**: GYM has **NO live per-set logging**, **NO in-progress/active-workout concept**, and
**NO `/api/game/*` event feed**. A workout is persisted as one blob (saved by the frontend, effectively
at/after completion). `grep` for `in_progress|active_workout|set_logged|log_set|/api/.*set` → nothing.

## Why this matters (the real decision)

The game's #2 `GymSysBackendClient` (a deliberate stub today) + ADR-0002 assume a **real-time event
stream**: `workout_started` → `set_logged` (per set, AS the user does it) → `rest_started/ended` →
`workout_completed`, polled via a differential cursor. That stream is what powers the **Pillar 2 mid-set
glance** (you do a set, glance at your phone, the game already reacted) and **Pillar 1** (real sets drive
the avatar live).

**GYM does not produce that stream today.** It only knows about completed workouts. So the keystone is a
**product/architecture fork**, not just plumbing:

### Option A — Live workout session (full vision, Pillar 2 as designed)
Add a live-session feature to GYM:
- `POST /api/game/session/claim` → `X-Session-Token` (ADR-0002 session lock)
- workout-logging UI writes each set LIVE → backend appends events to a per-user event log
- `GET /api/game/events?cursor=N` → differential events since cursor (workout_started / set_logged /
  rest_* / workout_completed), `server_epoch_id` for cursor safety (ADR-0002)
- game polls every 5s ±jitter (ADR-0002), derives class/stats/loot live
- **Pros**: delivers the actual core fantasy (mid-set reactivity, live avatar). **Cons**: real new feature
  on your LIVE GYM system (UI + backend + storage); biggest scope; must not break existing GYM workflows.

### Option B — Post-workout reaction (pragmatic MVP, simpler)
Game reacts to **completed** workouts only:
- `GET /api/game/feed?since=<ts>` → workouts saved since last poll (thin read over existing `/api/workouts`)
- on a newly-saved workout → run the whole loop once (class from exercises, loot, avatar evolution)
- **Pros**: minimal GYM change (one read endpoint, no UI change, no live logging); low risk to GYM.
  **Cons**: NO mid-set glance — the Pillar 2 「做緊 set 偷望」hypothesis is NOT delivered/tested; the game
  becomes "open it after your workout → see your rewards" (still valid, but a different feel).

## Recommendation

**Phase 1 = Option B** (prove the end-to-end real-data loop cheaply + safely against the live GYM, no
risk to existing workflows), **then Phase 2 = Option A** if the post-workout loop validates and you want
the mid-set magic. This de-risks touching the production GYM system and gets real workout data driving the
game fastest.

## First concrete step (either path)

1. **CORS/topology** (ADR-0004): decide deploy shape — nginx same-origin proxy (`/mirror-hero/` static +
   `/api/game/` → GYM) vs dev-time direct with CORS headers. (No nginx config exists yet in either repo.)
2. **Backend**: add a `game_api.py` APIRouter on GYM mounted at `/api/game` (Option B: one `feed` endpoint
   first).
3. **Game #2 client**: implement `src/autoload/gym_sys_backend_client.gd` real HTTP (replaces stub) —
   `HTTPRequest` poll + session token header + emit the locked workout signals WST already consumes
   (the VS-1 harness proved WST→loop wiring works off these exact signals via the FakeGymSysClient).

## Open questions for frank
- **A or B for Phase 1?** (recommend B)
- GYM deploy: where does GYM run for the game to reach it? (localhost dev first? Docker? the `\\rcprohk`
  host?) — determines CORS/topology.
- Are you OK with me adding a **read-only** `/api/game/feed` endpoint to the live GYM `main.py` (Option B,
  non-invasive — does not touch existing routes/data)?

> ⚠️ This modifies a SEPARATE live production system (GYM). Best done in a fresh focused session with the
> path decided. Logged in `production/risk-register/external-gates.md` Line A.
