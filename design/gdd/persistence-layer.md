# PersistenceLayer

> **Status**: Approved — 2026-05-26 (design-review Pass 2: all 11 P0 blockers resolved)
> **Author**: Frank + systems-designer + creative-director (Section B framing only)
> **Last Updated**: 2026-05-26
> **Implements Pillar**: Pillar 3 (Drop Euphoria hard guarantee — tombstone persistence) + Pillar 1 (anti-fabrication architectural posture — server-authoritative state cache durability)
> **System #**: 3 (Foundation / VS tier)
> **Depends On**: (none — Foundation leaf-edge; autoload position 1)
> **Depended On By**: #1 GameStateMachine (★ hard, autoload position 2 calls `read()` sync at boot), #2 GymSys Backend Client (3 keys), #8 Streak, #9 Workout State Tracker, #10 Exercise→Class Mapping, #11 Stat System, #12 Ability, #15 Loot Drop, #17 Equipment, #18 PR Detection, #19 Zone
> **Governing ADRs**: ADR-006 State Machine Contract (RATIFIED 2026-05-25, Status: Proposed) — binds Contracts 3 (SerializableResource envelope), 4 (autoload position 1 + sync `_ready`), 9 (clock-drift TTL), 10 (migration chain bound), 11 (best-effort IDB fence VS tier), 14 (test spy interface). ADR-003 PersistenceLayer Save State Strategy (to be authored AFTER this GDD as its input scope).

## Overview

PersistenceLayer 係 Mirror Hero 唯一嘅 client-side persistence 接觸層 — 一個 synchronous `IPersistence` interface 封住所有 Godot 4.6 `user://state.json` (Web Export = IndexedDB; Desktop = local file) 嘅 I/O，autoload position **1** 確保 read path 喺 #1 GameStateMachine (position 2) 同 #2 GymSys Backend Client (position 3+) 嘅 `_ready()` 之前完成（per ADR-006 Contract 4 per-autoload sequential ordering）。佢嘅職責有四：(1) 暴露 4-method sync interface — `read() -> Dictionary` / `write(key, value) -> bool` / `delete(key) -> bool` / `migrate(from_version, to_version) -> bool` —— 全部 NO `await`，保證 autoload chain stays sync (per ADR-006 Contract 11 best-effort IDB fence at VS tier); (2) boot 時讀 `schema_version: int`，若 `!= SCHEMA_VERSION` const → run bounded migration chain (per ADR-006 Contract 10: `MAX_MIGRATION_CHAIN_LENGTH = 6` × `MIGRATION_BUDGET_MS = 150ms` ceiling = 900ms total boot budget；超 budget 或 chain length → return `false` → corrupt-save path per GDD #1 Rule 5 priority 5); (3) 為所有 `SerializableResource` payload 提供 `to_dict()/from_dict()` 透明 round-trip envelope (per ADR-006 Contract 3 — explicit `payload_type` via `get_script().get_global_name()`，避免 `Object.get_class() == "Resource"` silent corruption); (4) 為 test 提供 `attach_write_spy(Callable)` / `attach_delete_spy(Callable)` / `clear_spies()` 三件 mock hook (per ADR-006 Contract 14 Test Spy Contract — production interface 同時 expose 但 no-op，MockPersistenceLayer records)。系統嚴格 stateless from gameplay perspective —— 唔解釋任何 key 嘅 semantic（gameplay logic 完全外部 own），唔做 conflict resolution（呢個 ADR-003 處理），唔做 backend sync（呢個 #2 GymSysClient + ADR-003 處理）。佢只係一個 typed sync I/O facade + schema migration runner + serialization envelope。所有 deployment topology decision (backend-primary vs localStorage-cache，conflict-resolution 規則，offline-mode storage tier choice) 將喺 **ADR-003 PersistenceLayer Save State Strategy** lock 死，本 GDD 屬 ADR-003 嘅 input scope；**ADR-006 Contracts 3/4/9/10/11/14** 已 ratified 並 binding 本 GDD prose。

## Player Fantasy

**Direct fantasy**: None — PersistenceLayer 係 infrastructure，玩家唔會 *feel* 個 sync I/O layer 本身。

