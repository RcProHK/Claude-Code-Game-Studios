# Gym-Mode HUD

> **Status**: Designed (pending `/design-review`) — 8 required sections + Visual/Audio + UI + Open Questions authored 2026-06-03 (full review mode, specialist-backed).
> **Author**: Frank + (creative-director · game-designer · ux-designer · ui-programmer · systems-designer · art-director · qa-lead)
> **Last Updated**: 2026-06-03
> **Implements Pillar**: **Pillar 2 — 無壓力陪伴 (Frictionless Companion)** [PRIMARY owner]; supporting Pillar 1 / 3
> **System #**: 20 (Presentation / MVP tier)
> **Depends On**: #11 Stat (Approved) · #12 Ability (Approved) · #4 Audio Manager (Approved, merged) · #2 GymSys Client (`set_logged` source) · #9 WorkoutStateTracker (Approved) · #1 GSM (state) · soft: #6 / #8 / #33 / #21
> **Creative Director Review (CD-GDD-ALIGN)**: CONCERNS (accepted) 2026-06-03 — 0 BLOCKING; 4 findings inline-accepted (AD1 Boss/player HP semantic → `/ux-design` · AD2 AC-V-1 glance playtest protocol [必跟進] · C1 #2/#8 bidirectional gap [fallback AC 備] · C2 #33 input-gate deferred [AC-EC-S5 fallback]). 可推進至 Approved。
> **EG-2 absorbed** (from #4 Audio EG-1 Option B): silent-mode banner SOFT-GATE (CR-6/7/8) + audio-trigger consumer SFX forwarding (CR-9/10/11) — folded into Detailed Design.
> **Next**: run `/design-review design/gdd/gym-mode-hud.md` in a FRESH session for independent validation; then `/ux-design gym-mode-hud` (**MUST** define AC-V-1 glance playtest protocol per CD downstream obligation).

---

## Overview

Gym-Mode HUD 係玩家做緊 gym set 期間、唯一持續顯示喺螢幕嘅 game UI 層。佢將三條 **read-only** 數據流——#11 Stat System 嘅 HP / EXP / stat、#12 Ability System 嘅已裝備技能、#9 WorkoutStateTracker 嘅 set / workout 進度——composite 成一個**高飽和 amber-gold、≤0.3 秒一眼讀到**嘅 status overlay,疊喺 desaturated（−30%）嘅 auto-combat 世界之上。玩家**唔需要 interact**:佢只係「眼角瞄一瞄」就知自己宜家幾強、打到邊、今日仲爭幾多組。呢個正正係 **Pillar 2 無壓力陪伴** 嘅化身——所有 input frictionless、所有 output ceremonial,絕不要求 mid-set 注意力。

除咗顯示,#20 仲孭起兩個 presentation-layer 職責(由 #4 Audio EG-2 relocate 落嚟):**(1) Silent-mode unlock banner**——web audio 要等用戶第一個 gesture 先解鎖,HUD 顯示「㩒一下開聲」banner,而且係 **SOFT-GATE**(workout 計數要等 banner tap-dismiss / `audio_unlocked` 之後先開始,否則 #2 polling 可能喺第一 tap 前 push `set_logged`,令第一組 SFX 全部 drop,破壞 Pillar 1「每個真實動作有聲音回應」);**(2) Audio-trigger consumer**——#20 直接訂閱 #2 `set_logged`,喺 audio LOCKED 時 buffer mid/high priority SFX、`audio_unlocked` 後 flush,並 owns `set_complete` × `streak_chime` 同幀嘅 80–120ms stagger。

**點解要存在**:冇咗 #20,玩家喺 set 中間就完全冇 game 反饋——Pillar 2 嘅「陪伴」蒸發,Pillar 1 嘅「真身數據可見」同 Pillar 3 嘅「爆裝飽和文字」全部冇 surface。佢係呢個 idle-companion game 由「背景跑緊嘅嘢」變成「值得眼角瞄」嘅唯一橋樑。

## Player Fantasy

**核心 fantasy 一句**:玩家喺力竭邊緣咬牙做 rep,眼角餘光掃過 amber-gold 嘅戰報——HP 穩、EXP 啱啱跳——佢冇停、冇 tap、冇對焦,但**知道**自己嘅痛正即時化成力量。HUD 係**沉默見證者(The Silent Witness)**:在場、忠實、即時,但從不要求你回應佢。佢成功嘅標準,係 session 之後你話「我冇點留意過佢」——而你全程安心。

**Anchor metaphor —「餘光戰報 The Glance Dispatch」**:健身房牆上嗰塊鏡。你唔會盯住塊鏡做 rep,但每組之間、每下喘氣嘅瞬間,眼角會掃過——確認自己仲喺度、仲喺變強。HUD = 喺**餘光(peripheral vision)** 接收嘅鏡像戰報,唔需要對焦。呢個 metaphor 本身就 encode 晒設計約束:任何要求對焦先讀到嘅 element 都違反 fantasy。高飽和 amber-gold、大字、低密度、事件驅動 motion——全部由「餘光接收」直接推導,唔係事後加嘅 a11y 要求。

**Anchor moment（Pillar 1 × Pillar 2 交匯點）**:「咬牙第 8 rep,力竭邊緣,眼角餘光掃過——HP bar 冇跌、EXP 條剛因為上一組 set 跳咗一格、角色喺 desaturated 世界照打。你冇停低、冇 tap、冇對焦,但嗰 0.3 秒你**知道**:呢組捱落去佢就升。然後你迫返埋落去做埋最後兩下。」
- 餘光交付 80% 嘅 status;set 之間休息對焦只係**確認**剩低 20% detail——reward 唔係喺對焦先出現,而係喺餘光已經被看到。

**Voice —「沉默見證者」**(fit 現有 register 光譜:介乎 #26 ledger「唔講大話」同 #7 Silent Showrunner 之間,但唔撞 #9 oracle 嘅 loud register):
- **唔係 coach**——絕不可以有「Tap now / Push harder / 加油!」。任何 call-to-action / 祈使句都違反 Pillar 2。
- **唔係 oracle**——必須 mute,唔搶注意力。
- **係 witness**——見證你嘅努力,默默、忠實、即時反映,但**從不要求你回應**。Voice = 「在場而不出聲」。
- **視覺即聲音**——HUD 嘅 voice 幾乎全由視覺承載:amber-gold 嘅溫度、popup 嘅節奏、bar 嘅穩定。文字極少,愈少愈好。
- **慶典留俾出面**——ceremony 屬於掉裝(#21)同 Mirror Moment(#29),唔屬於持續 HUD。#20 嘅 witness 係**安靜嘅在場**,只係令你安心捱到 ceremony 出現嗰刻。

**此 fantasy 服務嘅 Pillars**:Pillar 2 無壓力陪伴(PRIMARY,直接化身);Pillar 1 真身真力(supporting——餘光確認「你嘅痛有 game 意義」);Pillar 3 爆裝刺激(supporting——HUD 只承載 reward 嘅日常 surface,peak ceremony 外置)。

**Anti-pattern 警告（design test 種子）**——主雷:**「焦慮儀表板 The Anxiety Dashboard」**,變成另一個嘈住你嘅 fitness app HUD:① 實時跳動數字製造焦慮(逼對焦監控);② notification / nag 行為(coach voice 變體);③ 資訊密度爆棚變 cockpit;④ 要求 mid-set 互動攞 reward(cardinal sin);⑤ HUD 太搶飽和反客為主,玩家盯 HUD 多過盯 lift。
- **一句總結**:fitness app 想你**盯住佢**(engagement = 收入);Mirror Hero 嘅 HUD 想你**忘記佢**(forget it = 成功)。

## Detailed Design

### Core Rules

| # | Rule |
|---|---|
| **CR-1** | **雙層資訊架構**:Tier 1 餘光層(力竭/shake 下 0.3 秒可讀,承載 80% status)vs Tier 2 對焦層(休息凝視先讀,20% detail)。**Reward 永不鎖 Tier 2**——必須喺餘光已被看到。 |
| **CR-2** | **事件驅動 motion only**:Tier 1 靜止為 default,motion 只由離散事件觸發(EXP 跳格 / HP tick / boss HP 跌)、one-shot、≤1s、自動 settle。**禁 idle 持續抖動 / 跳秒數字**(= Anxiety Dashboard 主雷①)。 |
| **CR-3** | **Update model = signal-driven + pull-on-init**:live update 靠 dep push signal(handler 自行 filter,例如 `stat_changed` by `stat_id`,只 redraw 該 sub-widget);initial / resume 靠 pull query 補真值。**禁 `_process` 每幀 poll**;animation 用 `Tween` 自 gate(tween 跑時先 `set_process(true)`,到值即 `false`),idle 0 cost。 |
| **CR-4** | **進度係 event-driven estimate,5s gap 靜止**:`set_progress` 一格一格跳(event-driven),**禁逐秒精確倒數**(逼對焦,違 CR-2)。#2 polling 5s gap 期間 HUD **靜止顯示最後 confirmed state**,絕不 interpolate / 估算推進(違反 Pillar 1 anti-fabrication + #9 Falsifiable Test)。set 之間 5s 靜止係 design intent。 |
| **CR-5** | **State-gated visibility**:HUD 顯示/隱藏/強調跟 GSM state(見 States 矩陣);modal(#21 loot)在場主動退讓;`is_input_permitted()==false` 唔收 tap。 |
| **CR-6** | **Banner 顯示條件**:`AudioManager.is_audio_unlocked()==false`(web pre-gesture LOCKED)且 HUD 已離開 Booting → 顯示邀請式「㩒一下開聲」banner(零祈使句,witness register)。`is_audio_unlocked()` 開機已 true(desktop / 已解鎖)→ banner 永不出現。 |
| **CR-7** | **Banner dismiss**:訂 `audio_unlocked`,玩家第一個 tap(= 核心 next-exercise input)自然 unlock → one-shot dismiss,記 `banner_dismissed_this_session`(in-memory,非 persisted)→ **本 session 永不再現**(resume 唔重彈)。 |
| **CR-8** | **Soft-gate enforce**:用 `is_audio_unlocked()` 做 ready signal;**unlock 前唔開始 workout 計數 / SFX forwarding**,unlock 後先 count backend `set_logged`。Soft-gate 只延遲起點、唔丟數據(cursor 仍前進)。理由:#2 polling 可能喺首 tap 前 push `set_logged`,唔 gate → 第一組 SFX 全 drop → 破 Pillar 1。 |
| **CR-9** | **Audio-trigger consumer 訂閱**:dedicated child node `WorkoutAudioAdapter` 直接訂 `#2.set_logged`(唔經 #9,跟 #18 先例)+ `AudioManager.audio_unlocked` +(co-design)#8 `streak_chime` 路由。實際 call `AudioManager.play_sfx(event_id)`。 |
| **CR-10** | **Buffer policy**:Audio LOCKED 時 mid/high priority SFX → buffer(FIFO `_pending`,cap 8–16 防 memory);`audio_unlocked` 後 flush(flush 都行 stagger,唔一次連發撞 voice steal);**low priority 直接 drop 唔 buffer**。 |
| **CR-11** | **Stagger ownership**:`set_complete` × `streak_chime` 同幀 → consumer 先播 set_complete,defer streak_chime **80–120ms**(`create_timer`,non-blocking)。此 consumer 係 same-frame funnel;`AudioManager` stateless gateway 唔 delay,delay 100% 喺 #20 側。 |
| **CR-12** | **數據語意(已拍板)**:**HP** = `get_stat(MAX_HP)` derive 嘅「身體力量」顯示(穩定/滿,反映 Pillar 1 真身力,**非** depleting combat bar——current-HP runtime owner 不存在,depleting bar 遞後,唔 fabricate);**技能** = `get_unlocked_abilities()`(「今日訓練啟動嘅已解鎖技能」,equip slot deferred 到 #30 v0.2)。 |
| **CR-13** | **Pillar 2 紅線(8 條)**:① 禁 mid-set 互動攞 reward(cardinal sin)② 禁祈使句 ③ 禁 idle motion ④ reward 禁鎖對焦層 ⑤ Tier 1 element 硬上限 ≤5 ⑥ modal 在場退讓 ⑦ 尊重 `is_input_permitted()` ⑧ shake 期間 Tier 1 仍可讀。 |

**Information Tier 分配表**

| Element | Tier | 過「力竭 0.3 秒餘光測試」理由 |
|---|---|---|
| HP(身體力量,穩定) | L1 餘光主 | 大字高飽和固定 anchor,餘光直讀 |
| EXP(climbing) | L1 餘光主 | Anchor moment 主角,事件驅動跳格 |
| WorkoutPhase + 粗粒度進度 | L2 餘光次 | 餘光感知「進度感」,細節留 L3 |
| Boss HP(BOSS_ENCOUNTER) | L2→L1 | boss 戰時升 emphasis |
| avatar(desaturated 世界內) | L1 | silhouette 識別 |
| 精確 stat 數值 / 技能 icon 明細 / streak 數 | L3 對焦 | REST_PERIOD 先 surface,set 中唔逼睇 |
| 新技能解鎖 flash | 瞬時 L1 → 常駐 L3 | 一次性慶祝後退 ambient |

### States and Transitions

**HUD Element × GSM GameState 顯示矩陣**(◉Emphasis ○Ambient ▷Surface —Hidden ▽Defer ❄Frozen)

> GSM `GameState` 真相(grep-verified):`BOOTING / DISCONNECTED / IDLE / WORKOUT_ACTIVE / REST_PERIOD / COMBAT_ACTIVE / BOSS_ENCOUNTER / LOOT_DROP / SUSPENDED`。`WARM_UP` / `WORKOUT_COMPLETE` 屬 **#9 WorkoutPhase**,唔係 GSM state。

| GameState | HP | EXP | STAT | SKILLS | PROG | BOSS | 重點 |
|---|---|---|---|---|---|---|---|
| BOOTING | — | — | — | — | — | — | HUD 未掛起,boot veil |
| DISCONNECTED | ○dim | — | — | — | — | — | 全 dim + 細 connection glyph,非 nag,唔彈 popup |
| IDLE | ○ | ○ | ○ | ○ | — | — | 待機 ambient;BannerGate 可疊出 |
| WORKOUT_ACTIVE | ◉ | ◉ | ○ | ○ | ○ | — | 餘光主場,HP+EXP emphasis |
| REST_PERIOD | ○ | ○ | ▷ | ▷ | ▷ | — | **唯一容許對焦窗**:PROG 升 surface(set X/Y + 下一動作提示) |
| COMBAT_ACTIVE | ◉ | ◉ | ○ | ○ | ○ | — | 同 WORKOUT_ACTIVE,零互動 |
| BOSS_ENCOUNTER | ◉ | ○ | ○ | ◉ | ○ | ◉ | 強調 BOSS HP + SKILLS,仍 non-interactive |
| LOOT_DROP | ○dim | ○dim | — | — | ▽ | — | **主動 defer**,讓 #21 loot modal 做 ceremony;HUD 唔出 loot 文字 |
| SUSPENDED | ❄ | ❄ | ❄ | ❄ | ❄ | ❄ | **Freeze-dim**:凍結最後值 + 多 dim 一層,唔隱藏唔彈 popup |

*WORKOUT_ACTIVE 之下用 #9 WorkoutPhase 細分 PROG copy*:`WARM_UP`→「準備緊…」(ambient);`SET_ACTIVE`→ set X/Y + 動作名(ambient,絕不跳動);`REST_PERIOD`→ set 完成 + 下一動作 + 剩餘組數(surface);`WORKOUT_COMPLETE`→ 靜態結語(短暫過場,交棒 BOSS/LOOT)。

**HUD 內部 states(薄 view——只自有 3 個 state,其餘 derive GSM,唔重複 truth / 唔起第二個 state machine,避免同 ADR-0006 generational lock drift)**

| State | 進入 | 行為 | 離開 |
|---|---|---|---|
| **Booting** | GSM BOOTING | 唔 render,boot veil | 離開 BOOTING 且 node ready → 評估 BannerGate |
| **BannerGate** | `is_audio_unlocked()==false` | render banner + ambient HUD 已可見;**SOFT-GATE workout 計數 hold** | `audio_unlocked` → Active;開機已 unlock → 直接 skip |
| **Active** | 已 unlock | 跟矩陣 derive GSM 渲染;flush audio buffer | GSM SUSPENDED / visibilitychange hidden → Suspended |
| **Suspended** | GSM SUSPENDED 或 Page hidden / bfcache pagehide | **Freeze-dim**,停 motion/popup/SFX trigger | pageshow/visible/離 SUSPENDED → reconcile → Active |

**Banner Flow(SOFT-GATE)**:出現(web LOCKED)→ 靜態「㩒一下開聲」+ 輕 amber 脈動(非 CTA 句)→ 玩家首 tap → unlock → emit `audio_unlocked` → flush buffered SFX + banner fade-out → soft-gate 解除,workout 計數正式開始 → Active。Skip 路徑:開機已 unlock。Session 規則:dismiss 後永不再現,resume 唔重彈。

**bfcache / focus-out resume reconcile**:進 Suspended = Freeze-dim。Resume 序:① 唔信 stale frame,先 pull 真值(`is_audio_unlocked()` / GSM `get_current_state()`〔係 method 唔係 `.current_state`〕/ #11 stat / #9 phase)② bar 由 frozen 值**一次性 snap** 到真值(唔逐格補播 missed motion)③ GSM 仍 SUSPENDED → HUD 停 Suspended 唔搶先 ④ banner 防重彈(`banner_dismissed_this_session` true → 永不重出,只 re-check `is_audio_unlocked()`,被 re-lock 則靜默 re-buffer)⑤ 唔 double-flush SFX。**不變量**:resume 後 HUD == 當刻真值,零 stale / 零 double-popup / 零 double-SFX。

### Interactions with Other Systems

| Dep | Data IN → #20 | #20 → OUT | push/pull | Owner | 狀態 |
|---|---|---|---|---|---|
| **#11 Stat** | `stat_changed(stat_id,old,new,source,is_equip)` push + `get_stat()` | — | both | #11 | ✅(#11 已列 #20 consumer,指定 `connect_for_initial_state`) |
| **#12 Ability** | `ability_unlocked` push(icon flash)+ `get_unlocked_abilities()` | — | both | #12 | ✅ equip deferred |
| **#9 WST** | `phase_changed` / `set_progress_changed`(debounced 500ms)/ `dominant_class_changed` push + query | — | both | #9 | ✅(#9 列 #20 為 5 consumer 之一) |
| **#4 Audio** | `audio_unlocked` push + `is_audio_unlocked()` | `play_sfx(event_id)` | both + call-out | #4 | ✅ |
| **#2 GymSys** | `set_logged(exercise_id,reps,weight)` push(無 transition_id) | — | push | #2 | ✅ single-flight monotonic |
| **#1 GSM** | `state_changed(from,to,payload)` push + `current_state` pull | —(**絕不** drive transition) | both | #1 | ✅(#1 列 #20 soft dependent) |
| **#8 Streak** | streak 事件(供 stagger streak_chime) | — | TBD | #8 | ⚠️ co-design(Open Q) |
| **#6 ScreenEffects** | 無直接 call(topology coupling) | — | implicit | #6/ADR-0001 | ✅ HUD layer 50 < SE 100 |
| **#33 Attention** | `is_input_permitted()` pull | — | pull | #33 | ⚠️ Not Started,留 seam(Open Q) |

**Subscription wiring**(#20 唔係 autoload,喺 main scene instantiate,所有 autoload `_ready()` 已完):
1. 有 initial-state 概念嘅 signal 全用 `connect_for_initial_state`(`stat_changed` 有 CI lint `check_stat_changed_connect.gd` 強制;`ability_unlocked`;`state_changed`)——令 boot 即收 current value,唔會空白/stale。
2. 瞬時 event(`audio_unlocked` / `set_logged` / `phase_changed`)用 plain `.connect`,initial 用 query pull 補。
3. **pull-then-subscribe**:`_ready()` 先 pull 填 initial UI 再 connect 收後續 delta。
4. `_exit_tree()` kill tween + 清 `_pending` queue,避免 dangling `play_sfx` 喺 destroyed node。

**Provisional interface(carry 去 Open Questions)**:Prov-3 #8 streak signal-for-stagger(#8 GDD 未為 #20 expose);Prov-4 #33 `is_input_permitted()` 未 implement(banner tap 暫「直接 tap→unlock」,gating deferred wiring);Prov-5 `set_logged` 無 transition_id(可接受,server single-flight monotonic dedup)。

## Formulas

> #20 係 Presentation HUD,formula surface 偏薄——3 條真 formula,其餘係 constant(下表)。

### Formula 1 — EXP bar fill ratio

`exp_fill = clamp(current_exp / max(exp_to_next, 1), 0.0, 1.0)`

| Variable | Type | Range | Description |
|---|---|---|---|
| current_exp | int | [0, ∞) | #11 `get_stat(EXP)` 當前累積經驗 |
| exp_to_next | int | [1, ∞) | #11 升級所需(`max(.,1)` 防 div-by-zero) |
| exp_fill | float | [0.0, 1.0] | EXP bar 填充比例(clamped) |

**Output**:[0,1]。clamp 理由:cross-system stale 或剛升級瞬間(current ≥ to_next)唔可以令 bar overflow / 負值。**Example**:340/500 = **0.68**;邊界 500/500 = 1.0。

### Formula 2 — Tween duration(reduce_motion gate)

`tween_duration = reduce_motion ? 0.0 : base_tween_duration`

| Variable | Type | Range | Description |
|---|---|---|---|
| reduce_motion | bool | {T,F} | a11y / 系統 reduce-motion flag |
| base_tween_duration | float | [0.2, 0.5] | constant,default 0.3s |
| tween_duration | float | {0.0} ∪ [0.2,0.5] | SceneTreeTween 實際時長 |

**Output**:離散——reduce_motion 時恰好 0.0(瞬間 `set`,跳過 tween),否則 = base。**Example**:false → 0.3s lerp;true → 0.0 瞬間定位。

### Formula 3 — Banner amber 脈動 alpha

`banner_alpha = base_alpha + pulse_amp * (0.5 + 0.5 * sin(2π * t / pulse_period))`

| Variable | Type | Range | Description |
|---|---|---|---|
| base_alpha | float | [0.6, 0.8] | banner 底 alpha,default 0.7 |
| pulse_amp | float | [0.05, 0.15] | 脈動振幅(**僅 alpha,非 scale**),default 0.1 |
| t | float | [0, ∞) | 自 banner 出現累計秒數 |
| pulse_period | float | [1.5, 2.5] | 一個呼吸週期秒數,default 2.0s |
| banner_alpha | float | [base, base+amp] | 當前 alpha,硬 clamp ≤1.0 |

**Output**:[base, base+amp],clamp ≤1.0。**Example**:base=0.7, amp=0.1, period=2.0, t=0.5 → 0.8(峰);t=1.5 → 0.7(谷)。
**CR-2 合規界定**:此脈動 **banner-only、非 HUD element**,只擺 alpha 唔擺 scale/position(唔搶餘光);`audio_unlocked` 一 emit **立即 kill tween + banner fade-out**。Banner 唔屬 Tier 1 餘光層,故豁免 CR-2「禁 idle motion」——但明示此豁免邊界,**任何 HUD element 不得援引此 formula 做 idle 動畫**。

### Constants(non-derived)

| Constant | 值 | safe range | 過低 | 過高 |
|---|---|---|---|---|
| `set_streak_chime_stagger_ms` | 100 | [80,120] | 兩聲黐埋分唔開 | streak_chime 似甩拍 |
| `pending_buffer_cap` | 12 | [8,16] | burst 提早 drop SFX(擦 Pillar 1) | flush 堆串補播 + 食 memory |
| `glance_tier1_max` | 5 | ≤5 | 更安全 | 餘光 serial scan,破 0.3s(pre-attentive 4±1) |
| `world_desaturation` | 0.7(−30% sat) | [0.6,0.8] | 世界太灰失辨識 | 對比不足 HUD 唔跳出 |
| `base_dim` | 0.5 | [0.4,0.6] | dim 不足無狀態暗示 | 太黑似斷線/壞 |
| `freeze_dim_extra` | ×0.7(疊 base_dim) | [0.6,0.8] | freeze 同 disconnect 分唔開 | SUSPENDED 太黑似 crash |
| `icon_flash_duration` | 0.6s | [0.4,0.8] | flash 太快餘光接唔到 | 拖尾似 idle motion |

> *DISCONNECTED / LOOT_DROP / SUSPENDED 嘅 dim 統一由 `base_dim` × state multiplier 推導(共用 tuning point);SUSPENDED 額外乘 `freeze_dim_extra`。*
> *引用不重定:`set_progress_changed` debounce **500ms 由 #9 own**,#20 只 consume。*

### Negative-space block(故意冇 formula — Pillar 1 anti-fabrication)

1. **set_progress 內插**:5s polling gap 期間 **禁** 任何 `progress += elapsed/expected` 類推進。純 event-driven step,gap 內靜止顯示最後 confirmed state(CR-4)。
2. **HP fill ratio**:HP = `get_stat(MAX_HP)` 穩定顯示,**非** depleting bar,無 current-HP runtime owner,**禁** fabricate depleting fill(CR-12)。

*Cross-system flag*:`base_dim` / `world_desaturation` / `icon_flash_duration` 等屬 #20 內部 presentation constant,唔跨 GDD,毋須入 `entities.yaml`。

## Edge Cases

> 22 條,分 4 區。Severity:CRITICAL 1 / HIGH 11 / MEDIUM 8 / LOW 2。

### A. Formula 邊界
- **EC-F1 [HIGH]** **If** `exp_to_next == 0`(max-level sentinel):F1 `max(0,1)=1` 做分母,current≥1 即 fill=1.0 滿條,無 div-by-zero/NaN。滿條 = max-level 正確語意。
- **EC-F2 [HIGH]** **If** `current_exp > exp_to_next`(升級瞬間未 reset / stale):clamp 1.0 滿條,無 overflow;下個 level-up `stat_changed` snap 返低位。單格 frame 顯滿可接受(當下值確 ≥ to_next,witness 唔講大話)。
- **EC-F3 [HIGH]** **If** `current_exp < 0` 或 `exp_to_next < 0`(非法 push):clamp 0.0 空條;入 F1 前 `max(current_exp,0)` sanitize。
- **EC-F4 [MEDIUM]** **If** `current_exp/exp_to_next == NaN/INF`:入 F1 前 `is_nan/is_inf` guard,fallback 用上一 confirmed `exp_fill` 唔 redraw,log 一次。**唔餵 NaN 入 Tween**(NaN 令 SceneTreeTween 永不 settle,卡 `set_process(true)` 燒 CPU)。
- **EC-F5 [HIGH]** **If** `reduce_motion` 喺 tween 跑緊由 false→true:in-flight tween 即 `kill()`+`set()` snap 到 target,`set_process(false)`,唔等自然完。反向 true→false 只影響之後新事件。
- **EC-F6 [MEDIUM]** **If** banner `t` 長累積溢出:`fmod(t,pulse_period)` 餵 sin,數學等價永不溢出。
- **EC-F7 [LOW]** **If** presentation constant(`world_desaturation`/`base_dim` 等)config 設 range 外:clamp safe range 用 default 唔 crash,log warning。

### B. Signal race / 同幀
- **EC-R1 [HIGH]** **If** 同幀多個 `stat_changed`(不同 stat_id):各 handler 按 stat_id filter 只 redraw 該 sub-widget(CR-3),各自起 tween,唔 batch full redraw(破 draw-call budget)。
- **EC-R2 [HIGH]** **If** 同一 stat_id tween 未完又嚟新 `stat_changed`:kill 舊 tween,由**當前 interpolated 值** restart 去新 target(唔由原起點重播 = 唔回跳,唔疊兩 tween)。reduce_motion 時直接 snap。
- **EC-R3 [HIGH]** **If** `state_changed`(GSM)同 `phase_changed`(#9)同幀語意矛盾:GSM state 為 visibility/emphasis 主權威(矩陣 driver),#9 phase 只供 PROG copy;各管各層唔互相否決。
- **EC-R4 [CRITICAL]** **If** `audio_unlocked` 同 GSM `state_changed`→WORKOUT_ACTIVE 同幀:**固定先處理 `audio_unlocked`**(unlock→flush buffer→解 soft-gate→開始 count `set_logged`)**再** apply WORKOUT_ACTIVE 矩陣。保證 buffered 首組 SFX flush 喺計數開始前完成,唔丟首組聲(CR-8 核心)。
- **EC-R5 [MEDIUM]** **If** `ability_unlocked`(flash 0.6s)未完又嚟第二個:不同 icon slot 各自 one-shot 並行;同 slot 罕見重觸 kill-restart;flash 完一律退 L3 ambient。

### C. Audio consumer
- **EC-A1 [HIGH]** **If** `set_logged` 喺 LOCKED 到、workout 完從未 unlock(全程冇 tap):`_pending` FIFO,超 cap=12 drop oldest;永不 unlock = 永不 flush;`_exit_tree` 清 `_pending`(CR-9 wiring 4)。無 gesture = web audio 物理上唔出聲,buffer 只係善意。
- **EC-A2 [MEDIUM]** **If** `streak_chime` 到但冇對應 `set_complete`(單獨):直接播唔 stagger;CR-11 stagger 只在 set_complete×streak_chime 同幀並存時觸發。
- **EC-A3 [MEDIUM]** **If** flush 進行中又嚟新 `set_logged`:入 `_pending` 隊尾經隊列消化(保 FIFO+stagger 不撞 voice-steal),唔插隊即播;flush 完隊列空恢復即播。
- **EC-A4 [HIGH]** **If** stagger timer(deferred streak_chime 100ms)未 fire 就 suspend/`_exit_tree`:timer callback guard 檢查 node still in tree + 非 Suspended,否則 drop 該 deferred chime(唔喺 freeze/destroyed 出聲)。
- **EC-A5 [LOW]** **If** flush 時 `_pending` 內出現 low priority(CR-10 理論不可能):防禦 assert,drop+log 唔播(出現即 buffer policy bug)。

### D. State transition / provisional / web-perf
- **EC-S1 [HIGH]** **If** BannerGate 期間 GSM 已 WORKOUT_ACTIVE:HUD ambient 已顯示,但 soft-gate hold(計數/SFX 唔啟動,`set_logged` 入 buffer);首 tap→`audio_unlocked` 先解 gate+flush。**GSM 自行前進唔被 HUD 阻**(HUD 絕不 drive GSM);soft-gate 只 gate #20 自己計數/SFX。
- **EC-S2 [MEDIUM]** **If** 進 SUSPENDED 但 banner 未 dismiss:Freeze-dim 疊 banner,pulse tween 暫停;Resume 仍 LOCKED 且 `banner_dismissed_this_session==false`→banner 復現+pulse 重啟;期間被 unlock 過 → 永不重出。
- **EC-S3 [HIGH]** **If** GSM 進 LOOT_DROP 但 #21 modal 未 ready/未實作:HUD 按矩陣主動 defer(HP/EXP ○dim,PROG ▽,唔出 loot 文字),維持 defer 直到離開 LOOT_DROP。**HUD 絕不 fallback 自畫 loot 文字**(越界違 CR-13⑥ + Layer Discipline)。留 seam(Open Q)。
- **EC-S4 [MEDIUM]** **If** DISCONNECTED 期間有 `set_logged` 到(reconnect burst / in-flight):**聲行視覺靜**——SFX 照 buffer/播(聲音忠於真實動作 = Pillar 1),視覺維持 dim 不彈 popup(忠於斷線狀態)。兩 channel 各自誠實。
- **EC-S5 [HIGH]** **If** `is_input_permitted()`(#33)未 implement 時 banner tap:per Prov-4 直接 tap→unlock(gating deferred);banner tap = 解鎖 gesture 非 game 互動,唔違 Pillar 2(unlock 唔攞 reward);#33 ready 後 wrap game-affecting tap,banner-unlock tap 永遠豁免。
- **EC-S6 [MEDIUM]** **If** #8 streak signal 未 expose(Prov-3)時 set_complete 到:正常即播無 stagger;CR-11 邏輯休眠直到 #8 co-design 落實;唔因等一個唔存在嘅 chime 而 defer set_complete。
- **EC-S7 [HIGH]** **If** HUD Tier 1 element > `glance_tier1_max=5`:**design-time 硬約束非 runtime**;BOSS_ENCOUNTER 矩陣已驗 L1≤5;新增 L1 element 必重驗(CI/review-time gate);**runtime 唔自動隱藏**(自動隱破餘光穩定)。
- **EC-S8 [LOW]** **If** desktop(開機已 unlocked):BannerGate skip→Active,banner 永不出現,F3 永不執行,soft-gate 即解,`set_logged` 即時計數+即播。
- **EC-S9 [MEDIUM]** **If** pageshow/resume 後 pull 到 GSM state 同 freeze 前唔同(freeze@WORKOUT_ACTIVE,resume@LOOT_DROP):一次性 reconcile 到新 state 矩陣(snap),banner/buffer 按 reconcile 序;**唔重播 missed state 動畫**(bfcache 期 motion 無意義,Pillar 1 只認當下真值)。

## Dependencies

| Dep | 方向 | 硬/軟 | Interface | Bidirectional 狀態 |
|---|---|---|---|---|
| **#11 Stat System** | upstream | **Hard** | `stat_changed` push + `get_stat(MAX_HP/EXP/...)` query | ✅ #11 已列 #20 為 consumer(指定 `connect_for_initial_state`) |
| **#9 WorkoutStateTracker** | upstream | **Hard** | `phase_changed`/`set_progress_changed`(debounce 500ms)/`dominant_class_changed` + query | ✅ #9 已列 #20 為 5 consumer 之一 |
| **#1 Game State Machine** | upstream | **Hard** | `state_changed(from,to,payload)` + `current_state` pull | ✅ #1 已列 #20 為 soft dependent(reads `current_state` to switch HUD layout) |
| **#4 Audio Manager** | upstream | **Hard** | `is_audio_unlocked()`/`audio_unlocked`/`play_sfx()` | ✅ EG-1 已將 workout-SFX forwarding ownership relocate 落 #20(audio-manager.md forward contract 已 amend) |
| **#2 GymSys Backend Client** | upstream | **Hard**(audio-consumer 角色) | `set_logged(exercise_id,reps,weight)` push(直接 subscribe,#18 先例) | ⚠️ **one-directional**——#2 GDD 未列 #20 為 subscriber。flag 補 #2 consumer 列表。 |
| **#12 Ability System** | upstream | Soft | `ability_unlocked` push(icon flash)+ `get_unlocked_abilities()` | ✅ #12 framing 已提「ability unlock → #20 HUD icon flash」;equip API deferred |
| **#8 Streak System** | upstream | Soft(co-design) | streak 事件供 stagger `streak_chime` | ⚠️ **one-directional**——#8 GDD 未為 #20 expose streak signal。#8↔#20 co-design point(Prov-3) |
| **#6 Screen Effects** | sibling(topology) | Soft | 無直接 call;`hud_shakes_with_world=true` → HUD layer 50 < SE 100,跟世界 shake | ✅ topology-coupled,constant 由 #6 own(#20 為 referrer) |
| **#33 Attention Budget & Interaction Policy** | upstream | Soft(deferred) | `is_input_permitted()` pull gating | ⚠️ #33 **Not Started**;#20 留 deferred wiring seam(Prov-4) |
| **#21 Loot Drop Modal** | **downstream** | Soft | #20 喺 GSM LOOT_DROP **主動 defer**,讓 #21 做 ceremony 主角;#20 唔出 loot 文字 | ⚠️ #21 **Not Started**;defer 行為已定,#21 ready 後對接(EC-S3 seam) |

**Hard dependencies(缺則 #20 無法運作)**:#11(HP/EXP/stat 無數據源)、#9(無進度)、#1(無 state 切 layout)、#4(banner/SFX 係 #20 職責)、#2(audio-consumer 無 set_logged 源)。
**Soft dependencies(enhanced 但 works without)**:#12(技能可顯示空)、#8(無 stagger,chime 即播)、#6(無 shake coupling)、#33(無 gating,banner tap 仍 work)、#21(loot defer,#21 未 ready 仍 defer)。

**需補嘅 bidirectional gap**:① #2 GDD 加 #20 為 `set_logged` subscriber;② #8 GDD 為 #20 expose streak-event signal(co-design)。兩者 carry 去 Open Questions + 跨系統 gate。

## Tuning Knobs

**#20 owned knobs**

| Knob | Default | Safe range | 影響 gameplay aspect | 過高 | 過低 | Player-facing? |
|---|---|---|---|---|---|---|
| `base_tween_duration` | 0.3s | [0.2,0.5] | bar 動畫平滑度 | 拖尾似 idle motion | 跳得太硬冇平滑感 | 否 |
| `reduce_motion` | false | {T,F} | a11y——關晒 tween(瞬間 set) | — | — | **✅ a11y** |
| `set_streak_chime_stagger_ms` | 100 | [80,120] | 雙聲分離度 | streak_chime 似甩拍 | 兩聲黐埋 | 否 |
| `pending_buffer_cap` | 12 | [8,16] | LOCKED buffer memory | flush 堆串 + 食 memory | burst 提早 drop SFX(擦 Pillar 1) | 否 |
| `glance_tier1_max` | 5 | ≤5 | 餘光 0.3s 可讀性(design-time) | 餘光 serial scan 破 0.3s | 更安全 | 否 |
| `base_dim` | 0.5 | [0.4,0.6] | DISCONNECTED/LOOT dim 程度 | 太黑似壞 | 無狀態暗示 | 否 |
| `freeze_dim_extra` | ×0.7 | [0.6,0.8] | SUSPENDED 額外 dim | 似 crash | freeze≈disconnect 分唔開 | 否 |
| `icon_flash_duration` | 0.6s | [0.4,0.8] | 技能解鎖 flash 時長 | 拖尾似 idle motion | 餘光接唔到 | 否 |
| `banner_base_alpha` | 0.7 | [0.6,0.8] | banner 可見度 | 太實搶餘光 | 睇唔到提示 | 否 |
| `banner_pulse_amp` | 0.1 | [0.05,0.15] | banner 呼吸感 | 抖到搶注意力 | 似靜態冇邀請感 | 否 |
| `banner_pulse_period` | 2.0s | [1.5,2.5] | banner 呼吸節奏 | 慢到察覺唔到 | 快到緊張 | 否 |

**Cross-knob interactions**
- `reduce_motion=true` → `base_tween_duration` **失效**(F2 strictly 0),亦應令 `banner_pulse_amp` 視為 0(banner 靜態)、`icon_flash_duration` 縮至瞬顯。reduce_motion 係所有 motion knob 嘅 master override。
- `glance_tier1_max` × 實際 L1 element 數:design-time 互鎖,加 element 必重驗(EC-S7),非 runtime auto-hide。
- `base_dim` × `freeze_dim_extra`:SUSPENDED 實際 dim = `base_dim × freeze_dim_extra`,兩者乘積唔好過低(≤0.28 似 crash)。

**Referenced knobs(非 #20 own,point to source)**
- `world_desaturation`(0.7 / −30% sat):屬 **art-bible Layer Discipline** 全域常數,#20 只 reference 確保 HUD 飽和度對比;**唔由 #20 重定**。
- `set_progress_changed` debounce(500ms):**#9 own**,#20 只 consume。
- `hud_shakes_with_world`(true):**#6 own**(registry),#20 為 referrer。
- `motion_intensity`(#6 a11y slider):若 master 場景將 `reduce_motion` 綁 #6 motion slider,則 #20 `reduce_motion` 應 derive 自該 a11y source(避免兩個獨立 a11y toggle)——co-design flag。

## Visual/Audio Requirements

**設計總綱**:所有 motion = 「Snap-in → Settle → 退場」三段,**絕無 idle 動畫**(banner 脈動唯一豁免)。餘光 0.3s 可讀靠三 channel:**位置固定** + **形狀** + **飽和 amber 對比 desaturated world**。

### Visual event feedback spec

| Event | 形態 | 色 | Motion | 時長 |
|---|---|---|---|---|
| **EXP popup / bar 跳格** | `+N` popup 由 bar 上緣冒出 + bar fill **step 跳格**(§7.D ticker,唔 smooth lerp) | `ui_amber_primary #F2A93B` + 1px ink shadow `#1A1D24`@40% | popup overshoot 1.1×→settle;bar 每格 ≤33ms | popup 250ms + hold 0.4s + fade 200ms |
| **Level-up flash**(每組完成) | 三件 co-trigger:avatar silhouette rim flash(衫光)+ 武器 glow pulse + `+EXP` popup | `event_white #FFFFFF` 首 frame → 0.1s 落 `event_amber`(§4.A;**唔用** loot 純白 burst 體積) | one-shot,peak 即衰減,無 hold loop | 0.4s |
| **Ability unlock flash** | 新 icon(16×16 solid silhouette + 1px ink outline)pop-in + amber 邊緣 flash | flash `event_amber`;icon body family accent ≤3px(Strike `#E85A5A`/Control `#A66BC9`/Mobility `#5BA8E8`) | scale 0.8→1.0 ease-out cubic 120ms + flash;one-shot → 退 L3 ambient(static,無脈動) | `icon_flash_duration` 0.6s |
| **Silent-mode banner**(脈動豁免) | 細 banner「㩒一下開聲」,**非 HUD element** | `event_amber` text + 1px ink shadow | **alpha 脈動** 0.7±0.1 / period 2s(**唔用 scale**);unlock 即 fade 200ms | 至 unlock |

### 持續顯示三條
- **HP(MAX_HP)**:圓角橫矩形 **6px 高**(§3.C 最粗=最重要);**non-depleting**(顯示身體力量上限,唔做 deplete 動畫,避免讀成「受傷」焦慮);只喺 MAX_HP **升級**時 step 跳格。Fill `event_amber`。
- **EXP bar**:圓角橫矩形 **3px 高**(HP 50% 厚=次要);事件驅動跳格。
- **Boss HP**(BOSS_ENCOUNTER):圓角橫矩形,放 **screen 上方**(區隔玩家 HP);**depleting**(boss 受傷 deplete,同玩家 HP 語意相反,靠位置+行為區分);fill `event_amber` / empty `ui_ink_mid #2D323D`;退場即移除。⚠️ depleting(敵)vs non-depleting(玩家)留 `/ux-design` verify 唔混淆。

### Dim states(全部降 alpha/明度,**唔降飽和**——保 amber semantic,對齊 §4.D `ui_amber_dim`)
- DISCONNECTED → HUD alpha `base_dim 0.5`,**靜止**(無脈動避免讀成 error 焦慮)+ 可選 1px amber 離線 micro-icon。
- LOOT_DROP defer → HUD dim(建議 ×0.4 對齊 §4.E Loot World sat)+ 暫停所有 #20 motion,讓 #21 獨佔(§1.2 loot=金字塔頂)。
- SUSPENDED → ×0.7 + 凍結最後 frame(無 motion/fade,表「暫停而非斷開」)。

### Animation / 風格約束
- **Amber 張力平衡**:`event_amber #F2A93B` 永遠 100% 飽和,靠對比 `world_desaturation=0.7` 自動彈出,**唔靠 motion 搶眼**。張力釋放全喺事件瞬間,事件之間完全靜止——「色持續高張力,motion 瞬時低頻」= 存在但唔煩。禁 idle glow / 呼吸動畫(banner 例外)。
- **Outline/shadow**:HUD text/number **2px ink outline `#1A1D24`** 維持 shake 期間對比(`hud_shakes_with_world=true`)+ 1px hard shadow @40%(非 gaussian)。雙層保證 web Compatibility motion blur 下仍有 figure-ground 分離。
- **Font**:**MSDF font**(任何 scale crisp);數字用 monospace 變體避免跳格字寬抖動;中文用 Zpix style,禁 pixel+TTF 混排(§7.B)。

### 最直接 apply 嘅 art-bible principles
§1.2 P3 Layer Discipline(飽和=重要程度,#20 glanceability 根本)、§3.C/D UI Shape Grammar + Attention Hierarchy(HP 6px/EXP 3px;HUD rank 4 結構上唔搶 loot rank 2)、§7.A Frameless HUD(無框,depth 靠 contrast,服務 Silent Witness)、§7.D Snap+Settle+step ticker(motion personality 源頭)、§4.E Mood Override(`event_amber` 不受 mood saturation override,#20 dim 係 alpha 層,同 MoodController saturation 層正交)。

### #5 Particle
**#20 核心 HUD 唔需要 particle**——Control-node animation(Tween + shader rim flash)已足(particle budget 留俾 loot/combat;HUD particle 違「唔搶 loot attention」)。唯一可選:level-up spark `vfx_levelup_spark_micro.tres`(≤8 desktop/≤4 mobile),但 emit 喺 avatar sprite = **#26 AvatarRenderer territory,非 #20**;**MVP default 純 Control-node glow,particle defer**(#5/#26 coordination)。

### Audio co-trigger(SFX palette 屬 #4,#20 只觸發)
level-up flash white-peak frame = `set_complete` SFX attack onset(同 frame);EXP popup peak ≈ tick onset;unlock flash scale 到 1.0 frame = chime onset;banner fade-out 200ms 與第一 SFX 同步(視覺退場=聲音接手)。**原則**:visual attack/peak frame 永遠對齊 audio onset,唔可 visual 先行等 audio;silent-mode 下 visual 必須**獨立完整可讀**(SFX 係 enhancement 非 primary,§4.B)。

## UI Requirements

**Glance Hierarchy(0.3s 餘光接收優先次序;positioning + 視覺重量綁定層級)**

| 層 | Element | Positioning(建議,`/ux-design` 定案) | 視覺重量 | 接收方式 |
|---|---|---|---|---|
| **L1 餘光主層** | **HP**、**EXP** | 固定 corner anchor(建議 top-left),最大字、最高 amber 飽和、最穩定位置 | 最重:大、亮、full-saturation | **0.3s 餘光直讀**,Anchor moment 主角 |
| **L2 餘光次層** | PROG(set X/Y)·(BOSS_ENCOUNTER)BOSS HP | L1 鄰近、次級字號 | 中:常駐但低於 L1 | 餘光感知「進度感 / boss 緊張感」,細節留 L3 |
| **L3 對焦層** | STAT 明細 · SKILLS 列表 · 下一動作提示 · 剩餘組數 | 較密較細,**REST_PERIOD 先升起** | 低:平時 ambient/折疊 | **要對焦先讀**;只喺 REST_PERIOD 容許 |

**核心 UI 規則(可落 AC)**
- **80/20 法則**:L1+L2 喺餘光交付 ≥80% status;L3 只承載 20% confirmation detail,且**只喺 rest 對焦**。reward 必須喺餘光已被看到,唔可「對焦先解鎖」。
- **Motion 紀律**:L1/L2 只可事件驅動 motion,**禁持續跳動數字**(Anxiety Dashboard 主雷)。idle 時靜止。
- **Layer Discipline**:HUD full saturation;world −30%。L1 飽和 ≥ L2 ≥ L3,確保餘光天然落 L1。
- **位置恆定**:L1 anchor 位置**跨所有 GSM state 絕不移動**(餘光靠肌肉記憶,移位 = 要重新對焦 = 破 fantasy)。

**Banner placement**:silent-mode banner 非全屏遮蔽(banner 後 ambient HUD 已可見);hit-area 大 tap target;`focus_mode = FOCUS_NONE`(唔搶 keyboard focus,one-tap touch design 無 hover state)。

**平台適配**:web mobile/tablet primary;觸控 one-tap;HUD element 必須喺**無對焦下靠形狀/顏色/位置區分,唔可靠讀字**;MSDF font 支撐任何 DPI/scale;細螢幕 legibility 由 `/ux-design` + scalable-text(Theme base font size 一個 knob 全 HUD 縮放)保證。

**邊界**:本 section 只定 UI 原則 + glance 結構;**詳細 per-screen layout(element 確切座標、密度、aspect-ratio 響應、touch target 尺寸)屬 `/ux-design gym-mode-hud` 嘅 UX-spec 職責**,stories 應 cite `design/ux/gym-mode-hud.md` 而非本 GDD。

## Acceptance Criteria

> **Test evidence 分流**:Logic/Integration = **BLOCKING**(headless GUT 可驗);Visual/Feel/UI = **ADVISORY**(餘光可讀、glance、shake 可讀 = 體感,headless 驗唔到,要 screenshot/playtest + lead sign-off)。BLOCKED 標記 = 依賴 #33/#8/#21/#2-GDD 未 ready,wiring deferred,AC gated。

### A. Core Rules ACs

**AC-CR-1**(雙層架構 / reward 不鎖 Tier 2)— GIVEN HUD WORKOUT_ACTIVE、L1 已渲染,WHEN reward 事件(EXP 跳格 / ability flash)觸發,THEN reward 首發 surface 喺 L1 餘光層(非 L3),L3 唔係該 reward 唯一觸發點。 *Visual · `production/qa/evidence/` · **ADVISORY***

**AC-CR-2**(事件驅動 motion / 禁 idle 抖動)— GIVEN HUD idle(500ms+ 無 signal),WHEN 觀察 Tier 1 一個 idle 窗口,THEN 無 motion / 無跳秒數字(`set_process()==false`、tween count==0),每事件 motion ≤1s settle。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING**(視覺面 ADVISORY,`set_process(false)`+tween-count gate 取 BLOCKING 子集)*

**AC-CR-3**(signal-driven + pull-on-init / 禁每幀 poll / tween 自 gate)— GIVEN `_ready()` 完成,WHEN `stat_changed(stat_id=EXP)` push 到,THEN 只 EXP sub-widget redraw、全程無 `_process` 每幀 poll、tween 跑時 `set_process(true)` settle 後 `false`。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-4**(event-driven step / 5s gap 靜止)— GIVEN 收到 `set_progress_changed` 後進入 polling gap,WHEN 5s 內無新 event,THEN 顯示值 delta==0(無 `progress += elapsed`)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-5**(state-gated visibility / modal 退讓 / 拒 tap)— GIVEN GSM LOOT_DROP,WHEN apply 矩陣,THEN HP/EXP ○dim、PROG ▽defer、不渲染 loot 文字;且 `is_input_permitted()==false` 時 tap 唔被消費(early-return)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING**(input gate **BLOCKED on #33** — 見 AC-EC-S5)*

**AC-CR-6**(banner 顯示條件)— GIVEN `is_audio_unlocked()==false` 且離 Booting,WHEN 評估 BannerGate,THEN banner 顯示==true;GIVEN `is_audio_unlocked()==true`(desktop)THEN ==false(永不出現)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-7**(banner dismiss / session 永不再現)— GIVEN banner 顯示中,WHEN 首 tap 觸發 `audio_unlocked`,THEN one-shot dismiss、`banner_dismissed_this_session==true`;WHEN 之後 resume 重評,THEN 不重現(即使再 LOCKED)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-8**(soft-gate enforce — 核心)— GIVEN audio LOCKED soft-gate hold,WHEN `set_logged` 喺 unlock 前到,THEN workout 計數唔開始 / SFX 唔 forward(入 buffer);WHEN `audio_unlocked` 後,THEN 先 flush 再 count 後續、cursor 全程前進不丟。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-9**(audio consumer 訂閱 + play_sfx)— GIVEN `WorkoutAudioAdapter` wire 好,WHEN unlock 後 `set_logged` 到,THEN call `play_sfx(event_id)` 一次(spy count==1、event_id 正確)。 *Integration · `tests/integration/gym_mode_hud/` · **BLOCKING**(streak_chime 路由 **BLOCKED on #8** — 見 AC-EC-S6;整合測前須 **#2 GDD 補列 #20 subscriber**)*

**AC-CR-10**(buffer policy — cap 12 / low drop / flush)— GIVEN audio LOCKED,WHEN 14 個 mid/high event 連續到,THEN `_pending` size ≤12(FIFO drop oldest);low priority event 唔入 buffer(直接 drop);`audio_unlocked` 後 flush 至空。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-11**(stagger — 80–120ms)— GIVEN `set_complete`×`streak_chime` 同幀,WHEN consumer 處理,THEN 先 `play_sfx(set_complete)`、`streak_chime` defer `set_streak_chime_stagger_ms`(100,∈[80,120])後播;`AudioManager` 側無 delay。 *Logic(fake-time/SceneTreeTimer spy)· `tests/unit/gym_mode_hud/` · **BLOCKING**(BLOCKED on #8 — 同幀並存需 #8 chime 路由)*

**AC-CR-12**(數據語意 — HP non-depleting / 技能 source)— GIVEN HUD 渲染,WHEN 讀 HP 來源,THEN HP fill 綁 `get_stat(MAX_HP)`(非 depleting,只 MAX_HP 升級時 step);技能列表==`get_unlocked_abilities()`(無 fabricated current-HP)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-13**(Pillar 2 紅線 8 條 — 複合,逐項分流):① 禁 mid-set 互動攞 reward / ④ reward 禁鎖對焦層 → **AC-CR-1**(ADVISORY);② 禁祈使句 → *UI · `production/qa/evidence/` copy walkthrough · **ADVISORY***;③ 禁 idle motion → **AC-CR-2**;⑤ Tier 1 ≤5 → *Logic design-time count gate · **ADVISORY**(EC-S7 runtime 唔 auto-hide)*;⑥ modal 退讓 → **AC-CR-5**+**AC-EC-S3**;⑦ 尊重 `is_input_permitted()` → **AC-CR-5**(**BLOCKED on #33**);⑧ shake 期間 Tier 1 可讀 → *Visual/Feel · `production/qa/evidence/` shake screenshot · **ADVISORY***。

### B. Formula ACs

**AC-F1**(exp_fill — F1)— GIVEN `340/500` THEN `exp_fill==0.68`;`500/500` THEN `1.0`;`exp_to_next=0`(EC-F1)THEN `max(0,1)=1`、fill==1.0 無 NaN;`current_exp=-5`(EC-F3)THEN sanitize 後 0.0。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-F2**(tween_duration — F2)— GIVEN `reduce_motion==false` THEN `==base(0.3)`;`==true` THEN `==0.0`(瞬間 set)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-F3**(banner_alpha — F3 + 邊界 + unlock kill)— GIVEN `base=0.7,amp=0.1,period=2.0`,`t=0.5` THEN `≈0.8`(峰,±0.001);`t=1.5` THEN `≈0.7`(谷);`t` 極大(EC-F6)用 `fmod` THEN ∈[base,base+amp] 不溢出;`audio_unlocked` emit THEN pulse tween 即 `kill()`。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING**(脈動「搶餘光」屬視覺,另見 AC-V-3)*

### C. Edge Case ACs(高 severity)

**AC-EC-R4**(CRITICAL — unlock × WORKOUT_ACTIVE 同幀 ordering)— GIVEN `audio_unlocked` 同 `state_changed→WORKOUT_ACTIVE` 同幀,WHEN 處理,THEN **固定先** unlock→flush→解 soft-gate **再** apply 矩陣;斷言首組 SFX flush(call count>0)先於 count-start。 *Logic(同幀注入兩 signal 斷言序)· `tests/unit/gym_mode_hud/` · **BLOCKING**(最高優先,CR-8 核心)*

**AC-EC-A1**(LOCKED 全程冇 tap — cap 12)— GIVEN 全程 LOCKED 從未 tap,WHEN 20 個 `set_logged` 到再 `_exit_tree`,THEN `_pending` 全程 ≤12、永不 flush、`_exit_tree` 後清空(無 dangling `play_sfx`)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-R2**(同 stat_id tween 未完又新事件)— GIVEN EXP tween 跑緊(t=0.15),WHEN 新 `stat_changed(EXP)` 到,THEN kill 舊 tween、由當前 interpolated 值 restart(無回跳/無疊);`reduce_motion==true` THEN 直接 snap。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-A4**(stagger timer 未 fire 就 suspend/exit)— GIVEN deferred `streak_chime` timer(100ms)未 fire,WHEN `_exit_tree` 或進 Suspended,THEN guard 檢查(in-tree && 非 Suspended)不滿足則 drop(call count==0)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-S9**(resume reconcile — 一次 snap / 唔重播)— GIVEN freeze@WORKOUT_ACTIVE、resume@LOOT_DROP,WHEN pageshow reconcile,THEN pull 真值後一次性 snap、apply LOOT_DROP 矩陣、banner 防重彈、SFX 唔 double-flush。 *Integration · `tests/integration/gym_mode_hud/` OR documented playtest · **BLOCKING***

**AC-EC-S1**(BannerGate 期間 GSM 已 WORKOUT_ACTIVE — HUD 不阻 GSM)— GIVEN BannerGate hold、GSM 自行進 WORKOUT_ACTIVE,WHEN 觀察,THEN ambient 已顯示、soft-gate 仍 hold(`set_logged` 入 buffer)、**GSM 前進不被 HUD 阻**;首 tap 後解 gate+flush。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-S4**(DISCONNECTED 期間 set_logged — 聲行視覺靜)— GIVEN GSM DISCONNECTED 期間 `set_logged` 到,WHEN 處理,THEN SFX 照 buffer/播(忠於真實動作)、視覺維持 dim 不彈 popup(忠於斷線)。 *Logic(雙 channel 斷言)· `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-F4**(NaN/INF 唔餵 Tween)— GIVEN `exp_fill` 計出 NaN/INF,WHEN guard,THEN fallback 用上一 confirmed、唔 redraw、log 一次、唔餵 NaN 入 Tween(防永不 settle 燒 CPU)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

### D. Visual / Feel / UI ACs(天然 ADVISORY — headless 驗唔到)

**AC-V-1**(餘光 0.3s 可讀 — Glance Hierarchy)— GIVEN HUD WORKOUT_ACTIVE,WHEN tester 力竭 / shake 模擬下 0.3s 餘光掃過,THEN L1(HP/EXP)交付 ≥80% status、L1 飽和 ≥ L2 ≥ L3、L1 anchor 跨所有 state 不移動。 *Visual/Feel · `production/qa/evidence/`(多 state screenshot + lead sign-off)· **ADVISORY** — ⚠️ untestable headlessly,須 glance playtest protocol(限時曝光 + 主觀問卷)*

**AC-V-2**(shake 期間 figure-ground)— GIVEN `hud_shakes_with_world==true` 世界 shake 中,WHEN 餘光讀數字,THEN 2px outline + 1px shadow 維持 figure-ground(數字可讀)。 *Visual/Feel · `production/qa/evidence/`(shake 截圖/錄影 + lead sign-off)· **ADVISORY***

**AC-V-3**(banner 邀請感非搶注意)— GIVEN banner 脈動中(F3),WHEN tester 觀察,THEN 讀成「呼吸/邀請」非「抖動/緊張」,唔搶餘光。 *Visual/Feel · `production/qa/evidence/`(錄影 + lead sign-off)· **ADVISORY***

**AC-V-4**(world desaturation 對比)— GIVEN world −30% sat、HUD full saturation,WHEN 截圖比對,THEN HUD amber 自然彈出(對比足、世界仍可辨識)。 *Visual · `production/qa/evidence/` · **ADVISORY***

**AC-U-1**(banner copy 零祈使句)— GIVEN banner + 所有 PROG copy,WHEN copy walkthrough,THEN 無祈使句 / CTA(「㩒一下開聲」屬邀請非命令)。 *UI · `production/qa/evidence/` copy walkthrough · **ADVISORY***

**AC-U-2**(REST_PERIOD 唯一對焦窗)— GIVEN GSM REST_PERIOD,WHEN apply 矩陣,THEN L3(STAT/SKILLS/下一動作/剩餘組數)surface 升起;非 REST_PERIOD state L3 維持 ambient/折疊。 *UI(visibility-flag 可部分 headless)· `production/qa/evidence/` walkthrough OR `tests/unit/` · **ADVISORY***

### E. Untestable / BLOCKED 標記彙總(QA gate 用)

**Untestable headlessly(ADVISORY,須 playtest + lead sign-off)**:AC-V-1(0.3s 餘光 / 80% status — 最需主觀評分)、AC-V-2/3/4、AC-CR-1、AC-CR-13⑧。

**BLOCKED(依賴未 ready,sprint 前須確認 dep 狀態)**:
- **#33**(Not Started):AC-CR-5 input-gate / AC-CR-13⑦。Prov-4 fallback = **AC-EC-S5**。
- **#8 expose**(Prov-3):AC-CR-9 streak 路由 / AC-CR-11 stagger 同幀。fallback = **AC-EC-S6**。
- **#2 GDD bidirectional**:AC-CR-9 整合測前須 #2 補列 #20 為 `set_logged` subscriber。
- **#21**(Not Started):**AC-EC-S3** defer 行為 self-contained 可測,#21 對接 deferred。

**Deferred-dep fallback ACs(dep ready 前可獨立過,BLOCKING self-contained)**:
- **AC-EC-S5**:GIVEN #33 未 implement,WHEN banner tap,THEN 走「直接 tap→unlock」、banner-unlock tap 永遠豁免 `is_input_permitted`。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***
- **AC-EC-S6**:GIVEN #8 streak signal 未 expose,WHEN `set_complete` 到,THEN 即播無 stagger(CR-11 邏輯休眠),唔因等唔存在嘅 chime 而 defer。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***
- **AC-EC-S3**:GIVEN GSM LOOT_DROP 但 #21 未 ready,WHEN apply 矩陣,THEN HUD 主動 defer、絕不 fallback 自畫 loot 文字。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

### Coverage 自檢
- 每條 CR ≥1 AC(CR-1→AC-CR-1 … CR-13→8 項分流)✅
- 每條 formula ≥1 testable AC(F1→AC-F1 / F2→AC-F2 / F3→AC-F3,全 BLOCKING Logic)✅
- 指定 BLOCKING logic ACs 齊(CR-8 / CR-10 / CR-11 / EC-R4 CRITICAL ordering)✅
- 餘光/shake/glance 明確 ADVISORY(AC-V-1/2/3/4 + AC-CR-1 + AC-CR-13⑧)✅

> **QA flag**:AC-V-1「0.3 秒餘光讀 80% status」係 Player Fantasy 命脈但 headless 完全驗唔到 → `/ux-design gym-mode-hud` 階段必須定 glance playtest protocol,否則此條淪為 hand-waving。Sprint `/story-readiness` 須 re-check #33/#8/#2-GDD/#21 四個 dep 狀態。

## Open Questions

| ID | 問題 | Owner | Target resolution | 現狀 / 暫定 |
|----|------|-------|-------------------|-------------|
| **Q-OQ1** | #8 Streak 要為 #20 expose 「streak_chime 將 fire」signal,令 #20 可 stagger `set_complete`×`streak_chime`(CR-11) | #8 Streak GDD + #20 | #8↔#20 co-design,sprint 前 | Prov-3。fallback **AC-EC-S6**(未 expose 時 set_complete 即播無 stagger)self-contained 可過 |
| **Q-OQ2** | #33 Attention Budget `is_input_permitted()` 未 implement(#33 Not Started),#20 input gating wiring deferred | #33 GDD | #33 author 後 | Prov-4。fallback **AC-EC-S5**(banner tap 直接 unlock,豁免 gating)可過 |
| **Q-OQ3** | Current-HP depleting bar 嘅 runtime owner 不存在(#13 pure static)。MVP HP=MAX_HP 顯示已定;depleting bar 何時/由邊個 system own? | game-designer / 新 combat-runtime-state owner | post-MVP(可折入 #25 Combat Visual Feedback) | 已拍板 MVP 唔做 depleting,唔 fabricate(CR-12)|
| **Q-OQ4** | Equip slot 概念(已裝備 vs 已解鎖技能)。MVP 顯示 `get_unlocked_abilities()` | #30 Skill Tree(v0.2) | v0.2 | 已拍板 equip deferred(CR-12)|
| **Q-OQ5** | #2 GymSys GDD 須補列 #20 為 `set_logged` subscriber(bidirectional gap)| #2 GDD | architecture / sprint 前 | AC-CR-9 整合測前置;#18 PR-Detection 先例 |
| **Q-OQ6** | #21 Loot Drop Modal(Not Started)對接:#20 LOOT_DROP defer handshake 細節 | #21 GDD | #21 author 後 | defer 行為已定(EC-S3),#21 ready 後對接;fallback AC-EC-S3 可過 |
| **Q-OQ7** | `reduce_motion` 應否 derive 自 #6 `motion_intensity` a11y slider(避免兩個獨立 a11y toggle)| #20 + #6 + master 場景 | `/ux-design` 階段 | co-design flag;Tuning Knobs Referenced 已記 |
| **Q-OQ8** | Level-up spark particle(`vfx_levelup_spark_micro.tres`)emit 喺 avatar sprite = #26 territory | #5 / #26 coordination | polish-pass | MVP default 純 Control-node glow,particle defer |
| **Q-OQ9** | AC-V-1「0.3s 餘光讀 80% status」headless 驗唔到,須定 glance playtest protocol(限時曝光 + 主觀問卷)否則淪為 hand-waving | qa-lead + ux-designer | `/ux-design gym-mode-hud` | QA flag;Player Fantasy 命脈 |
| **Q-OQ10** | Boss HP(敵,depleting)vs HP(玩家,MAX_HP non-depleting)語意相反,靠位置+行為區分,須 verify 唔混淆 | ux-designer | `/ux-design gym-mode-hud` | art-director flag |
