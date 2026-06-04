# Attention Budget & Interaction Policy

> **Status**: ✅ Approved 2026-06-04 (pass 3 full 4-agent review — all BLOCKING resolved inline; B1 enum sentinel + B2 WORKOUT_COMPLETE gate-table + MAJOR-5 CI owner-exempt + CRITICAL-4 FAIL_CLOSED→const + G1 AC-18 split + CRITICAL-3/1 arity/has_method ACs + cross-flag #21 ceremony timing)
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
  - **`AttentionBudgetPolicy extends IInputPolicy`** — concrete Pillar 2 enforcement; `is_input_permitted()` = **Hybrid derivation**（GSM floor `{WORKOUT_ACTIVE,COMBAT_ACTIVE,BOSS_ENCOUNTER}` 強制鎖 + WST `SET_ACTIVE` phase 只可收緊；ADR-0006 C13 GSM「source of truth」= GSM floor 做 primary 憲法層）。`is_notification_permitted()` 亦喺 `IInputPolicy` interface（B-C2）。**ctor = `_init(gsm_ref, wst_ref)` untyped**（typed Node = compile-fail，參 GDScript DI seam rule）；factory = `AttentionBudget.create_policy() -> IInputPolicy`（B-B2）。
  - **`MockInputPolicy extends IInputPolicy`** for tests：`func is_input_permitted() -> bool: return _permitted`；`func is_notification_permitted() -> bool: return _notification_permitted`（兩個 stub 值獨立設）
  - **Input handlers (HUD/modals) accept `IInputPolicy` via constructor injection** — NOT direct reference to `AttentionBudgetPolicy` 或 static autoload call（B-B1）
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
- ~~`is_input_permitted()` phase-vs-GSM reconcile~~ **RESOLVED 2026-06-04 → Hybrid**：GSM floor `{WORKOUT_ACTIVE,COMBAT_ACTIVE,BOSS_ENCOUNTER}` = 憲法強制鎖（phase 唔可 override）；WST `SET_ACTIVE` = refinement layer（只可收緊）。Contract 13「derive from GSM current_state」= GSM floor 係 primary 層。詳見 Rule 3 + Formula 1。

---

## Overview

Attention Budget & Interaction Policy（#33）係 Mirror Hero 嘅 **Pillar 2（無壓力陪伴 / Frictionless Companion）憲法執行層**。佢係一個 autoload service（`AttentionBudget`，boot pos 11+），對外只暴露一個極窄嘅 read-only API：`is_input_permitted() -> bool`（透過 ADR-0006 Contract 13 嘅 `IInputPolicy` interface，由 input handler 經 constructor 注入；handler 永不直接 reference 呢個 autoload）。佢嘅唯一職責 = 喺玩家 **workout session 或 combat 期間**（GSM floor `{WORKOUT_ACTIVE,COMBAT_ACTIVE,BOSS_ENCOUNTER}` 憲法鎖）以及**正在做緊一 set**（WST `SET_ACTIVE` phase refinement 收緊），保證 game **完全唔會要求、消費或打斷玩家任何注意力**：HUD tap early-return、required modal 唔彈、non-critical notification 全部 suppress。

Policy 係**純 pull-based Hybrid derivation** —— 每次 query 都即時由 live `GameStateMachine.get_current_state()`（#1）+ `WorkoutStateTracker.get_current_phase()`（#9）兩層計出：**GSM floor 係憲法強制鎖**（phase 唔可 override）；**WST phase 係 refinement**（只可收緊，唔可放鬆）。**唔保存任何 cached gate state**，所以 phone-lock / app-switch resume 之後自動回到正確 gate（冇 stale lock 阻住「set 完一 tap 落一個動作」，亦冇 stale open 容許 mid-set 打斷）。實作細節（IInputPolicy interface contract、boot position、subscription helper）由 ADR-0006 Contract 13 / 4 / 6 規範。系統本身唔擁有任何 UI；佢係其他所有 input / notification / modal 系統都必須遵守嘅 constitutional NO。

## Player Fantasy

#33 係玩家**永遠唔會直接察覺**嘅系統 —— 佢嘅成功指標就係「冇感覺」。玩家嘅 fantasy 唔係「我用緊一個 attention policy」，而係：

> 「我喺度狂谷最後幾 rep，個世界冇任何嘢叫我撳掣、冇 pop-up、冇『連續訓練 7 日！』嘅 nag。當我放低 barbell、抖緊氣嗰陣，先輕輕一 tap 落一個動作。部機由始至終都係我嘅**沉默拍檔**，唔係另一個 fitness app 喺度扮 coach 嘈我。」

呢個對應 game-pillars **Pillar 2「無壓力陪伴」**嘅核心承諾：game 喺 workout 期間係 **companion 唔係主角**。玩家係**間接**體驗呢個系統嘅 —— 佢哋感受到嘅唔係 #33 本身，而係 #33 所**保護出嚟嘅「不被打擾」狀態**。

**Anti-fantasy（必須杜絕）= 「The Nag Engine」**：任何 mid-set 嘅 required interaction、彈窗、震動、計時催促，都會即刻將「陪伴」變成「打擾」，直接謀殺 Pillar 2。所以 #33 唔係一個「幾時 nag 先啱」嘅 scheduler，而係一條「mid-set 乜都唔准」嘅 constitutional law —— 佢嘅預設答案永遠係 constitutional NO。

## Detailed Design

### Core Rules

**Rule 1 — Single source of permission（`is_input_permitted`）**
所有 in-session input handler（#20 HUD tap、#21 loot modal、任何 gameplay-facing interactive element）必須喺消費 input 之前 query 一個 injected `IInputPolicy.is_input_permitted()`，`false` 時 early-return（唔消費、唔產生 side-effect）。Handler **唔可** direct reference `AttentionBudget` autoload 或 `AttentionBudgetPolicy` concrete class —— 只可透過 constructor-injected `IInputPolicy`（ADR-0006 C13；保證 testability via `MockInputPolicy`）。Enforcement 喺 **input-handler boundary**，唔喺 state-machine boundary。

**Injection seam spec（B-B1/B2）**：`AttentionBudgetPolicy._init(gsm_ref, wst_ref)` — 兩個 ref **untyped**（typed Node = GDScript compile-fail，GDScript DI seam rule）。autoload 提供 `AttentionBudget.create_policy() -> IInputPolicy` factory 供 handler 構造時呼叫。**`IInputPolicy` interface 包含兩個 pure pull method**：`is_input_permitted() -> bool` + `is_notification_permitted() -> bool`（兩個未 override 都 push_error；MockInputPolicy 各有獨立 stub 值）。

**Rule 2 — Pure pull-based derivation（no cached gate）**
`is_input_permitted()` 係 stateless pure function，每次 call 即時讀 live `GameStateMachine.get_current_state()` + `WorkoutStateTracker.get_current_phase()` 計出（見 Formula 1），**唔保存任何 gate state**。呢個係 hard-contract #4（phone-lock recovery）嘅**架構性保證**：suspend / resume 之後冇 stale gate 可以殘留，唔需要任何 reset logic。

**Rule 3 — Hybrid permission 模型（GSM floor + WST refinement）**
`is_input_permitted()` 採用兩層 Hybrid 架構（對齊 GSM GDD AC-15a + 現存 stub `INPUT_BLOCKED_STATES`；CD 裁 2026-06-04）：

- **GSM floor（憲法強制鎖）**：`gsm_state ∈ {WORKOUT_ACTIVE, COMBAT_ACTIVE, BOSS_ENCOUNTER}` 時，`is_input_permitted()` 必返 `false`，**WST phase 唔可 override**（Pillar 2 憲法；game 係 companion ≠ 主角；combat / boss 期間自動玩）。`WORKOUT_ACTIVE` 係全段 workout session 的 GSM state（包括 inter-set 等待），**唔係** REST_PERIOD GSM state（set 完後 GSM 轉 REST_PERIOD，彼時 floor 不命中 → 一 tap window 開放）。
- **WST refinement（只可收緊）**：`wst_phase == SET_ACTIVE` 時，在 GSM floor 基礎上**額外收緊** → `false`，即使 GSM 係非 floor state 亦 lock（EC-3 defense-in-depth：GSM/WST 不一致邊界保護）。
- **Rule 3b — Ceremony lock（`LOOT_DROP`，對齊 GSM AC-11b）**：`gsm_state == LOOT_DROP` 時 `is_input_permitted()` 返 `false`。理由 = loot reveal ceremony 期間，**周邊（#20 HUD 等 surroundings）唔可消費 tap**；唯一合法 input = #21 loot modal 自己嗰個 dismiss tap，佢用同 **Rule 6 unlock 一樣嘅 exempt pattern**（#21 modal handler 唔注入 gating policy / 注入 always-permitted policy）拎到 tap。GSM AC-11b（locked，tested `test_rule7_no_mid_set_input.gd`）明文：「`is_input_permitted()` 返 `false` … modal is the input, not the surroundings」；GSM 狀態表 LootDrop「input-required, single tap」嘅 single tap 正正係指 modal 自己嗰個 exempt tap。若 #33 喺 LOOT_DROP 開 gate，#20 AC-CR-5 input gate 會喺 ceremony 期間放行背景 HUD tap → 偷咗 loot tap，正係 AC-11b 要堵嘅漏洞。
- **廢棄「phase 壓倒 state」**：SET_ACTIVE 唔係唯一 cardinal lock（上版語意）；GSM floor 同等憲法效力。hard-contract #1「max 0 player interaction per SET_ACTIVE」由 Hybrid 保證（SET_ACTIVE ∈ refinement layer 永遠 lock；WORKOUT_ACTIVE 更由 floor 鎖住整段 session）。

**Rule 4 — Lifecycle safety gate**
當 `GameStateMachine.get_current_state() ∈ {BOOTING, SUSPENDED}`，`is_input_permitted()` 返 `false`（系統未 ready 或 reconciling 中，唔消費 input 防 race）。

**Rule 5 — Default-open（保住 Pillar 2 唯一輸入）**
除咗 Rule 3（Hybrid floor/refinement）+ Rule 4 命中嘅情況，`is_input_permitted()` 返 `true`。Pillar 2 嘅「玩家唯一輸入」（set 完 → 一 tap 落一個動作）發生喺 **`REST_PERIOD` GSM state**（set 完後 GSM 轉離 WORKOUT_ACTIVE floor，一 tap window 開放），必須永遠 permitted。**Default-open GSM states**：`IDLE` / `REST_PERIOD`（GSM state）/ `DISCONNECTED` —— 均非 GSM floor、非 ceremony-locked、非 lifecycle-locked，且 WST phase ≠ `SET_ACTIVE`。**注意**：`COMBAT_ACTIVE` / `BOSS_ENCOUNTER` / `WORKOUT_ACTIVE` 已在 GSM floor（Rule 3）；`LOOT_DROP` 在 ceremony lock（Rule 3b）→ 呢幾個 state 唔屬 default-open 分支（AC-03 覆蓋範圍更新）。

**Rule 6 — Unlock gesture exemption（解決 #20 AC-EC-S5）**
silent-mode audio-unlock banner tap（#20 EG-2 soft-gate bootstrap gesture）**唔受 IInputPolicy 管轄**。佢係令 session 開始 counting 嘅 bootstrap gesture；若 gate 佢就會 deadlock（未 unlock → 計唔到 phase → 永遠當 gate）。Exemption 喺 handler 層實現：unlock-banner handler **唔注入** gating policy（或注入 always-permitted policy）。**GDD binding：unlock gesture 永不 gated**，正式取代 #20 現用嘅 fallback AC-EC-S5。

**Rule 7 — Notification suppression**
`AttentionBudget` autoload 額外暴露 `is_notification_permitted() -> bool`（見 Formula 2）：phase == `SET_ACTIVE` 或 GSM ∈ {BOOTING, SUSPENDED, LOOT_DROP} 時返 `false`。任何 **non-critical** notification producer（#8 streak nag、coach tip、loot badge toast）必須 query 呢個先 fire。被 suppress 嘅 notification **直接 DROP，唔 queue**（queued nag = 延遲嘅打擾，等於 The Nag Engine）；需要「workout 後先顯示」嘅 producer 自己 own 延遲邏輯（例如 #8 milestone 喺 `WORKOUT_COMPLETE` 自行重發）。**Critical** safety / data-loss notification（disconnect 警告、save 失敗）**唔受 Rule 7 管**（見 EC-12）——但必須喺 **`CRITICAL_NOTIFICATION_KINDS` closed allowlist** 登記。

**CRITICAL_NOTIFICATION_KINDS closed allowlist（B-C1）**：`AttentionBudget` autoload 維護 `CRITICAL_NOTIFICATION_KINDS: Array[StringName]`（明文列舉，closed，唔係 open-ended）。`AttentionBudget.is_critical_notification(kind: StringName) -> bool` = `kind ∈ CRITICAL_NOTIFICATION_KINDS`。未登記嘅 kind 唔可用 critical bypass — 嘗試 bypass 但 `is_critical_notification()` 返 `false` 嘅 producer 視為 policy violation。**CI static check**：任何 non-critical notification producer **禁** raw fire notification 而不先 query `is_notification_permitted()` 或 `is_critical_notification(kind)`（grep ban；AC-18）。

**Rule 8 — Glance budget ceiling（cross-system policy 上限）**
#33 定義 cross-system 上限常數 `GLANCE_BUDGET_CEILING_MS = 2000`：任何 in-session UI element 嘅 single-glance attention demand 唔可超過 2 秒（#20 HUD 自己 own 更嚴嘅 0.3s 餘光；呢個 ceiling 係畀**所有** in-session element 嘅 hard cap）。Enforcement = design-time AC + playtest（tachistoscope / observed glance），**非** per-frame runtime gate；提供 debug-build `assert_glance_within_budget(element_id, measured_ms)` 畀 instrumented playtest 用（release build no-op）。

**Rule 9 — `connect_for_initial_state` subscription**
autoload `_ready()` subscription **分兩路**：**#1 `state_changed`** 用 `connect_for_initial_state(callable)`（ADR-0006 Contract 6，保証 initial state callback）；**#9 `phase_changed`** 用 **plain `.connect`**（WST 冇 `connect_for_initial_state` helper —— GSM 專有；`phase_changed(from, to)` = 2-arg 無 payload，與 Contract 6 3-arg+payload 不相容）。Subscription 嘅用途 = 驅動 notification-suppression 邊界偵測（Rule 7 邊緣觸發 DROP 決定）；**唔影響** `is_input_permitted()` 嘅 pure-pull derivation（Rule 2）—— 即使 subscription 從未 fire，derivation 一樣正確。`input_policy_changed` affordance signal **cut from v1 scope**（B-E3；狀態機複雜度 > 收益；v2 可 consider）。

**Rule 10 — Stub migration（implementation gate）**
現存 `src/systems/attention_budget_policy.gd`（Story 015，#20 epic）用 **靜態 autoload call + `INPUT_BLOCKED_STATES: Array` array**（pure GSM-state-driven，冇 injection seam）。**#33 epic 第一個 story 必須 rewrite 此 stub**：(a) 替換 static autoload call → `_init(gsm_ref, wst_ref)` untyped ctor injection；(b) `INPUT_BLOCKED_STATES` → Hybrid derivation（Formula 1）；(c) 廢除/更新依賴 `INPUT_BLOCKED_STATES` 舊行為嘅 tests（唔可保留覆蓋舊 pure-GSM-state 路徑嘅 test）。**未 rewrite 前唔可 mark any story Complete。**

### States and Transitions

呢個系統**本質 stateless**（Rule 2 pure derivation），但 autoload 同其他 Foundation autoload 一樣有 lifecycle substate：

```gdscript
enum Substate { INITIALISING, READY }
```

| Substate | 進入條件 | `is_input_permitted()` 行為 | 離開條件 |
|---|---|---|---|
| **INITIALISING** | autoload `_ready()` | GSM 通常 == `BOOTING` → Rule 4 返 `false`（fail-closed safe） | subscribe #1 `state_changed` via `connect_for_initial_state` + #9 `phase_changed` via plain `.connect` → seed notification-suppression edge tracking → READY |
| **READY** | INITIALISING 完成 | 正常 live derivation（Formula 1 / 2） | （終態；冇 SUSPENDED substate） |

**冇 SUSPENDED substate** —— #33 唔 cache 任何嘢，所以唔需要 suspend / restore（對比 #9 WST 有 SUSPENDED 因為佢 cache workout data）。GSM `SUSPENDED` state 由 Rule 4 喺 derivation 層直接處理。

**Derived gate（唔係 stored state，係每次 query 計出嘅概念）**：

| GSM `current_state` | WST `phase` | `is_input_permitted()` | `is_notification_permitted()` | 規則 |
|---|---|---|---|---|
| `WORKOUT_ACTIVE` | 任意 | **false** | **false** | Rule 3（GSM floor）/ Rule 7 |
| `COMBAT_ACTIVE` | 任意 | **false** | **false** | Rule 3（GSM floor）/ Rule 7 |
| `BOSS_ENCOUNTER` | 任意 | **false** | **false** | Rule 3（GSM floor）/ Rule 7 |
| `BOOTING` | 任意 | **false** | **false** | Rule 4 / 7 |
| `SUSPENDED` | 任意 | **false** | **false** | Rule 4 / 7 |
| 任意非 floor 非 lifecycle | `SET_ACTIVE` | **false** | **false** | Rule 3（WST refinement / EC-3 defense）/ Rule 7 |
| `LOOT_DROP` | ≠`SET_ACTIVE` | **false** | **false** | Rule 3b（ceremony lock：周邊鎖住，loot modal dismiss tap 由 #21 exempt handler 處理；對齊 GSM AC-11b）/ 7（suppress ceremony toast）|
| `IDLE`/`REST_PERIOD`（GSM）/`DISCONNECTED` | `IDLE`/`WARM_UP`/`REST_PERIOD`/`WORKOUT_COMPLETE` | true | true | Rule 5（`WORKOUT_COMPLETE` 係 WST phase，**唔係 GSM state** — 唔可寫 `GameState.WORKOUT_COMPLETE`，compile error）|

> 注：GSM floor 行（Rule 3）**無視 WST phase** —— floor 喺 derivation 最高優先評估（phase 唔可推翻）。`REST_PERIOD` GSM state（玩家 set 完休息）不在 floor → default-open → 一 tap window 開放。

### Interactions with Other Systems

| 系統 | 方向 | Hard/Soft | Interface | Owner |
|---|---|---|---|---|
| **#1 GameStateMachine** | IN（upstream）| Hard | pull `get_current_state()` + push `state_changed(from,to,payload)` | GSM 係 `current_state` 真相源；#33 read-only consumer |
| **#9 WorkoutStateTracker** | IN（upstream）| Hard | pull `get_current_phase()` + push `phase_changed(from,to)` | `SET_ACTIVE` phase = strict gate window；#33 read-only consumer |
| **#20 Gym-Mode HUD** | OUT（downstream）| Hard | inject `IInputPolicy`；tap handler honor `is_input_permitted()`（#20 AC-CR-5）；unlock banner handler exempt（Rule 6）| #20 own「honoring」；#33 own「permission predicate」|
| **#21 Loot Drop Modal** | OUT（downstream）| Soft | `LOOT_DROP` state `is_input_permitted()==false`（ceremony lock，Rule 3b）；loot modal dismiss tap 用 **exempt handler**（唔注入 gating policy / 注入 always-permitted，同 Rule 6 unlock 同 pattern）拎到 tap；周邊 HUD tap 被鎖（防偷 loot tap）；mid-set 永不 `LOOT_DROP`（GSM transition 保證，參 GSM state-transition table）。⚠️ **Cross-system constraint flag（game-designer P3 #1）**：Rule 3b 假設 loot ceremony 只喺 REST_PERIOD / WORKOUT_COMPLETE boundary 觸發；若 #21 ceremony 喺玩家預期外嘅時機彈出，`is_input_permitted()==false` 嘅 lock 感覺同「冇 pop-up」嘅 Pillar 2 fantasy 衝突（ceremony = 另一個要求你注意嘅 modal）。**#21 GDD authoring 時必須 define ceremony timing constraint：loot reveal 只可喺 GSM LOOT_DROP state + 唔係玩家 active set 期間觸發。** #33 嘅 policy 係正確的；loot ceremony 嘅 disruption risk 在 #21 嘅 timing 設計。| #21 |
| **Notification producers**（#8 streak / coach tips / toasts）| OUT（downstream）| Soft | query `is_notification_permitted()` 先 fire | producer own 自己嘅 defer 邏輯 |

**Ownership boundary**：#33 owns **permission predicate**（`is_input_permitted` / `is_notification_permitted`）；consumer owns **honoring** 佢。Enforcement at **input-handler boundary**（ADR-0006 C13），唔喺 state-machine boundary —— GSM / WST 只係 read-only 真相源，唔識 #33 存在。

**Bidirectional consistency**：#33 只**讀** #1 / #9 嘅 already-public API（`get_current_state` / `get_current_phase` / `state_changed` / `phase_changed`），**唔需要 patch 上游 GDD**（consumer-forward-contract principle —— 已 merged 嘅 data-layer GDD 唔因為新 consumer 而改）。#20 GDD 已列 #33 為 AC-CR-5 嘅 provider，bidirectionality 已滿足。

## Formulas

呢個系統以 boolean predicate 為主，無連續數值 scaling。三條 predicate / constant：

### Formula 1 — `is_input_permitted` derivation

```
is_input_permitted() =
    # Null guard — highest precedence（fail-closed；B-B3：防 fail-OPEN）
    IF (gsm_ref == null OR wst_ref == null):
        RETURN false                                                     # null → unconditional fail-closed（FAIL_CLOSED_ON_NULL_DEP 係 const true，唔係 knob；見 Constitutional constants）
    # Sentinel guard — unknown enum → fail-closed（B1 Pillar 2 constitutional NO）
    IF gsm_state NOT IN KNOWN_GSM_STATES OR wst_phase NOT IN KNOWN_WST_PHASES:
        RETURN false                                                     # 未知 int 值唔屬 KNOWN_GSM_STATES → fail-OPEN 直接違反 Pillar 2；sentinel 堵呢個漏口
    # Hybrid derivation（全部 lock set 由 named constant 引用，唔字面 hardcode；見 Constitutional constants）
    NOT ( gsm_state ∈ GSM_FLOOR_LOCKED_STATES                          # Rule 3：GSM floor（憲法強制鎖；={WORKOUT_ACTIVE,COMBAT_ACTIVE,BOSS_ENCOUNTER}，= stub INPUT_BLOCKED_STATES）
          OR gsm_state ∈ CEREMONY_LOCKED_STATES                        # Rule 3b：ceremony lock（={LOOT_DROP}；周邊鎖，loot modal dismiss tap exempt；對齊 locked GSM AC-11b）
          OR gsm_state ∈ LIFECYCLE_LOCKED_STATES                       # Rule 4：={BOOTING,SUSPENDED}（未 ready / reconciling）
          OR wst_phase ∈ INPUT_LOCKED_PHASES )                         # Rule 3：WST refinement（={SET_ACTIVE}，只可收緊）
```

**Variables:**
| Variable | Type | Range | Description |
|---|---|---|---|
| `gsm_ref` | Node ref（untyped）| non-null（normally）| GameStateMachine autoload ref；null → fail-closed（EC-2）|
| `wst_ref` | Node ref（untyped）| non-null（normally）| WorkoutStateTracker autoload ref；null → fail-closed（EC-2）|
| `gsm_state` | `GameState` enum | {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED} | live `GameStateMachine.get_current_state()`（#1，pull）|
| `wst_phase` | `WorkoutPhase` enum | {IDLE, WARM_UP, SET_ACTIVE, REST_PERIOD, WORKOUT_COMPLETE} | live `WorkoutStateTracker.get_current_phase()`（#9，pull）|

**Output Range:** `bool`（`true` = 容許互動 / `false` = lock）。fail-closed：若任一 dependency ref 為 null → **無條件** 返 `false`（`FAIL_CLOSED_ON_NULL_DEP` 係 `const true`，唔係 runtime knob；EC-2；null → method call crash，唔係「safe fail-open」，見 H3 fix）。
**Example A:** `gsm_state = BOSS_ENCOUNTER`, `wst_phase = REST_PERIOD` → null guard pass → `NOT(true OR false OR false OR false)` = **`false`**（boss 戰 GSM floor 鎖，即使係 REST_PERIOD phase）。
**Example B:** `gsm_state = REST_PERIOD`（GSM state）, `wst_phase = REST_PERIOD` → `NOT(false OR false OR false OR false)` = **`true`**（set 完抖氣 → 一 tap window 開放）。
**Example C:** `gsm_state = IDLE`（edge case）, `wst_phase = SET_ACTIVE` → null guard pass → sentinel pass（IDLE / SET_ACTIVE 均 IN KNOWN sets）→ `NOT(false OR false OR false OR true)` = **`false`**（WST refinement defense-in-depth；4 terms，同 Formula terms 數量一致）。
**Example D:** `gsm_state = LOOT_DROP`, `wst_phase = WORKOUT_COMPLETE` → `NOT(false OR true OR …)` = **`false`**（ceremony lock：周邊唔收 tap，loot modal dismiss tap 由 #21 handler exempt 處理；對齊 GSM AC-11b「modal is the input, not the surroundings」）。

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
**Example:** `gsm_state = LOOT_DROP`, `wst_phase = WORKOUT_COMPLETE` → `is_input_permitted() = false`（ceremony lock Rule 3b）且 `is_notification_permitted() = false`（LOOT_DROP suppression）。
**⚠️ 注意 B2 fix**：`LOOT_DROP` 令兩個 example 都係 false — 之前文字寫「is_input_permitted() = true」係錯誤（已由 Rule 3b ceremony lock fix）。
**H1 — WORKOUT_COMPLETE notification permit（intentional，已文件化）**：GSM `WORKOUT_COMPLETE` **唔係** GSM state（B2 fix）。WST `WORKOUT_COMPLETE` phase 時 `is_notification_permitted()` 返 `true`（唔在 suppressed set）—— **刻意設計**：workout 完結係 milestone notification window，`#8 streak milestone` 等 deferred producer 正是喺 `WORKOUT_COMPLETE` 重發（EC-8 / Rule 7 cite 佢）。任何人將 `WORKOUT_COMPLETE`（WST phase）加入 `NOTIFICATION_SUPPRESSED_STATES` tuning knob 會靜默封死 deferred-milestone 路徑，冇 AC 抓到 —— **加之前必須 design review。**

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
- **EC-3 — GSM 同 WST 唔一致**（GSM == `IDLE` 但 WST phase == `SET_ACTIVE`）：WST refinement 額外收緊（Rule 3）→ `false`。永遠 fail 去保護嗰邊（defense-in-depth；非「phase 壓倒 state」舊語意，floor 同 refinement 各自獨立收緊）。
- **EC-4 — 同一 frame 內 `state_changed` + `phase_changed` 同時到**：pure-pull 讀最終值，`is_input_permitted()` 唔會 expose 中間 flicker（synchronous）。`input_policy_changed` affordance signal **cut from v1 scope**（Rule 9；若 v2 reintroduce，consumer handler 必須 idempotent，因可能 emit 兩次）。
- **EC-5 — unlock gesture 喺 SET_ACTIVE 期間發生**：exempt（Rule 6），unlock handler 唔 gated → unlock 照行。（注：soft-gate 下 counting 喺 unlock 後先開始，所以 pre-unlock 通常停喺 IDLE/WARM_UP；若 pre-unlock 有 stray `set_logged`，由 #9 + #20 處理；#33 嘅 binding 只係：unlock 永不 gated。）
- **EC-6 — phone-lock mid-set**：GSM → `SUSPENDED` → `false`（Rule 4）。resume 後 GSM 還原（例如返 `COMBAT_ACTIVE`），WST 由 snapshot reconcile phase。`is_input_permitted()` 即時重新 derive → 正確，**冇 stale lock**（Rule 2 架構保證）。
- **EC-7 — resume 後落喺 reconciled `SET_ACTIVE`**：WST reconcile 到 last-known phase 若係 `SET_ACTIVE`，#33 honor 之 → 維持 lock 直到真 `rest_started` / 下個 `set_logged` 更新 #9 phase。#33 唔自行判斷 phase，只 honor #9。
- **EC-8 — notification 啱啱喺 `SET_ACTIVE` entry fire**：producer 喺 fire-time query `is_notification_permitted()` → `false` → **DROP（唔 queue）**。延遲嘅 nag = The Nag Engine，禁止。需要「workout 後顯示」嘅 producer 自行喺 `WORKOUT_COMPLETE` 重發。
- **EC-9 — glance element playtest 量度 >2000ms**：AC fail（design 必須收窄），**唔係** runtime block。debug build `assert_glance_within_budget` push_error；release build no-op。
- **EC-10 — HUD 每 frame query `is_input_permitted()`（hot path）**：必須 O(1) cheap（兩個 enum read + 比較），零 allocation。見 perf AC-17。
- **EC-11 — 多個 `IInputPolicy` instance 注入唔同 handler**：全部由同一個 global GSM/WST derive → 結果一致，冇 divergence（stateless，shared flyweight 或 per-handler 皆可）。
- **EC-12 — Critical notification 喺 SET_ACTIVE**（disconnect 警告 / save 失敗）：**唔受 Rule 7 管** —— critical safety/data-loss notification 直接 fire（資料完整性 > Pillar 2 不打擾）。producer 用獨立 critical channel，唔 query `is_notification_permitted()`。
- **EC-13 — `DISCONNECTED` state + pending tap**：`is_input_permitted()` 返 `true`（容許玩家撳 reconnect affordance）；#33 唔 gate disconnect/login UI（嗰個係 #24 domain）。
- **EC-16 — unknown / out-of-range GSM enum int**（B1 sentinel）：future GSM state 加入但 #33 未 sync `KNOWN_GSM_STATES` → sentinel guard → `false`（fail-closed）。實作者每次新增 `GameState` enum value 必須 check `KNOWN_GSM_STATES` 是否需更新。Pillar 2 constitutional fail-closed：寧願 over-gate 過 stale-enum-fail-open。
- **EC-17 — `FAIL_CLOSED_ON_NULL_DEP` 若係 var 被 mutate to false**（CRITICAL-4 防範）：憲法上禁止（`const`，唔可 mutate）。任何嘗試 mutate 係 code smell = 直接 Pillar 2 breach。若發現有人嘗試改，升 design review。
- **EC-14 — 快速 `SET_ACTIVE ↔ REST_PERIOD` 震盪**（玩家重新握 bar）：每次都係 fresh derivation，#33 唔做 debounce（phase 穩定性係 #9 嘅責任）；#33 純 honor #9 當前 phase。
- **EC-15 — loot modal dismiss tap 喺 `LOOT_DROP`**（ceremony lock，Rule 3b）：`is_input_permitted()` 返 `false`（周邊 #20 HUD tap 被鎖，唔偷 loot tap）。#21 loot modal dismiss tap **唔經本 predicate** —— modal handler 用 exempt pattern（唔注入 gating policy，同 Rule 6 unlock 同源），所以照收 dismiss tap → 玩家 tap → GSM 離開 `LOOT_DROP` → `IDLE`。對齊 GSM AC-11b「modal is the input, not the surroundings」。

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
| ~~`FAIL_CLOSED_ON_NULL_DEP`~~ | ~~removed from Tuning Knobs~~ | — | **已移至 Constitutional constants（`const true`，唔係 knob）**。Runtime-mutable `var` = Pillar 2 breach；`false` 嘅後果係 crash（`_gsm.get_current_state()` null method call），唔係「safe fail-open」—— 舊描述錯誤（H3）。|
| `CRITICAL_NOTIFICATION_KINDS` | `["disconnect_warning", "save_failed"]` | closed Array[StringName] | critical bypass 許可種類（B-C1；closed allowlist，唔係 open-ended）| 加入非 critical kinds = The Nag Engine leak 口 | 過窄 = data-loss notification 無法 fire |

### Constitutional constants（非自由 tuning —— 改動需經 design review，唔可隨手調）

| Constant | Value | Rationale |
|---|---|---|
| `KNOWN_GSM_STATES` | `{BOOTING,DISCONNECTED,IDLE,WORKOUT_ACTIVE,REST_PERIOD,COMBAT_ACTIVE,BOSS_ENCOUNTER,LOOT_DROP,SUSPENDED}` | B1 sentinel：Formula 1 guard 用。未知 gsm int（未來新 state / enum cast error）唔命中任何 lock set 會 fail-OPEN → Pillar 2 breach。sentinel 堵呢個漏口。必須同 `GameState` enum 保持同步（唔係 dynamic — impl-time 加 const）。|
| `KNOWN_WST_PHASES` | `{IDLE,WARM_UP,SET_ACTIVE,REST_PERIOD,WORKOUT_COMPLETE}` | B1 sentinel（同上，WST phase side）。必須同 `WorkoutPhase` enum 保持同步。|
| `FAIL_CLOSED_ON_NULL_DEP` | `const true`（immutable）| null guard（EC-2）：dependency ref null → `return false`。必須係 `const`，唔可係 `var` / exported —— runtime mutation = Pillar 2 constitutional breach。`false` 嘅後果係 null method call crash，唔係「safe fail-open」。唔係 tuning knob。|
| `GSM_FLOOR_LOCKED_STATES` | `{WORKOUT_ACTIVE, COMBAT_ACTIVE, BOSS_ENCOUNTER}` | Rule 3 憲法強制鎖（= 現存 stub `INPUT_BLOCKED_STATES`，對齊 GSM AC-15a）。data-driven set，Formula 1 引用（唔字面 hardcode）。加 state 會 over-lock；移除 = Pillar 2 floor 破洞。|
| `CEREMONY_LOCKED_STATES` | `{LOOT_DROP}` | Rule 3b ceremony lock（對齊 GSM AC-11b）。周邊鎖、modal exempt。Formula 1 引用。**Invariant（H2）**：`CEREMONY_LOCKED_STATES ⊆ NOTIFICATION_SUPPRESSED_STATES`（Formula 2 嘅 suppressed set）必須成立 —— ceremony-locked 喺 input 層鎖,亦應 suppress notification（唔讓 toast 蓋住 ceremony）。若調 knob 移走 CEREMONY state 出 NOTIFICATION_SUPPRESSED_STATES 而冇同步移 CEREMONY_LOCKED_STATES → input lock but notification open = 不一致。設計者修改任一 set 前需 verify 此 invariant。|
| `LIFECYCLE_LOCKED_STATES` | `{BOOTING, SUSPENDED}` | Rule 4 lifecycle safety gate（未 ready / reconciling）。Formula 1 引用。|
| `INPUT_LOCKED_PHASES` | `{SET_ACTIVE}` | mid-set lock window（WST refinement）。加 phase 會 over-lock（封死「一 tap 落動作」嘅 Pillar 2 唯一輸入）；移除 `SET_ACTIVE` = Pillar 2 死亡。|
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

- **AC-01a（Rule 3 GSM floor，BLOCKING）**：GIVEN GSM state ∈ {`WORKOUT_ACTIVE`, `COMBAT_ACTIVE`, `BOSS_ENCOUNTER`}，WHEN query `is_input_permitted()`，THEN 返 `false` —— 對 **所有** WST phase ∈ {`IDLE`, `WARM_UP`, `SET_ACTIVE`, `REST_PERIOD`, `WORKOUT_COMPLETE`} 成立（GSM floor 憲法鎖，phase 唔可 override；特別包含 `SET_ACTIVE` 閉合 double-lock cartesian —— floor 同 WST refinement 同時命中，兩層各自獨立返 false，互不依賴）。
- **AC-01b（Rule 3 WST refinement，BLOCKING）**：GIVEN GSM state ∉ floor ∉ lifecycle（例如 `IDLE`）AND WST phase == `SET_ACTIVE`，WHEN query `is_input_permitted()`，THEN 返 `false`（WST refinement defense-in-depth；EC-3 edge case）。
- **AC-02（Rule 4，BLOCKING）**：GIVEN GSM state == `SUSPENDED`（phase 任意非 SET_ACTIVE），WHEN query，THEN `false`；GSM == `BOOTING` 同樣返 `false`。
- **AC-03（Rule 5 default-open，BLOCKING）**：GIVEN GSM ∈ {`IDLE`, `REST_PERIOD`（GSM state）, `DISCONNECTED`} AND WST phase ∈ {`IDLE`, `WARM_UP`, `REST_PERIOD`, `WORKOUT_COMPLETE`}，WHEN query `is_input_permitted()`，THEN `true`。（GSM floor states `WORKOUT_ACTIVE`/`COMBAT_ACTIVE`/`BOSS_ENCOUNTER` 喺 AC-01a 覆蓋；`LOOT_DROP` 喺 AC-19（ceremony lock）覆蓋；均唔屬 default-open 分支。）
- **AC-19（Rule 3b ceremony lock，BLOCKING）**：GIVEN GSM state == `LOOT_DROP` AND WST phase ≠ `SET_ACTIVE`，WHEN query `is_input_permitted()`，THEN `false`（周邊鎖，對齊 locked GSM AC-11b；loot modal dismiss tap 屬 #21 exempt handler，唔經本 predicate）。
- **AC-04（Rule 2 pure-pull，BLOCKING）**：GIVEN 兩次 query 之間直接 mutate mock GSM/WST 值（**唔送任何 signal 畀 #33**），WHEN 第二次 query，THEN 反映新值（證明無 cache）。
- **AC-05（Rule 1 injection，BLOCKING — Integration）**：GIVEN handler 用 `MockInputPolicy(permitted=false)` 構造，WHEN handler 收到 tap，THEN tap early-return（唔消費、無 side-effect）。
- **AC-06（Rule 6 exemption，Integration — #20 scope）**：unlock-banner handler exemption 喺 #33 內部唔可單獨驗證（handler 屬 #20 scope）。呢條 AC 移到 #20 epic story：GIVEN WST phase == `SET_ACTIVE`，WHEN unlock-banner handler 收到 tap，THEN 照行（handler 唔注入 gating policy 或注入 always-permitted policy）。#33 内部唔出此條 AC；binding 喺 Rule 6 明文（unlock 永不 gated），#20 story 負責 Integration 驗證。
- **AC-07（Rule 7，BLOCKING）**：GIVEN phase == `SET_ACTIVE`，WHEN query `is_notification_permitted()`，THEN `false`。
- **AC-08（Rule 7，BLOCKING）**：GIVEN phase == `REST_PERIOD` AND GSM ∉ suppressed set，WHEN query `is_notification_permitted()`，THEN `true`。
- **AC-09（EC-3 disagree，BLOCKING）**：GIVEN GSM == `IDLE` AND phase == `SET_ACTIVE`，WHEN query `is_input_permitted()`，THEN `false`（WST refinement 收緊；= AC-01b 嘅 `IDLE` 具體 instance，覆蓋 EC-3 GSM/WST 不一致邊界）。
- **AC-10（EC-2 fail-closed，BLOCKING）**：GIVEN injected GSM ref == null，WHEN query `is_input_permitted()`，THEN `false`（null guard 無條件 fail-closed；`FAIL_CLOSED_ON_NULL_DEP` 係 `const true`，唔係 conditional knob；null ref → unconditional early-return false，唔繼續到 derivation 避免 null method call crash）。Edge：WST ref == null 同樣 → false。
- **AC-11（EC-6 recovery，BLOCKING — Integration）**：GIVEN suspend mid-set（GSM `SUSPENDED`）後 GSM 還原到 **non-floor state** `REST_PERIOD`（玩家 suspend 期間 set 已結束）且 WST reconcile phase == `REST_PERIOD`，WHEN query，THEN `true`（無 stale lock —— suspend 期間嘅 lock 完全冇殘留，gate 即時反映 resume 後真值）。**注**：若 resume 還原到 floor state（如 `COMBAT_ACTIVE`），derivation 正確返 `false`（floor 鎖，companion 自動玩 combat）—— 呢個唔係 stale lock，係當前真值；AC-11 用 non-floor resume state 先能分辨「無 stale lock」vs「floor 當前鎖」。
- **AC-12（Rule 9 boot，BLOCKING — Integration/static）**：GIVEN autoload `_ready()`，THEN (a) #1 `state_changed` 透過 `connect_for_initial_state` subscribe（assert initial callback fired）；(b) #9 `phase_changed` 透過 plain `.connect` subscribe（WST 冇 `connect_for_initial_state`）。**CI static check（pin 精確 pattern 防 over-broad lint 重演 main-RED 前科）**：ban regex = `state_changed\s*\.\s*connect\s*\(`（即 `state_changed.connect(` plain 訂閱形式，**帶括號** `\(` 以區分合法嘅 `.connect_for_initial_state(`，後者無 `.connect(` 形式故唔 match）。pattern 錨定 `state_changed` signal，**唔 match** `phase_changed.connect(`（#33 合法 plain connect）。⚠️ **GSM owner-exempt 必須**：`src/autoload/game_state_machine.gd` 內部喺 `connect_for_initial_state()` helper 有一行 `state_changed.connect(callable)`（own seam，合法用法），ban regex **會 match 佢**（substring 比對）→ **冇 owner-exempt = main RED on day one**（同 PR #12 debug_override lint 教訓完全一樣；gateway-lints must exempt the owner that defines the seam）。CI check 須加 `--iglob '!src/autoload/game_state_machine.gd'` 或等效 owner-exempt。GDD 之前「唔需要 file-level 豁免清單」嘅斷言係錯嘅 — 修正。
- **AC-13（Formula 3 boundary，BLOCKING）**：GIVEN `GLANCE_BUDGET_CEILING_MS == 2000`，WHEN `glance_within_budget(2001)` THEN `false`；`glance_within_budget(2000)` THEN `true`。
- **AC-14（Rule 9 derivation independence，BLOCKING）**：GIVEN `state_changed` / `phase_changed` 從未 deliver（subscription 斷開）AND mock live 值 == `SET_ACTIVE`，WHEN query `is_input_permitted()`，THEN `false`（證明 derivation 獨立於 subscription）。
- **AC-15（EC-8 drop-not-queue，REMOVED from #33 → BLOCKED-deferred #8/#28 BLOCKING）**：drop-vs-queue 係 producer 嘅行為，唔係 #33 predicates 嘅行為。#33 side 嘅 predicate 返 `false` 已由 AC-07 覆蓋；「mock producer 無 re-emission callback」測嘅係 producer side，#33 唔擁有。**#33 epic 唔出此 AC**。真正嘅 drop-not-queue Integration AC（BLOCKING）喺 **#8 Streak / #28 Telemetry producer epic** 開：「GIVEN producer query is_notification_permitted() = false，WHEN suppressed，THEN 無 notification 被 queue / schedule，producer DROP 嗰個 event」。如此 deferred 確保 Pillar 2 hard-contract #3 喺 producer 層真正 gate，而唔係喺 #33 側以 ADVISORY 假裝守咗。
- **AC-16（Substate，BLOCKING）**：GIVEN autoload 未 READY（GSM == `BOOTING`），WHEN query `is_input_permitted()`，THEN `false`。
- **AC-17a（perf 結構性，BLOCKING — Static）**：`is_input_permitted()` body **無 allocating 構造**（無 inline Array/Dictionary literal、無 `.new()`、無 string concat、無 closure capture）—— hot-path 每 frame 由 #20 HUD query（60fps × allocation = 持續 GC jank）。**O(k) small-constant linear scan**（`in` on `Array[int]` = O(n)，n≤4 sets each k≤9 elements；唔 alloc；喺 16.6ms frame budget 完全無問題，但 AC 唔聲稱 O(1) —— 若需真 O(1) 改用 `Dictionary` hashed lookup，現階段 overkill）。**code-inspection / CI static grep 可確定性驗證**（grep ban 以下 allocating 構造 喺 `is_input_permitted` method body：inline `\[`/`{` literal、`.new\(`、string `%`/`+` concat；named-method alloc 如 `.duplicate()`/`.map()` 呢幾類 grep 抓唔到，由 AC-17b runtime 補）。
- **AC-17b（perf runtime，ADVISORY）**：instrumented profiler run 量度每 call heap alloc ≈ 0（`Performance.get_monitor(MEMORY_STATIC)` baseline diff）。**降 ADVISORY**：headless GUT 嘅 monitor diff 受 GC / 旁路 alloc 噪音影響，唔可作 deterministic BLOCKING gate（避免不可達 binding gate，[[feedback_binding_gate_satisfiability]]）；BLOCKING 由 AC-17a 結構性 proxy 守。

- **AC-18a（CRITICAL_NOTIFICATION_KINDS const + method，BLOCKING — Unit）**：`CRITICAL_NOTIFICATION_KINDS: Array[StringName]` closed allowlist 存在；`AttentionBudget.is_critical_notification(kind: StringName) -> bool` 方法存在；`is_critical_notification(&"disconnect_warning")` → `true`；`is_critical_notification(&"unknown_kind")` → `false`；`is_critical_notification(&"")` → `false`。**#33 epic 實作** `CRITICAL_NOTIFICATION_KINDS` const + `is_critical_notification()` method（unit-testable in #33 story-003）。
- **AC-18b（producer compliance grep，ADVISORY — BLOCKED-deferred）**：CI static check：任何 non-critical notification producer（#8 streak nag、coach tip、toast）必須 query `is_notification_permitted()` 先 fire。Critical bypass 必須調用 `AttentionBudget.is_critical_notification(kind)` 且 kind ∈ `CRITICAL_NOTIFICATION_KINDS`；未登記 kind = policy violation。**BLOCKED-deferred to #8 Streak / #28 Telemetry**（producer 實作後方可 grep；#33 epic 唔開此 gate）。

- **AC-20（connect_for_initial_state callback arity，BLOCKING — Integration）**：GIVEN autoload `_ready()` calls `connect_for_initial_state(_on_gsm_state_changed)`，THEN callback `_on_gsm_state_changed` 接受 **exactly 3 args** `(from: int, to: int, payload)` 且**冇 `.bind()`** ——錯誤 arity（2-arg 或 `.bind()` extra-arg）= deferred off-stack runtime crash（ADR-0006 C6 callv arity；`workout_state_tracker.gd` `phase_changed` = 2-arg，**唔係** 3-arg，兩個 callback 唔好混淆）。**CI 靜態 check**：`connect_for_initial_state(*.bind(*))`pattern = error（Contract 6 CI rule；ADR-0006）。Test：mock GSM 呼叫 callv，assert 3-arg callback 收到正確 3 values。
- **AC-21（`_init` duck-typed guard，BLOCKING — Unit）**：`AttentionBudgetPolicy._init(gsm_ref, wst_ref)` 必須喺 construction 時做 duck-typed assertion：`assert(gsm_ref != null and gsm_ref.has_method(&"get_current_state"), "AttentionBudgetPolicy: gsm_ref missing get_current_state")`（同理 wst_ref + `get_current_phase`）。**理由**：untyped seam（GDScript DI seam rule）令錯誤 arg order / 錯誤 ref 唔喺 compile time 抓到，喺 Formula 1 query time 才 crash（null method call，off-stack，難 trace）。assert 將錯誤前移到 construction。Test：GIVEN wrong-type ref passed to _init；WHEN construct；THEN assert fires。

## Open Questions

- **Q-OQ1 — ADR-0008 AttentionBudget absolute autoload position**（Proposed → 需 ratification）。Owner: technical-director。本 GDD honor partial-order pos 11+（after GSM pos 2 + WST pos 5）；absolute position deferred to ADR-0008 ratification（insertion rule 已喺 ADR-0008 為 #33 記低）。
- **Q-OQ2 — `is_input_permitted` phase-vs-GSM reconcile** — **RESOLVED 2026-06-04（CD 裁 Hybrid）**：GSM floor `{WORKOUT_ACTIVE,COMBAT_ACTIVE,BOSS_ENCOUNTER}` = 憲法強制鎖（phase 唔可 override；對齊 GSM AC-15a + stub）；WST `SET_ACTIVE` = refinement（只可收緊）。Contract 13「derive from GSM current_state」= GSM 做 floor 層，唔係唯一層。詳見 Rule 3 / Formula 1。舊版「phase 壓倒 state」語意已廢棄。
- **Q-OQ3 — notification suppression = drop vs producer-owned re-eval** — 現 spec = **DROP**（EC-8 / AC-15）；需要「workout 後顯示」嘅 producer 自己 own deferral（例如 #8 streak milestone 喺 `WORKOUT_COMPLETE` 自行重發）。待 #8 / #28 authoring 時 confirm。
- **Q-OQ4 — `DISCONNECTED` state 嘅 gate** — 現 spec = default-open（容許 reconnect affordance；login/reconnect 係 #24 domain）。⚠️ **game-designer P3 #3 flag**：DISCONNECTED default-open 同 LOOT_DROP「lock surroundings + exempt handler」哲學唔一致 —— DISCONNECTED 係 blanket-open，LOOT_DROP 係 lock+exempt。建議：若 #24 design 確認 disconnect screen 會覆蓋整個 viewport（gameplay HUD 隱藏），DISCONNECTED open 係 safe；若兩者 co-exist，應考慮 lock gameplay input、exempt reconnect affordance（same LOOT_DROP pattern）。**Defer to #24 authoring**；#33 現狀 default-open，待 #24 co-design 收窄。
- **Q-OQ5 — `IInputPolicy` concrete instance 係 shared flyweight 定 per-handler** — 兩者皆 valid（stateless，EC-11）；defer 到 implementation。
