# PR Detection & Avatar Progression

> **Status**: In Design
> **Author**: frank + agents (design-system — degraded inline mode: specialist spawns blocked by 1M-context credits 2026-06-06;sections 由 main session 以 specialist 視角 inline 起草,全部跟 recommended per user autonomous 授權。**Review manually via fresh-session /design-review before production。**)
> **Last Updated**: 2026-06-06
> **Implements Pillar**: Pillar 1 (Real Body, Real Power — **PRIMARY**:anti-fabrication 鏈嘅 PR 入口)· Pillar 4 (Muscle = Class — supporting:PR 按肌群 route 落 stat/ability)· Pillar 5 (Mirror Moment — supporting:PR 係 evolution 鏈嘅最強驅動)
> **Layer / Tier**: Feature / Pre-MVP
> **Depends On**: #2 GymSysBackendClient · #3 PersistenceLayer · #10 ExerciseClassMapping · #11 Stat System · (#12 Ability System 係 downstream signal consumer)

## Overview

PR Detection & Avatar Progression 係 Mirror Hero 嘅 **Pillar 1 心臟** —— 將玩家真實嘅 1RM breakthrough 轉化成遊戲內**唯一**嘅大幅成長事件。系統訂閱 #2 嘅 `set_logged(exercise_id, reps, weight)` 原始流(**直訂 #2,唔經 #9** — #9 L863 sibling-consumer split),對每個 set 計 estimated 1RM(Epley),同 **server-sourced historical baseline** 比較,判定 PR 後:(1) 經 #11 Formula 2 計 `pr_delta` 並 call `apply_stat_delta(stat_id, PR_BREAKTHROUGH, delta)`(caller path GDD-locked:`src/feature/pr_detection.gd`);(2) emit `pr_breakthrough(stat_id, magnitude)` signal 畀 #12 做 ability unlock 評估;(3) 通知 #9 increment `pr_count_today`(#15 loot rarity 嘅 pr_factor input)。

**Q-N3 RESOLVED(本 GDD close,carried from game-concept Q3)**:PR 判定採 **client-side derivation over server-sourced inputs**。判定用嘅三個 input 全部係 server data —— set 數據由 GymSys 後端記錄並經 #2 polling 落地(client 冇 fabricate 面),historical baseline 由 GymSys 提供(`pr.baseline` 經 #2 API extension,gate G-PR-1),公式係 deterministic 純函數。Client 冇任何自由輸入可以偽造 PR —— 等效 server-validated(滿足 #12 FR-2),而且零額外 round-trip(Pillar 2:判定即時,mid-set 唔等 server)。

**Avatar Progression scope(ADR-0010 邊界)**:#26 AvatarRenderer **own** evolution tier 計算(由 #11 stat + #12 ability sync read derive,Formula 2 @ #26)—— 本系統**唔重複**呢個邏輯。#18 嘅 progression 角色係**事件源**:PR → stat delta → #26 tier 自然推進;PR → ability unlock → #26 posture 變化。另加 PR milestone tracking(累計 PR count 嘅 forward hooks → #19 zone unlock / v0.2 cosmetic),MVP 只記錄 + telemetry,唔觸發內容。

## Player Fantasy

**核心情緒**:「**我喺 gym 入面突破嘅嗰一刻,遊戲世界即時承認佢**」—— 真實 PR 嘅腎上腺素同 in-game 慶祝係**同一個 moment**,唔係事後補發。

**錨定時刻**:玩家 bench press 卡咗三個禮拜嘅 60kg,今日上到 65kg。Rack 返條 bar、抹汗、攞起部機 —— 畫面上 avatar 嘅 STR 數字跳咗 +0.5(全 session 最大嘅單次跳)、一條 strike ability 解鎖 toast、今日 loot rarity 因 pr_factor 而升呢。**「呢個唔係 game 送你嘅 —— 係你舉返嚟嘅。」**(unique hook:Like Pokémon evolution, AND ALSO YOU yourself are evolving)

**間接層(infrastructure 面)**:玩家唔會「操作」PR Detection —— 佢哋操作槓鈴。系統嘅存在感係透過效果:stat 跳、ability 解鎖、loot 升呢、avatar 進化。Design 上呢個系統永遠唔可以要求 mid-set 注意(Pillar 2)—— 所有 PR 反饋都係 set 完成後嘅 glance 獎勵。

