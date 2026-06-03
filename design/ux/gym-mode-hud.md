# UX Spec: Gym-Mode HUD (#20)

> **Status**: In Design → Ready for `/ux-review`
> **Author**: Frank + ux-designer
> **Last Updated**: 2026-06-03
> **Journey Phase(s)**: Active-workout companion (mid-set, peripheral attention) — *no `design/player-journey.md` exists yet (gap noted in Open Questions)*
> **Template**: UX Spec
> **Source GDD**: `design/gdd/gym-mode-hud.md` (✅ APPROVED R8, 2026-06-03)
> **Mandate**: 呢份 UX spec 交付 GDD 明文 defer 落 `/ux-design` 嘅 owned deliverables —— **AC-V-1 binding glance protocol(#20 epic ENTRY GATE)**、visual primitives(`min_bar_height_px` / `min_font_size_px` / Boss HP non-color glyph / skill silhouette set)、layout zones / 座標、REST_PERIOD cockpit list cap。GDD 係 requirements input,本 spec 唔覆寫 GDD 嘅 mechanics(stories cite GDD for rules,cite 本 spec for layout/glance)。

---

## Purpose & Player Need

玩家做緊 gym set、力竭邊緣,**唔能夠、亦唔應該**對焦螢幕。Gym-Mode HUD 係佢做 set 期間唯一持續在場嘅 game UI,功能單一:**喺 0.3 秒餘光(peripheral vision)交付「我宜家幾強、打到邊、HP 穩唔穩」嘅狀態鏡像,完全唔要求互動**。

> 完成呢句:「玩家喺 set 之間每下喘氣,眼角想 ___」→「**確認自己仲喺度、仲喺變強,然後迫返埋落去做埋最後兩下**。」

冇咗 #20,玩家 mid-set 完全冇 game 反饋,Pillar 2「無壓力陪伴」蒸發。本 spec 嘅成功標準同 GDD 一致:**session 之後玩家話「我冇點留意過佢」而全程安心**(forget-it = success)。

---

## Player Context on Arrival

| 維度 | 內容 |
|---|---|
| **首次遇到** | 開 game / 第一次進入 gym session(GSM 由 BOOTING → IDLE / WORKOUT_ACTIVE) |
| **之前喺做緊** | 物理上做緊 rep / 組間休息 / 攞緊水。注意力 **80% 喺身體,≤20% 可分俾螢幕** |
| **情緒狀態** | 力竭、專注於 lift、可能短暫煩躁(力盡)。設計**假設 worst-case:peripheral + fatigued + 螢幕 shake**(非 foveal-rested) |
| **自願 vs 被送** | 自願背景陪伴。HUD 唔召喚玩家;玩家**主動**用餘光掃,而非被 notification 拉去對焦 |
| **裝置距離** | 30–60cm(手機/平板擺架上 or 地下),per accessibility-requirements §5 |

呢個 context 直接 encode 設計約束:**任何要求對焦先讀到嘅 element 都違反 purpose**(= GDD Anchor metaphor「餘光戰報」)。

---

## Navigation Position

```
[Game root] → [Gym Session runtime] → Gym-Mode HUD (常駐 overlay,非可導航 screen)
```

#20 **唔係一個玩家「navigate 去」嘅 screen** —— 佢係 gym session 全程疊喺 desaturated auto-combat 世界之上嘅 persistent overlay(CanvasLayer 50,SE layer 100 之下)。冇 enter/exit 按鈕、冇 menu entry。可見性 100% 由 GSM state 驅動(見 States & Variants)。唯一「導航式」行為係 **#21 loot modal 在場時主動退讓**(defer,非導航跳轉)。

---

## Entry & Exit Points

HUD 唔由玩家動作進入/離開,而係跟 GSM state 自動 mount/demote。下表記錄「可見性事件」入口/出口:

| Entry(可見性升起) | Trigger | HUD 帶入 context |
|---|---|---|
| GSM 離開 BOOTING | autoload boot 完 + node ready | branch:`is_audio_unlocked() ? Active : BannerGate`(pull-then-subscribe initial state) |
| GSM → WORKOUT_ACTIVE / COMBAT_ACTIVE / BOSS_ENCOUNTER | `state_changed` | apply 對應 emphasis 矩陣 |
| Resume(bfcache/visibilitychange visible) | `pageshow` / visibility | reconcile:pull 真值 snap,終點 branch Active/BannerGate |

| Exit(可見性退/凍) | Trigger | 不可逆狀態變化 |
|---|---|---|
| GSM → LOOT_DROP | `state_changed` | 主動 defer(dim ×`loot_dim_multiplier`,▽ PROG,**絕不自畫 loot 文字**),讓 #21;無不可逆 |
| GSM → SUSPENDED / page hidden | `state_changed` / visibilitychange hidden | Freeze-dim,凍結最後值,停 motion/SFX。無不可逆(resume 一次性 snap reconcile) |
| GSM → BOOTING(罕見 re-boot) | `state_changed` | 唔 render,boot veil |

**無單向出口** —— 所有退/凍狀態都可 reconcile 返。banner dismiss 係 session 級單向(`banner_dismissed_this_session`,non-persisted,resume 唔重彈但新 session 會 re-evaluate)。

---

## Layout Specification

### Information Hierarchy

(承 GDD Information Tier 表 + UI Requirements Glance Hierarchy,本 spec 鎖定 peripheral 接收次序)

| 接收次序 | Element | Tier | 餘光理由 |
|---|---|---|---|
| 1（最先) | **HP**(身體力量,non-depleting) | L1 餘光主 | 最粗 bar(6px)、最高 amber 飽和、固定 anchor;升級 step 跳格 = positive anchor |
| 1（並列) | **EXP**(climbing) | L1 餘光主 | Anchor moment 主角,事件驅動跳格 |
| 2 | **PROG**(set X/Y 粗粒度)·(BOSS)Boss HP | L2 餘光次 | 餘光感知「進度感 / boss 緊張」,細節留 L3 |
| 3 | STAT 明細 · SKILLS 列表 · 下一動作 · 剩餘組數 | L3 對焦 | **只 REST_PERIOD surface**,set 中唔逼睇 |
| 瞬時 | 新技能解鎖 flash | 瞬 L1 → 常駐 L3 | 一次性慶祝後退 ambient |

