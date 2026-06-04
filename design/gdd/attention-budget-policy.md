# Attention Budget & Interaction Policy

> **Status**: Designed (pending /design-review) — all 8 sections authored 2026-06-04 (autonomous inline mode; CD-GDD-ALIGN + specialist review deferred to fresh-session /design-review)
> **Author**: Frank + (creative-director · game-designer · systems-designer · ux-designer · qa-lead)
> **Last Updated**: 2026-06-04
> **Implements Pillar**: **Pillar 2 — 無壓力陪伴 (Frictionless Companion)** [PRIMARY enforcement owner]
> **System #**: 33 (Core / Pre-MVP)
> **Depends On**: #1 GameStateMachine (`state_changed` / `get_current_state()`) · #9 WorkoutStateTracker (`phase_changed` / `get_current_phase()`)
> **Depended on by**: #20 Gym-Mode HUD (`is_input_permitted()` — AC-CR-5 input-gate, 現用 fallback AC-EC-S5) · notifications · modals (#21 loot)

---

## ⚠️ DESIGN CONTEXT (pre-loaded — read before authoring each section)

呢個 skeleton 由 `/design-system attention-budget-policy` Phase 2 gather context 後建立。Fresh session resume 時，以下係 **locked constraints**（architecture + 上游 GDD 已定），GDD 必須 honor，唔可矛盾：

### Architecture (ADR-0006 — Accepted, 已 lock)
- **Contract 13 — `IInputPolicy` interface (THE core contract)**:
  - `class_name IInputPolicy extends RefCounted` · `func is_input_permitted() -> bool` (push_error if not overridden)
  - **`AttentionBudgetPolicy extends IInputPolicy`** — concrete Pillar 2 enforcement; `is_input_permitted()` **derives from `GameStateMachine.current_state`** (read-only; GSM 係 source of truth)
  - **`MockInputPolicy extends IInputPolicy`** for tests (`func is_input_permitted() -> bool: return _permitted`)
  - **Input handlers (HUD/modals) accept `IInputPolicy` via constructor injection** — NOT direct reference to `AttentionBudgetPolicy`
  - Pillar 2 enforcement lives at the **input-handler boundary**, NOT the state-machine boundary. State machine = read-only current_state; IInputPolicy = the gate input handlers respect.
- **Contract 4 — boot order**: AttentionBudget autoload position **11+** (after PersistenceLayer pos 1 + GameStateMachine pos 2). Per-instance sequential boot.
- **GSM subscription**: 用 `connect_for_initial_state(callable)` (Contract 6) — 唔可 plain `.connect` in `_ready` (miss initial state).

### Architecture (Proposed — flag, not yet locked)
- **ADR-0008 Autoload Position Map** — AttentionBudget absolute position **undefined / Queued**. GDD 可 spec partial-order constraint (pos 11+, after GSM) but absolute position deferred to ADR-0008 ratification. **Insertion rule already noted in ADR-0008 for #33.**

### Hard contracts (from EPIC — Pillar 2 constitutional law)
1. **max 0 玩家互動 per `SET_ACTIVE` state** — gym session 期間 game 係 companion 唔係主角。任何 mid-set required interaction = cardinal sin。
2. **glance budget < 2 秒** — 任何 UI element 唔可要求 >2s 注意力（#20 HUD 自己 own 0.3s 餘光,#33 係 cross-system policy 上限）。
3. **notification suppression** — `SET_ACTIVE` 期間唔可觸發任何非致命 notification（coach-nag = Pillar 2 anti-pattern）。
4. **phone-lock / app-switch recovery** — resume 後 game 回到正確 WorkoutPhase state（同 #1 SUSPENDED + #9 bfcache + #20 reconcile 協調；#33 定 input-policy 層 recovery）。

### Consumer expectation (已 spec, 必須滿足)
- **#20 HUD AC-CR-5**: `is_input_permitted()==false` 時 tap 唔被消費 (early-return)。#20 現用 fallback AC-EC-S5 (banner tap 直接 unlock 豁免 gating) 因 #33 未 implement。#33 GDD 須定義 banner-unlock tap 係 exempt（unlock gesture 永不 gated）vs 一般 HUD tap（gated during SET_ACTIVE）。

### Dependencies data flow
- **IN ← #1 GSM**: `state_changed(from, to, payload)` push + `get_current_state()` pull (current_state = input-permission 真相源)
- **IN ← #9 WST**: `phase_changed(from, to)` + `get_current_phase()` — `SET_ACTIVE` phase 係 strictest gate window
- **OUT → consumers**: `is_input_permitted() -> bool` pull (NOT a signal — handlers query at input time)

