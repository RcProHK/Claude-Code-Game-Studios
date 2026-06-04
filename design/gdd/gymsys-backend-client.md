# GymSys Backend Client

> **Status**: APPROVED 2026-05-26 — Pass 2 lean re-review (0 blocking; 4 advisory resolved: AC-28 count corrected 13→18, 3 undeclared signals added, Rule 11.1 latch-200 clarified, 429+Draining edge case added)
> **Author**: Frank + systems-designer + network-programmer + godot-specialist + creative-director + qa-lead
> **Last Updated**: 2026-05-26 (P0 revision pass)
> **Implements Pillar**: Pillar 2 (Frictionless Companion — invisible reliable polling + non-blocking logout drain per P0-4) + Pillar 3 (Drop Euphoria — backend-cached LootDrop survives crash / device handoff per Decision #4; tombstone Set dedupe per P0-2) + Pillar 1 (Real Body, Real Power — workout data sole source of truth + confused-deputy defense P0-6 + schema-drift fail-loud P0-7)
> **System #**: 2 (Foundation / VS tier)
> **Depends On**: (none)
> **Depended On By**: #1 GameStateMachine (★ hard, Decision #3/#4 contract obligations), #3 PersistenceLayer, #9 Workout State Tracker, #18 PR Detection, #24 Login UI (★ added: non-blocking drain UI binding per P0-4 + carve-out misconfig prompt per P0-6 + update-required prompt per P0-7), #27 Onboarding Flow (indirect), #31 SSE/Realtime Upgrade (v0.2)
> **Governing ADRs**: ADR-006 State Machine Contract (RATIFIED 2026-05-25, Status: Proposed) — inherits Contracts 2 (transition_id format), 4 (autoload ordering), 5 (call_deferred idiom), 11 (best-effort IDB), 15 (server-authoritative pending_since). ADR-002 GymSys integration protocol (to be authored from this GDD; **expanded scope per design-review: CD-CASCADE-A non-blocking drain UX, CD-CASCADE-B schema versioning REMOVE semantics, CD-CASCADE-C UNIQUE constraint composite key on (transition_id, account_id)**).
> **Creative Director Review (CD-GDD-ALIGN)**: REJECT 2026-05-26 (re-opened from prior CONCERNS) → revised same session → pending lean re-review。Prior CONCERNS verdict missed: Rule 15 FIFO double-ritual (Pillar 3); AC-18 client-owned blocking drain (Pillar 2); knob safe range self-contradiction; FSM matrix incomplete; broken JavaScriptBridge probe API premise; missing confused-deputy defense; X-Protocol-Version REMOVE-field silent corruption. All 7 P0 items addressed via surgical revision pass 2026-05-26。3 new cascades flagged to ADR-002 ratification gate (CD-CASCADE-A/B/C above)。Designer Top 5 fix-now items completed per CD triage。

## Overview

GymSys Backend Client 係 Mirror Hero 同 GymSys backend (deployed at `\\rcprohk\docker\studiosys`) 之間嘅唯一接觸層 —— 一個 HTTP REST client + signal-emitter，封住所有 network I/O、session 管理、retry policy 同 idempotent state writes。佢嘅職責有四：(1) 用 `GYMSYS_POLL_INTERVAL_SECONDS = 5.0` cadence poll `/api/game/state` 取 workout data（`workout_started` / `set_logged` / `rest_started(duration_seconds)` / `rest_ended` / `workout_completed` / `poll_failed` / `poll_recovered` 七個 signal — Decision #3 鎖死 7-signal contract，legacy `exercise_switched` 由 backend 繼續 emit 但 client 唔再 forward）；(2) 為 GameStateMachine 嘅 dual-target write (Rule 2 step 6) 提供 fire-and-forget POST helper —— 包括 state transition POST 同 LootDrop cache POST，全部帶 `transition_id` header (ADR-006 Contract 2 opaque format) 同 `X-Session-Token` header (Decision #4 single-device lock)；(3) 收到 HTTP 401 即 emit `session_invalidated()` signal 畀 GameStateMachine 處理 force-boot policy（per GDD #1 Rule 5 priority 0 + B3 active-state deferral），唔自行決定 transition；(4) 喺 `Disconnected` state 用 `retry_delay(n) = min(BASE_DELAY × 2^(n-1), RETRY_CAP)` formula（由 #1 owned、由我哋 execute）做 exponential backoff reconnect。系統嚴格 stateless from gameplay perspective —— 唔 cache workout interpretation、唔 derive game state、唔 own player progression；佢只 emit normalised events 同 forward backend responses。所有 contract 細節（endpoint shapes、transition_id UNIQUE constraint、session API、LootDrop cache/commit endpoints）將喺 **ADR-002 GymSys Integration Protocol** lock 死，本 GDD 屬 ADR-002 嘅 input scope；**ADR-006 Contracts 2/4/5/11/15** 已 ratified 並 binding 本 GDD prose。

## Player Fantasy

**Direct fantasy**: None — GymSys Backend Client 係 infrastructure，玩家唔會 *feel* 個 HTTP client 本身。

**Indirect fantasy — Backend 唔識講大話 (Anti-Cheat Ground Truth as Earned Power)**:
玩家心入面嘅 felt promise：「我 avatar 嗰把劍嘅每一點 attack power，都係我 gym record 入面有 row 對應住。冇得呃，所以呢個 power 真係屬於我。」呢個 fantasy 唔係由 GymSys Client emit 任何 visual / audio cue 表達，而係由佢嘅 **architectural posture** 強制 —— server-authoritative LootDrop（per ADR-006 Contract 15 + Decision #4 LootDrop cache endpoint），idempotent commit via `transition_id` UNIQUE constraint（per Contract 2），client 永遠唔可以單方面「製造」power、亦永遠唔可以 silently rollback player 已 earned 嘅 stat。

呢個 indirect fantasy 直接 enables：
- **Pillar 1 (Real Body, Real Power)** — 呢個係 Pillar 1 嘅 *technical embodiment*。Server-side 係 source of truth；client 嘅角色純粹係 trusted messenger，唔係 power-grant authority。Player 潛意識知道呢樣野，所以 avatar 嘅每一格進步先有 weight。
- **Pillar 5 (Mirror Moment)** — 截圖嗰一刻 player 心入面講嘅嗰句「呢個係我」，前提係佢相信冇任何一格 stat 係 client-side fabricated。GymSys Client 嘅 anti-fabrication posture 喺架構層 underwrite 呢個 belief。

與 #1 GameStateMachine 「invisible reliability + transparent device handoff」嘅關係：#1 講「state 跨 device 跨 session 永遠連貫」；#2 講「跨 device 跨 session 嘅 state 全部 traceable to backend write，client 唔造假亦唔被造假所騙」。兩個 fantasy 互補但唔重疊 —— #1 係 continuity，#2 係 authenticity。

**Falsifiable design test**: 任何 client-side path 引致以下情境 = bug，唔係 acceptable behavior:
1. 玩家發現 disconnect 期間 client 自己「估」咗 EXP，reconnect 後 rollback（optimistic UI undo）→ 信任崩潰
2. 同一 `transition_id` 重複 POST 喺 server-side dedupe 失敗，產生雙倍 LootDrop → exploit 開放
3. 玩家可以 modify client storage 增加 stat 而 backend 唔知 → Pillar 1 anti-pillar #1（NOT 氪金/in-game shortcut）violated 至最底層

### Fantasy Risk Register (added 2026-05-26 per design-review game-designer P1-1)

呢個 indirect fantasy 嘅 "architectural posture" framing 係 elegant but contingent — 以下三個 ADR-002 clauses 真正 deliver 嘅 invariants 必須喺 ADR-002 ratification gate 鎖死，否則 Player Fantasy paragraph 變 retroactive lie：

| # | Contingent Invariant | Owner | Fallback if Dropped |
|---|---------------------|-------|---------------------|
| FR-1 | Backend `transition_id` UNIQUE constraint enforced on lootdrop_commit + state_write tables (or composite `(transition_id, account_id)` per CD-CASCADE-C) | ADR-002 + GymSys schema migration | Fantasy framing degrades to "client tries idempotence + monitor exploits via #28 Telemetry" — accept Pillar 1 risk explicitly |
| FR-2 | Server-authoritative LootDrop commit semantics (client commit POST always returns canonical inventory; client cannot fabricate canonical state) | ADR-002 endpoint shapes | Fantasy framing degrades to "client-side anti-tampering checksum on payload" — weaker promise, post-MVP scope |
| FR-3 | Schema versioning policy: required-field REMOVE = MAJOR bump + `410 Gone` deprecation (CD-CASCADE-B per P0-7) | ADR-002 schema versioning section | Without this, REMOVE drift causes silent Pillar 1 data loss — fall back to client refuses to operate when MAX_KNOWN_VERSION exceeded |

**Ratification gate binding**: ADR-002 review MUST verify backend implementation satisfies all 3 invariants before Status: Accepted。若 ADR-002 lands without one of FR-1/FR-2/FR-3 → revisit this Player Fantasy paragraph with the corresponding fallback framing。

## Detailed Design

GymSys Backend Client 係 HTTP REST 嘅 wrapper + signal-emitter，封住所有 network I/O。本 GDD 訂明 client 嘅內部行為；endpoint shape / payload schema / backend protocol 細節 escalate 到 **ADR-002 GymSys Integration Protocol**（pending authoring）。本 GDD 屬 ADR-002 嘅 input scope。

### Core Rules

**Rule 1 — Polling cadence + lifecycle suppression.**
Client 用 `GYMSYS_POLL_INTERVAL_SECONDS = 5.0` 嘅 timer 喺 `Polling` substate fire `GET /api/game/state`。Client 訂閱 GameStateMachine 嘅 `state_changed`，喺 `to == Suspended` pause 內部 timer，喺 from-Suspended 嘅 `state_changed` (any non-Suspended new state) 即時 fire 一個 poll，跟住 resume timer cadence。**唔自行 register `pagehide` JS callback** —— piggyback #1 嘅 existing handler，避免兩個 listener 嘅 ordering nondeterminism。**Rule 1 binding**: client implementation `_register_lifecycle_listeners()` 必須 zero JavaScriptBridge calls；唯一 lifecycle source = GameStateMachine signals。

**Rule 2 — Single-flight poll.**
Polling channel size = 1。下個 poll tick fire 時若 prior poll request 仍 inflight → silently skip (no queueing, no stale-replay)。Skip 觸發 `dropped_poll_tick(reason: "prior_inflight")` signal 畀 test observability。理由：3G cellular 上偶然 RTT > 5s 會引致 response ordering inversion（舊 `set_logged` 過晚到達覆蓋新 state）→ Pillar 1 / Pillar 3 silent corruption。Single-flight 保證 server response stream 嚴格 monotonic。

**Rule 3 — Multi-channel inflight cap + priority.**
Client 維持四個 logical channels：

| Channel | Inflight cap | Queue policy | Priority |
|---------|--------------|--------------|----------|
| `poll` | 1 | skip-on-busy (Rule 2) | 4 (lowest) |
| `state_write` | 4 | FIFO, no-drop | 3 |
| `loot_cache` | 4 | FIFO, no-drop | 2 |
| `loot_commit` | 2 | FIFO, no-drop | **1 (highest)** |

全局 inflight cap `MAX_INFLIGHT_REQUESTS = 4`。超過 cap 時新 enqueue 嘅 request 按 priority + FIFO 等位；poll channel 永遠 skip 唔等位。**Loot commit 永遠優先 over loot cache 同 state write** — 玩家已 tap dismiss 嘅 LootDrop 必須最快 reach backend (Pillar 3 hard guarantee)。

**Rule 4 — Orphan HTTPRequest dispatch pattern (Godot 4.6 Web Export).**
每個 request 用一個 ephemeral `HTTPRequest` Node：
1. `var http := HTTPRequest.new()` (typed local var — avoids 4.5 variadic-args ambiguity)
2. `http.timeout = REQUEST_TIMEOUT_SECONDS` (per channel — `poll` 用 `POLL_TIMEOUT_SECONDS = 4.0`，其餘用 `WRITE_TIMEOUT_SECONDS = 10.0`)
3. `http.request_completed.connect(_on_request_completed.bind(http, channel_id, transition_id), CONNECT_ONE_SHOT)`
4. `add_child(http)` → `http.request(url, headers, method, body_string)`
5. Handler `_on_request_completed`: capture response → `get_tree().process_frame.connect(func(): _dispatch_response(...), CONNECT_ONE_SHOT)` (per ADR-006 Contract 5) → `http.queue_free()` (NOT `call_deferred("queue_free")` — `queue_free` 已 deferred; double-defer = code smell)

**Rule 4 binding**: handler MUST target `self` (the GymSys Client autoload), never the freed orphan node. Static analyzer scope addition (proposed for ADR-002) scans this pattern.

**Rule 5 — Strong-typed signal normalization (no raw Dict emit).**
Backend response (Dictionary) 由 private `_normalize_*` functions 轉成 typed signal payload。一個 signal 一個 normalize function。Schema validation lives in one place — backend response shape drift 只觸動 normalize function。Locked 7 workout signals (per Decision #3 + GDD #1) + 6 NEW auxiliary signals (this GDD):

```gdscript
# Locked 7 (consumed by #9 Workout State Tracker)
signal workout_started()
signal set_logged(exercise_id: String, reps: int, weight: float)
signal rest_started(duration_seconds: int)
signal rest_ended()
signal workout_completed(completed_at: int)              # unix timestamp from server
signal poll_failed(category: PollFailureCategory)        # transport classification
signal poll_recovered()

# NEW (this GDD) — auxiliary signals NOT in GDD #1's lock list but needed for downstream
signal session_invalidated()                              # propagated to #1 per Decision #4
signal auth_required()                                    # initial empty token OR claim exhausted
signal lootdrop_cache_fetched(transition_id: String, payload: Dictionary, pending_since_server: int)
signal dropped_poll_tick(reason: String)                  # Rule 2 observability
signal protocol_error(transition_id: String, reason: String)  # 4xx client bug surface (Rule 12 matrix)
signal lootdrop_committed(transition_id: String, canonical_inventory: Dictionary)  # 200 response; gated by Rule 15

# NEW 2026-05-26 (design-review P0-4) — non-blocking logout drain signals
signal drain_started(pending_commits: int)                # USER_EXPLICIT logout entry → #24 non-modal banner
signal drain_completed(committed_count: int, timeout_count: int)  # all inflight commits resolved or timed out

# FSM observability signals (internal — test-seam + telemetry-class)
signal substate_changed(from: String, to: String)         # every legal substate transition; test-seam
signal dropped_event(from: String, to: String, reason: String)  # illegal FSM transition attempt (— cells in 6×6 matrix)
signal drain_in_progress(rejected_tid: String)            # TELEMETRY-CLASS — new commit enqueue rejected during Draining
```

**ClearTokenReason enum** (Rule 6 / Edge Cases logout flow):
```gdscript
enum ClearTokenReason {
    USER_EXPLICIT,   # player Settings → Logout — drain commits in background
    SESSION_KILLED,  # Rule 11 401 latch — no drain, token already invalid
}
```

**Telemetry-class signals (UI binding forbidden — added 2026-05-26 per design-review P1-3 game-designer)**: Signals `protocol_error`, `dropped_poll_tick`, `session_evicted_by_browser`, `persistence_volatile`, `inflight_cap_breached`, `logout_drain_timeout` (deprecated — replaced by `drain_completed`), `tombstones_trimmed`, `persistence_quota_exhausted`, `drain_in_progress`, `dropped_event` 屬 **TELEMETRY-CLASS** — UI consumers (#20 HUD, #24 Login UI, anything in `src/ui/`) MUST NOT subscribe to these signals。Only `src/core/networking/telemetry_router.gd` (or equivalent #28 Telemetry consumer) 可以 subscribe。**`substate_changed` 屬 TEST-SEAM ONLY** — only `tests/` may subscribe; UI and production game code MUST NOT。**CI static check** `tools/ci/check_no_ui_subscribes_telemetry.sh` enforces this — greps `src/ui/**/*.gd` for the 11 forbidden signal names (10 telemetry-class + `substate_changed`)。

**Why strong types**: #9 Workout State Tracker consume these directly. Raw Dict emit 等於每個 consumer 重做一次 parsing → drift accumulates。Typed signatures enable signal-contract test (analogous to GDD #1 AC-15 pattern)。

**Rule 6 — Session token storage path.**
Session token 持久化喺 `user://state.json` 嘅 `session_token: String` key，經 `PersistenceLayer.write("session_token", token)`。**Client 唔直接 call `FileAccess`** — 所有 IO 經 `IPersistence` interface (per GDD #1 dependency contract)。Token 唔加密；same-origin browser sandbox isolation 已 sufficient for VS tier; production cert + HTTPS-only enforce by ADR-002 + ADR-004。

Client `IPersistence` keys (canonical list, full enumeration for #3 PersistenceLayer reciprocity):
- `session_token: String` — auth token (Rule 6 + 7)
- `_committed_tombstones: Dictionary[String, int]` — Rule 15 commit dedupe set (key=`<tid>:loot-commit`, value=`committed_at` unix ts)
- `_last_known_state: String` — Rule 14 Suspended cleanup persist (idle / workout_active / etc — server response cache marker)

**In-memory only** (NOT persisted — reset on autoload `_ready` / bfcache reload):
- `_session_epoch: int` — Rule 11/Edge Cases stale-response filter epoch counter (incremented on every `set_session_token(new)` where new != current; init = 0 in `_ready()`); request tagging in dispatch helper
- `_token_invalidated_latched: bool` — Rule 11 401-burst dedupe latch
- `_inflight_requests: Dictionary[String, HTTPRequest]` — Rule 4 dispatch tracking

**Rule 7 — AwaitingAuth substate at boot.**
Autoload `_ready()` 完成 PersistenceLayer 讀取後立即 inspect `session_token`：若 empty / missing → 入 `AwaitingAuth` substate，**`Polling` timer 唔 start**；emit `auth_required()` signal 通知 #24 Login UI 接管。Client 等待 `set_session_token(token: String)` API call (由 #24 通過 `claim_session(...)` 流程提供) → 轉入 `Polling` substate → fire 即時 poll。**Rule 7 防 boot 401 storm**：若 client 喺空 token 狀態 fire poll，每個 poll 都會 immediate 401 → 觸發 `session_invalidated()` → 進入 force-boot loop。

**Rule 8 — Header presence + casing discipline + confused-deputy defense.**
每個 authenticated outbound request 必須帶兩個 headers：
- `X-Session-Token: <token>` (canonical lowercase `x-session-token` — Starlette case-insensitive but document canonical to aid greppability)
- `X-Protocol-Version: 1` (默認 `1` for VS tier；數值 lock 喺 ADR-002 ratification 時)

State-affecting POST 另加：
- `X-Transition-Id: <opaque_string>` (per ADR-006 Contract 2 + Rule 9 below)

**Rule 8.1 — Confused-deputy response defense (NEW 2026-05-26 per design-review P0-6 network-programmer).**
On every authenticated POST response, client MUST inspect response headers for `Set-Cookie`. If `Set-Cookie` present AND outbound request carried `X-Session-Token` → studiosys cookie-middleware carve-out (Q-N2) is misconfigured；request was BOTH cookie-authenticated AND token-authenticated → **confused-deputy attack surface**。Action: (1) **REFUSE to persist any state from this response** — handler treats response as protocol_error not success; (2) emit `protocol_error("server_reflected_cookie_auth", endpoint_path)`; (3) emit `auth_required()` (force re-claim to ensure clean session); (4) latch `_carve_out_misconfig_detected: bool = true` (in-memory) — subsequent requests still go out, but state writes refused until `_carve_out_misconfig_detected` cleared by explicit `client.acknowledge_carve_out_fix()` admin API (manual recovery, not automatic — operator must verify deployment fixed)。**Rationale**: Browser auto-attaches studiosys session cookie on same-origin even when client only `set X-Session-Token`. AC-09 forbidden-header check is BLIND to browser-attached cookies (attached post-fetch-shim, invisible to Godot). The defensive `Set-Cookie` response check is the only cross-layer signal that the carve-out is misconfigured. **Pillar 1 binding**: without this defense, prior account's cookie could write inventory under wrong account → anti-fabrication promise broken。

**Rule 9 — `transition_id` per-endpoint child IDs.**
ADR-006 Contract 2 mandates `transition_id` opaque + UNIQUE constraint backend-side。本 client locked decision：state-write 同 LootDrop 多個 endpoint family 各自用 derived child IDs（client-side concatenation, opaque to backend）：

| Endpoint | Child ID format |
|----------|-----------------|
| State transition POST | `<parent_tid>:state` |
| LootDrop cache POST | `<parent_tid>:loot-cache` |
| LootDrop commit POST | `<parent_tid>:loot-commit` |
| LootDrop cache GET | `<parent_tid>:loot-cache` (same key as POST — read uses same row) |

Parent `transition_id` 由 GameStateMachine 喺 transition function 生成 (per Contract 2 algorithm)；client 喺 dispatch helper 自動 append suffix。Backend 一個 UNIQUE constraint 列依然 hold（per-endpoint string 唔同 → 唔 collide），無需 ADR-006 amendment。**Rule 9 binding**: child suffix list 鎖死喺本 GDD；新 endpoint family 加入時必須 GDD edit + suffix 加入 list（防止 ad-hoc string drift）。

**Rule 10 — 401 vs CORS / transport-error disambiguation.**
Godot 4.6 Web Export 嘅 `request_completed(result, response_code, ...)` 傳 2 個 indicator。Client 喺 dispatch handler 跑分類：

| `result` | `response_code` | Classification | Action |
|----------|-----------------|----------------|--------|
| `RESULT_SUCCESS` | 401 | Genuine session invalidation | Rule 11 latch + emit `session_invalidated()` |
| `RESULT_SUCCESS` | 409 | Idempotency conflict — already committed elsewhere | Treat as success, fetch canonical state, reconcile |
| `RESULT_SUCCESS` | 429 | Rate limited | Honor `Retry-After` header (Rule 12) |
| `RESULT_SUCCESS` | 410 | Protocol version deprecated (NEW 2026-05-26 per P0-7) | emit `protocol_error("endpoint_410_gone", ...)` + `auth_required()`; latch `_protocol_skew_detected` |
| `RESULT_SUCCESS` | 4xx (≠ 401, 409, 410, 429) | Protocol error (client bug) | emit `protocol_error(tid, reason)`; do NOT retry |
| `RESULT_SUCCESS` | 5xx | Server error | Rule 12 backoff retry up to 5 attempts |
| `RESULT_CANT_CONNECT` / `RESULT_CONNECTION_ERROR` / `RESULT_TIMEOUT` / `RESULT_NO_RESPONSE` | 0 | Transport failure (incl. CORS swallow) | emit `poll_failed(category)`; #1 transitions to `Disconnected`; Rule 12 backoff |
| `RESULT_REQUEST_FAILED` | 0 | Browser / fetch shim failure (rare) | Same as transport failure |
| `RESULT_CANCELED` | 0 (or undefined per Q-A4 spike) | Explicit `cancel_request()` | Silent — caller initiated cancellation |

**Rule 10 critical**: transport failure **NEVER** triggers `session_invalidated()`。GDD #1 Decision #4 嘅「any 401 → invalidate」原文喺 GDD #1 / AC-31 prose 屬 ambiguity；本 Rule 10 喺 client 層 disambiguate，GDD #1 唔需 amendment。Client owns the classification logic.

**Rule 11 — 401 latch + cancel siblings.**
First 401 (per Rule 10 row 1) 觸發：
1. Set `_token_invalidated_latched: bool = true` (in-memory, not persisted)
2. Emit `session_invalidated()` **exactly 1 次**
3. Iterate all inflight requests across 4 channels → `http.cancel_request()` + `call_deferred("queue_free")` + remove from inflight set (do NOT wait for `request_completed`)
4. Subsequent 401 responses arriving from cancelled-mid-flight requests → swallow + do NOT re-emit
5. Latch clears on 下次 successful `POST /session/claim` 收到新 token (Rule 7 path)

Cancellation 喺 4.6 Web Export 嘅確切 behavior 未 verify (Q-A4 spike scope addition) — implementation MUST treat `RESULT_CANCELED` 同 silent drop 都係 acceptable post-cancel outcome。

**Rule 11.1 — Response classification precedence (NEW 2026-05-26 per design-review D1 arbitration).**
3 filters (latch / substate / epoch) 各自 protect 不同 scenarios (defense-in-depth justified per godot-specialist)，但 single response 嚟到時 filter 跑嘅 order 必須 spec-explicit。Handler `_dispatch_response()` 內部 filter chain order：
1. **Epoch check first** — `if request._session_epoch != self._session_epoch: SWALLOW (return early, no signal emit, no state mutation)`。Reason: epoch mismatch 代表 prior account's data — 必須 first-line defense 避免任何 leak。
2. **Substate check** — `if self._substate in [Suspended, Draining]: SWALLOW (response is from prior active phase, stale by definition)`。
3. **Latch check (last)** — `if self._token_invalidated_latched:` (a) 401 responses 從 cancelled siblings → swallow (avoid `session_invalidated` re-emit per Rule 11 step 4); (b) 200 canonical responses (e.g., `lootdrop_committed` from a commit that beat the 401 race) → **still process for cross-account safety** (server says we successfully committed — record tombstone even though latch fired，避免 後續 retry 雙重 fire)。**Do NOT emit `lootdrop_committed` signal during latch — tombstone write only**; downstream has already received `session_invalidated()` and will reconcile on next `claim_session` completion。**Rationale**: latch 主要係 signal-emission dedupe filter，唔係 response filter — 200 嘅 successful work landing during latch 仍要 honor。

Filter precedence 順序意義：epoch protects "wrong account"; substate protects "stale phase"; latch protects "duplicate session_invalidated emit"。三者 orthogonal，但 epoch 必須先跑因為佢 protect 最 severe 嘅 corruption category。

**Rule 12 — Retry policy matrix.**

| Error class | Retry? | Max attempts | Delay |
|-------------|--------|--------------|-------|
| `5xx` | Yes | 5 | `retry_delay(n)` formula (per GDD #1 Formula 1) |
| `408` Request Timeout | Yes | Once immediate, then backoff | 0s first, then formula |
| `429` Too Many Requests | Yes | Until `Retry-After` exhausts | `Retry-After` header literal |
| `409` Conflict (commit dedupe) | No (treat as success) | N/A | N/A |
| `404` on GET `/lootdrop/{tid}/cache` | No (fall through to GDD #1 Rule 5 priority 3) | N/A | N/A |
| `410 Gone` (NEW 2026-05-26 — protocol version deprecation per P0-7) | No | 0 | emit `protocol_error("endpoint_410_gone", endpoint, required_version)` + `auth_required()` (force re-claim → user sees update prompt via #24) |
| `4xx` (≠ 401, 408, 409, 410, 429) | **No** (client bug) | 0 | emit `protocol_error` |
| `401` | **No** | 0 | Rule 11 latch + emit `session_invalidated()` |
| Transport failures | Yes | Until backoff cap | `retry_delay(n)` formula |
| `RESULT_CANCELED` | No | 0 | Silent |

**Why no 1-size-fits-all**: GDD #1 Formula 1 owns `retry_delay`；Rule 12 specifies WHEN to apply it.

**Rule 13 — Timeout discipline.**
所有 `HTTPRequest.timeout` MUST 非零。`POLL_TIMEOUT_SECONDS = 4.0`（小於 `GYMSYS_POLL_INTERVAL_SECONDS = 5.0` 防止 next-tick overlap），其他 channels 用 `WRITE_TIMEOUT_SECONDS = 10.0`。Godot 4.6 default `timeout = 0` = wait forever = HIGH risk — Rule 13 鎖死非零強制。

**Rule 14 — bfcache + Suspended cleanup contract.**
Client 訂閱 GameStateMachine 嘅 `state_changed`，喺 `to == Suspended` 入到 `Suspended` substate 嘅同時：
1. Pause `Polling` timer
2. Walk `_inflight_requests` set → 每個 `http.cancel_request()` + `call_deferred("queue_free")`
3. Clear `_inflight_requests` 即刻 (do NOT wait for `request_completed`)
4. Persist `last_known_state` cache 喺 `user://state.json` 經 `IPersistence.write` (Rule 6 contract)

Resume (`state_changed` from `Suspended` to other state) → fire single immediate poll → resume timer cadence。**Rule 14 防 bfcache zombie leak**：10 分鐘 suspended 唔 cleanup → 120 個 orphan `HTTPRequest` 累積。

**Rule 15 — Committed transition tombstone set (revised 2026-05-26).**
Client 持有 in-memory `_committed_tombstones: Dictionary[String, int]` (key = `<tid>:loot-commit` child ID, value = `committed_at` unix timestamp from server's 200 response — **store timestamp ONLY，NO payload**)，並 mirror 至 `user://state.json` 經 `IPersistence.write`。Eviction policy: **age-based, NOT count-based** — entries older than `COMMITTED_TOMBSTONE_RETENTION_DAYS = 35` (matches ADR-006 Contract 15 backend retention 37d - 2d safety buffer) trimmed at boot + nightly idle tick (every `Polling` substate entry from `Suspended` with elapsed wall-clock ≥ 1h since last sweep)。同一 `transition_id` 第二次 commit 收到 200 → handler 喺 tombstone set 內 hit → **唔再 emit `lootdrop_committed`** signal → 避免 double-fire ritual UI / 雙層 inventory update。

**Why tombstone Set (not FIFO cache)**: prior design used FIFO count-cap = 50 + canonical inventory snapshot per entry。Failure mode：51+ commits 累積 → 最舊 entry evicted → 若 server 因 proxy retry / debug replay re-emit 200 for evicted tid → cache miss → `lootdrop_committed` re-fires for 同一 sacred drop → **Pillar 3 double-ritual violation** (Falsifiable Design Test #2 「雙倍 LootDrop」)。Tombstone Set 只 store tids（每 entry ~64 bytes for tid + 8 bytes timestamp ≈ 72 bytes）— 35 日 × 30 commits/day = 1050 entries × 72 = 76 KB → 完全可 hold 喺 IndexedDB 內 entire retention window，零 false re-emit possible。Canonical inventory snapshot 唔需要 cache —— 第二次 200 嘅 response body 仍 contains canonical state，client 唔 re-fire signal 即已 sufficient（consumer side 已有上次 fire 嘅 state）。

### States and Transitions (Internal Sub-State Machine)

Client 內部有自己嘅 sub-state machine（與 GDD #1 嘅 9-state FSM 分開；client 唔 affect FSM enum）。**Revised 2026-05-26 per design-review P0-5**: 6 substates (added `Draining` per P0-4); full 6×6 transition matrix below replaces prior partial table。

| State | Purpose | Persists? |
|-------|---------|-----------|
| `Initialising` | Autoload `_ready()` 跑緊；讀 session_token | No |
| `AwaitingAuth` | 無 valid session_token；waiting for `set_session_token(...)` | No |
| `Polling` | 主要 operating state；timer fires GET /api/game/state every `GYMSYS_POLL_INTERVAL_SECONDS` | No |
| `Backoff` | Transport / 5xx retry sleep | Internal `n` counter only (in-memory) |
| `Suspended` | App backgrounded；timer paused；inflight cancelled | No |
| `Draining` (NEW 2026-05-26) | USER_EXPLICIT logout in progress；loot_commit channel finishing in background；new commits rejected | No |

#### Full 6×6 Transition Matrix

Rows = from-state；Columns = to-state。Cell = trigger + action + signal emission。`—` = illegal direct transition (illegal transitions emit `dropped_event(from, to, reason)`)。

| FROM \ TO        | Initialising | AwaitingAuth | Polling | Backoff | Suspended | Draining |
|------------------|--------------|--------------|---------|---------|-----------|----------|
| **Initialising** | self-loop (during `_ready()`) | persisted `session_token` empty/missing → emit `auth_required()` | persisted `session_token` valid → fire immediate poll | — (no inflight yet to fail) | — (per ADR-006 Contract 4 atomic `_ready()`; if `state_changed → Suspended` arrives mid-`_ready`, queue + handle post-`_ready` complete) | — (logout requires token to exist; Initialising hasn't read it yet) |
| **AwaitingAuth** | — (one-way) | self-loop on `claim_session` failure | `set_session_token(non_empty)` invoked → enter Polling + fire immediate poll | — (no inflight to fail) | **Cell 1 RESOLVED [A]**: `state_changed → Suspended` arrives → cancel any inflight `claim_session` HTTPRequest + persist nothing (typed credentials in #24 UI are #24's concern; client doesn't persist them) + enter Suspended | — (no token to clear) |
| **Polling**      | — (one-way) | (a) Rule 11 401 latch → emit `session_invalidated` + cancel siblings → enter AwaitingAuth；(b) `clear_session_token(SESSION_KILLED)` | self-loop on successful poll | transport failure / 5xx → Rule 12 retry | `state_changed → Suspended` → Rule 14 cleanup | `clear_session_token(USER_EXPLICIT)` → enter Draining |
| **Backoff**      | — | **Cell 2 RESOLVED [A]**: next retry attempt 觸到 401 → Rule 11 latch + cancel pending retry timer + enter AwaitingAuth directly (no Polling hop) | next retry succeeds → reset `n=1` + enter Polling | self-loop incrementing `n` (Rule 12) | **Cell 3 RESOLVED [A]**: `state_changed → Suspended` → cancel retry timer + reset `n=1` + enter Suspended; on resume fire fresh poll (no `n` preservation across suspend) | `clear_session_token(USER_EXPLICIT)` → enter Draining (cancel retry timer + skip Backoff state altogether) |
| **Suspended**    | — | — (token expiry detection requires actual poll; cannot transition directly. If token expired during suspend, resume → Polling → Polling fires poll → 401 → Rule 11 latch → AwaitingAuth via Polling row above) | `state_changed → (any non-Suspended)` → fire immediate poll + enter Polling | — (must enter Polling first; Backoff is entered only on actual transport failure post-resume) | self-loop (subsequent `state_changed` to/from Suspended is idempotent) | — (logout while Suspended is rejected; UI must wake app first) |
| **Draining**     | — | (a) `drain_completed` emit → enter AwaitingAuth + `auth_required()`; (b) Rule 11 SESSION_KILLED upgrade race during drain → cancel remaining inflight + enter AwaitingAuth immediately | — (cannot resume polling without re-claiming token) | — (Draining only cares about commit inflight, not retries) | `state_changed → Suspended` arrives during drain → cancel all inflight including commits + enter Suspended (drain abandoned; tombstone protection preserves dedupe semantics on resume) | self-loop while inflight commits remain |

**Illegal direct transitions** (any cell marked `—` above) → `dropped_event(from: String, to: String, reason: String)` signal emit + state unchanged。AC-26 enumerates all 36 cells (6 legal self-loops + ~17 legal transitions + ~13 illegal `dropped_event` cases — exact counts in AC-26 test data).

**Internal state ≠ FSM state.** Client 嘅 `Polling` / `Backoff` / `Draining` 等 substate 唔 emit 任何 signal 畀 #1 (除咗 `session_invalidated` / `auth_required` / `drain_started` / `drain_completed` 等 cross-system signals)，唔影響 GameStateMachine 9-state enum。Client 只係 #1 嘅一個 service provider；client's internal state machine 對 gameplay layer 透明。

### Interactions with Other Systems

| System | Direction | Interface | Owner |
|--------|-----------|-----------|-------|
| **#1 GameStateMachine** | signal up (we → GSM) | Emit 7 workout signals + `session_invalidated()` + `auth_required()` + `lootdrop_cache_fetched(...)` | GSM owns subscription via `connect_for_initial_state(callable)` per ADR-006 Contract 6 |
| **#1 GameStateMachine** | callback down (GSM → we) | GSM calls `client.write_state_transition(transition_id, from, to, payload)` (fire-and-forget) AND `client.cache_lootdrop(transition_id, payload)` (fire-and-forget) — per GDD #1 Rule 2 step 6 dual-target write | Client owns the API surface; GSM 唔知 HTTP 點做 |
| **#1 GameStateMachine** | signal down (GSM → we, via state_changed) | We subscribe to `state_changed` to drive internal lifecycle (Rule 14 Suspended pause) | GSM owns signal; client 訂閱 read-only |
| **#3 PersistenceLayer** | bidirectional via interface | `IPersistence.read() / write(key, value)` — used for `session_token`, `_committed_tombstones` (Rule 15, age-pruned), `_last_known_state` mirror | #3 owns implementation; we own which keys we touch |
| **#9 Workout State Tracker** | signal up (we → #9) | Subscribes to 7 typed workout signals; **NO direct call back to client** | #9 read-only consumer |
| **#14 EnemyDirector** / **#15 LootDropSystem** | indirect via #1 | These 唔直接接觸 client；佢哋 read `state_changed` 由 #1 emit | No direct interface |
| **#24 Login / GymSys Connection UI** | bidirectional | UI calls `client.claim_session(username: String, password: String) -> SessionClaimResult`; UI 訂閱 `auth_required()` signal | #24 owns login UI; client owns the claim API |
| **#28 Telemetry** | signal up | Subscribes to `poll_failed`, `dropped_poll_tick`, `session_invalidated`, `protocol_error`, `lootdrop_cache_fetched`, `lootdrop_committed` for funnel metrics | #28 read-only |
| **Future #31 SSE / Realtime Upgrade (v0.2)** | swap-in upgrade | Client internal transport (poll vs SSE) abstracted behind `IGymSysTransport` interface (defined here; impl deferred to #31 GDD) | #31 will provide SSE `IGymSysTransport` impl |

#### `IGymSysTransport` interface stub (defined here for v0.2 swap-in readiness)

```gdscript
class_name IGymSysTransport extends RefCounted

# Returns latest workout state via signal emission (does not block)
func request_workout_state() -> void: push_error("override"); pass

# Set token used for authenticated requests
func set_session_token(token: String) -> void: push_error("override"); pass

# Pause transport (used on Suspended / explicit shutdown)
func pause() -> void: push_error("override"); pass
func resume() -> void: push_error("override"); pass

# Signals emitted by transport impl (subscribed by GymSysClient facade)
signal raw_state_received(state_dict: Dictionary)
signal transport_error(category: String)
signal auth_invalidated()
```

VS tier impl = `PollingTransport` (5s `HTTPRequest`-based) — described above。v0.2 #31 impl = `SSETransport` (server-sent events) — defined in #31 GDD。GymSysClient facade unchanged — #9 同 #14 等 consumer 唔知 transport 變咗。

#### `SessionClaimResult` Resource (returned from `claim_session()`)

```gdscript
class_name SessionClaimResult extends Resource

@export var success: bool
@export var token: String       # populated only if success == true
@export var error_code: String  # one of: "invalid_credentials" / "network_error" / "rate_limited" / "server_error" / ""
@export var retry_after: int    # seconds; populated only when error_code == "rate_limited"
```

#24 Login UI 用呢個 Resource 顯示對應 user-facing message — 避免 raw HTTP code leak 到 UX。

## Formulas

GymSys Backend Client 主要係 event-driven coordinator + signal-emitter，唔做 gameplay math。本 section 包含一條 client-owned formula；其他需要嘅 calculation 均為決定 table / cap / rule（已喺 Section C 內列明），不適合 formula 化。

### Formula 1: Polling Jitter (Thundering-Herd Avoidance)

Multiple Mirror Hero clients 同一 wall-clock tick（e.g. 用戶 7:00 AM 集體開 app）會 cluster 喺 0/5/10/15s 邊界 hit backend。±0.5s random jitter 散開 load。

`actual_poll_interval = GYMSYS_POLL_INTERVAL_SECONDS + randf_range(-POLL_JITTER_SECONDS, +POLL_JITTER_SECONDS)`

**Preconditions** (runtime `assert()` enforced at boot — analogous to GDD #1 ADR-006 Contract 8 `_assert_knob_invariants`):

- `POLL_JITTER_SECONDS >= 0.0`
- `GYMSYS_POLL_INTERVAL_SECONDS - POLL_JITTER_SECONDS >= POLL_TIMEOUT_SECONDS + 0.5` (cross-knob invariant — preserves single-flight margin under Web Export frame-time spikes)

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base poll interval (seconds) | `GYMSYS_POLL_INTERVAL_SECONDS` | float | 5.0 (locked by game-concept) | Read-only knob from game-concept; can't be changed without re-validating Pillar 2 polling cost |
| Jitter amplitude (seconds) | `POLL_JITTER_SECONDS` | float | **0.0 .. 0.5** (default 0.5) | Owned by this GDD; capped at 0.5 to preserve ≥0.5s margin above `POLL_TIMEOUT_SECONDS = 4.0` |
| Poll request timeout (seconds) | `POLL_TIMEOUT_SECONDS` | float | 4.0 (Rule 13) | Read-only from this same GDD's Tuning Knobs; cross-references jitter math |
| Result (seconds) | `actual_poll_interval` | float | `[4.5, 5.5]` at defaults | Seconds until next poll fires from current tick |

**Output Range** (at defaults): `[4.5, 5.5]` seconds. Hard guarantee `actual_poll_interval > POLL_TIMEOUT_SECONDS` holds within declared safe ranges — single-flight invariant from Rule 2 preserved.

**Example** (with `GYMSYS_POLL_INTERVAL_SECONDS = 5.0`, `POLL_JITTER_SECONDS = 0.5`):
- random uniform ∈ `[-0.5, +0.5]` → actual ∈ `[4.5, 5.5]`
- 5 consecutive samples (deterministic seed for test): 4.73, 5.21, 4.92, 5.48, 4.61 — within range ✓

**Cross-system note**: 呢條 formula 完全 self-contained 喺 GymSys Client。Backend 唔知 jitter 存在（佢只見 requests arriving with spread-out timestamps）。GDD #1 Formula 1 (`retry_delay`) 喺 `Backoff` substate 取代呢條 formula —— 兩個 formula 唔同時 active：
- `Polling` substate fires 用 Formula 1 (this section)
- `Backoff` substate fires 用 GDD #1 Formula 1 (`retry_delay`) — 我哋 execute 嘅 sleep

### Formula owned elsewhere (referenced, not duplicated)

| Formula | Owner GDD | Used in this client |
|---------|-----------|--------------------|
| `retry_delay(n) = min(BASE_DELAY × 2^(n-1), RETRY_CAP)` | #1 GameStateMachine (Formula 1) | `Backoff` substate sleep duration (Rule 12 retry policy execution; per-Rule 12 matrix retry decisions invoke this with `n` = consecutive failure count, reset to 1 on success) |

## Edge Cases

### Boot Edge Cases

- **If `user://state.json` 完全唔存在 (first boot)**: All keys missing including `session_token`. Enter `AwaitingAuth` substate; emit `auth_required()` signal; #24 Login UI takes over. Polling timer NOT started.
- **If `user://state.json` 存在但 `session_token` key 缺 / 空 string / null**: Same handling as first boot — enter `AwaitingAuth`, emit `auth_required()`.
- **If persisted `_committed_tombstones` contains entries older than `COMMITTED_TOMBSTONE_RETENTION_DAYS = 35` (clock skew / migration artifact / corruption)**: Trim by age at boot (drop entries where `now - committed_at > retention`), emit `tombstones_trimmed(removed: int, retention_days: int)` for telemetry, continue. NOT a corrupt-save signal. Tombstone entries 永遠唔由 count cap 觸發 eviction — age-only。
- **If `BACKEND_BASE_URL` config 缺 / 空 string at autoload `_ready`**: Fail-fast assertion crash (debug build) OR emit `protocol_error("missing_base_url")` (release build) + do NOT start polling timer. **Critical**: silent empty URL would make every poll fail RESULT_CANT_CONNECT, looking identical to CORS — undebuggable in production.
- **If `IPersistence.read()` returns Dictionary but values are stale schema (e.g. v0 token format)**: Per GDD #1's `PersistenceLayer.migrate(from, to)` chain — bounded by ADR-006 Contract 10. If migration succeeds, continue; if fails → corrupt-save path (per #1 Rule 5 priority 5), enter `AwaitingAuth`.

### Polling Edge Cases

- **If poll fires while GameStateMachine state == `Booting` (autoload order race shouldn't happen per ADR-006 Contract 4, but defensive)**: silently skip; single-flight invariant handles it.
- **If poll RTT > 5s on cellular**: Rule 2 single-flight skip next tick(s) until response arrives; emit `dropped_poll_tick("prior_inflight")` per dropped attempt for telemetry observability.
- **If polling returns 200 with empty / no-active-workout body**: NOT an error. Client stays in `Polling` substate; does NOT emit any of the 7 workout signals (no event to forward). Internal `_last_known_state = "idle"` cached for `IPersistence.write`. Consumer (#9 Workout State Tracker) simply has nothing to process — Pillar 2 "frictionless" satisfied.
- **If poll returns 200 with malformed JSON / unparseable body**: `JSON.parse_string()` returns `null` → emit `protocol_error(tid="poll_response", reason="malformed_json")`; do NOT 401 latch; continue polling next tick.
- **If poll response missing expected fields (e.g. `workout_started` 但缺 `workout_id`)**: normalize function returns error; emit `protocol_error(...)` with field name; do NOT emit partial workout signal.

### Auth / Session Edge Cases

- **If 401 hits multiple inflight requests simultaneously**: First (per Rule 11) triggers latch + cancel siblings + emit `session_invalidated()` once. Cancelled requests' `request_completed` callbacks 仍 fire 過陣 → handler 見 `_token_invalidated_latched == true` → swallow，唔重 emit signal。
- **If `claim_session()` race against backend already-invalidated state (e.g. tablet claimed first)**: backend 返 200 + new token，但 tablet 嘅 token 已生效 → 下次 poll 401 → standard latch + re-claim cycle。`SESSION_CLAIM_RETRY_LIMIT = 3` 內止 loop；超過 → stay in `AwaitingAuth` + emit `auth_required()` 再次。
- **If session token persisted 但 expired server-side (TTL `SESSION_TOKEN_TTL_HOURS = 720` 已過 per #1)**: First poll 即收 401 → standard latch + `AwaitingAuth` flow → 用戶 see re-login prompt。
- **If user explicit logout via `client.clear_session_token(reason)` (revised 2026-05-26 per design-review P0-4 — non-blocking)**: Two-tier API based on `reason: ClearTokenReason` enum：
  - `ClearTokenReason.USER_EXPLICIT` (player tapped "Settings → Logout"): API **returns immediately** (no `await`). Client enters new substate `Draining`：(1) emit `drain_started(pending_commits: int)` signal for #24 UI banner (non-modal — Pillar 2 protection); (2) `state_write` + `loot_cache` + `poll` channels — `cancel_request()` 即時 + `call_deferred("queue_free")`; (3) `loot_commit` channel allowed to finish in background up to `WRITE_TIMEOUT_SECONDS = 10.0` per inflight commit (NOT a single global 10s window — each commit gets full timeout budget); (4) **reject NEW commit enqueues** while in `Draining` substate → emit `drain_in_progress(rejected_tid: String)` for telemetry; (5) when last inflight commit resolves OR each commit's WRITE_TIMEOUT exhausts → emit `drain_completed(committed_count: int, timeout_count: int)` → transition to `AwaitingAuth` substate + emit `auth_required()`. **Pillar 2 invariant**: API call returns within ≤ 16 ms (one process frame budget); UI MUST NOT block during drain。**Rule binding**: `clear_session_token()` MUST be implementation-wise sync-return；any `await` inside violates AC-23-style fire-and-forget contract。
  - `ClearTokenReason.SESSION_KILLED` (server 401 latch path — Rule 11): No drain。Cancel all inflight (including commits — they will 401 anyway) + transition to `AwaitingAuth` + emit `auth_required()`. Drain makes no sense when token is already invalid backend-side。
  - **Idempotency** (AC-29 retained): Second `clear_session_token(...)` call during active `Draining` substate returns immediately + emits `drain_in_progress` debug signal; does NOT reset drain timers, does NOT issue duplicate cancellations。
- **If `clear_session_token()` called during in-flight non-commit request**: cancel immediately as part of step (2) above (no drain needed — read-only or idempotent writes).
- **If `_session_epoch` mismatch on inflight response (response arrives after logout/re-claim)**: Every inflight request tagged with `_session_epoch: int` at dispatch time。Response handler check current epoch vs request's epoch → 不等 → swallow response (avoid mixing prior account's data into new session)。

### Network Failure Edge Cases

- **If CORS preflight rejection (cross-origin deployment without proper Allow-Origin headers)**: `request_completed(RESULT_CANT_CONNECT, 0, ...)` → Rule 10 row "transport failure" → emit `poll_failed("cors_or_network")`；**NEVER** triggers `session_invalidated()`。
- **If self-signed cert on iOS Safari**: silent fetch failure → 同 CORS 看落一樣 (RESULT_CANT_CONNECT, 0) → 同樣 transport-failure path。**Deployment requires real CA cert (Let's Encrypt via reverse proxy) — flagged at ADR-002 + ADR-004**。
- **If Firefox Enhanced Tracking Protection blocks cross-origin XHR**: Same RESULT_CANT_CONNECT path as CORS。Cannot disambiguate from CORS at GDScript layer。Both 路徑 emit `poll_failed("cors_or_network")`。
- **If loot_commit channel receives 429 during Draining substate**: Honor `Retry-After` only if `Retry-After < WRITE_TIMEOUT_SECONDS`; otherwise treat as per-commit timeout — increment `timeout_count` for `drain_completed` payload and cancel the commit. Rationale: each inflight commit in Draining has a fixed `WRITE_TIMEOUT_SECONDS = 10.0` budget; a `Retry-After` exceeding that budget cannot be honored within the drain window.
- **If DNS resolution failure**: Same transport-failure handling as CORS。
- **If TCP RST mid-response**: `RESULT_NO_RESPONSE` → Rule 12 retry transport-failure path with `retry_delay(n)` backoff。
- **If 5xx storm (backend down)**: Rule 12 retry up to 5 attempts then `poll_failed`，GameStateMachine transitions to `Disconnected`。Total worst-case 1+2+4+8+16=31s before user sees "Disconnected" UI overlay。**Pillar 1 perceived risk** — 31s 黑屏 / 卡 spinner 期間玩家覺得 app 死咗。**Mitigation**: UI 喺第 2 次 retry (即 ~3s 後) 開始顯示「Reconnecting…」spinner，by #20 Gym-Mode HUD 訂閱 `poll_failed` signal trigger。
- **If 408 Request Timeout**: Rule 12 matrix — immediate retry once, then backoff。
- **If 429 Too Many Requests with `Retry-After: <N>` header**: Rule 12 — wait N seconds (honor backend signal)，meanwhile ALL 4 channels pause (not poll-only)；resume cadence + jitter formula after wait。

### bfcache / Suspended Edge Cases

- **If 10-min bfcache suspend then resume**: Rule 14 cleanup contract — all 4 channels cancelled + cleared on `Suspended` entry → fresh polling on resume → zero zombie node leak。
- **If bfcache restore arrives mid-cancellation race**: cancel issued by Rule 14 but response was already buffered in browser fetch queue → arrives 過陣 → handler sees `_substate == Suspended` AND `_is_tearing_down` flag → swallow response silently, log debug warning。
- **If iOS Safari WASM reinit on bfcache (not pure restore, full reload)**: autoload `_ready()` runs again → session_token re-read from `IPersistence`；若 token 仍 valid (server-side TTL 內) → resume `Polling` normally；若 evicted by Safari ITP (>7d inactive) → `AwaitingAuth` (per Boot edges)。

### Idempotency & Commit Cache Edge Cases

- **If commit POST 200 arrives but `<tid>:loot-commit` already in `_committed_tombstones` (Rule 15)**: handler 唔再 emit `lootdrop_committed`；唔 double-fire ritual UI / 雙層 inventory update。Backend write was idempotent server-side, client-side tombstone filters re-fired signal。Canonical inventory from response body 唔再 propagate downstream — assumption: 第一次 emit 嗰陣 consumer 已 sync; 第二次 200 嘅 response 必須 byte-equal to first (server-authoritative idempotence — ADR-002 binding)。若 byte-不等 → emit `protocol_error("idempotent_commit_response_drift", tid)`。
- **If GET `/lootdrop/{tid}/cache` returns 404 (backend pruned after 37-day retention per ADR-006 Contract 15)**: fall through to GDD #1 Rule 5 priority 3 (backend-wins reconcile)；emit `lootdrop_cache_fetched(tid, {}, 0)` with empty payload as marker to GameStateMachine。
- **If GDD #1 calls `cache_lootdrop()` OR `commit_lootdrop()` twice with same `transition_id` in same frame**: per-channel queue 對 incoming requests 做 tid dedup — 第二個 enqueue 觸發 → match prior queued entry → return prior promise (collapse duplicate)。
- **If `_inflight.size() > MAX_INFLIGHT_REQUESTS = 4` (dispatcher re-entry bug or race)**: runtime `assert(_inflight.size() <= MAX_INFLIGHT_REQUESTS)` at dispatch entry → debug-build crash + log P0；release build → defer 5th request to queue, emit `inflight_cap_breached` for telemetry。

### Resource & Storage Edge Cases

- **If `user://` IndexedDB quota exceeded at write time** (not boot — runtime write fail): `IPersistence.write` returns `false` → catch + trim `_committed_tombstones` by 2x retention shrink (35d → 17d half-life cut) → retry once → if still fails → emit `persistence_quota_exhausted(key: String)` for telemetry + log error；continue operating (in-memory state still valid)。**Note (revised 2026-05-26 per design-review)**: tombstone shrink under quota pressure prefers DROPPING dedupe protection for OLDEST entries (>17d ago — those drops are highly unlikely to re-arrive 200 from server) over losing token / last_known_state which are operationally critical。
- **If HTTPRequest node parent destroyed mid-response (autoload teardown race)**: orphan node leak risk → **mitigation**: all orphan HTTPRequests parented under `/root/GymSysClient/_orphans` container (NOT root) → autoload teardown owns the cleanup → no leaked nodes survive autoload destruction。
- **If Safari ITP evicts `user://state.json` after 7-day inactivity**: All keys gone on next boot → looks like first-boot → `AwaitingAuth` flow. **NEW signal `session_evicted_by_browser()` emit** for analytics (distinguish 「真係 first boot」 vs 「Safari evicted」 — 由 #28 Telemetry 訂閱)。**Pillar 3 risk note**: 若玩家 7+ 日唔 open game，session token gone + LootDrop cache gone (backend mirror 仍喺，per Contract 15 37-day retention) → re-claim 後 GET cache restore — graceful recovery 仍 hold。
- **If Chrome Incognito refuses IndexedDB persistence (quota = 0)** — **revised 2026-05-26 per design-review godot-specialist P0-5**: Detection 由 reactive path 處理 — first `IPersistence.write(...)` call returns `false` → emit `persistence_volatile()` warning signal (one-shot, latched after first emit)；do NOT block polling；UI #24 訂閱呢個 signal 顯示「Private Mode 唔可以 carry session across tab refresh」per game-concept Q-E1。**Prior design used `JavaScriptBridge.eval("navigator.storage.estimate()")` at boot — DELETED because `JavaScriptBridge.eval()` 返 JS Promise object（唔係 resolved Dict），GDScript 4.6 唔可以 `await` JS Promise → API premise broken。Reactive detection 達到同樣 telemetry shape，延遲只係到第一次 write attempt (typically < 5s post-boot)。**

### Concurrency Hazards

- **If `state_changed → Suspended` arrives during `_dispatch_response()` deferred execution (response handler 排咗去 next frame，但 next frame 時已入 Suspended)**: Gate signal emission on `_substate != Suspended` AND `not _is_tearing_down` → drop response silently if Suspended already entered (response was about to update last_known_state but is now stale by definition)。
- **If `clear_session_token()` called during in-flight commit POST (Pillar 2 protection)**: handled per Auth edges "logout drain" rule — wait WRITE_TIMEOUT before cancelling commit channel。

### Time / Clock Edge Cases

- **If DST transition fires mid-poll cycle (e.g. 02:00 → 03:00 spring-forward)**: client-side scheduling ALL pinned to `Time.get_ticks_msec()` (monotonic, DST-immune)。`Time.get_unix_time_from_system()` 唯一允許用途 = echo to backend payload (transition_id timestamp prefix — per ADR-006 Contract 2)。**Critical**: NEVER mix monotonic + wall-clock for retry/jitter timing — DST jumps causes 1-hour silent skip。
- **If browser tab sleeps > 5 min (laptop lid close) then resume**: `_process(_delta)` delta spikes huge on first frame post-resume → clamp `delta` to `actual_poll_interval` ceiling — NEVER burst-fire backlog polls。Rule 14 Suspended cleanup applies if `state_changed → Suspended` fired during sleep；若無 (silent browser pause without visibility event)，clamp 保護。
- **If system clock NTP-corrected mid-401-latch**: latch 係 boolean flag + in-memory，timestamp-free → 唔受 NTP impact (per Rule 11)。
- **If backend `server_time` field differs from client wall-clock by > 5 min**: Do NOT correct client clock。Trust backend timestamps verbatim for display (e.g. `completed_at` in workout_completed signal)。Surface skew in dev builds only via `protocol_error("clock_skew_5min", details)`。

### Backend Protocol Drift

- **If backend returns `X-Protocol-Version: <v>` where `v > MAX_KNOWN_VERSION = 1` (newer than client's lock — revised 2026-05-26 per design-review P0-7)**: Two sub-cases based on whether response satisfies client's v1 schema requirements:
  - **Sub-case A (ADD-only drift)**: backend v2 only added new optional fields；all client v1 required fields still present in response → known fields parsed, new fields silently ignored, emit `protocol_error("schema_drift_higher_version_compatible", actual_v: int)` for telemetry, continue operation。Forward-compat path。**VS tier NO upgrade nag** per game-concept Q-E5；MVP 之後 re-evaluate。
  - **Sub-case B (REMOVE drift — required field missing)**: backend v2 removed a field that client v1 required (e.g., `set_logged.weight`, `workout_completed.completed_at`, `rest_started.duration_seconds`) → response fails v1 schema validation in `_normalize_*` function → **DO NOT silently fall back**, instead: (1) emit `protocol_error("major_version_skew_breaking", actual_v, missing_field)`; (2) emit `auth_required()` to surface re-login / app-update prompt via #24; (3) latch `_protocol_skew_detected: bool = true` (in-memory) — subsequent polls refuse to dispatch until skew cleared by `set_session_token(...)` (which implies #24 has shown user update prompt + new client app loaded)。**Rationale**: silent fallback for REMOVED required field would let #18 PR Detection silently miss a real set (player did real PR, system blind) → **Pillar 1 silent data loss violation**。Fail-loud preferred over silent silent-corruption for major schema breakage。Backend MUST keep v1 endpoints alive during transition window (ADR-002 binding); deprecation = explicit `410 Gone` with `X-Required-Version` header (Rule 12 matrix new row treats `410 Gone` as `auth_required()` trigger, NOT 4xx generic)。
- **If backend returns `rest_started` without `duration_seconds` field**: Fallback to GDD #1 `REST_PERIOD_FALLBACK_SECONDS = 90`。Signal emit `rest_started(90)` — NOT silently dropped。Emit `protocol_error("missing_field_duration_seconds")` for backend debug。
- **If backend returns `set_logged` with unknown `exercise_id` (string ID drift)**: Emit signal with backend's literal value (e.g. `set_logged("unknown_exercise_42", 8, 60.0)`)；UI fallback "Unknown Exercise" per GDD #1 Edge Cases。
- **If backend returns 200 but `committed_at` field missing on `workout_completed` response**: Fallback to `Time.get_unix_time_from_system()` (client clock) as `completed_at` value；log protocol drift。Single-source-of-truth 已 break，但 game 可以繼續。

## Dependencies

### Upstream Dependencies (this system requires)

**None.** GymSys Backend Client 係 Foundation layer leaf-edge — 唔需要任何 game system pre-loaded。

**Engine / platform 依賴（非 system-level）**：

- Godot 4.6 Autoload mechanism (statically typed singleton, position 4 per project.godot ground truth — F-SYNC-2 sync 2026-05-28; was generic "position 3+" range notation, now specific per Contract 4 ratified order)
- Godot 4.6 `HTTPRequest` Node (wraps browser `fetch()` API on Web Export — knowledge-gap items per godot-specialist review, see Open Questions)
- Godot 4.6 signal system (typed signal signatures)
- `Time.get_ticks_msec()` (monotonic 64-bit milliseconds — wrap non-issue per ADR-006)
- `Time.get_unix_time_from_system()` (wall-clock anchor for `transition_id` timestamp echo — per ADR-006 Contract 2)
- `JSON.parse_string()` + `JSON.stringify()` (response/request body serialization)
- ~~`JavaScriptBridge.eval()`~~ — **REMOVED 2026-05-26 per design-review** (no longer required; quota detection moved to reactive `IPersistence.write → false` path)
- Browser fetch() API (Web Export underlying transport — single-thread JS event loop assumption per Q-A4 spike pending)

### Downstream Dependents (systems that depend on this)

**Hard dependents** (call client API directly OR subscribe to typed signals)：

| # | System | Layer | Tier | Nature of dependency |
|---|--------|-------|------|----------------------|
| 1 | GameStateMachine ★ (bidirectional hard) | Foundation | VS | (a) GSM calls `client.write_state_transition(transition_id, from, to, payload)` AND `client.cache_lootdrop(transition_id, payload)` (fire-and-forget per #1 Rule 2 step 6 dual-target write); (b) client emits 7 workout signals + `session_invalidated()` + `auth_required()` + `lootdrop_cache_fetched(...)` consumed by GSM via `connect_for_initial_state(callable)` per ADR-006 Contract 6; (c) client SUBSCRIBES to GSM's `state_changed` for lifecycle (Rule 14 Suspended pause). **Provisional reciprocity note**: GDD #1 Dependencies section line 359 lists #2 as "promoted to hard" with full contract obligations matching this row — already locked. |
| 3 | PersistenceLayer | Foundation | VS | Client calls `IPersistence.read()` at autoload `_ready()` to bootstrap `session_token`；`IPersistence.write(key, value)` for runtime persistence of `session_token`, `_committed_tombstones` (Rule 15, age-pruned), `_last_known_state` mirror。Keys used: `session_token`, `_committed_tombstones`, `_last_known_state`。**Reciprocity expected**: when GDD #3 written, it MUST list #2 as a consumer with these 3 specific keys + sync-read API contract (no `await` allowed in `IPersistence.read` boot path per ADR-006 Contract 4 autoload ordering)。 |
| 9 | Workout State Tracker (inferred) | Core | VS | Subscribes to 7 typed workout signals (`workout_started`, `set_logged`, `rest_started`, `rest_ended`, `workout_completed`, `poll_failed`, `poll_recovered`)。Read-only consumer — **NEVER calls back to client**。Tracker derives in-game workout-state aggregation from these signals。 |
| 24 | Login / GymSys Connection UI | Presentation | MVP | Subscribes to `auth_required()` signal to show login prompt；calls `client.claim_session(username, password) -> SessionClaimResult` (typed Resource per Section C)；calls `client.clear_session_token()` for explicit logout (drain procedure per Edge Cases Auth/Session)。UI owns login flow；client owns claim API。 |

**Soft dependents**（讀 client signals 但唔 drive API calls）：

| # | System | Layer | Tier | Nature |
|---|--------|-------|------|--------|
| 18 | PR Detection & Avatar Progression | Feature | Pre-MVP | Read-only consumer of `set_logged(exercise_id, reps, weight)` signal — derives 1RM PR breakthrough from real-time set log stream。Does NOT call client API。 |
| 20 | Gym-Mode HUD (WorkoutAudioAdapter) | Presentation | MVP | Read-only consumer of `set_logged(exercise_id, reps, weight)` signal — **audio-trigger ONLY** (SFX via `WorkoutAudioAdapter` child node, GSM-state-gated, LOCKED-buffer → unlock-flush)。Does NOT call client API。**Does NOT drive count / EXP visual** — those use the #9-validated path (`set_progress_changed` / `phase_changed` + #11 `stat_changed`), NEVER raw `set_logged` (anti-fabrication; EG-1 ownership relocation from #4 Audio)。Also subscribes `poll_failed` for the "Reconnecting…" overlay (see Edge Cases 5xx storm)。 |
| 28 | Telemetry / Analytics (inferred) | Polish | Pre-MVP | Subscribes to 6 telemetry signals: `poll_failed(category)`, `dropped_poll_tick(reason)`, `session_invalidated()`, `protocol_error(tid, reason)`, `lootdrop_cache_fetched(...)`, `lootdrop_committed(...)` for funnel + error rate tracking。Plus dev-only: `session_evicted_by_browser()`, `persistence_volatile()`, `inflight_cap_breached()`, `logout_drain_timeout(pending)`, `cache_trimmed(removed)`, `persistence_quota_exhausted(key)`。 |
| 31 | SSE / Realtime Upgrade (v0.2 swap-in) | Polish | v0.2 | Will implement `IGymSysTransport` interface (defined in Section C — `request_workout_state()`, `set_session_token()`, `pause()`, `resume()`, plus 3 signals `raw_state_received` / `transport_error` / `auth_invalidated`)。GymSysClient facade unchanged。#9 同 #14 等 consumer 唔知 transport 變咗。**Provisional swap-in contract**: 當 #31 GDD 寫時 expect `IGymSysTransport` interface 可能需要 contract delta（e.g. backpressure signal for SSE bursty events）— defer to #31 authoring。 |

### Bidirectional Consistency Check

呢度列出嘅 dependents 必須喺自己嘅 GDD 寫 "depends on: #2 GymSys Backend Client"。當以下 GDD 寫成時，需要 cross-check：

- **#1 GameStateMachine ✓** — 已 written (Approved 2026-05-25)；Decision #3 + #4 + Rule 2 step 6 + Rule 5 priority 0 全部 locked 對應本 GDD Section C 內容。No reciprocity gap。
- **#3 PersistenceLayer** (Not Started — next priority after this GDD per active.md) — 必須引用 `IPersistence.read() / write(key, value) / delete(key) / migrate(from, to)` 同 ADR-006 Contract 4 sync-read 契約。
- **#9 Workout State Tracker** (Not Started) — 必須引用 7-signal typed contract (`workout_started`, `set_logged`, `rest_started`, `rest_ended`, `workout_completed`, `poll_failed`, `poll_recovered`)。
- **#18 PR Detection** (Not Started) — 必須引用 `set_logged` payload schema (`exercise_id: String`, `reps: int`, `weight: float`)。
- **#20 Gym-Mode HUD ✓** — written (Approved 2026-06-03; implemented 2026-06-04, PR #17)。`WorkoutAudioAdapter` subscribes `set_logged` for **SFX-trigger ONLY** (audio enhancement layer, GSM-state-gated, no `transition_id` needed — server single-flight monotonic dedup suffices)。Count / EXP visual use the #9-validated path, NEVER raw `set_logged` (anti-fabrication — Silent Witness must not fabricate; EG-1 relocation from #4 Audio)。Also subscribes `poll_failed`。**Resolves Q-OQ5 (#20 set_logged subscriber reciprocity) + Q-X9。**
- **#24 Login / GymSys Connection UI** (Not Started) — 必須引用 `claim_session(username, password) -> SessionClaimResult` API + `auth_required()` signal + `clear_session_token()` API + logout drain procedure。
- **#28 Telemetry** (Not Started) — 必須引用 13 telemetry signals (6 main + 7 dev/edge)。
- **#31 SSE / Realtime Upgrade** (v0.2, Not Started) — 必須 implement `IGymSysTransport` interface 完整。

**Provisional lock note**: 全部 cross-system contracts (signal signatures, API surface, key schema) 喺 reciprocal GDDs 未寫前 unilaterally locked from this side. Defer to reciprocal-GDD authoring; revisit at `/review-all-gdds` pass.

### ADR binding

**ADR-006 State Machine Contract** (Accepted 2026-05-28) — 5 Contracts directly bind this GDD：
- C2: `transition_id` opaque format — we receive parent tid from #1, append per-endpoint suffix (Rule 9)
- C4: Autoload position 4 ordering — we run `_ready()` AFTER PersistenceLayer (pos 1), GameStateMachine (pos 2), PlatformDetect (pos 3) (F-SYNC-2 sync 2026-05-28; was generic "3+" range)
- C5: `process_frame.connect(... CONNECT_ONE_SHOT)` idiom for follow-up state work (Rule 4 step 5)
- C11: VS tier no IDB fence — we don't `await` writes through IPersistence
- C15: server-authoritative `pending_since_server` — surfaced through `lootdrop_cache_fetched` signal

**ADR-002 GymSys Integration Protocol** (NOT YET WRITTEN — to be authored from this GDD as input scope) — will lock：
- Endpoint shapes (`POST /session/claim`, `POST /lootdrop/{tid}/cache`, `GET /lootdrop/{tid}/cache`, `POST /lootdrop/{tid}/commit`, `GET /api/game/state`)
- Backend schema (`accounts.active_session_token`, `lootdrop_cache(transition_id PK, account_id, payload JSON, pending_since_server INT, committed_at INT NULL)`)
- studiosys cookie-middleware carve-out on `/api/game/*` routes (per X-Session-Token only decision)
- 37-day `lootdrop_cache` retention cron (per Contract 15)
- `X-Protocol-Version` versioning policy
- TLS posture (real CA cert via reverse proxy)
- CORS posture (same-origin via reverse proxy — Q1 deployment topology)

**ADR-004 CORS / Cross-Origin Auth Topology** (NOT YET WRITTEN) — will lock deployment topology decision behind which ADR-002 endpoint shapes resolve。本 GDD 假設 same-origin via reverse proxy；若 ADR-004 lands 不同 → Rule 8 header strategy + Rule 10 disambiguation table may need minor amendment。

## Tuning Knobs

所有時間單位以秒為準（除非另外註明）。每個 knob 列：default、safe range、太低嘅後果、太高嘅後果。

### Owned by GymSys Backend Client

| Knob | Default | Safe Range | Too Low | Too High |
|------|---------|------------|---------|----------|
| `POLL_JITTER_SECONDS` (Formula 1 input — Section D) | 0.5s | **0.0 .. 0.5** | 0 = disable jitter；單客 OK 但多客同時開 app 會 cluster-hit backend P95 spike | > 0.5 → 跨 `POLL_TIMEOUT_SECONDS + 0.5` margin → 違反 jitter invariant → single-flight 失保 |
| `POLL_TIMEOUT_SECONDS` | 4.0s | **2.0 .. 4.0** (tightened per design-review 2026-05-26 to honor Invariant #1 unconditionally) | < 2.0 → 慢 cellular 真實 RTT 都超時 → 永遠 transport-failure path 觸發 → backend 健全但玩家見 Disconnected | > 4.0 → next-tick fire 時上 tick 仍 inflight → single-flight skip 過多 → 玩家 perceive 為「stuck on idle」（5s 內冇 update）；且若 `POLL_JITTER` 同時 = 0.5 → Invariant #1 boot assert crash |
| `WRITE_TIMEOUT_SECONDS` | 10.0s | 5.0 .. 30.0 | < 5.0 → mobile cellular state-write under load 容易超時 → 假 transport-failure → Rule 12 retry 暴增 cost | > 30.0 → 真 hang 嘅 request 霸佔 inflight slot 過長 → MAX_INFLIGHT 對其他 channel 失效 |
| `MAX_INFLIGHT_REQUESTS` | 4 | **2 .. 6** (browser per-origin connection cap = 6 hard upper) | < 2 → state-write + loot-cache + poll 不能並行 → loot ritual 被 commit 嘅 inflight 卡住 → Pillar 3 ritual hiccup | > 6 → 違反 browser default 6-connection-per-origin cap → extras silently queue 喺 fetch layer → Godot 唔知有 stall |
| `MAX_5XX_RETRY_ATTEMPTS` | 5 | 3 .. 10 | < 3 → 真 server 短暫 5xx (e.g. deploy restart 5s) 即跌入 Disconnected → 玩家 perceived 為「app 死咗」| > 10 → 真 server 長期 down 時 silently keep retrying 太耐 → user 唔知道應該手動 retry / re-login |
| `SESSION_CLAIM_RETRY_LIMIT` (client-side enforce, GDD #1 read-only reference) | 3 | 1 .. 10 | 1 → short network race / 短 5xx 就 escalate 到 `auth_required()` → false-positive re-login prompt | > 10 → race 真係解決唔到時無 escalation → user stuck silent failure (per GDD #1 Tuning Knobs note) |
| `COMMITTED_TOMBSTONE_RETENTION_DAYS` (replaces `MAX_COMMITTED_CACHE_ENTRIES` per design-review 2026-05-26) | 35d | 14 .. 90 | < 14 → 玩家 7-13 日 inactive 後返嚟，evicted tombstone + late 200 → re-fire `lootdrop_committed` → Pillar 3 double-ritual | > 90 → IndexedDB 累積 tombstone entries (~30 commits/day × 90 = 2700 × 72 bytes ≈ 200 KB) — 仍細，但已超出 ADR-006 Contract 15 嘅 37d 後端 retention → tombstone hits 對應 backend 已 pruned 嘅 row → 無意義保留 |
| `MAX_KNOWN_VERSION` (NEW 2026-05-26 per design-review P0-7) | 1 | 1 .. 8 | < 1 → impossible (lower bound is current protocol baseline) | > 8 → arbitrary cap; bumping requires ADR-002 amendment + new normalize functions for each version |

### Read-only by GymSys Backend Client (owned elsewhere — referenced for context)

| Knob | Owner GDD | Why GymSys Client cares |
|------|-----------|------------------------|
| `GYMSYS_POLL_INTERVAL_SECONDS` (default 5.0s) | game-concept (locked at concept stage) | 決定 polling cadence；jitter formula input；Pillar 2 frictionless 邏輯依此 cost 計算 |
| `BASE_DELAY` (default 1.0s) | #1 GameStateMachine (Formula 1) | Disconnected retry backoff base — we EXECUTE the sleep with this value |
| `RETRY_CAP` (default 16.0s) | #1 GameStateMachine (Formula 1) | Disconnected retry backoff cap — we EXECUTE the sleep capped at this value |
| `SESSION_TOKEN_TTL_HOURS` (default 720 = 30d) | #1 GameStateMachine (Decision #4) | Backend-side TTL；client 唔 enforce 但須容忍 server-side expiry → 401 standard latch path |
| `LOOTDROP_PENDING_HARD_CAP_DAYS` (default 30d) | #1 GameStateMachine (Decision #1) | Influences backend `lootdrop_cache` retention cron (37d = 30 + 7 buffer per Contract 15) |
| `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` (default 300s) | #1 GameStateMachine (ADR-006 Contract 9) | If client clock drifts > tolerance from server `server_time`, log via `protocol_error("clock_skew_5min")` |

### Knobs explicitly NOT exposed (compile-time constants)

- **`BACKEND_BASE_URL`** — deployment-time config, NOT runtime knob。Source: build-time environment variable / config file。Pending ADR-004 same-origin deployment lock。
- **Header field names** (`X-Session-Token`, `X-Transition-Id`, `X-Protocol-Version`) — protocol contract, lock at ADR-002 ratification。
- **Endpoint URL paths** (`/api/game/state`, `/session/claim`, `/lootdrop/{tid}/cache`, etc.) — protocol contract, lock at ADR-002。
- **transition_id child suffix list** (`:state`, `:loot-cache`, `:loot-commit`) — protocol contract (Rule 9 binding), lock here。
- **Internal substate enum** — schema, change = migration not tuning。

### Tuning Knob Interaction Warnings (cross-knob invariants)

| # | Invariant | At defaults | At worst safe boundary | Why |
|---|-----------|-------------|------------------------|-----|
| 1 | `GYMSYS_POLL_INTERVAL_SECONDS - POLL_JITTER_SECONDS ≥ POLL_TIMEOUT_SECONDS + 0.5` (Section D Formula 1 precondition) | 5.0 - 0.5 = 4.5 ≥ 4.0 + 0.5 = 4.5 ✓ (tight equality at default — both knobs at safe upper bound) | `POLL_JITTER = 0.5` AND `POLL_TIMEOUT = 4.0` → 4.5 ≥ 4.5 ✓ (safe range tightened 2026-05-26 to guarantee invariant unconditionally) | Single-flight margin — jitter can't drag interval below timeout |
| 2 | `POLL_TIMEOUT_SECONDS < GYMSYS_POLL_INTERVAL_SECONDS` (strict <) | 4.0 < 5.0 ✓ | `POLL_TIMEOUT = 4.0 < 5.0` ✓ | Timeout 必須 trigger 喺 next-tick fire 之前，否則 single-flight skip 永遠 hold lock |
| 3 | `WRITE_TIMEOUT_SECONDS > POLL_TIMEOUT_SECONDS` (writes need more headroom — backend write path slower than read) | 10.0 > 4.0 ✓ | `WRITE_TIMEOUT = 5.0 > 4.0 = POLL_TIMEOUT` ✓ | State writes (incl. LootDrop commit) tolerate longer RTT than reads — backend writes touch DB |
| 4 | `MAX_5XX_RETRY_ATTEMPTS × max(retry_delay) ≤ 60s` (perceived recovery window) | 5 × 16 = 80s ✗ at defaults — accept policy: user sees "Disconnected" UI before final give-up | 3 × 16 = 48s ✓ | Soft constraint — 玩家 patience 對 generic "reconnecting" UI > 60s 開始懷疑 app 死咗 |
| 5 | `MAX_INFLIGHT_REQUESTS ≤ 6` (browser default per-origin concurrent connection cap) | 4 ≤ 6 ✓ | 6 ≤ 6 ✓ (safe range upper bound) | Browser fetch 內部 queue extras — Godot 唔知道 → debugger 看 4 inflight 但實際只 6 hit network |
| 6 | `SESSION_CLAIM_RETRY_LIMIT × WRITE_TIMEOUT_SECONDS ≤ 60s` (re-login window) | 3 × 10 = 30s ✓ | 10 × 30 = 300s ✗ → 5 分鐘 silent retry stall | User patience for "logging in" UI ~30-60s |

**Safe range derivations**:
- `POLL_TIMEOUT_SECONDS` upper bound = `GYMSYS_POLL_INTERVAL_SECONDS - POLL_JITTER_SECONDS - 0.5 = 5.0 - 0.5 - 0.5 = 4.0` at maximum jitter — declared safe range tightened **2026-05-26** from `2.0 .. 4.5` → `2.0 .. 4.0` to honor Invariant #1 unconditionally (no footnote escape). Default 4.0 sits at safe ceiling regardless of `POLL_JITTER_SECONDS` value within its own safe range.
- `MAX_INFLIGHT_REQUESTS` upper hard cap = 6 (browser per-origin limit) — declared range tightened to **2 .. 6** (above).

## Visual/Audio Requirements

N/A — pure infrastructure. Network operations have no visual / audio surface. All player-facing reactions to network state (e.g. "Disconnected" overlay, "Reconnecting…" spinner) are owned by downstream UI systems (#20 Gym-Mode HUD, #24 Login UI) which subscribe to GameStateMachine signals derived from this client's events.

## UI Requirements

N/A — pure infrastructure. This system exposes typed signals + a small public API surface (`fetch_workout_state()`, `claim_session()`, etc.) consumed by other systems. UI surfaces (login screen, reconnection toasts, session-invalidated banners) are owned elsewhere — see #24 Login / GymSys Connection UI.

## Acceptance Criteria

全部 30 ACs 用 Given-When-Then 格式。Test type: Unit / Integration / Static / Manual。Evidence path：`tests/unit/gymsys-client/`、`tests/integration/gymsys-client/`、`tools/ci/`（架構靜態檢查）。

**Test infrastructure preconditions** (extends GDD #1 ADR-006 Contract 14 Test Spy Contract):

- `GymSysClient` autoload 接受 constructor injection (`new(http_factory: IHTTPFactory = ProductionHTTPFactory.new(), persistence: IPersistence = ProductionPersistence.new(), clock: IClock = SystemClock.new())`)
- `IHTTPFactory` interface — mock spawns trackable `MockHTTPRequest` nodes; allow per-test response injection (result, response_code, body, headers, Retry-After)
- `MockHTTPRequest.attach_spawn_spy(Callable)` + `attach_cancel_spy(Callable)` + `attach_queue_free_spy(Callable)` per Contract 14 naming
- `IClock.advance(seconds)` — controlled time advance for jitter / retry timer tests
- `MockHeadersCapture` records `(url, method, headers_dict, body_string)` per request — used by AC-09 / AC-10
- All 13 typed signals + 7 dev-only telemetry signals — verifiable via `get_signal_list()` introspection (AC-28)
- Test seams: `_test_get_inflight_count() -> int`, `_test_get_session_epoch() -> int`, `_test_is_token_latched() -> bool`, `_test_get_substate() -> String` — guarded by `OS.is_debug_build()`；production no-op

### Core Rule Enforcement (Rules 1-15)

- **AC-01** (Rule 1 polling + lifecycle suppression): **GIVEN** client `_substate == "Polling"` AND mock `GameStateMachine.state_changed("workout_active", "suspended", payload)` fired, **WHEN** event handler runs, **THEN** internal poll timer paused (`_poll_timer.is_paused() == true`)；mock IClock advanced by `GYMSYS_POLL_INTERVAL_SECONDS` → mock HTTPRequest spawn spy call count unchanged from pre-suspend baseline.
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_polling_suspends_on_state_changed.gd`
- **AC-02** (Rule 1 binding — no JavaScriptBridge calls of any kind — revised 2026-05-26): **GIVEN** all `.gd` files under `src/core/networking/`, **WHEN** CI script `tools/ci/check_no_javascriptbridge.sh` greps for `JavaScriptBridge.eval`, **THEN** zero matches total。Chrome Incognito quota detection switched to reactive path via `IPersistence.write → false` failure (Edge Case Resource & Storage)。
  - **Test type**: Static / CI | **Evidence**: `tools/ci/check_no_javascriptbridge.sh`
- **AC-03** (Rule 2 single-flight poll skip): **GIVEN** mock prior poll HTTPRequest in flight (unanswered), **WHEN** mock IClock advances `actual_poll_interval` → poll timer fires, **THEN** `MockHTTPRequest.spawn_spy.call_count == 1` (not 2)；`dropped_poll_tick("prior_inflight")` emit count == 1.
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_single_flight_poll_skip.gd`
- **AC-04** (Rule 3 inflight cap enforced — qa-lead rewrite): **GIVEN** mock 5 transitions enqueued in same frame (1 poll + 4 state_writes via fire-and-forget callbacks), **WHEN** dispatcher runs, **THEN** `_test_get_inflight_count() <= MAX_INFLIGHT_REQUESTS = 4` assertion sampled (a) after each `enqueue()` call returns, (b) after each `_process` tick within a 5-frame observation window；5th request remains queued (not dispatched) until one inflight resolves。
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_inflight_cap_enforced.gd`
- **AC-05** (Rule 4 orphan HTTPRequest pattern — static, 10-line window): **GIVEN** all `.gd` files under `src/core/networking/`, **WHEN** CI AST check runs, **THEN** every `HTTPRequest.new()` call site is followed within same function body by (a) `.timeout = <non-zero>` assignment, (b) `.request_completed.connect(..., CONNECT_ONE_SHOT)` call, (c) `add_child(...)` call — all 3 must occur within 10 source lines AND within same `func` scope。
  - **Test type**: Static / CI | **Evidence**: `tools/ci/check_httprequest_pattern.sh`
- **AC-06** (Rule 5 typed signal normalization — extra-field assert): **GIVEN** mock backend response `{"event": "rest_started", "duration_seconds": 90, "extra_field": "ignored", "another_extra": 42}`, **WHEN** `_normalize_rest_started` runs, **THEN** `rest_started.emit(duration_seconds: 90)` exactly once；signal payload introspection confirms args = `[90]` (1 element, NOT Dictionary)；`extra_field` / `another_extra` NOT present in any subsequent signal emission for this response cycle。
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_signal_typed_normalization.gd`
- **AC-07** (Rule 6 session token persistence path): **GIVEN** `IPersistence.attach_write_spy(write_log.append)` + `MockFileAccess.attach_open_spy(file_log.append)`, **WHEN** `set_session_token("test_token_abc")` called, **THEN** `write_log[-1] == {"key": "session_token", "value": "test_token_abc"}`；`file_log.size() == 0` (NO direct FileAccess from client)。
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_session_token_via_persistence.gd`
- **AC-08** (Rule 7 AwaitingAuth at empty token — deterministic outcome): **GIVEN** mock `IPersistence.read()` returns `{}` (no `session_token` key), **WHEN** autoload `_ready()` completes, **THEN** `_test_get_substate() == "AwaitingAuth"`；`_poll_timer == null` (timer not constructed at all when in AwaitingAuth)；`auth_required()` signal emit count == 1.
  - **Test type**: Integration | **Evidence**: `tests/integration/gymsys-client/test_awaiting_auth_at_boot.gd`
- **AC-09** (Rule 8 header presence + forbidden enumeration): **GIVEN** mock client `_substate == "Polling"` with `_session_token = "tk_X"`, **WHEN** state-write callback `write_state_transition("tx_123", "idle", "workout_active", {})` fired, **THEN** `MockHeadersCapture[-1].headers` 含 `X-Session-Token: tk_X`, `X-Protocol-Version: 1`, `X-Transition-Id: tx_123:state`；同時不含 `Authorization`, `Cookie`, `X-Api-Key`, `X-Auth-Token`（forbidden header set assertion）。
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_request_headers.gd`
- **AC-10** (Rule 9 transition_id child suffix): **GIVEN** parent `transition_id = "1748212345_42_idle_workout_active"`, **WHEN** state-write, loot-cache (POST), loot-cache (GET), loot-commit dispatchers fire 各一次, **THEN** `MockHeadersCapture` records `X-Transition-Id` 分別 = `1748212345_42_idle_workout_active:state`, `1748212345_42_idle_workout_active:loot-cache` (POST), `1748212345_42_idle_workout_active:loot-cache` (GET — same key), `1748212345_42_idle_workout_active:loot-commit`.
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_tid_child_suffix.gd`
- **AC-11** (Rule 10 disambiguation matrix — parameterised 9-row table): **GIVEN** mock `MockHTTPRequest.inject_response(result, response_code, body)` per Rule 10 table, **WHEN** each `_dispatch_response` runs, **THEN** matrix outcomes：(RESULT_SUCCESS, 401) → `session_invalidated()` emit == 1；(RESULT_SUCCESS, 409) → `lootdrop_cache_fetched(...)` triggered (canonical fetch path), `session_invalidated()` emit == 0；(RESULT_SUCCESS, 429+Retry-After: 30) → all channels pause for 30s；(RESULT_CANT_CONNECT, 0) → `poll_failed("cors_or_network")` emit == 1, `session_invalidated()` emit == 0；(RESULT_SUCCESS, 5xx) → Rule 12 retry timer scheduled；(RESULT_SUCCESS, 4xx ≠ 401/408/409/429) → `protocol_error(...)` emit == 1, no retry。
  - **Test type**: Unit (table-driven, 9 cases) | **Evidence**: `tests/unit/gymsys-client/test_response_classification_matrix.gd`
- **AC-12** (Rule 11 401 latch single-emit): **GIVEN** 4 inflight requests + mock injects first 401 response, **WHEN** all 4 `request_completed` signals fire over multiple frames (3 後續 cancelled-mid-flight returns), **THEN** `session_invalidated()` emit count == 1 across entire scenario；`_test_is_token_latched() == true`；`MockHTTPRequest.cancel_spy.call_count == 3` (cancel called on 3 siblings)；all 4 `MockHTTPRequest.queue_free_spy.call_count == 4`。
  - **Test type**: Integration | **Evidence**: `tests/integration/gymsys-client/test_401_burst_storm_dedupe.gd`
- **AC-13** (Rule 12 retry matrix — parameterised): **GIVEN** mock response per Rule 12 9-row table, **WHEN** dispatch handler classifies, **THEN** retry timer state asserted per row：(RESULT_SUCCESS, 5xx) → `_retry_timer.wait_time == retry_delay(n)` (formula output)；(RESULT_SUCCESS, 4xx ≠ 401/408/409/429) → `_retry_timer == null` (no retry scheduled), `protocol_error(...)` emit == 1；(RESULT_SUCCESS, 408) → first retry immediate (`_retry_timer.wait_time == 0.0`)；(RESULT_SUCCESS, 429+Retry-After: 30) → `_retry_timer.wait_time == 30.0` (NOT formula)。
  - **Test type**: Unit (table-driven) | **Evidence**: `tests/unit/gymsys-client/test_retry_matrix.gd`
- **AC-14** (Rule 13 timeout non-zero — static): **GIVEN** all `.gd` files under `src/core/networking/`, **WHEN** CI grep检索 `\.timeout\s*=\s*0\.0?\b`, **THEN** zero matches；同 `HTTPRequest.new()` 同 file 內每個 occurrence 必須有對應 `.timeout = <positive_float>` 同 function scope，within 10 source lines。
  - **Test type**: Static / CI | **Evidence**: `tools/ci/check_no_zero_timeout.sh`
- **AC-15** (Rule 14 bfcache cleanup contract): **GIVEN** 4 inflight requests + mock `GameStateMachine.state_changed.emit("workout_active", "suspended", payload)`, **WHEN** handler runs, **THEN** `MockHTTPRequest.cancel_spy.call_count == 4`；`MockHTTPRequest.queue_free_spy.call_count == 4` (deferred)；`_test_get_inflight_count() == 0`；subsequent `request_completed` from those 4 orphans (held ≥2 frames post-handler) → no signal emission (all swallowed)。
  - **Test type**: Integration | **Evidence**: `tests/integration/gymsys-client/test_bfcache_cleanup.gd`
- **AC-16** (Rule 15 commit tombstone dedupe — revised 2026-05-26): **GIVEN** `<tid>:loot-commit = "1748212345_42_loot_drop_idle:loot-commit"` 已 in `_committed_tombstones` with `committed_at = 1748212345`, **WHEN** same `<tid>:loot-commit` 200 response arrives 第二次 (same byte content as first), **THEN** `lootdrop_committed` signal emit count stays at 1 (cumulative, NOT 2)；tombstone entry unchanged。**AND additionally**: **GIVEN** same tombstone entry, **WHEN** same tid 200 arrives 第二次 BUT response body byte-不等 first response, **THEN** `protocol_error("idempotent_commit_response_drift", tid)` emit count == 1 + `lootdrop_committed` still NOT emitted。
  - **Test type**: Unit (2 sub-cases) | **Evidence**: `tests/unit/gymsys-client/test_commit_tombstone_dedupe.gd`

### Formula

- **AC-17** (Formula 1 jitter range — qa-lead rewrite for determinism): **GIVEN** `GYMSYS_POLL_INTERVAL_SECONDS = 5.0` AND `POLL_JITTER_SECONDS = 0.5` AND `seed(42)` (deterministic RNG), **WHEN** 1000 samples of `actual_poll_interval` collected, **THEN** all 1000 samples ∈ `[4.5, 5.5]`；statistical mean ∈ `[4.90, 5.10]` (loose tolerance — avoid CI flake)；first 10 samples 同 fixed-seed expected sequence 完全一致 (deterministic verification).
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_jitter_formula_range.gd`
- **AC-25** NEW (Formula 1 per-cycle resample — qa-lead gap): **GIVEN** mock IClock advances 5 consecutive poll intervals, **WHEN** internal `actual_poll_interval` value captured per cycle, **THEN** 5 values pairwise distinct (mathematically guaranteed by float jitter — assert via `len(unique(samples)) == 5`)；jitter NOT fixed at boot。
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_jitter_resamples_per_cycle.gd`

### Edge Case Coverage

- **AC-18** (Edge: non-blocking logout drain — Pillar 2 protection — revised 2026-05-26): **GIVEN** 2 inflight `loot-commit` + 1 inflight `poll` + mock `client.clear_session_token(ClearTokenReason.USER_EXPLICIT)` called, **WHEN** API invoked, **THEN**: (a) call returns within 1 process frame (sentinel pattern: pre/post tick-id captured, must match); (b) `_test_get_substate() == "Draining"` immediately post-call; (c) `drain_started.emit(pending_commits: 2)` signal emit count == 1; (d) poll channel `cancel_request` 即時 called; (e) commit channel inflight NOT cancelled — both complete naturally; (f) attempted new `cache_lootdrop()` during Draining → `drain_in_progress(rejected_tid)` emit + request NOT dispatched; (g) when both commits resolve → `drain_completed(committed_count: 2, timeout_count: 0)` emit + `_test_get_substate() == "AwaitingAuth"` + `auth_required()` emit == 1. **CI static check**: `tools/ci/check_clear_session_token_sync_return.sh` — function `clear_session_token` body contains ZERO `await` keywords.
  - **Test type**: Integration + Static / CI | **Evidence**: `tests/integration/gymsys-client/test_logout_drain_nonblocking.gd` + `tools/ci/check_clear_session_token_sync_return.sh`
- **AC-19** (Edge: _session_epoch — stale response swallow): **GIVEN** request A dispatched with `_session_epoch = 5`, then `clear_session_token() + claim_session(...)` brings new epoch 6, **WHEN** request A's response arrives, **THEN** handler reads request A's tagged epoch (5) vs current `_session_epoch` (6) → swallow；no `workout_started` / other signal emission；inventory state unchanged。
  - **Test type**: Integration | **Evidence**: `tests/integration/gymsys-client/test_session_epoch_swallow_stale.gd`
- **AC-20** (Edge: DST / monotonic clock discipline — static): **GIVEN** static analyzer scans `src/core/networking/**/*.gd`, **WHEN** CI grep `Time\.get_unix_time_from_system`, **THEN** matches limited to ONLY `_build_transition_id_timestamp_prefix()` function (file `gymsys_client.gd` whitelist)；任何其他用 (scheduling / retry / jitter timer paths) → CI fail。
  - **Test type**: Static / CI | **Evidence**: `tools/ci/check_monotonic_discipline.sh`
- **AC-21** (Edge: protocol drift fallback — `rest_started` missing duration_seconds): **GIVEN** mock backend response `{"event": "rest_started"}` (missing field), **WHEN** `_normalize_rest_started` runs, **THEN** `rest_started.emit(90)` (fallback `REST_PERIOD_FALLBACK_SECONDS`)；`protocol_error("missing_field_duration_seconds")` emit == 1；signal NOT silently dropped。
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_protocol_drift_fallback.gd`
- **AC-22** (Edge: clock skew >5min detection): **GIVEN** mock server response with `server_time = T0` AND `MockClock.unix_time = T0 + 600` (10 min skew), **WHEN** response handler processes payload, **THEN** `protocol_error("clock_skew_5min", details)` emit == 1；assert client wall-clock NOT modified (no calls to `OS.set_*` or any clock-mutation API via spy)；`workout_completed` signal payload uses backend `completed_at` verbatim (NOT client `Time.get_unix_time_from_system()`).
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_clock_skew_detection.gd`

### Cross-System Contracts

- **AC-23** (Cross-system: GSM dual-target write callback fire-and-forget — qa-lead rewrite with sentinel + static): **GIVEN** mock GSM calls `client.write_state_transition("tx_X", "idle", "workout_active", payload)`, **WHEN** function entry sentinel set `_test_fire_and_forget_entered = true` + function exit sentinel set `_test_fire_and_forget_returned = true`, **THEN** both sentinels set within same `_process` tick (verified via tick-id capture pre/post)；AND static CI check: function `write_state_transition` body contains ZERO `await` keywords (grep)；`MockHTTPRequest.spawn_spy.call_count == 1` post-return。
  - **Test type**: Unit + Static / CI | **Evidence**: `tests/unit/gymsys-client/test_dual_target_fire_and_forget.gd` + `tools/ci/check_no_await_in_write_state_transition.sh`
- **AC-24** (Cross-system: GSM subscription pattern — ADR-006 Contract 6): **GIVEN** GymSysClient autoload `_ready()` runs, **WHEN** subscription wire-up checked at end of `_ready()`, **THEN** runtime spy on `GameStateMachine.connect_for_initial_state` confirms call count == 1 with Callable target `_on_gsm_state_changed`；static CI check：`gymsys_client.gd` contains zero matches for `GameStateMachine.state_changed.connect` literal (only `connect_for_initial_state` allowed)；`_on_gsm_state_changed` Callable NOT created with `.bind(...)` (static grep `connect_for_initial_state.*\.bind\(` returns 0 matches)。
  - **Test type**: Integration + Static / CI | **Evidence**: `tests/integration/gymsys-client/test_gsm_subscription_pattern.gd` + `tools/ci/check_connect_for_initial_state_pattern.sh`

### NEW ACs (qa-lead gap-find — AC-26 through AC-30)

- **AC-26** NEW (FSM 6-substate transitions exhaustive — revised 2026-05-26 per design-review P0-5): **GIVEN** mock GymSysClient instantiated separately for each of 6 substates (Initialising/AwaitingAuth/Polling/Backoff/Suspended/Draining), **WHEN** test driver triggers ALL 36 cells of the 6×6 transition matrix (per Section C "Full 6×6 Transition Matrix" table), **THEN**: (a) every legal cell (6 self-loops + ~17 cross-state transitions per matrix) emits `substate_changed(from: String, to: String)` signal exactly once + post-condition `_test_get_substate() == to`; (b) every illegal cell (~13 `—` marked cells) emits `dropped_event(from, to, reason)` signal + post-condition `_test_get_substate() == from` (unchanged); (c) test seam `_test_get_substate_history() -> Array[String]` returns the full ordered transition log for assertion。Sub-assertions specifically named per Cells 1/2/3 resolved at design-review:
  - **Cell 1** (AwaitingAuth → Suspended): `state_changed("workout_active", "suspended", payload)` during AwaitingAuth → claim_session inflight HTTPRequest cancel_spy count == 1; persisted IPersistence write_spy count == 0 (no credentials stored)
  - **Cell 2** (Backoff → AwaitingAuth): next retry attempt returns (RESULT_SUCCESS, 401) during Backoff substate → Rule 11 latch fires + pending retry timer's `_test_get_retry_timer_active() == false` (cancelled) + transition directly to AwaitingAuth (NOT via Polling — verify `_test_get_substate_history()[-2:] == ["Backoff", "AwaitingAuth"]`)
  - **Cell 3** (Backoff → Suspended): `state_changed → Suspended` during Backoff with `_test_get_retry_n() == 4` → on resume `_test_get_retry_n() == 1` (reset, not preserved) + first poll fires fresh
  - **Test type**: Integration (table-driven, 36 cells) | **Evidence**: `tests/integration/gymsys-client/test_substate_transitions_matrix.gd`
- **AC-27** NEW (Rule 12 retry cap upper bound): **GIVEN** mock 8 consecutive 5xx responses + `RETRY_CAP = 16.0`, **WHEN** Rule 12 retry timer fires, **THEN** `retry_delay(n)` clamped at 16.0 for n>=5；after `MAX_5XX_RETRY_ATTEMPTS = 5` exhausted → emit `poll_failed("retry_cap_exhausted")` + GSM transitions to `Disconnected` (mock spy on `state_changed` emit verifies)；no 6th retry attempted。
  - **Test type**: Integration | **Evidence**: `tests/integration/gymsys-client/test_retry_cap_exhaustion.gd`
- **AC-28** NEW (18 typed signals introspection): **GIVEN** GymSysClient autoload instantiated, **WHEN** `get_signal_list()` introspected, **THEN** all 18 declared signals present with exact signatures per Section C Rule 5 listing: the 7 locked workout signals (`workout_started: ()`, `set_logged: (exercise_id: String, reps: int, weight: float)`, `rest_started: (duration_seconds: int)`, `rest_ended: ()`, `workout_completed: (completed_at: int)`, `poll_failed: (category: PollFailureCategory)`, `poll_recovered: ()`); the 6 auxiliary signals (`session_invalidated: ()`, `auth_required: ()`, `lootdrop_cache_fetched: (transition_id: String, payload: Dictionary, pending_since_server: int)`, `dropped_poll_tick: (reason: String)`, `protocol_error: (transition_id: String, reason: String)`, `lootdrop_committed: (transition_id: String, canonical_inventory: Dictionary)`); the 2 drain signals (`drain_started: (pending_commits: int)`, `drain_completed: (committed_count: int, timeout_count: int)`); and the 3 FSM observability signals (`substate_changed: (from: String, to: String)`, `dropped_event: (from: String, to: String, reason: String)`, `drain_in_progress: (rejected_tid: String)`)；assert each signal name + arg count + arg type via introspection。
  - **Test type**: Unit | **Evidence**: `tests/unit/gymsys-client/test_signal_contract_introspection.gd`
- **AC-29** NEW (Edge: `clear_session_token()` re-entry during drain — revised 2026-05-26): **GIVEN** drain procedure in progress (2 commits inflight, `_substate == "Draining"`), **WHEN** second `clear_session_token(reason)` call fires within drain window, **THEN** second call returns immediately within 1 process frame；emit `drain_in_progress(rejected_tid: "")` debug signal；不 reset drain wall-clock；不 dispatch additional cancellation；inflight commit count unchanged (no double-cancel)。**AND additionally** (covers SESSION_KILLED race vs USER_EXPLICIT in-progress): **GIVEN** Draining substate active from prior USER_EXPLICIT call, **WHEN** Rule 11 fires `clear_session_token(SESSION_KILLED)` (e.g., concurrent 401 arrived) **THEN** SESSION_KILLED upgrades the drain — remaining inflight commits cancelled immediately (no further wait), transition to AwaitingAuth instantly。
  - **Test type**: Integration (2 sub-cases) | **Evidence**: `tests/integration/gymsys-client/test_logout_reentry_during_drain.gd`
- **AC-30** (ADR-006 Contract binding evidence — markers + tests — revised 2026-05-26): **GATE AC, runs AFTER AC-01..29 implementation** per design-review qa-lead P0-3。**GIVEN** GymSysClient source file `gymsys_client.gd` AND AC-01..29 implementations complete, **WHEN** CI scans for required ADR-006 binding markers + verifies corresponding test files exist, **THEN** comment markers present: `# ADR-006 Contract 2: transition_id opaque`, `# ADR-006 Contract 4: autoload position 3+`, `# ADR-006 Contract 5: process_frame.connect ONE_SHOT`, `# ADR-006 Contract 11: no IDB fence`, `# ADR-006 Contract 15: pending_since_server authoritative`；對應 5 contracts 每個有 matching test file existence check (e.g. `tests/unit/gymsys-client/test_adr006_contract_2_*.gd`)。
  - **Test type**: Static / CI (gate-only — last to run) | **Evidence**: `tools/ci/check_adr006_binding_markers.sh`
- **AC-31** NEW 2026-05-26 (Rule 8.1 confused-deputy defense — Pillar 1 anti-fabrication): **GIVEN** mock backend response 200 to POST state-write WITH `Set-Cookie: studiosys_session=xyz123; Path=/; HttpOnly` header AND outbound request was sent with `X-Session-Token: tk_X`, **WHEN** response handler classifies, **THEN**: (a) state NOT persisted (`MockPersistence.write_spy.call_count` for relevant key unchanged); (b) `protocol_error("server_reflected_cookie_auth", "/api/game/state")` emit count == 1; (c) `auth_required()` emit count == 1; (d) `_test_get_carve_out_latch() == true`; (e) subsequent state-write attempts → `protocol_error("carve_out_misconfig_blocked", ...)` emit + no dispatch; (f) calling `client.acknowledge_carve_out_fix()` admin API → `_test_get_carve_out_latch() == false` + next state-write dispatches normally。
  - **Test type**: Integration | **Evidence**: `tests/integration/gymsys-client/test_confused_deputy_defense.gd`

## Open Questions

呢度收集設計過程中發現需要 follow-up 嘅問題。每個 question 標 owner + suggested resolution。已解決嘅項目 strikethrough 並保留以審計。

| ID | Question | Owner | Status |
|----|----------|-------|--------|
| **Q-N1** | GymSys deployment topology (same-origin reverse proxy vs cross-origin direct)? Decision affects CORS preflight overhead + cookie middleware coexistence. | technical-director + producer | **DEFERRED to ADR-004 CORS / Cross-Origin Auth Topology**. 本 GDD 假設 same-origin via reverse proxy；若 ADR-004 lands cross-origin → Rule 8 header strategy + Rule 10 disambiguation table 需要 minor amendment |
| **Q-N2** | studiosys cookie middleware coexistence with `X-Session-Token` — 需要 backend route carve-out (`/api/game/*` skip cookie auth) 嗎？ | studiosys 維護者 (Frank) + technical-director | **OPEN — must lock at ADR-002 ratification**。本 GDD Section C Rule 8 假設 cookie middleware 已 carve out；若否 → confused-deputy 風險 (cookie + token 雙 auth surface) |
| **Q-N3** | PR detection server-side judging — real 1RM PR 觸發稀有 drop 嘅 判定 vs client-side derivation? | game-designer + #18 PR Detection owner + technical-director | **OPEN — game-concept Q3 carried forward**. 本 GDD 提供 `set_logged(exercise_id, reps, weight)` 嘅原始流，但 PR detection 邏輯由 #18 同 GymSys backend 共同 own — defer to #18 GDD + GymSys API extension ADR |
| **Q-A4** (carried from #1) | Godot 4.6 Web Export COOP/COEP threading default | engine-programmer | OPEN — VS spike 確認 export template thread support 預設狀態；若 enabled → Rule 2 single-flight invariant 需要 mutex / atomic primitives |
| **Q-A7** NEW | Godot 4.6 `HTTPRequest.cancel_request()` Web Export behavior — emit RESULT_CANCELED, RESULT_NO_RESPONSE, 還是 silently drop? Impacts Rule 11 cancel-siblings cleanup contract + Rule 14 bfcache cleanup contract. | engine-programmer + VS spike | **OPEN — VS spike scope addition**. Rule 11 implementation MUST treat 三種 outcomes 都係 acceptable post-cancel；assertion test 鎖定 actual 4.6 behavior 之後決定簡化 |
| **Q-A8** NEW | bfcache + in-flight HTTPRequest 互動 on Godot 4.6 Web Export — restored tab 嘅 pending fetch 點處理? | engine-programmer + VS spike | **OPEN — VS spike scope addition**. Rule 14 cleanup contract 喺 Suspended 入到時 cancel 所有 inflight，避免 zombie node leak — VS spike 量度實際 bfcache 行為 (是否 fetch 自動 abort、是否 response 仍 delivered post-restore 等) |
| **Q-A9** NEW | `HTTPRequest` fetch-shim API stability across 4.4-4.6 — release notes 對 HTTPRequest Web Export specifics 都 silent。 | engine-programmer + VS spike | **OPEN — combined with Q-A4 / Q-A7 / Q-A8 spike scope**. Verify `use_threads = true` 喺 Web 仍 silently ignored；redirect handling；response header access scope；POST body type (`String` vs `PackedByteArray`) preference |
| **Q-X4** (carried from #1) | Re-login UX after `auth_required` signal — modal? Toast + retry button? Auto-redirect to OAuth? | ux-designer + #24 owner | OPEN — 屬於 UX spec 範圍；client 只 emit signal + 維持 `AwaitingAuth` substate；UI surface 由 UX spec 定 |
| **Q-X5** NEW | Backend response shape for "no active workout" — 200 with empty body vs 200 with explicit `{idle: true}` envelope? Influences `_normalize_*` function logic + 「is idle a signal?」 design decision. | game-designer + GymSys backend 維護者 (Frank) | **OPEN — ADR-002 input scope**. 本 GDD Section E "Polling Edges" 假設 empty body = no-op (client 唔 emit signal)；若 backend 改 explicit envelope → 需要 8th signal `state_idle()` 或 reuse `poll_recovered()`。Defer to ADR-002 ratification |
| **Q-X6** NEW (#31 forward-compat) | `IGymSysTransport` interface 是否需要 backpressure signal for SSE bursty events? Polling 自然 throttle 喺 5s cadence，但 SSE 可能 push 多個 events 同 frame。 | network-programmer + #31 SSE GDD author | **OPEN — defer to #31 GDD**. 本 GDD Section C 定義 `IGymSysTransport` interface stub；當 #31 寫成時 expect contract delta；如需加 backpressure signal (e.g. `transport_buffer_full`) → 屬於 minor interface evolution |
| **Q-X7** NEW | `BACKEND_BASE_URL` 嘅 configuration mechanism — env var, build-time constant, or runtime config file? | engine-programmer + devops | **OPEN — defer to engine-setup / build pipeline phase**. 本 GDD 假設 build-time constant (per technical-preferences.md "constants UPPER_SNAKE_CASE")；若需 runtime config 需要 `IConfigProvider` interface addition |
| **Q-X8** NEW (Safari ITP follow-up) | If Safari ITP evicts `user://state.json` after 7d, `session_evicted_by_browser` signal emit + `AwaitingAuth` flow — 玩家 7+ 日唔 open game 嘅 returning-player ritual 由邊個 own? #29 Mirror Moment 嘅 returning-player flow (per GDD #1 Q-A6)? Or #24 Login UI? | game-designer + #29 owner + #24 owner | **OPEN — defer to #29 Mirror Moment GDD authoring**. 本 GDD 只 emit `session_evicted_by_browser` signal；ritual UX 由 consumer GDD 決定 |
| **Q-X9** NEW (CD-GDD-ALIGN Concern 1 cascade — Pillar 2 protection on #20 HUD): 5xx storm 31s "Reconnecting…" UI spinner 點 design 先唔違反 Pillar 2 mid-set attention anti-pillar? Creative-director gate 提出 binding constraint：spinner MUST be peripheral, ≤10% screen real estate, no gaze-drawing animation, no audio cue. | ux-designer + #20 Gym-Mode HUD owner | **OPEN — binding constraint on #20 Gym-Mode HUD GDD**. 本 GDD 唔 own UI surface；#20 GDD authoring 時必須 honour 呢個 constraint，否則 cascade violation 直接 Pillar 2 失守 |
| **Q-X10** NEW (CD-GDD-ALIGN Concern 2 cascade — Pillar 2 protection on #24 Login UI): Logout drain (10s wait per AC-18) 期間嘅 UX 點 handle? CD gate 建議兩個 acceptable design path：(a) background optimistic "Logged out" + silent drain；(b) "Confirm logout? Saving last drop…" prompt 只 fire post-workout (never mid-set)。 | ux-designer + #24 Login UI owner | **OPEN — binding constraint on #24 Login UI GDD**. 本 GDD 嘅 AC-18 drain procedure 唔 specify UX；#24 GDD 必須 close 呢個 question to avoid mid-set "Saving…" modal violating Pillar 2 |
| **Q-X11** NEW (CD-GDD-ALIGN Concern 3 cascade — Pillar 1 downstream binding for ADR-002): ADR-002 GymSys Integration Protocol 必須 enforce backend UNIQUE constraint on `transition_id` (per Rule 9 child suffixes) + server-authoritative LootDrop commit semantics (per Contract 15) — Pillar 1 anti-fabrication promise 全靠 ADR-002 真正 deliver。 | technical-director (ADR-002 author) | **DOWNSTREAM BINDING** — flag for ADR-002 ratification gate (TD-ARCHITECTURE). 本 GDD 嘅 Pillar 1 technical embodiment 由 ADR-002 真正 lock；ADR-002 gate review 必須 verify backend schema 真係 enforce 兩個 invariants |

**Resolution gating**:
- **Q-N1 + Q-N2 + Q-X5** 必須喺 ADR-002 GymSys Integration Protocol 寫成之前 close (ADR-002 inherits decisions)
- **Q-N3** 必須喺 #18 PR Detection GDD 寫成之前 close
- **Q-A4 / Q-A7 / Q-A8 / Q-A9** 全部合併入 VS spike scope (Q-A4 already queued)，VS implementation 開始之前 close
- **Q-X4** 喺 UX spec authoring 期間 close (VS 前)
- **Q-X6** 喺 #31 SSE GDD authoring (v0.2 tier) 期間 close
- **Q-X7** 喺 build pipeline / engine setup phase close
- **Q-X8** 喺 #29 Mirror Moment GDD authoring 期間 close
- **Q-X9 + Q-X10** 喺各自 #20 / #24 GDD authoring 期間 close (CD-GDD-ALIGN cascading constraints)
- **Q-X11** 喺 ADR-002 GymSys Integration Protocol ratification gate close (downstream Pillar 1 binding)