**反面界定**:呢個唔係「自動偵測你今日狀態」嘅 AI 教練,亦唔做 form 分析 —— 純粹 1RM 數字突破判定。Cardio / 步數 / 非阻力訓練**永不**觸發(anti-pillar #5:Apple Watch 整合不可侵蝕 strength training 核心)。

## Detailed Design

### Core Rules

> **Resolved cross-system decisions(D1–D6,authoring 時 lock;provisional until /design-review):**
> - **D1(Q-N3 close)** — PR 判定 = client-side derivation over server-sourced inputs(set 數據 + baseline 都係 GymSys server data;公式 deterministic)。無 per-PR server round-trip。
> - **D2** — Baseline 來源 = GymSys server historical(gate G-PR-1:#2 API extension 提供 per-exercise best e1RM);local persist(`pr.best.*`)做 offline cache;**server 值永遠贏**(boot reconcile 取 max 係錯 —— 取 server,因為 server 先係 ground truth,local 只係 cache)。
> - **D3** — `pr_delta` 計算 follow **#11 Formula 2**(`PR_BASE × pr_magnitude × diminishing_factor`),caller(#18)負責計(per #11 L255)。實作為 shared static calc(`src/core/pr_delta_calc.gd`)讀同一 config 常數 —— 唔 inline 重抄(knob-drift;#17 G-2 同款教訓)。`PR_BASE = 6.0` PROVISIONAL(ADR-0005 retune gate)屬 #11/ADR-0005 own,#18 只引用。
> - **D4** — Class routing 經 #10:`exercise_id → AbilityClass → stat_id`(STRIKE→STR / CONTROL→DEX / MOBILITY→VIT)。`UNKNOWN` class → **skip + telemetry**(Pillar 1 cardio gate:#10 唔識嘅 exercise 唔餵 stat — #11 L39 binding)。
> - **D5** — Idempotency 靠 **baseline monotonicity**:PR 確認後 baseline 即時升到 new e1RM → 同一 set 嘅 replay(bfcache / #2 catch-up redelivery)計出嘅 e1RM 唔再超 baseline → 自然 no-op。無需 set-level dedup id(`set_logged` payload 冇 id — #2 schema locked)。
> - **D6** — `pr_count_today` ownership:**#18 detect,#9 count**。#18 emit `pr_breakthrough` → #9 subscribe + increment 內部 daily counter → #15 read `get_pr_count_today()`(#15 L293 shipped 讀 #9 — 零 #15 churn)。Gate G-PR-2:#9 additive amendment(getter + subscriber;getter 現時未實作,grep src 0 hits — 係 #15 嘅 deferred 面)。

1. **Set 事件接收** — 訂閱 #2 `set_logged(exercise_id: String, reps: int, weight: float)`(直訂,#9 L863 split)。每個事件行 Rule 2-7 嘅判定 pipeline。#2 own delivery semantics(suspended queue / catch-up replay)—— #18 對 replay 安全(D5)。
2. **Eligibility gate** — 順序檢查,任一不過 → skip(無 side effect):
   - `reps < 1` 或 `weight <= 0` → skip + `pr.input_invalid` telemetry(defensive — #2 schema 應保證)。
   - `reps > REP_CAP`(12)→ skip,唔係 PR 候選(高 rep set 嘅 e1RM 外推不可靠;Epley 喺 12+ rep 誤差 >10%)。
   - #10 `get_class_for_exercise(exercise_id)` 回 `UNKNOWN` → skip + `pr.unknown_exercise` telemetry(**Pillar 1 cardio gate** — 非阻力訓練 / 未映射動作永不餵 stat)。
3. **e1RM 計算** — Formula 1(Epley):`e1RM = weight × (1 + reps / E1RM_DIVISOR)`。
4. **Baseline 比較** — 攞該 `exercise_id` 嘅 `best_e1rm`(Rule 8 baseline store)。**Cold-start**:baseline 不存在(server 無歷史 + local 無)→ 將本 set 嘅 e1RM 寫入做 baseline,**唔算 PR**(第一次做新動作係建立基準,唔係突破 — Pillar 1 honest)+ `pr.baseline_established` telemetry。
5. **PR 判定** — Formula 2:`pr_magnitude = (new_e1rm − best_e1rm) / best_e1rm`。`pr_magnitude < MIN_PR_MAGNITUDE`(0.01)→ 唔算 PR(float noise / 微小 rounding 唔好嘈);`≥ MIN_PR_MAGNITUDE` → **PR confirmed**,行 Rule 6-7。`pr_magnitude` clamp 上限 2.0(#11 Formula 2 input range;>2.0 = anomaly,clamp 後照算 — #11 嘅 clamp 係最後防線,#18 喺自己層都 clamp + `pr.magnitude_anomaly` telemetry)。
6. **PR 生效(順序 binding)** —
   1. `stat_id = class → stat` mapping(D4)。
   2. `pr_delta = PRDeltaCalc.compute(stat_id 嘅 current_stat, pr_magnitude)`(D3;current_stat 經 `StatSystem.get_stat(stat_id)` —— 注意呢度讀嘅係 base stat 名 `&"str"` 等,PR_BREAKTHROUGH 只准 base)。
   3. `ok = StatSystem.apply_stat_delta(stat_id, StatSource.PR_BREAKTHROUGH, pr_delta)`。**`ok == false` → 唔升 baseline、唔 emit signal、唔 count**(#11 EC-06:persist 失敗 → backend reconcile 下次 boot retry;#11 reject(suspended 等)同樣 — PR 事件由 baseline 未升保證可重判)。
   4. 成功後:baseline 升到 `new_e1rm` + persist(`pr.best.<exercise_id>`,`flush=true` — PR 係 anti-fabrication anchor moment,同 #11 Rule 7 一致)。
   5. emit `pr_breakthrough(stat_id, pr_magnitude)`(#12 subscribe → Path A unlock 評估;#9 subscribe → count increment,D6)。
   6. emit `pr.detected` telemetry(exercise_id / magnitude / stat_id / delta)。
7. **同 workout 連續 PR** — 每次 PR 後 baseline 即升,同一 workout 內再突破(漸進加重)→ 每次都係獨立 PR,各自判定(magnitude 以最新 baseline 計 —— 連續細突破各算細 PR,合理:#11 diminishing + #15 MAX_PR_FACTOR cap 已防 farming)。
8. **Baseline store** — `Dictionary { exercise_id: String → best_e1rm: float }`。Boot 時:(a) load local `pr.best.*`;(b) 問 #2 攞 server baseline(G-PR-1);(c) **server 覆寫 local**(D2 — server 係 ground truth,涵蓋 pre-game 歷史 + 跨 device);(d) server unavailable(offline)→ 用 local cache 照行(grace — 判定照做,server 返嚟時 reconcile)。
9. **Milestone tracking(Avatar Progression 面)** — 累計 lifetime PR count(`pr.lifetime_count` persist)。Milestone thresholds(data-driven `PRMilestoneConfig.tres`:[10, 25, 50, 100])達標 → emit `pr_milestone_reached(count)` + telemetry。**MVP 無 consumer**(forward hooks:#19 zone unlock 條件之一 / v0.2 cosmetic);#26 嘅 evolution tier 唔用呢個(佢由 stat/ability derive — ADR-0010 邊界,本系統唔重複)。
10. **Boot / lifecycle** — autoload `PrDetection`(ADR-0008 gate G-PR-3:`#2 GymSysBackendClient ≺ #10 ≺ StatSystem ≺ PrDetection`;#12 subscription 方向:**#18 boot 時主動將自己 `pr_breakthrough` connect 落 #12 嘅 documented handler**(#12 早 boot,訂唔到未存在嘅 #18 — 反轉接線 boot-order safe;#12 handler 名 epic 時 grep 真 code pin,gate G-PR-4)。GSM 經 `connect_for_initial_state`(Contract 6)—— #18 自己無 SUSPENDED queue 需求(#2 own set_logged 嘅 delivery semantics;#18 stateless per-event + D5 replay-safe),只跟 GSM 做 telemetry 靜默。

### States and Transitions

| State | 意義 | 入 | 出 |
|-------|------|----|----|
| `INITIALISING` | load local baselines → server baseline sync 請求(async,唔 block)→ 訂 #2 / 接線 #12 | boot(Contract 4) | 完成 → `READY` |
| `READY` | 接 `set_logged`,行判定 pipeline | INITIALISING 完成 | — |
| `BASELINE_SYNCING`(substate of READY) | server baseline 未返(offline / 慢)— 用 local cache 照判定;server 返 → reconcile(server 覆寫;若 server baseline 高過 local 判過嘅 PR → 見 EC-7) | READY 且 server 未答 | server 答 → plain READY |

> 無 SUSPENDED state:#18 stateless per-event,#2 負責事件流嘅 suspend/drain;#11 reject(佢 suspended 時)由 Rule 6.3 嘅 `ok==false` 路徑兜(baseline 唔升 → 唔 lost,#2 catch-up redelivery 或下次 set 再判)。

### Interactions with Other Systems

| 系統 | 誰 own interface | 流入 #18 | 流出 #18 | 備註 |
|------|------------------|----------|----------|------|
| **#2 GymSysBackendClient** | #2 own `set_logged` signal;**G-PR-1**:additive baseline API(`get_pr_baselines() -> Dictionary` 或 state response 加 field) | `set_logged(exercise_id, reps, weight)` 原始流 + server baselines | — | 直訂(#9 L863);payload schema cite #2 L479 |
| **#3 PersistenceLayer** | #3 own `IPersistence` | boot load `pr.*` | `pr.best.<exercise_id>` / `pr.lifetime_count`(PR 確認時 `flush=true`) | ADR-0003;localStorage FORBIDDEN |
| **#10 ExerciseClassMapping** | #10 own `get_class_for_exercise(exercise_id)` | class enum(UNKNOWN → skip,D4) | — | 純 lookup;#11 L254「#10 returns class/stat_id for #9 + #18 to route」✓ |
| **#11 Stat System** | #11 own `apply_stat_delta` + `get_stat` | `get_stat(stat_id)`(diminishing input) | `apply_stat_delta(stat_id, PR_BREAKTHROUGH, pr_delta)`(caller path locked:`src/feature/pr_detection.gd`,CI whitelist) | delta 由 #18 用 #11 Formula 2 計(D3);`ok==false` → 唔升 baseline(EC-3) |
| **#12 Ability System** | #18 own `pr_breakthrough(stat_id: StringName, magnitude: float)` signal | — | signal(#12 Path A unlock;#18 boot 時主動接線 — G-PR-4) | #12 L223 locked interface;#12 mock 已用同款 signature ✓ |
| **#9 WorkoutStateTracker** | **G-PR-2**:#9 additive — subscribe `pr_breakthrough` + `get_pr_count_today()` getter | — | signal(#9 count) | #15 L293 read #9 getter(shipped spec)— 零 #15 churn;getter 現未實作(src grep 0) |
| **#15 Loot Drop** | (間接經 #9) | — | pr_factor 數據鏈:#18 → #9 count → #15 read | #15 Q-OQ4 provisional pr_factor 喺 #18 落地後 revisit ✓ |
| **#17 Equipment** | #17 own SourceReceipt | — | `pr_snapshot` 數據(receipt 製作時由 #15/#17 read:`get_session_pr_summary() -> Dictionary`) | F-12 receipt 嘅「鍛造自 180kg × 5」原始數據源 |
| **#26 AvatarRenderer** | #26 own evolution(ADR-0010) | — | (間接:stat delta → #26 tier derive) | #18 唔直接餵 #26 — 邊界紀律 |
| **#19 Zone System** | forward hook | — | `pr_milestone_reached(count)` signal(MVP 無 consumer) | #19 GDD authoring 時決定用唔用 |

> **Bidirectional sync flags(寫 #18 後回填):** #2(G-PR-1 API + downstream 表 actualize)· #9(G-PR-2 amendment)· ADR-0008(G-PR-3 insertion)· #12(G-PR-4 handler 名 pin)· registry 6 處 `pr-detection.md` expected-referrer actualize。

## Formulas

### Formula 1 — `e1rm`(estimated 1RM,Epley)

`e1rm = weight × (1 + reps / E1RM_DIVISOR)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `weight` | w | float | (0, 500] kg(sanity 上限) | set 重量(#2 payload,server-sourced) |
| `reps` | r | int | [1, REP_CAP=12] | 完成次數(>12 唔係 PR 候選 — Rule 2) |
| `E1RM_DIVISOR` | d | float | **30.0**(Epley 標準,非 knob — 改咗就唔係 Epley) | 外推係數 |
| `e1rm` | — | float | (0, ~700] | 估算 1RM |

**Output Range:** weight=60, reps=5 → 60 × (1+5/30) = **70.0**。reps=1 → e1rm = weight(直接 1RM)。
**Example:** bench 65kg × 3 → 65 × 1.1 = **71.5**。
*用 e1RM 而唔係 raw weight:rep PR(同重多 rep)都係真實 strength 突破,Epley 將佢統一落同一把尺。*

### Formula 2 — `pr_magnitude`

`pr_magnitude = clamp((new_e1rm − best_e1rm) / best_e1rm, 0.0, 2.0)`
`is_pr = pr_magnitude >= MIN_PR_MAGNITUDE`

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `new_e1rm` | float | (0, ~700] | 本 set 嘅 Formula 1 輸出 |
| `best_e1rm` | float | (0, ~700] | baseline(Rule 8;cold-start 行 Rule 4,唔入呢條) |
| `MIN_PR_MAGNITUDE` | float | **0.01**(1%)knob [0.005, 0.05] | noise floor — 微小 rounding 唔算突破 |
| `pr_magnitude` | float | [0, 2.0] | #11 Formula 2 嘅 input(range 對齊 #11 L323 ✓) |

**Output Range:** 0–2.0。**Example:** 60kg×5 baseline(e1rm 70)→ 65kg×5(e1rm 75.83)→ m = 5.83/70 = **0.0833** ✓ PR。
*Clamp 2.0 = anomaly 保護(#11 同款);#18 層 clamp 時 emit `pr.magnitude_anomaly`(server 數據出 200%+ jump 多數係 logging 錯誤)。*

### Formula 3 — `pr_delta`(引用 #11,唔重定義)

`pr_delta = PR_BASE × pr_magnitude × (1.0 − (current_stat / MAX_STAT_VALUE) ^ PR_DIMINISH_EXP)`

> **Source of truth = #11 stat-system.md Formula 2**(PR_BASE 6.0 PROVISIONAL [1,20] / PR_DIMINISH_EXP 2.0 [1,4] / MAX_STAT_VALUE 999 — 全部 #11/ADR-0005 own,#18 唔複製 knob)。實作:shared static `PRDeltaCalc.compute(current_stat, magnitude)`(`src/core/pr_delta_calc.gd`)讀 #11 嘅 config 常數 — 單一 source(D3)。Worked example 同 cross-knob invariants 見 #11 L330-344。

### Formula 4 — cold-start baseline 建立

```
if not baselines.has(exercise_id):
    baselines[exercise_id] = new_e1rm   # 建基準,NOT a PR
    persist("pr.best." + exercise_id, new_e1rm)
    emit telemetry "pr.baseline_established"
    return SKIP
```

*第一次做新動作 = 建立基準。冇 baseline 就冇「突破」可言 — fabrication-proof(否則玩家加新 exercise 第一 set 就送 PR)。Server baseline(G-PR-1)令老用戶嘅 pre-game 歷史都係基準 — 接入 game 嗰日唔會用陳年數據刷一輪假 PR。*

### Session PR summary(getter,畀 receipt 鏈)

`get_session_pr_summary() -> Dictionary`:`{ exercise_id: { "one_rm_kg": best_e1rm_today, "magnitude": max_magnitude_today } }`(本 workout 內 confirmed PRs)。#15/#17 製 LEGENDARY SourceReceipt 時 read(`pr_snapshot` + `signature_text` 嘅數據源)。Workout 完結(#9 `workout_completed`)後 clear。

## Edge Cases

- **EC-1 (HIGH) — If `exercise_id` 唔喺 #10 mapping(UNKNOWN class)**:skip 判定,emit `pr.unknown_exercise` telemetry,零 side effect。**Pillar 1 cardio gate** — 跑步機/單車/未映射動作永不餵 stat(#11 L39 binding)。
- **EC-2 (MEDIUM) — If `reps > REP_CAP`(高 rep set)**:skip(唔係 PR 候選)。**唔** emit 嘈音 telemetry(高 rep set 係正常訓練,唔係異常)。
- **EC-3 (CRITICAL) — If `apply_stat_delta` return false**(#11 persist fail / suspended reject / invalid):**baseline 唔升、signal 唔 emit、count 唔加** — 成個 PR 事件當未發生。#2 catch-up redelivery 或玩家下一個 set(仍超 baseline)會重新判定 → 唔 lost。對齊 #11 EC-06(backend reconcile path)。
- **EC-4 (HIGH) — If 同一 set 被 redelivery(bfcache / #2 catch-up replay)**:第一次判定已升 baseline → replay 計出 `pr_magnitude = 0` → 唔係 PR → 自然 no-op(D5 monotonic idempotency)。**唔依賴 set id**(payload 冇)。
- **EC-5 (MEDIUM) — If `pr_magnitude > 2.0`**(server 數據異常,如 logging 錯 kg/lb):clamp 至 2.0 + emit `pr.magnitude_anomaly`(#28 alert 候選)。照算 PR(server 數據係 ground truth — 唔好擅自否定;clamp 限制傷害)。
- **EC-6 (MEDIUM) — If `weight <= 0` 或 `reps < 1`**:skip + `pr.input_invalid` telemetry(defensive;#2 schema 應保證唔出現)。
- **EC-7 (MEDIUM) — If server baseline sync 返嚟,高過 local 已判 PR 嘅 baseline**(BASELINE_SYNCING 期間判咗「假 PR」— local cache 舊):server 覆寫 baseline(D2);**已 apply 嘅 stat delta 唔回收**(#11 冇 negative PR path;損失 = 一次過細 delta,one-shot 誤差,telemetry `pr.baseline_conflict` 記錄)。下次判定用正確 baseline。
- **EC-8 (LOW) — If server baseline sync 失敗(offline)**:`BASELINE_SYNCING` substate 持續 — local cache 照判定(grace;ADR-0003 backend-primary 嘅 offline 容忍)。Server 返嚟先 reconcile。
- **EC-9 (MEDIUM) — If 同一 workout 連續 PR(漸進加重)**:每次獨立判定、各自生效(Rule 7)。Farming 防線:#11 diminishing + #15 `MAX_PR_FACTOR`(10)cap + magnitude 以最新 baseline 計(連續突破嘅 magnitude 遞減)。
- **EC-10 (LOW) — If 首 boot 完全無數據**(新用戶 / 新 device offline):全部 exercise cold-start(Formula 4)— 第一 session 零 PR,全部建基準。第二 session 開始正常。Onboarding(#27)應講明「今日係你嘅基準日」。
- **EC-11 (LOW) — If `pr.best.*` persist 失敗**(IndexedDB fail):baseline 升咗 in-memory(stat 已加,簽收一致);下次 boot local 缺 → server baseline 兜底(D2)。Server 都未有(server sync 又 fail)→ 重判一次 PR(double-count 風險 one-shot,backend-primary 環境下機率極低;telemetry 記錄)。
- **EC-12 (LOW) — If milestone config thresholds 唔係 ascending**:config-load assertion fail loud(data-driven validate 慣例)。

## Dependencies

### Upstream(#18 依賴,Hard)
| 系統 | Hard/Soft | Interface | 缺佢會點 |
|------|-----------|-----------|----------|
| **#2 GymSysBackendClient** | Hard | `set_logged` signal + G-PR-1 baseline API | 無 set 流 → 系統盲 |
| **#10 ExerciseClassMapping** | Hard | `get_class_for_exercise` | 無法 route stat;UNKNOWN gate 失效 |
| **#11 Stat System** | Hard | `apply_stat_delta` + `get_stat` + Formula 2 常數 | PR 無法生效 — Pillar 1 斷鏈 |
| **#3 PersistenceLayer** | Hard | `pr.*` namespace | baseline / count 唔 persist |

### Downstream(依賴 #18)
| 系統 | Hard/Soft | #18 提供 |
|------|-----------|----------|
| **#12 Ability System** | Hard(unlock Path A) | `pr_breakthrough(stat_id, magnitude)` signal(locked interface #12 L223) |
| **#9 WST** | Soft(G-PR-2) | signal → pr_count(→ #15 pr_factor) |
| **#15 / #17** | Soft | `get_session_pr_summary()`(receipt pr_snapshot 源) |
| **#19 Zone** | Soft(hook) | `pr_milestone_reached(count)` |
| **#26 Avatar** | Indirect | (經 #11/#12 — ADR-0010 邊界,無直接 interface) |

### ADR / 架構約束
- **ADR-0002**(data contract Locked):set_logged 係 5 workout signals 之一;cursor/idempotency 由 #2 own。
- **ADR-0003**:`pr.*` namespace backend-primary;PR 確認 `flush=true`。
- **ADR-0005**:`PR_BASE` PROVISIONAL — ratification 時 PR delta 同 loot rarity cross-validate(#11 L335)。#18 唔 own 呢個 knob。
- **ADR-0006**:Contract 4(boot 順序)+ Contract 6(GSM 訂閱)。
- **ADR-0008**:gate G-PR-3 — `GymSysBackendClient ≺ ExerciseClassMapping ≺ StatSystem ≺ PrDetection`(insertion rule 待 amendment)。
- **CI**:`tools/ci/check_stat_mutation_callers.gd` 已 enforce PR_BREAKTHROUGH caller = `src/feature/pr_detection.gd`(#11 shipped lint — 檔名 LOCKED)。

## Tuning Knobs

| Knob | 預設值 | Safe Range | 影響 / 太高 / 太低 |
|------|--------|-----------|---------------------|
| `REP_CAP` | 12 | [8, 15] | PR 候選 rep 上限。太高 → 高 rep e1RM 外推失真(假 PR);太低 → rep-PR 玩家(同重多 rep)被無視 |
| `MIN_PR_MAGNITUDE` | 0.01 | [0.005, 0.05] | noise floor。太高 → 微量加重(2.5kg 小盤)唔算 PR,挫敗;太低 → rounding noise 觸發假 PR |
| `WEIGHT_SANITY_MAX` | 500.0 kg | [300, 1000] | input sanity 上限(EC-6 延伸)。世界紀錄 ~500kg — 超過必係數據錯誤 |
| `PR_MILESTONE_THRESHOLDS` | [10, 25, 50, 100] | ascending ints | milestone hooks(MVP 無 consumer)。EC-12 assert |
| `E1RM_DIVISOR` | 30.0 | **LOCKED(Epley 定義)** | 非 knob — 改咗就唔係 Epley,baseline 全部失效 |
| `PR_BASE` / `PR_DIMINISH_EXP` | (#11 own) | — | **唔喺 #18** — 指向 #11 Formula 2 / ADR-0005(單一 source) |

## Visual/Audio Requirements

> #18 係 data/logic 層 — PR 嘅視覺/聽覺慶祝由 presentation 系統 own:stat 跳字 → #20 HUD(EXP/stat popup 通道);ability unlock toast → #20/#33(CRITICAL allowlist 通道);loot 加成 → #15/#21 ceremony。本節只列 co-trigger contract。

| 事件 | 通道 | 約束 |
|------|------|------|
| PR confirmed | #20 HUD stat-jump + #4 SFX(短 sting,經 #33 attention 通道) | **Set 後 glance 獎勵,唔可以 mid-set 搶注意**(Pillar 2);PR sting 音量 < loot fanfare(層級:PR < mini-boss < final boss loot) |
| ability unlock(下游 #12 觸發) | #12/#20 own | #18 唔直接觸發 UI |
| milestone reached | telemetry only(MVP) | 無 UI consumer |

> 📌 **Asset Spec** — PR sting SFX 係本系統唯一 asset 需求。Art bible approve 後跑 `/asset-spec system:pr-detection`。

## UI Requirements

> #18 **無自己 UI**。提供嘅 data surface:

| Surface | Consumer | #18 提供 |
|---------|----------|----------|
| Stat-jump popup 數據 | #20 HUD(經 #11 `stat_changed` source==PR_BREAKTHROUGH — #18 唔直接餵 UI) | (間接) |
| PR 歷史 / baseline 顯示 | #22 Character Screen(v0.2 — MVP 唔做) | `get_baselines() -> Dictionary`(read-only) |
| Session PR summary | #15/#17 receipt 鏈 | `get_session_pr_summary()` |

無 UX flag — MVP 零 UI surface(#20 經 #11 signal 已 cover stat 顯示)。

## Acceptance Criteria

> GWT;Logic = unit-testable(seams:#2 signal 注入 / #10 / #11 / persistence / TimeProvider mock — 跟 #17 嘅 8-seam 慣例)。

### Detection pipeline
- **AC-01 (Logic)** — **GIVEN** baseline bench=70.0,**WHEN** `set_logged("bench_press", 5, 65.0)`(e1rm 75.83),**THEN** PR confirmed:`apply_stat_delta(STR, PR_BREAKTHROUGH, δ)` called once(δ = PRDeltaCalc golden)、`pr_breakthrough(&"str", ~0.0833)` emitted、baseline → 75.83 + persist flush=true。
- **AC-02 (Logic)** — **GIVEN** baseline 75.83,**WHEN** 同一 set replay,**THEN** no-op(magnitude 0 < floor)— 零 stat call、零 signal(EC-4 idempotency)。
- **AC-03 (Logic)** — **GIVEN** 無 baseline 嘅新 exercise,**WHEN** set_logged,**THEN** baseline 建立 + `pr.baseline_established` telemetry,**唔係** PR(Formula 4)。
- **AC-04 (Logic)** — **GIVEN** #10 回 UNKNOWN,**WHEN** set_logged("treadmill_run", ...),**THEN** skip + `pr.unknown_exercise`,零 side effect(EC-1 Pillar 1 gate)。
- **AC-05 (Logic)** — **GIVEN** reps=13(> REP_CAP),**THEN** skip,無 telemetry 嘈音(EC-2)。
- **AC-06 (Logic)** — **GIVEN** magnitude 計出 0.008(< 0.01 floor),**THEN** 唔算 PR,baseline 不變。
- **AC-07 (Logic)** — **GIVEN** magnitude 計出 3.5,**THEN** clamp 2.0 + `pr.magnitude_anomaly` emit,PR 照生效(EC-5)。
- **AC-08 (Logic)** — **GIVEN** `apply_stat_delta` mock return false,**THEN** baseline 不變、零 signal、零 count(EC-3 全有或全無)。
- **AC-09 (Logic)** — **GIVEN** push/pull/leg 三個 exercise 各一 PR,**THEN** 分別 route STR/DEX/VIT(D4 mapping golden)。
- **AC-10 (Logic)** — **GIVEN** 同 workout 連續兩次加重 PR(70→75.83→80),**THEN** 兩次各自生效,第二次 magnitude 以 75.83 為 base(EC-9)。

### Formulas
- **AC-11 (Logic)** — Formula 1 golden:`e1rm(60, 5) == 70.0`;`e1rm(65, 3) == 71.5`;`e1rm(100, 1) == 100 × (1+1/30) ≈ 103.33`(注意 reps=1 都經 Epley — 同一把尺,唔特判)。
- **AC-12 (Logic)** — PRDeltaCalc golden(對齊 #11 worked example):`compute(12.0, 0.0833) ≈ 0.500`(#11 L338-340)。
- **AC-13 (Logic)** — `compute(999.0, any) == 0.0`(diminishing hard cap,#11 invariant)。

### Baseline sync
- **AC-14 (Logic)** — **GIVEN** local baseline 70 + server 回 85,**WHEN** sync 完成,**THEN** baseline = 85(server 贏,D2)+ 後續判定用 85。
- **AC-15 (Logic)** — **GIVEN** server sync fail(offline),**THEN** local cache 照判定(EC-8 grace),`BASELINE_SYNCING` substate telemetry。
- **AC-16 (Logic)** — **GIVEN** BASELINE_SYNCING 期間 local-base PR 已生效,server 返高 baseline,**THEN** baseline 覆寫、stat 唔回收、`pr.baseline_conflict` emit(EC-7)。

### Persistence / summary / milestone
- **AC-17 (Integration)** — **GIVEN** baselines + lifetime_count persist,**WHEN** boot,**THEN** round-trip 還原;PR 確認時 write 帶 flush=true。
- **AC-18 (Logic)** — **GIVEN** 本 workout 2 個 PR,**WHEN** `get_session_pr_summary()`,**THEN** 回 2 entries(one_rm_kg + magnitude);**WHEN** `workout_completed`,**THEN** summary clear。
- **AC-19 (Logic)** — **GIVEN** lifetime_count 9 → PR → 10,**THEN** `pr_milestone_reached(10)` emit(thresholds config)。
- **AC-20 (Logic)** — **GIVEN** milestone config [10, 5, 50](非 ascending),**THEN** config-load assert fail loud(EC-12)。

### 整合面
- **AC-21 (Integration)** — **GIVEN** 真 #12(或 contract mock),**WHEN** PR confirmed(STR),**THEN** #12 收到 `pr_breakthrough(&"str", m)` 並行 Path A 評估(接線方向 G-PR-4)。
- **AC-22 (Integration)** — **GIVEN** #9 G-PR-2 amendment 落地,**WHEN** PR ×3,**THEN** `get_pr_count_today() == 3`;**WHEN** 跨 UTC 日界,**THEN** count reset(#9 own daily 語意)。

## Open Questions / Cross-System Gates

| # | 問題 | Impact | Resolution path | Owner |
|---|------|--------|-----------------|-------|
| **G-PR-1** | #2 additive baseline API:`get_pr_baselines()`(per-exercise historical best e1RM,server-computed)— polling state response 加 field 定獨立 endpoint?GymSys 後端 extension(user 自己 backend,可行) | D2 server-baseline 依賴 | #2 GDD amendment + GymSys API extension(同 ADR-0002 data contract 對齊);**offline grace 令缺佢唔 block 判定** | #2 / GymSys backend |
| **G-PR-2** | #9 additive:subscribe `pr_breakthrough` + `get_pr_count_today()` getter(+UTC daily reset 語意) | #15 pr_factor 數據鏈 | #9 GDD focused amendment(additive;getter 現未實作 — 係 #15 deferred 面嘅補完) | #9 |
| **G-PR-3** | ADR-0008 insertion rule:`#2 ≺ #10 ≺ StatSystem ≺ PrDetection`(+同 InventorySystem 嘅相對位置 — 無相互依賴,order-resilient) | autoload boot | ADR-0008 focused amendment(照 #17 G-4 先例) | technical-director |
| **G-PR-4** | #12 接線方向:#18 boot 時 connect 自己 signal 落 #12 嘅 handler — #12 真 code handler 名 + 訪問面(grep ability_system.gd)pin 落 story | boot-order-safe 接線 | epic 時 grep #12 shipped code;如 #12 無 public handler → #12 additive 一行 | #18 epic |
| **Q-PR-1** | `REP_CAP=12` 同 `MIN_PR_MAGNITUDE=0.01` 嘅初值:真實 GymSys 數據校準(user 有真數據!)— 太多/太少 PR 都傷(太多 = 通脹,太少 = 唔覺) | PR 頻率 feel | VS-tier 用 user 真 GymSys 歷史回放校準 | balance / VS-tier |
| **Q-PR-2** | Onboarding 首 session「基準日」溝通(EC-10:第一日零 PR)— 邊個 own 呢句 copy?(#27 Onboarding 未 design) | 新用戶 expectation | #27 GDD authoring 時收;interim:#20 HUD 一句 toast hook | #27 |

> **Degraded-mode note**:本 GDD 喺 specialist spawning blocked 下 inline authored(main session 代行 systems-designer / economy-designer / qa-lead 視角)。CD-GDD-ALIGN gate **未跑**(spawn blocked)— **必須 fresh-session `/design-review`(full mode,spawning 恢復後)先可以開 epic**。