### Anti-pattern 警告 (design test 種子)
- **「The Nag Engine」**: #33 變成另一個 fitness app 嘅 notification spammer。#33 嘅成功 = 玩家 mid-set **完全冇** game 打斷;policy 係「乜都唔准」嘅 constitutional NO，唔係「幾時 nag」嘅 scheduler。

### Open architecture question (carry to Open Questions section)
- ADR-0008 AttentionBudget absolute autoload position (Proposed → needs ratification)
- `is_input_permitted()` 係純 GSM-state-derived 定要 #9 phase 細分（SET_ACTIVE vs REST_PERIOD 唔同 gate level）?— Contract 13 講 derive from GSM current_state，但 hard-contract #1 講 SET_ACTIVE（#9 phase）。reconcile: GSM COMBAT_ACTIVE/WORKOUT_ACTIVE vs #9 SET_ACTIVE phase 嘅 gate 關係。

---

## Overview

Attention Budget & Interaction Policy（#33）係 Mirror Hero 嘅 **Pillar 2（無壓力陪伴 / Frictionless Companion）憲法執行層**。佢係一個 autoload service（`AttentionBudget`，boot pos 11+），對外只暴露一個極窄嘅 read-only API：`is_input_permitted() -> bool`（透過 ADR-0006 Contract 13 嘅 `IInputPolicy` interface，由 input handler 經 constructor 注入；handler 永不直接 reference 呢個 autoload）。佢嘅唯一職責 = 喺玩家**正在做緊一組 set（#9 WorkoutStateTracker `SET_ACTIVE` phase）嗰一刻**，保證 game **完全唔會要求、消費或打斷玩家任何注意力**：HUD tap early-return、required modal 唔彈、non-critical notification 全部 suppress。

Policy 係**純 pull-based derivation** —— 每次 query 都即時由 live `GameStateMachine.current_state`（#1）+ `WorkoutStateTracker.get_current_phase()`（#9）兩層計出，**唔保存任何 cached gate state**，所以 phone-lock / app-switch resume 之後自動回到正確 gate（冇 stale lock 阻住「set 完一 tap 落一個動作」，亦冇 stale open 容許 mid-set 打斷）。實作細節（IInputPolicy interface contract、boot position、subscription helper）由 ADR-0006 Contract 13 / 4 / 6 規範。系統本身唔擁有任何 UI；佢係其他所有 input / notification / modal 系統都必須遵守嘅 constitutional NO。

## Player Fantasy

#33 係玩家**永遠唔會直接察覺**嘅系統 —— 佢嘅成功指標就係「冇感覺」。玩家嘅 fantasy 唔係「我用緊一個 attention policy」，而係：

> 「我喺度狂谷最後幾 rep，個世界冇任何嘢叫我撳掣、冇 pop-up、冇『連續訓練 7 日！』嘅 nag。當我放低 barbell、抖緊氣嗰陣，先輕輕一 tap 落一個動作。部機由始至終都係我嘅**沉默拍檔**，唔係另一個 fitness app 喺度扮 coach 嘈我。」

呢個對應 game-pillars **Pillar 2「無壓力陪伴」**嘅核心承諾：game 喺 workout 期間係 **companion 唔係主角**。玩家係**間接**體驗呢個系統嘅 —— 佢哋感受到嘅唔係 #33 本身，而係 #33 所**保護出嚟嘅「不被打擾」狀態**。

**Anti-fantasy（必須杜絕）= 「The Nag Engine」**：任何 mid-set 嘅 required interaction、彈窗、震動、計時催促，都會即刻將「陪伴」變成「打擾」，直接謀殺 Pillar 2。所以 #33 唔係一個「幾時 nag 先啱」嘅 scheduler，而係一條「mid-set 乜都唔准」嘅 constitutional law —— 佢嘅預設答案永遠係 constitutional NO。

## Detailed Design

### Core Rules

**Rule 1 — Single source of permission（`is_input_permitted`）**
所有 in-session input handler（#20 HUD tap、#21 loot modal、任何 gameplay-facing interactive element）必須喺消費 input 之前 query 一個 injected `IInputPolicy.is_input_permitted()`，`false` 時 early-return（唔消費、唔產生 side-effect）。Handler **唔可** direct reference `AttentionBudget` autoload 或 `AttentionBudgetPolicy` concrete class —— 只可透過 constructor-injected `IInputPolicy`（ADR-0006 C13；保證 testability via `MockInputPolicy`）。Enforcement 喺 **input-handler boundary**，唔喺 state-machine boundary。

