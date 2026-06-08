# EG-4 — #8 Streak Milestone Reachability Erratum

> **Status**: ✅ **ADJUDICATED 2026-06-08(fresh-session CD adjudication — Option (a) Rest-day grace)**
> **Route**: fresh-session CD adjudication(影響面跨 #8/#15/#29 — 唔好喺 #19 session 內裁)
> **唔 block**: #19 revision(#19 已按 P1 裁決刪 STREAK 軸,獨立於本 EG)

## CD Adjudication(2026-06-08 — binding)

**裁決:Option (a) Rest-day grace 採納。** Grep 實證(裁決前 verification-first):

- Shipped `consecutive_day_classification` = `_days_between == 1`(`streak_system.gd:240-241`)— 零 grace 確認
- #15 下游唔係 signal 訂閱,係 `streak_factor = 1.0 + min(streak/scale, max_bonus)`(`loot_rarity_calc.gd:149`)— streak 不可達 → factor inert 實證成立
- `streak_milestone_reached` signal **未 shipped**(AC-38 deferred)— milestone emit 機制仲係 paper contract,改動零 runtime 訂閱 churn
- Shipped `MILESTONE_THRESHOLDS = [1,7,14,30,60,90]` 實際只用於 buff step function(`get_streak_buff_multiplier`)— 係 GDD L803「step boundaries {1,…} ⊇ milestones」嘅 **buff step table**,同 GDD milestone gate set `[7,14,30,60,90]` 兩個概念被合成一個 const(命名誤導,非單純 drift)

**選項評估:**

| 選項 | 判定 | 理由 |
|---|---|---|
| (a) grace | ✅ 採納 | S-size(一 knob + 一 predicate)達到 reachability + 消 junk-workout incentive;persistence 零 migration;下游零 churn |
| (b) weekly 重定義 | ❌ | core formula + milestone 單位(日→週)+ 7 個 Fantasy Test 全重寫 = XL churn;(a) 實證唔夠先升級(v0.2+ 候選) |
| (c) thresholds 改細 | ❌ | 治標 — 3x/week 玩家 streak 仍 cap 1-2 |
| (d) 接受現狀 | ❌ | 保留 overtraining/junk-workout incentive = anti-Pillar 1;#15 streak_factor + buff ladder 對多數玩家 inert |

**Binding 細節(#8 focused amendment — EG-1 先例):**

1. **Chain predicate**:streak 繼續條件由「gap == 1」改「`1 ≤ gap ≤ STREAK_GRACE_GAP_DAYS`」;新 knob `STREAK_GRACE_GAP_DAYS = 3`(容忍 ≤2 個完整 rest day),safe range [1, 4]。數學驗證:3x/week Mon/Wed/Fri max gap = Fri→Mon = 3 ✓;PPL 6x/week gap ≤ 2 ✓;2x/week gap ≥ 4 ✗ 斷 — 行 #19 WORKOUT_COUNT 軸(streak = consistency prestige 軸 / count = persistence 軸,partition 跟 #19 P1/P2 裁決)
2. **計數語意**:streak = **unbroken training-day chain**(每 workout day +1;grace 只改 reset predicate,唔改 increment)。Reachability:3x/week → 7 @ ~2.3 週 / 30 @ 10 週 / 90 @ 30 週 — 全可達且 prestige cadence 合理
3. **Const 概念分離**:shipped const 改名 `BUFF_STEP_THRESHOLDS`/`BUFF_STEP_MULTIPLIERS`(對應唯一用途);milestone gate set `[7,14,30,60,90]` 留返將來 AC-38 emit 機制先引入 — 唔可以 iterate 含 1 嘅 buff table 做 milestone emit
4. **Fantasy Test 語意 sweep**:7 個 test 期望值喺 grace 語意下逐一驗證**全部不變**(Sick Day gap 5 > 3 仍 reset ✓ / Travel Week gap 7 仍斷 ✓ / Phone-Lost retro-credit 不受影響 ✓)— GDD 只需加 amendment 注釋,唔重寫 test 敘事
5. **殘餘 incentive 申報**:連休 2 日後第 3 日為保 streak 做輕 workout 嘅 incentive 仍存在,但同「唔好連續休息太耐」嘅真實訓練建議方向一致 — 唔再 anti-Pillar 1(原版係誘發**每日** junk workout)

**Resolution 執行**:同 session focused amendment(GDD Rule 6 + 知識 sweep + code + tests + CI gate)— 見 git history `fix(#8): EG-4 rest-day grace`。

## 問題(grep 實證)

1. **#8 streak 定義零 rest-day grace**:`streak_system.gd` Rule 6 — streak = 連續 calendar day,gap > 1 日 reset。3x/week(默認玩家 cadence)streak 永不過 1-2;6x/week PPL 玩家每 rest day 斷,永不過 6。**Milestone 7/14/30/60/90 對絕大多數真實訓練模式係數學上不可達** — 唔係「難」,係「永不」。
2. **Shipped/spec divergence**:shipped `MILESTONE_THRESHOLDS = [1,7,14,30,60,90]`(streak_system.gd:38-41)vs #8 GDD `{7,14,30,60,90}` — 多咗個 1。
3. **誘發 degenerate strategy**:唯一可達路徑 = 每日 workout → (a) overtraining,(b) streak-saver junk workout(入 gym log 一組 curl 收工)— GymSys `workout_completed` 冇 minimum-substance gate。直接同 Pillar 1 健康倫理 + #8 自己嘅 Sick Day Test 精神(「reset 係 forward-pull 唔係 punisher」)對撞。

## 受影響 downstream

- **#8 自身**:buff multiplier 階梯(shipped L264-272)— 多數玩家永遠困喺 tier 1,成個 milestone 經濟對佢哋 inert
- **#15 Loot**:ritual-tier rarity unlock(訂 `streak_milestone_reached`)— 同樣 inert
- **#29 Mirror Moment**:weekly progression markers 之一
- **#19 Zone**:已按 CD P1 裁決刪 STREAK 軸(v0.2 gate = WORKOUT_COUNT)— 本 EG 唔影響 #19

## Resolution 選項(CD adjudication 時評估)

- (a) **Rest-day grace**:streak 容忍 N 日 gap(如 ≤2 日唔斷)— 最細改動,但「連續」語意變
- (b) **Weekly-frequency streak 重定義**:「連續 N 週每週 ≥M 次」— 最忠實於真實訓練 cadence,但 #8 core formula 重寫
- (c) **Thresholds 重校**:接受 daily-only 可達,thresholds 改細(但治標)
- (d) **接受現狀 + 明文**:streak 係 daily-dedication 玩家嘅 prestige 軸(其他玩家用 count 軸)— 要 #15/#29 各自評估 inert 後果

任何選項都係 **#8 amendment**(merged Approved 上游)— 跟 EG-1 先例(focused amendment 經 gate 行)。

## 參考

- 開立:`design/gdd/reviews/zone-system-review-log.md` Pass 1(economy-designer F-1 + CD P1 裁決)
- 先例:EG-1(#4 audio ownership relocation,Option B,PR #13)
