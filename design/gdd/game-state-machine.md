# Game State Machine

> **Status**: Approved (Pass 5 lean re-review APPROVED 2026-05-25; Pass 6 lean re-review APPROVED 2026-05-26 — confirmed prior verdict holds after #5/#6 bidirectional Soft dependents addition; 3 advisory polish items applied inline). Pass 4 sync propagated all 15 ratified ADR-006 contracts (Status: Proposed) into GDD prose + ACs. Architectural rigor lives in **`docs/architecture/adr-0006-state-machine-contract.md`**; this GDD remains source-of-truth for FSM topology, pillar enforcement rules, and Decisions #1-5.
> **Author**: Frank + systems-designer + creative-director + gameplay-programmer + godot-specialist + qa-lead
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Infrastructure — no direct pillar, enables Pillar 2 (Frictionless Companion) and Pillar 5 (Mirror Moment)
> **System #**: 1 (Foundation / VS tier)
> **Depends On**: (none)
> **Depended On By**: #33 Attention Budget & Interaction Policy (Pre-MVP); implicitly all runtime systems
> **Creative Director Review (CD-GDD-ALIGN)**: APPROVED 2026-05-25 — all 5 pillars + anti-pillars pass
> **Design Review**: MAJOR REVISION → Revised → NEEDS REVISION (2nd pass) → Revised → NEEDS REVISION (3rd pass) → Revised (surgical 3rd pass) 2026-05-25. Locked decisions binding on this GDD:
> 1. **Client-wins LootDrop forward-recovery** + **natural-pause gated reveal** (Decision #1) — supersedes prior "non-modal toast on resume"; **30-day boundary behavior reframed to force-transition `Booting → LootDrop` on next boot (NOT silent auto-commit) per Pass 3 B1**
> 2. **`BossOutcome` enum** (DEFEATED / INTERRUPTED_WITH_CREDIT / ABANDONED) replaces prior `boss_defeated: bool` (Decision #2)
> 3. **`ExerciseSwitching` → `RestPeriod`** rename, data-driven duration from GymSys (Decision #3)
> 4. **Single-device session lock** + backend-cached LootDrop + `transition_id`-idempotent commits (Decision #4); **401 force-boot deferred to next natural-pause state when current_state ∈ active set per Pass 3 B3**; **post-401 toast immediate on state-mismatch (bypass Decision #1 gating) per Pass 3 B12**
> 5. Storage backend = IndexedDB via Godot `user://` (unchanged from 1st revision)
> 6. **NEW Decision #5 — Weekly Tick Missed-Window Replay** — on boot, if `wall_clock_anchor` since last Idle-entry exceeds weekly window AND missed tick(s) detected, enqueue catch-up `weekly_tick` event(s) BEFORE evaluating Rule 5 priority 1 LootDrop reveal (per Pass 3 B2, Pillar 5 falsifiable test "weekly evolution tick 從來唔錯過、唔重複" protection)

---

## Overview

Game State Machine 係 Mirror Hero 嘅 runtime coordinator —— 任何時候，game 都明確處於一個唯一嘅 top-level state（例如 `Booting`、`Disconnected`、`Idle`、`WorkoutActive`、`RestPeriod`、`CombatActive`、`BossEncounter`、`LootDrop`、`Suspended`），並按定義好嘅 transition rules 喺 states 之間轉換。佢負責三件事：(1) 為其他所有 runtime systems 提供「而家應該做乜」嘅單一答案，避免兩個 system 各自假設不同 game phase；(2) 接收外部事件（GymSys polling、玩家 input、app focus / visibility 變化、save/load 完成、enemy died）並決定佢哋觸發乜 transition；(3) 確保 state 變化能 atomically 持久化到 PersistenceLayer（Godot `user://` → IndexedDB on Web Export），並能喺 mobile Safari context loss / app reload / bfcache restore 之後 deterministically 恢復。

呢個 system 唔包含任何 gameplay logic、UI、art 或 audio —— 佢只係定義「state 嘅形狀」同「transition 嘅 contract」。其他 systems（Workout State Tracker、CombatResolver、EnemyDirector、Loot Drop System、Attention Budget Policy 等）訂閱呢度發出嘅 state-change 信號，並按自己嘅職責對應行動。

## Player Fantasy

**Direct fantasy**: None — Game State Machine 係 infrastructure，玩家唔會 *feel* 個 state machine 本身。

**Indirect fantasy — invisible reliability**:
「鎖屏 → 做 set → 解鎖 → 一切如常。」玩家唔需要諗 game 仲喺唔喺度。State machine 嘅 felt promise 係 *invisible reliability* —— 四週後打開 app，weekly evolution tick 已經啱啱好 fire 過、avatar 真係進化咗、上次 workout 中斷嘅 LootDrop modal 仲喺度等住玩家確認。

**Transparent device handoff** (Decision #4): 喺電話開 workout、揭去 tablet 繼續、再轉返電話 — progress 唔會 lose、loot 唔會 double-grant、唔會見到「session expired」error wall。Backend 出唯一 active session token；舊裝置 silently force-boot 入 reconciliation，玩家只見「已在另一部裝置繼續」嘅 non-blocking toast。

呢個 indirect fantasy 直接 enables：
- **Pillar 2 (無壓力陪伴)** — mobile Safari kill tab、轉 app、電話無電都唔損 progress
- **Pillar 5 (鏡像時刻)** — 每週進化 tick 從來唔錯過、唔重複

**Falsifiable design test**: 任何令玩家懷疑「game 係咪有 lose track」嘅情境（state 重置、weekly tick 失蹤、loot 喺 crash 後消失、boss 打完 reload 後復活）= bug，唔係 acceptable behavior。

## Detailed Rules

### Core Rules

**Rule 1 — Exactly One Active State.**
任何時刻 game 處於唯一一個 top-level state。違反 → hard crash-to-`Booting`，唔係 silent ignore。每個 transition entry point 有 assertion check。

**Rule 2 — Transition Atomicity (Tombstone Pattern).**
一個 transition 係 atomic unit，按以下 fixed order 執行（single-thread guarantees no interruption mid-function — 絕對唔可以喺 transition 函式內部用 `await`）：

0. **Acquire lock**: 檢查 `_transitioning`；若已 held → silently drop（per Rule 4）；否則設 `_transitioning = true`。立即 schedule fallback unlock：`get_tree().create_timer(STATE_TRANSITION_FALLBACK_MS / 1000.0).timeout.connect(_force_clear_lock)`，防止 step 1-7 任一錯誤令 lock 永遠 stuck。
1. **Validate** transition 合法 (guard clause)；若不合法 → release lock + Rule 4 drop。
2. **Write tombstone**: 生成 `transition_id` per **ADR-006 Contract 2** algorithm — `wall_clock_ms × 1000 + persisted_monotonic_counter`, format `"%d_%d_%s_%s" % [wall_clock_ms, counter, from, to]`. Counter persisted under `_transition_id_counter` key (incremented FIRST before formatting; survives WASM reload, NTP clock-drift, account-scoped backend UNIQUE constraint catches rare overlap). **Opaque string** — no code path may parse `transition_id` to recover `from` / `to` / counter (state names may contain `_`); read tombstone Dictionary fields directly if recovery context needed. Then write `pending_transition` 入 `user://state.json`（包含 `transition_id`, `from`, `to`, `payload`, `payload_type` (Contract 3 — sourced from `payload.get_script().get_global_name()`, NOT `Object.get_class()` which returns engine class `"Resource"` and silently breaks forward-recovery), `wall_clock_anchor: Time.get_unix_time_from_system()`, `monotonic_anchor: Time.get_ticks_msec()`）。Resource payloads serialized via `to_dict()` per Contract 3 SerializableResource envelope (NOT raw `JSON.stringify(Resource)` which silently returns `{}`). 失敗（quota exceeded 等）→ emit `critical_save_failed`、release lock、Rule 4 drop。
3. **Write final state**: 覆寫 `user://state.json` 嘅 `current_state` + `schema_version`（同次 IO call commit tombstone + final，避免 partial write window）。失敗 → tombstone 留低、emit `critical_save_failed`、release lock、in-memory **唔可以更新**（phantom-state 防禦）；下次 boot 走 forward-recovery 重做 step 3。
4. **Update in-memory `_current_state`**（**只有** step 3 持久化成功後先做；保證 disk = memory 永遠 monotonic 一致）。
5. **Remove tombstone**（disk）。Idempotent — 若 step 5 失敗 boot 時 tombstone 仍喺，forward-recovery 行 step 5+6+7+8 重做即可，無 side-effect。
6. **Dual-target backend write** (fire-and-forget；per Decision #4 binding ADR-002)：
   a. **State transition POST** — 帶 `transition_id` 畀 GymSys backend dedupe。
   b. **For LootDrop transitions only**: `POST /lootdrop/{transition_id}/cache` 連同完整 payload — 令任何裝置都可以由 backend restore loot。
   實作：spawn orphan `HTTPRequest` node、`add_child()` 到 autoload root、connect `request_completed` 去獨立 handler（handler 負責 `queue_free()` 個 node + 處理 401 → 入 priority-0 force-boot path）。**不可** 喺 transition function 內 `await`。
7. **Emit signal**: `state_changed(from_state, to_state, payload)`. **Emit 喺 release lock 之前** — 任何 subscriber 嘗試 synchronous re-enter `_request_transition()` 都會撞 `_transitioning == true` 而 silently drop（per Rule 4 + AC-04a）。Subscriber 想觸發 follow-up transition 必須用 `call_deferred("_request_transition", ...)` 入 Event Intake Queue 下一 tick 處理。
8. **Release lock**: `_transitioning = false`。

**Forward-recovery on boot** (tab 喺 step 3-7 中途死咗，tombstone 仍喺)：
- 將 tombstone 嘅 `to` 視為 commit target；
- **CRITICAL (ADR-006 Contract 2 binding)**: 從 tombstone 提取 `transition_id` 並 **verbatim reuse** through step 3-8 replay — **NEVER 重新 call `_generate_transition_id()`**。Regeneration 會產生新 ID → backend UNIQUE constraint dedupe 失效 → **double LootDrop grant risk** (Pillar 3 violation)。Static analyzer (Contract 12) scans `_generate_transition_id` calls inside any function name matching `_forward_recover*` — CI fail if found。
- 從 step 3 開始 **idempotently** 重做：寫 final state（重複同值無害）→ 更新 in-memory → 移除 tombstone → dual-target backend write（`transition_id` 令 server 端 unique constraint dedupe）→ emit `state_changed` → release fallback lock。
- **LootDrop 永遠唔可以因為 tab 關閉而消失** = 呢條 rule 嘅 falsifiable test。
- Backend `POST /lootdrop/{transition_id}/cache` idempotent — 已 cache 過嘅 `transition_id` 第二次 push 直接 200 ack。
- Backend `POST /lootdrop/{transition_id}/commit` 同樣 idempotent — 第二次 commit 返 200 連同 canonical inventory snapshot，client 用此 reconcile，從不雙 grant。

**Exception safety**：GDScript 冇 `try/finally`。Lock cleanup 由 step 0 嘅 `create_timer` fallback unlock 兜底；若 step 1-8 全部正常 path 都會主動 release，timer fire 時 `_transitioning` 已係 false，`_force_clear_lock` no-op 即可。

**Why emit-before-release** (cluster #1 atomicity fix):
舊版本將 release lock 排喺 emit 之前，企圖避免 subscriber 同步 re-enter 撞 lock。實際後果相反 — subscriber 同步嘗試 `_request_transition()` 會 **成功** 入第二次 transition function，喺 outer transition 嘅 step 8 之前 nest 一層 atomic unit。若 outer transition 係 LootDrop，nested transition 寫 final state 之後 outer 嘅 emit 再 fire stale signal → Pillar 3 violated. 新順序：lock 保持 held 到 emit 完，subscriber synchronous re-enter 直接撞 lock drop（observable via AC-04a, `dropped_event` signal）。Subscriber 真係需要 follow-up transition 嘅 case 行 `call_deferred` → Event Intake Queue next tick (priority 2)。

**Rule 3 — Flat Top-Level, Owned Sub-Machines.**
Top-level FSM 係 flat（9 states，無 nesting）。Sub-machine ownership 屬於知道細節嘅 subsystem：`CombatActive` 嘅 wave / enemy selection 由 EnemyDirector 擁有；`LootDrop` 嘅 reveal / confirmation 由 Loot Drop System 擁有。Top-level machine 只見 parent state，避免 infrastructure 持有 gameplay logic。

**Rule 4 — Rejected Events Are Dropped Silently.**
如事件喺一個無定義 transition 嘅 state arrive，silently discard。無 queue、無 error。理由：GymSys polling 每 5 秒 fire 一次，`Suspended` / `Booting` 必須無 side-effect 食咗呢啲 event。**例外**：`CRITICAL_SAVE_FAILED` 喺所有 state 升級為 logged error + non-blocking UI notice。

**Rule 5 — Save Reconciliation Precedence (on boot).**
Boot 時若 persisted state 係 `WorkoutActive` / `CombatActive` / `BossEncounter` → restore 去 persisted state（唔默認 `Idle`）。若係 `LootDrop` → restore 去 `LootDrop` 並 reload cached drop payload（Pillar 3 hard guarantee — drop 永遠唔消失）。若係 `Suspended` → restore 去 `Suspended.resume_target`。

**Reconciliation precedence ordered table** （high-to-low priority；前者 wins over 後者）：

| Priority | Condition | Winner | Pillar |
|----------|-----------|--------|--------|
| **0 (highest)** | 任何 backend call 返 HTTP 401 → session token invalidated（per Decision #4 single-device lock）| **Force-boot reconciliation — but active-state deferred (Pass 3 B3 fix)**：(a) **若 `current_state ∈ {WORKOUT_ACTIVE, COMBAT_ACTIVE, BOSS_ENCOUNTER}` → DEFER force-boot；phone enters local-only mode (functionally `Disconnected` with cached GymSys data); 401 reconciliation triggers on next `state_changed` to natural-pause state (`RestPeriod` / `Idle` / `Disconnected`).** (b) 若 `current_state ∈ {Idle, RestPeriod, Disconnected, Suspended, Booting}` → 即時 transition `current_state → Booting`. (c) Booting path: wipe `session_token` → `POST /session/claim` → re-evaluate priority 0.5/1-5. (d) emit `session_invalidated()` signal. (e) **Toast gating (Pass 3 B12 fix)**: 若 post-401 reconciliation 落到 **與 pre-401 `current_state` 唔同** 嘅 state (e.g. tablet 已 finish workout → backend authoritative `Idle`) → toast 「已在另一部裝置繼續」**即時 fire** on that `state_changed` emit (bypass Decision #1 natural-pause gating — player needs context NOW). 若 backend 同意 pre-401 state → toast 經 Decision #1 gating 延後. **LootDrop 仍由 priority 1 / 0.5 保護**（local cached + backend cache mirror 雙保險） | **P2 + P3 — transparent device handoff (refined)** |
| **0.5 (NEW, Pass 3 B1 fix)** | `loot_pending.pending_since` 超過 `LOOTDROP_PENDING_HARD_CAP_DAYS` (30 日) AND `loot_reveal_pending == true` | **Force-transition `Booting → LootDrop`** with cached payload + `source_event = "deferred_reveal_hard_cap"` — 即時 fire 完整 #21 modal ritual，玩家一開 game 即見 ritual. **NOT silent commit** (per Pass 3 B1 — Pillar 3「不知不覺發生」anti-pattern 防禦). Auto-commit-to-inventory + 「未開封」badge **只係 fallback**：若 force-transition 失敗 (e.g. payload corrupt + backend cache absent + `MAX_FORCE_TRANSITION_RETRIES` 用盡) 先 trigger fallback path. AC-19 重寫至此 contract. | **P3 (Drop Euphoria) — ritual preserved at boundary** |
| 1 | Local has unredeemed LootDrop（state=`LootDrop` OR `loot_reveal_pending == true`） AND `pending_since` ≤ hard cap | **Client wins** — restore LootDrop with cached payload；backend reconcile happens AFTER loot commit。若 local payload 缺失但 `loot_reveal_pending == true` → `GET /lootdrop/{transition_id}/cache` 由 backend restore payload；如 backend 都無 → log + fall through to priority 3 | **P3 (Drop Euphoria) hard guarantee** |
| 2 | Local has valid tombstone with `transition_id` AND tombstone TTL not expired | **Client forward-recovery wins** — replay step 3-8 of Rule 2 idempotently；backend dedupe via `transition_id` UNIQUE constraint | P2 (Frictionless) — atomicity |
| 3 | Backend reachable AND local + backend disagree on non-LootDrop state | **Backend wins** — backend `current_state` is authoritative | Source of truth |
| 4 | Backend unreachable AND local has valid persisted state | **Client wins (offline mode)** — enter `Disconnected` with local state；reconcile when backend recovers | P2 (Frictionless) — offline-tolerant |
| 5 (lowest) | Local corrupt AND backend unreachable | Boot to `Idle`, log error | Recovery |

**Rule 5.5 — Weekly Tick Missed-Window Replay (Decision #5 / Pass 3 B2, Pillar 5 enforcement):**

`weekly_tick` 事件係 #29 Mirror Moment System 嘅 weekly evolution trigger。Pillar 5 falsifiable test (Player Fantasy §B): 「weekly evolution tick 從來唔錯過、唔重複」。Suspended / Disconnected 跨週期會錯過 normal tick fire → state machine 必須喺 boot 時補 fire。

機制：
1. **Boot-time check** (Phase C step 2，喺 Rule 5 reconciliation 之後、priority 1 LootDrop reveal 評估**之前**)：read `_last_weekly_tick_unix` 由 `user://state.json` (新 persistence key); compute `missed_count = floor((now - _last_weekly_tick_unix) / WEEKLY_TICK_INTERVAL_SECONDS)` clamped 至 `MAX_WEEKLY_TICK_CATCHUP = 8`.
2. **Enqueue catch-up events**: missed_count > 0 → enqueue `missed_count` 個 `weekly_tick` event 喺 Event Intake Queue priority 5 (lowest); 但 catch-up events 必須喺 priority-1 LootDrop reveal **之前** drain → 用獨立 boot-only flush phase (一次過 drain catch-up events 然後正常 _process queue 繼續).
3. **Dedupe guarantee**: 每次 fire `weekly_tick` 更新 `_last_weekly_tick_unix = anchored_tick_time` (anchored to `WEEKLY_TICK_HOUR_UTC` floor, 唔係 `now`) — 確保 8 個 missed ticks 補 fire 後下個 normal tick 唔會 double-fire same week.
4. **Falsifiable test**: 玩家連續 4 週都唔開 game → 第 5 週開 → 補 fire 4 個 `weekly_tick` (#29 處理 idempotent merge / batched evolution display) → `_last_weekly_tick_unix` 更新至最新；下次 normal tick fire 喺正常 `WEEKLY_TICK_HOUR_UTC` 時間。

**Cap rationale**: `MAX_WEEKLY_TICK_CATCHUP = 8` (~2 個月) 防止玩家極長期不活躍 (e.g. 1 年) 一開 game 就 enqueue 52 個 tick 拖死 boot。超過 cap → 視為 "stale account return"，由 #29 用獨立 returning-player ritual 處理 (defer to #29 GDD).

**Why missing weekly_tick was Pillar 5 cliff**: 舊版 GDD 只 mention `weekly_tick` 喺 Event Intake Queue priority 5 (line 176) 同 `Idle` self-loop fires (line 187)。冇 rule 話「Suspended → boot 時補 fire missed ticks」→ 玩家 skip 一週 = 該週 evolution **永遠錯過** = Pillar 5 falsifiable test fail。Rule 5.5 喺 boot phase 強制補 fire，由 #29 處理 idempotent evolution merge。

---

**Natural-Pause Gated Reveal** (Decision #1 — supersedes prior "non-modal toast on resume" paragraph):

當 priority-1 restore 觸發 OR transition-into-LootDrop 喺 player active 中發生，**LootDrop modal 嘅 reveal timing 由 state machine 控制**：

- **Safe states (allow reveal)**: `Idle`, `RestPeriod`, `Disconnected`
- **Suppressed states (defer reveal)**: `WorkoutActive`, `CombatActive`, `BossEncounter`

機制：
1. 任何時候 `loot_reveal_pending == true`（persisted in `user://state.json`），state machine 喺每次 `state_changed` emit 之後 evaluate：若新 state ∈ safe states **且** （若新 state == `RestPeriod`）remaining duration ≥ `MIN_REVEAL_WINDOW_SECONDS` → `call_deferred("_request_transition", LOOT_DROP)` 帶 cached payload，`source_event = "deferred_reveal"`。
2. 若新 state ∈ suppressed states → reveal 留 pending，等下次 safe state 入嘅機會（玩家 finish set → RestPeriod 自然觸發；workout end → Idle 自然觸發）。
3. **Hard backstop (Pass 3 B1 reframe)**: `LOOTDROP_PENDING_HARD_CAP_DAYS = 30` (default; safe 14-90)。超過 30 日仍 pending 嘅情況走 **Rule 5 priority 0.5** — boot 時 force-transition `Booting → LootDrop` 帶 cached payload + `source_event = "deferred_reveal_hard_cap"`，玩家一開 game 立即見完整 #21 modal ritual。**唔再 silent auto-commit** (舊版 30 日後自動入 inventory + 「未開封」badge **violates Pillar 3 「不知不覺發生」anti-pattern**, 因為「玩家發現 badge 然後 tap」係 UX 假設而非保證). 「未開封」badge + inventory-tap recovery path **只係 fallback** — 喺 force-transition 失敗 (payload corrupt + backend cache absent + `MAX_FORCE_TRANSITION_RETRIES = 3` 用盡) 嗰陣先 trigger; 玩家仍可 tap badge 觸發 `Idle → LootDrop` ritual。**架構意圖**：默認路徑 = boot 必見 ritual；fallback 路徑 = inventory badge ritual recovery；冇 silent commit path。
4. **Soft TTL preserved**: `LOOTDROP_PENDING_TTL_DAYS = 6` (Safari ITP touch refresh 用，不變)。
5. **RestPeriod modal force-close**: 若 `rest_ended` 喺 modal 仍開時 fire → modal force-close、`loot_reveal_pending` 保持 true、下次 RestPeriod 重試 (per Decision #3)。
6. **Multi-pending queue**: 同時積累多個 LootDrop → 每個 RestPeriod 只 drain ONE，避免一次過 fatigue overload。

**Why natural-pause not toast-on-resume**:
舊版「非模態 toast 喺 resume 入 WorkoutActive 時 fire」直接違反 Pillar 2 — toast 本身就係 attention demand，等同 modal pop。改為 gating after natural pause points（玩家收 set 之間自然停低）= zero attention cost during active phase + ritual preserved at correct moment + 30-day backstop 保證 loot 永遠 reachable。Pillar 2 + Pillar 3 同時 satisfied。

**Backend dedupe** (Decision #4): 所有 transition backend write 帶 `transition_id`。GymSys backend 喺 `lootdrop_cache` + commit tables 用 `transition_id` UNIQUE constraint 做 server-side dedupe，client retry 完全安全。Server 端唔需要 application-level dedupe 邏輯 — DB constraint 已 enforce。Reference: ADR-002 GymSys integration protocol (to be authored).

**Rule 6 — No Input Required Mid-Set (Pillar 2 Enforcement).**
`WorkoutActive` 同 `CombatActive` 同 `BossEncounter` 三個 state 必須無任何 required player input。如有 transition 想 demand blocking acknowledgement，必須 defer 到 `RestPeriod` 或 `LootDrop`（natural pause points — RestPeriod 由 GymSys `rest_started` 自然觸發，玩家身體已停止；LootDrop 本身就係 ritual moment）。State machine 唔自己 enforce 呢條 rule — 由 #33 Attention Budget Policy 訂閱 `state_changed` 並 expose `is_input_permitted() → bool`。State machine 係 source of truth；#33 係 derived consumer。

**Rule 7 — Workout Completion Takes Priority (Reality Wins).**
任何時候 GymSys 發出 `workout_completed`（即使 late by 30+ 秒），game 即時 force-transition 去 `LootDrop`，唔理而家係邊個 state（包括 `BossEncounter`）。理由：玩家現實中已經收 set，game 必須跟現實。

**Boss outcome enum (Pillar 3, Decision #2)**: LootDrop payload 帶 `BossPayload` resource，其中 `outcome: BossOutcome` enum 取代舊 `boss_defeated: bool` flag，從 schema 層 disambiguate 三種收場：

| Outcome | 觸發 | `source_event` | `hp_at_interrupt` | Loot grant? |
|---------|------|----------------|-------------------|-------------|
| `DEFEATED` | Boss HP 由 combat 推到 0 → `boss_defeated` event | `"boss_defeated"` | `0` | Yes (combat path) |
| `INTERRUPTED_WITH_CREDIT` | `workout_completed` 喺 `BossEncounter` fire（Rule 7 path） | `"workout_completed"` | `<current_hp>` | Yes (Pillar 3 — workout completion = ritual = loot) |
| `ABANDONED` | **Post-MVP reserved** — 玩家明示 quit OR `BossEncounter` 內超 long-inactivity TTL。Never fires in VS tier 範圍 | `"abandoned"` | `<current_hp>` | **No** |

**Why enum not bool**:
舊版 `boss_defeated: true` 對 DEFEATED vs INTERRUPTED_WITH_CREDIT 兩種完全不同 ritual context 用同一 flag — downstream（成就、telemetry、weekly progression）無法 distinguish 玩家「實際擊殺」vs「現實中收 set 同時 boss 仍剩血」。Mirror Moment 系統 (#29) 嘅 weekly boss-kill progression 只應認 DEFEATED；achievements 只應 count DEFEATED；但 LootDrop 三者都 grant（除 ABANDONED）。Enum 喺 schema 層 lock 呢個 disambiguation，downstream consumer 唔可以誤用。

**Engagement threshold**: NONE — Pillar 3 明確「workout completion = ritual = loot」，唔加 HP threshold。Downstream 想用 engagement % filter（e.g. weekly progress 要求 ≥50% HP 已削減）可以由 `hp_at_interrupt / hp_max` 自行 derive，state machine 唔做 policy decision。

**Visual ownership unchanged**: EnemyDirector 處理 boss 收場動畫（INTERRUPTED_WITH_CREDIT 用 fast-victory 變奏唔係 fade-out），state machine 唯一責任係保證 `BossPayload` 入 `StateTransitionPayload.data["boss"]`。Pillar 3 由此架構強制。

**Downstream consumer rules** (advisory；binding 喺各自 consumer GDDs):
- #15 Loot Drop System: merge boss-drop if `outcome != ABANDONED`
- #16 Boss System: allow retry if `outcome == INTERRUPTED_WITH_CREDIT`
- #28 Telemetry: count 3 outcomes 為 separate metrics
- #29 Mirror Moment: 只 DEFEATED advances weekly boss-kill progression
- Future achievements: count DEFEATED only

### Storage Backend

**Choice: IndexedDB via Godot `user://`**（Godot Web Export idiomatic pattern）。

- 所有 persistence I/O 經 `FileAccess.open("user://state.json", ...)`。Godot 4.6 Web Export 後台用 IndexedDB sync layer，初始 sync 喺 JavaScript bootstrap 完成（GDScript `_ready()` 之前）。
- **Quota**: ~50MB–1GB（依瀏覽器同 origin 配額），對 game state + LootDrop payload 綽綽有餘。
- **Storage keys**（JSON top-level keys 喺 `user://state.json`）：
  - `schema_version: int` — sourced from `const SCHEMA_VERSION = 1`（compile-time constant；boot 比較 `schema_version != SCHEMA_VERSION` → run `PersistenceLayer.migrate`）；未來 migration 改 const 即可
  - `current_state: String` — 用 stable string key（`"booting"`, `"idle"`, `"workout_active"`, `"rest_period"`, ...）解耦 GDScript enum identifier，方便 schema migration
  - `pending_transition: Dictionary` — 即 tombstone；missing key = 無 tombstone。Tombstone schema 必含 `transition_id`, `from`, `to`, `payload` (serialized via Contract 3 `to_dict()` envelope), `payload_type` (sourced from `payload.get_script().get_global_name()` per Contract 3 — `Object.get_class()` returns engine class `"Resource"` and breaks forward-recovery), `wall_clock_anchor`, `monotonic_anchor`
  - `_transition_id_counter: int` (NEW, Contract 2) — monotonic counter for `transition_id` generation; incremented FIRST before each transition's tombstone write; persisted to survive WASM reload (boot reads, next transition increments from saved value). Missing key on first boot → initialize to 0.
  - `loot_pending: Dictionary` — LootDrop payload cache + `pending_since: int` (unix timestamp)
  - `loot_reveal_pending: bool` (NEW, Decision #1) — natural-pause gating flag；true = 有 cached LootDrop 等住 safe-state reveal
  - `session_token: String` (NEW, Decision #4) — 由 `POST /session/claim` 獲取嘅 single-device active token；每 backend call 經 `X-Session-Token` header 帶送；missing/empty → 入 priority-0 force-boot 路徑
  - `_last_weekly_tick_unix: int` (NEW, Decision #5 / Pass 3 B2) — 最後一次 fire `weekly_tick` 嘅 wall-clock unix timestamp (anchored to `WEEKLY_TICK_HOUR_UTC` floor)；boot 用嚟計 `missed_count`；missing → 視為 first boot, set 到 now anchored
  - `_pending_401_reconciliation: bool` (NEW, Pass 3 B3) — 401 喺 active state (WORKOUT_ACTIVE / COMBAT_ACTIVE / BOSS_ENCOUNTER) 收到時 set true；下次 `state_changed` 入 natural-pause state 時 drain (force-boot reconciliation)；persist 以防 active-state 期間 page reload 丟咗 deferred 401
  - `resume_target: String` — Suspended state 用
  - `retry_attempt_index: int` — Disconnected state 用
- **Safari ITP eviction**：iOS Safari Intelligent Tracking Prevention 可能喺 origin 7 日不活躍後 evict IndexedDB。對策：
  - `LOOTDROP_PENDING_TTL_DAYS` capped at **6 日**（少於 ITP 7 日窗口）
  - 每次 resume 都 touch `user://state.json`（重寫同一份 content）refresh ITP timer
  - LootDrop 同時 cache 入 backend（透過 step 6 fire-and-forget write），ITP evict 後仍可由 backend restore
- **Schema migration mechanism**：boot 時讀 `schema_version`。版本不匹配 → 跑 `PersistenceLayer.migrate(from_version, to_version)`（喺 #3 PersistenceLayer GDD 訂定）；fallback 不能 migrate → 視為 corrupt save，per Rule 5 priority 5 boot to `Idle`。

### Event Intake Queue

State machine 唔即時 process 收到嘅 event；統一經 **Event Intake Queue**（owned by GameStateMachine autoload）。

- **Data structure**: priority FIFO（每個 priority bucket 內 FIFO，bucket 間按 priority 數值處理）。Implemented as `Array[Dictionary]` with `{priority: int, source: String, event_type: String, payload: Variant, enqueued_at: int}`.
- **Priority levels**:
  - `0` (highest) — `CRITICAL_SAVE_FAILED` (system errors)
  - `1` — `workout_completed` (Rule 7 reality-wins)
  - `2` — Player input events (tap, switch confirm)
  - `3` — GymSys lifecycle events (workout_started, set_logged, **rest_started**, **rest_ended** per Decision #3; legacy `exercise_switched` deprecated — silently dropped)
  - `4` — Enemy lifecycle events (enemy_died, enemy_spawn_ready)
  - `5` (lowest) — Periodic ticks (weekly_tick)
- **Flush timing**: `_process(_delta)` 結尾 drain queue，每 frame 最多處理 **1 個 event**（防止 same-frame cascade 失控）。多 event 同 frame 到達 → 排序入 queue，下一個 frame drain next。
- **Validity re-check on dequeue**: 每個 event 出 queue 時，**重新跑 guard clause**（同 Rule 2 step 1）。若 dequeue 時 `current_state` 已唔接受該 event → silently drop per Rule 4，唔 transition。例：`workout_completed` enqueue 時 game 喺 `BossEncounter`，dequeue 前 frame 玩家收 set 觸發 `boss_defeated`、game 已喺 `LootDrop` → `workout_completed` dequeue 時 guard fail → drop（但 boss path 已經處理 loot）。
- **Subscriber-triggered transitions**: Rule 2 step 8 嘅 subscriber 透過 `call_deferred("_request_transition", event)` 入 queue，priority `2`，下一個 frame drain — 唔會 same-frame re-enter。

### States and Transitions

| State | Purpose | Entry Trigger | Exit Triggers (→ next state) | Persists? | Systems Running |
|-------|---------|---------------|------------------------------|-----------|-----------------|
| `Booting` | Cold start，load + validate persisted state | App launch / page reload | Save loaded → restored state OR `Idle`; Save corrupt → `Idle` (clean slate) | No | PersistenceLayer only |
| `Disconnected` | GymSys 不可達；run on cached workout data | GymSys poll timeout / HTTP error | Poll succeeds → previous state; Manual retry success → previous state | Yes (`resume_target`) | GymSys Backend Client (retry), Workout State Tracker (read-only cached) |
| `Idle` | 無 active workout；ambient background loop | Boot complete with no active workout; Workout 結束 + LootDrop confirmed | `workout_started` (GymSys) → `WorkoutActive`; Weekly tick → `Idle` (self-loop, fires Mirror Moment check) | Yes | Attention Budget (idle mode), Mirror Moment System (weekly tick) |
| `WorkoutActive` | Workout 進行中，無 combat | `workout_started` OR GymSys `rest_ended` | GymSys `rest_started(duration_seconds)` → `RestPeriod`; Enemy spawn → `CombatActive`; `workout_completed` → `LootDrop`; Focus loss → `Suspended` | Yes | Workout State Tracker, Attention Budget (no-input mode), EnemyDirector (spawn logic) |
| `RestPeriod` (renamed from `ExerciseSwitching`, Decision #3) | Set 之間嘅 rest window；safe input point；natural pause for deferred LootDrop reveal | GymSys `rest_started(duration_seconds: int)` — fires after every set | GymSys `rest_ended` → `WorkoutActive` (auto); Player tap during LootDrop modal → modal commit → `WorkoutActive`. **Timer ownership = GymSys**，state machine 不擁有 RestPeriod 倒數；若 `rest_started` 漏帶 `duration_seconds` → fallback `REST_PERIOD_FALLBACK_SECONDS = 90` | No | Attention Budget (input-permitted), Workout State Tracker, Loot Drop Modal (if `loot_reveal_pending` AND remaining ≥ `MIN_REVEAL_WINDOW_SECONDS`) |
| `CombatActive` | Enemy encounter 進行中 | EnemyDirector `enemy_spawned` signal | Enemy died → `WorkoutActive`; GymSys `rest_started` → `RestPeriod` (combat pauses, resumes on return); Focus loss → `Suspended`; `workout_completed` → `LootDrop` (Rule 7) | Yes | EnemyDirector (owns sub-machine), CombatResolver, Attention Budget (background combat) |
| `BossEncounter` | Boss 戰；由 EnemyDirector promote 自 CombatActive | EnemyDirector `boss_spawned` | Boss defeated → `LootDrop` (`BossOutcome.DEFEATED`); Focus loss → `Suspended`; `workout_completed` → `LootDrop` (Rule 7, `BossOutcome.INTERRUPTED_WITH_CREDIT`); GymSys `rest_started` → `RestPeriod` (combat pauses) | Yes | EnemyDirector, CombatResolver, Attention Budget (elevated, may allow RestPeriod reveal window) |
| `LootDrop` | Guaranteed loot reveal；requires one player tap | `workout_completed` 或 boss defeated | Player tap (loot confirmed) → `Idle` | Yes (drop payload cached — Pillar 3 hard guarantee) | Loot Drop System (owns sub-machine), Attention Budget (input-required, single tap) |
| `Suspended` | App backgrounded / focus lost；minimal tick；resume-ready | JS `pagehide` / `visibilitychange` (primary) 或 Godot `NOTIFICATION_APPLICATION_PAUSED` (secondary) | Focus restored → `resume_target` (若 `resume_target == Booting`，restore `Idle`) | Yes (`resume_target` field) | PersistenceLayer (checkpoint on entry), GymSys Client (poll suspended) |

**9-state list locked for VS tier.** State enum slot 數量同 IDs 不變，只係 `EXERCISE_SWITCHING` 改名為 `REST_PERIOD`（GameState enum value 換名；persistence stable key `"rest_period"` 取代 `"exercise_switching"`，schema migration 由 `PersistenceLayer.migrate(1→2)` 處理）。`BossEncounter` 保留 — 係 Pillar 3 mid-workout euphoria spike 嘅唯一 mechanism。`WeeklyTick` 唔需要獨立 state — 喺 `Idle` 內部處理。

### Interactions with Other Systems

**#2 GymSys Backend Client → GameStateMachine** (one-way)
GymSys Client emit signals (Decision #3 update — was 6, now 7 with `rest_started` + `rest_ended` replacing `exercise_switched`)：`workout_started`, `set_logged(exercise_id, reps, weight)`, `rest_started(duration_seconds: int)`, `rest_ended()`, `workout_completed(completed_at: timestamp)`, `poll_failed`, `poll_recovered`. GameStateMachine 訂閱全部 7 個。Legacy `exercise_switched(new_exercise_id)` 仍由 GymSys Client emit (backward-compat 同 backend `.rest-bar` UI) 但 state machine **唔再訂閱**；silently dropped per Rule 4。GameStateMachine 唔直接 call GymSys Client.

**#3 PersistenceLayer ↔ GameStateMachine** (bidirectional, subordinate)
GameStateMachine call `PersistenceLayer.save_state(state, payload)` 喺每個 transition 嘅 step 2 + 4（per Rule 2）。PersistenceLayer call `GameStateMachine.restore(saved_state, payload)` 一次喺 `Booting` 過程。PersistenceLayer 從不主動觸發 transition。

**#9 Workout State Tracker → GameStateMachine** (one-way)
Workout State Tracker emit `enemy_spawn_ready(enemy_id)` 喺 set-count threshold 達到時。GameStateMachine 消費呢個 signal，觸發 `WorkoutActive → CombatActive`（透過 EnemyDirector 嘅 enemy_spawned 中介）。Tracker 唔知 state 存在。

**GameStateMachine → #14 EnemyDirector** (signal-only)
GameStateMachine emit `state_changed(from, to, payload)`. EnemyDirector 監聽進入 `CombatActive` / `BossEncounter` 啟動 sub-machine，監聽離開做 cleanup（包括 Rule 7 嘅 boss abort 動畫）。GameStateMachine 從不直接 call EnemyDirector method。

**GameStateMachine → #15 Loot Drop System** (signal + callback)
Loot Drop System 喺 transition into `LootDrop` 之前已生成 loot payload，作為 transition payload 傳入。GameStateMachine emit `state_changed(*, "LootDrop", payload)`。Loot Drop System 跑自己 sub-machine（reveal → confirm），完成後 emit `loot_confirmed`，GameStateMachine 訂閱呢個 signal 觸發 exit transition。

**GameStateMachine → #33 Attention Budget & Interaction Policy** (signal-only, derived consumer)
#33 訂閱 `state_changed` 並維持 read-only current-state view。Expose `is_input_permitted() → bool`。GameStateMachine **從不 call** `is_input_permitted` — 呢個係 UI components 用嘅 query。State machine 係 source of truth；#33 係 derived consumer。Pillar 2 喺架構層由呢個 indirection 強制。

## Formulas

State machine 主要係 event-driven coordinator，唔做 gameplay math。Section D 只包含一條 formula；其他所有數值都係 named constants / thresholds（見 Section G Tuning Knobs）。

### Formula 1: Disconnected Retry Delay

喺 `Disconnected` state，GymSys Backend Client 嘅 retry 用 exponential backoff with cap。

`retry_delay(n) = min(BASE_DELAY × 2 ^ min(n - 1, ATTEMPT_CAP), RETRY_CAP)`

**Preconditions** (runtime `assert()` enforced at function entry — fail-fast crash if violated):

- `n >= 1` (attempts are 1-indexed; n=0 不合法)
- `BASE_DELAY > 0.0` (零或負延遲 → 退避 hammer loop)
- `RETRY_CAP >= BASE_DELAY` (cap 低於 base 令曲線無意義)
- `ATTEMPT_CAP = 30`（內部 hard cap，防止 IEEE 754 `2^n` 喺 n=1024 上溢成 `INF`；30 次 attempts × 16s cap 已遠超任何合理 retry window）

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Attempt index | `n` | int | 1..∞ (clamped to ATTEMPT_CAP internally) | Current retry attempt number, 1-indexed (resets to 1 on successful poll) |
| Base delay (seconds) | `BASE_DELAY` | float | 0.5..2.0 | Delay before first retry (default: 1.0) |
| Retry cap (seconds) | `RETRY_CAP` | float | 16..60 | Maximum wait between retries (default: 16.0) |
| Attempt cap (internal) | `ATTEMPT_CAP` | int | 30 (fixed, not exposed) | Hard cap on exponent to prevent IEEE 754 overflow |
| Result (seconds) | `retry_delay` | float | `BASE_DELAY` .. `RETRY_CAP` | Seconds to wait before attempt `n` |

**Output Range:** Clamped to `[BASE_DELAY, RETRY_CAP]`. Never exceeds cap regardless of attempt count. Boundary check: `n=1` returns exactly `BASE_DELAY`; `n >= 1 + log2(RETRY_CAP / BASE_DELAY)` returns exactly `RETRY_CAP`.

**Example** (with `BASE_DELAY = 1.0`, `RETRY_CAP = 16.0`):

- n=1 → min(1 × 1, 16) = **1.0s**
- n=2 → min(1 × 2, 16) = **2.0s**
- n=3 → min(1 × 4, 16) = **4.0s**
- n=4 → min(1 × 8, 16) = **8.0s**
- n=5 → min(1 × 16, 16) = **16.0s**
- n=6+ → stays at 16.0s (cap hit)

**Cross-system note:** 呢條 formula 嘅 ownership 屬於 GameStateMachine（決定幾時切返去 previous state），但實際 sleep / poll 動作由 GymSys Backend Client 執行。Tuning knobs (`BASE_DELAY`, `RETRY_CAP`) 喺 Section G 列為 GameStateMachine 嘅 knob，唔係 #2 嘅 knob，因為呢個 backoff curve 直接影響 user-perceived recovery latency。

## Edge Cases

### Boot Edge Cases

- **If `user://` (IndexedDB) 完全被 disable**（Safari Private Mode）: Boot sequence 先做 feature-detect write test；失敗則強制入 `Disconnected`，並用 in-memory fallback cache（session scope，tab close lost）。**Pillar 3 風險** — LootDrop 喺呢個 mode 無法 survive page reload。`[OPEN QUESTION Q-E1]`: in-memory fallback 對 LootDrop durability 係咪 acceptable？
- **If 持久化 state 損壞或 schema 不識別**: 視為 corrupt save，clear `user://` (IndexedDB) state key，boot 去 `Idle`。Backend tombstone check 喺下個 poll 重新 reconcile。
- **If tombstone TTL 已過期** (e.g., > `TOMBSTONE_TTL`)：視為 abandoned，清除 tombstone，以 backend state 為準 reconcile 後正常 boot。
- **If boot 期間 backend unreachable + `user://` (IndexedDB) 有 LootDrop pending**: 入 `Disconnected` 並保留 LootDrop pending flag；重連後優先執行 loot commit 先正常 reconcile。**唔可以跳過或清除 LootDrop pending**（Pillar 3 hard rule）。

### Concurrency & Race Edge Cases

- **If 同一 frame 收到多個 GymSys events**（e.g. `rest_started` + `workout_completed`）: Event priority queue 排序處理；`workout_completed` 永遠最高優先（per Rule 7）。前一個 event 觸發嘅 state 改變如令後一個 event 變 invalid，後者 silently drop（per Rule 4）。
- **If `RestPeriod` `rest_ended` 同 player tap (on open LootDrop modal) 同一 dequeue cycle** (Decision #3): Event Intake Queue priority 排序 — player tap (priority 2) 先 dequeue → modal commit → `RestPeriod → WorkoutActive`；`rest_ended` (priority 3) 下個 frame dequeue 時 guard fail（已喺 WorkoutActive）→ `dropped_event` emit。反之若 `rest_ended` 先 fire 而 modal 仍開 → modal force-close、`loot_reveal_pending` 保持 true、auto transition `RestPeriod → WorkoutActive`、下次 RestPeriod 重試 reveal。**Timer ownership = GymSys** → state machine 無自己 timeout timer 可以 cancel；只清理 modal UI state（透過 `state_changed` signal 通知 #21）。
- **If boss 死亡同 `workout_completed` 同一 frame**: Rule 7 wins → boss death transition 廢棄，force-transition 去 `LootDrop` 帶 `BossPayload { outcome: INTERRUPTED_WITH_CREDIT, hp_at_interrupt: <current_hp>, hp_max: <hp_max>, boss_id: <id> }`. Boss death 嘅 DEFEATED outcome 唔會 fire 因為 `workout_completed` priority 高過 `boss_defeated`。Loot merge 邏輯由 #15 Loot Drop System GDD 定義。
- **If player 喺 transition 執行緊中途 tap**: Single-thread JS 保證 GDScript function 唔被打斷，所以 tap event 喺 transition function 完成後先處理。但若 tap 觸發再一次 transition（re-entrance），用 transition lock：transition function 開頭設 `_transitioning = true`，emit signal 之後先 release（per Rule 2 step 7→8 order）；如 lock 仍 held 而新 transition request 到達，silently drop with `dropped_event(*, "lock_held")` emit。

### Mobile Safari / Web Export Quirks

- **bfcache restore handling (formal rule, not deferred to Q-A3 spike)**: `pageshow` JS listener marshalls `event.persisted: bool` via `JavaScriptBridge.create_callback()` 入 GDScript。
  - 若 `persisted == true` AND in-memory `_current_state == Suspended` AND tombstone 不存在 AND **persisted `schema_version == SCHEMA_VERSION` const** → **fast resume path**：直接 transition `Suspended → resume_target`，唔重 boot。Schema check 必須執行 — fast path 跳過 boot reconciliation 同 schema migration，若 schema drift 而行 fast path 會用舊 schema 解新 data → silent corruption。
  - 若 `persisted == true` 但 in-memory state 已被 Godot WASM 重新初始化（Godot WASM 喺 bfcache 可能 reinit；偵測方法：autoload `_ready()` 跑緊 = 新 instance）OR `schema_version` 不匹配 → **fallback full boot path**：行 Rule 5 reconciliation including schema migration。
  - 兩個 path 都用 `event.persisted == true` 觸發 retry backoff index reset (`n = 1`)。
  - 兩個 path resume 後都會 evaluate `loot_reveal_pending`：若 true AND new state ∈ safe states → `call_deferred` 觸發 deferred reveal (per Decision #1)。
  - VS spike (Q-A3) 任務改為「量度 bfcache 喺 iOS Safari 嘅 reinit 比率」，唔係「決定點 handle」— handle path 已 lock。
- **`pagehide` / `visibilitychange` listener registration**: Autoload `_ready()` 內呼叫 `JavaScriptBridge.eval()` register listener，傳回 callback object 由 GDScript 保留 reference（避免 GC）。Listeners 必須 idempotent — 多次 register 唔可雙觸發（用 `_listeners_bound: bool` guard）。
- **If Suspended > `SUSPENSION_TTL_SECONDS` (default 24h) 後 resume**: Backend session token 大概率失效；resume 時 reset retry backoff index `n=1`，並強制走 boot reconciliation（唔係 simple resume）。
- **Monotonic clock + wall clock anchor**: Tombstone 同時記 `monotonic_anchor = Time.get_ticks_msec()` 同 `wall_clock_anchor = Time.get_unix_time_from_system()`。Reason: `Time.get_ticks_msec()` 喺 full reload reset 到 0（IndexedDB persistent 但 WASM ticks 唔 persistent），所以 boot 比較 tombstone TTL 時用 `wall_clock_anchor` diff（容忍 ±5s clock drift）。bfcache restore 嘅 case，monotonic 仍 valid。Workout `completed_at` timestamps 用 backend 提供嘅 server-side timestamp，唔用 client clock。
- **`Time.get_ticks_msec()` wraps after ~49.7 days**: 用 `Time.get_ticks_usec()` (64-bit microseconds, wraps after ~292,471 years — non-issue) 喺所有需要 monotonic 嘅地方。
- **If full page reload mid-LootDrop**: Tombstone + `loot_pending` + `loot_reveal_pending` 觸發 reconciliation；priority-1 wins → boot restore 去 `LootDrop` 並 reload cached drop payload。若本地 payload 完整 → 即時 emit `state_changed` 去 `LootDrop` 等 ritual；若 payload 缺（IndexedDB partial write）→ `GET /lootdrop/{transition_id}/cache` 由 backend mirror 補返；backend 都無 → log + fall through to natural-pause gating with `loot_reveal_pending = true` 等下次 safe state 重試。**Pillar 3 hard test** — drop 永遠唔消失。
- **iOS pending touch on `pagehide`**: 進入 Suspended 時 synthesize `InputEventScreenTouch(pressed: false)` 入 `Input.parse_input_event()` 清除「卡住按住」嘅 touch state，防止 bfcache restore 後幻影 tap。

### GymSys Protocol Weirdness

- **If `workout_completed` 到達但本地無對應 active workout record**: Backend wins（Rule 5）；accept event，force-transition 去 `LootDrop`，用 backend 提供嘅 workout summary 作為 loot seed。
- **If `rest_started` 帶 unknown `exercise_id` 喺 payload metadata**（backend schema drift）: Accept event，transition 去 `RestPeriod`，UI fallback "Unknown Exercise"。**唔可以 reject 或 crash**（Pillar 2 — 唔可以 require player attention）。
- **If `workout_started` 到達時 game 已在 `WorkoutActive`**: Duplicate event（e.g. reconnection replay）。Silently drop，唔 re-enter，保留現有 sub-machine state。
- **If backend returns "no workout active" 但 game 係 `WorkoutActive`**: Backend wins（Rule 5）；force-transition 去 `Idle`，discard 本地 WorkoutActive sub-machine。**例外**：如有 LootDrop pending，先完成 loot commit 先 transition（Pillar 3 protection）。

### Resource & Cache Edge Cases

- **If `user://` (IndexedDB) save 期間 quota exceeded**（tombstone step 2 寫成功但 step 3 final state 寫失敗，per Rule 2 new step order）: 視為 incomplete transition；in-memory **唔可以 update**（phantom state 防禦）；emit `critical_save_failed` non-blocking notice；release lock；行下次 boot Rule 5 reconciliation。**Tombstone-priority rule**：若 tombstone TTL 仍 valid → priority-2 forward-recovery wins（即使 backend unreachable）— 唔可以 default 去 backend-wins 而 drop tombstone，否則 Pillar 3 forward-recovery LootDrop 會消失。IndexedDB 50MB-1GB 配額大，預期極少觸發；若實測 typical save < 50KB 則無需 eviction policy。
- **If LootDrop 永遠無 confirmed**（player 關 tab 唔返來 OR `loot_reveal_pending` 一直 deferred）: `loot_reveal_pending` flag + cached payload 留 `user://` (IndexedDB) + backend mirror。**雙層 cap** (Decision #1):
  - **Soft cap `LOOTDROP_PENDING_TTL_DAYS = 6`** — Safari ITP 7-day evict 之前用 `user://` touch refresh ITP timer。
  - **Hard cap `LOOTDROP_PENDING_HARD_CAP_DAYS = 30`** — 超過 30 日仍 pending → auto-commit loot 入 inventory + 永久「未開封」badge。Tap 「未開封」item → `Idle → LootDrop` 完整 ritual + `source_event = "deferred_reveal"`。**唔可以 silent commit 而無 ritual recovery path** = Pillar 3「不知不覺發生」anti-pattern 防禦。
  - 30-day 之前每個自然 safe-state entry（每 RestPeriod / Idle entry）已會嘗試 deferred reveal，hard cap 純粹係 backstop。
- **If GymSys backend 返回 schema version 高於 client 支援版本**: 接收 known fields，silently ignore unknown fields；如 known fields 不足以決定 transition（e.g. `workout_completed` 但缺 `completed_at`），log warning 並用 client clock fallback。VS tier 暫定 NO upgrade nag；MVP 之後再決定 nag 強度。
- **Disconnected × Suspended composite**: Suspended 永遠 win — 焦點 loss 入 Suspended，`resume_target = Disconnected` (若之前係 Disconnected)。Resume 時若 backend 仍 unreachable → 重入 Disconnected；若 backend 已 recovered → 走 Disconnected 嘅 exit transition「Poll succeeds → previous state」，previous state 從 Disconnected 嘅 `resume_target` (double-nested) 解出。Disconnected 嘅 `resume_target` 喺 entry 時 capture，suspended 唔覆寫佢。

### Multi-Device Session Edge Cases (Decision #4)

- **If backend returns HTTP 401** (session token invalidated — 另一部裝置 claim 咗): 即時 force-transition `current_state → Booting` (priority 0 reconciliation)。Local LootDrop pending preserved（priority 1 仍 wins after re-claim）。Emit `session_invalidated()` signal；UI toast 「已在另一部裝置繼續」**唔即時顯示** — 經 Decision #1 natural-pause gating 延後到下一個 safe state（Idle / RestPeriod / Disconnected）；若 player 已唔活躍可以無 toast 視覺出現，next active session boot 已是新 token。
- **Phone offline + tablet active**: Phone stale 直到 reconnect → 下次 GymSys poll 返 401 → force boot → `POST /session/claim` 失敗（tablet 已持 token）→ 顯示 `auth_required()` re-login prompt。Phone 上 LootDrop pending 仍 valid — 玩家 re-login 之後 cached payload 仍 reachable。如玩家喺 offline window 內 tap-confirm LootDrop → commit 暫存 queue offline；reconnect 後 `POST /lootdrop/{transition_id}/commit` 帶 idempotent transition_id；若 tablet 已 commit → backend 返 200 連同 canonical inventory snapshot；client 用此 reconcile，**唔會 double-grant**。
- **Simultaneous login race**（兩部裝置 同時 hit `POST /session/claim`）: Backend 用 row-lock — 第一個 reach 嘅 win，第二個收 200 但 token 已被 invalidate 喺 next poll；第二部裝置 hit 401 → force boot → re-claim。Net effect: 最後 reach 嘅 device wins，前者轉 stale。
- **Tablet login mid-phone-workout**: Phone 仍喺 `WorkoutActive` / `CombatActive` 跑 → 下次 poll fire (5s cadence per `GYMSYS_POLL_INTERVAL_SECONDS`) → 401 → priority-0 force boot。Workout sub-machine state lose；`workout_in_progress` flag 由 backend 持有（GymSys session level），re-login 之後 reconcile 返 same workout active。
- **Offline LootDrop tap then reconnect** (Decision #4 idempotency test): Tap 喺 offline 時 transition `LootDrop → Idle`，commit POST queue offline retry。Reconnect 後 retry fires；若 backend 已 commit (另一部裝置 race) → 200 + canonical inventory；client merge inventory snapshot; 若無 → 200 + 新 grant。`transition_id` UNIQUE constraint 保證 server 端 dedupe。

## Dependencies

### Upstream Dependencies (this system requires)

**None.** Game State Machine 係 Foundation layer 最底層 — 唔需要任何 game system pre-loaded。

**Engine / platform 依賴（非 system-level）**：

- Godot 4.6 Autoload mechanism (statically typed singleton)
- Godot signal system (typed signal signatures)
- `Time.get_ticks_usec()` (monotonic 64-bit microseconds — wrap non-issue)
- `Time.get_unix_time_from_system()` (wall-clock anchor for full-reload reconciliation)
- Web Export runtime + `JavaScriptBridge.eval()` (JS event listener registration)
- `JavaScriptBridge.create_callback()` + `JavaScriptObject` wrapper (marshalling `event.persisted: bool` from `pageshow`)
- Godot `user://` filesystem (backed by IndexedDB on Web Export; 50MB-1GB quota; Safari ITP 7-day inactivity evict)
- `Input.parse_input_event()` (synthesize touch-release on pagehide to clear stuck input)
- Single-threaded JS event loop (atomicity guarantee for Rule 2; **NOT** valid if COOP/COEP threading enabled — see Q-A4)

### Downstream Dependents (systems that depend on this)

**Hard dependents**（call `GameStateMachine.current_state` 或訂閱 `state_changed`）：

| # | System | Layer | Tier | Nature of dependency |
|---|--------|-------|------|----------------------|
| 2 | GymSys Backend Client (★ promoted to hard) | Foundation | VS | **Required contract additions (Decisions #3 + #4)**: (a) emit `rest_started(duration_seconds: int)`, `rest_ended()`; (b) consume `transition_id` header on every state write; (c) consume `X-Session-Token` header on every authenticated call; (d) handle 401 → propagate force-boot signal; (e) implement `POST /session/claim`, `POST /lootdrop/{transition_id}/cache`, `GET /lootdrop/{transition_id}/cache`, `POST /lootdrop/{transition_id}/commit` endpoints (binding ADR-002) |
| 3 | PersistenceLayer | Foundation | VS | Receives `save_state(state, payload)` calls during transitions; provides `restore(state, payload)` on Booting; **must expose synchronous `read()` callable from `GameStateMachine._ready()`** (no `await`) — see Boot Sequence rewrite |
| 9 | Workout State Tracker | Core | VS | Emits `enemy_spawn_ready(enemy_id)` to state machine; reads `current_state` to decide when to log set events vs ignore |
| 14 | EnemyDirector | Core | VS | Subscribes to `state_changed`; activates on `CombatActive` / `BossEncounter` entry, deactivates on exit. **Decision #2 binding**: 必須 populate full `BossPayload` (outcome + boss_id + hp_at_interrupt + hp_max) 之後 emit `boss_defeated` event — state machine 唔可以自行 derive |
| 15 | Loot Drop System | Core | Pre-MVP | Subscribes to `state_changed`; activates on `LootDrop` entry; emits `loot_confirmed` back to trigger exit. **Decision #2 consumer rule**: merge boss-drop only if `BossPayload.outcome != ABANDONED` |
| 33 | Attention Budget & Interaction Policy ★ | Core | Pre-MVP | Subscribes to `state_changed` (read-only); derives `is_input_permitted()` from current state — **架構上強制 Pillar 2** |

**Soft dependents**（讀 `current_state` 但唔 drive transitions）：

| # | System | Layer | Tier | Nature |
|---|--------|-------|------|--------|
| 5 | Particle System Wrapper | Foundation | VS | Subscribes to `state_changed` via `connect_for_initial_state(_on_gsm_state_changed)` (ADR-006 Contract 6)；Suspended state entry triggers its cancel-all sequence (burst queue flush + in-flight particle cancel) |
| 6 | Screen Effects System | Foundation | VS | Subscribes to `state_changed` via `connect_for_initial_state(_on_gsm_state_changed)` (ADR-006 Contract 6)；Suspended state entry triggers Rule 13 cancel-all sequence (trauma=0, pause_remaining=0, shader uniform force-write Vector2.ZERO, get_tree().paused = false) |
| 13 | CombatResolver | Core | VS | Read-only consumer — only processes damage events when state is `CombatActive` / `BossEncounter` |
| 16 | Boss System | Feature | VS | Reads `current_state == BossEncounter` to know when to render boss UI overlay. **Decision #2 consumer rule**: allow retry only if `BossPayload.outcome == INTERRUPTED_WITH_CREDIT` |
| 20 | Gym-Mode HUD | Presentation | MVP | Reads `current_state` to switch HUD layout per state |
| 21 | Loot Drop Modal | Presentation | Pre-MVP | Renders only when `current_state == LootDrop`. **Decision #1 + #2 contracts**: (a) accept `source_event = "deferred_reveal"` entry mode (natural-pause gating); (b) accept inventory tap on "未開封" item as entry trigger; (c) `BossPayload` 影響 modal layout（INTERRUPTED_WITH_CREDIT 用 fast-victory variant）; (d) RestPeriod 內 modal 必須能夠 force-close on `rest_ended` 且保留 `loot_reveal_pending = true` |
| 25 | Combat Visual Feedback | Presentation | MVP | Reads `current_state` to know when to spawn hit-pause / particles |
| 28 | Telemetry / Analytics | Polish | Pre-MVP | Subscribes to `state_changed` for funnel + duration tracking. **Decision #2 consumer rule**: count `BossPayload.outcome` 三者為 separate metrics (DEFEATED, INTERRUPTED_WITH_CREDIT, ABANDONED) |
| 29 | Mirror Moment System | Polish | MVP | Self-loop event `weekly_tick` fired inside `Idle` state. **Decision #2 consumer rule**: 只有 `BossPayload.outcome == DEFEATED` advances weekly boss-kill progression |

### Bidirectional Consistency Check

呢度列出嘅 dependents 必須喺自己嘅 GDD 寫 "depends on: #1 Game State Machine"。當以下 GDD 寫成時，需要 cross-check：

- #5, #6 (Foundation VS tier — 已 Approved；各自 GDD Section F 已列明 `connect_for_initial_state` contract ✓ — bidirectional 現已補完)
- #2, #3, #9 (VS tier — 跟住設計，呢個係 reciprocal dependency 嘅 reference baseline)
- #14, #15 (VS tier — 必須引用 `state_changed` signal contract + `transition_id` dedupe protocol + `BossPayload` schema)
- #33 (Pre-MVP — Pillar 2 owner，必須引用 `is_input_permitted()` derivation)
- #21 (Pre-MVP — 必須實作 natural-pause gated LootDrop reveal per Decision #1 + "未開封" badge + inventory tap entry mode)
- #16 (VS — Boss System — 必須 reference `BossPayload.outcome` enum for retry policy)
- #28 (Pre-MVP — Telemetry — 必須 split 3 outcomes 為 separate metrics)
- #29 (MVP — Mirror Moment — 必須 only DEFEATED 算 weekly progression)

**Provisional lock note**: 全部 cross-system ACs (AC-13/14/15a/15b + new ACs 為 Decisions #1/#2/#4) 喺 reciprocal GDD 未寫前 unilaterally locked from one side. 當 #14, #15, #33 GDDs 寫成時 expect contract delta — 已知 risk：#33 Attention Budget 可能需要 `state_entered_at` timestamp 補強 signal payload。Defer to reciprocal-GDD authoring; revisit during /review-all-gdds.

**ADR binding (Decision #4)**: ADR-002 (GymSys integration protocol) 必須 specify：
- Session API: `POST /session/claim` issues new token + invalidates prior active; all authenticated endpoints accept `X-Session-Token` header + return 401 if invalidated
- LootDrop cache + commit endpoints with `transition_id` UNIQUE constraint on `lootdrop_cache(transition_id PK, account_id, payload JSON, committed_at)`
- Schema migration: add `accounts.active_session_token`, `lootdrop_cache` tables
- Rest events: extend existing `.rest-bar` UI to emit `rest_started(duration_seconds)` + `rest_ended()` events to game client

### Why state machine is a leaf (no upstream)

Foundation layer 設計原則：state machine **唔可以** depend on任何 gameplay system，否則就會出現 "state machine 要等 X 系統 ready 先可以決定 state" — 違反 atomicity 同 boot determinism。Engine 同 platform API 之外，state machine 嘅啟動只需要 PersistenceLayer 喺 boot 時 hand 返一個 saved state struct（呢個 hand-over 喺 `Booting` state 內完成，唔算 dependency）。

**Boot sequence** (Cluster 5 — rewritten; prior version had factually incorrect autoload claim):

> **Why the rewrite**: 舊版本聲稱「`PersistenceLayer._enter_tree()` fires before any autoload `_ready()`」並只 warn 訂閱者「**may** miss initial emit」。實際 Godot autoload behavior: 同一 SceneTree 內，所有 autoloads 一個接一個 added，每個 add 順序係 `_enter_tree` → `_ready`（即 PersistenceLayer 嘅 `_ready` 已經 fire **之前** GameStateMachine 開始 add）。後果：若 GameStateMachine 喺 `_ready` 直接 emit initial signal，subscriber autoloads（list 中排喺 GameStateMachine 之後嘅 autoloads）都未 connect 到 signal → **WILL** miss it (not "may"). 解決方法：唔 emit "initial" `state_changed`；改為 expose `connect_for_initial_state(callable)` helper 由 subscribers 主動取得 initial state。

**Phase A — Engine bootstrap** (out-of-scope; Godot WASM init + IndexedDB hydrate before any GDScript code runs).

**Phase B+C (merged) — Autoload per-instance sequential** (ADR-006 Contract 4 verified Godot 4.6 behavior — supersedes prior "batched Phase B then Phase C" framing). For each autoload in Project Settings list order:

1. Engine calls `add_child(autoload_instance)` on root.
2. `autoload._enter_tree()` runs synchronously to completion.
3. `autoload._ready()` runs synchronously to completion.
4. Engine proceeds to next autoload (NOT batched — strict per-autoload sequential).

**Autoload load order (locked, in Project Settings)**:
1. `PersistenceLayer` (position 1)
2. `GameStateMachine` (position 2)
3. All other autoloads (EnemyDirector, LootDropSystem, AttentionBudget, GymSysClient, ...) — position 3+

**Per-autoload responsibilities**:

- **`PersistenceLayer._ready()` (position 1, runs first to completion)**:
  - Synchronous `FileAccess.open("user://state.json", READ)` → in-memory dict
  - Compare `dict.schema_version` vs `const SCHEMA_VERSION = 1` → if mismatch, run `migrate(from_version, to_version)` (bounded by `MAX_MIGRATION_CHAIN_LENGTH` × `MIGRATION_BUDGET_MS` per Contract 10); if migration fails → mark corrupt (Rule 5 priority 5)
  - Expose **synchronous** `IPersistence` interface — `read() -> Dictionary`, `write(key, value) -> bool`, `delete(key)`, `migrate(from, to)` (no `await` — autoload chain stays sync per Contract 11 best-effort)

- **`GameStateMachine._ready()` (position 2, runs after PersistenceLayer fully complete)**:
  - Call `_assert_knob_invariants()` BEFORE Rule 5 (Contract 8 — debug-build crash on violation; release no-op)
  - Call `PersistenceLayer.read()` (sync — safe because position-1 autoload's `_ready` already returned)
  - Read `_transition_id_counter` for next transition baseline (Contract 2)
  - Read `_last_weekly_tick_unix` (Decision #5 / Rule 5.5)
  - Construct singleton `_initial_state_payload` sentinel (`StateTransitionPayload` with `source_event = "initial_state"`) per Contract 6 — used by `connect_for_initial_state`
  - Run Rule 5 reconciliation → set `_current_state`
  - Run Rule 5.5 weekly tick missed-window catch-up (boot-only flush phase BEFORE priority-1 LootDrop reveal)
  - **DO NOT emit initial `state_changed`** — downstream subscribers (positions 3+) have NOT yet connected; emit would be silently lost. Subscribers obtain initial state via `connect_for_initial_state(callable)` helper (Contract 6 + 7).
  - Set boot-complete flag `_boot_completed = true`

- **Other autoloads' `_ready()` (positions 3+, subscribers)**:
  - Call `GameStateMachine.connect_for_initial_state(_on_state_changed)` — Contract 6 sentinel-delivery path
  - **MUST NOT** plain `state_changed.connect(_on_state_changed)` — that misses initial state delivery
  - **MUST NOT** call with `.bind(extra)` — `Callable.bind()` shifts positional args; Contract 6 `callv` direct delivery uses standard 3-arg signature `(from, to, payload)` and `.bind()` mis-delivers silently. CI scan (Contract 12 scope addition) flags `connect_for_initial_state(*.bind(*))` literal pattern.

**Phase D — Initial-state delivery via `connect_for_initial_state` helper** (Contract 6 sentinel + Contract 7 race guard):

```gdscript
# In GameStateMachine autoload:
const INITIAL_STATE_PAYLOAD_SOURCE_EVENT: String = "initial_state"
var _initial_state_payload: StateTransitionPayload  # constructed once at boot (Contract 6)
var _last_emit_tick: int = -1                       # Contract 7 race guard

func connect_for_initial_state(callable: Callable) -> void:
    state_changed.connect(callable)
    var captured_state: String = _current_state
    var captured_tick: int = _last_emit_tick   # Contract 7 — snapshot for race guard
    # Deferred via process_frame.connect (NOT call_deferred — Contract 5 idiom avoids
    # variadic-args ambiguity under Godot 4.6 typed-Resource resolution).
    get_tree().process_frame.connect(
        func(): _deliver_initial_state(callable, captured_state, captured_tick),
        CONNECT_ONE_SHOT
    )

func _deliver_initial_state(callable: Callable, captured_state: String, captured_tick: int) -> void:
    # Contract 7 race guard: real transition fired since connect → skip stale initial.
    if _last_emit_tick > captured_tick:
        return
    # Direct callv — NOT state_changed.emit (would broadcast to ALL subscribers, not
    # just the newly-connecting one). Initial-state delivery contract: subscriber
    # receives sentinel payload via callv targeting this Callable only.
    callable.callv(["", captured_state, _initial_state_payload])
```

**Initial-state delivery contract (binding)**:

- Subscribers detect initial-state delivery via `payload.source_event == "initial_state"` (sentinel pattern — Contract 6); same 3-arg signature `(from: String, to: String, payload: StateTransitionPayload)` as real transitions.
- The Callable passed to `connect_for_initial_state` MUST accept the standard 3-arg signature AND MUST NOT be created with `.bind()` extra args (`.bind()` shifts positional layout → `callv` mis-delivers silently). CI rule (Contract 12 scope) scans for `connect_for_initial_state(*.bind(*))` literal pattern → flag as error.
- Race guard (Contract 7): if a real transition fires between `connect_for_initial_state` call and the deferred lambda firing, the deferred initial-state delivery is **skipped** — subscriber already got up-to-date state via the real `state_changed` emit. Verified by AC-30a NEW.

呢個 contract 喺 **AC-30** (sentinel delivery) + **AC-30a** (race guard) 強制驗證。

**Phase E — First real transition** fires `state_changed(prev_state, new_state, payload)` 正常傳達 — subscribers 已 connect。

**`Booting` state query rule**: 喺 `_current_state == BOOTING` 期間（Phase C step 1 之前 OR Rule 5 migration failed），`GameStateMachine.current_state` 仍 return `BOOTING`（不可 return null）。其他 systems 喺 connect 之前 query → 視為 BOOTING，systems 應 no-op 或顯示 splash UI；唔可以 assume game logic ready.

**bfcache fast-resume schema check** (Cluster 6 binding): bfcache fast resume path 跳過 boot reconciliation，但 **必須** 仍然 compare `_pre_suspend_schema_version == const SCHEMA_VERSION`；不匹配 → fallback full boot path（per Edge Cases / Mobile Safari section）。

## Tuning Knobs

所有時間單位以秒為準（除非另外註明）。每個 knob 列：default、safe range、太低嘅後果、太高嘅後果。

### Owned by GameStateMachine

| Knob | Default | Safe Range | Too Low | Too High |
|------|---------|------------|---------|----------|
| `BASE_DELAY` | 1.0s | 0.5 .. 2.0 | Backend hammering on transient errors → rate limit / IP block | 玩家感到 disconnect 過長；reconnect 反應差 |
| `RETRY_CAP` | 16.0s | 8 .. 60 | Backoff curve 太短，未能緩解 backend pressure | Reconnect latency 過長；玩家以為 game 死咗 |
| `REST_PERIOD_FALLBACK_SECONDS` (NEW, Decision #3) | 90.0s | 30 .. 180 | GymSys `rest_started` 漏帶 `duration_seconds` 時 fallback 太短 → 玩家未掂 modal 就 auto-end | Fallback 太長 → GymSys 真係 down 時 RestPeriod 卡住，玩家以為 app 死咗 |
| `MIN_REVEAL_WINDOW_SECONDS` (NEW, Decision #1+#3; **ADR-006 Contract 8 lower bound raise**) | 15.0s | **11 .. 30** (was 5..30; lower bound raised — 5×100=500ms violates invariant 1 vs default `STATE_TRANSITION_FALLBACK_MS = 1000ms`) | LootDrop modal 開無耐就被 `rest_ended` force-close → 玩家來唔切讀 reveal | Modal 推遲到下次 RestPeriod 重試太頻繁，玩家覺得 reveal 一直 dodging |
| `SUSPENSION_TTL_SECONDS` | 86400s (24h) | 3600 .. 604800 (1h-7d) | Resume 經常觸發 full re-boot，session 經常被砍 | 過期 session 被當 fresh，backend 拒絕 → forced re-login，user friction |
| `TOMBSTONE_TTL_SECONDS` | 300s (5min) | 60 .. 3600 | 真正 mid-flight tombstone 被誤判 garbage → state inconsistency | Stale tombstones 殘留太耐，每次 boot 都做 unnecessary recovery |
| `LOOTDROP_PENDING_TTL_DAYS` (soft cap — ITP refresh) | **6 days** | 3 .. 6 | Player 偶然 break 而 IndexedDB 被 ITP evict 之前無時間做 touch refresh → loot 消失 | 接近 ITP 7-day window → 任何延遲都可能令 evict 先於 refresh |
| `LOOTDROP_PENDING_HARD_CAP_DAYS` (NEW hard cap, Decision #1) | **30 days** | 14 .. 90 | 玩家正常 break 就被 auto-commit 入「未開封」inventory → 損失 ritual moment | Backstop 太遠，「未開封」inventory 累積太多 visual clutter |
| `STATE_TRANSITION_FALLBACK_MS` (renamed from LOCK_TIMEOUT_MS; **ADR-006 Contract 8 upper bound lowered**) | 1000ms | **100 .. 1499** (was 500..2000; upper bound lowered — Contract 8 invariant 1 hard upper = `MIN_REVEAL_WINDOW_SECONDS × 100` = 1500ms at `MIN_REVEAL_WINDOW_SECONDS = 15`) | Fallback unlock 太快觸發，正常但慢嘅 transition 被搶 lock | Stuck lock 真係出現時，玩家等太耐先觸發 fallback unlock；中間期 GymSys events 全 drop |

> **⚠️ Cross-knob warning (F-RAT-1 — Gate A signoff 2026-05-28)**: Contract 8 Invariant 1 (`STATE_TRANSITION_FALLBACK_MS ≤ MIN_REVEAL_WINDOW_SECONDS × 100`) means the two knobs are coupled at their boundary corners. **If `MIN_REVEAL_WINDOW_SECONDS` is set below default 15, designer MUST simultaneously reduce `STATE_TRANSITION_FALLBACK_MS` upper bound to `MIN_REVEAL_WINDOW_SECONDS × 100 − 1`** (e.g., at MIN_REVEAL=11, FALLBACK must stay ≤ 1099ms; at MIN_REVEAL=12, ≤ 1199ms). Default combination (FALLBACK=1000 + MIN_REVEAL=15) is safely in the invariant center (1000 < 1500), but designers tuning either knob toward the corrected-range corners MUST verify the pair holds. Contract 8 `_assert_knob_invariants()` runtime check WILL trip on boot in debug builds if pair invariant violates — release builds no-op (the assert is debug-only per ADR-006 line 871). CI smoke test catches violation pre-ship.
| `MAX_TRANSITION_PAYLOAD_BYTES` | 64 KB | 16 KB .. 256 KB | LootDrop payload 撞 cap → tombstone 寫失敗 | 過大 payload 撐爆 IndexedDB write latency；增加 quota 風險 |
| `SESSION_TOKEN_TTL_HOURS` (NEW, Decision #4) | 720 (30d) | 24 .. 2160 (1d-90d) | Token 經常過期，玩家 forced re-login 太頻繁，違反 Pillar 2 | Stolen token 嘅 attack window 太長；reset-password 後仍可用舊 token |
| `SESSION_CLAIM_RETRY_LIMIT` (NEW, Decision #4) | 3 | 1 .. 10 | 短暫 race / 5xx 就 escalate 到 re-login prompt，false-positive | Race 真係解決唔到時無 escalation，玩家停喺 silent failure |
| `WEEKLY_TICK_INTERVAL_SECONDS` (NEW, Decision #5 / Pass 3 B2) | 604800 (7d) | 86400 .. 1209600 (1d-14d) | 短於 7d → #29 evolution cadence 過快，Pillar 5 weekly ritual 失去 anticipation | 長於 14d → 跨月才一次 evolution，retention 心臟唔跳 |
| `MAX_WEEKLY_TICK_CATCHUP` (NEW, Decision #5) | 8 | 1 .. 26 | 1-2 catchup → 玩家長期不活躍返來只 fire 一週進化，前面 progress 真係 lose | >26 → 長期 lapse 玩家一開 game 就 fire 半年 ticks, boot 過慢，#29 batched render 撐爆 |
| `MAX_FORCE_TRANSITION_RETRIES` (NEW, Pass 3 B1) | 3 | 1 .. 5 | 1 retry → 暫時 IndexedDB 寫失敗就 fallback 到「未開封」badge，玩家失去默認 ritual on boot | >5 → boot 喺 LootDrop 反覆嘗試, 啱啱可以開 game 就卡 |
| `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` (NEW, **ADR-006 Contract 9**) | 300s (5 min) | 60 .. 3600 | < 60s → NTP small corrections 觸發 false drift detection, tombstones unnecessarily 路 monotonic fallback | > 3600s → 大 clock jump (e.g. DST + NTP correction) 唔被檢測, stale tombstones 被當 valid → false forward-recovery |
| `MAX_MIGRATION_CHAIN_LENGTH` (NEW, **ADR-006 Contract 10**; shared with #3 PersistenceLayer) | **6** | **1 .. 20** | Too short → 老 client 拒絕 multi-version upgrades, forced corrupt-save path | Too long → migration chain 可能 stall boot 超過 user tolerance (> 20 × 150ms = 3000ms ceiling) |
| `MIGRATION_BUDGET_MS` (NEW, **ADR-006 Contract 10**; shared with #3 PersistenceLayer) | **150ms/step** | **50 .. 500** | < 50ms → 正常 migration step 被當 timeout → false corrupt-save path | > 500ms × 6 = 3000ms migration ceiling + WASM init = cold start > 5s → web user abandon |
> - `EXERCISE_SWITCH_TIMEOUT` — RestPeriod duration 由 GymSys data-driven (Decision #3), state machine 唔再 own timeout timer
> - `LATE_THRESHOLD_SECONDS` — orphan removed (Cluster 6). 無 consumer，late-event handling 邏輯從未實作；若 MVP 後需要可再加 + 同時加 consumer code path

### Read-only by GameStateMachine (owned elsewhere — referenced for context)

| Knob | Owner GDD | Why state machine cares |
|------|-----------|------------------------|
| `GYMSYS_POLL_INTERVAL_SECONDS` (default 5.0s, per concept doc) | #2 GymSys Backend Client | 決定 state-affecting events 嘅 base cadence；401 force-boot latency 取決於下一次 poll fire |
| `WEEKLY_TICK_HOUR_UTC` | #29 Mirror Moment System | 決定 `Idle` 內部 weekly tick event fire 時間；唔影響 state list 本身 |

### Knobs explicitly NOT exposed (compile-time constants)

- **State enum values** — 改變 state list = 改變 schema，需要 migration 而非 tuning
- **Transition rule table** — 改 transition = 改 design intent，唔係 tuning knob
- **Save reconciliation precedence** — backend-wins 係 architectural decision (ADR-003 territory)，唔係 knob

### Tuning Knob Interaction Warnings (Cluster 6 — all invariants verified at safe-range boundaries)

| # | Invariant | At defaults | At worst safe boundary | Why |
|---|-----------|-------------|------------------------|-----|
| 1 | `TOMBSTONE_TTL_SECONDS × 10 ≤ SUSPENSION_TTL_SECONDS` (strict 10× margin, was "<" — Cluster 6 fix) | 3000s ≤ 86400s ✓ | 3600 × 10 = 36000s ≤ 3600s ✗ → **safe range update**: TOMBSTONE max lowered to 360s (was 3600) to preserve invariant at SUSPENSION min (3600s) | Resume 時 tombstone 必須遠新過 session window，否則 stale tombstone 觸發 false forward-recovery |
| 2 | `STATE_TRANSITION_FALLBACK_MS ≤ MIN_REVEAL_WINDOW_SECONDS × 100` (1000ms ≤ 1500ms ✓ at defaults) | ✓ | 2000ms ≤ 5 × 100 = 500ms ✗ → **safe range update**: STATE_TRANSITION_FALLBACK_MS max lowered to 500ms when MIN_REVEAL_WINDOW_SECONDS at 5; **practical guidance**: keep STATE_TRANSITION_FALLBACK_MS ≤ 1000ms in production; raise only with concurrent MIN_REVEAL_WINDOW_SECONDS raise | Fallback unlock 永遠唔可以長到霸佔玩家整個 reveal window |
| 3 | `LOOTDROP_PENDING_TTL_DAYS < 7` (Safari ITP hard cap) | 6 < 7 ✓ | 6 < 7 ✓ | ITP 喺 origin 7 日不活躍 evict IndexedDB；soft cap 唔可以踩 7 |
| 4 | `LOOTDROP_PENDING_TTL_DAYS < LOOTDROP_PENDING_HARD_CAP_DAYS` (soft < hard) | 6 < 30 ✓ | 6 < 14 ✓ | Soft cap (ITP refresh) 必須早過 hard cap (auto-commit) trigger |
| 5 | `MIN_REVEAL_WINDOW_SECONDS × 2 ≤ REST_PERIOD_FALLBACK_SECONDS` (reveal window 要有空間 + buffer) | 30s ≤ 90s ✓ | 60s ≤ 30s ✗ → **safe range update**: MIN_REVEAL_WINDOW_SECONDS max lowered to 15 when REST_PERIOD_FALLBACK at 30; **practical**: 唔好 boost MIN_REVEAL 過 15 除非同時 boost REST_PERIOD_FALLBACK | RestPeriod 短於 reveal min ×2 → modal 永遠唔開得，pending 一直累積 |
| 6 | `SESSION_TOKEN_TTL_HOURS > SUSPENSION_TTL_SECONDS / 3600` (token TTL 必須長過 single suspension window) | 720h > 24h ✓ | 24h > 168h (7d max suspension) ✗ → **safe range update**: SESSION_TOKEN_TTL min raised to 168h (7 days) | 過期 session resume 時 token 仍應 valid，否則每次 wake 都 forced re-login |
| 7 | Boot order: LootDrop TTL check **先於** Suspension TTL check | (boot logic) | (boot logic) | 即使 session 過期 forced re-login，pending loot 仍要 commit (per Decision #1 hard cap 30d backstop)；唔可以 evict 玩家已賺嘅 loot 換 session reset |

**Safe range corrections from invariant audit** (Cluster 6 closure + ADR-006 Contract 8 ratification):
- `TOMBSTONE_TTL_SECONDS`: 60 .. **360** (was 60..3600) — preserves Cluster 6 invariant 1 (×10 margin vs SUSPENSION_TTL_SECONDS min). Note: ADR-006 Contract 8 invariant 2 only requires strict-less (`<`) — GDD's ×10 margin is a project-policy tightening above architectural floor; safe.
- `STATE_TRANSITION_FALLBACK_MS`: **100 .. 1499** (was 500..2000; updated per ADR-006 Contract 8 invariant 1 — hard upper = MIN_REVEAL_WINDOW_SECONDS × 100 = 1500ms at default `MIN_REVEAL_WINDOW_SECONDS = 15`)
- `MIN_REVEAL_WINDOW_SECONDS`: **11 .. 30** (was 5..30; lower bound raised per ADR-006 Contract 8 invariant 1 — `5 × 100 = 500ms < 1000ms` default FALLBACK violates invariant)
- `SESSION_TOKEN_TTL_HOURS`: **168** .. 2160 (was 24..2160) — preserves invariant 6

Updated knob table above reflects these corrections.

## Visual/Audio Requirements

**N/A — pure infrastructure.** State machine 唔擁有任何 visual / audio output。所有 state-affecting visual / SFX 由 downstream consumers 處理：

- `state_changed → CombatActive` 的 hit pause / particle burst 由 #25 Combat Visual Feedback + #5 Particle System Wrapper 處理
- `state_changed → LootDrop` 的 loot reveal 視覺儀式由 #21 Loot Drop Modal 處理（Pillar 3 signature）
- Audio cue（boss spawn fanfare、loot drop sfx）由 #4 Audio Manager 訂閱 `state_changed` 並 trigger 對應 cue

State machine 嘅 implementation 內絕對唔可以 reference `AudioStreamPlayer`、`GPUParticles2D`、`Tween` 等 visual / audio 類 node。

## UI Requirements

**N/A — pure infrastructure.** State machine 唔擁有任何 UI surface。但會 expose 兩個 read-only query 畀 UI consumers：

- `GameStateMachine.current_state → GameState` (enum)
- `state_changed(from, to, payload)` signal

UI systems (#20 Gym-Mode HUD, #21 Loot Drop Modal, #22 Character Screen, etc.) 訂閱呢個 signal 自行決定 layout / visibility / transitions。

**Debug overlay**（dev-only）：建議實作一個 `DebugStateOverlay` Control node（gated by `OS.is_debug_build()`）display：current state、last 5 transitions with timestamps、tombstone present / absent、retry attempt index、event queue depth。**唔屬於 production UI**。

### Signal Contract (typed)

```gdscript
# === Signals ===
signal state_changed(from_state: GameState, to_state: GameState, payload: StateTransitionPayload)
signal dropped_event(event_type: String, reason: String)  # observable side-effect of Rule 4 drops, for tests
signal critical_save_failed(error: String)                # observed by UI for non-blocking notice
signal session_invalidated()                              # NEW (Decision #4) — backend 401 detected; UI toast deferred per Decision #1 natural-pause gating
signal auth_required()                                    # NEW (Decision #4) — no valid session token; UI must show re-login prompt
signal tombstone_write_completed(transition_id: String, latency_ms: int)  # NEW (ADR-006 Contract 11) — telemetry hook for MVP gate; latency WASM-side only (NO IDB fence at VS tier — best-effort); used to validate <1/10K loss rate before MVP upgrade to flush+await
signal weekly_tick_catchup_capped(missed_count: int, capped_at: int)      # NEW (Decision #5 / Rule 5.5) — fires when missed_count > MAX_WEEKLY_TICK_CATCHUP; #29 Mirror Moment 用呢個 signal trigger returning-player ritual

# === Enums ===
enum GameState {
    BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE,
    REST_PERIOD,                # renamed from EXERCISE_SWITCHING (Decision #3)
    COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED
}

enum BossOutcome {              # NEW (Decision #2) — replaces prior boss_defeated: bool
    DEFEATED,                   # boss HP=0 via combat
    INTERRUPTED_WITH_CREDIT,    # workout_completed during BossEncounter (Rule 7 path)
    ABANDONED                   # post-MVP reserved; never fires in VS tier
}

# === Resources ===
class_name StateTransitionPayload extends Resource
@export var transition_id: String  # for backend dedupe (UNIQUE constraint on backend side per Decision #4)
@export var source_event: String   # "workout_completed", "boss_defeated", "deferred_reveal", "session_invalidated", etc.
@export var data: Dictionary       # flexible; per-state schema documented in consumer GDDs

class_name BossPayload extends Resource  # NEW (Decision #2) — embedded as StateTransitionPayload.data["boss"]
@export var outcome: BossOutcome
@export var boss_id: int
@export var hp_at_interrupt: int
@export var hp_max: int

# === Helpers (Cluster 5 + ADR-006 Contract 6 + 7 — solves initial-state-emit-loss bug
#                AND null-payload typed-signal footgun AND deferred-vs-real-transition race) ===
const INITIAL_STATE_PAYLOAD_SOURCE_EVENT: String = "initial_state"
var _initial_state_payload: StateTransitionPayload  # sentinel — constructed once at boot
var _last_emit_tick: int = -1                       # Contract 7 race guard

func connect_for_initial_state(callable: Callable) -> void:
    state_changed.connect(callable)
    var captured_state: GameState = _current_state    # F-STEP4-2 sync 2026-05-28: was String
    var captured_tick: int = _last_emit_tick
    get_tree().process_frame.connect(
        func(): _deliver_initial_state(callable, captured_state, captured_tick),
        CONNECT_ONE_SHOT
    )

func _deliver_initial_state(callable: Callable, captured_state: GameState, captured_tick: int) -> void:
    if _last_emit_tick > captured_tick:    # real transition fired since connect → skip stale
        return
    # F-STEP4-1 self-loop pattern (2026-05-28): pass current state for both from + to so callv args
    # match typed signature (from: GameState, to: GameState, payload: ...). Empty string `""` for
    # from_state would violate the typed signature. Subscribers detect initial-state delivery via
    # payload.source_event == "initial_state" sentinel (Contract 6), NOT via from == "".
    # ADR-0006 Contract 6 code (line 374) still shows the deprecated `""` pattern — addendum pending.
    callable.callv([captured_state, captured_state, _initial_state_payload])
    # `.bind()` extras on callable are FORBIDDEN — `callv` mis-delivers args if positions shift.
    # CI lint enforced: tools/ci/check_connect_for_initial_state_bind.gd (ADR-0006 Contract 12).
```

**Subscriber dispatch order** (Godot signal connect-order is the de-facto contract; this section locks the intended order):

1. PersistenceLayer (#3) — observe-only, may schedule async writes
2. Logic systems (#9, #13, #14, #15, #33) — gameplay reaction
3. Presentation (#20, #21, #22, #25, #26) — UI/visual reaction
4. Telemetry (#28) — last (record post-effect)

Implementation: GameStateMachine fires `state_changed` per real transition + once per subscriber via `connect_for_initial_state` deferred call on connect (Phase D of Boot Sequence). Subscribers connect in autoload `_ready()` 喺 group 順序固定（Group 1 先 register，Group 4 後 register）。`StateChangeBroadcaster` mediator 暫不需要，但若 future ordering bugs 出現可作為 escalation path。

## Acceptance Criteria

全部 **~51 條 ACs** (27 prior + 6 Decisions #1/#2/#4 + Cluster 5 + Pass 3 surgical + Pass 4 ADR-006 sync: AC-11a-extra, AC-22a/b, AC-27a/b, AC-30a, AC-33-collision-safety, AC-33-NEW; 包括 split 子項 11a/11a-extra/11b、15a/15b、17a/17b/17c、22a/22b、27a/27b、30/30a、31a/31b/31c、32a/32b、33/33-collision-safety/33-NEW、34a/34b) 用 Given-When-Then 格式。Test type: Unit / Integration / Static / Manual。Evidence path：`tests/unit/state-machine/`、`tests/integration/state-machine/`、`tests/static/` (架構靜態檢查)。

**Test infrastructure preconditions** (referenced by multiple ACs; **ADR-006 Contract 14 formal Test Spy Contract**):

- `GameStateMachine` autoload 接受 constructor injection (`new(clock: IClock = SystemClock.new(), persistence: IPersistence = ProductionPersistence.new(), http: IHTTP = ProductionHTTP.new())`) — 令 24h waits / save IO / time freeze / 401 mock tests 可行
- `PersistenceLayer` 暴露 `IPersistence` interface with `read() / write(key, value) / delete(key) / migrate(from, to)`; Contract 14 additionally mandates spy interface `attach_write_spy(Callable) / attach_delete_spy(Callable) / clear_spies()` on production `IPersistence` (production no-op, MockPersistenceLayer records)
- `GameStateMachine` test spy: `attach_in_memory_spy(Callable)` records every `_set_in_memory(old_state, new_state)` mutation; `clear_spies()`. Used by AC-04a / AC-16 / AC-21 — supersedes prior ad-hoc `_set_in_memory()` direct references.
- `IHTTP` interface — mock for backend dual-target writes (Decision #4); allow tests to inject 401, retry-after, idempotency responses
- `dropped_event(event_type: String, reason: String)` signal — Rule 4 drops 嘅 observable side-effect，畀 tests assert "silent" behavior
- `session_invalidated()` / `auth_required()` signals (Decision #4) — observable for Decision #4 ACs
- `tombstone_write_completed(transition_id, latency_ms)` signal (Contract 11) — telemetry observable for AC-33-NEW
- `weekly_tick_catchup_capped(missed_count, capped_at)` signal (Decision #5) — observable for AC-34b
- `IInputPolicy` interface (Contract 13) + `MockInputPolicy` with `attach_query_spy(Callable)` for AC-15b
- `MockToastQueue.attach_enqueue_spy(Callable)` (Contract 14) for AC-31a/b/c, AC-32a/b, AC-34a/b
- `MockInventory.attach_grant_spy(Callable)` for AC-19, AC-31a
- `MockEnemyDirector.attach_spawn_spy(Callable)` / `attach_boss_defeated_spy(Callable)` for AC-13, AC-14
- Mock `BossPayload` factory — `make_boss_payload(outcome: BossOutcome, hp: int = -1) -> BossPayload` 簡化 boss-related test setup
- Helper generation: `/test-helpers state_machine` skill (existing) MUST scaffold all above into `tests/helpers/state_machine_spies.gd` per Contract 14. Run once during VS setup.
- **Spy naming discipline (Contract 14 binding)**: any AC referencing a spy MUST use the exact interface name from the table above. Test author can grep the spy name to find correct attachment pattern. Prior ad-hoc names (e.g., `_set_in_memory()` bare reference, "mock IPersistence write spy" phrase) are deprecated; ACs below normalised to canonical names.

### Core Rule Enforcement (Rules 1-7)

- **AC-01** (Rule 1): **GIVEN** game 正常運行，**WHEN** 任何時刻 inspect `GameStateMachine.current_state`，**THEN** 返回 `GameState` enum 入面 exactly one — 非 null / 非 compound / 非 dual-state。
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_single_active_state.gd`
- **AC-02** (Rule 1): **GIVEN** persisted `current_state` 含有 unrecognized string key (`"phantom_state"`)，**WHEN** boot assertion fire，**THEN** hard-crash to `Booting`（assert + log），保存被視為 corrupt clear, 然後 boot 去 `Idle`。MockLogger.error_calls.size() >= 1 assert.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_assertion_crash_on_invalid_state.gd`
- **AC-03** (Rule 2 forward-recovery, new step order): **GIVEN** mock `IPersistence` returns `{current_state: "workout_active", pending_transition: {transition_id: "tx_123", from: "workout_active", to: "loot_drop", payload: {...}, wall_clock_anchor: now-30}}` 且 final-state record 缺 `loot_drop` 寫入，**WHEN** `GameStateMachine.boot()` runs，**THEN** forward-recovery 自動 idempotently 重做 step 3-8（per new Rule 2 ordering）：寫 final state → 更新 in-memory → clear tombstone → dual-target backend write with `transition_id = "tx_123"` (state POST + lootdrop cache POST) → emit `state_changed` → release lock。`current_state` 結束時等於 `LOOT_DROP`，唔會係 `WORKOUT_ACTIVE`。
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_tombstone_forward_recovery.gd`
- **AC-04a** (Rule 2 re-entrance via synchronous subscriber, observable — Cluster 1 atomicity test; **Contract 14 canonical spies**): **GIVEN** outer transition 執行緊 step 7 emit signal AND a subscriber's connected handler synchronously calls `_request_transition(...)` AND `IPersistence.attach_write_spy(write_log.append)` wired，**WHEN** the synchronous call enters，**THEN** lock 仍 held (step 8 未 release)，inner call 撞 lock → `dropped_event` signal emit exactly 1 次帶 `reason = "lock_held"`；`write_log.size() == 2` (outer tombstone + outer final, NO inner pair)；outer emit completes 之後先 release lock。**Verifies emit-before-release ordering prevents nested transitions** (vs prior bug where release-before-emit allowed nested transition).
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_transition_lock_drop_synchronous_reentrance.gd`
- **AC-04b** (Rule 2 lock fallback unlock): **GIVEN** transition function 喺 step 3 (final state write) throw 並未 release lock，**WHEN** `STATE_TRANSITION_FALLBACK_MS` 時間經過後，**THEN** fallback timer fire `_force_clear_lock`，`_transitioning == false`，下個 incoming event 唔再被 drop — 無 permanent freeze；in-memory state remains pre-transition value (phantom-state defense)。
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_lock_fallback_unlock.gd`
- **AC-05** (Rule 4): **GIVEN** game 喺 `Suspended`，**WHEN** GymSys emit `workout_started`，**THEN** `dropped_event(workout_started, "rejected_in_state_suspended")` emit, `current_state` 不變, mock persistence write spy call count == 0.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_rejected_event_silent_drop.gd`
- **AC-06** (Rule 4 exception, CRITICAL_SAVE_FAILED): **GIVEN** `Suspended` 期間 `CRITICAL_SAVE_FAILED` event fire，**WHEN** event processed，**THEN** `critical_save_failed(error)` signal emit exactly 1 次, `dropped_event` 唔 emit (即唔當 silent drop), MockLogger.error_calls.size() >= 1, UI notice queue (mock #21 toast queue) length increases by 1.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_critical_save_failed_exception.gd`
- **AC-07** (Rule 5 priority 1, Pillar 3): **GIVEN** boot 時 mock persistence returns `{current_state: "loot_drop", loot_pending: {item_id: "epic_sword", payload: {...}}}` 且 backend reachable + `current_state: "idle"`，**WHEN** reconciliation 完成，**THEN** game 進入 `LOOT_DROP`（client wins priority 1），loot payload 完全 preserved，backend 不可以 override。
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_boot_lootdrop_clientwins.gd`
- **AC-08** (Rule 5 priority 3 non-LootDrop): **GIVEN** persisted state = `WORKOUT_ACTIVE` 無 loot_pending，backend 第一個 poll 確認 `current_state = "workout_active"`，**WHEN** boot reconciliation 完成，**THEN** game 進入 `WORKOUT_ACTIVE`，tombstone 不存在；transition_id 喺 backend write spy 收到 exactly once。
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_boot_workout_restore.gd`
- **AC-09** (Rule 5 corrupt save): **GIVEN** `user://state.json` 存在但 `FileAccess.get_as_text()` 後 `JSON.parse_string()` 返回 null，**WHEN** `Booting` 執行，**THEN** state key cleared (mock delete spy called), boot 去 `IDLE`, `critical_save_failed` signal emit 1 次，下個 poll 觸發 backend reconciliation — 無 crash、無 stuck 喺 `BOOTING`。
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_corrupt_save_clean_boot.gd`
- **AC-10** (Rule 5 stale tombstone): **GIVEN** tombstone 嘅 `wall_clock_anchor` 比 `clock.get_unix_time()` 早超過 `TOMBSTONE_TTL_SECONDS` (300s)，**WHEN** game boot，**THEN** tombstone 視為 abandoned、deleted from persistence (delete spy called)，priority-3 backend reconcile 跑 —— 唔可以 forward-recover。
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_expired_tombstone_abandoned.gd`
- **AC-11a** (Rule 7 boss credit, Pillar 3 + Decision #2 BossOutcome enum + **ADR-006 Contract 3 round-trip**): **GIVEN** game 喺 `BOSS_ENCOUNTER` boss HP > 0，**WHEN** GymSys emit `workout_completed`，**THEN** game force-transition 到 `LOOT_DROP` 喺下一個 frame. Transition payload 必須包含 `data["boss"]: BossPayload` 且該 `BossPayload` 必須滿足：`outcome == BossOutcome.INTERRUPTED_WITH_CREDIT`、`boss_id == <current_boss_id>`、`hp_at_interrupt == <current_hp>`、`hp_max == <boss_hp_max>`、`source_event == "workout_completed"`。缺任何一個 field OR `outcome` 不等於 `INTERRUPTED_WITH_CREDIT` → assert fail. **Verifies enum disambiguates from `DEFEATED` path** (which has `outcome=DEFEATED, hp_at_interrupt=0, source_event="boss_defeated"`). **AC-11a-extra (Contract 3 round-trip)**: **GIVEN** `BossPayload` instance constructed per above，**WHEN** call `dict = payload.to_dict()` then `restored = BossPayload.from_dict(dict)`，**THEN** `restored.outcome == payload.outcome` (enum survives string round-trip via `BossOutcome.find_key`), `restored.boss_id == payload.boss_id`, `restored.hp_at_interrupt == payload.hp_at_interrupt`, `restored.hp_max == payload.hp_max`. AND `dict["outcome"] == "INTERRUPTED_WITH_CREDIT"` (string name, NOT int — verifies SerializableResource envelope writes human-readable JSON for IndexedDB devtools inspection per Contract 3 rationale).
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_rule7_boss_credit_payload.gd` + `test_boss_payload_serialization_round_trip.gd`
- **AC-11b** (Rule 7 no-input timing, Pillar 2 + Decision #1 natural-pause language): **GIVEN** game force-transition `BOSS_ENCOUNTER → LOOT_DROP` per AC-11a，**WHEN** transition 完成，**THEN** `AttentionBudget.is_input_permitted()` 返回 `false` 喺到達 `LOOT_DROP` 嘅瞬間；only after #21 Loot Drop Modal opens the ritual reveal (player has not yet tapped to dismiss) `is_input_permitted()` 仍係 `false`（modal is the input, not the surroundings）；玩家 tap dismiss → exit `LOOT_DROP`. **No "non-modal toast" path here** — toast UX was the prior anti-pattern; Decision #1 replaces it with natural-pause gated modal ritual.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_rule7_no_mid_set_input.gd`
- **AC-12** (Rule 7 same-frame): **GIVEN** Event Intake Queue 內同一 dequeue cycle 出現 `boss_defeated` (priority 4) 同 `workout_completed` (priority 1)，**WHEN** queue drain，**THEN** `workout_completed` 先 dequeue (priority wins), game transition `BOSS_ENCOUNTER → LOOT_DROP`。`boss_defeated` 下一 frame dequeue 時 guard fail → `dropped_event(boss_defeated, "guard_failed_state_loot_drop")` emit. `state_changed` history.size() == 1.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_same_frame_event_priority.gd`

### Cross-System Contracts

- **AC-13**: **GIVEN** game transition 到 `COMBAT_ACTIVE`，**WHEN** `state_changed(...)` signal fire，**THEN** EnemyDirector activate sub-machine 喺下一個 frame (via `call_deferred`) — state machine **無** direct call EnemyDirector method（mock EnemyDirector method call spy count == 0；只有 signal emit count == 1）。
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_enemydirector_signal_contract.gd`
- **AC-14**: **GIVEN** game 喺 `LOOT_DROP`，**WHEN** LootDropSystem emit `loot_confirmed`，**THEN** GameStateMachine 接收 signal → `call_deferred("_request_transition", ...)` → 下個 frame transition 到 `IDLE`. Loot Drop System mock 嘅 direct-call spy count == 0.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_lootdrop_system_contract.gd`
- **AC-15a** (behavioral, Pillar 2): **GIVEN** game 喺 `WORKOUT_ACTIVE`，**WHEN** #33 AttentionBudgetPolicy query `is_input_permitted()`，**THEN** 返回 `false`.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_attention_budget_returns_false.gd`
- **AC-15b** (architectural, **ADR-006 Contract 13 IInputPolicy injection** — supersedes prior literal-name regex test which was refactor-fragile): **GIVEN** input handler component (HUD, modal) constructor-injected with `policy: IInputPolicy = MockInputPolicy.new()` AND mock configured `_permitted = false`，**WHEN** trigger raw input event during `WORKOUT_ACTIVE`，**THEN** mock's `is_input_permitted()` spy called exactly 1 次 (verified via `MockInputPolicy.attach_query_spy(Callable)`) AND input event dropped (handler's downstream action spy call count == 0). **Architectural enforcement layer**: Pillar 2 lives at the input-handler boundary (consuming `IInputPolicy`), NOT at the state-machine boundary; state machine remains source-of-truth read-only `current_state`. Refactoring input handlers to inject `IInputPolicy` (instead of direct `AttentionBudgetPolicy` reference) does NOT break this test — Contract 13 contract test survives.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_input_policy_injection_drops_during_workout.gd`
- **AC-16** (Cluster 2 — phantom-state defense via write order; **Contract 14 canonical spies**): **GIVEN** `IPersistence.attach_write_spy(write_log.append)` + `IPersistence.attach_delete_spy(delete_log.append)` + `GameStateMachine.attach_in_memory_spy(mem_log.append)` all wired before transition, **WHEN** transition runs and inspect merged call order array, **THEN** order = `["tombstone_write" (step 2), "final_state_write" (step 3), "in_memory_set" (step 4), "tombstone_delete" (step 5), "emit_signal" (step 7), "release_lock" (step 8)]`. 永遠唔會喺 guard (step 1) 之前 OR `release_lock` 之後. **In-memory `attach_in_memory_spy` 觀察到嘅 `_set_in_memory` 必須喺 `final_state_write` 之後**（若反序 → step 3 失敗會 leak 入 phantom in-memory state）。**`emit_signal` 必須喺 `release_lock` 之前**（per AC-04a — synchronous re-entrance 撞 lock）。
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_persistence_call_order.gd`

### Formula

- **AC-17a** (positive path): **GIVEN** `Disconnected` state 且 `BASE_DELAY=1.0` `RETRY_CAP=16.0`，**WHEN** retry n=1 至 n=6，**THEN** delays = `1.0, 2.0, 4.0, 8.0, 16.0, 16.0` — n≥6 cap 住永遠唔超 `RETRY_CAP`.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_retry_backoff_formula.gd`
- **AC-17b** (precondition assertions, negative tests): **GIVEN** `BASE_DELAY = -1.0` OR `n = 0` OR `BASE_DELAY > RETRY_CAP`, **WHEN** `retry_delay(n)` called, **THEN** runtime `assert()` fires (test catches via `Engine.is_editor_hint()` mock OR by wrapping call in `await get_tree().process_frame` and checking debug_break() called). 至少 1 次 assertion message.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_retry_backoff_preconditions.gd`
- **AC-17c** (overflow cap): **GIVEN** `n = 100`, **WHEN** `retry_delay(100)` called, **THEN** result == `RETRY_CAP` (16.0) 而非 INF — 由 `ATTEMPT_CAP = 30` 內部 clamp 保護.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_retry_backoff_overflow_cap.gd`

### Static Analysis (Architectural Guarantees)

- **AC-18** (Rule 2 + Pillar 2 architectural, **ADR-006 Contract 12 file-wide rule** — supersedes prior `_transition_*`-prefix-only scan which leaked through helper-via-await escapes): **GIVEN** the codebase under `src/core/state_machine/`，**WHEN** CI runs `rg --glob "src/core/state_machine/**/*.gd" "\\bawait\\b"`，**THEN** result must be empty (zero matches across all files in that directory, including helpers). Allowed escape: HTTPRequest callbacks (`_on_http_request_completed`) MUST NOT `await` either; deferred logic via `call_deferred` OR `process_frame.connect(... CONNECT_ONE_SHOT)` only (Contract 5 idiom). **Architectural reasoning**: helper functions in state-machine files are implicitly part of transition execution graph; whole-file scan eliminates need for call-graph walker AND closes Pass 3 qa-lead B3 escape.
  - **Test type**: Static / CI | **Evidence**: `tools/ci/check_no_await.gd` OR `tools/ci/check_no_await.sh` (shell command above)

### Pillar 3 Hard Guarantee

- **AC-19** (Decision #1 — 30-day hard cap REFRAMED per Pass 3 B1 — force-boot LootDrop, NOT silent commit; **ADR-006 Contract 15 server-authoritative clock**): **GIVEN** `loot_reveal_pending == true`，**WHEN** boot reconciliation enters Rule 5 priority 0.5 check，**THEN** authoritative hard-cap timestamp is fetched via `GET /lootdrop/{transition_id}/cache` returning `pending_since_server: int (unix)` (NOT local `loot_pending.pending_since` — local is mirror only, NOT authoritative per Contract 15)。如 `now - pending_since_server >= LOOTDROP_PENDING_HARD_CAP_DAYS × 86400` (30 日) → priority 0.5 wins — force-transition `Booting → LootDrop` 帶 cached payload + `source_event = "deferred_reveal_hard_cap"` — 完整 #21 modal ritual fire 喺玩家一開 game 第一個 frame；玩家 tap dismiss → exit `LootDrop` → loot grant to inventory + `loot_reveal_pending = false` + `loot_pending` cleared. **NO silent commit before player sees ritual**. **Offline mode rule (Contract 15 binding)**: if backend `GET /lootdrop/{transition_id}/cache` unreachable, defer hard-cap eviction (DO NOT use local `pending_since` for eviction); client uses local `pending_since` only for soft TTL UX purposes; hard-cap fires only when backend reachable. **AC-19b (fallback)**: **GIVEN** AC-19 setup AND payload corrupt + backend `GET /lootdrop/{transition_id}/cache` 返 404 + 3 retries 失敗，**WHEN** `MAX_FORCE_TRANSITION_RETRIES = 3` 用盡，**THEN** fallback path 觸發：loot auto-commit 入 inventory 帶「未開封」badge (`inventory.items[i].unopened == true`)；玩家可 tap badge → `Idle → LootDrop` ritual recovery (`source_event = "deferred_reveal_unopened_badge"`) — 即使 fallback path 都仍保證 ritual reachable。**Loot content preserved**, **default path = ritual on boot**, **fallback path = ritual via badge tap**, **NEVER silent commit without ritual reachability**.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_lootdrop_hard_cap_force_boot.gd` + `test_lootdrop_hard_cap_offline_defers.gd` + `test_lootdrop_hard_cap_fallback_badge.gd`
- **AC-20** (Rule 5 priority 1 vs priority 3): **GIVEN** local has `current_state: "loot_drop"` + `loot_pending: {...}`, backend returns `"no workout active, idle"`, **WHEN** reconciliation 行, **THEN** priority 1 wins — game 進入 `LOOT_DROP` 帶 cached payload；backend 嘅 `idle` claim ignored；loot commit 之後先 reconcile 入 `IDLE`。Backend write spy 收 transition_id 一次（commit）然後正常 idle transition。
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_loot_priority_over_backend.gd`
- **AC-21** (forward-recovery quota fail + phantom-state defense — Cluster 2 + **ADR-006 Contract 11 best-effort IDB + Contract 14 canonical spies**): **GIVEN** tombstone 存在 `to: "loot_drop"` 但 mock `IPersistence.write()` 喺 step 3 final state write returns `false` (WASM-side serialization failure — e.g., QuotaExceededError surfaced through `FileAccess.store_*` bool return per 4.4+ API) AND `GameStateMachine.attach_in_memory_spy(mem_log.append)` wired, **WHEN** boot reconciliation, **THEN** **in-memory retry once** (NOT IDB-fence wait — Contract 11 VS tier mandates no `FileAccess.flush()` / no async-commit ack wait); if retry still returns `false` → tombstone preserved → `critical_save_failed` emit → **in-memory `_current_state` 仍係 pre-transition value** (NOT `LOOT_DROP`; phantom-state 防禦 — 唔可以喺 disk 寫失敗時 leak 入 in-memory; `mem_log` does NOT contain any entry transitioning to `LOOT_DROP`)；priority-2 forward-recovery 留低，下次 boot 嘗試重做 step 3-8。**Verifies Cluster 2 fix**: 與舊版 (in-memory updated before final write) 對比，呢個 AC fail 即代表 phantom-state bug 重現。**Contract 11 risk acceptance**: WASM-accept vs IDB-commit < 1-frame gap (tab killed in this window → tombstone lost) is the ~0.05% per-transition risk explicitly accepted at VS tier; telemetry hook `tombstone_write_completed` measures actual rate for MVP gate (see AC-33-NEW).
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_lootdrop_quota_fail_no_phantom_state.gd`

### Suspended / Race / Web Export

- **AC-22** (Suspension TTL): **GIVEN** mock `clock` advanced past `SUSPENSION_TTL_SECONDS` (24h)，`current_state == SUSPENDED` 且 `resume_target == WORKOUT_ACTIVE`，**WHEN** `pageshow` event with `persisted == false` fires，**THEN** full boot reconciliation 跑（NOT simple resume），backend session re-validated，`retry_attempt_index = 1` reset.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_suspension_ttl_forces_reboot.gd`
- **AC-22a** NEW (**ADR-006 Contract 9 wall-clock drift → monotonic fallback**): **GIVEN** tombstone with `wall_clock_anchor = T0` AND `monotonic_anchor_ms = M0` AND mock `Time.get_unix_time_from_system()` jumps to `T0 + 10000s` (10000s wall diff) while mock `Time.get_ticks_msec()` reports `M0 + 60000` (60s monotonic diff — `mono_diff_sec = 60`), **WHEN** `_is_tombstone_expired(tombstone)` called, **THEN** `abs(10000 - 60) = 9940 > WALL_CLOCK_DRIFT_TOLERANCE_SECONDS (300)` → drift detected → expiry check falls back to monotonic (`mono_diff_sec = 60 > TOMBSTONE_TTL_SECONDS (300)` → false → tombstone NOT expired) — wall-clock NTP correction does NOT falsely nuke valid tombstone. **AC-22b** (Contract 9 default wall path): **GIVEN** tombstone with both anchors AND mock clocks advance in lockstep (no drift detected), **WHEN** check fires, **THEN** wall-clock TTL diff used (default path) — `now_wall - anchor_wall > TOMBSTONE_TTL_SECONDS` → tombstone expired.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_tombstone_ttl_drift_tolerance.gd`
- **AC-23** (RestPeriod race — Decision #3): **GIVEN** game 喺 `REST_PERIOD` with open LootDrop modal AND GymSys emit `rest_ended` 同一 dequeue cycle 同 player tap dismiss modal，**WHEN** queue drain，**THEN** Event Intake Queue priority 排序：player tap (priority 2) 先 → modal commit + transition `REST_PERIOD → WORKOUT_ACTIVE`；`rest_ended` (priority 3) 下個 frame dequeue 時 guard fail (已喺 WORKOUT_ACTIVE) → `dropped_event(rest_ended, "guard_failed_state_workout_active")` emit. 反向 case: `rest_ended` 先 → modal force-close、`loot_reveal_pending` 保持 `true`、transition → `WORKOUT_ACTIVE`、player tap 入 queue (priority 2) 但 guard fail (state changed) → `dropped_event` emit；`loot_reveal_pending` 下次 RestPeriod 重試 reveal. **No timer to cancel** — state machine 唔再 own RestPeriod timeout (Decision #3 — GymSys owns).
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_rest_period_race.gd`
- **AC-24** (Disconnected → previous state recovery, Pillar 2): **GIVEN** state machine 喺 `DISCONNECTED` 帶 `resume_target = WORKOUT_ACTIVE`，**WHEN** GymSys client emit `poll_recovered`, **THEN** game transition 返 `WORKOUT_ACTIVE`（NOT `IDLE`），`retry_attempt_index = 1` reset，state_changed signal fire exactly once.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_disconnected_recovery.gd`
- **AC-25** (pagehide → Suspended, JS bridge): **GIVEN** mock `JavaScriptBridge` simulates `pagehide` callback fire，**WHEN** callback marshalls through to GDScript, **THEN** game transition current_state → `SUSPENDED`, `resume_target` capture 原 state, synthesized `InputEventScreenTouch(pressed: false)` emit via `Input.parse_input_event` (mock Input spy).
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_pagehide_suspend.gd`
- **AC-26** (bfcache fast resume, Q-A3 resolved + Cluster 6 schema check): **GIVEN** game 喺 `SUSPENDED`, in-memory autoload instance preserved (mock `event.persisted = true` 而 GameStateMachine instance == pre-suspend instance) AND `_pre_suspend_schema_version == const SCHEMA_VERSION`, **WHEN** `pageshow` callback fires, **THEN** fast resume path — direct transition `SUSPENDED → resume_target`，無 boot reconciliation 跑（mock IPersistence.read spy call count == 0 喺 resume window 內），但 `loot_reveal_pending` 檢查仍跑（per Decision #1 — 若 true AND new state ∈ safe states → `call_deferred` deferred reveal）.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_bfcache_fast_resume.gd`
- **AC-27** (bfcache fallback to full boot — autoload reinit OR schema mismatch): **GIVEN** EITHER `event.persisted = true` AND autoload instance 已 reinit (mock GameStateMachine instance != pre-suspend instance) OR `_pre_suspend_schema_version != const SCHEMA_VERSION`, **WHEN** `pageshow` callback fires, **THEN** fallback full boot path 跑 — Rule 5 reconciliation including schema migration 完整執行, mock IPersistence.read spy called, `PersistenceLayer.migrate(from, to)` called if schema mismatch.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_bfcache_fallback_full_boot.gd`
- **AC-27a** (**ADR-006 Contract 10 migration chain bounded**): **GIVEN** persisted `schema_version = 1` AND `const SCHEMA_VERSION = 12` (chain length 11), **WHEN** boot calls `PersistenceLayer.migrate(1, 12)`, **THEN** chain length check fires `chain_length > MAX_MIGRATION_CHAIN_LENGTH (10)` → migration returns false → corrupt-save path per Rule 5 priority 5 → boot to `IDLE` with `critical_save_failed` emit; no migration steps executed. **AC-27b** (Contract 10 per-step budget): **GIVEN** persisted `schema_version = 1` AND `const SCHEMA_VERSION = 3` AND mock `_migrate_one_step(1, 2)` sleeps `MIGRATION_BUDGET_MS + 100ms = 600ms`, **WHEN** boot calls migrate, **THEN** step 1→2 returns success but `step_elapsed > MIGRATION_BUDGET_MS` → migration returns false → corrupt-save path; step 2→3 never invoked.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_migration_chain_length_cap.gd` + `test_migration_step_budget_cap.gd`

### NEW ACs — Decision #1 / #2 / #4 / Cluster 5 (binding)

- **AC-28** (Decision #1 — deferred reveal on safe-state entry): **GIVEN** `loot_reveal_pending == true` AND `current_state == WORKOUT_ACTIVE` AND cached `loot_pending` payload valid, **WHEN** GymSys emit `rest_started(duration_seconds=90)` causing transition `WORKOUT_ACTIVE → REST_PERIOD`, **THEN** state machine `_on_state_changed` handler evaluates `loot_reveal_pending && new_state in [IDLE, REST_PERIOD, DISCONNECTED] && remaining >= MIN_REVEAL_WINDOW_SECONDS` → `call_deferred("_request_transition", LOOT_DROP)` 帶 cached payload + `source_event = "deferred_reveal"`. Next frame: `state_changed → LOOT_DROP` emit. Test 同樣 verify **suppressed path**: `loot_reveal_pending == true` AND new_state == `WORKOUT_ACTIVE` → no deferred call, flag preserved。
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_deferred_reveal_safe_state_entry.gd`
- **AC-29** (Decision #1 — inventory tap on "未開封" item recovery): **GIVEN** inventory contains item with `unopened == true` (auto-committed per AC-19), **WHEN** player tap triggers `request_reveal(item_id)` API (inventory UI side, mock), **THEN** state machine 接收 → `Idle → LootDrop` transition 帶 restored payload + `source_event = "deferred_reveal"`. Modal ritual completes → player tap dismiss → exit `LootDrop` + `unopened` flag cleared on item (mock inventory write spy). **No double-grant**：item 已喺 inventory, 呢個 path 只係 ritual recovery 唔再 grant 新 loot.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_inventory_tap_unopened_ritual.gd`
- **AC-30** (Cluster 5 + **ADR-006 Contract 6 sentinel payload** — supersedes prior `payload == null` model): **GIVEN** GameStateMachine `_ready()` completes setting `_current_state = WORKOUT_ACTIVE` (from prior session via Rule 5 reconcile) AND `_initial_state_payload` sentinel constructed (`StateTransitionPayload` with `source_event = "initial_state"`, `data = {}`), **WHEN** subscriber autoload 喺 own `_ready()` call `GameStateMachine.connect_for_initial_state(_on_state_changed)`, **THEN** next idle frame (via `process_frame.connect ONE_SHOT` per Contract 5 idiom) subscriber `_on_state_changed(from, to, payload)` invoked via direct `Callable.callv(["", "WORKOUT_ACTIVE", _initial_state_payload])` — NOT via `state_changed.emit()` (would broadcast to all subscribers per Contract 6). Subscriber sees `from == ""`, `to == "WORKOUT_ACTIVE"`, `payload.source_event == "initial_state"`. Subscriber detects initial-state delivery via `if payload.source_event == "initial_state": _setup_for_state(to)` else `_react_to_transition(from, to, payload)`. **Verifies Contract 6 sentinel pattern**: payload is non-null typed Resource; subscribers no longer null-deref by accidentally treating initial-state delivery as real transition.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_connect_for_initial_state_sentinel_delivery.gd`
- **AC-30a** NEW (**ADR-006 Contract 7 race guard** — `connect_for_initial_state` vs real transition same boot frame): **GIVEN** GameStateMachine `_ready()` set `_current_state = IDLE` AND subscriber autoload calls `connect_for_initial_state(_on_state_changed)` capturing `captured_tick = _last_emit_tick` (snapshot), **WHEN** before next `process_frame` fires, a real GymSys event triggers `_request_transition` → `state_changed.emit("idle", "workout_active", payload)` (subscriber receives real transition; `_last_emit_tick` incremented past `captured_tick`), AND THEN the deferred `_deliver_initial_state` lambda fires, **THEN** `_last_emit_tick > captured_tick` → race guard skips initial-state delivery → subscriber's `_on_state_changed` invoked EXACTLY 1 time total (the real transition), NEVER receiving a stale initial-state delivery after the real transition. **Verifies Pass 3 godot-specialist B4 fix**: prior version would have subscriber see real → stale initial-state-of-IDLE → desynced state model.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_connect_for_initial_state_race_guard.gd`
- **AC-31** (Decision #4 — 401 force boot WITH active-state deferral per Pass 3 B3, Pillar 2 fix): **AC-31a (deferred active-state path)**: **GIVEN** game 喺 `WORKOUT_ACTIVE` AND mock GymSys poll returns HTTP 401, **WHEN** poll response handler 處理, **THEN** force-boot **DEFERRED** — `_pending_401_reconciliation = true` set; phone 維持 `WORKOUT_ACTIVE` 並 run on cached GymSys data (functionally Disconnected mode); **NO** immediate transition to BOOTING; mock UI HUD spy verifies no splash/boot screen flash. **WHEN** GymSys emit `rest_started` triggering `WORKOUT_ACTIVE → REST_PERIOD`, **THEN** the deferred 401 reconciliation **fires on REST_PERIOD entry** — emit `session_invalidated()`, transition `REST_PERIOD → BOOTING`, retry `POST /session/claim` up to `SESSION_CLAIM_RETRY_LIMIT` (3) times. **AC-31b (non-active immediate path)**: **GIVEN** game 喺 `IDLE` (or `RestPeriod` / `Disconnected` / `Suspended`) AND 401 fires, **WHEN** handler 處理, **THEN** 即時 force-boot — `current_state → BOOTING` 同 frame；retry claim path same as AC-31a. **AC-31c (claim exhaustion)**: **GIVEN** AC-31a/b setup AND mock backend returns 5xx on every `POST /session/claim` retry, **WHEN** `SESSION_CLAIM_RETRY_LIMIT` (3) attempts exhausted, **THEN** `auth_required()` signal emit 1 次；state machine holds at BOOTING；`current_state` query returns BOOTING (not null, not crashed)；GymSys polls suppressed until re-claim succeeds.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_401_active_deferred.gd` + `test_401_non_active_immediate.gd` + `test_401_claim_exhaustion_auth_required.gd`
- **AC-32** (Decision #4 — `session_invalidated` toast timing split per Pass 3 B12, state-mismatch case bypasses gating): **AC-32a (state-agree case, gating applies)**: **GIVEN** AC-31 path complete AND post-401 reconciliation lands on **same state** as pre-401 (e.g. backend agrees `WORKOUT_ACTIVE`)，**WHEN** `session_invalidated()` signal emit, **THEN** #21/HUD toast queue 不 immediately fire 「已在另一部裝置繼續」 — gating per Decision #1；mock UI toast queue size == 0 during the agreed-state period; **WHEN** GymSys emit `rest_started` 後 transition → `REST_PERIOD`, **THEN** queued toast finally displays (toast spy increments by 1). **AC-32b (state-mismatch case, immediate toast — Pass 3 B12)**: **GIVEN** AC-31 path complete AND post-401 reconciliation lands on **DIFFERENT state** (e.g. pre-401 was `WORKOUT_ACTIVE`, backend authoritative says `IDLE` because tablet finished/cancelled workout)，**WHEN** the post-reconcile `state_changed(WORKOUT_ACTIVE → IDLE)` signal fire, **THEN** toast 「已在另一部裝置繼續」**即時 fire** on that emit (bypass Decision #1 natural-pause gating) — toast spy size == 1 喺 same frame；player gets context immediately on the disruptive state change, NOT 90 seconds later. **Verifies B12 fix**: state-mismatch is the "transparent handoff" failure mode that requires immediate context; state-agree is the no-op case that respects gating.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_session_invalidated_toast_state_agree.gd` + `test_session_invalidated_toast_state_mismatch_immediate.gd`
- **AC-33** (Decision #4 — idempotent commit, no double-grant on multi-device race; **collision-safety now RESOLVED via ADR-006 Contract 2**): **GIVEN** offline device A taps LootDrop dismiss → commit queued offline AND device B 已 commit same `transition_id` to backend, **WHEN** device A reconnects AND retries `POST /lootdrop/{transition_id}/commit`, **THEN** mock backend returns 200 with canonical inventory snapshot (NOT new grant)；device A 用 snapshot reconcile inventory，no double-add of item，`loot_pending` cleared. **Verifies `transition_id` UNIQUE constraint server-side dedupe** (Decision #4 cluster #3 closure). **AC-33-collision-safety** (Contract 2): **GIVEN** transition with `transition_id = T1` written to tombstone in session A, AND WASM reload simulated (mock `Time.get_unix_time_from_system()` advances 5s; mock `_transition_id_counter` persisted), **WHEN** forward-recovery on next boot reads tombstone, **THEN** forward-recovery code MUST extract `T1` from tombstone verbatim and reuse — NEVER call `_generate_transition_id()`. Test asserts: (a) backend write spy receives `T1` exactly once during forward-recovery (verifies reuse), (b) no NEW counter-incremented transition_id appears in spy log for the recovered transition (verifies non-regeneration), (c) backend UNIQUE constraint returns 200-dedupe rather than 409-conflict.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_lootdrop_commit_idempotent_no_double_grant.gd` + `test_transition_id_collision_safety_wasm_reload.gd`
- **AC-33-NEW** (**ADR-006 Contract 11 telemetry hook for MVP gate**): **GIVEN** mock `IPersistence.write()` for tombstone takes `T_ms` to return (WASM-side accept, NOT IDB commit ack), **WHEN** Rule 2 step 4 completes (or step 3 in new ordering — final state write success), **THEN** GameStateMachine emits `tombstone_write_completed(transition_id, latency_ms)` signal exactly 1 次 with `latency_ms == T_ms` (measured WASM-side). Telemetry subscriber (#28) records latency distribution; MVP gate ownership: producer schedules end-of-VS-playtest review against 1/10K loss-rate threshold (per ADR-006 Migration Plan step 11). If threshold exceeded → Contract 11 upgrades to Option B (`FileAccess.flush() + 1-frame await`) for MVP.
  - **Test type**: Unit | **Evidence**: `tests/unit/state-machine/test_tombstone_write_completed_telemetry.gd`

### Decision #5 — Weekly Tick Missed-Window Replay (NEW Pass 3 B2)

- **AC-34a** (Decision #5 — missed weekly_tick replay on boot, Pillar 5 protection): **GIVEN** mock persistence returns `_last_weekly_tick_unix = (now - 4 × WEEKLY_TICK_INTERVAL_SECONDS - 3600)` (4 ticks missed) AND `current_state = "idle"`, **WHEN** boot completes Phase C step 2 (Rule 5 reconciliation + Rule 5.5 weekly tick check) and Rule 5.5 evaluates `missed_count = floor(diff / WEEKLY_TICK_INTERVAL_SECONDS) = 4`, **THEN** 4 `weekly_tick` events enqueued at priority 5 → drained in dedicated boot-flush phase BEFORE priority-1 LootDrop reveal evaluation. After drain: `_last_weekly_tick_unix` updated to latest anchored tick time (anchored to `WEEKLY_TICK_HOUR_UTC` floor, NOT `now`); #29 mock receives exactly 4 `weekly_tick` signals; next normal tick scheduled at correct upcoming `WEEKLY_TICK_HOUR_UTC` (no double-fire same week).
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_weekly_tick_missed_replay.gd`
- **AC-34b** (Decision #5 — cap at MAX_WEEKLY_TICK_CATCHUP): **GIVEN** mock persistence returns `_last_weekly_tick_unix = (now - 52 × WEEKLY_TICK_INTERVAL_SECONDS)` (1 year missed), **WHEN** boot Rule 5.5 evaluates, **THEN** missed_count clamped to `MAX_WEEKLY_TICK_CATCHUP = 8`; only 8 `weekly_tick` events enqueued (not 52); `_last_weekly_tick_unix` updated to latest anchored time within the 8-tick window; emit `weekly_tick_catchup_capped(missed: int, capped_to: int)` signal so #29 can trigger returning-player ritual.
  - **Test type**: Integration | **Evidence**: `tests/integration/state-machine/test_weekly_tick_catchup_cap.gd`

## ADR-006 Escalation Boundary — RESOLVED 2026-05-25 (Pass 4)

> **Status**: ADR-006 State Machine Contract **RATIFIED 2026-05-25** (Status: Proposed) at `docs/architecture/adr-0006-state-machine-contract.md`. Pass 4 light verification 2026-05-25 surgically propagated all 15 Contracts back into GDD prose / ACs. This section is now a **historical/cross-reference index** — ADR-006 remains authoritative on the 15 items; GDD prose is no longer "provisional", it now matches ADR-006 contracts. Pass 4 verdict: NEEDS REVISION → REVISED (this pass). Re-review in fresh session optional.

### Items historically escalated to ADR-006 (each now Resolved by listed Contract — see ADR file for binding spec)

1. **Atomic transition primitive (Godot-native semantics)** → **Resolved by Contract 1** (Generational lock ID + `call_deferred` discipline). Originally 4 re-entrance vectors uncovered (Pass 3 gameplay-programmer B1-B4): synchronous `request_completed` re-entry; fallback timer cross-transition unlock; `add_child` deferred ordering for orphan HTTPRequest; forward-recovery `transition_id` regeneration. ADR-006 Contract 1 specifies: (a) generational lock id (works in single-thread WASM + future-proofs COOP/COEP threading); (b) per-transition fallback timer scoped via captured `my_gen`; (c) HTTPRequest deferred-insertion canonical pattern; (d) `request_completed` handler `call_deferred` discipline + static analyzer.

2. **`transition_id` collision-safe generation across WASM reload** → **Resolved by Contract 2** (`wall_clock_ms × 1000 + persisted_monotonic_counter`). Originally `"%d_%s_%s" % [Time.get_ticks_usec(), from, to]` reset on reload → forward-recovery generated DIFFERENT id → double-grant risk (Pass 3 systems-designer R3 + gameplay-programmer B4 corroborated). ADR-006 Contract 2 mandates: `_transition_id_counter` persisted in `user://state.json`, format `"%d_%d_%s_%s" % [wall_clock_ms, counter, from, to]`, opaque (no code path parses), AND forward-recovery MUST reuse tombstone's `transition_id` verbatim (CI-enforced).

3. **Tombstone serialization format** → **Resolved by Contract 3** (SerializableResource `to_dict()/from_dict()` envelope). Current `user://state.json` uses JSON. `JSON.stringify(Resource)` returns `{}` → BossPayload Resource embedded in `StateTransitionPayload.data["boss"]` **silently lost** on tombstone round-trip (Pass 3 godot-specialist R8 — verifiable in 30s in any Godot 4.6 project). AC-11a forward-recovery currently cannot pass under this spec. ADR-006 to mandate: switch persistence envelope to `var_to_bytes` + base64 (preserves Resource), OR define `BossPayload.to_dict() / from_dict()` for explicit JSON-serializable schema, OR store BossPayload as Dictionary throughout (drop Resource type).

4. **Autoload `_enter_tree` / `_ready` ordering (Godot 4.6 actual behavior)** → **Resolved by Contract 4** (per-autoload sequential; GDD Phase B+C rewritten same pass). Boot Sequence Phase B/C diagram **self-contradicts** at lines 386-391 (Phase B/C "batched" framing vs parenthetical "per-autoload sequential" correct model — Pass 3 godot-specialist B1). ADR-006 to replace Phase B/C framing with single phase: "per autoload in list order: `_enter_tree` → `_ready` runs to completion before next autoload added" + restate `connect_for_initial_state` rationale under correct model.

5. **`Callable.call_deferred()` signature under Godot 4.6 variadic changes** → **Resolved by Contract 5** (lambda + `process_frame.connect ONE_SHOT` preferred idiom; CI scan flags `_request_transition.call_deferred(` literal pending Q-A4 VS spike outcome). Pass 3 godot-specialist B2 flagged uncertainty post-4.5 variadic-args rewrite.

6. **Initial-state delivery typed-signal contract** → **Resolved by Contract 6** (sentinel `_initial_state_payload` with `source_event = "initial_state"`; direct `callv` not `signal.emit`; `.bind()` forbidden). Originally helper passed `null` as `payload: StateTransitionPayload` (typed Resource subscriber footgun, Pass 3 godot-specialist B3). AC-30 rewritten in this Pass 4 sync.

7. **`connect_for_initial_state` race vs real transition same boot frame** → **Resolved by Contract 7** (`_last_emit_tick` snapshot at connect; deferred lambda checks `_last_emit_tick > captured_tick` → skip stale). AC-30a NEW added in this Pass 4 sync.

8. **Knob invariant boundary math (4 violations at safe-range boundaries)** → **Resolved by Contract 8** (`_assert_knob_invariants()` runtime check at boot; safe-range corrections applied to GDD Tuning Knobs in this Pass 4 sync: `STATE_TRANSITION_FALLBACK_MS` 100..1499, `MIN_REVEAL_WINDOW_SECONDS` 11..30).

9. **Wall-clock TTL clock-drift bounded formula** → **Resolved by Contract 9** (`WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300` + monotonic fallback when drift detected). AC-22a NEW added in this Pass 4 sync.

10. **Schema migration chain bounded cost** → **Resolved by Contract 10** (`MAX_MIGRATION_CHAIN_LENGTH = 6` + `MIGRATION_BUDGET_MS = 150` per step; total ceiling 900ms). AC-27a + AC-27b NEW added in this Pass 4 sync.

11. **IndexedDB async-commit fence semantics** → **Resolved by Contract 11** (VS tier: NO fence — best-effort; telemetry hook `tombstone_write_completed(transition_id, latency_ms)` records actual rate; MVP gate upgrades to `flush + await` if > 1/10K loss rate observed). AC-33-NEW added in this Pass 4 sync. ~0.05% VS risk acceptance documented in ADR Consequences.

12. **`@no-await` static analysis transitive enforcement** → **Resolved by Contract 12** (scan-entire-file rule: `rg --glob "src/core/state_machine/**/*.gd" "\\bawait\\b"` returns empty). AC-18 rewritten in this Pass 4 sync.

13. **AC-15b interface-indirection robustness** → **Resolved by Contract 13** (formal `IInputPolicy` interface; injection-based test with `MockInputPolicy`; Pillar 2 enforcement at input-handler boundary not state-machine boundary). AC-15b rewritten in this Pass 4 sync.

14. **Mock spy hook contract canonicalisation** → **Resolved by Contract 14** (formal Test Spy Contract — `IPersistence.attach_write_spy(Callable) / attach_delete_spy(Callable) / clear_spies()`, `GameStateMachine.attach_in_memory_spy(Callable)`, `MockToastQueue / MockInventory / MockEnemyDirector / MockInputPolicy` all canonicalised). AC-04a / AC-16 / AC-21 renamed in this Pass 4 sync; `/test-helpers state_machine` skill scaffolds spy set.

15. **Cross-device `loot_reveal_pending` + `pending_since` authoritative clock** → **Resolved by Contract 15** (server-side `pending_since_server` at `POST /lootdrop/{transition_id}/cache` write; client mirror only; hard-cap eviction deferred offline). AC-19 rewritten in this Pass 4 sync; inherited by ADR-002.

### Items NOT deferred (kept in this GDD)

This GDD remains source-of-truth for:
- 9-state enum + transition matrix (Section "States and Transitions")
- Pillar enforcement rules (Rules 1, 4, 6, 7 + Rule 5.5 weekly tick replay + Rule 5 priority table)
- Decision #1 reframed (force-boot LootDrop on hard-cap, NOT silent commit)
- Decision #2 BossOutcome enum semantics
- Decision #3 RestPeriod rename + data-driven duration
- Decision #4 single-device session lock policy + 401 active-state deferral + state-mismatch immediate toast
- Decision #5 Weekly Tick Missed-Window Replay
- Event Intake Queue priority taxonomy (mechanism details may move to ADR-006)
- Formula 1 retry backoff (math + preconditions)
- All ~51 ACs (Section H count canonical — see Acceptance Criteria header for full breakdown including AC-19b fallback + AC-31a/b/c + AC-32a/b + AC-34a/b + Pass 4 ADR-006 sync additions AC-11a-extra/22a-b/27a-b/30a/33-collision-safety/33-NEW)

### Pass 4 expected scope

After ADR-006 ratified: Pass 4 (estimated ~30 min) verifies (a) GDD ACs trace cleanly to ADR-006 contracts; (b) pillar tests survive; (c) no new architectural-seam issues. Not another adversarial round.

---

## Open Questions

呢度收集設計過程中發現需要 follow-up 嘅問題。每個 question 標 owner + suggested resolution。已解決嘅項目 strikethrough 並保留以審計。

| ID | Question | Owner | Status |
|----|----------|-------|--------|
| **Q-E1** | `user://` (IndexedDB) disabled (Safari Private Mode) 時，in-memory fallback cache 對 LootDrop durability 係咪 acceptable？ | game-designer + product | OPEN — VS playtest 確認；可能需要 UI 提示「Private Mode 唔可以 carry loot 過 tab refresh」 |
| ~~Q-E2~~ | ~~Suspended → full re-boot threshold 24h 啱唔啱？~~ | systems-designer + qa-lead | DEFERRED — 待 GymSys session expiry 政策定後配對；當前 24h default 保留 |
| ~~Q-E3~~ | ~~`user://` quota exceeded 時 eviction policy?~~ | engine-programmer | RESOLVED — IndexedDB 50MB-1GB 足夠；無 eviction policy 需要。Tombstone-priority rule 喺 Edge Cases 處理 quota fail forward-recovery |
| ~~Q-E4~~ | ~~Pending LootDrop survive 上限~~ | game-designer | RESOLVED — capped at **6 days** (under Safari ITP 7-day window) + queue-reveal-on-resume 機制（AC-19）|
| **Q-E5** | Backend schema 高於 client 版本時，係咪要強制 client upgrade nag？ | live-ops-designer | OPEN — VS tier 暫定 NO；MVP 之後再決定 nag 強度 |
| ~~Q-A1~~ | ~~`STATE_TRANSITION_LOCK_TIMEOUT_MS = 100ms`~~ | gameplay-programmer | RESOLVED — Renamed to `STATE_TRANSITION_FALLBACK_MS = 1000ms`，semantics 改為 fallback unlock 而非 lock-held drop. VS 期間 instrument transition duration 確認 fallback never fires in normal path |
| ~~**Q-A2**~~ | ~~係咪需要為 state machine reserve 一個 ADR slot（state contract + transition rules）？~~ | technical-director | **RESOLVED 2026-05-25** — ADR-006: State Machine Contract RATIFIED (Status: Proposed) at `docs/architecture/adr-0006-state-machine-contract.md`. 15 contracts lock 死 atomicity primitive, transition_id collision-safety, serialization envelope, autoload ordering, knob invariants, etc. Pass 4 sync propagated 全部 15 contracts 入 GDD. |
| ~~Q-A3~~ | ~~Verify Godot 4.6 Web Export bfcache 行為（HIGH RISK）~~ | engine-programmer + VS prototype | PARTIALLY RESOLVED — bfcache restore 處理 rule 已寫入 Detailed Rules / Edge Cases（fast resume vs fallback full boot 雙 path）。VS spike 任務 narrowed to「量度 iOS Safari WASM reinit 比率」，唔再係「決定點 handle」 |
| **Q-A4** (NEW) | Godot 4.6 Web Export 有冇可能 enable COOP/COEP threading？如有 → 單線程 atomicity assumption 失效，需要 mutex | engine-programmer | OPEN — VS spike 確認 Godot 4.6 export template 嘅 thread support 預設狀態；若無 COOP/COEP headers，atomicity holds |
| ~~**Q-X1**~~ | ~~Loot reveal toast/badge 嘅 visual / interaction spec 由邊個寫？~~ | ux-designer + #21 owner | **RESOLVED 2026-05-25 via Decision #1** — toast/badge UX 已 deprecated；改為 natural-pause gated modal ritual + 30-day hard cap auto-commit "未開封" badge + inventory-tap ritual recovery. UX spec 寫入 #21 Loot Drop Modal GDD 範圍；state machine emit `state_changed → LOOT_DROP` 帶 `source_event = "deferred_reveal"` 即可 |
| **Q-X2** (partially resolved 2026-05-25) | Boss interrupt 嘅 fast-victory 收場動畫由 #14 EnemyDirector 還是 #21 Loot Drop Modal 處理？ | game-designer + #14 owner | **Payload schema locked via Decision #2**: `BossPayload {outcome, boss_id, hp_at_interrupt, hp_max}` 由 #14 populate. **動畫 ownership 仍 OPEN** — 待 #14 / #21 GDDs 寫成時 negotiate；state machine 只責任係保證 payload 入 `state_changed` |
| **Q-X3** (NEW, Decision #2) | ABANDONED outcome trigger conditions — post-MVP enemy-side timeout / explicit-quit ritual? | game-designer + #14 owner | DEFERRED to post-MVP — VS tier `ABANDONED` 從不 fire；MVP 後再 specify long-inactivity TTL / explicit-quit UX |
| **Q-X4** (NEW, Decision #4) | Re-login UX after `auth_required` signal — modal? Toast + retry button? Auto-redirect to OAuth? | ux-designer + #2 owner | OPEN — 屬於 UX spec 範圍；state machine 只 emit `auth_required()` signal + maintain `current_state == BOOTING` 直到 re-claim 成功；UI surface 由 UX spec 定 |
| ~~**Q-A5**~~ (NEW, Pass 3 ADR-006 trigger) | ~~ADR-006 State Machine Contract 應幾時起草？~~ | technical-director | **RESOLVED 2026-05-25** — ADR-006 ratified (Status: Proposed); Pass 4 light verification done; GDD sync complete. Next blocker for #3 PersistenceLayer GDD: none. |
| **Q-A6** (NEW, Pass 3 B7 / Decision #5) | `MAX_WEEKLY_TICK_CATCHUP = 8` 對長期 lapse player (e.g. 1 年不活躍) 嘅 returning-player ritual 設計 — 由 #29 Mirror Moment 用 `weekly_tick_catchup_capped` signal 處理? Specific ritual TBD | game-designer + #29 owner | OPEN — defer to #29 GDD authoring；state machine 只 emit signal + cap，#29 自行決定 ritual |

**Resolution gating**: Q-E1 必須喺 #15 Loot Drop System GDD 寫成之前解決（Pillar 3 直接依賴）。Q-A2 (ADR-006) — Pass 3 confirmed need; combined with Q-A5 as next-action ADR. Q-X2 動畫 ownership 喺 Pre-MVP tier 解決（payload schema 已 locked）。Q-X3 post-MVP。Q-X4 應喺 UX spec authoring 期間 close（VS 前）。Q-A4 喺 VS spike 期間 close（ADR-006 covers）。Q-A5 next-session ADR-006 authoring. Q-A6 喺 #29 GDD 範圍 close. Q-E5 喺 MVP 之後 batch resolve。

---

## Errata(2026-06-07 — #21 G-LM-4c 執行;source = loot-drop-modal.md Bidirectional sync flags)

1. **L128「每個 RestPeriod 只 drain ONE」** → 被 #21 Rule 6/10 supersede:intra-queue drain-all + catch-up contact-sheet(fatigue bound 由 #21 F3 caps + per-item commit + 外部 force-close 兜)。GSM 唔再 own drain cadence — LOOT_DROP occupancy 內嘅 reveal 數量係 #21/#15 嘅事。
2. **L375(b)「未開封 item tap entry trigger」→ defer v0.2**(#21 OQ-6)— 需要 #23 Inventory UI surface + 獨立 content-source 分支;MVP 30-日 hard-cap auto-commit 係極罕 fallback path,deferred-ack 已 acknowledge。L375 (a)/(c)/(d) 已由 #21 兌現(Rule 2 / Rule 13b(c) 快勝 variant / Rule 8 pre-S3 cancel)。

**Code-side 同步(2026-06-07,#21 story-019)**:`_post_transition_loot_hooks` 接線(Rule 13 L123 evaluate-after-emit + G-LM-4 ⑥ same-occupancy retry-suppression)+ `on_loot_confirmed(queue_drained)` exit chain(drained=false 即 catch-up defer — flag 保留俾下個 occupancy);RestPeriod `MIN_REVEAL_WINDOW` remaining-duration check 留 #2 transport(VS-gated)。