**Rule 2 — Pure pull-based derivation（no cached gate）**
`is_input_permitted()` 係 stateless pure function，每次 call 即時讀 live `GameStateMachine.current_state` + `WorkoutStateTracker.get_current_phase()` 計出（見 Formula 1），**唔保存任何 gate state**。呢個係 hard-contract #4（phone-lock recovery）嘅**架構性保證**：suspend / resume 之後冇 stale gate 可以殘留，唔需要任何 reset logic。

**Rule 3 — `SET_ACTIVE` 係 cardinal lock window（phase 壓倒 state）**
當 `WorkoutStateTracker.get_current_phase() == SET_ACTIVE`，`is_input_permitted()` 必返 `false`，**無視 GSM state**（即使 GSM 係 COMBAT_ACTIVE / BOSS_ENCOUNTER，mid-set 保護壓倒一切）。呢個直接 encode hard-contract #1「max 0 player interaction per SET_ACTIVE」。

**Rule 4 — Lifecycle safety gate**
當 `GameStateMachine.current_state ∈ {BOOTING, SUSPENDED}`，`is_input_permitted()` 返 `false`（系統未 ready 或 reconciling 中，唔消費 input 防 race）。

**Rule 5 — Default-open（保住 Pillar 2 唯一輸入）**
除咗 Rule 3 + Rule 4 命中嘅情況，`is_input_permitted()` 返 `true`。Pillar 2 嘅「玩家唯一輸入」（set 完 → 一 tap 落一個動作）發生喺 `REST_PERIOD` / set-completion window，必須永遠 permitted。`IDLE` / `WARM_UP` / `REST_PERIOD` / `WORKOUT_COMPLETE` phase + `COMBAT_ACTIVE` / `BOSS_ENCOUNTER`（phase≠SET_ACTIVE）/ `LOOT_DROP` / `DISCONNECTED` state 全部容許互動。

**Rule 6 — Unlock gesture exemption（解決 #20 AC-EC-S5）**
silent-mode audio-unlock banner tap（#20 EG-2 soft-gate bootstrap gesture）**唔受 IInputPolicy 管轄**。佢係令 session 開始 counting 嘅 bootstrap gesture；若 gate 佢就會 deadlock（未 unlock → 計唔到 phase → 永遠當 gate）。Exemption 喺 handler 層實現：unlock-banner handler **唔注入** gating policy（或注入 always-permitted policy）。**GDD binding：unlock gesture 永不 gated**，正式取代 #20 現用嘅 fallback AC-EC-S5。

**Rule 7 — Notification suppression**
`AttentionBudget` autoload 額外暴露 `is_notification_permitted() -> bool`（見 Formula 2）：phase == `SET_ACTIVE` 或 GSM ∈ {BOOTING, SUSPENDED, LOOT_DROP} 時返 `false`。任何 **non-critical** notification producer（#8 streak nag、coach tip、loot badge toast）必須 query 呢個先 fire。被 suppress 嘅 notification **直接 DROP，唔 queue**（queued nag = 延遲嘅打擾，等於 The Nag Engine）；需要「workout 後先顯示」嘅 producer 自己 own 延遲邏輯（例如 #8 milestone 喺 `WORKOUT_COMPLETE` 自行重發）。**Critical** safety / data-loss notification（disconnect 警告、save 失敗）**唔受 Rule 7 管**（見 EC-12）。

**Rule 8 — Glance budget ceiling（cross-system policy 上限）**
#33 定義 cross-system 上限常數 `GLANCE_BUDGET_CEILING_MS = 2000`：任何 in-session UI element 嘅 single-glance attention demand 唔可超過 2 秒（#20 HUD 自己 own 更嚴嘅 0.3s 餘光；呢個 ceiling 係畀**所有** in-session element 嘅 hard cap）。Enforcement = design-time AC + playtest（tachistoscope / observed glance），**非** per-frame runtime gate；提供 debug-build `assert_glance_within_budget(element_id, measured_ms)` 畀 instrumented playtest 用（release build no-op）。

**Rule 9 — `connect_for_initial_state` subscription**
autoload `_ready()` 用 `connect_for_initial_state(callable)`（ADR-0006 Contract 6）subscribe #1 `state_changed` + #9 `phase_changed`，**唔可** plain `.connect`（會 miss initial state）。Subscription 嘅**唯一**用途 = 驅動 notification-suppression 邊界偵測 + 可選 `input_policy_changed(permitted: bool)` affordance signal；**唔影響** `is_input_permitted()` 嘅 pure-pull derivation（Rule 2）—— 即使 subscription 從未 fire，derivation 一樣正確。