**80/20 binding**:L1+L2 喺餘光交付 ≥80% status;L3 只承載 20% confirmation,且只 REST 對焦。reward 必須喺餘光已被看到。

### Visual Primitives (RESOLVED — 解 GDD deferred 值 + ux-review R5 #1/#5 「threshold 有 alpha 冇 / font floor 有 bar floor 冇」死鎖)

呢個 sub-section 落實 GDD 「確切數字由 /ux-design 定」嘅全部 numeric primitive。**AC-V-1 protocol 依賴呢啲 primitive 先存在**(解 ux-review R5 #9 雞蛋死鎖:先定 primitive,後 author protocol)。

| Primitive | 值(鎖定) | 來源 / rationale |
|---|---|---|
| **`min_font_size_px`** | **7** device px | m5x7 bitmap 最低可辨(accessibility-requirements §5 + P-03);MSDF effective 字號 hard floor,`text_scale` 調到 0.8 都唔可跌穿 |
| **`min_bar_height_px`** | **4** device px | EXP bar peripheral acuity floor(解 ux-review R5 #5)。HP 6px、EXP 目標 3px logical;但 EXP render = `max(round(hp_height × 0.5 × dpr), min_bar_height_px)` → 低 DPI / 細 viewport 下 3px<4 device px 時 clamp 上 4px。Hierarchy「HP 6 > EXP ≥4」恆成立 |
| **`◐ deep_dim_element_alpha`** | **0.22**(GDD locked) | 已 < `deep_dim_alpha_threshold` 0.35;本 spec 確認 0.22 喺 desaturated world 上對焦仍可讀(Tier 2 floor),餘光下 figure-ground 不足 = 正確退出 glance budget |
| **`ambient_alpha` ○** | **0.55**(GDD locked) | 餘光可見下限,> threshold |
| **Boss HP threat glyph** | **threat-chevron prefix**(下指角 ▼ + 8×8 angular 敵標,ink outline + crimson fill) | non-color load-bearing channel #1(見下「Boss HP bar variant」) |
| **Boss HP bar geometry** | **angular notched end-caps**(vs player 圓角 2px) | non-color load-bearing channel #2;single-frame 即分 Boss vs Player(唔靠 crimson、唔靠 deplete 動畫) |
| **Skill silhouette set** | **reference P-04 skill-family-icon**(canonical) | Strike=diagonal/sharp、Control=symmetric/arc、Mobility=flowing/negative-space;16×16 solid + 1px ink,8×8 squint test。**唔重新發明** |
| **BOSS skill cluster glance cap** | **4 icon**(`skill_cluster_display_cap`) | pre-attentive subitizing 4±1;>4 摺疊「+N」 |
| **REST_PERIOD SKILLS list cap** | **top 8 可見 + scroll**(對焦層較寬) | B11 cockpit bound;**唔係** BOSS 4-icon glance cap,係對焦窗有界 list cap |
| **Banner touch target** | **≥ 44×44 CSS px**(Apple HIG / accessibility-requirements §4) | 唯一 touch interaction |
| **HUD text 雙層描邊** | 2px ink outline `#1A1D24` + 1px hard shadow @40% | shake 期間 figure-ground(`hud_shakes_with_world=true`) |

**Boss HP bar variant(non-color 區分 — 兌現 GDD R4 B5 binding invariant「≥1 colorblind-safe non-color channel」)**:
- **Channel #1（primary,glance-valid)**:bar 左端 **threat-chevron glyph prefix**(下指角 + angular 敵標,8×8,crimson `#C8453E` fill + ink outline)。Player HP 無 prefix。single-frame 快照即分。
- **Channel #2**:bar 幾何 —— Boss HP 用 **angular notched 端帽**,Player HP 用圓角 2px。形狀差喺 peripheral 仍有效。
- **Channel #3（enhancement)**:crimson `#C8453E` vs amber `#F2A93B`(色盲下可能塌軸,故唔做 load-bearing)。
- **Channel #4（對焦才 valid)**:depleting 方向(右→左)vs Player non-depleting。
- **位置**:screen 上方(區隔下方 L1 player anchor)。

### Layout Zones（建議座標,art-director 可微調;zone 分配係 binding)

3 個 zone arrangement 比較後採 **Arrangement A — Corner-anchored peripheral**(理由:餘光靠肌肉記憶,corner 固定 = 唔需重新對焦;center 留空唔遮 avatar lift 動作):

| Zone | 位置 | 內容 | Layer |
|---|---|---|---|
| **Z1 L1 anchor**（固定,跨所有 state 0px 位移) | **top-left** safe-zone(≥16px edge inset) | HP bar(6px)+ EXP bar(≥4px)+ EXP `+N` popup | 獨立 absolute Control / 獨立 layer node |
| **Z2 L2 progress** | top-left 之下,鄰近 Z1 | PROG（set X/Y + WorkoutPhase copy,ambient,絕不跳秒) | overlay,不 push Z1 |
| **Z3 Boss(BOSS_ENCOUNTER only)** | **top-center**（區隔 Z1) | Boss HP bar + threat glyph | overlay,不 push Z1 |
| **Z4 SKILLS cluster** | top-right(BOSS=◉ emphasis;其餘 ◐) | skill-family-icon cluster（單一 glance_group parent) | overlay |
| **Z5 REST_PERIOD L3 panel** | bottom,**slide-up overlay**(REST 才升起) | STAT 明細 ≤3 block / SKILLS top-8 list+scroll / 下一動作 / 剩餘組數 | overlay,**永不 reflow Z1**(layout isolation,兌現 AC-V-1 ④ 0px) |
| **Z6 Banner**（silent-mode) | **bottom-center toast**(非全屏遮蔽) | 「㩒一下開聲」+ alpha 脈動 | overlay,non-fullscreen,不 push Z1 |

