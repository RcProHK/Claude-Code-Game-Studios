# Streak System

> **Status**: Approved(2026-05-26 CD-GDD-ALIGN)+ **EG-4 Amendment 2026-06-08**
> **Author**: Frank + (specialists TBD per section)
> **Last Updated**: 2026-06-08

> **⚡ EG-4 Amendment(2026-06-08,CD adjudication binding — `production/escalations/EG-4-streak-reachability.md`)**:
> streak 語意由「連續 calendar day(零 grace)」改為「**unbroken training-day chain(rest-day grace)**」— chain 繼續條件 = `1 ≤ gap_days ≤ STREAK_GRACE_GAP_DAYS`(新 knob,default **3** = 容忍 ≤2 個完整 rest day)。
> **理由**:原版零 grace 令 milestone 7+ 對 3x/week 默認玩家數學上不可達(永不,唔係難),且誘發 daily junk-workout degenerate strategy(anti-Pillar 1)。Grace 後 3x/week → milestone 7 @ ~2.3 週 / 90 @ ~30 週,全可達。
> **計數語意**:每 workout day +1(grace 只改 reset predicate,唔改 increment)— streak 值 = chain 內 training day 數。
> **Falsifiable Tests #1-#7 期望值逐一驗證全部不變**(Sick Day gap 5 > 3 仍 reset / Travel Week gap 7 仍斷 / Phone-Lost retro-credit 不受影響)。
> **連帶裁決**:shipped const `MILESTONE_THRESHOLDS [1,7,14,30,60,90]` 實為 buff step table(含 s=1 baseline boundary)同 milestone gate set `[7,14,30,60,90]` 兩概念合一 — 改名 `BUFF_STEP_THRESHOLDS`/`BUFF_STEP_MULTIPLIERS`;將來 AC-38 milestone emit 機制必須用獨立 `[7,14,30,60,90]` set,不得 iterate 含 1 嘅 buff table。
> **觀察到但 out-of-scope(deferred erratum)**:shipped buff 值 `[1.1,1.25,1.4,1.6,1.8,2.0]`(story-004 authoring 起)≠ GDD Formula 1 `[1.05,1.15,1.30,1.50,1.75,2.00]`;API 名 shipped `get_streak_buff_multiplier` ≠ spec `get_loot_rarity_modifier`。CI-green 一週,canonical 值待 balance pass 裁定 — 本 amendment 唔郁。
> **Implements Pillar**: Pillar 1 (Real Body, Real Power) primary; Pillar 3 (Drop Euphoria) supporting; Pillar 5 (Mirror Moment) supporting
> **System #**: 8 (Foundation / Pre-MVP tier)
> **Depends On**: #3 PersistenceLayer (read/write storage)
> **Depended On By**: #15 Loot Drop System (rarity modifier consumer), #29 Mirror Moment (weekly progression consumer)
> **Governing ADRs**: ADR-006 State Machine Contract (Contract 4 autoload sequential + Contract 9 wall-clock drift tolerance); ADR-003 Save State Strategy (pending — Streak persistence keys)

## Overview

Streak System 係 Mirror Hero 計算「unbroken training-day chain 嘅 workout 日數」(EG-4 amendment — 容忍 ≤`STREAK_GRACE_GAP_DAYS` 日 gap)嘅 Foundation 層 singleton autoload — 訂閱 #2 GymSys Backend Client 嘅 `workout_completed` event，update streak counter，via #3 PersistenceLayer atomic 持久化 `streak_count`、`last_workout_date_local`、`streak_milestones_unlocked` 三條核心 state keys。系統暴露 read-only public API 畀 downstream consumers 查詢當前 streak value (`get_current_streak() -> int`) + 提供 streak modifier 計算 (`get_loot_rarity_modifier() -> float`) — 每日 `workout_completed` event fire 之後 atomic update streak counter；若連續日數 hit milestone (7 / 14 / 30 / 60 / 90) 自動 emit `streak_milestone_reached(milestone: int)` signal 畀 #15 Loot Drop System (rarity gate) 同 #29 Mirror Moment (weekly progression marker) 各自響應。系統嚴格 anti-pillar enforcement：chain 斷裂(gap > `STREAK_GRACE_GAP_DAYS` 日)觸發 streak reset 但 **只 lose streak buff、never permadeath** — 玩家已 unlock 嘅 zone / cosmetic / equipment 永久保留 (per game-concept Anti-Pillar #3 「NOT Permadeath / weekly reset / progress 懲罰」)；reset 只係令 `streak_count` 由下一個 workout 起重新由 1 計(Rule 6)、loot rarity modifier 回 baseline。Streak buff 純粹係 forward-looking incentive，唔係 retrospective punishment。

系統 **wall-clock-aware** via ADR-006 Contract 9 同源 drift-tolerance helper：跨時區、夏令時切換、device clock tampering 都唔可以人為 inflate streak (Pillar 1 anti-fake stance)。Daily boundary 用 **user-local-midnight** 計算 (default device timezone，onboarding 時鎖定 timezone choice)，GymSys backend 提供 UTC ISO 8601 timestamp 作 source of truth；client 做 local-day conversion。系統 stateless from gameplay perspective — 唔 trigger animation / VFX / SFX、唔 own UI surface；HUD streak chip + flame icon + counter display 由 #20 Gym-Mode HUD render，streak reset toast 由 #25 Combat Visual Feedback 觸發、weekly milestone celebration 由 #29 Mirror Moment 處理。Streak System 本身只係「連續日數係幾多 + 邊個 milestones 解咗鎖」嘅 reactive accounting service。Foundation tier scope 鎖死 cross-platform single behaviour — mobile / desktop 行為一致。

## Player Fantasy

**Indirect Foundation Fantasy — 未斷嘅鏈 (The Unbroken Chain) / Consistency Witness**:

玩家心入面嘅 felt promise：「**我朝早 6:45 喺更衣室著好衫，鏡入面嘅自己有少少眼瞓，但我知今日係 Day 23。打開個 app，個 streak counter 由 22 跳到 23 嗰一下，唔係 fanfare、唔係 popup，係一種沉實嘅「我冇令自己失望」感覺。今日 leg day，我做完 squat 第一組落到 bench 抖氣，個遊戲後台已經幫我 roll 完今朝第一個 chest — 因為我 streak 夠長，rarity tier 升咗一檔，drop 出嚟係件 epic。我冇睇個 phone，我只係知：呢件嘢之所以 epic，係因為我連續 23 日無論幾忙都返咗 gym。如果我病咗成個禮拜冇返(超過 grace 容忍嘅 rest day),條鏈會斷,但我練咗 23 日所得到嘅件 epic 同所有解鎖嘅 zone 一樣會喺度等我 — 我冇被罰，我只係要重新累積下一條鏈。平時隔日練、週末抖兩日 — 條鏈唔會斷,因為真實訓練本來就需要休息(EG-4)。**」

呢個 fantasy 唔由 Streak System 自己 emit 任何敘事 text、VFX、SFX、或 animation — 而係由佢嘅 **architectural posture** 強制：