### States and Transitions

呢個系統**本質 stateless**（Rule 2 pure derivation），但 autoload 同其他 Foundation autoload 一樣有 lifecycle substate：

```gdscript
enum Substate { INITIALISING, READY }
```

| Substate | 進入條件 | `is_input_permitted()` 行為 | 離開條件 |
|---|---|---|---|
| **INITIALISING** | autoload `_ready()` | GSM 通常 == `BOOTING` → Rule 4 返 `false`（fail-closed safe） | subscribe #1+#9 via `connect_for_initial_state` → seed notification-suppression edge tracking → READY |
| **READY** | INITIALISING 完成 | 正常 live derivation（Formula 1 / 2） | （終態；冇 SUSPENDED substate） |

**冇 SUSPENDED substate** —— #33 唔 cache 任何嘢，所以唔需要 suspend / restore（對比 #9 WST 有 SUSPENDED 因為佢 cache workout data）。GSM `SUSPENDED` state 由 Rule 4 喺 derivation 層直接處理。

**Derived gate（唔係 stored state，係每次 query 計出嘅概念）**：

| GSM `current_state` | WST `phase` | `is_input_permitted()` | `is_notification_permitted()` | 規則 |
|---|---|---|---|---|
| 任意 | `SET_ACTIVE` | **false** | **false** | Rule 3 / 7（cardinal lock）|
| `BOOTING` | 任意 | **false** | **false** | Rule 4 / 7 |
| `SUSPENDED` | 任意 | **false** | **false** | Rule 4 / 7 |
| `LOOT_DROP` | ≠SET_ACTIVE | true | **false** | Rule 5 / 7（容許 dismiss tap，但唔好 toast 蓋住 ceremony）|
| `IDLE`/`WORKOUT_ACTIVE`/`REST_PERIOD`/`COMBAT_ACTIVE`/`BOSS_ENCOUNTER`/`WORKOUT_COMPLETE`/`DISCONNECTED` | `IDLE`/`WARM_UP`/`REST_PERIOD`/`WORKOUT_COMPLETE` | true | true | Rule 5 |

> 注：`SET_ACTIVE` 行（Rule 3）**無視 GSM state** —— phase gate 喺 derivation 入面優先評估。

### Interactions with Other Systems

| 系統 | 方向 | Hard/Soft | Interface | Owner |
|---|---|---|---|---|
| **#1 GameStateMachine** | IN（upstream）| Hard | pull `get_current_state()` + push `state_changed(from,to,payload)` | GSM 係 `current_state` 真相源；#33 read-only consumer |
| **#9 WorkoutStateTracker** | IN（upstream）| Hard | pull `get_current_phase()` + push `phase_changed(from,to)` | `SET_ACTIVE` phase = strict gate window；#33 read-only consumer |
| **#20 Gym-Mode HUD** | OUT（downstream）| Hard | inject `IInputPolicy`；tap handler honor `is_input_permitted()`（#20 AC-CR-5）；unlock banner handler exempt（Rule 6）| #20 own「honoring」；#33 own「permission predicate」|
| **#21 Loot Drop Modal** | OUT（downstream）| Soft | loot modal 喺 `LOOT_DROP` state（permitted）彈出 + 消費 dismiss tap；mid-set 永不 `LOOT_DROP`（GSM transition 保證）| #21 |
| **Notification producers**（#8 streak / coach tips / toasts）| OUT（downstream）| Soft | query `is_notification_permitted()` 先 fire | producer own 自己嘅 defer 邏輯 |

**Ownership boundary**：#33 owns **permission predicate**（`is_input_permitted` / `is_notification_permitted`）；consumer owns **honoring** 佢。Enforcement at **input-handler boundary**（ADR-0006 C13），唔喺 state-machine boundary —— GSM / WST 只係 read-only 真相源，唔識 #33 存在。

**Bidirectional consistency**：#33 只**讀** #1 / #9 嘅 already-public API（`get_current_state` / `get_current_phase` / `state_changed` / `phase_changed`），**唔需要 patch 上游 GDD**（consumer-forward-contract principle —— 已 merged 嘅 data-layer GDD 唔因為新 consumer 而改）。#20 GDD 已列 #33 為 AC-CR-5 嘅 provider，bidirectionality 已滿足。

## Formulas

呢個系統以 boolean predicate 為主，無連續數值 scaling。三條 predicate / constant：

### Formula 1 — `is_input_permitted` derivation

