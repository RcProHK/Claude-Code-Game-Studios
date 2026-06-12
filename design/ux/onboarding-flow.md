# UX Spec: Onboarding Flow

> **Status**: In Design
> **Author**: Frank + ux-designer（degraded-inline — specialist spawn credit-limited;grep-verified against GDD `design/gdd/onboarding-flow.md`[APPROVED 2026-06-11] + game-concept L106/L191-214 + accessibility-requirements + interaction-patterns catalog + #24/#21/#26 host/sibling specs）
> **Last Updated**: 2026-06-12（Story 015 — 5 advisory carry resolved）
> **Journey Phase(s)**: First-run onboarding（game-concept L106「首 5 分鐘 onboarding curve」）— 無 `design/player-journey.md`（gap,見 Open Questions）
> **Platform Target**: Web (primary — HTML5/WASM, Godot Compatibility renderer) + Desktop (secondary)；one-tap touch + mouse。Coach-mark peripheral anchor 須喺 16:9 / 4:3 / portrait 都唔遮中央 one-tap 互動區（見下方 Acceptance Criteria 補充 AC-UX-13/14/15/16,Story 015 advisory carry）。
> **Template**: UX Spec
> **Source GDD**: [onboarding-flow.md](../gdd/onboarding-flow.md)（#27,Polish/Pre-MVP;`OnboardingCoordinator` autoload + `OnboardingOverlayLayer` CanvasLayer）

---

## Purpose & Player Need

Onboarding Flow 嘅 UX 服務一個 player need:**「我第一次開 Mirror Hero,要喺五分鐘內無人塞 tutorial wall 之下睇得明點玩」**。佢唔係一個「screen」,係一條 **overlay flow** —— 一層薄 coach-mark + 一段非綁定 preview,疊喺既有 game surface（#24 login / world combat / #21 loot ceremony）之上,**永不取代任何既有 surface,永不 block 玩家**。

呢個 spec 涵蓋 4 個 in-context surface（GDD Rule 3 四步）:

1. **Welcome coach-mark**（Step 1,connect 成功後一句歡迎)
2. **Combat preview「試演」screen**（Step 2,非綁定 auto-fight + watermark + skip)
3. **Muscle=class coach-mark**（Step 3,首個 dominant class 着燈)
4. **First-drop framing coach-mark**（Step 4,首爆裝 ceremony dismiss 之後)

冇咗呢層,玩家會喺一個無解釋嘅 auto-combat 世界面前一頭霧水(唔知點解角色自己打、點解今日係 STRIKE、幾時爆裝)。UX 嘅核心使命:**用最少嘅 pixel + 最克制嘅手勢交付清晰,做完即退場**。引路人,唔係主角。

**UX 命脈(對應 GDD 兩條設計命脈)**:
- **Pillar 2 — 零阻塞**:每個 surface 對「呢個會唔會逼玩家停低先繼續?」必須 NO。無 modal、無 "Next>"、無確認對話。
- **Pillar 1 — 唔呃**:preview **必須**有「試演」watermark(玩家一眼知唔係真 progress);首件裝備係真 #15 drop,UX 只加 framing 唔 fabricate。

---

## Player Context on Arrival