- **Forward-pull modifier，唔係 backward punisher** — Streak 永遠 *加乘* 當下嘅 loot rarity / unlock progress；chain 斷裂(連續休息超過 `STREAK_GRACE_GAP_DAYS` 容忍日數,EG-4)= `loot_rarity_modifier` 歸 baseline 1.0x (buff 消失)，但所有歷史 drop、已解鎖 zone、milestone equipment **永久保留** (anti-pillar 嘅「NOT Permadeath / progress 懲罰」hard guarantee enforced at data layer — streak reset 只 nuke current modifier state，never touch inventory / unlock manifest)
- **Day-scale temporal accumulation，partition 自 #1 GSM 嘅 ms-scale continuity** — #1 owns within-session millisecond-grain reliability (state transitions never drop frames)；本 system owns *across-session, across-day* temporal accumulation。即使 app crash、即使連續一週冇開過 game 但每日返咗 gym (streak 由 GymSys workout event 驅動，非由 app launch event)，streak 都會繼續累積。Architectural partition 嘅核心：#1 = milliseconds, #8 = days
- **Threshold milestones 係 *permanent unlocks*，唔係 *renewable buffs*** — 過咗 7/14/30/60/90 milestone 嗰一刻解鎖嘅 zone / boss / cosmetic / equipment slot，**永久屬於玩家**。Streak 斷咗都唔會 lock 返。Streak's *current* value 只控制 ongoing modifier；歷史 milestone artifacts 屬玩家所有，呢個 contract enforced via `streak_milestones_unlocked: Array[int]` 持久化 (一旦寫入永不 delete)
- **Streak HUD presence below-threshold，唔搶 attention** — Counter tick 應該 *understated dignified* (small number tick + 低調 chime via #4 AudioManager)，唔可以係 DNF-style 爆裝級別 fanfare (#3 Pillar 嘅 dopamine peak 屬 loot drop，唔屬 streak tick)。本 system 唔 own UI surface — #20 Gym-Mode HUD render counter chip + flame icon；本 system 只提供 read-only `get_current_streak() -> int` query API
- **Wall-clock-aware anti-fake stance (Pillar 1 dignity)** — Daily boundary 用 user-local-midnight (timezone 喺 onboarding 鎖定)，GymSys backend timestamp 用 UTC ISO 8601 source of truth；client-side clock tampering 唔可以 inflate streak (via ADR-006 Contract 9 同源 drift-tolerance helper — `wall_clock_unix < last_workout_local_midnight - WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` 視為 fraudulent，reject 該 update)

呢個 indirect Unbroken Chain fantasy 同 GDD #1 GSM 嘅「invisible reliability」、#5 ParticleSystemWrapper 嘅「眼角擒獲」、#6 ScreenEffects 嘅「眼角嘅爆擊」、#7 Camera 嘅「沉默嘅 Showrunner」一齊形成 **Foundation tier 嘅統一 fantasy vocabulary**：

- #1 owns *temporal continuity* (state machine ms-scale reliability)
- #5 owns *peripheral visual signal* (particle burst attention capture)
- #6 owns *peripheral kinaesthetic signal* (shake + hit pause 體感印章)
- #7 owns *spatial framing* (camera 決定 player 嘅眼睛去邊)
- **#8 (this system) owns *cross-day temporal accumulation*** (Streak 見證玩家嘅 consistency 跨日子)

5 個 Foundation system 各 own player's attention / identity 嘅 distinct channel，互不干涉，合起來保證 Pillar 1 + Pillar 2 + Pillar 5 嘅 long-horizon trust contract 完整。

呢個 indirect fantasy 直接 enables：

- **Pillar 1 (真身真力 — primary owner)** — Streak 嘅唯一輸入 = 真實 gym workout event (via #2 GymSys Backend Client `workout_completed`)，永不接受任何 in-game shortcut / pay-to-restore path。Wall-clock drift defense + UTC backend timestamp source of truth = streak 數字 unfakeable
- **Pillar 3 (DNF 式爆裝刺激 — supporting via rarity modifier)** — `loot_rarity_modifier = f(streak_count)` 喺 #15 Loot Drop System 嘅 base rarity 公式作 multiplicative term (formula: `base × volume × PR × streak`)。Streak 唔自己 deliver dopamine peak，但 *amplify* #15 嘅 ritual moment
- **Pillar 5 (鏡像時刻 — supporting via milestone markers)** — Weekly milestone (Day 7 / 14 / 30 / 60 / 90) trigger `streak_milestone_reached(milestone: int)` signal，畀 #29 Mirror Moment 作為 weekly progression marker 之一 (其他 markers 包括 PR count + volume threshold + zone unlock)

**Falsifiable design test** — 任何 client-side path 引致以下情境 = bug，唔係 acceptable behavior：

> **EG-4 grace 注**(2026-06-08):以下 7 個 test 嘅「連續 N 日」敘事喺 chain 語意下解讀為「unbroken training-day chain 達 N」(daily cadence 係 valid chain 嘅特例)。每個 test 嘅期望結果已逐一用 grace=3 重新驗證,**全部不變**:#1 gap 5 日 > 3 → 仍 reset ✓;#2 gap 7 日 → 仍斷 ✓;#3 retro-credit 機制獨立於 chain predicate ✓;#5/#7 同 grace 無關 ✓;#6 chain 斷裂語意不變 ✓。

1. **The Sick Day Test** — 玩家連續 45 日返 gym，第 46 日發燒躺床。Recovery 後第 50 日返 gym：UI 應該顯示「Day 1 of new streak」 + inventory 仍然有 Day 45 milestone unlock 嘅 epic gear + 所有 30/45 milestone zone 仍然 accessible。**Violation**：inventory 任何嘢被 grey-out / locked / removed → anti-pillar permadeath 違反
2. **The Travel Week Test** — 玩家連續 60 日，然後出 trip 7 日完全冇 access to gym (非 phone-skip, 真實 life circumstance)。Return 後第一次 workout，app 唔會彈出「You lost your 60-day streak!」嘅 punitive notification — 最多係 neutral「New streak starting」。**Violation**：出現 guilt-tripping copy (e.g.「You let us down」/「Don't disappoint your avatar again」) → Pillar 1 嘅 dignity contract 違反
3. **The Phone-Lost Test** — 玩家連續 30 日返 gym，但第 31 日喺 gym 唔記得帶手機 / 手機冇電。GymSys backend has the real workout data。Streak 應該 *retroactively credit* 嗰日 (Pillar 1 嘅核心 = real body real power, NOT app interaction power)。**Violation**：streak 凈靠 app event 而忽略 GymSys 真實數據 → real-body contract 違反
4. **The Numb Counter Test** — Streak counter 由 22 tick 到 23 嗰一刻，HUD reaction 應該係 *understated dignified* (small number tick, 配低調 chime)。**Violation**：每日 streak tick 都 trigger 大型 VFX / popup / fanfare → 同 #3 Pillar Drop Euphoria 撞 fantasy + dilute 咗 loot moment 嘅獨特性
5. **The Pay-to-Streak Test** — 商店、premium tier、廣告觀看、任何 in-game currency 或 real-money payment 都唔可以 *purchase streak restoration* / *streak freeze* / *retroactive day credit*。**Violation**：任何 monetization path 可以 restore 一個斷咗嘅 streak → Pillar 1 + anti-pillar「NOT pay-to-power」直接違反
6. **The Long-Haul Test** — 玩家 A 連續 180 日 vs 玩家 B 斷過一次然後又連續 90 日。Current `loot_rarity_modifier`：A 應該 > B (因為 current streak 數字大)，但 B 嘅 inventory **必須包含** 90-day milestone 嘅獨特物品；A 唔可以「補返」呢件物品因為 A 從未達到「斷後重起 90 日」嘅情境。**Violation**：milestone 單純由 *peak streak value* 解鎖而非 *what player has actually lived through* → fantasy 嘅 long-game soul 失效
7. **The Clock Tamper Test** — 玩家連續 5 日返 gym。第 6 日佢將 device clock 撥前 7 日想 fake「Day 12」。系統 detect device wall clock 跳前 > `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` (300s) → reject the update + 將 streak state 鎖喺 last legitimate value (Day 5) until backend re-sync。**Violation**：streak inflated by clock manipulation → Pillar 1 anti-fake stance 失效

### Fantasy Risk Register

呢個 indirect fantasy 嘅 "Unbroken Chain" framing 係 contingent on 以下 invariants 喺 **ADR-003 ratification + VS-tier playtest** 真正 enforced，否則 Player Fantasy paragraph 變 retroactive lie：

| # | Contingent Invariant | Owner | Fallback if Dropped |
|---|---------------------|-------|---------------------|
| FR-1 | GymSys backend `workout_completed` event 配合 client local-day conversion 達到 retro-credit Phone-Lost case (Falsifiable Test #3) — 即係 GymSys 真實 workout data 喺玩家 phone 唔喺度時仍 captured，next reconcile 觸發 streak retro-update | ADR-003 + ADR-002 GymSys protocol | 若 backend 唔 expose retro-workout window query API → Phone-Lost case 變 "可能漏 credit"，需要 fallback copy framing 強調「streak 主要 reward consistent app + gym usage，少數情境失誤可接受」— Pillar 1 dignity 弱化但保留 |
| FR-2 | `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300` (mirror PersistenceLayer Contract 9 value) 喺實際 device 上有效防 clock tamper (Falsifiable Test #7) — 但極端 case (e.g. device clock 慢慢 drift over weeks) 可能造成 false-positive reject | ADR-003 + VS-tier `/playtest-report` | 若 false-positive rate 過高 → 加入 backend wall-clock comparison fallback (用 GymSys backend timestamp 作 ground truth)，client-only drift detect 降級為 advisory |
| FR-3 | Streak `loot_rarity_modifier` 喺 #15 Loot Drop System rarity 公式作 multiplicative term，永不喺其他系統 (e.g. #11 Stat System / #12 Ability System) 直接 read — 防 streak 變相成為 *avatar power* path (Pillar 1 violation) | gameplay-programmer + CI script | 若 caller violation (e.g. #12 Ability System call `Streak.get_current_streak()` to boost ability damage) → CI fail at build + push_warning at runtime；streak modifier 系統 access 限喺 #15 + #29 whitelist |

**Ratification gate binding**: ADR-003 Save State Strategy review MUST verify implementation satisfies FR-1 + FR-2 + FR-3 before Status: Accepted。若 ADR-003 lands without 任何一個 → revisit this Player Fantasy paragraph with the corresponding fallback framing。

## Detailed Design

### Internal States (5)

| State | Entry | Exit | Behaviour |
|-------|-------|------|-----------|
| **Booting** | Autoload `_ready()` start | All three `IPersistence.read()` calls return + `_local_timezone_offset_minutes` resolved + GSM `connect_for_initial_state(_on_gsm_state_changed)` resolved | All public getters return safe defaults (`get_current_streak() → 0`, `get_loot_rarity_modifier() → 1.0`, `is_milestone_unlocked(_) → false`); `workout_completed` handler **queued** into single-slot `_deferred_workout_event` (latest wins per Rule 6); no PersistenceLayer writes; no signals emit |
| **Ready** | Booting complete OR Updating handler return OR GSM exits Suspended | `workout_completed` event arrives → Updating; OR GSM enters Suspended → Suspended | Normal service: public getters return live `_streak_count` / derived modifier / `streak_milestones_unlocked` membership; `workout_completed` consumed inline; `streak_changed` / `streak_milestone_reached` emit per Rules 5–8 |
| **Updating** | `workout_completed(completed_at_utc)` received in Ready and passed Rule 4 drift gate | `IPersistence.write` for all three streak keys returned + signals emit returned + Rule 9 milestone Array persisted | Single-flight: any second `workout_completed` arriving during this state goes into `_deferred_workout_event` single-slot queue (latest wins, prior dropped + `push_warning`); public getters return values **as of pre-update** (caller sees consistent snapshot until update commits); no GSM observation during this window |
| **Suspended** | GSM `state_changed → SUSPENDED` (覆蓋一切) | GSM `state_changed → 非 SUSPENDED` (Ready re-entry; drain `_deferred_workout_event` if non-null) | `_deferred_workout_event` retained; `workout_completed` callbacks silent-queue into the same single slot (latest wins); public getters return last-Ready snapshot values (cache stays valid — no recompute); persistence writes hard-rejected; signal emits hard-suppressed; this is per the Section B "Suspended 永遠覆蓋一切" contract mirrored from #7 Camera Rule 8 |
| **Failed** | `IPersistence.critical_save_failed` received during own `streak.*` write attempt (Rule 10) | Session restart only (no auto-recover, per persistence Rule 9 corrupt path sticky semantics) | All public getters keep returning last in-memory values (no rollback — Section B Pillar 1 dignity: never silently lose state); `workout_completed` handler still consumes event into in-memory cache but **does NOT retry persistence**; `streak_persistence_failed(error_code: String)` re-emitted once per session; downstream consumers (#15 / #29) continue receiving live modifier reads — Streak System refuses to fabricate persistence success but also refuses to fake regression to baseline |

**Suspended 永遠覆蓋一切** — same posture as #7 Camera Rule 8 / #6 ScreenEffects Suspended drain。Reasoning: bfcache resume + tab kill 都唔可以喺 resume frame 撞落 stale `Updating` 嘅 half-written persistence state。`_deferred_workout_event` single-slot drain on Ready re-entry 保證 reality-event 唔丟失 (Section B Falsifiable Test #2 binding — Travel Week tolerance / Phone-Lost credit)。

**Failed 唔自動 recover** — same posture as PersistenceLayer Rule 9。一旦 IDB write 失敗 (e.g. Safari Private Mode quota=0, IDB corruption)，Streak System 唔可以扮無事；in-memory cache 繼續 serve reads，但 disk persistence 已 broken，restart-only 恢復路徑迫 caller (#15 / #29 / #20 HUD) 知道 modifier 嘅 source-of-truth 已 degraded。

### Interactions (7)

1. **Upstream: `GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)`** — ADR-006 Contract 6 helper。Streak System 只 observe Suspended ↔ 非-Suspended transitions per Rule 11；其他 GSM state (Booting / Idle / WorkoutActive / RestPeriod / CombatActive / BossEncounter / LootDrop / Disconnected) **唔影響** streak update gate — streak 只認 `workout_completed`，唔認 GSM gameplay states。Initial-state sentinel (`payload.source_event == "initial_state"`) 視為 noop。

2. **Upstream: `GymSysBackendClient.workout_completed(completed_at: int)` signal** — Streak System 訂閱呢個 signal (per GymSys GDD line 90 簽名)。`completed_at` 係 **server-provided UTC Unix timestamp**，永遠 trusted over client wall-clock per GymSys AC-22。Rule 4 (drift gate) + Rule 5 (local-day boundary computation) consume 呢個 timestamp。**Forbidden coupling**: Streak System 唔可以訂閱其他 6 個 GymSys signals (`workout_started` / `set_logged` / `rest_started` / `rest_ended` / `poll_failed` / `poll_recovered`) — 連續日數 accounting 嘅 input scope 嚴格鎖喺 workout completion event，唔關心 set-level / exercise-level granularity。

3. **Upstream / Downstream: `PersistenceLayer` (IPersistence interface)** — Streak System owns **and only owns** keys under `streak.*` namespace per persistence Rule 12: `streak.streak_count` (int), `streak.last_workout_date_local` (String, ISO 8601 YYYY-MM-DD), `streak.streak_milestones_unlocked` (Array[int]), `streak.local_timezone_offset_minutes` (int)。寫入 via `PersistenceLayer.write(key, value, flush=true)` (Rule 10 atomic write order: count → date → milestones → flush; on any failed `write_completed` filter → Rule 10.1 abort); 讀取 via `PersistenceLayer.read(key)` 喺 Booting state。**Forbidden coupling**: Streak System 唔可以 read / write `gsm.*` 或 `gym.*` 或任何 non-streak namespace；唔可以訂閱 `PersistenceLayer.write_completed` for non-streak keys (Rule 13 CI enforcement)。Subscribe `critical_save_failed(error_code, key)` 但只 act on `key.begins_with("streak.")` (Rule 10 Failed state entry)。

4. **Downstream: `streak_changed(new_streak: int, prior_streak: int)` signal** — emit 每次 `_streak_count` mutation (Rule 6 increment, Rule 7 reset-to-1, Rule 8 same-day no-op skipped — same-day 唔 emit)。#20 Gym-Mode HUD 訂閱呢個做 understated counter tick (Section B Falsifiable Test #4 "Numb Counter" binding — HUD 接管 dignity-style tick animation，Streak System 唔 own visual)。`prior_streak` 提供 delta 畀 HUD 決定動畫 direction (increment vs reset-to-1)。**Reset event** 由 `prior_streak > 1` 而 `new_streak == 1` 嚟 distinguish — Streak System 唔 emit 獨立 `streak_broken` signal (避免 punitive UX framing — Section B Falsifiable Test #2 "Travel Week" binding)。

5. **Downstream: `streak_milestone_reached(milestone: int)` signal** — emit 一次 per milestone unlock per session (gated by `streak.streak_milestones_unlocked: Array[int]` membership — Rule 9)。Payload `milestone ∈ {7, 14, 30, 60, 90}`。#15 Loot Drop System 訂閱呢個 trigger ritual-tier rarity unlock；#29 Mirror Moment 訂閱呢個 mark weekly progression。**Emit-once contract**: 已寫入 Array 嘅 milestone 即使 streak 跌 0 後再升回都唔再 emit (Section B Falsifiable Test #6 "Long-Haul" binding — milestones 屬玩家所有，唔係 renewable buff)。

6. **Downstream: `get_loot_rarity_modifier() -> float` getter** — #15 Loot Drop System call 呢個 pure getter 喺 base rarity 公式 (per Section B Pillar 3 supporting role: `base × volume × PR × streak`)。Return value 由 Rule 8 curve 決定，bounded `[1.0, 2.0]` per Section D。**Forbidden coupling**: 除 #15 + #29 外其他 system (e.g. #11 Stat / #12 Ability / #18 PR Detection) **唔可以** call 呢個 getter 將 streak 注入 avatar power 路徑 (Section B FR-3 binding — 違反 Pillar 1 anti-pillar #1)。Rule 13 CI script 喺 `src/gameplay/stats/`, `src/gameplay/abilities/`, `src/gameplay/pr/` paths grep call site，violation = build fail。

7. **Forbidden coupling: in-game shortcut / pay-to-restore** — Streak System 嘅唯一 input edge 係 GymSys `workout_completed` (per Interaction #2)。**永無**第二個 entry point — 唔暴露 `force_increment()` / `restore_streak()` / `gift_day()` API；冇 dev console cheat (production builds)；冇 IAP hook；冇 ad-watch reward hook。Section B Falsifiable Test #5 "Pay-to-Streak" 嘅 architectural enforcement — Pillar 1 anti-pillar #2 hard guarantee。Rule 13 CI script 額外 grep `Streak\.(set_|increment_|force_|restore_|gift_)` patterns 喺整個 codebase = build fail。

### Rules (14)

#### Rule 1 — Closed API surface

```gdscript
# Public API (read-only — caller never mutates Streak state directly)
func get_current_streak() -> int                           # current streak_count
func get_loot_rarity_modifier() -> float                   # Rule 8 curve output, [1.0, 2.0]
func is_milestone_unlocked(milestone: int) -> bool         # streak_milestones_unlocked.has(m)
func get_unlocked_milestones() -> Array[int]               # defensive copy of streak_milestones_unlocked
func get_last_workout_date_local() -> String               # ISO 8601 YYYY-MM-DD, empty string if never

# Future-reserved API (post-#27 Onboarding GDD authoring):
# func set_local_timezone_offset_minutes(offset_min: int) -> bool  # one-shot onboarding write

# Signals (Interactions #4–#5 + persistence failure)
signal streak_changed(new_streak: int, prior_streak: int)
signal streak_milestone_reached(milestone: int)
signal streak_persistence_failed(error_code: String)        # Rule 10 Failed state entry, emitted once per session
```

**No public mutator method.** State transitions happen exclusively through internal `_on_workout_completed(completed_at_utc)` handler (private, connected to GymSys signal). 違反呢條 = caller path 直接 mutate streak counter，相當於 Section B Falsifiable Test #5「Pay-to-Streak」嘅 architectural breach。Rule 13 CI enforce。

`NaN` / negative / non-monotonic `completed_at` → reject + `push_error` + `_rejected_events_count += 1` + early return (Foundation autoload 唔 throw — 同 #5 / #6 / #7 一致)。

Rationale: closed primitive 同 #5/#6/#7 architectural posture 一致 — Showrunner Channel separation 喺 API 層 enforce。Streak System 唔係「玩家 stats」嘅一部分，係「玩家 history witness」服務 — read-only by design。

#### Rule 2 — Booting: read three keys, derive timezone, await GSM initial-state

```gdscript
func _ready() -> void:
    _state = State.BOOTING

    _streak_count = PersistenceLayer.read("streak.streak_count") if PersistenceLayer.read("streak.streak_count") != null else 0
    _last_workout_date_local = PersistenceLayer.read("streak.last_workout_date_local") if PersistenceLayer.read("streak.last_workout_date_local") != null else ""
    var milestones_raw = PersistenceLayer.read("streak.streak_milestones_unlocked")
    _streak_milestones_unlocked = (milestones_raw as Array[int]) if milestones_raw != null else ([] as Array[int])

    # Timezone offset: from streak.local_timezone_offset_minutes (set during #27 Onboarding)
    var tz_raw = PersistenceLayer.read("streak.local_timezone_offset_minutes")
    _local_timezone_offset_minutes = (tz_raw as int) if tz_raw != null else _detect_device_timezone_offset_minutes()

    PersistenceLayer.critical_save_failed.connect(_on_persistence_critical_save_failed)
    GymSysBackendClient.workout_completed.connect(_on_workout_completed)
    GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)

    _state = State.READY
```

`_detect_device_timezone_offset_minutes()` fallback: `Time.get_time_zone_from_system().bias` (Godot 4.6 API — minutes east of UTC, signed int). **Open Item Q-O1**: #27 Onboarding GDD 唔存在 — confirm whether Onboarding writes `streak.local_timezone_offset_minutes` at first-launch, or Streak System silently falls back to device timezone forever。

Rationale: 三條 read + timezone resolve 全部 sync per persistence Contract 4 autoload position 1 ordering — Streak System 自己 autoload position 後過 PersistenceLayer，所以 read 嗰陣 PersistenceLayer 已 Ready substate。GSM `connect_for_initial_state` 必須 used 而非 plain `.connect()` per ADR-006 Contract 6 sentinel pattern。

#### Rule 3 — `workout_completed` event handler atomic skeleton

```gdscript
func _on_workout_completed(completed_at_utc: int) -> void:
    if _state == State.SUSPENDED or _state == State.UPDATING:
        _deferred_workout_event = completed_at_utc  # single-slot, latest wins
        if _state == State.UPDATING:
            push_warning("Streak: workout_completed during Updating — coalesced into _deferred slot")
        return
    if _state == State.BOOTING:
        _deferred_workout_event = completed_at_utc
        return
    if _state == State.FAILED:
        _apply_workout_in_memory_only(completed_at_utc)
        return

    if not _passes_drift_gate(completed_at_utc):
        _rejected_events_count += 1
        return

    _state = State.UPDATING
    var prior_streak: int = _streak_count
    var prior_date: String = _last_workout_date_local

    var workout_date_local: String = _utc_to_local_date(completed_at_utc, _local_timezone_offset_minutes)
    var new_streak: int = _compute_new_streak(workout_date_local, prior_date, prior_streak)

    if new_streak == prior_streak and workout_date_local == prior_date:
        # Same-day repeat workout — no-op per Rule 8 (idempotent)
        _state = State.READY
        _drain_deferred_if_any()
        return

    if not _write_streak_state_atomic(new_streak, workout_date_local):
        return  # Rule 10 Failed state entry already set

    _streak_count = new_streak
    _last_workout_date_local = workout_date_local
    streak_changed.emit(new_streak, prior_streak)

    _check_and_emit_milestones(new_streak)

    _state = State.READY
    _drain_deferred_if_any()
```

Rationale: handler 結構鎖死「guard → drift gate → local-day compute → consecutive-day determination → atomic persist → in-memory commit → signal emit → milestone check → drain deferred」 8-step sequence。任何中途 fail 都唔留 partial state。Mirror PersistenceLayer Rule 2 + GSM Rule 2 嘅 atomic-or-fail-loud 紀律。

#### Rule 4 — Wall-clock drift gate (`WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300`)

```gdscript
func _passes_drift_gate(completed_at_utc: int) -> bool:
    if completed_at_utc <= 0:
        push_error("Streak: workout_completed with invalid timestamp %d rejected" % completed_at_utc)
        return false

    var device_now_utc: int = int(Time.get_unix_time_from_system())
    var future_skew: int = completed_at_utc - device_now_utc
    if future_skew > PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS:
        push_warning("Streak: rejecting workout_completed %d seconds in future (drift tolerance %d) — device clock likely tampered backward" % [future_skew, PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS])
        _drift_rejected_count += 1
        return false

    # Monotonicity guard
    if _last_accepted_completed_at_utc > 0 and completed_at_utc < _last_accepted_completed_at_utc:
        push_warning("Streak: rejecting non-monotonic workout_completed %d (last accepted %d)" % [completed_at_utc, _last_accepted_completed_at_utc])
        _drift_rejected_count += 1
        return false

    _last_accepted_completed_at_utc = completed_at_utc
    return true
```

Note: `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300` 直接從 PersistenceLayer 引用 (registered constant)，single source of truth — Streak 唔自己重複定義。

Rationale: Section B Falsifiable Test #7「Clock Tamper Test」嘅 architectural enforcement — 玩家撥前 device clock 7 日，GymSys backend timestamp 唔會跳前 (server-side ground truth)，所以 `completed_at_utc - device_now_utc` ≈ 0。Drift gate 防嘅係另一個方向：玩家撥**後** device clock，令 device 認為而家係 6 月，然後 GymSys 真實事件 timestamp (5 月) 應該照樣 accept (negative future_skew = past = OK)。亦防 GymSys backend 自己出錯返 future timestamp。

#### Rule 5 — Local-day computation (timezone + DST aware)

```gdscript
func _utc_to_local_date(utc_seconds: int, offset_minutes: int) -> String:
    var local_seconds: int = utc_seconds + (offset_minutes * 60)
    var dt: Dictionary = Time.get_datetime_dict_from_unix_time(local_seconds)
    return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]
```

**DST-aware design choice**: timezone offset 喺 onboarding **lock 一次** (Open Item Q-O1)，唔每次 read device timezone。避免「玩家 spring-forward 嗰晚剛好 23:55 完 workout，DST 跳前 1 hour 之後 device 嘅 timezone offset 變咗，client 視為已過第二日」呢類 false-credit / false-loss case。鎖定 timezone = 玩家 commitment 嘅一部分 (Section B Pillar 1 dignity)。

**Date-string equality, not datetime arithmetic**: consecutive-day check (Rule 7) 比較 ISO 8601 YYYY-MM-DD string 而非 datetime delta seconds。原因：daylight saving + leap second + manual timezone change 都可能令 24-hour delta 等於「同一日」或「跳兩日」。Day boundary 嘅 ground truth 係 calendar day，唔係 86400-second delta。

Rationale: Section B Falsifiable Test #3「Phone-Lost Test」+ Test #6「Long-Haul Test」binding — 跨日 boundary 必須 calendar-correct。

#### Rule 6 — Chain-continuation computation (training-day chain with rest-day grace — EG-4 amendment)

```gdscript
const STREAK_GRACE_GAP_DAYS: int = 3  # EG-4: tolerate ≤2 full rest days (gap ≤ 3 calendar days)

func _compute_new_streak(workout_date_local: String, prior_date: String, prior_streak: int) -> int:
    if prior_date.is_empty() or prior_streak == 0:
        return 1  # First-ever workout

    if workout_date_local == prior_date:
        return prior_streak  # Same day — idempotent

    var gap: int = _gap_days(prior_date, workout_date_local)  # noon-anchored calendar-day delta
    if gap >= 1 and gap <= STREAK_GRACE_GAP_DAYS:
        return prior_streak + 1  # Chain continues — increment (one per training day)

    return 1  # Gap > STREAK_GRACE_GAP_DAYS — reset to 1 (forward-pull, NOT punisher)

func _gap_days(prior_iso: String, current_iso: String) -> int:
    # Noon-anchored unix conversion on BOTH dates, integer day delta.
    # hour=12 avoids DST ±1h boundary ambiguity (same protection as the
    # pre-EG-4 _is_next_calendar_day helper — noon + N×86400 always lands
    # on the target day's noon).
    var prior_dict: Dictionary = _parse_iso_date(prior_iso)
    prior_dict["hour"] = 12
    var current_dict: Dictionary = _parse_iso_date(current_iso)
    current_dict["hour"] = 12
    var prior_unix: int = int(Time.get_unix_time_from_datetime_dict(prior_dict))
    var current_unix: int = int(Time.get_unix_time_from_datetime_dict(current_dict))
    return int(round(float(current_unix - prior_unix) / 86400.0))
```

Noon-anchored arithmetic (`hour: 12`) 避免 DST spring-forward / fall-back 嗰一日 ±1 hour shift 將 86400 跨 0:00 boundary。

**EG-4 chain 語意**:streak 值 = unbroken chain 內嘅 **training day 數**(每 workout day +1)— grace 只放寬 reset predicate,唔令 rest day 計數。3x/week 玩家 +3/week → milestone 7 ≈ 2.3 週 / 90 ≈ 30 週(原版零 grace 下數學上不可達 — 見 escalation file)。

**Reset semantics**: gap > `STREAK_GRACE_GAP_DAYS` → streak = 1 (NOT 0)。對應 Section B「The Travel Week Test」嘅 dignity framing — 玩家返到嚟之後個 counter 由 1 開始，唔係由 0。

Rationale: Section B Falsifiable Test #2「Travel Week」locked — 唔 emit `streak_broken`，silent reset-to-1。Section B 鎖死「forward-pull modifier, not backward punisher」架構 posture。EG-4 grace rationale:零 grace 誘發 daily junk-workout degenerate strategy + 懲罰生理必需嘅 rest day,直接 anti-Pillar 1;grace=3 對齊「唔好連續休息太耐」嘅真實訓練建議。

#### Rule 7 — Milestone thresholds + emit-once-per-Array contract

```gdscript
const MILESTONE_THRESHOLDS: Array[int] = [7, 14, 30, 60, 90]  # Section B locked

func _check_and_emit_milestones(new_streak: int) -> void:
    for m in MILESTONE_THRESHOLDS:
        if new_streak >= m and not _streak_milestones_unlocked.has(m):
            _streak_milestones_unlocked.append(m)
            if PersistenceLayer.write("streak.streak_milestones_unlocked", _streak_milestones_unlocked, true):
                streak_milestone_reached.emit(m)
            else:
                _streak_milestones_unlocked.erase(m)
                return  # halt further milestone checks until Failed cleared
```

**Emit-once contract**: 一旦 milestone 寫入 `streak.streak_milestones_unlocked: Array[int]`，**永不 delete** (per Section B Falsifiable Test #6「Long-Haul Test」+ anti-pillar permadeath hard guarantee)。下次 streak reset 後 streak 重 grow 過 milestone，`has(m) == true` → 唔 emit。

**Multi-milestone same-event handling**: ascending order 依次 emit 每個 newly-crossed milestone (defensive for future retro-credit batch grant cases)。

Rationale: Section B Falsifiable Test #6 binding — milestone artifacts (inventory unlock, zone access, cosmetic) 由 #15 + #29 收 signal 後 perform；Streak System 只記「邊個 milestone 我見過」。

#### Rule 8 — `loot_rarity_modifier` curve shape (Section D formalizes formula)

Section C 只 lock **shape** 唔 lock formula。Formula 1 喺 Section D 形式化。Shape contract：

- **Monotonically non-decreasing** with `streak_count` ∈ `[0, ∞)`
- **Baseline** at `streak_count == 0`: modifier = 1.0
- **Cap** at high streak: modifier ≤ 2.0
- **Milestone-aligned step function** (NOT continuous): modifier 喺 7 / 14 / 30 / 60 / 90 days 邊界跳 step
- **Reset on streak break**: `streak_count` drop to 1 → modifier drop to 1.05 即時 (forward-pull means **current** state matters, NOT peak)

Provisional step (formalized Section D):

| streak_count | loot_rarity_modifier |
|--------------|----------------------|
| 0 | 1.00 |
| 1–6 | 1.05 |
| 7–13 | 1.15 |
| 14–29 | 1.30 |
| 30–59 | 1.50 |
| 60–89 | 1.75 |
| 90+ | 2.00 (cap) |

```gdscript
func get_loot_rarity_modifier() -> float:
    if _streak_count >= 90: return 2.00
    if _streak_count >= 60: return 1.75
    if _streak_count >= 30: return 1.50
    if _streak_count >= 14: return 1.30
    if _streak_count >= 7:  return 1.15
    if _streak_count >= 1:  return 1.05
    return 1.00
```

**Step function over continuous**: 配合 Rule 7 milestone-permanent contract — 玩家 cross 7 days boundary 嗰一刻同時感受 `streak_milestone_reached(7)` 嘅 ritual signal + `loot_rarity_modifier` step up。Continuous curve 會 dilute ritual moment + 引入 per-day micro-incentive (玩家計緊「再做一日 modifier 升 0.003」)，違反 Section B「understated dignified」framing。

Rationale: shape 而非 formula — final coefficient + cap + step boundaries 喺 Section D 經 worked example + variable table 鎖死，因為 final curve 直接影響 #15 rarity 公式 input range，需要 balance simulation。

#### Rule 9 — Persistence interaction (atomic write order, namespace discipline)

```gdscript
func _write_streak_state_atomic(new_streak: int, new_date_local: String) -> bool:
    # Atomic write order: count → date → flush
    # Reason: if count writes but date fails, next boot reads count=N + date=stale,
    # next workout same calendar day silently increments again (double-credit).
    # By writing count first then date, partial-fail leaves a self-detecting state:
    # count > prior_count but date == prior_date → next boot's Rule 6 same-day check catches it.

    if not PersistenceLayer.write("streak.streak_count", new_streak, false):
        push_error("Streak: streak.streak_count write failed")
        _enter_failed_state("STREAK_COUNT_WRITE_FAIL")
        return false

    if not PersistenceLayer.write("streak.last_workout_date_local", new_date_local, true):  # critical flush on second write to commit pair atomically
        push_error("Streak: streak.last_workout_date_local write failed")
        # Rollback streak_count in-memory + persistence to keep pair consistent
        PersistenceLayer.write("streak.streak_count", _streak_count, true)
        _enter_failed_state("STREAK_DATE_WRITE_FAIL")
        return false

    return true
```

**Write order rationale**: 兩條 keys 必須 atomic-pair。`streak.streak_count` 先寫 (non-flush)，`streak.last_workout_date_local` 後寫 (flush=true 觸發 PersistenceLayer Rule 3 atomic disk flush 包埋兩 key)。若 count 成功但 date fail，rollback count to prior value 保持 pair consistency。Milestone Array 喺 Rule 7 入面獨立寫 (亦 flush=true) — 因為 milestone unlock 係 monotonic-only (永不 erase per Rule 7)，partial fail worst case 只係下次 boot 唔知玩家見過 milestone → 再 emit 一次 — 呢個比 streak count 雙重 credit 風險低 (milestone downstream consumer 都係 idempotent identity-keyed unlock)。

**Namespace discipline**: Streak System **只寫** `streak.*` 開頭嘅 keys (per persistence Rule 12)，**永不**寫 `gsm.*` / `gym.*` / `_internal.*` / 任何其他 namespace。Rule 13 CI script 確認。

Rationale: PersistenceLayer Rule 3 atomic-flush + ordered-write-with-rollback = paired key consistency 保證。

#### Rule 10 — `critical_save_failed` handling (Failed state entry, no auto-recover)

```gdscript
func _on_persistence_critical_save_failed(error_code: String, key: String) -> void:
    if not key.begins_with("streak."):
        return  # Only act on streak.* namespace failures
    _enter_failed_state("PERSIST_LAYER_FAIL:%s:%s" % [error_code, key])

func _enter_failed_state(reason: String) -> void:
    if _state == State.FAILED:
        return  # already failed, no re-emit
    _state = State.FAILED
    push_error("Streak: entering Failed state — %s" % reason)
    streak_persistence_failed.emit(reason)
    # In-memory cache stays valid; getters keep serving last good state.
    # No auto-retry — restart-only recovery per Section C State table.
```

**Anti-fabrication posture (Section B FR-2 binding)**: PersistenceLayer Rule 9 corrupt path = wipe disk + emit `critical_save_failed`。Streak System 收到 → 但 **唔扮**「OK fresh start streak=0」(會 silently lose 玩家真實連續日數)。In-memory cache 繼續 serve `get_current_streak()` last-known value，downstream (#15 / #29 / #20 HUD) 收到 `streak_persistence_failed` signal → 自行 decide 點 surface。預期 #24 Login UI 訂閱呢個 signal 顯示 「Storage unavailable — streak progress may not save until app restart」 message。

**No retry**: per State table，Failed 係 sticky 直到 session restart。原因：persistence 連 wipe-and-fresh-start 都 fail (e.g. Safari Private Mode quota=0)，再 retry 都會 fail；玩家最少 deserve 知道個 storage 壞咗，唔係見住 modifier 慢慢 silently regress。

Rationale: Section B "Saved Means Saved" 嘅 architectural posture 由 PersistenceLayer GDD enforce，本 system 唔重複實現，但接住 contract — 收到 `critical_save_failed` 唔靜悄悄 swallow + fake-reset。

#### Rule 11 — Suspended state behaviour: deferred single-slot drain

```gdscript
func _on_gsm_state_changed(from_state: String, to_state: String, payload) -> void:
    if payload != null and payload.has_method("get") and payload.get("source_event") == "initial_state":
        return  # Initial-state sentinel — noop

    if to_state == "suspended":
        _state = State.SUSPENDED
        return

    if _state == State.SUSPENDED:
        _state = State.READY
        _drain_deferred_if_any()

func _drain_deferred_if_any() -> void:
    if _deferred_workout_event > 0:
        var deferred: int = _deferred_workout_event
        _deferred_workout_event = 0
        _on_workout_completed(deferred)  # Re-enter via normal handler — Rule 4 + monotonicity still apply
```

**Single-slot, latest-wins** drain policy: streak 只關心「最近一次完成 workout 嘅 calendar day」決定 chain-continue vs same-day vs gap-reset(Rule 6 grace predicate),唔係 set 一次都增 streak。Latest-wins 簡化 + 避免 queue overflow + 保證 monotonicity。

**Sync handler = no abort race**: Rule 3 handler 完全 sync (no `await`)，所以 GSM 喺 Updating 中間 emit Suspended 嘅情況下 GDScript event loop 唔會搶 — handler 跑完先輪到 GSM signal handler。Updating → Suspended transition 唔會留 partial write 狀態。

Rationale: mirror #7 Camera Rule 8 / #6 ScreenEffects Suspended drain — Suspended 永遠覆蓋一切，state 喺 resume 嗰一刻乾淨，唔留 mid-flight artifact。

#### Rule 12 — Retro-credit window (provisional, gated by Open Item Q-O2)

Section B Falsifiable Test #3「Phone-Lost Test」要求：玩家 Day 31 真實返 gym 但手機冇電/唔喺手；Day 32 開 app，streak 應該係 32 而唔係 reset-to-1。

**Provisional contract**: 依賴 GymSys backend `workout_completed` signal 喺玩家 reconnect / next-poll 嗰陣 deliver **歷史 unconsumed events**。Streak System Rule 4 monotonicity gate + Rule 6 next-day check 自然處理 — 收到 Day 31 嘅 `completed_at_utc` (即使 device time 已係 Day 32) → Rule 4 drift gate (negative future_skew = OK, past timestamp legitimate) → Rule 5 local-day = "Day 31" → Rule 6 prior_date "Day 30" 至 "Day 31" = next calendar day → streak +1 → 然後 Day 32 嘅 event 跟住 emit → streak +1 again。

**Open Item Q-O2**: 確認 GymSys backend 是否 expose retro-workout window query。若 backend 唔 expose — Section B FR-1 ratification fallback framing 啟動 (Phone-Lost case 可能漏 credit)。

**Streak System 自己唔做 retro logic** — 純 reactive to GymSys events。Backend retro-window 屬 ADR-002 GymSys Integration Protocol scope。

Rationale: Section B FR-1 Risk Register binding。

#### Rule 13 — CI enforcement: closed API + namespace discipline (`tools/ci/check_streak_callers.gd`)

仿照 #7 Camera Rule 13 + #5 ParticleSystemWrapper Rule 13 pattern。GDScript script run via `godot --headless --script`:

```gdscript
# Pseudo-code
const VIOLATIONS_CALLER = [
    r"Streak\.get_loot_rarity_modifier\s*\(",
]
const WHITELIST_PATHS_LOOT_RARITY = [
    "src/gameplay/loot/",         # #15 Loot Drop System
    "src/gameplay/mirror_moment/", # #29 Mirror Moment
    "src/autoload/streak.gd",
    "tests/",
]

const VIOLATIONS_MUTATOR = [
    r"Streak\.set_streak_count\s*\(",
    r"Streak\.increment_streak\s*\(",
    r"Streak\.force_streak\s*\(",
    r"Streak\.restore_streak\s*\(",
    r"Streak\.gift_day\s*\(",
]

const VIOLATIONS_NAMESPACE = [
    # Forbidden: Streak autoload writing non-streak.* keys
    r'PersistenceLayer\.write\(\s*"(?!streak\.)',
    r'PersistenceLayer\.delete\(\s*"(?!streak\.)',
]
const WHITELIST_NAMESPACE_PATHS = [
    "src/autoload/streak.gd",
]
```

Additional CI check: `tests/unit/streak/test_no_cross_namespace_writes.gd` — runtime test 喺 `MockPersistenceLayer` (via persistence Rule 6 spy contract) attach write spy + simulate full `_on_workout_completed` flow + assert spy 收到嘅 all keys 全部 `begins_with("streak.")`。

Build fail = blocking。

#### Rule 14 — Persistence scope (positive — Streak DOES persist, but only own namespace)

Unlike #5 / #6 / #7 (which are 100% non-persistent wrappers), **Streak System DOES persist** — 但 only within own `streak.*` namespace。

- ✅ Read / write `streak.streak_count`, `streak.last_workout_date_local`, `streak.streak_milestones_unlocked`, `streak.local_timezone_offset_minutes`
- ❌ Never read / write `gsm.*` (owned by #1 GameStateMachine)
- ❌ Never read / write `gym.*` (owned by #2 GymSys Backend Client)
- ❌ Never read / write `_internal.*` (owned by PersistenceLayer itself)
- ❌ Never read / write any future system's namespace (e.g. `loot.*`, `mirror.*`, `inventory.*`)

**Test enforcement**: `tests/unit/streak/test_namespace_isolation.gd` 驗證 Streak autoload 只 touch `streak.*` keys via PersistenceLayer write spy。

Rationale: persistence Rule 12 namespace convention 由本 system 第一次作為 future-system reference implementation — Streak 係 first cross-system consumer of `streak.*` namespace。嚴格 isolation 防止 future feature creep 進入其他 system 嘅 state ownership (e.g.「Streak System write inventory unlock」anti-pattern — milestone unlocks 屬 #15 / #29 寫各自 namespace)。

## Formulas

呢個 section 鎖低所有 Streak 計算嘅 mathematical specification。1 mandatory step function (Rule 8 loot rarity modifier) + 2 helpers covering Section C Rule 5 + Rule 6。所有 invariants binding to Section H Acceptance Criteria。

### Formula 1 (Mandatory) — `loot_rarity_modifier_step_curve` (Rule 8 formalization)

The `loot_rarity_modifier_step_curve` formula is defined as:

```
modifier(streak_count) =
    1.00  if streak_count <  1
    1.05  if 1  ≤ streak_count <  7
    1.15  if 7  ≤ streak_count < 14
    1.30  if 14 ≤ streak_count < 30
    1.50  if 30 ≤ streak_count < 60
    1.75  if 60 ≤ streak_count < 90
    2.00  if streak_count ≥ 90
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| streak_count | s | int | [0, ∞) | Current training-day chain count (EG-4 chain 語意); reset to 0 on Booting first-launch, to 1 on workout after chain break (Rule 6) |
| MILESTONE_THRESHOLDS | M | Array[int] | `[7, 14, 30, 60, 90]` (Section G locked) | Step boundary points; milestone-aligned |
| modifier(s) | m | float | `[1.00, 2.00]` | Output multiplier for #15 Loot Drop System base rarity formula |

**Output Range:** Monotonically non-decreasing；bounded `[1.00, 2.00]`；reset on streak break to either 1.00 (if streak=0) or 1.05 (if streak=1 from gap-reset)。Each boundary crossing = +0.10 to +0.25 step。

**Reset behavior (Section B "forward-pull, not punisher" binding)**: When `streak_count` drops from N ≥ 7 down to 1 (via Rule 6 gap reset), `modifier` drops from `step_at(N)` to `1.05` in same frame. There is NO carry-over of historical streak — modifier reflects **current** streak only.

**Worked example — Day 8 workout (新解鎖 7-day milestone 嘅當日):**

| Event | streak_count (before) | streak_count (after) | modifier (before) | modifier (after) | milestone_emit |
|-------|----------------------|----------------------|-------------------|------------------|---------------|
| Day 1 workout | 0 | 1 | 1.00 | 1.05 | — |
| Day 2 workout | 1 | 2 | 1.05 | 1.05 | — |
| ... | ... | ... | ... | ... | ... |
| Day 7 workout | 6 | 7 | 1.05 | **1.15** | `streak_milestone_reached(7)` |
| Day 8 workout | 7 | 8 | 1.15 | 1.15 | — |

**Worked example — Chain break + recovery (EG-4 grace=3):**

| Event | streak_count | modifier | Notes |
|-------|--------------|----------|-------|
| Day 45 workout | 45 | 1.50 | Mid-30-tier |
| Day 47 workout | 46 | 1.50 | gap=2 ≤ grace 3 → **chain continues**(EG-4 — rest day 唔斷鏈,rest day 本身唔計數)|
| Day 48-51 missed | 46 | 1.50 | No workout event — no state change(4 日無 workout)|
| Day 52 workout | 1 | 1.05 | gap=5 > grace 3 → Rule 6 reset → modifier 1.50 → 1.05; `streak_changed(1, 46)` emit; milestone Array unchanged (Rule 7 emit-once-permanent) |
| Day 58 workout(連續日練到)| 7 | 1.15 | Crossed 7-day boundary; `streak_milestone_reached(7)` already in Array → silent (Rule 9 emit-once contract) |

### Formula 2 (Helper) — chain-continuation classification (Rule 6 logic — EG-4 amendment)

Pure function encapsulating Rule 6 chain-continue vs same-day vs gap classification。

```
classify(workout_date_local, prior_date, prior_streak) =
    "first_workout"    if prior_date.is_empty() OR prior_streak == 0
    "same_day"         if workout_date_local == prior_date
    "chain_continue"   if 1 ≤ gap_days(prior_date, workout_date_local) ≤ STREAK_GRACE_GAP_DAYS
    "gap_reset"        otherwise
```

```
gap_days(prior_iso, current_iso) =
    let prior_noon   = unix_from(parse(prior_iso),   hour=12)   # noon-anchored to avoid DST ±1h
    let current_noon = unix_from(parse(current_iso), hour=12)
    return round((current_noon - prior_noon) / 86400)
```

> **Shipped-code 對應**(EG-4):`consecutive_day_classification(a, b)`(exact-1-day primitive,YYYYMMDD int 版)保留為 calendar formula;production caller 改用新 `chain_continuation_classification(a, b)` = `1 ≤ _days_between(a, b) ≤ STREAK_GRACE_GAP_DAYS`。

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| workout_date_local | d_w | String | "YYYY-MM-DD" | Output of Formula 3 — workout completion timestamp in user-local-day |
| prior_date | d_p | String | "YYYY-MM-DD" or "" | Previously persisted `streak.last_workout_date_local` |
| prior_streak | s_p | int | [0, ∞) | Previously persisted `streak.streak_count` |
| STREAK_GRACE_GAP_DAYS | G | int | [1, 4] (knob — Section G) | Chain 容忍嘅最大 calendar-day gap;default 3 = ≤2 個完整 rest day |
| result | r | enum | `{first_workout, same_day, chain_continue, gap_reset}` | 4-state classification used by Rule 6 update logic |

**Output Range:** Discrete enum of 4 states。`first_workout` → streak = 1。`same_day` → streak unchanged。`chain_continue` → streak += 1。`gap_reset` → streak = 1 (NOT 0)。

**Worked examples (grace boundary + DST edge case):**

| Workout UTC | Local TZ (UTC+8) | Prior date | Prior streak | Expected classification |
|-------------|------------------|-----------|--------------|------------------------|
| 2026-05-25 17:00 UTC (= local 2026-05-26 01:00) | +480 min | "" | 0 | `first_workout` |
| 2026-05-26 17:00 UTC (= local 2026-05-27 01:00) | +480 min | "2026-05-26" | 1 | `chain_continue` (gap=1, streak → 2) |
| 2026-05-26 22:00 UTC (= local 2026-05-27 06:00) | +480 min | "2026-05-27" | 2 | `same_day` (still 2) |
| 2026-05-28 17:00 UTC (= local 2026-05-29 01:00) | +480 min | "2026-05-27" | 2 | `chain_continue` (gap=2 ≤ G,streak → 3 — **EG-4:原版係 gap_reset**) |
| 2026-05-31 17:00 UTC (= local 2026-06-01 01:00) | +480 min | "2026-05-29" | 3 | `chain_continue` (gap=3 = G boundary,streak → 4) |
| 2026-06-05 17:00 UTC (= local 2026-06-06 01:00) | +480 min | "2026-06-01" | 4 | `gap_reset` (gap=5 > G,streak → 1) |

**DST robustness — Sydney spring-forward (UTC+10 → UTC+11 at 2026-10-04 02:00 local):**

| Workout UTC | Local TZ (pre-DST = +600 min, locked at onboarding) | Prior date | Expected |
|-------------|------------------------------------------------------|-----------|---------|
| 2026-10-04 14:50 UTC (= local 00:50 next day, before spring-forward) | +600 (locked) | "2026-10-03" | `chain_continue` (gap=1) ✓ |
| 2026-10-04 18:00 UTC (= local 04:00 next day, after spring-forward — but TZ stays locked +600) | +600 (locked) | "2026-10-04" | `same_day` ✓ |

**Note**: Locked timezone offset (per Rule 5 design choice) means actual DST events don't shift streak day boundaries — predictable from player's onboarding-time POV。Player who travels timezones must explicitly call `set_local_timezone_offset_minutes(new_offset)` via future API (Rule 1) to reset boundary semantics。

### Formula 3 (Helper) — `local_calendar_date_from_utc` (Rule 5 conversion)

Pure helper converting UTC Unix timestamp to ISO 8601 local-day string。

The `local_calendar_date_from_utc` function is defined as:

```
local_calendar_date_from_utc(utc_seconds, offset_minutes) =
    let local_seconds = utc_seconds + (offset_minutes × 60)
    let dt = Time.get_datetime_dict_from_unix_time(local_seconds)
    return format("YYYY-MM-DD", dt.year, dt.month, dt.day)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| utc_seconds | t_u | int | [0, 2^63) | Server-provided UTC Unix timestamp from GymSys `workout_completed(completed_at)` |
| offset_minutes | o | int | [-720, 840] | Locked timezone offset (UTC+14 max for Kiribati, UTC-12 min for Baker Island) — full IANA tz range coverage |
| result | d | String | "YYYY-MM-DD" | ISO 8601 calendar date in user-local-day |

**Output Range:** Always non-empty string of length 10 (YYYY-MM-DD format)。Range covers all valid Unix timestamps from 1970-01-01 to 9999-12-31 in any timezone。

**Worked example:**

| utc_seconds | offset_minutes | local_seconds | local date |
|-------------|---------------|---------------|-----------|
| 1748275200 (2026-05-26 16:00:00 UTC) | +480 (HKT) | 1748304000 (2026-05-27 00:00:00 local) | "2026-05-27" |
| 1748275200 | -300 (EST) | 1748257200 (2026-05-26 11:00:00 local) | "2026-05-26" |
| 1748275200 | 0 (UTC) | 1748275200 | "2026-05-26" |

**Edge: epoch boundary**: `utc_seconds = 0` (1970-01-01 00:00 UTC) → in UTC+14 → local = "1970-01-01"，唔會 underflow。`utc_seconds < 0` 被 Rule 4 drift gate reject 喺 caller side，本 formula 唔需要 handle。

### Math Invariants → Section H AC promotion candidates

以下 5 條 invariants 將 promote 入 Section H Acceptance Criteria：

- **AC-D1 (Formula 1 monotonicity)**: ∀ s₁, s₂ ∈ ℤ⁺ s.t. s₁ ≤ s₂ → `modifier(s₁) ≤ modifier(s₂)` (monotonically non-decreasing across step boundaries)
- **AC-D2 (Formula 1 cap)**: `modifier(s) ≤ 2.00 ∀ s ∈ ℤ⁺` (hard cap — guards against Pillar 1 power explosion)
- **AC-D3 (Formula 1 baseline)**: `modifier(0) = 1.00` (baseline at zero — Section B forward-pull binding)
- **AC-D4 (Formula 2 DST robustness)**: Locked timezone offset → next_calendar_day classification consistent across DST transition day (noon-anchored arithmetic protection)
- **AC-D5 (Formula 1 step boundaries match milestones)**: Each step boundary `s ∈ {1, 7, 14, 30, 60, 90}` 一一對應 milestone gate (Section G `MILESTONE_THRESHOLDS` consistency invariant)

### Section G knob preview

呢個 Section D introduces 0 new tuning knobs — 全部 numeric constants 已喺 Rule 7 (`MILESTONE_THRESHOLDS`) + Rule 8 step table 鎖定，Section G 會 enumerate as knobs。Safe ranges + extreme behaviors 喺 Section G 形式化。

**Cross-system constants needed (Section 5b registry candidates):**

- `MILESTONE_THRESHOLDS = [7, 14, 30, 60, 90]` (referenced by #15 + #29)
- `loot_rarity_modifier_step_curve` (Formula 1 — referenced by #15)
- Step table values (1.00 / 1.05 / 1.15 / 1.30 / 1.50 / 1.75 / 2.00) — used by #15 for base rarity input range

Will be registered喺 Phase 5b after Section H ratification。

## Edge Cases

呢個 section 列出 22 個 explicitly-handled edge cases，按 7 個 categories 排列。每個 case 標明 condition + exact resolution + rationale。所有 cases 跨 Section B (Falsifiable Tests) / Section C (Rules) / Section D (Formulas) 已 verified — 唔重複 already-locked invariants，只 cover boundary scenarios。

### Input validation (EC-01 ~ EC-04)

- **EC-01 — If `workout_completed(completed_at_utc)` 收到 NaN / 負數 / 0**: Rule 4 `_passes_drift_gate` 入口 reject + `push_error` + `_rejected_events_count += 1`，state stays Ready。*Rationale*: GymSys server-side timestamp 永遠 > 0 (Unix epoch enforcement)；非法值 → 上游 contract violation，fail-loud 暴露 GymSys client bug 早期。
- **EC-02 — If `completed_at_utc` 喺 device wall-clock 之未來 > `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300`**: Rule 4 drift gate reject + `push_warning` + `_drift_rejected_count += 1`。*Rationale*: 玩家撥後 device clock 想 fake future workout 失敗；亦 catch GymSys backend clock skew bug。300s = mirror PersistenceLayer's same drift tolerance。
- **EC-03 — If `completed_at_utc` 喺 `_last_accepted_completed_at_utc` 之過去 (non-monotonic)**: Rule 4 monotonicity guard reject + `push_warning`。**Exception**: 若 `_last_accepted_completed_at_utc == 0` (first event after Booting / Reset)，accept。*Rationale*: GymSys backend 應該以 ascending timestamp order 發送 events；out-of-order 通常係 GymSys queue 處理 bug 或 client cache replay 異常。In-memory `_last_accepted_completed_at_utc` 跨 Booting reset (唔 persist)，所以 cold start 之後第一個 event 永遠 accept (避免 replay 後 false-reject)。
- **EC-04 — If `completed_at_utc` value 喺 epoch 邊界 (e.g. 1970-01-01)**: Formula 3 `local_calendar_date_from_utc` 計算 yields "1970-01-01" or similar — 但 Rule 4 drift gate 已 reject (device now ≠ 1970)，所以 epoch values 永遠唔會到 Formula 3。*Rationale*: defensive — epoch path 唔可能達到，但 Formula 3 仍 well-defined。

### State machine boundary (EC-05 ~ EC-09)

- **EC-05 — If `workout_completed` arrives during Booting**: Rule 3 routes into `_deferred_workout_event` single-slot. Booting → Ready transition (autoload `_ready()` 末段) → `_drain_deferred_if_any()` 觸發 normal handler。*Rationale*: scene re-load / hard refresh case — GymSys client 可能 boot 完先過 Streak (autoload position non-deterministic order — but ADR-006 Contract 4 sequential ordering: PersistenceLayer pos 1 → GSM pos 2 → GymSys pos 3 → Streak pos N+)。Defer + drain 保 reality event lossless。
- **EC-06 — If `workout_completed` arrives during Updating** (mid-`_write_streak_state_atomic`): Rule 3 routes into `_deferred_workout_event` (overwriting any earlier deferred — latest wins)。Current Updating completes (sync per persistence Rule 1)，then `_drain_deferred_if_any()` re-enters handler。*Rationale*: sync persistence write means no real concurrency；defensive defer 處理 GDScript signal coalescing edge cases。Latest-wins 因為 single workout = single calendar day，唔需要 queue 多個。
- **EC-07 — If `state_changed → SUSPENDED` fires during Updating mid-write**: Rule 11 routes any `_on_gsm_state_changed` calls **after** current Updating sync handler returns。Persistence pair (`streak.streak_count` + `streak.last_workout_date_local`) 已 atomic-flush 喺 Updating 返回前完成。Suspended entry 之後若有 in-flight `workout_completed` 已被 Rule 3 routed to `_deferred_workout_event`。*Rationale*: sync GDScript event loop = no race；唔需要 explicit lock。
- **EC-08 — If GSM `state_changed → SUSPENDED` payload 唔 contain `source_event` field**: Rule 11 sentinel check `payload.has_method("get") and payload.get("source_event") == "initial_state"` 失敗 → 視為 non-initial transition。**唔 reject**，正常 process。*Rationale*: GSM Contract 6 sentinel pattern 由 GSM ensure；本 system 唔可以假設 sentinel field 永遠存在 — defensive fallback to "treat as real transition"。
- **EC-09 — If Suspended → Ready transition 之後，`_deferred_workout_event` 包含一個 stale timestamp (e.g. 玩家 suspended 30 分鐘後 resume)**: Rule 11 `_drain_deferred_if_any()` re-enter handler → Rule 4 drift gate 重新 check (future_skew = stale_ts - now)。若 stale_ts 已超出 monotonicity gate or 已過時 → reject。若 legitimate (e.g. workout 真係 30 分鐘前發生) → accept normally。*Rationale*: Suspended 期間 device wall-clock 推進咗，但 `completed_at_utc` 來自 GymSys server timestamp (固定)，Rule 4 drift check 自動處理。

### bfcache / Web Export resume (EC-10 ~ EC-12)

- **EC-10 — If bfcache resume 後 `_last_accepted_completed_at_utc` in-memory 已 lost** (Godot autoload state 喺 bfcache 期間應該 preserved，但 defensive)：Rule 4 monotonicity guard 嘅 `_last_accepted_completed_at_utc == 0` fallback path 觸發 (accept first event after reset)。Subsequent events 重新建立 monotonicity baseline。*Rationale*: bfcache restore 失誤 worst case = 第一個 resume 之後嘅 event 唔做 monotonicity check (但仍做 future_skew + drift check) — risk 係 GymSys queue replay 可能 retro-credit 一個過去 event。Mitigation: Rule 6 same-day check 仍 catch 「same day already counted」case (因為 persistence `streak.last_workout_date_local` 已存住)。
- **EC-11 — If WASM hard-reload (page refresh) 期間 in-flight `_write_streak_state_atomic` 中斷 (count written, date NOT yet)**: 重啟後 Rule 2 Booting read 拎到 `_streak_count = N+1` 但 `_last_workout_date_local = old_date`。下次 `workout_completed` 同一 calendar day → Rule 6 same-day check returns `prior_streak` (which is N+1) → noop (avoid double-credit)。下次跨日 → Rule 6 chain check uses old_date → 若 gap_days(old_date, today) ≤ `STREAK_GRACE_GAP_DAYS` → streak = N+2 (correct continuation)；若 gap > grace → gap_reset to 1 (treats prior partial write as if N+1 was "real" prior streak)。*Rationale*: ordered write (count → date) 確保 partial-fail self-detecting；double-credit prevented；唯一 cost = 玩家可能 see streak inflated by 1 vs. reality (acceptable，因為 IDB atomic flush 99.9% case work，呢個 edge case rare)。
- **EC-12 — If browser tab refresh during Suspended state**: WASM hot reload → Streak autoload 重 boot → Rule 2 Booting reads persistence → `_state = Ready`。`_deferred_workout_event` in-memory 失蹤 — **acceptable loss**：因為 `_deferred_workout_event` 內容係未 process 嘅 future event，但同樣 event 會喺 GymSys backend 重 emit (GymSys Rule 14 idempotent commits)。*Rationale*: backend retry 補；本 system 唔 persist `_deferred_workout_event`，避免 IDB write 增加 frequency (Pillar 2 frictionless contract — Streak 唔可以加重 PersistenceLayer 寫負擔)。

### Cross-system race / dependency (EC-13 ~ EC-15)

- **EC-13 — If GymSys `workout_completed` fired before GSM autoload `_ready()` complete** (race despite ADR-006 Contract 4 sequential _ready): Rule 3 routes to `_deferred_workout_event` (Booting state guard)。Booting → Ready transition 喺 Rule 2 完成 GSM `connect_for_initial_state` 後 fire。*Rationale*: 唔 reject — preserve event。Per ADR-006 Contract 4，PersistenceLayer pos 1 → GSM pos 2 → GymSys pos 3 → Streak pos 4+，所以 Streak `_ready()` 入面 GymSys 已 ready；但 hot-reload / editor scenarios 唔保證。Defer + drain 防 race。
- **EC-14 — If `workout_completed` arrives before PersistenceLayer ready** (autoload position misconfiguration): Rule 2 Booting read 入口會直接 NPE 喺 `PersistenceLayer.read(...)` call。**Behavior**: autoload boot fail crashes — Godot autoload init crash = fatal。*Rationale*: 唔可以 silently fallback to in-memory only — 違反 Section B Pillar 1 dignity (silently lose persistence = silently lose streak)。Fail-loud at boot reveals autoload misconfiguration before any user data corruption。
- **EC-15 — If GSM 從未 emit initial state** (e.g. GSM crashed during own boot): Rule 2 `connect_for_initial_state(_on_gsm_state_changed)` registers handler but GSM never fires initial sentinel → Streak's `_on_gsm_state_changed` 永遠唔 fire。Streak stays喺 Ready state，照常 process `workout_completed` events (because Rule 3 唔 require GSM state read — only Rule 11 Suspended observer uses GSM state)。Suspended events 從不 fire → `_state` 永遠 Ready。*Rationale*: GSM 唔 ready 唔 block Streak — Streak 嘅 input edge 係 GymSys workout event，唔係 GSM state。Suspended observation 係 nice-to-have，唔係 hard contract。Mitigation: `tests/integration/streak/test_streak_without_gsm.gd` 驗證 streak 仍 functional。

### Timezone / DST boundary (EC-16 ~ EC-18)

- **EC-16 — If device timezone shifts mid-session** (e.g. flight crossing time zone, system clock auto-adjust): Rule 5 用 **locked** `_local_timezone_offset_minutes` (boot 時 read from persistence)，唔每次 read device timezone。Result: workout 同 calendar day boundary 跟 onboarding 鎖定 timezone，唔被 mid-session 改變影響。*Rationale*: predictable behavior over device-sync convenience。Player travelling timezones 需要 explicit `set_local_timezone_offset_minutes(new_offset)` call (Rule 1 future API) 重設。
- **EC-17 — If DST spring-forward 喺 workout 跨日嘅關鍵時刻**: Formula 2 `gap_days` 用 noon-anchored arithmetic (noon + N×86400 永遠 land 喺目標日 noon — DST 變動 ±1h 唔跨日;EG-4 前身 `next_calendar_day` 同款保護)。Result: streak day-boundary 不受 DST jolt 影響。*Rationale*: real-world timezone math 嘅 standard practice — noon anchoring 防 midnight ±1h 邊界 ambiguity。
- **EC-18 — If `streak.local_timezone_offset_minutes` value 喺 Persistence read 拎到 NaN / Array / 非-int**: Rule 2 `(tz_raw as int)` cast → Godot 4.6 GDScript invalid cast → 0 (numeric default) or null。If null → `_detect_device_timezone_offset_minutes()` fallback。*Rationale*: legacy persistence corruption recovery — device timezone fallback is acceptable default (Section B Pillar 1 dignity 唔嚴重 violated 因為 GymSys backend timestamp 仍係 UTC ground truth)。

### Persistence failure (EC-19 ~ EC-20)

- **EC-19 — If `PersistenceLayer.write("streak.streak_count", N+1)` returns `true` but actual IDB flush 失敗 silently** (PersistenceLayer Contract 11 VS-tier accept up to 1/10K loss rate): subsequent `critical_save_failed(error_code, key)` signal fires → Rule 10 catch → Failed state entry → in-memory cache continues serving last good value。**Risk window**: 喺 `write_completed` return `true` 同 `critical_save_failed` 之間 (1 frame ~ 16ms VS-tier)，玩家可能讀到 modifier 已 updated 但 disk 未 flush。*Rationale*: PersistenceLayer GDD 嘅 Contract 11 acceptable loss rate 喺本 system inherit；玩家極端 edge case (browser kill mid-frame) 可能漏 1 day credit — 接受呢個 tradeoff 為咗 Web Export performance。
- **EC-20 — If `PersistenceLayer.write("streak.streak_milestones_unlocked", [...], true)` 失敗 喺 Rule 7 milestone emit 之前**: Rule 7 erase append-attempt + return (halt further milestone checks)。`streak_milestone_reached` 唔 emit (correctness over UX 一致 — 唔可以 fake-emit milestone 然後 next boot disagree)。*Rationale*: persistence是 milestone unlock 嘅 source of truth — 信 the disk over the moment。下次 boot 後若 streak ≥ milestone 仍未 unlock，Rule 7 自動 retry emit (因為 `streak_milestones_unlocked` 仍未 include milestone)。

### Numerical boundary (EC-21 ~ EC-23)

- **EC-21 — If `streak.streak_count` value 已 overflow int (理論 ~2^31 = ~5.9 billion days)**: 唔可能達到 (玩家壽命 ~30,000 days max)。但 Formula 1 step function 喺 90+ tier 已 cap，所以 even theoretical overflow 都唔影響 modifier output。`streak_changed` signal payload 用 int — Godot 4.6 默認 int64 — no concern。*Rationale*: theoretical safety — 100-year-streak 仍係 36,500 << int64 ceiling。
- **EC-22 — If `streak.streak_milestones_unlocked: Array[int]` 增長到 5 entries (full set: [7, 14, 30, 60, 90])**: 之後 milestone check `has(m)` 永遠 true → 永遠 silent。Array 永不超過 5 entries (因為 `MILESTONE_THRESHOLDS` const 鎖死 5 個)。*Rationale*: Array size bounded by const — no unbounded growth risk。
- **EC-23(EG-4)— Grace boundary 精確行為**: gap == `STREAK_GRACE_GAP_DAYS`(default 3)→ `chain_continue`(streak += 1);gap == `STREAK_GRACE_GAP_DAYS + 1` → `gap_reset`(streak = 1)。gap == 0 case 不可達(same-day branch 先 short-circuit)。Degenerate knob check:`STREAK_GRACE_GAP_DAYS = 1` 時行為精確等於原版零-grace 語意(boundary 收返去 exact-next-day)。*Rationale*: off-by-one 喺 grace boundary = 玩家「啱啱守住條鏈」被誤判斷裂 — dignity contract 要求 predicate 精確(AC-40 binding)。

### Cross-reference verification

- **Section B Falsifiable Tests coverage**:
  - Test #1 (Sick Day): covered by Rule 7 emit-once-permanent + Rule 14 namespace isolation (milestone Array 永不 erase) → EC-22 verifies
  - Test #2 (Travel Week): covered by Rule 6 gap_reset to 1 + Rule 4 (no `streak_broken` signal emit) → no specific EC needed (invariant)
  - Test #3 (Phone-Lost): covered by Rule 12 + Q-O2 (GymSys retro-event delivery contract)
  - Test #4 (Numb Counter): covered by Interaction #4 (Streak no own visual) → no EC
  - Test #5 (Pay-to-Streak): covered by Rule 1 no-mutator + Rule 13 CI VIOLATIONS_MUTATOR → no EC
  - Test #6 (Long-Haul): covered by Rule 7 emit-once-permanent + EC-22
  - Test #7 (Clock Tamper): covered by Rule 4 drift gate + EC-02 + EC-03

- **Section D AC-D candidates coverage**:
  - AC-D1 (Formula 1 monotonicity): covered by Rule 8 step boundaries strictly non-decreasing
  - AC-D2 (Formula 1 cap): covered by Rule 8 hard cap at 2.00
  - AC-D3 (Formula 1 baseline): covered by Rule 8 default return 1.00
  - AC-D4 (Formula 2 DST robustness): covered by EC-17 + Formula 2 worked examples
  - AC-D5 (Step boundaries match milestones): covered by Rule 7 + Rule 8 const co-reference

- **Sister #5/#6/#7 edge cases — no duplicates**: 本 GDD edge cases 全部聚焦 cross-day temporal accumulation + timezone + GymSys event handling + persistence atomic pair — 同 #5 (particle pool / preset table) / #6 (shake / hit pause math) / #7 (camera tween / drag margin) 解耦，無 overlap。

## Dependencies

### Upstream Dependencies (本 system requires)

| # | System | Layer | Hard/Soft | Nature of dependency |
|---|--------|-------|-----------|----------------------|
| **#2** | GymSys Backend Client | Foundation / VS | **Hard (sole input edge)** | Subscribe `workout_completed(completed_at: int)` signal — Streak System 嘅唯一 input edge。Server-provided UTC Unix timestamp trusted over client wall-clock per GymSys AC-22。**Forbidden coupling**: 唔訂閱其他 6 個 GymSys signals (`workout_started` / `set_logged` / `rest_started` / `rest_ended` / `poll_failed` / `poll_recovered`) — scope discipline。Q-O2 開放：GymSys 是否 expose retro-workout event delivery for Phone-Lost case (Section B FR-1 ratification gate)。 |
| **#3** | PersistenceLayer | Foundation / VS | **Hard (state persistence)** | `read(key)` 喺 Booting state 拎四條 keys；`write(key, value, flush)` 喺 Updating state atomic-pair write streak_count + last_workout_date_local，independent flush for milestones Array；訂閱 `critical_save_failed(error_code, key)` 過濾 `streak.*` namespace 觸發 Failed state；引用 `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300` constant + `is_expired()` helper。Keys 自 owned: `streak.streak_count`, `streak.last_workout_date_local`, `streak.streak_milestones_unlocked`, `streak.local_timezone_offset_minutes`。Streak System 係 first cross-system consumer of `streak.*` namespace (per persistence Rule 12 reference)。 |
| **#1** | GameStateMachine | Foundation / VS | **Soft (Suspended observer only)** | Subscribe `state_changed` via `connect_for_initial_state` per ADR-006 Contract 6。**Only observes** Suspended ↔ non-Suspended transitions for Rule 11 cancel-write protection。其他 GSM gameplay states (Idle / WorkoutActive / RestPeriod / etc.) 唔影響 Streak — Streak 嘅 input event 嚟自 GymSys，唔嚟自 GSM。 |

**ADRs referenced (upstream constraints)**:

- **ADR-006 State Machine Contract** (Contract 4: autoload sequential `_ready`; Contract 6: `connect_for_initial_state`; Contract 7: race guard; Contract 9: `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS`) — ratified Proposed
- **ADR-003 Save State Strategy** — pending, FR-1/FR-2/FR-3 (Section B Risk Register) gated on ADR-003 ratification (retro-workout delivery contract + drift tolerance enforcement + cross-system rarity modifier discipline)
- **ADR-002 GymSys Integration Protocol** — pending, Q-O2 retro-workout window contract scope

### Downstream Dependents (systems that depend on 本 system)

**Per skill bidirectional consistency rule**: 以下 entries 必須喺對應 GDD 寫成時加入該 GDD 嘅「depends on: #8 Streak System」 句段。

| # | System | Layer | Tier | Status | Nature of dependency |
|---|--------|-------|------|--------|----------------------|
| **#15** | Loot Drop System | Core / Pre-MVP | **Pending GDD** | **Hard (rarity modifier consumer)** | Call `Streak.get_loot_rarity_modifier() -> float` 喺 base rarity 公式 (per Section B Pillar 3 supporting role: `base × volume × PR × streak`)。Subscribe `streak_milestone_reached(milestone: int)` trigger ritual-tier rarity unlock。Per Rule 6 + Rule 13 CI gate，#15 是唯一 production-code allowed caller of `get_loot_rarity_modifier()` (除 #29)。**Forbidden**: 唔可以 mutate streak state (Streak is read-only from #15 POV)。 |
| **#29** | Mirror Moment System | Polish / MVP | **Pending GDD** | **Hard (weekly progression marker)** | Call `Streak.get_current_streak() -> int` 為 weekly progression evaluator；subscribe `streak_milestone_reached(milestone: int)` 作為 weekly evolution trigger candidate。Mirror Moment 自己 own weekly evolution rules (combine streak + PR count + volume threshold)，Streak 只 contribute milestone marker。 |
| **#20** | Gym-Mode HUD | Presentation / MVP | **Pending GDD** | **Soft (display consumer)** | Call `Streak.get_current_streak() -> int` for HUD counter chip display；subscribe `streak_changed(new_streak: int, prior_streak: int)` for understated tick animation per Section B Falsifiable Test #4 binding。**Forbidden**: 唔 visualize milestone moments with DNF-style fanfare — milestone celebration delegated to #29 + #15。 |
| **#24** | Login / GymSys Connection UI | Presentation / MVP | **Pending GDD** | **Soft (failure display consumer)** | Subscribe `streak_persistence_failed(error_code: String)` signal → display blocking message「Storage unavailable — streak progress may not save until app restart」per Rule 10。 |
| **#27** | Onboarding Flow | Polish / Pre-MVP | **Pending GDD** | **Soft (timezone capture contract)** | 喺 first-launch onboarding 鎖定玩家 timezone offset → call Streak's future API `set_local_timezone_offset_minutes(offset_min: int)` (per Rule 1 future-reserved API + Q-O1)。**Open**: #27 GDD 尚未存在 — contract provisional pending #27 authoring。 |

**Provisional contract lock note**: 全部 5 個 downstream entries 喺其 GDD 未寫成前 unilaterally locked from Streak side。當 #15, #29, #20, #24, #27 GDDs 寫成時 expect contract delta — submit ADR if downstream needs Streak API change。Streak API 係 source of truth per Section C closed primitive contract。

### Bidirectional Consistency Check (next-revision requirements)

- **#1 GameStateMachine** (currently does NOT list #8)：next revision 必須 add #8 to 「Downstream Dependents — Soft dependents」table。Expected entry: 「**#8 Streak System** subscribes via `connect_for_initial_state` (ADR-006 Contract 6)；only observes Suspended transitions for Rule 11 cancel-write protection」。Same revision batch as #5/#6/#7 (now needs 4 entries: #5, #6, #7, #8)。
- **#2 GymSys Backend Client**: 加 #8 to 「Downstream Dependents」table。Expected: 「**#8 Streak System** subscribes to `workout_completed(completed_at: int)` signal — sole input edge for streak counter mutation」。
- **#3 PersistenceLayer**: 加 #8 to 「Consumer Systems」 table。Expected: 「**#8 Streak System** owns `streak.*` namespace; first cross-system reference of namespace convention」。

### Open Items (carry forward)

- **Q-F1 NEW**: #1 + #2 + #3 GDDs next revision 要加 #8 bidirectional dependency entries — defer to next `/consistency-check` pass or individual `/design-review` re-passes
- **Q-F2 NEW (= Q-O1)**: #27 Onboarding GDD authoring 鎖定 timezone capture contract for `streak.local_timezone_offset_minutes` write path
- **Q-F3 NEW (= Q-O2)**: ADR-002 GymSys Integration Protocol authoring 包括 retro-workout event delivery contract for Phone-Lost case (Section B FR-1)
- **Q-F4 NEW (= Q-O3)**: Section D Formula 1 step curve values (1.05 / 1.15 / 1.30 / 1.50 / 1.75 / 2.00) co-balance simulation with #15 Loot Drop System base rarity 公式 input range — defer to #15 GDD authoring

## Tuning Knobs

呢個 section 列出所有 designer / programmer-facing tunable values，安全範圍同 extreme behavior。9 個 owned knobs (6 step values + 1 thresholds + 1 timezone fallback flag + 1 grace gap [EG-4]) + cross-knob invariants。

### Owned by Streak System (designer-facing — designers 可 tune without code change)

| Knob | Default | Safe Range | Source / Used By | Too high (above safe range) | Too low (below safe range) |
|------|---------|------------|------------------|----------------------------|---------------------------|
| `MILESTONE_THRESHOLDS` | `[7, 14, 30, 60, 90]` | Each milestone ∈ `[3, 365]`; Array length ∈ `[3, 8]`; strictly ascending | Rule 7 + Rule 8 step boundaries | Each > 365 → milestone year-long achievable，玩家難以感受 progression cadence | Each < 3 → milestone 過早 emit，dilute Pillar 5 ritual moment dignity；Array < 3 entries → 唔夠 progression marker support #29 weekly evolution |
| `STREAK_GRACE_GAP_DAYS`(EG-4)| 3 | `[1, 4]` int | Rule 6 chain predicate + Formula 2 | > 4 →「持續」語意失效(一週練一次都唔斷,streak 軸同 #19 WORKOUT_COUNT 軸冗餘)| = 1 → 回復原版 daily-only(EG-4 問題重現:3x/week milestone 不可達 + daily junk-workout incentive,anti-Pillar 1)|
| `MODIFIER_AT_STREAK_0` | 1.00 | `[1.00, 1.00]` (locked baseline — `streak == 0` 永遠 1.00 per Section B) | Formula 1 baseline | N/A (locked = invariant) | N/A (locked = invariant) |
| `MODIFIER_AT_TIER_1` (1–6 days) | 1.05 | `[1.00, 1.20]` | Formula 1 tier 1 value | > 1.20 → "first workout" buff 過大，dilute milestone tier ritual feel (玩家「reset 後第一日就 +20%」感覺好 OP) | < 1.00 → 違反 monotonicity invariant (AC-D1) |
| `MODIFIER_AT_TIER_7` (7–13 days) | 1.15 | `[1.10, 1.30]` | Formula 1 tier 7 | > 1.30 → 同 tier 14 嘅 jump 太細 → step boundary feel mute | < 1.10 → 7-day milestone unlock 嘅 mechanical bonus 唔顯著，Pillar 3 binding 弱化 |
| `MODIFIER_AT_TIER_14` (14–29 days) | 1.30 | `[1.20, 1.50]` | Formula 1 tier 14 | > 1.50 → 同 tier 30 嘅 jump 太細 | < 1.20 → 違反 monotonicity if tier 7 = 1.30 |
| `MODIFIER_AT_TIER_30` (30–59 days) | 1.50 | `[1.40, 1.70]` | Formula 1 tier 30 | > 1.70 → 同 tier 60 嘅 jump 太細 | < 1.40 → 30-day milestone (monthly cadence) bonus 唔顯著 |
| `MODIFIER_AT_TIER_60` (60–89 days) | 1.75 | `[1.60, 1.90]` | Formula 1 tier 60 | > 1.90 → 同 cap 2.00 嘅 jump 太細 | < 1.60 → 違反 monotonicity |
| `MODIFIER_AT_TIER_90` (cap) | 2.00 | `[1.80, 2.50]` | Formula 1 hard cap | > 2.50 → Pillar 1 power explosion (long-streak 玩家 vs 短 streak 玩家差距太大，違反 anti-pillar #4 跨用戶 PVP 精神) | < 1.80 → cap 同 tier 60 jump 太細，long-haul 玩家 felt reward 不顯著 |

### Read-only by Streak (owned elsewhere — referenced for context)

| Knob | Owner | Used By Streak For |
|------|-------|---------------------|
| `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` (= 300) | #3 PersistenceLayer (Contract 9) | Rule 4 drift gate future-skew threshold |
| `GymSysBackendClient.workout_completed(completed_at: int)` signal | #2 GymSys Backend Client | Rule 2 subscription + Rule 3 handler input |
| `GameStateMachine.State.SUSPENDED` enum value | #1 GameStateMachine | Rule 11 Suspended state guard |
| `PersistenceLayer.IPersistence.write` `flush: bool` parameter | #3 PersistenceLayer | Rule 9 atomic-pair flush=true on second key |

### Knobs explicitly NOT exposed (compile-time constants — designer 改要 GDD revision)

呢啲 values 鎖死喺 Section C / Section D，**唔可以 runtime tune** — 改要：(1) propose Section C Rule revision，(2) update Rule 13 CI script if needed，(3) re-run FR-1/FR-2/FR-3 Risk Register playtest：

| Constant | Value | Why locked compile-time |
|----------|-------|------------------------|
| Streak input edge | GymSys `workout_completed` only | Section B Falsifiable Test #5 「Pay-to-Streak」locked Pillar 1 anti-pillar #2；改 = anti-pillar violation |
| Milestone emit-once-permanent contract | `streak_milestones_unlocked` Array 永不 erase | Section B Falsifiable Test #6 「Long-Haul」 locked Pillar 5 milestone ownership；改 = retroactive content loss possibility |
| Streak reset semantics | gap > `STREAK_GRACE_GAP_DAYS` → streak = 1 (NOT 0, NO `streak_broken` signal)(EG-4:grace 日數本身係 knob,reset-to-1-not-0 語意先係 locked)| Section B Falsifiable Test #2「Travel Week」 locked dignity framing；改 = punitive UX framing |
| Persistence write order | count → date → (flush) → milestones | Rule 9 atomic-pair semantics；改 = double-credit risk on partial fail |
| Persistence ban scope | Streak only writes `streak.*` namespace | Rule 14 namespace isolation + Pillar 1 dignity；改 = cross-system state pollution |
| Closed API surface | No public mutator method (read-only getters + signals) | Rule 1 + Section B Falsifiable Test #5 architectural enforcement |
| `_state` enum membership | `Booting`, `Ready`, `Updating`, `Suspended`, `Failed` (5 states) | Section C State table；改 = upstream of Section H AC test suite refactor |
| Noon-anchored DST arithmetic | `hour: 12` in `_gap_days` helper(EG-4 前身 `_is_next_calendar_day` 同款保護)| Formula 2 DST robustness invariant；改 = false-credit / false-loss spring-forward edge case |

### Tuning Knob Interaction Warnings (invariants — Section H AC binding)

以下 cross-knob invariants 必須喺所有 default + safe range boundary 上 hold；違反 = Section H AC fail：

1. **Monotonicity (Formula 1)**: `MODIFIER_AT_STREAK_0 ≤ MODIFIER_AT_TIER_1 ≤ MODIFIER_AT_TIER_7 ≤ MODIFIER_AT_TIER_14 ≤ MODIFIER_AT_TIER_30 ≤ MODIFIER_AT_TIER_60 ≤ MODIFIER_AT_TIER_90` — strict non-decreasing
   - At default: `1.00 ≤ 1.05 ≤ 1.15 ≤ 1.30 ≤ 1.50 ≤ 1.75 ≤ 2.00` ✓
   - At worst safe-range combination (e.g. tier_7 = 1.10, tier_14 = 1.20): 1.05 ≤ 1.10 ≤ 1.20 ≤ 1.40... still monotonic ✓
2. **Cap invariant (Formula 1)**: `MODIFIER_AT_TIER_90 ≤ 2.50` — hard Pillar 1 protection
   - At default: 2.00 ≤ 2.50 ✓
3. **Milestone thresholds ascending + bounded**: `MILESTONE_THRESHOLDS` strictly ascending, no duplicates, all ∈ [3, 365]
   - At default: `[7, 14, 30, 60, 90]` ✓
4. **Step boundary <-> milestone alignment**: Formula 1 step boundaries `{1, 7, 14, 30, 60, 90}` ⊇ `MILESTONE_THRESHOLDS` (milestones are step boundaries plus implicit s=1 baseline boundary)
5. **Grace bounds(EG-4)**: `STREAK_GRACE_GAP_DAYS` int ∈ `[1, 4]`
   - At default: 3 ∈ [1, 4] ✓;boundary 行為:gap == G → chain_continue,gap == G+1 → gap_reset(AC-40 binding)
   - At default: `[7, 14, 30, 60, 90]` ⊂ `{1, 7, 14, 30, 60, 90}` ✓
5. **Drift tolerance inheritance**: Streak uses PersistenceLayer's `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` constant (300) — same value, single source of truth
   - At default: `Streak.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS == PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS == 300` ✓ (no local override)

### Section H AC promotion candidates (from invariants above)

- **AC-G1**: Formula 1 monotonicity invariant at default + at worst safe-range combination
- **AC-G2**: `MODIFIER_AT_TIER_90 ≤ 2.50` cap invariant
- **AC-G3**: `MILESTONE_THRESHOLDS` ascending + no-duplicate + bounded invariant
- **AC-G4**: `Streak.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS == PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` cross-system consistency

## Visual/Audio Requirements

**N/A — pure infrastructure。** Streak System 唔 own 任何 visual / audio output。所有 visual / audio expression 由 downstream consumers 處理：

- Streak counter display (number chip + flame icon) 由 #20 Gym-Mode HUD render
- `streak_changed(new_streak, prior_streak)` tick animation 由 #20 HUD 接收 signal 後執行 understated dignified tick (per Section B Falsifiable Test #4 "Numb Counter" binding — no fanfare, low-key tick + 低調 chime via #4 AudioManager)
- `streak_milestone_reached(milestone)` celebration moment 由 #29 Mirror Moment 觸發 (Pillar 5 weekly evolution marker) + #15 Loot Drop System 觸發 rarity-tier ritual moment (Pillar 3 cinematic loot reveal)
- Streak reset (gap_reset → `_streak_count == 1`) 嘅 visual reaction 由 #20 HUD 渲染 — **必須** dignity-style (per Section B Falsifiable Test #2 "Travel Week" binding — no punitive copy, no guilt-trip popup)
- `streak_persistence_failed` blocking error message 由 #24 Login / GymSys Connection UI 觸發 (per Rule 10 + Section B Pillar 1 dignity)

Streak autoload 嘅 implementation 內絕對唔可以 reference `AudioStreamPlayer`、`GPUParticles2D`、`Sprite2D`、`Tween`、`AnimationPlayer`、或任何 visual / audio node。Streak System 嘅唯一 output 係 read-only getter values + 3 signals — pure data layer。

**Debug overlay (dev-only)**: 建議實作 `DebugStreakOverlay` Control node (gated by `OS.is_debug_build()`) display：current `_streak_count`、`_state` enum、`_streak_milestones_unlocked` Array、`_last_workout_date_local` ISO date、`_drift_rejected_count` counter、`_deferred_workout_event` slot value。**唔屬於 production UI**。

## UI Requirements

本 system **唔 own 任何 UI surface** — Streak autoload 係 backend Foundation service，唔 render counter chip / HUD overlay / milestone celebration / modal / error toast。所有 UI 由其他 systems 各自處理。

### No UI surface owned (production)

- Streak counter chip + flame icon display 由 #20 Gym-Mode HUD 處理 (subscribes `streak_changed` for understated tick animation per Section B Falsifiable Test #4 binding)
- Milestone celebration moment 由 #15 Loot Drop System (rarity-tier ritual) + #29 Mirror Moment (weekly progression marker) 各自渲染 (subscribe `streak_milestone_reached`)
- Streak reset (gap_reset)** 唔顯示** 獨立 popup / toast — #20 HUD 接 `streak_changed(1, N)` 後自行決定 silent reset animation (NOT punitive — Section B Falsifiable Test #2 binding)
- Persistence failure blocking error message 由 #24 Login / GymSys Connection UI 處理 (subscribe `streak_persistence_failed` per Rule 10)
- 「Reduce Streak Visual Intensity」/ "降低 Streak 顯示" accessibility toggle (if needed) 屬 #20 HUD 嘅 motion accessibility cluster (與 #6 ScreenEffects motion_intensity slider 並列) — Streak autoload 唔 own toggle

### Future surface: timezone capture handshake (Q-O1 reservation)

預留 backend API contract for future #27 Onboarding Flow GDD：

| Element | Specification |
|---------|---------------|
| Owner | #27 Onboarding Flow GDD (pending — first-launch timezone capture) |
| Backend contract | `Streak.set_local_timezone_offset_minutes(offset_min: int) -> bool` (future-reserved API per Rule 1) |
| Default if未 called | Rule 2 silent fallback to `_detect_device_timezone_offset_minutes()` (device timezone — acceptable per Pillar 1 because GymSys backend UTC timestamp 仍係 ground truth) |
| When called | Persisted to `streak.local_timezone_offset_minutes` via `IPersistence.write(..., flush=true)`；rejected if `offset_min ∉ [-720, 840]` IANA range |
| UI label (suggested) | 「你嘅時區 / Time zone」 (single picker dropdown — 標準 IANA timezone list) |
| UI hint (suggested) | 「Streak 嘅每日計算用呢個時區做 boundary。搬屋換時區可以喺 Settings 改 — 過去 streak 紀錄唔受影響」 |

> **📌 UX Flag — Timezone capture handshake**: 呢個 system 預留 1 個未來 player-facing UI requirement (timezone picker)。喺 Phase 4 (Pre-Production)，run `/ux-design` to create UX spec for **#27 Onboarding Flow — Timezone Capture Step** **before** writing epics. Stories that reference呢個 toggle 應該 cite `design/ux/onboarding-timezone.md`，**唔好** cite 本 GDD directly. 本 GDD 只 own backend contract (setter API + persistence key + behaviour spec)，不 own visual chrome / placement / interaction design。
>
> Note this in the systems index for #27 Onboarding Flow when added。

## Acceptance Criteria

呢個 section 列出 **33 個 acceptance criteria** binding to Sections C-G。Test type / gate level / source 全 enumerated。**Breakdown: 28 BLOCKING + 2 ADVISORY + 3 ADR-003 RATIFICATION-GATED**。

### Core API & Validation (Rule 1, 4)

- **AC-01**: GIVEN Streak autoload in Ready state, WHEN introspect public methods via `get_method_list()` + signals via `get_signal_list()`, THEN exactly 5 public methods (`get_current_streak`, `get_loot_rarity_modifier`, `is_milestone_unlocked`, `get_unlocked_milestones`, `get_last_workout_date_local`) + 3 signals (`streak_changed`, `streak_milestone_reached`, `streak_persistence_failed`) — **no mutator method (`set_*` / `increment_*` / `force_*` / `restore_*` / `gift_*`) present**, all other methods prefixed `_`。Source: Rule 1, Falsifiable Test #5 | Type: Integration | Gate: BLOCKING | File: `tests/integration/streak/streak_api_surface_test.gd`
- **AC-02**: GIVEN Ready state with `_streak_count == 5`, WHEN `_on_workout_completed(completed_at_utc=NaN)` OR `_on_workout_completed(-1)` OR `_on_workout_completed(0)` called, THEN Rule 4 `_passes_drift_gate` rejects + `push_error` emitted + `_rejected_events_count += 1`，`_streak_count` 維持 5，state stays Ready，no signal emit。Source: Rule 1, Rule 4, EC-01 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_validation_test.gd`
- **AC-03**: GIVEN Ready state with `device_now_utc=1748275200`, WHEN `_on_workout_completed(completed_at_utc=1748275801)` called (601s in future, > `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS=300`), THEN drift gate rejects + `push_warning` emitted + `_drift_rejected_count += 1`，`_streak_count` 不變。Source: Rule 4, EC-02, Falsifiable Test #7 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_drift_gate_test.gd`
- **AC-04**: GIVEN Ready state with `_last_accepted_completed_at_utc=1748275200`, WHEN `_on_workout_completed(1748275000)` called (200s before last accepted, monotonicity violation), THEN reject + `push_warning` + `_drift_rejected_count += 1`，`_streak_count` 不變。GIVEN cold-start (`_last_accepted_completed_at_utc==0`), WHEN any past-but-positive timestamp arrives, THEN accept (mono guard skipped on first event)。Source: Rule 4, EC-03 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_monotonicity_test.gd`

### Booting (Rule 2)

- **AC-05**: GIVEN PersistenceLayer Ready with `streak.streak_count=5`, `streak.last_workout_date_local="2026-05-25"`, `streak.streak_milestones_unlocked=[7]`, `streak.local_timezone_offset_minutes=480`, WHEN Streak autoload `_ready()` runs, THEN exactly 4 `PersistenceLayer.read()` calls fired in order (count → date → milestones → timezone), `_streak_count==5`, `_last_workout_date_local=="2026-05-25"`, `_streak_milestones_unlocked==[7]`, `_local_timezone_offset_minutes==480`，GSM `connect_for_initial_state(_on_gsm_state_changed)` called exactly 1 time, `_state == State.READY` within 1 frame。Source: Rule 2 | Type: Integration | Gate: BLOCKING | File: `tests/integration/streak/streak_booting_test.gd`
- **AC-06**: GIVEN Streak autoload source `src/autoload/streak.gd`, WHEN grep for `GameStateMachine\.state_changed\.connect\s*\(`, THEN zero matches — only `GameStateMachine\.connect_for_initial_state\s*\(` matches (ADR-006 Contract 6)。Source: Rule 2, ADR-006 Contract 6 | Type: Static | Gate: BLOCKING | File: `tests/integration/streak/streak_gsm_subscription_test.gd`
- **AC-07**: GIVEN PersistenceLayer Ready with all four `streak.*` keys returning `null` (first launch), WHEN Streak `_ready()` runs, THEN `_streak_count==0`, `_last_workout_date_local==""`, `_streak_milestones_unlocked==[]`, `_local_timezone_offset_minutes` falls back to `_detect_device_timezone_offset_minutes()` return value (signed int from `Time.get_time_zone_from_system().bias`)，`get_current_streak()` returns 0，`get_loot_rarity_modifier()` returns 1.00。Source: Rule 2, Rule 8 baseline | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_first_launch_test.gd`

### State Machine (Rules 3, 11)

- **AC-08**: GIVEN Booting state with `_deferred_workout_event==0`, WHEN `_on_workout_completed(1748275200)` arrives mid-Booting, THEN `_deferred_workout_event==1748275200`, no persistence write, no signal emit; subsequent Booting → Ready transition triggers `_drain_deferred_if_any()` → handler re-entry with same timestamp → normal Updating cycle。Source: Rule 3, EC-05 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_deferred_drain_test.gd`
- **AC-09**: GIVEN Suspended state with `_deferred_workout_event==0`, WHEN two `_on_workout_completed(t1=1748275200)` then `_on_workout_completed(t2=1748275800)` arrive during Suspended, THEN `_deferred_workout_event==1748275800` (latest wins, prior dropped, `push_warning` emitted on the dropped event)，`_streak_count` 不變直到 GSM Suspended → non-Suspended transition fires Rule 11 drain → handler re-enters with t2 only。Source: Rule 3 single-slot latest-wins, Rule 11, EC-06 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_deferred_latest_wins_test.gd`
- **AC-10**: GIVEN Ready state with `_streak_count==3`, WHEN `PersistenceLayer.critical_save_failed.emit("QUOTA_EXCEEDED", "streak.streak_count")` fires, THEN `_state == State.FAILED`, `streak_persistence_failed("PERSIST_LAYER_FAIL:QUOTA_EXCEEDED:streak.streak_count")` emitted exactly 1 time; subsequent `critical_save_failed` for `streak.*` keys does NOT re-emit (per Rule 10「once per session」)。`get_current_streak()` continues returning 3 (in-memory cache preserved)。Source: Rule 10, EC-19 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_failed_state_test.gd`
- **AC-11**: GIVEN PersistenceLayer emits `critical_save_failed("DISK_FULL", "gsm.session_id")` (NON-streak namespace), WHEN Streak's `_on_persistence_critical_save_failed` handler invoked, THEN `key.begins_with("streak.")` filter returns false → no state change, no signal emit, `_state` stays Ready。Source: Rule 10, Rule 14 namespace isolation | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_failed_namespace_filter_test.gd`

### Streak Math (Rules 5, 6, Formula 2-3)

- **AC-12**: GIVEN Ready state with `_streak_count==5`, `_last_workout_date_local=="2026-05-26"`, `_local_timezone_offset_minutes==480`, WHEN `_on_workout_completed(completed_at_utc=1748275200)` arrives (UTC `2026-05-26 16:00` + offset 480min → local `2026-05-27 00:00`), THEN Rule 6 classifies as `chain_continue` (gap=1 ≤ G)，∴ `_compute_new_streak` returns 6，`streak_changed.emit(6, 5)` fires exactly 1 time, persistence written via Rule 9 atomic order。Source: Rule 5, Rule 6, Formula 2-3 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_next_day_test.gd`
- **AC-13**: GIVEN Ready state with `_streak_count==5`, `_last_workout_date_local=="2026-05-26"`, WHEN second `_on_workout_completed(...)` arrives same local calendar day (workout_date_local resolves to `"2026-05-26"`), THEN Rule 6 returns `same_day` → handler short-circuits before `_write_streak_state_atomic` → no persistence write, `streak_changed` NOT emitted, `_streak_count` 維持 5。Source: Rule 6 idempotent, EC-06 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_same_day_idempotent_test.gd`
- **AC-14**: GIVEN Ready state with `_streak_count==45`, `_last_workout_date_local=="2026-05-25"`, `_streak_milestones_unlocked==[7,14,30]`, WHEN `_on_workout_completed(...)` arrives with workout_date_local `"2026-05-30"` (5-day gap > `STREAK_GRACE_GAP_DAYS`=3 — EG-4), THEN Rule 6 returns `gap_reset` → `_streak_count == 1` (NOT 0), `streak_changed.emit(1, 45)` fires exactly 1 time, **NO `streak_broken` signal exists / no punitive signal emit**, `_streak_milestones_unlocked` 維持 `[7,14,30]` (Rule 7 emit-once-permanent)。Source: Rule 6, Rule 7, Falsifiable Test #2 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_gap_reset_test.gd`
- **AC-15**: GIVEN fresh boot with `_streak_count==0`, `_last_workout_date_local==""`, WHEN `_on_workout_completed(1748275200)` arrives, THEN Rule 6 returns `first_workout` → `_streak_count == 1`, `streak_changed.emit(1, 0)` fires exactly 1 time, modifier flips from 1.00 to 1.05 (Formula 1 tier 1)。Source: Rule 6 first-workout branch, Formula 1 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_first_workout_test.gd`
- **AC-16**: GIVEN `_local_timezone_offset_minutes==600` (Sydney UTC+10, locked at onboarding), `prior_date=="2026-10-03"`, WHEN workout occurs spanning DST spring-forward (UTC `2026-10-04 14:50` and again UTC `2026-10-04 18:00`), THEN noon-anchored arithmetic in `_gap_days` yields `chain_continue` (gap=1) classification for first event (streak 1 → 2) and `same_day` for second (streak stays 2) — no false-credit / false-loss from DST ±1h boundary。Source: Rule 5, Rule 6, Formula 2 worked example, EC-17 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_dst_robustness_test.gd`

### Milestones (Rule 7, Formula 1)

- **AC-17**: GIVEN Ready state with `_streak_count==6`, `_streak_milestones_unlocked==[]`, WHEN workout increments to 7, THEN `_streak_milestones_unlocked` becomes `[7]` (Array append BEFORE signal emit per Rule 7), `PersistenceLayer.write("streak.streak_milestones_unlocked", [7], true)` returns true, `streak_milestone_reached.emit(7)` fires exactly 1 time。GIVEN streak later resets to 1 then grows back to 7, WHEN milestone check runs, THEN `has(7)==true` → emit NOT fired (Rule 7 emit-once-permanent contract)。Source: Rule 7, Falsifiable Test #6 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_milestone_emit_once_test.gd`
- **AC-18**: GIVEN Ready state with `_streak_count==6`, `_streak_milestones_unlocked==[]`, WHEN `_on_workout_completed` arrives via retro-credit path causing `new_streak == 15` (skipping over 7-day boundary in single tick — defensive batch case), THEN `_check_and_emit_milestones` emits `streak_milestone_reached(7)` THEN `streak_milestone_reached(14)` in ascending order — both Array-appended + persisted before respective emit。Source: Rule 7 multi-milestone ascending | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_milestone_multi_test.gd`
- **AC-19 [AC-D5 binding]**: GIVEN `MILESTONE_THRESHOLDS=[7,14,30,60,90]` (Rule 7 const) AND Formula 1 step boundaries `{1,7,14,30,60,90}`, WHEN test asserts set membership, THEN `MILESTONE_THRESHOLDS ⊂ Formula1_step_boundaries` AND each `m ∈ MILESTONE_THRESHOLDS` corresponds to a `modifier(m)` step jump (1.05→1.15→1.30→1.50→1.75→2.00) — alignment invariant。Source: AC-D5, Rule 7 + Rule 8 co-reference | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_milestone_step_alignment_test.gd`
- **AC-20 [AC-D1 binding]**: GIVEN `streak_count` values `[0, 1, 6, 7, 13, 14, 29, 30, 59, 60, 89, 90, 91, 365, 999]`, WHEN `get_loot_rarity_modifier()` called for each, THEN return values `[1.00, 1.05, 1.05, 1.15, 1.15, 1.30, 1.30, 1.50, 1.50, 1.75, 1.75, 2.00, 2.00, 2.00, 2.00]` — monotonically non-decreasing across all step boundaries (∀ s₁≤s₂ → modifier(s₁) ≤ modifier(s₂))。Source: AC-D1, Formula 1 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_modifier_monotonicity_test.gd`
- **AC-21 [AC-D2 binding]**: GIVEN `streak_count` values `[90, 100, 365, 9999, 2147483647]`, WHEN `get_loot_rarity_modifier()` called, THEN all return exactly `2.00` — hard cap enforced (Pillar 1 power explosion guard)。Source: AC-D2, Formula 1 cap | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_modifier_cap_test.gd`
- **AC-22 [AC-D3 binding]**: GIVEN `_streak_count == 0` (fresh boot OR post-gap-reset frame before any workout commits), WHEN `get_loot_rarity_modifier()` called, THEN return value is exactly `1.00` — baseline at zero。Source: AC-D3, Formula 1 baseline | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_modifier_baseline_test.gd`

### Persistence (Rules 9, 10, 14)

- **AC-23**: GIVEN MockPersistenceLayer with write spy, WHEN `_write_streak_state_atomic(new_streak=6, new_date_local="2026-05-26")` executes, THEN spy records exactly two writes in order: (1) `("streak.streak_count", 6, flush=false)`, (2) `("streak.last_workout_date_local", "2026-05-26", flush=true)` — order + flush flags both verified。Source: Rule 9 atomic write order | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_persistence_order_test.gd`
- **AC-24**: GIVEN `_streak_count==5`, mocked PersistenceLayer where `write("streak.last_workout_date_local", ...)` returns `false`, WHEN `_write_streak_state_atomic(6, "2026-05-26")` called, THEN rollback fires: `PersistenceLayer.write("streak.streak_count", 5, true)` invoked to restore prior value, `_enter_failed_state("STREAK_DATE_WRITE_FAIL")` triggers, `_state == State.FAILED`, `streak_changed` NOT emitted, in-memory `_streak_count` 維持 5。Source: Rule 9 rollback, Rule 10 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_persistence_rollback_test.gd`
- **AC-25 [Rule 14 namespace isolation]**: GIVEN MockPersistenceLayer write spy attached to Streak autoload, WHEN full lifecycle exercised (Booting reads → multiple `_on_workout_completed` events → milestone unlock → Failed state entry attempt), THEN spy records confirm ALL `write()` / `read()` / `delete()` keys 100% match `^streak\.` regex — zero touches of `gsm.*` / `gym.*` / `_internal.*` / any other namespace。Source: Rule 14, Falsifiable Test #5 architectural enforcement | Type: Integration | Gate: BLOCKING | File: `tests/unit/streak/streak_namespace_isolation_test.gd`
- **AC-26**: GIVEN Failed state entered via `_enter_failed_state("REASON_A")`, WHEN second `_enter_failed_state("REASON_B")` called within same session, THEN early-return on `_state == State.FAILED` check → `streak_persistence_failed` NOT re-emitted, `push_error` NOT duplicated。Failed state remains sticky until session restart — no auto-recovery code path exercised。Source: Rule 10 sticky | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_failed_sticky_test.gd`

### CI Enforcement (Rule 13)

- **AC-27**: GIVEN repo source tree, WHEN `tools/ci/check_streak_callers.gd` runs via `godot --headless --script`, THEN scans all `.gd` files OUTSIDE `WHITELIST_PATHS_LOOT_RARITY = ["src/gameplay/loot/", "src/gameplay/mirror_moment/", "src/autoload/streak.gd", "tests/"]` for `Streak\.get_loot_rarity_modifier\s*\(` pattern. Zero matches required; violation → exit(1) blocking。**FR-3 binding**: enforces #15 + #29 whitelist。Source: Rule 13, FR-3 | Type: Static / CI | Gate: BLOCKING | File: `tools/ci/check_streak_callers.gd` + `tests/unit/ci/check_streak_callers_test.gd`
- **AC-28**: GIVEN repo source tree, WHEN `tools/ci/check_streak_callers.gd` runs, THEN scans ALL `.gd` files for mutator violation patterns: `Streak\.set_streak_count\s*\(`, `Streak\.increment_streak\s*\(`, `Streak\.force_streak\s*\(`, `Streak\.restore_streak\s*\(`, `Streak\.gift_day\s*\(`. Zero matches required; any match → exit(1) blocking (Pay-to-Streak architectural breach)。Source: Rule 13, Falsifiable Test #5 | Type: Static / CI | Gate: BLOCKING | File: `tools/ci/check_streak_callers.gd` + `tests/unit/ci/check_streak_mutator_ban_test.gd`
- **AC-29**: GIVEN repo source tree, WHEN `tools/ci/check_streak_callers.gd` runs, THEN scans paths OUTSIDE `WHITELIST_NAMESPACE_PATHS = ["src/autoload/streak.gd"]` for `PersistenceLayer\.write\(\s*"(?!streak\.)` AND `PersistenceLayer\.delete\(\s*"(?!streak\.)` (negative lookahead for non-streak namespace writes from streak code). Zero matches required from `streak.gd`; any match → exit(1) blocking (namespace pollution)。Source: Rule 13, Rule 14 | Type: Static / CI | Gate: BLOCKING | File: `tools/ci/check_streak_callers.gd`

### Cross-knob Invariants (Section G)

- **AC-30 [AC-G1 binding]**: GIVEN safe-range corner combinations of `MODIFIER_AT_TIER_*` knobs (e.g. tier_1=1.20, tier_7=1.10) which would VIOLATE monotonicity, WHEN `_validate_modifier_curve_monotonicity()` boot-time invariant check runs (or test asserts default + worst-corner cases), THEN at default `[1.00, 1.05, 1.15, 1.30, 1.50, 1.75, 2.00]` strictly non-decreasing ✓; at violation corner asserted to fail → push_error + boot abort (defensive)。Source: AC-G1, Tuning Knob invariant #1 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_knob_invariants_test.gd`
- **AC-31 [AC-G2 binding]**: GIVEN any knob configuration within safe ranges, WHEN read `MODIFIER_AT_TIER_90`, THEN `MODIFIER_AT_TIER_90 ≤ 2.50` (hard Pillar 1 power-explosion cap)。At default: 2.00 ≤ 2.50 ✓。Source: AC-G2, Tuning Knob invariant #2 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_knob_invariants_test.gd`
- **AC-32 [AC-G3 binding]**: GIVEN any `MILESTONE_THRESHOLDS` knob value, WHEN test asserts (a) strictly ascending order, (b) no duplicate entries, (c) all elements `∈ [3, 365]`, (d) Array length `∈ [3, 8]`, THEN all 4 conditions hold. At default `[7, 14, 30, 60, 90]` ✓。Source: AC-G3, Tuning Knob invariant #3 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/streak_knob_invariants_test.gd`
- **AC-33 [AC-G4 binding]**: GIVEN Streak autoload + PersistenceLayer both Ready, WHEN test reads `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS` from both modules' constants (or from Streak's drift-gate runtime reference to `PersistenceLayer.WALL_CLOCK_DRIFT_TOLERANCE_SECONDS`), THEN value === 300 in both — no local override defined in `src/autoload/streak.gd` (grep verify: zero `const WALL_CLOCK_DRIFT_TOLERANCE_SECONDS =` matches in streak.gd)。Source: AC-G4, ADR-006 Contract 9, FR-2 binding | Type: Static / Integration | Gate: BLOCKING | File: `tests/integration/streak/streak_drift_tolerance_consistency_test.gd`

### Falsifiable Test Direct Bindings

- **AC-34 [Falsifiable Test #1 — Sick Day, Falsifiable Test #6 — Long-Haul]**: GIVEN `_streak_count==45`, `_streak_milestones_unlocked==[7,14,30]` persisted, simulated `inventory_keys` list `["epic_gloves_d30", "zone_alpha_unlock"]` (owned by #15 / external — held only as test fixture observation), WHEN streak gap-reset cascade fires (workout arrives Day 50 with `prior_date=="2026-04-12"` → 38-day gap), THEN `_streak_count == 1`, `_streak_milestones_unlocked == [7,14,30]` (Array unchanged), modifier drops to 1.05; test additionally asserts the simulated inventory fixture is NOT touched by Streak code (Streak owns zero inventory writes per Rule 14)。Source: Falsifiable Test #1, Falsifiable Test #6, Rule 7, Rule 14 | Type: Integration | Gate: BLOCKING | File: `tests/integration/streak/streak_sick_day_long_haul_test.gd`
- **AC-35 [Falsifiable Test #2 — Travel Week]**: GIVEN `_streak_count==60`, `_streak_milestones_unlocked==[7,14,30,60]`, WHEN player returns after 7-day gap and `_on_workout_completed(...)` fires, THEN (a) `_streak_count == 1`, (b) `streak_changed.emit(1, 60)` fires exactly 1 time, (c) **NO `streak_broken` signal exists in `streak.gd` signal list** (grep verify — `signal streak_broken` zero matches), (d) no `push_warning` / `push_error` containing strings matching `/lost.*streak|disappointed|let.*down|punish/i`。Source: Falsifiable Test #2, Rule 6 reset-to-1, Interaction #4 | Type: Integration | Gate: BLOCKING | File: `tests/integration/streak/streak_travel_week_test.gd`
- **AC-36 [Falsifiable Test #4 — Numb Counter, advisory cross-system playtest]**: GIVEN VS-tier playtest panel (n ≥ 5) on baseline device, WHEN streak counter ticks 22 → 23 via real workout event from GymSys client, THEN ≥ 80% panelists describe HUD reaction as「low-key tick / understated」(NOT「fanfare / popup / 大型 VFX」). **Note**: Streak System itself emits no VFX/SFX; this AC validates the **caller-side** dignity-style HUD render in #20 Gym-Mode HUD when it lands. Streak side is covered by Interaction #4 (no own visual) — this AC binds when #20 HUD GDD authored。Source: Falsifiable Test #4, Interaction #4 | Type: Visual | Gate: ADVISORY | File: `production/qa/evidence/falsifiable_numb_counter_playtest.md` (pending #20 GDD)

### ADR-003 RATIFICATION-GATED (3 ACs)

- **AC-37 [FR-1, Risk Register binding — Phone-Lost retro-credit contract]**: GIVEN GymSys backend retro-workout window query API specified in ADR-002 / ADR-003 (pending), WHEN integration test scenario: Day 30 workout occurs but `phone_offline=true`, Day 32 player reconnects, backend delivers retro `workout_completed(completed_at_utc=Day30_timestamp)` then current `workout_completed(completed_at_utc=Day32_timestamp)`, THEN Streak's Rule 4 monotonicity gate accepts both in order (Day30 < Day32), Rule 6 yields `chain_continue` (prior was Day 29, gap=1) → streak goes 29 → 30 → then Day32 event gap=2 ≤ G → `chain_continue` → 31(EG-4:原版係 gap_reset)— net result matches ADR-003 ratification spec for the retro-credit window contract. **AC structure locked**; exact pass criteria fill-in-blank pending ADR-003 ratification。Source: Risk Register FR-1, Rule 12 provisional, Falsifiable Test #3 | Type: Integration | Gate: ADR-003 RATIFICATION-GATED | File: `tests/integration/streak/streak_phone_lost_retro_test.gd`
- **AC-38 [FR-2, Risk Register binding — drift tolerance false-positive rate]**: GIVEN VS-tier playtest with telemetry instrumented to count `_drift_rejected_count` increments tagged `cause=future_skew_>300s`, WHEN measured over ≥ 100 baseline-device sessions across geographic regions (UTC offset diversity), THEN false-positive reject rate ≤ threshold defined in **ADR-003 (pending ratification)** (acceptable rate per Pillar 1 dignity / Phone-Lost retro path). If exceeded → fallback: introduce backend-timestamp comparison ground truth, client-only drift gate downgrades to advisory `push_warning` (no reject)。Source: Risk Register FR-2, Rule 4, EC-02 | Type: Performance | Gate: ADR-003 RATIFICATION-GATED | File: `tests/performance/streak/drift_gate_false_positive_test.md` (telemetry analysis doc)
- **AC-39 [FR-3, Risk Register binding — cross-system rarity modifier discipline]**: GIVEN expanded CI gate `tools/ci/check_streak_callers.gd` covering ALL future system paths (e.g. `src/gameplay/stats/`, `src/gameplay/abilities/`, `src/gameplay/pr/`, `src/gameplay/zones/`), WHEN scanned, THEN any `Streak.get_loot_rarity_modifier()` call OUTSIDE `WHITELIST_PATHS_LOOT_RARITY = ["src/gameplay/loot/", "src/gameplay/mirror_moment/", "src/autoload/streak.gd", "tests/"]` → exit(1) blocking. **Q-O3 resolved (post-ratification)**: whitelist explicit, requires PR review for any expansion. ADR-003 ratification confirms #15 + #29 are the only authorized callers。Source: Risk Register FR-3, Rule 13 | Type: Static / CI | Gate: ADR-003 RATIFICATION-GATED | File: `tools/ci/check_streak_callers.gd` + `tests/unit/ci/streak_caller_whitelist_test.gd`

### EG-4 Amendment AC(2026-06-08)

- **AC-40 [EC-23 / Tuning Knob invariant #5 binding — grace boundary]**: GIVEN `STREAK_GRACE_GAP_DAYS == 3` (default) and Ready state with `_streak_count==5`, prior date D, WHEN workout arrives at (a) D+1 / (b) D+2 / (c) D+3, THEN each yields `chain_continue` → streak 6 (boundary inclusive); WHEN instead workout arrives at (d) D+4, THEN `gap_reset` → streak 1。Additionally GIVEN `STREAK_GRACE_GAP_DAYS == 1` (degenerate knob floor), THEN behavior is exactly the pre-EG-4 zero-grace semantics (only D+1 continues)。Source: EG-4 adjudication, Rule 6, Formula 2, EC-23 | Type: Logic | Gate: BLOCKING | File: `tests/unit/streak/test_calendar_formulas.gd`

### Total count + breakdown

**34 ACs total** (qa-lead synthesis + 1 main-session math fix to AC-12 worked example + EG-4 amendment AC-40):
- **29 BLOCKING**: AC-01 to AC-35 + AC-40, excluding AC-36/37/38/39
- **2 ADVISORY**: AC-36 (Numb Counter perceptual playtest, gated on #20 HUD GDD)
- **3 ADR-003 RATIFICATION-GATED**: AC-37 (FR-1 Phone-Lost retro-credit), AC-38 (FR-2 drift tolerance FPR), AC-39 (FR-3 caller whitelist expansion)

### Coverage Map

| Section | Source items | ACs binding | Coverage |
|---------|--------------|-------------|----------|
| C — Rule 1 (closed API) | 1 rule | AC-01 | 1/1 ✓ |
| C — Rule 2 (Booting) | 1 rule | AC-05, 06, 07 | 3/1 ✓ over |
| C — Rule 3 (handler skeleton) | 1 rule | AC-08, 09 | 2/1 ✓ over |
| C — Rule 4 (drift gate) | 1 rule | AC-02, 03, 04 | 3/1 ✓ over |
| C — Rule 5 (local-day calc) | 1 rule | AC-12, 16 | 2/1 ✓ over |
| C — Rule 6 (chain-continuation,EG-4) | 1 rule | AC-12, 13, 14, 15, 16, 40 | 6/1 ✓ over |
| C — Rule 7 (milestones) | 1 rule | AC-17, 18, 19 | 3/1 ✓ over |
| C — Rule 8 (modifier curve) | 1 rule | AC-20, 21, 22 | 3/1 ✓ over |
| C — Rule 9 (persist atomic order) | 1 rule | AC-23, 24 | 2/1 ✓ over |
| C — Rule 10 (Failed state) | 1 rule | AC-10, 11, 26 | 3/1 ✓ over |
| C — Rule 11 (Suspended drain) | 1 rule | AC-09 | 1/1 ✓ |
| C — Rule 12 (retro-credit) | 1 rule | AC-37 (ADR-gated) | 1/1 ✓ |
| C — Rule 13 (CI script) | 1 rule | AC-27, 28, 29, 39 | 4/1 ✓ over |
| C — Rule 14 (namespace) | 1 rule | AC-11, 25, 34 | 3/1 ✓ over |
| D — Formula ACs (D1-D5) | 5 candidates | D1→AC-20, D2→AC-21, D3→AC-22, D4→AC-16, D5→AC-19 | 5/5 ✓ |
| E — Edge cases (HIGH impact) | 23 ECs | 01→AC02, 02→AC03, 03→AC04, 05→AC08, 06→AC09/13, 17→AC16, 19→AC10/24, 22→AC34, 23→AC40 | HIGH covered (LOW-impact ECs covered by code review + manual smoke) |
| F — Cross-system contracts | 5 downstream | AC-06 (GSM subscription), AC-27/39 (#15+#29 whitelist), AC-36 (#20 HUD pending) | partial (#24 / #27 ACs pending GDDs) |
| G — Knob ACs (G1-G4) | 4 candidates | G1→AC-30, G2→AC-31, G3→AC-32, G4→AC-33 | 4/4 ✓ |
| B — Falsifiable Tests #1-7 | 7 tests | T#1→AC34, T#2→AC35, T#3→AC37, T#4→AC36, T#5→AC01/28, T#6→AC17/34, T#7→AC03/04 | 7/7 ✓ |
| B — Risk Register FR-1/2/3 | 3 invariants | AC-37, 38, 39 | 3/3 ✓ |

### Noteworthy Gaps (flagged for next-revision)

1. **Section F downstream contracts #20 Gym-Mode HUD + #24 Login UI + #27 Onboarding** — no explicit AC binding yet because GDDs unwritten. `streak_changed` (#20), `streak_persistence_failed` (#24), `set_local_timezone_offset_minutes` future API (#27) signal/API contracts covered from Streak side (AC-01, AC-10); downstream consumer-side timing + UX validation pending GDD ratification (AC-40+ candidates).
2. **Section E low-impact ECs (EC-04, 07-16, 18, 20-21)** — deliberately untested per AC scope discipline (focus on HIGH-impact ECs that bind to Falsifiable Tests or Rules). Covered by code review + manual smoke check.
3. **AC-37 (FR-1 retro-credit) — exact pass criteria pending ADR-003 retro-workout window contract**. AC structure locked, retro-window semantics fill-in-blank.
4. **AC-38 (FR-2 drift FPR) — acceptable false-positive rate threshold pending ADR-003 ratification**. Telemetry collection scaffolding can begin pre-ratification; threshold assertion fill-in-blank.
5. **AC-26 (Failed state sticky)** intentionally does NOT test session-restart recovery — restart path covered by `tests/integration/streak/streak_session_restart_test.gd` to be authored when integration harness lands.
6. **AC-36 (Numb Counter playtest) — binding split** — Streak side architecturally covered by Interaction #4 (no own visual); perceptual validation pending #20 HUD GDD authoring, hence ADVISORY gate.

## Open Questions

本 GDD 識別 7 個 open questions across Section C (3 carried forward) + Section B Risk Register (3) + Section F bidirectional sync (1)。每個 question 包：owner / trigger / default if未 resolved / risk if未 resolved。

### Q-O1 — Onboarding timezone capture contract (#27 Onboarding Flow GDD)

- **Question**: #27 Onboarding Flow GDD 尚未存在。Rule 2 / Rule 5 假設 `streak.local_timezone_offset_minutes` 喺 first-launch 由 #27 寫入 (via future-reserved API `set_local_timezone_offset_minutes()`); fallback 係 `Time.get_time_zone_from_system().bias` (device timezone)
- **Owner**: #27 Onboarding Flow GDD owner + ux-designer + accessibility-specialist
- **Trigger**: #27 GDD authoring (Timezone Capture Step section) OR VS-tier first-scene scaffolding
- **Default if未 resolved**: Rule 2 silent device-timezone fallback (acceptable per Pillar 1 because GymSys backend UTC timestamp 仍係 ground truth)
- **Risk if未 resolved**: 玩家搬屋換時區後個 streak day boundary 可能 shift —但 GymSys backend timestamp ground truth 永久 stable，所以 streak count integrity preserved；只係 day-boundary timing 由 device timezone 推導

### Q-O2 — GymSys retro-workout event delivery contract (ADR-002 / ADR-003)

- **Question**: GymSys Backend Client GDD Section C 唔包含 retro-workout event query API。Rule 12「Phone-Lost retro-credit」contract 預設 backend 喺 reconnect / next-poll 補 emit unconsumed `workout_completed` events。**需要 ADR-002 / ADR-003 ratification 確認**: (a) 加入 retro-event delivery requirement (commits FR-1)，或 (b) accept fallback framing per Section B Risk Register FR-1 (Phone-Lost case 可能漏 credit，Pillar 1 dignity 弱化)
- **Owner**: ADR-002 GymSys Integration Protocol authoring + ADR-003 Save State Strategy authoring
- **Trigger**: ADR-002 / ADR-003 ratification gate
- **Default if未 resolved**: Rule 12 provisional contract holds (assume backend補 emit on reconnect — typical REST polling pattern)；AC-37 結構鎖定，pass criteria fill-in-blank
- **Risk if未 resolved**: Phone-Lost case (Section B Falsifiable Test #3) 可能漏 credit → Pillar 1「real body real power」dignity 弱化 ("missed-but-real workout not counted") → 玩家 trust loss

### Q-O3 — Section D step curve co-balance simulation with #15 Loot Drop System

- **Question**: Rule 8 step function boundary values (1.05 / 1.15 / 1.30 / 1.50 / 1.75 / 2.00) 屬 provisional — 需要與 #15 Loot Drop System base rarity 公式 input range 做 co-balance simulation。Pillar 3 dopamine peak shouldn't compress + Pillar 1「power increment proportional to commitment」curve shape 需 validation
- **Owner**: economy-designer + systems-designer (Section D 重新 review 配合 #15 GDD)
- **Trigger**: #15 Loot Drop System GDD authoring (Pre-MVP tier, natural co-design window since Streak 亦 Pre-MVP)
- **Default if未 resolved**: Section D 預設值；AC-30 (G1) + AC-31 (G2) 仍 enforce monotonicity + cap 邊界
- **Risk if未 resolved**: 玩家可能感受 step boundary spacing 不對稱 (e.g.「7 → 14 days jump 太細，但 30 → 60 days jump 太大」)，dilute Pillar 5 weekly progression cadence

### Q-R1 — FR-1 ADR-003 retro-workout window contract (= Q-O2 escalated)

- **Question**: ADR-003 必須 specify retro-workout backend query semantics — `since_sequence_id` pagination, max-window day count, ordering guarantee
- **Owner**: ADR-003 authoring (queued)
- **Trigger**: ADR-003 Save State Strategy ratification
- **Default if未 resolved**: AC-37 結構 lock，pass criteria fill-in-blank pending ADR-003
- **Risk if未 resolved**: VS-tier playtest 可能發現 Phone-Lost case rare but real → retro-fit backend contract → 增加 GymSys client + backend 嘅 protocol complexity

### Q-R2 — FR-2 ADR-003 drift tolerance false-positive rate threshold

- **Question**: ADR-003 必須 specify acceptable false-positive rate for Rule 4 drift gate (current default `WALL_CLOCK_DRIFT_TOLERANCE_SECONDS = 300` 同 PersistenceLayer 一致 — 但 streak 嘅 sensitivity 可能不同)
- **Owner**: ADR-003 authoring + VS-tier telemetry instrumentation
- **Trigger**: VS-tier playtest data collection (≥100 sessions, geographic UTC offset diversity)
- **Default if未 resolved**: AC-38 結構 lock，threshold fill-in-blank pending playtest data
- **Risk if未 resolved**: 玩家喺 high-drift environments (e.g. Synology NAS device clock drift) 可能 trigger false-positive reject → silent streak count loss

### Q-R3 — FR-3 cross-system rarity modifier discipline (CI script expansion contract)

- **Question**: Rule 13 CI script 嘅 `WHITELIST_PATHS_LOOT_RARITY` (currently `["src/gameplay/loot/", "src/gameplay/mirror_moment/", "src/autoload/streak.gd", "tests/"]`) 喺未來如果新 system (e.g. #18 PR Detection 想 surface streak modifier 喺 PR celebration moment) 申請加入時，governance process 點樣 verify Pillar 1 anti-pillar #1 唔違反？
- **Owner**: devops-engineer (CI script maintenance) + game-designer (whitelist policy)
- **Trigger**: First time someone proposes adding a new whitelisted path
- **Default if未 resolved**: 嚴格 PR review；提案必須 cite 點解該 system 嘅 streak modifier 訪問 NOT 違反 Pillar 1 anti-pillar #1
- **Risk if未 resolved**: 未來 system creep — streak modifier 滲透入 avatar power path → Pillar 1 silent dilution

### Q-V1 — Streak HUD visual style accessibility cluster (#20 Gym-Mode HUD + #6 ScreenEffects motion_intensity)

- **Question**: Streak counter chip + flame icon HUD visual style — 點樣同 #6 ScreenEffects 嘅 motion_intensity slider + future Camera reduce_motion accessibility cluster 整合？玩家見到 multiple disconnected accessibility toggles 抑或 unified panel section？
- **Owner**: #22 Character Screen GDD owner (accessibility settings panel) + #20 Gym-Mode HUD GDD owner + accessibility-specialist
- **Trigger**: #20 + #22 GDD authoring + AccessibilityBus.reduce_motion ADR (per Camera #7 GDD spin-off)
- **Default if未 resolved**: Streak HUD 跟 #20 HUD owner 決定，不直接 own accessibility surface
- **Risk if未 resolved**: 玩家見到 motion intensity / reduce camera motion / streak visibility 等 toggles 分散，cognitive load 增加；應 unified panel section per CD 之前 #6 motion_intensity UX Flag 提示