```
is_input_permitted() =
    NOT ( wst_phase == SET_ACTIVE          # Rule 3：phase 壓倒一切
          OR gsm_state == BOOTING          # Rule 4：未 ready
          OR gsm_state == SUSPENDED )      # Rule 4：reconciling
```

**Variables:**
| Variable | Type | Range | Description |
|---|---|---|---|
| `gsm_state` | `GameState` enum | {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED} | live `GameStateMachine.current_state`（#1，pull） |
| `wst_phase` | `WorkoutPhase` enum | {IDLE, WARM_UP, SET_ACTIVE, REST_PERIOD, WORKOUT_COMPLETE} | live `WorkoutStateTracker.get_current_phase()`（#9，pull） |

**Output Range:** `bool`（`true` = 容許互動 / `false` = lock）。fail-closed：若任一 dependency ref 為 null 且 `FAIL_CLOSED_ON_NULL_DEP == true` → 返 `false`（見 EC-2）。
**Example:** `gsm_state = BOSS_ENCOUNTER`, `wst_phase = SET_ACTIVE` → `NOT(true OR false OR false)` = `NOT true` = **`false`**（mid-set 保護壓倒 boss 戰）。
**Example:** `gsm_state = COMBAT_ACTIVE`, `wst_phase = REST_PERIOD` → `NOT(false OR false OR false)` = **`true`**（抖緊氣 → 一 tap window 開放）。

### Formula 2 — `is_notification_permitted` derivation

```
is_notification_permitted() =
    NOT ( wst_phase == SET_ACTIVE
          OR gsm_state == BOOTING
          OR gsm_state == SUSPENDED
          OR gsm_state == LOOT_DROP )      # 額外：唔好 toast 蓋住 loot ceremony
```

**Variables:** 同 Formula 1。
**Output Range:** `bool`。比 Formula 1 多一個 `LOOT_DROP` suppression term（input 容許 dismiss，但 non-critical notification 唔好打斷 ceremony）。
**Example:** `gsm_state = LOOT_DROP`, `wst_phase = WORKOUT_COMPLETE` → `is_input_permitted() = true` 但 `is_notification_permitted() = false`。

### Formula 3 — glance budget ceiling check

```
glance_within_budget(measured_ms) = measured_ms <= GLANCE_BUDGET_CEILING_MS
```

**Variables:**
| Variable | Type | Range | Description |
|---|---|---|---|
| `measured_ms` | int | 0 – ∞ | playtest 量度嘅 single-glance attention demand（毫秒）|
| `GLANCE_BUDGET_CEILING_MS` | int const | 2000（safe [800, 3000]）| cross-system glance 上限 |

**Output Range:** `bool`。boundary：`measured_ms == 2000` → `true`；`2001` → `false`。
**Example:** #20 HUD 餘光量度 300ms → `glance_within_budget(300) = true`（遠低於 ceiling，亦低於 #20 自己嘅 0.3s 目標）。

## Edge Cases