**Layout isolation rule(binding,兌現 AC-V-1 ④ 0px)**:Z1 L1 anchor element **必須 absolute-positioned 喺獨立 layout context**,唔參與會 reflow 嘅 flow container。Z3/Z5/Z6 一律 overlay 疊加,**永不 push Z1 layout flow**。否則 Boss HP 插入 / L3 升起會 reflow Z1 → 違 0px。

### Component Inventory

| Component | Zone | 類型 | 內容 | 互動 | Pattern |
|---|---|---|---|---|---|
| HP bar | Z1 | data display | `get_stat(MAX_HP)` non-depleting | 否 | **P-02 frameless-hud-bar**(6px) |
| EXP bar | Z1 | data display | `exp_fill`(F1) | 否 | **P-02**(≥4px,danger tint N/A) |
| EXP `+N` popup | Z1 | feedback | level delta | 否 | **P-10 damage-number-popup** + **P-03 ticker**(step) |
| PROG block | Z2 | data display | set X/Y + phase copy | 否 | frameless text,P-03 step(無 idle) |
| Boss HP bar | Z3 | data display | boss current_hp(depleting) | 否 | P-02 變體 + threat glyph prefix(本 spec 定義) |
| SKILLS cluster | Z4 | data display | `get_unlocked_abilities()` → tier_ordinal DESC top-4 | 否 | **P-04 skill-family-icon** ×≤4 + 「+N」,單一 glance_group parent |
| REST L3 panel | Z5 | data display | STAT/SKILLS list/下一動作/剩餘組 | 否(只睇) | P-04 list + frameless text |
| Silent banner | Z6 | overlay/input | 「㩒一下開聲」 | **單 tap**（唯一互動) | **P-09 single-tap**(focus_mode=NONE) |

