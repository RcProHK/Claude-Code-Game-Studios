# Zone System

> **Status**: In Design — Revised(Pass 1 MAJOR REVISION NEEDED 2026-06-06 → revision 同日,按 CD P1-P6 裁決重寫;pending fresh re-review)
> **Author**: frank + agents(原稿 degraded inline 2026-06-06;review 歷程見 `design/gdd/reviews/zone-system-review-log.md`)
> **Last Updated**: 2026-06-06
> **Implements Pillar**: Pillar 5 (Mirror Moment — supporting:zone unlock 係 weekly progression markers 之一,#8 L46)· Pillar 1 (supporting:unlock 條件只能係真實訓練 milestones)
> **Layer / Tier**: Feature / MVP
> **Depends On**: #3 PersistenceLayer · #9 WorkoutStateTracker(unlock 條件 signal source)· #14 EnemyDirector(zone → wave/arena 數據面,v0.2)

## Overview

Zone System 係遊戲世界嘅**關卡容器層** —— 定義每個 zone 嘅身份(名 / 背景 scene / enemy archetype pool / boss pool / 視覺 palette)、管理 unlock 狀態(`zone.state` envelope persist,**永久解鎖永不回收** — anti-pillar permadeath guarantee),並將 active zone 嘅數據面提供畀 #14 EnemyDirector 同 presentation 層。

**MVP 現實(誠實 scope)**:MVP 得 **1 個 zone**(game-concept MVP #4:「1 zone with auto-combat」)。MVP 嘅 Zone System = (a) data-driven `ZoneRegistry.tres`(1 entry);(b) unlock framework 結構(訂 #9 `workout_completed_forwarded` 計 **training-day count**,評估 unlock 條件)— MVP zone 0 永遠 unlocked,framework 喺 v0.2 第二個 zone 先有真實作用;(c) `get_active_zone()` 數據面。系統刻意薄 — 大頭係 data schema + forward contracts。

> **Design History(Pass 1 P1/P2 裁決 — binding,v0.2 author 必讀)**:unlock 軸**唔用 streak 軸、唔用 PR-count 軸**。
> - **Streak 軸**:#8 streak = 連續 calendar day 零 rest-day grace → milestone 7+ 對 3x/week 默認玩家**數學上不可達**,且誘發 junk-workout farming(content gate 懲罰 rest day = anti-Pillar 1)。問題屬 #8 上游 — **見 EG-4**(`production/escalations/EG-4-streak-reachability.md`);EG-4 裁決 rehabilitate 咗 streak 軸先可以喺 v0.2+ 重新考慮。
> - **PR-count 軸**:CD directive(#18 review)— count 軸跨 demographic variance 10-20×(imported veteran 6-12 個月先到 milestone 10)。v0.2 候選係 **Σmagnitude(PR_SCORE,float)** — ratify 後先加 enum kind(.tres 後加零 migration 成本;錯 capability 比缺 capability 更貴)。
> - **WORKOUT_COUNT(training-day count)**係 v0.2 primary gate 軸:monotonic、無 reset、demographic variance 只係出席率差異(~2-3×)、「**持續**訓練」嘅忠實量度(persistent ≠ consecutive)。

## Player Fantasy

**核心情緒**:「**我嘅持續訓練,將個世界一格一格咁打開**」—— zone 唔係買嚟、唔係刷嚟,係用一日一日真實訓練換返嚟嘅領土。

**錨定時刻**(v0.2 起):第 20 個訓練日完成,boot 時 world map 上第二個 zone 嘅迷霧散開 —— 新背景、新敵人剪影、新 boss。玩家知道呢格地圖係自己 20 日汗水(唔理係 6 週定 10 週儲返嚟 — 病咗一星期都唔會蒸發)。**MVP 嘅誠實版**:玩家眼中只有一個 zone(楓之島式森林),Zone System 隱形 — fantasy 兌現喺 v0.2,MVP 起好個框先。

**反面界定**:zone 唔係 difficulty selector(難度由真實訓練強度驅動,game-concept Flow State)、唔係 paywall、唔可以用任何 in-game 行為解鎖(Pillar 1:unlock 條件只認真身訓練數據)。**Zone 亦唔係 power 階梯** — 見 Rule 8 lateral loot contract。

## Detailed Design

### Core Rules

1. **Zone 定義(data-driven)** — `ZoneRegistry.tres`(`Array[ZoneDef]`;**editor-saved**,唔好手寫 .tres — typed-array-of-script-class 手寫易 silent null;nested custom Resource 有 `EnemyRegistry.tres` shipped 先例):
   ```
   ZoneDef (Resource):
     zone_id: StringName            # &"zone_verdant_forest"
     display_name: String
     background_scene_path: String  # res:// path(唔用 PackedScene export — 免 registry load 拉成個 scene graph)
     wave_archetype_pool: Array[StringName]   # 空 array = UNFILTERED sentinel(MVP 用呢個 — 唔 hard-code 全集,#14 加 archetype 唔會被靜默 filter)
     boss_pool: Array[StringName]   # 同上 sentinel 語意
     world_palette_id: StringName   # art bible desaturated -30% 變體
     unlock_condition: UnlockCondition
   UnlockCondition (Resource):
     kind: enum {ALWAYS, WORKOUT_COUNT, UNKNOWN}   # ADR-0007 Classification:sentinel UNKNOWN last;v0.2 ratify 先加新 kind(PR_SCORE 候選)
     threshold: int                 # WORKOUT_COUNT:training-day 數(≥1);ALWAYS 忽略
   ```
   MVP registry = 1 entry(`zone_verdant_forest`,`ALWAYS`,pools 空 = unfiltered)。
2. **Training-day count(unlock currency)** — 訂 #9 `workout_completed_forwarded(completed_at: int, transition_id: String)`(**shipped 現貨**:`workout_state_tracker.gd:69`;#9 係 fabrication-guarded validated path — count 永不行 raw #2,#20 教訓同款)。每事件:
   1. `transition_id == last_counted_transition_id` → no-op(replay dedup;transition_id intrinsic 喺 payload,`loot_drop_system.gd:582` shipped 先例;ADR-0006 collision-safe)。
   2. `utc_date(completed_at) == last_counted_date` → no-op(**per-calendar-day cap 1** — count 語意係「training-day 數」唔係「workout 數」:同日入 N 個 session 只計 1,junk-workout farming 物理免疫,MVP day 1 起生效零追溯問題)。Date 用 **UTC date derive 自 completed_at**(server timestamp 純函數 — deterministic、零 clock/timezone seam;同日多 session 計 1 嘅誤差方向係 under-count,anti-fabrication-safe;同 #17 receipt date 嘅 UTC determinism pin 同款)。
   3. 否則:`workout_count += 1`,update 兩個 cursor,行 Rule 3 unlock 評估,persist(Rule 5)。
3. **Unlock 評估** — count 變化(或 Rule 7 sweep)→ 掃 registry 未解鎖 zones:`kind == WORKOUT_COUNT and workout_count >= threshold` → unlock:append `unlocked_zone_ids` + ceremony queue(Rule 6)+ persist(Rule 5 write-success-then-emit)→ emit `zone_unlocked(zone_id)`。
4. **永久性(anti-pillar binding)** — `unlocked_zone_ids` **只加不減**(envelope load path assert 呢條 invariant);**ALWAYS zones derived-not-persisted**(manifest 只載 earned unlocks;可用集合 = derived ∪ persisted)。任何狀態變化(count 唔會跌,#11 同款 monotonic)都永不收回 zone。
5. **Persist + write-success-then-emit** — 單一 envelope key **`zone.state`**(SerializableResource,ADR-0006 C3 / ADR-0009;經 `to_dict()/from_dict()` — GSM tombstone / loot 先例):`{ schema_version: int, workout_count: int, last_counted_transition_id: String, last_counted_date: String, unlocked_zone_ids: Array[StringName], ceremony_pending: Array[StringName] }`。單 key 理由:count + 兩個 dedup cursor 係 **atomic pair**(分 key 寫,crash 喺中間 = double-count / lost count);#3 IPersistence 冇 enumeration API,whole-cache flush 下 per-key 零著數(#18 Rule 8 同款論證)。**順序 binding(#8 Rule 7 樣板)**:`write("zone.state", envelope.to_dict(), flush=true)` 回 true **先** emit `zone_unlocked`;回 false → **唔 emit + in-memory rollback**(unlocked_zone_ids 還原)+ `zone.persist_failed` telemetry — 下次 boot sweep(Rule 7)自愈(count 已 persist 嘅話 unlock 重新評估)。Emit 咗但冇 persist = ceremony 放咗領土消失 = anti-pillar,絕對唔准。
6. **Ceremony(P6 裁決)** — unlock 嘅 persist 效果**永遠即時**;presentation 分離:`zone_unlocked` emit 後,ceremony 交 `ceremony_pending` queue(persist 喺 envelope — survive crash)。**Delivery window**:唔遲過同 session 嘅 post-workout summary;mid-workout 觸發 → 經 #33 attention 通道排程(EC-5);boot-time sweep unlock(#20 scene-tree 未 wire,emit fire-into-void)→ queue 等 presentation ready 先 drain。**Multi-unlock aggregate**:queue drain 一次過做**單一 aggregated reveal**(「3 個 zone 迷霧散開」一個 ceremony),唔係 N 個 stacked toast。Drain API:`drain_ceremony_queue() -> Array[StringName]`(consumer 攞走即清;forward contract → #20/#29,BLOCKED-ON 標記見 Interactions)。
7. **Retroactive sweep(純 local recompute)** — boot 時(load envelope 後)行一次:對全部未解鎖 zones 評估 `workout_count >= threshold` → 達標即 unlock(行 Rule 3 路徑)。用途:(a) v0.2 加新 zone,老玩家 count 已達 → boot 即時拎到應得 unlock;(b) Rule 5 persist-fail 嘅自愈;(c) EC-1 manifest 損壞嘅 recovery(unlock 係 count 嘅 pure derivation — **零 backend 依賴**)。Sweep 冪等(已 unlocked → skip),re-run 平。
8. **Lateral loot contract(P5 裁決,forward binding)** — **Zone-specific loot pools 必須 power-budget-neutral 對 base pools;zone 差異只可以係 thematic / cosmetic / variety**。Zone gate 住 vertical power loot = streak/count → zone → boss loot → equipment 嘅 #8 FR-3 power-laundering 繞道,封死。Zone 獎勵嘅係 Discovery(新背景 / 新敵人剪影 / 新 boss),power 永遠只嚟自真實訓練(#11/#18 鏈)。v0.2 zone content design binding。
9. **Active zone** — MVP:固定 zone 0。v0.2+:玩家喺 non-workout 時間揀(#22/#24 UI);workout 開始時鎖定當日 zone(mid-workout 唔切 — Pillar 2)。**Forward 斷言(v0.2 zone 選擇)**:zones 必須水平差異化(Rule 8)— zone 選擇必須 low-regret,唔可以存在 strictly-better progression 軸。`get_active_zone() -> ZoneDef` 係 #14 / presentation 讀面。
10. **Boot** — `_ready` 內 synchronous:load `zone.state`(`read()` 一次;corrupt → EC-1)→ `validate_registry()`(EC-4/6;**validation function 唔係 raw assert** — GUT headless 測唔到 raw assert,#18 AC-20 教訓)→ Rule 7 sweep → plain `.connect` #9 signal → READY(同 frame)。Autoload `ZoneSystem` @ `src/autoload/zone_system.gd`。**Gate G-Z-1**:ADR-0008 insertion — constraint 只有 `PersistenceLayer ≺ WorkoutStateTracker ≺ ZoneSystem`;**append 鏈尾(PrDetection 之後,#28 Telemetry 仍排最尾)**。**冇** `ZoneSystem ≺ EnemyDirector` constraint(投機 — #14 MVP 零 zone 觸點 grep 實證 `enemy_director.gd:506-508` 自 load EnemyRegistry;v0.2 read 發生喺 workout-start **runtime**,唔係 boot frame — G-Z-2 pin)。**接線方向**:#19 係 late-boot consumer(sources 全部早 boot)— 自己 `_ready` plain connect 即可;**G-PR-4 reverse-wire 唔適用**(嗰個係 emitter-after-consumer 嘅相反情境);milestone-style `connect_for_initial_state` 都唔使(transient event 唔係 state snapshot,boot frame 零 emit + sweep pull 補底)。

### States and Transitions

| State | 意義 |
|-------|------|
| `INITIALISING` | `_ready` 內 synchronous:load envelope → validate registry → sweep → connect #9 |
| `READY` | 接 `workout_completed_forwarded`;serve `get_active_zone()` / unlock 讀面 |

(無 SUSPENDED / GSM Contract 6 需求 — **理由(Pass 1 修正後企得住)**:零 backend 恢復依賴(Rule 7 sweep 係唯一 recovery,純 local);#9 喺 SUSPENDED 唔 emit(#2 queue 上游 hold,resume 後 drain 先到);#19 stateless per-event + persist 即時。#9 SUSPENDED 期間 defensive drop 嘅 event 屬 accepted one-shot miss — EC-8。)

### Interactions with Other Systems

| 系統 | 誰 own | 流入 #19 | 流出 #19 | 備註 |
|------|--------|----------|----------|------|
| **#3 Persistence** | #3 own IPersistence;**G-Z-3**:`zone.` namespace 註冊(VALID_NAMESPACES `persistence_layer.gd:291-294` 一行 + #3 GDD Rule 12 registry 一行 + namespace lint **create-or-amend** — lint 未 shipped,#18 G-PR-6 同款) | boot `read("zone.state")` | `write("zone.state", dict, flush=true)` per unlock / count 變化 | 單 envelope(Rule 5);localStorage FORBIDDEN |
| **#9 WST** | #9 own signal(**shipped**:`workout_state_tracker.gd:69`) | `workout_completed_forwarded(completed_at, transition_id)` | — | training-day count source(Rule 2);plain connect |
| **#14 EnemyDirector** | #19 own `get_active_zone()` | — | wave_archetype_pool / boss_pool(**空 = unfiltered sentinel**,MVP)| **G-Z-2(v0.2)**:#14 喺 workout-start runtime read + amendment 一行;MVP zero-churn(grep 實證 #14 零 zone 觸點)|
| **#16 Boss** | (經 #14 鏈) | — | boss_pool scope(sentinel 同上) | v0.2 |
| **#15/#17 Loot/Equipment** | 各自 | — | **Rule 8 lateral contract**(forward binding):zone loot pools power-budget-neutral | v0.2 zone content 時 enforce |
| **#29 Mirror Moment** | #29 own ceremony | — | `zone_unlocked` signal + ceremony queue(weekly marker 之一,#8 L46 列明) | **BLOCKED-ON: #29 未 design** — MVP queue 照 persist,consumer 後補 |
| **#20/#33** | 各自 | — | `drain_ceremony_queue()` + aggregated reveal contract(Rule 6) | **BLOCKED-ON: #20 ceremony surface story** — MVP 1 zone ALWAYS,queue 實際空 |

> **Bidirectional sync flags(寫 #19 後回填)**:#3(G-Z-3 namespace)· #9(downstream 表加 #19 subscriber row)· ADR-0008(G-Z-1)· #14(G-Z-2 v0.2)· **#18 pr-detection.md ×3 處 milestone-consumer 引用 actualize ✅ 已同步**(#18 Rule 9 / Interactions #19 row / Future Extensions —「#19 已接做 unlock kind」改「v0.2 ratify Σmagnitude PR_SCORE 先加」;#18 嘅 milestone signal 回復「MVP 無 consumer,telemetry only」— 同 #18 自己 CD directive 一致)· registry entities.yaml。

## Formulas

> 唯一計算:training-day count(Rule 2)。Unlock 係 threshold 比較(`workout_count >= threshold`)。

### Training-day count(Rule 2 形式化)

```
on workout_completed_forwarded(completed_at, transition_id):
    if transition_id == state.last_counted_transition_id: return   # replay dedup
    var day := utc_date_string(completed_at)                        # "YYYY-MM-DD",純函數
    if day == state.last_counted_date: return                       # per-day cap 1
    state.workout_count += 1
    state.last_counted_transition_id = transition_id
    state.last_counted_date = day
    evaluate_unlocks()                                              # Rule 3
    persist()                                                       # Rule 5
```

*Variance:全部 input 嚟自 payload(server timestamp + transition_id)— deterministic,零 clock seam。同 UTC 日內第二個 workout 唔計(under-count 方向,安全);out-of-order redelivery 由 #2 cursor ordering(ADR-0002)保證唔出現,單 slot cursor 夠(假設記低 — epic 時對返 #2 ordering 保證)。*

## Edge Cases

- **EC-1 (HIGH) — Envelope persist 損壞 / 缺失**:fallback = ALWAYS zones 可用(derived,MVP = zone 0)+ `zone.manifest_corrupt` CRITICAL telemetry,**唔好** lock 死玩家(anti-pillar)。Earned unlocks recovery = Rule 7 sweep 由 count 重新 derive(count 都冇埋 → reset 0 + telemetry — count 係唯一 non-derivable primary state,誠實申報;**零 backend 恢復 claim** — 嗰個 server 面唔存在,ADR-0002 endpoints 冇 zone,Pass 1 已糾正)。
- **EC-2 (MEDIUM) — Signal replay(bfcache / boot catch-up)**:transition_id cursor → no-op;unlock 寫入冪等(已 unlocked → skip,唔重複 emit / 唔重複 queue)。
- **EC-3 (MEDIUM) — v0.2 加新 zone,老玩家 count 已達 threshold**:boot Rule 7 sweep 即時 unlock + ceremony queue(aggregated reveal — 唔使等下一次 workout)。
- **EC-4 (LOW) — Registry 載入失敗 / 0 entries / 無 ALWAYS zone**:`validate_registry() == false` + push_error(**唔用 raw assert** — GUT headless 測唔到),boot 停喺 INITIALISING + CRITICAL telemetry(遊戲冇 zone 唔可以行 — fail loud)。
- **EC-5 (LOW) — Mid-workout 達 threshold**:unlock persist 即時;ceremony 入 queue 經 #33 排程(window:唔遲過 post-workout summary);active zone 唔切(Rule 9)。
- **EC-6 (LOW) — Duplicate zone_id / threshold < 1 / kind == UNKNOWN entry**:`validate_registry() == false` + push_error per entry(同 EC-4 path)。
- **EC-7 (MEDIUM) — Unlock persist write 回 false**:唔 emit + in-memory rollback + `zone.persist_failed` telemetry;下次 boot sweep 自愈(Rule 5 binding — ceremony 冇放,領土冇消失,一致)。
- **EC-8 (LOW) — #9 SUSPENDED 期間 defensive drop 咗 workout event**:該 training day 唔入 count — accepted one-shot miss(#2 suspend queue 上游 hold 令主路徑唔可達;count 唔 derivable 所以 sweep 唔補)+ deliberate-decision 記錄。Under-count 方向,anti-fabrication-safe。

## Dependencies

### Upstream(Hard)
| 系統 | Interface | 缺佢會點 |
|------|-----------|----------|
| **#3 Persistence** | `zone.state` key(G-Z-3 namespace) | unlock / count 唔 persist |
| **#9 WST** | `workout_completed_forwarded`(shipped ✓) | count 軸盲 — MVP 1 zone ALWAYS 照行,framework 閒置 |

### Downstream
#14(wave/boss pool scope,G-Z-2 v0.2)· #16(經 #14)· #29(marker signal + queue,BLOCKED-ON #29)· #20/#33(ceremony drain,BLOCKED-ON #20 story)· #22/#24(v0.2 zone 選擇 UI)· #15/#17(Rule 8 lateral contract,v0.2)

### ADR / 架構約束
- **ADR-0003**:`zone.state` backend-primary posture;unlock flush=true。(Recovery = local sweep — 見 EC-1;零 server 恢復面依賴。)
- **ADR-0006**:Contract 4 boot;Contract 3(envelope to_dict/from_dict);**Contract 6 唔適用**(States 段理由)。
- **ADR-0007**:UnlockCondition kind 係 Classification enum — sentinel UNKNOWN last,zero-default fabrication FORBIDDEN(load 到 UNKNOWN kind = config error,EC-6)。
- **ADR-0008**:gate G-Z-1 — `PersistenceLayer ≺ WST ≺ ZoneSystem`,append 鏈尾(PrDetection 之後;#28 仍最尾)。
- **ADR-0009**:envelope typed SerializableResource;signal payload minimal(`zone_unlocked(zone_id)`)。
- **無新 ADR**。

## Tuning Knobs

| Knob | 預設值 | Safe Range | 影響 |
|------|--------|-----------|------|
| Per-zone `threshold`(WORKOUT_COUNT) | v0.2 data | ≥1 int;validate EC-6 | 太低 → unlock 無感;太高 → 內容鎖死。**v0.2 pacing 錨**:3x/week 玩家 → threshold 20 ≈ 6-7 週(time-to-unlock 表 v0.2 content design 時補全) |
| `ZoneRegistry.tres` 內容 | 1 zone(MVP) | data | zone 內容本身 |

> Runtime knobs 接近零 — by design(容器層)。Per-day cap = 1 係**語意(training-day count 定義)唔係 knob**。

## Test Seams(4 類 — #17/#18 慣例,untyped DI)

1. **`_persistence`**(untyped,default→PersistenceLayer)— EC-1 garbage 注入 / EC-7 write→false / flush-arg spy
2. **Registry 注入**(`load_registry(reg)` test entry)— AC-01/02/05/07 全靠佢(第二 zone / invalid entries)
3. **`_workout_source`**(untyped signal source,default→WorkoutStateTracker)— AC-02/03/06 emit 控制
4. **`_telemetry_log`**(append-log + `get_telemetry()`,#15/#17 verbatim pattern,`_emit_telemetry(event: String, data)`)— telemetry asserts。Events:`zone.manifest_corrupt` / `zone.persist_failed` / `zone.registry_invalid` / `zone.unlocked`。

> 零 clock seam — Rule 2 date 係 payload 純函數(deliberate)。

## Visual/Audio Requirements

- **Layer Discipline binding**(art bible):`world_palette_id` 必須係 desaturated -30% 變體 — zone 背景永遠唔同 loot/HUD 搶飽和度。
- **Zone unlock ceremony**(v0.2):aggregated 迷霧散開 reveal — #29 Mirror Moment 級數,#19 只提供 queue + data,ceremony 唔係 #19 own(Rule 6 forward contract)。
- 無 audio 需求(zone BGM → #4 catalog,v0.2)。

> 📌 **Asset Spec** — MVP zone 背景(verdant forest,楓之島式)係 MVP 必需 asset。Art bible approve 後跑 `/asset-spec system:zone-system`。

## UI Requirements

> MVP **零 UI**(1 zone,無得揀)。讀面:`is_zone_unlocked(zone_id) -> bool` / `get_unlocked_zone_ids() -> Array[StringName]`(defensive copy)/ `get_active_zone() -> ZoneDef` / `drain_ceremony_queue() -> Array[StringName]`。v0.2 zone 選擇 map(#22/#24)— 到時 `/ux-design`。

## Acceptance Criteria

> GWT;Logic = unit-testable(seams 上節)。Evidence path:`tests/unit/zone_system/` + `tests/integration/zone_system/`。

- **AC-01 (Logic)** — **GIVEN** MVP registry(1 zone ALWAYS,pools 空),**WHEN** boot,**THEN** `get_active_zone().zone_id == &"zone_verdant_forest"`、`is_zone_unlocked(&"zone_verdant_forest") == true`(derived)、persisted manifest **唔含** ALWAYS zone(Rule 4)。
- **AC-02 (Logic)** — **GIVEN** 注入 registry 加第二 zone(WORKOUT_COUNT 2)+ count 1,**WHEN** `workout_completed_forwarded(t2, "txn-B")`(新 UTC day),**THEN** count → 2、`write("zone.state", _, flush=true)` **先於** `zone_unlocked` emit(spy order assert)、emit 一次、ceremony_pending 含該 zone_id。
- **AC-03 (Logic)** — **GIVEN** AC-02 後,**WHEN** 同一 `"txn-B"` replay,**THEN** count 不變、零第二次 emit、零 queue 重複(EC-2)。
- **AC-04 (Logic)** — **GIVEN** persist 回 garbage(`_persistence` mock),**WHEN** boot,**THEN** ALWAYS zones 可用 + `zone.manifest_corrupt` telemetry(spy assert)、唔 crash(EC-1)。
- **AC-05 (Logic)** — **GIVEN** count 已 persist = 25 + 注入 registry 新 zone(WORKOUT_COUNT 20),**WHEN** boot,**THEN** Rule 7 sweep 即時 unlock + ceremony_pending 含佢(EC-3 retroactive)。
- **AC-06 (Logic)** — **GIVEN** count 4 + threshold 5,**WHEN** `workout_completed_forwarded(t_same_day, "txn-C")`(`utc_date(t_same_day) == last_counted_date`),**THEN** count 不變(per-day cap);**WHEN** `workout_completed_forwarded(t_next_day, "txn-D")`,**THEN** count → 5 + unlock(Rule 2)。
- **AC-07 (Logic)** — **GIVEN** registry 有 duplicate zone_id / 0 entries / threshold 0 / kind UNKNOWN(四個 vector),**THEN** `validate_registry() == false` + push_error + `zone.registry_invalid` telemetry,boot 停 INITIALISING(EC-4/6;**唔用 raw assert**)。
- **AC-08 (Integration)** — **GIVEN** unlock + count + cursors + ceremony_pending persist,**WHEN** boot round-trip(真 PersistenceLayer),**THEN** envelope 完全還原(`tests/integration/zone_system/test_zone_persistence_roundtrip.gd`)。
- **AC-09 (三件套,G-Z-2 zero-churn)** — **(a) Logic**:MVP registry pools 空 → `get_active_zone().wave_archetype_pool.is_empty()`(unfiltered sentinel — data assert,test 自己 call,唔扮 #14);**(b) regression gate**:combined CI(unit+integration)green,#14 suite 零變化(現有 evidence);**(c) static gate(story-done check)**:grep `enemy_director.gd` 零 `ZoneSystem` reference(MVP)。
- **AC-10 (Logic)** — **GIVEN** `write` mock 回 false,**WHEN** unlock 觸發,**THEN** 零 emit、`unlocked_zone_ids` rollback、`zone.persist_failed` telemetry(EC-7);**WHEN** 下次 boot(write 恢復),**THEN** sweep 補返 unlock。
- **AC-11 (Logic)** — **GIVEN** sweep 一次 unlock 3 zones,**THEN** ceremony_pending 含 3 entries + `drain_ceremony_queue()` 一次過回 3 個並清空(aggregate 由 consumer 做單一 reveal — #19-side assert queue 語意)。
- **AC-12 (Logic)** — Boot ordering:load envelope **先於** sweep **先於** connect #9(injection order assert);`_ready` 完結時 READY(synchronous)。

## Future Extensions(v0.2+,非 MVP)

- **PR_SCORE kind**(float threshold,Σmagnitude 軸)— CD ratify 後加 enum + `threshold_f` field;#18 嘅 Σmagnitude data surface 已備(pr-detection.md Rule 6.5 persist field),屆時開 #18 additive getter gate。
- **Streak 軸 rehabilitation** — pending **EG-4** 裁決(rest-day grace / weekly-frequency 重定義)。
- **Composite any-of conditions**(`Array[UnlockCondition]`)— 有真實需求先加。
- **Zone 選擇 UI**(#22/#24)+ low-regret 斷言(Rule 9)。
- **Time-to-unlock pacing 表**(per threshold × cadence)— v0.2 content design 必交。

## Open Questions / Cross-System Gates

| # | 問題 | Resolution path | Owner |
|---|------|-----------------|-------|
| **G-Z-1** | ADR-0008 insertion:`PersistenceLayer ≺ WST ≺ ZoneSystem`,append 鏈尾(PrDetection 之後,#28 仍最尾)— **零 EnemyDirector constraint** | ADR-0008 focused amendment(同 G-PR-3 一齊做) | technical-director |
| **G-Z-2** | #14 v0.2 接入:workout-start **runtime** read `get_active_zone()`(唔係 boot)+ #14 amendment 一行;MVP zero-churn(pool sentinel) | v0.2 | #14 / v0.2 |
| **G-Z-3** | #3 `zone.` namespace:VALID_NAMESPACES 一行 + Rule 12 registry 一行 + lint create-or-amend(未 shipped — #18 G-PR-6 同款) | #19 epic story | #19 epic / #3 |
| **Q-Z-1** | v0.2 zone 2-3 thresholds:**依據 = #9 workouts/week 分佈 + D7/D30 retention**(#28 Telemetry 未存在 — 依賴佢 ship 或 manual query GymSys DB;small-N 下係「設計 rationale + 觀察」唔係統計,誠實申報) | v0.2 content design | balance |
| **Q-Z-2** | Zone 切換嘅 #14/#26 場景重載協議(workout 開始時鎖定 — 邊個觸發 reload?) | v0.2(MVP 單 zone 無切換) | v0.2 architecture |
| **EG-4** | #8 streak reachability erratum(上游,唔 block #19)— streak 軸喺 #19 重新考慮嘅前提 | `production/escalations/EG-4-streak-reachability.md` → fresh-session CD adjudication | CD / #8 |

> **Review 處理紀錄**:Pass 1(MAJOR,5 specialists + CD)→ 本 revision 按 CD P1-P6 + R1-R5 重寫(軸重裁 / signal contract / envelope / boot chain / ceremony + seams + 12 ACs)。詳見 `design/gdd/reviews/zone-system-review-log.md`。**Pending fresh re-review** — exit bar 12 項 grep-verifiable + 0 new phantom。
