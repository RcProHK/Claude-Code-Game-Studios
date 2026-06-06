# EG-4 — #8 Streak Milestone Reachability Erratum

> **Status**: OPEN(2026-06-06,#19 Zone review Pass 1 經 CD 開立)
> **Route**: fresh-session CD adjudication(影響面跨 #8/#15/#29 — 唔好喺 #19 session 內裁)
> **唔 block**: #19 revision(#19 已按 P1 裁決刪 STREAK 軸,獨立於本 EG)

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