**新 pattern flag**:Boss HP threat-glyph bar variant 未喺 pattern library。Cross-reference check 會 flag 加入 P-11 `enemy-threat-hud-bar`(見下)。

### ASCII Wireframe

**WORKOUT_ACTIVE / COMBAT_ACTIVE**（餘光可見 = HP◉ + EXP◉ + PROG○ = 3）:
```
┌─────────────────────────────────────────────┐
│ ▰▰▰▰▰▰▰▰▰▱▱  HP        [Z1 L1 anchor]         │  ← 6px amber, non-depleting
│ ▰▰▰▰▰▱▱▱▱▱▱  EXP  +120 ↑                      │  ← ≥4px, step popup
│ Set 3/5 · Bench Press        [Z2 L2]          │  ← ambient, 絕不跳秒
│                                               │
│            ( desaturated auto-combat world )  │  ← avatar #26, 唔計 #20 budget
│                                    [STAT ◐]   │  ← deep-dim, 退出餘光
│                                  [SKILLS ◐]   │  ← Z4 deep-dim
└─────────────────────────────────────────────┘
```

**BOSS_ENCOUNTER**（餘光可見 = HP◉ + Boss HP◉ + SKILLS cluster◉(算1) + EXP○ = 4 ≤ 5 ✅）:
```
┌─────────────────────────────────────────────┐
│ ▼▰▰▰▰▰▰▱▱  BOSS          [Z3 top-center]      │  ← threat-chevron prefix, angular caps, crimson
│ ▰▰▰▰▰▰▰▰▰▱  HP   ▰▰▰▱▱ EXP        [⬗⬙⬗+2] Z4 │  ← HP◉ / EXP○ ambient / cluster◉ 4-icon+「+2」
│ [STAT ◐]  [PROG ◐ deep-dim 退出餘光]           │
│            ( desaturated boss fight )         │
└─────────────────────────────────────────────┘
```

**REST_PERIOD**（唯一對焦窗,L3 slide-up;豁免 0.3s glance budget,但 cockpit-bound）:
```
┌─────────────────────────────────────────────┐
│ ▰▰▰▰▰▰▰▰▰▱ HP   ▰▰▰▰▰▱ EXP        [Z1 不動]   │
│ ─────────────────────────────────────────    │
│ ▷ Set 3/5 完成 · 下一個:Squat · 剩 2 組      │  ← Z5 surface
│ ▷ STAT: STR 142 · END 98 · ... (≤3 block)     │
│ ▷ SKILLS (top 8 + scroll ▾):⬗⬙⬗⬗⬙⬗⬙⬗ +N      │  ← list cap 8, 非 glance cap 4
└─────────────────────────────────────────────┘
```

---

## States & Variants

承 GDD「HUD Element × GSM GameState 顯示矩陣」。本 spec 鎖定每 state 嘅 **layout 變化 + 餘光 count**(◉Emphasis ○Ambient ◐Deep-dim〔退出餘光〕▷Surface —Hidden ▽Defer ❄Frozen):

| GameState | Z1 HP | EXP | STAT | SKILLS | PROG | Boss | 餘光 count | Layout 變化 |
|---|---|---|---|---|---|---|---|---|
| BOOTING | — | — | — | — | — | — | (未 render) | boot veil |
| DISCONNECTED | ○dim | — | — | — | — | — | (state 豁免) | 全 dim + 細離線 glyph,靜止 |
| IDLE | ○ | ○ | ○ | ○ | — | — | (state 豁免) | 待機 ambient;banner 可疊 |
| WORKOUT_ACTIVE | ◉ | ◉ | ◐ | ◐ | ○ | — | **3** | 餘光主場 |
| REST_PERIOD | ○ | ○ | ▷ | ▷ | ▷ | — | (對焦窗豁免) | **Z5 slide-up surface**,cockpit-bound |
| COMBAT_ACTIVE | ◉ | ◉ | ◐ | ◐ | ○ | — | **3** | 同 WORKOUT |
| BOSS_ENCOUNTER | ◉ | ○ | ◐ | ◉ | ◐ | ◉ | **4** | **Z3 Boss bar 升起** + Z4 cluster emphasis |
| LOOT_DROP | ○dim | ○dim | — | — | ▽ | — | (defer 豁免) | 主動 defer 讓 #21,dim ×`loot_dim_multiplier` |
| SUSPENDED | ❄ | ❄ | ❄ | ❄ | ❄ | ❄ | (freeze 豁免) | Freeze-dim ×`freeze_dim_extra`,凍結最後值 |