- **EC-1 — phase signal 喺 boot 時早過 state signal 到達**：pure-pull（Rule 2）令 derivation 冇 ordering dependency —— `is_input_permitted()` 永遠即時讀兩個 live 值。signal 到達次序唔影響結果。
- **EC-2 — query 時 dependency ref 為 null**（autoload 未 register / 太早 query）：若 GSM 或 WST ref == null 且 `FAIL_CLOSED_ON_NULL_DEP == true` → 返 `false`（fail-closed = safe，唔消費 input）。正常情況下 boot pos 11+ 保證 GSM(pos 2) + WST(pos 5) 已 ready。
- **EC-3 — GSM 同 WST 唔一致**（GSM == `IDLE` 但 WST phase == `SET_ACTIVE`）：`SET_ACTIVE` 壓倒（Rule 3）→ `false`。永遠 fail 去保護嗰邊。
- **EC-4 — 同一 frame 內 `state_changed` + `phase_changed` 同時到**：pure-pull 讀最終值，`is_input_permitted()` 唔會 expose 中間 flicker（synchronous）。`input_policy_changed` affordance signal 可能 emit 兩次 → consumer handler 必須 idempotent。
- **EC-5 — unlock gesture 喺 SET_ACTIVE 期間發生**：exempt（Rule 6），unlock handler 唔 gated → unlock 照行。（注：soft-gate 下 counting 喺 unlock 後先開始，所以 pre-unlock 通常停喺 IDLE/WARM_UP；若 pre-unlock 有 stray `set_logged`，由 #9 + #20 處理；#33 嘅 binding 只係：unlock 永不 gated。）
- **EC-6 — phone-lock mid-set**：GSM → `SUSPENDED` → `false`（Rule 4）。resume 後 GSM 還原（例如返 `COMBAT_ACTIVE`），WST 由 snapshot reconcile phase。`is_input_permitted()` 即時重新 derive → 正確，**冇 stale lock**（Rule 2 架構保證）。
- **EC-7 — resume 後落喺 reconciled `SET_ACTIVE`**：WST reconcile 到 last-known phase 若係 `SET_ACTIVE`，#33 honor 之 → 維持 lock 直到真 `rest_started` / 下個 `set_logged` 更新 #9 phase。#33 唔自行判斷 phase，只 honor #9。
- **EC-8 — notification 啱啱喺 `SET_ACTIVE` entry fire**：producer 喺 fire-time query `is_notification_permitted()` → `false` → **DROP（唔 queue）**。延遲嘅 nag = The Nag Engine，禁止。需要「workout 後顯示」嘅 producer 自行喺 `WORKOUT_COMPLETE` 重發。
- **EC-9 — glance element playtest 量度 >2000ms**：AC fail（design 必須收窄），**唔係** runtime block。debug build `assert_glance_within_budget` push_error；release build no-op。
- **EC-10 — HUD 每 frame query `is_input_permitted()`（hot path）**：必須 O(1) cheap（兩個 enum read + 比較），零 allocation。見 perf AC-17。
- **EC-11 — 多個 `IInputPolicy` instance 注入唔同 handler**：全部由同一個 global GSM/WST derive → 結果一致，冇 divergence（stateless，shared flyweight 或 per-handler 皆可）。
- **EC-12 — Critical notification 喺 SET_ACTIVE**（disconnect 警告 / save 失敗）：**唔受 Rule 7 管** —— critical safety/data-loss notification 直接 fire（資料完整性 > Pillar 2 不打擾）。producer 用獨立 critical channel，唔 query `is_notification_permitted()`。
- **EC-13 — `DISCONNECTED` state + pending tap**：`is_input_permitted()` 返 `true`（容許玩家撳 reconnect affordance）；#33 唔 gate disconnect/login UI（嗰個係 #24 domain）。
- **EC-14 — 快速 `SET_ACTIVE ↔ REST_PERIOD` 震盪**（玩家重新握 bar）：每次都係 fresh derivation，#33 唔做 debounce（phase 穩定性係 #9 嘅責任）；#33 純 honor #9 當前 phase。

## Dependencies

| 系統 / ADR | 方向 | Hard/Soft | Interface | Patch 需求 |
|---|---|---|---|---|
| **#1 GameStateMachine** | upstream IN | Hard | `get_current_state()` pull + `state_changed(from,to,payload)` push | 無（read-only already-public API）|
| **#9 WorkoutStateTracker** | upstream IN | Hard | `get_current_phase()` pull + `phase_changed(from,to)` push | 無（read-only already-public API）|
| **#20 Gym-Mode HUD** | downstream OUT | Hard | inject `IInputPolicy`；honor `is_input_permitted()`（AC-CR-5）；unlock exempt（Rule 6）| #20 已列 #33 為 provider；implement 後可由 fallback AC-EC-S5 升級到真 gating |
| **#21 Loot Drop Modal** | downstream OUT | Soft | `LOOT_DROP` state 彈窗 + dismiss tap | 無 |
| **#8 Streak + notification producers** | downstream OUT | Soft | query `is_notification_permitted()` | 無 |
| **ADR-0006 Contract 13** | architecture | Hard | `IInputPolicy extends RefCounted` + `is_input_permitted()`；`AttentionBudgetPolicy` / `MockInputPolicy`；ctor injection | inherited（已 Accepted）|
| **ADR-0006 Contract 4** | architecture | Hard | autoload boot pos 11+（after PersistenceLayer pos 1 + GSM pos 2 + WST pos 5）；per-instance sequential boot | inherited |
| **ADR-0006 Contract 6** | architecture | Hard | `connect_for_initial_state(callable)` subscription | inherited |
| **ADR-0008 Autoload Position Map** | architecture | — | AttentionBudget **absolute** position（Proposed/Queued）| **Open Q-OQ1** — partial-order pos 11+ honored；absolute deferred to ADR-0008 ratification |

**Hard vs Soft**：#1 + #9 係 hard（#33 冇佢哋無法 derive permission）；#20 / #21 / notification producers 係 soft（佢哋係 consumer，#33 唔依賴佢哋運作）。

