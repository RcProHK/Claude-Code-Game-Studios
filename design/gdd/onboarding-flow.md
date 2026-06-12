# Onboarding Flow

> **Status**: APPROVED（/design-review 2026-06-11 — NEEDS REVISION → revise-now → APPROVED 同 session，degraded-inline + grep-verify；2 BLOCKING citation-level + 2 RECOMMENDED 全收，0 architectural fault）
> **Author**: Frank + (degraded-inline authoring — specialist spawn credit-limited; grep-verified against shipped GDDs/src)
> **Last Updated**: 2026-06-11
> **Review revisions（2026-06-11）**: B-1 `SET_ACTIVE` cross-enum 型別錯誤 → 改 `WORKOUT_ACTIVE`（WORKOUT_CRITICAL 變純 #1 GSM `GameState` set，grep game_state_machine.gd:80-90；#9 `WorkoutPhase.SET_ACTIVE` 精度 deferred）。B-2 `tail after #29` stale citation → 改 tail-append after current tail（#25 `CombatVisualFeedback` L162，64ebbb5 後加）。R-1 CF-1 citation → cite #12 ability-system.md L444（`TIER_1_THRESHOLD` 真名）。R-2 `OnboardingOverlayLayer` desaturation moot（coach-mark 永不同 world desaturation 同框）→ captured band <100 acceptable。
> **Implements Pillar**: Pillar 2 (Frictionless Companion — NO tutorial wall) primary; Pillar 1 (real drop only) + Pillar 4 (muscle=class teaching) + Pillar 3 (first-drop ceremony framing) supporting
> **System #**: 27 (Polish / Presentation layer, Pre-MVP tier)
> **Depends On**: #24 Login/Shell (login surface host), #9 WST (workout lifecycle signals), #10 Exercise→Class (teaching content), #15 LootDrop (first guaranteed drop)

## Overview

Onboarding Flow 係 Mirror Hero 嘅 **first-run choreography 層** — 一個 Polish/Presentation coordinator，負責新玩家頭一次開 game 嗰段體驗，將「**連接 GymSys 帳號 → 即時見到 avatar auto-fight preview → 學識練乜 = 邊個 class → 真實做完第一個 workout 必爆首件裝備**」串成一條無斷層、無 tutorial wall 嘅 in-context 流程（game-concept.md L106 嘅 onboarding curve）。

佢**唔自己擁有任何 gameplay 數值或 game surface** — 純粹 orchestrate 既有系統：host #24 嘅 login surface、觀察 #9 嘅 workout lifecycle、引用 #10 嘅 muscle=class 真相、慶祝 #15 嘅真實首個 daily guaranteed drop。佢唯一 own 嘅三樣嘢係：(1) **first-run 進度 latch**（persist 邊幾步做完，確保每步只 fire 一次、永不重播）；(2) 一個 **dismissible、peripheral、non-blocking 嘅 coach-mark overlay**（in-context 解釋，唔係 modal tutorial wall）；(3) 一段 **非綁定、零真實 progress 嘅 combat preview**（Pillar 1 safe — 即時交付 auto-combat fantasy，即使玩家連接帳號嗰陣唔喺 gym）。

設計命脈兩條：**首件裝備必須係真實 workout 嘅 drop（Pillar 1 — onboarding 唔可 script 假爆、唔可 client-trigger #15 daily token）；tutorial 永不築牆停玩家（Pillar 2 — coach-mark 全部 peripheral + dismissible，零 mid-set 干擾）**。冇咗呢個系統，新玩家會喺一個無解釋嘅 auto-combat 世界面前一頭霧水 —— 唔知「點解我個角色自己打」、「點解今日係 STRIKE」、「幾時先爆裝」—— 既有系統各自運作但無人引路。Onboarding 純粹做引路人，做完即退場（完成後永久 dormant，零 runtime cost）。

## Player Fantasy

**「唔使人教，自己就明」（It Teaches by Showing, Not Telling）** — moment-of-clarity fantasy。

> *creative-director 未諮詢（degraded-inline — specialist spawn credit-limited；production 前人手 review framing）。以下 framing 由 game-concept.md flow-state design（L104-109）+ Pillar 2 anti-pillar 推導。*

玩家心入面嘅 felt promise：

> 「**我第一次開呢個 game，冇人塞一大版 tutorial 落我面前；但我五分鐘之內就完全明白點玩 —— 因為個 game 用畀我睇，唔係寫畀我讀。我見到我個角色自己喺度打，我即刻明咩叫 auto-combat;我（連住 GymSys 之後）見到自己做推嘅動作着 STRIKE 燈，我即刻明咩叫『練乜變乜』;我真實做完一整個 workout，一件裝備喺我面前儀式式咁掉出嚟，我即刻明咩叫『real reps become real power』。由頭到尾無人打斷我、無 'Next>' 掣逼我撳、無 'OK 我明喇' 嘅假對話 —— 個 game 對我嘅尊重，由佢點介紹自己嗰一刻就開始。**」

呢個 fantasy 嘅特別之處：**onboarding 系統本身就係 Pillar 2（無壓力陪伴）嘅第一個 falsifiable test**。一個關於「無壓力」嘅 game，如果用一道 modal tutorial wall 開場，就喺第一秒違反自己嘅 pillar。所以 onboarding 嘅 fantasy 唔由華麗 cutscene 交付，由 **architectural restraint** 強制：

- **教學零阻塞（Pillar 2 收口）** — 所有 coach-mark 都係 peripheral、dismissible、auto-dismiss；冇一個會 pause game、冇一個會 block 下一個動作、冇一個要求玩家確認先繼續。Falsifiable：對 onboarding 每一個 surface 問「呢個會唔會逼玩家停低先可以繼續？」必須全部 NO。
- **首印象係真，唔係 demo 騙局（Pillar 1 護欄）** — preview 明確標示「試演」，零真實 progress；而真正嘅「第一件裝備」係玩家**真實做完 workout** 爆出嚟嗰件（#15 daily guaranteed drop）。Onboarding 唔可以為咗「五分鐘內畀到爽」而 fake 一件裝備呃玩家 —— 嗰樣會喺第一日就摧毀「呢個 game 唔呃我」嘅信任。
- **引路人，唔係主角** — onboarding 嘅成功標準係**玩家事後唔記得有過 onboarding**，只記得「我一開始就睇得明」。佢做完即永久退場。

**錨定 moment**：第一次見到 avatar 喺 background auto-fight 嗰一眼（「呢個係我」），同第一件真實裝備落地嗰一下（「我做真嘢，game 認我」）。Onboarding 嘅工作唔係製造呢兩個 moment（戰鬥由 #25/#14 製造、爆裝由 #15/#21 製造），而係**確保新玩家睇得明、唔錯過呢兩個 moment 嘅意義**。