**◉↔◐ state transition 視覺(解 ux-review R5 #2「state transition 視覺零 spec」)**:element 由 ◐ 升 ◉/○(如 BOSS→REST STAT ◐→▷)時 **一次性 snap 到當前 value(skip tween)**,唔回播 deep-dim 期間 missed motion(對齊 GDD EC-R6 + EC-S9 bfcache reconcile 原則)。反向降 ◐ 即 dim,值仍即時 set(EC-R6:◐ element 收 stat_changed 直接 set 不 tween)。

---

## Interaction Map

> **Input(from technical-preferences.md §Input & Platform)**:Primary = **Touch(single-tap)**;Keyboard/Mouse secondary;**Gamepad = None**;Touch = Partial(web mobile/tablet)。

#20 係 **near-zero-interaction overlay**（Pillar 2 cardinal rule:禁 mid-set 互動攞 reward)。唯一互動:

| Component | Action | 觸發 input | 即時 feedback | Outcome |
|---|---|---|---|---|
| Silent banner | single tap | touch tap / mouse click / keyboard Enter(focus_mode=NONE 唔搶 focus) | banner fade-out 200ms + buffered SFX flush(priority-desc) | `audio_unlocked` emit → 之後 SFX 出聲;`banner_dismissed_this_session=true` |

**所有其他 element 零互動**(HP/EXP/PROG/SKILLS/Boss HP 純 read-only display)。`is_input_permitted()==false`(#33,deferred)時連 banner tap 都唔消費 —— 但 **banner-unlock tap 永遠豁免 gating**(解鎖 gesture 非 game 互動,唔攞 reward,唔違 Pillar 2;#33 ready 後 wrap game-affecting tap,banner tap 恆豁免)。

---

## Events Fired

| Player Action | Event Fired | Payload |
|---|---|---|
| Banner single tap | `AudioManager.audio_unlocked`(由 #4 emit,#20 訂閱)+ #20 內部 `banner_dismissed_this_session=true` | 無 game-state payload |
| (無其他玩家 action) | — | — |

**持久狀態 flag**:`banner_dismissed_this_session` 係 **in-memory non-persisted**(resume 唔重彈,但新 session re-evaluate `is_audio_unlocked()`)—— 刻意 NOT 寫 PersistenceLayer(session-scoped gesture state,非 user setting)。**無任何 #20 action 寫 save data / progress / economy** —— #20 純 read-only consumer,無架構持久化關注點。

---

## Transitions & Animations

| 轉場 | 行為 | reduce_motion |
|---|---|---|
| HUD 出現(離 BOOTING) | ambient HUD fade-in(快,≤200ms);無 ceremony | 直接顯示 |
| Banner 出現 | toast slide-up(bottom)+ alpha 脈動(F3,period 2s,**僅 alpha 非 scale**) | 靜態無脈動(`banner_pulse_amp`→0) |
| Banner dismiss | fade-out 200ms + pulse `kill()` | 即時隱藏 |
| EXP 跳格 | `+N` popup overshoot 1.1×→settle + bar step ticker(P-03,33ms/格) | 單次 snap,無 overshoot |
| Level-up flash(每組完成) | 三件 co-trigger:avatar rim flash + 武器 glow + `+EXP` popup,one-shot ≤0.4s | 靜態 amber,無白峰(photosensitivity:white-peak 受 reduce_motion 抑制) |
| Ability unlock flash | icon pop-in scale 0.8→1.0 ease-out 120ms + amber 邊緣 flash 0.6s → 退 L3 ambient | scale 縮至瞬顯 |
| state demote(進 SUSPENDED/LOOT) | Freeze-dim / defer dim,停所有 motion | 同(本來就停) |
| Resume reconcile | 一次性 snap 到真值,**唔回播 missed motion**(Pillar 1 只認當下真值) | 同 |
| ◐↔◉ emphasis 轉 | 一次性 snap(skip tween) | 同 |

**Motion sickness / reduced-motion**:`reduce_motion` 係所有 motion knob 嘅 master override(覆蓋 bar step→snap / popup overshoot→定位 / level-up flash→靜態 / banner pulse→0)。應 derive 自 #6 `motion_intensity` a11y slider(避免兩個獨立 toggle,co-design flag Q-OQ7)。**禁 idle 持續動畫**(banner 脈動係唯一豁免,且 alpha-only 非 scale,unlock 即 kill)。

---

## Data Requirements

| Data | Source System | Read/Write | Notes |
|---|---|---|---|
| HP（MAX_HP) | #11 Stat | Read | `stat_changed(MAX_HP)` push + `get_stat()` pull;non-depleting |
| EXP | #11 Stat | Read | `stat_changed(EXP)`;trust boundary 喺 #11(#20 無 consumer-side fabrication filter) |
| 已解鎖技能 | #12 Ability | Read | `ability_unlocked` push + `get_unlocked_abilities()`;tier_ordinal 由 #20-owned `SkillIconRegistry`(intrinsic,L386/L405) |
| set/workout 進度 | #9 WST | Read | `set_progress_changed`(debounce 500ms #9 own)/ `phase_changed`;**計數只認 #9-validated signal,唔食 raw set_logged** |
| GSM state | #1 GSM | Read | `state_changed` + `get_current_state()`(method 非 .current_state);驅動矩陣 |
| audio unlock | #4 Audio | Read + call-out | `is_audio_unlocked()`/`audio_unlocked` + `play_sfx()`;讀 `SfxCatalog.tres` priority field |
| raw set_logged | #2 GymSys | Read（audio path only) | `WorkoutAudioAdapter` 訂閱,**只觸發 SFX 絕不驅動計數/視覺**;GSM-state-level gate |
| streak 事件 | #8 Streak | Read（co-design) | stagger `streak_chime`;Prov-3,fallback 即播無 stagger |
| `is_input_permitted()` | #33 Attention | Read(deferred) | Prov-4,banner tap 豁免 |

**架構關注點**:#20 **完全 read-only**,唔 own 任何 game state(HP=MAX_HP 顯示,current-HP depleting bar runtime owner 不存在 = Q-OQ3 post-MVP)。所有 data push/pull,**禁 `_process` 每幀 poll**。呢個係 UX 需求陳述,delivery 機制係 architecture 決定(已由 GDD + ADR-0006 connect_for_initial_state 鎖定)。

---

## Accessibility

> **Committed tier**:WCAG AA Core + Motion Safety(`design/accessibility-requirements.md`)。

| 要求 | 本 spec 兌現 |
|---|---|
| **Color independence**（每語意 ≥2 non-color signal) | Boss HP:threat glyph + angular geometry(≥2 non-color,色係 enhancement);skill class:P-04 silhouette shape(非色);HP vs EXP:bar 厚度(6 vs ≥4)+ 位置 + label |
| **Touch ≥44×44** | Banner tap target ≥44×44 CSS px(唯一互動);無 hold/swipe/drag/double-tap/timing |
| **Contrast WCAG AA** | amber `#F2A93B` on ink `#1A1D24` ≈8.5:1(AAA);warm-white number ≈11:1;雙層描邊保 shake 對比 |
| **Motion safety** | `reduce_motion` master override + derive 自 #6 `motion_intensity`(Q-OQ7);白峰 flash 受抑;flash debounce <3Hz(WCAG 2.3.1) |
| **Min font** | `min_font_size_px=7`(MSDF effective floor,`text_scale` 0.8 唔可跌穿) |
| **Min bar height** | `min_bar_height_px=4`(EXP peripheral floor) |
| **Color-independent QA** | build 須出 desaturated 截圖(WORKOUT/BOSS/REST)驗全 gameplay-critical info greyscale 可讀 |
| **Keyboard nav** | banner 可 Enter 觸發(focus_mode=NONE 唔搶 focus,但 keyboard 可達);其餘 element 非互動無需 nav order |
| **Gamepad** | None(per tech-prefs)— 無需 gamepad nav order |

**⚠️ Cross-doc conflict flag(Open Questions OQ-U2)**:accessibility-requirements §3/§5 committed「bitmap m5x7 font,font scaling deferred v0.2+」,但 GDD 引入 **MSDF font + `text_scale` player-facing knob**。兩者矛盾(bitmap 唔 scale vs MSDF 可 scale)。本 spec 取 `min_font_size_px=7` 與兩者一致,但 `text_scale` 作為 player-facing a11y knob 嘅 MVP 地位需 reconcile —— flag 去 OQ-U2,唔喺本 spec 單方面覆寫 committed tier。

---

## Localization Considerations

| Element | 最長文本 | layout-critical? | locale notes |
|---|---|---|---|
| PROG copy「Set 3/5 · 動作名」 | 動作名（中/英）+ phase copy | 中 | 動作名長度變動大;Z2 須容 40% 擴張或 truncate-with-ellipsis;絕不換行推 Z1 |
| Banner「㩒一下開聲」 | 短 | **是**(單行 toast) | EN「Tap to enable sound」較長;banner 須容 +40% 仍單行 or 縮字;非祈使句保持(witness register) |
| REST L3「下一個:X · 剩 N 組」 | 動作名 + 數字 | 中 | 數字 locale 格式;list 區可垂直增長(對焦窗) |
| EXP `+N` popup | 數字 | 否 | 純數字,locale 千分位 |

**HIGH PRIORITY for localization-lead**:Banner(單行 toast,layout-critical)+ PROG 動作名(長度不定)—— 40% 擴張須 spec truncate/縮放策略,唔可 reflow Z1。CJK(Zpix)vs Latin(MSDF)混排規則 per art-bible §7.B(禁 pixel+TTF 混排)。

---

## Acceptance Criteria

> 沿用 GDD AC 分流:Logic/Integration = BLOCKING(headless GUT);Visual/Feel/Glance = ADVISORY-RESULT。本 spec 嘅 AC 聚焦 **layout / glance / a11y**(GDD 已覆 mechanics AC)。

- [ ] **AC-UX-1（performance — HUD 出現)**:HUD ambient 由 GSM 離 BOOTING 到首 frame render ≤ 200ms（含 pull-then-subscribe initial state)。*Integration · BLOCKING*
- [ ] **AC-UX-2（navigation — state-driven visibility)**:注入 GSM 9 state,每 state HUD layout 對應 States 矩陣(emphasis/dim/defer/freeze 正確;Z3 Boss 只 BOSS_ENCOUNTER 升起;Z5 只 REST_PERIOD surface)。*Logic · BLOCKING*
- [ ] **AC-UX-3（0px anchor — layout isolation)**:跨所有 9 GSM state,Z1 L1 anchor(HP/EXP)螢幕座標位移 == **0px**（Z3/Z5/Z6 overlay 升降唔 reflow Z1）。*Logic(measure rect)· BLOCKING*
- [ ] **AC-UX-4（empty/locked state)**:GIVEN `get_unlocked_abilities()` 返空,Z4 SKILLS cluster 顯示空 group(無 crash、無 void);GIVEN HP/EXP 首 frame 無 confirmed 值,fallback 0.0 不顯 NaN。*Logic · BLOCKING*
- [ ] **AC-UX-5（min visual primitive floors)**:量度 — HP bar=6px、EXP bar ≥`min_bar_height_px`(4)、HUD 字號 ≥`min_font_size_px`(7),`text_scale` 調 0.8 時 effective 字號仍 ≥7。*Logic/UI · BLOCKING*
- [ ] **AC-UX-6（Boss HP non-color 區分 — colorblind)**:BOSS_ENCOUNTER 截圖經 deuteranopia/protanopia/tritanopia simulation + greyscale,Boss HP vs Player HP 靠 **threat glyph + angular geometry** single-frame 可分(唔靠 crimson/deplete)。*Visual/a11y · ADVISORY(lead sign-off)*
- [ ] **AC-UX-7（skill class silhouette)**:Z4 cluster icon 經 greyscale + 8×8 squint test,Strike/Control/Mobility 靠 P-04 silhouette 可分(唔靠 ≤3px color accent)。*Visual/a11y · ADVISORY*
- [ ] **AC-UX-8（touch target)**:banner hit-area ≥ 44×44 CSS px。*UI · ADVISORY*
- [ ] **AC-UX-9（reduce_motion)**:`reduce_motion==true` 時 banner pulse 靜止、bar step→snap、popup 無 overshoot、level-up 無白峰。*Logic · BLOCKING*
- [ ] **AC-UX-10（REST cockpit bound)**:REST_PERIOD SKILLS list 可見 ≤8 + scroll(非無限展開);STAT ≤3 block。*UI · ADVISORY*
- [ ] **AC-V-1（餘光 0.3s glance — Player Fantasy 命脈;BINDING entry gate)**：見下「Glance Playtest Protocol」。*Visual/Feel · ADVISORY-RESULT / BINDING-PROTOCOL-DELIVERY-GATE*

