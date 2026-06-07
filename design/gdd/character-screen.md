# Character Screen (#22)

> **Status**: Designed(pending fresh-session `/design-review`)
> **Author**: frank + design-system pipeline(full mode:creative-director ×2 + game-designer + systems-designer + qa-lead + art-director)
> **Last Updated**: 2026-06-07
> **Implements Pillar**: Pillar 1(stat 對比 —「我喺 gym 做嘅嘢留低咗刻度」)· Pillar 4(class posture 顯示)· 支援 Pillar 3(loadout 管理)
> **Creative Director Review (CD-GDD-ALIGN)**: CONCERNS (4 findings C1-C4 resolved inline) 2026-06-07

<!-- DESIGN CONTEXT(2026-06-07 pre-load — fresh session 唔使重 grep;全部 grep-verified)

## 上游 forward contracts(BINDING — 全部已 shipped/APPROVED)

### #11 Stat System(shipped)
- #22 = listens + reads on open:`get_stat(stat_id)` on screen open(static initial render)+ `connect_for_initial_state(stat_changed)` live update;**禁 poll、禁掂 internal `_base`**(stat-system.md L260/L586/L725)
- 3 base(STR/DEX/VIT)+ 4 derived(max_hp/attack_power/move_speed/crit_chance)
- `stat_changed(..., EQUIPMENT, _)` → #22 stat number animation 200-400ms ease +「↑/↓」arrow(L696)
- Historical comparison(上週 vs 今週)→ **#22 own snapshot via #28 Telemetry data**(L260 — #28 未 build:design 要裁 MVP 方案[local snapshot vs defer v0.2])

