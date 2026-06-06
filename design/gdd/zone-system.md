# Zone System

> **Status**: In Design
> **Author**: frank + agents (design-system — degraded inline mode: specialist spawns blocked by 1M-context credits 2026-06-06;**review manually via fresh-session /design-review before production**)
> **Last Updated**: 2026-06-06
> **Implements Pillar**: Pillar 5 (Mirror Moment — supporting:zone unlock 係 weekly progression markers 之一,#8 L46)· Pillar 1 (supporting:unlock 條件只能係真實訓練 milestones)
> **Layer / Tier**: Feature / MVP
> **Depends On**: #3 PersistenceLayer · #14 EnemyDirector(zone → wave/arena 數據面)· (#8 Streak + #18 PR Detection 係 unlock 條件 signal sources)

## Overview

Zone System 係遊戲世界嘅**關卡容器層** —— 定義每個 zone 嘅身份(名 / 背景 scene / enemy archetype pool / boss pool / 視覺 palette)、管理 unlock 狀態(`zone.unlocked.*` persist,**永久解鎖永不回收** — anti-pillar permadeath guarantee,同 #8 milestone contract 同款),並將 active zone 嘅數據面(wave archetype pool / arena config / 背景)提供畀 #14 EnemyDirector 同 presentation 層。

**MVP 現實(誠實 scope)**:MVP 得 **1 個 zone**(game-concept MVP #4:「1 zone with auto-combat」)。所以 MVP 嘅 Zone System = (a) 一個 data-driven `ZoneRegistry.tres`(1 entry);(b) unlock framework 嘅**結構**(訂 #8 `streak_milestone_reached` + #18 `pr_milestone_reached`,評估 unlock 條件)— MVP zone 0 永遠 unlocked,framework 行為喺 v0.2 第二個 zone 先有真實作用;(c) `get_active_zone()` 數據面。系統刻意薄 — 大頭係 data schema + forward contracts,唔係 runtime 邏輯。

## Player Fantasy

**核心情緒**:「**我嘅持續訓練,將個世界一格一格咁打開**」—— zone 唔係買嚟、唔係刷嚟,係用 streak 同 PR 換返嚟嘅領土。

**錨定時刻**(v0.2 起):連續 14 日訓練達標,boot 時 world map 上第二個 zone 嘅迷霧散開 —— 新背景、新敵人剪影、新 boss。玩家知道呢格地圖係自己嘅 14 日汗水。**MVP 嘅誠實版**:玩家眼中只有一個 zone(楓之島式森林),Zone System 隱形 — 佢嘅 fantasy 兌現喺 v0.2,MVP 起好個框先。

**反面界定**:zone 唔係 difficulty selector(難度由真實訓練強度驅動,game-concept Flow State)、唔係 paywall、唔可以用任何 in-game 行為解鎖(Pillar 1:unlock 條件只認 streak milestone / PR milestone / workout count — 全部真身數據)。

## Detailed Design

### Core Rules

1. **Zone 定義(data-driven)** — `ZoneRegistry.tres`(`Array[ZoneDef]`):
   ```
   ZoneDef (Resource):
     zone_id: StringName            # &"zone_verdant_forest"
     display_name: String           # 顯示名
     background_scene_path: String  # res:// 背景 scene
     wave_archetype_pool: Array[StringName]   # #14 wave archetype ids(餵 #14 選 wave)
     boss_pool: Array[StringName]   # #16 boss ids
     world_palette_id: StringName   # art bible Layer Discipline 嘅 desaturated palette 變體
     unlock_condition: UnlockCondition
   UnlockCondition (Resource):
     kind: enum {ALWAYS, STREAK_MILESTONE, PR_MILESTONE, WORKOUT_COUNT}
     threshold: int                 # milestone 值(kind != ALWAYS 時)
   ```
   MVP registry = 1 entry(`zone_verdant_forest`,`ALWAYS`)。
2. **Unlock 評估** — 訂 #8 `streak_milestone_reached(milestone)` + #18 `pr_milestone_reached(count)`(+#9 `workout_completed` 計 workout count)。事件到 → 掃 registry 未解鎖 zones → condition 滿足 → unlock:寫 `zone.unlocked.<zone_id>`(persist,**一旦寫入永不 delete** — #8 L28 同款 binding)+ emit `zone_unlocked(zone_id)`(#29 Mirror Moment marker / #20 toast 經 #33 通道)。
3. **永久性(anti-pillar binding)** — unlock manifest 只加唔減。Streak 斷咗、stat 跌咗(不可能,#11 不衰減)、任何狀態變化都**永不**收回 zone。Boot 時 unlock manifest 損壞 → 保守 fallback:zone 0(ALWAYS)必可用 + CRITICAL telemetry,唔好 lock 死玩家。
4. **Active zone** — MVP:固定 zone 0。v0.2+:玩家喺 non-workout 時間揀(#22/#24 UI);workout 開始時鎖定當日 zone(mid-workout 唔切 — Pillar 2,場景重載係 attention + perf 災難)。`get_active_zone() -> ZoneDef` 係 #14 / presentation 嘅讀面。
5. **#14 數據面** — #14 boot / workout 開始時 read `get_active_zone().wave_archetype_pool`,佢自己嘅 wave 選擇邏輯喺 pool 內運作(#14 own selection;#19 only scopes the pool)。`boss_pool` 同理畀 #16 spawn 鏈。**MVP:pool = #14 現有 shipped archetype 全集** — #19 落地唔改變 #14 行為(zero churn:#14 而家硬讀自己 config,#19 嘅 pool 係 v0.2 收窄 hook;gate G-Z-2)。
6. **Boot** — load `zone.unlocked.*` → validate(Rule 3 fallback)→ active zone = MVP 固定 / v0.2 persist 玩家上次選擇。Autoload `ZoneSystem`(輕;ADR-0008 gate G-Z-1:`PersistenceLayer ≺ ZoneSystem ≺ EnemyDirector` — #14 boot 時可能 read active zone)。

### States and Transitions

| State | 意義 |
|-------|------|
| `INITIALISING` | load unlock manifest + registry validate |
| `READY` | 接 milestone signals;serve `get_active_zone()` |

(無 SUSPENDED 需求 — milestone signals 嚟自已有 suspend-safe 系統;unlock 評估 stateless + persist 即時。)

### Interactions with Other Systems

| 系統 | 誰 own | 流入 #19 | 流出 #19 |
|------|--------|----------|----------|
| **#3 Persistence** | #3 | boot load `zone.unlocked.*` | unlock 寫入(flush=true — milestone 係 anchor moment) |
| **#8 Streak** | #8 own signal | `streak_milestone_reached(milestone)` | — |
| **#18 PR Detection** | #18 own signal | `pr_milestone_reached(count)` | — |
| **#9 WST** | #9 own signal | `workout_completed`(WORKOUT_COUNT 條件計數) | — |
| **#14 EnemyDirector** | #19 own `get_active_zone()` | — | wave_archetype_pool / arena 數據(G-Z-2:MVP zero-churn,v0.2 收窄) |
| **#16 Boss** | (經 #14 鏈) | — | boss_pool scope |
| **#29 Mirror Moment** | #29 own ceremony | — | `zone_unlocked` signal(weekly marker 之一,#8 L46 列明) |
| **#20/#33** | 各自 | — | unlock toast 經 #33 attention 通道(non-workout 時段 deliver) |

## Formulas

> 本系統無數值公式 — unlock 係 threshold 比較(condition.threshold ≤ event value)。唯一「計算」:

### Workout count 累計

`workout_count += 1` on #9 `workout_completed`;persist `zone.workout_count`。WORKOUT_COUNT 條件:`workout_count >= threshold`。冪等:workout_id dedup(同一 workout_completed replay 唔重複計 — 記 `zone.last_counted_workout_id`)。

## Edge Cases

- **EC-1 (HIGH) — If unlock manifest persist 損壞 / 缺失**:fallback = 所有 `ALWAYS` zones 可用(MVP = zone 0)+ CRITICAL telemetry;**唔好** lock 死玩家(anti-pillar)。已 unlock 嘅非 ALWAYS zones 喺 backend reconcile 返(ADR-0003 backend-primary)。
- **EC-2 (MEDIUM) — If milestone signal replay**(bfcache / boot catch-up):unlock 寫入冪等(已 unlocked → no-op,唔重複 emit `zone_unlocked`)。
- **EC-3 (MEDIUM) — If registry 有 zone 嘅 unlock threshold 喺玩家已過嘅 milestone 之下**(v0.2 加新 zone,老玩家 streak 已 30 日):boot 時做一次 **retroactive sweep**(用 #8 `streak_milestones_unlocked` 歷史 + #18 lifetime count + workout_count 評估全部未解鎖 zones)— 老玩家即時拎到應得嘅 unlock,唔使等下一次 milestone event。
- **EC-4 (LOW) — If registry 載入失敗 / 0 entries**:assert fail loud(config-load;遊戲冇 zone 唔可以行)。
- **EC-5 (LOW) — If `zone_unlocked` 喺 workout 期間觸發**(mid-workout 達 milestone):unlock 即時生效(persist),但 **toast 經 #33 排程到 non-workout 時段**;active zone 唔切(Rule 4 — 當日 zone 鎖定)。
- **EC-6 (LOW) — If duplicate zone_id 喺 registry**:config-load assert fail loud。

## Dependencies

### Upstream(Hard)
| 系統 | Interface | 缺佢會點 |
|------|-----------|----------|
| **#3 Persistence** | `zone.*` namespace | unlock 唔 persist |
| **#14 EnemyDirector** | (#19 提供讀面;#14 consume)| — 見 downstream |

### Signal sources(Soft — 冇佢哋 MVP 照行,unlock framework 閒置)
#8 `streak_milestone_reached` · #18 `pr_milestone_reached` · #9 `workout_completed`

### Downstream
#14(wave pool scope,G-Z-2 v0.2)· #16(boss pool,經 #14)· #29(marker signal)· #20/#33(toast)· #22/#24(v0.2 zone 選擇 UI)

### ADR / 架構約束
- **ADR-0003**:`zone.*` backend-primary;unlock flush=true。
- **ADR-0006**:Contract 4 boot;Contract 6(GSM 唔需要 — 無 state-dependent 行為;milestone signals 用 plain connect,sources 全部 late-boot-safe?gate G-Z-1 確認順序)。
- **ADR-0008**:gate G-Z-1 — `PersistenceLayer ≺ ZoneSystem ≺ EnemyDirector`;同 #18 PrDetection 嘅相對位置:`PrDetection ≺ ZoneSystem`(#19 訂 #18 signal — 接線方向同 G-PR-4 同款處理)。
- **無新 ADR**。

## Tuning Knobs

| Knob | 預設值 | Safe Range | 影響 |
|------|--------|-----------|------|
| `ZoneRegistry.tres` 內容 | 1 zone(MVP) | data | zone 內容本身(unlock thresholds 每 zone 自帶) |
| (unlock thresholds) | per-zone data | kind 對應嘅 milestone 值 | 太低 → unlock 無感;太高 → v0.2 內容鎖死。**v0.2 加 zone 時用 MVP retention telemetry 定** |

> 本系統 runtime knobs 接近零 — 全部喺 data。呢個係 by design(容器層)。

## Visual/Audio Requirements

> Zone 嘅視覺本體(背景 scene / palette)係 **art assets**,由 ZoneDef data 引用;產出歸 art pipeline。系統層約束:

- **Layer Discipline binding**(art bible):`world_palette_id` 必須係 desaturated -30% 變體 — zone 背景永遠唔可以同 loot/HUD 搶飽和度(Visual Identity Anchor 原則 3)。
- **Zone unlock 瞬間**(v0.2):map 迷霧散開動畫 — #29 Mirror Moment 級數嘅 ceremony 候選,唔係 #19 own。
- 無 audio 需求(zone BGM 變化 → #4 catalog,v0.2)。

> 📌 **Asset Spec** — MVP zone 背景(verdant forest,楓之島式)係 MVP 必需 asset。Art bible approve 後跑 `/asset-spec system:zone-system`。

## UI Requirements

> MVP **零 UI**(1 zone,無得揀,unlock toast 經 #20/#33 generic 通道)。v0.2:zone 選擇 map(#22/#24 surface)— 到時行 `/ux-design`。無 UX flag for MVP。

## Acceptance Criteria

- **AC-01 (Logic)** — **GIVEN** MVP registry(1 zone,ALWAYS),**WHEN** boot,**THEN** `get_active_zone().zone_id == &"zone_verdant_forest"`,unlocked 集合含 zone 0。
- **AC-02 (Logic)** — **GIVEN** registry 加第二 zone(STREAK_MILESTONE 14),**WHEN** `streak_milestone_reached(14)`,**THEN** unlock 寫入(flush=true)+ `zone_unlocked` emit 一次。
- **AC-03 (Logic)** — **GIVEN** zone 已 unlocked,**WHEN** 同一 milestone signal replay,**THEN** no-op(EC-2 冪等,零重複 emit)。
- **AC-04 (Logic)** — **GIVEN** unlock manifest 損壞(persist 回 garbage),**WHEN** boot,**THEN** ALWAYS zones 可用 + CRITICAL telemetry,唔 crash(EC-1)。
- **AC-05 (Logic)** — **GIVEN** 老玩家(#8 milestones_unlocked 含 30)+ v0.2 新 zone(STREAK_MILESTONE 14),**WHEN** boot retroactive sweep,**THEN** 新 zone 即時 unlocked(EC-3)。
- **AC-06 (Logic)** — **GIVEN** WORKOUT_COUNT 條件(threshold 5)+ count 4,**WHEN** `workout_completed`(新 workout_id),**THEN** count → 5 + unlock;**AND** 同 workout_id replay **THEN** count 不變(Formula 冪等)。
- **AC-07 (Logic)** — **GIVEN** registry 有 duplicate zone_id 或 0 entries,**THEN** config-load assert fail loud(EC-4/6)。
- **AC-08 (Integration)** — **GIVEN** unlock state persist,**WHEN** boot round-trip,**THEN** unlocked 集合 + workout_count 完全還原。
- **AC-09 (Integration)** — **GIVEN** #14 boot,**WHEN** read `get_active_zone()`,**THEN** 攞到 wave_archetype_pool(MVP = 全集,zero #14 行為變化 — G-Z-2)。

## Open Questions / Cross-System Gates

| # | 問題 | Resolution path | Owner |
|---|------|-----------------|-------|
| **G-Z-1** | ADR-0008 insertion:`Persistence ≺ ZoneSystem ≺ EnemyDirector` + `PrDetection ≺ ZoneSystem`;milestone signal 接線方向(late-boot subscriber 問題,同 G-PR-4 同款) | ADR-0008 amendment + epic 時 grep sources 嘅 signal 面 | technical-director / epic |
| **G-Z-2** | #14 read `get_active_zone().wave_archetype_pool` 嘅接入(MVP zero-churn:pool = 全集;v0.2 #14 amendment 一行) | v0.2;MVP 唔郁 #14 | #14 / v0.2 |
| **Q-Z-1** | v0.2 第 2-3 個 zone 嘅 unlock thresholds(STREAK 14?PR 25?)— 用 MVP retention telemetry 定 | v0.2 content design | balance |
| **Q-Z-2** | Zone 切換嘅 #14/#26 場景重載協議(workout 開始時鎖定 — 邊個觸發 reload?)| v0.2(MVP 單 zone 無切換) | v0.2 architecture |

> **Degraded-mode note**:inline authored(spawns blocked)。**必須 fresh-session `/design-review` 先開 epic。**