### AC-V-1 Glance Playtest Protocol（RESOLVED — #20 epic ENTRY GATE;解 ux-review R5 #3/#9 + R7 #2)

> 呢個 protocol 兌現 GDD「`/ux-design` + qa-lead 用**現實樣本量**定可達 binding 統計標準」嘅 mandate。設計同時治三個 standing defect:R5 #3(Wilson 下界做 hard gate 數學不可達)、R5 #9(雞蛋死鎖 — primitive 已喺上方 RESOLVED)、**R7 #2(GIVEN 只測 WORKOUT_ACTIVE → 擴至 BOSS_ENCOUNTER)**。

**測量 construct（match Player Fantasy「peripheral-fatigued-shaking」,非 foveal-rested-static)**:
- **(a) Peripheral**:中央 fixation cross 強制注視,HUD target 喺 gaze 偏心 **≥10–15°**(非中央 flash)。
- **(b) Dual-task secondary load**:tester 同時做 secondary motor/verbal task(如倒數 7 / 持續輕拍),模擬力竭認知佔用。
- **(c) Exposure**:tachistoscope **300ms**(≈0.3s 餘光窗)。
- **(d) Shake 變體**:static + `hud_shakes_with_world` shaking 兩組,**both 須過**。
- **(e) State scope（R7 #2 fix)**:**WORKOUT_ACTIVE AND BOSS_ENCOUNTER 兩個 state 都測**(BOSS glance load 較重:+Boss HP + 4-icon cluster,必須獨立驗)。
- 任務:閃現後問「HP 滿唔滿? EXP 有冇啱啱跳? (BOSS)邊個 bar 係 boss?」記答中率。

