# Telemetry / Analytics

> **Status**: APPROVED (degraded-inline `/design-review` 2026-06-12 — NEEDS REVISION → revise-now → APPROVED same session; 1 BLOCKING + 2 REC inline-resolved, grep-verified against shipped src/registry)
> **Author**: frank + analytics-engineer (degraded-inline) + grep-verified upstream contracts
> **Last Updated**: 2026-06-12
> **Implements Pillar**: None directly — infrastructure that *measures* whether Pillars 2/3 are working; serves the Pre-MVP PIVOT/KILL hypothesis gate
> **Creative Director Review (CD-GDD-ALIGN)**: APPROVED (degraded-inline) 2026-06-12 — 0 blocking; STRONG Pillar 1/2 structural coherence (de-id + 100% passive), serves Pillar 3 validation, zero anti-pillar violation, scope-disciplined (hypothesis-scoring deferred to backend)
> **Design Review fixes applied**: B-1 `out_of_order_signal` phantom → telemetry-derived `out_of_order_observed` (WST L378 is internal log, not subscribable signal) · R-1 `state_changed` signature → `(from, to, payload)` per GSM L578 · N-1 Formula 1 first-SET_ACTIVE edge · R-2 registry referrer (Phase 5b) · N-2 WST bfcache_resumed decl erratum (Q-T8, WST-side epic-time)

## Overview

Telemetry / Analytics 係一個**純被動觀察層(passive observer layer)**:佢 subscribe 全部 upstream gameplay 系統嘅 signal,將每個有意義嘅事件(workout 階段轉換、每一擊、每次擊殺、每件爆裝、每個系統異常)翻譯成**結構化、版本化、去識別化(de-identified)嘅 telemetry event**,buffer 喺本地,再批次 flush 去玩家自己嘅 GymSys backend。佢**唔產生任何 gameplay signal、唔 mutate 任何 game state、玩家永遠睇唔到佢**。

呢個系統存在嘅唯一理由係**回答一條 production 問題,唔係 serve 玩家**:`game-concept.md` 嘅 Pre-MVP core hypothesis ——「玩家做緊 gym set 期間眼角瞄到 auto-combat 仲會被吸引;做完一日 workout 後爆裝感覺值得做返第二日」—— 究竟係真定假?`systems-index.md` 嘅 Pre-MVP failure criterion 寫得好白:「Telemetry data after Month 4 fails to show『players glance + drop excitement』signals → **PIVOT or KILL**」。換句話講,**呢個系統就係驗證成個 project 值唔值得繼續做落去嘅量度儀器**。冇佢,Pre-MVP gate 只能靠主觀感覺去判 go/no-go;有佢,go/no-go 變成有數據支撐嘅決定。

設計上有兩條不可妥協嘅 posture:
1. **Pillar 2(無壓力陪伴)硬約束** — telemetry 100% passive。永遠唔可以彈「評分今次 session」popup、唔可以 mid-set 問問題、唔可以有任何要玩家 attention 嘅 mechanic。所有「玩家點諗」嘅 signal 都只能用**被動行為 proxy**(切換動作嘅反應快慢、session 在場時間、頁面 focus/blur),唔可以主動問。
2. **First-party-only 隱私 posture** — 呢個 game 處理玩家**真實身體數據**(訓練 volume、PR、肌群)。Telemetry data 只 flush 去玩家自己嗰個 GymSys backend(same-origin per ADR-0004),**唔接任何第三方 analytics SaaS、唔送 PII、唔送可識別嘅原始身體數據**。呢個同 game 嘅 premium / 非氪金定位、同 anti-pillar 精神一致。

> **設計 vs 實作邊界**:本 GDD 只規範**捕捉乜嘢事件、點 schema、點 aggregate、點滿足 Pre-MVP gate**(behavior level)。**點儲存 / 點傳輸 / retention 幾耐 / privacy 法規細節**(implementation level)留俾一張未寫嘅 ADR(暫稱 ADR-0012 Telemetry Data Pipeline & Privacy)。本 GDD 唔 cite 任何 telemetry ADR,因為仲未有 —— 喺 Dependencies + Open Questions 明確 flag 呢個 gap。

## Player Fantasy

**呢個系統冇 player fantasy —— 而且呢個係 by design,唔係 gap。** Telemetry 嘅成功標準恰恰係**玩家完全察覺唔到佢存在**:冇 popup、冇 loading、冇 prompt、冇延遲、冇隱私焦慮。任何「玩家感受到 telemetry」嘅情況都係 bug(違反 Pillar 2)。所以本 section 唔砌一個虛假嘅 power fantasy。