**Bidirectional consistency**：#33 純 read-only consumer of #1 / #9 already-public surface → **唔需要 patch 上游已 merged GDD**（consumer-forward-contract principle，與 #4 audio EG-1 / #20 同源）。#20 GDD 已 reference #33（AC-CR-5），bidirectionality 已成立。

## Tuning Knobs

| Knob | Default | Safe range | 影響 | 太高 | 太低 |
|---|---|---|---|---|---|
| `GLANCE_BUDGET_CEILING_MS` | 2000 | [800, 3000] | cross-system single-glance attention 上限（Formula 3）| >3000 背叛 Pillar 2（element 要太多注意力）| <800 過度限制合理可讀 HUD |
| `NOTIFICATION_SUPPRESSED_STATES` | `{SET_ACTIVE, BOOTING, SUSPENDED, LOOT_DROP}` | data-driven set | 邊啲 context mute non-critical notification（Formula 2）| 太闊 = 漏 important info | 太窄 = nag leak（The Nag Engine）|
| `FAIL_CLOSED_ON_NULL_DEP` | `true` | bool | dependency ref null 時 `is_input_permitted` 返值（EC-2）| — | `false` = unsafe interaction leak（mid-set 可能照消費 tap）|

### Constitutional constants（非自由 tuning —— 改動需經 design review，唔可隨手調）

| Constant | Value | Rationale |
|---|---|---|
| `INPUT_LOCKED_PHASES` | `{SET_ACTIVE}` | mid-set lock window。加 phase 會 over-lock（封死「一 tap 落動作」嘅 Pillar 2 唯一輸入）；移除 `SET_ACTIVE` = Pillar 2 死亡。|
| `MAX_SET_ACTIVE_INTERACTIONS` | `0` | hard-contract #1 嘅 constitutional 0 —— 文件化嘅紅線，非可調參數。|

## Visual/Audio Requirements

#33 係 pure policy service，**唔擁有任何 UI / VFX / audio**。但佢定義一條塑造 consumer 視覺 affordance 嘅 cross-system 約束：

- 當 `is_input_permitted() == false`（mid-set），consumer（#20 HUD）應將可互動 affordance 視覺上 de-emphasize。**#33 唔重複定義視覺手法** —— #20 已 own dim / alpha 三軸；#33 只係呢個 lock 狀態嘅**來源**。
- 可選 `input_policy_changed(permitted: bool)` signal 畀 consumer 更新 affordance；非必要（consumer 可 poll `is_input_permitted()`）。
- **冇 audio** —— notification suppression 嘅正確表現就係**靜默**（無聲 = 成功）。

呢個系統**唔屬於 visual system category**（Foundation/Core infrastructure），所以**無 asset spec 需求**。

## UI Requirements

#33 **唔貢獻任何 screen / HUD element**（pure policy service）。佢只係 #20 HUD 等 consumer 嘅 permission 來源。**無 UX spec 需求** —— consumer 嘅 UX（#20 HUD 喺 lock 狀態嘅 tap affordance）喺 #20 自己嘅 ux-design 處理。

> 唔出 UX Flag（#33 無 own UI）。

## Acceptance Criteria

全部用 `MockInputPolicy` + mock GSM/WST（注入 live enum 值）可獨立驗證；type = Logic（unit），除非標明。