**Indirect fantasy — 存咗就係存咗 (Saved Means Saved)**:
玩家心入面嘅 felt promise：「Mirror Hero 入面冇『saving...』提示。每個 write call 返時 cache mutation 已完成；disk persist 喺 FLUSH_DEBOUNCE_MS (100ms) 內自動發生（非 critical path），或對 critical tombstone write (flush=true) 立即發生。若 flush 失敗，`critical_save_failed` 即時 emit — 系統永遠唔會靜悄悄 lose 我嘅 progress 然後扮無事發生。」呢個 fantasy 唔由 PersistenceLayer 自身 emit 任何 visual / audio cue 表達，而係由佢嘅 **architectural posture** 強制 — sync `read/write/delete/migrate` interface 設計時就 disallow optimistic UI lies (no half-states, no pending toast)，所有 failure mode 都 fail-loud (per ADR-006 Contract 11 telemetry hook `tombstone_write_completed`，Contract 10 migration `false` return，corrupt-save fallback per GDD #1 Rule 5 priority 5)。Client 永遠唔可以單方面「假裝」存咗，亦永遠唔可以靜悄悄 rollback player 已 earned 嘅 stat。

呢個 indirect fantasy 同 GDD #2 嘅「Backend 唔識講大話 (Anti-Cheat Ground Truth)」係 **paired anti-lie postures**：GDD #2 architectural 拒絕 fabricate stats (server-authoritative)，PersistenceLayer architectural 拒絕 fabricate persistence (sync, fail-loud)。兩者組成 Foundation tier 嘅一致 voice — **「呢個系統唔會講大話畀你聽」** —— GDD #2「backend 講真話」+ PersistenceLayer「storage 講真話」共同 underwrite Pillar 1 嘅 anti-fabrication promise 同 Pillar 3 嘅 ritual sanctity。

呢個 indirect fantasy 直接 enables：
- **Pillar 3 (Drop Euphoria — hard guarantee)** — LootDrop tombstone 經 SerializableResource envelope (Contract 3) 寫入 `user://state.json`，跨 WASM reload / Safari ITP 7 日 inactivity / 30 日 hard cap 都 survive。第二日 player 開 app，drop ritual 重 fire — 唔係「再生成一次」，係「上次嗰個」continue。
- **Pillar 1 (Real Body, Real Power)** — 真實 PR 不可由 client-side bug 靜悄悄丟失；所有 stat mutation 經 atomic `write(key, value)` 落 IDB，失敗 emit `critical_save_failed` (而唔係 silent drop)。
- **Pillar 5 (Mirror Moment) — precondition only** — Mirror Moment 每週可見 evolution 嘅前提係 base avatar state 跨週 unbroken；PersistenceLayer 提供呢個 unbroken-ness 嘅 substrate。本身唔 own Mirror Moment fantasy，只係 precondition layer。

**Falsifiable design test**: 任何 client-side path 引致以下情境 = bug，唔係 acceptable behavior：
1. 玩家 deadlift rep 47 嗰刻 earn 咗一個 rare LootDrop，tombstone 寫咗去 `user://state.json`，但跟住 Safari iOS killed the tab for memory pressure → 玩家 5 分鐘後 reopen tab → drop 唔見咗 → **Pillar 3 hard guarantee 違反**
2. 同一個 `write("loot_reveal_payload", ...)` call 返 `true`，但下次 `read()` 完全冇呢個 key → 系統「講咗大話」(同意存咗但實際冇) → **anti-lie posture 違反**
3. Schema migration `1 → 2` 中途 IDB write 失敗，但 PersistenceLayer 唔 emit `critical_save_failed`，只係靜靜地 return `false` → consumer 唔知 partial migration 狀態 → silent corruption → **Pillar 1 indirect violation** (earned state 變 inconsistent without warning)
4. Player Chrome Incognito 開 game，IndexedDB quota = 0，每個 `write` 返 `false`，但系統照 fire `lootdrop_committed` signal 扮成功 → **anti-lie 違反** (見 Q-E1)

### Fantasy Risk Register

呢個 indirect fantasy 嘅 "anti-lie architectural posture" framing 係 contingent on 以下 invariants 喺 **ADR-003** ratification 真正 enforced，否則 Player Fantasy paragraph 變 retroactive lie：

| # | Contingent Invariant | Owner | Fallback if Dropped |
|---|---------------------|-------|---------------------|
| FR-1 | `IPersistence.write(key, value)` returning `true` implies WASM-side serialization success (NOT IDB commit ack per Contract 11 VS tier) — `critical_save_failed` signal fires on Contract 11 telemetry hook breach (>1/10K loss rate at MVP gate) | ADR-006 Contract 11 + ADR-003 | Upgrade to Option B (flush + 1-frame await) per Contract 11 — Pillar 3 hard guarantee restored at 16-32ms cost per critical write |
| FR-2 | Schema migration chain (Contract 10) is atomic-or-fail-loud — partial migration MUST surface `critical_save_failed`, never silent inconsistent state | ADR-006 Contract 10 + ADR-003 migration policy | Without this, "存咗就係存咗" framing degrades to "存咗可能變半成品而你唔知" — Pillar 1 silent corruption window |
| FR-3 | Browser Private Mode quota=0 detection is reactive (`write → false` → `persistence_volatile()` per Q-E1) — system MUST refuse to lie about persistence success | ADR-003 + Q-E1 resolution | If Private Mode silently accepts writes but loses on tab close → architectural posture broken; fallback = blocking modal "Private Mode 唔可以 carry state" |

**Ratification gate binding**: ADR-003 review MUST verify implementation satisfies all 3 invariants before Status: Accepted。若 ADR-003 lands without one of FR-1/FR-2/FR-3 → revisit this Player Fantasy paragraph with the corresponding fallback framing。

## Detailed Design

### Core Rules

1. **Rule 1 — Sync interface discipline (no await)** — `IPersistence` 嘅 4 method (`read/write/delete/migrate`) 全部 sync return，唔可以 `await` 任何嘢。違反會 break **Contract 4** (autoload position 1 `_ready()` MUST complete sync — 否則 GameStateMachine 喺 position 2 `_ready()` 會見到未 ready 嘅 PersistenceLayer)。CI 靜態檢查 `tools/ci/check_no_await_in_persistence.sh` 喺 `src/foundation/persistence/` 內任何 `await` 出現即 fail build。

2. **Rule 2 — In-memory write-through cache (dirty-flag debounced flush)** — `_ready()` 一次性 load `user://state.json` parse 成 `_cache: Dictionary` 喺 memory。後續 `read(key)` 直接 return `_cache.get(key)` (O(1) lookup，無 file I/O)。`write(key, val, flush: bool = false)` 先 mutate `_cache[key] = val` + mark `_dirty = true`，然後：(a) 若 `flush = true` (critical tombstone path)：即時執行 Rule 3 atomic flush；(b) 若 `flush = false` (default)：啟動/重置 `_flush_timer` (FLUSH_DEBOUNCE_MS = 100ms)，timer 到期後 auto-flush。**「cache mutation 同 dirty-flag 永遠同步」** 係 invariant — `write()` 返 `true` 代表 cache mutation 成功；disk persist 喺 FLUSH_DEBOUNCE_MS 內完成（非 critical）或即時（critical）。任何 flush 失敗 → Rule 9 corrupt path (emit `critical_save_failed`)。Callers requiring immediate IDB durability (e.g. GSM tombstone writes per Rule 2 step 2) 必須傳 `flush = true`。

3. **Rule 3 — Atomic file flush pattern** — `_flush_dirty()` internal method（由 debounce timer 或 critical write path 調用）：`FileAccess.open(path, WRITE) → store_string(JSON.stringify(_cache)) → close() → emit flush_completed(flushed_key_count, latency_ms, is_critical)`。**冇 incremental / per-key writes** — 每次 flush 序列化整個 cache 為 single JSON blob。Flush return `false` → Rule 9 corrupt path (emit `critical_save_failed`) — 注意：debounced 模式下 flush 失敗時 **唔 revert cache**（cache state 仍正確，disk 未追上），Rule 9 wipe 重置 cache + disk 至 clean state。**唔用 temp file + rename** — 正確原因：Emscripten IDBFS `syncfs` 係 whole-filesystem snapshot，唔係 per-file transactional，temp file + final file 同時 flush，rename atomicity 唔能提供原子性保證。**`store_string()` return bool**: 反映 WASM MEMFS buffer write success，**唔係** IDB commit ack — IDB async flush 喺 GDScript call stack 返回後 continue。VS tier accept 呢個 ~1 frame IDB lag（同 Rule 7 一致）。

4. **Rule 4 — SerializableResource envelope (Contract 3)** — 任何 Resource payload extends `SerializableResource` base class，必須 override `to_dict() -> Dictionary` + static `from_dict(d: Dictionary) -> SerializableResource`。Envelope 格式：`{ "payload_type": "<global_class_name>", "data": { ... } }`。`payload_type` 必須由 `get_script().get_global_name()` 提供 — **NOT `Object.get_class()`**（後者 silent return `"Resource"` — anti-lie posture 嘅典型 silent failure mode）。

   **`_payload_dispatch` lazy lookup specification (D2)**：`from_dict(d: Dictionary) -> SerializableResource` 喺 called 時，用 `d["payload_type"]` string 做 **lazy class lookup**：呼叫 `ClassDB.instantiate(d["payload_type"])` — 任何有 `class_name` declaration 嘅 `SerializableResource` subclass 自動可被 instantiate，**唔需要 code-time manual registration**。

   Lookup rules：
   - `d["payload_type"]` 為 empty string 或 absent → Rule 9 corrupt path (error_code: `"UNREGISTERED_PAYLOAD_TYPE"`)，唔可以 return null silently
   - `ClassDB.instantiate(payload_type)` 失敗（class 唔存在 / non-SerializableResource subclass / inner class without registered `class_name`） → Rule 9 corrupt path (error_code: `"UNREGISTERED_PAYLOAD_TYPE"`)
   - 所有 payload class 必須有明確 `class_name` declaration — **禁止 inner class payload**（inner class 唔喺 ClassDB 全局 register，`get_global_name()` 返 `""`，`ClassDB.instantiate` 失敗）
   - **Rename policy**：class rename = schema version bump，`_migrate_one_step` 必須 rewrite stored `payload_type` field — ADR-003 binding

5. **Rule 5 — Schema version + bounded migration runner (Contract 10)** — Boot sequence：
   1. Parse `user://state.json` → read `schema_version: int` field
   2. If `schema_version == SCHEMA_VERSION (= 1)` → done，enter Ready substate
   3. **Fail-fast pre-check (P0-7)**: If `abs(SCHEMA_VERSION - schema_version) > MAX_MIGRATION_CHAIN_LENGTH (= 6)` → return `false` immediately，**zero steps executed**，emit `critical_save_failed("MIGRATION_CHAIN_TOO_LONG", "")` → corrupt path (Rule 9)。呢個 path `migration_step_completed` emit count = 0（fail-fast before any step execution）
   4. If `schema_version < SCHEMA_VERSION` → chain `_migrate_one_step(N → N+1)` until reach `SCHEMA_VERSION`；每個成功 step emit `migration_step_completed(from_version: N, to_version: N+1, latency_ms: int)`。**Signal suppression (D1)**: migration flush 內嘅 write operations 唔 emit `write_completed` — 呢段期間 consumer 唔收 per-key mutation events；migration 完成後先 resume normal emit
   5. **Bounds (Contract 10)**: chain length ≤ `MAX_MIGRATION_CHAIN_LENGTH = 6`；每 step ≤ `MIGRATION_BUDGET_MS = 150ms` (用 `Time.get_ticks_msec()` 量度，total 900ms boot ceiling)。step timeout 超 → abort chain → `migrate()` return `false` → emit `critical_save_failed("MIGRATION_TIMEOUT", "step_N_to_M")` → corrupt path (Rule 9)
   6. If `schema_version > SCHEMA_VERSION` → impossible (downgrade scenario) → corrupt path
   7. **Atomic-or-fail-loud sub-clause**: 每個 `_migrate_one_step` 必須全成功或 zero-effect。中途 disk write fail → revert in-memory cache to pre-step snapshot → return false → bubble up。**禁止 silent partial migration** (Pillar 1 hard guarantee)

6. **Rule 6 — Test spy contract (Contract 14)** — Production `PersistenceLayer` 同時 expose `attach_write_spy(cb: Callable) / attach_delete_spy(cb: Callable) / clear_spies()` 但**全部 no-op**。`MockPersistenceLayer` (位於 `tests/mocks/`) extends 同一 `IPersistence` interface，override 呢 3 個 method 為實際 record 行為 (`_write_log: Array[Dictionary]`)。**唔可以**用 conditional compilation (`OS.has_feature("debug")`) 區分 — interface shape 喺 production / test build 必須 identical，否則 test 同 prod divergence 會 mask bug。

7. **Rule 7 — VS tier IDB fence policy (Contract 11)** — `write()` sync return，唔 await IDB commit ack。`_flush_dirty()` 同樣唔 await IDB commit ack — `store_string` bool 反映 WASM MEMFS buffer success，唔係 IDB persistence。VS tier accept ~1 frame IDB lag on flush (MVP gate review: 若 production telemetry loss rate > 1/10K，升級 flush 至 await IDB ack — post-VS scope)。

   **Telemetry signals (Rule 11 owner split)**：
   - `write_completed(key: String, latency_ms: int, is_touch: bool)` — per individual cache mutation (emits when `write()` updates `_cache`，regardless of flush timing；latency_ms 量度 cache mutation only，唔包括 disk I/O)
   - `flush_completed(flushed_key_count: int, latency_ms: int, is_critical: bool)` — per actual disk flush (emits when `_flush_dirty()` completes)
   - GSM listens `write_completed` filter `key == "pending_transition"` → emit 自己嘅 Contract 11 `tombstone_write_completed(transition_id, latency_ms)`
   - `touch()` call 亦觸發 `write_completed(key, latency_ms, is_touch: true)` + 隨後嘅 `flush_completed`（因 touch 係 critical，`flush = true`）

   **Rule 7.1 — Delete method semantics (P0-2)** — `delete(key: String) -> bool`：
   - 若 key 存在：`_cache.erase(key)` → mark `_dirty = true` → 即時執行 `_flush_dirty()` (critical path，等同 `flush = true`) → emit `delete_completed(key, latency_ms)` → return `true`
   - 若 key 唔存在：no-op，return `false`（唔觸發 flush，唔 emit signal）
   - Flush 失敗：Rule 9 corrupt path → emit `critical_save_failed("FLUSH_FAILED", key)`；**唔 re-insert key 入 cache**（cache 已 erase，Rule 9 wipe 令 state consistent）
   - `delete()` **永遠 flush=true**（critical）— delete 係 destructive operation，唔應受 debounce timer delay

8. **Rule 8 — Clock-drift TTL helper (Contract 9)** — Public pure function：
   ```gdscript
   func is_expired(anchor_unix: int, ttl_seconds: int, anchor_monotonic_ms: int = 0) -> bool
   ```
   實作：(a) 計 wall-clock delta = `Time.get_unix_time_from_system() - anchor_unix`；(b) If `anchor_monotonic_ms > 0` 且 `abs(wall_delta - monotonic_delta) > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS (= 300)` → **trust monotonic**，return `monotonic_delta > ttl_seconds * 1000`；(c) Else → return `wall_delta > ttl_seconds`。**Pure function** — 唔 mutate state，唔 touch cache。Caller (e.g. GymSys client age-pruning `_committed_tombstones`) 負責 anchor 嘅 storage。

9. **Rule 9 — Corrupt save detection + critical_save_failed signal** — 以下任何條件觸發 corrupt path：
   - `JSON.parse_string()` returns null
   - Parsed 結果唔係 Dictionary
   - 缺 `schema_version` key
   - `migrate()` return false
   - Rule 4 `payload_type` 未 register
   - `_flush_dirty()` returns `false` (MEMFS disk write failed — e.g. quota exhausted / read-only filesystem)

   行為：(1) wipe `user://state.json` to `{ "schema_version": SCHEMA_VERSION }` — record wiped byte count before write；(1b) emit `corrupt_save_recovered(wiped_byte_count: int)` — Telemetry hook for data-loss analytics (wiped_byte_count = original file size in bytes pre-wipe；0 if file didn't exist)；(2) `_cache = { "schema_version": SCHEMA_VERSION }`；(3) `emit_signal("critical_save_failed", error_code: String, key: String)` (key 可 empty string for boot-time / flush-time corruption)；(4) 進入 Corrupt substate (見 States and Transitions)。**禁止 silent recovery** — consumer 必須見到 signal 並走 fallback path (Pillar 1 anti-fabrication)。Signal order: `corrupt_save_recovered` emits BEFORE `critical_save_failed`。

   **Corrupt substate write clarification**: Rule 9 wipe 後 cache 重設為 clean `{ "schema_version": SCHEMA_VERSION }`。Corrupt substate 內 `write()` call 寫入呢個 **wiped fresh cache**，唔係 original key context；`write_completed` signal 照常 emit。Consumer 已收過 `critical_save_failed`，必須自行決定 clean-slate 嘅 gameplay response（e.g. 重新從 backend fetch state），唔可以假設 Corrupt 內嘅 write 係原始 key 嘅 recovery。

10. **Rule 10 — Safari ITP touch refresh** — Public method `touch(key: String) -> bool` rewrite 同樣 content (read cache → atomic flush)。畀 GameStateMachine Rule 1 引用，refresh Safari ITP 7-day storage timer。Behaviour-wise 等同 `write(key, read(key))` 但 explicit 表達 intent + `write_completed` signal `is_touch: true` 標記 (避免 telemetry 將 touch 誤算為 mutation rate)。

11. **Rule 11 — Telemetry signal surface (anti-lie posture)** — PersistenceLayer 必須 emit 以下 generic signals，**全部 PersistenceLayer-owned domain-agnostic events**，consumer 自行 wrap 加 domain semantic：
    - `write_completed(key: String, latency_ms: int, is_touch: bool)` — per cache mutation (每次 `write()` / `touch()` 更新 `_cache` 時 emit；latency_ms = cache mutation time only)
    - `flush_completed(flushed_key_count: int, latency_ms: int, is_critical: bool)` — per actual disk flush (每次 `_flush_dirty()` 成功完成時 emit；latency_ms = full disk I/O time)
    - `delete_completed(key: String, latency_ms: int)` — every successful delete
    - `migration_step_completed(from_version: int, to_version: int, latency_ms: int)` — per migration step
    - `critical_save_failed(error_code: String, key: String)` — Rule 9 trigger
    - `corrupt_save_recovered(wiped_byte_count: int)` — after Rule 9 wipe complete

    **Owner split with ADR-006 Contract 11**: PersistenceLayer NEVER emit `tombstone_write_completed(transition_id, ...)` — `transition_id` 係 GSM-domain semantic。GSM 喺 `write_completed.connect()` handler 入面 filter `key == "pending_transition"` 然後 emit 自己嘅 Contract 11 signal with 自己嘅 `transition_id` context。**Infra layer 唔知 domain concept** 係 Foundation tier 嘅 architectural posture。

12. **Rule 12 — Key namespace convention (recommended, NOT enforced)** — 為 prevent 將來 system collision 風險，**recommended convention**：
    - `gsm.*` — GameStateMachine owns (e.g. `gsm.current_state`)
    - `gym.*` — GymSys Backend Client owns (e.g. `gym.session_token`)
    - `_internal.*` — PersistenceLayer self-managed (e.g. `_internal.schema_version`)

    **Enforcement**: `write(key, val)` 若 key 唔 match registered namespace pattern → `push_warning("Key '%s' lacks namespace prefix" % key)` (debug build only，release no-op)。CI lint `tools/ci/check_key_namespace_convention.sh` 喺 new code 出 warning 但 NOT fail build。**Backward-compat**: GDD #1 (`current_state`, `pending_transition`, etc.) 同 GDD #2 (`session_token`, etc.) 既有 bare keys 仍 valid — 唔需要 rename。Convention 只適用於將來新 system 加入嘅 key。

13. **Rule 13 — Migration idempotency requirement** — 每個 `_migrate_one_step(N → N+1)` 必須 idempotent — replay 同一 step 兩次結果 identical。原因：boot 期間 crash mid-migration + reboot 後，partial-written file 可能令 schema_version 已升但 data 未升（雖然 Rule 5 atomic-or-fail-loud 緩解，但 WASM IDB ~1 frame lag (Contract 11) 留咗 race window）。Idempotency = safety net。**Implementation guidance**: migration steps 用 `if "new_key" not in _cache:` guard，避免 double-transform。

### States and Transitions

PersistenceLayer 唔係 stateful gameplay system，但 boot lifecycle 有 4 個 internal substates：

| Substate | Entry | API behaviour | Exit |
|----------|-------|---------------|------|
| **Initialising** | `_enter_tree()` start | All API rejects (assert) — autoload position 1 invariant means 冇 caller 應該喺呢個 substate 入面 hit API | `_ready()` parsed file successfully → Ready / Migrating / Corrupt |
| **Migrating** | Schema mismatch detected, Rule 5 chain running | `read/write/delete` **block-reject** (return null / false + emit `critical_save_failed("MIGRATION_IN_PROGRESS", key)`) — 防止 consumer 喺 schema 半升級狀態下讀到 stale shape | Chain complete → Ready；OR chain failed → Corrupt |
| **Ready** | Normal operation | All API functional per Rules 1-11 | Never (only Corrupt via Rule 9 trigger) |
| **Corrupt** | Rule 9 fired | `read()` returns `{}` empty / null per key；`write()` accepted (cache fresh)；migration disabled；signal already emitted once — won't re-emit until session restart | Session restart only (never auto-recover) |

**Why Migrating reject explicit**: Contract 4 sync `_ready()` 同 Contract 10 5s migration ceiling 之間有 tension — 若 caller 喺 boot 期間 fire API call，必須有 deterministic reject behaviour 而非 UB。**Migrating substate 嘅 block-reject** 直接 enforce 「半升級期間冇人見到中間 state」嘅 Pillar 1 invariant。

### Interactions with Other Systems

| Consumer | Direction | API used | Key ownership | Notes |
|----------|-----------|----------|---------------|-------|
| **#1 GameStateMachine** (autoload pos 2) | reads + writes | `read()` at boot；`write()` per state transition (Rule 2 step 2/4 of GSM Rule 2)；`delete()` per Rule 2 step 5；`touch()` per Safari ITP refresh (GSM Rule 1)；listens `critical_save_failed`；listens `write_completed` 過濾 wrap Contract 11 | All 7 keys per GDD #1 spec (`current_state`, `schema_version`, `pending_transition`, `loot_reveal_pending`, `loot_reveal_payload`, `_last_weekly_tick_unix`, `_transition_id_counter`) | Heaviest consumer；每個 transition 寫 `pending_transition` tombstone (via SerializableResource envelope per Rule 4) |
| **#2 GymSys Backend Client** (autoload pos 3+) | reads + writes | `read()` at boot；`write()` for 3 keys；uses `is_expired()` helper for 35-day `_committed_tombstones` age-pruning (Rule 8) | 3 keys per GDD #2 spec (`session_token`, `_committed_tombstones`, `_last_known_state`) | 監聽 `critical_save_failed` 觸發 `persistence_volatile()` signal (GDD #2 Edge Case Resource & Storage path) |
| **#15 LootDropSystem** (Pre-MVP) | indirect via GSM | (none direct) | — | LootPayload Resource 經 SerializableResource envelope (Rule 4) 由 GSM persist；Pillar 3 hard guarantee 路徑 |
| **#16 BossSystem** (VS) | indirect via GSM | (none direct) | — | BossPayload Resource 經 SerializableResource envelope (Rule 4) 由 GSM persist |
| **#8 Streak System** (Pre-MVP) | reads + writes (TBD when GDD authored) | `read()` + `write()` for streak counter；`is_expired()` for daily-window check | TBD (likely `streak.*` namespace per Rule 12 convention) | First system to adopt new namespace convention |
| **#28 Telemetry** (Pre-MVP) | listens signals | listens all 5 generic signals (`write_completed / delete_completed / migration_step_completed / critical_save_failed / corrupt_save_recovered`) | — | Forwards to GymSys backend on next sync window；needed for MVP gate review (Rule 7 IDB fence loss rate) |
| **MockPersistenceLayer** (tests only) | extends interface | overrides `attach_*_spy` to record (Rule 6) | — | NOT a runtime consumer — test fixture only |

**Interaction invariants**:
- **No backward dependency**: PersistenceLayer 永遠唔可以 import / reference 任何 consumer (autoload position 1 hard constraint per Contract 4)
- **No fan-out logic**: PersistenceLayer 只 emit generic signals (Rule 11)，唔知 consumer 係邊個 — 由 consumer 自行 `connect`
- **Synchronous read contract**: 所有 consumer 喺自己嘅 `_ready()` 用 `read()` 嘅時候，依賴 Contract 4 sequential autoload ordering 保證 PersistenceLayer 已 Ready substate

## Formulas

PersistenceLayer 主要係 sync I/O facade + schema migration runner + serialization envelope，唔做 gameplay math。本 section 包含一條 client-owned helper formula (from ADR-006 Contract 9)；其他需要嘅 calculation 均為 bounded loop / decision logic（已喺 Detailed Design Rules 5/12 內列明）。

### Formula 1: Drift-Tolerant TTL Expiry Check (Contract 9 implementation)

Public pure helper function 畀 consumer 判斷一個 wall-clock anchored 嘅 expiry timestamp 係咪過咗 TTL，同時容忍 NTP / DST / manual time change 嘅 wall-clock 跳動。

```gdscript
func is_expired(anchor_unix: int, ttl_seconds: int, anchor_monotonic_ms: int = 0) -> bool:
    var now_unix: int = int(Time.get_unix_time_from_system())
    var wall_delta: int = now_unix - anchor_unix

    # Guard: negative wall_delta + no monotonic anchor (clock not initialized / extreme rollback) — FR-3
    if wall_delta < 0 and anchor_monotonic_ms == 0:
        push_warning("is_expired: negative wall_delta — clock not initialized; treating as not-expired")
        return false

    # If caller provided monotonic anchor, check for clock drift
    if anchor_monotonic_ms > 0:
        var now_monotonic_ms: int = Time.get_ticks_msec()
        # Guard: cross-session anchor (monotonic resets to 0 each process restart)
        if now_monotonic_ms < anchor_monotonic_ms:
            push_error("is_expired: cross-session anchor_monotonic_ms detected — falling back to wall-clock")
            return wall_delta > ttl_seconds
        var monotonic_delta_ms: int = now_monotonic_ms - anchor_monotonic_ms
        # Compare at ms precision to avoid integer-second truncation (P0-4)
        if abs(wall_delta * 1000 - monotonic_delta_ms) > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS * 1000:
            # Wall clock drifted (NTP / DST / manual) — trust monotonic
            return monotonic_delta_ms > ttl_seconds * 1000

    # Default path: wall-clock comparison
    return wall_delta > ttl_seconds
```

**Preconditions** (runtime `assert()` enforced at autoload boot):

- `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS >= 60` (lower bound — below this, harmless second-tick jitter triggers false drift detection)
- `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS <= 3600` (upper bound — above this, real day-long drift escapes detection)

**Session scope constraint (B2 fix)**: `anchor_monotonic_ms` 係 **session-scoped only**。`Time.get_ticks_msec()` 每次 process restart 重設為 0。Cross-session TTL check（e.g. token expiry 跨 browser reload，loot tombstone TTL 跨 app restart）**必須傳 `anchor_monotonic_ms = 0`**（default），只用 wall-clock path。任何 caller persisting `anchor_monotonic_ms` 落 disk via `to_dict()` 係 bug — monotonic anchor 跨 session 失去意義，drift detection 會 malfunction（新 session ticks 遠低於舊 anchor → `monotonic_delta` negative → expired token 誤判為 fresh）。

**Runtime cross-session guard (P0-4)**: 若 `anchor_monotonic_ms > 0` 且 `Time.get_ticks_msec() < anchor_monotonic_ms`（即新 session ticks 低於 anchor），function 以 `push_error` log 並 fallback 去 wall-clock path（返 `wall_delta > ttl_seconds`），唔做 monotonic comparison。呢個 guard 係 defensive measure — 正確 caller 唔應 persist monotonic anchor 跨 session。

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Anchor wall-clock timestamp (Unix seconds) | `anchor_unix` | int | ≥ 0 | Caller-provided timestamp at which anchor event occurred (e.g. tombstone write time, session start time) |
| TTL in seconds | `ttl_seconds` | int | ≥ 1 | Caller-provided maximum age before expiry |
| Anchor monotonic timestamp (milliseconds) | `anchor_monotonic_ms` | int | 0 (omitted) or ≥ 1 | Optional `Time.get_ticks_msec()` at anchor moment; enables drift detection |
| Wall-clock drift tolerance | `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` | int (knob) | 60 .. 3600 (default 300) | Owned by PersistenceLayer; how much wall-clock can disagree with monotonic before we distrust wall-clock |
| Result | (return) | bool | true / false | true = anchor is older than ttl_seconds (expired) |

**Output Range:** Boolean. Pure function — no side effects, no cache mutation, no signal emit.

**Behaviour matrix** (comparisons use ms precision per updated code):

| Scenario | `wall_delta` | `monotonic_delta_ms` | drift detected? | Returns |
|----------|--------------|----------------------|-----------------|---------|
| Normal clock, anchor < ttl | 100s | 100000ms (or omitted) | No (diff=0) | `false` (not expired) |
| Normal clock, anchor > ttl | 1000s | 1000000ms (or omitted) | No (diff=0) | `true` (expired) |
| NTP correction +600s mid-session | 700s | 100000ms | Yes (diff 600000ms > 300000ms) | Trust monotonic → `100000 > ttl×1000` |
| DST spring-forward +3600s | 3700s | 100000ms | Yes (diff 3600000ms > 300000ms) | Trust monotonic → `100000 > ttl×1000` |
| Manual clock-rollback -86400s (1 day) | -86300s | 100000ms | Yes (diff 86400000ms > 300000ms) | Trust monotonic → `100000 > ttl×1000` |
| Anchor_monotonic_ms = 0 (omitted) | (any positive) | N/A | Cannot detect | Default to `wall_delta > ttl_seconds` |
| **Negative wall_delta, no monotonic** (P0-5) | -3600s | N/A (omitted) | N/A | Guard: `push_warning` + return `false` |

**Example** (with `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300`, `ttl_seconds = 86400` = 1 day):

- Caller stores anchor at unix=1748212345, monotonic_ms=12000
- 23 hours later: now_unix=1748295145 (wall_delta=82800s), now_monotonic_ms=82812000ms (monotonic_delta_ms=82800000ms)
- `abs(82800 * 1000 - 82800000) = abs(82800000 - 82800000) = 0 < 300000 (300s × 1000)` → no drift → return `82800000 > 86400 * 1000 = 86400000` → `false` (not expired ✓)
- 1 day + 1 hour later, but DST kicked in adding 3600s to wall-clock: wall_delta=93600s, monotonic_delta_ms=90000000ms
- `abs(93600 * 1000 - 90000000) = abs(93600000 - 90000000) = 3600000 > 300000` → drift detected → trust mono → return `90000000 > 86400000` → `true` (expired ✓ — DST jump correctly ignored)

**Cross-system note**: 呢條 formula 完全 self-contained 喺 PersistenceLayer。Consumer (e.g. GymSys Client 嘅 35-day `_committed_tombstones` age-pruning per GDD #2 Rule 15) call `PersistenceLayer.is_expired(committed_at, 35 * 86400)`，唔需要自己處理 drift detection。Mirror Hero 嘅其他 TTL-bearing 系統 (e.g. GDD #1 `_last_weekly_tick_unix` weekly tick replay, `pending_transition` 7200s tombstone TTL per Contract 9) 全部經呢條 helper 處理 wall-clock 不可靠 case。

### Formulas owned elsewhere (referenced, not duplicated)

| Formula | Owner GDD / ADR | Used in this layer |
|---------|-----------------|---------------------|
| `retry_delay(n) = min(BASE_DELAY × 2^(n-1), RETRY_CAP)` | GDD #1 GameStateMachine (Formula 1) | Not used directly — referenced via GymSys Client's `Backoff` substate executing retry sleep |
| Migration chain total time bound: `total_time_ms = chain_length × MIGRATION_BUDGET_MS` | ADR-006 Contract 10 | Detailed Design Rule 5 step 5 — `total_time <= 900ms (6 × 150)` boot ceiling |
| `transition_id` generation: `wall_clock_ms × 1000 + counter` | ADR-006 Contract 2 | Not generated here — Counter persistence handled by GameStateMachine writing `_transition_id_counter` via `PersistenceLayer.write()` |

## Edge Cases

### Boot / File I/O Edge Cases

- **If `user://state.json` 完全唔存在 (first boot)**: `FileAccess.open(READ)` fail → 視為 fresh install → init `_cache = { "schema_version": SCHEMA_VERSION }` → atomic write 落 disk → enter Ready substate；NOT corrupt path (first boot 唔 emit `critical_save_failed`)。
- **If `user://state.json` exists 但 0 bytes (empty file)**: `JSON.parse_string("")` returns null → Rule 9 corrupt path → wipe + re-init + emit `critical_save_failed("EMPTY_FILE", "")`。
- **If `user://state.json` exists 但 `JSON.parse_string()` 失敗 (truncated / non-JSON content)**: Rule 9 corrupt path → emit `critical_save_failed("INVALID_JSON", "")`。
- **If `FileAccess.open(WRITE)` fail mid-boot** (read-only filesystem / permission denied — extremely rare on Web Export): autoload `_ready()` enters fail-fast mode — `_cache = {}` in-memory only，emit `critical_save_failed("READ_ONLY_FILESYSTEM", "")` immediately，後續所有 `write()` return false。Game 可繼續 run 但 zero persistence — consumer 必須 listen `critical_save_failed` 並 surface 適當 UX (#24 Login UI 可能 show 「Storage 不可用」blocking modal — per Q-X12 NEW below)。
- **If `_ready()` throws unexpected exception** (e.g. `OutOfMemoryError` parsing 50MB malicious file): Godot autoload 鏈 abort → game crash。**Mitigation**: 加 file size sanity check before parse。**注意**: `FileAccess.get_length()` 係 Godot 4.x **instance method**（require open file handle first）。正確 sequence (P0-8)：`var f: FileAccess = FileAccess.open(path, FileAccess.READ)` → `var size: int = f.get_length()` → `if size > MAX_STATE_FILE_BYTES: f.close(); _trigger_corrupt("FILE_TOO_LARGE", ""); return` → `var text: String = f.get_as_text()` → `f.close()` → parse `text`。**不可** call `FileAccess.get_length()` without open handle（static call 唔存在）。

### Schema Migration Edge Cases

- **If `schema_version > SCHEMA_VERSION` (downgrade scenario — user opened older app build after newer one)**: Rule 5 step 5 — corrupt path。Reasoning: 我哋無法估 future schema → 唯一安全 option = wipe + start fresh。**Pillar 3 risk**: 若 future schema 加咗新 LootDrop key，downgrade boot 會 lose 個 drop。Tradeoff 接受 — versioning policy 由 ADR-003 lock 死「無 downgrade support」。
- **If `_migrate_one_step(N → N+1)` 超 `MIGRATION_BUDGET_MS = 150ms`**: 即時 abort chain → `migrate()` return false → corrupt path + `critical_save_failed("MIGRATION_TIMEOUT", "step_%d_to_%d" % [N, N+1])`。Boot 仍 continue (degraded mode)。
- **If migration chain exceeds `MAX_MIGRATION_CHAIN_LENGTH = 6`**: 即係 user 跳過咗 6+ versions (e.g. v1 → v8)。Rule 5 step 3 **fail-fast pre-check** catches 呢個 BEFORE any step executes → `critical_save_failed("MIGRATION_CHAIN_TOO_LONG", "")` emit with `migration_step_completed` count = 0 → Corrupt path。**ADR-003 binding**: schema bumps 必須足夠頻繁 (e.g. 每 quarter release) 避免 user 跨越 6 個 version；若 release cadence 跨度大，必須 fold migrations (e.g. v1→v5 jumbo step)。
- **If crash mid-migration (e.g. WASM tab killed during `_migrate_one_step` 3 → 4)**: 下次 boot read `schema_version` — 因 Rule 5.6 atomic-or-fail-loud sub-clause + Rule 3 atomic write，partial migration 唔會留底 → `schema_version` 仍 = 3 → migration chain replays 3 → 4。Rule 13 idempotency guarantees 重做 step 結果 identical。**Race window** (Contract 11 ~1 frame IDB lag): 若 `schema_version` 已升但 data 未升 → Rule 13 idempotent guard (`if "new_key" not in _cache:`) 防 double-transform。

### Serialization Envelope Edge Cases (Rule 4)

- **If Resource payload extends `Resource` 但唔 extends `SerializableResource`**: GSM Rule 2 step 2 寫 tombstone 嗰陣 call `payload.to_dict()` → method not found → GDScript runtime error → tombstone write fail → GSM 走 critical_save_failed path。Static analyzer (ADR-006 Contract 12 / static-check scope) flags `extends Resource` 用喺 `pending_transition` payload 路徑。
- **If `payload.get_script() == null`** (instantiated via `Resource.new()` 而非 typed class_name): `payload_type` 變 empty string → `ClassDB.instantiate("")` fails → Rule 9 corrupt path on `from_dict` (error_code: `"UNREGISTERED_PAYLOAD_TYPE"`)。**Mitigation**: `to_dict` 入面 explicit assert `assert(payload_type != "", "Payload missing class_name script")` 喺 debug build catch。
- **If `payload_type` 對應嘅 class 已 renamed (e.g. `BossPayload` → `EncounterPayload`)**: `ClassDB.instantiate("BossPayload")` fails（class 已唔存在）→ Rule 9 corrupt path on `from_dict` (error_code: `"UNREGISTERED_PAYLOAD_TYPE"`)。**ADR-003 binding**: class rename = schema version bump，migration step 入面 rewrite stored `payload_type` field。
- **If `data` Dictionary contains non-JSON-safe values (e.g. Node reference, Callable, Object)**: `JSON.stringify()` silently drops 或 throws — depending on Godot version。**Static analyzer scope**: `to_dict()` body 唔可以 include 任何 Node / Callable / Object literal。CI lint `tools/ci/check_to_dict_json_safe.sh`。
- **JSON int64 precision (correct threat model)**: Godot 4.x `JSON.stringify(int)` serializes native int64 literal (唔 cast 落 float64)；`JSON.parse_string` 返 `TYPE_INT` (int64)。GDScript round-trip **唔損 precision** at 2^63。**真正威脅**：若 state JSON 經過 browser JS interop layer（e.g. `window.postMessage`，任何 hypothetical localStorage fallback，DevTools clipboard copy）— JS `Number` type truncates int64 > 2^53。**Mitigation**：唔可以將 `user://state.json` 內容 route 經 JS boundary。若 ADR-003 引入任何 JS-mediated storage path，需在該 boundary 加 explicit int64 > 2^53 check。

### Storage Backend Edge Cases (IndexedDB / Safari ITP / Private Mode)

- **If Safari ITP evicts `user://state.json` after 7 days inactivity**: All keys gone → next boot looks like first-boot → enter Ready substate empty。Consumer (e.g. GymSys Client) 自己 detect (per GDD #2 `session_evicted_by_browser` signal handling)。PersistenceLayer 本身 NOT emit eviction-specific signal — 由 consumer compare expected vs actual state 推斷。
- **If Chrome Incognito quota = 0 (Private Mode IndexedDB unavailable — Q-E1)**: 第一次 `write()` 觸發 `FileAccess.store_string` returns false → **emit `critical_save_failed("QUOTA_EXHAUSTED", key)` 並 Stay in Ready substate (D4)**。理由：quota exhaustion 唔代表 cache 損壞 — in-memory `_cache` 仍 correct；consumer 喺 Ready mode 仍可 read cached values；game session 可 continue（in-memory only）+ consumer 自決 UX response（e.g. warning toast per Q-X12）。對比：entering Corrupt would prevent ALL writes — quota exhaustion write semantics differ from true corruption。**Reactive detection** per GDD #2 Q-E1 resolution — PersistenceLayer 唔需要 boot-time `JavaScriptBridge.eval("navigator.storage.estimate()")` probe (per GDD #2 P0-5 lesson — `JavaScriptBridge.eval()` 返 JS Promise，GDScript 4.6 唔可以 await)。
- **If `user://` IndexedDB quota exceeded mid-session** (player 累積大量 LootDrop cache 撐爆 quota): `write()` returns false → cache revert → emit `critical_save_failed("QUOTA_EXHAUSTED", key)` → consumer (GymSys Client 已 spec) trim age-pruned tombstones via `delete()` → retry write。**唔 implement automatic retry** — caller logic 自決定 backoff / trim strategy。
- **If `FileAccess.store_string` returns true 但 IDB commit fail downstream (Contract 11 VS tier ~1 frame race window)**: Tab killed mid-frame → `write()` 認為成功但 disk 冇 update。**Accepted risk** per Contract 11 (~0.05% per-transition loss rate)。Telemetry hook `write_completed(key, latency_ms, is_touch)` 提供 MVP gate measurement。**Pillar 3 risk acknowledged** — VS tier accept；MVP review 決定升級至 flush+await。
- **If user manually clears IndexedDB via DevTools / Settings**: Same as Safari ITP eviction path — next boot looks like first-boot。**No silent reconcile** with backend — consumer 自己決定 fetch backend state (e.g. GymSys Client `auth_required()` signal flow)。

### Clock / Time Drift Edge Cases (Formula 1)

- **If system clock NTP-corrected mid-session by > 5 min**: Formula 1 drift detection triggers → trust monotonic → expiry decision based on actual elapsed time。**Telemetry hook NOT emitted by PersistenceLayer** (drift 唔係 PersistenceLayer's domain) — caller 自己 measure 同 emit drift telemetry。
- **If `Time.get_unix_time_from_system()` returns 0** (extremely rare — clock not yet initialised on cold boot): Formula 1 treats `now_unix = 0` literally — `wall_delta` 可能 huge negative → return `wall_delta > ttl_seconds` likely `false`。**Edge mitigation**: caller (GSM `_last_weekly_tick_unix` reconciliation) 自己 sanity-check `anchor_unix > 0` before passing to `is_expired()`。
- **`Time.get_ticks_msec()` wraparound**: Godot 4.x `Time.get_ticks_msec()` 返回 **int64**（唔係 uint32），**唔會** 24.8 日 wrap。呢個 edge case 係 phantom — 已刪除。True constraint: session-scoped monotonic clock (見 Formula 1 preconditions cross-session note)。
- **If DST spring-forward fires mid-poll / mid-write**: All scheduling 由 PersistenceLayer-internal code 用 `Time.get_ticks_msec()` (monotonic — DST-immune)。`Time.get_unix_time_from_system()` 唯一用途 = anchor timestamps；DST 加 1 hour → Formula 1 detect drift → trust monotonic。**No silent skip**。

### Concurrency / Substate Edge Cases

- **If `read()` called during `Migrating` substate** (e.g. consumer's `_ready()` 撞 PersistenceLayer's migration chain — should be impossible per Contract 4 sequential autoload, but defensive): API block-reject → return `null` → emit `critical_save_failed("MIGRATION_IN_PROGRESS", key)`。Consumer 必須 handle null。
- **If `write()` called during `Initialising` substate** (consumer auto-load position 0 — invalid configuration): debug-build assert crash with message "PersistenceLayer not ready — check autoload position"。Release build no-op + emit `critical_save_failed("NOT_READY", key)`。
- **If `delete()` called during `Corrupt` substate**: API accepts (cache state can be mutated freely once corruption signalled) → atomic flush → emit `delete_completed` per Rule 11。**No silent retry** of original corruption recovery — corrupt is sticky until session restart per Rule 9。
- **If two `write()` calls fire in same frame for same key** (e.g. GSM Rule 2 step 2 + step 4 both writing `current_state`): Sync I/O means second call overwrites first BEFORE next frame. Order = call order. `write_completed` emits twice (once per call). Caller responsible for correctness.
- **If `write()` called from inside `write_completed` handler (re-entrance)**: GDScript signal emit is synchronous — handler runs to completion before emit returns。Second `write()` inside handler will execute fully (sync I/O) → second `write_completed` fires → if handler re-fires `write()` → unbounded recursion。**Static analyzer scope**: handlers connected to `write_completed` MUST NOT call back into `write()` — CI lint flags this pattern.

### Test Spy / Mock Edge Cases (Rule 6)

- **If production code accidentally inherits `MockPersistenceLayer`** (wrong autoload registered): test spy methods record into `_write_log` 但 nothing reads → minor memory leak but functionally correct。CI smoke check `tools/ci/check_autoload_uses_production.sh` verifies `PersistenceLayer` autoload class == `ProductionPersistenceLayer` 喺 release build。
- **If test calls `attach_write_spy(invalid_callable)`** (e.g. Callable refers to freed object): Production no-op (silent OK)。Mock attempts `cb.call(key, val)` → error suppressed (try/catch around spy invocation) → spy 跳過 + emit warning。Test should fail 其 own assert 而非 PersistenceLayer crash。
- **If test forgets `clear_spies()` between tests**: Spy callbacks accumulate → next test sees stale recordings → test isolation broken。**Test helper auto-call**: `tests/helpers/persistence_test_setup.gd` provides `setUp() / tearDown()` hooks that auto-call `clear_spies()`。

### Cross-System Signal Edge Cases

- **If `critical_save_failed` emitted but zero consumers connected** (autoload chain misconfigured or signal renamed): Signal emit silent no-op (Godot default behaviour)。**Production safety net**: PersistenceLayer 自己 `push_error("critical_save_failed: %s | key=%s" % [error_code, key])` 同時 log 到 Godot console — ensures observable even without consumers。
- **If consumer's `write_completed` handler raises exception**: GDScript signal dispatch isolates — exception logged but other connected handlers 仍 receive signal。PersistenceLayer state unaffected。
- **If GameStateMachine subscribes to `write_completed` BEFORE PersistenceLayer enters Ready substate** (boot ordering bug): Contract 4 sequential autoload guarantees this is impossible — PersistenceLayer pos 1 must Ready before GSM pos 2 subscribes。If somehow violated → `write_completed` never fires (Initialising / Corrupt substate doesn't emit) → GSM never sees Contract 11 telemetry → MVP gate decision 失準。**Test**: AC enforces autoload order via project.godot inspection。

## Dependencies

### Upstream Dependencies (this system requires)

**None.** PersistenceLayer 係 Foundation layer leaf-edge — autoload position 1，唔需要任何其他 game system pre-loaded。

**Engine / platform 依賴 (非 system-level)**：

- Godot 4.6 Autoload mechanism (statically typed singleton, position 1 per ADR-006 Contract 4)
- Godot 4.6 `FileAccess.open / store_string / get_as_text / close` API (return-bool semantics 4.4+)
- Godot 4.6 `JSON.parse_string / JSON.stringify` (Dictionary / Variant serialization)
- Godot 4.6 signal system (typed signal signatures)
- `Time.get_ticks_msec()` (monotonic milliseconds for Formula 1 drift detection + migration step budget)
- `Time.get_unix_time_from_system()` (wall-clock anchor for Formula 1)
- `Object.get_script().get_global_name()` (Contract 3 explicit class_name resolution — NOT `Object.get_class()` per Rule 4 binding)
- Browser IndexedDB (Web Export `user://` 後台 sync layer — initial sync 喺 GDScript `_ready()` 之前完成 per Contract 4 Phase A)

### Downstream Dependents (systems that depend on this)

**Hard dependents** (call PersistenceLayer API directly OR subscribe to typed signals)：

| # | System | Layer | Tier | Nature of dependency |
|---|--------|-------|------|----------------------|
| 1 | GameStateMachine ★ (bidirectional hard, but PersistenceLayer doesn't depend back) | Foundation | VS | (a) `read()` at boot to bootstrap `current_state` + `pending_transition` + `loot_reveal_*` + `_last_weekly_tick_unix` + `_transition_id_counter` + `schema_version` (7 keys); (b) `write()` per state transition (Rule 2 step 2 = tombstone write，step 4 = final state + tombstone clear，step 5 = delete tombstone); (c) `touch()` per Safari ITP refresh (GSM Rule 1); (d) `migrate(from, to)` on schema mismatch (per GDD #1 §Edge Case "持久化 state 損壞或 schema 不識別"); (e) listens `critical_save_failed` 觸發 GDD #1 Rule 5 priority 5 corrupt-save path → boot to `Idle`; (f) listens `write_completed`，filter `key == "pending_transition"`，emit 自己嘅 Contract 11 `tombstone_write_completed(transition_id, latency_ms)` signal。**Reciprocity**: GDD #1 line 360 已 list #3 PersistenceLayer 為 hard dep with `IPersistence` interface 同 sync `read()` contract — locked。|
| 2 | GymSys Backend Client | Foundation | VS | (a) `read()` at boot to bootstrap `session_token` + `_committed_tombstones` + `_last_known_state` (3 keys); (b) `write()` for 3 keys during runtime per GDD #2 Rule 6; (c) uses `is_expired(committed_at, 35 * 86400)` helper for `_committed_tombstones` age-pruning per GDD #2 Rule 15; (d) listens `critical_save_failed` 觸發 GDD #2 `persistence_volatile()` signal (per GDD #2 Edge Case "Chrome Incognito refuses IndexedDB persistence")。**Reciprocity**: GDD #2 line 453 已 list #3 PersistenceLayer 為 hard dep with 3 keys 同 sync-read contract — locked。|
| 28 | Telemetry / Analytics (inferred) | Polish | Pre-MVP | Subscribes to ALL 6 generic signals (`write_completed / flush_completed / delete_completed / migration_step_completed / critical_save_failed / corrupt_save_recovered`) for funnel + error rate tracking + MVP gate IDB fence loss rate measurement (Rule 7 / Contract 11)。|

**Soft / indirect dependents** (使用 PersistenceLayer 間接 via #1 GSM 或 #2 GymSys Client)：

| # | System | Layer | Tier | Nature |
|---|--------|-------|------|--------|
| 8 | Streak System | Foundation | Pre-MVP | Per systems-index — will likely become first system to adopt Rule 12 `streak.*` namespace convention. Reads/writes daily counter + uses `is_expired()` helper for window check。Defer to #8 GDD authoring。|
| 9 | Workout State Tracker (inferred) | Core | VS | indirect via GSM (subscribes GSM signals) — no direct PersistenceLayer API call expected。|
| 10 | Exercise → Class Mapping | Core | Pre-MVP | Indirect via GSM — class mapping data may be persisted to `gsm.exercise_class_map` (TBD when #10 GDD authored)。|
| 11 | Stat System (inferred) | Core | VS | Indirect via GSM — stat persistence likely under `gsm.stats.*` (TBD)。|
| 12 | Ability System | Core | VS | Indirect via GSM — ability unlock state under `gsm.abilities.*` (TBD)。|
| 15 | Loot Drop System ⚠️ | Core | Pre-MVP | Indirect via GSM — LootPayload Resource (extends SerializableResource per Rule 4) 由 GSM persist 喺 `loot_reveal_payload`。|
| 16 | Boss System | Feature | VS | Indirect via GSM — BossPayload Resource (extends SerializableResource per Rule 4) 由 GSM persist 喺 `pending_transition.payload`。|
| 17 | Equipment & Inventory | Feature | MVP | Indirect via GSM — inventory state under `gsm.inventory.*` (TBD)。|
| 18 | PR Detection & Avatar Progression | Feature | Pre-MVP | Indirect via GSM — PR history under `gsm.pr_history.*` (TBD)。|
| 19 | Zone System ⚠️ | Feature | MVP | Indirect via GSM — zone unlock state under `gsm.zones.*` (TBD)。|
| 33 | Attention Budget & Interaction Policy | Core | Pre-MVP | Indirect — derives from GSM `current_state`，唔直接讀 PersistenceLayer。|

### Bidirectional Consistency Check

呢度列出嘅 dependents 必須喺自己嘅 GDD 寫 "depends on: #3 PersistenceLayer"。當以下 GDD 寫成時，需要 cross-check：

- **#1 GameStateMachine ✓** — 已 written (Approved 2026-05-25)；Rule 2 step 2/4/5 + Rule 5 reconciliation + IPersistence interface call sites 全部 locked 對應本 GDD Detailed Design 內容。No reciprocity gap。
- **#2 GymSys Backend Client ✓** — 已 written (Approved 2026-05-26)；Rule 6 (`session_token` storage path) + Rule 15 (`_committed_tombstones` age-pruning) + Edge Cases Resource & Storage path 全部 locked 對應本 GDD。No reciprocity gap。
- **#8 Streak System** (Not Started) — 必須引用 `IPersistence.read/write` + `is_expired()` helper for daily-window check + Rule 12 namespace convention adoption。
- **#9 Workout State Tracker** (Not Started) — 一般 indirect via GSM；若 direct PersistenceLayer access 需要 namespace prefix `wst.*` per Rule 12。
- **#28 Telemetry** (Not Started) — 必須引用 6 generic signals (`write_completed / flush_completed / delete_completed / migration_step_completed / critical_save_failed / corrupt_save_recovered`) for MVP gate IDB fence measurement。
- **#10 / #11 / #12 / #15 / #16 / #17 / #18 / #19 / #33** (Not Started) — 全部 indirect via GSM expected；若 direct access 需要 namespace prefix per Rule 12。

**Provisional lock note**: 全部 cross-system contracts (IPersistence interface, key schema, signal signatures) 喺 reciprocal GDDs 未寫前 unilaterally locked from this side. Defer to reciprocal-GDD authoring; revisit at `/review-all-gdds` pass.

### ADR binding

**ADR-006 State Machine Contract** (RATIFIED 2026-05-25, Status: Proposed) — 6 Contracts directly bind this GDD：
- **C3**: SerializableResource envelope — explicit `to_dict/from_dict` + `payload_type` via `get_script().get_global_name()` (Rule 4)
- **C4**: Autoload position 1 + per-autoload sequential `_enter_tree → _ready` + sync `_ready()` (Rule 1 + States and Transitions)
- **C9**: Wall-clock TTL with drift tolerance + monotonic fallback (Rule 8 + Formula 1)
- **C10**: Schema migration bounded chain (`MAX_MIGRATION_CHAIN_LENGTH = 6`, `MIGRATION_BUDGET_MS = 150ms`) (Rule 5)
- **C11**: Best-effort IDB fence VS tier — NO `await`，emit `write_completed` telemetry (Rule 7 + Rule 11)
- **C14**: Test Spy Contract — `attach_write_spy / attach_delete_spy / clear_spies` interface (Rule 6)

**ADR-003 PersistenceLayer Save State Strategy** (NOT YET WRITTEN — to be authored from this GDD as input scope) — will lock：
- Backend-primary vs localStorage-cache topology (per game-concept Technical Considerations "backend-primary, localStorage cache for offline boot")
- Conflict resolution between cached + backend state (last-write-wins vs vector clock vs CRDT)
- Offline-mode storage tier choice
- Schema migration step implementations (`_migrate_one_step(N → N+1)` per version pair)
- `MAX_STATE_FILE_BYTES` enforcement (Edge Case Boot/File I/O — 1MB sanity cap)
- `int64 > 2^53` precision wraparound assert for `_transition_id_counter` (Edge Case Serialization Envelope)
- `payload_type` rename migration policy (Edge Case Serialization Envelope)
- Class rename = schema version bump policy
- **CD-CASCADE-D NEW (proposed)**: Schema downgrade policy = no support (Edge Case Schema Migration)

**ADR-004 CORS / Cross-Origin Auth Topology** (NOT YET WRITTEN) — indirect: deployment topology decision affects whether `user://state.json` is the ONLY persistence tier (same-origin) vs needs additional cross-origin coordination. PersistenceLayer 本身 unaffected — backend sync 由 #2 GymSys Client 處理。

## Tuning Knobs

所有時間單位以秒為準（除非另外註明）。每個 knob 列：default、safe range、太低嘅後果、太高嘅後果。

### Owned by PersistenceLayer

| Knob | Default | Safe Range | Too Low | Too High |
|------|---------|------------|---------|----------|
| `MAX_MIGRATION_CHAIN_LENGTH` (ADR-006 Contract 10) | **6** | **1 .. 20** | < 1 → 唔可以 migrate 任何 version pair → 任何 schema bump 即 corrupt path → user lose all data on version upgrade | > 20 (at 150ms/step) → 20 × 150ms = 3000ms migration ceiling → 加 WASM init 超過 web boot expectation。Version jump > 6 應用 batch migration squash，唔係加 chain length | 
| `MIGRATION_BUDGET_MS` (ADR-006 Contract 10) | **150ms / step** | **50 .. 500** | < 50ms → 正常 migration step (e.g. iterate 200 records) 被 false-timeout → corrupt path → data loss | > 500ms × 6 = 3000ms migration ceiling + 加 WASM init = cold start > 5s → web user abandon |
| `FLUSH_DEBOUNCE_MS` (Rule 2 / Rule 3 debounced flush) | **100ms** | **50 .. 2000** | < 50ms → debounce 接近 per-write flush → write amplification 重現；多 flush 嘅 workout session 喺 mobile Safari 有 jank | > 2000ms → tab close within debounce window → non-critical state loss window 過大（critical tombstone 唔受影響 per Rule 2 flush=true） |
| `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` (Formula 1 + Contract 9) | 300s (5 min) | **60 .. 3600** | < 60 → 正常 NTP second-tick jitter (typically 1-30s correction) 觸發 false drift detection → monotonic fallback under-pessimistic → expiry 提早 trigger | > 3600 → real day-long manual time change 逃過 detection → silent stale data accepted as fresh → Pillar 1 indirect violation (e.g. expired tombstone treated as valid) |
| `MAX_STATE_FILE_BYTES` (Edge Cases Boot/File I/O — defensive parse limit) | 1_048_576 (1 MB) | **131_072 .. 16_777_216** (128 KB .. 16 MB) | < 128 KB → 正常 Mirror Hero account 累積 LootDrop cache + workout history 撐爆 limit → corrupt path → user 「無故」lost progress | > 16 MB → malicious / accidental huge file 觸發 OOM 喺 mobile Safari → autoload `_ready()` exception → game crash on boot |

### Read-only by PersistenceLayer (owned elsewhere — referenced for context)

| Knob | Owner GDD | Why PersistenceLayer cares |
|------|-----------|---------------------------|
| `SCHEMA_VERSION` (const = 1) | Compile-time const in PersistenceLayer source | 唔算 tuning knob — schema bumps = code change，require new migration step in `_migrate_one_step` switch。Bumping requires PR + tests，唔係 runtime tweak。|
| `COMMITTED_TOMBSTONE_RETENTION_DAYS` (default 35d) | GDD #2 GymSys Backend Client | Used by GymSys Client via `is_expired(committed_at, 35 * 86400)` 做 age-pruning。PersistenceLayer 提供 helper，唔擁有 retention policy。|
| `LOOTDROP_PENDING_TTL_DAYS` (default 6d soft cap) | GDD #1 GameStateMachine (Decision #1) | Used by GSM via `is_expired(loot_added_unix, 6 * 86400)`。Soft cap Safari ITP 7-day 之前 touch-refresh。|
| `LOOTDROP_PENDING_HARD_CAP_DAYS` (default 30d) | GDD #1 GameStateMachine (Decision #1) | Hard cap → force-transition on boot per GSM Rule 5 priority 0.5。|
| `SUSPENSION_TTL_SECONDS` (default 86400) | GDD #1 GameStateMachine | Used via `is_expired(suspend_started_unix, 86400)` for resume-vs-fresh-boot decision。|

### Knobs explicitly NOT exposed (compile-time constants)

- **`SCHEMA_VERSION`** — compile-time const in `persistence_layer.gd`。每次 bump 對應一個新 `_migrate_one_step` case，requires PR review + migration test。NOT a runtime tweak。
- **`user://state.json` file path** — compile-time。Web Export → IndexedDB；Desktop → local AppData。Changing 等於 break 所有現存 user installs (data not migrated to new path)。
- **Namespace prefix strings** (`gsm.*`, `gym.*`, `_internal.*`) — compile-time per Rule 12 convention。新增 namespace 需要 GDD update + CI lint extension。
- **Signal names** (`write_completed`, `delete_completed`, `migration_step_completed`, `critical_save_failed`, `corrupt_save_recovered`) — protocol contract per Rule 11；rename = breaking change to all consumers。
- **`IPersistence` interface methods** (`read / write / delete / migrate / is_expired / touch / attach_*_spy / clear_spies`) — protocol contract per Rule 6 + Contract 14；rename = breaking change。

### Tuning Knob Interaction Warnings (cross-knob invariants)

| # | Invariant | At defaults | At worst safe boundary | Why |
|---|-----------|-------------|------------------------|-----|
| 1 | `MAX_MIGRATION_CHAIN_LENGTH × MIGRATION_BUDGET_MS ≤ 900ms` (total migration ceiling，加 WASM init ~2s = total cold start < 3s no-migration，< 4s with migration) | 6 × 150 = 900 ✓ (500ms headroom from 4s web budget) | 20 × 500 = 10_000ms ✗ — at upper safe boundaries, migration alone = 10s = total cold start ~12s = unacceptable | Runtime assert at autoload boot: `assert(MAX_MIGRATION_CHAIN_LENGTH * MIGRATION_BUDGET_MS <= 900, "Migration ceiling exceeds 900ms — adjust knobs or squash migration steps")` |
| 2 | `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS >= 60` (Formula 1 lower precondition) | 300 ≥ 60 ✓ | 60 ≥ 60 ✓ | Below 60s, second-tick NTP jitter (1-30s typical) triggers false-drift → monotonic fallback under-pessimistic |
| 3 | `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS <= 3600` (Formula 1 upper precondition) | 300 ≤ 3600 ✓ | 3600 ≤ 3600 ✓ | Above 1 hour, real day-long manual clock change escapes detection → silent stale-data accepted |
| 4 | `MAX_STATE_FILE_BYTES >= 131_072` (128 KB minimum for normal Mirror Hero accumulated state) | 1_048_576 (1 MB) ≥ 131_072 ✓ | 131_072 ≥ 131_072 ✓ (tight equality at lower boundary) | Estimated max normal state size: ~50 KB (workout history) + ~60 KB (LootDrop cache) + ~20 KB (misc) ≈ 130 KB；safety margin = 2x at default。Below 128 KB → false-corrupt path on real accounts |

**Safe range derivations**:
- `MAX_MIGRATION_CHAIN_LENGTH` upper bound = `5000ms / MIGRATION_BUDGET_MS_LOWER (100ms)` = 50 — designer can pick chain length OR step budget, but not both at upper extreme。
- `MIGRATION_BUDGET_MS` upper bound = `5000ms / MAX_MIGRATION_CHAIN_LENGTH_LOWER (1)` = 5000ms — but practical upper = 2000ms (single-step longer than 2s = poor UX even with `chain_length = 1`)。
- `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` range derived from Formula 1 boundary analysis — below 60s false-positive; above 3600s false-negative。
- `MAX_STATE_FILE_BYTES` upper bound = mobile Safari WASM heap ceiling ~256 MB / 16 (10% headroom assuming JSON parse uses 16x file size in transient memory) = 16 MB ceiling。

## Visual/Audio Requirements

N/A — pure infrastructure. PersistenceLayer 操作冇 visual / audio surface。所有 player-facing reactions to persistence state (e.g. "Storage 不可用" blocking modal, "Save failed — please refresh" toast, schema migration progress spinner) are owned by downstream UI systems — primarily **#24 Login / GymSys Connection UI** subscribing to `critical_save_failed` signal。

## UI Requirements

N/A — pure infrastructure. PersistenceLayer 暴露 typed signals + sync I/O API surface consumed by other autoloads。UI surfaces (corrupt-save modal, quota-exhausted toast, migration progress UI, Private Mode warning) are owned elsewhere — see **#24 Login / GymSys Connection UI** which subscribes to `critical_save_failed` 並 surface 適當 UX per error_code (per cross-cascade Q-X12 NEW)。

## Acceptance Criteria

全部 32 ACs 用 Given-When-Then 格式。Test type: Unit / Integration / Static / Manual。Evidence path：`tests/unit/persistence-layer/`、`tests/integration/persistence-layer/`、`tools/ci/`（架構靜態檢查）。

**Test infrastructure preconditions** (extends GDD #1 ADR-006 Contract 14 Test Spy Contract):

- `PersistenceLayer` autoload 接受 constructor injection (`new(file_factory: IFileFactory = ProductionFileFactory.new(), clock: IClock = SystemClock.new(), schema_version_override: int = -1)`) — `schema_version_override >= 0` 時 override compile-time `SCHEMA_VERSION` constant，畀 migration chain tests 模擬跨 version scenarios（e.g. `new(..., schema_version_override: 11)` = pretend SCHEMA_VERSION == 11 for AC-08 fail-fast test）
- `IFileFactory` interface — mock spawns trackable `MockFileAccess` instances; allow per-test data injection (file_exists, file_content, open_fail, store_string_fail, file_length_override)
- `MockFileAccess.attach_open_spy(Callable) + attach_store_spy(Callable) + attach_close_spy(Callable)`
- `IClock.advance(seconds)` — controlled time advance for Formula 1 drift tests
- `MockPersistenceLayer` (test fixture) — full IPersistence interface impl recording all calls to `_write_log: Array[Dictionary]`、`_delete_log: Array[String]`
- Test seams: `_test_get_substate() -> String`, `_test_get_cache_snapshot() -> Dictionary`, `_test_can_lookup_payload(payload_type: String) -> bool` — guarded by `OS.is_debug_build()`；production no-op
- **`_test_force_substate(name: StringName) -> void` (D3)** — debug seam to force PersistenceLayer into any substate for boundary testing (Initialising / Migrating / Ready / Corrupt)；guarded by `OS.is_debug_build()`；production no-op；唔 bypass transition logic — 只 set internal substate enum，用於 AC-23 substate matrix testing

### Core Rule Enforcement (Rules 1-13)

- **AC-01** (Rule 1 — sync interface discipline): **GIVEN** all `.gd` files under `src/foundation/persistence/`, **WHEN** CI script `tools/ci/check_no_await_in_persistence.sh` greps for `\bawait\b`, **THEN** zero matches total。
  - **Test type**: Static / CI | **Evidence**: `tools/ci/check_no_await_in_persistence.sh`
- **AC-02** (Rule 2 — in-memory cache O(1) read): **GIVEN** mock `IPersistence.write("foo", "bar")` called once，then `MockFileAccess.attach_open_spy(open_log.append)`, **WHEN** `read("foo")` called 1000 times consecutively, **THEN** `open_log.size() == 0` (zero file I/O on read path)；returned value == `"bar"` for all 1000 calls。
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_in_memory_cache_read.gd`
- **AC-03** (Rule 2 — cache-disk invariant, critical flush path): **GIVEN** mock `IPersistence` AND `MockFileAccess.store_string_fail = true`, **WHEN** `write("foo", "bar", true)` (**flush=true**, critical path) executes, **THEN** `write()` returns `false`；`_test_get_cache_snapshot().get("foo") == null` (cache reverted per Rule 9 wipe)；`critical_save_failed("FLUSH_FAILED", "")` emit count == 1。*Note: `flush=false` (default debounce) path behaves differently — `write()` returns `true` immediately (cache mutation success); Rule 9 triggers later when debounce timer fires and flush fails. That path is covered by AC-15 trigger condition #6.*
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_cache_disk_invariant.gd`
- **AC-04** (Rule 3 — atomic file write single sequence): **GIVEN** `MockFileAccess.attach_open_spy` + `attach_store_spy` + `attach_close_spy`, **WHEN** `write("foo", "bar")` called once, **THEN** spy call counts: `open_spy.call_count == 1`, `store_spy.call_count == 1` (single write call, NOT per-key incremental), `close_spy.call_count == 1`；store payload = `JSON.stringify(_cache)` (full dict)。
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_atomic_file_write_pattern.gd`
- **AC-05** (Rule 4 — SerializableResource envelope round-trip): **GIVEN** `BossPayload.new()` with `outcome = BossOutcome.DEFEATED`, `boss_id = 42`, `hp_at_interrupt = 100`, `hp_max = 200`, **WHEN** `write("pending_transition", { "payload": boss.to_dict(), "payload_type": boss.get_script().get_global_name() })` then `read("pending_transition")` then `BossPayload.from_dict(read_result.payload)`, **THEN** restored `outcome == BossOutcome.DEFEATED` (enum integer match), `boss_id == 42`, `hp_at_interrupt == 100`, `hp_max == 200`；`payload_type == "BossPayload"` (NOT `"Resource"`)。
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_serializable_resource_round_trip.gd`
- **AC-06** (Rule 4 — payload_type via get_script discipline): **GIVEN** all `.gd` files under `src/`, **WHEN** CI grep for `payload_type.*=.*\.get_class\(`, **THEN** zero matches (only `get_script().get_global_name()` allowed for payload_type)。
  - **Test type**: Static / CI | **Evidence**: `tools/ci/check_payload_type_uses_get_script.sh`
- **AC-07** (Rule 5 — schema migration bounded chain + migration_step_completed emission): **GIVEN** mock file content `{ "schema_version": 0 }` AND `schema_version_override = 3` (mock SCHEMA_VERSION = 3) AND each `_migrate_one_step` takes 100ms (controlled via `IClock.advance`), **WHEN** `_ready()` runs, **THEN** chain executes step 0→1, 1→2, 2→3；total elapsed_ms < `MIGRATION_CHAIN_LENGTH × MIGRATION_BUDGET_MS` (900ms ceiling)；**3 `migration_step_completed` signals emit (one per step) with verified args: `(from_version == N, to_version == N+1, latency_ms ≈ 100 ± 10ms)` for each N in {0, 1, 2}**；**zero `write_completed` signals emit during migration** (write_completed suppressed per D1)；final `_test_get_cache_snapshot().schema_version == 3`；`_test_get_substate() == "Ready"`. **AC-07b (budget boundary)**: **GIVEN** mock `_migrate_one_step` taking exactly `MIGRATION_BUDGET_MS - 1 = 149ms` (just below budget), **WHEN** executed, **THEN** step PASSES (no timeout)；`migrate()` returns true；step `migration_step_completed` emits with `latency_ms ≈ 149 ± 5ms`。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_migration_chain_normal.gd`
- **AC-08** (Rule 5 — migration chain length fail-fast): **GIVEN** mock file `{ "schema_version": 0 }` AND `schema_version_override = 11` (mock SCHEMA_VERSION = 11，gap = 11 > MAX_MIGRATION_CHAIN_LENGTH = 6), **WHEN** `_ready()` runs, **THEN** fail-fast pre-check triggers BEFORE any step executes；**`migration_step_completed` emit count == 0** (zero steps ran)；`critical_save_failed("MIGRATION_CHAIN_TOO_LONG", "")` emit count == 1；enter Corrupt substate；`_test_get_cache_snapshot()` == `{ "schema_version": 11 }` (post-wipe re-init at current version)。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_migration_chain_too_long.gd`
- **AC-09** (Rule 5 — migration step budget cap): **GIVEN** mock `_migrate_one_step` that takes 200ms (exceeds `MIGRATION_BUDGET_MS = 150ms`), **WHEN** boot triggers migration, **THEN** `migrate()` return false；`critical_save_failed("MIGRATION_TIMEOUT", "step_0_to_1")` emit count == 1；enter Corrupt substate。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_migration_step_timeout.gd`
- **AC-10** (Rule 5.6 — atomic-or-fail-loud sub-clause): **GIVEN** mock `_migrate_one_step(1→2)` that mutates cache then fails write mid-step, **WHEN** boot executes, **THEN** post-fail `_test_get_cache_snapshot().schema_version == 1` (revert to pre-step snapshot, NOT 2 partial)；migrate return false；critical_save_failed emit。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_migration_atomic_fail_loud.gd`
- **AC-11** (Rule 6 — test spy contract production no-op): **GIVEN** production `PersistenceLayer` (NOT mock) AND `attach_write_spy(my_cb)` called, **WHEN** `write("foo", "bar")` executes, **THEN** `my_cb` NEVER invoked (production spy methods are no-op)；no error/warning emitted。
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_production_spy_noop.gd`
- **AC-12** (Rule 6 — MockPersistenceLayer spy records): **GIVEN** `MockPersistenceLayer` instance with `attach_write_spy(write_log.append) + attach_delete_spy(delete_log.append)`, **WHEN** `write("foo", "bar") + write("baz", 42) + delete("foo")` called in sequence, **THEN** `write_log == [{"key": "foo", "value": "bar"}, {"key": "baz", "value": 42}]`；`delete_log == ["foo"]`。
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_mock_spy_records.gd`
- **AC-13** (Rule 7 — VS IDB fence no-await, synchronous emit): **GIVEN** signal counter attached to `write_completed` before call, **WHEN** `write("foo", "bar")` returns, **THEN** `write_completed` emit count == 1 **within same call stack** (verified by counter reading immediately after `write()` returns, before any `await` or frame yield)；signal args: `key == "foo"`, `is_touch == false`. *Note: no wall-clock timing assertion — headless GUT runner has variable CPU scheduling; synchronous emission is the testable invariant.*
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_no_await_sync_return.gd`
- **AC-14** (Rule 8 — is_expired Formula 1 boundary table, 6-row parameterised): **GIVEN** mock `IClock` with controllable wall-clock + monotonic, **WHEN** each row of Formula 1 behaviour matrix executed (normal not-expired / normal expired / NTP +600s drift / DST +3600s / clock rollback / mono omitted), **THEN** return value matches expected per matrix row; pure-function assertion: `_test_get_cache_snapshot()` 喺 call 前後 byte-identical (no mutation)。
  - **Test type**: Unit (table-driven, 6 cases) | **Evidence**: `tests/unit/persistence-layer/test_is_expired_formula.gd`
- **AC-15** (Rule 9 — corrupt detection: 6 trigger conditions, table-driven): **GIVEN** each of the following 6 trigger conditions, **WHEN** boot or runtime API hits trigger, **THEN** for each: `user://state.json` content post-recovery == `{ "schema_version": SCHEMA_VERSION }`；`_test_get_cache_snapshot()` == same；`critical_save_failed(error_code, key)` emit count == 1 with correct `error_code`；`_test_get_substate() == "Corrupt"`:
  | # | Trigger condition | Expected error_code | key |
  |---|---|----|---|
  | 1 | `JSON.parse_string(file_content)` returns null | `"INVALID_JSON"` | `""` |
  | 2 | Parse result not Dictionary (e.g. JSON array) | `"INVALID_JSON"` | `""` |
  | 3 | Parsed Dict missing `schema_version` key | `"INVALID_JSON"` | `""` |
  | 4 | `migrate()` returns false (chain timeout / length cap) | `"MIGRATION_TIMEOUT"` or `"MIGRATION_CHAIN_TOO_LONG"` | `""` |
  | 5 | `from_dict()` encounters unregistered `payload_type` | `"UNREGISTERED_PAYLOAD_TYPE"` | (key containing payload) |
  | 6 | `_flush_dirty()` returns false (MEMFS write error) | `"FLUSH_FAILED"` | `""` |
  - **Test type**: Integration (table-driven, 6 sub-cases) | **Evidence**: `tests/integration/persistence-layer/test_corrupt_detection_matrix.gd`
- **AC-15b** (Rule 9 — corrupt_save_recovered emission + signal order): **GIVEN** mock `IFileFactory` with `file_content = '{"schema_version": 1, "foo": "bar"}'` (25 bytes) AND signal order recorder attached to both `corrupt_save_recovered` and `critical_save_failed`, **WHEN** any Rule 9 trigger fires (e.g. INVALID_JSON), **THEN** `corrupt_save_recovered(wiped_byte_count == 25)` emits FIRST；`critical_save_failed` emits AFTER；signal order: `corrupt_save_recovered` precedes `critical_save_failed`（verified by order log index）。**Edge**: if file didn't exist → `wiped_byte_count == 0`。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_corrupt_save_recovered_emission.gd`
- **AC-16** (Rule 9 — corrupt is sticky single-emit): **GIVEN** Corrupt substate entered (Rule 9 fired), **WHEN** subsequent 100 `write()` calls execute, **THEN** all 100 succeed (cache mutation allowed in Corrupt)；`critical_save_failed` emit count stays at 1 (NOT re-emit per call)；exit from Corrupt requires session restart (no auto-recovery test path)。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_corrupt_sticky_single_emit.gd`
- **AC-17** (Rule 10 — Safari ITP touch refresh emits write_completed with is_touch=true): **GIVEN** `write("foo", "bar")` called once, **WHEN** `touch("foo")` called, **THEN** `write_completed.emit` 第二次 called with `is_touch: true`；cache value unchanged；file content unchanged (same JSON bytes)。
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_touch_refresh.gd`
- **AC-18** (Rule 11 — telemetry signal surface introspection): **GIVEN** PersistenceLayer autoload instantiated, **WHEN** `get_signal_list()` introspected, **THEN** **6** declared signals present with exact signatures: `write_completed: (key: String, latency_ms: int, is_touch: bool)`, `flush_completed: (flushed_key_count: int, latency_ms: int, is_critical: bool)`, `delete_completed: (key: String, latency_ms: int)`, `migration_step_completed: (from_version: int, to_version: int, latency_ms: int)`, `critical_save_failed: (error_code: String, key: String)`, `corrupt_save_recovered: (wiped_byte_count: int)`；assert each signal name + arg count + arg type via introspection。
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_signal_contract_introspection.gd`
- **AC-19** (Rule 11 — split owner: PersistenceLayer never emits tombstone_write_completed): **GIVEN** all `.gd` files under `src/foundation/persistence/`, **WHEN** CI grep for `tombstone_write_completed`, **THEN** zero matches (signal owned by GSM, NOT PersistenceLayer)。
  - **Test type**: Static / CI | **Evidence**: `tools/ci/check_no_tombstone_signal_in_persistence.sh`
- **AC-20** (Rule 12 — namespace convention push_warning): **GIVEN** debug build PersistenceLayer AND `MockLogger.attach_warning_spy(warning_log.append)`, **WHEN** `write("bare_key", "val")` called (no namespace prefix), **THEN** `warning_log` contains exactly one entry matching pattern `Key 'bare_key' lacks namespace prefix`；`write()` still returns true (NOT enforce — push_warning only)。
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_namespace_warning.gd`
- **AC-21** (Rule 12 — namespace prefix acceptance): **GIVEN** debug build PersistenceLayer AND warning spy, **WHEN** `write("gsm.current_state", "idle") + write("gym.session_token", "tk") + write("_internal.schema_version", 1)` called, **THEN** zero warnings emitted (all keys match accepted namespaces)；all writes return true。
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_namespace_acceptance.gd`
- **AC-22** (Rule 13 — migration idempotency replay): **GIVEN** `_migrate_one_step(1→2)` implementation with idempotent guard `if "new_key" not in _cache`, **WHEN** step is executed 3 times consecutively on same input, **THEN** post-third-run cache state byte-identical to post-first-run state；no errors emitted。
  - **Test type**: Unit | **Evidence**: `tests/unit/persistence-layer/test_migration_idempotent.gd`

### Substate Transitions

- **AC-23** (Substate matrix — 4 substates × API behaviour, self-contained): **GIVEN** PersistenceLayer in each of 4 substates (Initialising / Migrating / Ready / Corrupt), **WHEN** test driver calls each of 4 API methods, **THEN** behaviour matches the following table exactly (16 cells):
  | Substate | `read(key)` | `write(key, val)` | `delete(key)` | `migrate()` |
  |---|---|---|---|---|
  | Initialising | assert crash (debug) / null + `critical_save_failed("NOT_READY",key)` (release) | assert crash (debug) / false + `critical_save_failed("NOT_READY",key)` (release) | same as write | assert crash (debug) |
  | Migrating | null + `critical_save_failed("MIGRATION_IN_PROGRESS", key)` | false + `critical_save_failed("MIGRATION_IN_PROGRESS", key)` | false + `critical_save_failed("MIGRATION_IN_PROGRESS", key)` | accepted (chain continues) |
  | Ready | `_cache.get(key)` (Dictionary value or null if absent) | true (cache mutated + dirty) | true (key removed + dirty) | runs migration if schema mismatch |
  | Corrupt | `{}` / null per key (fresh wiped cache) | true (writes to wiped cache) | true (removes from wiped cache) | disabled (no-op return false) |
  - **Test type**: Integration (table-driven, 16 cells) | **Evidence**: `tests/integration/persistence-layer/test_substate_api_matrix.gd`
- **AC-24** (Substate transition: Initialising → Ready normal): **GIVEN** mock file `{ "schema_version": 1 }` matching SCHEMA_VERSION, **WHEN** `_ready()` runs, **THEN** `_test_get_substate()` sequence: `"Initialising"` → `"Ready"` (no Migrating intermediate, no Corrupt)。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_substate_initialising_to_ready.gd`
- **AC-25** (Substate transition: Initialising → Migrating → Ready): **GIVEN** mock file `{ "schema_version": 0 }` AND SCHEMA_VERSION = 1, **WHEN** `_ready()` runs, **THEN** substate sequence: `"Initialising"` → `"Migrating"` → `"Ready"`；while in Migrating, `read("foo")` returns null + emits `critical_save_failed("MIGRATION_IN_PROGRESS", "foo")`。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_substate_initialising_to_migrating_to_ready.gd`

### Edge Case Coverage (representative — full set per Edge Cases section)

- **AC-26** (Edge: first boot — no file exists): **GIVEN** mock `MockFileAccess.file_exists = false`, **WHEN** `_ready()` runs, **THEN** `_cache == { "schema_version": SCHEMA_VERSION }`；atomic write fires once；NO `critical_save_failed` emit (first-boot is not corruption)；enter Ready substate。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_first_boot.gd`
- **AC-27** (Edge: file size sanity cap): **GIVEN** mock `MockFileAccess.file_length = 2_000_000` (2 MB > 1 MB MAX_STATE_FILE_BYTES default), **WHEN** `_ready()` runs, **THEN** parse skipped → corrupt path → `critical_save_failed("FILE_TOO_LARGE", "")` emit。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_file_size_cap.gd`
- **AC-28** (Edge: schema downgrade): **GIVEN** mock file `{ "schema_version": 5 }` AND `SCHEMA_VERSION = 1`, **WHEN** `_ready()` runs, **THEN** corrupt path → `critical_save_failed("SCHEMA_DOWNGRADE", "")` emit；wipe + re-init at SCHEMA_VERSION = 1。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_schema_downgrade.gd`
- **AC-29** (Edge: write re-entrance from signal handler): **GIVEN** static analyzer scans handlers connected to `write_completed`, **WHEN** scan executes, **THEN** zero handlers contain `PersistenceLayer.write(` literal pattern (CI lint fail if any consumer re-fires write from within write_completed handler)。
  - **Test type**: Static / CI | **Evidence**: `tools/ci/check_no_write_reentrance.sh`

### Cross-System Contracts

- **AC-30** (Cross-system: GSM consumes signal split): **GIVEN** mock GameStateMachine subscribed to `write_completed`, **WHEN** `write("pending_transition", tombstone_dict)` fires, **THEN** GSM's handler receives `(key: "pending_transition", latency_ms: int, is_touch: false)`；GSM emits its own `tombstone_write_completed(transition_id, latency_ms)` per Contract 11 (verified via spy on GSM signal emission)；PersistenceLayer's own signal list has NO `tombstone_write_completed` entry (cross-ref AC-19)。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_gsm_signal_split.gd`
- **AC-31** (Cross-system: GymSys Client uses is_expired): **GIVEN** mock GymSys Client with `_committed_tombstones = { "tid_A:loot-commit": 1700000000 }` (committed 35d ago) AND `IClock.unix_time = 1700000000 + 35*86400 + 1`, **WHEN** GymSys nightly age-prune sweep runs, **THEN** GymSys calls `PersistenceLayer.is_expired(1700000000, 35*86400)` → returns true → tombstone deleted via `PersistenceLayer.delete("gym._committed_tombstones.tid_A:loot-commit")` (verified via delete spy)。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_gymsys_age_pruning.gd`

### ADR-006 Contract Binding Markers

- **AC-32** (ADR-006 Contract binding evidence — markers + tests): **GATE AC, runs AFTER AC-01..31 implementation**. **GIVEN** PersistenceLayer source file `persistence_layer.gd` AND AC-01..31 implementations complete, **WHEN** CI script `tools/ci/check_adr006_persistence_binding_markers.sh` runs, **THEN** ALL 6 of the following exact comment strings are present in `persistence_layer.gd`:
  1. `# ADR-006 Contract 3: SerializableResource envelope`
  2. `# ADR-006 Contract 4: autoload position 1 + sync _ready`
  3. `# ADR-006 Contract 9: clock-drift TTL`
  4. `# ADR-006 Contract 10: migration chain bounded`
  5. `# ADR-006 Contract 11: best-effort IDB fence`
  6. `# ADR-006 Contract 14: test spy interface`

  AND the following test files exist (one per contract): `tests/unit/persistence-layer/test_adr006_c3_serializable_envelope.gd`, `tests/unit/persistence-layer/test_adr006_c4_autoload_sync.gd`, `tests/unit/persistence-layer/test_adr006_c9_clock_drift_ttl.gd`, `tests/integration/persistence-layer/test_adr006_c10_migration_chain.gd`, `tests/unit/persistence-layer/test_adr006_c11_idb_fence.gd`, `tests/unit/persistence-layer/test_adr006_c14_test_spy.gd`.
  - **Test type**: Static / CI (gate-only — last to run) | **Evidence**: `tools/ci/check_adr006_persistence_binding_markers.sh`
- **AC-33** (Q-E1 — quota exhaustion Stay Ready path): **GIVEN** mock `MockFileAccess.store_string_fail = true` (simulate quota exhaustion) AND PersistenceLayer in Ready substate, **WHEN** `write("foo", "bar")` executes, **THEN** `critical_save_failed("QUOTA_EXHAUSTED", "foo")` emits；`_test_get_substate() == "Ready"` (**NOT** "Corrupt" — quota exhaustion stays Ready per D4)；cache mutation reverted (`_test_get_cache_snapshot().get("foo") == null`)；subsequent `write("baz", 42)` also returns false + emits `critical_save_failed("QUOTA_EXHAUSTED", "baz")` (each failure signals independently，唔 collapse into single emit)。
  - **Test type**: Integration | **Evidence**: `tests/integration/persistence-layer/test_quota_exhaustion_stay_ready.gd`

## Open Questions

呢度收集設計過程中發現需要 follow-up 嘅問題。每個 question 標 owner + suggested resolution。已解決嘅項目 strikethrough 並保留以審計。

| ID | Question | Owner | Status |
|----|----------|-------|--------|
| **Q-E1** (carried from GDD #1 + #2) | Chrome Incognito / Private Mode quota = 0 — reactive `write() → false` 觸發 `critical_save_failed("QUOTA_EXHAUSTED", key)` 之後，game UX 點 handle? Should #24 Login UI show blocking modal? Should game refuse to start? Or degraded-mode warning toast? | game-designer + #24 owner + ux-designer | **OPEN — defer to #24 Login UI GDD authoring**. 本 GDD 只 emit signal；UX 決定由 consumer 接管。**Pillar 3 risk**: Private Mode silently 接 write 後 lose-on-tab-close 違反 anti-lie posture — necessary that #24 surface 呢個 state to user。 |
| **Q-A4** (carried from GDD #1) | Godot 4.6 Web Export COOP/COEP threading default state — 若 enabled → Rule 2 in-memory cache write-through pattern 需要 mutex / atomic primitives? | engine-programmer | OPEN — VS spike 確認 export template thread support 預設狀態 (cross-GDD #1 / #2 / #3 binding)。**PersistenceLayer impact**: 若 threading enabled，`_cache` Dictionary mutation 需要 lock。VS spike outcome 決定 implementation pattern。 |
| **Q-A8** (carried from GDD #2 — re-scoped per this GDD) | Godot 4.6 Web Export `FileAccess.flush()` IDB commit ack timing — exact lag in ms? Loss rate per per-frame tab-kill scenarios? | engine-programmer + VS spike | **OPEN — VS spike scope addition per ADR-006 Contract 11**. 本 GDD Rule 7 + Edge Case "FileAccess.store_string returns true 但 IDB commit fail" 假設 ~1 frame lag + ~0.05% per-transition loss rate；VS spike telemetry measure actual rate；MVP gate review decide 升級至 flush+await。 |
| **Q-X12** NEW | Storage 不可用 (READ_ONLY_FILESYSTEM / QUOTA_EXHAUSTED / Private Mode quota=0) 嘅 UX surface — #24 Login UI 點處理 `critical_save_failed` signal? 多個 error_code 各自需要 different UX? Or generic "Storage 不可用，部分功能可能受限" toast? | ux-designer + #24 owner | **OPEN — binding constraint on #24 Login UI GDD**. 本 GDD 完整 error_code list（`INVALID_JSON / READ_ONLY_FILESYSTEM / MIGRATION_TIMEOUT / MIGRATION_CHAIN_TOO_LONG / QUOTA_EXHAUSTED / SCHEMA_DOWNGRADE / FILE_TOO_LARGE / UNREGISTERED_PAYLOAD_TYPE / FLUSH_FAILED / NOT_READY / MIGRATION_IN_PROGRESS / EMPTY_FILE`）；#24 GDD 必須 close 呢個 question。**Note**: `UNREGISTERED_NAMESPACE` 已移除 — namespace violation 只 emit `push_warning()`，唔係 `critical_save_failed`（Rule 12）。 |
| **Q-X13** NEW (downstream binding for ADR-003) | ADR-003 PersistenceLayer Save State Strategy 必須 lock：(a) backend-primary vs localStorage-cache topology；(b) conflict resolution rules (last-write-wins / vector clock / CRDT)；(c) offline-mode storage tier choice；(d) `_migrate_one_step` implementations per version pair；(e) `MAX_STATE_FILE_BYTES` enforcement；(f) int64 > 2^53 wraparound assert；(g) `payload_type` rename migration policy；(h) schema downgrade policy。 | technical-director (ADR-003 author) | **DOWNSTREAM BINDING** — flag for ADR-003 ratification gate (TD-ARCHITECTURE)。本 GDD 嘅 anti-lie posture + Pillar 3 hard guarantee 由 ADR-003 真正 lock；ADR-003 gate review 必須 verify 8 個 invariants。 |
| **Q-X14** NEW (CD-CASCADE-D — Schema downgrade policy) | Schema downgrade scenario (`schema_version > SCHEMA_VERSION`) — 一律 corrupt path + wipe? 還是 read-only degraded mode allow user export data? | game-designer + technical-director | **OPEN — propose ADR-003 binding**. 本 GDD Edge Case Schema Migration 假設「無 downgrade support」(wipe + start fresh)；若 future user feedback 顯示「我升級後 downgrade 失去 progress」係 painful，需要 ADR-003 amendment 加 read-only export path。Pillar 3 risk acknowledged in Edge Case text。 |
| **Q-X15** NEW (Test mock infrastructure) | `IFileFactory` interface 應該成為 generic test infrastructure (shared with future systems doing file I/O)？或者 PersistenceLayer-specific? | gameplay-programmer + test infra owner | **OPEN — defer to test infra phase**. 若 generic → 應該移到 `tests/helpers/` 共用；若 PersistenceLayer-specific → 維持喺 `tests/unit/persistence-layer/`。當前 AC-01..32 假設 latter。 |

**Resolution gating**:
- **Q-X12** 喺 #24 Login UI GDD authoring 期間 close (cross-cascade UX constraint)
- **Q-X13** 喺 ADR-003 ratification gate close (downstream architectural binding)
- **Q-X14** 喺 ADR-003 schema versioning policy section close
- **Q-X15** 喺 first test infra phase (VS sprint 1) close
- **Q-A4 / Q-A8** 合併入 GDD #1/#2 既有 VS spike scope，VS implementation 開始之前 close
- **Q-E1** 喺 #24 Login UI GDD authoring 期間 close