**Sample size 可行性（indie solo dev — 解 R5 #3 + feedback_glance_protocol_stats)**:
- **N = 12**（target;solo dev 經 gym community 可達。**承認 scope**:招唔到 45+ tester 做 CI-下界 gate)。
- **BINDING pass(4 項 conjunctive,lead 不可 override)**:
  1. **Quantitative protocol 交付**(上述 a–e 全部);未交付 = CANNOT-VERIFY,#20 唔可入 sprint。
  2. **Point estimate 答中率 ≥ 80%**（≥10/12),**per state(WORKOUT + BOSS)× per variant(static + shake)四格各自 ≥80%**。
  3. **Likert「需唔需對焦先讀到」median ≥ 4/5**（5=完全唔使對焦)。
  4. **Z1 anchor 跨 state 位移 = 0px**（同 AC-UX-3,客觀量度)。
- **ADVISORY(report-for-context,非 pass/fail gate)**:報 95% Wilson CI 下界做 sample-confidence(10/12=83% → Wilson 下界 ≈55%,**已知細樣本必偏低,刻意唔做 binding 條件** —— 對齊 [[gym-mode-hud-ac-v1-stats]]:CI 下界 + 小 N = 數學不可達,只報唔 gate)。CI 用嚟引導「要唔要加大 N」嘅判斷,非卡 epic。
- **Gross-fail = BLOCKING exit**:任一格 point estimate < 70%(明顯不過)→ escalate ux 重設計,非微調。