- **AC-01（Rule 3，BLOCKING）**：GIVEN WST phase == `SET_ACTIVE`，WHEN query `is_input_permitted()`，THEN 返 `false` —— 對 GSM state ∈ {`WORKOUT_ACTIVE`, `COMBAT_ACTIVE`, `BOSS_ENCOUNTER`} 全部成立（phase 壓倒 state）。
- **AC-02（Rule 4，BLOCKING）**：GIVEN GSM state == `SUSPENDED`（phase 任意非 SET_ACTIVE），WHEN query，THEN `false`；GSM == `BOOTING` 同樣返 `false`。
- **AC-03（Rule 5 default-open，BLOCKING）**：GIVEN GSM ∈ {IDLE, WORKOUT_ACTIVE, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, DISCONNECTED, WORKOUT_COMPLETE} AND phase ∈ {IDLE, WARM_UP, REST_PERIOD, WORKOUT_COMPLETE}，WHEN query，THEN `true`。
- **AC-04（Rule 2 pure-pull，BLOCKING）**：GIVEN 兩次 query 之間直接 mutate mock GSM/WST 值（**唔送任何 signal 畀 #33**），WHEN 第二次 query，THEN 反映新值（證明無 cache）。
- **AC-05（Rule 1 injection，BLOCKING — Integration）**：GIVEN handler 用 `MockInputPolicy(permitted=false)` 構造，WHEN handler 收到 tap，THEN tap early-return（唔消費、無 side-effect）。
- **AC-06（Rule 6 exemption，BLOCKING）**：GIVEN phase == `SET_ACTIVE` AND unlock-banner handler，WHEN unlock tap，THEN unlock 照行（handler 唔 gated）。
- **AC-07（Rule 7，BLOCKING）**：GIVEN phase == `SET_ACTIVE`，WHEN query `is_notification_permitted()`，THEN `false`。
- **AC-08（Rule 7，BLOCKING）**：GIVEN phase == `REST_PERIOD` AND GSM ∉ suppressed set，WHEN query `is_notification_permitted()`，THEN `true`。
- **AC-09（EC-3 disagree，BLOCKING）**：GIVEN GSM == `IDLE` AND phase == `SET_ACTIVE`，WHEN query `is_input_permitted()`，THEN `false`（phase 壓倒）。
- **AC-10（EC-2 fail-closed，BLOCKING）**：GIVEN injected GSM ref == null AND `FAIL_CLOSED_ON_NULL_DEP == true`，WHEN query，THEN `false`。
- **AC-11（EC-6 recovery，BLOCKING — Integration）**：GIVEN suspend mid-set 後 GSM 還原到 `COMBAT_ACTIVE` 且 WST reconcile phase == `REST_PERIOD`，WHEN query，THEN `true`（無 stale lock）。
- **AC-12（Rule 9 boot，BLOCKING — Integration/static）**：GIVEN autoload `_ready()`，THEN 透過 `connect_for_initial_state` subscribe #1 `state_changed` + #9 `phase_changed`（assert subscription 存在 + initial callback 已 fire）；CI static check：呢兩個 signal **無** plain `.connect`。
- **AC-13（Formula 3 boundary，BLOCKING）**：GIVEN `GLANCE_BUDGET_CEILING_MS == 2000`，WHEN `glance_within_budget(2001)` THEN `false`；`glance_within_budget(2000)` THEN `true`。
- **AC-14（Rule 9 derivation independence，BLOCKING）**：GIVEN `state_changed` / `phase_changed` 從未 deliver（subscription 斷開）AND mock live 值 == `SET_ACTIVE`，WHEN query `is_input_permitted()`，THEN `false`（證明 derivation 獨立於 subscription）。
- **AC-15（EC-8 drop-not-queue，BLOCKING — Integration）**：GIVEN 一個 notification 喺 `SET_ACTIVE` 被 suppress，WHEN phase 之後 → `REST_PERIOD`，THEN 該 notification **唔自動 fire**（dropped，非 queued）—— 驗證無 deferred emission。
- **AC-16（Substate，BLOCKING）**：GIVEN autoload 未 READY（GSM == `BOOTING`），WHEN query `is_input_permitted()`，THEN `false`。
- **AC-17（perf，ADVISORY）**：`is_input_permitted()` O(1) 無 allocation（profiled；hot-path 每 frame 由 #20 query）。

## Open Questions

- **Q-OQ1 — ADR-0008 AttentionBudget absolute autoload position**（Proposed → 需 ratification）。Owner: technical-director。本 GDD honor partial-order pos 11+（after GSM pos 2 + WST pos 5）；absolute position deferred to ADR-0008 ratification（insertion rule 已喺 ADR-0008 為 #33 記低）。
- **Q-OQ2 — `is_input_permitted` phase-vs-GSM reconcile** — **本 GDD 已 RESOLVED**（Rule 3：WST phase `SET_ACTIVE` 壓倒 + Rule 4 GSM lifecycle safety）。記錄喺此以防 architecture review 異議；Contract 13 講「derive from GSM current_state」嘅原意係「GSM 係真相源之一」，本 GDD 將 #9 phase 加入為**更細嘅 strict gate**，唔矛盾（GSM state 仍係 Rule 4 lifecycle 真相源）。
- **Q-OQ3 — notification suppression = drop vs producer-owned re-eval** — 現 spec = **DROP**（EC-8 / AC-15）；需要「workout 後顯示」嘅 producer 自己 own deferral（例如 #8 streak milestone 喺 `WORKOUT_COMPLETE` 自行重發）。待 #8 / #28 authoring 時 confirm。
- **Q-OQ4 — `DISCONNECTED` state 嘅 gate** — 現 spec = permitted（容許 reconnect affordance；login/reconnect 係 #24 domain）。待 #24 authoring confirm 邊界。
- **Q-OQ5 — `IInputPolicy` concrete instance 係 shared flyweight 定 per-handler** — 兩者皆 valid（stateless，EC-11）；defer 到 implementation。
