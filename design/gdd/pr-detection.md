# PR Detection & Avatar Progression

> **Status**: ✅ **APPROVED**(2026-06-06,Pass 3 — 同日三 pass 收斂:Pass 1 MAJOR [5 specialists + CD] → 全文 revision + ADR-0011 → Pass 2 fresh 3-verifier [Pass 1 全 FIXED,0 phantom,6 targeted] → Pass 3 fixes + CD grep spot-check APPROVED)
> **Author**: frank + agents(原稿 degraded inline 2026-06-06;review 歷程見 `design/gdd/reviews/pr-detection-review-log.md`)
> **Last Updated**: 2026-06-06
> **Implements Pillar**: Pillar 1 (Real Body, Real Power — **PRIMARY**:anti-fabrication 鏈嘅 PR 入口)· Pillar 4 (Muscle = Class — supporting:PR 按肌群 route 落 stat/ability)· Pillar 5 (Mirror Moment — supporting:PR 係 evolution 鏈嘅最強驅動)
> **Layer / Tier**: Feature / Pre-MVP
> **Depends On**: #2 GymSysBackendClient · #3 PersistenceLayer · #10 ExerciseClassMapping · #11 Stat System · ADR-0011(topology + server baseline contract)· (#12 Ability System / #9 WST 係 downstream signal consumers)

## Overview

PR Detection & Avatar Progression 係 Mirror Hero 嘅 **Pillar 1 心臟** —— 將玩家真實嘅 1RM breakthrough 轉化成遊戲內**唯一**嘅大幅成長事件。系統訂閱 #2 嘅 `set_logged(exercise_id, reps, weight)` 原始流(**直訂 #2,唔經 #9** — #9 L863 SIBLING-consumer split),對每個 set 計 estimated 1RM(Epley,rep-clamped),同 **server-sourced historical baseline** 比較,判定 PR 後:(1) 經 #11 Formula 2 計 `pr_delta` 並 call `apply_stat_delta(stat_id, PR_BREAKTHROUGH, delta)`(caller path:`src/autoload/pr_detection.gd`,ADR-0011 §D-4);(2) emit `pr_breakthrough(stat_id, magnitude)` signal 畀 #12 做 ability unlock 評估(gate G-PR-5);(3) 通知 #9 increment `pr_count_today`(#15 loot rarity 嘅 pr_factor input,gate G-PR-2)。