不過,跟 Foundation/infrastructure GDD 嘅慣例(#1 GSM 嘅「隱形」framing、#7 Camera 嘅「Silent Showrunner」),我哋誠實咁交代**真正嘅 stakeholder 同間接嘅玩家利益**:

- **直接 stakeholder = 開發者(你自己)**。Telemetry 服務嘅「fantasy」係一種**開發者嘅篤定感**:Month 4 Pre-MVP checkpoint 嗰一刻,你唔使靠「我覺得 OK 喎」去決定成個 project 生死,而係打開 dashboard 睇住真實數據講「玩家真係會 glance、爆裝真係驅動返第二日 → PROCEED」或者「數據唔 support hypothesis → PIVOT,而且我而家知道係邊半條 hypothesis 死咗」。**呢個系統將一個賭博式嘅 go/no-go 決定,變成一個有證據嘅決定。**

- **間接玩家利益 = 一隻配得起繼續做落去嘅 game**。因為 telemetry 驗證 hypothesis,最終 ship 出去俾玩家嘅,係一隻**真係被數據證明過有人 glance、有人為爆裝返嚟**嘅 game,而唔係一隻憑感覺做、其實冇人睇畫面嘅 game。玩家永遠唔會知道 telemetry 救過佢哋免於玩一隻 dead-on-arrival 嘅產品 —— 但佢哋享受嘅,正正係 telemetry 幫手守住嘅 product-market fit。

- **情緒錨點(對開發者)**:健身文化入面有句「if you didn't log it, it didn't happen」。Telemetry 對 Mirror Hero 嘅 production 就係呢句話 —— 你嘅 hypothesis 如果冇被 instrument 量度過,佢就等於冇被驗證過。**You can't improve what you don't measure。**

> 結論:Player Fantasy = **N/A (intentional)**。Section 保留係為咗明確記錄「冇 fantasy」係刻意決定,並交代真正服務對象。後續 reviewer 唔好當呢個 section 係未填。

## Detailed Design

### Core Rules

1. **Rule 1 — Pure observer, zero gameplay side-effect.** Telemetry 只 subscribe upstream signal。佢**永遠唔 emit gameplay signal、唔 mutate 任何 game state、唔 call 返 source system 嘅 mutating method**。佢唯一嘅「output」係本地 buffer + flush 去 backend。任何違反呢條都係 Pillar 2 / anti-fabrication 違規(CI-1 守)。

2. **Rule 2 — Handler 係 O(1)、non-blocking、allocation-light。** 每個 subscribed signal 對應一個 handler,handler 做嘅嘢只係:(a) 將 payload 翻譯成 typed `TelemetryEvent` envelope,(b) append 入 ring buffer,(c) update 相關 lossless accumulator。Handler 唔可以做 file I/O、唔可以做 network、唔可以 block frame。Flush 係另一條 async path(Rule 6)。

3. **Rule 3 — Event envelope schema(common header)。** 每個 event 都有統一 envelope:
   | Field | Type | 意義 |
   |---|---|---|
   | `event_name` | StringName | 事件類型(e.g. `&"hit_resolved"`) |
   | `schema_version` | int | per-event-name 版本號(Rule 14) |
   | `client_event_id` | int | 本地 monotonic 序號(per session,去重 + 排序) |
   | `session_id` | String | 本 session 唯一 ID(Rule 11) |
   | `client_ts_unix` | int | 事件發生時 wall-clock unix(秒) |
   | `client_ts_monotonic_ms` | int | `Time.get_ticks_msec()`(drift-immune 排序) |
   | `game_state` | StringName | 事件發生時 #1 GSM 嘅 current_state(stamp,Rule 13) |
   | `payload` | Dictionary | event-specific,**已 de-identify**(Rule 4) |

4. **Rule 4 — De-identification(隱私 + Pillar 1)。** Payload **永遠唔載原始身體數據**:冇絕對重量(kg)、冇絕對 1RM、冇體重。需要 magnitude 時,只存**已正規化 / 已分桶(bucketed)**嘅形式 —— 例如 `pr_magnitude`(已係 [0, 2.0] normalized)、rarity tier(enum string)、workout volume(用 `completed_exercises_count` 動作數,唔係 kg)。理由:telemetry 對 product hypothesis 嘅問題係「玩家有冇 glance / 爆裝爽唔爽」,從來唔需要知道玩家舉幾多公斤。CI-2 守 forbidden-field denylist。

5. **Rule 5 — Ring buffer + 三層 priority。** Event 入一個 capped ring buffer。每個 event 有 priority:
   - **CRITICAL** — 系統完整性 / 異常:**upstream-subscribed** 異常 —— `combat_metric_anomaly`(#14)+ loot 異常族(`loot_ceremony_capped` / `loot_zero_workout_floor_applied` / `loot_rarity_mismatch` / `loot_drop_unbound`,#15);**telemetry-derived** meta —— `duplicate_transition_observed`(EC-03)、`out_of_order_observed`(telemetry 自身用 `client_ts_monotonic_ms` 檢測 incoming event 亂序,**非 upstream signal**;⚠️ 注意 WST L378 嘅 `wst.out_of_order_signal` 係 WST **內部 log call**,唔係可 subscribe 嘅 signal,故 telemetry 自行檢測)、`telemetry.buffer.dropped_count`、`telemetry_self_error`。**永不 sample、永不 drop**(有 reserved sub-buffer,Rule 7)。
   - **STANDARD** — gameplay 事件:`enemy_killed`、`loot_dropped`、`workout_*`、`phase_changed`、`bfcache_resumed`、glance/euphoria proxy 事件。
   - **LOW** — 高頻可抽樣:`hit_resolved`(一秒可以好多次)。受 Rule 8 sampling。

6. **Rule 6 — Flush model(async batch)。** Flush 觸發條件(任一):(a) buffer STANDARD/LOW 區達 `flush_batch_size`;(b) `flush_interval_seconds` timer 到;(c) `workout_completed_forwarded`(天然 session 邊界 —— 最重要嘅 flush point);(d) page-hide / app-suspend(best-effort beacon flush,Rule 12)。Flush = 將 buffered events 批次 serialize → POST 去 GymSys backend telemetry endpoint(same-origin per ADR-0004)。成功 ACK 後先從 buffer 移除(at-least-once delivery;backend 用 `session_id + client_event_id` 去重)。**Flush 失敗 → events 留喺 buffer,exponential backoff 重試,唔阻 gameplay。**

7. **Rule 7 — Buffer overflow policy(CRITICAL 不滅)。** 若 buffer 滿(offline / backend down 長時間):STANDARD/LOW 區**drop 最舊嘅 LOW,再 drop 最舊嘅 STANDARD**;CRITICAL 有獨立 reserved 容量,**永不被 evict**。每次 drop 累加 `telemetry.buffer.dropped_count`(本身係 CRITICAL meta-event,確保「我哋有掉嘢」呢個事實唔會靜靜失傳)。若連 CRITICAL reserved 都滿 → emergency 寫 `user://` 本地 spool(若 PersistenceLayer 報 non-private)。

8. **Rule 8 — Sampling with lossless aggregate(高頻事件)。** LOW-priority 高頻事件(`hit_resolved`)按 `hit_sample_rate` 抽樣:只有抽中嘅**個別** event 入 buffer。但**無論抽唔抽中,lossless accumulator 一定 update**(`total_hits`、`total_damage_dealt`、`crit_count`、per-`damage_tier` count)。Accumulator 喺 flush / workout boundary 以 `combat_aggregate` event 形式整批送出。**個別抽樣係為咗控 volume,但 aggregate truth 永不失準。**

9. **Rule 9 — Glance-proxy capture(hypothesis 上半:「玩家會 glance」)。** 直接量度注意力做唔到(冇 eye tracking —— 違反隱私 + Pillar 2),所以只用**被動行為 proxy**:
   - **Exercise-switch latency** — 由 `phase_changed(REST_PERIOD → SET_ACTIVE)` / 或 `dominant_class_changed` 計「玩家幾快揀下一個動作」。快切換 = 投入嘅 proxy。
   - **Page-visibility transitions** — 透過 platform_detect 嘅 Page Visibility API hook,record workout 期間 tab focus/blur 次數同 foreground 時長。玩家成個 set 都 keep 住 tab visible vs 完全 background = glance intent 嘅 proxy。
   - **Session foreground-time ratio** — foreground 秒數 / session 總秒數。
   呢三個 proxy 餵 hypothesis 上半。**全部 100% passive,冇任何一個要玩家主動做嘢。**

10. **Rule 10 — Drop-euphoria-proxy capture(hypothesis 下半:「爆裝值得返第二日」)。** 捕捉:
    - **Drop rarity distribution** — 每件 `loot_dropped` 嘅 `rarity_tier`(已 de-identified enum)。
    - **Return-after-drop context** — 每次 session-open 嘅 meta-event 帶上 `last_session_max_rarity` context stamp;真正嘅「高稀有度 → 翌日返嚟」相關性留俾 backend 喺 analysis time 計(telemetry 只負責 stamp,唔做跨 session 推斷,保持 client 簡單)。
    - **Screenshot intent(forward hook)** — 若 #21 Loot Drop Modal / #29 Mirror Moment 將來 expose screenshot-button-press signal,telemetry record 之做 euphoria 強 proxy。MVP 可能未有此 signal → 標 forward hook,唔 block。

11. **Rule 11 — Session lifecycle。** Telemetry 喺 game boot(或 GymSys session claim per ADR-0002)開一個新 `session_id`,emit `session_started` meta-event(帶 platform / is_mobile / app_version / last_session_max_rarity context)。Session 結束(workout_completed 後 idle 超時 / page unload)emit `session_ended`(帶 foreground_ratio / total events)。全部 event 都 stamp 同一個 `session_id`。

12. **Rule 12 — Page-hide best-effort beacon(Web 特性)。** Web Export 嘅 tab 隨時被 browser 殺(mobile Safari 尤甚)。當 platform_detect 報 `visibilitychange → hidden` 或 `pagehide`,telemetry 即刻做一次 **best-effort 同步 flush**(用 `navigator.sendBeacon` 等 fire-and-forget 機制,經 platform_detect seam)。呢個係「臨死前最後一送」,確保 session-end 數據唔會因為冇得 graceful shutdown 而成批失傳。

13. **Rule 13 — Order-resilient late boot(ADR-0008 binding)。** Telemetry **boots LAST**(ADR-0008 §insertion rule,reserved 「Last」)。Subscribe 時用 `connect_for_initial_state`(ADR-0006 Contract 6)back-fill #1 GSM 嘅 current_state,令 `game_state` stamp 由第一個 event 起就準確。**Combat / loot signal 全部係 runtime(CombatActive / boss-kill)先 emit,遠喺所有 autoload boot 之後**,所以 late boot 一定 catch 到 —— 呢個正正 supersede 咗 #14 EnemyDirector L593 嘅 stale provisional claim「#28 must boot BEFORE #14」(見 Dependencies §Cross-system conflict + Open Questions Q-T1)。

14. **Rule 14 — Frozen schema + version-on-change(#15 FR-LOOT-3 binding)。** `loot_dropped` event 必須跟 frozen `loot_dropped_v1` schema 序列化(欄位集 = `drop_id, rarity_tier, item_type, transition_id` per #15 signal contract)。**任何 schema 改動 = 新版本號(`_v2`),永不 in-place 改欄位**,確保 backend 歷史數據可解析。CI-3 enforce frozen field set per event_name。

15. **Rule 15 — Recursion guard + self-error isolation(#13 EC-49 binding,28-recursion-guard)。** Telemetry 自身嘅 internal error(serialize 失敗 / flush 失敗 / buffer 異常)**只記去獨立 diagnostic channel**(`push_warning` + 本地 `telemetry_self_error` LOW meta-event),**永不 re-emit 做 gameplay `combat_metric_anomaly`**(否則 telemetry 處理 anomaly 時自己出錯 → 再 emit anomaly → 無限遞迴)。Handler 必須 re-entrancy-safe:一個 handler 直接或間接都唔可以令另一個被追蹤 signal 再 fire。

### States and Transitions

Telemetry 係一個輕量 5-state FSM(autoload，state 純內部,唔 expose 俾 gameplay):

| State | 意義 | 進入條件 | 可去 State |
|---|---|---|---|
| **BOOTING** | `_ready` 起,subscribe upstream + `connect_for_initial_state` back-fill | autoload `_ready`(Last position) | → ACTIVE(subscribe 完成) |
| **ACTIVE** | 正常捕捉 + 累積 + 定時 flush | BOOTING 完 / FLUSHING ACK / SUSPENDED resume | → FLUSHING / SUSPENDED / DEGRADED |
| **FLUSHING** | 一批 events 正在 POST 去 backend | Rule 6 任一 flush trigger | → ACTIVE(ACK 成功,清 buffer)/ ACTIVE(失敗,留 buffer + backoff) |
| **SUSPENDED** | page hidden / app suspend,已做 beacon flush,暫停 timer | platform_detect `visibilitychange→hidden` / `pagehide` | → ACTIVE(resume / `visibilitychange→visible`) |
| **DEGRADED** | private-mode 或 telemetry disabled:in-memory best-effort,唔寫 `user://` spool | PersistenceLayer 報 `private_mode_detected` / master switch off | → ACTIVE(private mode 解除,罕見) |

**Transition 註記**:
- BOOTING → ACTIVE 係唯一 boot path;subscribe 全部 upstream + back-fill GSM state 後即轉。
- FLUSHING 失敗**唔轉去 error state** —— 留 ACTIVE,buffer 保留,`retry_delay` exponential backoff(復用 registry `retry_delay` formula 概念,見 Tuning Knobs)。Telemetry **永不因為 backend 死而影響 gameplay**。
- SUSPENDED 入場必先做一次 best-effort beacon flush(Rule 12)。
- DEGRADED 唔代表停止捕捉,只代表唔做本地持久化 spool —— in-memory buffer 仍運作,有得 flush 就 flush(尊重 #15 Private Mode 同款 posture)。

### Interactions with Other Systems

| 系統 | 方向 | 介面(grep-verified) | 用途 |
|---|---|---|---|
| **#9 Workout State Tracker** | #9 → #28(subscribe) | `workout_started_forwarded()` / `workout_completed_forwarded(completed_at:int, transition_id:int)` / `workout_summary_available(WorkoutSummaryRO)` / `set_progress_changed(float)` / `dominant_class_changed(AbilityClass)` / `phase_changed(from,to)` / **`bfcache_resumed(was_mid_workout:bool, restored_phase)`(WST L399 明寫「for #28 telemetry」)** | workout lifecycle 事件 + glance-proxy 計時源(`phase_changed` REST_PERIOD→SET_ACTIVE)+ bfcache 復原審計 |
| **#13 CombatResolver / #14 EnemyDirector** | #14 → #28(subscribe) | `hit_resolved(HitResolvedPayload)` / `enemy_killed(EnemyKilledPayload)` / `combat_metric_anomaly(CombatAnomalyPayload)`(3 個 signal,#13 owns 定義、#14 emit) | combat 事件(LOW sampled + lossless aggregate)+ **silent-fail backstop**:anomaly critical channel(#14 Rule 17 已 upstream rate-limit 10/sec/reason + aggregate;#28 = FR-5 終端 sink) |
| **#15 LootDrop System** | #15 → #28(subscribe) | `loot_dropped(drop_id, rarity_tier, item_type, transition_id)` per **frozen `loot_dropped_v1`** + telemetry-only:`loot_ceremony_capped(workout_id, capped_kill_count)` / `loot_zero_workout_floor_applied` / `loot_rarity_mismatch` / `loot_drop_unbound(transition_id, reason)` / `loot_pending_recovered`(ADR-0003 durability 驗證) | drop-euphoria proxy(rarity distribution)+ loot 完整性審計 |
| **#1 GameStateMachine** | #1 → #28(subscribe) | `state_changed(from_state, to_state, payload: StateTransitionPayload)`(transition_id 在 payload 內,per GSM L578)+ `connect_for_initial_state`(Contract 6)back-fill `current_state` | `game_state` envelope stamp(Rule 3)+ glance state context + boot order-resilience |
| **GymSys backend(transport)** | #28 → backend(POST) | `POST /api/game/telemetry`(batch);same-origin per ADR-0004 | flush 目的地 —— **first-party-only,無第三方 SaaS**。具體 endpoint / auth / retention 由未寫 ADR-0012 定 |
| **#3 PersistenceLayer** | #3 → #28(read) | `private_mode_detected: bool`(read);可選 `user://` spool 做 offline buffer durability | DEGRADED gate(Rule 7 emergency spool / Rule 15 disable posture) |
| **platform_detect autoload** | read | Page Visibility API hook(`visibilitychange` / `pagehide`)+ `is_mobile_web` + `navigator.sendBeacon` seam(raw JS 經 platform_detect,per ADR-001 forbidden-pattern) | glance-proxy(Rule 9)+ beacon flush(Rule 12) |
| **#33 Attention Budget(可選)** | #33 → #28(subscribe,若 expose) | attention-budget gate 事件(若有) | 觀察 input-permission policy 實際行為(forward hook,唔 block MVP) |

**介面所有權**:全部係**單向 #X → #28 consume**。Telemetry 對任何 gameplay 系統都係**零 downstream**(ADR-0008 確認 pure observer)。唯一嘅外向 I/O 係 flush 去自己嘅 backend。

## Formulas

> **範圍註記**:Telemetry client 只做**per-event 嘅 derivation 同 sampling/aggregation 不變量**。真正嘅「glance score / euphoria score / retention 相關性」係 **analysis-time computation,喺 backend / dashboard 上做**(用 telemetry 送出嘅 raw + bucketed 數據),**唔屬於本 client GDD**。呢個界線避免 client scope creep,亦令 hypothesis scoring 公式可以喺唔改 client 嘅情況下迭代。

### Formula 1 — exercise_switch_latency(glance proxy 核心)

量度「玩家由 rest 入 active 之間幾快揀下一個動作」—— 切換越快 = 越投入嘅 proxy。

`switch_latency_ms = ts_set_active_entry − ts_rest_period_entry`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `ts_rest_period_entry` | t_r | int (ms) | [0, ∞) | `phase_changed(_, REST_PERIOD)` 時嘅 `client_ts_monotonic_ms` |
| `ts_set_active_entry` | t_a | int (ms) | [0, ∞) | 下一個 `phase_changed(_, SET_ACTIVE)` 時嘅 `client_ts_monotonic_ms` |

**Output Range:** [0, ∞) ms;送出前分桶(`SWITCH_LATENCY_BUCKETS_MS`,見 Tuning Knobs)成 `{<5s, 5–15s, 15–60s, 60–180s, >180s}`,**只送 bucket index 唔送原值**(de-identify + 防止反推 rest 時長洩漏訓練細節)。
**Example:** rest 入場 t_r=120000ms,12 秒後揀到下一動作 SET_ACTIVE t_a=132000ms → latency=12000ms → bucket `5–15s`。
**Edge:** (a) 若 REST_PERIOD 直接去 WORKOUT_COMPLETE(最後一組,冇下一個 SET_ACTIVE)→ 唔產生 latency event(EC-04)。(b) 首個 SET_ACTIVE(`WARM_UP→SET_ACTIVE`,冇前置 REST_PERIOD)→ 冇 `t_r` anchor,唔產生 latency event;latency **只喺自上次 reset 後有記錄過 REST_PERIOD entry 時計**。

### Formula 2 — foreground_time_ratio(glance proxy:在場專注度)

`foreground_ratio = foreground_ms / max(session_duration_ms, 1)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `foreground_ms` | f | int (ms) | [0, session_duration_ms] | tab visible 累積時長(platform_detect visibility hook 累加) |
| `session_duration_ms` | d | int (ms) | [1, ∞) | session_started 到計算時刻嘅 monotonic 時長 |

**Output Range:** [0.0, 1.0]。`max(..,1)` 防 div-by-zero(boot 瞬間 d 可為 0)。
**Example:** session 跑咗 1,800,000ms(30 分鐘 workout),tab visible 累積 1,260,000ms → ratio=0.70 → 玩家七成時間 keep 住畫面 visible,glance hypothesis 上半正向 signal。
**Edge:** ratio 接近 0(成個 session 都 background)= glance hypothesis 警號;ratio 接近 1 = 強正向。送 raw float(已係正規化,非身體數據)。

### Formula 3 — hit_sample_keep(高頻 sampling 決策,deterministic)

決定一個 `hit_resolved` 嘅**個別** event 入唔入 buffer(aggregate 永遠唔受影響,見 Formula 4)。

`keep_individual = (hits_seen mod HIT_SAMPLE_STRIDE == 0)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `hits_seen` | h | int | [0, ∞) | 本 session 至今收到嘅 `hit_resolved` 總數(monotonic,sample 前已 +1) |
| `HIT_SAMPLE_STRIDE` | s | int | [1, 100] knob,default 10 | 每 s 個 hit 保留 1 個個別 event;s=1 = 全保留 |

**Output Range:** {false, true} boolean。
**Example:** stride=10 → 第 10/20/30… 個 hit 保留個別 event,其餘 9/10 只入 aggregate。Volume 降 90% 但 aggregate truth 不變。
**Edge:** `is_crit == true` 或 `damage_tier == CRITICAL` 嘅 hit **強制 keep**(override sampling)—— crit 係 Pillar 3 sensation 嘅關鍵 signal,唔可以抽走(AC-06)。

### Formula 4 — combat_aggregate accumulation(lossless 不變量)

Sampling 之下仍保證 aggregate 真確。**無論 Formula 3 keep 與否,以下 accumulator 每個 `hit_resolved` 都無條件 update:**

```
total_hits        += 1
total_damage      += payload.damage_dealt          # 已 clamp 整數,非身體數據
crit_count        += 1 if payload.is_crit else 0
tier_count[tier]  += 1                              # per damage_tier 直方圖
```

**Variables:**
| Variable | Type | Range | Description |
|---|---|---|---|
| `total_hits` | int | [0, ∞) | 本 session 累積 hit 數(lossless) |
| `total_damage` | int | [0, ∞) | 累積 `damage_dealt`(in-game 傷害值,非身體數據) |
| `crit_count` | int | [0, total_hits] | 累積 crit 數 |
| `tier_count` | Dictionary[StringName,int] | 每 tier ≥ 0 | per `damage_tier` 計數 |

**不變量(AC-07,binding):** 對任一 session,送出嘅 `combat_aggregate.total_hits` == 該 session 實際收到嘅 `hit_resolved` signal 總數,**與 `HIT_SAMPLE_STRIDE` 無關**。即:`sum(individual hit events kept) ≤ total_hits`,但 `total_hits` 永遠係真值。
**Output:** `combat_aggregate` event 喺每次 flush / `workout_completed` 邊界整批送出後 reset per session 視窗(或 cumulative,由 backend 去重)。

### Formula 5 — flush 失敗 backoff delay(cross-reference,非本 GDD 新定義)

Flush 失敗重試延遲**復用 registry 既有 `retry_delay` formula 嘅指數退避概念**(`min(BASE × 2^(n−1), CAP)`,source = `game-state-machine.md`),用 telemetry 自己嘅 knob `TELEMETRY_FLUSH_BASE_DELAY` / `TELEMETRY_FLUSH_RETRY_CAP`(見 Tuning Knobs)。**唔喺 registry 新增 formula entry** —— 只係同款數學形狀嘅本地應用。理由:避免重複定義同一條退避曲線,registry `retry_delay` 已係 source of truth。

## Edge Cases

- **EC-01 [Buffer | HIGH] — 若 backend 成個 session 都 down/offline**:buffer 填滿 → Rule 7 先 evict 最舊 LOW、再 STANDARD,**CRITICAL reserved 區不滅**;每 drop 累加 `telemetry.buffer.dropped_count`(CRITICAL meta)。重連後 flush 自動恢復。**Gameplay 完全唔受影響**(telemetry 永不 block frame)。

- **EC-02 [Web | HIGH] — 若 tab 被 browser 突殺(mobile Safari)未及 beacon**:Rule 6(c) 每次 `workout_completed` 已 flush + Rule 11 session 邊界 flush,令 in-flight 損失局限於最後一個未 flush 嘅 STANDARD/LOW 批次。At-least-once + backend `session_id+client_event_id` 去重保證重連後唔會重複計。**接受最後一批 best-effort 損失** —— 呢個係 Web 平台固有限制,唔當 bug。

- **EC-03 [Idempotency | MEDIUM] — 若同一 `transition_id` 嘅同名 event 重複到達(GSM tombstone race / #15 duplicate emit)**:telemetry **如實記錄兩個 event**(各有獨立 `client_event_id`),**唔靜靜 suppress**(faithful observer);但若喺 `dup_window_ms` 內見到同 `event_name + transition_id` → 額外 emit 一個 `duplicate_transition_observed`(CRITICAL,審計用)。判定真假重複留俾 backend。理由:telemetry 嘅職責係忠實記錄佢見到乜,唔係修正 upstream。

- **EC-04 [Glance | LOW] — 若 REST_PERIOD 直接轉 WORKOUT_COMPLETE(最後一組,冇下一個 SET_ACTIVE)**:Formula 1 唔產生 `switch_latency` event(冇「下一個動作」可計)。唔當缺失,係正常終局。

- **EC-05 [Critical | MEDIUM] — 若 `combat_metric_anomaly` 洪水(縱使 #14 Rule 17 已 upstream rate-limit 10/sec/reason + aggregate)填爆 CRITICAL reserved 區**:觸發 Rule 7 emergency 寫 `user://` 本地 spool(若 non-private);**仍然永不靜靜 drop CRITICAL** —— spool 失敗先至 drop,且 drop 計入 `dropped_count`。理由:anomaly 係 anti-fabrication / cheat-detection 命脈(#13 Pillar 1 binding),寧願落地都唔好無聲消失。

- **EC-06 [Self-error | HIGH] — 若 telemetry 自身 serialize 某 event 失敗**:Rule 15 —— 記去獨立 diagnostic channel(`push_warning` + 本地 `telemetry_self_error` LOW meta),**drop 嗰個單一 event,唔 crash,唔 re-emit `combat_metric_anomaly`**(防遞迴)。其餘 events 照常。

- **EC-07 [Clock | MEDIUM] — 若 session 中途 wall-clock 跳變(NTP 校正 / DST / 手動改鐘)**:event 排序**一律用 `client_ts_monotonic_ms`**(drift-immune,同 ADR-0006 Contract 9 posture);`client_ts_unix` 只作絕對 stamp 保留(可能跳)。Backend 用 monotonic + session_id 重建順序。

- **EC-08 [Privacy | MEDIUM] — 若 session 中途 private mode 出現(原 non-private,IndexedDB 變 unavailable)**:轉 DEGRADED;停 `user://` spool;in-memory buffer 繼續,有得 flush 就 flush。同 #15 Private Mode posture 一致。

- **EC-09 [Bfcache | MEDIUM] — 若收到 `bfcache_resumed(was_mid_workout=true)`**:record `bfcache_resumed` event(STANDARD)。**Session 連續性**:若距上次活動 ≤ `session_resume_ttl_seconds` → **保留同一 `session_id`**(視為延續);超 TTL → 開新 session_id + `session_started(resumed_from_bfcache=true)`。理由:bfcache 係同一次遊玩嘅延續,唔應斬斷 session 統計。

- **EC-10 [Boot | LOW] — 若 boot 時 `connect_for_initial_state` 回 sentinel(GSM 未就緒 —— 理論上唔會,因 #28 排 Last)**:log `telemetry_boot_state_unavailable`(LOW),首批 event `game_state` stamp 用 `&"UNKNOWN"`,直到收到第一個 `state_changed`。**唔 fabricate state**(Pillar 1)。

- **EC-11 [Suspend | LOW] — 若 SUSPENDED 期間仍收到 gameplay signal(page hidden 但 combat 竟 tick)**:仍然 buffer(唔丟),如實記錄。理由:寧願多記都唔好漏記;異常 tick-while-hidden 本身就係值得分析嘅 signal。

- **EC-12 [Flush | LOW] — 若 flush ACK 遲到,嗰批 event 已因 overflow 被 evict**:按 `client_event_id` 移除,搵唔到嘅 id no-op。Backend 去重保證唔會雙計。無 corruption。

- **EC-13 [Cold-join | MEDIUM] — 若收到 `workout_completed_forwarded` 但本 session 從未見過 `workout_started_forwarded`(bfcache 中途 cold join)**:如實 record completion,帶 `had_observed_start=false` flag,**唔 fabricate 一個 start event**。Backend 知道呢個 session 係中途接手。

- **EC-14 [Loot | LOW] — 若收到 `loot_drop_unbound(reason="no_active_workout")`**:如實 record 做審計 event(STANDARD)。呢個係 #15 已知合法 path(gym 之外打 debug boss),**唔當 error**,但對「drop 喺非 workout context 發生幾頻繁」係有用 signal。

- **EC-15 [Soak | LOW] — 若 session 極長(soak,數小時)**:monotonic 計數器用 int64 安全;buffer cap + 定時 flush 防 memory 增長(對應 512MB browser ceiling)。`session_duration_ms` 大但無溢出風險。

- **EC-16 [Schema | MEDIUM] — 若有人改 `loot_dropped` payload 欄位但冇 bump version**:CI-3 build-time 偵測(frozen `loot_dropped_v1` field set 比對)→ build fail。Runtime telemetry 永遠只寫 frozen field set,多出欄位唔會被序列化。

- **EC-17 [Opt-out | HIGH] — 若 master `telemetry_enabled = false`(玩家 opt-out)**:**完全唔 flush,唔送任何嘢出 device**;capture 降到只保留 in-memory CRITICAL 做本地 crash 診斷(永不離開 device)。尊重隱私 opt-out 高於數據收集。Default = enabled(first-party,premium single-player)。

- **EC-18 [Beacon | LOW] — 若 `navigator.sendBeacon` 喺目標 browser unavailable**:platform_detect fallback 去 pagehide 上嘅同步 best-effort XHR;再失敗就接受損失(beacon 本質係 best-effort)。Desktop primary path 通常有 sendBeacon。

## Dependencies

### Upstream(telemetry 消費 / 讀取)

| 系統 | 硬/軟 | 狀態 | 介面 | 缺咗會點 |
|---|---|---|---|---|
| **#9 Workout State Tracker** | Hard | Approved 2026-05-27 | 7 個 workout signal(見 Interactions);**`bfcache_resumed` WST L399 明寫「for #28」** | 冇 workout lifecycle = 冇 session 分段、冇 glance switch-latency 計時源 → hypothesis 上半量度不能 |
| **#13 CombatResolver** | Hard | Approved 2026-05-27 | 定義 `hit_resolved` / `enemy_killed` / `combat_metric_anomaly` 三個 payload type | 冇 payload schema = 唔知點解析 combat event |
| **#14 EnemyDirector** | Hard | Approved 2026-05-27 | **emit** 上述 3 signal(#13 owns 定義、#14 emit) | 冇 emitter = 收唔到 combat event + 收唔到 anomaly silent-fail backstop |
| **#15 LootDrop System** | Hard | Approved 2026-05-28 | `loot_dropped`(frozen `loot_dropped_v1`)+ 5 個 telemetry-only loot 審計 signal | 冇 loot event = drop-euphoria proxy 不能 → hypothesis 下半量度不能 |
| **#1 GameStateMachine** | Hard | Approved 2026-05-25 | `state_changed` + `connect_for_initial_state`(Contract 6)+ `current_state` | 冇 state stamp = event 缺 context;冇 back-fill = late-boot 首批 event state 不準 |
| **platform_detect**(autoload) | Hard(for glance/beacon) | 已存在(ADR-001 JS seam owner) | Page Visibility API hook + `is_mobile_web` + `navigator.sendBeacon` seam | 冇 visibility hook = foreground_ratio + tab focus/blur glance proxy 不能;冇 beacon = page-hide 損失大 |
| **GymSys backend(transport)** | Hard | **ADR-0012 Accepted (contract) 2026-06-12 ✅** | `POST /api/game/telemetry`(header-auth batch)+ `/api/game/telemetry/beacon`(token-in-body),same-origin per ADR-0004;table `game_telemetry` `UNIQUE(session_id, client_event_id)` | 冇 flush 目的地 = 數據出唔到 device;**endpoint/auth/dedup/retention 已由 ADR-0012 定**(empirical 留 VS-tier) |
| **#3 PersistenceLayer** | Soft | Approved 2026-05-26 | `private_mode_detected` read + 可選 `user://` spool | 冇 = 失去 DEGRADED gate + offline durability spool,但 in-memory 仍可運作 |
| **#33 Attention Budget** | Soft(forward hook) | Merged(#18 epic) | 若 expose attention-gate 事件則 subscribe | MVP 唔 block;純 forward-hook 觀察 input-permission policy |

### Bidirectional 一致性 ✅
本系統嘅 upstream 全部已經喺**佢哋自己嘅 GDD 入面** list 咗 #28 做 downstream consumer(grep-verified):#9 WST L399、#13 CombatResolver L10/L216、#14 EnemyDirector L593、#15 LootDrop L301/L911 + FR-LOOT-3。**雙向依賴已成立**,本 GDD 唔引入任何「單向幻影」依賴。

### ⚠️ Cross-system 衝突(設計時解決,epic-time 回填 erratum)
**#14 EnemyDirector L593** 寫:「#28 must boot **BEFORE** #14(per #13 EC-50 + Rule 9)」—— 理由係驚 telemetry listener 未 connect 時 #14 emit → signal silent drop。
**ADR-0008 §insertion rule(canonical autoload map,L129)** 寫:「#28 Telemetry → **Last** — boots after all producers,`connect_for_initial_state` back-fill late-join」。

**判定 = ADR-0008 prevails(#28 排 Last)。** 理由(grep-verified):
1. ADR-0008 就係為咗收編呢類散落各 GDD 嘅 boot-order claim 而設嘅**單一 ground-truth**(GAP-002 close);個別 GDD 嘅 boot claim 服從 canonical map。
2. #14 嘅 combat signal(`hit_resolved`/`enemy_killed`/`combat_metric_anomaly`)係**runtime emit**(只喺 CombatActive / boss-kill 嗰陣),遠喺所有 autoload `_ready()` 完成之後。#28 縱使 boot Last,到真正開打嗰刻**一定已 subscribe 妥當** → catch 到全部 combat signal,**唔存在 silent drop**。
3. #14 L593 嘅「BEFORE」係 **ADR-0008 出現之前嘅 stale provisional claim**(嗰時冇 canonical map)。

**Action**:#14 L593 標記 **erratum**(將「#28 must boot BEFORE #14」改為「#28 boots Last per ADR-0008;combat signals are runtime so late-boot catches all」)—— 屬跨 file edit,epic-time 處理,記入 Open Questions Q-T1。**Recursion guard([[28-recursion-guard]],#13 EC-49)係另一條獨立、仍然有效嘅約束,本 GDD Rule 15 已 honour。**

### Governing ADRs

| ADR | 狀態 | 對本 GDD 嘅約束 |
|---|---|---|
| **ADR-0008 Autoload Position Map** | Accepted | #28 boots **Last**(reserved insertion rule);`connect_for_initial_state` order-resilience |
| **ADR-0006 State Machine Contract** | Accepted | Contract 6 `connect_for_initial_state`(boot back-fill);Contract 9 drift-tolerant monotonic timing(EC-07) |
| **ADR-0004 CORS / Cross-Origin Topology** | Accepted | flush 走 same-origin `/api/game/telemetry`,relative URL,無第三方 |
| **ADR-0003 Save State Strategy** | Accepted | `user://` spool only;**localStorage FORBIDDEN**;private-mode gate posture |
| **ADR-0002 GymSys Integration Protocol** | Accepted | `session_id` source(session claim);transport baseline |
| **ADR-0012 Telemetry Data Pipeline & Privacy** | **Accepted (contract) 2026-06-12 ✅** | endpoint pair(`POST /api/game/telemetry` header-auth + `/api/game/telemetry/beacon` token-in-body)/ dedicated 第 5 HTTP channel(隔離於 #2 4-channel pool)/ `UNIQUE(session_id, client_event_id)` dedup / retention 180d / opt-out 兩層 / de-id backend reject。**本 GDD 描述 WHAT/WHY,ADR-0012 描述 HOW**。Q-T2/T3/T6/T7 全 RESOLVED。empirical transport 留 VS-tier-gated |

## Tuning Knobs

全部 data-driven(`TelemetryConfig.tres`),冇 hardcode。

| Knob | Default | Safe Range | 過低後果 | 過高後果 |
|---|---|---|---|---|
| `TELEMETRY_BUFFER_MAX` | 2000 events | [500, 10000] | load 下提早 overflow,丟 STANDARD/LOW | 食 browser memory(512MB ceiling 風險) |
| `TELEMETRY_CRITICAL_RESERVED` | 256 events | [64, 1024] | anomaly 洪水時 CRITICAL 都 overflow → emergency spool | 偷 STANDARD/LOW 容量 |
| `flush_batch_size` | 100 events | [20, 500] | network 太頻(chatty) | payload 大、flush latency 高、crash 損失批次大 |
| `flush_interval_seconds` | 30.0 s | [10.0, 120.0] | network chatter | crash 時未 flush 損失窗口大 |
| `HIT_SAMPLE_STRIDE` | 10 | [1, 100] | volume 高(s=1 全保留個別 hit) | 個別 hit event 稀疏(**aggregate 仍 lossless**,Formula 4) |
| `SWITCH_LATENCY_BUCKETS_MS` | [5000, 15000, 60000, 180000] | 升序 4 邊界 | bucket 太密 = 低訊噪 | bucket 太疏 = glance 直方圖失解析度 |
| `session_resume_ttl_seconds` | 1800 s (30 min) | [300, 7200] | bfcache 太易斬 session(過度分段) | 跨長空檔仍算同一 session(統計失真) |
| `dup_window_ms` | 1000 ms | [100, 5000] | 漏報真重複 | 誤報正常間隔事件為重複 |
| `foreground_sample_interval_ms` | 1000 ms | [250, 5000] | visibility poll 太頻食 CPU | foreground_ms 解析度粗 |
| `TELEMETRY_FLUSH_BASE_DELAY` | 2.0 s | [1.0, 5.0] | 失敗後 retry 太密轟 backend | 首次 retry 太慢 |
| `TELEMETRY_FLUSH_RETRY_CAP` | 60.0 s | [16.0, 300.0] | backoff 封頂太低,持續轟 down backend | 復原後 flush 恢復太慢 |
| `telemetry_enabled` | true | {true, false} | —(opt-out master switch,EC-17) | — |

### Cross-knob invariants
- **INV-T1**:`TELEMETRY_CRITICAL_RESERVED < TELEMETRY_BUFFER_MAX`(reserved 係總 buffer 嘅子集;違反 = CRITICAL 區大過總容量,荒謬)。
- **INV-T2**:`flush_batch_size ≤ TELEMETRY_BUFFER_MAX`(一 batch 唔可以多過成個 buffer)。
- **INV-T3**:`SWITCH_LATENCY_BUCKETS_MS` 必須嚴格升序(Formula 1 分桶前提;EC binding)。
- **INV-T4**:`TELEMETRY_FLUSH_BASE_DELAY ≤ TELEMETRY_FLUSH_RETRY_CAP`(退避起點唔可高過封頂)。

### Referenced(別系統 own,本 GDD 只讀)
- `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS`(PersistenceLayer own;EC-07 monotonic 排序 posture 對齊概念)
- `retry_delay` formula 形狀(GSM own;Formula 5 復用)
- platform_detect `is_mobile_web`(影響 buffer/sample 是否套 mobile-conservative profile —— 可選,未 MVP-block)

## Visual/Audio Requirements

**N/A(intentional)。** Telemetry 對玩家**零視覺、零音效**。佢嘅成功定義就係玩家察覺唔到佢存在(Pillar 2)。任何 telemetry 引致嘅 visual/audio artifact(loading、popup、indicator、音效)都係違規。

唯一可能嘅視覺面係**開發者專用 debug overlay**(buffer 佔用 / flush 狀態 / event 計數)—— 但呢個係 dev-only tooling,**唔係 player-facing 需求**,屬 `tools-programmer` 範疇,唔喺本 GDD scope,亦唔觸發 art-director 介入。

## UI Requirements

**N/A — 冇任何 player-facing UI(intentional,Pillar 2)。** Telemetry 永遠唔向玩家顯示任何介面、唔要求任何輸入。**因此唔觸發 `/ux-design` UX Flag** —— 冇 screen / HUD element 需要 UX spec。

> 註:**opt-out 開關**(`telemetry_enabled`,EC-17)嘅 UI **唔屬本系統**。佢應該 surface 喺一個玩家設定 / 隱私頁(將來 #24 Login/Shell 或一個 settings screen),由嗰個系統 own UI;telemetry 只 own 嗰個 boolean 嘅行為語意。本 GDD 唔負責畫嗰個 toggle。

## Acceptance Criteria

> 分類:Logic = 自動 unit(BLOCKING);Integration = 整合 test(BLOCKING);Static-CI = lint(BLOCKING);Advisory = playtest/評審。

- **AC-01 [Static-CI | BLOCKING] (Rule 1 pure observer — `tools/ci/check_telemetry_no_gameplay_emit.gd`)**:**GIVEN** `telemetry.gd` source,**WHEN** CI 掃描,**THEN** 唔存在任何 `emit_signal(<gameplay signal>)`、唔存在對 upstream 系統 mutating method 嘅 call;違反 → CI fail。(CI-1)

- **AC-02 [Static-CI | BLOCKING] (Rule 4 de-identification — `tools/ci/check_telemetry_no_pii.gd`)**:**GIVEN** 所有 event payload 構造點,**WHEN** CI 比對 forbidden-field denylist(原始 kg / 絕對 1RM / bodyweight / 任何可識別身體原值),**THEN** 任一命中 → CI fail。(CI-2)

- **AC-03 [Logic | BLOCKING] (Rule 5/7 overflow CRITICAL 不滅)**:**GIVEN** buffer 容量 `TELEMETRY_BUFFER_MAX`,塞入混合 priority 超容量事件,**WHEN** overflow,**THEN** 全部 CRITICAL 保留、最舊 LOW 先被 evict、再 STANDARD;`telemetry.buffer.dropped_count` 每次 evict +1。`tests/unit/telemetry/test_buffer_overflow_priority.gd`

- **AC-04 [Logic | BLOCKING] (Rule 8 sampling)**:**GIVEN** `HIT_SAMPLE_STRIDE=10`,餵 100 個 `hit_resolved`,**WHEN** sampling,**THEN** 入 buffer 嘅個別 hit event ≈ 10 個(第 10/20/…),其餘只入 aggregate。`tests/unit/telemetry/test_hit_sampling.gd`

- **AC-05 [Logic | BLOCKING] (Formula 1 switch latency)**:**GIVEN** `phase_changed(_,REST_PERIOD)` @ t=120000ms 然後 `phase_changed(_,SET_ACTIVE)` @ t=132000ms,**WHEN** 計 latency,**THEN** = 12000ms → bucket `5–15s`,event 只帶 bucket index 非原值;另:REST_PERIOD→WORKOUT_COMPLETE **唔產生** latency event(EC-04)。`tests/unit/telemetry/test_switch_latency.gd`

- **AC-06 [Logic | BLOCKING] (Formula 3 crit override)**:**GIVEN** `HIT_SAMPLE_STRIDE=10`,**WHEN** 一個 `is_crit==true`(或 `damage_tier==CRITICAL`)嘅 hit 唔喺 stride 位,**THEN** 該個別 hit event **仍強制 keep**。`tests/unit/telemetry/test_crit_always_kept.gd`

- **AC-07 [Logic | BLOCKING] (Formula 4 lossless 不變量)**:**GIVEN** 任意 `HIT_SAMPLE_STRIDE ∈ [1,100]`,餵 N 個 `hit_resolved`,**WHEN** 讀 `combat_aggregate.total_hits`,**THEN** == N(精確,與 stride 無關)。`tests/unit/telemetry/test_aggregate_lossless.gd`

- **AC-08 [Logic | BLOCKING] (Formula 2 foreground ratio)**:**GIVEN** foreground=1,260,000ms / duration=1,800,000ms,**WHEN** 計 ratio,**THEN** =0.70;duration=0 時 `max(.,1)` 守 div-by-zero,ratio 有定義。`tests/unit/telemetry/test_foreground_ratio.gd`

- **AC-09 [Integration | BLOCKING] (Rule 6 flush at-least-once)**:**GIVEN** buffer 有 N 個 event + mock backend,**WHEN** flush POST 成功 ACK,**THEN** 該批由 buffer 移除;**WHEN** flush 失敗,**THEN** event 留 buffer + exponential backoff 重試,gameplay 不受影響。`tests/integration/telemetry/test_flush_lifecycle.gd`

- **AC-10 [Integration | BLOCKING] (Rule 13 + ADR-0008 boot Last order-resilience)**:**GIVEN** telemetry 喺 #14 之後 boot(Last),`connect_for_initial_state` back-fill GSM state,**WHEN** boot 後 emit `hit_resolved`/`enemy_killed`/`combat_metric_anomaly`,**THEN** 三者全部被 capture(零 silent drop);首批 event `game_state` stamp == back-filled current_state。`tests/integration/telemetry/test_boot_order_resilience.gd`

- **AC-11 [Static-CI | BLOCKING] (Rule 14 frozen schema — `tools/ci/check_telemetry_frozen_schema.gd`)**:**GIVEN** `loot_dropped` 序列化點,**WHEN** CI 比對 frozen `loot_dropped_v1` field set(`drop_id, rarity_tier, item_type, transition_id`),**THEN** 增/刪欄位而冇 bump version → CI fail。(CI-3,#15 FR-LOOT-3 binding)

- **AC-12 [Logic | BLOCKING] (Rule 15 recursion guard,#13 EC-49)**:**GIVEN** anomaly handler 內注入 serialize 失敗,**WHEN** 觸發,**THEN** 記去 diagnostic channel(`push_warning` + `telemetry_self_error`),**唔** re-emit `combat_metric_anomaly`,無無限遞迴。`tests/unit/telemetry/test_recursion_guard.gd`

- **AC-13 [Integration | BLOCKING] (Rule 12 page-hide beacon)**:**GIVEN** mock platform_detect 發 `visibilitychange→hidden`,**WHEN** 觸發,**THEN** 做一次 best-effort beacon flush;sendBeacon unavailable → XHR fallback(EC-18)。`tests/integration/telemetry/test_pagehide_beacon.gd`

- **AC-14 [Logic | BLOCKING] (EC-09 bfcache session 連續性)**:**GIVEN** `bfcache_resumed`,**WHEN** 距上次活動 ≤ `session_resume_ttl_seconds`,**THEN** 保留同一 `session_id`;超 TTL → 新 session_id + `session_started(resumed_from_bfcache=true)`。`tests/unit/telemetry/test_bfcache_session.gd`

- **AC-15 [Logic | BLOCKING] (EC-17 opt-out)**:**GIVEN** `telemetry_enabled=false`,**WHEN** 任何 event 產生,**THEN** 零 flush、零數據離開 device(只保 in-memory CRITICAL 本地診斷)。`tests/unit/telemetry/test_opt_out.gd`

- **AC-16 [Logic | BLOCKING] (EC-07 clock skew)**:**GIVEN** session 中途 wall-clock 跳 +3600s,**WHEN** 排序事件,**THEN** 用 `client_ts_monotonic_ms`,順序穩定;`client_ts_unix` 跳但唔影響 ordering。`tests/unit/telemetry/test_clock_skew.gd`

- **AC-17 [Logic | BLOCKING] (Rule 11 session lifecycle)**:**GIVEN** boot → events → unload,**WHEN** 檢視 stream,**THEN** `session_started` 同 `session_ended` 包夾,全部 event 共用同一 `session_id`。`tests/unit/telemetry/test_session_lifecycle.gd`

- **AC-18 [Logic | BLOCKING] (EC-03 duplicate transition)**:**GIVEN** 同 `event_name+transition_id` 喺 `dup_window_ms` 內到兩次,**WHEN** 處理,**THEN** 兩個都如實記錄(各有 `client_event_id`)+ emit 一個 `duplicate_transition_observed`(CRITICAL)。`tests/unit/telemetry/test_duplicate_transition.gd`

- **AC-19 [Logic | BLOCKING] (Rule 2 non-blocking handler)**:**GIVEN** signal handler path,**WHEN** 處理單一 event,**THEN** handler 內無 file I/O 無 network call(flush 喺獨立 async path);handler 完成於 frame budget 內。`tests/unit/telemetry/test_handler_nonblocking.gd`

- **AC-20 [Logic | BLOCKING] (EC-01/EC-05 buffer 韌性)**:**GIVEN** backend 全程 down,**WHEN** 跑完整 session,**THEN** gameplay 零影響;CRITICAL 全保(或 emergency spool);重連後 flush 自動恢復。`tests/integration/telemetry/test_offline_resilience.gd`

- **AC-21 [Logic | BLOCKING] (EC-08 DEGRADED private mode)**:**GIVEN** PersistenceLayer 報 `private_mode_detected=true`,**WHEN** 進 DEGRADED,**THEN** 唔寫 `user://` spool,in-memory buffer 繼續運作,有得 flush 就 flush。`tests/unit/telemetry/test_degraded_private_mode.gd`

- **AC-22 [Advisory | Playtest] (Pre-MVP gate data 完整性 — 系統使命驗收)**:**GIVEN** 一個完整 simulated/real workout session,**WHEN** 收集 telemetry,**THEN** 產出嘅 metric set 足以評估 hypothesis 兩半 —— 上半「glance」(switch-latency 分布 + foreground_ratio + visibility transition 計數)+ 下半「drop excitement」(rarity 分布 + `last_session_max_rarity` session-open stamp)。**呢個係 Pre-MVP PIVOT/KILL gate 嘅可量度前提**(systems-index L331)。`production/qa/evidence/telemetry-premvp-data-completeness.md`

## Open Questions

| ID | 問題 | Owner | 解決時機 | 狀態 |
|---|---|---|---|---|
| **Q-T1** | **#14 EnemyDirector L593 erratum** — 「#28 must boot BEFORE #14」係 ADR-0008 之前嘅 stale claim,應改為「#28 boots Last per ADR-0008;combat signals are runtime so late-boot catches all」。跨 file edit。 | analytics-engineer + #14 owner | **epic-time**(create-epics / story 處理跨 file edit) | OPEN — 已喺本 GDD Dependencies §Cross-system conflict 判定 ADR-0008 prevails |
| **Q-T2** | **ADR-0012 Telemetry Data Pipeline & Privacy 未寫** — endpoint schema / auth / batch protocol / retention period / de-id 法規 / opt-out 機制。本 GDD 描述 WHAT/WHY,呢張 ADR 描述 HOW。 | technical-director | architecture phase | **✅ RESOLVED 2026-06-12** — ADR-0012 Accepted (contract);unblocks Story 011/012 |
| **Q-T3** | Flush transport 用 #2 GymSysBackendClient 既有 HTTP path,定 telemetry 自己一條 dedicated HTTPRequest? | technical-director | ADR-0012 scope | **✅ RESOLVED** — **dedicated 第 5 channel**(隔離於 #2 4-channel MAX_INFLIGHT pool;pure-observer 永不餓死 loot_commit;ADR-0012 §Transport) |
| **Q-T4** | Screenshot-intent signal — #21 Loot Drop Modal / #29 Mirror Moment 有冇 expose screenshot-button-press signal 做 euphoria 強 proxy?MVP 可能未有 → forward hook。 | #21/#29 owner + analytics-engineer | #21/#29 next-revision OR v0.2 | OPEN — 唔 block MVP(Rule 10 已標 forward hook) |
| **Q-T5** | Mobile-conservative profile — `is_mobile_web` 時自動套細 buffer / 大 stride? | analytics-engineer | post-VS profiling | OPEN — 唔 MVP-block |
| **Q-T6** | Backend dedup idempotency key 確認 = `session_id + client_event_id`?需 GymSys backend 協調。 | analytics-engineer + GymSys backend | ADR-0012 scope | **✅ RESOLVED** — backend `game_telemetry` table `UNIQUE(session_id, client_event_id)`;at-least-once client + idempotent backend(ADR-0012 §Backend Schema) |
| **Q-T7** | Telemetry 數據喺玩家 backend 嘅 retention 期 / 刪除政策(隱私)。 | technical-director | ADR-0012 scope | **✅ RESOLVED** — `TELEMETRY_RETENTION_DAYS=180`(covers Month-4 Pre-MVP window + analysis buffer)+ player delete-by-account;first-party only,無第三方 SaaS(ADR-0012 §Retention) |
| **Q-T8** | **WST-side erratum**(design-review N-2)— WST signal 宣告 block(workout-state-tracker.md L117-123)冇列 `bfcache_resumed`,但 L399 承諾 emit「for #28 telemetry」。應喺 WST 宣告 block 補上(對齊 emit 承諾)。跨 file,唔 block telemetry(契約已成立)。 | #9 WST owner + analytics-engineer | epic-time / WST next-revision | OPEN — 唔 block #28 |