### #17 Equipment(shipped)
- #22 = manual override surface:equip/unequip/`set_lock(item_id,bool)`/salvage command sink(L127);**manual equip 唔受 score 限制但唔 lock 下次 auto-equip 換返** → **UX MUST 露 lock affordance 當 manual equip 較弱件**(L63 forward flag)
- AntiSnowball badge:`get_aggregate_raw_and_effective() -> {raw, effective}` →「+84 / +90(受真身上限約束)」+「練多啲,解放佢嘅全力」ledger voice(L64/L212/L335)
- Loadout:3 functional + cosmetic slot,per-slot equipped item + detail(L345);EC-11 lock 同 frame 永遠贏
- Provenance:`provenance_text` 全 tier(「拾於 6月3日・腿日」;**display timezone = #22 presentation 層 forward flag**)+ LEGENDARY `SourceReceipt.signature_text`(hover/inspect)(L66/L334)
- Craft/upgrade → v0.2 Forge(D5/A1)— #22 MVP 唔出 craft UI

### #18 PR Detection(shipped)
- PR 歷史/baseline 顯示 = **v0.2**(`get_baselines()` read-only copy;pr-detection.md L298/L353)— MVP #22 唔做 PR history panel

### #26 Avatar Renderer(GDD approved)
- Read-only 5 getters(CR-11):`get_visual_state()`(duplicate copy)/`get_class_posture()`/`get_evolution_tier()`/`is_ready_for_milestone_check()`/`get_animation_state()`;subscribe `avatar_visual_updated(state)` live;**NO setters**(L290/L734/L964 content contract 節有完整 spec — authoring 時讀)
- FR-AVATAR-1:AvatarVisualState schema stable — #22 consumption 對齊

### #21 Loot Modal(epic complete)
- **OQ-1 喺 #22 裁**:stat-delta ticker(modal 顯示 equip 前後 stat 變化)需要 #17 equip-result payload API(`receive_loot` 回 enum 冇 stats)— 裁「modal 加 slot vs 留俾 #22 screen」;P-06 rarity 語言共用(pattern 級)

### #7 Camera
- Camera story 011 BLOCKED on #22 GDD(camera-system epic)— grep camera-system.md「#22」確認 binding 內容

### 其他
- P-06 rarity 色/badge 語言(interaction-patterns.md,canonical hex = art bible §4.B)
- accessibility-requirements.md:CJK body 12px Zpix floor;P-07 motion-intensity-slider **住喺 #22 Accessibility Settings section**(interaction-patterns L232 — #22 要 host 個 slider!)
- ADR-0001(UI Presentation HIGH domain)/ ADR-0006 C6 / ADR-0003(#22 如要 local snapshot → namespace 申請 + #3 registry)

## 設計裁決待做(authoring 時 AskUserQuestion / CD)
1. OQ-1 stat-delta ticker 歸宿(#21 modal slot vs #22 screen 顯示)
2. 上週對比 MVP 方案:#28 未有 → local `charscreen.*` snapshot(要 #3 namespace)vs 裁 v0.2
3. Screen 入口/導航(GSM safe states only?Pillar 2 — gym mode 期間入唔入得?)
4. P-07 motion slider hosting + Accessibility Settings section scope
-->

## Overview

Character Screen(#22)係玩家喺 workout 以外時間(GSM `IDLE` / `DISCONNECTED`)打開嘅全屏 review + 控制 surface — 個 game 嘅「門框刻度」。玩家喺度睇返自己用真實訓練刻低嘅數字(#11 Stat System:3 base + 4 derived)、管理身上裝備(#17 Equipment loadout:manual equip / unequip / lock / salvage + AntiSnowball badge + provenance)、同望住自己嘅 avatar(#26 Avatar Renderer:今日 class posture + evolution tier + preview)。佢同時 host 全 game 嘅 **Accessibility Settings panel**(P-07 screen-shake intensity slider + P-08 reduce-camera-motion toggle — #7 Camera Q-V1 嘅 unified cluster 裁決)。

#22 **唔 own 任何 game data** — 三路內容全部經 upstream public API 讀寫(#11 `get_stat` + `stat_changed` subscribe / #17 command sink + getters / #26 5 read-only getters per CR-11),screen 自己只 own UI state(active panel、modal、settings 值)。實作受 ADR-0001(UI Presentation HIGH domain budget)、ADR-0003(`settings.*` persistence keys)、ADR-0006 Contract 6(`connect_for_initial_state` subscription)約束。

玩家影響:呢度係 Pillar 1 嘅 retention surface —「我喺 gym 做嘅嘢留低咗刻度」喺呢個 screen 先至睇得晒。每個 stat 數字、每件裝備嘅 provenance(「拾於 6月3日・腿日」)、每個 evolution tier badge,全部係玩家真實訓練嘅收據。冇呢個 screen,workout 嘅累積就只係 combat 入面嘅隱形 multiplier。

## Player Fantasy

> **Framing**(creative-director 裁定 2026-06-07):**「門框刻度」(The Doorframe)** — direct engagement surface;runner-up「角落人嘅枱」prep 聲線吸收入 loadout panel micro-copy 層。

### 核心情緒:回望先睇得到嘅成長

安靜、earned 嘅自豪 —「呢啲數字冇一格係送嘅」。#21 Loot Modal 係 burst surface(一瞬、亮、workout 期間);#22 嘅 temporal mode 完全相反:home / IDLE、唔攰、有時間、主動打開。情緒唔係 dopamine,係 dopamine 嘅**沉澱** — #21 影低一格格嘅相,#22 係啲相同刻度累積成一條可見時間線嘅地方。

**Anchor moment**:Rest day 夜晚,玩家攤喺梳化打開 game,入 Character Screen。Avatar 做 idle animation。佢望住 STR:47 — 佢冇諗起邊次爆裝嘅閃光,佢諗起嘅係一月嗰陣呢度係 30。手指掃過把劍:「拾於 6月3日・腿日」。「哦…嗰日。」成個 screen 係一道門框 — 屋企人幫細路量高嗰啲鉛筆刻度,你企返埋去,先見到自己高咗幾多。

### 聲線規則

- **數字 + 日期做主語**,形容詞係雜音(同 #21「數字行先」原則同源,但時態相反:#21 係 present-tense 快門 caption,#22 係**過去式收據** — 翻簿係回望)
- **零 hype、零感嘆號** — 呢個 screen 嘅聲線係 quiet ledger,唔係 #21 EPIC caption 嘅證人 hype 聲
- 承繼 Pillar 1 rule:**禁正向運氣歸因**
- **禁 progress-bar / 百分比 KPI 語言** — 刻度係 marks,唔係 progress(冇 implied endpoint;fitness transformation narrative 本來就冇終點)
- **Loadout panel 一角望前**(「角落人」聲線吸收位):AntiSnowball badge 嘅「練多啲,解放佢嘅全力」— 件裝備等緊你嘅身體追上佢。Screen 整體回望,loadout 一角望前,呢個張力係健康嘅。
- **第二個聲明例外 — milestone hint**(CD C2):「下次 Mirror Moment 就快到」係一句望前嘅話,serve Pillar 5 anticipation、唔劇透內容(Rule 11 / EC-16)— 同 loadout 一角並列,係 design test 嘅兩個 carved-out 例外;其餘 micro-copy 一律過 test。

### Metaphor 邊界(protect #29)

「鏡子」metaphor 係 Pillar 5 / #29 Mirror Moment 嘅 ceremony 資產(ADR-0010 ownership split)— #22 **唔搶**。Avatar preview 一節可以輕觸(「佢企喺度,記住你今日練咗乜」),但唔升做 screen-level framing;#22 **永不 reveal 新 evolution** — 每週揭幕係 #29 嘅儀式。

### Design test

任何 #22 micro-copy,問:「呢句係咪一格有日期嘅刻度?」— 如果佢係 hype、係 progress %、係預測未來,就唔屬於呢個 screen。

**Pillar 對齊**:Pillar 1 primary(provenance text = 有日期嘅刻;evolution tier badge = 大格刻度;AntiSnowball「+84 / +90」= 下一格刻喺邊嘅預告)· Pillar 4(「今日 class: STRIKE」posture 顯示)· 支援 Pillar 3(loadout 管理)。

## Detailed Design

> **Ground-truth note**:#11 / #17 / #26(GDD)/ #6 已 shipped/approved — 本 section 所有 API 名同 return shape 以 shipped code 為準(`src/autoload/inventory_system.gd` / `stat_system.gd` / `screen_effects.gd`),grep-verified 2026-06-07。

### Core Rules

**A. 入口 / GSM lifecycle**

1. **入口條件**:open 條件 = `GameStateMachine.get_current_state() ∈ {IDLE, DISCONNECTED}`。其他 state 時入口 affordance **隱藏**(pin:hidden,唔係 greyed — workout 期間 nav 雜訊歸零,Pillar 2;唔係 tap 咗先彈 error)。**入口 affordance 由 host shell own**(home nav — #24/shell 未 design,provisional):shell 自己 subscribe GSM 控制 affordance 顯示;#22 提供 pure check `can_open() -> bool` + `open()` 內 re-check(double guard)— 咁先保得住 Rule 8 嘅 CLOSED 零-subscription invariant。**禁止重用 #33 `is_input_permitted()` 做入口 check** — 語意唔同:`REST_PERIOD` 時 `is_input_permitted()==true`(一 tap window 係留俾 #20 next-exercise tap),但 #22 必須鎖(#33 glance budget <2s policy:#22 係 >2s 注意力 surface — Pillar 2)。
2. **Pure overlay**:open 唔 pause game、唔改任何 game system state。#22 own 嘅 state 只有 UI state(`active_panel` / `modal` / settings 顯示值)。
3. **Force-close**:OPEN / OPENING 期間 GSM `state_changed` → 任何 ∉ `{IDLE, DISCONNECTED}` → FORCE_CLOSING:cancel 晒所有 modal(`SALVAGE_CONFIRM` = **cancel,永不 confirm** — destructive action 永不被 system event auto-confirm)、skip 出場 animation(≤150ms fast path)、唔 auto-fire 任何 pending command。`SUSPENDED`(tab hidden)→ instant snap CLOSED(無 animation);resume 返嚟**唔 auto-reopen**(Pillar 2 — screen 係玩家主動行為)。`DISCONNECTED → WORKOUT_ACTIVE` 直跳(GSM AC-24 `resume_target` recovery,唔經 IDLE)同樣行 force-close path。**FORCE_CLOSING / SUSPENDED snap 一律零 SFX** — `ui_charscreen_close` cue 只屬 player-initiated close(force-close 嗰刻 GSM 正轉入 workout state,一響 thock 就係 workout-entry 雜訊 — P2 audio channel 同 visual channel 一齊鎖;CD C1)。
4. **IDLE ↔ DISCONNECTED 互轉**:唔 force-close — 兩個都係 permitted state,只 toggle offline banner。**DISCONNECTED 時全功能照行**(equip / unequip / lock / salvage / settings — #17 / #11 / #26 全 local autoload;ADR-0003 unsynced-only client wins)— positive assertion,唯一分別係 banner。
5. **Close 手勢**:persistent X button(visual + tap surface ≥48px)+ ESC(desktop keyboard)。Browser back button MVP **唔 intercept**(SPA history 整合 → Open Questions)。CLOSING 期間 re-tap open = ignore(唔 queue — queue 會喺 force-close 場景產生鬼 open)。
6. **Close 唔取消 upstream writes**:任何 close path 永不 cancel #17 已 debounce 嘅 persistence write — write ownership 喺 #17,#22 唔掂。

**B. Data binding(stat panel + avatar panel)**

7. **Open 第一 frame synchronous read 齊**:#11 `get_stat(stat_id)` ×7(STR / DEX / VIT + max_hp / attack_power / move_speed / crit_chance)、#17 loadout state + per-slot `get_item(item_id)` + `get_aggregate_raw_and_effective()` + `get_forge_shards()`、#26 5 getters。全部 local sync read — **冇 loading state**,OPENING 係純 animation state。
8. **Subscription lifecycle**:open 時 subscribe #11 `stat_changed` + #26 `avatar_visual_updated` + GSM `state_changed`,一律用 `connect_for_initial_state`(ADR-0006 Contract 6);close 時全部 disconnect。**CLOSED state invariant = 零 active subscription** — 每次 open 經 sentinel 重攞 initial state,順手解決「closed 期間 data 變咗」嘅 stale 問題。
9. **上游禁令(binding)**:禁 poll #11(stat-system L725)、禁掂 #11 internal `_base`、#26 NO setters(CR-11)、**#22 永不自行計 stat aggregate / predicted final number**(會 duplicate #17 Formula 4 clamp logic)。
10. **`stat_changed` render 規則**:source == `EQUIPMENT` → 該 stat row 200-400ms ease 數字 tween + ↑/↓ arrow(stat-system L696)。**非 EQUIPMENT source → snap 更新,無 tween 無 arrow**(reconnect 後 backend reconciliation 補數唔應該演成「即場升級」— Pillar 1 誠實度)。同 row tween 進行中再收 signal → 由**當前顯示值** retarget,永不 queue 疊 tween。`old == new`(zero delta)→ 無 arrow 無 tween(#22 自己 guard,唔依賴 #11 唔 emit)。Aggregate push 一次掂 4 條 derived → 最多 4 row 並行 animate,per-row 獨立 tween(ADR-0001 budget 內)。
11. **Avatar panel**(persistent,唔屬 tab):render `get_visual_state()` + idle animation(`get_animation_state()`);「今日 class: [STRIKE]」label(`get_class_posture()`);「T[n]」tier badge(`get_evolution_tier()`);`is_ready_for_milestone_check()==true` → 一行 quiet 提示「下次 Mirror Moment 就快到」(唔 reveal 內容 — Player Fantasy metaphor 邊界)。
12. **ARIA announcement**:`avatar_visual_updated` significant change(class posture swap / tier transition)→ ARIA live region「Avatar 變為 [class] T[tier]」(#26 L987 contract);短時間多次 → coalesce 最後一條為準,唔 queue 讀多句。非 significant update silent。

**C. Loadout panel + commands**

13. **Loadout 顯示**:4 slot(3 functional + 1 cosmetic)per-slot card:item name + rarity badge(P-06:colored corner accent + 文字 label)+ `provenance_text`。Empty slot 有明確 empty-state render。**AntiSnowball badge**:`get_aggregate_raw_and_effective() -> {raw, effective}`;`raw > effective` 時顯示「+[effective] / +[raw](受真身上限約束)」+ ledger voice tooltip「練多啲,解放佢嘅全力」— 非紅色 alarm,「未解鎖潛能」視覺語言(#17 L335)。每次 loadout mutation 後 re-read。
14. **Command 模式(synchronous re-read)**:所有 #17 command(`equip(item_id, slot)` / `unequip(slot)` / `set_lock(item_id, bool)` / `salvage(item_id)`)係 **synchronous Dictionary return** `{"ok": bool, "error": String}`(shipped ground truth)— issue → 讀 return → **同 frame re-read 受影響 state → re-render**。NO optimistic UI、NO wait-for-signal(#17 冇 loadout signal — grep-verified)。
15. **Command error handling**:`"not_found"` / `"slot_type_mismatch"` / `"in_mailbox_claim_first"` / `"slot_empty"` / `"locked"` → re-read + non-blocking toast,無 crash 無 silent fail。**`"deferred_reentrancy"` 例外**:#17 會下一 frame 自動重放 command — #22 **唔 toast error**,下 frame re-read 收割結果。
16. **Stat delta on equip(OQ-1 裁決,2026-06-07)**:equip / unequip 嘅 stat 變化顯示**完全靠** #11 `stat_changed(EQUIPMENT)` 自然流入(Rule 10)— #21 modal 唔加 ticker slot,#17 唔使加 equip-result payload API。Item detail / picker 可以 side-by-side 顯示候選 vs 現役 item 嘅 `stat_modifiers`(per-item 原始數據),但禁 predicted final(Rule 9)。
17. **Inline slot-filtered picker(Gap-1 裁決)**:functional slot tap → bottom-sheet picker:列 `slot_affinity == slot` 且 `IN_INVENTORY` 嘅 items(cosmetic slot → cosmetic-only 同款);每 row:name + rarity badge + `stat_modifiers` 摘要 + locked 標記;揀 → `equip(item_id, slot)`。**邊界**:full inventory browse / sort / search / bulk-salvage = **#23 地盤**;picker 唔做 search、唔跨 slot。Picker 內 sort:rarity desc → acquired date desc(免依賴 #17 private score)。
18. **Lock affordance(#17 L63 forward flag 兌現)**:manual `equip` 成功 + 該 item `is_locked == false` → **unconditional inline nudge**:「未上鎖 — 下次自動換裝可能換走佢 [鎖定]」一行 + per-slot lock toggle highlight。唔計「較弱」score(#17 score 係 private,`equip()` return 冇 displacement 資訊 — 零 duplicate scoring;任何 unlocked manual choice 都可以被 auto-equip 換走,unconditional 係誠實兌現)。Per-slot lock toggle 常駐 loadout card。
19. **Salvage 兩步 friction**:salvage = tap → `SALVAGE_CONFIRM` modal(`salvage_yield(rarity)` static preview + `provenance_text` + rarity badge)→ confirm。**永無單 tap 毀件路徑**。Salvage EQUIPPED item:allowed(#17 內部 auto-unequip),modal 加「現役裝備 — 會自動卸下」warning 行。LEGENDARY / 帶 `source_receipt` 件 → modal 顯示 `signature_text` + 加重 confirm 字眼(對齊 #17「receipt 件永不 silent expire」價值觀)。
20. **Locked item 嘅 destructive 入口灰掉**:locked item salvage 入口 disabled +「上鎖中 — 解鎖先可以分解」hint(shipped ground truth:`salvage` L555 reject `{"error": "locked"}`;lock 免疫**所有** salvage path 包括 bulk)。
21. **Cosmetic slot 通道分離**:cosmetic equip 永不餵 #11(#17 Rule 8 structural exclusion)→ 期望 feedback 係 `avatar_visual_updated`(preview 換裝),**唔係** stat animation — 兩條 feedback 通道唔撈亂。
22. **Provenance touch 等效**:無 hover(touch primary)→ canonical 路徑 = item tap → `ITEM_INSPECT` view(detail + provenance + LEGENDARY `signature_text`)。唔用 long-press(web touch 有 context-menu 衝突)。
23. **Panel visibility re-read(Gap-2 裁決)**:panel / tab 每次 visibility 切換時 re-read 對應 data source(切返嚟 = re-read)— 封 cross-surface mutation(e.g. #23 bulk-salvage)嘅 stale 風險,零 upstream 改動。
24. **Auto-equip 反轉事後可見性(Gap-5 裁決)**:MVP **silent 接受**(玩家冇 lock 嘅 manual 選擇被 auto-equip 換走,下次開 screen 見到新 loadout,無 change-log)。Rule 18 嘅 equip-time nudge 係 primary 防線;「上次自動換裝 X→Y」note → v0.2(Open Questions)。

**D. Accessibility Settings panel**

25. **MVP 內容**:P-07 motion-intensity slider(`ScreenEffects.set_motion_intensity`,0.0-1.0,percentage label,keyboard ±0.1)+ P-08 reduce-camera-motion toggle(`Camera.set_motion_reduction(bool)` — #7 story 011 contract,本 GDD pin 後解鎖)。Q-F5 hud-shake-inclusion toggle → **v0.2**(機制係 master scene CanvasLayer 重排,等 master scene 成形 — Open Questions)。
26. **Apply-on-change,無 Save button**:slider / toggle 改值即時 call consumer setter — settings 冇「draft 未儲存」概念,force-close 永不丟 settings。
27. **Persist timing**:slider **release** / toggle flip 先觸發 `PersistenceLayer.write("settings.[key]", value)`(debounced single write per settle)— drag 每 tick 寫 = ADR-0003 syncfs 災難。Persist fail(Private Mode,ADR-0003 detect-and-gate)→ settings session-only 生效 + non-blocking banner「設定今次有效,未能儲存」。
28. **現值 source(Gap-3 裁決)**:#22 panel open 時讀 `PersistenceLayer.read()` 嘅 `settings.*` keys(documented defaults:`motion_intensity` 1.0 / `camera_motion_reduction` false)— consumer autoload **冇 getter**(grep-verified)。#22 只寫 validated 值(slider 已 clamp 0-1),consumer setter 同 persisted 值由 boot self-read 保持一致(見 Rule 29)。
29. **Boot application ownership(Gap-3 / decision 4)**:**無 SettingsManager autoload**。每個 consumer autoload 喺自己 `_ready()` self-read 對應 `settings.*` key 並 apply(P-07 spec 嘅 boot 行為)— #6 / #7 各加一個 additive story(G-CS-2 / G-CS-4)。#22 只負責:UI + live setter call + persist write。
30. **Slider 操作細節**:HIT_HEAVY live preview 喺 slider **release** 時播一次(唔係 drag 期間連續播);快速來回 drag → consumer call per-frame coalesce(**coalesce locus = #22-side** — #6 唔使改)+ preview SFX cancel-restart 唔疊聲。Preview 經 **#6 additive preview API**(G-CS-4 — shipped `screen_effects.gd` public 只有 `shake(intensity, duration)`,HIT_HEAVY params 收埋喺 internal preset table L194;#22 唔 hardcode magic numbers)。

### States and Transitions

```
CLOSED ──open()[GSM ∈ {IDLE, DISCONNECTED}]──► OPENING(入場 animation;data 已喺第一 frame sync read 齊)
                                                  │ animation 完成
                                                  ▼
        ◄──CLOSING(出場 animation)◄──close()── OPEN
CLOSED                                            │ GSM state_changed → ∉ {IDLE, DISCONNECTED}
        ◄──FORCE_CLOSING(≤150ms;cancel modals)◄─┘(SUSPENDED = instant snap,無 animation)
```

| State | 進入條件 | 行為 | 離開 |
|-------|---------|------|------|
| `CLOSED` | boot 默認 / close 完成 | **invariant:零 active subscription**;入口 affordance 跟 GSM state 顯示/隱藏 | `open()`(Rule 1 條件)|
| `OPENING` | open() 獲准 | 第一 frame sync read 齊 + subscribe(Rule 7-8);入場 animation | animation 完成 → OPEN;GSM force-close → 直接 abort 去 CLOSED(skip OPEN)|
| `OPEN` | OPENING 完成 | 互動;orthogonal 軸:`active_panel ∈ {STATS, LOADOUT, SETTINGS}` × `modal ∈ {NONE, SALVAGE_CONFIRM, ITEM_INSPECT, SLOT_PICKER}`;flag:`offline_banner` | `close()` → CLOSING;GSM → FORCE_CLOSING |
| `CLOSING` | 玩家 close | 出場 animation;期間 re-tap open = ignore | animation 完成 → CLOSED + disconnect 全部 |
| `FORCE_CLOSING` | GSM 轉入非 permitted state | cancel 所有 modal(SALVAGE_CONFIRM = cancel)、skip animation(≤150ms)、唔 fire pending command | → CLOSED + disconnect 全部 |

**Avatar preview panel** 係 persistent element(唔屬 `active_panel` 軸)。

### Interactions with Other Systems

| System | 方向 | 性質 | Interface |
|--------|------|------|-----------|
| **#11 Stat System** | IN(read + subscribe) | Hard | open 時 `get_stat(stat_id)` ×7;subscribe `stat_changed` via `connect_for_initial_state`;EQUIPMENT source → tween + arrow(Rule 10)。禁 poll / 禁 `_base` |
| **#17 Equipment & Inventory** | IN(read)+ OUT(command) | Hard | commands `equip` / `unequip` / `set_lock` / `salvage`(Dictionary return);reads `get_item` / `get_aggregate_raw_and_effective` / `get_forge_shards` / `salvage_yield`(static)+ **G-CS-1 additive getters**(`get_loadout()` copy + slot-filtered enumeration — GDD L127 應承,code 未有) |
| **#26 Avatar Renderer** | IN(read + subscribe) | Hard | 5 read-only getters(CR-11)+ `avatar_visual_updated` subscribe;ARIA announcement 兌現(#26 L987) |
| **#1 GSM** | IN(read + subscribe) | Hard | `get_current_state()` 入口 check;subscribe `state_changed` force-close(Rule 3);handler 內如需觸發 GSM 行為必須 `call_deferred`(GSM emit-before-release) |
| **#3 PersistenceLayer** | OUT(write)+ IN(read) | Hard | `settings.*` keys(G-CS-3 namespace 註冊);write on settle(Rule 27);read on panel open(Rule 28) |
| **#6 ScreenEffects** | OUT(setter) | Hard | `set_motion_intensity(float)` live call;boot self-read = #6 additive story(G-CS-4);Q-F5 toggle v0.2 |
| **#7 Camera** | OUT(setter) | Hard | `set_motion_reduction(bool)`(story 011 — 本 GDD pin contract 解鎖;boot self-read 同款 G-CS-2) |
| **#33 Attention Budget** | (none) | — | **明文唔用** `is_input_permitted()`(Rule 1 語意分離);#22 跟 #33 嘅 glance-budget policy 用自己嘅 GSM state set 兌現 |
| **#21 Loot Modal** | (pattern 共用) | Soft | P-06 rarity 語言 pattern 級共用;OQ-1 裁決:ticker 留 #22(Rule 16),#21 唔加 slot — 回寫 #21 OQ-1 row(G-CS-5) |
| **#23 Inventory UI** | 邊界 | Soft | picker 唔做 browse / search / bulk(Rule 17 邊界);#23 係 full inventory surface |
| **#18 PR Detection** | (v0.2) | Soft | PR history panel = v0.2(`get_baselines()` read-only) |
| **#28 Telemetry** | (v0.2) | Soft | 上週對比 = v0.2(#28-dependent — 裁決 2026-06-07) |
| **#29 Mirror Moment** | (metaphor 邊界) | Soft | #22 永不 reveal 新 evolution;`is_ready_for_milestone_check()` 提示唔劇透(Rule 11) |

## Formulas

> **統一設計原則 —「Formatter 就係 epsilon」**:#22 所有 visibility / animation predicate 一律比較 **formatted display 值**,唔比較 raw float(#17 aggregate 同 #11 stat 都係 float)。Raw float 比較會產生三類 bug:badge 因 1e-7 誤差閃現、「↑ arrow 但數字冇變」phantom arrow、sub-display-unit tween。將 predicate 綁喺 formatter 上,三類一次過消滅,唔使揀 magic epsilon。F1 / F4 / zero-delta guard 全部建基於呢條原則。

### F1 — Stat tween display function

The `display_value` formula is defined as:

`display_value(t) = fmt_s( lerp(v_from, v_target, ease_out_cubic(t / STAT_TWEEN_MS)) )`,where `ease_out_cubic(u) = 1 - (1 - u)^3`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| tween 起點 | `v_from` | float | per-stat(#11 定義) | retarget 時刻嘅當前 interpolated 值 |
| tween 終點 | `v_target` | float | per-stat | signal 帶嚟嘅新值 |
| elapsed | `t` | float (ms) | 0 – STAT_TWEEN_MS | tween 已行時間 |
| duration | `STAT_TWEEN_MS` | int (ms) | **200–400(#11 L696「typically」建議 band — #22 pin 做 hard local constraint;CD C3)** | **constant**,default 300(band 中點 — 向兩邊留最大 tuning headroom;唔跟 \|delta\| scale:4-row 並行 push constant ⇒ 全部同時落定 = 單一「刻低」settle moment;200 貼 floor 易讀成 snap-blink,400 貼 ceiling 連續操作成段 mid-tween) |
| formatter | `fmt_s` | func | — | per-stat display formatter(見 Format Table) |

**Output Range:** bounded 喺 `[min(v_from, v_target), max(v_from, v_target)]` — ease-out-cubic monotonic、**零 overshoot**。Overshoot 曲線(back / elastic)會有一瞬顯示玩家從未擁有過嘅 stat 值 = 數字講大話 — **曲線係 pinned design constant(Pillar 1 約束),唔係 knob**。
**Retarget 規則**(formalize Rule 10):mid-tween 新 signal → `v_from := 當前 interpolated 值`,clock 歸零,`v_target := 新值`,永不 queue。Arrow 方向 = `sign(v_target − v_display_at_retarget)`,**operand pin:`v_display_at_retarget` = raw interpolated 值(即新 tween 嘅 `v_from`),唔係 formatted 值**(roundi monotonic ⇒ sign 一致,但 golden vector 測試要 pin 一個)— retarget 可令 arrow 反轉。
**Zero-delta guard(formatter-based)**:`fmt_s(v_target) == fmt_s(當前 display 值)` → 無 tween 無 arrow(必要時 kill 進行中 tween 並 settle)。
**Example:** equip 令 attack_power 84→90,STAT_TWEEN_MS=300。t=150ms:u=0.5,ease=1−0.5³=0.875,值=84+6×0.875=89.25 → fmt →「89」。呢刻第二次 aggregate push 到(target 95)→ v_from:=89.25,clock 歸零,新 tween 89.25→95 行足 300ms。

### F2 — Settings slider quantization + percentage label

The `settings_quantize` formula is defined as:

```
pct     = roundi(clampf(v_raw, 0.0, 1.0) × 100)    # UI canonical state = int pct
v_store = float(pct) / 100.0                        # setter call + persist 值
label   = "%d%%" % pct
keyboard: pct := clampi(pct ± 10, 0, 100)           # P-07 binding ±0.1 step
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| raw input | `v_raw` | float | unbounded(drag / persist read) | slider drag 原始值或 persisted 讀入值 |
| canonical | `pct` | int | 0–100 | UI source of truth(101 個離散值)|
| stored | `v_store` | float | {0.00, 0.01, …, 1.00} | 傳俾 `set_motion_intensity()` + `PersistenceLayer.write()` |
| label | `label` | string | "0%"–"100%" | P-07 percentage label |

**Output Range:** `v_store` 嚴格落喺 101 點 grid,clamped(`set_motion_intensity` 自己都 clamp — screen_effects.gd L394 — 但 #22 唔依賴佢,Rule 28 只寫 validated 值)。
**Rationale:**(1)int `pct` 做 source of truth ⇒ keyboard ±0.1 永不累積 binary float drift;(2)shake amplitude perceptual JND(vibrotactile Weber fraction ~10-20%)遠粗過 1% — quantize 零感知損失;(3)label ↔ stored 值一一對應,「0.999 顯示 100% 但唔係 1.0」嘅 EC class 由設計上消滅。**1% grid 係 pinned constant(改 grid = label bijectivity 失效),唔係 knob。**
**Example:** drag raw 0.6789 → pct=68 → store 0.68 → label「68%」→ `set_motion_intensity(0.68)`。

### F3 — Picker sort comparator

The `picker_before` predicate is defined as:

```
picker_before(a, b) :=
    a.rarity > b.rarity                                                  # 1. rarity desc
 ∨ (a.rarity == b.rarity ∧ a.acquired_at_unix > b.acquired_at_unix)     # 2. acquired desc(新先)
 ∨ (前兩級全 tie ∧ String(a.item_id) < String(b.item_id))               # 3. item_id asc(final)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| rarity | `rarity` | int (RarityTier) | COMMON(0)–LEGENDARY(4) | #15/#17 canonical tier |
| acquired | `acquired_at_unix` | int | unix **seconds** > 0 | #17 item field — 秒級解像度,batch grant(mailbox claim 多件)同秒 tie 係**常態**,必須有 final tie-break |
| id | `item_id` | StringName→String | unique | 最終 tie-break,保證 strict total order |

**Output Range:** `item_id` unique ⇒ strict total order,zero residual tie ⇒ 每次 open 結果 byte-identical(deterministic,unit-testable)。
**Divergence note(intentional,防 verifier false-flag)**:#17 內部 `_candidate_beats`(inventory_system.gd L786-796)嘅 acquired_at 方向係 **asc(舊先 — auto-equip churn minimization)**;#22 picker 係 **desc(新先 — browse recency,「啱啱爆嗰件喺邊」)**。方向相反係 intentional — 兩個 comparator 服務唔同目的;第三級 item_id asc 同 #17 L796 一致。**Comparator 鏈係 pinned(改序 = determinism test 全爆),唔係 knob。**
**Example:** 3 件 —(EPIC, t=1000, `sword_a`)、(EPIC, t=1000, `axe_b`)、(RARE, t=2000, `bow_c`)→ `[axe_b, sword_a, bow_c]`(EPIC 同秒,"axe_b"<"sword_a" 字典序;RARE 雖新但 rarity 行先)。

### F4 — AntiSnowball badge visibility predicate

The `badge_visible` predicate is defined as:

```
disp(x)       = roundi(x)
badge_visible = disp(raw) > disp(effective)
badge_text    = "+%d / +%d(受真身上限約束)" % [disp(effective), disp(raw)]
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| raw | `raw` | float | ≥ 0 | `get_aggregate_raw_and_effective().raw`(inventory_system.gd L895-901)|
| effective | `effective` | float | 0 ≤ effective ≤ raw(#17 Formula 4 clamp 結構保證)| 同上 `.effective` |
| formatter | `disp` | func→int | — | **同 badge 文案同一個 formatter** — formatter 就係 epsilon |

**Output Range:** `disp(effective) ≤ disp(raw)` 永真(clamp + roundi monotonic)⇒ predicate 單方向,冇「effective > raw」分支。Badge 出現 ⇔ 文案兩個數字唔同 ⇔ 文案有意義 — 三者由構造上等價。
**Example:** raw 90.4 / effective 90.0 → disp 90 vs 90 → **hidden**(否則文案 render「+90 / +90(受真身上限約束)」自相矛盾)。raw 90.6 / effective 90.0 → 91 vs 90 → 顯示「+90 / +91(受真身上限約束)」。

### Per-stat Display Format Table(F1 `fmt_s` / F4 `disp` 嘅 shared dependency)

| Stat | Source range(stat-system.md)| Format | Example |
|------|------------------------------|--------|---------|
| STR / DEX / VIT | 0–999(MAX_STAT_VALUE)| `roundi` int | 「47」 |
| max_hp | [80, ~8072](L362)| `roundi` int | 「1240」 |
| attack_power | [10, ~4500](L391)| `roundi` int | 「96」 |
| move_speed | [90.0, 420.0] px/s(L419)| `roundi` int | 「210」 |
| crit_chance | [0.0, 0.50] fraction(L447)| `"%d%%" % roundi(x×100)` | 「7%」 |

Sub-display-unit 變化(e.g. crit_chance 0.071→0.074)由 formatter guard 自然吸收 — 無 phantom arrow(Pillar 1 誠實度)。

### 明確「唔需要 formula」清單(presentation layer 誠實地薄)

| 候選 | 裁決 | 理由 |
|------|------|------|
| Salvage yield preview | Rule(Rule 19)| 直接 call #17 static `salvage_yield(rarity)`(inventory_system.gd L911;COMMON 100 → LEGENDARY 800)— #22 自己寫 = duplicate ban 同類違規 |
| forge_shards 顯示 | Rule | `get_forge_shards()` int verbatim render;MVP 禁 K/M abbreviation — ledger 數字係收據,唔縮寫 |
| provenance_text / signature_text / tier badge | Rule | upstream 已 derive 好,verbatim display |
| Force-close ≤150ms | Knob | 一個 cap 常數(Tuning Knobs)|

## Edge Cases

> 格式:**If [condition]**: [exact outcome]。分 6 組;全部有 resolution,無「handle appropriately」。

### A. Lifecycle / GSM races

- **EC-01(force-close × destructive modal)**:If `SALVAGE_CONFIRM` 開緊 + GSM → `WORKOUT_ACTIVE`:modal **cancel**(永不 confirm)、item 不變、screen force-close。Destructive action 永不被 system event auto-confirm。
- **EC-02(open 同 frame signal race)**:If OPENING 期間 `avatar_visual_updated` fire,而 `connect_for_initial_state` sentinel 又派一次 initial state → 同 frame 收兩次:render 必須 **idempotent**(same-state re-render 無視覺 glitch)。
- **EC-03(DISCONNECTED → WORKOUT_ACTIVE 直跳)**:If screen open 喺 DISCONNECTED,`poll_recovered` 帶 `resume_target=WORKOUT_ACTIVE`(GSM AC-24,唔經 IDLE):照行 force-close path — force-close 唔可以假設「必經 IDLE」。
- **EC-04(同 frame equip + force-close,三 ordering 都 pin)**:(i)If equip 已 synchronous 執行 + return 已讀,同 frame GSM force-close:command 結果**成立**(#17 state 已 mutate — Rule 6 close 永不 cancel upstream write);re-read / re-render skip(screen 閂緊);pending toast **drop**;下次 open 先見新 loadout。(ii)If force-close 先處理:FORCE_CLOSING 內所有 command input **ignore**。(iii)If command return `deferred_reentrancy` 然後 force-close:#17 下 frame replay 係 #17 自己機器,**照行**(#22 冇能力 cancel 亦唔應該);#22 唔 re-read 唔 toast,結果下次 open 收割。
- **EC-05(signal 喺 CLOSING / FORCE_CLOSING 到達)**:If 任何 subscribed signal 喺 closing states 到達:handler 一律 no-op guard(`state ∈ {OPENING, OPEN}` 先 render)— disconnect 喺 CLOSED 先完成,中間有 window。
- **EC-06(IDLE↔DISCONNECTED toggle 時 modal open)**:If banner toggle(Rule 4)發生喺 modal open 期間:modal **唔受影響**,只 banner 換 — 明文,免 implementer 順手 dismiss。
- **EC-07(modal open 時嘅 close 手勢 routing)**:If `SALVAGE_CONFIRM` / picker / inspect open 時撳 ESC 或 X:**第一下只 dismiss modal**(destructive modal default = cancel),第二下先 close screen。Modal capture priority > screen — 一下 ESC 連 screen 一齊閂 = 玩家想取消 salvage 但成個 screen 冇埋,過罰。

### B. Data render

- **EC-08(zero-delta / sub-display-unit)**:If `stat_changed` 而 `fmt_s(v_target) == fmt_s(當前 display 值)`(包括 crit_chance 0.071→0.074 sub-display-unit):無 tween 無 arrow(F1 formatter guard;#22 自己 guard,唔依賴 #11 唔 emit)。
- **EC-09(retarget 中再 retarget)**:If tween 進行中連續收 N 次 signal:每次由當前 interpolated 值 restart(F1),永不 queue;signal 停 → 最後一條收斂。Bounded:每次 retarget 起點喺舊 path 上、target 永遠係 latest true 值 — 唔 oscillate 唔 backlog。4-row 並行 retarget 因 constant duration 一齊 restart,保持 lockstep。
- **EC-10(A→B→A 快手反悔)**:If mid-tween 新 signal 嘅 `fmt(v_target)` == `fmt(當前 display 值)`:kill tween、settle 該值、**清走 arrow**。Guard 比較對象係當前 display,唔係上一條 signal 嘅 old 值(用 raw old/new 比較會漏判)。
- **EC-11(tab 切走切返 mid-tween)**:If STATS panel tween 進行中切去 LOADOUT 再切返:Rule 23 re-read ⇒ **snap 到當前 true 值,kill 舊 tween,唔 resume**(resume 一條基於舊 read 嘅 tween 可能 tween 向 stale target)。
- **EC-12(aggregate {0,0} 新號 / 全空 loadout)**:If `get_aggregate_raw_and_effective()` 回 {0,0}:render「+0」,F4 ⇒ badge hidden。**唔** hide aggregate row —「+0」係誠實刻度,空門框都係門框。
- **EC-13(salvage 現役 → 空 slot)**:If salvage equipped weapon:slot 變空 → aggregate 跌 → 多條 stat row 同步 ↓ animate(EQUIPMENT source);空 slot 明確 empty-state render。
- **EC-14(CJK text overflow)**:If LEGENDARY `signature_text` / `provenance_text` 長 CJK string:wrap(多行)優先;空間死限先 ellipsis + ITEM_INSPECT 顯示全文。**唔可以 shrink font 落 12px Zpix floor 以下**(accessibility-requirements.md L87)。
- **EC-15(provenance timezone)**:「拾於 6月3日」display timezone = **device local**(#17 L66 forward flag — #22 presentation 責任)。跨 timezone 旅行後同一件 item 顯示日期可以變 — 接受並寫明,唔做 timezone pinning。
- **EC-16(milestone readiness mid-session flip)**:If `is_ready_for_milestone_check()` 喺 screen open 期間先變 true:hint 只喺 open + `avatar_visual_updated` 時 evaluate — readiness 唔屬 visual state,#26 冇 per-readiness signal(grep-verified:#26 signals = `avatar_visual_updated` + `avatar_evolution_milestone`,後者係 #29 嘅)。Mid-session flip 唔追 real-time,下次 open 見到 — quiet hint 唔係 time-critical。

### C. Commands

- **EC-17(stale item_id command)**:If #22 UI row 仍顯示某 item 但佢已被消滅(e.g. #23 喺另一 surface bulk-salvage):command return `{"ok": false, "error": "not_found"}` → re-read + non-blocking toast,無 crash 無 silent fail。
- **EC-18(salvage confirm 撳落去 item 已死)**:If `SALVAGE_CONFIRM` open 期間 item 被另一路徑消滅(mailbox TTL auto-salvage / hard-cap FIFO — time/grant-driven,IDLE 都會 fire):confirm tap → `not_found` → close modal + toast「件物品已唔存在」+ 全 loadout panel re-read;#22 **零**自行 shards 變動(credit 係消滅嗰下 #17 已做,re-read 自然反映)。Yield preview 唔會「過時但件還在」— rarity 係 immutable field,件存在 preview 必準;唯一 stale class = 件唔存在,即本 EC。Confirm 嘅 validation = synchronous return 本身,唔使 pre-check。
- **EC-19(picker 內 stale item)**:If picker row tap equip 而 return `not_found`:toast + **picker list 原地 rebuild**(唔 close picker);rebuild 後空 → 落 EC-20 empty state。Close 成個 picker 懲罰玩家多過個 bug。
- **EC-20(picker empty list)**:If slot tap 而 match 結果 = 0 件:picker **照 open**,render empty-state copy(「呢個 slot 暫時冇後備裝備」)+ close affordance;**唔** disable slot tap、**唔** auto-close — disabled tap 係 mystery meat,empty sheet 教玩家 inventory 狀態。
- **EC-21(auto-equip 反轉)**:If 玩家 manual equip 冇 lock,下次 reveal auto-equip 換返:MVP **silent 接受**(Rule 24);Rule 18 equip-time nudge 係 primary 防線;「上次自動換裝 X→Y」note → v0.2(Open Questions Q-CS2)。
- **EC-22(lock × salvage)**:If item `is_locked == true`:salvage 入口 **disabled** +「上鎖中 — 解鎖先可以分解」hint(shipped ground truth:`salvage` L555 reject `{"error": "locked"}`;lock 免疫所有 salvage path 包括 bulk)。
- **EC-23(deferred_reentrancy)**:If command return `{"ok": false, "error": "deferred_reentrancy"}`:#17 下一 frame 自動重放 — #22 **唔 toast**,下 frame re-read 收割結果(Rule 15)。

### D. Settings

- **EC-24(slider release 喺 0.0)**:If pct==0 時 release:HIT_HEAVY preview call **照發**(uniform code path),ScreenEffects `motion_intensity==0` short-circuit ⇒ 零 visible motion — **intentional,唔准 fake shake**(preview 語意係「感受結果」,0 嘅結果就係無;fake 一下 = 設定講大話)。Confirmation = 「0%」label + ARIA announce。
- **EC-25(persisted legacy / corrupt float)**:If persist 讀入 0.999 等非 grid 值:panel open apply F2 quantize 後先 render(pct=100 顯示「100%」),但**唔即時 rewrite persistence**(write 只喺 user settle — 避免 open-time write storm 撞 ADR-0003 syncfs);#6 boot self-read 用 raw float,同 UI 顯示最多差 0.005,感知為零;下次 user settle 自然 normalize。
- **EC-26(slider spam)**:If 快速來回 drag:consumer call per-frame coalesce + preview SFX cancel-restart 唔疊聲 + 只喺 settle 後一次 persist write(Rule 27/30)。
- **EC-27(drag 中 force-close / SUSPENDED snap)**:If drag 中(release 未發生)遇 force-close:**當 force-close = settle** — 以當前 applied 值 enqueue `PersistenceLayer.write`,先寫後閂(enqueue sync,durability 係 #3 嘅事)— Rule 26「force-close 永不丟 settings」嘅 operationalization。Private Mode persist-fail:value 留 session-applied,banner **suppress**(screen 閂緊,冇地方掛)。
- **EC-28(keyboard 邊界)**:If pct==100 撳 `+`(或 0 撳 `−`):clamp no-op,**唔** wrap、唔 error SFX;ARIA announce 該值一次後 coalesce(撳住唔放唔 spam「100%」×20)。

### E. Accessibility

- **EC-29(ARIA spam)**:If 短時間多次 `avatar_visual_updated` significant change(tier + posture 同時變):announcement coalesce — **最後一條為準**(`ARIA_COALESCE_WINDOW_MS`),唔 queue 讀多句。

### F. DISCONNECTED

- **EC-30(DISCONNECTED 全功能 — positive assertion)**:If GSM == DISCONNECTED:equip / unequip / lock / salvage / settings **全部照行**(#17 / #11 / #26 全 local autoload;ADR-0003 unsynced-only client wins)— 唯一分別係 offline banner。明文寫低,唔留白。

### G. Audio

- **EC-31(web 首次 gesture = open #22)**:If 玩家喺 web 嘅第一下 gesture 就係 open #22 嘅 tap:`ui_charscreen_open` SFX 可能撞 #4 AudioManager LOCKED state 被 drop(#4 Rule 5 one-shot 唔 defer)— **接受,唔 workaround**(screen 本身 silent 開啟無損功能;audio unlock 由 #4 own)。

## Dependencies

### Upstream(#22 depends on)

| System | Hard/Soft | Interface(data 流向 #22)| Bidirectional 狀態 |
|--------|-----------|------------------------------|---------------------|
| **#11 Stat System** | Hard | `get_stat(stat_id)` ×7 read-on-open;`stat_changed` subscribe(`connect_for_initial_state`);禁 poll / 禁 `_base` | ✅ #11 L260/L586/L696/L718 已列 #22 |
| **#17 Equipment & Inventory** | Hard | commands(`equip`/`unequip`/`set_lock`/`salvage`,Dictionary return)+ reads(`get_item`/`get_aggregate_raw_and_effective`/`get_forge_shards`/static `salvage_yield`)+ **G-CS-1 additive getters**(見下)| ✅ #17 L127/L288/L345-352 已列 #22 |
| **#26 Avatar Renderer** | Hard | 5 read-only getters(CR-11)+ `avatar_visual_updated` subscribe;ARIA contract 兌現 | ✅ #26 L290/L734/L964 content contract 已 forward |
| **#1 GSM** | Hard | `get_current_state()` 入口 check + `state_changed` subscribe(force-close);handler 內觸發 GSM 行為必須 `call_deferred` | GSM 係 Foundation hub — generic UI consumer,唔使逐個列 |
| **#3 PersistenceLayer** | Hard | `settings.*` read/write(**G-CS-3 namespace 註冊**)| 待 G-CS-3 執行時補 #3 GDD referenced-by |
| **#6 ScreenEffects** | Hard(setter 單向)| `set_motion_intensity(float)` live call | ✅ #6 UI Requirements 已 flag「motion_intensity slider UX Flag for #22」 |
| **#7 Camera** | Hard(setter 單向)| `set_motion_reduction(bool)` — **story 011 contract 由本 GDD pin 解鎖**(P-08)| ✅ #7 UI Requirements Q-V1 + AC-06b/AC-27 已 forward |

### Downstream(depends on #22)

| System | 性質 | 內容 |
|--------|------|------|
| **#7 Camera story 011 / AC-06b / AC-27** | 實作 gate | 本 GDD §UI Requirements pin 咗 `set_motion_reduction` UI contract → story 011 解鎖 |
| **#23 Inventory UI** | 邊界 contract | Rule 17 picker 邊界(#22 唔做 browse/search/bulk);#23 GDD authoring 時引用 |
| **#29 Mirror Moment** | metaphor 邊界 | #22 永不 reveal 新 evolution(Player Fantasy 章)|

### 非依賴(明文)

- **#33 Attention Budget**:#22 **唔用** `is_input_permitted()`(Rule 1 — 語意分離,#22 用自己嘅 GSM state set)。#33 嘅 glance-budget policy 由「workout 期間鎖死成個 screen」滿足 — 政策遵從,唔係 API 依賴。
- **#18 PR Detection / #28 Telemetry**:v0.2 先成為 upstream(PR history panel / 上週對比)— MVP 零接口。

### Cross-system gates(非 GDD defect — epic 開波前/期間執行)

| Gate | 內容 | 性質 |
|------|------|------|
| **G-CS-1** | #17 additive read getters:`get_loadout() -> Dictionary`(slot → item_id **copy**)+ `get_items_for_slot(slot) -> Array[StringName]`(slot-filtered IN_INVENTORY enumeration,F3 排序由 #22 做)— #17 GDD L127 應承「loadout state + per-item detail」,shipped code 只有 `get_item`(`_loadout` private,grep-verified 2026-06-07)| additive story(同 #17 G-LM-9 batch seam 先例)|
| **G-CS-2** | #7 story 011 spec 接線:`set_motion_reduction(bool)` setter + boot self-read `settings.camera_motion_reduction`(#7 GDD L697「SettingsManager autoload」措辭 → 以本 GDD Rule 29 consumer-self-read 取代 — #7 erratum note)| story 011 unblock + erratum |
| **G-CS-3** | `settings.*` namespace 註冊(#3 registry + entities.yaml;ADR-0003 process)— P-07 L243 已用 `settings.motion_intensity` key 但 namespace 未註冊(grep 0 hits)| namespace 申請 |
| **G-CS-4** | #6 additive story(兩件):(a)boot self-read — `_ready()` 讀 `settings.motion_intensity` 並 apply(shipped code 冇 boot read,L95 SettingsManager seam 留咗位);(b)**preview API** — expose `preview_hit_heavy()`(或等效)俾 #22 slider preview call,免 #22 hardcode internal preset params(qa-lead FLAG-3)| additive story |
| **G-CS-5** | #21 OQ-1 回寫:loot-drop-modal.md OQ-1 row → RESOLVED(裁決:ticker 留 #22 Rule 16,modal 唔加 slot)| doc erratum |
| **G-CS-6** | interaction-patterns.md errata:P-03「Used In: #22」加 sync note(F1 cubic-lerp-經-formatter ≠ P-03 33ms/step ticker — 免 implementer 錯套;同 G-LM-7 先例做法)| doc erratum |

## Tuning Knobs

| Knob | Default | Safe range | Too high | Too low | Source |
|------|---------|-----------|----------|---------|--------|
| `STAT_TWEEN_MS` | 300 | **200–400(#11 L696「typically」建議 band — #22 自我 pin 做 hard local constraint,出界 = 違本 GDD 唔係違上游;CD C3)** | 連續操作成段 mid-tween,數字「漿糊」感 | 4-row 並行讀成 snap-blink,arrow 共現時間太短 | F1 |
| `FORCE_CLOSE_MAX_MS` | 150 | 0–150(150 = Rule 3 pinned cap)| workout HUD 同 #22 並存 frame → Pillar 2 violation | 0 完全 OK(SUSPENDED 本來就 0)— 純 visual continuity 取捨 | Rule 3 |
| `SETTINGS_PERSIST_DEBOUNCE_MS` | 500 | 200–1000 | settle 後 tab 即死嘅 write-loss window 變大(EC-27 flush 已 mitigate 大半)| 微調連環 write → IndexedDB syncfs churn(ADR-0003)| Rule 27 |
| `LOCK_NUDGE_DURATION_MS` | 5000 | 3000–8000 | 常駐雜訊,撞 quiet ledger 聲線 | CJK 讀唔切(nudge ~20 字 ÷ 舒適 3-5 字/秒 ⇒ 下限 ~4s)| Rule 18 |
| `ERROR_TOAST_DURATION_MS` | 3000 | 2000–5000 | toast 堆疊遮 UI | error 未讀完消失 → 玩家以為 silent fail | Rule 15 |
| `ARIA_COALESCE_WINDOW_MS` | 800 | 500–2000 | announcement 同 action 脫節,SR user 唔知邊下觸發 | SR queue spam(coalesce 形同虛設)| Rule 12 / EC-29 |

### Pinned constants(明文非 knob — 免有人亂校)

- **Ease 曲線**(cubic ease-out)— 換 overshoot 曲線 = 顯示玩家從未擁有過嘅 stat 值,Pillar 1 問題(F1)
- **Slider keyboard step 10 pct** — P-07 L246 binding
- **F2 1% quantize grid** — 改 grid = label bijectivity 證明失效
- **F3 picker comparator 鏈** — 改序 = determinism test 全爆

### Referenced knobs(source of truth 喺上游 — #22 唔 duplicate)

| Knob | Owner | #22 關係 |
|------|-------|----------|
| `motion_intensity`(0-1)| #6 ScreenEffects | #22 係 UI surface,值嘅 semantics 由 #6 own |
| `camera_motion_reduction`(bool)| #7 Camera | 同上(P-08)|
| `hud_shake_inclusion`(bool)| #6(registry L1450)| v0.2 toggle(Q-CS3)|
| 200-400ms animation band | #11 L696 | `STAT_TWEEN_MS` 嘅 hard range 來源 |

## Visual/Audio Requirements

> art-director spec(2026-06-07,grep-verified 對齊 art bible / interaction-patterns / #4 shipped contract)。

### Master rule:#22 particle budget = 0(pinned)

Art bible §1.1:「剪影 carry identity,粒子 carry event,飽和度 carry priority」— #22 上面**冇 event,只有 record**。所有 dopamine 已喺 #21 burst 完,呢度係沉澱層 ⇒ 零 particle、零 flash、零 shake(唯一例外 = P-07 slider preview,嗰下 shake 係 #6 所有、player-initiated 試聽)。ADR-0001 mobile particle budget 完全唔使分配 — 唔係慳,係 statement。

**強度層級**:L0 static ink(狀態本身係 feedback)/ L1 ink shift(opacity/色 ≤150ms 無位移)/ L2 quiet motion(單一 tween,Snap+Settle §7.D,零 overshoot)/ L3 accent(amber arrow/highlight — **本 screen 天花板**)/ ~~L4+~~(particle/flash/shake/elastic — 禁)。

### Per-event visual feedback(摘要表)

| Event | 處理 | Tier |
|-------|------|------|
| Screen open / close | opaque `ui_ink_bg` slide-up + fade 150-200ms ease-out(close 120-150ms ease-in);content 一次過 final,**禁 staggered pop-in**(#21 S1 紀律)| L2 |
| Stat tween + arrow | m6x11 `ui_amber_primary` 數字;↑ = 8×8 amber sprite,↓ = 同形 `ui_text_dim`(方向由 glyph 形狀 carry — **永不紅綠**;EQUIPMENT ↓(unequip / salvage)唔係懲罰 — CD C4:reconciliation 係 snap 無 arrow,Rule 10);settle 後 hold ~1.2s fade 200ms;row 無 highlight flash | L3 |
| Equip 成功 | **零專屬 VFX(「完全無 VFX」名單頭號)** — feedback 全部係後果:slot card crossfade ~120ms + stat rows 自然 tween + cosmetic 行 avatar swap。Ledger 唔講「成功!」,ledger 俾你睇條數 | L1 |
| Lock nudge | slot card 下 slide-in `ui_ink_mid` strip(Zpix 12px)+ lock toggle amber accent ≤3px;**禁 pulse** | L2 |
| Salvage confirm modal | scrim ~60% + `ui_ink_mid` panel + 1px `ui_ink_hi` border;**無 elastic**(elastic 係 #21 ceremony 文法);confirm CTA = ink fill + `#D94B3E` 1px border(紅做 enhancement,friction 係結構性兩步);LEGENDARY signature = `ui_text_dim` 收據 footer 質感 | L2 |
| Salvage 執行 | card fade-out + collapse 200ms;shards 數字 **snap,無 celebration**(bookkeeping 唔係 reward);無破碎 particle | L1-L2 |
| Picker(bottom sheet)| slide-up 150-200ms + scrim;rows = P-06 item card pattern 一次過出現 | L2 |
| Offline banner | 頂部 ink strip + `ui_text_dim` + slate broken-link glyph;**amber 唔准用**(amber = actionable/stat;banner 係 status);static 唔 pulse | L1 |
| Empty states | 全 L0 static:空 slot = 1px pixel-dotted outline + slot silhouette glyph + dim label;「+0」照 render;無引導閃爍 | L0 |
| AntiSnowball badge | text chip:effective = `ui_amber_primary`,raw = **`ui_amber_dim #A87526`**(§4.D「brightness-reduced 非 desaturated」=「同一種貨幣,未着燈」— 「未解鎖潛能」嘅視覺翻譯);static | L0 |
| Tab switch / toast / inspect | snap-switch 80-120ms / ink strip slide / static panel | L0-L2 |
| Avatar swap(open 期間)| sprite snap swap,無 crossfade 無 white flash(pure white reserved for loot §4.A)| L1 |
| Milestone hint | 一行 `ui_text_dim` static — 零 glow 零動畫,連視覺都唔劇透 #29 | L0 |

**「完全無 VFX」名單(明文)**:equip 成功本身 / salvage 後 shards 入賬 / empty states / AntiSnowball badge / milestone hint / offline banner / avatar swap / provenance & signature 顯示。

### Style 約束(門框-ledger 嘅非 literal 轉化)

**禁 literal skeuomorphism**(無木紋/紙質/撕邊)。四個抽象 device:
1. **Tick-mark motif(screen signature)**:avatar panel 側 1px `ui_ink_hi` vertical rule + tier notches,current tier amber accent ≤3px — 量高刻度抽象化,成 screen 唯一裝飾元素
2. **Columnar 收據排版**:stat 數字右對齊 monospace 欄(m6x11),label 左數字右 — 賬簿行
3. **賬簿線 framing**:§7.A Menu layer 可有 frame,限 1px hairline + StyleBoxFlat ink 三層;**禁 #21 pixel-illustrated dirty frame**(ceremony 資產)
4. **留白紀律**:panel 間闊 gutter — quiet 唔單係冇 motion,係有空氣

**Palette**:amber + ink 雙色紀律(§7.A);rarity 五 hex(§4.B canonical)只出現喺 badge corner accent + 永配文字 label(P-06);`#D94B3E` 限 salvage CTA;**pure white 全 screen 禁用**。全屏 **opaque** ink base(行出個世界去讀本簿 — sidestep MoodController 依賴)。

**Avatar preview**:全身 32×32 native sprite **整數倍 scale**(3-4×,nearest);idle 2-frame breathing(§5.D)+ 2-3px secondary motion — screen 唯一持續動嘅嘢,刻意;背景 = abstract 單一 gradient(`world_ash` → `ui_ink_bg`,零 prop);**avatar saturation = 1.0**(§2.1「凸顯今日成果」;§2.1 vs §4.E 矛盾 → art bible erratum flag,Open Questions Q-CS6);「今日 class」label + P-04 16×16 class icon +「T[n]」badge chip。**§3.D 形狀紀律:#22 唔准引入圓形裝飾**(圓形 rank 2 reserved 俾 loot orb / exercise ring;avatar 頭除外)。

### Audio direction

**BGM:#22 零 `play_bgm` call** — #4 Rule 6 track map 無 IDLE entry ⇒ 維持當前 BGM;screen open/close 唔係 music event,唔改唔 duck 唔 fade(同 Rule 2 pure overlay 一致)。

**SFX palette:「紙、木、石墨」** — 全部經 `play_sfx(event_id)`(data-driven `SfxCatalog.tres`),全部 low priority mono(#4 AC-03b:永不 steal loot fanfare voice);質感 = 鉛筆刻一下/紙頁/軟木 thock;**零 chime 零 fanfare**(Pillar 3 reserved):

| Cue id(draft)| Event | 方向 |
|---|---|---|
| `ui_charscreen_open` / `ui_charscreen_close` | open / close | 低沉軟 thock + 紙(close = 短 reverse)|
| `ui_equip_settle` | stat tween **settle 一刻**(每 command 最多 1 響,4 row 並行都係 1)| 「刻一下」— 聲音 = 刻度落筆(Pillar 1)|
| `ui_lock_on` / `ui_lock_off` | lock toggle | 細金屬 click,on 略重 |
| `ui_salvage_execute` | salvage 執行 | 短 grind / 紙撕 — 唔係爆炸 |
| `ui_sheet_open` / `ui_sheet_close` | picker / modal | 軟 slide(共用)|
| `ui_toggle_flip` | P-08 toggle | 細 click |
| (重用)`ui_back` / `ui_error` | 返回 / error toast | #4 catalog 已有 |

**明文 silent 名單**:stat arrows(聲音歸 settle 一響)/ tab switch(cut,試玩先補)/ offline banner / lock nudge 出現 / empty states / milestone hint / slider drag(release 嘅 HIT_HEAVY shake 本身就係 preview,**唔加** hit SFX;EC-28 clamp 唔 error SFX)/ **force-close + SUSPENDED snap**(`ui_charscreen_close` 只屬 player-initiated close — CD C1)。

**Contract notes**:#4 EG-1 唔適用(workout-SFX forwarding consumer 係 #20;#22 全 direct `play_sfx`);web 首 gesture LOCKED drop = EC-31 接受。

### Asset 清單 draft(/asset-spec 用;§8.A naming;多數元素應 StyleBoxFlat / code-drawn,最終 split /asset-spec 裁)

- Sprites:`ui_icon_arrow_up_8` / `ui_icon_arrow_down_8`(8×8 白 sprite modulate)、`ui_icon_lock_on/off`、`ui_icon_slot_*` ×4(empty-state silhouette)、`ui_icon_offline`、`ui_icon_close_x`、`ui_icon_salvage`、`ui_card_item_bg`(9-slice)、`ui_card_rarity_accent`(單白 sprite 五色 modulate — 一 asset 五用)、`ui_sheet_bg`(9-slice)、`ui_tickrule_notch`(或 code-drawn)
- 重用:P-04 class icons(#20 已有)、P-07/P-08 slider/toggle(StyleBox)
- Avatar backdrop:GradientTexture2D(零 asset)
- SFX:上表 9 個 cue(OGG q4 mono ≤100KB)

📌 **Asset Spec** — Visual/Audio requirements 已定義。Art bible approved 後,run `/asset-spec system:character-screen` 產出 per-asset spec + generation prompts。

## UI Requirements

#22 本身就係 UI system — 本 section 收口 layout 結構 + pattern 引用 + 實作要求;詳細 wireframe / flow 由 `/ux-design character-screen` 產出(`design/ux/character-screen.md`)。

### Layout 結構

- **Persistent**:avatar preview panel(唔屬 tab 軸)+ tick-mark tier rule + 頂部 offline banner 位 + close X(≥48px)
- **Tab 軸**:`STATS`(default — review surface 為主)/ `LOADOUT` / `SETTINGS`
- **Modal 軸**:`SALVAGE_CONFIRM` / `ITEM_INSPECT` / `SLOT_PICKER`(bottom sheet)
- 入口 affordance 由 host shell own(Rule 1;shell 未 design — provisional)

### Pattern 引用(interaction-patterns.md)

| Pattern | 用處 | Note |
|---------|------|------|
| P-02 frameless bar | slider track | P-07 spec 內引用 |
| P-04 class icons | 「今日 class」label 配圖 | #20 已有 asset |
| P-06 rarity 5-tier | item card badge(corner accent + 文字 label)| 永不 color-alone |
| P-07 motion-intensity-slider | SETTINGS panel | 本 GDD = 佢嘅「Used In」實現;F2 quantize 係 #22 加嘅 implementation 細節 |
| P-08 reduce-motion-toggle | SETTINGS panel | `Camera.set_motion_reduction` — story 011 contract |
| P-03 number ticker | **唔適用於 stat tween** | F1(cubic lerp 經 formatter)≠ P-03(33ms/step、duration ∝ delta)— interaction-patterns P-03「Used In: #22」需 sync note(G-CS-6),免 implementer 錯套 |

### 實作要求

- Touch primary:全部 tap target ≥48px;無 hover-only(provenance 行 ITEM_INSPECT tap 路徑 — Rule 22);無 long-press
- Font:CJK body Zpix 12px floor;數字行 m6x11;H1 11px m6x11
- ARIA:`platform_detect.announce_aria`(shipped,#21 story-025)— avatar 變化 announcement(Rule 12)+ settings 值 announce(EC-28)
- Keyboard(desktop):ESC close(modal 先,screen 後 — EC-07);slider ←/→ ±10pct
- ADR-0001 UI Presentation budget 適用;screen 喺 IDLE 開,唔同 combat 爭 budget,但 particle = 0 pinned

> **📌 UX Flag — Character Screen**:本 system 有完整 UI requirements。Phase 4 入 epic 之前 **必須** run `/ux-design character-screen` 產出 `design/ux/character-screen.md`(#26 UX Flag L989 同樣要求);stories cite UX spec,唔直接 cite GDD。Bulk-salvage flow 係 #23 — #22 UX spec 唔包。

## Acceptance Criteria

> **49 ACs**(qa-lead 提案結構 2026-06-07,main session 擴充):**42 BLOCKING**(9 Logic unit + 33 Integration)+ **6 ADVISORY**(manual)+ **1 ADR-0001 RATIFICATION-GATED**。
> **Test seam 要求**:injected time source(F1 tween 用 manual `advance(delta_ms)` stepper,**唔綁 engine Tween wall clock** — 冇佢 Group B/D 全 flaky)、GSM / #17 / #26 ref injection(untyped var,GDScript DI seam 慣例)、ARIA sink = `platform_detect.announce_aria`(shipped seam)。
> **G-CS-1 gated 標記**:AC-20 / AC-31 嘅 picker source 喺 `get_loadout()` / `get_items_for_slot()` 落地前跑唔到 — story 排序須 G-CS-1 先行。

### Group A — Formulas(Logic / unit / headless GUT)

- **AC-01**:GIVEN F1 tween v_from=84, v_target=90, STAT_TWEEN_MS=300,WHEN advance 到 t=150ms,THEN interpolated = 89.25 且 display =「89」(golden vector)。Source: F1 | Type: Logic | Gate: BLOCKING | File: `tests/unit/character_screen/test_stat_tween.gd`
- **AC-02**:GIVEN tween 進行中(任意 t),WHEN 新 signal(target 95)到,THEN v_from := 當前 interpolated 值、clock 歸零、無 queue;連續 N 次 retarget 後 signal 停 → 收斂於最後 target。Source: F1 / EC-09 | Type: Logic | Gate: BLOCKING | File: 同上
- **AC-03**:GIVEN `fmt_s(v_target) == fmt_s(當前 display 值)`(含 crit_chance 0.071→0.074 sub-display-unit),WHEN signal 到,THEN 無 tween 無 arrow;進行中 tween kill + settle。Source: F1 zero-delta guard / EC-08 | Type: Logic | Gate: BLOCKING | File: 同上
- **AC-04**:GIVEN mid-tween 反悔 signal(A→B→A,`fmt(v_target)==fmt(display)`),WHEN 處理,THEN kill tween + settle + **arrow 清走**;arrow operand = raw interpolated `v_display_at_retarget`(pin)。Source: F1 / EC-10 | Type: Logic | Gate: BLOCKING | File: 同上
- **AC-05**:GIVEN raw input 0.6789 / 0.999 / −0.5 / 1.7,WHEN F2 quantize,THEN pct = 68 / 100 / 0 / 100,store = 0.68 / 1.0 / 0.0 / 1.0,label =「68%」/「100%」/「0%」/「100%」。Source: F2 | Type: Logic | Gate: BLOCKING | File: `tests/unit/character_screen/test_char_screen_format.gd`
- **AC-06**:GIVEN pct=100 撳 `+` / pct=0 撳 `−`,WHEN keyboard step,THEN clamp no-op 唔 wrap;pct=55 撳 `+` → 65。Source: F2 / EC-28 | Type: Logic | Gate: BLOCKING | File: 同上
- **AC-07**:GIVEN 3 件 —(EPIC,t=1000,`sword_a`)(EPIC,t=1000,`axe_b`)(RARE,t=2000,`bow_c`),WHEN F3 sort,THEN `[axe_b, sword_a, bow_c]`;重複 sort byte-identical(deterministic)。Source: F3 / EC golden vector | Type: Logic | Gate: BLOCKING | File: `tests/unit/character_screen/test_picker_sort.gd`
- **AC-08**:GIVEN aggregate {raw:90.4, effective:90.0} / {90.6, 90.0} / {0, 0},WHEN F4 evaluate,THEN hidden /「+90 / +91(受真身上限約束)」/ hidden 且 row render「+0」。Source: F4 / EC-12 | Type: Logic | Gate: BLOCKING | File: `tests/unit/character_screen/test_char_screen_format.gd`
- **AC-09**:GIVEN 7 個 stat 嘅 representative 值(含 crit_chance 0.07、move_speed 210.4),WHEN format,THEN 全部符合 Format Table(「7%」「210」等 golden vectors)。Source: Format Table | Type: Logic | Gate: BLOCKING | File: 同上

### Group B — Lifecycle(Integration / mock GSM)

- **AC-10**:GIVEN GSM state = IDLE 或 DISCONNECTED,WHEN `open()`,THEN 成功;GIVEN 其餘 7 個 state 逐個,WHEN `open()` / `can_open()`,THEN 拒絕 / false(double guard)。Source: Rule 1 | Type: Integration | Gate: BLOCKING | File: `tests/integration/character_screen/test_charscreen_lifecycle.gd`
- **AC-11**:GIVEN OPEN + `SALVAGE_CONFIRM` 開緊,WHEN GSM → WORKOUT_ACTIVE,THEN modal cancel(item 不變、salvage 永不執行)+ force-close 喺 ≤ FORCE_CLOSE_MAX_MS 完成 + pending command 唔 fire + **零 `play_sfx` call**(close cue 只屬 player-initiated — CD C1)。Source: Rule 3 / EC-01 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-12**:GIVEN OPEN,WHEN GSM → SUSPENDED,THEN instant snap CLOSED(無 animation);WHEN resume 返 IDLE,THEN **唔** auto-reopen。Source: Rule 3 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-13**:GIVEN OPEN 喺 IDLE,WHEN GSM → DISCONNECTED(同 reverse),THEN screen 唔 close、banner toggle;GIVEN modal open,THEN modal 唔受影響。Source: Rule 4 / EC-06 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-14**:GIVEN OPEN 喺 DISCONNECTED,WHEN GSM 直跳 WORKOUT_ACTIVE(resume_target,唔經 IDLE),THEN force-close 照行。Source: EC-03 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-15**:GIVEN 每條 close path(normal / force / suspend-snap)行完,WHEN introspect,THEN **零 active subscription**(CLOSED invariant)。Source: Rule 8 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-16**:GIVEN CLOSING 進行中,WHEN re-tap open,THEN ignore(唔 queue,無鬼 open)。Source: Rule 5 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-17**:GIVEN CLOSING / FORCE_CLOSING,WHEN 任何 subscribed signal 到,THEN handler no-op(無 render 無 error)。Source: EC-05 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-18**:GIVEN open,WHEN subscribe,THEN 3 條 subscription 全部經 `connect_for_initial_state`(grep / introspect);sentinel + 真 signal 同 frame 雙派 → render idempotent(同 state 二次 render 無變化)。Source: Rule 8 / EC-02 / ADR-0006 C6 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-19**:GIVEN ESC 撳一下 while modal open,WHEN 處理,THEN 只 dismiss modal(salvage = cancel);第二下先 close screen。Source: EC-07 | Type: Integration | Gate: BLOCKING | File: 同上

### Group C — Data binding(Integration / mock #11 #26)

- **AC-20** *(G-CS-1 gated)*:GIVEN open 第一 frame,WHEN read,THEN 7 stat + loadout + aggregate + shards + 5 avatar getters 全部 sync 讀齊(無 deferred fetch、無 loading state)。Source: Rule 7 | Type: Integration | Gate: BLOCKING | File: `tests/integration/character_screen/test_charscreen_binding.gd`
- **AC-21**:GIVEN OPEN,WHEN `stat_changed(attack_power, 84, 90, EQUIPMENT, _)`,THEN 該 row tween + ↑ arrow;WHEN source ≠ EQUIPMENT(同款 delta),THEN snap 更新、無 tween 無 arrow。Source: Rule 10 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-22**:GIVEN 一次 aggregate push 掂 4 條 derived,WHEN render,THEN 4 row 並行獨立 tween、constant duration 同時落定。Source: Rule 10 / F1 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-23**:GIVEN open,WHEN avatar panel render,THEN 5 getters 內容齊(visual state / posture label / tier badge / animation / milestone hint);hint 只喺 open + `avatar_visual_updated` 時 evaluate(mid-session flip 唔追)。Source: Rule 11 / EC-16 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-24**:GIVEN STATS tween 進行中,WHEN tab 切去 LOADOUT 再切返,THEN re-read + snap 到 true 值、舊 tween kill 唔 resume。Source: Rule 23 / EC-11 | Type: Integration | Gate: BLOCKING | File: 同上

### Group D — Commands(Integration / 真 #17 + mock GSM)

- **AC-25**:GIVEN equip 合法 candidate,WHEN command return `{"ok": true}`,THEN 同 frame re-read + slot card 更新;cosmetic equip → 無 stat tween,`avatar_visual_updated` 驅動 preview swap。Source: Rule 14 / Rule 21 | Type: Integration | Gate: BLOCKING | File: `tests/integration/character_screen/test_charscreen_commands.gd`
- **AC-26**:GIVEN command return error(`not_found` / `slot_type_mismatch` / `slot_empty`),WHEN 處理,THEN re-read + toast;GIVEN return `deferred_reentrancy`,THEN **無 toast**,下 frame re-read 收割。Source: Rule 15 / EC-17 / EC-23 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-27**:GIVEN manual equip 成功 + item 未 lock,WHEN render,THEN unconditional lock nudge 出現(LOCK_NUDGE_DURATION_MS 後消失);GIVEN item 已 lock,THEN 無 nudge。Source: Rule 18 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-28**:GIVEN salvage tap,WHEN modal 開,THEN 顯示 `salvage_yield(rarity)` preview + provenance + rarity badge;equipped item 加「現役裝備」warning;LEGENDARY 顯示 `signature_text`。**無任何單 tap 直達 salvage 執行嘅 code path**。Source: Rule 19 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-29**:GIVEN item `is_locked`,WHEN render loadout / inspect,THEN salvage 入口 disabled +「上鎖中」hint。Source: Rule 20 / EC-22 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-30**:GIVEN salvage 現役 weapon confirm,WHEN 執行,THEN slot empty-state render + 受影響 stat rows ↓ tween(EQUIPMENT source 自然流入)+ shards snap 更新。Source: EC-13 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-31** *(G-CS-1 gated)*:GIVEN slot tap,WHEN picker 開,THEN 只列 `slot_affinity` match + IN_INVENTORY、F3 排序;0 件 → empty-state sheet 照開;stale row equip → `not_found` → toast + 原地 rebuild(唔 close picker)。Source: Rule 17 / EC-19 / EC-20 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-32**:GIVEN `SALVAGE_CONFIRM` open 期間 item 被外部消滅,WHEN confirm tap,THEN `not_found` → modal close + toast + 全 panel re-read;#22 自身零 shards 計算。Source: EC-18 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-33**:GIVEN EC-04 三個 ordering(equip-then-force-close / force-close-then-tap / deferred_reentrancy-then-force-close),WHEN 逐個重演,THEN 結果 = EC-04 (i)(ii)(iii) pin 嘅行為(command 成立+skip render+toast drop / input ignore / replay 照行+下次 open 收割)。Source: EC-04 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-34**:GIVEN ITEM_INSPECT open,WHEN render,THEN provenance_text 全 tier 顯示 + LEGENDARY signature_text;display timezone = device local。Source: Rule 22 / EC-15 | Type: Integration | Gate: BLOCKING | File: 同上

### Group E — Settings(Integration / mock #6 #7 #3)

- **AC-35**:GIVEN slider 改值,WHEN settle,THEN `set_motion_intensity(v_store)` 即時 call(apply-on-change,無 save button);P-08 flip → `set_motion_reduction(bool)` + persist `settings.camera_motion_reduction`。Source: Rule 26 / Rule 25 | Type: Integration | Gate: BLOCKING | File: `tests/integration/character_screen/test_charscreen_settings.gd`
- **AC-36**:GIVEN drag 連續 30 tick,WHEN 觀察 persist,THEN **零** per-tick write;release 後 debounce window 內恰好 1 次 `PersistenceLayer.write`。Source: Rule 27 / EC-26 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-37**:GIVEN pct==0 release,WHEN preview,THEN preview call 照發(uniform path — #6 short-circuit 負責零 motion);release 先播一次,drag 期間零 preview call。Source: Rule 30 / EC-24 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-38**:GIVEN drag 中(未 release),WHEN force-close,THEN 當 settle — 當前 applied 值 enqueue write 先於 close;GIVEN persist fail(Private Mode mock),THEN session-applied 保留 + banner suppress。Source: EC-27 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-39**:GIVEN persisted 值 0.999(legacy float),WHEN panel open,THEN 顯示「100%」(F2 apply)但**唔**即時 rewrite persistence;user settle 先 normalize。Source: EC-25 | Type: Integration | Gate: BLOCKING | File: 同上
- **AC-40**:GIVEN `settings.*` keys 唔存在(fresh install),WHEN panel open,THEN defaults render(motion_intensity 1.0 /「100%」;camera_motion_reduction false)。Source: Rule 28 | Type: Integration | Gate: BLOCKING | File: 同上

### Group F — ARIA + Audio(Integration)

- **AC-41**:GIVEN `avatar_visual_updated` significant change,WHEN 處理,THEN `platform_detect.announce_aria("Avatar 變為 [class] T[tier]")` 恰好一次;window 內多次 → 只最後一條;非 significant → 零 announce。Source: Rule 12 / EC-29 | Type: Integration | Gate: BLOCKING | File: `tests/integration/character_screen/test_charscreen_aria.gd`
- **AC-42**:GIVEN 一次 equip command 引發 4-row 並行 tween,WHEN settle,THEN `ui_equip_settle` SFX 經 `play_sfx` 恰好 **1** 響(唔係 4);silent 名單 events(arrow / tab / banner / nudge)零 SFX call。Source: Visual/Audio | Type: Integration | Gate: BLOCKING | File: 同上

### Group G — Manual(ADVISORY)

- **AC-43**:GIVEN 長 CJK provenance / signature 文字,WHEN 截圖 walkthrough,THEN wrap 優先、死限先 ellipsis + inspect 全文;font 永不細過 Zpix 12px。Source: EC-14 | Type: UI | Gate: ADVISORY | File: `production/qa/evidence/character-screen/`
- **AC-44**:GIVEN 真 screen reader(web AT),WHEN avatar 變化 + settings 操作,THEN announcements 可聽、語意正確。Source: Rule 12 | Type: UI | Gate: ADVISORY | File: 同上
- **AC-45**:GIVEN touch device walkthrough,WHEN 量 tap targets,THEN 全部 ≥48px。Source: UI Requirements | Type: UI | Gate: ADVISORY | File: 同上
- **AC-46**:GIVEN browser back button,WHEN 撳,THEN #22 唔 intercept(absence claim — headless 不可測)。Source: Rule 5 | Type: UI | Gate: ADVISORY | File: 同上
- **AC-47**:GIVEN 完整 screen walkthrough 截圖 set,WHEN 對照 Visual/Audio「完全無 VFX」名單 + L0-L3 tier 表,THEN 零 particle / flash / pulse / elastic;greyscale check(§4.C)pass。Source: Visual/Audio | Type: Visual | Gate: ADVISORY | File: 同上
- **AC-48**:GIVEN 玩家試玩(soak),WHEN 觀察 median session,THEN 安靜瀏覽為主(Player Fantasy 驗證標準 a)。Source: Player Fantasy | Type: Playtest | Gate: ADVISORY | File: 同上

### Group H — RATIFICATION-GATED

- **AC-49** *[ADR-0001 RATIFICATION-GATED]*:GIVEN mobile tier 真機,WHEN screen open + 4-row tween + picker open,THEN UI CPU ≤ 2ms / frame budget 內(ADR-0001 mobile 數字 ratify 後先 binding)。Source: ADR-0001 | Type: Performance | Gate: RATIFICATION-GATED | File: `tests/performance/character_screen/`

## Open Questions

| ID | Question | Owner | Target |
|----|----------|-------|--------|
| **Q-CS1** | 入口 affordance host shell 歸宿 — home nav / master scene 未 design(#24 Login UI 係最近親 surface)。`can_open()` contract 已 pin(Rule 1),shell 接線時兌現 | #24 GDD / master scene | #24 authoring |
| **Q-CS2** | Auto-equip 反轉事後可見性 —「上次自動換裝 X→Y」note(MVP silent 接受,EC-21;note 需 #17 EQUIPPED 轉換 timestamp 數據) | #22 v0.2 | v0.2 |
| **Q-CS3** | Q-F5 `hud_shake_inclusion` toggle(registry L1450 — implementation owner #22 + master scene)— 機制係 CanvasLayer 重排,等 master scene 成形 | #22 v0.2 + master scene | v0.2 |
| **Q-CS4** | Browser back / SPA history 整合(MVP 唔 intercept — AC-46 absence claim)— 同 #27 PWA 層一齊裁 | #27 Onboarding / PWA | v0.2 |
| **Q-CS5** | 上週對比(#28 Telemetry 數據)+ PR history panel(#18 `get_baselines()`)— 兩個 v0.2 panel 嘅 layout 預留 | #22 v0.2 | v0.2(#28/#18 ready 後)|
| **Q-CS6** | Art bible 內部矛盾:§2.1 Menu row「Character 100% 飽和」vs §4.E Menu row「Character ×0.85」— #22 裁 1.0(「凸顯今日成果」),erratum flag 俾 art-director | art-director | art bible 下次 revision |
| **Q-CS7** | `SfxCatalog.tres` 9 個 `ui_charscreen_*` cue 嘅 audio asset 製作 — 隨 `/asset-spec system:character-screen` | /asset-spec | epic 期間 |