**為何 N=12 + point-estimate 而唔追 CI 下界**:Player Fantasy 嘅「80% status」係 design target,唔需要做 statistical floor;indie 現實樣本下,point estimate ≥80% + 0px anchor(客觀)+ Likert 已足夠 gate「餘光可讀」。CI 報告保留俾 future scaling。

---

## Open Questions

| ID | 問題 | Owner | 現狀 |
|----|------|-------|------|
| **OQ-U1** | 無 `design/player-journey.md` —— 本 spec 嘅 player context 係 GDD + 常識推導。建議補 journey map(template `.claude/docs/templates/player-journey.md`)鎖定 emotional arc | ux-designer | gap noted;唔 block #20(context 已足) |
| **OQ-U2** | **Cross-doc conflict**:accessibility-requirements §3/§5「bitmap m5x7,font scaling v0.2+ deferred」vs GDD「MSDF + `text_scale` player-facing knob」。`text_scale` MVP 地位需 reconcile | ux-designer + #20 GDD | flag;`min_font_size_px=7` 與兩者一致,scaling knob 待裁 |
| **OQ-U3** | Boss HP threat-glyph 確切 pixel art(下指角 vs 骷髏 vs 敵標)+ angular end-cap 幾何 | art-director | 形態 channel locked(glyph prefix + angular),pixel art defer art-director |
| **OQ-U4** | AC-V-1 tester 招募(N=12 gym community)+ tachistoscope tooling(web 閃現 harness) | qa-lead + Frank | protocol locked;執行待 epic entry |
| **OQ-U5** | `reduce_motion` derive 自 #6 `motion_intensity`(避免雙 toggle) | #20 + #6 + master scene | co-design(同 GDD Q-OQ7) |
| **OQ-U6** | 新 pattern **P-11 enemy-threat-hud-bar** 須加入 interaction-patterns library | ux-designer | cross-ref check flagged;見下 |
| (繼承 GDD) | Q-OQ1 #8 streak signal / Q-OQ5 #2 subscriber / Q-OQ6 #21 defer / Q-OQ12 SUSPENDED producer | 各 GDD | sprint `/story-readiness` 前 re-check 5 dep/gate |