| 維度 | 狀態 |
|---|---|
| **何時首遇** | 第一次開 game(`onboarding.completed != true`),由 #24 login surface 起步 |
| **之前做緊咩** | 啱啱開 app / 連接 GymSys 帳號(可能喺屋企,可能喺 gym mid-workout — EC-01/EC-02) |
| **情緒狀態** | **好奇 + 輕微唔確定**(「呢個 game 點玩?」)—— 唔係 time-pressured,唔係 stressed。設計假設玩家願意睇,但**唔耐煩被 hand-hold** |
| **自願 vs 被送** | 自願開 app;coach-mark 係 game **主動**遞上(玩家無 request),所以更要克制 —— uninvited hint 必須 peripheral + 即可 dismiss |
| **注意力預算** | Onboarding 永不喺 workout-critical state(`WORKOUT_ACTIVE`/`REST_PERIOD`/`LOOT_DROP`)出現 → 玩家睇 coach-mark 時必然喺 idle/landing,有 spare attention(#33 zero carve-out) |

**關鍵張力**:coach-mark 係 **uninvited**(game 主動遞),所以 UX 紀律比玩家主動打開嘅 screen 更嚴 —— 任何 pulse / gaze-grab / audio 都會變成「打斷」。教學係**狀態**(玩家想睇就睇),唔係 **urgency gesture**。

---

## Navigation Position

Onboarding **唔住喺 navigation hierarchy 入面** —— 佢冇自己嘅 menu entry、冇 route、玩家**唔可以主動導航去**。佢係一條 **event-driven overlay flow**,由 coordinator 喺特定 game-state edge 自動疊現:

```
[App boot] → #24 Login Shell (host surface)
                  └─ OnboardingOverlayLayer (coach-mark 疊喺現有 surface 之上,event-driven)
                        ├─ Step 1 welcome  ← GSM landing edge
                        ├─ Step 2 preview  ← post-connect, pre-workout
                        ├─ Step 3 class    ← #9 dominant_class_changed
                        └─ Step 4 first-drop ← #21 modal_dismissed(terminal)
```

**唯一入口 = first-run boot**;**唯一出口 = 四步完成 → 永久 DORMANT**。完成後玩家**無法重訪**(MVP 無「重睇教學」,Q-OB-4 deferred)。Onboarding 係 navigation graph 上一條 **transient 首遇路徑**,行完即從圖上消失。

---

## Entry & Exit Points

### Entry（玩家點樣「到達」每個 surface — 全 event-driven,非玩家導航）

| Entry Source | Trigger | 玩家攜帶 context |
|---|---|---|
| App first boot | `onboarding.completed != true` + `step_connect != true` → FSM 入 `WELCOME` | 全新玩家,未連 GymSys |
| Connect 成功 | GSM 離 `BOOTING` 落 landing + #2 session established | 帳號連好,avatar 即將首現 |
| Post-connect, pre-workout | `step_connect` latched + 無 active workout → FSM 入 `PREVIEW` | 想睇「個 game 點打」 |
| 首個真實 dominant class | `#9 dominant_class_changed(known_class)` 首 fire | 啱啱做完(或做緊)第一個 workout set |
| 首次 loot ceremony 終結 | `#21 modal_dismissed(drop_id, terminal=true)` 首 fire | 啱啱睇完人生第一件爆裝 |

### Exit（玩家點樣離開每個 surface）

| Exit Destination | Trigger | Notes |
|---|---|---|
| Coach-mark 消失（回到底層 surface） | tap-anywhere **或** auto-dismiss timer（`coach_auto_dismiss_sec` 6s） | 非 irreversible — step latch as done,但底層 game 一直在 |
| Preview 退場 | preview 播完 / 玩家 skip / 真實 workout abort（EC-03） | cross-fade 退場,唔 hard cut;`step_preview` latch |
| **永久 DORMANT（onboarding 退場）** | 四 step latch 全 set → `onboarding.completed = true` | **⚠️ one-way** — 玩家無法返轉頭重睇 onboarding(MVP) |
| 真實優先 interrupt | preview 期間 `#9 workout_started_forwarded` fire → preview 即 abort | 真實 workout 接管底層 surface,onboarding 讓位 |

**唯一 irreversible exit = DORMANT**(GDD Rule 2 idempotent,backend-primary persist 跨 device)。所有 coach-mark dismiss 都係軟性(skip = 合法完成,Rule 7),但合起來推到 DORMANT 就唔可逆。

---

## Layout Specification

### Information Hierarchy

Onboarding 每個 surface 只傳 **一個 idea**(克制 = Pillar 2)。全 flow 優先級:

1. **(最高)底層 game surface 永遠可見可玩** —— coach-mark 永不遮關鍵互動(login button / next-exercise tap / loot ceremony)。Onboarding 嘅 #1 規則就係**唔搶**。
2. **當前 coach-mark 嘅一句 copy** —— peripheral,貼近相關 element,一眼讀完。
3. **Dismiss affordance** —— tap hint glyph 或自然 auto-fade(玩家知「撳邊都走得」)。
4. **(preview 專屬)「試演」watermark** —— 持續可見,Pillar 1 護欄(玩家知唔係真)。
5. **(最低,可被發現非即顯)skip affordance** —— preview 角落,想跳就跳。

**單一 slot 紀律**:同時最多一個 coach-mark(Formula 1 `no_other_coachmark_visible`;EC-13 兩 trigger 同 frame → 按 step order 排隊)。

### Layout Zones

Onboarding overlay 用 **peripheral-anchored** zone model(對齊 #24 banner / P-17 紀律 —— 教學住喺視覺邊陲,中央留畀 game):

```
┌─────────────────────────────────────────┐
│  [top-center]  ← Step 3 class coach-mark │   ← 貼近 class indicator / avatar
│                                          │
│         （底層 game surface              │
│           — login / world / loot —       │   ← CENTER 永遠係 game,onboarding 唔住中央
│            永遠可見可玩）                 │
│                                          │
│  Step 4 first-drop →  [near loot region] │   ← 貼近剛收嘅 loot 區
│  [bottom peripheral] ← Step 1 welcome    │   ← 近 avatar(「睇下你個角色」)
└─────────────────────────────────────────┘
```

Preview screen 例外（佔較大畫面但仍非綁定）:

```
┌─────────────────────────────────────────┐
│ ⓘ 試演 / Preview          [⏭ Skip ≥44px] │  ← watermark 角落常駐 + skip
│                                          │
│      （avatar auto-fight scripted wave   │
│        — 借既有 combat render —          │
│         non-binding cosmetic showcase）  │
│                                          │
│  ▒▒▒▒ 試演 watermark 半透重複 ▒▒▒▒       │  ← 防止「以為真」(Pillar 1)
└─────────────────────────────────────────┘
```

### Component Inventory

| Zone | Component | 類型 | Content | 互動? | Pattern |
|---|---|---|---|---|---|
| peripheral(近 avatar) | Welcome coach-mark card | 細高飽和 text card | 「連好喇 — 睇下你個角色」 | tap-dismiss | **`coach-mark`(新 pattern)** |
| top-center / 近 class indicator | Class coach-mark card | 細 text card | 「你今日做緊推 → **STRIKE** 着燈」(class 着色) | tap-dismiss | **`coach-mark`(新)** + 借 [P-06 rarity-color-tier](interaction-patterns.md#p-06-rarity-color-tier) class-color 慣例 |
| 近 loot region | First-drop coach-mark card | 細 text card | 「頭先爆嗰件係你真實做嘢換返嚟 — 以後日日做日日有」 | tap-dismiss | **`coach-mark`(新)** |
| preview 角落 | 「試演」watermark | 持續 badge + 半透 repeat overlay | 「ⓘ 試演 / Preview」 | 非互動(資訊) | **`preview-watermark`(新 pattern)** |
| preview 角落 | Skip affordance | tappable button ≥44px | 「⏭ Skip」 | tap → skip preview | borrow #21 dismiss-target 尺寸慣例 |
| preview 中央 | Auto-fight showcase | 借既有 combat render | scripted dummy wave(零真實) | 非互動(觀賞) | 借 #25/#14 combat render,**零 enemy_killed/loot** |
| (全 overlay) | `OnboardingOverlayLayer` | CanvasLayer host | pre-warmed hidden | — | layer 數值 epic-time G-OB-3(captured band <100,R-2) |

**新 pattern 旗(epic-time 入 `interaction-patterns.md`)**:
- **`coach-mark`** — peripheral dismissible in-context teaching hint;零 animation/pulse/audio(教學係狀態非 urgency,鏡 P-17 restraint);單 slot;tap-anywhere + auto-dismiss;workout-critical defer;announce_aria polite。
- **`preview-watermark`** — 非綁定「試演」標示(持續角落 badge + 半透 repeat),令觀賞性 showcase 同真實 progress 視覺區隔(Pillar 1 anti-deception)。

### ASCII Wireframe

**Step 1 — Welcome coach-mark(疊喺 #24 login landing)**:
```
┌───────────────────────────────────────┐
│   (#24 login shell — connected state)  │
│                                        │
│            [ avatar 首現 ]             │
│         ╭──────────────────╮           │
│         │ 連好喇 — 睇下你   │  ← coach  │
│         │ 個角色      (tap) │    peripheral
│         ╰──────────────────╯    近 avatar│
└───────────────────────────────────────┘
```

**Step 2 — Preview「試演」**:
```
┌───────────────────────────────────────┐
│ ⓘ 試演 / Preview            [⏭ Skip]   │
│                                        │
│      🗡 avatar  ⚔  ▶ dummy enemy        │
│         (auto-fight scripted wave)     │
│   ░ 試演 ░ ░ 試演 ░ ░ 試演 ░  (半透)    │
└───────────────────────────────────────┘
```

**Step 3 — Class coach-mark(非 mid-set;GSM = IDLE/landing)**:
```
┌───────────────────────────────────────┐
│  ╭────────────────────────╮            │
│  │ 你今日做緊推 → STRIKE   │ ← top-center│
│  │ 着燈           (tap)    │   近 class   │
│  ╰────────────────────────╯   indicator │
│         [ world / avatar ]             │
└───────────────────────────────────────┘
```

**Step 4 — First-drop framing(loot ceremony **dismiss 之後**,唔疊 sacred surface)**:
```
┌───────────────────────────────────────┐
│       [ #21 loot modal 已 dismiss ]    │
│              [ loot region ]           │
│    ╭──────────────────────────╮        │
│    │ 頭先爆嗰件係你真實做嘢    │ ← 近    │
│    │ 換返嚟 — 日日做日日有(tap)│   loot 區│
│    ╰──────────────────────────╯        │
└───────────────────────────────────────┘
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Default(coach-mark 可顯示)** | FSM 非 DORMANT + step 未 latch + GSM 非 workout-critical + 無其他 coach-mark(Formula 1 `may_show=true`) | 對應 step coach-mark fade-in(`coach_fade_sec`) |
| **Deferred(workout-critical)** | GSM ∈ {`WORKOUT_ACTIVE`,`REST_PERIOD`,`LOOT_DROP`}(B-1 fix:全 #1 GSM) | coach-mark **唔顯示**,保持 pending,state 清返先補顯(AC-10);**永不 mid-set 出現** |
| **Stale-defer(teachable moment 過咗)** | defer 超過 `coach_max_defer_sec` 120s 仍無 window | **silent latch 該 step**(唔顯示過時教學,EC-12)— Pillar 2:過時 hand-holding 比唔教仲差 |
| **Preview-playing** | FSM `PREVIEW` + scene load 成功 | auto-fight showcase + watermark + skip 全顯 |
| **Preview-failed(退化)** | preview scene/asset load 失敗(EC-15) | **graceful skip** —— `step_preview` latch、零 crash、零空白屏,直入 COACHING |
| **Real-workout-override** | preview 期間 `#9 workout_started_forwarded`(EC-03) | preview 即 abort + cross-fade 讓位真實 combat;`step_preview` latch as done-by-workout |
| **UNKNOWN-class defer** | `dominant_class_changed(UNKNOWN)`(EC-11) | Step 3 **唔顯示「UNKNOWN 着燈」**,等 known class 或 generic copy「你嘅訓練決定你嘅 class」 |
| **Reduced-motion** | OS/app reduced-motion(`coach_fade_sec → 0`) | coach-mark 硬切無 fade;preview 仍可播但無多餘 transition |
| **Coach-marks-disabled** | `coach_marks_enabled = false`(a11y escape hatch) | 全部 step **silent latch**,純靠既有系統教學;onboarding 退化成 latch tracker |
| **DORMANT(terminal)** | 四 step latch 全 set | 零 surface、零 subscription、`OnboardingOverlayLayer` 永久 hidden |

---

## Interaction Map

> Input methods(`technical-preferences.md`):**Touch primary(single-tap)** + Keyboard/Mouse secondary;**無 gamepad**;Web primary。Onboarding 全部互動 = single-tap,零 hover-only、零 drag、零 hold。

| Component | Action | Touch / Mouse / Keyboard | 即時 feedback | Outcome |
|---|---|---|---|---|
| 任何 coach-mark | **tap-anywhere dismiss** | screen tap / 左 click / `Esc` 或 `Enter` | coach-mark fade-out(`coach_fade_sec`) | dismiss + step latch(AC-12,先於 auto-timer) |
| 任何 coach-mark | **auto-dismiss(無互動)** | (無 input;timer) | 過 `coach_auto_dismiss_sec` 後 fade-out | dismiss + step latch(Formula 2,AC-11) |
| Preview Skip button | **tap skip** | tap / click(≥44px target) / `Esc` | button press feedback + preview cross-fade 退場 | `step_preview` latch、轉 COACHING |
| Preview showcase | **觀賞(非互動)** | (無 input) | auto-fight 自己打 | 純 cosmetic;**唔接受任何 gameplay input**(`mouse_filter = IGNORE` 防偷玩家 one-tap — 對齊 #25 UX-06) |
| 底層 game surface | **正常 game 互動** | (passthrough) | game 自己處理 | coach-mark overlay **唔截**底層 input(login button / next-exercise tap 永遠可達) |

**關鍵互動紀律**:
- **Input non-interference(命脈)** —— coach-mark overlay 嘅非互動區 `mouse_filter = IGNORE`,只有 coach-mark card 本身 + skip button 食 tap;**底層 game 嘅 single-tap(next-exercise / login)永不被 onboarding overlay 偷**。
- **Tap-anywhere = 玩家主導** —— 撳邊都 dismiss(玩家唔使搵細 X)。Pillar 2:玩家話事。
- **零 hold / 零 drag / 零 multi-touch** —— 對齊 one-tap input design(technical-preferences)。

---

## Events Fired

> Onboarding 係 **observe-only consumer-forward**(GDD Rule 8) —— **唔 emit gameplay event、唔 request GSM transition、唔 trigger loot**。佢只寫自己嘅 `onboarding.*` latch + (optional)analytics。

| Player Action / Trigger | Event Fired | Payload / Data |
|---|---|---|
| Welcome coach-mark dismiss | (persist)`onboarding.step_connect = true` | bool latch,#3 PersistenceLayer,`onboarding.*` namespace |
| Preview 完成 / skip / abort | (persist)`onboarding.step_preview = true` | bool latch |
| Class coach-mark dismiss | (persist)`onboarding.step_class = true` | bool latch |
| First-drop coach-mark dismiss | (persist)`onboarding.step_first_drop = true` | bool latch |
| 四 step latch 全 set | (persist)`onboarding.completed = true` | bool latch → DORMANT |
| (any step shown / skipped) | **(optional)** `onboarding_step_completed` analytics | `{step_id, method: shown\|skipped\|auto, ms_since_boot}` — **epic-time #28 Telemetry 接,MVP 可 no-op** |
| 底層 game 互動 | **none(onboarding 唔 emit)** | game event 由底層系統自己 fire,onboarding 零干預 |

**⚠️ 架構注意(persistent state 寫入)**:onboarding **只**寫 `onboarding.*` namespace bool latch(backend-primary,ADR-0003)。**零** gameplay namespace 寫入(`loot.*`/`stat.*`/`ability.*`/`streak.*`)—— CI lint **G-OB-2** 守(`tools/ci/check_onboarding_no_gameplay_mutator.gd`)。呢個係 Pillar 1 命脈,唔係 UX 自由度。

---

## Transitions & Animations

| Transition | 行為 | 時長 |
|---|---|---|
| **Coach-mark enter** | fade-in(opacity 0→1)+ 輕微 ease;**零 slide-in、零 pulse、零 scale-bounce**(克制,鏡 #24 banner / P-17) | `coach_fade_sec` 0.25s（reduced-motion → 0 硬切） |
| **Coach-mark exit** | fade-out(opacity 1→0) | `coach_fade_sec` 0.25s |
| **Preview enter** | cross-fade 入場(唔 hard cut) | ~0.3s |
| **Preview exit** | cross-fade 退場讓位底層(完成 / skip / abort 皆同) | ~0.3s |
| **State-change(defer→show)** | coach-mark 喺 workout-critical 清返後 fade-in 補顯 | `coach_fade_sec` |
| **Real-workout abort** | preview cross-fade 退,真實 combat render 接管 | 即時讓位(≤1 frame 後底層接手) |

**Motion safety(命脈)**:全部 transition 純 **opacity fade**,**零 motion / 零 parallax / 零 zoom** —— reduced-motion 模式 `coach_fade_sec → 0` 硬切即可,**無任何會引起 motion sickness 嘅效果**(WCAG 2.3.x;對齊 accessibility-requirements Motion Safety tier)。Preview 嘅 combat render motion 由 #25/#14 既有 motion_intensity 系統管(非 onboarding 新增 motion)。

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| `onboarding.*` latch(completed/step_connect/preview/class/first_drop) | #3 PersistenceLayer(`onboarding.*` namespace) | **Read + Write** | 唯一 write target;backend-primary ADR-0003;onboarding owns 呢 5 個 key |
| GSM current state | #1 GSM `state_changed`(connect_for_initial_state,ADR-0006 C6) | Read | landing 偵測 + workout-critical gating;**永不 request transition** |
| Connect/session established | #2 GymSysClient(經 #1/#24) | Read | `step_connect` 觸發;connect-detection signal 確切 edge = Q-OB-6 epic-time |
| `dominant_class_changed(new_class:int)` | #9 WST | Read | Step 3 trigger;可 carry UNKNOWN(EC-11 defensive) |
| `workout_started_forwarded()` | #9 WST | Read | 真實優先 interrupt(EC-03) |
| `modal_dismissed(drop_id, terminal)` | #21 Loot Drop Modal | Read | Step 4 trigger(首 terminal dismiss) |
| `get_class_for_exercise(id) -> int` + class taxonomy | #10 Exercise→Class | Read(lookup) | Step 3 teaching copy(STRIKE/CONTROL/MOBILITY);read-only static config |
| Coach-mark copy(localized string) | onboarding data-driven config | Read | 廣東話口語 witness 語氣(同 #24/#20 register);**唔係 tuning knob** |
| Preview scripted wave 內容 | preview scene config(Q-OB-1) | Read | MVP zone-1 enemy + CF-1 auto-unlock TIER_1 ability showcase |

**架構 flag**:onboarding **唔 own 任何 gameplay state** —— 純 read upstream + write 自己 `onboarding.*` latch。零 UI-owns-game-state(對齊 thin-orchestrator 定位)。所有 read interface 照用 as-is(consumer-forward,零 upstream patch)。

---

## Accessibility

> Tier:**WCAG AA Core + Motion Safety**(accessibility-requirements.md L12)。

- **Contrast** — coach-mark text 用既有高飽和 palette:warm-white `#F5EFE0` / amber `#F2A93B` on ink-bg `#1A1D24`（~11:1 / ~8.5:1,AAA;CJK Zpix 12px+ AA)。WCAG AA contrast 全 text element 達標。
- **Tap target** — skip button + coach-mark dismiss target ≥44px(touch primary);tap-anywhere dismiss 令整屏可 dismiss(超大 target)。
- **Color-independent** — class coach-mark 唔可只靠顏色傳「STRIKE」—— copy **明寫 class 名**(「STRIKE 着燈」),顏色係 enhancement channel 非 load-bearing(對齊 art-bible colorblind 雙-channel 規則)。
- **Reduced-motion** — `coach_fade_sec → 0` 硬切;全 transition 純 opacity 無 motion(Motion Safety tier 達標)。
- **Motion sickness** — 零 parallax/zoom/slide;preview combat motion 受 #25/#14 motion_intensity 管(=0 → 無 shake)。
- **Screen reader** — coach-mark text 經 `announce_aria(text, polite)`(polite region,唔搶;對齊 #24/#19 announce_aria 先例)。Preview「試演」watermark 亦 announce「試演 / Preview, 非真實 progress」。
- **Escape hatch** — `coach_marks_enabled = false` 全關 coach-mark(a11y / 重玩測試);step latch 照行,純靠既有系統教學。
- **Non-blocking 保證** — 因 coach-mark 永不 block / pause / 要求確認,a11y 上**無 keyboard-trap、無 forced focus、無 timeout-pressure**(auto-dismiss 係寬鬆 6s 且 tap 即走,non-AAA-timeout-concern 因 dismiss 唔丟失任何 progress)。

---

## Localization Considerations

| Element | 最長 text 風險 | 優先級 |
|---|---|---|
| Welcome coach-mark | 「連好喇 — 睇下你個角色」(短) | 低 |
| Class coach-mark | 「你今日做緊推 → STRIKE 着燈」—— **class 名 + 動作名雙變數**,英文/德文展開 40% 可能爆 card 寬 | **HIGH** — card 須 wrap 或 auto-size,唔可單行硬鎖 |
| First-drop coach-mark | 「頭先爆嗰件係你真實做嘢換返嚟 — 以後日日做日日有」(較長句) | **HIGH** — 多行 card,須測 40% 展開 |
| 「試演 / Preview」watermark | 短 badge | 低 — 但雙語並排須留位 |
| Skip 「⏭ Skip」 | 短 | 低 |

- Coach-mark card **必須 auto-size / wrap**,唔可固定單行寬(40% translation 展開會爆版 → HIGH)。
- Class 名(STRIKE/CONTROL/MOBILITY)係 #12 canonical token —— UX copy 引用時須行 localization,但 class **概念** 唔變(避免逐 locale 重新命名 class)。
- 廣東話口語 register(witness 語氣)同 #24/#20 一致 —— localization brief 須保留「陪伴非說教」tone。
- 無 date/currency/number 格式(onboarding 零數值顯示)。

---

## Acceptance Criteria

> UX-AC —— QA tester 可獨立驗(無需讀其他 doc)。對應 GDD AC-01..24 但聚焦 surface/互動/a11y。

- [ ] **UX-01(purpose)** — 全新玩家首 session 完成「connect → preview → 首 workout → 首爆裝」全程,**零 modal wall / 零 "Next>" 掣 / 零強制確認對話**出現(Pillar 2 falsifiable,人手 walkthrough)。
- [ ] **UX-02(non-interference)** — coach-mark 顯示中,底層 game 嘅 single-tap(login button / next-exercise)**仍可正常觸發**,coach-mark overlay 非互動區 `mouse_filter=IGNORE` 唔截 input(spy / 手動驗)。
- [ ] **UX-03(defer mid-set)** — GSM ∈ {WORKOUT_ACTIVE, REST_PERIOD, LOOT_DROP} 期間,**零 coach-mark 出現**(截圖 / 觀察整個 set;對應 GDD AC-10/AC-14)。
- [ ] **UX-04(tap-dismiss)** — coach-mark 顯示中 tap 任意位置 → coach-mark 即 fade-out 消失(先於 auto-timer;對應 AC-12)。
- [ ] **UX-05(auto-dismiss)** — coach-mark 顯示後無互動,過 `coach_auto_dismiss_sec`(預設 6s)→ 自動 fade-out(對應 AC-11)。
- [ ] **UX-06(preview watermark)** — preview 全程「試演 / Preview」watermark **持續可見**;玩家無法誤以為呢段係真實 progress(Pillar 1 護欄,人手驗)。
- [ ] **UX-07(preview skip)** — preview 中 tap skip(≥44px target)→ preview cross-fade 退場、`step_preview` latch、轉 COACHING(對應 AC-07)。
- [ ] **UX-08(graceful degrade)** — preview scene load 失敗時,**零空白屏 / 零 crash**,直接跳過繼續流程(對應 AC-21/EC-15)。
- [ ] **UX-09(a11y contrast)** — 全部 coach-mark text 達 WCAG AA contrast(warm-white/amber on ink-bg);class coach-mark 唔單靠顏色傳 class(copy 明寫 class 名)。
- [ ] **UX-10(reduced-motion)** — reduced-motion 開啟時 coach-mark 硬切(無 fade)、全程零 motion/parallax/zoom(Motion Safety)。
- [ ] **UX-11(screen reader)** — coach-mark 顯示時 `announce_aria(text, polite)` fire,SR 讀到 coach-mark copy 而唔搶斷其他 announce。
- [ ] **UX-12(one-way exit)** — 四 step latch 全 set 後,onboarding 永久 DORMANT,後續 session **零 coach-mark / 零 preview** 再現(對應 AC-04/05)。

### Epic-time advisory carry（Story 015 — 5 UX advisory resolved）

- [ ] **UX-AC-13(appear-latency)** — coach-mark trigger fire 後,若當前 non-critical window,coach-mark fade-in 喺 **≤1 frame** 內啟動(coordinator `_enqueue_coachmark` 即時 `_service_coachmark`,唔等下一 `_process` tick;deferred 則 state 一清返即下一 frame 補顯)。
- [ ] **UX-AC-14(resolution / aspect-ratio)** — coach-mark peripheral anchor(top strip)+ preview watermark(corner badge)喺 **16:9 / 4:3 / portrait** 都唔遮中央 one-tap 互動區(login button / next-exercise);`PRESET_TOP_WIDE` + corner anchor 隨 viewport scale。
- [ ] **UX-AC-15(preview-loading state)** — preview scene load 期間(scene path 設定後、play 之前)顯示 watermark + skip affordance(唔留空白屏);load 失敗 → graceful skip(UX-08);MVP 無 scene path → 直接 placeholder timer(零 loading state)。
- [ ] **UX-AC-16(keyboard focus order)** — coach-mark **非 keyboard-trap / 非 forced-focus**(`mouse_filter=IGNORE`,唔搶 focus);preview skip affordance 可 Tab 到 + Enter/Space 觸發 + Esc = skip;onboarding overlay 永不改底層 surface 嘅 focus order(疊加非取代)。

---

## Open Questions

| ID | Question | Owner | 建議 default |
|---|---|---|---|
| **UXQ-01** | 無 `design/player-journey.md` —— onboarding 嘅 journey phase / 情緒曲線靠 game-concept L106 推導。要唔要補 player journey map? | ux-designer + producer | Defer;template `.claude/docs/templates/player-journey.md`;onboarding context 已由 game-concept 充分推導,非 blocking |
| **UXQ-02** | Coach-mark card 確切視覺(圓角 / 邊框 / 9-slice / 是否借 #22 `ui_card_item_bg`)? | art-director(art bible) | Epic-time `/asset-spec system:onboarding-flow`;建議借既有 HUD card 視覺語言,amber-gold 高飽和 |
| **UXQ-03** | `coach-mark` + `preview-watermark` 兩個新 pattern 幾時入 `interaction-patterns.md`? | ux-designer | **Epic-time** —— `/create-epics` 時連同 G-OB gate 加入 pattern library(行為 ground truth 喺本 spec + GDD Rule 4)。對比 P-17 peripheral-honesty-banner:coach-mark 鏡其 restraint 但係 teaching 非 error,獨立 pattern |
| **UXQ-04** | Preview「試演」watermark 確切視覺(角落 badge vs 半透 repeat overlay vs 兩者)? | art-director | 建議 **角落常駐 badge + 中央輕半透 repeat** 雙保險(Pillar 1 anti-deception);epic-time asset-spec 定稿 |
| **UXQ-05** | 「重睇教學」入口(settings 加 reset latch)? | game-designer | MVP **無**(GDD Q-OB-4);v0.2 候選,`coach_marks_enabled` 已預留總開關 |
| **UXQ-06** | Preview 借既有 combat SFX vs 全 silent? | audio-director | GDD Q-OB-3:借既有 #4 combat cue(preview = showcase 有聲先似真),onboarding 本身零 fanfare |

> **新 UX pattern 候選(epic-time 入 library)**:`coach-mark`(peripheral dismissible in-context hint)+ `preview-watermark`(非綁定試演標示)。兩者行為 ground truth 喺本 spec + GDD Rule 3/4。