**Pillar links**：Pillar 2（Frictionless Companion）PRIMARY — onboarding 係 pillar 嘅自我示範；Pillar 1（real drop only）/ Pillar 4（muscle=class 第一課）/ Pillar 3（first-drop ceremony framing）supporting。

## Detailed Design

### Core Rules

> *Specialist 諮詢（game-designer / systems-designer / ux-designer）degraded-inline — credit-limited；rules 由 grep-verified 上游 contract（#24 host 關係 L117 / #9 signals / #15 daily-token server-authority / #10 taxonomy / #21 `modal_dismissed`）+ Pillar 1/2 推導。Production 前人手 review。*

**Rule 1 — 單 coordinator 擁有權** — `OnboardingCoordinator` autoload（ADR-0008 **tail-append after current autoload tail — G-OB-1**；grep-verified 2026-06-11：current tail 係 `CombatVisualFeedback`(#25, project.godot L162)，**非** #29 MirrorMomentCoordinator(#25 喺 64ebbb5 後加，排 #29 之後)。Tail-append = after every prior autoload，terminal — 零 shift 現有 position，避 [[feedback_lint_allowlist_adr_sync]] drift class）own 兩樣嘢：**first-run 進度 latch**（經 #3 PersistenceLayer，`onboarding.*` namespace）+ 一個 CanvasLayer `OnboardingOverlayLayer`（coach-mark host）。Pre-warmed `visible = false`（#21/#22/#23/#24 先例 — idle 零 draw-call）。內部可拆 `src/ui/onboarding/` helper file（coach_mark / preview_director），但**唔開第二個 autoload**（established pattern：一 autoload + 多 helper file）。**唔 own**：login surface（#24）、combat（#25/#14）、loot 生成或 reveal（#15/#21）、avatar render（#26）、persistence schema（#3）。純 orchestrator。

**Rule 2 — First-run gate（idempotent，persisted，per-step latch）** — Onboarding 只喺 `onboarding.completed != true` 時行動。**四個 step 各有獨立 persisted latch**：`onboarding.step_connect` / `onboarding.step_preview` / `onboarding.step_class` / `onboarding.step_first_drop`（全 bool，經 #3 backend-primary）。每個 step **恰好 fire 一次**，完成嘅 step **永不重播**（跨 app-close / bfcache / 重裝 / 換 device — backend-primary persistence 保證）。四個 latch 全 set → `onboarding.completed = true` → coordinator 永久 `DORMANT`（disconnect 全部 signal、`OnboardingOverlayLayer` 永久 hidden、零 runtime cost）。

**Rule 3 — 四步流程（in-context，順序但 latch-driven）**：

   1. **Step 1 — Connect（host #24，唔重做 login）** — first-run boot → onboarding 確保入口係 #24 login surface（#24 owns surface，onboarding **唔** reimplement login）。觀察 connect 成功（GSM 離開 BOOTING 落 landing state + #2 session established）→ 顯示一句 **welcome coach-mark**（「連好喇 — 睇下你個角色」，dismissible）→ latch `step_connect`。
   2. **Step 2 — Combat preview（「試演」，非綁定）** — connect 之後、玩家真實 workout 未開始之前 → onboarding 播一段 **非綁定 combat preview**：avatar auto-fight 一段 scripted wave，令 auto-combat fantasy 即時落地（即使玩家連帳號嗰陣喺屋企唔喺 gym）。**零 loot、零 stat、零 ability unlock、零 gameplay persistence、零 #15 daily token**。明確標示「試演 / Preview」+ skip affordance → latch `step_preview`（睇完或 skip 都 latch）。
   3. **Step 3 — Muscle=class 第一課** — 玩家第一個真實 workout 確立 dominant class（首個 `#9 dominant_class_changed`）→ 一次性 peripheral coach-mark：「你今日做緊推 → **STRIKE** 着燈」（引用 #10 `get_class_for_exercise` taxonomy + 錨 **#12 ability-system.md CF-1**「Default Baseline Auto-Unlock」：first-boot `DEFAULT_BASE_STAT=10 ≥ TIER_1_THRESHOLD=10` → 3×TIER_1 ability auto-unlock，grep-verified ability-system.md L444/L637。**Onboarding 唔計呢個值 — 純引用作 teaching 背景**，auto-unlock 行為由 #12 own）。Dismissible、non-blocking → latch `step_class`。
   4. **Step 4 — First-drop framing（唔 overlay sacred ceremony）** — onboarding active 期間**第一次 loot reveal 終結**（`#21 modal_dismissed(drop_id, terminal=true)`）→ 喺 ceremony **dismiss 之後** 一次性 peripheral closure coach-mark：「頭先爆嗰件，係你真實做完戰鬥/workout 換返嚟嘅 —— 以後日日做日日有」（爆裝概念教學）→ latch `step_first_drop`。**唔疊喺 loot modal 之上**（Pillar 3 — #21 ceremony 係 sacred surface）。

**Rule 4 — Non-blocking coach-mark 紀律（Pillar 2 命脈）** — 每個 coach-mark 必須：peripheral 位置、dismissible（tap-anywhere 或 auto-dismiss timer）、**永不 pause game、永不 block input / next-exercise、永不要求確認先繼續**。零 modal tutorial wall。Game 入 **workout-critical state**（`WORKOUT_ACTIVE` 做緊組 / `REST_PERIOD` next-exercise tap window / `LOOT_DROP` sacred ceremony — **全部 #1 GSM `GameState`**，grep-verified game_state_machine.gd:80-90）時，任何 pending coach-mark **defer/hide**（讓位 sacred moment，同 #24 banner 讓 REST 同理）。**任何 coach-mark 永不喺 mid-set 出現**（Falsifiable：grep onboarding 每個 coach-mark show path，必須先 check 非 workout-critical state，否則 = Pillar 2 違反 bug）。

**Rule 5 — Preview 非綁定（Pillar 1 命脈）** — Step 2 preview 授予**零真實嘢**：no loot / no stat / no ability unlock / no gameplay persistence / no #15 daily token。純 scripted dummy wave 上嘅 cosmetic showcase，明確標「試演」。Preview **永不寫** `loot.*` / `stat.*` / `ability.*` / `streak.*` namespace、**永不 call** #15 drop 生成或 daily-claim、**永不 call** #11/#12 mutator。CI lint（G-OB-2）守 onboarding 零 gameplay-mutator call。若玩家真實 workout 喺 preview 期間/之前開始 → **真實 workout 優先**（preview 即 abort，`step_preview` latch as done-by-workout，真實系統接管）。

**Rule 6 — 首件裝備 = 真 drop（Pillar 1 命脈）** — Onboarding **永不生成或 fabricate 首件裝備**。「首件裝備」係玩家真實 `workout_completed` → #15 daily guaranteed drop（server-authoritative `POST /api/game/loot/claim-daily`、≥COMMON floor、workout-conditional — loot-drop-system.md Rule 1-3）。Onboarding 只喺真實 ceremony **之後**加教學 framing；**永不 call** #15 drop generation、**永不 claim** daily token、**永不 client-trigger** drop。

**Rule 7 — Skip / resume / 唔重播** — 玩家可 skip 任何 coach-mark（dismiss）；skip 咗嘅 step **照 latch as done**（skip 係合法完成 — Pillar 2 唔強逼重睇）。MVP **無「重播 onboarding」**（deferred → Open Q）。Mid-flow 中斷（app close / bfcache）→ 下次 boot 由**下一個未 latch 嘅 step 續**（file-backed resume）。重裝 + backend-primary：若 backend `onboarding.completed==true` → 永久 DORMANT（唔喺新 device 重新 onboard）。

**Rule 8 — Observe-only，never drive** — Onboarding 訂閱**最小 signal set**，**永不 request GSM transition、永不 mutate gameplay、永不 trigger loot**。訂：#1 GSM `state_changed`（landing；經 `connect_for_initial_state` ADR-0006 C6）+ #2 connect 確認 + #9 `workout_started_forwarded` / `dominant_class_changed` / `workout_completed_forwarded` + #21 `modal_dismissed`。讀：#10 `get_class_for_exercise` / class taxonomy（teaching copy）+ #3 `onboarding.*` latch。全部 upstream interface 照用（**零 upstream patch — consumer-forward**）。

### States and Transitions

Onboarding internal FSM（5 states — **唔係** GSM states；onboarding observe GSM + #9 + #21 signals 自己分流。四個 **step-latch 係 orthogonal**：state 反映 gating context，step 完成靠 latch 唔靠 state — 同 #24 banner overlay orthogonal-to-shell-FSM 同款）：

| State | 入場條件 | 顯示 / 行為 | 出場 |
|---|---|---|---|
| `DORMANT` | `onboarding.completed == true`（或非 first-run） | 冇 surface、冇 active subscription、`OnboardingOverlayLayer` 永久 hidden | **terminal**（永不再入其他 state） |
| `WELCOME` | first-run boot 且 `step_connect != true` | 觀察 connect；connect 成功 → welcome coach-mark（dismissible） | `step_connect` latch → `PREVIEW`（若無 active 真實 workout）或 `COACHING`（若真實 workout 已 active — Rule 5 真實優先） |
| `PREVIEW` | `step_connect` done、`step_preview != true`、無 active 真實 workout | 非綁定 combat preview + skip affordance（Rule 5） | `step_preview` latch（睇完 / skip / 被真實 workout abort）→ `COACHING` |
| `COACHING` | `step_preview` done（或被 workout-priority skip）且仲有 step pending | 按 trigger arm + show class coach-mark（Step 3）+ first-drop coach-mark（Step 4）；workout-critical state 時 defer（Rule 4） | 四個 latch 全 set → `COMPLETE` |
| `COMPLETE` | 四個 step latch 全 set | 寫 `onboarding.completed = true`、disconnect 全部 signal、hide overlay | 即時 → `DORMANT`（transient） |

**轉場紀律**：

- **真實優先 interrupt（Rule 5）** — 任何時候若真實 workout 開始（`#9 workout_started_forwarded`）而仲喺 `PREVIEW` → 即 abort preview、`step_preview` latch as done-by-workout、轉 `COACHING`。Preview **永不** 蓋過真實 workout。
- **Step-latch orthogonal** — `step_class` / `step_first_drop` 嘅 trigger（`dominant_class_changed` / `modal_dismissed`）可喺 `COACHING` 任何時候 fire；若 trigger 喺 `WELCOME`/`PREVIEW` 期間提早 fire（罕見：玩家連接即衝 gym 做嘢），latch 照 set（step 完成靠 latch 唔靠 current state），對應 coach-mark 喺非 workout-critical window 補顯（或若已過適當時機則 silent latch — 唔強推過時教學，Pillar 2）。
- **Boot resume** — 每次 boot 讀四個 latch：全 true → 直入 `DORMANT`；否則入「首個未 latch step 對應」嘅 state（`step_connect` 未 set → `WELCOME`；`step_connect` set 但 `step_preview` 未 → `PREVIEW`；如此類推）。File-backed，跨中斷無縫續。
- **Coach-mark overlay orthogonal** — `OnboardingOverlayLayer` 嘅 coach-mark 顯示由 Rule 4 gating 獨立控制，任何非-DORMANT state 都可疊現一個 coach-mark，但 workout-critical state 一律 defer。

### Interactions with Other Systems

| System | 方向 | Interface | 擁有權 |
|---|---|---|---|
| **#24 Login/Shell** | host（被 host） | onboarding **唔重做 login** — #24 提供 login surface，onboarding 觀察 connect 成功（透過 #1 GSM landing + #2 session）並加 first-time welcome framing（login-gymsys-connection-ui.md L117：「#27 owns flow;#24 owns surface;first-run tutorial 內容唔入 #24」） | #24 owns login surface；#27 owns first-run flow choreography |
| **#1 GSM** | observe | `state_changed(from, to, payload)` 經 `connect_for_initial_state`（ADR-0006 C6）— 偵測 connect landing + workout-critical state（`WORKOUT_ACTIVE`/`REST_PERIOD`/`LOOT_DROP`，全 GSM `GameState`）作 coach-mark gating；**永不 request transition**（Rule 8） | GSM owns states；#27 observe-only |
| **#2 GymSysClient** | observe | connect/session established 確認（onboarding 偵測首次連接成功 latch `step_connect`）；**唔訂 telemetry-class signal、唔 call claim**（login 由 #24 host） | #2 owns auth/transport；#27 observe |
| **#9 WST** | observe | 訂：`workout_started_forwarded()`（真實優先 interrupt — Rule 5）/ `dominant_class_changed(new_class: int)`（Step 3 muscle=class trigger）/ `workout_completed_forwarded(completed_at, transition_id)`（首次真實 workout 完成 — context）。**Coach-mark gating 軸 = #1 GSM state**（`WORKOUT_ACTIVE`/`REST_PERIOD`/`LOOT_DROP`，見 Formula 1）**唔係** #9 `WorkoutPhase`；#9 `WorkoutPhase.SET_ACTIVE`(ordinal 2) finer mid-set 精度 deferred（epic-time 若要可 subscribe #9 `phase_changed`，MVP 用 GSM `WORKOUT_ACTIVE` 粗粒已足夠保守） | #9 owns workout lifecycle；#27 observe |
| **#10 Exercise→Class** | read（lookup） | `get_class_for_exercise(exercise_id) -> int`（AbilityClass ordinal）+ class taxonomy（push→STRIKE / pull→CONTROL / leg→MOBILITY）作 Step 3 teaching copy；**唔 mutate**（#10 static config read-only） | #10 owns taxonomy；#27 read for copy |
| **#15 LootDrop** | none（觀察結果，唔 trigger） | onboarding **永不 call** #15 drop 生成 / daily-claim / client-trigger（Rule 6）；首件裝備 = 真實 `workout_completed` → #15 server-authoritative daily drop（loot-drop-system.md Rule 1-3）；onboarding 只透過 #21 reveal 終結偵測 ceremony 發生 | #15 owns loot 生成（server-authoritative）；#27 零干預 |
| **#21 Loot Drop Modal** | observe | 訂 `modal_dismissed(drop_id: String, terminal: bool)` — 首次 `terminal==true` dismissal → Step 4 first-drop framing coach-mark（**ceremony dismiss 之後**，唔疊 sacred surface — Rule 3.4 / Pillar 3） | #21 owns reveal ceremony；#27 加 post-ceremony teaching |
| **#3 PersistenceLayer** | read/write（own namespace） | 讀/寫 `onboarding.*` latch（`completed` / `step_connect` / `step_preview` / `step_class` / `step_first_drop`，全 bool，backend-primary per ADR-0003）；**唔掂其他 namespace** | #3 owns persistence engine；#27 owns `onboarding.*` keys |
| **#33 Attention Budget** | yield（觀察） | coach-mark 屬 peripheral non-blocking class，唔搶 attention budget；workout-critical state 一律 defer（Rule 4）— onboarding **唔要求** attention carve-out（同 #24 banner 唔同：onboarding 永不 mid-set 出現，無需 carve-out） | #33 owns budget；#27 自我約束 defer，零 carve-out |
| **#25/#14 Combat** | observe（preview only） | Step 2 preview 用既有 combat render（avatar auto-fight），但 preview 係**非綁定 scripted wave**（零真實 enemy_killed / 零 loot trigger — Rule 5）；真實 combat 由 #14/#25 own，onboarding 唔干預 | #14/#25 own combat；#27 preview 純 cosmetic |
| **#26 Avatar Renderer** | none（觀察畫面） | onboarding 唔 render avatar（#26 喺 GameLayer 自己 render）；preview/welcome 期間 avatar 經既有 world camera 自然顯示 | #26 owns avatar render；#27 零 duplicate |
| **#4 AudioManager** | none / minimal | coach-mark 預設 silent（同 #24 silent 紀律）；preview 可借既有 combat SFX（#4 既有 cue，唔開新 catalog gate）→ Open Q | — |

## Formulas

> **誠實申報**：Onboarding 係 thin presentation/flow 層，**零 gameplay 數值**（同 #24 先例）。本 section 唔發明唔存在嘅 math，只 formalize **三條** UI gating/timing/resume logic。全部 timing 用 monotonic clock（`Time.get_ticks_msec()`，wall-clock tamper 免疫），test seam 用 **injected clock**（`advance(delta_ms)` 模式，#22/#23/#24 先例）。**Integer-ms 紀律**：knob 以 float sec 申報，載入時 `knob_ms := int(knob_sec * 1000.0)`，formula 內部一律 integer ms 比較（去 float boundary-flaky；任何 formula 路徑唔可直 call `Time.get_ticks_msec()`，必須讀注入 clock — AC 守）。

### Formula 1 — Coach-mark 顯示閘（may_show gate，Rule 4）

一個 coach-mark 喺當前 frame 可唔可以顯示：

`may_show(step) = (fsm_state != DORMANT) AND (latch[step] == false) AND (gsm_state ∉ WORKOUT_CRITICAL) AND (no_other_coachmark_visible)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| fsm_state | — | enum | {DORMANT, WELCOME, PREVIEW, COACHING, COMPLETE} | onboarding 內部 FSM state |
| latch[step] | — | bool | {false, true} | 該 step 嘅 persisted 完成 latch |
| gsm_state | — | enum | GSM states | 當前 #1 GSM state |
| WORKOUT_CRITICAL | — | set | {WORKOUT_ACTIVE, REST_PERIOD, LOOT_DROP} | sacred / mid-set state 集合（**全 #1 GSM `GameState`** — grep-verified game_state_machine.gd:80-90；單一 enum membership，無 cross-enum）（Rule 4 defer 條件） |
| no_other_coachmark_visible | — | bool | {false, true} | 單一 coach-mark slot 紀律（同時最多一個） |

**Output Range:** boolean。`true` = 可顯示；`false` = defer（保持 pending，下 frame 重判）。**極端**：WORKOUT_CRITICAL 全程 `false`（coach-mark 永不 mid-set — Pillar 2 命脈）。
**Example:** `COACHING` state、`step_class` 未 latch、GSM = `IDLE`、無其他 coach-mark → `may_show = true`。若同一刻 GSM = `WORKOUT_ACTIVE` → `false`（defer 到組做完）。

### Formula 2 — Coach-mark auto-dismiss 倒數（Rule 4）

```
dismissed(t) = tapped OR (now_ms - shown_at_ms >= COACH_AUTO_DISMISS_MS)
visible(t)   = shown AND NOT dismissed(t)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| now_ms | t | int (ms) | monotonic | 注入 clock 當前 ms |
| shown_at_ms | t₀ | int (ms) | monotonic | coach-mark 顯示瞬間 ms |
| COACH_AUTO_DISMISS_MS | — | int (ms) | [3000, 12000] | auto-dismiss 閾值（knob `coach_auto_dismiss_sec` × 1000） |
| tapped | — | bool | {false, true} | 玩家 tap-anywhere dismiss |

**Output Range:** boolean visible。auto-dismiss 預設 ~6s（夠睇一句 in-context copy，唔賴喺度）；tap 即時 dismiss（玩家主導 — Pillar 2）。
**Example:** `shown_at_ms = 10000`、`COACH_AUTO_DISMISS_MS = 6000`、`now_ms = 16001` → `dismissed = true`（已過 6s）。玩家喺 `now_ms = 12000` tap → `dismissed = true`（提早）。

### Formula 3 — Boot resume state 選擇（Rule 7 / States §boot resume）

boot 時由四個 latch 推導入場 state（純決定，無浮點）：

```
resume_state =
    DORMANT   if onboarding.completed
    WELCOME   elif NOT step_connect
    PREVIEW   elif NOT step_preview
    COACHING  elif (NOT step_class) OR (NOT step_first_drop)
    COMPLETE  else   # 四步齊但 completed flag 未寫 → 即補寫 → DORMANT
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| onboarding.completed | — | bool | {false, true} | 總完成 latch |
| step_connect / step_preview / step_class / step_first_drop | — | bool | {false, true} | 四個 per-step latch |

**Output Range:** enum FSM state（5 值之一）。**極端**：四 step 齊但 `completed` 未寫（罕見 crash window）→ `COMPLETE` → 即補寫 `completed=true` → `DORMANT`（self-heal idempotent，Rule 2）。
**Example:** `completed=false, step_connect=true, step_preview=false` → `resume_state = PREVIEW`（玩家上次連咗、未睇 preview，續返）。

## Edge Cases

> 分四類：**真實優先 / persistence / teaching-trigger / 退化**。每條 named condition + exact resolution。

### 真實優先（Pillar 1/2 priority）

- **EC-01 — 玩家連接時喺屋企（唔喺 gym）**：preview 照播（非綁定），`step_class` / `step_first_drop` **等真實 workout 先 latch**；onboarding **唔 force-complete**、唔 nag。玩家可以連咗帳號慢慢睇 preview，第二日去 gym 先觸發後兩步。**Rationale**：onboarding 跟玩家真實節奏，唔逼。
- **EC-02 — 玩家連接時已喺 gym mid-workout**（connect 嗰刻 `#9 workout_started_forwarded` 已 fire / GSM 喺 workout-系 state）：**skip preview** — `step_preview` latch as done-by-workout，直入 `COACHING`，真實 workout 接管。**Rationale**：真實永遠贏 demo（Rule 5）；唔可以喺玩家做緊嘢時硬塞 preview。
- **EC-03 — preview 播緊，真實 workout 突然開始**：preview **即 abort**（`step_preview` latch as done-by-workout）、轉 `COACHING`。Preview frame 立即讓位真實 combat render。
- **EC-04 — coach-mark pending 時 GSM 入 workout-critical**（`WORKOUT_ACTIVE`/`REST_PERIOD`/`LOOT_DROP`）：coach-mark `may_show=false` defer（Formula 1），保持 pending，state 清返先顯示。**永不 mid-set 出現**。

### Persistence / resume（idempotent）

- **EC-05 — app close / bfcache 喺 preview 中途**：下次 boot 由 Formula 3 resume → 因 `step_preview` 未 latch → 重入 `PREVIEW`，preview 由頭重播（**非綁定，replay 無害**）。`step_preview` 只喺 preview 完成 / skip / workout-abort 先 latch（唔喺開始就 latch — 防 crash 即走令玩家從未見過）。
- **EC-06 — 重裝 app / 換 device，backend `onboarding.completed==true`**：永久 `DORMANT`，**唔重新 onboard**（backend-primary 真相，Formula 3 completed-first）。
- **EC-07 — `onboarding.*` latch read 失敗**（#3 read error，offline first boot）：保守 default **全 false（顯示 onboarding）** — coach-mark dismissible，誤顯示成本低；但 backend sync 返 true 後嘅 step **唔重 fire**（latch resolve 為準）。**永不** fabricate `completed=true`（會令真新玩家錯過 onboarding）。
- **EC-08 — `onboarding.completed==true` 但某 step latch 係 false**（corruption）：**completed flag 贏** → `DORMANT`（Formula 3 先檢 completed）；唔重 onboard。
- **EC-09 — 四 step latch 齊但 `completed` 未寫**（crash window）：Formula 3 → `COMPLETE` → 即補寫 `completed=true` → `DORMANT`（self-heal）。

### Teaching-trigger 邊界

- **EC-10 — 玩家見到嘅第一件 loot 係 mini-boss drop（唔係 daily guaranteed drop）**：Step 4 照喺**第一次 `#21 modal_dismissed(terminal=true)`** fire（教學係關於**爆裝 ceremony**，唔係特定 drop type）→ latch `step_first_drop`。**Rationale**：first爆裝 moment 嘅意義對 mini-boss / daily drop 一致。
- **EC-11 — `dominant_class_changed` emit `UNKNOWN`（未 mapped exercise）**：Step 3 coach-mark **唔顯示「UNKNOWN 着燈」**（無意義）→ 等下一個 **known class**（STRIKE/CONTROL/MOBILITY）先顯示具體 copy；若該 workout 全程 UNKNOWN → 用 generic copy「你嘅訓練決定你嘅 class」或 silent defer。**永不** naming UNKNOWN。
- **EC-12 — teachable moment 過咗（coach-mark defer 太耐，context 變 stale）**：超過 `COACH_MAX_DEFER_MS` 仍未有非-critical window 顯示 → **silent latch 該 step（唔顯示過時教學）**。**Rationale**：Pillar 2 — 過時 hand-holding 比唔教仲差。
- **EC-13 — 兩個 coach-mark trigger 同 frame fire**（`dominant_class_changed` + `modal_dismissed`）：單一 slot（Formula 1 `no_other_coachmark_visible`）→ 按 step order 排隊（class 先於 first-drop），逐個喺非-critical window 顯示。
- **EC-14 — 玩家即 skip 每個 coach-mark**：每個 skip 照 latch（skip = 合法完成，Rule 7）→ onboarding 快速 complete → `DORMANT`。**Rationale**：唔想 hand-holding 嘅玩家即刻甩身（Pillar 2）。

### 退化（graceful degrade）

- **EC-15 — preview combat scene/asset load 失敗**：preview **graceful skip**（`step_preview` latch as done）、零 crash、繼續流程。Onboarding **永不** block boot 喺 preview 上。
- **EC-16 — 玩家連登入都未成功**（#24 login 反覆失敗，GSM 永留 BOOTING/auth）：onboarding 留 `WELCOME` 靜觀，**零顯示**；login error UX 由 #24 own。Connect 成功先郁。
- **EC-17 — 玩家完成首 workout 但 daily token 已被同日早一個 workout claim**（理論上 first-run 首 workout = 首 token，但防守）：該次無 loot reveal → `step_first_drop` 唔由此 latch；等下次有 reveal。**永不** 為咗 latch 而 fabricate drop（Pillar 1）。

## Dependencies

Onboarding 係**純 downstream observer / orchestrator**（consumer-forward — 零 upstream behavior 改動）。

### Hard dependencies（無佢 onboarding 唔運作）

| System | 性質 | Data interface | Back-reference 狀態 |
|---|---|---|---|
| **#24 Login/Shell** | hard（host） | onboarding host #24 login surface 作 Step 1；觀察 connect 成功 | ✅ **已 bidirectional**（login-gymsys-connection-ui.md L11 / L117 / L249 已列「#27 Onboarding Flow (login step host)」） |
| **#3 PersistenceLayer** | hard | `onboarding.*` latch 讀寫（backend-primary，ADR-0003） | ⚠️ back-ref follow-up（#3 為通用 persistence engine，consumer 眾多，慣例唔逐個列；`onboarding.*` namespace 新增） |
| **#1 GSM** | hard | `state_changed` observe（landing + workout-critical gating，ADR-0006 C6） | ⚠️ back-ref follow-up（GSM observer 眾多，唔逐個列 — 同 #24/#26 慣例） |
| **#9 WST** | hard | `workout_started_forwarded` / `dominant_class_changed` / `workout_completed_forwarded` observe | ⚠️ back-ref follow-up（epic-time 加「Depended On By: … #27」一行） |

### Soft dependencies（增強，無佢 onboarding 仍 graceful degrade）

| System | 性質 | Data interface | Degrade |
|---|---|---|---|
| **#10 Exercise→Class** | soft（teaching copy） | `get_class_for_exercise` + taxonomy（Step 3 copy） | 無 #10 → Step 3 用 generic copy（唔 naming 具體 class）；EC-11 |
| **#15 LootDrop** | soft（觀察結果） | onboarding 唔 call #15；只透過 #21 reveal 偵測 ceremony | 無 loot reveal → `step_first_drop` 待下次（EC-17）；onboarding 唔 fabricate（Rule 6） |
| **#21 Loot Drop Modal** | soft（teaching trigger） | `modal_dismissed(drop_id, terminal)` observe（Step 4 trigger） | 無 reveal → Step 4 不觸發；onboarding 等待，唔 nag |
| **#2 GymSysClient** | soft（connect 確認） | session established 偵測（透過 #1/#24） | connect 由 #24/#2 own；onboarding 觀察結果 |
| **#33 Attention Budget** | soft（自我約束） | coach-mark 自我 defer workout-critical（Rule 4），唔要 carve-out | onboarding 永不 mid-set，無需 #33 carve-out |
| **#25/#14 Combat** | soft（preview render） | preview 借既有 combat render（非綁定 scripted wave） | preview load fail → graceful skip（EC-15） |
| **#4 AudioManager** | soft（minimal） | coach-mark silent；preview 可借既有 SFX → Open Q | 無 #4 → coach-mark 照 silent 運作 |

### Bidirectional 一致性 note

- **#24 ✅ 已雙向**（唯一 host 關係，已明文）。
- **#9 / #10 / #15 / #21**：onboarding 係新 observe-only downstream，唔改上游行為。Back-reference（「Depended On By: … #27」）建議 epic-time 加一行喺各上游 GDD（doc-consistency follow-up，非 GDD defect — 同 #26 observe-only downstream 先例）。
- **零 upstream patch**：onboarding 消費全部 interface as-is（consumer-forward 原則 — [[feedback_consumer_forward_contract]]）。

## Tuning Knobs

| Knob | Default | Safe Range | 影響 | 太高 / 太低 |
|---|---|---|---|---|
| `coach_auto_dismiss_sec` | 6.0 | [3.0, 12.0] | coach-mark auto-dismiss 倒數（Formula 2） | 太高 = coach-mark 賴喺度阻視線；太低 = 玩家未睇完就消失 |
| `coach_max_defer_sec` | 120.0 | [30.0, 600.0] | coach-mark defer 上限，超時 silent latch（EC-12） | 太高 = 過時教學遲早彈出；太低 = teachable moment 一遇 workout-critical 就永久錯過 |
| `coach_fade_sec` | 0.25 | [0.0, 0.6] | coach-mark fade in/out 時長 | 太高 = 顯示遲緩；太低 = 硬 cut |
| `preview_duration_sec` | 24.0 | [8.0, 60.0] | 非綁定 combat preview 長度（Step 2） | 太高 = 玩家未到 gym 就悶；太低 = fantasy 未落地 |
| `preview_enabled` | true | {true, false} | 總開關 Step 2 preview | false → 跳過 preview（`step_preview` 即 latch）；無 loop / mid-set 影響（preview 本身非綁定） |
| `coach_marks_enabled` | true | {true, false} | 總開關全部 coach-mark（a11y / 重玩測試 escape hatch） | false → 全部 step silent latch、純靠既有系統教學；onboarding 退化成純 latch tracker |

**Knob 互動**：
- `coach_auto_dismiss_sec` 必須 ≪ `coach_max_defer_sec`（dismiss 係單個 coach-mark 壽命，defer 係等顯示窗口；兩者唔同軸）。
- `preview_enabled=false` 令 `preview_duration_sec` 無關（preview 唔播）。
- `coach_marks_enabled=false` 令所有 coach-* knob 無關（無 coach-mark 顯示）；但 step latch 照行（onboarding 仍會喺四 trigger 齊後 `completed`）。

**非 numeric（data-driven，唔列 knob）**：所有 coach-mark **copy 文案**（welcome / class / first-drop）係 data-driven localized string（廣東話口語 witness 語氣，同 #24/#20 register 一致），唔係 tuning knob；preview scripted wave 內容係 scene config。

## Visual/Audio Requirements

> *art-director / audio-director degraded-inline — credit-limited；跟 game-concept Visual Identity Anchor（Layer Discipline：HUD/text 高飽和）+ #24 banner restraint 先例。Production 前人手 review。*

### Visual

- **Coach-mark** — peripheral 位置、貼近相關 element（welcome 近 avatar / class 課近 class indicator 或 avatar / first-drop 近剛收嘅 loot 區）。視覺：細、高飽和 text card、fade in/out（`coach_fade_sec`）。**Note（R-2 澄清）**：coach-mark 喺所有 world-desaturating state（`LOOT_DROP` ceremony，world −60% desaturation）一律 defer（Rule 4 / AC-10）→ **永不同 world desaturation 同框** → 唔需要 >100 BackBufferCopy-immune layer，可安全住 captured band（<100），desaturation-immunity 對 coach-mark 係 moot（見 G-OB-3）。**零 pulse、零 gaze-drawing animation**（同 #24 banner 紀律 — Pillar 2：教學係狀態唔係 urgency gesture）。Dismissible affordance visible（tap hint glyph 或自然 auto-fade）。單一 slot（同時最多一個）。
- **Preview「試演」** — 借既有 combat render（avatar auto-fight），但**必須有明確「試演 / Preview」標示**（角落 badge / watermark）令玩家知道**唔係真實 progress**（Pillar 1 護欄 — 唔可以令玩家以為呢段打贏咗有嘢收）。Skip affordance（≥44px tap target）可見。Preview 結束 cross-fade 退場，唔 hard cut。
- **`OnboardingOverlayLayer`** — CanvasLayer，pre-warmed hidden（idle 零 draw-call）；唔加 BackBufferCopy（無 blur — ADR-0001 #21/#24 裁決同源）。Layer 數值 epic-time 釘（ADR-0001 amendment — G-OB-3，須喺既有 layer enumeration 之內，唔搶 #21 loot ceremony 110 / #24 banner 111 之上；**因 coach-mark 永不同 world desaturation 同框（R-2），captured band <100 acceptable — 唔強逼入擠迫嘅 (100,110) immune band**，與 #25 CombatOverlayLayer 105 解耦）。

### Audio

- **Coach-mark 全 silent** — 零 audio cue（同 #24 silent 紀律 — 教學唔搶耳，Pillar 2）。
- **Preview** — 可借既有 combat SFX（#4 既有 cue，preview 用既有 showcase 聲，**唔開新 #4 catalog gate** → Open Q 確認）；onboarding 本身**唔加** fanfare。
- **First-drop teaching silent** — 真實 loot fanfare 由 #15/#21 ceremony 提供，onboarding 嘅 post-ceremony coach-mark 零額外 audio。

📌 **Asset Spec** — Visual/Audio requirements 已定義。Art bible approved 後，run `/asset-spec system:onboarding-flow` 產出 coach-mark card 視覺 spec + 「試演」badge + preview scene asset 描述。

## UI Requirements

Onboarding 有真實 UI surface（coach-mark overlay + preview presentation + welcome + skip affordance），但**全部非綁定 / non-blocking**（無 modal、無 forced flow、無 "Next>" 掣）。需要 UX spec 嘅 surface：

- **Welcome coach-mark**（Step 1）— connect 成功後一句歡迎，dismissible。
- **Combat preview screen**（Step 2）— 「試演」標示 + skip affordance + 退場 transition。
- **Muscle=class coach-mark**（Step 3）— 貼近 class indicator / avatar，引用 #10 class copy。
- **First-drop coach-mark**（Step 4）— loot ceremony dismiss 後，貼近 loot 區。
- **單一 coach-mark slot 紀律** — 同時最多一個；queue by step order（Formula 1 / EC-13）。
- **a11y** — coach-mark text WCAG AA contrast；tap target ≥44px；reduced-motion（`coach_fade_sec→0` 硬切無 animation）；`coach_marks_enabled=false` escape hatch；screen-reader announce（peripheral polite，唔搶，同 #24/#19 announce_aria 先例）。

> **📌 UX Flag — Onboarding Flow（#27）**：呢個系統有 UI requirements。Phase 4（Pre-Production）run `/ux-design onboarding-flow` 為 coach-mark overlay + preview screen 寫 UX spec **再** 寫 epic。Stories 引用 UX surface 應 cite `design/ux/onboarding-flow.md`，唔直接 cite GDD。**新 UX pattern 候選**：`coach-mark`（peripheral dismissible in-context hint）+ `preview-watermark`（非綁定試演標示）— epic-time 入 `design/ux/interaction-patterns.md`。
>
> 已 note 入 systems index #27 row 嘅 UX flag。

## Acceptance Criteria

> *qa-lead degraded-inline — credit-limited。每條獨立可驗。BLOCKING = 自動 test gate；ADVISORY = visual/playtest 人手。*

### First-run latch / idempotency（Rule 2 / 7）

- **AC-01（BLOCKING）** — GIVEN `onboarding.completed==false` 且四 step latch 全 false，WHEN coordinator boot，THEN FSM 入 `WELCOME`（Formula 3）且 `OnboardingOverlayLayer` pre-warmed `visible==false`。
- **AC-02（BLOCKING）** — GIVEN `step_connect==true` 而 `step_preview==false`，WHEN boot，THEN resume 入 `PREVIEW`（Formula 3 file-backed resume）。
- **AC-03（BLOCKING）** — GIVEN 某 step latch 已 true，WHEN 該 step 嘅 trigger 再 fire，THEN coach-mark **唔重顯示**、latch 維持 true（恰好一次，永不重播）。
- **AC-04（BLOCKING）** — GIVEN 四 step latch 全 set，WHEN coordinator tick，THEN 寫 `onboarding.completed=true`、disconnect 全部 signal、入 `DORMANT`（terminal，唔再入其他 state）。
- **AC-05（BLOCKING）** — GIVEN `onboarding.completed==true`，WHEN boot，THEN 直入 `DORMANT`、零 subscription、零 surface（即使某 step latch 因 corruption 為 false — completed-first，EC-08）。

### 四步流程（Rule 3）

- **AC-06（BLOCKING）** — GIVEN `WELCOME` 且 connect 成功（GSM 離 BOOTING + session established），WHEN observe，THEN latch `step_connect`、顯示 welcome coach-mark（非 workout-critical 時）。
- **AC-07（BLOCKING）** — GIVEN `PREVIEW`，WHEN preview 完成或 skip，THEN latch `step_preview`、轉 `COACHING`。
- **AC-08（BLOCKING）** — GIVEN `COACHING` 且 `step_class==false`，WHEN 首個 `#9 dominant_class_changed(known_class)` fire（非 workout-critical window），THEN 顯示 muscle=class coach-mark（copy 含 #10 `get_class_for_exercise` 對應 class）、latch `step_class`。
- **AC-09（BLOCKING）** — GIVEN `COACHING` 且 `step_first_drop==false`，WHEN 首個 `#21 modal_dismissed(terminal=true)` fire，THEN ceremony dismiss **之後** 顯示 first-drop coach-mark、latch `step_first_drop`（唔疊喺 modal 之上）。

### Pillar 2 non-blocking（Rule 4 / Formula 1·2）

- **AC-10（BLOCKING）** — GIVEN 任何 pending coach-mark，WHEN GSM ∈ {WORKOUT_ACTIVE, REST_PERIOD, LOOT_DROP}（全 GSM `GameState`），THEN `may_show==false`、coach-mark **唔顯示**（defer，保持 pending）。
- **AC-11（BLOCKING）** — GIVEN coach-mark 顯示中，WHEN `now_ms - shown_at_ms >= COACH_AUTO_DISMISS_MS`（注入 clock advance），THEN coach-mark dismiss（Formula 2）。
- **AC-12（BLOCKING）** — GIVEN coach-mark 顯示中，WHEN 玩家 tap-anywhere，THEN 即時 dismiss（先於 auto timer）。
- **AC-13（BLOCKING）** — GIVEN coach-mark defer 超過 `COACH_MAX_DEFER_MS`，WHEN 仍無非-critical window，THEN **silent latch 該 step（唔顯示過時教學）**（EC-12）。
- **AC-14（ADVISORY playtest）** — GIVEN 真實 mid-set，WHEN 觀察成個 set 期間，THEN **零 coach-mark 出現**（Pillar 2 falsifiable — 人手 / 截圖驗）。

### Pillar 1 非綁定 / 真 drop（Rule 5 / 6）— CI lint

- **AC-15（BLOCKING — CI lint G-OB-2）** — `tools/ci/check_onboarding_no_gameplay_mutator.gd`：grep onboarding source（`src/autoload/onboarding_coordinator.gd` + `src/ui/onboarding/*`）**零** write 去 `loot.*`/`stat.*`/`ability.*`/`streak.*` namespace、**零** call #15 drop-gen / daily-claim、**零** call #11/#12 mutator。違反 = fail（Rule 5/6 命脈）。
- **AC-16（BLOCKING）** — GIVEN preview 播放中，WHEN preview 整段運行，THEN persistence 無任何 gameplay namespace 寫入、#15 無 drop 生成、daily token 無 claim（非綁定驗證）。
- **AC-17（BLOCKING）** — GIVEN onboarding active，WHEN 任何 step，THEN onboarding **永不** call GSM transition request、**永不** call #15 client-trigger（observe-only，Rule 8 — spy/grep 驗）。

### 真實優先 / 退化（EC）

- **AC-18（BLOCKING）** — GIVEN `PREVIEW`，WHEN `#9 workout_started_forwarded` fire，THEN preview abort、`step_preview` latch as done-by-workout、轉 `COACHING`（EC-03）。
- **AC-19（BLOCKING）** — GIVEN connect 嗰刻真實 workout 已 active，WHEN `step_connect` latch，THEN **skip PREVIEW** 直入 `COACHING`（EC-02）。
- **AC-20（BLOCKING）** — GIVEN `dominant_class_changed(UNKNOWN)`，WHEN Step 3 trigger，THEN **唔顯示「UNKNOWN 着燈」**、等 known class 或 generic copy（EC-11）。
- **AC-21（BLOCKING）** — GIVEN preview scene load 失敗，WHEN `PREVIEW` 入場，THEN graceful skip（`step_preview` latch）、零 crash、繼續流程（EC-15）。
- **AC-22（BLOCKING）** — GIVEN `onboarding.*` read 失敗，WHEN boot，THEN default 全 false（顯示 onboarding）、**永不** fabricate `completed=true`（EC-07）。

### Autoload / boot（G-OB-1）

- **AC-23（BLOCKING — CI lint）** — `OnboardingCoordinator` 喺 `project.godot` autoload position **tail-append after current tail**（ADR-0008 G-OB-1；epic-time grep current tail — 2026-06-11 係 `CombatVisualFeedback` #25 L162，非 #29）；boot-order static test 驗 position > **所有現有 coordinator** 且 boot 乾淨。
- **AC-24（ADVISORY playtest）** — GIVEN 真新玩家首 session，WHEN 完成連接→preview→首 workout→首爆裝，THEN 事後問卷顯示玩家**唔覺有過 tutorial**、能自述 auto-combat / muscle=class / 爆裝三個概念（Pillar 2 fantasy 驗 — 人手 playtest）。

## Open Questions

| ID | Question | Owner | 建議 default（full-autonomous） |
|---|---|---|---|
| **Q-OB-1** | Preview scripted wave 具體內容（邊個 enemy / 幾耐 / avatar 用咩 idle ability）？ | level-designer + game-designer | Defer 去 epic/asset — preview scene config，MVP 用既有 zone-1 enemy + CF-1 auto-unlock 嘅 TIER_1 ability showcase；`preview_duration_sec` 24s |
| **Q-OB-2** | 「首件裝備」要唔要一件 scripted COMMON「starter gift」（即時畀），定**淨係**真實首 workout drop？ | creative-director + game-designer | **RESOLVED（pillar-clean）**：淨係真實 drop（Rule 6）。Scripted starter gift 會經 #15 daily-token server-authority 之外塞 item → Pillar 1 灰區 + 架構違反。CF-1 已畀 baseline（3×TIER_1 ability auto-unlock）作「即時有嘢」；裝備留畀真實 workout。**若 playtest 顯示首 session 留存太弱** → v0.2 重議 scripted starter（要 #15 明文 carve-out，非 onboarding 私下塞） |
| **Q-OB-3** | Preview 用既有 combat SFX 定全 silent？ | audio-director | 建議借既有 #4 combat cue（preview = combat showcase，有聲先似真），**唔開新 catalog gate**；onboarding 本身零 fanfare |
| **Q-OB-4** | 「重播 onboarding」要唔要？ | game-designer | MVP **無**（Rule 7）；v0.2 候選喺 settings 加「重睇教學」（`coach_marks_enabled` 已預留總開關 + 可加 reset latch action） |
| **Q-OB-5** | `OnboardingOverlayLayer` 嘅 ADR-0001 CanvasLayer 數值？ | technical-director（ADR-0001 amendment） | **Epic-time gate（G-OB-3）**：須喺既有 layer enumeration 之內、唔搶 #21 loot 110 / #24 banner 111 之上；coach-mark 屬非-sacred UI，建議 **captured band <100**（R-2：coach-mark 永不同 world desaturation 同框，無需 >100 immune；BBCopy capture 係 positional <100 全 capture，enumeration 明寫對齊 [[feedback_lint_allowlist_adr_sync]] 防 stale-enumeration phantom）。若 epic-time 揀 >100 immune slot 須喺 (100,110) 且明寫 BBCopy-immune carve-out |
| **Q-OB-6** | Connect-success 確切偵測 signal（GSM 離 BOOTING vs #2 session signal）？ | systems-designer（epic-time grep-verify #2 API） | **Epic-time**：grep #2 公開 surface（`is_auth_required()`/session-established signal）+ #1 GSM landing state 確認確切 edge；MVP 用 GSM 離 BOOTING 落 non-auth landing 作 connect proxy |
| **Q-OB-7** | Onboarding 要唔要獨立 autoload，定摺入 #24 LoginShellCoordinator？ | technical-director | **RESOLVED（separate autoload）**：#24 GDD L117 明文「first-run tutorial 內容唔入 #24」；onboarding 嘅 lifecycle（4-step latch + preview + coach-mark）同 #24 shell FSM 唔同抽象，摺入 = 錯誤耦合（同 #24 Rule 14 FSM-extraction 裁決同理）。獨立 tail autoload（G-OB-1） |