**Topology(ADR-0011 §D-1,supersedes game-concept Q3)**:PR 判定 = **facts server-authoritative,derivation client-side,contract-pinned**。三個 input 全部係 server-authoritative facts(set 數據經 #2 polling、baseline 經 G-PR-1 contract、公式 deterministic)— client 冇任何自由輸入可以偽造 PR,同時零 per-PR round-trip(Pillar 2)。Server baseline 嘅 formula parity / value validation / ratchet 語意 / sync timing 四面 contract 詳見 **ADR-0011 §D-2**(binding)。

**兩條 named invariants(本系統嘅 anti-fabrication 骨幹)**:

- **INV-PR-1 — No trusted baseline, no PR(fail-closed)**:任何 exercise 喺「無 trusted baseline」狀態下(local persisted 無 + 本 boot server sync 未成功提供),該 session 對佢只行 baseline establishment(Formula 4 window),**永不**判 PR。封死 cold-start warmup-ramp 假 PR cascade 同 BASELINE_SYNCING farmable window 兩個洞。
- **INV-PR-2 — Magnitude log-additivity(farming 自我平衡)**:對任意 confirmed-PR 步進序列(initial → final e1RM):**upper bound `Σ pr_magnitude ≤ (final−initial)/initial` 恆成立**(clamp 只會減 Σ — 單向 under-credit,anti-farming 方向永不破);lower bound `ln(final/initial) ≤ Σ` 喺 **per-step raw m ≤ 2.0** 時成立(單步超 clamp 嘅 anomaly 步會 under-credit — 刻意)。即 micro-stepping 收多倍事件數但 magnitude 總量不增(convexity 仲益大步)— stat 面 farming 結構性無利可圖。D8 commit-time magnitude 重計係呢條 invariant 嘅必要組件(stale-magnitude commit 會破 upper bound)。呢條(+ #11 diminishing)先係真防線;property test AC-31 + interleaved vector AC-29。

**Avatar Progression scope(ADR-0010 邊界)**:#26 AvatarRenderer **own** evolution tier 計算(由 #11 stat + #12 ability sync read derive)—— 本系統**唔重複**呢個邏輯。#18 嘅 progression 角色係**事件源**:PR → stat delta → #26 tier 自然推進;PR → ability unlock → #26 posture 變化。另加 PR milestone tracking(`pr_milestone_reached` — **MVP 無 consumer(telemetry only)**;#19 Pass 1 P2 裁決:#19 MVP enum 冇 PR kind,v0.2 ratify **Σmagnitude PR_SCORE 軸**先加,`lifetime_pr_score` data surface 已為此而備;thresholds PROVISIONAL 待 Q-PR-1 校準)。

## Player Fantasy

**核心情緒**:「**我喺 gym 入面突破嘅嗰一刻,遊戲世界即時承認佢**」—— 真實 PR 嘅腎上腺素同 in-game 慶祝係**同一個 moment**,唔係事後補發。

**錨定時刻**:玩家 bench press 卡咗三個禮拜嘅 60kg,今日上到 65kg。Rack 返條 bar、抹汗、攞起部機 —— 畫面上 avatar 嘅 STR 數字跳咗 +0.5(全 session 最大嘅單次跳)、一條 strike ability 解鎖 toast、今日 loot rarity 因 pr_factor 而升呢。**「呢個唔係 game 送你嘅 —— 係你舉返嚟嘅。」**(unique hook:Like Pokémon evolution, AND ALSO YOU yourself are evolving)

**第一 session 嘅承認(Baseline Forged)**:新 exercise 嘅第一個 workout 係**基準日** — 零 PR,但唔係零反饋:workout 完結時每個新 exercise 出一個 player-visible「**基準已鍛入**」moment(「Bench Press 基準:e1RM 70kg」)。誠實、有承認感、零 Pillar 2 衝突(Rule 11 + AC-28 binding)。對已有 GymSys 歷史嘅老用戶,G-PR-1 server baseline import 令第一 session 就可以出真 PR — import 完成時另有 reveal hook(Rule 11)。

**間接層(infrastructure 面)**:玩家唔會「操作」PR Detection —— 佢哋操作槓鈴。系統嘅存在感係透過效果:stat 跳、ability 解鎖、loot 升呢、avatar 進化。Design 上呢個系統永遠唔可以要求 mid-set 注意(Pillar 2)—— 所有 PR 反饋都係 set 完成後嘅 glance 獎勵。

**反面界定**:呢個唔係「自動偵測你今日狀態」嘅 AI 教練,亦唔做 form 分析 —— 純粹 e1RM 數字突破判定。Cardio / 步數 / 非阻力訓練**永不**觸發(anti-pillar #5)。

### Progression cadence ownership(顯式分工)

PR 係**唯一大幅 stat 成長事件**,但唔係日常 cadence 通道 — input 端頻率天然 front-loaded(novice LP 每週 6-9 個 → advanced 每季 ~1 個;見 Expected PR Frequency 表),呢個 cliff 係**接受嘅**(lifetime ratchet = 誠實;rolling-window stats 會迫 #11 churn,結構上不可行)。日常 progression 故事由其他系統 own:

| Cadence | Owner | 角色 |
|---------|-------|------|
| 每 set | #9 VOLUME_TICK(經 #11) | 恆定細步 stat income |
| 每 workout | #15 loot(必爆 daily)+ #17 equipment | 日常獎勵主通道 |
| 每週 | #8 streak + #26 Mirror Moment | 習慣 + 形象節奏 |
| 稀有 | **#18 PR(本系統)** | **rare jackpot 頂層** — 一次過大跳 + ability unlock + loot 升呢 |

Intermediate/advanced/returner 嘅 engagement 唔靠 PR 頻率掹住 — 靠上表前三行。Veteran(server import 老手)零 honeymoon 係 intended(「成長之鏡」非「地位之鏡」— 人人 stat 10.0 開局,in-game 進度反映接入後嘅真實進步)。

### Expected PR Frequency(provisional — Q-PR-1 真數據實證化)

| 階段 | e1RM-PR 頻率(含 rep-PR) | typical magnitude | 備註 |
|------|---------------------------|-------------------|------|
| Novice(LP 期,首 3-6 個月) | 每週 2-6(MVP 3 exercises) | 0.02–0.05 | 首 workout 零 PR(基準日) |
| Intermediate | 每月 1-4 | 0.015–0.03 | cadence 故事轉移到 volume/loot/equipment |
| Advanced / imported veteran | 每季 ~1 | 0.01–0.02 | rare jackpot 語意成立 |

> ⚠️ **Cross-system erratum flag(畀 #15 owner,#18 唔 patch 上游)**:#15 player profile「hardcore 7 PR/週 sustained」假設只成立於 novice LP 期 — advanced hardcore 實際 ≈ Casual 頻率,#15 Monte Carlo balance 需於 balance pass revisit。另 #15 `MAX_PR_FACTOR` 一名三義(EC-42 count-clamp 10 / knob 表 1.25 / Q-OQ4 ratio [0.5,2.0])— #15 內部 reconcile;**#18 嘅 farming 防線唔依賴佢**(rest 於 INV-PR-2 + #11 diminishing)。

## Detailed Design

### Core Rules

> **Resolved decisions(D1–D8;D1/D2 受 ADR-0011 govern):**
> - **D1** — Topology = facts server-authoritative + derivation client-side + contract-pinned(**ADR-0011 §D-1**,supersedes game-concept Q3)。
> - **D2** — Baseline reconcile = **server 贏 pre-session 真相 + session-confirmed floor**(ADR-0011 §D-2 reconcile 規則):server sync 覆寫 local,但唔可以將任何 exercise 嘅 baseline 拉低過本 session 已 confirmed PR 嘅 e1RM(否則 catch-up replay 重判同一 PR → double-count)。Server 回嘅每個 entry 過 per-entry validation(ADR-0011 §D-2.2),唔過 → reject 該 entry 保留 local + `pr.baseline_invalid`。
> - **D3** — `pr_delta` 計算 follow **#11 Formula 2**,caller(#18)負責計(per #11 L255)。實作為 shared static calc(`src/core/pr_delta_calc.gd`)讀同一 config 常數 — 唔 inline 重抄。`PR_BASE = 6.0` PROVISIONAL(ADR-0005 retune gate)屬 #11/ADR-0005 own,#18 只引用。
> - **D4** — Class routing 經 #10:`exercise_id → AbilityClass → stat_id`(STRIKE→STR / CONTROL→DEX / MOBILITY→VIT)。`UNKNOWN` class → **skip + telemetry**(Pillar 1 cardio gate;#11 L39 binding)。
> - **D5** — Idempotency 靠 **baseline monotonicity**:PR 確認後 baseline 即升 → 同一 set 嘅 replay(bfcache / #2 catch-up redelivery)計出嘅 e1RM 唔再超 baseline → 自然 no-op。無需 set-level dedup id(`set_logged` payload 冇 id — #2 schema locked)。**Crash-window caveat(deliberate decision)**:Rule 6 嘅 6.3(stat write)同 6.5(baseline persist)係兩個獨立 write — tab 喺兩者之間被 kill → replay 重判 → one-shot double-count。順序唔調轉係刻意:調轉會喺 reject path lose PR,**under-count 對 Pillar 1 比 double-count 更傷**;殘餘風險 one-shot + backend-primary 下機率極低,`pr.replay_recheck` telemetry 偵測。
> - **D6** — `pr_count_today` ownership:**#18 detect,#9 count**。#18 emit `pr_breakthrough` → #9 subscribe(接線方向:**#18 boot 時 reverse-wire,同 #12 一致** — #9 早 boot 唔主動訂)→ #15 read `get_pr_count_today()`(#15 L293 shipped spec — 零 #15 churn)。Gate G-PR-2。
> - **D7(Position B 裁決)** — **REP_CAP = clamp,唔係 skip**:`effective_reps = min(reps, REP_CAP)` 入 Formula 1。高 rep set(13-15+)以「至少示範咗 e1rm(weight, 12)」嘅 **true lower bound** 計 — 只會 under-credit 永不 over-credit(anti-fabrication-safe)。後果:同重量純加 rep 過咗 12 → 零 PR(Epley 認證唔到,誠實);加重先郁到 e1RM。Hypertrophy 玩家(13-15 rep 常態)由「整個 archetype 隱形」變成正常參與。
> - **D8(Position D 裁決)** — **Soft-confirm 防 typo fabrication**:`pr_magnitude > SUSPECT_PR_MAGNITUDE`(0.30)→ 唔即時生效,入 **PENDING_CONFIRMATION**(delta / signal / count / baseline 全 hold)。理由:GymSys 係手動入數,kg/lb typo 係最高發生率嘅 fabrication vector;生理上 30%+ e1RM 單跳接近不可能,而 corroboration 對真 detraining-return 玩家只係延遲一兩個 set。GymSys 改返正確數字 → 該 set 喺 server 消失 → 永不 redeliver → pending 自然 discard(catch-up replay 來自 server state — 自我修正)。
>   **D8 pipeline 順序(binding — corroboration 喺 Rule 5 之前行)**:`set_logged` 過咗 Rule 2-4 後,若該 exercise 有 pending:
>   1. **Corroboration check 先行**:本 set e1rm ≥ `pending.e1rm_raw × CORROBORATION_RATIO` → **commit pending**:`m_commit = clamp((pending.e1rm_raw − current_baseline) / current_baseline, 0, 2.0)`(**magnitude 以 commit 時 current baseline 重計** — pending 期間 interleaved 細 PR 升咗 baseline 嘅話,stored magnitude 已 stale,直接用會破 INV-PR-2 upper bound;重計後再過 MIN floor),行 Rule 6(delta 用 m_commit;baseline 升 `pending.e1rm_raw`;summary tuple 用 pending set 嘅 raw weight/reps)+ `pr.pending_corroborated`。
>   2. Commit 後(或無 corroborate),本 set 對**最新** baseline 行 Rule 5 正常判定(自己都 suspect → 開新 pending)。
>   3. 同 exercise 第二個 suspect 期間到達 → **keep-highest**(`pending.e1rm_raw` 取大者,corroboration bar 更高)+ `pr.pending_replaced` telemetry。Pending 係 per-exercise dict(多 exercise 可同時 pending)。
>   4. **Discard deadline**:pending entry 記 `opened_seq`(envelope `workout_seq` — #2 `workout_started` 時 +1);`workout_completed` 時 `current_seq > opened_seq` 仍無 corroboration → discard + `pr.pending_discarded`(即「開 pending 嗰個 workout 之後嘅下一個 workout 完結」)。

1. **Set 事件接收** — 訂閱 #2 `set_logged(exercise_id: String, reps: int, weight: float)`(直訂,#9 L863 SIBLING split;handler 簽名跟 #2 GDD 用 `String` — Godot 4 String↔StringName signal dispatch implicit convert,無 bug,citation 一致優先)。每個事件行 Rule 2–7 判定 pipeline。#2 own delivery semantics(suspended queue / catch-up replay)— #18 對 replay 安全(D5)。
2. **Eligibility gate** — 順序檢查,任一不過 → skip(無 side effect):
   - `reps < 1` 或 `weight <= 0` → skip + `pr.input_invalid` telemetry(defensive — #2 schema 應保證)。
   - `weight > WEIGHT_SANITY_MAX`(500kg)或 `weight < WEIGHT_SANITY_MIN`(1.0kg)→ skip + `pr.input_invalid`(數據錯誤 / 異常 logging;tiny weight 同時擋「微重量種 baseline → 下一 set clamp-2.0 假 max PR」嘅 seed)。
   - #10 `get_class_for_exercise(exercise_id)` 回 `UNKNOWN` → skip + `pr.unknown_exercise` telemetry(**Pillar 1 cardio gate**)。
   - (注意:**高 rep 唔係 skip 條件** — D7 clamp 喺 Formula 1 處理。)
3. **e1RM 計算** — Formula 1(Epley,rep-clamped):`e1rm = weight × (1 + min(reps, REP_CAP) / E1RM_DIVISOR)`。
4. **Baseline 比較** — 攞該 `exercise_id` 嘅 trusted baseline(Rule 8)。**無 trusted baseline → INV-PR-1**:行 Formula 4 establishment window(本 workout 內該 exercise 全部 set 只推高 candidate,零 PR),skip Rule 5–7。
5. **PR 判定** — Formula 2:`pr_magnitude = (new_e1rm − best_e1rm) / best_e1rm`。`is_pr = pr_magnitude >= MIN_PR_MAGNITUDE − MAGNITUDE_EPS`(epsilon 1e-9 const — 防「啱啱好 1%」嘅 float 邊界拒絕真 PR);唔過 → 唔算 PR。過 →:
   - `pr_magnitude > 2.0` → clamp 至 2.0 + `pr.magnitude_anomaly` telemetry(下游全部收 clamped 值)。
   - `pr_magnitude > SUSPECT_PR_MAGNITUDE` → **D8 soft-confirm path**(PENDING_CONFIRMATION),skip Rule 6;corroborated 先行 Rule 6。
   - 否則 → **PR confirmed**,行 Rule 6–7。
6. **PR 生效(順序 binding)** —
   1. `stat_id = class → stat` mapping(D4)。
   2. `pr_delta = PRDeltaCalc.compute(StatSystem.get_stat(stat_id), pr_magnitude)`(D3;讀 base stat 名 `&"str"` 等 — PR_BREAKTHROUGH 只准 base)。
   3. **`pr_delta > 0.0`** → `ok = StatSystem.apply_stat_delta(stat_id, StatSource.PR_BREAKTHROUGH, pr_delta)`;`ok == false` → **abort 成個事件**(baseline 唔升、signal 唔 emit、count 唔加 — EC-3 all-or-nothing;#2 redelivery 或下一個 set 重判)。**`pr_delta == 0.0`(stat 已 cap 999)→ short-circuit:skip apply call,直行 6.4–6.7**(capped 玩家照拎 signal / count / milestone 承認 — 唔依賴 #11 對 zero-delta 嘅未 pin 行為)。
   4. baseline 升到 `new_e1rm`(anomaly path 用 **raw** e1rm — corroborated 即係真,唔好 poison 後續判定;delta 已以 clamped 值計)。
   5. update session PR summary(Formula 5 schema:該 exercise 取 magnitude 最大嗰個 confirmed set 嘅完整 tuple)+ `lifetime_count += 1` + `lifetime_pr_score += pr_magnitude` + milestone check(Rule 9)。
   6. persist `pr.state`(單一 key envelope,`flush=true` — PR 係 anchor moment;6.4–6.5 全部 dirty 一次過落盤,一次 PR 一次 flush)。
   7. emit `pr_breakthrough(stat_id, pr_magnitude)`(**emit gate,#12 EC-16 binding 義務**:GSM 非 SUSPENDED 先 emit — 唔係 → **one-slot pending-emit buffer hold,leave-SUSPENDED 時 flush**(AC-30)。注意:gate 喺 **6.3 short-circuit path(pr_delta==0,capped 玩家)係 load-bearing** — 嗰條 path skip 咗 #11 嘅 suspended check,gate 係唯一防線,唔係 assert。#12 `boot_completed` 半邊:#12 無 sync getter 可 assert(G-PR-5 story 順手加 `is_boot_completed()` getter,mirror #11 G-2 先例,畀 AC-30 assert surface);interim 靠 G-PR-3 結構保證(#18 鏈尾 boot,#12 `_ready` 尾 synchronous emit `boot_completed` — `ability_system.gd:179/395`)。#12 EC-16 嘅「GSM `Ready` state」係 loose wording(GSM enum 無 READY — `game_state_machine.gd:80-89`),#18 解讀為「非 SUSPENDED」)+ `pr.detected` telemetry(exercise_id / magnitude / stat_id / delta)。
7. **同 workout 連續 PR** — 每次 PR 後 baseline 即升,同一 workout 內再突破 → 各自獨立 PR(magnitude 以最新 baseline 計,連續細突破遞減)。Farming 防線 = **INV-PR-2**(log-additivity:Σ magnitude 受 ln bound,micro-stepping 無利)+ #11 diminishing。**唔 cite #15 MAX_PR_FACTOR 做防線**(上游一名三義,erratum flag 已出 — 見 Expected Frequency 表注)。
8. **Baseline store** — 單一 persist key **`pr.state`**(SerializableResource envelope,ADR-0006 Contract 3 / ADR-0009):`{ baselines: Dictionary[String, float], pending: Dictionary[String, Dictionary], candidates: Dictionary[String, float], workout_seq: int, lifetime_count: int, lifetime_pr_score: float }`。Pending inner schema:`{ e1rm_raw: float, weight: float, reps: int, opened_seq: int }`(D8 discard deadline 需要)。`workout_seq` 喺 #2 `workout_started` 時 +1(monotonic counter — **#18 無 clock 依賴**,staleness 用 seq 唔用 unix time)。**Write boundary(binding)**:envelope 經 `to_dict()` 落 `write()` / `from_dict()` 還原 — #3 flush 係 `JSON.stringify`,直接 write Resource instance 會 silent corrupt(GSM tombstone `game_state_machine.gd:540` + loot `loot_drop_system.gd:634` 先例)。**單 key 理由(binding)**:#3 IPersistence **冇 key-enumeration API**(shipped surface = exact-key read/write/delete/migrate)— per-key `pr.best.*` boot load unimplementable;PersistenceLayer 係 whole-cache snapshot flush,per-key 細分零 I/O 著數。Boot 時:(a) `read("pr.state")` 還原;**stale candidates(上次 mid-workout crash 殘留)→ discard**(window 重開,對齊 EC-10 — 永不假 PR);(b) 等 #2 **首個 polling state response 嘅 baseline field**(G-PR-1,ADR-0011 §D-2.4 — baseline ride 喺 polling response 上,唔開獨立 endpoint/request,結構性保證 baseline 先於(或同於)catch-up replay,「selective block baseline」攻擊面唔存在 — block 咗就連 set 事件都冇);(c) per-entry validate 後 server 覆寫 local(D2;session-confirmed floor);(d) server unavailable → 有 local cache 嘅 exercise 照判定(grace),**無 local cache 嘅 exercise 行 INV-PR-1 fail-closed**(establishment-only)。
9. **Milestone tracking** — `lifetime_count` 達 `PRMilestoneConfig.tres` thresholds([10, 25, 50, 100] **PROVISIONAL** — 零 gameplay 驗證,#19 v0.2 接用前 Q-PR-1 校準)→ emit `pr_milestone_reached(count)`。**Boot 載入已過 threshold 唔 re-emit**(crossing-only 語意,AC-19)。**Consumer**:**MVP 無(telemetry only)** — #19 Pass 1 P2 裁決:#19 MVP enum 冇 PR kind(workout-count 係 primary 軸);v0.2 ratify **Σmagnitude PR_SCORE** 先加(zone-system.md Future Extensions)。`lifetime_pr_score`(Σ magnitude)同步 persist,係 #19 將來 PR_SCORE 軸嘅 data surface(#19 design space,#18 只保證數據可取;屆時開 #18 additive getter gate)。Config thresholds 非 ascending → `validate_milestone_config() == false` + push_error(EC-12;AC-20 — 唔用 raw assert,GUT headless 測唔到)。
10. **Boot / lifecycle** — autoload `PrDetection` @ `src/autoload/pr_detection.gd`(**ADR-0011 §D-4**;`src/feature/` 係 phantom path — 全部 18 個 shipped autoload 喺 `src/autoload/`;`check_stat_mutation_callers.gd` whitelist amend 落 epic 第一個 story)。Gate G-PR-3:ADR-0008 insertion — **constraint:`GymSysBackendClient ≺ ExerciseClassMapping ≺ StatSystem ≺ {AbilitySystem, WST}(現行 project.godot 相對次序不變 — shipped 順序係 StatSystem → AbilitySystem → StreakSystem → WST,`project.godot:42-45`;AbilitySystem/WST 之間零相互依賴,#18 唔加 constraint)≺ PrDetection`**(#18 排鏈尾,append 喺 AttentionBudget 之後 — 兩個 reverse-wire target 都先 boot;唯一後置考慮 = 將來 #28 Telemetry 仍排最尾)。`_ready` 內 **synchronous** 完成 INITIALISING → READY(load local → 接線 → READY;項目慣例 — WST/#3 同款;#2 事件全部經 async HTTP callback boot frame 後先到,結構上零 pre-READY window;**server baseline = 等首個 #2 polling state response 嘅 baseline field**(ADR-0011 §D-2.4 — 唔係獨立 async request),未返前行 BASELINE_SYNCING substate)。**Reverse-wiring(boot 時 #18 主動 connect 自己 signal 落兩個 consumer)**:`pr_breakthrough.connect(AbilitySystem._on_pr_breakthrough)`(G-PR-4 — handler 已 grep pin:`ability_system.gd:895`,簽名 `(stat_id: StringName, magnitude: float)` match;shipped comment L884-888 明文留咗呢個做 #18 stable entry point)+ `pr_breakthrough.connect(#9 G-PR-2 新 handler)`。方向理由:唔係「#12 訂唔到未存在嘅 #18」(Godot autoload 兩段式 boot 下,所有 autoload 喺任何 `_ready` 前已 instantiate — 經 global name connect 未-ready node 嘅 signal 合法且 deterministic)— 而係 (a) #12 shipped code 已將 `_on_pr_breakthrough` 定位做「#18 connect 嘅 stable entry point」,ownership 已定;(b) 項目紀律唔依賴未-ready instance。GSM 經 `connect_for_initial_state`(Contract 6)— #18 **無 set-event queue 需求**(#2 own delivery;#18 stateless per-event + D5 replay-safe);**唯一 state = Rule 6.7 嘅 one-slot pending-emit buffer**(leave-SUSPENDED 時 flush;SUSPENDED sliver 內第二個 PR confirm → **keep-latest overwrite** — reachability 極窄(#2 suspended queue 已擋主路徑)且 self-healing:#12 unlock 係 threshold-based,下個 stat event 補評估)。跟 GSM 做 telemetry 靜默 + Rule 6.7 emit gate。
11. **Player-visible moments(#18 emit,presentation consume)** —
    - **Baseline Forged**:establishment window commit 時(Rule 8 / Formula 4 嘅 workout_completed step)per 新 exercise emit `baseline_established(exercise_id: String, e1rm: float)` signal — #20 glance / post-workout summary surface 消費(「Bench Press 基準:e1RM 70kg」)。**Binding**:呢個 moment 唔可以 telemetry-only(PRIMARY pillar 嘅第一印象通道;AC-28)。
    - **Baseline import reveal(veteran)**:首次 server sync 帶 non-empty history → emit `baseline_import_completed(exercise_count: int)`(forward hook;presentation 做「你嘅真實力量已鍛入」reveal — Pillar-1-pure,唔 fabricate 增長)。MVP:signal + telemetry,UI consumer #20/#27 backlog。

### States and Transitions

| State | 意義 | 入 | 出 |
|-------|------|----|----|
| `INITIALISING` | `_ready` 內 synchronous:load `pr.state`(stale candidates discard)→ reverse-wire #12/#9 → 訂 #2(baseline 會隨首個 polling state response 到 — 唔發獨立 request) | boot(Contract 4) | `_ready` 尾 → `READY`(同 frame) |
| `READY` | 接 `set_logged`,行判定 pipeline | INITIALISING 完成 | — |
| `BASELINE_SYNCING`(substate of READY) | server baseline 未返:**有 local cache 嘅 exercise 照判定(grace);無 local cache 嘅 exercise 行 INV-PR-1(establishment-only,零 PR)**。Server 返 → per-entry validate + reconcile(D2 session-confirmed floor) | READY 且 server 未答 | server 答(或 validated reject 完成)→ plain READY |

> 無 SUSPENDED state:#18 stateless per-event,#2 負責事件流嘅 suspend/drain;#11 reject(suspended 時)由 Rule 6.3 `ok==false` 兜(baseline 唔升 → 可重判)。

### Interactions with Other Systems

| 系統 | 誰 own interface | 流入 #18 | 流出 #18 | 備註 |
|------|------------------|----------|----------|------|
| **#2 GymSysBackendClient** | #2 own 7-signal contract;**G-PR-1**:polling state response 加 baseline field(ADR-0011 §D-2 contract) | `set_logged` 原始流 + `workout_started` / `workout_completed`(summary/candidate lifecycle)+ server baselines | — | 直訂(#9 L863);payload schema cite #2 L479;**summary clear 用 #2 `workout_started`(下一個 workout 開始先 clear)— 唔用 workout_completed(同 #15/#17 receipt read 同 signal = subscriber-order race);candidate commit 用 #2 `workout_completed`** |
| **#3 PersistenceLayer** | #3 own `IPersistence`;**G-PR-6**:`pr.` namespace 註冊(VALID_NAMESPACES + Rule 12 registry + CI lint 各一行 additive) | boot `read("pr.state")` | `write("pr.state", envelope, flush=true)` per PR / establishment commit | ADR-0003;localStorage FORBIDDEN;單一 key(Rule 8 理由);corrupt-wipe 語意見 EC-11 |
| **#10 ExerciseClassMapping** | #10 own `get_class_for_exercise(exercise_id)` | class enum(UNKNOWN → skip,D4) | — | 純 lookup;#11 L254「#10 returns class/stat_id for #9 + #18 to route」✓ |
| **#11 Stat System** | #11 own `apply_stat_delta` + `get_stat` | `get_stat(stat_id)` | `apply_stat_delta(stat_id, PR_BREAKTHROUGH, pr_delta)`(caller = `src/autoload/pr_detection.gd`,ADR-0011 §D-4) | delta 由 #18 計(D3);`ok==false` → abort(EC-3);**#11 EC-36 嘅「server-side validation」義務由 ADR-0011 §D-3 guarantee mapping 滿足 — #11 L616 Formula 2 clamp 係 incidental fail-soft,唔係 designed defense,#18 自己層 clamp + soft-confirm 先係防線** |
| **#12 Ability System** | #18 own `pr_breakthrough(stat_id: StringName, magnitude: float)` signal;#12 own handler | — | signal(#18 boot 時 reverse-wire 落 `_on_pr_breakthrough` — G-PR-4 已 pin) | #12 L223 interface ✓;**G-PR-5(binding)**:#12 additive 一行 — `_on_stat_changed` skip `source == PR_BREAKTHROUGH`,否則 stat_changed synchronous emit 令 unlock 經 STAT_THRESHOLD provenance 搶先行,`pr_breakthrough` 到達時冪等 skip = PR provenance dead code + flush 變 deferred(100ms crash window);順手修 L890 comment(magnitude = relative,唔係 delta)。**#12 EC-16 義務**:Rule 6.7 emit gate。**Unlock farming 防線注**:#12 Path A 實際係 stat-threshold-based(`_evaluate_unlock` 查 current stat)— PR 事件只 trigger evaluation,count 刷唔到 ability |
| **#9 WorkoutStateTracker** | **G-PR-2**:#9 additive — `pr_breakthrough` handler + `get_pr_count_today()` getter + daily reset 語意(**#9 own;TimeProvider seam 屬 #9-side,寫入 G-PR-2 spec**) | — | signal(#18 boot 時 reverse-wire — 方向同 #12 一致,D6) | #15 L293 read #9 getter(shipped spec)— 零 #15 churn;getter 現未實作(src grep 0) |
| **#15 Loot Drop** | (間接經 #9) | — | pr_factor 數據鏈:#18 → #9 count → #15 read | #15 Q-OQ4 provisional pr_factor 喺 #18 落地後 revisit ✓;MAX_PR_FACTOR erratum flag 見上 |
| **#17 Equipment** | #17 own SourceReceipt | — | `get_session_pr_summary()`(Formula 5 — **per-entry 含 raw `weight_kg` / `reps`**,receipt「鍛造自 180kg × 5」嘅數據源) | F-12;summary 喺 post-workout 窗口存活(clear 於下一個 `workout_started`)— receipt 製作零 race |
| **#20 HUD / #29 Mirror Moment** | forward contract(consumer-forward 慣例,EG-1 先例) | — | `baseline_established` / `baseline_import_completed` signals + summary 數據 | **Forward 斷言**:PR celebration 必須視覺 distinct 於 loot ceremony(#20 按 `stat_changed` source==PR_BREAKTHROUGH filter),且 end-of-workout recap 層級 ≥ loot tier(mid-set sting 維持低 — Pillar 2 正確);end-of-workout PR recap 入 #20 backlog |
| **#26 AvatarRenderer** | #26 own evolution(ADR-0010) | — | (間接:stat delta → #26 tier derive) | #18 唔直接餵 #26 — 邊界紀律 |
| **#19 Zone System** | #19 own unlock framework | — | `pr_milestone_reached(count)` + `lifetime_pr_score` data surface | **MVP 無 consumer**(#19 P2 裁決:MVP enum 冇 PR kind);v0.2 ratify PR_SCORE(Σmagnitude)先接(zone-system.md Future Extensions + Q-PR-1 校準) |

> **Bidirectional sync flags(寫 #18 後回填):** #2(G-PR-1 polling field + downstream 表 actualize)· #9(G-PR-2 amendment)· ADR-0008(G-PR-3 insertion)· #12(G-PR-5 additive + comment 修正)· **#3(G-PR-6 `pr.` namespace)**· registry expected-referrer actualize · #19(milestone consumer 雙向 ✓ 已有)。

## Formulas

### Formula 1 — `e1rm`(estimated 1RM,Epley,rep-clamped)

`e1rm = weight × (1 + min(reps, REP_CAP) / E1RM_DIVISOR)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `weight` | w | float | [WEIGHT_SANITY_MIN, WEIGHT_SANITY_MAX] kg | set 重量(#2 payload,server-sourced;range 由 Rule 2 gate enforce) |
| `reps` | r | int | ≥ 1(>12 clamp 至 12 — D7) | 完成次數 |
| `REP_CAP` | — | int | **12** knob [8, 15] | clamp 上限(Epley 12+ rep 外推不可靠 — clamp 畀 true lower bound,唔 skip) |
| `E1RM_DIVISOR` | d | float | **30.0**(Epley 標準,LOCKED — 改咗就唔係 Epley;**必須 float literal,`5/30` int division == 0 陷阱**) | 外推係數 |
| `e1rm` | — | float | (0, ~700] | 估算 1RM |

**Output Range:** weight=60, reps=5 → 60 × (1+5/30.0) = **70.0**;weight=100, reps=15 → clamp 12 → 100 × 1.4 = **140.0**(同 reps=12 一樣 — rep-only 增長過 12 唔郁 e1RM,誠實)。
**Example:** bench 65kg × 3 → 65 × 1.1 = **71.5**;**reps=1 同樣經 Epley**:100kg × 1 → 103.33(同一把尺,唔特判 — AC-11;server 端 parity 同款,ADR-0011 §D-2.1)。
*用 e1RM 而唔係 raw weight:rep PR(同重多 rep,≤12 範圍內)都係真實 strength 突破,Epley 統一落同一把尺。Singles dead-zone(新 weight 高過歷史 bar weight 但 e1rm ≤ baseline)係 **intended** — 見 EC-14。*

### Formula 2 — `pr_magnitude`

`pr_magnitude = clamp((new_e1rm − best_e1rm) / best_e1rm, 0.0, 2.0)`
`is_pr = pr_magnitude >= MIN_PR_MAGNITUDE − MAGNITUDE_EPS`
`needs_confirmation = pr_magnitude > SUSPECT_PR_MAGNITUDE`(D8)

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `new_e1rm` | float | (0, ~700] | 本 set 嘅 Formula 1 輸出 |
| `best_e1rm` | float | **(0, ~700] — 由 Rule 8 trusted-baseline 不變式 + ADR-0011 §D-2.2 per-entry validation 保證**(server 回 0 → ÷0 → INF → clamp 2.0 = 保證假 max PR;負數 → PR 永久 silent 死 — 兩個 degenerate 都喺 reconcile validation 層 reject) | baseline(無 trusted baseline → INV-PR-1,唔入呢條) |
| `MIN_PR_MAGNITUDE` | float | **0.01**(1%)knob [0.005, 0.05] | noise floor(epsilon-guarded;真 sub-floor 進步唔會永久消失 — ADR-0011 §D-2.3 ratchet 語意保證 server baseline 唔吸收 sub-floor 增幅,累積到過 floor 一次過 fire) |
| `MAGNITUDE_EPS` | float | 1e-9(const,非 knob) | float 邊界保護(「啱啱好 1%」唔被拒) |
| `SUSPECT_PR_MAGNITUDE` | float | **0.30** knob [0.15, 0.5] | soft-confirm 閾(D8) |
| `pr_magnitude` | float | [0, 2.0] | #11 Formula 2 input(range 對齊 #11 L323 ✓) |

**Output Range:** 0–2.0。**Example:** 60kg×5 baseline(e1rm 70)→ 65kg×5(e1rm 75.83)→ m = 5.83/70 = **0.0833** ✓ PR。
*Clamp 2.0 + #18 層 anomaly telemetry;**#11 嘅 Formula 2 clamp 係 incidental fail-soft(#11 EC-36 明文唔 own 防線責任)— 防線喺 #18 呢層**(ADR-0011 §D-3)。*

### Formula 3 — `pr_delta`(引用 #11,唔重定義)

`pr_delta = PR_BASE × pr_magnitude × (1.0 − (current_stat / MAX_STAT_VALUE) ^ PR_DIMINISH_EXP)`

> **Source of truth = #11 stat-system.md Formula 2**(PR_BASE 6.0 PROVISIONAL [1,20] / PR_DIMINISH_EXP 2.0 [1,4] / MAX_STAT_VALUE 999 — 全部 #11/ADR-0005 own,#18 唔複製 knob)。實作:shared static `PRDeltaCalc.compute(current_stat, magnitude)`(`src/core/pr_delta_calc.gd`)讀 #11 config 常數 — 單一 source(D3)。Worked example 見 #11 L330-344。`current_stat == 999` → delta 0.0 → Rule 6.3 short-circuit(skip apply,signal/count 照行)。

### Formula 4 — Baseline establishment window(INV-PR-1)

```
# 無 trusted baseline 嘅 exercise(local 無 + server sync 未提供):
on set_logged(ex, reps, weight):           # 過咗 Rule 2 gate
    candidates[ex] = max(candidates.get(ex, 0.0), e1rm)   # 只推高,零 PR
on #2 workout_completed:
    for ex in candidates:
        baselines[ex] = candidates[ex]      # session max 落 baseline
        emit baseline_established(ex, candidates[ex])      # Rule 11 moment
        emit telemetry "pr.baseline_established"
    candidates.clear(); persist pr.state (flush=true)
# Server baseline 喺 window 期間到達(validated)→ 該 exercise window 即終止,
# baseline = max(server_value, candidate) — candidate 高過 server 時保留 candidate 高度
#(零 PR fire — establishment 語意維持;ratchet 高度唔 lose,只 lose 一次 celebration,
#  deliberate accept + `pr.candidate_supersession` telemetry;reachability 窄 — §D-2.4
#  ordering 令主路徑唔可達,剩 per-entry reject 後補 / multi-poll 邊緣)。
# 之後嘅 set 正常判定(against 該 baseline)。
```

*第一個 workout = 基準日(成個 workout,唔淨係第一個 set — 否則 warmup ramp 40→50→60 嘅 set 2 起全部係假 PR,magnitude 0.2-0.33 級)。冇 baseline 就冇「突破」可言 — fabrication-proof。Server baseline(G-PR-1)令老用戶 pre-game 歷史係基準 — 接入嗰日唔會刷一輪假 PR。Candidate 喺 mid-workout crash 遺失 → window 下次該 exercise 出現時重開(degraded but safe — 永不假 PR,EC-10)。*

### Formula 5 — Session PR summary(getter schema)

`get_session_pr_summary() -> Dictionary`:
`{ exercise_id: { "weight_kg": float, "reps": int, "e1rm_kg": float, "magnitude": float } }`

Per-entry = 本 workout 內該 exercise **magnitude 最大嗰個 confirmed PR set 嘅完整 tuple**(四個 field 來自同一個 set — receipt「鍛造自 180kg × 5」砌得出真實一組;`e1rm_kg` 命名 explicit 係估算值,唔係 `one_rm`,Pillar 1 honesty)。**Clear 時機 = 下一個 #2 `workout_started`**(summary 喺成個 post-workout 窗口存活 — #15/#17 receipt 喺 loot claim time read 都零 race;唔用 workout_completed clear — 同 consumer read 同 signal = subscriber-order race)。`workout_completed` 之後遲到嘅 set(retro-logging / catch-up)判出 PR → stat 照生效(誠實),**唔入 summary**(EC-13)。

## Edge Cases

- **EC-1 (HIGH) — `exercise_id` UNKNOWN class**:skip + `pr.unknown_exercise`,零 side effect。**Pillar 1 cardio gate**(#11 L39 binding)。
- **EC-2 (MEDIUM) — 高 rep set(reps > 12)**:**clamp 唔係 skip**(D7)— `e1rm(W, 15) == e1rm(W, 12)`,true lower bound。同重量純加 rep 過 12 → 零 PR(誠實);加重照 PR。無嘈音 telemetry(正常訓練)。
- **EC-3 (CRITICAL) — `apply_stat_delta` return false**:abort 成個事件(baseline 唔升、signal 唔 emit、count 唔加)。#2 redelivery 或下一 set 重判 → 唔 lost。對齊 #11 EC-06。**`pr_delta == 0.0`(cap)係另一路徑** — short-circuit 唔 call apply,signal/count 照行(Rule 6.3)。
- **EC-4 (HIGH) — 同一 set replay(bfcache / catch-up)**:第一次判定已升 baseline → replay magnitude 0 → no-op(D5)。**Crash-window 殘餘**(6.3↔6.6 之間 tab kill)→ one-shot double-count,deliberate accept(D5 caveat — under-count 更傷)+ `pr.replay_recheck` telemetry。
- **EC-5 (HIGH) — `pr_magnitude > SUSPECT_PR_MAGNITUDE`(疑似 typo / kg-lb 錯)**:**D8 soft-confirm** — PENDING_CONFIRMATION(delta / signal / count / baseline 全 hold + `pr.pending_opened` telemetry);corroborated → commit(delta 以 clamped ≤2.0 計,baseline 升 raw e1rm — 唔 poison);無 corroboration 到下一 workout 完結 → discard + `pr.pending_discarded`。`> 2.0` 同時 emit `pr.magnitude_anomaly`。**唔再「照算 PR」**:GymSys 數據係「入咗咩」嘅 ground truth,唔係「舉咗咩」嘅 — Pillar 1 在乎後者。
- **EC-6 (MEDIUM) — Input sanity**:`weight <= 0` / `reps < 1` / `weight > WEIGHT_SANITY_MAX` / `weight < WEIGHT_SANITY_MIN` → skip + `pr.input_invalid`(AC-25)。
- **EC-7 (MEDIUM) — Server baseline 高過 local(BASELINE_SYNCING 期間判咗 local-base PR)**:server 覆寫(D2);已 apply stat delta 唔回收(#11 冇 negative path;one-shot,`pr.baseline_conflict` 記錄)。
- **EC-7b (HIGH) — Server baseline 低過 session-confirmed**(server snapshot 計算時點早過本 session 嘅 set):**session-confirmed floor**(D2)— 該 exercise baseline 唔被拉低過本 session confirmed PR 嘅 e1rm,否則 catch-up replay 重判 → double-count。`pr.baseline_conflict` telemetry。(AC-16)
- **EC-8 (MEDIUM) — Server baseline sync 失敗(offline)**:BASELINE_SYNCING 持續 — **有 local cache 嘅 exercise** 照判定(grace,ADR-0003 offline 容忍);**無 local cache 嘅 exercise** 行 INV-PR-1 establishment-only(fail-closed — 「清 IndexedDB + block endpoint」farm 路徑歸零)。
- **EC-9 (MEDIUM) — 同 workout 連續 PR**:各自獨立(Rule 7)。防線 = INV-PR-2 + #11 diminishing(AC-31 property test)。
- **EC-10 (MEDIUM) — 首 boot 完全無數據(新用戶 / 新 device offline)**:全部 exercise 行 establishment window(Formula 4)— 第一 session 零 PR、出 Baseline Forged moments(Rule 11)。第二 session 開始正常。Mid-workout crash → candidates 遺失 → window 重開(safe)。Onboarding copy(#27)講「基準日」— Q-PR-2。
- **EC-11 (LOW) — `pr.state` persist 失敗**:in-memory 保持(stat 已加,簽收一致);下次 boot local 缺 → server baseline 兜(D2);server 都缺 → 該 exercise 重行 establishment window(零假 PR — INV-PR-1 嘅 fail-closed 喺呢度都救)。注意 `flush=true` 失敗喺 #3 嘅 corrupt path 係 **whole-cache wipe** — 嗰 scenario 下全 store 重建,#18 局部推理 moot(誠實 acknowledge;#3 own)。
- **EC-12 (LOW) — Milestone thresholds 非 ascending**:`validate_milestone_config()` return false + push_error(fail loud;**唔用 raw assert** — GUT headless 測唔到,AC-20)。
- **EC-13 (LOW) — Retro-logged / late set(`workout_completed` 後先到)**:判定照行(stat 誠實),**唔入 session summary**(receipt 唔漏唔錯配)、唔觸發 Baseline Forged;`pr.late_set` telemetry。
- **EC-14 (LOW) — Singles dead-zone(intended)**:新 weight 高過歷史 bar weight 但 e1rm ≤ baseline(例:60×5 baseline e1rm 70 → 65kg×1 e1rm 67.2)→ 零承認。**Intended behaviour**(Position A 裁決):e1RM 尺話你身體本來估算可以 ~70 — 承認 65 single 做「成長」反而係 fabricate 示範事件。Emit `pr.weight_novelty_no_pr` telemetry — **發生率 ≥5% set 數 → v0.2 dual-track(best_weight 第二軌)提前**(Future Extensions)。
- **EC-15 (LOW) — Pending 自我 corroboration via replay**:catch-up redelivery 理論上可 redeliver suspect set 自我 corroborate。殘餘風險 accept:replay 來自 **server state** — 玩家喺 GymSys 改正 typo → set 消失 → 永不 redeliver → pending 自然 discard(自我修正);冇改正 = server 真相維持。`pr.pending_corroborated` telemetry 記 corroboration 來源 set 嘅 (reps, weight) 供審計。
- **EC-16 (MEDIUM) — Server baseline entry invalid**:per-entry validation = `is_finite(v) ∧ v >= WEIGHT_SANITY_MIN ∧ v <= WEIGHT_SANITY_MAX × (1 + REP_CAP / 30.0)`(下界係 **WEIGHT_SANITY_MIN 唔係 0** — near-zero entry(如 0.5)係 ÷0 嘅 sibling:tiny baseline → 正常 set clamp-2.0 假 max PR,而且 D8 corroboration 對細 absolute 值 trivially pass,保護唔到;上界用公式唔 hardcode 700,免 REP_CAP knob coupling)。唔過 → reject 該 entry(保留 local)+ `pr.baseline_invalid`(ADR-0011 §D-2.2;AC-23)。

## Dependencies

### Upstream(#18 依賴,Hard)
| 系統 | Hard/Soft | Interface | 缺佢會點 |
|------|-----------|-----------|----------|
| **#2 GymSysBackendClient** | Hard | `set_logged` + `workout_started` / `workout_completed` + G-PR-1 baseline field | 無 set 流 → 系統盲 |
| **#10 ExerciseClassMapping** | Hard | `get_class_for_exercise` | 無法 route stat;UNKNOWN gate 失效 |
| **#11 Stat System** | Hard | `apply_stat_delta` + `get_stat` + Formula 2 常數 | PR 無法生效 — Pillar 1 斷鏈 |
| **#3 PersistenceLayer** | Hard | `pr.state` key(G-PR-6 namespace) | baseline / count 唔 persist |
| **ADR-0011** | Hard(contract) | topology + G-PR-1 四 sub-spec + guarantee mapping | 信任錨點無 spec — Pass 1 四個 degenerate 重現 |

### Downstream(依賴 #18)
| 系統 | Hard/Soft | #18 提供 |
|------|-----------|----------|
| **#12 Ability System** | Hard(unlock Path A) | `pr_breakthrough(stat_id, magnitude)`(reverse-wired;G-PR-4 pinned / G-PR-5 additive) |
| **#9 WST** | Soft(G-PR-2) | signal → pr_count(→ #15 pr_factor) |
| **#15 / #17** | Soft | `get_session_pr_summary()`(Formula 5 — raw weight/reps 齊) |
| **#19 Zone** | Soft(v0.2 per CD directive) | `pr_milestone_reached(count)` + `lifetime_pr_score` |
| **#20 / #29** | Forward contract | `baseline_established` / `baseline_import_completed` + celebration 斷言 |
| **#26 Avatar** | Indirect | (經 #11/#12 — ADR-0010 邊界) |

### ADR / 架構約束
- **ADR-0011**(Accepted-contract):topology(Q3 supersession)+ G-PR-1 server baseline contract + #11 EC-36 / #12 FR-2+EC-35+EC-16 guarantee mapping + caller path。
- **ADR-0002**(Locked):set_logged 係 5 workout signals 之一;cursor/idempotency 由 #2 own。
- **ADR-0003**:`pr.state` backend-primary;PR 確認 `flush=true`。
- **ADR-0005**:`PR_BASE` PROVISIONAL — ratification 時 PR delta 同 loot rarity cross-validate(#11 L335)。#18 唔 own。
- **ADR-0006**:Contract 4(boot 順序)+ Contract 6(GSM 訂閱)。
- **ADR-0008**:gate G-PR-3 — full chain(Rule 10)insertion rule 待 amendment。
- **CI**:`tools/ci/check_stat_mutation_callers.gd` whitelist amend(`src/feature/` → `src/autoload/pr_detection.gd`)落 epic story(ADR-0011 §D-4;lint 本身 vacuous — regex 被 DI 慣例繞過 + 2/4 whitelist stale — escalated lead-programmer,獨立 CI-tooling story)。

## Tuning Knobs

| Knob | 預設值 | Safe Range | 影響 / 太高 / 太低 |
|------|--------|-----------|---------------------|
| `REP_CAP` | 12 | [8, 15] | Formula 1 rep clamp(D7)。太高 → 高 rep 外推失真;太低 → rep-PR 空間收窄 |
| `MIN_PR_MAGNITUDE` | 0.01 | [0.005, 0.05] | noise floor(epsilon-guarded)。太高 → 微量加重唔算 PR;太低 → rounding noise。Q-PR-1 真數據校準 |
| `SUSPECT_PR_MAGNITUDE` | 0.30 | [0.15, 0.5] | soft-confirm 閾(D8)。太低 → 真 detraining-return PR 都要等 corroboration;太高 → typo 漏網 |
| `CORROBORATION_RATIO` | 0.95 | [0.85, 1.0] | pending corroboration 容差。太低 → 弱 corroboration;太高 → 同重 doubles 都 corroborate 唔到 |
| `WEIGHT_SANITY_MAX` | 500.0 kg | [300, 1000] | Rule 2 input gate 上限(世界紀錄 ~500kg) |
| `WEIGHT_SANITY_MIN` | 1.0 kg | [0.5, 5.0] | Rule 2 下限 — 擋 tiny-baseline seed(cable/band 異常 logging) |
| `PR_MILESTONE_THRESHOLDS` | [10, 25, 50, 100] **PROVISIONAL** | ascending ints | milestone hooks(#19 v0.2;Q-PR-1 校準前唔接 gameplay)。EC-12 validate |
| `E1RM_DIVISOR` | 30.0 | **LOCKED(Epley 定義)** | 非 knob — server parity 都鎖呢個值(ADR-0011 §D-2.1) |
| `MAGNITUDE_EPS` | 1e-9 | const(非 knob) | float 邊界保護 |
| `PR_BASE` / `PR_DIMINISH_EXP` | (#11 own) | — | 指向 #11 Formula 2 / ADR-0005(單一 source) |

## Telemetry(機制 pin)

跟 shipped 慣例(#15/#17 pattern,**verbatim**:`loot_drop_system.gd:119,307` / `inventory_system.gd:100,1076`):internal `_telemetry_log: Array[Dictionary]` **append log**(unbounded,同 #15/#17 — 唔係 ring;#28 forwarding 時再議 cap)+ `_emit_telemetry(event: String, data: Dictionary)` helper(**`String` 唔係 StringName** — 跟 shipped 簽名)+ `get_telemetry()` test surface(seam 5)。Events(16):`pr.detected` / `pr.input_invalid` / `pr.unknown_exercise` / `pr.baseline_established` / `pr.magnitude_anomaly` / `pr.baseline_conflict` / `pr.baseline_invalid` / `pr.pending_opened` / `pr.pending_corroborated` / `pr.pending_replaced` / `pr.pending_discarded` / `pr.weight_novelty_no_pr` / `pr.late_set` / `pr.replay_recheck` / `pr.persist_failed` / `pr.candidate_supersession`。

## Visual/Audio Requirements

> #18 係 data/logic 層 — 慶祝由 presentation own;本節列 co-trigger contract + forward 斷言。

| 事件 | 通道 | 約束 |
|------|------|------|
| PR confirmed(mid-session) | #20 HUD stat-jump(`stat_changed` source==PR_BREAKTHROUGH **distinct 視覺 variant** — 唔可以同 volume tick 同款淨係數字大啲)+ #4 SFX 短 sting 經 #33 | Set 後 glance,mid-set 唔搶注意(Pillar 2);sting 音量低係 **intended**(mid-session 層級受 Pillar 2 cap) |
| **End-of-workout PR recap** | #20/#29(forward contract) | **層級 ≥ loot tier** — meaning hierarchy 喺注意力免費時刻重奪(數據 = `get_session_pr_summary()`);#20 backlog |
| Baseline Forged | #20 glance / post-workout summary | **唔可以 telemetry-only**(AC-28 binding)— 第一 session 嘅 PRIMARY pillar 反饋 |
| Baseline import reveal | #20/#27(forward hook) | veteran 接入日「你嘅真實力量已鍛入」— Pillar-1-pure |
| ability unlock(#12 下游) | #12/#20 own | #18 唔直接觸發 UI |
| milestone reached | telemetry only(MVP;#19 v0.2) | — |

> 📌 **Asset Spec** — PR sting SFX 係本系統唯一 asset 需求。Art bible approve 後跑 `/asset-spec system:pr-detection`。

## UI Requirements

> #18 **無自己 UI**。Data surfaces:

| Surface | Consumer | #18 提供 |
|---------|----------|----------|
| Stat-jump popup | #20(經 #11 `stat_changed` source filter) | (間接) |
| Baseline Forged / import reveal | #20(glance 通道) | `baseline_established` / `baseline_import_completed` signals |
| PR 歷史 / baseline 顯示 | #22 Character Screen(v0.2) | `get_baselines() -> Dictionary`(read-only copy) |
| Session PR summary / recap | #15/#17 receipt 鏈 + #20 recap | `get_session_pr_summary()`(Formula 5) |

## Acceptance Criteria

> GWT;Logic = unit-testable。**Test seams(8,對齊 #17 慣例)**:① #2 signal 注入(set_logged / workout_started / workout_completed)② #2 baseline async response mock(capture-and-release — AC-14/15/16/23 ordering)③ #10 mock ④ #11 mock(apply_stat_delta return 控制 + get_stat)⑤ telemetry spy(append-log 讀取 `get_telemetry()` — #17 seam 5 同款)⑥ persistence spy/mock ⑦ #12/#9 handler spy(signal 接收驗證)⑧ GSM mock(emit gate / 靜默)。**無 TimeProvider seam**(#18 無 clock 依賴;daily reset 係 #9-side — G-PR-2 spec)。Epsilon:golden 數值 assert ±0.001(除非另注)。

### Detection pipeline
- **AC-01 (Logic)** — **GIVEN** trusted baseline bench=70.0 **且 STR=12.0**,**WHEN** `set_logged("bench_press", 5, 65.0)`(e1rm 75.833),**THEN** `apply_stat_delta(&"str", PR_BREAKTHROUGH, δ)` called once,δ ≈ **0.500**(±0.001 — AC-12 golden 重用)、`pr_breakthrough(&"str", 0.0833 ±0.001)` emitted、baseline → **75.833**(±0.001)、`pr.state` persist flush=true 一次、`pr.detected` telemetry emitted。
- **AC-02 (Logic)** — **GIVEN** baseline 75.83(AC-01 後),**WHEN** 同一 set replay,**THEN** 零 stat call、零 signal、**baseline 不變、零 persist write**(EC-4 idempotency)。
- **AC-03 (Logic)** — **Warmup-ramp golden(INV-PR-1)**:**GIVEN** 無 trusted baseline 嘅新 exercise,**WHEN** 同一 workout 內 `set_logged` ×3(40kg×5 → 50kg×5 → 60kg×5),**THEN** 三個 set 全部零 PR(零 stat call / 零 signal / 零 count);**WHEN** #2 `workout_completed`,**THEN** baseline = 70.0(session max e1rm)+ `baseline_established("…", 70.0)` emitted + `pr.baseline_established` telemetry;**WHEN** 下一 workout `set_logged(65kg×5)`(e1rm 75.83),**THEN** 正常 PR confirmed(m ≈ 0.0833)。
- **AC-04 (Logic)** — **GIVEN** #10 回 UNKNOWN,**WHEN** `set_logged("treadmill_run", …)`,**THEN** skip:零 stat call、零 signal、零 baseline/candidate write、零 persist;`pr.unknown_exercise` telemetry(spy assert)(EC-1)。
- **AC-05 (Logic)** — **Rep clamp golden(D7)**:`e1rm(100.0, 15) == e1rm(100.0, 12) == 140.0`;**GIVEN** baseline 140.0(100×12 建立),**WHEN** `set_logged(100kg×15)`(rep-only 增長),**THEN** 零 PR;**WHEN** `set_logged(110kg×15)`,**THEN** PR confirmed(e1rm 154,m = 0.1)。
- **AC-06 (Logic)** — **GIVEN** baseline 100.0,**WHEN** `set_logged(86.4kg×5)`(e1rm 100.8,m = 0.008 < floor),**THEN** 唔算 PR,baseline 不變。
- **AC-07 (Logic)** — **Soft-confirm 三路徑(D8/EC-5)**:**GIVEN** baseline 70.0,**WHEN** `set_logged` 計出 raw m = 3.5(typo 級),**THEN** PENDING opened(零 delta / 零 signal / 零 count / baseline 不變)+ `pr.magnitude_anomaly` + `pr.pending_opened`;**(a) corroborate**:後續 set e1rm ≥ pending.e1rm_raw × 0.95 → commit(**magnitude 以 commit 時 current baseline 重計**(D8 pipeline)再 clamp → 2.0;delta 以重計 clamped 值計;baseline 升 pending **raw** e1rm;signal magnitude = 2.0)+ `pr.pending_corroborated`;**(b) discard**:開 pending 後嘅下一個 workout `workout_completed`(`current_seq > opened_seq`)仍無 corroboration → pending 清空、baseline 不變、`pr.pending_discarded`;**(c) 正常 anomaly**:m = 0.25(< SUSPECT)→ 即時 confirmed,無 pending。
- **AC-08 (Logic)** — **GIVEN** `apply_stat_delta` mock return false,**THEN** baseline 不變、零 signal、`lifetime_count` 不變、session summary 不變、零 persist(EC-3 all-or-nothing,三個 count 面 enumerate)。
- **AC-09 (Logic)** — **GIVEN** push/pull/leg 三個 exercise 各一 PR,**THEN** 分別 route `&"str"` / `&"dex"` / `&"vit"`(D4 golden)。
- **AC-10 (Logic)** — **GIVEN** baseline 70.0,**WHEN** 同 workout `set_logged(65kg×5)`(e1rm 75.83,m₁ ≈ 0.0833)→ `set_logged(75kg×2)`(e1rm **80.0**,m₂ = (80−75.83)/75.83 ≈ **0.0550**),**THEN** 兩次各自生效,第二次以 75.83 為 base(EC-9)。

### Formulas
- **AC-11 (Logic)** — Formula 1 golden:`e1rm(60, 5) == 70.0`;`e1rm(65, 3) == 71.5`;`e1rm(100, 1) ≈ 103.33`(**reps=1 同樣經 Epley,唔特判**);`e1rm(100, 15) == 140.0`(clamp)。
- **AC-12 (Logic)** — PRDeltaCalc golden(對齊 #11 worked example):`compute(12.0, 0.0833) ≈ 0.500`(#11 L338-340;**pinned 於 PROVISIONAL PR_BASE=6.0 — ADR-0005 retune 時 update test**)。
- **AC-13 (Logic)** — `compute(999.0, m) == 0.0` for m ∈ {0.01, 0.5, 2.0}(pinned sample set);**且** Rule 6.3 short-circuit:capped 玩家 PR → 零 `apply_stat_delta` call、baseline 照升、signal/count 照 emit。
- **AC-24 (Logic)** — **Boundary exact**:**GIVEN** baseline 100.0,**WHEN** set 計出 e1rm 101.0(m = 0.01 整),**THEN** PR confirmed(epsilon guard — 唔被 float 拒)。

### Baseline sync / reconcile
- **AC-14 (Logic)** — **GIVEN** local baseline 70 + server 回 85(validated),**WHEN** sync 完成(capture-release seam),**THEN** baseline = 85 + 後續判定用 85(D2 server 贏 pre-session)。
- **AC-15 (Logic)** — **GIVEN** server sync fail(offline mock):**(a)** 有 local cache 嘅 exercise → 照判定(grace);**(b)** 無 local cache 嘅 exercise → establishment-only,零 PR(INV-PR-1 fail-closed;EC-8 兩路徑都 assert)。
- **AC-16 (Logic)** — **Double-count race(EC-7b)**:**GIVEN** BASELINE_SYNCING 期間 local-base PR 已 confirmed(baseline → 75.83),**WHEN** server response 返 70(計算時點早過該 set;capture-release),**THEN** baseline 維持 75.83(session-confirmed floor — 唔被拉低)+ `pr.baseline_conflict`;**WHEN** 同一 set catch-up replay,**THEN** no-op(零 double-count)。
- **AC-23 (Logic)** — **Server entry validation(EC-16)**:**GIVEN** server 回 `{a: 0.0, b: -10.0, c: INF, d: 0.5, e: 800.0, f: 85.0}`,**THEN** a/b/c/d/e reject(local 保留;d = near-zero sibling < WEIGHT_SANITY_MIN;e > 上界 700)+ `pr.baseline_invalid` ×5;f 正常採納(ADR-0011 §D-2.2)。

### Persistence / summary / milestone
- **AC-17 (Integration)** — `pr.state` envelope(baselines + pending + candidates + lifetime_count + lifetime_pr_score)round-trip 還原;PR 確認 = **一次** write flush=true(Rule 6.6 collapse)。
- **AC-26 (Logic)** — **GIVEN** persist write return false(EC-11),**THEN** in-memory 保持(後續判定一致)+ `pr.persist_failed` telemetry;唔 crash。
- **AC-18 (Logic)** — **GIVEN** 本 workout 同一 exercise 兩個 PR(m 0.0833 → 0.0550),**WHEN** `get_session_pr_summary()`,**THEN** 1 entry = **m 最大嗰個 set 嘅完整 tuple**(weight_kg=65.0 / reps=5 / e1rm_kg=**75.833** ±0.001 / magnitude=0.0833 — 四 field 同源);兩個唔同 exercise → 2 entries;**WHEN** `workout_completed`,**THEN** summary **仍在**(post-workout 窗口);**WHEN** 下一個 `workout_started`,**THEN** clear。
- **AC-19 (Logic)** — **GIVEN** lifetime_count 9 → PR → 10,**THEN** `pr_milestone_reached(10)` emit;**GIVEN** boot 載入 count=10(已過 threshold),**THEN** 零 re-emit(crossing-only)。
- **AC-20 (Logic)** — **GIVEN** milestone config [10, 5, 50],**THEN** `validate_milestone_config() == false` + push_error(spy 可測 — 唔用 raw assert)。
- **AC-25 (Logic)** — **Input sanity(EC-6)**:`(reps=0)` / `(weight=0)` / `(weight=600)` / `(weight=0.5)` 四個 vector 全部 skip + `pr.input_invalid`,零 side effect。

### Boot / lifecycle / experience
- **AC-27 (Logic)** — Boot ordering:load `pr.state` **先於** subscribe #2(injection order assert);`_ready` 完結時 state == READY(synchronous,INITIALISING 唔跨 frame);boot 載入帶 stale candidates 嘅 envelope → candidates discard(Rule 8a)。
- **AC-29 (Logic)** — **Pending-interleaved magnitude 重計(D8 / INV-PR-2)**:**GIVEN** baseline 70.0,**WHEN** set A e1rm 94.5(raw m = 0.35 > SUSPECT → pending)→ interleaved 正常 PR set(e1rm 76.0,m ≈ 0.0857,confirmed,baseline → 76.0)→ set B e1rm 92.0(≥ 94.5 × 0.95 = 89.775 → corroborate),**THEN** commit magnitude = **(94.5 − 76.0) / 76.0 ≈ 0.2434**(重計 — 唔係 stored 0.35),baseline → 94.5;Σm = 0.0857 + 0.2434 ≈ **0.3291 ≤ (94.5−70)/70 = 0.35**(INV-PR-2 upper bound 保持)。
- **AC-28 (Logic + Experience binding)** — **Baseline Forged**:establishment commit 時 `baseline_established(exercise_id, e1rm)` emitted(handler spy)— **binding:呢個 moment 有 player-visible consumer 通道**(#20 forward contract;#18-side AC assert signal + payload;presentation 面 AC 由 #20 own)。
- **AC-30 (Logic)** — **Emit gate(#12 EC-16 / Rule 6.7)**:**GIVEN** GSM mock = SUSPENDED + capped 玩家(pr_delta==0 short-circuit path — 6.3 嘅 #11 suspended check 唔行,gate 係唯一防線),**WHEN** PR pipeline 行到 6.7,**THEN** `pr_breakthrough` 唔 emit、入 one-slot pending-emit buffer;**WHEN** GSM leave-SUSPENDED,**THEN** buffer flush(signal emit exactly once)。GSM 靜默:state 轉換時 #18 零 active 行為(telemetry only)— **唯一例外 = pending-emit buffer flush on leave-SUSPENDED**。
- **AC-31 (Logic)** — **INV-PR-2 property test**:對步進序列 70 → 75.83 → 80 → 90(全 confirmed),assert `ln(90/70) ≤ Σm ≤ (90−70)/70`(±1e-6);再對 micro-step 序列(1% ×20 步)assert 同一 bound — farming 無 stat 著數嘅數學保證。

### 整合面
- **AC-21 (Integration)** — **GIVEN** 真 #12(或 contract spy),**WHEN** PR confirmed(STR),**THEN** `AbilitySystem._on_pr_breakthrough` 收到 `(&"str", m)` **exactly once**(G-PR-4 reverse-wire;#18-side 止於 handler invocation — #12 內部 Path A 行為由 #12 own)。
- **AC-22 (Integration,⛔ GATED on G-PR-2)** — **#18-side**:PR ×3 → `pr_breakthrough` emit ×3(handler spy count)。count 累計 + daily reset 係 **#9-side AC**(G-PR-2 amendment spec own,per #9 daily 語意 — #18 唔 hardcode UTC;#9-side TimeProvider seam)。**G-PR-2 未落地前本 AC 唔可執行 — epic 排 story 時標 BLOCKED-ON gate。**

## Future Extensions(v0.2+,非 MVP)

- **Dual-track baseline(best_weight 第二軌)** — trigger:`pr.weight_novelty_no_pr` ≥5% set 數(EC-14 telemetry 實證後先做;Position A 裁決)。
- **Windowed「recent best」慶祝事件**(90-day tier,只餵 loot/ceremony 永不餵 stat)— plateau/returner drought 緩解;Pillar 1 相容(都係關於身體嘅真話)。
- **PR_SCORE zone unlock**(#19 v0.2;Σmagnitude 軸 ratify + Q-PR-1 校準;#19 P2 裁決 — MVP 兩邊都零接線)。
- **PR 歷史 surface**(#22 Character Screen)。

## Open Questions / Cross-System Gates

| # | 問題 | Impact | Resolution path | Owner |
|---|------|--------|-----------------|-------|
| **G-PR-1** | GymSys backend baseline API — **contract 已 spec(ADR-0011 §D-2:formula parity / per-entry validation / confirmed-ratchet 語意 / polling-field timing)**;剩 backend 實作 story + parity spot-check | D2 server-baseline 依賴 | GymSys API extension 實作(user 自有 backend);offline grace + INV-PR-1 令缺佢唔 block | #2 / GymSys backend |
| **G-PR-2** | #9 additive:`pr_breakthrough` handler(**#18 reverse-wire,方向同 #12 一致**)+ `get_pr_count_today()` getter + daily reset 語意(**#9 own;TimeProvider seam #9-side**) | #15 pr_factor 數據鏈;AC-22 gate | #9 GDD focused amendment | #9 |
| **G-PR-3** | ADR-0008 insertion:**constraint `#2 ≺ #10 ≺ StatSystem ≺ {AbilitySystem, WST} ≺ PrDetection`**(AbilitySystem/WST 之間零相互 constraint — **現行 project.godot 順序 StatSystem → AbilitySystem → StreakSystem → WST(`project.godot:42-45`)保持不變**;#18 append 鏈尾,AttentionBudget 之後) | autoload boot | ADR-0008 focused amendment(照 #17 G-4 先例) | technical-director |
| **G-PR-4** | ✅ **RESOLVED-pinned**:#12 handler = `AbilitySystem._on_pr_breakthrough`(`ability_system.gd:895`,簽名 match,shipped comment L884-888 明文係 #18 entry point) | boot-order-safe 接線 | (pinned;G-PR-5 story 順手修 L890 magnitude comment) | — |
| **G-PR-5** | **#12 additive(scope:1 行 code + 3 配套)**:(a) `_on_stat_changed` skip `source == PR_BREAKTHROUGH` — 否則 double-path(STAT_THRESHOLD provenance 搶先 + deferred flush crash window);(b) **shipped test 反轉**:`tests/unit/ability_system/test_unlock_path_b_multi_tier.gd:98-99` 現 assert PR-sourced stat_changed 經 Path B unlock — 改 assert 零 Path B unlock for source==0,否則 CI 即紅;(c) `is_boot_completed()` getter(mirror #11 G-2 先例 — AC-30 #12-half assert surface);(d) L890 comment 修正(magnitude = relative ratio 唔係 delta)。Approved-upstream additive amendment(EG-1 先例) | PR provenance + AC-13 flush 正確性 + AC-30 | #18 epic wiring story | #18 epic / #12 |
| **G-PR-6** | **#3 `pr.` namespace 註冊**:VALID_NAMESPACES(`persistence_layer.gd:291-294`)一行 + #3 GDD Rule 12 registry 一行 + namespace lint **create-or-amend**(#3 GDD L128 spec 咗 `check_key_namespace_convention.sh` 但 tools/ci/ **未 shipped** — story 執行時 create 或記 follow-up,唔好假設有嘢可 amend) | debug build per-write push_warning | #18 epic story(additive;#3 L415 程序) | #18 epic / #3 |
| **Q-PR-1** | Knob 校準(**scope 擴大**):用 user 真 GymSys 歷史回放 — (a) PR 頻率分佈 by training age(驗 Expected Frequency 表);(b) `REP_CAP` / `MIN_PR_MAGNITUDE` / `SUSPECT_PR_MAGNITUDE` 初值;(c) #11 diminishing 喺 MVP stat range 嘅 inertness 量度;(d) milestone thresholds。**Validation criteria**:首 workout 零 PR / novice 每週 2-6 PR / `pr.weight_novelty_no_pr` <5% / 零 m>0.3 無 corroboration commit | PR 頻率 feel + balance anchor | VS-tier 真數據回放 | balance / VS-tier |
| **Q-PR-2** | Onboarding「基準日」copy — #27 own 句子;**moment 本身 #18 已 binding emit**(Rule 11 + AC-28),#20 glance 通道 interim | 新用戶 expectation | #27 GDD authoring 時收 | #27 |

> **Review 處理紀錄**:Pass 1(MAJOR)16 BLOCKING clusters + Position A–F 裁決 → revision + ADR-0011 同日;Pass 2 fresh 3-verifier re-review(systems-designer + qa-lead + godot-specialist)— Pass 1 全 FIXED、citation 0 phantom,揭 6 targeted BLOCKING(AC-30/Rule 6.7 矛盾 / server ratchet D8 語意 / near-zero hole / pending stale-magnitude 破 INV-PR-2 / G-PR-3 chain 方向 vs project.godot / AC-29 gap)→ Pass 3 targeted fixes 全落(本版)。詳見 `design/gdd/reviews/pr-detection-review-log.md`。
